/* # -*- coding: utf-8; mode: c; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=c:et:sw=4:ts=4:sts=4
 */
/*
 * tracelib.c
 *
 * Copyright (c) 2007-2008 Eugene Pimenov (GSoC)
 * Copyright (c) 2008-2010, 2012-2015, 2017 The MacPorts Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the MacPorts Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if HAVE_SYS_EVENT_H
#include <sys/event.h>
#endif
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#include <cregistry/portgroup.h>
#include <cregistry/entry.h>
#include <registry2.0/registry.h>
#include <darwintracelib1.0/sandbox_actions.h>

#if defined(LOCAL_PEERPID) && defined(HAVE_LIBPROC_H)
#include <libproc.h>
#define HAVE_PEERPID_LIST
#endif /* defined(LOCAL_PEERPID) && defined(HAVE_LIBPROC_H) */

#include "tracelib.h"

#include "Pextlib.h"

#include "strlcat.h"

#ifdef HAVE_TRACEMODE_SUPPORT
#ifndef HAVE_STRLCPY
/* Define strlcpy if it's not available. */
size_t strlcpy(char *dst, const char *src, size_t size);
size_t strlcpy(char *dst, const char *src, size_t size) {
    size_t result = strlen(src);
    if (size > 0) {
        size_t copylen = size - 1;
        if (copylen > result) {
            copylen = result;
        }
        memcpy(dst, src, copylen);
        dst[copylen] = 0;
    }
    return result;
}
#endif

#ifdef HAVE_PEERPID_LIST
static bool peerpid_list_enqueue(int sock, pid_t pid);
static pid_t peerpid_list_dequeue(int sock);
static pid_t peerpid_list_get(int sock, const char **progname);
static void peerpid_list_walk(bool (*callback)(int sock, pid_t pid, const char *progname));
#endif /* defined(HAVE_PEERPID_LIST) */


static char *name;
static char *sandbox;
static size_t sandboxLength;
static char **depends = NULL;
static size_t dependsLength = 0;
static int sock = -1;
static int kq = -1;
/* EVFILT_USER isn't available (< 10.6), use the self-pipe trick to return from
 * the blocking kqueue(2) call by writing a byte to the pipe */
static int selfpipe[2];
static int enable_fence = 0;
static Tcl_Interp *interp;

static mount_cs_cache_t *mount_cs_cache;

/**
 * Mutex that shall be acquired to exclusively lock checking and acting upon
 * the value of kq, indicating whether the event loop has started. If it has
 * started, shutdown of the event loop shall occur by writing to the write end
 * of the selfpipe (which is non-blocking), which will in turn trigger the
 * event loop termination and a signal on the evloop_signal condition variable
 * when the loop has been terminated and it is safe to free the resources that
 * were used by the loop.
 *
 * If kq is -1, the event loop has not been started and resources can
 * immediately be free(3)d (under the lock to avoid concurrent set up of the
 * event loop in a different thread).
 */
static pthread_mutex_t evloop_mutex = PTHREAD_MUTEX_INITIALIZER;

/**
 * Condition variable that shall be used to signal the end of the event loop
 * after a termination signal has been sent to it via the write end of
 * selfpipe. The associated mutex is evloop_mtx.
 */
static pthread_cond_t evloop_signal = PTHREAD_COND_INITIALIZER;

static void send_file_map(int sock);
static void dep_check(int sock, char *path);

typedef enum {
    SANDBOX_UNKNOWN,
    SANDBOX_VIOLATION
} sandbox_violation_t;
static void sandbox_violation(int sock, const char *path, sandbox_violation_t type);

#ifdef HAVE_PEERPID_LIST
typedef struct _peerpid {
    struct _peerpid *ppid_next;
    char            *ppid_prog;
    int              ppid_sock;
    pid_t            ppid_pid;
} peerpid_entry_t;

static peerpid_entry_t *peer_list = NULL;

/**
 * Add a new entry to the list of PIDs of peers. Call this once for each
 * accepted socket with the socket and the peer's PID.
 *
 * @param sock The new socket that was opened by the process with the given PID
 *             and should be added to the list of peers.
 * @param pid The PID of the new peer.
 * @return boolean indicating success.
 */
static bool peerpid_list_enqueue(int sock, pid_t pid) {
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    const char *progname = "<unknown>";

    peerpid_entry_t *ppid = malloc(sizeof(peerpid_entry_t));
    if (!ppid) {
        return false;
    }

    if (proc_pidpath(pid, pathbuf, sizeof(pathbuf))) {
        progname = pathbuf;
    }

    ppid->ppid_prog = strdup(progname);
    if (!ppid->ppid_prog) {
        free(ppid);
        return false;
    }
    ppid->ppid_sock = sock;
    ppid->ppid_pid = pid;
    ppid->ppid_next = peer_list;
    peer_list = ppid;
    return true;
}

/**
 * Given a socket, dequeue a peer from the current list of peers. Use this when
 * a socket is closed.
 *
 * @param sock The socket that is being closed and should be dequeued.
 * @return The PID of the socket that has been dequeued, or (pid_t) -1
 */
static pid_t peerpid_list_dequeue(int sock) {
    peerpid_entry_t **ref = &peer_list;
    while (*ref) {
        peerpid_entry_t *curr = *ref;
        if (curr->ppid_sock == sock) {
            // dequeue the element
            *ref = curr->ppid_next;
            pid_t pid = curr->ppid_pid;
            free(curr->ppid_prog);
            free(curr);
            return pid;
        }

        ref = &curr->ppid_next;
    }

    return (pid_t) -1;
}

/**
 * Return the peer PID given a socket.
 *
 * @param sock The socket for which the peer PID is needed.
 * @param progname A pointer that will point to the string that holds the
 *                 command line corresponding to the PID at the time of
 *                 enqueuing. Set to NULL if not needed.
 * @return The peer's PID or (pid_t) -1, if the socket could not be found in the list.
 */
static pid_t peerpid_list_get(int sock, const char **progname) {
    peerpid_entry_t *curr = peer_list;
    while (curr) {
        if (curr->ppid_sock == sock) {
            if (progname) {
                *progname = curr->ppid_prog;
            }
            return curr->ppid_pid;
        }

        curr = curr->ppid_next;
    }

    return (pid_t) -1;
}

/**
 * Walk the current list of (socket, peer PID) pairs and call a callback
 * function for each pair.
 *
 * @param callback Callback function to call for each tuple of socket, peer PID and
 *             peer command line. The function should take an integer (the
 *             socket), a pid_t (the peer's PID) and a const char * (the peer's
 *             command line) and return a boolean (true, if the element should
 *             be removed from the list, false otherwise). The callback must
 *             not modify the list using peerpid_list_enqueue() or
 *             peerpid_list_dequeue().
 */
static void peerpid_list_walk(bool (*callback)(int sock, pid_t pid, const char *progname)) {
    peerpid_entry_t **ref = &peer_list;
    while (*ref) {
        peerpid_entry_t *curr = *ref;
        if (callback(curr->ppid_sock, curr->ppid_pid, curr->ppid_prog)) {
            // dequeue the element
            *ref = curr->ppid_next;
            free(curr->ppid_prog);
            free(curr);
            continue;
        }

        ref = &curr->ppid_next;
    }
}
#endif /* defined(HAVE_PEERPID_LIST) */

#define MAX_SOCKETS (64)
#define BUFSIZE     (4096)

/**
 * send a buffer \c buf with the given length \c size to the socket \c sock, by
 * using the communication protocol between darwintrace and tracelib (i.e., by
 * prefixing the code with a uint32_t containing the length of the message)
 *
 * \param[in] sock the socket to send to
 * \param[in] buf the buffer to send, should contain at least \c size bytes
 * \param[in] size the number of bytes in \c buf
 */
static void answer_s(int sock, const char *buf, uint32_t size) {
    send(sock, &size, sizeof(size), 0);
    send(sock, buf, size, 0);
}

/**
 * send a '\0'-terminated string given in \c buf to the socket \c by using the
 * communication protocol between darwintrace and tracelib. See \c answer_s for
 * details.
 *
 * \param[in] sock the socket to send to
 * \param[in] buf the string to send; must be \0-terminated
 */
static void answer(int sock, const char *buf) {
    answer_s(sock, buf, (uint32_t) strlen(buf));
}

/**
 * Closes the two sockets given in \a p and sets their values to -1.
 */
static void pipe_cleanup(int p[2]) {
    for (size_t i = 0; i < 2; ++i) {
        if (p[i] != -1) {
            close(p[i]);
            p[i] = -1;
        }
    }
}

/**
 * Helper function to simplify error handling. Converts the error indicated by
 * \a msg, appended with a string representation of the UNIX error \a errno
 * into a Tcl error by setting up the result of the Tcl interpreter \a interp
 * accordingly.
 *
 * Returns TCL_ERROR to be used as the return value of the caller.
 */
static int error2tcl(const char *msg, int err, Tcl_Interp *interp) {
    Tcl_SetErrno(err);
    Tcl_ResetResult(interp);
    if (err != 0) {
        Tcl_AppendResult(interp, msg, (char *) Tcl_PosixError(interp), NULL);
    } else {
        Tcl_AppendResult(interp, msg, NULL);
    }

    return TCL_ERROR;
}

/**
 * Sets the path of the tracelib unix socket where darwintrace should attempt
 * to connect to. This path should be specific to the port being installed.
 * Different sockets should be used for different ports (and maybe even
 * phases).
 *
 * \param[in,out] interp the Tcl interpreter
 * \param[in] objc the number of parameters
 * \param[in] objv the parameters
 * \return a Tcl return code
 */
static int TracelibSetNameCmd(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "number of arguments should be exactly 3");
        return TCL_ERROR;
    }

    name = strdup(Tcl_GetString(objv[2]));
    if (!name) {
        Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
        return TCL_ERROR;
    }

    return TCL_OK;
}

/**
 * Save sandbox boundaries to memory and format them for darwintrace. This
 * means changing : to \0 (with \ being an escape char).
 *
 * Input:
 *  /dev/null:/dev/tty:/tmp\:
 * In variable;
 *  /dev/null\0/dev/tty\0/tmp:\0\0
 *
 * \param[in,out] interp the Tcl interpreter
 * \param[in] objc the number of parameters
 * \param[in] objv the parameters
 * \return a Tcl return code
 */
static int TracelibSetSandboxCmd(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    char *src, *dst;
    enum { NORMAL, ACTION, ESCAPE } state = NORMAL;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "number of arguments should be exactly 3");
        return TCL_ERROR;
    }

    src = Tcl_GetString(objv[2]);
    sandboxLength = strlen(src) + 2;
    sandbox = malloc(sandboxLength);
    if (!sandbox) {
        Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
        return TCL_ERROR;
    }
    for (dst = sandbox; *src != '\0'; src++) {
        switch (*src) {
            case '\\':
                if (state == ESCAPE) {
                    /* double backslash, turn into single backslash (note
                     * C strings use \ as escape char, too! */
                    *dst++ = '\\';
                    state = NORMAL;
                } else {
                    /* hit a backslash, assume this is an escape sequence */
                    state = ESCAPE;
                }
                break;
            case ':':
                if (state == ESCAPE) {
                    /* : was escaped, keep literally */
                    *dst++ = ':';
                    state = NORMAL;
                } else if (state == ACTION) {
                    /* : -> \0, we're done with this entry */
                    *dst++ = '\0';
                    state = NORMAL;
                } else {
                    /* unescaped : should never occur in normal state */
                    free(sandbox);
                    Tcl_SetResult(interp, "Unexpected colon before action specification.", TCL_STATIC);
                    return TCL_ERROR;
                }
                break;
            case '=':
                if (state == ESCAPE) {
                    /* = was escaped, keep literally */
                    *dst++ = '=';
                    state = NORMAL;
                } else {
                    /* hit =, this is the end of the path, the action follows */
                    *dst++ = '\0';
                    state = ACTION;
                }
                break;
            case '+':
            case '-':
            case '?':
                if (state == ACTION) {
                    /* control character after equals, convert to binary */
                    switch (*src) {
                        case '+':
                            *dst++ = FILEMAP_ALLOW;
                            break;
                        case '-':
                            *dst++ = FILEMAP_DENY;
                            break;
                        case '?':
                            *dst++ = FILEMAP_ASK;
                            break;
                    }
                } else {
                    /* before equals sign, copy literally */
                    *dst++ = *src;
                }
                break;
            default:
                if (state == ESCAPE) {
                    /* unknown escape sequence, free buffer and raise an error */
                    free(sandbox);
                    Tcl_SetResult(interp, "Unknown escape sequence.", TCL_STATIC);
                    return TCL_ERROR;
                }
                if (state == ACTION) {
                    /* unknown control character, free buffer and raise an error */
                    free(sandbox);
                    Tcl_SetResult(interp, "Unknown control character. Possible values are +, -, and ?.", TCL_STATIC);
                    return TCL_ERROR;
                }
                /* otherwise: copy the char */
                *dst++ = *src;
                break;
        }
    }
    /* add two \0 to mark the end */
    *dst++ = '\0';
    *dst = '\0';

    return TCL_OK;
}

/**
 * Receive line from socket, parse it and send an answer, if necessary. The
 * caller should ensure that data is available for reading from the given
 * socket. This method will block until a complete message has been read.
 *
 * \param[in] sock the socket to communicate with
 * \return 1, if the communication was successful, 0 in case of errors and/or
 *         when the socket should be closed
 */
static int process_line(int sock) {
    char *f;
    char buf[BUFSIZE];
    uint32_t len = 0;
    ssize_t ret;

    if ((ret = recv(sock, &len, sizeof(len), MSG_WAITALL)) != sizeof(len)) {
        if (ret < 0) {
            perror("tracelib: recv");
        } else if (ret == 0) {
            /* this usually means the socket was closed by the remote side */
        } else {
            fprintf(stderr, "tracelib: partial data received: expected %zu, but got %zd on socket %d\n", sizeof(len), ret, sock);
        }
        return 0;
    }

    if (len > BUFSIZE - 1) {
        pid_t pid = (pid_t) -1;
#ifdef HAVE_PEERPID_LIST
        pid = peerpid_list_get(sock, NULL);
#endif
        fprintf(stderr, "tracelib: transfer too large: %" PRIu32 " bytes sent, but buffer holds %d on socket %d from pid %ld\n", len, BUFSIZE - 1, sock, (unsigned long) pid);
        return 0;
    }

    if ((ret = recv(sock, buf, len, MSG_WAITALL)) != (ssize_t) len) {
        if (ret < 0) {
            perror("tracelib: recv");
        } else {
            fprintf(stderr, "tracelib: partial data received: expected %" PRIu32 ", but got %zd on socket %d\n", len, ret, sock);
        }
        return 0;
    }
    buf[len] = '\0';

    f = strchr(buf, '\t');
    if (!f) {
        fprintf(stderr, "tracelib: malformed command '%s' from socket %d\n", buf, sock);
        return 0;
    }

    /* Replace \t with \0 */
    *f = '\0';
    /* Advance pointer to arguments */
    f++;

    if (strcmp(buf, "filemap") == 0) {
        send_file_map(sock);
    } else if (strcmp(buf, "sandbox_unknown") == 0) {
        sandbox_violation(sock, f, SANDBOX_UNKNOWN);
    } else if (strcmp(buf, "sandbox_violation") == 0) {
        sandbox_violation(sock, f, SANDBOX_VIOLATION);
    } else if (strcmp(buf, "dep_check") == 0) {
        dep_check(sock, f);
    } else {
        fprintf(stderr, "tracelib: unexpected command %s (%s)\n", buf, f);
        return 0;
    }

    return 1;
}

/**
 * Construct an in-memory representation of the sandbox file map and send it to
 * the socket indicated by \c sock.
 *
 * \param[in] sock the socket to send the sandbox bounds to
 */
static void send_file_map(int sock) {
    if (enable_fence) {
        answer_s(sock, sandbox, sandboxLength);
    } else {
        char allowAllSandbox[5] = {'/', '\0', FILEMAP_ALLOW, '\0', '\0'};
        answer_s(sock, allowAllSandbox, sizeof(allowAllSandbox));
    }
}

/**
 * Process a sandbox violation reported by darwintrace. Calls back up to Tcl to
 * run a callback with the reported violation path.
 *
 * \param[in] sock socket reporting the violation; unused.
 * \param[in] path the offending path to be passed to the callback
 */
static void sandbox_violation(int sock UNUSED, const char *path, sandbox_violation_t type) {
    Tcl_SetVar(interp, "_sandbox_viol_path", path, 0);
    int retVal = TCL_OK;
    switch (type) {
        case SANDBOX_VIOLATION:
            retVal = Tcl_Eval(interp, "slave_add_sandbox_violation ${_sandbox_viol_path}");
            break;
        case SANDBOX_UNKNOWN:
            retVal = Tcl_Eval(interp, "slave_add_sandbox_unknown ${_sandbox_viol_path}");
            break;
    }

    if (retVal != TCL_OK) {
        fprintf(stderr, "Error evaluating Tcl statement to add sandbox violation: %s\n", Tcl_GetStringResult(interp));
    }

    Tcl_UnsetVar(interp, "_sandbox_viol_path", 0);
}

/**
 * Internal helper function to compare two strings.
 */
static int pointer_strcmp(const char** a, const char** b) {
    return strcmp(*a, *b);
}

/**
 * Check whether a path is in the transitive hull of dependencies of the port
 * currently being installed and send the result of the query back to the
 * socket.
 *
 * Sends one of the following characters as return code to the socket:
 *  - #: in case of errors. Not handled by the darwintrace code, which will
 *       lead to an error and the termination of the processing that sent the
 *       request causing this error.
 *  - ?: if the file isn't known to MacPorts (i.e., not registered to any port)
 *  - +: if the file was installed by a dependency and access should be granted
 *  - !: if the file was installed by a MacPorts port which is not in the
 *       transitive hull of dependencies and access should be denied.
 *
 * \param[in] sock the socket to answer to
 * \param[in] path the path to return the dependency information for
 */
static void dep_check(int sock, char *path) {
    char *port = 0;
    int fs_cs = -1;
    reg_registry *reg;
    reg_entry entry;
    reg_error error;

    if (NULL == (reg = registry_for(interp, reg_attached))) {
        ui_error(interp, "%s", Tcl_GetStringResult(interp));
        /* send unexpected output to make the build fail */
        answer(sock, "#");
    }

#ifdef __APPLE__
    fs_cs = fs_case_sensitive_darwin(interp, path, mount_cs_cache);
#endif /* __APPLE__ */

    if (-1 == fs_cs) {
        fs_cs = fs_case_sensitive_fallback(interp, path, mount_cs_cache);
    }

    if (-1 == fs_cs) {
        /*
         * Unable to determine FS case-sensitivity.
         * Assume the worst case (case-insensitive.)
         */
        fs_cs = 0;
    }

    /* find the port id */
    entry.reg = reg;
    entry.proc = NULL;
    entry.id = reg_entry_owner_id(reg, path, fs_cs);
    if (entry.id == 0) {
        /* file isn't known to MacPorts */
        answer(sock, "?");
        return;
    }

    /* find the port's name to compare with out list */
    if (!reg_entry_propget(&entry, "name", &port, &error)) {
        /* send unexpected output to make the build fail */
        ui_error(interp, "%s", error.description);
        answer(sock, "#");
    }

    /* check our list of dependencies; use binary search on sorted list */
    if (NULL != bsearch(&port, depends, dependsLength, sizeof(*depends),
                        (int (*)(const void*, const void*)) pointer_strcmp)) {
        free(port);
        answer(sock, "+");
    } else {
        free(port);
        answer(sock, "!");
    }
}

static int TracelibOpenSocketCmd(Tcl_Interp *in) {
    struct sockaddr_un sun;

    if (-1 == (sock = socket(PF_LOCAL, SOCK_STREAM, 0))) {
        return error2tcl("socket: ", errno, in);
    }

    sun.sun_family = AF_UNIX;
    strlcpy(sun.sun_path, name, sizeof(sun.sun_path));

    if (-1 == (bind(sock, (struct sockaddr *) &sun, sizeof(sun)))) {
        int err = errno;
        close(sock);
        sock = -1;
        return error2tcl("bind: ", err, in);
    }

    if (-1 == listen(sock, SOMAXCONN)) {
        int err = errno;
        close(sock);
        sock = -1;
        return error2tcl("bind: ", err, in);
    }

    // keep a reference to the interpreter that opened the socket
    interp = in;

    return TCL_OK;
}

#ifdef HAVE_PEERPID_LIST
/**
 * Callback to be passed to peerpid_list_walk(). Closes the open sockets and
 * sends SIGTERM to the associated processes. Leaves the list unmodified.
 */
static bool close_and_send_sigterm(int sock UNUSED, pid_t pid, const char *progname) {
    ui_warn(interp, "Sending SIGTERM to process %ld: %s", (unsigned long) pid, progname);
    kill(pid, SIGTERM);

    // keep the elements in the list
    return false;
}

/**
 * Callback to be passed to peerpid_list_walk(). Sends SIGKILL to the processes
 * and deletes the elements from the list.
 */
static bool send_sigkill_and_free(int sock, pid_t pid, const char *progname UNUSED) {
    close(sock);
    kill(pid, SIGKILL);

    // remove the elements from the list
    return true;
}
#endif

/* create this on heap rather than stack, due to its rather large size */
static struct kevent res_kevents[MAX_SOCKETS];

static int TracelibRunCmd(Tcl_Interp *in) {
    struct kevent kev;
    int retval = TCL_ERROR;
    int flags;
    int opensockcount = 0;
    bool break_eventloop = false;

    /* (Re-)initialize mount point FS case-sensitivity cache. */
    if (mount_cs_cache) {
        reset_mount_cs_cache(mount_cs_cache);
    }
    else {
        mount_cs_cache = new_mount_cs_cache();
    }

    pthread_mutex_lock(&evloop_mutex);
    /* bring all variables into a defined state so the cleanup code can be
     * called from anywhere */
    selfpipe[0] = -1;
    selfpipe[1] = -1;
    kq = -1;

    if (-1 == (kq = kqueue())) {
        error2tcl("kqueue: ", errno, in);
        goto error_locked;
    }

    if (sock != -1) {
        /* mark listen socket non-blocking in order to prevent a race condition
         * that would occur between kevent(2) and accept(2), if a incoming
         * connection is aborted before it is accepted. Using a non-blocking
         * accept(2) prevents the problem.*/
        flags = fcntl(sock, F_GETFL, 0);
        if (-1 == fcntl(sock, F_SETFL, flags | O_NONBLOCK)) {
            error2tcl("fcntl(F_SETFL, += O_NONBLOCK): ", errno, in);
            goto error_locked;
        }

        /* register the listen socket in the kqueue */
        EV_SET(&kev, sock, EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
        if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
            error2tcl("kevent (listen socket): ", errno, in);
            goto error_locked;
        }
        /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
         * always be returned. When a filter is successfully added, the data field
         * will be zero. */
        if ((kev.flags & EV_ERROR) == 0 || (kev.data != 0)) {
            error2tcl("kevent (listen socket receipt): ", kev.data, in);
            goto error_locked;
        }


        /* use the self-pipe trick to trigger returning from kevent(2) when
         * tracelib closesocket is called. */
        if (-1 == pipe(selfpipe)) {
            error2tcl("pipe: ", errno, in);
            goto error_locked;
        }

        /* mark the write side of the pipe non-blocking */
        flags = fcntl(selfpipe[1], F_GETFL, 0);
        if (-1 == fcntl(selfpipe[1], F_SETFL, flags | O_NONBLOCK)) {
            error2tcl("fcntl(F_SETFL, += O_NONBLOCK): ", errno, in);
            goto error_locked;
        }

        /* wait for the user event on the listen socket, as sent by CloseCmd as
         * deathpill */
        EV_SET(&kev, selfpipe[0], EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
        if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
            error2tcl("kevent (selfpipe): ", errno, in);
            goto error_locked;
        }
        /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
         * always be returned. When a filter is successfully added, the data field
         * will be zero. */
        if ((kev.flags & EV_ERROR) == 0 || (kev.data != 0)) {
            error2tcl("kevent (selfpipe receipt): ", kev.data, in);
            goto error_locked;
        }
    }
    pthread_mutex_unlock(&evloop_mutex);

    while (sock != -1 && !break_eventloop) {
        int keventstatus;
        bool incoming = false;

        /* run kevent(2) until new activity is available */
        do {
            if (-1 == (keventstatus = kevent(kq, NULL, 0, res_kevents, MAX_SOCKETS, NULL))) {
                error2tcl("kevent (main loop): ", errno, in);
                goto error_unlocked;
            }
        } while (keventstatus == 0);

        for (int i = 0; i < keventstatus; ++i) {
            /* handle traffic on the selfpipe */
            if ((int) res_kevents[i].ident == selfpipe[0]) {
                /* traffic on the selfpipe means we should clean up */
                break_eventloop = true;
                /* finish processing this batch */
                continue;
            } else if ((int) res_kevents[i].ident != sock) {
                /* if the socket is to be closed, or */
                if ((res_kevents[i].flags & (EV_EOF | EV_ERROR)) > 0
                    /* new data is available, and its processing tells us to
                     * close the socket */
                    || (!process_line(res_kevents[i].ident))) {
                        /* an error occured or process_line suggested closing
                         * this socket */
                        close(res_kevents[i].ident);
                        /* closing the socket will automatically remove it from the
                         * kqueue :) */
                        opensockcount--;

#ifdef HAVE_PEERPID_LIST
                        if (peerpid_list_dequeue(res_kevents[i].ident) == (pid_t) -1) {
                            fprintf(stderr, "tracelib: didn't find PID for closed socket %d\n", (int) res_kevents[i].ident);
                        }
#endif
                }
            } else {
                /* the control socket has activity – we might have a new
                 * connection. */

                /* handle error conditions */
                if ((res_kevents[i].flags & (EV_ERROR | EV_EOF)) > 0) {
                    error2tcl("control socket closed", 0, in);
                    goto error_unlocked;
                }

                /* delay processing, process data on existing sockets first */
                incoming = true;
            }
        }

        if (incoming) {
            /* new connection attempt(s) */
            for (;;) {
                int s;

                if (-1 == (s = accept(sock, NULL, NULL))) {
                    if (errno == EWOULDBLOCK) {
                        break;
                    }

                    error2tcl("accept: ", errno, in);
                    goto error_unlocked;
                }

                flags = fcntl(s, F_GETFL, 0);
                if (-1 == fcntl(s, F_SETFL, flags & ~O_NONBLOCK)) {
                    ui_warn(interp, "tracelib: couldn't mark socket as blocking");
                    close(s);
                    continue;
                }

                /* register the new socket in the kqueue */
                EV_SET(&kev, s, EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
                if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
                    ui_warn(interp, "tracelib: error adding socket to kqueue");
                    close(s);
                    continue;
                }
                /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
                 * always be returned. When a filter is successfully added, the data field
                 * will be zero. */
                if ((kev.flags & EV_ERROR) == 0 || (kev.data != 0)) {
                    ui_warn(interp, "tracelib: error adding socket to kqueue (receipt)");
                    close(s);
                    continue;
                }

#ifdef HAVE_PEERPID_LIST
                pid_t peer_pid = (pid_t) -1;
                socklen_t peer_pid_len = sizeof(peer_pid);
                if (getsockopt(s, SOL_LOCAL, LOCAL_PEERPID, &peer_pid, &peer_pid_len) == 0) {
                    // We found a PID for the remote side
                    peerpid_list_enqueue(s, peer_pid);
                } else {
                    // Error occured, process has probably already terminated
                    close(s);
                    continue;
                }
#endif
                opensockcount++;
            }
        }
    }

    retval = TCL_OK;

error_unlocked:
    pthread_mutex_lock(&evloop_mutex);
error_locked:
    // Close remainig sockets to avoid dangling processes
    if (opensockcount > 0) {
#ifdef HAVE_PEERPID_LIST
        ui_warn(interp, "tracelib: %d open sockets leaking at end of runcmd, closing, sending SIGTERM and SIGKILL", opensockcount);
        peerpid_list_walk(close_and_send_sigterm);
        peerpid_list_walk(send_sigkill_and_free);
#else
        ui_warn(interp, "tracelib: %d open sockets leaking at end of runcmd", opensockcount);
#endif
    }

    // cleanup selfpipe and set it to -1
    pipe_cleanup(selfpipe);

    // close kqueue(2) socket
    if (kq != -1) {
        close(kq);
        kq = -1;
    }

    pthread_mutex_unlock(&evloop_mutex);
    // wake up any waiting threads in TracelibCloseSocketCmd
    pthread_cond_broadcast(&evloop_signal);

    /* Free mount_cs_cache object. */
    if (mount_cs_cache) {
        reset_mount_cs_cache(mount_cs_cache);

        free(mount_cs_cache);
        mount_cs_cache = NULL;
    }

    return retval;
}

static int TracelibCleanCmd(Tcl_Interp *interp UNUSED) {
#define safe_free(x) do{ \
        free(x); \
        x = NULL; \
    } while(0);

    if (sock != -1) {
        close(sock);
        sock = -1;
    }

    if (name) {
        unlink(name);
        safe_free(name);
    }

    for (size_t i = 0; i < dependsLength; ++i) {
        safe_free(depends[i]);
    }
    safe_free(depends);
    dependsLength = 0;

    enable_fence = 0;
    return TCL_OK;

#undef safe_free
}

static int TracelibCloseSocketCmd(Tcl_Interp *interp UNUSED) {
    pthread_mutex_lock(&evloop_mutex);
    if (kq != -1 && selfpipe[1] != -1) {
        /* We know the pipes have been created because kq != -1 and we have the
         * lock. We don't have to check for errors, because none should occur
         * but when the pipe is full, which we wouldn't care about. */
        write(selfpipe[1], "!", 1);

        /* Wait for the kqueue event loop to terminate. We must not return
         * earlier than that because the next call will be to tracelib clean,
         * and that frees up memory that would be used by the event loop
         * otherwise. */
        pthread_cond_wait(&evloop_signal, &evloop_mutex);
    } else {
        /* The kqueue(2) loop isn't running yet, so we can just close the
         * socket and make sure it stays closed. In this situation, the kqueue
         * will not be created. */
        if (sock != -1) {
            close(sock);
            sock = -1;
        }
    }
    pthread_mutex_unlock(&evloop_mutex);

    return TCL_OK;
}

static int TracelibSetDeps(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    Tcl_Obj **objects;
    int length;
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "number of arguments should be exactly 3");
        return TCL_ERROR;
    }

    if (TCL_OK != Tcl_ListObjGetElements(interp, objv[2], &length, &objects)) {
        return TCL_ERROR;
    }

    /* When called twice, do not leak memory */
    if (depends) {
        for (size_t i = 0; i < dependsLength; ++i) {
            free(depends[i]);
        }
        free(depends);
    }
    depends = NULL;
    dependsLength = 0;

    /* Allocate memory as needed */
    if (NULL == (depends = malloc(length * sizeof(*depends)))) {
        Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
        return TCL_ERROR;
    }
    /* Copy all objects over */
    for (int i = 0; i < length; ++i) {
        if (NULL == (depends[i] = strdup(Tcl_GetString(objects[i])))) {
            /* Allocation failed, clean up what we have so far */
            for (int j = 0; j < i; ++j) {
                free(depends[j]);
            }
            free(depends);
            depends = NULL;
            dependsLength = 0;
            Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
            return TCL_ERROR;
        }

        dependsLength++;
    }

    /* Sort all dependencies so we can use binary searching */
    qsort(depends, dependsLength, sizeof(*depends),
          (int (*)(const void*, const void*)) pointer_strcmp);

    return TCL_OK;
}

static int TracelibEnableFence(Tcl_Interp *interp UNUSED) {
    enable_fence = 1;
    return TCL_OK;
}
#endif /* defined(HAVE_TRACEMODE_SUPPORT) */

int TracelibCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    int result = TCL_OK;

    /* There is no args for commands now. */
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "option");
        return TCL_ERROR;
    }

#ifdef HAVE_TRACEMODE_SUPPORT
    static const char *options[] = {"setname", "opensocket", "run", "clean", "setsandbox", "closesocket", "setdeps", "enablefence", 0};
    typedef enum {
        kSetName,
        kOpenSocket,
        kRun,
        kClean,
        kSetSandbox,
        kCloseSocket,
        kSetDeps,
        kEnableFence
    } EOptions;
    EOptions current_option;

    result = Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0, (int *)&current_option);
    if (result == TCL_OK) {
        switch (current_option) {
            case kSetName:
                result = TracelibSetNameCmd(interp, objc, objv);
                break;
            case kOpenSocket:
                result = TracelibOpenSocketCmd(interp);
                break;
            case kRun:
                result = TracelibRunCmd(interp);
                break;
            case kClean:
                result = TracelibCleanCmd(interp);
                break;
            case kCloseSocket:
                result = TracelibCloseSocketCmd(interp);
                break;
            case kSetSandbox:
                result = TracelibSetSandboxCmd(interp, objc, objv);
                break;
            case kSetDeps:
                result = TracelibSetDeps(interp, objc, objv);
                break;
            case kEnableFence:
                result = TracelibEnableFence(interp);
                break;
        }
    }
#else /* defined(HAVE_TRACEMODE_SUPPORT) */
    Tcl_SetResult(interp, "tracelib not supported on this platform", TCL_STATIC);
    result = TCL_ERROR;
#endif /* defined(HAVE_TRACEMODE_SUPPORT) */

    return result;
}

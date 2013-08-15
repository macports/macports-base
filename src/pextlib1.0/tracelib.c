/* # -*- coding: utf-8; mode: c; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=c:et:sw=4:ts=4:sts=4
 */
/*
 * tracelib.c
 * $Id$
 *
 * Copyright (c) 2007-2008 Eugene Pimenov (GSoC)
 * Copyright (c) 2008-2010, 2012-2013 The MacPorts Project
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
#include <limits.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if HAVE_SYS_EVENT_H
#include <sys/event.h>
#endif
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#include <cregistry/entry.h>
#include <registry2.0/registry.h>

#include "tracelib.h"

#include "strlcat.h"

#ifdef __APPLE__
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

static char *name;
static char *sandbox;
static char *filemap, *filemap_end;
static char *depends;
static int sock = -1;
static int kq = -1;
/* EVFILT_USER isn't available (< 10.6), use the self-pipe trick to return from
 * the blocking kqueue(2) call by writing a byte to the pipe */
static int selfpipe[2];
static int enable_fence = 0;
static Tcl_Interp *interp;
static pthread_mutex_t sock_mutex = PTHREAD_MUTEX_INITIALIZER;
static int cleanuping = 0;
static char *sdk = NULL;

static void send_file_map(int sock);
static void dep_check(int sock, char *path);
static void sandbox_violation(int sock, const char *path);
static void ui_warn(const char *format, ...);
#if 0
static void ui_info(const char *format, ...);
#endif
static void ui_error(const char *format, ...);

#define MAX_SOCKETS (1024)
#define BUFSIZE     (1024)

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
 * Sets the path of the tracelib unix socket where darwintrace should attempt
 * to connect to. This path should be specific to the port being installed.
 * Different sockets should be used for different ports (and maybe even
 * phases).
 *
 * \param[inout] interp the Tcl interpreter
 * \param[in] objc the number of parameters
 * \param[in] the parameters
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
 * \param[inout] interp the Tcl interpreter
 * \param[in] objc the number of parameters
 * \param[in] the parameters
 * \return a Tcl return code
 */
static int TracelibSetSandboxCmd(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    int len;
    char *src, *dst;
    enum { NORMAL, ESCAPE } state = NORMAL;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "number of arguments should be exactly 3");
        return TCL_ERROR;
    }

    src = Tcl_GetString(objv[2]);
    len = strlen(src) + 2;
    sandbox = malloc(len);
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
                } else {
                    /* : -> \0, unless it has been escaped */
                    *dst++ = '\0';
                }
                break;
            default:
                if (state == ESCAPE) {
                    /* unknown escape sequence, free buffer and raise an error */
                    free(sandbox);
                    Tcl_SetResult(interp, "unknown escape sequence", TCL_STATIC);
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
    uint32_t len;
    ssize_t ret;

    if ((ret = recv(sock, &len, sizeof(len), MSG_WAITALL)) != sizeof(len)) {
        if (ret < 0) {
            perror("tracelib: recv");
        } else if (ret == 0) {
            /* this usually means the socket was closed by the remote side */
        } else {
            fprintf(stderr, "tracelib: partial data received: expected %ld, but got %ld on socket %d\n", (unsigned long) sizeof(len), (unsigned long) ret, sock);
        }
        return 0;
    }

    if (len > BUFSIZE - 1) {
        fprintf(stderr, "tracelib: transfer too large: %ld bytes sent, but buffer holds %d on socket %d\n", (unsigned long) len, (int) (BUFSIZE - 1), sock);
        return 0;
    }

    if ((ret = recv(sock, buf, len, MSG_WAITALL)) != (ssize_t) len) {
        if (ret < 0) {
            perror("tracelib: recv");
        } else {
            fprintf(stderr, "tracelib: partial data received: expected %ld, but got %ld on socket %d\n", (unsigned long) len, (unsigned long) ret, sock);
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
    } else if (strcmp(buf, "sandbox_violation") == 0) {
        sandbox_violation(sock, f);
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
    if (!filemap) {
        char *t, * _;

        size_t remaining = 1024;
        filemap = (char *)malloc(remaining);
        if (!filemap) {
            ui_warn("send_file_map: memory allocation failed");
            return;
        }
        t = filemap;

#       define append_allow(path, resolution) do { strlcpy(t, path, remaining); \
            if (remaining < (strlen(t)+3)) \
                remaining=0; \
            else \
                remaining-=strlen(t)+3; \
            t+=strlen(t)+1; \
            *t++=resolution; \
            *t++=0; \
        } while(0);

        if (enable_fence) {
            for (_ = sandbox; *_; _ += strlen(_) + 1) {
                append_allow(_, 0);
            }

            append_allow("/bin", 0);
            append_allow("/sbin", 0);
            append_allow("/dev", 0);
            append_allow(Tcl_GetVar(interp, "prefix", TCL_GLOBAL_ONLY), 2);
            /* If there is no SDK we will allow everything in /usr /System/Library etc, else add binaries to allow, and redirect root to SDK. */
            if (sdk && *sdk) {
                char buf[260];
                buf[0] = '\0';
                strlcat(buf, Tcl_GetVar(interp, "developer_dir", TCL_GLOBAL_ONLY), 260);
                strlcat(buf, "/SDKs/", 260);
                strlcat(buf, sdk, 260);

                append_allow("/usr/bin", 0);
                append_allow("/usr/sbin", 0);
                append_allow("/usr/libexec/gcc", 0);
                append_allow("/System/Library/Perl", 0);
                append_allow("/", 1);
                strlcpy(t - 1, buf, remaining);
                t += strlen(t) + 1;
            } else {
                append_allow("/usr", 0);
                append_allow("/System/Library", 0);
                append_allow("/Library", 0);
                append_allow(Tcl_GetVar(interp, "developer_dir", TCL_GLOBAL_ONLY), 0);
            }
        } else {
            append_allow("/", 0);
        }
        append_allow("", 0);
        filemap_end = t;
#       undef append_allow
    }

    answer_s(sock, filemap, filemap_end - filemap);
}

/**
 * Process a sandbox violation reported by darwintrace. Calls back up to Tcl to
 * run a callback with the reported violation path.
 *
 * \param[in] sock socket reporting the violation; unused.
 * \param[in] path the offending path to be passed to the callback
 */
static void sandbox_violation(int sock UNUSED, const char *path) {
    Tcl_SetVar(interp, "path", path, 0);
    Tcl_Eval(interp, "slave_add_sandbox_violation $path");
    Tcl_UnsetVar(interp, "path", 0);
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
    char *t;
    reg_registry *reg;
    reg_entry entry;
    reg_error error;

    if (NULL == (reg = registry_for(interp, reg_attached))) {
        ui_error(Tcl_GetStringResult(interp));
        /* send unexpected output to make the build fail */
        answer(sock, "#");
    }

    /* find the port id */
    entry.reg = reg;
    entry.proc = NULL;
    entry.id = reg_entry_owner_id(reg, path);
    if (entry.id == 0) {
        /* file isn't known to MacPorts */
        answer(sock, "?");
        return;
    }

    /* find the port's name to compare with out list */
    if (!reg_entry_propget(&entry, "name", &port, &error)) {
        /* send unexpected output to make the build fail */
        ui_error(error.description);
        answer(sock, "#");
    }

    /* check our list of dependencies */
    for (t = depends; *t; t += strlen(t) + 1) {
        if (strcmp(t, port) == 0) {
            free(port);
            answer(sock, "+");
            return;
        }
    }

    free(port);
    answer(sock, "!");
}

static void ui_msg(const char *severity, const char *format, va_list va) {
    char buf[1024], tclcmd[32];

    vsnprintf(buf, sizeof(buf), format, va);

    snprintf(tclcmd, sizeof(tclcmd), "ui_%s $warn", severity);

    Tcl_SetVar(interp, "warn", buf, 0);
    if (TCL_OK != Tcl_Eval(interp, tclcmd)) {
        fprintf(stderr, "Error evaluating tcl statement `%s': %s\n", tclcmd, Tcl_GetStringResult(interp));
    }
    Tcl_UnsetVar(interp, "warn", 0);

}

static void ui_warn(const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_msg("warn", format, va);
    va_end(va);
}

#if 0
static void ui_info(const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_msg("info", format, va);
    va_end(va);
}
#endif

static void ui_error(const char *format, ...) {
    va_list va;
    va_start(va, format);
    ui_msg("error", format, va);
    va_end(va);
}

static int TracelibOpenSocketCmd(Tcl_Interp *in) {
    struct sockaddr_un sun;
    struct rlimit rl;

    cleanuping = 0;

    pthread_mutex_lock(&sock_mutex);
    if (-1 == (sock = socket(PF_LOCAL, SOCK_STREAM, 0))) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "socket: ", (char *) Tcl_PosixError(interp), NULL);
        pthread_mutex_unlock(&sock_mutex);
        return TCL_ERROR;
    }
    pthread_mutex_unlock(&sock_mutex);

    interp = in;

    /* raise the limit of open files to the maximum from the default soft limit
     * of 256 */
    if (getrlimit(RLIMIT_NOFILE, &rl) == -1) {
        ui_warn("getrlimit failed (%d), skipping setrlimit", errno);
    } else {
#if defined(__APPLE__) && defined(OPEN_MAX)
        if (rl.rlim_max > OPEN_MAX) {
            rl.rlim_max = OPEN_MAX;
        }
#endif
        rl.rlim_cur = rl.rlim_max;
        if (setrlimit(RLIMIT_NOFILE, &rl) == -1) {
            ui_warn("setrlimit failed (%d)", errno);
        }
    }

    sun.sun_family = AF_UNIX;
    strlcpy(sun.sun_path, name, sizeof(sun.sun_path));

    if (-1 == (bind(sock, (struct sockaddr *) &sun, sizeof(sun)))) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "bind: ", (char *) Tcl_PosixError(interp), NULL);
        close(sock);
        sock = -1;
        return TCL_ERROR;
    }

    if (-1 == listen(sock, 32)) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "listen: ", (char *) Tcl_PosixError(interp), NULL);
        close(sock);
        sock = -1;
        return TCL_ERROR;
    }

    return TCL_OK;
}

#if HAVE_KQUEUE
/* create this on heap rather than stack, due to its rather large size */
static struct kevent res_kevents[MAX_SOCKETS];
#endif

static int TracelibRunCmd(Tcl_Interp *in) {
#if HAVE_KQUEUE
    struct kevent kev;
    int flags;
    int oldsock;
    int opensockcount = 0;

    pthread_mutex_lock(&sock_mutex);
    if (-1 == (kq = kqueue())) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(in);
        Tcl_AppendResult(in, "kqueue: ", (char *) Tcl_PosixError(in), NULL);
        return TCL_ERROR;
    }

    if (sock != -1) {
        oldsock = sock;

        /* mark listen socket non-blocking in order to prevent a race condition
         * that would occur between kevent(2) and accept(2), if a incoming
         * connection is aborted before it is accepted. Using a non-blocking
         * accept(2) prevents the problem.*/
        flags = fcntl(oldsock, F_GETFL, 0);
        if (-1 == fcntl(oldsock, F_SETFL, flags | O_NONBLOCK)) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "fcntl(F_SETFL, += O_NONBLOCK): ", (char *) Tcl_PosixError(in), NULL);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }

        /* register the listen socket in the kqueue */
        EV_SET(&kev, oldsock, EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
        if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "kevent (listen socket): ", (char *) Tcl_PosixError(in), NULL);
            close(kq);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }
        /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
         * always be returned. When a filter is successfully added, the data field
         * will be zero. */
        if ((kev.flags & EV_ERROR) == 0 || ((kev.flags & EV_ERROR) > 0 && kev.data != 0)) {
            Tcl_SetErrno(kev.data);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "kevent (listen socket receipt): ", (char *) Tcl_PosixError(in), NULL);
            close(kq);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }


        /* use the self-pipe trick to trigger returning from kevent(2) when
         * tracelib closesocket is called. */
        if (-1 == pipe(selfpipe)) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "pipe: ", (char *) Tcl_PosixError(in), NULL);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }

        /* mark the write side of the pipe non-blocking */
        flags = fcntl(selfpipe[1], F_GETFL, 0);
        if (-1 == fcntl(selfpipe[1], F_SETFL, flags | O_NONBLOCK)) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "fcntl(F_SETFL, += O_NONBLOCK): ", (char *) Tcl_PosixError(in), NULL);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }

        /* wait for the user event on the listen socket, as sent by CloseCmd as
         * deathpill */
        EV_SET(&kev, selfpipe[0], EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
        if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "kevent (selfpipe): ", (char *) Tcl_PosixError(in), NULL);
            close(kq);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }
        /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
         * always be returned. When a filter is successfully added, the data field
         * will be zero. */
        if ((kev.flags & EV_ERROR) == 0 || ((kev.flags & EV_ERROR) > 0 && kev.data != 0)) {
            Tcl_SetErrno(kev.data);
            Tcl_ResetResult(in);
            Tcl_AppendResult(in, "kevent (selfpipe receipt): ", (char *) Tcl_PosixError(in), NULL);
            close(kq);
            pthread_mutex_unlock(&sock_mutex);
            return TCL_ERROR;
        }
    }
    pthread_mutex_unlock(&sock_mutex);

    while (sock != -1 && !cleanuping) {
        int keventstatus;
        int i;

        /* run kevent(2) until new activity is available */
        do {
            if (-1 == (keventstatus = kevent(kq, NULL, 0, res_kevents, MAX_SOCKETS, NULL))) {
                Tcl_SetErrno(errno);
                Tcl_ResetResult(in);
                Tcl_AppendResult(in, "kevent (main loop): ", (char *) Tcl_PosixError(in), NULL);
                close(kq);
                return TCL_ERROR;
            }
        } while (keventstatus == 0);

        for (i = 0; i < keventstatus; ++i) {
            /* handle traffic on the selfpipe */
            if ((int) res_kevents[i].ident == selfpipe[0]) {
                pthread_mutex_lock(&sock_mutex);
                close(selfpipe[0]);
                close(selfpipe[1]);
                selfpipe[0] = -1;
                selfpipe[1] = -1;
                pthread_mutex_unlock(&sock_mutex);
                break;
            }

            /* the control socket has activity – we might have a new
             * connection. We use a copy of sock here, because sock might have
             * been set to -1 by the close command */
            if ((int) res_kevents[i].ident == oldsock) {
                int s;

                /* handle error conditions */
                if ((res_kevents[i].flags & (EV_ERROR | EV_EOF)) > 0) {
                    if (cleanuping) {
                        break;
                    }
                    Tcl_ResetResult(in);
                    Tcl_SetResult(in, "control socket closed", NULL);
                    close(kq);
                    return TCL_ERROR;
                }

                /* else: new connection attempt(s) */
                for (;;) {
                    if (-1 == (s = accept(sock, NULL, NULL))) {
                        if (cleanuping) {
                            break;
                        }
                        if (errno == EWOULDBLOCK) {
                            break;
                        }
                        Tcl_SetErrno(errno);
                        Tcl_ResetResult(in);
                        Tcl_AppendResult(in, "accept: ", (char *) Tcl_PosixError(in), NULL);
                        close(kq);
                        return TCL_ERROR;
                    }

                    flags = fcntl(s, F_GETFL, 0);
                    if (-1 == fcntl(s, F_SETFL, flags & ~O_NONBLOCK)) {
                        ui_warn("tracelib: couldn't mark socket as blocking");
                        close(s);
                        continue;
                    }

                    /* register the new socket in the kqueue */
                    EV_SET(&kev, s, EVFILT_READ, EV_ADD | EV_RECEIPT, 0, 0, NULL);
                    if (1 != kevent(kq, &kev, 1, &kev, 1, NULL)) {
                        ui_warn("tracelib: error adding socket to kqueue");
                        close(s);
                        continue;
                    }
                    /* kevent(2) on EV_RECEIPT: When passed as input, it forces EV_ERROR to
                     * always be returned. When a filter is successfully added, the data field
                     * will be zero. */
                    if ((kev.flags & EV_ERROR) == 0 || ((kev.flags & EV_ERROR) > 0 && kev.data != 0)) {
                        ui_warn("tracelib: error adding socket to kqueue");
                        close(s);
                        continue;
                    }

                    opensockcount++;
                }

                if (cleanuping) {
                    break;
                }
            } else {
                /* if the socket is to be closed, or */
                if ((res_kevents[i].flags & (EV_EOF | EV_ERROR)) > 0
                    /* new data is available, and its processing tells us to
                     * close the socket */
                    || (!process_line(res_kevents[i].ident))) {
                    /* an error occured or process_line suggested closing this
                     * socket */
                    close(res_kevents[i].ident);
                    /* closing the socket will automatically remove it from the
                     * kqueue :) */
                    opensockcount--;
                }
            }
        }
    }

    /* NOTE: We aren't necessarily closing all client sockets here! */
    if (opensockcount > 0) {
        fprintf(stderr, "tracelib: %d open sockets will leak at end of runcmd\n", opensockcount);
    }
    pthread_mutex_lock(&sock_mutex);
    close(kq);
    kq = -1;
    pthread_mutex_unlock(&sock_mutex);

    return TCL_OK;
#else
    Tcl_SetResult(in, "tracelib not supported on this platform", TCL_STATIC);
    return TCL_ERROR;
#endif
}

static int TracelibCleanCmd(Tcl_Interp *interp UNUSED) {
#define safe_free(x) do{free(x); x=0;}while(0);
    cleanuping = 1;
    pthread_mutex_lock(&sock_mutex);
    if (sock != -1) {
        /* shutdown(sock, SHUT_RDWR);*/
        close(sock);
        sock = -1;
    }
    pthread_mutex_unlock(&sock_mutex);
    if (name) {
        unlink(name);
        safe_free(name);
    }
    if (filemap) {
        safe_free(filemap);
    }
    if (depends) {
        safe_free(depends);
    }
    enable_fence = 0;
#undef safe_free
    return TCL_OK;
}

static int TracelibCloseSocketCmd(Tcl_Interp *interp UNUSED) {
    cleanuping = 1;
    pthread_mutex_lock(&sock_mutex);
    if (sock != -1) {
        int oldsock = sock;
        /*shutdown(sock, SHUT_RDWR);*/
        close(oldsock);
        sock = -1;

        if (kq != -1) {
            /* We know the pipes have been created because kq != -1 and we have
             * the lock. We don't have to check for errors, because none should
             * occur but when the pipe is full, which we wouldn't care about.
             * */
            write(selfpipe[1], "!", 1);
        }
    }
    pthread_mutex_unlock(&sock_mutex);
    return TCL_OK;
}

static int TracelibSetDeps(Tcl_Interp *interp UNUSED, int objc, Tcl_Obj *CONST objv[]) {
    char *t, * d;
    size_t l;
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "number of arguments should be exactly 3");
        return TCL_ERROR;
    }

    d = Tcl_GetString(objv[2]);
    l = strlen(d);
    depends = malloc(l + 2);
    if (!depends) {
        Tcl_SetResult(interp, "memory allocation failed", TCL_STATIC);
        return TCL_ERROR;
    }
    depends[l + 1] = 0;
    strlcpy(depends, d, l + 2);
    for (t = depends; *t; ++t)
        if (*t == ' ') {
            *t++ = 0;
        }

    return TCL_OK;
}

static int TracelibEnableFence(Tcl_Interp *interp UNUSED) {
    enable_fence = 1;
    if (filemap) {
        free(filemap);
    }
    filemap = 0;
    return TCL_OK;
}
#endif /* __APPLE__ */

int TracelibCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    int result = TCL_OK;
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

    /* There is no args for commands now. */
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "option");
        return TCL_ERROR;
    }

#ifdef __APPLE__
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
#else /* __APPLE__ */
    Tcl_SetResult(interp, "tracelib not supported on this platform", TCL_STATIC);
    result = TCL_ERROR;
#endif /* __APPLE__ */

    return result;
}

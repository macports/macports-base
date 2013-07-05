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

#include <string.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/select.h>
#include <sys/un.h>
#include <stdarg.h>
#include <errno.h>
#include <pthread.h>
#include <limits.h>
#include "tracelib.h"

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
static int enable_fence = 0;
static Tcl_Interp *interp;
static pthread_mutex_t sock_mutex = PTHREAD_MUTEX_INITIALIZER;
static int cleanuping = 0;
static char *sdk = NULL;

static void send_file_map(int sock);
static void dep_check(int sock, const char *path);
static void sandbox_violation(int sock, const char *path);
static void ui_warn(const char *format, ...);
static void ui_info(const char *format, ...);
static void ui_error(const char *format, ...);

#define MAX_SOCKETS ((FD_SETSIZE)-1)

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

/*
 * Save sandbox path into memory and prepare it for checks.
 * For now it just change : to \0, and add last \0
 * Input:
 *  /dev/null:/dev/tty:/tmp
 * In variable;
 *  /dev/null\0/dev/tty\0/tmp\0\0
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

/*
 * Is there more data? (return 1 if more data in socket, 0 otherwise)
 */
static char can_I_recv_more(int sock) {
    struct timeval tv;
    fd_set fdr;
    tv.tv_sec  = 0;
    tv.tv_usec = 0;

    FD_ZERO(&fdr);
    FD_SET(sock, &fdr);
    return select(sock + 1, &fdr, 0, 0, &tv) == 1;
}

/*
 * receive line from socket, parse it and send answer
 */
static char process_line(int sock) {
    char *t, buf[1024] = {0}, *f, *next_t;
    int len;

    if ((len = recv(sock, buf, sizeof(buf) - 1, 0)) == -1) {
        return 0;
    }
    if (!len) {
        return 0;
    }

    buf[len] = '\0';

    for (t = buf; *t && t - buf < (int)sizeof(buf); t = next_t) {
        next_t = t + strlen(t) + 1;
        if (next_t == buf + sizeof(buf) && len == sizeof(buf) - 1) {
            memmove(buf, t, next_t - t);
            t = buf;
            {
                char *end_of_t = t + strlen(t);
                *end_of_t = ' ';
                for (; can_I_recv_more(sock);) {
                    if (recv(sock, end_of_t, 1, 0) != 1) {
                        ui_warn("recv failed");
                        return 0;
                    }
                    if (*end_of_t++ == '\0') {
                        break;
                    }
                }
            }
        }

        f = strchr(t, '\t');
        if (!f) {
            ui_warn("malformed command %s", t);
            break;
        }

        /* Replace \t with \0 */
        *f = '\0';
        /* Advance pointer to arguments */
        f++;

        if (!strcmp(t, "filemap")) {
            send_file_map(sock);
        } else if (!strcmp(t, "sandbox_violation")) {
            sandbox_violation(sock, f);
        } else if (!strcmp(t, "dep_check")) {
            dep_check(sock, f);
        } else if (!strcmp(t, "execve")) {
            /* ====================== */
            /* = TODO: do something = */
            /* ====================== */
        } else {
            ui_warn("unknown command %s (%s)", t, f);
        }
    }
    return 1;
}

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

    {
        size_t s = filemap_end - filemap;
        send(sock, &s, sizeof(s), 0);
        send(sock, filemap, s, 0);
    }
}

static void sandbox_violation(int sock UNUSED, const char *path) {
    Tcl_SetVar(interp, "path", path, 0);
    Tcl_Eval(interp, "slave_add_sandbox_violation $path");
    Tcl_UnsetVar(interp, "path", 0);
}

static void dep_check(int sock, const char *path) {
    char *port = 0;
    size_t len = 1;
    char resolution = '!';
    int tcl_retval;

    Tcl_SetVar(interp, "path", path, 0);
    /* FIXME: Use C registry API */
    tcl_retval = Tcl_Eval(interp, "registry::file_registered $path");
    port = strdup(Tcl_GetStringResult(interp));
    if (!port) {
        ui_warn("dep_check: memory allocation failed");
        return;
    }
    if (tcl_retval != TCL_OK) {
        ui_error("failed to run registry::file_registered \"%s\": %s", path, port);
    }
    Tcl_UnsetVar(interp, "path", 0);

    if (tcl_retval == TCL_OK && (*port != '0' || port[1])) {
        char *t;

        t = depends;
        for (; *t; t += strlen(t) + 1) {
            /* fprintf(stderr, "trace: %s =?= %s\n", t, port); */
            if (!strcmp(t, port)) {
                resolution = '+';
                break;
            }
        }
    }

    if (resolution != '+') {
        if (*port == '0' && !port[1]) {
            ui_info("trace: access denied to %s (*unknown*)", path);
        } else {
            ui_info("trace: access denied to %s (%s)", path, port);
        }
    }

    free(port);

    if (send(sock, &len, sizeof(len), 0) == -1) {
        ui_warn("tracelib send failed");
    }
    if (send(sock, &resolution, 1, 0) == -1) {
        ui_warn("tracelib send failed");
    }
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

static void ui_info(const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_msg("info", format, va);
    va_end(va);
}

static void ui_error(const char *format, ...) {
    va_list va;
    va_start(va, format);
    ui_msg("error", format, va);
    va_end(va);
}

static int TracelibOpenSocketCmd(Tcl_Interp *in) {
    struct sockaddr_un sun;
    struct rlimit rl;

    pthread_mutex_lock(&sock_mutex);
    if (cleanuping) {
        pthread_mutex_unlock(&sock_mutex);
        return 0;
    }
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
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
    if (bind(sock, (struct sockaddr *)&sun, sizeof(sun)) == -1) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "bind: ", (char *) Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }

    if (listen(sock, 5) == -1) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "listen: ", (char *) Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }

    return TCL_OK;
}


static int TracelibRunCmd(Tcl_Interp *in UNUSED) {
    int max_fd, max_used, socks[MAX_SOCKETS];
    fd_set fdr;
    int i;

    max_used = 0;
    max_fd = sock;

    for (; sock != -1 && !cleanuping;) {
        FD_ZERO(&fdr);
        FD_SET(sock, &fdr);
        for (i = 0; i < max_used; ++i) {
            FD_SET(socks[i], &fdr);
        }

        if (select(max_fd + 1, &fdr, 0, 0, 0) < 1) {
            continue;
        }
        if (sock == -1) {
            break;
        }
        if (FD_ISSET(sock, &fdr)) {
            int s;
            s = accept(sock, 0, 0);

            if (s == -1) {
                if (cleanuping) {
                    break;
                } else {
                    ui_warn("tracelib: accept return -1 (errno: %d)", errno);
                }
                /* failed sometimes and i dunno why*/
                continue;
            }
            /* Temporary solution, it's better to regenerate this variable in each iteration, because when closing socket we'll get it too high */
            if (s > max_fd) {
                max_fd = s;
            }
            for (i = 0; i < max_used; ++i)
                if (!socks[i]) {
                    socks[i] = s;
                    break;
                }
            if (i == max_used) {
                if (max_used == MAX_SOCKETS - 1) {
                    ui_warn("There is no place to store socket");
                    close(s);
                } else {
                    socks[max_used++] = s;
                }
            }
        }

        for (i = 0; i < max_used; ++i) {
            if (!socks[i]) {
                continue;
            }
            if (FD_ISSET(socks[i], &fdr)) {
                if (!process_line(socks[i])) {
                    close(socks[i]);
                    socks[i] = 0;
                    continue;
                }
            }
        }
    }

    for (i = 0; i < max_used; ++i) {
        if (socks[i]) {
            close(socks[i]);
            socks[i] = 0;
        }
    }

    return TCL_OK;
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
    cleanuping = 0;
    return TCL_OK;
}

static int TracelibCloseSocketCmd(Tcl_Interp *interp UNUSED) {
    cleanuping = 1;
    pthread_mutex_lock(&sock_mutex);
    if (sock != -1) {
        /*shutdown(sock, SHUT_RDWR);*/
        close(sock);
        sock = -1;
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

    return result;
}

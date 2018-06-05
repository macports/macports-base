/*
 * adv-flock.c
 *
 * Copyright (c) 2009, 2014-2018 The MacPorts Project
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
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
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

#ifndef __APPLE__
/* needed to get struct sigaction on some platforms, but
  hides flock on macOS */
#define _XOPEN_SOURCE 500L
#endif

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#include <errno.h>
#include <inttypes.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

#include <tcl.h>

#include "adv-flock.h"

static volatile int alarmReceived = 0;

static void alarmHandler(int sig UNUSED) {
    alarmReceived = 1;
}

int
AdvFlockCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    static const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\", and optionally \"-noblock\"";
    int operation = 0, fd, i, ret, sigret = TCL_OK;
    int errnoval = 0;
    int oshared = 0, oexclusive = 0, ounlock = 0, onoblock = 0, retry = 0;
#if !defined(HAVE_FLOCK)
    off_t curpos;
#endif
    char *res;
    Tcl_Channel channel;
    ClientData handle;
    struct sigaction sa_oldalarm, sa_alarm;

    if (objc < 3 || objc > 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "channelId switches");
        return TCL_ERROR;
    }

    if ((channel = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), NULL)) == NULL) {
        Tcl_SetResult(interp, "error getting channel, result was NULL", TCL_STATIC);
        return TCL_ERROR;
    }

    if (Tcl_GetChannelHandle(channel, TCL_READABLE | TCL_WRITABLE, &handle) != TCL_OK) {
        Tcl_SetResult(interp, "error getting channel handle", TCL_STATIC);
        return TCL_ERROR;
    }
    fd = (int)(intptr_t)handle;

    for (i = 2; i < objc; i++) {
        char *arg = Tcl_GetString(objv[i]);
        if (!strcmp(arg, "-shared")) {
            oshared = 1;
        }
        else if (!strcmp(arg, "-exclusive")) {
            oexclusive = 1;
        }
        else if (!strcmp(arg, "-unlock")) {
            ounlock = 1;
        }
        else if (!strcmp(arg, "-noblock")) {
            onoblock = 1;
        }
    }

    /* verify the arguments */

    if ((oshared + oexclusive + ounlock) != 1) {
        /* only one of the options should have been specified */
        Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
        return TCL_ERROR;
    }

    if (onoblock && ounlock) {
        /* should not be specified together */
        Tcl_SetResult(interp, "-noblock cannot be used with -unlock", TCL_STATIC);
        return TCL_ERROR;
    }

    /* (re-)enable SIGALRM so we can use alarm(3) to specify a timeout for the
     * locking, do some Tcl signal processing and restart the locking to solve
     * #43388. */
    memset(&sa_alarm, 0, sizeof(struct sigaction));
    sigemptyset(&sa_alarm.sa_mask);
    sa_alarm.sa_flags = 0; /* explicitly don't specify SA_RESTART, we want the
                              following alarm(3) to interrupt the locking. */
    sa_alarm.sa_handler = alarmHandler;
    sigaction(SIGALRM, &sa_alarm, &sa_oldalarm);

    do {
        /* use a delay of one second */
        retry = 0;
        alarmReceived = 0;
        alarm(1);
#if HAVE_FLOCK
        /* prefer flock if present */
        if (oshared) {
            operation |= LOCK_SH;
        }

        if (oexclusive) {
            operation |= LOCK_EX;
        }

        if (ounlock) {
            operation |= LOCK_UN;
        }

        if (onoblock) {
            operation |= LOCK_NB;
        }

        ret = flock(fd, operation);
        if (ret == -1) {
            errnoval = errno;
        }
#else
        if (ounlock) {
            operation = F_ULOCK;
        }

        /* lockf semantics don't map to shared locks. */
        if (oshared || oexclusive) {
            if (onoblock) {
                operation = F_TLOCK;
            }
            else {
                operation = F_LOCK;
            }
        }

        curpos = lseek(fd, 0, SEEK_CUR);
        if (curpos == -1) {
            Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
            return TCL_ERROR;
        }

        ret = lockf(fd, operation, 0); /* lock entire file */
        if (ret == -1) {
            errnoval = errno;
        }

        curpos = lseek(fd, curpos, SEEK_SET);
        if (curpos == -1) {
            Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
            return TCL_ERROR;
        }
#endif /* HAVE_FLOCK */
        /* disable the alarm timer */
        alarm(0);

        if (ret == -1) {
            if (oshared || oexclusive) {
                if (!onoblock && alarmReceived && errnoval == EINTR) {
                    /* We were trying to lock, the lock was supposed to block,
                     * it failed with EINTR and we processed a SIGALRM. This
                     * probably means the call was interrupted by the timer.
                     * Call Tcl signal processing functions and try again. */
                    if (Tcl_AsyncReady()) {
                        sigret = Tcl_AsyncInvoke(interp, TCL_OK);
                        if (sigret != TCL_OK) {
                            break;
                        }
                    }
                    retry = 1;
                    continue;
                }

                if (onoblock && errnoval == EAGAIN) {
                    /* The lock wasn't supposed to block, and the lock wasn't
                     * successful because the lock is taken. On some systems
                     * EAGAIN == EWOULDBLOCK, but let's play it safe. */
                    errnoval = EWOULDBLOCK;
                }
            }
        }
    } while (retry);

    /* Restore the previous handler for SIGALRM */
    sigaction(SIGALRM, &sa_oldalarm, NULL);

    if (sigret != TCL_OK) {
        /* We received a signal that raised an error. The file hasn't been
         * locked. */
        return sigret;
    }

    if (ret != 0) {
        switch (errnoval) {
            case EAGAIN:
                res = "EAGAIN";
                break;
            case EBADF:
                res = "EBADF";
                break;
            case EINVAL:
                res = "EINVAL";
                break;
            case EOPNOTSUPP:
                res = "EOPNOTSUPP";
                break;
            default:
                res = strerror(errno);
                break;
        }
        Tcl_SetResult(interp, (void *) res, TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

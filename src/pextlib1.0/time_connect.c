/*
 * Copyright (c) 2026 The MacPorts Project
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
 * 3. Neither the name of the copyright owner nor the names of contributors
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

/* required for getaddrinfo(3) on Linux */
#define _XOPEN_SOURCE 600L

#include "time_connect.h"

#include <fcntl.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>

int
TimeConnectCmd(
		ClientData clientData UNUSED,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* const objv[])
{
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "host service");
        return TCL_ERROR;
    }
    const char *host = Tcl_GetString(objv[1]);
    const char *serv = Tcl_GetString(objv[2]);
    int status = TCL_OK;

    /* Look up the host */
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *res = NULL;
    if (getaddrinfo(host, serv, &hints, &res) != 0) {
        status = TCL_ERROR;
    }

    /* Create socket */
    int sock = -1;
    if (status == TCL_OK && (sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0) {
        status = TCL_ERROR;
    }

    struct timeval tv;
    fd_set fdset;
    Tcl_Time start, finish;
    if (status == TCL_OK) {
        /* set as non-blocking so we can use a custom timeout */
        fcntl(sock, F_SETFL, O_NONBLOCK);
        /* set up timeout */
        tv.tv_sec = 3;
        tv.tv_usec = 0;
        /* prepare for select() use */
        FD_ZERO(&fdset);
        FD_SET(sock, &fdset);
        /* record start time */
        Tcl_GetTime(&start);
        if (connect(sock, res->ai_addr, res->ai_addrlen) < 0 && (errno != EINPROGRESS)) {
            status = TCL_ERROR;
        }
    }

    if (status == TCL_OK) {
        int select_result;
        /* run select, retrying if it is interrupted due to signal etc */
        do {
            select_result = select(sock + 1, NULL, &fdset, NULL, &tv);
        } while (select_result == -1 && (errno == EAGAIN || errno == EINTR));
        if (select_result > 0) {
            /* socket is connected, record finishing time */
            Tcl_GetTime(&finish);
            /* check if there is a socket error */
            int so_error;
            socklen_t len = sizeof(so_error);
            getsockopt(sock, SOL_SOCKET, SO_ERROR, &so_error, &len);
            if (so_error == 0) {
                /* All OK, we can calculate the result.
                 * Convert seconds and microseconds to a single value in milliseconds. */
                double delta = ((finish.sec - start.sec) * 1000.0) + ((finish.usec - start.usec) / 1000.0);
                Tcl_Obj *deltaObj = Tcl_NewDoubleObj(delta);
                Tcl_SetObjResult(interp, deltaObj);
            } else {
                /* socket error */
                status = TCL_ERROR;
            }
        } else if (select_result == 0) {
            /* timed out */
            status = TCL_ERROR;
        } else {
            /* select failed */
            status = TCL_ERROR;
        }
    }

    if (sock >= 0) {
        close(sock);
    }
    if (res) {
        freeaddrinfo(res);
    }
    return status;
}

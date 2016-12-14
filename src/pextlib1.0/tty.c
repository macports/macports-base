/*
 * tty.c
 * Tcl wrappers for tty control functions
 *
 * Author: Rainer Mueller <raimue@macports.org>
 *
 * Copyright (c) 2009 The MacPorts Project
 * Copyright (c) 2008 Rainer Mueller <raimue@macports.org>
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
 * 3. Neither the name of The MacPorts Project nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
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

#include <stdint.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <tcl.h>

#include "tty.h"

int
IsattyCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *tcl_result;
    Tcl_Channel chan;
    int dir;
    ClientData fd;
    int rval;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "channel");
        return TCL_ERROR;
    }

    chan = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), &dir);
    if (chan == NULL) {
        Tcl_SetResult(interp, "no such channel", TCL_STATIC);
        return TCL_ERROR;
    }

    if (Tcl_GetChannelHandle(chan,
            dir & TCL_READABLE ? TCL_READABLE : TCL_WRITABLE,
            &fd) == TCL_ERROR) {
        return TCL_ERROR;
    }

    rval = isatty((int)(intptr_t)fd);

    tcl_result = Tcl_NewIntObj(rval);
    Tcl_SetObjResult(interp, tcl_result);

    return TCL_OK;
}

int
TermGetSizeCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *tcl_result;
    Tcl_Channel chan;
    int dir;
    ClientData fd;
    Tcl_Obj *robjv[2];
    struct winsize ws = {0, 0, 0, 0};

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "channel");
        return TCL_ERROR;
    }

    chan = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), &dir);
    if (chan == NULL) {
        Tcl_SetResult(interp, "no such channel", TCL_STATIC);
        return TCL_ERROR;
    }

    if (Tcl_GetChannelHandle(chan,
            dir & TCL_READABLE ? TCL_READABLE : TCL_WRITABLE,
            &fd) == TCL_ERROR) {
        return TCL_ERROR;
    }

    if (!isatty((int)(intptr_t)fd)) {
        Tcl_SetResult(interp, "channel is not connected to a tty", TCL_STATIC);
        return TCL_ERROR;
    }

    if (ioctl((int)(intptr_t)fd, TIOCGWINSZ, &ws) == -1) {
        Tcl_SetResult(interp, "ioctl failed", TCL_STATIC);
        return TCL_ERROR;
    }

    robjv[0] = Tcl_NewIntObj(ws.ws_row);
    robjv[1] = Tcl_NewIntObj(ws.ws_col);

    tcl_result = Tcl_NewListObj(2, robjv);
    Tcl_SetObjResult(interp, tcl_result);

    return TCL_OK;
}

/*
 * realpath.c
 *
 * Copyright (c) 2009 The MacPorts Project.
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
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

/* required for PATH_MAX and realpath(3) */
#define _XOPEN_SOURCE 500
#define _DARWIN_C_SOURCE

#include <tcl.h>

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "realpath.h"

/**
 * realpath command entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int RealpathCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    const char error_message[] = "realpath failed: ";
    Tcl_Obj *tcl_result;
    char *path;
    char *rpath = malloc(PATH_MAX+1);
    char *res;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "path");
        free(rpath);
        return TCL_ERROR;
    }

    path = Tcl_GetString(objv[1]);
    res = realpath(path, rpath);
    if (!res) {
        free(rpath);
        tcl_result = Tcl_NewStringObj(error_message, sizeof(error_message) - 1);
        Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(strerror(errno), -1));
        Tcl_SetObjResult(interp, tcl_result);
        return TCL_ERROR;
    } else {
        tcl_result = Tcl_NewStringObj(rpath, -1);
        free(rpath);
    }

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

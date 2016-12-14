/*
 * sysctl.c
 *
 * Copyright (c) 2009 The MacPorts Project
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

#include <tcl.h>

#include <string.h>
#include <errno.h>
#include <sys/types.h>

#if HAVE_SYS_SYSCTL_H
#include <sys/sysctl.h>
#endif

#include "sysctl.h"

/*
 * Read-only wrapper for sysctlbyname(3). Only works for values of type CTLTYPE_INT and CTLTYPE_QUAD.
 */
#ifdef HAVE_SYSCTLBYNAME
int SysctlCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
#else
int SysctlCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
#endif
{
#ifdef HAVE_SYSCTLBYNAME
    const char error_message[] = "sysctl failed: ";
    Tcl_Obj *tcl_result;
    int res;
    char *name;
    int value;
    Tcl_WideInt long_value;
    size_t len = sizeof(value);

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "name");
        return TCL_ERROR;
    }

    name = Tcl_GetString(objv[1]);
    res = sysctlbyname(name, &value, &len, NULL, 0);
    if (res == -1 && errno != ENOMEM && errno != ERANGE) {
        tcl_result = Tcl_NewStringObj(error_message, sizeof(error_message) - 1);
        Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(strerror(errno), -1));
        Tcl_SetObjResult(interp, tcl_result);
        return TCL_ERROR;
    } else if (res == -1) {
        len = sizeof(long_value);
        res = sysctlbyname(name, &long_value, &len, NULL, 0);
        if (res == -1) {
            tcl_result = Tcl_NewStringObj(error_message, sizeof(error_message) - 1);
            Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(strerror(errno), -1));
            Tcl_SetObjResult(interp, tcl_result);
            return TCL_ERROR;
        }
        tcl_result = Tcl_NewWideIntObj(long_value);
    } else {
        tcl_result = Tcl_NewIntObj(value);
    }
    
    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
#else
    Tcl_SetObjResult(interp, Tcl_NewStringObj("sysctl not available", -1));
    return TCL_ERROR;
#endif
}

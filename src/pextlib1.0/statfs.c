/*
 * statfs.c
 *
 * Copyright (c) 2017 The MacPorts Project.
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

#include <tcl.h>

#include <sys/errno.h>
#include <string.h>
#include <sys/param.h>
#include <sys/mount.h>

#include "statfs.h"

/* Function to actually call and check statfs return. */
#if defined(__APPLE__)   || \
    defined(__OpenBSD__) || \
    defined(__FreeBSD__) || \
    defined(__NetBSD__)
static
int
_statfs(Tcl_Interp *interp,
        int objc,
        Tcl_Obj *CONST objv[],
        struct statfs *s,
        Tcl_Obj *tcl_result)
{
    const char error_message[] = "statfs call failed: ";
    char *path;
    int res;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "path");
        return TCL_ERROR;
    }

    path = Tcl_GetString(objv[1]);
    res = statfs(path, s);

    if (res) {
        tcl_result = Tcl_NewStringObj(error_message,
                                      sizeof(error_message) - 1);
        Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(strerror(errno), -1));
        Tcl_SetObjResult(interp, tcl_result);
        return TCL_ERROR;
    } else {
        return TCL_OK;
    }
}

/* X-Macro defining accessors for string members. */
#define X(_MEMB_, UNUSED) \
int _MEMB_##Cmd(ClientData clientData, \
                Tcl_Interp *interp, \
                int objc, \
                Tcl_Obj *CONST objv[]) \
{ \
    struct statfs s; \
    Tcl_Obj *tcl_result = 0; \
    if (_statfs(interp, objc, objv, &s, tcl_result) == TCL_ERROR) { \
      return TCL_ERROR; \
    } else { \
      tcl_result = Tcl_NewStringObj(s._MEMB_, -1); \
      Tcl_SetObjResult(interp, tcl_result); \
      return TCL_OK; \
    } \
}
STATFS_STRINGS
#undef X

/* X-Macro defining accessors for int flavors (all cast to long.) */
#define X(_MEMB_, UNUSED) \
int _MEMB_##Cmd(ClientData clientData, \
                Tcl_Interp *interp, \
                int objc, \
                Tcl_Obj *CONST objv[]) \
{ \
    struct statfs s; \
    Tcl_Obj *tcl_result = 0; \
    if (_statfs(interp, objc, objv, &s, tcl_result) == TCL_ERROR) { \
      return TCL_ERROR; \
    } else { \
      tcl_result = Tcl_NewLongObj((long) s._MEMB_); \
      Tcl_SetObjResult(interp, tcl_result); \
      return TCL_OK; \
    } \
}
STATFS_LONGS
#undef X

#else

/* Return errors on other OSes. */
#define X(_MEMB_, UNUSED) \
int _MEMB_##Cmd(ClientData clientData, \
                Tcl_Interp *interp, \
                int objc, \
                Tcl_Obj *CONST objv[]) \
{ \
  tcl_result = Tcl_NewStringObj("Unsupported statfs[" #_MEMB_ "]", -1); \
  Tcl_SetObjResult(interp, tcl_result); \
  return TCL_ERROR; \ \
}
STATFS_ALL
#undef X

#endif


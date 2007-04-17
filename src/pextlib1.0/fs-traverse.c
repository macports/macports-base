/*
 * fs-traverse.c
 * $Id$
 *
 * Find files and execute arbitrary expressions on them.
 * Author: Jordan K. Hubbard, Kevin Ballard
 *
 * Copyright (c) 2004 Apple Computer, Inc.
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#include <tcl.h>

static int do_traverse(Tcl_Interp *interp, int flags, char *target, char *varname, char *body);

#define F_DEPTH 0x1
#define F_IGNORE_ERRORS 0x2

/* fs-traverse ?-depth? ?-ignoreErrors? varname target ?target ...? body */
int
FsTraverseCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *varname;
    char *body;
    int flags = 0;
    int rval = TCL_OK;
    Tcl_Obj *CONST *objv_orig = objv;

    /* Adjust arguments to remove initial `find' */
    ++objv, --objc;

    /* Parse flags */
    while (objc) {
        if (!strcmp(Tcl_GetString(*objv), "-depth")) {
            flags |= F_DEPTH;
            ++objv, --objc;
            continue;
        }
        if (!strcmp(Tcl_GetString(*objv), "-ignoreErrors")) {
            flags |= F_IGNORE_ERRORS;
            ++objv, --objc;
            continue;
        }
        break;
    }
    
    /* Parse remaining args */
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv_orig, "?-depth? ?-ignoreErrors? varname target ?target target ...? body");
        return TCL_ERROR;
    }
    
    varname = Tcl_GetString(*objv);
    ++objv, --objc;
    
    body = Tcl_GetString(objv[objc-1]);
    --objc;
    
    while (objc) {
        char *target = Tcl_GetString(*objv);
        ++objv, --objc;
        
        if ((rval = do_traverse(interp, flags, target, varname, body)) == TCL_CONTINUE) {
            rval = TCL_OK;
            continue;
        } else if (rval == TCL_BREAK) {
            rval = TCL_OK;
            break;
        } else if (rval != TCL_OK) {
            break;
        }
    }
    return rval;
}

static int
do_traverse(Tcl_Interp *interp, int flags, char *target, char *varname, char *body)
{
    DIR *dirp;
    struct dirent *dp;
    int rval = TCL_OK;
    struct stat sb;
    
    /* No permission? */
    if (lstat(target, &sb) != 0) {
        if (flags & F_IGNORE_ERRORS) {
            return TCL_OK;
        } else {
            Tcl_ResetResult(interp);
            Tcl_AppendResult(interp, "Error: no permission to access file/folder `", target, "'");
            return TCL_ERROR;
        }
    }
    
    /* Handle files now, or directories if !depth */
    if (!(flags & F_DEPTH) || !(sb.st_mode & S_IFDIR)) {
        Tcl_SetVar(interp, varname, target, 0);
        if ((rval = Tcl_EvalEx(interp, body, -1, 0)) != TCL_OK) {
            return rval;
        }
    }
    
    /* Handle directories */
    if (sb.st_mode & S_IFDIR) {
        if ((dirp = opendir(target)) == NULL) {
            if (flags & F_IGNORE_ERRORS) {
                return TCL_OK;
            } else {
                Tcl_ResetResult(interp);
                Tcl_AppendResult(interp, "Error: Could not open directory `", target, "'");
                return TCL_ERROR;
            }
        }
        
        while ((dp = readdir(dirp)) != NULL) {
            char tmp_path[PATH_MAX];

            if (!strcmp(dp->d_name, ".") || !strcmp(dp->d_name, ".."))
                continue;
            strcpy(tmp_path, target);
            strcat(tmp_path, "/");
            strcat(tmp_path, dp->d_name);

            if ((rval = do_traverse(interp, flags, tmp_path, varname, body)) == TCL_CONTINUE) {
                rval = TCL_OK;
                continue;
            } else if (rval != TCL_OK) {
                break;
            }
        }
        (void)closedir(dirp);
        
        /* Handle directory now if depth */
        if (flags & F_DEPTH) {
            Tcl_SetVar(interp, varname, target, 0);
            if ((rval = Tcl_EvalEx(interp, body, -1, 0)) != TCL_OK) {
                return rval;
            }
        }
    }
    return rval;
}

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

#include <fts.h>
#include <errno.h>

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#include <tcl.h>

static int do_traverse(Tcl_Interp *interp, int flags, char * CONST *targets, char *varname, Tcl_Obj *body);

#define F_DEPTH 0x1
#define F_IGNORE_ERRORS 0x2

/* fs-traverse ?-depth? ?-ignoreErrors? varname target-list body */
int
FsTraverseCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *varname;
    Tcl_Obj *body;
    int flags = 0;
    int rval = TCL_OK;
    Tcl_Obj *listPtr;
    Tcl_Obj *CONST *objv_orig = objv;
    int lobjc;
    Tcl_Obj **lobjv;

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
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv_orig, "?-depth? ?-ignoreErrors? varname target-list body");
        return TCL_ERROR;
    }
    
    varname = Tcl_GetString(*objv);
    ++objv, --objc;
    
    listPtr = *objv;
    ++objv, --objc;
    
    body = *objv;
    
    if ((rval = Tcl_ListObjGetElements(interp, listPtr, &lobjc, &lobjv)) == TCL_OK) {
        char **entries = calloc(objc, sizeof(char *));
        char **iter = (char **)entries;
        while (lobjc) {
            *iter++ = Tcl_GetString(*lobjv);
            --lobjc, ++lobjv;
        }
        rval = do_traverse(interp, flags, entries, varname, body);
        free(entries);
    }
    return rval;
}

static int
do_traverse(Tcl_Interp *interp, int flags, char * CONST *targets, char *varname, Tcl_Obj *body)
{
    int rval = TCL_OK;
    FTS *root_fts;
    FTSENT *ent;
    
    root_fts = fts_open(targets, FTS_PHYSICAL | FTS_COMFOLLOW | FTS_NOCHDIR | FTS_XDEV, NULL);
    
    while ((ent = fts_read(root_fts)) != NULL) {
        switch (ent->fts_info) {
            case FTS_D:  /* directory in pre-order */
            case FTS_DP: /* directory in post-order*/
            {
                if (!(flags & F_DEPTH) != !(ent->fts_info == FTS_D)) {
                    Tcl_SetVar(interp, varname, ent->fts_path, 0);
                    if ((rval = Tcl_EvalObjEx(interp, body, 0)) == TCL_CONTINUE) {
                        fts_set(root_fts, ent, FTS_SKIP);
                    } else if (rval == TCL_BREAK) {
                        fts_close(root_fts);
                        return TCL_OK;
                    } else if (rval != TCL_OK) {
                        fts_close(root_fts);
                        return rval;
                    }
                }
                break;
            }
            case FTS_F:   /* regular file */
            case FTS_SL:  /* symbolic link */
            case FTS_SLNONE: /* symbolic link with non-existant target */
            case FTS_DEFAULT: /* file type not otherwise handled (e.g., fifo) */
            {
                Tcl_SetVar(interp, varname, ent->fts_path, 0);
                if ((rval = Tcl_EvalObjEx(interp, body, 0)) == TCL_CONTINUE) {
                    fts_set(root_fts, ent, FTS_SKIP); /* probably useless on files/symlinks */
                } else if (rval == TCL_BREAK) {
                    fts_close(root_fts);
                    return TCL_OK;
                } else if (rval != TCL_OK) {
                    fts_close(root_fts);
                    return rval;
                }
            }
            case FTS_DC:  /* directory that causes a cycle */
                break;    /* ignore it */
            case FTS_DNR: /* directory that cannot be read */
            case FTS_ERR: /* error return */
            case FTS_NS:  /* file with no stat(2) information */
            {
                if (!(flags & F_IGNORE_ERRORS)) {
                    Tcl_SetErrno(ent->fts_errno);
                    Tcl_SetResult(interp, (char *)Tcl_PosixError(interp),  TCL_STATIC);
                    fts_close(root_fts);
                    return TCL_ERROR;
                }
            }
        }
    }
    /* check errno before calling fts_close in case it sets errno to 0 on success */
    if (errno != 0 || (fts_close(root_fts) != 0 && !(flags & F_IGNORE_ERRORS))) {
        Tcl_SetResult(interp, (char *)Tcl_PosixError(interp), TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 * fs-traverse.c
 *
 * Find files and execute arbitrary expressions on them.
 * Author: Jordan K. Hubbard, Kevin Ballard, Rainer Mueller
 *
 * Copyright (c) 2004 Apple Inc.
 * Copyright (c) 2010 The MacPorts Project
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
 * 3. Neither the name of Apple Inc. nor the names of its contributors
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

/* required for u_short in fts.h on Linux; I think this can be considered a bug
 * in the system header, though. */
#define _BSD_SOURCE

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <fts.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <tcl.h>

#include "fs-traverse.h"

static int do_traverse(Tcl_Interp *interp, int flags, char * CONST *targets, Tcl_Obj *varname, Tcl_Obj *body);

#define F_DEPTH 0x1
#define F_IGNORE_ERRORS 0x2
#define F_TAILS 0x4

/* fs-traverse ?-depth? ?-ignoreErrors? ?-tails? ?--? varname target-list body */
int
FsTraverseCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *varname;
    Tcl_Obj *body;
    int flags = 0;
    int rval = TCL_OK;
    Tcl_Obj *listPtr;
    Tcl_Obj *CONST *objv_orig = objv;
    int lobjc;
    Tcl_Obj **lobjv;

    /* Adjust arguments to remove command name */
    ++objv, --objc;

    /* Parse flags */
    while (objc) {
        char *arg = Tcl_GetString(*objv);
        if (!strcmp(arg, "-depth")) {
            flags |= F_DEPTH;
            ++objv, --objc;
            continue;
        }
        if (!strcmp(arg, "-ignoreErrors")) {
            flags |= F_IGNORE_ERRORS;
            ++objv, --objc;
            continue;
        }
        if (!strcmp(arg, "-tails")) {
            flags |= F_TAILS;
            ++objv, --objc;
            continue;
        }
        if (!strcmp(arg, "--")) {
            ++objv, --objc;
            break;
        }
        break;
    }

    /* Parse remaining args */
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv_orig, "?-depth? ?-ignoreErrors? ?-tails? ?--? varname target-list body");
        return TCL_ERROR;
    }

    varname = *objv;
    ++objv, --objc;

    listPtr = *objv;
    ++objv, --objc;

    body = *objv;

    if ((rval = Tcl_ListObjGetElements(interp, listPtr, &lobjc, &lobjv)) == TCL_OK) {
        char **entries;
        char **iter;

        if (flags & F_TAILS && lobjc > 1) {
            /* result would be ambiguous with multiple paths, so we do not allow this */
            Tcl_SetResult(interp, "-tails cannot be used with multiple paths", TCL_STATIC);
            return TCL_ERROR;
        }

        entries = calloc(lobjc+1, sizeof(char *));
        iter = (char **)entries;
        while (lobjc > 0) {
            *iter++ = Tcl_GetString(*lobjv);
            --lobjc, ++lobjv;
        }
        *iter = NULL;
        rval = do_traverse(interp, flags, entries, varname, body);
        free(entries);
    }
    return rval;
}

static const char *
extract_tail(const char *target, const char *path)
{
    const char *xpath = path;
    size_t tlen = strlen(target);

    if (strncmp(xpath, target, tlen) == 0) {
        if (*(xpath + tlen) == '\0') {
            xpath = ".";
        } else if (*(xpath + tlen) == '/') {
            xpath += tlen + 1;
        } else if (*(target + tlen - 1) == '/') {
            xpath += tlen;
        }
    }

    return xpath;
}

static int
do_compare(const FTSENT **a, const FTSENT **b)
{
    return strcmp((*a)->fts_name, (*b)->fts_name);
}

static int
do_traverse(Tcl_Interp *interp, int flags, char * CONST *targets, Tcl_Obj *varname, Tcl_Obj *body)
{
    int rval = TCL_OK;
    FTS *root_fts;
    FTSENT *ent;

    root_fts = fts_open(targets, FTS_PHYSICAL | FTS_COMFOLLOW | FTS_NOCHDIR | FTS_XDEV, &do_compare);

    while ((ent = fts_read(root_fts)) != NULL) {
        switch (ent->fts_info) {
            case FTS_D:  /* directory in pre-order */
            case FTS_DP: /* directory in post-order*/
            {
                if (!(flags & F_DEPTH) != !(ent->fts_info == FTS_D)) {
                    Tcl_Obj *rpath, *path;
                    if (flags & F_TAILS) {
                        /* there cannot be multiple targets */
                        const char *xpath = extract_tail(targets[0], ent->fts_path);
                        path = Tcl_NewStringObj(xpath, -1);
                    } else {
                        path = Tcl_NewStringObj(ent->fts_path, ent->fts_pathlen);
                    }
                    Tcl_IncrRefCount(path);
                    rpath = Tcl_ObjSetVar2(interp, varname, NULL, path, TCL_LEAVE_ERR_MSG);
                    Tcl_DecrRefCount(path);
                    if (rpath == NULL && !(flags & F_IGNORE_ERRORS)) {
                        fts_close(root_fts);
                        return TCL_ERROR;
                    }
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
                Tcl_Obj *rpath, *path;
                if (flags & F_TAILS) {
                    /* there cannot be multiple targets */
                    const char *xpath = extract_tail(targets[0], ent->fts_path);
                    path = Tcl_NewStringObj(xpath, -1);
                } else {
                    path = Tcl_NewStringObj(ent->fts_path, ent->fts_pathlen);
                }
                Tcl_IncrRefCount(path);
                rpath = Tcl_ObjSetVar2(interp, varname, NULL, path, TCL_LEAVE_ERR_MSG);
                Tcl_DecrRefCount(path);
                if (rpath == NULL && !(flags & F_IGNORE_ERRORS)) {
                    fts_close(root_fts);
                    return TCL_ERROR;
                }
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
                    Tcl_ResetResult(interp);
                    Tcl_AppendResult(interp, ent->fts_path, ": ", (char *)Tcl_PosixError(interp), NULL);
                    fts_close(root_fts);
                    return TCL_ERROR;
                }
            }
        }
    }
    /* check errno before calling fts_close in case it sets errno to 0 on success */
    if (errno != 0) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, root_fts->fts_path, ": ", (char *)Tcl_PosixError(interp), NULL);
        fts_close(root_fts);
        return TCL_ERROR;
    } else if (fts_close(root_fts) != 0 && !(flags & F_IGNORE_ERRORS)) {
        Tcl_SetErrno(errno);
        Tcl_SetResult(interp, (char *)Tcl_PosixError(interp), TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

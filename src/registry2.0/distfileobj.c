/*
 * distfileobj.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2011 Clemens Lang <cal@macports.org>
 * Copyright (c) 2022 The MacPorts Project
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <string.h>
#include <stdlib.h>
#include <tcl.h>
#include <sqlite3.h>

#include "distfileobj.h"
#include "registry.h"
#include "util.h"

const char* distfile_props[] = {
    "id",
    "subdir",
    "path",
    NULL
};

/* ${distfile} prop ?value? */
static int distfile_obj_prop(Tcl_Interp* interp, reg_distfile* distfile, int objc,
        Tcl_Obj* CONST objv[]) {
    int index;
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?value?");
        return TCL_ERROR;
    }
    if (objc == 2) {
        /* ${distfile} prop; return the current value */
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], distfile_props, "prop", 0, &index)
                == TCL_OK) {
            char* key = Tcl_GetString(objv[1]);
            char* value;
            reg_error error;
            if (reg_distfile_propget(distfile, key, &value, &error)) {
                Tcl_Obj* result = Tcl_NewStringObj(value, -1);
                Tcl_SetObjResult(interp, result);
                free(value);
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
        return TCL_ERROR;
    } else {
        /* ${distfile} prop name value; not implemented */
        return TCL_ERROR;
    }
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, reg_distfile* distfile, int objc,
            Tcl_Obj* CONST objv[]);
} distfile_obj_cmd_type;

static distfile_obj_cmd_type distfile_cmds[] = {
    /* keys */
    { "subdir", distfile_obj_prop },
    { "path", distfile_obj_prop },
    { NULL, NULL }
};

/* ${distfile} cmd ?arg ...? */
/* This function implements the command that will be called when a distfile
 * created by `registry::distfile` is used as a procedure.
 */
int distfile_obj_cmd(ClientData clientData, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], distfile_cmds,
                sizeof(distfile_obj_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        distfile_obj_cmd_type* cmd = &distfile_cmds[cmd_index];
        return cmd->function(interp, (reg_distfile*)clientData, objc, objv);
    }
    return TCL_ERROR;
}


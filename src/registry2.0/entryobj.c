/*
 * entryobj.c
 * $Id: $
 *
 * Copyright (c) 2007 Chris Pickel <sfiera@macports.org>
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

#include "entryobj.h"
#include "registry.h"
#include "util.h"

const char* entry_props[] = {
    "name",
    "portfile",
    "url",
    "location",
    "epoch",
    "version",
    "revision",
    "variants",
    "default_variants",
    "date",
    "state",
    "installtype",
    NULL
};

/* ${entry} prop ?value? */
static int entry_obj_prop(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    int index;
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?value?");
        return TCL_ERROR;
    }
    if (objc == 2) {
        /* ${entry} prop; return the current value */
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], entry_props, "prop", 0, &index)
                == TCL_OK) {
            char* key = Tcl_GetString(objv[1]);
            char* value;
            reg_error error;
            if (reg_entry_propget(reg, entry, key, &value, &error)) {
                Tcl_Obj* result = Tcl_NewStringObj(value, -1);
                Tcl_SetObjResult(interp, result);
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
        return TCL_ERROR;
    } else {
        /* ${entry} prop name value; set a new value */
        reg_registry* reg = registry_for(interp, reg_attached | reg_can_write);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], entry_props, "prop", 0, &index)
                == TCL_OK) {
            char* key = Tcl_GetString(objv[1]);
            char* value = Tcl_GetString(objv[2]);
            reg_error error;
            if (reg_entry_propset(reg, entry, key, value, &error)) {
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
        return TCL_ERROR;
    }
}

/*
 * ${entry} map file-list
 *
 * Maps the listed files to the port represented by ${entry}. This will throw an
 * error if a file is mapped to an already-existing file, but not a very
 * descriptive one.
 *
 * TODO: more descriptive error on duplicated file
 */
static int entry_obj_map(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "map file-list");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** files;
        reg_error error;
        Tcl_Obj** listv;
        int listc;
        if (Tcl_ListObjGetElements(interp, objv[2], &listc, &listv) != TCL_OK) {
            return TCL_ERROR;
        }
        if (list_obj_to_string(&files, listv, listc, &error)) {
            if (reg_entry_map(reg, entry, files, listc, &error) == listc) {
                return TCL_OK;
            }
        }
        return registry_failed(interp, &error);
    }
}

/*
 * ${entry} unmap file-list
 *
 * Unmaps the listed files from the given port. Will throw an error if a file
 * that is not mapped to the port is attempted to be unmapped.
 */
static int entry_obj_unmap(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "map file-list");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** files;
        reg_error error;
        Tcl_Obj** listv;
        int listc;
        if (Tcl_ListObjGetElements(interp, objv[2], &listc, &listv) != TCL_OK) {
            return TCL_ERROR;
        }
        if (list_obj_to_string(&files, listv, listc, &error)) {
            if (reg_entry_unmap(reg, entry, files, listc, &error) == listc) {
                return TCL_OK;
            }
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_files(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "files");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** files;
        reg_error error;
        int file_count = reg_entry_files(reg, entry, &files, &error);
        if (file_count >= 0) {
            int i;
            Tcl_Obj** objs;
            if (list_string_to_obj(&objs, files, file_count, &error)) {
                Tcl_Obj* result = Tcl_NewListObj(file_count, objs);
                Tcl_SetObjResult(interp, result);
                for (i=0; i<file_count; i++) {
                    free(files[i]);
                }
                free(files);
                return TCL_OK;
            }
            for (i=0; i<file_count; i++) {
                free(files[i]);
            }
            free(files);
        }
        return registry_failed(interp, &error);
    }
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, reg_entry* entry, int objc,
            Tcl_Obj* CONST objv[]);
} entry_obj_cmd_type;

static entry_obj_cmd_type entry_cmds[] = {
    { "name", entry_obj_prop },
    { "portfile", entry_obj_prop },
    { "url", entry_obj_prop },
    { "location", entry_obj_prop },
    { "epoch", entry_obj_prop },
    { "version", entry_obj_prop },
    { "revision", entry_obj_prop },
    { "variants", entry_obj_prop },
    { "default_variants", entry_obj_prop },
    { "date", entry_obj_prop },
    { "state", entry_obj_prop },
    { "installtype", entry_obj_prop },
    { "map", entry_obj_map },
    { "unmap", entry_obj_unmap },
    { "files", entry_obj_files },
    { NULL, NULL }
};

/* ${entry} cmd ?arg ...? */
/* This function implements the command that will be called when an entry
 * created by `registry::entry` is used as a procedure. Since all data is kept
 * in a temporary sqlite3 database that is created for the current interpreter,
 * none of the sqlite3 functions used have any error checking. That should be a
 * safe assumption, since nothing outside of registry:: should ever have the
 * chance to touch it.
 */
int entry_obj_cmd(ClientData clientData, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], entry_cmds,
                sizeof(entry_obj_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        entry_obj_cmd_type* cmd = &entry_cmds[cmd_index];
        return cmd->function(interp, (reg_entry*)clientData, objc, objv);
    }
    return TCL_ERROR;
}

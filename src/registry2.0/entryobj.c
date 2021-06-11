/*
 * entryobj.c
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
    "id",
    "name",
    "portfile",
    "location",
    "epoch",
    "version",
    "revision",
    "variants",
    "requested_variants",
    "date",
    "state",
    "installtype",
    "archs",
    "os_platform",
    "os_major",
    "requested",
    "cxx_stdlib",
    "cxx_stdlib_overridden",
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
            if (reg_entry_propget(entry, key, &value, &error)) {
                Tcl_Obj* result = Tcl_NewStringObj(value, -1);
                Tcl_SetObjResult(interp, result);
                free(value);
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
        return TCL_ERROR;
    } else {
        /* ${entry} prop name value; set a new value */
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], entry_props, "prop", 0, &index)
                == TCL_OK) {
            char* key = Tcl_GetString(objv[1]);
            char* value = Tcl_GetString(objv[2]);
            reg_error error;
            if (reg_entry_propset(entry, key, value, &error)) {
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
        return TCL_ERROR;
    }
}

typedef struct {
    char* name;
    int (*function)(reg_entry* entry, char** files, int file_count,
            reg_error* errPtr);
} filemap_op;

static filemap_op filemap_cmds[] = {
    { "map", reg_entry_map },
    { "unmap", reg_entry_unmap },
    { "deactivate", reg_entry_deactivate },
    { NULL, NULL }
};

static int entry_obj_filemap(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    int op;
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "file-list");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else if (Tcl_GetIndexFromObjStruct(interp, objv[1], filemap_cmds,
                sizeof(filemap_op), "cmd", 0, &op) != TCL_OK) {
        return TCL_ERROR;
    } else {
        char** files;
        reg_error error;
        Tcl_Obj** listv;
        int listc;
        int result = TCL_ERROR;
        if (Tcl_ListObjGetElements(interp, objv[2], &listc, &listv) != TCL_OK) {
            return TCL_ERROR;
        }
        if (list_obj_to_string(&files, listv, listc, &error)) {
            if (filemap_cmds[op].function(entry, files, listc, &error)) {
                result = TCL_OK;
            } else {
                result = registry_failed(interp, &error);
            }
            free(files);
        } else {
            result = registry_failed(interp, &error);
        }
        return result;
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
        int file_count = reg_entry_files(entry, &files, &error);
        int i;
        if (file_count >= 0) {
            Tcl_Obj** objs;
            int retval = TCL_ERROR;
            if (list_string_to_obj(&objs, files, file_count, &error)) {
                Tcl_Obj* result = Tcl_NewListObj(file_count, objs);
                Tcl_SetObjResult(interp, result);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            for (i=0; i<file_count; i++) {
                free(files[i]);
            }
            free(files);
            return retval;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_imagefiles(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "imagefiles");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** files;
        reg_error error;
        int file_count = reg_entry_imagefiles(entry, &files, &error);
        int i;
        if (file_count >= 0) {
            Tcl_Obj** objs;
            int retval = TCL_ERROR;
            if (list_string_to_obj(&objs, files, file_count, &error)) {
                Tcl_Obj* result = Tcl_NewListObj(file_count, objs);
                Tcl_SetObjResult(interp, result);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            for (i=0; i<file_count; i++) {
                free(files[i]);
            }
            free(files);
            return retval;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_activate(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc > 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "activate file-list ?as-file-list?");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char** files;
        char** as_files = NULL;
        reg_error error;
        Tcl_Obj* as = NULL;
        Tcl_Obj** as_listv = NULL;
        Tcl_Obj** listv;
        int listc;
        int as_listc;
        int result = TCL_ERROR;
        if (objc >= 4) {
            as = objv[3];
        }
        if (Tcl_ListObjGetElements(interp, objv[2], &listc, &listv) != TCL_OK) {
            return TCL_ERROR;
        }
        if (as != NULL) {
            if (Tcl_ListObjGetElements(interp, as, &as_listc, &as_listv)
                    != TCL_OK) {
                return TCL_ERROR;
            }
            if (listc != as_listc) {
                /* TODO: set an error code */
                Tcl_SetResult(interp, "list and as_list must be of equal "
                        "length", TCL_STATIC);
                return TCL_ERROR;
            }
        }
        if (list_obj_to_string(&files, listv, listc, &error)
                && (as_listv == NULL || list_obj_to_string(&as_files, as_listv,
                        as_listc, &error))) {
            if (reg_entry_activate(entry, files, as_files, listc, &error)) {
                result = TCL_OK;
            } else {
                result = registry_failed(interp, &error);
            }
            free(files);
        } else {
            result = registry_failed(interp, &error);
        }
        return result;
    }
}

static int entry_obj_dependencies(Tcl_Interp* interp, reg_entry* entry,
        int objc, Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "dependencies");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        reg_entry** entries;
        reg_error error;
        int entry_count = reg_entry_dependencies(entry, &entries, &error);
        if (entry_count >= 0) {
            Tcl_Obj** objs;
            int retval = TCL_ERROR;
            if (list_entry_to_obj(interp, &objs, entries, entry_count, &error)){
                Tcl_Obj* result = Tcl_NewListObj(entry_count, objs);
                Tcl_SetObjResult(interp, result);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            free(entries);
            return retval;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_dependents(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "dependents");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        reg_entry** entries;
        reg_error error;
        int entry_count = reg_entry_dependents(entry, &entries, &error);
        if (entry_count >= 0) {
            Tcl_Obj** objs;
            int retval = TCL_ERROR;
            if (list_entry_to_obj(interp, &objs, entries, entry_count, &error)){
                Tcl_Obj* result = Tcl_NewListObj(entry_count, objs);
                Tcl_SetObjResult(interp, result);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            free(entries);
            return retval;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_depends(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "depends portname");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        char* port = Tcl_GetString(objv[2]);
        reg_error error;
        if (reg_entry_depends(entry, port, &error)) {
            return TCL_OK;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_add_portgroup(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 6) {
        Tcl_WrongNumArgs(interp, 1, objv, "addgroup name version sha256 size");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        reg_error error;
        char* name = Tcl_GetString(objv[2]);
        char* version = Tcl_GetString(objv[3]);
        char* sha256 = Tcl_GetString(objv[4]);
        Tcl_WideInt tclsize;
        Tcl_GetWideIntFromObj(interp, objv[5], &tclsize);
        sqlite_int64 size = (sqlite_int64)tclsize;
        if (reg_entry_addgroup(entry, name, version, sha256, size, &error)) {
            return TCL_OK;
        }
        return registry_failed(interp, &error);
    }
}

static int entry_obj_get_portgroups(Tcl_Interp* interp, reg_entry* entry, int objc,
        Tcl_Obj* CONST objv[]) {
    reg_registry* reg = registry_for(interp, reg_attached);
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "groups_used");
        return TCL_ERROR;
    } else if (reg == NULL) {
        return TCL_ERROR;
    } else {
        reg_portgroup** portgroups;
        reg_error error;
        int portgroup_count = reg_entry_getgroups(entry, &portgroups, &error);
        if (portgroup_count >= 0) {
            Tcl_Obj** objs;
            int retval = TCL_ERROR;
            if (list_portgroup_to_obj(interp, &objs, portgroups, portgroup_count, &error)){
                Tcl_Obj* result = Tcl_NewListObj(portgroup_count, objs);
                Tcl_SetObjResult(interp, result);
                free(objs);
                retval = TCL_OK;
            } else {
                retval = registry_failed(interp, &error);
            }
            free(portgroups);
            return retval;
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
    /* keys */
    { "id", entry_obj_prop },
    { "name", entry_obj_prop },
    { "portfile", entry_obj_prop },
    { "location", entry_obj_prop },
    { "epoch", entry_obj_prop },
    { "version", entry_obj_prop },
    { "revision", entry_obj_prop },
    { "variants", entry_obj_prop },
    { "requested_variants", entry_obj_prop },
    { "date", entry_obj_prop },
    { "state", entry_obj_prop },
    { "installtype", entry_obj_prop },
    { "archs", entry_obj_prop },
    { "os_platform", entry_obj_prop },
    { "os_major", entry_obj_prop },
    { "requested", entry_obj_prop },
    { "cxx_stdlib", entry_obj_prop },
    { "cxx_stdlib_overridden", entry_obj_prop },
    /* filemap */
    { "map", entry_obj_filemap },
    { "unmap", entry_obj_filemap },
    { "files", entry_obj_files },
    { "imagefiles", entry_obj_imagefiles },
    { "activate", entry_obj_activate },
    { "deactivate", entry_obj_filemap },
    /* dep map */
    { "dependents", entry_obj_dependents },
    { "dependencies", entry_obj_dependencies },
    { "depends", entry_obj_depends },
    /* portgroups */
    { "addgroup", entry_obj_add_portgroup },
    { "groups_used", entry_obj_get_portgroups },
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

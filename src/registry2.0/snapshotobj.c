/*
 * snapshotobj.c
 * vim:tw=80:expandtab
 *
 * Copyright (c) 2017 The MacPorts Project
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

#include "snapshotobj.h"
#include "registry.h"
#include "util.h"

const char* snapshot_props[] = {
    "id",
    "note",
    "ports",
    "created_at",
    NULL
};

/* ${snapshot} id */
static int snapshot_obj_id(Tcl_Interp* interp, reg_snapshot* snapshot, int objc,
        Tcl_Obj* CONST objv[]) {
    int index;
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?value?");
        return TCL_ERROR;
    }
    if (objc == 2) {
        /* ${snapshot} id; return the current value */
        char value[sizeof(snapshot->id)+1];
        sprintf(value, "%lld", snapshot->id);
        if (Tcl_GetIndexFromObj(interp, objv[1], snapshot_props, "prop", 0, &index)
                == TCL_OK) {
            Tcl_Obj* result = Tcl_NewStringObj(value, -1);
            Tcl_SetObjResult(interp, result);
            return TCL_OK;
        }
    }
    return TCL_ERROR;
}

/* ${snapshot} prop */
static int snapshot_obj_prop(Tcl_Interp* interp, reg_snapshot* snapshot, int objc,
        Tcl_Obj* CONST objv[]) {
    int index;
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?value?");
        return TCL_ERROR;
    }
    if (objc == 2) {
        /* ${snapshot} prop; return the current value */
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], snapshot_props, "prop", 0, &index)
                == TCL_OK) {
            char* key = Tcl_GetString(objv[1]);
            char* value;
            reg_error error;
            if (reg_snapshot_propget(snapshot, key, &value, &error)) {
                Tcl_Obj* result = Tcl_NewStringObj(value, -1);
                Tcl_SetObjResult(interp, result);
                free(value);
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
    }
    return TCL_ERROR;
}

/* ${snapshot} ports */
static int snapshot_obj_ports(Tcl_Interp* interp, reg_snapshot* snapshot, int objc,
        Tcl_Obj* CONST objv[]) {
    int index;
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?value?");
        return TCL_ERROR;
    }
    if (objc == 2) {
        /* ${snapshot} prop; return the current value */
        reg_registry* reg = registry_for(interp, reg_attached);
        if (reg == NULL) {
            return TCL_ERROR;
        }
        if (Tcl_GetIndexFromObj(interp, objv[1], snapshot_props, "prop", 0, &index)
                == TCL_OK) {
            port** ports;
            reg_error error;
            int port_count = reg_snapshot_ports_get(snapshot, &ports, &error);
            if (port_count >= 0) {
                char* portstrs[port_count + 1];
                int i;
                for(i = 0; i < port_count; i++){
                    port* current_port = ports[i];
                    portstrs[i] = NULL;
                    if (asprintf(&portstrs[i], "%s %d %s %s",
                            current_port->name,
                            current_port->requested,
                            current_port->state,
                            current_port->variants) < 0) {
                        return TCL_ERROR;
                    }
                }

                Tcl_Obj** objs;
                if (list_string_to_obj(&objs, portstrs, port_count, &error)){
                    Tcl_Obj* result = Tcl_NewListObj(port_count, objs);
                    Tcl_SetObjResult(interp, result);
                    free(objs);
                    for (i=0; i < port_count; i++) {
                        free(ports[i]);
                    }
                    free(ports);
                    return TCL_OK;
                } else {
                    return registry_failed(interp, &error);
                }
            }
            return registry_failed(interp, &error);
        }
    }
    return TCL_ERROR;
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, reg_snapshot* snapshot, int objc,
            Tcl_Obj* CONST objv[]);
} snapshot_obj_cmd_type;

static snapshot_obj_cmd_type snapshot_cmds[] = {
    /* keys */
    { "id", snapshot_obj_id },
    { "note", snapshot_obj_prop },
    { "created_at", snapshot_obj_prop },
    /* ports */
    { "ports", snapshot_obj_ports },
    { NULL, NULL }
};

/* ${snapshot} cmd ?arg ...? */
/* This function implements the command that will be called when a snapshot
 * created by `registry::snapshot` is used as a procedure. Since all data is kept
 * in a temporary sqlite3 database that is created for the current interpreter,
 * none of the sqlite3 functions used have any error checking. That should be a
 * safe assumption, since nothing outside of registry:: should ever have the
 * chance to touch it.
 */
int snapshot_obj_cmd(ClientData clientData, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], snapshot_cmds,
                sizeof(snapshot_obj_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        snapshot_obj_cmd_type* cmd = &snapshot_cmds[cmd_index];
        return cmd->function(interp, (reg_snapshot*)clientData, objc, objv);
    }
    return TCL_ERROR;
}

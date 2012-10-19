/*
 * item.c
 * $Id$
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

#include "itemobj.h"
#include "registry.h"
#include "util.h"

/* ${item} retain */
/* Increments the refcount of the item. Calls to retain should be balanced by
 * calls to release. The refcount starts at 1 and needn't be retained by the
 * creator.
 */
static int item_obj_retain(Tcl_Interp* interp, item_t* item, int objc,
        Tcl_Obj* CONST objv[]) {
    sqlite3_stmt* stmt;
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }
    sqlite3_prepare_v2(item->db, "UPDATE items SET refcount = refcount+1 WHERE "
            "rowid=?", -1, &stmt, NULL);
    sqlite3_bind_int64(stmt, 1, item->rowid);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    Tcl_SetObjResult(interp, objv[0]);
    return TCL_OK;
}

/* ${item} release */
/* Decrements the refcount of the item. If this is called after all retains have
 * been balanced with releases, the object will be freed.
 */
static int item_obj_release(Tcl_Interp* interp, item_t* item, int objc,
        Tcl_Obj* CONST objv[]) {
    sqlite3_stmt* stmt;
    int refcount;
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 2, objv, "");
        return TCL_ERROR;
    }
    sqlite3_prepare_v2(item->db, "UPDATE items SET refcount = refcount-1 "
            "WHERE rowid=?", -1, &stmt, NULL);
    sqlite3_bind_int64(stmt, 1, item->rowid);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    sqlite3_prepare_v2(item->db, "SELECT refcount FROM items WHERE rowid=?", -1,
            &stmt, NULL);
    sqlite3_bind_int64(stmt, 1, item->rowid);
    sqlite3_step(stmt);
    refcount = sqlite3_column_int(stmt, 0);
    sqlite3_finalize(stmt);
    if (refcount <= 0) {
        Tcl_DeleteCommand(interp, Tcl_GetString(objv[0]));
    }
    return TCL_OK;
}

/* ${item} key name ?value? */
static int item_obj_key(Tcl_Interp* interp, item_t* item, int objc,
        Tcl_Obj* CONST objv[]) {
    static const char* keys[] = {
        "name", "url", "path", "worker", "options", "variants",
        NULL
    };
    if (objc == 3) {
        /* ${item} key name; return the current value */
        int index;
        if (Tcl_GetIndexFromObj(interp, objv[2], keys, "key", 0, &index)
                != TCL_OK) {
            /* objv[2] is not a valid key */
            return TCL_ERROR;
        } else {
            sqlite3_stmt* stmt;
            char query[64];
            char* key = Tcl_GetString(objv[2]);
            int len;
            const char* result;
            Tcl_Obj* resultObj;
            snprintf(query, sizeof(query), "SELECT %s FROM items WHERE rowid=?", key);
            sqlite3_prepare_v2(item->db, query, -1, &stmt, NULL);
            sqlite3_bind_int64(stmt, 1, item->rowid);
            sqlite3_step(stmt);
            /* eliminate compiler warning about signedness */
            result = sqlite3_column_text(stmt, 0);
            len = sqlite3_column_bytes(stmt, 0);
            resultObj = Tcl_NewStringObj(result, len);
            Tcl_SetObjResult(interp, resultObj);
            sqlite3_finalize(stmt);
        }
    } else if (objc == 4) {
        /* ${item} key name value; set a new value */
        int index;
        if (Tcl_GetIndexFromObj(interp, objv[2], keys, "key", 0, &index)
                != TCL_OK) {
            /* objv[2] is not a valid key */
            return TCL_ERROR;
        } else {
            sqlite3_stmt* stmt;
            char query[64];
            char* key = Tcl_GetString(objv[2]);
            char* value = Tcl_GetString(objv[3]);
            snprintf(query, sizeof(query), "UPDATE items SET %s=? WHERE rowid=?", key);
            sqlite3_prepare_v2(item->db, query, -1, &stmt, NULL);
            sqlite3_bind_text(stmt, 1, value, -1, SQLITE_STATIC);
            sqlite3_bind_int64(stmt, 2, item->rowid);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
    } else {
        Tcl_WrongNumArgs(interp, 1, objv, "key name ?value?");
        return TCL_ERROR;
    }
    return TCL_OK;
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, item_t* item, int objc,
            Tcl_Obj* CONST objv[]);
} item_obj_cmd_type;

static item_obj_cmd_type item_cmds[] = {
    { "retain", item_obj_retain },
    { "release", item_obj_release },
    { "key", item_obj_key },
    { NULL, NULL }
};

/* ${item} cmd ?arg ...? */
/* This function implements the command that will be called when an item created
 * by `registry::item` is used as a procedure. Since all data is kept in a
 * temporary sqlite3 database that is created for the current interpreter, none
 * of the sqlite3 functions used have any error checking. That should be a safe
 * assumption, since nothing outside of registry:: should ever have the chance
 * to touch it.
 */
int item_obj_cmd(ClientData clientData, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], item_cmds,
                sizeof(item_obj_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        item_obj_cmd_type* cmd = &item_cmds[cmd_index];
        return cmd->function(interp, (item_t*)clientData, objc, objv);
    }
    return TCL_ERROR;
}

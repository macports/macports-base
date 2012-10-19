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

#include "item.h"
#include "itemobj.h"
#include "util.h"
#include "registry.h"

static void delete_item(ClientData clientData) {
    sqlite_int64 rowid = ((item_t*)clientData)->rowid;
    sqlite3* db = ((item_t*)clientData)->db;
    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(db, "DELETE FROM items WHERE rowid=?", -1, &stmt, NULL);
    sqlite3_bind_int(stmt, rowid, 1);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    free(clientData);
}

static item_t* get_item(Tcl_Interp* interp, char* name) {
    return (item_t*)get_object(interp, name, "item", item_obj_cmd);
}

static int set_item(Tcl_Interp* interp, char* name, sqlite_int64 rowid) {
    sqlite3* db = registry_db(interp, 0);
    item_t* new_item = malloc(sizeof(item_t));
    if (!new_item) {
        return TCL_ERROR;
    }
    new_item->rowid = rowid;
    new_item->db = db;
    if (set_object(interp, name, new_item, "item", item_obj_cmd, delete_item)
                == TCL_OK) {
        sqlite3_stmt* stmt;
        /* record the proc name in case we need to return it in a search */
        if ((sqlite3_prepare_v2(db, "UPDATE items SET proc=? WHERE rowid=?", -1,
                    &stmt, NULL) == SQLITE_OK)
                && (sqlite3_bind_text(stmt, 1, name, -1, SQLITE_STATIC)
                    == SQLITE_OK)
                && (sqlite3_bind_int64(stmt, 2, rowid) == SQLITE_OK)
                && (sqlite3_step(stmt) == SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            return TCL_OK;
        }
        Tcl_DeleteCommand(interp, name);
        sqlite3_finalize(stmt);
    }
    free(new_item);
    return TCL_ERROR;
}

/* item create ?name? */
static int item_create(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    sqlite_int64 item;
    sqlite3* db = registry_db(interp, 0);
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "?name?");
        return TCL_ERROR;
    } else if (db == NULL) {
        return TCL_ERROR;
    }
    sqlite3_exec(db, "INSERT INTO items (refcount) VALUES (1)", NULL, NULL,
            NULL);
    item = sqlite3_last_insert_rowid(db);
    if (objc == 3) {
        /* item create name */
        char* name = Tcl_GetString(objv[2]);
        if (set_item(interp, name, item) == TCL_OK) {
            Tcl_SetObjResult(interp, objv[2]);
            return TCL_OK;
        }
    } else {
        /* item create */
        char* name = unique_name(interp, "::registry::item");
        if (set_item(interp, name, item) == TCL_OK) {
            Tcl_Obj* res = Tcl_NewStringObj(name, -1);
            Tcl_SetObjResult(interp, res);
            free(name);
            return TCL_OK;
        }
        free(name);
    }
    return TCL_ERROR;
}

/* item release ?name ...? */
static int item_release(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    int i;
    for (i=2; i<objc; i++) {
        char* proc = Tcl_GetString(objv[i]);
        item_t* item = get_item(interp, proc);
        if (item == NULL) {
            return TCL_ERROR;
        } else {
            /* decref */
        }
    }
    return TCL_OK;
}

static const char* searchKeys[] = {
    "name",
    "url",
    "path",
    "worker",
    "options",
    "variants",
    NULL
};

/**
 * item search ?{key value} ...?
 *
 * TODO: rip this out and adapt `entry search`
 */
static int item_search(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    int i, r;
    sqlite3* db = registry_db(interp, 0);
    sqlite3_stmt* stmt;
    Tcl_Obj* result;
    /* 40 + 20 per clause is safe */
    int query_size = (20*objc)*sizeof(char);
    char* query = (char*)malloc(query_size);
    char* query_start = "SELECT proc FROM items";
    char* insert;
    int insert_size = query_size - strlen(query_start);
    if (db == NULL || query == NULL) {
        return TCL_ERROR;
    }
    strncpy(query, query_start, query_size);
    insert = query + strlen(query_start);
    for (i=2; i<objc; i++) {
        int len;
        int index;
        char* key;
        Tcl_Obj* keyObj;
        /* ensure each search clause is a 2-element list */
        if (Tcl_ListObjLength(interp, objv[i], &len) != TCL_OK || len != 2) {
            free(query);
            Tcl_AppendResult(interp, "search clause \"", Tcl_GetString(objv[i]),
                    "\" is not a list with 2 elements", NULL);
            return TCL_ERROR;
        }
        /* this should't fail if Tcl_ListObjLength didn't */
        Tcl_ListObjIndex(interp, objv[i], 0, &keyObj);
        /* ensure that a valid search key was used */
        if (Tcl_GetIndexFromObj(interp, keyObj, searchKeys, "search key", 0,
                &index) != TCL_OK) {
            free(query);
            return TCL_ERROR;
        }
        key = Tcl_GetString(keyObj);
        if (i == 2) {
            snprintf(insert, insert_size, " WHERE %s=?", key);
            insert += 9 + strlen(key);
            insert_size -= 9 + strlen(key);
        } else {
            snprintf(insert, insert_size, " AND %s=?", key);
            insert += 7 + strlen(key);
            insert_size -= 7 + strlen(key);
        }
    }
    r = sqlite3_prepare_v2(db, query, -1, &stmt, NULL);
    free(query);
    for (i=2; i<objc; i++) {
        char* val;
        Tcl_Obj* valObj;
        Tcl_ListObjIndex(interp, objv[i], 1, &valObj);
        val = Tcl_GetString(valObj);
        sqlite3_bind_text(stmt, i-1, val, -1, SQLITE_STATIC);
    }
    result = Tcl_NewListObj(0, NULL);
    r = sqlite3_step(stmt);
    while (r == SQLITE_ROW) {
        /* avoid signedness warning */
        const char* proc = sqlite3_column_text(stmt, 0);
        int len = sqlite3_column_bytes(stmt, 0);
        Tcl_Obj* procObj = Tcl_NewStringObj(proc, len);
        Tcl_ListObjAppendElement(interp, result, procObj);
        r = sqlite3_step(stmt);
    }
    sqlite3_finalize(stmt);
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
}

/* item exists name */
static int item_exists(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "name");
        return TCL_ERROR;
    }
    if (get_item(interp, Tcl_GetString(objv[2])) == NULL) {
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
    } else {
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(1));
    }
    return TCL_OK;
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
} item_cmd_type;

static item_cmd_type item_cmds[] = {
    /* Global commands */
    { "create", item_create },
    { "search", item_search },
    { "exists", item_exists },
    /* Instance commands */
    /*
    { "retain", item_retain },
    { "release", item_release },
    { "name", item_name },
    { "url", item_url },
    { "path", item_path },
    { "worker", item_worker },
    { "options", item_options },
    { "variants", item_variants },
    */
    { NULL, NULL }
};

/* item cmd ?arg ...? */
int item_cmd(ClientData clientData UNUSED, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], item_cmds,
                sizeof(item_cmd_type), "cmd", 0, &cmd_index) == TCL_OK) {
        item_cmd_type* cmd = &item_cmds[cmd_index];
        return cmd->function(interp, objc, objv);
    }
    return TCL_ERROR;
}

/*
 * registry.c
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

#include <stdio.h>
#include <unistd.h>
#include <tcl.h>
#include <sqlite3.h>

#include "graph.h"
#include "item.h"
#include "entry.h"
#include "util.h"
#include "sql.h"

int registry_failed(Tcl_Interp* interp, reg_error* errPtr) {
    Tcl_Obj* result = Tcl_NewStringObj(errPtr->description, -1);
    Tcl_SetObjResult(interp, result);
    Tcl_SetErrorCode(interp, errPtr->code, NULL);
    reg_error_destruct(errPtr);
    return TCL_ERROR;
}

int registry_tcl_detach(Tcl_Interp* interp, sqlite3* db, reg_error* errPtr) {
    reg_entry** entries;
    int entry_count = reg_all_entries(db, &entries, errPtr);
    if (entry_count >= 0) {
        int i;
        for (i=0; i<entry_count; i++) {
            Tcl_DeleteCommand(interp, entries[i]->proc);
        }
        if (reg_detach(db, errPtr)) {
            Tcl_SetAssocData(interp, "registry::attached", NULL, (void*)0);
            return 1;
        }
    }
    return registry_failed(interp, errPtr);
}

/**
 * Deletes the sqlite3 DB associated with interp.
 *
 * This function will close an interp's associated DB, although there doesn't
 * seem to be a way of verifying that it happened properly. This will be a
 * problem if we get lazy and forget to finalize a sqlite3_stmt somewhere, so
 * this function will be noisy and complain if we do.
 *
 * Then it will leak memory :(
 */
static void delete_db(ClientData db, Tcl_Interp* interp) {
    reg_error error;
    if (Tcl_GetAssocData(interp, "registry::attached", NULL)) {
        if (!registry_tcl_detach(interp, (sqlite3*)db, &error)) {
            fprintf(stderr, error.description);
            reg_error_destruct(&error);
        }
    }
    if (!reg_close((sqlite3*)db, &error)) {
        fprintf(stderr, error.description);
        reg_error_destruct(&error);
    }
}

/**
 * Returns the sqlite3 DB associated with interp.
 *
 * The registry keeps its state in a sqlite3 database that is keyed to the
 * current interpreter context. Different interps will have different instances
 * of the connection, although I don't know if the Apple-provided sqlite3 lib
 * was compiled with thread-safety, so I can't be certain that it's safe to use
 * the registry from multiple threads. I'm pretty sure it's unsafe to alias a
 * registry function into a different thread.
 *
 * If `attached` is set to true, then this function will additionally check if
 * a real registry database has been attached. If not, then it will return NULL.
 *
 * This function sets its own Tcl result.
 */
sqlite3* registry_db(Tcl_Interp* interp, int attached) {
    sqlite3* db = Tcl_GetAssocData(interp, "registry::db", NULL);
    if (db == NULL) {
        reg_error error;
        if (reg_open(&db, &error)) {
            Tcl_SetAssocData(interp, "registry::db", delete_db, db);
        } else {
            registry_failed(interp, &error);
            return NULL;
        }
    }
    if (attached) {
        if (!Tcl_GetAssocData(interp, "registry::attached", NULL)) {
            Tcl_SetErrorCode(interp, "registry::not-open", NULL);
            Tcl_SetResult(interp, "registry is not open", TCL_STATIC);
            db = NULL;
        }
    }
    return db;
}

static int registry_open(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "db-file");
        return TCL_ERROR;
    } else {
        char* path = Tcl_GetString(objv[1]);
        sqlite3* db = registry_db(interp, 0);
        reg_error error;
        if (reg_attach(db, path, &error)) {
            Tcl_SetAssocData(interp, "registry::attached", NULL,
                    (void*)1);
            return TCL_OK;
        } else {
            return registry_failed(interp, &error);
        }
    }
}

static int registry_close(ClientData clientData UNUSED, Tcl_Interp* interp,
        int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
        return TCL_ERROR;
    } else {
        sqlite3* db = registry_db(interp, 1);
        if (db == NULL) {
            return TCL_ERROR;
        } else {
            reg_error error;
            if (registry_tcl_detach(interp, db, &error)) {
                return TCL_OK;
            }
            return registry_failed(interp, &error);
        }
    }
    return TCL_ERROR;
}

/**
 * Initializer for the registry lib.
 *
 * This function is called automatically by Tcl upon loading of registry.dylib.
 * It creates the global commands made available in the registry namespace.
 */
int Registry_Init(Tcl_Interp* interp) {
    if (Tcl_InitStubs(interp, "8.3", 0) == NULL) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, "registry::open", registry_open, NULL,
            NULL);
    Tcl_CreateObjCommand(interp, "registry::close", registry_close, NULL,
            NULL);
    /* Tcl_CreateObjCommand(interp, "registry::graph", GraphCmd, NULL, NULL); */
    /* Tcl_CreateObjCommand(interp, "registry::item", item_cmd, NULL, NULL); */
    Tcl_CreateObjCommand(interp, "registry::entry", entry_cmd, NULL, NULL);
    if (Tcl_PkgProvide(interp, "registry", "2.0") != TCL_OK) {
        return TCL_ERROR;
    }
    return TCL_OK;
}

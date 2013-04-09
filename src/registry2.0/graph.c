/*
 * graph.c
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
#include <unistd.h>
#include <tcl.h>
#include <sqlite3.h>

#include "graph.h"
#include "graphobj.h"
#include "registry.h"
#include "util.h"

void DeleteGraph(graph* g) {
    sqlite3_stmt* stmt;
    if ((sqlite3_prepare_v2(g->db, "DETACH DATABASE registry", -1, &stmt, NULL)
                != SQLITE_OK)
            || (sqlite3_step(stmt) != SQLITE_DONE)) {
        fprintf(stderr, "error: registry db not detached correctly (%s)\n",
                sqlite3_errmsg(g->db));
    }
    sqlite3_finalize(stmt);
    free(g);
}

graph* GetGraph(Tcl_Interp* interp, char* name) {
    return GetCtx(interp, name, "graph", GraphObjCmd);
}

int SetGraph(Tcl_Interp* interp, char* name, graph* g) {
    return SetCtx(interp, name, g, "graph", GraphObjCmd,
            (Tcl_CmdDeleteProc*)DeleteGraph);
}

/* graph create dbfile ?name? */
int GraphCreateCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    if (objc > 4 || objc < 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "dbfile ?name?");
        return TCL_ERROR;
    } else {
        sqlite3* db = RegistryDB(interp);
        sqlite3_stmt* stmt;
        int needsInit = 0;
        int len;
        char* file = Tcl_GetStringFromObj(objv[2], &len);
        char* query = sqlite3_mprintf("ATTACH DATABASE '%q' AS registry", file);

        if (Tcl_FSAccess(objv[2], F_OK) != 0) {
            needsInit = 1;
            printf("initializing\n");
        }

        if ((sqlite3_prepare_v2(db, query, -1, &stmt, NULL) == SQLITE_OK)
                && (sqlite3_step(stmt) == SQLITE_DONE)) {
            sqlite3_finalize(stmt);
            if (!needsInit
                    || ((sqlite3_prepare_v2(db, "CREATE TABLE registry.ports "
                                "(name, portfile, url, location, epoch, "
                                "version, revision, variants, state)", -1,
                                &stmt, NULL)
                            == SQLITE_OK)
                        && (sqlite3_step(stmt) == SQLITE_DONE))) {
                graph* g = malloc(sizeof(graph));
                sqlite3_free(query);
                if (!g) {
                    return TCL_ERROR;
                }
                g->db = db;
                if (objc == 4) {
                    /* graph create dbfile name */
                    if (SetGraph(interp, Tcl_GetString(objv[3]), g) == TCL_OK) {
                        Tcl_SetObjResult(interp, objv[3]);
                        return TCL_OK;
                    }
                } else {
                    /* graph create dbfile; generate a name */
                    char* name = unique_name(interp, "::registry::graph");
                    if (SetGraph(interp, name, g) == TCL_OK) {
                        Tcl_Obj* res = Tcl_NewStringObj(name, -1);
                        Tcl_SetObjResult(interp, res);
                        free(name);
                        return TCL_OK;
                    }
                    free(name);
                }
                free(g);
            }
        } else {
            set_sqlite_result(interp, db, query);
            sqlite3_free(query);
        }
        sqlite3_finalize(stmt);
        return TCL_ERROR;
    }
}

/* graph delete ?name ...? */
int GraphDeleteCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    int i;
    for (i=2; i<objc; i++) {
        graph* g;
        char* proc = Tcl_GetString(objv[i]);
        g = GetGraph(interp, proc);
        if (g == NULL) {
            return TCL_ERROR;
        } else {
            Tcl_DeleteCommand(interp, proc);
        }
    }
    return TCL_OK;
}

/* graph exists name */
int GraphExistsCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 2, objv, "name");
        return TCL_ERROR;
    }
    if (GetGraph(interp, Tcl_GetString(objv[2])) == NULL) {
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
    } else {
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(1));
    }
    return TCL_OK;
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
} GraphCmdType;

static GraphCmdType graph_cmds[] = {
    /* commands usable only by `graph` itself */
    { "create", GraphCreateCmd },
    { "delete", GraphDeleteCmd },
    { "exists", GraphExistsCmd },
    /* commands usable by `graph` or an instance thereof */
    /* { "install", GraphInstallCmd }, */
    /* { "uninstall", GraphUninstallCmd }, */
    /* { "activate", GraphActivateCmd }, */
    /* { "deactivate", GraphDeactivateCmd }, */
    /* { "upgrade", GraphUpgradeCmd }, */
    /* { "changed", GraphChangedCmd }, */
    /* { "warnings", GraphWarningsCmd }, */
    /* { "errors", GraphErrorsCmd }, */
    /* { "commit", GraphCommitCmd }, */
    /* { "rollback", GraphRollbackCmd }, */
    /* { "active", GraphActiveCmd }, */
    /* { "installed", GraphInstalledCmd }, */
    /* { "location", GraphLocationCmd }, */
    /* { "map", GraphMapCmd }, */
    /* { "unmap", GraphUnmapCmd }, */
    /* { "contents", GraphContentsCmd }, */
    /* { "provides", GraphProvidesCmd }, */
    { NULL, NULL }
};

/* graph cmd ?arg ...? */
int GraphCmd(ClientData clientData UNUSED, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], graph_cmds,
                sizeof(GraphCmdType), "cmd", 0, &cmd_index) == TCL_OK) {
        GraphCmdType* cmd = &graph_cmds[cmd_index];
        return cmd->function(interp, objc, objv);
    }
    return TCL_ERROR;
}

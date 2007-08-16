/*
 * graphobj.c
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

#include "graphobj.h"
#include "util.h"

/* ${graph} install registry::item */
int GraphObjInstallCmd(Tcl_Interp* interp, graph* g, int objc,
        Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "install registry::item");
        return TCL_ERROR;
    } else {
        printf("installing %s to %p\n", Tcl_GetString(objv[2]), (void*)g);
    }
    return TCL_OK;
}

/* ${graph} uninstall registry::item */
int GraphObjUninstallCmd(Tcl_Interp* interp, graph* g, int objc,
        Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "uninstall registry::item");
        return TCL_ERROR;
    } else {
        printf("uninstalling %s to %p\n", Tcl_GetString(objv[2]), (void*)g);
    }
    return TCL_OK;
}

/* ${graph} activate registry::item */
int GraphObjActivateCmd(Tcl_Interp* interp, graph* g, int objc,
        Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "activate registry::item");
        return TCL_ERROR;
    } else {
        printf("activating %s to %p\n", Tcl_GetString(objv[2]), (void*)g);
    }
    return TCL_OK;
}

/* ${graph} deactivate registry::item */
int GraphObjDeactivateCmd(Tcl_Interp* interp, graph* g, int objc,
        Tcl_Obj* CONST objv[]) {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "deactivate registry::item");
        return TCL_ERROR;
    } else {
        printf("deactivating %s to %p\n", Tcl_GetString(objv[2]), (void*)g);
    }
    return TCL_OK;
}

enum {
    BUBBLE_UP = 1,
    BUBBLE_DOWN = 2
};

/* ${graph} upgrade ?-bubble-up? ?-bubble-down? ?--? porturl */
int GraphObjUpgradeCmd(Tcl_Interp* interp, graph* g, int objc,
        Tcl_Obj* CONST objv[]) {
    option_spec options[] = {
        { "--", END_FLAGS },
        { "-bubble-up", BUBBLE_UP },
        { "-bubble-down", BUBBLE_DOWN },
        { NULL, 0 }
    };
    int flags;
    int start=2;
    if (ParseFlags(interp, objc, objv, &start, options, &flags) != TCL_OK) {
        return TCL_ERROR;
    }
    if (objc - start != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "upgrade ?-bubble-up? "
                "?--bubble-down? ?--? registry::item");
        return TCL_ERROR;
    } else {
        printf("upgrading %s to %p (flags %x)\n", Tcl_GetString(objv[start]),
                (void*)g, flags);
    }
    return TCL_OK;
}

typedef struct {
    char* name;
    int (*function)(Tcl_Interp*, graph*, int, Tcl_Obj* CONST objv[]);
} GraphObjCmdType;

static GraphObjCmdType graph_obj_cmds[] = {
    { "install", GraphObjInstallCmd },
    { "uninstall", GraphObjUninstallCmd },
    { "activate", GraphObjActivateCmd },
    { "deactivate", GraphObjDeactivateCmd },
    { "upgrade", GraphObjUpgradeCmd },
    { NULL, NULL }
};

/* ${graph} cmd ?arg ...? */
int GraphObjCmd(ClientData clientData, Tcl_Interp* interp, int objc,
        Tcl_Obj* CONST objv[]) {
    int cmd_index;
    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "cmd ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObjStruct(interp, objv[1], graph_obj_cmds,
                sizeof(GraphObjCmdType), "cmd", 0, &cmd_index) == TCL_OK) {
        GraphObjCmdType* cmd = &graph_obj_cmds[cmd_index];
        return cmd->function(interp, clientData, objc, objv);
    }
    return TCL_ERROR;
}

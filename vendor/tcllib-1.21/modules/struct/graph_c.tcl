# graphc.tcl --
#
#       Implementation of a graph data structure for Tcl.
#       This code based on critcl, API compatible to the PTI [x].
#       [x] Pure Tcl Implementation.
#
# Copyright (c) 2006,2019 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require critcl
# @sak notprovided struct_graphc
package provide struct_graphc 2.4.3
package require Tcl 8.2

namespace eval ::struct {
    # Supporting code for the main command.

    catch {
	#critcl::cheaders -g
	#critcl::debug memory symbols
    }

    critcl::cheaders graph/*.h
    critcl::csources graph/*.c

    critcl::ccode {
	/* -*- c -*- */

	#include <global.h>
	#include <objcmd.h>
	#include <graph.h>

	#define USAGE "?name ?=|:=|as|deserialize source??"

	static void gg_delete (ClientData clientData)
	{
	    /* Release the whole graph. */
	    g_delete ((G*) clientData);
	}
    }

    # Main command, graph creation.

    critcl::ccommand graph_critcl {dummy interp objc objv} {
	/* Syntax */
	/*  - epsilon                         |1 */
	/*  - name                            |2 */
	/*  - name =|:=|as|deserialize source |4 */

	CONST char* name;
	G*          g;
	Tcl_Obj*    fqn;
	Tcl_CmdInfo ci;

	if ((objc != 4) && (objc != 2) && (objc != 1)) {
	    Tcl_WrongNumArgs (interp, 1, objv, USAGE);
	    return TCL_ERROR;
	}

	if (objc < 2) {
	    name = gg_new (interp);
	} else {
	    name = Tcl_GetString (objv [1]);
	}

	if (!Tcl_StringMatch (name, "::*")) {
	    /* Relative name. Prefix with current namespace */

	    Tcl_Eval (interp, "namespace current");
	    fqn = Tcl_GetObjResult (interp);
	    fqn = Tcl_DuplicateObj (fqn);
	    Tcl_IncrRefCount (fqn);

	    if (!Tcl_StringMatch (Tcl_GetString (fqn), "::")) {
		Tcl_AppendToObj (fqn, "::", -1);
	    }
	    Tcl_AppendToObj (fqn, name, -1);
	} else {
	    fqn = Tcl_NewStringObj (name, -1);
	    Tcl_IncrRefCount (fqn);
	}

	Tcl_ResetResult (interp);

	if (Tcl_GetCommandInfo (interp, Tcl_GetString (fqn), &ci)) {
	    Tcl_Obj* err;

	    err = Tcl_NewObj ();
	    Tcl_AppendToObj    (err, "command \"", -1);
	    Tcl_AppendObjToObj (err, fqn);
	    Tcl_AppendToObj    (err, "\" already exists, unable to create graph", -1);

	    Tcl_DecrRefCount (fqn);
	    Tcl_SetObjResult (interp, err);
	    return TCL_ERROR;
	}

	if (objc == 4) {
	    /* Construction with immediate initialization */
	    /* through deserialization */

	    Tcl_Obj* type = objv[2];
	    Tcl_Obj* src  = objv[3];
	    int      srctype;

	    static CONST char* types [] = {
		":=", "=", "as", "deserialize", NULL
	    };
	    enum types {
		G_ASSIGN, G_IS, G_AS, G_DESER
	    };

	    if (Tcl_GetIndexFromObj (interp, type, types, "type", 0, &srctype) != TCL_OK) {
		Tcl_DecrRefCount (fqn);
		Tcl_ResetResult  (interp);
		Tcl_WrongNumArgs (interp, 1, objv, USAGE);
		return TCL_ERROR;
	    }

	    g = g_new ();

	    switch (srctype) {
		case G_ASSIGN:
		case G_AS:
		case G_IS:
		if (g_ms_assign (interp, g, src) != TCL_OK) {
		    g_delete (g);
		    Tcl_DecrRefCount (fqn);
		    return TCL_ERROR;
		}
		break;

		case G_DESER:
		if (g_deserialize (g, interp, src) != TCL_OK) {
		    g_delete (g);
		    Tcl_DecrRefCount (fqn);
		    return TCL_ERROR;
		}
		break;
	    }
	} else {
	    g = g_new ();
	}

	g->cmd = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
                                       g_objcmd, (ClientData) g,
                                       gg_delete);

	Tcl_SetObjResult (interp, fqn);
	Tcl_DecrRefCount (fqn);
	return TCL_OK;
    }
}

# ### ### ### ######### ######### #########
## Ready

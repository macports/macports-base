# treec.tcl --
#
#       Implementation of a tree data structure for Tcl.
#       This code based on critcl, API compatible to the PTI [x].
#       [x] Pure Tcl Implementation.
#
# Copyright (c) 2005 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: tree_c.tcl,v 1.6 2008/03/25 07:15:34 andreas_kupries Exp $

package require critcl
# @sak notprovided struct_treec
package provide struct_treec 2.1.1
package require Tcl 8.2

namespace eval ::struct {
    # Supporting code for the main command.

    catch {
	#critcl::cheaders -g
	#critcl::debug memory symbols
    }

    critcl::cheaders tree/*.h
    critcl::csources tree/*.c

    critcl::ccode {
	/* -*- c -*- */

	#include <util.h>
	#include <t.h>
	#include <tn.h>
	#include <ms.h>
	#include <m.h>

	/* .................................................. */
	/* Global tree management, per interp
	*/

	typedef struct TDg {
	    long int counter;
	    char buf [50];
	} TDg;

	static void
	TDgrelease (ClientData cd, Tcl_Interp* interp)
	{
	    ckfree((char*) cd);
	}

	static CONST char*
	TDnewName (Tcl_Interp* interp)
	{
#define KEY "tcllib/struct::tree/critcl"

	    Tcl_InterpDeleteProc* proc = TDgrelease;
	    TDg*                  tdg;

	    tdg = Tcl_GetAssocData (interp, KEY, &proc);
	    if (tdg  == NULL) {
		tdg = (TDg*) ckalloc (sizeof (TDg));
		tdg->counter = 0;

		Tcl_SetAssocData (interp, KEY, proc,
				  (ClientData) tdg);
	    }
	    
	    tdg->counter ++;
	    sprintf (tdg->buf, "tree%d", tdg->counter);
	    return tdg->buf;

#undef  KEY
	}

	static void
	TDdeleteCmd (ClientData clientData)
	{
	    /* Release the whole tree. */
	    t_delete ((T*) clientData);
	}
    }

    # Main command, tree creation.

    critcl::ccommand tree_critcl {dummy interp objc objv} {
      /* Syntax
       *  - epsilon                         |1
       *  - name                            |2
       *  - name =|:=|as|deserialize source |4
       */

      CONST char* name;
      T*          td;
      Tcl_Obj*    fqn;
      Tcl_CmdInfo ci;

#define USAGE "?name ?=|:=|as|deserialize source??"

      if ((objc != 4) && (objc != 2) && (objc != 1)) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGE);
        return TCL_ERROR;
      }

      if (objc < 2) {
        name = TDnewName (interp);
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

      if (Tcl_GetCommandInfo (interp,
                              Tcl_GetString (fqn),
                              &ci)) {
        Tcl_Obj* err;

        err = Tcl_NewObj ();
        Tcl_AppendToObj    (err, "command \"", -1);
        Tcl_AppendObjToObj (err, fqn);
        Tcl_AppendToObj    (err, "\" already exists, unable to create tree", -1);

        Tcl_DecrRefCount (fqn);
        Tcl_SetObjResult (interp, err);
        return TCL_ERROR;
      }

      if (objc == 4) {
        Tcl_Obj* type = objv[2];
        Tcl_Obj* src  = objv[3];
        int srctype;

        static CONST char* types [] = {
          ":=", "=", "as", "deserialize", NULL
        };
        enum types {
          T_ASSIGN, T_IS, T_AS, T_DESER
        };

        if (Tcl_GetIndexFromObj (interp, type, types, "type",
                                 0, &srctype) != TCL_OK) {
          Tcl_DecrRefCount (fqn);
          Tcl_ResetResult (interp);
          Tcl_WrongNumArgs (interp, 1, objv, USAGE);
          return TCL_ERROR;
        }

        td = t_new ();

        switch (srctype) {
        case T_ASSIGN:
        case T_AS:
        case T_IS:
          if (tms_assign (interp, td, src) != TCL_OK) {
            t_delete (td);
            Tcl_DecrRefCount (fqn);
            return TCL_ERROR;
          }
          break;

        case T_DESER:
          if (t_deserialize (td, interp, src) != TCL_OK) {
            t_delete (td);
            Tcl_DecrRefCount (fqn);
            return TCL_ERROR;
          }
          break;
        }
      } else {
        td = t_new ();
      }

      td->cmd = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
                                      tms_objcmd, (ClientData) td,
                                      TDdeleteCmd);

      Tcl_SetObjResult (interp, fqn);
      Tcl_DecrRefCount (fqn);
      return TCL_OK;
    }

  namespace eval tree {
    critcl::ccommand prune_critcl {dummy interp objc objv} {
      return 5;
    }
  }
}

# ### ### ### ######### ######### #########
## Ready

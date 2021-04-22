# stackc.tcl --
#
#       Implementation of a stack data structure for Tcl.
#       This code based on critcl, API compatible to the PTI [x].
#       [x] Pure Tcl Implementation.
#
# Copyright (c) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: stack_c.tcl,v 1.1 2008/06/19 23:03:35 andreas_kupries Exp $

package require critcl
# @sak notprovided struct_stackc
package provide struct_stackc 1.3.1
package require Tcl 8.4

namespace eval ::struct {
    # Supporting code for the main command.

    catch {
	#critcl::cheaders -g
	#critcl::debug memory symbols
    }

    critcl::cheaders stack/*.h
    critcl::csources stack/*.c

    critcl::ccode {
	/* -*- c -*- */

	#include <util.h>
	#include <s.h>
	#include <ms.h>
	#include <m.h>

	/* .................................................. */
	/* Global stack management, per interp
	*/

	typedef struct SDg {
	    long int counter;
	    char buf [50];
	} SDg;

	static void
	SDgrelease (ClientData cd, Tcl_Interp* interp)
	{
	    ckfree((char*) cd);
	}

	static CONST char*
	SDnewName (Tcl_Interp* interp)
	{
#define KEY "tcllib/struct::stack/critcl"

	    Tcl_InterpDeleteProc* proc = SDgrelease;
	    SDg*                  sdg;

	    sdg = Tcl_GetAssocData (interp, KEY, &proc);
	    if (sdg  == NULL) {
		sdg = (SDg*) ckalloc (sizeof (SDg));
		sdg->counter = 0;

		Tcl_SetAssocData (interp, KEY, proc,
				  (ClientData) sdg);
	    }
	    
	    sdg->counter ++;
	    sprintf (sdg->buf, "stack%ld", sdg->counter);
	    return sdg->buf;

#undef  KEY
	}

	static void
	SDdeleteCmd (ClientData clientData)
	{
	    /* Release the whole stack. */
	    st_delete ((S*) clientData);
	}
    }

    # Main command, stack creation.

    critcl::ccommand stack_critcl {dummy interp objc objv} {
      /* Syntax
       *  - epsilon                         |1
       *  - name                            |2
       */

      CONST char* name;
      S*          sd;
      Tcl_Obj*    fqn;
      Tcl_CmdInfo ci;

#define USAGE "?name?"

      if ((objc != 2) && (objc != 1)) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGE);
        return TCL_ERROR;
      }

      if (objc < 2) {
        name = SDnewName (interp);
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
        Tcl_AppendToObj    (err, "\" already exists, unable to create stack", -1);

        Tcl_DecrRefCount (fqn);
        Tcl_SetObjResult (interp, err);
        return TCL_ERROR;
      }

      sd = st_new();
      sd->cmd = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
				      stms_objcmd, (ClientData) sd,
				      SDdeleteCmd);

      Tcl_SetObjResult (interp, fqn);
      Tcl_DecrRefCount (fqn);
      return TCL_OK;
    }
}

# ### ### ### ######### ######### #########
## Ready

# -*- tcl -*-
#
# Copyright (c) 2009-2015 by Andreas Kupries <andreas_kupries@users.sourceforge.net>

# # ## ### ##### ######## ############# #####################
## Package description

## Implementation of the PackRat Machine (PARAM), a virtual machine on
## top of which parsers for Parsing Expression Grammars (PEGs) can be
## realized. This implementation is written in C, for parsers written in
## Tcl. As such the parsers themselves are tied to Tcl for control flow.
#
## RD stands for Recursive Descent.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.4
package require critcl
# @sak notprovided pt_rde_critcl
package provide pt_rde_critcl 1.3.4

# # ## ### ##### ######## ############# #####################
## Implementation

namespace eval ::pt {

    # # ## ### ##### ######## ############# #####################
    ## Supporting code for the main command.

    catch {
	#critcl::cheaders -g
	#critcl::debug memory symbols
    }

    critcl::cheaders rde_critcl/*.h
    critcl::csources rde_critcl/*.c

    critcl::ccode {
	/* -*- c -*- */

	#include <util.h>  /* Allocation macros */
	#include <p.h>     /* Public state API */
	#include <ms.h>    /* Instance command */

	/* .................................................. */
	/* Global PARAM management, per interp
	*/

	typedef struct PARAMg {
	    long int counter;
	    char     buf [50];
	} PARAMg;

	static void
	PARAMgRelease (ClientData cd, Tcl_Interp* interp)
	{
	    ckfree((char*) cd);
	}

	static CONST char*
	PARAMnewName (Tcl_Interp* interp)
	{
#define KEY "tcllib/pt::rde/critcl"

	    Tcl_InterpDeleteProc* proc = PARAMgRelease;
	    PARAMg*                  paramg;

	    paramg = Tcl_GetAssocData (interp, KEY, &proc);
	    if (paramg  == NULL) {
		paramg = (PARAMg*) ckalloc (sizeof (PARAMg));
		paramg->counter = 0;

		Tcl_SetAssocData (interp, KEY, proc,
				  (ClientData) paramg);
	    }
	    
	    paramg->counter ++;
	    sprintf (paramg->buf, "rde%ld", paramg->counter);
	    return paramg->buf;

#undef  KEY
	}

	static void
	PARAMdeleteCmd (ClientData clientData)
	{
	    /* Release the whole PARAM. */
	    param_delete ((RDE_STATE) clientData);
	}
    }

    # # ## ### ##### ######## ############# #####################
    ## Main command, PARAM creation.

    critcl::ccommand rde_critcl {dummy interp objc objv} {
      /* Syntax: No arguments beyond the name
       */

      CONST char* name;
      RDE_STATE   param;
      Tcl_Obj*    fqn;
      Tcl_CmdInfo ci;
      Tcl_Command c;

#define USAGE "?name?"

      if ((objc != 2) && (objc != 1)) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGE);
        return TCL_ERROR;
      }

      if (objc < 2) {
        name = PARAMnewName (interp);
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
        Tcl_AppendToObj    (err, "\" already exists", -1);

        Tcl_DecrRefCount (fqn);
        Tcl_SetObjResult (interp, err);
        return TCL_ERROR;
      }

      param = param_new ();
      c = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
				paramms_objcmd, (ClientData) param,
				PARAMdeleteCmd);
      param_setcmd (param, c);

      Tcl_SetObjResult (interp, fqn);
      Tcl_DecrRefCount (fqn);
      return TCL_OK;
    }
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::rde::critcl 1.3.4
return

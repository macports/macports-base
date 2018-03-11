# queuec.tcl --
#
#       Implementation of a queue data structure for Tcl.
#       This code based on critcl, API compatible to the PTI [x].
#       [x] Pure Tcl Implementation.
#
# Copyright (c) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: queue_c.tcl,v 1.2 2011/04/21 17:51:55 andreas_kupries Exp $

package require critcl
# @sak notprovided struct_queuec
package provide struct_queuec 1.3.1
package require Tcl 8.4

namespace eval ::struct {
    # Supporting code for the main command.

    critcl::cheaders queue/*.h
    critcl::csources queue/*.c

    critcl::ccode {
	/* -*- c -*- */

	#include <util.h>
	#include <q.h>
	#include <ms.h>
	#include <m.h>

	/* .................................................. */
	/* Global queue management, per interp
	*/

	typedef struct QDg {
	    long int counter;
	    char buf [50];
	} QDg;

	static void
	QDgrelease (ClientData cd, Tcl_Interp* interp)
	{
	    ckfree((char*) cd);
	}

	static CONST char*
	QDnewName (Tcl_Interp* interp)
	{
#define KEY "tcllib/struct::queue/critcl"

	    Tcl_InterpDeleteProc* proc = QDgrelease;
	    QDg*                  qdg;

	    qdg = Tcl_GetAssocData (interp, KEY, &proc);
	    if (qdg  == NULL) {
		qdg = (QDg*) ckalloc (sizeof (QDg));
		qdg->counter = 0;

		Tcl_SetAssocData (interp, KEY, proc,
				  (ClientData) qdg);
	    }
	    
	    qdg->counter ++;
	    sprintf (qdg->buf, "queue%d", qdg->counter);
	    return qdg->buf;

#undef  KEY
	}

	static void
	QDdeleteCmd (ClientData clientData)
	{
	    /* Release the whole queue. */
	    qu_delete ((Q*) clientData);
	}
    }

    # Main command, queue creation.

    critcl::ccommand queue_critcl {dummy interp objc objv} {
      /* Syntax
       *  - epsilon                         |1
       *  - name                            |2
       */

      CONST char* name;
      Q*          qd;
      Tcl_Obj*    fqn;
      Tcl_CmdInfo ci;

#define USAGE "?name?"

      if ((objc != 2) && (objc != 1)) {
        Tcl_WrongNumArgs (interp, 1, objv, USAGE);
        return TCL_ERROR;
      }

      if (objc < 2) {
        name = QDnewName (interp);
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
        Tcl_AppendToObj    (err, "\" already exists, unable to create queue", -1);

        Tcl_DecrRefCount (fqn);
        Tcl_SetObjResult (interp, err);
        return TCL_ERROR;
      }

      qd = qu_new();
      qd->cmd = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
				      qums_objcmd, (ClientData) qd,
				      QDdeleteCmd);

      Tcl_SetObjResult (interp, fqn);
      Tcl_DecrRefCount (fqn);
      return TCL_OK;
    }
}

# ### ### ### ######### ######### #########
## Ready

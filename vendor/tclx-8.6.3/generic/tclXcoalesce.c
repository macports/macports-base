/*
 * tclXcoalesce.c --
 *
 *  coalesce Tcl commands.
 *-----------------------------------------------------------------------------
 * Copyright 2017 - 2019 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"


/*-----------------------------------------------------------------------------
 * TclX_CoalesceObjCmd --
 *     Implements the TCL coalesce command:
 *     coalesce ?-default value? var ?var...?
 *
 * Results:
 *  The value of the first existing variable is returned.
 *  If no variables exist, the default value is returned.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_CoalesceObjCmd (ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    int i;
    Tcl_Obj *val;
    int start = 1;

    if (objc < 2) {
      badargs:
        return TclX_WrongArgs (interp, objv [0], "?-default value? var ?var...?");
    }

    /* is -default specified? if so, handle */
    char *first = Tcl_GetString (objv[1]);
    if (STREQU (first, "-default")) {
        if (objc < 4) goto badargs;
        start = 3;
    }

    /* iterate through the variable list */
    for (i = start; i < objc; i++) {
        /* if the var exists, return its value */
        if ((val = Tcl_ObjGetVar2 (interp, objv [i], NULL, 0)) != NULL) {
            Tcl_SetObjResult (interp, val);
            return TCL_OK;
        }
    }

    /* none of the vars exist, if no default was specified, return an empty string */
    if (start == 1) {
        Tcl_SetObjResult (interp, Tcl_NewObj ());
        return TCL_OK;
    }

    /* none of the vars exist and a default was specified, return it*/
    Tcl_SetObjResult (interp, objv[start - 1]);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_CoalesceInit --
 *     Initialize the coalesce command.
 *-----------------------------------------------------------------------------
 */
void
TclX_CoalesceInit (Tcl_Interp *interp)
{
    Tcl_CreateObjCommand (interp,
			  "coalesce",
			  TclX_CoalesceObjCmd,
              (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "tcl::mathfunc::coalesce",
			  TclX_CoalesceObjCmd,
              (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}

/* vim: set ts=4 sw=4 sts=4 et : */

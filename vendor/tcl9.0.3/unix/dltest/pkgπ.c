/*
 * pkgπ.c --
 *
 *	This file contains a simple Tcl package "pkgπ" that is intended for
 *	testing the Tcl dynamic loading facilities.
 *
 * Copyright © 1995 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#undef STATIC_BUILD
#include "tcl.h"

/*
 *----------------------------------------------------------------------
 *
 * Pkga_EqObjCmd --
 *
 *	This procedure is invoked to process the "pkga_eq" Tcl command. It
 *	expects two arguments and returns 1 if they are the same, 0 if they
 *	are different.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
Pkg\u03C0_\u03A0ObjCmd(
    void *dummy,		/* Not used. */
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    (void)dummy;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv,  "");
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewDoubleObj(3.14159));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Pkgπ_Init --
 *
 *	This is a package initialization procedure, which is called by Tcl
 *	when this package is to be added to an interpreter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

DLLEXPORT int
Pkg\u03C0_Init(
    Tcl_Interp *interp)		/* Interpreter in which the package is to be
				 * made available. */
{
    int code;

    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) {
	return TCL_ERROR;
    }
    code = Tcl_PkgProvide(interp, "pkgπ", "1.0");
    if (code != TCL_OK) {
	return code;
    }
    Tcl_CreateObjCommand(interp, "π", Pkg\u03C0_\u03A0ObjCmd, NULL, NULL);
    return TCL_OK;
}

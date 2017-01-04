/*
 * pkga.c --
 *
 *	This file contains a simple Tcl package "pkga" that is intended for
 *	testing the Tcl dynamic loading facilities.
 *
 * Copyright (c) 1995 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tcl.h"

/*
 * Prototypes for procedures defined later in this file:
 */

static int    Pkga_EqObjCmd(ClientData clientData,
		Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
static int    Pkga_QuoteObjCmd(ClientData clientData,
		Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);

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
Pkga_EqObjCmd(
    ClientData dummy,		/* Not used. */
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *CONST objv[])	/* Argument objects. */
{
    int result;
    CONST char *str1, *str2;
    int len1, len2;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv,  "string1 string2");
	return TCL_ERROR;
    }

    str1 = Tcl_GetStringFromObj(objv[1], &len1);
    str2 = Tcl_GetStringFromObj(objv[2], &len2);
    if (len1 == len2) {
	result = (Tcl_UtfNcmp(str1, str2, len1) == 0);
    } else {
	result = 0;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(result));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Pkga_QuoteObjCmd --
 *
 *	This procedure is invoked to process the "pkga_quote" Tcl command. It
 *	expects one argument, which it returns as result.
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
Pkga_QuoteObjCmd(
    ClientData dummy,		/* Not used. */
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *CONST objv[])	/* Argument strings. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "value");
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, objv[1]);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Pkga_Init --
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

int
Pkga_Init(
    Tcl_Interp *interp)		/* Interpreter in which the package is to be
				 * made available. */
{
    int code;

    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
	return TCL_ERROR;
    }
    code = Tcl_PkgProvide(interp, "Pkga", "1.0");
    if (code != TCL_OK) {
	return code;
    }
    Tcl_CreateObjCommand(interp, "pkga_eq", Pkga_EqObjCmd,
	    (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "pkga_quote", Pkga_QuoteObjCmd,
	    (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    return TCL_OK;
}

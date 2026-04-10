/*
 * pkgt.c --
 *
 *	This file contains a simple Tcl package "pkgt" that is intended for
 *	testing the Tcl dynamic loading facilities.
 *
 * Copyright © 1995 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#undef STATIC_BUILD
#include "tcl.h"

static int TraceProc2 (
    void *clientData,
    Tcl_Interp *interp,
    Tcl_Size level,
    const char *command,
    Tcl_Command commandInfo,
    Tcl_Size objc,
    struct Tcl_Obj *const *objv)
{
    (void)clientData;
    (void)interp;
    (void)level;
    (void)command;
    (void)commandInfo;
    (void)objc;
    (void)objv;

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Pkgt_EqObjCmd2 --
 *
 *	This procedure is invoked to process the "pkgt_eq" Tcl command. It
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
Pkgt_EqObjCmd2(
    void *dummy,		/* Not used. */
    Tcl_Interp *interp,		/* Current interpreter. */
    Tcl_Size objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_WideInt result;
    const char *str1, *str2;
    Tcl_Size len1, len2;
    (void)dummy;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv,  "string1 string2");
	return TCL_ERROR;
    }

    str1 = Tcl_GetStringFromObj(objv[1], &len1);
    str2 = Tcl_GetStringFromObj(objv[2], &len2);
    len1 = Tcl_NumUtfChars(str1, len1);
    len2 = Tcl_NumUtfChars(str2, len2);
    if (len1 == len2) {
	result = (Tcl_UtfNcmp(str1, str2, (size_t)len1) == 0);
    } else {
	result = 0;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(result));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Pkgt_Init --
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
Pkgt_Init(
    Tcl_Interp *interp)		/* Interpreter in which the package is to be
				 * made available. */
{
    int code;

    if (Tcl_InitStubs(interp, "9.0-", 0) == NULL) {
	return TCL_ERROR;
    }
    code = Tcl_PkgProvide(interp, "pkgt", "1.0");
    if (code != TCL_OK) {
	return code;
    }
    Tcl_CreateObjCommand2(interp, "pkgt_eq", Pkgt_EqObjCmd2, NULL, NULL);
    Tcl_CreateObjTrace2(interp, 0, 0, TraceProc2, NULL, NULL);
    return TCL_OK;
}

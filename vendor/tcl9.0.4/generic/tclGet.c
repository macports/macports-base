/*
 * tclGet.c --
 *
 *	This file contains functions to convert strings into other forms, like
 *	integers or floating-point numbers or booleans, doing syntax checking
 *	along the way.
 *
 * Copyright © 1990-1993 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetInt --
 *
 *	Given a string, produce the corresponding integer value.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *intPtr will be set
 *	to the integer value equivalent to src.  If src is improperly formed
 *	then TCL_ERROR is returned and an error message will be left in the
 *	interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetInt(
    Tcl_Interp *interp,		/* Interpreter to use for error reporting. */
    const char *src,		/* String containing a (possibly signed)
				 * integer in a form acceptable to
				 * Tcl_GetIntFromObj(). */
    int *intPtr)		/* Place to store converted result. */
{
    Tcl_Obj obj;
    int code;

    obj.refCount = 1;
    obj.bytes = (char *) src;
    obj.length = strlen(src);
    obj.typePtr = NULL;

    code = Tcl_GetIntFromObj(interp, &obj, intPtr);
    if (obj.refCount > 1) {
	Tcl_Panic("invalid sharing of Tcl_Obj on C stack");
    }
    TclFreeInternalRep(&obj);
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetDouble --
 *
 *	Given a string, produce the corresponding double-precision
 *	floating-point value.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *doublePtr will be
 *	set to the double-precision value equivalent to src. If src is
 *	improperly formed then TCL_ERROR is returned and an error message will
 *	be left in the interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetDouble(
    Tcl_Interp *interp,		/* Interpreter used for error reporting. */
    const char *src,		/* String containing a floating-point number
				 * in a form acceptable to
				 * Tcl_GetDoubleFromObj(). */
    double *doublePtr)		/* Place to store converted result. */
{
    Tcl_Obj obj;
    int code;

    obj.refCount = 1;
    obj.bytes = (char *) src;
    obj.length = strlen(src);
    obj.typePtr = NULL;

    code = Tcl_GetDoubleFromObj(interp, &obj, doublePtr);
    if (obj.refCount > 1) {
	Tcl_Panic("invalid sharing of Tcl_Obj on C stack");
    }
    TclFreeInternalRep(&obj);
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetBoolean --
 *
 *	Given a string, return a 0/1 boolean value corresponding to the
 *	string.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *charPtr will be set
 *	to the 0/1 value equivalent to src. If src is improperly formed then
 *	TCL_ERROR is returned and an error message will be left in the
 *	interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_GetBool
#undef Tcl_GetBoolFromObj
int
Tcl_GetBool(
    Tcl_Interp *interp,		/* Interpreter used for error reporting. */
    const char *src,		/* String containing one of the boolean values
				 * 1, 0, true, false, yes, no, on, off. */
    int flags,
    char *charPtr)		/* Place to store converted result, which will
				 * be 0 or 1. */
{
    Tcl_Obj obj;
    int code;

    if ((src == NULL) || (*src == '\0')) {
	return Tcl_GetBoolFromObj(interp, NULL, flags, charPtr);
    }
    obj.refCount = 1;
    obj.bytes = (char *) src;
    obj.length = strlen(src);
    obj.typePtr = NULL;

    code = TclSetBooleanFromAny(interp, &obj);
    if (obj.refCount > 1) {
	Tcl_Panic("invalid sharing of Tcl_Obj on C stack");
    }
    if (code == TCL_OK) {
	Tcl_GetBoolFromObj(NULL, &obj, flags, charPtr);
    }
    return code;
}

#undef Tcl_GetBoolean
int
Tcl_GetBoolean(
    Tcl_Interp *interp,		/* Interpreter used for error reporting. */
    const char *src,		/* String containing one of the boolean values
				 * 1, 0, true, false, yes, no, on, off. */
    int *intPtr)		/* Place to store converted result, which will
				 * be 0 or 1. */
{
    return Tcl_GetBool(interp, src, (TCL_NULL_OK-2)&(int)sizeof(int), (char *)(void *)intPtr);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

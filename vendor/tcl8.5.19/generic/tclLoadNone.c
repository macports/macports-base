/*
 * tclLoadNone.c --
 *
 *	This procedure provides a version of the TclLoadFile for use in
 *	systems that don't support dynamic loading; it just returns an error.
 *
 * Copyright (c) 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/*
 *----------------------------------------------------------------------
 *
 * TclpDlopen --
 *
 *	This procedure is called to carry out dynamic loading of binary code;
 *	it is intended for use only on systems that don't support dynamic
 *	loading (it returns an error).
 *
 * Results:
 *	The result is TCL_ERROR, and an error message is left in the interp's
 *	result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclpDlopen(
    Tcl_Interp *interp,		/* Used for error reporting. */
    Tcl_Obj *pathPtr,		/* Name of the file containing the desired
				 * code (UTF-8). */
    Tcl_LoadHandle *loadHandle,	/* Filled with token for dynamically loaded
				 * file which will be passed back to
				 * (*unloadProcPtr)() to unload the file. */
    Tcl_FSUnloadFileProc **unloadProcPtr)
				/* Filled with address of Tcl_FSUnloadFileProc
				 * function which should be used for this
				 * file. */
{
    Tcl_SetResult(interp,
	    "dynamic loading is not currently available on this system",
	    TCL_STATIC);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFindSymbol --
 *
 *	Looks up a symbol, by name, through a handle associated with a
 *	previously loaded piece of code (shared library). This version of this
 *	routine should never be called because the associated TclpDlopen()
 *	function always returns an error.
 *
 * Results:
 *	Returns a pointer to the function associated with 'symbol' if it is
 *	found. Otherwise returns NULL and may leave an error message in the
 *	interp's result.
 *
 *----------------------------------------------------------------------
 */

Tcl_PackageInitProc *
TclpFindSymbol(
    Tcl_Interp *interp,
    Tcl_LoadHandle loadHandle,
    CONST char *symbol)
{
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * TclGuessPackageName --
 *
 *	If the "load" command is invoked without providing a package name,
 *	this procedure is invoked to try to figure it out.
 *
 * Results:
 *	Always returns 0 to indicate that we couldn't figure out a package
 *	name; generic code will then try to guess the package from the file
 *	name. A return value of 1 would have meant that we figured out the
 *	package name and put it in bufPtr.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclGuessPackageName(
    CONST char *fileName,	/* Name of file containing package (already
				 * translated to local form if needed). */
    Tcl_DString *bufPtr)	/* Initialized empty dstring. Append package
				 * name to this if possible. */
{
    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpUnloadFile --
 *
 *    This procedure is called to carry out dynamic unloading of binary code;
 *    it is intended for use only on systems that don't support dynamic
 *    loading (it does nothing).
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

void
TclpUnloadFile(
    Tcl_LoadHandle loadHandle)	/* loadHandle returned by a previous call to
				 * TclpDlopen(). The loadHandle is a token
				 * that represents the loaded file. */
{
}

/*
 * These functions are fallbacks if we somehow determine that the platform can
 * do loading from memory but the user wishes to disable it. They just report
 * (gracefully) that they fail.
 */

#ifdef TCL_LOAD_FROM_MEMORY

MODULE_SCOPE void *
TclpLoadMemoryGetBuffer(
    Tcl_Interp *interp,		/* Dummy: unused by this implementation */
    int size)			/* Dummy: unused by this implementation */
{
    return NULL;
}

MODULE_SCOPE int
TclpLoadMemory(
    Tcl_Interp *interp,		/* Used for error reporting. */
    void *buffer,		/* Dummy: unused by this implementation */
    int size,			/* Dummy: unused by this implementation */
    int codeSize,		/* Dummy: unused by this implementation */
    Tcl_LoadHandle *loadHandle,	/* Dummy: unused by this implementation */
    Tcl_FSUnloadFileProc **unloadProcPtr)
				/* Dummy: unused by this implementation */
{
    Tcl_SetResult(interp, "dynamic loading from memory is not available "
	    "on this system", TCL_STATIC);
    return TCL_ERROR;
}

#endif /* TCL_LOAD_FROM_MEMORY */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

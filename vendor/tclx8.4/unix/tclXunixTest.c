/* 
 * tclXunixTest.c --
 *
 * Tcl_AppInit and main functions for the Extended Tcl test program on Unix.
 *
 *-----------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXunixTest.c,v 8.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

extern int
Tcltest_Init _ANSI_ARGS_((Tcl_Interp *interp));

extern int
Tclxtest_Init _ANSI_ARGS_((Tcl_Interp *interp));

/*
 * The following variable is a special hack that insures the tcl
 * version of matherr() is used when linking against shared libraries.
 * Even if matherr is not used on this system, there is a dummy version
 * in libtcl.
 */
extern int matherr ();
int (*tclDummyMathPtr)() = matherr;

/*-----------------------------------------------------------------------------
 * main --
 * This is the main program for the application.
 *-----------------------------------------------------------------------------
 */
int
main (argc, argv)
    int    argc;
    char **argv;
{
    TclX_Main (argc, argv, Tcl_AppInit);
    return 0;			/* Needed only to prevent compiler warning. */
}


/*-----------------------------------------------------------------------------
 * Tcl_AppInit --
 *  Initialize TclX test application.
 *
 * Results:
 *   Returns a standard Tcl completion code, and leaves an error message in
 * interp result if an error occurs.
 *-----------------------------------------------------------------------------
 */
int
Tcl_AppInit (interp)
    Tcl_Interp *interp;
{
    if (Tcl_Init (interp) == TCL_ERROR) {
        return TCL_ERROR;
    }

    if (Tclx_Init (interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage (interp, "Tclx", Tclx_Init, Tclx_SafeInit);

    if (Tcltest_Init (interp) == TCL_ERROR) {
	return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, "Tcltest", Tcltest_Init,
                      (Tcl_PackageInitProc *) NULL);

    if (Tclxtest_Init (interp) == TCL_ERROR) {
	return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, "Tclxtest", Tclxtest_Init,
                      (Tcl_PackageInitProc *) NULL);
    return TCL_OK;
}



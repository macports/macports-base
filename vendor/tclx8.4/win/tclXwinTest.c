/* 
 * tclXwinTest.c --
 *
 * Provides a test version of the Tcl_AppInit procedure for use with
 * applications built with Extended Tcl on  Windows 95/NT systems.
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
 * $Id: tclXwinTest.c,v 1.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtend.h"

extern int
Tcltest_Init (Tcl_Interp *interp);

extern int
Tclxtest_Init (Tcl_Interp *interp);


/*-----------------------------------------------------------------------------
 * main --
 *
 * This is the main program for the application.
 *-----------------------------------------------------------------------------
 */
int
main (int    argc,
      char **argv)
{
    TclX_Main (argc, argv, Tcl_AppInit);
    return 0;                   /* Needed only to prevent compiler warning. */
}


/*-----------------------------------------------------------------------------
 * Tcl_AppInit --
 *
 * This procedure performs application-specific initialization.  Most
 * applications, especially those that incorporate additional packages, will
 * have their own version of this procedure.
 *
 * Results:
 *   Returns a standard Tcl completion code, and leaves an error message in
 *  interp result if an error occurs.
 *-----------------------------------------------------------------------------
 */
int
Tcl_AppInit (Tcl_Interp *interp)
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



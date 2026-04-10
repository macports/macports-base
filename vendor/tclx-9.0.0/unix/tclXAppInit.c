/*
 * tclXAppInit.c --
 *
 * Provides a default version of the Tcl_AppInit procedure for use with
 * applications built with Extended Tcl on Unix systems.
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
 * $Id: tclXAppInit.c,v 8.4 1999/03/31 06:37:53 markd Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtend.h"

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
 *
 * This is the main program for the application.
 *-----------------------------------------------------------------------------
 */
int
main (int    argc,
      char **argv)
{
    TclX_Main(argc, argv, Tcl_AppInit);
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
Tcl_AppInit (Tcl_Interp *interp)
{
    if (Tcl_Init (interp) == TCL_ERROR) {
        return TCL_ERROR;
    }

    if (Tclx_Init (interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage (interp, "Tclx", Tclx_Init, Tclx_SafeInit);

    /*
     * Call Tcl_CreateCommand for application-specific commands, if
     * they weren't already created by the init procedures called above.
     */

    /*
     * Specify a user-specific startup file to invoke if the application
     * is run interactively.  Typically the startup file is "~/.apprc"
     * where "app" is the name of the application.  If this line is deleted
     * then no user-specific startup file will be run under any conditions.
     */
    Tcl_SetVar(interp, "tcl_rcFileName", "~/.tclrc", TCL_GLOBAL_ONLY);
    return TCL_OK;
}

/* vim: set ts=4 sw=4 sts=4 et : */

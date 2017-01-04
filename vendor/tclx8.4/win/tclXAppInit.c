/* 
 * tclXAppInit.c --
 *
 * Provides a default version of the Tcl_AppInit procedure for use with
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
 * $Id: tclXAppInit.c,v 1.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

/*
 * As a shell (i.e., the main program) we cannot be using the stubs table.
 */
#ifdef USE_TCL_STUBS
#undef USE_TCL_STUBS
#endif

#include "tclExtend.h"

/*-----------------------------------------------------------------------------
 * TclX_AppInit --
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
TclX_AppInit (Tcl_Interp *interp)
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
    TclX_MainEx (argc, argv, TclX_AppInit, Tcl_CreateInterp());

    return 0;                   /* Needed only to prevent compiler warning. */
}


/*
 * tclXwinCmds.c --
 *
 * Tcl commands to access Win32 functionality and stubs for Unix commands that
 * are not implemented.
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
 * $Id: tclXwinCmds.c,v 1.2 2002/04/04 06:13:02 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

static int 
TclX_ChrootObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp, 
			      int         objc,
			      Tcl_Obj     *CONST objv[]));

static int 
TclX_TimesObjCmd _ANSI_ARGS_((ClientData   clientData,
                             Tcl_Interp  *interp,
			     int          objc,
			     Tcl_Obj      *CONST objv[]));


/*-----------------------------------------------------------------------------
 * Tcl_ChrootObjCmd --
 *   Stub to return an error if the chroot command is used on Windows.
 *-----------------------------------------------------------------------------
 */
static int
TclX_ChrootObjCmd (ClientData  clientData,
                  Tcl_Interp *interp,
                  int         objc,
                  Tcl_Obj   *CONST objv[])
{
    return TclXNotAvailableObjError (interp, objv [0]);
}

/*-----------------------------------------------------------------------------
 * Tcl_TimesObjCmd --
 *   Stub to return an error if the times command is used on Windows.
 *-----------------------------------------------------------------------------
 */
static int
TclX_TimesObjCmd (ClientData  clientData,
                 Tcl_Interp *interp,
                 int         objc,
                 Tcl_Obj   *CONST objv[])
{
    return TclXNotAvailableObjError (interp, objv [0]);
}

/*-----------------------------------------------------------------------------
 * TclX_PlatformCmdsInit --
 *     Initialize the platform-specific commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_PlatformCmdsInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
			  "chroot",
			  TclX_ChrootObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc *) NULL);

    Tcl_CreateObjCommand (interp, 
			  "times",
			  TclX_TimesObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
    
}


/*-----------------------------------------------------------------------------
 * TclX_ServerInit --
 *     
 *   Stub, does nothing.  The Unix version of the function initilizes some
 * compatiblity functions that are not implemented on Win32.
 *-----------------------------------------------------------------------------
 */
void
TclX_ServerInit (Tcl_Interp *interp)
{
}

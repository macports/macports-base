/*
 * tclXunixCmds.c --
 *
 * Tcl commands to access unix system calls that are not portable to other
 * platforms.
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
 * $Id: tclXunixCmds.c,v 8.1 2001/10/24 23:31:50 hobbs Exp $
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
 * TclX_ChrootObjCmd --
 *     Implements the TCL chroot command:
 *         chroot path
 *
 * Results:
 *      Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_ChrootObjCmd (clientData, interp, objc, objv)
       ClientData  clientData;
       Tcl_Interp *interp;
       int         objc;
       Tcl_Obj   *CONST objv[];
{
    char   *chrootString;
    int     chrootStrLen;

    if (objc != 2)
	return TclX_WrongArgs (interp, objv [0], "path");

    chrootString = Tcl_GetStringFromObj (objv [1], &chrootStrLen);

    if (chroot (chrootString) < 0) {
        TclX_AppendObjResult (interp, "changing root to \"", chrootString,
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_TimesObjCmd --
 *     Implements the TCL times command:
 *     times
 *
 * Results:
 *  Standard TCL results.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_TimesObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    struct tms tm;
    char       timesBuf [48];

    if (objc != 1)
	return TclX_WrongArgs (interp, objv [0], "");

    times (&tm);

    sprintf (timesBuf, "%ld %ld %ld %ld", 
             (long) TclXOSTicksToMS (tm.tms_utime),
             (long) TclXOSTicksToMS (tm.tms_stime),
             (long) TclXOSTicksToMS (tm.tms_cutime),
             (long) TclXOSTicksToMS (tm.tms_cstime));

    Tcl_SetStringObj (Tcl_GetObjResult (interp), timesBuf, -1);
    return TCL_OK;
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


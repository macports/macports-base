/*
 * tclXwinId.c --
 *
 * Win32 version of the id command.
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
 * $Id: tclXwinId.c,v 1.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Prototypes of internal functions.
 */
static int
IdProcess  _ANSI_ARGS_((Tcl_Interp *interp,
			int objc,
			Tcl_Obj *CONST objv[]));

static int
IdHost _ANSI_ARGS_((Tcl_Interp *interp,
		    int objc,
		    Tcl_Obj *CONST objv[]));

static int 
TclX_IdObjCmd _ANSI_ARGS_((ClientData clientData,
                           Tcl_Interp *interp,
                           int objc,
                           Tcl_Obj *CONST objv[]));

/*-----------------------------------------------------------------------------
 * Tcl_IdCmd --
 *     Implements the TclX id command on Win32.
 *
 *        id host
 *        id process
 *
 * Results:
 *  Standard TCL results, may return the Posix system error message.
 *
 *-----------------------------------------------------------------------------
 */

/*
 * id process
 */
static int
IdProcess (interp, objc, objv)
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *resultPtr = Tcl_GetObjResult (interp);

    if (objc != 2) {
        TclX_AppendObjResult (interp, tclXWrongArgs, objv [0], 
                              " process", (char *) NULL);
        return TCL_ERROR;
    }
    Tcl_SetLongObj (resultPtr, getpid());
    return TCL_OK;
}

/*
 * id host
 */
static int
IdHost (interp, objc, objv)
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    char hostName [TCL_RESULT_SIZE];

    if (objc != 2) {
        TclX_AppendObjResult (interp, tclXWrongArgs, objv [0], 
                              " host", (char *) NULL);
        return TCL_ERROR;
    }
    if (gethostname (hostName, sizeof (hostName)) < 0) {
        TclX_AppendObjResult (interp, "failed to get host name: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    TclX_AppendObjResult (interp, hostName, (char *) NULL);
    return TCL_OK;
}

static int
TclX_IdObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    char *optionPtr;

    if (objc < 2) {
        TclX_AppendObjResult (interp, tclXWrongArgs, objv [0], " arg ?arg...?",
                              (char *) NULL);
        return TCL_ERROR;
    }

    optionPtr = Tcl_GetStringFromObj (objv[1], NULL);

    /*
     * If the first argument is "process", return the process ID, parent's
     * process ID, process group or set the process group depending on args.
     */
    if (STREQU (optionPtr, "process")) {
        return IdProcess (interp, objc, objv);
    }

    /*
     * Handle returning the host name if its available.
     */
    if (STREQU (optionPtr, "host")) {
        return IdHost (interp, objc, objv);
    }

    TclX_AppendObjResult (interp, "second arg must be one of \"process\", ",
                          "or \"host\"", (char *) NULL);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_IdInit --
 *     Initialize the id command.
 *-----------------------------------------------------------------------------
 */
void
TclX_IdInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
			  "id",
			  TclX_IdObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}


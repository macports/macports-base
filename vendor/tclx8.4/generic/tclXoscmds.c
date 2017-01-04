/*
 * tclXoscmds.c --
 *
 * Tcl commands to access unix system calls that are portable to other
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
 * $Id: tclXoscmds.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

static int 
TclX_AlarmObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));

static int 
TclX_LinkObjCmd _ANSI_ARGS_((ClientData clientData,
                             Tcl_Interp *interp,
                             int objc,
                             Tcl_Obj *CONST objv[]));

static int 
TclX_NiceObjCmd _ANSI_ARGS_((ClientData clientData,
                             Tcl_Interp *interp,
                             int objc,
                             Tcl_Obj *CONST objv[]));

static int 
TclX_SleepObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));

static int 
TclX_SyncObjCmd _ANSI_ARGS_((ClientData clientData,
                             Tcl_Interp *interp,
                             int objc,
                             Tcl_Obj *CONST objv[]));

static int 
TclX_SystemObjCmd _ANSI_ARGS_((ClientData clientData,
                               Tcl_Interp *interp,
                               int objc,
                               Tcl_Obj *CONST objv[]));

static int 
TclX_UmaskObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * TclX_AlarmObjCmd --
 *     Implements the TCL Alarm command:
 *         alarm seconds
 *
 * Results:
 *      Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_AlarmObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    double seconds;

    if (objc != 2)
	return TclX_WrongArgs (interp, objv [0], "seconds");

    if (Tcl_GetDoubleFromObj (interp, objv[1], &seconds) != TCL_OK)
	return TCL_ERROR;

    if (TclXOSsetitimer (interp, &seconds, "alarm") != TCL_OK)
        return TCL_ERROR;

    Tcl_SetDoubleObj (Tcl_GetObjResult (interp), seconds);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_LinkObjCmd --
 *     Implements the TCL link command:
 *         link ?-sym? srcpath destpath
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *-----------------------------------------------------------------------------
 */
static int
TclX_LinkObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    char *srcPath, *destPath;
    Tcl_DString  srcPathBuf, destPathBuf;
    char *argv0String;
    char *srcPathString;
    char *destPathString;

    Tcl_DStringInit (&srcPathBuf);
    Tcl_DStringInit (&destPathBuf);

    if ((objc < 3) || (objc > 4))
	return TclX_WrongArgs (interp, objv [0], "?-sym? srcpath destpath");

    if (objc == 4) {
        char *argv1String = Tcl_GetStringFromObj (objv [1], NULL);

        if (!STREQU (argv1String, "-sym")) {
            TclX_AppendObjResult (interp,
                                  "invalid option, expected: \"-sym\", got: ",
                                  Tcl_GetStringFromObj (objv [1], NULL),
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }

    srcPathString = Tcl_GetStringFromObj (objv [objc - 2], NULL);
    srcPath = Tcl_TranslateFileName (interp, srcPathString, &srcPathBuf);
    if (srcPath == NULL)
        goto errorExit;

    destPathString = Tcl_GetStringFromObj (objv [objc - 1], NULL);
    destPath = Tcl_TranslateFileName (interp, destPathString, &destPathBuf);
    if (destPath == NULL)
        goto errorExit;

    argv0String = Tcl_GetStringFromObj (objv [0], NULL);
    if (objc == 4) {
        if (TclX_OSsymlink (interp, srcPath, destPath, argv0String) != TCL_OK)
            goto errorExit;
    } else {
        if (TclX_OSlink (interp, srcPath, destPath, argv0String) != TCL_OK)
            goto errorExit;
    }

    Tcl_DStringFree (&srcPathBuf);
    Tcl_DStringFree (&destPathBuf);
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&srcPathBuf);
    Tcl_DStringFree (&destPathBuf);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_NiceObjCmd --
 *     Implements the TCL nice command:
 *         nice ?priorityincr?
 *
 * Results:
 *      Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_NiceObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    Tcl_Obj    *resultPtr = Tcl_GetObjResult (interp);
    int         priorityIncr, priority;
    char       *argv0String;

    if (objc > 2)
	return TclX_WrongArgs (interp, objv [0], "?priorityincr?");

    argv0String = Tcl_GetStringFromObj (objv [0], NULL);

    /*
     * Return the current priority if an increment is not supplied.
     */
    if (objc == 1) {
        if (TclXOSgetpriority (interp, &priority, argv0String) != TCL_OK)
            return TCL_ERROR;
	Tcl_SetIntObj (Tcl_GetObjResult (interp), priority);
        return TCL_OK;
    }

    /*
     * Increment the priority.
     */
    if (Tcl_GetIntFromObj (interp, objv [1], &priorityIncr) != TCL_OK)
        return TCL_ERROR;

    if (TclXOSincrpriority (interp, priorityIncr, &priority,
                            argv0String) != TCL_OK)
        return TCL_ERROR;

    Tcl_SetIntObj (resultPtr, priority);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_SleepObjCmd --
 *     Implements the TCL sleep command:
 *         sleep seconds
 *
 * Results:
 *      Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_SleepObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    double time;

    if (objc != 2)
	return TclX_WrongArgs (interp, objv [0], "seconds");

    if (Tcl_GetDoubleFromObj (interp, objv [1], &time) != TCL_OK)
        return TCL_ERROR;

    TclXOSsleep ((int) time);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_SyncObjCmd --
 *     Implements the TCL sync command:
 *         sync
 *
 * Results:
 *      Standard TCL results.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_SyncObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    Tcl_Channel  channel;

    if ((objc < 1) || (objc > 2))
	return TclX_WrongArgs (interp, objv [0], "?filehandle?");

    if (objc == 1) {
	TclXOSsync ();
	return TCL_OK;
    }

    channel = TclX_GetOpenChannelObj (interp, objv [1], TCL_WRITABLE);
    if (channel == NULL)
        return TCL_ERROR;

    if (Tcl_Flush (channel) < 0) {
	Tcl_SetStringObj (Tcl_GetObjResult (interp),
                          Tcl_PosixError (interp), -1);
        return TCL_ERROR;
    }
    return TclXOSfsync (interp, channel);
}

/*-----------------------------------------------------------------------------
 * TclX_SystemObjCmd --
 *   Implements the TCL system command:
 *      system cmdstr1 ?cmdstr2...?
 *-----------------------------------------------------------------------------
 */
static int
TclX_SystemObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    Tcl_Obj *cmdObjPtr;
    char *cmdStr;
    int exitCode;

    if (objc < 2)
	return TclX_WrongArgs (interp, objv [0], "cmdstr1 ?cmdstr2...?");

    cmdObjPtr = Tcl_ConcatObj (objc - 1, &(objv[1]));
    cmdStr = Tcl_GetStringFromObj (cmdObjPtr, NULL);

    if (TclXOSsystem (interp, cmdStr, &exitCode) != TCL_OK) {
        Tcl_DecrRefCount (cmdObjPtr);
        return TCL_ERROR;
    }
    Tcl_SetIntObj (Tcl_GetObjResult (interp), exitCode);
    Tcl_DecrRefCount (cmdObjPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_UmaskObjCmd --
 *     Implements the TCL umask command:
 *     umask ?octalmask?
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_UmaskObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    int    mask;
    char  *umaskString;
    char   numBuf [32];

    if ((objc < 1) || (objc > 2))
	return TclX_WrongArgs (interp, objv [0], "?octalmask?");

    /*
     * FIX: Should include leading 0 to make it a legal number.
     */
    if (objc == 1) {
        mask = umask (0);
        umask ((unsigned short) mask);
        sprintf (numBuf, "%o", mask);
	Tcl_SetStringObj (Tcl_GetObjResult (interp), numBuf, -1);
    } else {
	umaskString = Tcl_GetStringFromObj (objv [1], NULL);
        if (!TclX_StrToInt (umaskString, 8, &mask)) {
            TclX_AppendObjResult (interp, "Expected octal number got: ",
                                  Tcl_GetStringFromObj (objv [1], NULL),
                                  (char *) NULL);
            return TCL_ERROR;
        }

        umask ((unsigned short) mask);
    }
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_OsCmdsInit --
 *     Initialize the OS related commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_OsCmdsInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
			  "alarm",
			  TclX_AlarmObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "link",
			  TclX_LinkObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "nice",
			  TclX_NiceObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    TclX_CreateObjCommand (interp,
			  "sleep",
			  TclX_SleepObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL, 0);

    Tcl_CreateObjCommand (interp,
                          "sync",
			  TclX_SyncObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    TclX_CreateObjCommand (interp,
                          "system",
			  TclX_SystemObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL, 0);

    Tcl_CreateObjCommand (interp,
			  "umask",
			  TclX_UmaskObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

}


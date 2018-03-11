/*
 * tclXprocess.c --
 *
 * Tcl command to create and manage processes.
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
 * $Id: tclXprocess.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * These are needed for wait command even if waitpid is not available.
 */
#ifndef  WNOHANG
#    define  WNOHANG    1
#endif
#ifndef  WUNTRACED
#    define  WUNTRACED  2
#endif

static int 
TclX_ExeclObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));

static int 
TclX_ForkObjCmd _ANSI_ARGS_((ClientData clientData,
                             Tcl_Interp *interp,
                             int objc,
                             Tcl_Obj *CONST objv[]));

static int 
TclX_WaitObjCmd _ANSI_ARGS_((ClientData clientData,
                             Tcl_Interp *interp,
                             int objc,
                             Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * TclX_ForkObjCmd --
 *   Implements the TclX fork command:
 *     fork
 *-----------------------------------------------------------------------------
 */
static int
TclX_ForkObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    if (objc != 1)
	return TclX_WrongArgs (interp, objv [0], "");

    return TclXOSfork (interp, objv [0]);
}

/*-----------------------------------------------------------------------------
 * TclX_ExeclObjCmd --
 *   Implements the TCL execl command:
 *     execl ?-argv0 ? prog ?argList?
 *-----------------------------------------------------------------------------
 */
static int
TclX_ExeclObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
#define STATIC_ARG_SIZE   12
    char  *staticArgv [STATIC_ARG_SIZE];
    char **argList = staticArgv;
    int nextArg = 1;
    char *argStr;
    int argObjc;
    Tcl_Obj **argObjv;
    char *path, *argv0 = NULL;
    int idx, status;
    Tcl_DString pathBuf;

    status = TCL_ERROR;  /* assume the worst */

    if (objc < 2)
        goto wrongArgs;

    argStr = Tcl_GetStringFromObj (objv [nextArg], NULL);
    if (STREQU (argStr, "-argv0")) {
        nextArg++;
        if (nextArg == objc)
            goto wrongArgs;
        argv0 = Tcl_GetStringFromObj (objv [nextArg++], NULL);
    }
    if ((nextArg == objc) || (nextArg < objc - 2))
        goto wrongArgs;

    /*
     * Get path or command name.
     */
    Tcl_DStringInit (&pathBuf);
    path = Tcl_TranslateFileName (interp,
                                  Tcl_GetStringFromObj (objv [nextArg++],
                                                        NULL),
                                  &pathBuf);
    if (path == NULL)
        goto exitPoint;

    /*
     * If arg list is supplied, split it and build up the arguments to pass.
     * otherwise, just supply argv[0].  Must be NULL terminated.
     */
    if (nextArg == objc) {
        argList [1] = NULL;
    } else {
        if (Tcl_ListObjGetElements (interp, objv [nextArg++],
                                    &argObjc, &argObjv) != TCL_OK)
            goto exitPoint;

        if (argObjc > STATIC_ARG_SIZE - 2)
            argList = (char **) ckalloc ((argObjc + 1) * sizeof (char **));
            
        for (idx = 0; idx < argObjc; idx++) {
            argList [idx + 1] = Tcl_GetStringFromObj (argObjv [idx], NULL);
        }
        argList [argObjc + 1] = NULL;
    }

    if (argv0 != NULL) {
        argList [0] = argv0;
    } else {
	argList [0] = path;  /* Program name */
    }

    status = TclXOSexecl (interp, path, argList);

  exitPoint:
    if (argList != staticArgv)
        ckfree ((char *) argList);
    Tcl_DStringFree (&pathBuf);
    return status;

  wrongArgs:
    TclX_WrongArgs (interp, objv [0], "?-argv0 argv0? prog ?argList?");
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_WaitObjCmd --
 *   Implements the TCL wait command:
 *     wait ?-nohang? ?-untraced? ?-pgroup? ?pid?
 *-----------------------------------------------------------------------------
 */
static int
TclX_WaitObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    int idx, options = 0, pgroup = FALSE;
    char *argStr;
    pid_t returnedPid, pid;
    int tmpPid, status;
    Tcl_Obj *resultList [3];

    for (idx = 1; idx < objc; idx++) {
        argStr = Tcl_GetStringFromObj (objv [idx], NULL);
        if (argStr [0] != '-')
            break;
        if (STREQU (argStr, "-nohang")) {
            if (options & WNOHANG)
                goto usage;
            options |= WNOHANG;
            continue;
        }
        if (STREQU (argStr, "-untraced")) {
            if (options & WUNTRACED)
                goto usage;
            options |= WUNTRACED;
            continue;
        }
        if (STREQU (argStr, "-pgroup")) {
            if (pgroup)
                goto usage;
            pgroup = TRUE;
            continue;
        }
        goto usage;  /* None match */
    }
    /*
     * Check for more than one non-minus argument.  If ok, convert pid,
     * if supplied.
     */
    if (idx < objc - 1)
        goto usage;  
    if (idx < objc) {
        if (Tcl_GetIntFromObj (interp, objv [idx], &tmpPid) != TCL_OK) {
            Tcl_ResetResult (interp);
            goto invalidPid;
        }
        if (tmpPid <= 0)
            goto negativePid;
        pid = tmpPid;
        if (pid != tmpPid)
            goto invalidPid;
    } else {
        pid = -1;  /* pid or pgroup not supplied */
    }

    /*
     * Versions that don't have real waitpid have limited functionality.
     */
#ifdef NO_WAITPID
    if ((options != 0) || pgroup) {
        TclX_AppendObjResult (interp, "The \"-nohang\", \"-untraced\" and ",
                              "\"-pgroup\" options are not available on this ",
                              "system", (char *) NULL);
        return TCL_ERROR;
    }
#endif

    if (pgroup) {
        if (pid > 0)
            pid = -pid;
        else
            pid = 0;
    }

    returnedPid = (pid_t) TCLX_WAITPID (pid, (int *) (&status), options);

    if (returnedPid < 0) {
        TclX_AppendObjResult (interp, "wait for process failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * If no process was available, return an empty status.  Otherwise return
     * a list contain the PID and why it stopped.
     */
    if (returnedPid == 0)
        return TCL_OK;

    resultList [0] = Tcl_NewIntObj (returnedPid);
    if (WIFEXITED (status)) {
        resultList [1] = Tcl_NewStringObj ("EXIT", -1);
        resultList [2] = Tcl_NewIntObj (WEXITSTATUS (status));
    } else if (WIFSIGNALED (status)) {
        resultList [1] = Tcl_NewStringObj ("SIG", -1);
        resultList [2] = Tcl_NewStringObj (Tcl_SignalId (WTERMSIG (status)),
                                           -1);
    } else if (WIFSTOPPED (status)) {
        resultList [1] = Tcl_NewStringObj ("STOP", -1);
        resultList [2] = Tcl_NewStringObj (Tcl_SignalId (WSTOPSIG (status)),
                                           -1);
    }
    Tcl_SetListObj (Tcl_GetObjResult (interp), 3, resultList);
    return TCL_OK;

  usage:
    TclX_WrongArgs (interp, objv [0], "?-nohang? ?-untraced? ?-pgroup? ?pid?");
    return TCL_ERROR;

  invalidPid:
    TclX_AppendObjResult (interp, "invalid pid or process group id \"",
                          Tcl_GetStringFromObj (objv [idx], NULL),
                          "\"", (char *) NULL);
    return TCL_ERROR;

  negativePid:
    TclX_AppendObjResult (interp, "pid or process group id must be greater ",
                          "than zero", (char *) NULL);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_ProcessInit --
 *   Initialize process commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_ProcessInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
                          "execl",
                          TclX_ExeclObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);

    /* Avoid conflict with "expect".
     */

    TclX_CreateObjCommand (interp,
                          "fork",
			  TclX_ForkObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL, 0);

    TclX_CreateObjCommand (interp,
                          "wait",
                          TclX_WaitObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL, 0);
}

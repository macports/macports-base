/* 
 * tclXtest.c --
 *
 *  Test support functions for the Extended Tcl test program.
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
 * $Id: tclXtest.c,v 1.2 2002/04/03 02:50:35 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

int
Tclxtest_Init _ANSI_ARGS_((Tcl_Interp *interp));

int
TclObjTest_Init _ANSI_ARGS_((Tcl_Interp *interp));

int
Tcltest_Init _ANSI_ARGS_((Tcl_Interp *interp));

/*
 * Error handler proc that causes errors to come out in the same format as
 * the standard Tcl test shell.  This keeps certain Tcl tests from reporting
 * errors.
 */
static char errorHandler [] =
    "proc tclx_errorHandler msg {global errorInfo; \
     if [lempty $errorInfo] {puts $msg} else {puts stderr $errorInfo}; \
     exit 1}";

/*
 * Prototypes of internal functions.
 */
static int
DoTestEval _ANSI_ARGS_((Tcl_Interp  *interp,
                        char        *levelStr,
                        char        *command,
                        Tcl_Obj     *resultList));

static int
TclxTestEvalCmd _ANSI_ARGS_((ClientData    clientData,
                             Tcl_Interp   *interp,
                             int           argc,
                             char        **argv));


/*-----------------------------------------------------------------------------
 * DoTestEval --
 *   Evaluate a level/command pair.
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o levelStr - Level string to parse.
 *   o command - Command to evaluate.
 *   o resultList - List object to append the two element eval code and result
 *     to.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
DoTestEval (interp, levelStr, command, resultList)
    Tcl_Interp  *interp;
    char        *levelStr;
    char        *command;
    Tcl_Obj     *resultList;
{
    Interp *iPtr = (Interp *) interp;
    int code;
    Tcl_Obj *subResult;
    CallFrame *savedVarFramePtr, *framePtr;

    /*
     * Find the frame to eval in.
     */
    code = TclGetFrame (interp, levelStr, &framePtr);
    if (code <= 0) {
        if (code == 0)
            TclX_AppendObjResult (interp, "invalid level \"", levelStr, "\"",
                                  (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Evaluate in the new environment.
     */
    savedVarFramePtr = iPtr->varFramePtr;
    iPtr->varFramePtr = framePtr;

    code = Tcl_Eval (interp, command);

    iPtr->varFramePtr = savedVarFramePtr;

    /*
     * Append the two element list.
     */
    subResult = Tcl_NewListObj (0, NULL);
    if (Tcl_ListObjAppendElement (interp, subResult,
                                  Tcl_NewIntObj (code)) != TCL_OK)
        return TCL_ERROR;
    if (Tcl_ListObjAppendElement (interp, subResult,
                                  Tcl_GetObjResult (interp)) != TCL_OK)
        return TCL_ERROR;
    if (Tcl_ListObjAppendElement (interp, resultList, subResult) != TCL_OK)
        return TCL_ERROR;
    
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclxTestEvalCmd --
 *    Command used in profile test.  It purpose is to evaluate a series of
 * commands at a specified level.  Its like uplevel, but can generate more
 * complex situations.  Level is specified in the same manner as uplevel,
 * with 0 being the current level.
 *     tclx_test_eval ?level cmd? ?level cmd? ...
 *
 * Results:
 *   A list contain a list entry for each command evaluated.  Each entry is
 * the eval code and result string.
 *-----------------------------------------------------------------------------
 */
static int
TclxTestEvalCmd (clientData, interp, argc, argv)
    ClientData    clientData;
    Tcl_Interp   *interp;
    int           argc;
    char        **argv;
{
    int idx;
    Tcl_Obj *resultList;

    if (((argc - 1) % 2) != 0) {
        TclX_AppendObjResult (interp, "wrong # args: ", argv [0],
                              " ?level cmd? ?level cmd? ...", (char *) NULL);
        return TCL_ERROR;
    }

    resultList = Tcl_NewListObj (0, NULL);

    for (idx = 1; idx < argc; idx += 2) {
        if (DoTestEval (interp, argv [idx], argv [idx + 1],
                        resultList) == TCL_ERROR) {
            Tcl_DecrRefCount (resultList);
            return TCL_ERROR;
        }
    }
        
    Tcl_SetObjResult (interp, resultList);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tclxtest_Init --
 *  Initialize TclX test support.
 *
 * Results:
 *   Returns a standard Tcl completion code, and leaves an error message in
 * interp result if an error occurs.
 *-----------------------------------------------------------------------------
 */
int
Tclxtest_Init (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateCommand (interp, "tclx_test_eval", TclxTestEvalCmd,
                       (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);

    /*
     * Add in standard Tcl tests support.
     */
    if (Tcltest_Init(interp) == TCL_ERROR) {
	return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, "Tcltest", Tcltest_Init,
            (Tcl_PackageInitProc *) NULL);
    if (TclObjTest_Init(interp) == TCL_ERROR) {
	return TCL_ERROR;
    }
    return Tcl_GlobalEval (interp, errorHandler);
}



/* 
 * tclXgeneral.c --
 *
 * A collection of general commands: echo, infox and loop.
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
 * $Id: tclXgeneral.c,v 1.4 2008/12/15 20:00:27 andreas_kupries Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Values returned by the infox command.
 */

static char *tclxVersion       = FULL_VERSION;
static int   tclxPatchlevel    = TCLX_PATCHLEVEL;
static char *tclAppName        = NULL;
static char *tclAppLongName    = NULL;
static char *tclAppVersion     = NULL;
static int   tclAppPatchlevel  = -1;

static int 
TclX_EchoObjCmd _ANSI_ARGS_((ClientData clientData, 
                             Tcl_Interp *interp,
                             int         objc,
                             Tcl_Obj    *CONST objv[]));

static int 
TclX_InfoxObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int         objc,
                              Tcl_Obj    *CONST objv[]));

static int 
TclX_LoopObjCmd _ANSI_ARGS_((ClientData clientData, 
                             Tcl_Interp *interp,
                             int         objc,
                             Tcl_Obj    *CONST objv[]));

static int
SetLoopCounter _ANSI_ARGS_((Tcl_Interp *interp,
                            char *varName,
                            int idx));

static int
GlobalImport _ANSI_ARGS_((Tcl_Interp *interp));

static int
TclX_Try_EvalObjCmd _ANSI_ARGS_((ClientData clientData, 
                                 Tcl_Interp *interp,
                                 int         objc,
                                 Tcl_Obj    *CONST objv[]));


/*-----------------------------------------------------------------------------
 * TclX_SetAppInfo --
 *   Store the application information returned by infox.
 *
 * Parameters:
 *   o defaultValues (I) - If true, then the values are assigned only if they
 *     are not already defined (defaulted).  If false, the values are always
 *     set.
 *   o appName (I) - Application symbolic name.  
 *   o appLongName (I) - Long, natural language application name.
 *   o appVersion (I) - Version number of the application.
 *   o appPatchlevel (I) - Patch level of the application.  If less than
 *     zero, don't change.
 * Notes:
 *   String pointers are saved without copying, don't release the memory.
 * If the arguments are NULL, don't change the values.
 *-----------------------------------------------------------------------------
 */
void
TclX_SetAppInfo (defaultValues, appName, appLongName, appVersion,
                 appPatchlevel)
    int   defaultValues;
    char *appName;
    char *appLongName;
    char *appVersion;
    int   appPatchlevel;
{
    if ((appName != NULL) &&
        ((!defaultValues) || (tclAppName == NULL))) {
        tclAppName = appName;
    }
    if ((appLongName != NULL) &&
        ((!defaultValues) || (tclAppLongName == NULL))) {
        tclAppLongName = appLongName;
    }
    if ((appVersion != NULL) &&
        ((!defaultValues) || (tclAppVersion == NULL))) {
        tclAppVersion = appVersion;
    }
    if ((appPatchlevel >= 0) &&
        ((!defaultValues) || (tclAppPatchlevel < 0))) {
        tclAppPatchlevel = appPatchlevel;
    }
}


/*-----------------------------------------------------------------------------
 * TclX_EchoObjCmd --
 *    Implements the TclX echo command:
 *        echo ?str ...?
 *
 * Results:
 *      Always returns TCL_OK.
 *-----------------------------------------------------------------------------
 */
static int
TclX_EchoObjCmd (dummy, interp, objc, objv)
    ClientData	dummy;
    Tcl_Interp *interp;
    int		objc;
    Tcl_Obj    *CONST objv[];
{
    int	  idx;
    Tcl_Channel channel;
#ifndef TCL_UTF_MAX
    char *stringPtr;
    int stringPtrLen;
#endif

    channel = TclX_GetOpenChannel (interp, "stdout", TCL_WRITABLE);
    if (channel == NULL)
	return TCL_ERROR;

    for (idx = 1; idx < objc; idx++) {
#ifndef TCL_UTF_MAX
	stringPtr = Tcl_GetStringFromObj (objv [idx], &stringPtrLen);
	if (Tcl_Write (channel, stringPtr, stringPtrLen) < 0)
#else
	if (Tcl_WriteObj(channel, objv[idx]) < 0)
#endif
	    goto posixError;
	if (idx < (objc - 1)) {
	    if (Tcl_Write (channel, " ", 1) < 0)
		goto posixError;
	}
    }
    if (TclX_WriteNL (channel) < 0)
	goto posixError;
    return TCL_OK;

  posixError:
    Tcl_SetStringObj (Tcl_GetObjResult (interp), Tcl_PosixError (interp), -1);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_InfoxObjCmd --
 *    Implements the TclX infox command:
 *        infox option
 *-----------------------------------------------------------------------------
 */
static int
TclX_InfoxObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *resultPtr = Tcl_GetObjResult (interp);
    char *optionPtr;

    /*
     * FIX: Need a way to get the have_ functionality from the OS-dependent
     * code.
     */
    if (objc != 2) {
        return TclX_WrongArgs (interp, objv[0], "option");
    }

    optionPtr = Tcl_GetStringFromObj (objv[1], NULL);

    if (STREQU ("version", optionPtr)) {
        if (tclxVersion != NULL) {
            Tcl_SetStringObj (resultPtr, tclxVersion, -1);
        }
        return TCL_OK;
    }
    if (STREQU ("patchlevel", optionPtr)) {
        Tcl_SetIntObj (resultPtr, tclxPatchlevel);
        return TCL_OK;
    }
    if (STREQU ("have_fchown", optionPtr)) {
#       ifndef NO_FCHOWN
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_fchmod", optionPtr)) {
#       ifndef NO_FCHMOD
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_flock", optionPtr)) {
        if (TclXOSHaveFlock ())
            Tcl_SetBooleanObj (resultPtr, TRUE);
        else
            Tcl_SetBooleanObj (resultPtr, FALSE);
        return TCL_OK;
    }
    if (STREQU ("have_fsync", optionPtr)) {
#       ifndef NO_FSYNC
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_ftruncate", optionPtr)) {
#       if (!defined(NO_FTRUNCATE)) || defined(HAVE_CHSIZE)
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_msgcats", optionPtr)) {
#       ifndef NO_CATGETS
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_posix_signals", optionPtr)) {
#       ifndef NO_SIGACTION
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_signal_restart", optionPtr)) {
#       ifndef NO_SIG_RESTART
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_truncate", optionPtr)) {
#       ifndef NO_TRUNCATE
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_symlink", optionPtr)) {
#       ifdef S_IFLNK
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("have_waitpid", optionPtr)) {
#       ifndef NO_WAITPID
        Tcl_SetBooleanObj (resultPtr, TRUE);
#       else
        Tcl_SetBooleanObj (resultPtr, FALSE);
#       endif        
        return TCL_OK;
    }
    if (STREQU ("appname", optionPtr)) {
        if (tclAppName != NULL) {
            Tcl_SetStringObj (resultPtr, tclAppName, -1);
        }
        return TCL_OK;
    }
    if (STREQU ("applongname", optionPtr)) {
        if (tclAppLongName != NULL)
            Tcl_SetStringObj (resultPtr, tclAppLongName, -1);
        return TCL_OK;
    }
    if (STREQU ("appversion", optionPtr)) {
        if (tclAppVersion != NULL)
            Tcl_SetStringObj (resultPtr, tclAppVersion, -1);
        return TCL_OK;
    }
    if (STREQU ("apppatchlevel", optionPtr)) {
        if (tclAppPatchlevel >= 0)
            Tcl_SetIntObj (resultPtr, tclAppPatchlevel);
        else
            Tcl_SetIntObj (resultPtr, 0);
        return TCL_OK;
    }
    TclX_AppendObjResult (interp, "illegal option \"", optionPtr,
                          "\", expect one of: version, patchlevel, ",
                          "have_fchown, have_fchmod, have_flock, ",
                          "have_fsync, have_ftruncate, have_msgcats, ",
                          "have_symlink, have_truncate, ",
                          "have_posix_signals, have_waitpid, appname, ",
                          "applongname, appversion, or apppatchlevel",
                          (char *) NULL);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * SetLoopCounter --
 *   Set the loop command counter variable.
 *-----------------------------------------------------------------------------
 */
static int
SetLoopCounter (interp, varName, idx)
    Tcl_Interp *interp;
    char *varName;
    int idx;
{
    Tcl_Obj *iObj, *newVarObj;

    iObj = Tcl_GetVar2Ex(interp, varName, NULL, TCL_PARSE_PART1);
    if ((iObj == NULL) || (Tcl_IsShared (iObj))) {
	iObj = newVarObj = Tcl_NewLongObj (idx);
    } else {
	newVarObj = NULL;
    }

    Tcl_SetLongObj (iObj, idx);
    if (Tcl_SetVar2Ex(interp, varName, NULL, iObj,
	    TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL) {
	if (newVarObj != NULL) {
	    Tcl_DecrRefCount (newVarObj);
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_LoopObjCmd --
 *     Implements the TclX loop command:
 *         loop var start end ?increment? command
 *
 * Results:
 *      Standard TCL results.
 *-----------------------------------------------------------------------------
 */
static int
TclX_LoopObjCmd (dummy, interp, objc, objv)
    ClientData  dummy;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    int result = TCL_OK;
    long idx, first, limit, incr = 1;
    char *varName; 
    Tcl_Obj  *command;

    if ((objc < 5) || (objc > 6)) {
	return TclX_WrongArgs (interp, objv [0], 
		"var first limit ?incr? command");
    }

    if (Tcl_ExprLongObj (interp, objv [2], &first) != TCL_OK)
	return TCL_ERROR;

    if (Tcl_ExprLongObj (interp, objv [3], &limit) != TCL_OK)
	return TCL_ERROR;

    if (objc == 5) {
	command = objv [4];
    } else {
	if (Tcl_ExprLongObj (interp, objv [4], &incr) != TCL_OK)
	    return TCL_ERROR;
	command = objv [5];
    }

    varName = Tcl_GetStringFromObj (objv[1], NULL);
    for (idx = first;
	 (((idx < limit) && (incr >= 0)) || ((idx > limit) && (incr < 0)));
	 idx += incr) {
	
	if (SetLoopCounter(interp, varName, idx) == TCL_ERROR)
	    return TCL_ERROR;

	result = Tcl_EvalObj (interp, command);
	if (result == TCL_CONTINUE) {
	    result = TCL_OK;
	} else if (result != TCL_OK) {
	    if (result == TCL_BREAK) {
		result = TCL_OK;
	    } else if (result == TCL_ERROR) {
		char buf [64];
		
		sprintf (buf, "\n    (\"loop\" body line %d)", 
			ERRORLINE(interp));
		Tcl_AddErrorInfo (interp, buf);
	    }
	    break;
	}
    }

    /*
     * Set loop counter to its final value.
     */
    if (SetLoopCounter(interp, varName, idx) == TCL_ERROR)
	return TCL_ERROR;
    return result;
}


/*-----------------------------------------------------------------------------
 * GlobalImport --
 *   Import the errorResult, errorInfo, and errorCode global variable into the
 * current environment by calling the global command directly.
 *
 * Parameters:
 *   o interp (I) - Current interpreter,  Result is preserved.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
GlobalImport (interp)
    Tcl_Interp *interp;
{
    static char global [] = "global";
    Tcl_Obj *savedResult;
    Tcl_CmdInfo cmdInfo;
#define globalObjc (4)
    Tcl_Obj *globalObjv [globalObjc];
    int idx, code = TCL_OK;

    savedResult = Tcl_DuplicateObj (Tcl_GetObjResult (interp));

    if (!Tcl_GetCommandInfo (interp, global, &cmdInfo)) {
        TclX_AppendObjResult (interp, "can't find \"global\" command", 
                              (char *) NULL);
        goto errorExit;
    }
    
    globalObjv [0] = Tcl_NewStringObj (global, -1);
    globalObjv [1] = Tcl_NewStringObj ("errorResult", -1);
    globalObjv [2] = Tcl_NewStringObj ("errorInfo", -1);
    globalObjv [3] = Tcl_NewStringObj ("errorCode", -1);

    for (idx = 0; idx < globalObjc; idx++) {
        Tcl_IncrRefCount (globalObjv [idx]);
    }
    
    code = (*cmdInfo.objProc) (cmdInfo.objClientData,
                               interp,
                               globalObjc,
                               globalObjv);
    for (idx = 0; idx < globalObjc; idx++) {
        Tcl_DecrRefCount (globalObjv [idx]);
    }

    if (code == TCL_ERROR)
        goto errorExit;

    Tcl_SetObjResult (interp, savedResult);
    return TCL_OK;

  errorExit:
    Tcl_DecrRefCount (savedResult);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_Try_EvalObjCmd --
 *     Implements the TclX try_eval command:
 *          try_eval code catch ?finally?
 *
 * Results:
 *      Standard TCL results.
 *-----------------------------------------------------------------------------
 */
static int
TclX_Try_EvalObjCmd (dummy, interp, objc, objv)
    ClientData  dummy;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    int code, code2;
    int haveFinally;
    Tcl_Obj *savedResultsPtr, *resultObjPtr;

    if ((objc < 3) || (objc > 4)) {
        return TclX_WrongArgs (interp, objv [0], "code catch ?finally?");
    }
    haveFinally = (objc >= 4) && !TclX_IsNullObj (objv [3]);

    /*
     * Evaluate the command.  If not error and no finally command, we are done.
     */
    code = Tcl_EvalObj (interp, objv [1]);
    if ((code != TCL_ERROR) && !haveFinally) {
        return code;
    }

    /*
     * Process error block, if available.  It's results becomes the command's
     * result.
     */
    if ((!TclX_IsNullObj (objv [2])) && (code == TCL_ERROR)) {
        resultObjPtr = Tcl_DuplicateObj (Tcl_GetObjResult (interp));
        Tcl_IncrRefCount (resultObjPtr);
        Tcl_ResetResult (interp);

        code = GlobalImport (interp);
        if (code != TCL_ERROR) {
            if (Tcl_SetVar2Ex(interp, "errorResult", NULL, 
                              resultObjPtr, TCL_LEAVE_ERR_MSG) == NULL) {
                code = TCL_ERROR;
            }
        }
        if (code != TCL_ERROR) {
            code = Tcl_EvalObj (interp, objv [2]);
        }
        Tcl_DecrRefCount (resultObjPtr);
   }

    /*
     * If a finally command is supplied, evaluate it, preserving the error
     * status.
     */
    if (haveFinally) {
        savedResultsPtr = TclX_SaveResultErrorInfo (interp);
        Tcl_ResetResult (interp);
    
        code2 = Tcl_EvalObj (interp, objv [3]);
        if (code2 == TCL_ERROR) {
            Tcl_DecrRefCount (savedResultsPtr);  /* Don't restore results */
            code = code2;
        } else {
            TclX_RestoreResultErrorInfo (interp, savedResultsPtr);
        }
    }
    return code;
}


/*-----------------------------------------------------------------------------
 * TclX_GeneralInit --
 *     Initialize the command.
 *-----------------------------------------------------------------------------
 */
void
TclX_GeneralInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
                          "echo",
                          TclX_EchoObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
                         "infox",
                         TclX_InfoxObjCmd,
                         (ClientData) NULL,
                         (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
                         "loop",
                         TclX_LoopObjCmd,
                         (ClientData) NULL,
                         (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
                         "try_eval",
                         TclX_Try_EvalObjCmd,
                         (ClientData) NULL,
                         (Tcl_CmdDeleteProc*) NULL);
}


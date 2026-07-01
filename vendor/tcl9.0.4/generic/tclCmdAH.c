/*
 * tclCmdAH.c --
 *
 *	This file contains the top-level command routines for most of the Tcl
 *	built-in commands whose names begin with the letters A to H.
 *
 * Copyright © 1987-1993 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclIO.h"
#include "tclTomMath.h"
#ifdef _WIN32
#   include "tclWinInt.h"
#endif

/*
 * The state structure used by [foreach]. Note that the actual structure has
 * all its working arrays appended afterwards so they can be allocated and
 * freed in a single step.
 */

struct ForeachState {
    Tcl_Obj *bodyPtr;		/* The script body of the command. */
    Tcl_Size bodyIdx;		/* The argument index of the body. */
    Tcl_Size j, maxj;		/* Number of loop iterations. */
    Tcl_Size numLists;		/* Count of value lists. */
    Tcl_Size *index;		/* Array of value list indices. */
    Tcl_Size *varcList;		/* # loop variables per list. */
    Tcl_Obj ***varvList;	/* Array of var name lists. */
    Tcl_Obj **vCopyList;	/* Copies of var name list arguments. */
    Tcl_Size *argcList;		/* Array of value list sizes. */
    Tcl_Obj ***argvList;	/* Array of value lists. */
    Tcl_Obj **aCopyList;	/* Copies of value list arguments. */
    Tcl_Obj *resultList;	/* List of result values from the loop body,
				 * or NULL if we're not collecting them
				 * ([lmap] vs [foreach]). */
};

/*
 * Prototypes for local procedures defined in this file:
 */

static int		CheckAccess(Tcl_Interp *interp, Tcl_Obj *pathPtr,
			    int mode);
static Tcl_ObjCmdProc	EncodingConvertfromObjCmd;
static Tcl_ObjCmdProc	EncodingConverttoObjCmd;
static Tcl_ObjCmdProc	EncodingDirsObjCmd;
static Tcl_ObjCmdProc	EncodingNamesObjCmd;
static Tcl_ObjCmdProc	EncodingProfilesObjCmd;
static Tcl_ObjCmdProc	EncodingSystemObjCmd;
static Tcl_ObjCmdProc	EncodingUserObjCmd;
static inline int	ForeachAssignments(Tcl_Interp *interp,
			    struct ForeachState *statePtr);
static inline void	ForeachCleanup(Tcl_Interp *interp,
			    struct ForeachState *statePtr);
static int		GetStatBuf(Tcl_Interp *interp, Tcl_Obj *pathPtr,
			    Tcl_FSStatProc *statProc, Tcl_StatBuf *statPtr);
static const char *	GetTypeFromMode(int mode);
static int		StoreStatData(Tcl_Interp *interp, Tcl_Obj *varName,
			    Tcl_StatBuf *statPtr);
static int		EachloopCmd(Tcl_Interp *interp, int collect,
			    int objc, Tcl_Obj *const objv[]);
static Tcl_NRPostProc	CatchObjCmdCallback;
static Tcl_NRPostProc	ExprCallback;
static Tcl_NRPostProc	ForSetupCallback;
static Tcl_NRPostProc	ForCondCallback;
static Tcl_NRPostProc	ForNextCallback;
static Tcl_NRPostProc	ForPostNextCallback;
static Tcl_NRPostProc	ForeachLoopStep;
static Tcl_NRPostProc	EvalCmdErrMsg;

static Tcl_ObjCmdProc FileAttrAccessTimeCmd;
static Tcl_ObjCmdProc FileAttrIsDirectoryCmd;
static Tcl_ObjCmdProc FileAttrIsExecutableCmd;
static Tcl_ObjCmdProc FileAttrIsExistingCmd;
static Tcl_ObjCmdProc FileAttrIsFileCmd;
static Tcl_ObjCmdProc FileAttrIsOwnedCmd;
static Tcl_ObjCmdProc FileAttrIsReadableCmd;
static Tcl_ObjCmdProc FileAttrIsWritableCmd;
static Tcl_ObjCmdProc FileAttrLinkStatCmd;
static Tcl_ObjCmdProc FileAttrModifyTimeCmd;
static Tcl_ObjCmdProc FileAttrSizeCmd;
static Tcl_ObjCmdProc FileAttrStatCmd;
static Tcl_ObjCmdProc FileAttrTypeCmd;
static Tcl_ObjCmdProc FilesystemSeparatorCmd;
static Tcl_ObjCmdProc FilesystemVolumesCmd;
static Tcl_ObjCmdProc PathDirNameCmd;
static Tcl_ObjCmdProc PathExtensionCmd;
static Tcl_ObjCmdProc PathFilesystemCmd;
static Tcl_ObjCmdProc PathJoinCmd;
static Tcl_ObjCmdProc PathNativeNameCmd;
static Tcl_ObjCmdProc PathNormalizeCmd;
static Tcl_ObjCmdProc PathRootNameCmd;
static Tcl_ObjCmdProc PathSplitCmd;
static Tcl_ObjCmdProc PathTailCmd;
static Tcl_ObjCmdProc PathTypeCmd;

/*
 *----------------------------------------------------------------------
 *
 * Tcl_BreakObjCmd --
 *
 *	This procedure is invoked to process the "break" Tcl command. See the
 *	user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "break" or the name to
 *	which "break" was renamed: e.g., "set z break; $z"
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_BreakObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    return TCL_BREAK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_CatchObjCmd --
 *
 *	This object-based procedure is invoked to process the "catch" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_CatchObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRCatchObjCmd, clientData, objc, objv);
}

int
TclNRCatchObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *varNamePtr = NULL;
    Tcl_Obj *optionVarNamePtr = NULL;
    Interp *iPtr = (Interp *) interp;

    if ((objc < 2) || (objc > 4)) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"script ?resultVarName? ?optionVarName?");
	return TCL_ERROR;
    }

    if (objc >= 3) {
	varNamePtr = objv[2];
    }
    if (objc == 4) {
	optionVarNamePtr = objv[3];
    }

    TclNRAddCallback(interp, CatchObjCmdCallback, INT2PTR(objc),
	    varNamePtr, optionVarNamePtr, NULL);

    /*
     * TIP #280. Make invoking context available to caught script.
     */

    return TclNREvalObjEx(interp, objv[1], 0, iPtr->cmdFramePtr, 1);
}

static int
CatchObjCmdCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    int objc = PTR2INT(data[0]);
    Tcl_Obj *varNamePtr = (Tcl_Obj *)data[1];
    Tcl_Obj *optionVarNamePtr = (Tcl_Obj *)data[2];
    int rewind = iPtr->execEnvPtr->rewind;

    /*
     * We disable catch in interpreters where the limit has been exceeded.
     */

    if (rewind || Tcl_LimitExceeded(interp)) {
	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"catch\" body line %d)", Tcl_GetErrorLine(interp)));
	return TCL_ERROR;
    }

    if (objc >= 3) {
	if (NULL == Tcl_ObjSetVar2(interp, varNamePtr, NULL,
		Tcl_GetObjResult(interp), TCL_LEAVE_ERR_MSG)) {
	    return TCL_ERROR;
	}
    }
    if (objc == 4) {
	Tcl_Obj *options = Tcl_GetReturnOptions(interp, result);

	if (NULL == Tcl_ObjSetVar2(interp, optionVarNamePtr, NULL,
		options, TCL_LEAVE_ERR_MSG)) {
	    /* Do not decrRefCount 'options', it was already done by
	     * Tcl_ObjSetVar2 */
	    return TCL_ERROR;
	}
    }

    Tcl_ResetResult(interp);
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(result));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_CdObjCmd --
 *
 *	This procedure is invoked to process the "cd" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_CdObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *dir;
    int result;

    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?dirName?");
	return TCL_ERROR;
    }

    if (objc == 2) {
	dir = objv[1];
    } else {
	dir = TclGetHomeDirObj(interp, NULL);
	if (dir == NULL) {
	    return TCL_ERROR;
	}
	Tcl_IncrRefCount(dir);
    }
    if (Tcl_FSConvertToPathType(interp, dir) != TCL_OK) {
	result = TCL_ERROR;
    } else {
	Tcl_DString ds;
	result = Tcl_UtfToExternalDStringEx(NULL, TCLFSENCODING, TclGetString(dir), -1, 0, &ds, NULL);
	Tcl_DStringFree(&ds);
	if (result == TCL_OK) {
	    result = Tcl_FSChdir(dir);
	}
	if (result != TCL_OK) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "couldn't change working directory to \"%s\": %s",
		    TclGetString(dir), Tcl_PosixError(interp)));
	    result = TCL_ERROR;
	}
    }
    if (objc != 2) {
	Tcl_DecrRefCount(dir);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConcatObjCmd --
 *
 *	This object-based procedure is invoked to process the "concat" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ConcatObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc >= 2) {
	Tcl_SetObjResult(interp, Tcl_ConcatObj(objc-1, objv+1));
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ContinueObjCmd --
 *
 *	This procedure is invoked to process the "continue" Tcl command. See
 *	the user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "continue" or the name to
 *	which "continue" was renamed: e.g., "set z continue; $z"
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ContinueObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    return TCL_CONTINUE;
}

/*
 *-----------------------------------------------------------------------------
 *
 * TclInitEncodingCmd --
 *
 *	This function creates the 'encoding' ensemble.
 *
 * Results:
 *	Returns the Tcl_Command so created.
 *
 * Side effects:
 *	The ensemble is initialized.
 *
 * This command is hidden in a safe interpreter.
 */

Tcl_Command
TclInitEncodingCmd(
    Tcl_Interp* interp)		/* Tcl interpreter */
{
    static const EnsembleImplMap encodingImplMap[] = {
	{"convertfrom", EncodingConvertfromObjCmd, TclCompileBasic1To3ArgCmd, NULL, NULL, 0},
	{"convertto",   EncodingConverttoObjCmd,   TclCompileBasic1To3ArgCmd, NULL, NULL, 0},
	{"dirs",        EncodingDirsObjCmd,        TclCompileBasic0Or1ArgCmd, NULL, NULL, 1},
	{"names",       EncodingNamesObjCmd,       TclCompileBasic0ArgCmd,    NULL, NULL, 0},
	{"profiles",    EncodingProfilesObjCmd,    TclCompileBasic0ArgCmd,    NULL, NULL, 0},
	{"system",      EncodingSystemObjCmd,      TclCompileBasic0Or1ArgCmd, NULL, NULL, 1},
	{"user",        EncodingUserObjCmd,        TclCompileBasic0ArgCmd,    NULL, NULL, 1},
	{NULL,          NULL,                      NULL,                      NULL, NULL, 0}
    };

    return TclMakeEnsemble(interp, "encoding", encodingImplMap);
}

/*
 *------------------------------------------------------------------------
 *
 * EncodingConvertParseOptions --
 *
 *    Common routine for parsing arguments passed to encoding convertfrom
 *    and encoding convertto.
 *
 * Results:
 *    TCL_OK or TCL_ERROR.
 *
 * Side effects:
 *    On success,
 *    - *encPtr is set to the encoding. Must be freed with Tcl_FreeEncoding
 *      if non-NULL
 *    - *dataObjPtr is set to the Tcl_Obj containing the data to encode or
 *      decode
 *    - *profilePtr is set to encoding error handling profile
 *    - *failVarPtr is set to -failindex option value or NULL
 *    On error, all of the above are uninitialized.
 *
 *------------------------------------------------------------------------
 */
static int
EncodingConvertParseOptions(
    Tcl_Interp *interp,		/* For error messages. May be NULL */
    int objc,			/* Number of arguments */
    Tcl_Obj *const objv[],	/* Argument objects as passed to command. */
    Tcl_Encoding *encPtr,	/* Where to store the encoding */
    Tcl_Obj **dataObjPtr,	/* Where to store ptr to Tcl_Obj containing data */
    int *profilePtr,		/* Bit mask of encoding option profile */
    Tcl_Obj **failVarPtr)	/* Where to store -failindex option value */
{
    static const char *const options[] = {"-profile", "-failindex", NULL};
    enum convertfromOptions { PROFILE, FAILINDEX } optIndex;
    Tcl_Encoding encoding;
    Tcl_Obj *dataObj;
    Tcl_Obj *failVarObj;
    int profile = TCL_ENCODING_PROFILE_STRICT;

    /*
     * Possible combinations:
     * 1) data						-> objc = 2
     * 2) ?options? encoding data			-> objc >= 3
     * It is intentional that specifying option forces encoding to be
     * specified. Less prone to user error. This should have always been
     * the case even in 8.6 imho where there were no options (ie (1)
     * should never have been allowed)
     */

    if (objc == 1) {
    numArgsError: /* ONLY jump here if nothing needs to be freed!!! */
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-profile profile? ?-failindex var? encoding data");
	((Interp *)interp)->flags |= INTERP_ALTERNATE_WRONG_ARGS;
	Tcl_WrongNumArgs(interp, 1, objv, "data");
	return TCL_ERROR;
    }

    failVarObj = NULL;
    if (objc == 2) {
	encoding = Tcl_GetEncoding(interp, NULL);
	dataObj = objv[1];
    } else {
	int argIndex;
	for (argIndex = 1; argIndex < (objc-2); ++argIndex) {
	    if (Tcl_GetIndexFromObj(interp, objv[argIndex], options, "option",
		    0, &optIndex) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if (++argIndex == (objc - 2)) {
		goto numArgsError;
	    }
	    switch (optIndex) {
	    case PROFILE:
		if (TclEncodingProfileNameToId(interp,
			Tcl_GetString(objv[argIndex]), &profile) != TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    case FAILINDEX:
		failVarObj = objv[argIndex];
		break;
	    default:
		TCL_UNREACHABLE();
	    }
	}
	/* Get encoding after opts so no need to free it on option error */
	if (Tcl_GetEncodingFromObj(interp, objv[objc - 2], &encoding) != TCL_OK) {
	    return TCL_ERROR;
	}
	dataObj = objv[objc - 1];
    }

    *encPtr = encoding;
    *dataObjPtr = dataObj;
    *profilePtr = profile;
    *failVarPtr = failVarObj;

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * EncodingConvertfromObjCmd --
 *
 *	This command converts a byte array in an external encoding into a
 *	Tcl string
 *
 * Results:
 *	A standard Tcl result.
 *
 *----------------------------------------------------------------------
 */

int
EncodingConvertfromObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *data;		/* Byte array to convert */
    Tcl_DString ds;		/* Buffer to hold the string */
    Tcl_Encoding encoding;	/* Encoding to use */
    Tcl_Size length = 0;			/* Length of the byte array being converted */
    const char *bytesPtr;	/* Pointer to the first byte of the array */
    int flags;
    int result;
    Tcl_Obj *failVarObj;
    Tcl_Size errorLocation;

    if (EncodingConvertParseOptions(interp, objc, objv, &encoding, &data,
	    &flags, &failVarObj) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Convert the string into a byte array in 'ds'.
     */
    bytesPtr = (char *) Tcl_GetBytesFromObj(interp, data, &length);

    if (bytesPtr == NULL) {
	return TCL_ERROR;
    }
    result = Tcl_ExternalToUtfDStringEx(interp, encoding, bytesPtr, length, flags,
	    &ds, failVarObj ? &errorLocation : NULL);
    /* NOTE: ds must be freed beyond this point even on error */

    switch (result) {
    case TCL_OK:
	errorLocation = TCL_INDEX_NONE;
	break;
    case TCL_ERROR:
	/* Error in parameters. Should not happen. interp will have error */
	goto done;
    default:
	/*
	 * One of the TCL_CONVERT_* errors. If we were not interested in the
	 * error location, interp result would already have been filled in
	 * and we can just return the error. Otherwise, we have to return
	 * what could be decoded and the returned error location.
	 */
	if (failVarObj == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
	break;
    }

    /*
     * TCL_OK or a TCL_CONVERT_* error where the caller wants back as much
     * data as was converted.
     */
    if (failVarObj) {
	Tcl_Obj *failIndex;
	TclNewIndexObj(failIndex, errorLocation);
	if (Tcl_ObjSetVar2(interp, failVarObj, NULL, failIndex,
		TCL_LEAVE_ERR_MSG) == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
    }
    /*
     * Note that we cannot use Tcl_DStringResult here because it will
     * truncate the string at the first null byte.
     */

    Tcl_SetObjResult(interp, Tcl_DStringToObj(&ds));
    result = TCL_OK;

done:
    Tcl_DStringFree(&ds);
    if (encoding) {
	Tcl_FreeEncoding(encoding);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * EncodingConverttoObjCmd --
 *
 *	This command converts a Tcl string into a byte array that
 *	encodes the string according to some encoding.
 *
 * Results:
 *	A standard Tcl result.
 *
 *----------------------------------------------------------------------
 */

int
EncodingConverttoObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *data;		/* String to convert */
    Tcl_DString ds;		/* Buffer to hold the byte array */
    Tcl_Encoding encoding;	/* Encoding to use */
    Tcl_Size length;		/* Length of the string being converted */
    const char *stringPtr;	/* Pointer to the first byte of the string */
    int result;
    int flags;
    Tcl_Obj *failVarObj;
    Tcl_Size errorLocation;

    if (EncodingConvertParseOptions(interp, objc, objv, &encoding, &data,
	    &flags, &failVarObj) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Convert the string to a byte array in 'ds'
     */

    stringPtr = TclGetStringFromObj(data, &length);
    result = Tcl_UtfToExternalDStringEx(interp, encoding, stringPtr, length, flags,
	    &ds, failVarObj ? &errorLocation : NULL);
    /* NOTE: ds must be freed beyond this point even on error */

    switch (result) {
    case TCL_OK:
	errorLocation = TCL_INDEX_NONE;
	break;
    case TCL_ERROR:
	/* Error in parameters. Should not happen. interp will have error */
	goto done;
    default:
	/*
	 * One of the TCL_CONVERT_* errors. If we were not interested in the
	 * error location, interp result would already have been filled in
	 * and we can just return the error. Otherwise, we have to return
	 * what could be decoded and the returned error location.
	 */
	if (failVarObj == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
	break;
    }
    /*
     * TCL_OK or a TCL_CONVERT_* error where the caller wants back as much
     * data as was converted.
     */
    if (failVarObj) {
	Tcl_Obj *failIndex;

	TclNewIndexObj(failIndex, errorLocation);
	if (Tcl_ObjSetVar2(interp, failVarObj, NULL, failIndex,
		TCL_LEAVE_ERR_MSG) == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
    }

    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(
	    (unsigned char*) Tcl_DStringValue(&ds),
	    Tcl_DStringLength(&ds)));

    result = TCL_OK;

done:
    Tcl_DStringFree(&ds);
    if (encoding) {
	Tcl_FreeEncoding(encoding);
    }
    return result;

}

/*
 *----------------------------------------------------------------------
 *
 * EncodingDirsObjCmd --
 *
 *	This command manipulates the encoding search path.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Can set the encoding search path.
 *
 *----------------------------------------------------------------------
 */

int
EncodingDirsObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *dirListObj;

    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?dirList?");
	return TCL_ERROR;
    }
    if (objc == 1) {
	Tcl_SetObjResult(interp, Tcl_GetEncodingSearchPath());
	return TCL_OK;
    }

    dirListObj = objv[1];
    if (Tcl_SetEncodingSearchPath(dirListObj) == TCL_ERROR) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"expected directory list but got \"%s\"",
		TclGetString(dirListObj)));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "ENCODING", "BADPATH",
		(char *)NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, dirListObj);
    return TCL_OK;
}

/*
 *-----------------------------------------------------------------------------
 *
 * EncodingNamesObjCmd --
 *
 *	This command returns a list of the available encoding names
 *
 * Results:
 *	Returns a standard Tcl result
 *
 *-----------------------------------------------------------------------------
 */

int
EncodingNamesObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp* interp,	    /* Tcl interpreter */
    int objc,		    /* Number of command line args */
    Tcl_Obj* const objv[])  /* Vector of command line args */
{
    if (objc > 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    Tcl_GetEncodingNames(interp);
    return TCL_OK;
}

/*
 *-----------------------------------------------------------------------------
 *
 * EncodingProfilesObjCmd --
 *
 *	This command returns a list of the available encoding profiles
 *
 * Results:
 *	Returns a standard Tcl result
 *
 *-----------------------------------------------------------------------------
 */

int
EncodingProfilesObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp* interp,	    /* Tcl interpreter */
    int objc,		    /* Number of command line args */
    Tcl_Obj* const objv[])  /* Vector of command line args */
{
    if (objc > 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    TclGetEncodingProfiles(interp);
    return TCL_OK;
}

/*
 *-----------------------------------------------------------------------------
 *
 * EncodingSystemObjCmd --
 *
 *	This command retrieves or changes the system encoding
 *
 * Results:
 *	Returns a standard Tcl result
 *
 * Side effects:
 *	May change the system encoding.
 *
 *-----------------------------------------------------------------------------
 */

int
EncodingSystemObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp* interp,     /* Tcl interpreter */
    int objc,		    /* Number of command line args */
    Tcl_Obj* const objv[])  /* Vector of command line args */
{
    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?encoding?");
	return TCL_ERROR;
    }
    if (objc == 1) {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj(Tcl_GetEncodingName(NULL), -1));
    } else {
	return Tcl_SetSystemEncoding(interp, TclGetString(objv[1]));
    }
    return TCL_OK;
}

/*
 *-----------------------------------------------------------------------------
 *
 * EncodingUserObjCmd --
 *
 *	This command retrieves the encoding as per the user settings.
 *
 * Results:
 *	Returns a standard Tcl result
 *
 *-----------------------------------------------------------------------------
 */

int
EncodingUserObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp* interp,     /* Tcl interpreter */
    int objc,		    /* Number of command line args */
    Tcl_Obj* const objv[])  /* Vector of command line args */
{
    if (objc > 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    Tcl_DString ds;
    Tcl_GetEncodingNameForUser(&ds);
    Tcl_DStringResult(interp, &ds);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ErrorObjCmd --
 *
 *	This procedure is invoked to process the "error" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ErrorObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *options, *optName;

    if ((objc < 2) || (objc > 4)) {
	Tcl_WrongNumArgs(interp, 1, objv, "message ?errorInfo? ?errorCode?");
	return TCL_ERROR;
    }

    TclNewLiteralStringObj(options, "-code error -level 0");

    if (objc >= 3) {		/* Process the optional info argument */
	TclNewLiteralStringObj(optName, "-errorinfo");
	Tcl_ListObjAppendElement(NULL, options, optName);
	Tcl_ListObjAppendElement(NULL, options, objv[2]);
    }

    if (objc >= 4) {		/* Process the optional code argument */
	TclNewLiteralStringObj(optName, "-errorcode");
	Tcl_ListObjAppendElement(NULL, options, optName);
	Tcl_ListObjAppendElement(NULL, options, objv[3]);
    }

    Tcl_SetObjResult(interp, objv[1]);
    return Tcl_SetReturnOptions(interp, options);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_EvalObjCmd --
 *
 *	This object-based procedure is invoked to process the "eval" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
EvalCmdErrMsg(
    TCL_UNUSED(void **),
    Tcl_Interp *interp,
    int result)
{
    if (result == TCL_ERROR) {
	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"eval\" body line %d)", Tcl_GetErrorLine(interp)));
    }
    return result;
}

int
Tcl_EvalObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNREvalObjCmd, clientData, objc, objv);
}

int
TclNREvalObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *objPtr;
    Interp *iPtr = (Interp *) interp;
    CmdFrame *invoker = NULL;
    int word = 0;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "arg ?arg ...?");
	return TCL_ERROR;
    }

    if (objc == 2) {
	/*
	 * TIP #280. Make argument location available to eval'd script.
	 */

	invoker = iPtr->cmdFramePtr;
	word = 1;
	objPtr = objv[1];
	TclArgumentGet(interp, objPtr, &invoker, &word);
    } else {
	/*
	 * More than one argument: concatenate them together with spaces
	 * between, then evaluate the result. Tcl_EvalObjEx will delete the
	 * object when it decrements its refcount after eval'ing it.
	 *
	 * TIP #280. Make invoking context available to eval'd script, done
	 * with the default values.
	 */

	objPtr = Tcl_ConcatObj(objc-1, objv+1);
    }
    TclNRAddCallback(interp, EvalCmdErrMsg, NULL, NULL, NULL, NULL);
    return TclNREvalObjEx(interp, objPtr, 0, invoker, word);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ExitObjCmd --
 *
 *	This procedure is invoked to process the "exit" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ExitObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_WideInt value;

    if ((objc != 1) && (objc != 2)) {
	Tcl_WrongNumArgs(interp, 1, objv, "?returnCode?");
	return TCL_ERROR;
    }

    if (objc == 1) {
	value = 0;
    } else if (TclGetWideBitsFromObj(interp, objv[1], &value) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_Exit((int)value);
    return TCL_OK;		/* Better not ever reach this! */
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ExprObjCmd --
 *
 *	This object-based procedure is invoked to process the "expr" Tcl
 *	command. See the user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is called in two
 *	circumstances: 1) to execute expr commands that are too complicated or
 *	too unsafe to try compiling directly into an inline sequence of
 *	instructions, and 2) to execute commands where the command name is
 *	computed at runtime and is "expr" or the name to which "expr" was
 *	renamed (e.g., "set z expr; $z 2+3")
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ExprObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRExprObjCmd, clientData, objc, objv);
}

int
TclNRExprObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *resultPtr, *objPtr;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "arg ?arg ...?");
	return TCL_ERROR;
    }

    TclNewObj(resultPtr);
    Tcl_IncrRefCount(resultPtr);
    if (objc == 2) {
	objPtr = objv[1];
	TclNRAddCallback(interp, ExprCallback, resultPtr, NULL, NULL, NULL);
    } else {
	objPtr = Tcl_ConcatObj(objc-1, objv+1);
	TclNRAddCallback(interp, ExprCallback, resultPtr, objPtr, NULL, NULL);
    }

    return Tcl_NRExprObj(interp, objPtr, resultPtr);
}

static int
ExprCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Tcl_Obj *resultPtr = (Tcl_Obj *)data[0];
    Tcl_Obj *objPtr = (Tcl_Obj *)data[1];

    if (objPtr != NULL) {
	Tcl_DecrRefCount(objPtr);
    }

    if (result == TCL_OK) {
	Tcl_SetObjResult(interp, resultPtr);
    }
    Tcl_DecrRefCount(resultPtr);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitFileCmd --
 *
 *	This function builds the "file" Tcl command ensemble. See the user
 *	documentation for details on what that ensemble does.
 *
 *	PLEASE NOTE THAT THIS FAILS WITH FILENAMES AND PATHS WITH EMBEDDED
 *	NULLS. With the object-based Tcl_FS APIs, the above NOTE may no longer
 *	be true. In any case this assertion should be tested.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

Tcl_Command
TclInitFileCmd(
    Tcl_Interp *interp)
{
    /*
     * Note that most subcommands are unsafe because either they manipulate
     * the native filesystem or because they reveal information about the
     * native filesystem.
     */

    static const EnsembleImplMap initMap[] = {
	{"atime",	FileAttrAccessTimeCmd,	TclCompileBasic1Or2ArgCmd, NULL, NULL, 1},
	{"attributes",	TclFileAttrsCmd,	NULL, NULL, NULL, 1},
	{"channels",	TclChannelNamesCmd,	TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
	{"copy",	TclFileCopyCmd,		NULL, NULL, NULL, 1},
	{"delete",	TclFileDeleteCmd,	TclCompileBasicMin0ArgCmd, NULL, NULL, 1},
	{"dirname",	PathDirNameCmd,		TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"executable",	FileAttrIsExecutableCmd, TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"exists",	FileAttrIsExistingCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"extension",	PathExtensionCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"home",	TclFileHomeCmd,		TclCompileBasic0Or1ArgCmd, NULL, NULL, 1},
	{"isdirectory",	FileAttrIsDirectoryCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"isfile",	FileAttrIsFileCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"join",	PathJoinCmd,		TclCompileBasicMin1ArgCmd, NULL, NULL, 0},
	{"link",	TclFileLinkCmd,		TclCompileBasic1To3ArgCmd, NULL, NULL, 1},
	{"lstat",	FileAttrLinkStatCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 1},
	{"mtime",	FileAttrModifyTimeCmd,	TclCompileBasic1Or2ArgCmd, NULL, NULL, 1},
	{"mkdir",	TclFileMakeDirsCmd,	TclCompileBasicMin0ArgCmd, NULL, NULL, 1},
	{"nativename",	PathNativeNameCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"normalize",	PathNormalizeCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"owned",	FileAttrIsOwnedCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"pathtype",	PathTypeCmd,		TclCompileBasic1ArgCmd, NULL, NULL, 0},
	{"readable",	FileAttrIsReadableCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"readlink",	TclFileReadLinkCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"rename",	TclFileRenameCmd,	NULL, NULL, NULL, 1},
	{"rootname",	PathRootNameCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"separator",	FilesystemSeparatorCmd,	TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
	{"size",	FileAttrSizeCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"split",	PathSplitCmd,		TclCompileBasic1ArgCmd, NULL, NULL, 0},
	{"stat",	FileAttrStatCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 1},
	{"system",	PathFilesystemCmd,	TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
	{"tail",	PathTailCmd,		TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"tempdir",	TclFileTempDirCmd,	TclCompileBasic0Or1ArgCmd, NULL, NULL, 1},
	{"tempfile",	TclFileTemporaryCmd,	TclCompileBasic0To2ArgCmd, NULL, NULL, 1},
	{"tildeexpand",	TclFileTildeExpandCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"type",	FileAttrTypeCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{"volumes",	FilesystemVolumesCmd,	TclCompileBasic0ArgCmd, NULL, NULL, 1},
	{"writable",	FileAttrIsWritableCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 1},
	{NULL, NULL, NULL, NULL, NULL, 0}
    };
    return TclMakeEnsemble(interp, "file", initMap);
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrAccessTimeCmd --
 *
 *	This function is invoked to process the "file atime" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	May update the access time on the file, if requested by the user.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrAccessTimeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;
    struct utimbuf tval;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "name ?time?");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
#if defined(_WIN32)
    /* We use a value of 0 to indicate the access time not available */
    if (Tcl_GetAccessTimeFromStat(&buf) == 0) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"could not get access time for file \"%s\"",
		TclGetString(objv[1])));
	return TCL_ERROR;
    }
#endif

    if (objc == 3) {
	/*
	 * Need separate variable for reading longs from an object on 64-bit
	 * platforms. [Bug 698146]
	 */

	Tcl_WideInt newTime;

	if (TclGetWideIntFromObj(interp, objv[2], &newTime) != TCL_OK) {
	    return TCL_ERROR;
	}

	tval.actime = newTime;
	tval.modtime = Tcl_GetModificationTimeFromStat(&buf);

	if (Tcl_FSUtime(objv[1], &tval) != 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "could not set access time for file \"%s\": %s",
		    TclGetString(objv[1]), Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}

	/*
	 * Do another stat to ensure that the we return the new recognized
	 * atime - hopefully the same as the one we sent in. However, fs's
	 * like FAT don't even know what atime is.
	 */

	if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(Tcl_GetAccessTimeFromStat(&buf)));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrModifyTimeCmd --
 *
 *	This function is invoked to process the "file mtime" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	May update the modification time on the file, if requested by the
 *	user.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrModifyTimeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;
    struct utimbuf tval;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "name ?time?");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
#if defined(_WIN32)
    /* We use a value of 0 to indicate the modification time not available */
    if (Tcl_GetModificationTimeFromStat(&buf) == 0) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"could not get modification time for file \"%s\"",
		TclGetString(objv[1])));
	return TCL_ERROR;
    }
#endif
    if (objc == 3) {
	/*
	 * Need separate variable for reading longs from an object on 64-bit
	 * platforms. [Bug 698146]
	 */

	Tcl_WideInt newTime;

	if (TclGetWideIntFromObj(interp, objv[2], &newTime) != TCL_OK) {
	    return TCL_ERROR;
	}

	tval.actime = Tcl_GetAccessTimeFromStat(&buf);
	tval.modtime = newTime;

	if (Tcl_FSUtime(objv[1], &tval) != 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "could not set modification time for file \"%s\": %s",
		    TclGetString(objv[1]), Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}

	/*
	 * Do another stat to ensure that the we return the new recognized
	 * mtime - hopefully the same as the one we sent in.
	 */

	if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(Tcl_GetModificationTimeFromStat(&buf)));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrLinkStatCmd --
 *
 *	This function is invoked to process the "file lstat" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Writes to an array named by the user.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrLinkStatCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "name ?varName?");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSLstat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc == 2) {
	return StoreStatData(interp, NULL, &buf);
    } else {
	return StoreStatData(interp, objv[2], &buf);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrStatCmd --
 *
 *	This function is invoked to process the "file stat" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Writes to an array named by the user.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrStatCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "name ?varName?");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc == 2) {
	return StoreStatData(interp, NULL, &buf);
    } else {
	return StoreStatData(interp, objv[2], &buf);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrTypeCmd --
 *
 *	This function is invoked to process the "file type" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrTypeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSLstat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    GetTypeFromMode((unsigned short) buf.st_mode), -1));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrSizeCmd --
 *
 *	This function is invoked to process the "file size" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrSizeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    if (GetStatBuf(interp, objv[1], Tcl_FSStat, &buf) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(buf.st_size));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsDirectoryCmd --
 *
 *	This function is invoked to process the "file isdirectory" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsDirectoryCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;
    int value = 0;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    if (GetStatBuf(NULL, objv[1], Tcl_FSStat, &buf) == TCL_OK) {
	value = S_ISDIR(buf.st_mode);
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(value));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsExecutableCmd --
 *
 *	This function is invoked to process the "file executable" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsExecutableCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    return CheckAccess(interp, objv[1], X_OK);
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsExistingCmd --
 *
 *	This function is invoked to process the "file exists" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsExistingCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    return CheckAccess(interp, objv[1], F_OK);
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsFileCmd --
 *
 *	This function is invoked to process the "file isfile" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsFileCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_StatBuf buf;
    int value = 0;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    if (GetStatBuf(NULL, objv[1], Tcl_FSStat, &buf) == TCL_OK) {
	value = S_ISREG(buf.st_mode);
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(value));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsOwnedCmd --
 *
 *	This function is invoked to process the "file owned" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsOwnedCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
#ifdef __CYGWIN__
#define geteuid() (short)(geteuid)()
#endif
#if !defined(_WIN32)
    Tcl_StatBuf buf;
#endif
    int value = 0;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }

    Tcl_Obj *normPathPtr = Tcl_FSGetNormalizedPath(interp, objv[1]);
    /* Note normPathPtr owned by Tcl, no need to free it */
    if (normPathPtr) {
	if (TclIsZipfsPath(TclGetString(normPathPtr))) {
	    return CheckAccess(interp, objv[1], F_OK);
	}
	/* Not zipfs, try native. */
    }

    /*
     * Note use objv[1] below, NOT normPathPtr even if not NULL because
     * for native paths we may not want links to be resolved.
     */

#if defined(_WIN32)
    value = TclWinFileOwned(objv[1]);
#else
    if (GetStatBuf(NULL, objv[1], Tcl_FSStat, &buf) == TCL_OK) {
	value = (geteuid() == buf.st_uid);
    }
#endif
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(value));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsReadableCmd --
 *
 *	This function is invoked to process the "file readable" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsReadableCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    return CheckAccess(interp, objv[1], R_OK);
}

/*
 *----------------------------------------------------------------------
 *
 * FileAttrIsWritableCmd --
 *
 *	This function is invoked to process the "file writable" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileAttrIsWritableCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    return CheckAccess(interp, objv[1], W_OK);
}

/*
 *----------------------------------------------------------------------
 *
 * PathDirNameCmd --
 *
 *	This function is invoked to process the "file dirname" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathDirNameCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *dirPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    dirPtr = TclPathPart(interp, objv[1], TCL_PATH_DIRNAME);
    if (dirPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, dirPtr);
    Tcl_DecrRefCount(dirPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathExtensionCmd --
 *
 *	This function is invoked to process the "file extension" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathExtensionCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *dirPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    dirPtr = TclPathPart(interp, objv[1], TCL_PATH_EXTENSION);
    if (dirPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, dirPtr);
    Tcl_DecrRefCount(dirPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathRootNameCmd --
 *
 *	This function is invoked to process the "file root" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathRootNameCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *dirPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    dirPtr = TclPathPart(interp, objv[1], TCL_PATH_ROOT);
    if (dirPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, dirPtr);
    Tcl_DecrRefCount(dirPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathTailCmd --
 *
 *	This function is invoked to process the "file tail" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathTailCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *dirPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    dirPtr = TclPathPart(interp, objv[1], TCL_PATH_TAIL);
    if (dirPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, dirPtr);
    Tcl_DecrRefCount(dirPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathFilesystemCmd --
 *
 *	This function is invoked to process the "file system" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathFilesystemCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *fsInfo;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    fsInfo = Tcl_FSFileSystemInfo(objv[1]);
    if (fsInfo == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj("unrecognised path", -1));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "FILESYSTEM",
		TclGetString(objv[1]), (char *)NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, fsInfo);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathJoinCmd --
 *
 *	This function is invoked to process the "file join" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathJoinCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name ?name ...?");
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, TclJoinPath(objc - 1, objv + 1, 0));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathNativeNameCmd --
 *
 *	This function is invoked to process the "file nativename" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathNativeNameCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_DString ds;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    if (Tcl_TranslateFileName(interp, TclGetString(objv[1]), &ds) == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_DStringToObj(&ds));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathNormalizeCmd --
 *
 *	This function is invoked to process the "file normalize" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathNormalizeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *fileName;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    fileName = Tcl_FSGetNormalizedPath(interp, objv[1]);
    if (fileName == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, fileName);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathSplitCmd --
 *
 *	This function is invoked to process the "file split" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathSplitCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *res;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    res = Tcl_FSSplitPath(objv[1], (Tcl_Size *)NULL);
    if (res == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"could not read \"%s\": no such file or directory",
		TclGetString(objv[1])));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "PATHSPLIT", "NONESUCH",
		(char *)NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, res);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * PathTypeCmd --
 *
 *	This function is invoked to process the "file pathtype" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PathTypeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Obj *typeName;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "name");
	return TCL_ERROR;
    }
    switch (Tcl_FSGetPathType(objv[1])) {
    case TCL_PATH_ABSOLUTE:
	TclNewLiteralStringObj(typeName, "absolute");
	break;
    case TCL_PATH_RELATIVE:
	TclNewLiteralStringObj(typeName, "relative");
	break;
    case TCL_PATH_VOLUME_RELATIVE:
	TclNewLiteralStringObj(typeName, "volumerelative");
	break;
    default:
	TCL_UNREACHABLE();
    }
    Tcl_SetObjResult(interp, typeName);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FilesystemSeparatorCmd --
 *
 *	This function is invoked to process the "file separator" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FilesystemSeparatorCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc < 1 || objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?name?");
	return TCL_ERROR;
    }
    if (objc == 1) {
	const char *separator = NULL;

	switch (tclPlatform) {
	case TCL_PLATFORM_UNIX:
	    separator = "/";
	    break;
	case TCL_PLATFORM_WINDOWS:
	    separator = "\\";
	    break;
	}
	Tcl_SetObjResult(interp, Tcl_NewStringObj(separator, 1));
    } else {
	Tcl_Obj *separatorObj = Tcl_FSPathSeparator(objv[1]);

	if (separatorObj == NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "unrecognised path", -1));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "FILESYSTEM",
		    TclGetString(objv[1]), (char *)NULL);
	    return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, separatorObj);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FilesystemVolumesCmd --
 *
 *	This function is invoked to process the "file volumes" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FilesystemVolumesCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_FSListVolumes());
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * CheckAccess --
 *
 *	Utility procedure used by Tcl_FileObjCmd() to query file attributes
 *	available through the access() system call.
 *
 * Results:
 *	Always returns TCL_OK. Sets interp's result to boolean true or false
 *	depending on whether the file has the specified attribute.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static int
CheckAccess(
    Tcl_Interp *interp,		/* Interp for status return. Must not be
				 * NULL. */
    Tcl_Obj *pathPtr,		/* Name of file to check. */
    int mode)			/* Attribute to check; passed as argument to
				 * access(). */
{
    int value;
    Tcl_DString ds;

    if (Tcl_FSConvertToPathType(interp, pathPtr) != TCL_OK) {
	value = 0;
    } else if (Tcl_UtfToExternalDStringEx(NULL, TCLFSENCODING, TclGetString(pathPtr),
	    TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	value = 0;
	Tcl_DStringFree(&ds);
    } else {
	Tcl_DStringFree(&ds);
	value = (Tcl_FSAccess(pathPtr, mode) == 0);
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(value));

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * GetStatBuf --
 *
 *	Utility procedure used by Tcl_FileObjCmd() to query file attributes
 *	available through the stat() or lstat() system call.
 *
 * Results:
 *	The return value is TCL_OK if the specified file exists and can be
 *	stat'ed, TCL_ERROR otherwise. If TCL_ERROR is returned, an error
 *	message is left in interp's result. If TCL_OK is returned, *statPtr is
 *	filled with information about the specified file.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static int
GetStatBuf(
    Tcl_Interp *interp,		/* Interp for error return. May be NULL. */
    Tcl_Obj *pathPtr,		/* Path name to examine. */
    Tcl_FSStatProc *statProc,	/* Either stat() or lstat() depending on
				 * desired behavior. */
    Tcl_StatBuf *statPtr)	/* Filled with info about file obtained by
				 * calling (*statProc)(). */
{
    int status;
    Tcl_DString ds;

    if (Tcl_FSConvertToPathType(interp, pathPtr) != TCL_OK) {
	return TCL_ERROR;
    }

    if (Tcl_UtfToExternalDStringEx(NULL, TCLFSENCODING, TclGetString(pathPtr),
	    TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	status = -1;
    } else {
	status = statProc(pathPtr, statPtr);
    }
    Tcl_DStringFree(&ds);

    if (status < 0) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "could not read \"%s\": %s",
		    TclGetString(pathPtr), Tcl_PosixError(interp)));
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StoreStatData --
 *
 *	This is a utility procedure that breaks out the fields of a "stat"
 *	structure and stores them in textual form into the elements of an
 *	associative array (if given) or returns a dictionary.
 *
 * Results:
 *	Returns a standard Tcl return value. If an error occurs then a message
 *	is left in interp's result.
 *
 * Side effects:
 *	Elements of the associative array given by "varName" are modified.
 *
 *----------------------------------------------------------------------
 */

static int
StoreStatData(
    Tcl_Interp *interp,		/* Interpreter for error reports. */
    Tcl_Obj *varName,		/* Name of associative array variable in which
				 * to store stat results. */
    Tcl_StatBuf *statPtr)	/* Pointer to buffer containing stat data to
				 * store in varName. */
{
    Tcl_Obj *field, *value, *result;
    unsigned short mode;

    if (varName == NULL) {
	TclNewObj(result);
	Tcl_IncrRefCount(result);
#define DOBJPUT(key, objValue)                  \
	Tcl_DictObjPut(NULL, result,            \
	    Tcl_NewStringObj((key), -1),        \
	    (objValue));
	DOBJPUT("dev",	Tcl_NewWideIntObj((long)statPtr->st_dev));
	DOBJPUT("ino",	Tcl_NewWideIntObj((Tcl_WideInt)statPtr->st_ino));
	DOBJPUT("nlink",	Tcl_NewWideIntObj((long)statPtr->st_nlink));
	DOBJPUT("uid",	Tcl_NewWideIntObj((long)statPtr->st_uid));
	DOBJPUT("gid",	Tcl_NewWideIntObj((long)statPtr->st_gid));
	DOBJPUT("size",	Tcl_NewWideIntObj((Tcl_WideInt)statPtr->st_size));
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
	DOBJPUT("blocks",	Tcl_NewWideIntObj((Tcl_WideInt)statPtr->st_blocks));
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
	DOBJPUT("blksize", Tcl_NewWideIntObj((long)statPtr->st_blksize));
#endif
	DOBJPUT("atime",	Tcl_NewWideIntObj(Tcl_GetAccessTimeFromStat(statPtr)));
	DOBJPUT("mtime",	Tcl_NewWideIntObj(Tcl_GetModificationTimeFromStat(statPtr)));
	DOBJPUT("ctime",	Tcl_NewWideIntObj(Tcl_GetChangeTimeFromStat(statPtr)));
	mode = (unsigned short) statPtr->st_mode;
	DOBJPUT("mode",	Tcl_NewWideIntObj(mode));
	DOBJPUT("type",	Tcl_NewStringObj(GetTypeFromMode(mode), -1));
#undef DOBJPUT
	Tcl_SetObjResult(interp, result);
	Tcl_DecrRefCount(result);
	return TCL_OK;
    }

    /*
     * Might be a better idea to call Tcl_SetVar2Ex() instead, except we want
     * to have an object (i.e. possibly cached) array variable name but a
     * string element name, so no API exists. Messy.
     */

#define STORE_ARY(fieldName, object) \
    TclNewLiteralStringObj(field, fieldName);				\
    Tcl_IncrRefCount(field);						\
    value = (object);							\
    if (Tcl_ObjSetVar2(interp,varName,field,value,TCL_LEAVE_ERR_MSG)==NULL) { \
	TclDecrRefCount(field);						\
	return TCL_ERROR;						\
    }									\
    TclDecrRefCount(field);

    /*
     * Watch out porters; the inode is meant to be an *unsigned* value, so the
     * cast might fail when there isn't a real arithmetic 'long long' type...
     */

    STORE_ARY("dev",	Tcl_NewWideIntObj((long)statPtr->st_dev));
    STORE_ARY("ino",	Tcl_NewWideIntObj(statPtr->st_ino));
    STORE_ARY("nlink",	Tcl_NewWideIntObj((long)statPtr->st_nlink));
    STORE_ARY("uid",	Tcl_NewWideIntObj((long)statPtr->st_uid));
    STORE_ARY("gid",	Tcl_NewWideIntObj((long)statPtr->st_gid));
    STORE_ARY("size",	Tcl_NewWideIntObj(statPtr->st_size));
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
    STORE_ARY("blocks",	Tcl_NewWideIntObj(statPtr->st_blocks));
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
    STORE_ARY("blksize", Tcl_NewWideIntObj((long)statPtr->st_blksize));
#endif
#ifdef HAVE_STRUCT_STAT_ST_RDEV
    if (S_ISCHR(statPtr->st_mode) || S_ISBLK(statPtr->st_mode)) {
	STORE_ARY("rdev", Tcl_NewWideIntObj((long) statPtr->st_rdev));
    }
#endif
    STORE_ARY("atime",	Tcl_NewWideIntObj(Tcl_GetAccessTimeFromStat(statPtr)));
    STORE_ARY("mtime",	Tcl_NewWideIntObj(
	    Tcl_GetModificationTimeFromStat(statPtr)));
    STORE_ARY("ctime",	Tcl_NewWideIntObj(Tcl_GetChangeTimeFromStat(statPtr)));
    mode = (unsigned short) statPtr->st_mode;
    STORE_ARY("mode",	Tcl_NewWideIntObj(mode));
    STORE_ARY("type",	Tcl_NewStringObj(GetTypeFromMode(mode), -1));
#undef STORE_ARY

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * GetTypeFromMode --
 *
 *	Given a mode word, returns a string identifying the type of a file.
 *
 * Results:
 *	A static text string giving the file type from mode.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static const char *
GetTypeFromMode(
    int mode)
{
    if (S_ISREG(mode)) {
	return "file";
    } else if (S_ISDIR(mode)) {
	return "directory";
    } else if (S_ISCHR(mode)) {
	return "characterSpecial";
    } else if (S_ISBLK(mode)) {
	return "blockSpecial";
    } else if (S_ISFIFO(mode)) {
	return "fifo";
#ifdef S_ISLNK
    } else if (S_ISLNK(mode)) {
	return "link";
#endif
#ifdef S_ISSOCK
    } else if (S_ISSOCK(mode)) {
	return "socket";
#endif
    }
    return "unknown";
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ForObjCmd --
 *
 *	This procedure is invoked to process the "for" Tcl command. See the
 *	user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "for" or the name to which
 *	"for" was renamed: e.g.,
 *	"set z for; $z {set i 0} {$i<100} {incr i} {puts $i}"
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 * Notes:
 *	This command is split into a lot of pieces so that it can avoid doing
 *	reentrant TEBC calls. This makes things rather hard to follow, but
 *	here's the plan:
 *
 *	NR:	---------------_\
 *	Direct:	Tcl_ForObjCmd -> TclNRForObjCmd
 *					|
 *				ForSetupCallback
 *					|
 *	[while] ------------> TclNRForIterCallback <---------.
 *					|		     |
 *				 ForCondCallback	     |
 *					|		     |
 *				 ForNextCallback ------------|
 *					|		     |
 *			       ForPostNextCallback	     |
 *					|____________________|
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ForObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRForObjCmd, clientData, objc, objv);
}

int
TclNRForObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;
    ForIterData *iterPtr;

    if (objc != 5) {
	Tcl_WrongNumArgs(interp, 1, objv, "start test next command");
	return TCL_ERROR;
    }

    TclSmallAllocEx(interp, sizeof(ForIterData), iterPtr);
    iterPtr->cond = objv[2];
    iterPtr->body = objv[4];
    iterPtr->next = objv[3];
    iterPtr->msg  = "\n    (\"for\" body line %d)";
    iterPtr->word = 4;

    TclNRAddCallback(interp, ForSetupCallback, iterPtr, NULL, NULL, NULL);

    /*
     * TIP #280. Make invoking context available to initial script.
     */

    return TclNREvalObjEx(interp, objv[1], 0, iPtr->cmdFramePtr, 1);
}

static int
ForSetupCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    ForIterData *iterPtr = (ForIterData *)data[0];

    if (result != TCL_OK) {
	if (result == TCL_ERROR) {
	    Tcl_AddErrorInfo(interp, "\n    (\"for\" initial command)");
	}
	TclSmallFreeEx(interp, iterPtr);
	return result;
    }
    TclNRAddCallback(interp, TclNRForIterCallback, iterPtr, NULL, NULL, NULL);
    return TCL_OK;
}

int
TclNRForIterCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    ForIterData *iterPtr = (ForIterData *)data[0];
    Tcl_Obj *boolObj;

    switch (result) {
    case TCL_OK:
    case TCL_CONTINUE:
	/*
	 * We need to reset the result before evaluating the expression.
	 * Otherwise, any error message will be appended to the result of the
	 * last evaluation.
	 */

	Tcl_ResetResult(interp);
	TclNewObj(boolObj);
	TclNRAddCallback(interp, ForCondCallback, iterPtr, boolObj, NULL,
		NULL);
	return Tcl_NRExprObj(interp, iterPtr->cond, boolObj);
    case TCL_BREAK:
	result = TCL_OK;
	Tcl_ResetResult(interp);
	break;
    case TCL_ERROR:
	Tcl_AppendObjToErrorInfo(interp,
		Tcl_ObjPrintf(iterPtr->msg, Tcl_GetErrorLine(interp)));
    }
    TclSmallFreeEx(interp, iterPtr);
    return result;
}

static int
ForCondCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    ForIterData *iterPtr = (ForIterData *)data[0];
    Tcl_Obj *boolObj = (Tcl_Obj *)data[1];
    int value;

    if (result != TCL_OK) {
	Tcl_DecrRefCount(boolObj);
	TclSmallFreeEx(interp, iterPtr);
	return result;
    } else if (Tcl_GetBooleanFromObj(interp, boolObj, &value) != TCL_OK) {
	Tcl_DecrRefCount(boolObj);
	TclSmallFreeEx(interp, iterPtr);
	return TCL_ERROR;
    }
    Tcl_DecrRefCount(boolObj);

    if (value) {
	/* TIP #280. */
	if (iterPtr->next) {
	    TclNRAddCallback(interp, ForNextCallback, iterPtr, NULL, NULL,
		    NULL);
	} else {
	    TclNRAddCallback(interp, TclNRForIterCallback, iterPtr, NULL,
		    NULL, NULL);
	}
	return TclNREvalObjEx(interp, iterPtr->body, 0, iPtr->cmdFramePtr,
		iterPtr->word);
    }
    TclSmallFreeEx(interp, iterPtr);
    return result;
}

static int
ForNextCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    ForIterData *iterPtr = (ForIterData *)data[0];
    Tcl_Obj *next = iterPtr->next;

    if ((result == TCL_OK) || (result == TCL_CONTINUE)) {
	TclNRAddCallback(interp, ForPostNextCallback, iterPtr, NULL, NULL,
		NULL);

	/*
	 * TIP #280. Make invoking context available to next script.
	 */

	return TclNREvalObjEx(interp, next, 0, iPtr->cmdFramePtr, 3);
    }

    TclNRAddCallback(interp, TclNRForIterCallback, iterPtr, NULL, NULL, NULL);
    return result;
}

static int
ForPostNextCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    ForIterData *iterPtr = (ForIterData *)data[0];

    if ((result != TCL_BREAK) && (result != TCL_OK)) {
	if (result == TCL_ERROR) {
	    Tcl_AddErrorInfo(interp, "\n    (\"for\" loop-end command)");
	    TclSmallFreeEx(interp, iterPtr);
	}
	return result;
    }
    TclNRAddCallback(interp, TclNRForIterCallback, iterPtr, NULL, NULL, NULL);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ForeachObjCmd, TclNRForeachCmd, EachloopCmd --
 *
 *	This object-based procedure is invoked to process the "foreach" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ForeachObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRForeachCmd, clientData, objc, objv);
}

int
TclNRForeachCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    return EachloopCmd(interp, TCL_EACH_KEEP_NONE, objc, objv);
}

int
Tcl_LmapObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRLmapCmd, clientData, objc, objv);
}

int
TclNRLmapCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    return EachloopCmd(interp, TCL_EACH_COLLECT, objc, objv);
}

static int
EachloopCmd(
    Tcl_Interp *interp,		/* Our context for variables and script
				 * evaluation. */
    int collect,		/* Select collecting or accumulating mode
				 * (TCL_EACH_*) */
    int objc,			/* The arguments being passed in... */
    Tcl_Obj *const objv[])
{
    int numLists = (objc-2) / 2;
    struct ForeachState *statePtr;
    int i, result;
    Tcl_Size j;

    if (objc < 4 || (objc%2 != 0)) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"varList list ?varList list ...? command");
	return TCL_ERROR;
    }

    /*
     * Manage numList parallel value lists.
     * statePtr->argvList[i] is a value list counted by statePtr->argcList[i];
     * statePtr->varvList[i] is the list of variables associated with the
     *		value list;
     * statePtr->varcList[i] is the number of variables associated with the
     *		value list;
     * statePtr->index[i] is the current pointer into the value list
     *		statePtr->argvList[i].
     *
     * The setting up of all of these pointers is moderately messy, but allows
     * the rest of this code to be simple and for us to use a single memory
     * allocation for better performance.
     */

    statePtr = (struct ForeachState *)TclStackAlloc(interp,
	    sizeof(struct ForeachState) + 3 * numLists * sizeof(Tcl_Size)
	    + 2 * numLists * (sizeof(Tcl_Obj **) + sizeof(Tcl_Obj *)));
    memset(statePtr, 0,
	    sizeof(struct ForeachState) + 3 * numLists * sizeof(Tcl_Size)
	    + 2 * numLists * (sizeof(Tcl_Obj **) + sizeof(Tcl_Obj *)));
    statePtr->varvList = (Tcl_Obj ***) (statePtr + 1);
    statePtr->argvList = statePtr->varvList + numLists;
    statePtr->vCopyList = (Tcl_Obj **) (statePtr->argvList + numLists);
    statePtr->aCopyList = statePtr->vCopyList + numLists;
    statePtr->index = (Tcl_Size *) (statePtr->aCopyList + numLists);
    statePtr->varcList = statePtr->index + numLists;
    statePtr->argcList = statePtr->varcList + numLists;

    statePtr->numLists = numLists;
    statePtr->bodyPtr = objv[objc - 1];
    statePtr->bodyIdx = objc - 1;

    if (collect == TCL_EACH_COLLECT) {
	statePtr->resultList = Tcl_NewListObj(0, NULL);
    } else {
	statePtr->resultList = NULL;
    }

    /*
     * Break up the value lists and variable lists into elements.
     */

    for (i=0 ; i<numLists ; i++) {
	/* List */
	/* Variables */
	statePtr->vCopyList[i] = TclListObjCopy(interp, objv[1+i*2]);
	if (statePtr->vCopyList[i] == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
	result = TclListObjLength(interp, statePtr->vCopyList[i],
	    &statePtr->varcList[i]);
	if (result != TCL_OK) {
	    result = TCL_ERROR;
	    goto done;
	}
	if (statePtr->varcList[i] < 1) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"%s varlist is empty",
		(statePtr->resultList != NULL ? "lmap" : "foreach")));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION",
		(statePtr->resultList != NULL ? "LMAP" : "FOREACH"),
		"NEEDVARS", (char *)NULL);
	    result = TCL_ERROR;
	    goto done;
	}
	TclListObjGetElements(NULL, statePtr->vCopyList[i],
	    &statePtr->varcList[i], &statePtr->varvList[i]);

	/* Values */
	if (TclObjTypeHasProc(objv[2+i*2],indexProc)) {
	    /* Special case for AbstractList */
	    statePtr->aCopyList[i] = Tcl_DuplicateObj(objv[2+i*2]);
	    if (statePtr->aCopyList[i] == NULL) {
		result = TCL_ERROR;
		goto done;
	    }
	    /* Don't compute values here, wait until the last moment */
	    statePtr->argcList[i] = TclObjTypeLength(statePtr->aCopyList[i]);
	} else {
	    /* List values */
	    statePtr->aCopyList[i] = TclListObjCopy(interp, objv[2+i*2]);
	    if (statePtr->aCopyList[i] == NULL) {
		result = TCL_ERROR;
		goto done;
	    }
	    result = TclListObjGetElements(interp, statePtr->aCopyList[i],
		&statePtr->argcList[i], &statePtr->argvList[i]);
	    if (result != TCL_OK) {
		goto done;
	    }
	}
	/* account for variable <> value mismatch */
	j = statePtr->argcList[i] / statePtr->varcList[i];
	if ((statePtr->argcList[i] % statePtr->varcList[i]) != 0) {
	    j++;
	}
	if (j > statePtr->maxj) {
	    statePtr->maxj = j;
	}
    }

    /*
     * If there is any work to do, assign the variables and set things going
     * non-recursively.
     */

    if (statePtr->maxj > 0) {
	result = ForeachAssignments(interp, statePtr);
	if (result == TCL_ERROR) {
	    goto done;
	}

	TclNRAddCallback(interp, ForeachLoopStep, statePtr, NULL, NULL, NULL);
	return TclNREvalObjEx(interp, objv[objc-1], 0,
		((Interp *) interp)->cmdFramePtr, objc-1);
    }

    /*
     * This cleanup stage is only used when an error occurs during setup or if
     * there is no work to do.
     */

    result = TCL_OK;
  done:
    ForeachCleanup(interp, statePtr);
    return result;
}

/*
 * Post-body processing handler.
 */

static int
ForeachLoopStep(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    struct ForeachState *statePtr = (struct ForeachState *)data[0];

    /*
     * Process the result code from this run of the [foreach] body. Note that
     * this switch uses fallthroughs in several places. Maintainer aware!
     */

    switch (result) {
    case TCL_CONTINUE:
	result = TCL_OK;
	break;
    case TCL_OK:
	if (statePtr->resultList != NULL) {
	    result = Tcl_ListObjAppendElement(
		interp, statePtr->resultList, Tcl_GetObjResult(interp));
	    if (result != TCL_OK) {
		/* e.g. memory alloc failure on big data tests */
		goto done;
	    }
	}
	break;
    case TCL_BREAK:
	result = TCL_OK;
	goto finish;
    case TCL_ERROR:
	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"%s\" body line %d)",
		(statePtr->resultList != NULL ? "lmap" : "foreach"),
		Tcl_GetErrorLine(interp)));
	TCL_FALLTHROUGH();
    default:
	goto done;
    }

    /*
     * Test if there is work still to be done. If so, do the next round of
     * variable assignments, reschedule ourselves and run the body again.
     */

    if (statePtr->maxj > ++statePtr->j) {
	result = ForeachAssignments(interp, statePtr);
	if (result == TCL_ERROR) {
	    goto done;
	}

	TclNRAddCallback(interp, ForeachLoopStep, statePtr, NULL, NULL, NULL);
	return TclNREvalObjEx(interp, statePtr->bodyPtr, 0,
		((Interp *) interp)->cmdFramePtr, statePtr->bodyIdx);
    }

    /*
     * We're done. Tidy up our work space and finish off.
     */

  finish:
    if (statePtr->resultList == NULL) {
	Tcl_ResetResult(interp);
    } else {
	Tcl_SetObjResult(interp, statePtr->resultList);
	statePtr->resultList = NULL;	/* Don't clean it up */
    }

  done:
    ForeachCleanup(interp, statePtr);
    return result;
}

/*
 * Factored out code to do the assignments in [foreach].
 */

static inline int
ForeachAssignments(
    Tcl_Interp *interp,
    struct ForeachState *statePtr)
{
    int i;
    Tcl_Size v, k;
    Tcl_Obj *valuePtr, *varValuePtr;

    for (i=0 ; i<statePtr->numLists ; i++) {
	int isAbstractList =
		TclObjTypeHasProc(statePtr->aCopyList[i],indexProc) != NULL;

	for (v=0 ; v<statePtr->varcList[i] ; v++) {
	    k = statePtr->index[i]++;
	    if (k < statePtr->argcList[i]) {
		if (isAbstractList) {
		    if (TclObjTypeIndex(interp, statePtr->aCopyList[i], k, &valuePtr) != TCL_OK) {
			Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
				"\n    (setting %s loop variable \"%s\")",
				(statePtr->resultList != NULL ? "lmap" : "foreach"),
				TclGetString(statePtr->varvList[i][v])));
			return TCL_ERROR;
		    }
		} else {
		    valuePtr = statePtr->argvList[i][k];
		}
	    } else {
		TclNewObj(valuePtr);	/* Empty string */
	    }

	    varValuePtr = Tcl_ObjSetVar2(interp, statePtr->varvList[i][v],
		    NULL, valuePtr, TCL_LEAVE_ERR_MSG);

	    if (varValuePtr == NULL) {
		Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
			"\n    (setting %s loop variable \"%s\")",
			(statePtr->resultList != NULL ? "lmap" : "foreach"),
			TclGetString(statePtr->varvList[i][v])));
		return TCL_ERROR;
	    }
	}
    }

    return TCL_OK;
}

/*
 * Factored out code for cleaning up the state of the foreach.
 */

static inline void
ForeachCleanup(
    Tcl_Interp *interp,
    struct ForeachState *statePtr)
{
    int i;

    for (i=0 ; i<statePtr->numLists ; i++) {
	if (statePtr->vCopyList[i]) {
	    TclDecrRefCount(statePtr->vCopyList[i]);
	}
	if (statePtr->aCopyList[i]) {
	    TclDecrRefCount(statePtr->aCopyList[i]);
	}
    }
    if (statePtr->resultList != NULL) {
	TclDecrRefCount(statePtr->resultList);
    }
    TclStackFree(interp, statePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FormatObjCmd --
 *
 *	This procedure is invoked to process the "format" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FormatObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *resultPtr;		/* Where result is stored finally. */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "formatString ?arg ...?");
	return TCL_ERROR;
    }

    resultPtr = Tcl_Format(interp, TclGetString(objv[1]), objc-2, objv+2);
    if (resultPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, resultPtr);
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

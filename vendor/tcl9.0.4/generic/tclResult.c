/*
 * tclResult.c --
 *
 *	This file contains code to manage the interpreter result.
 *
 * Copyright © 1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/*
 * Indices of the standard return options dictionary keys.
 */

enum returnKeys {
    KEY_CODE,	KEY_ERRORCODE,	KEY_ERRORINFO,	KEY_ERRORLINE,
    KEY_LEVEL,	KEY_OPTIONS,	KEY_ERRORSTACK,	KEY_LAST
};

/*
 * Function prototypes for local functions in this file:
 */

static Tcl_Obj **	GetKeys(void);
static void		ReleaseKeys(void *clientData);
static void		ResetObjResult(Interp *iPtr);

/*
 * This structure is used to take a snapshot of the interpreter state in
 * Tcl_SaveInterpState. You can snapshot the state, execute a command, and
 * then back up to the result or the error that was previously in progress.
 */

typedef struct {
    int status;			/* return code status */
    int flags;			/* Each remaining field saves the */
    int returnLevel;		/* corresponding field of the Interp */
    int returnCode;		/* struct. These fields taken together are */
    Tcl_Obj *errorInfo;		/* the "state" of the interp. */
    Tcl_Obj *errorCode;
    Tcl_Obj *returnOpts;
    Tcl_Obj *objResult;
    Tcl_Obj *errorStack;
    int resetErrorStack;
} InterpState;

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SaveInterpState --
 *
 *	Fills a token with a snapshot of the current state of the interpreter.
 *	The snapshot can be restored at any point by Tcl_RestoreInterpState.
 *
 *	The token returned must be eventually passed to one of the routines
 *	Tcl_RestoreInterpState or Tcl_DiscardInterpState, or there will be a
 *	memory leak.
 *
 * Results:
 *	Returns a token representing the interp state.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_InterpState
Tcl_SaveInterpState(
    Tcl_Interp *interp,		/* Interpreter's state to be saved */
    int status)			/* status code for current operation */
{
    Interp *iPtr = (Interp *) interp;
    InterpState *statePtr = (InterpState *)Tcl_Alloc(sizeof(InterpState));

    statePtr->status = status;
    statePtr->flags = iPtr->flags & ERR_ALREADY_LOGGED;
    statePtr->returnLevel = iPtr->returnLevel;
    statePtr->returnCode = iPtr->returnCode;
    statePtr->errorInfo = iPtr->errorInfo;
    statePtr->errorStack = iPtr->errorStack;
    statePtr->resetErrorStack = iPtr->resetErrorStack;
    if (statePtr->errorInfo) {
	Tcl_IncrRefCount(statePtr->errorInfo);
    }
    statePtr->errorCode = iPtr->errorCode;
    if (statePtr->errorCode) {
	Tcl_IncrRefCount(statePtr->errorCode);
    }
    statePtr->returnOpts = iPtr->returnOpts;
    if (statePtr->returnOpts) {
	Tcl_IncrRefCount(statePtr->returnOpts);
    }
    if (statePtr->errorStack) {
	Tcl_IncrRefCount(statePtr->errorStack);
    }
    statePtr->objResult = Tcl_GetObjResult(interp);
    Tcl_IncrRefCount(statePtr->objResult);
    return (Tcl_InterpState) statePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_RestoreInterpState --
 *
 *	Accepts an interp and a token previously returned by
 *	Tcl_SaveInterpState. Restore the state of the interp to what it was at
 *	the time of the Tcl_SaveInterpState call.
 *
 * Results:
 *	Returns the status value originally passed in to Tcl_SaveInterpState.
 *
 * Side effects:
 *	Restores the interp state and frees memory held by token.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_RestoreInterpState(
    Tcl_Interp *interp,		/* Interpreter's state to be restored. */
    Tcl_InterpState state)	/* Saved interpreter state. */
{
    Interp *iPtr = (Interp *) interp;
    InterpState *statePtr = (InterpState *) state;
    int status = statePtr->status;

    iPtr->flags &= ~ERR_ALREADY_LOGGED;
    iPtr->flags |= (statePtr->flags & ERR_ALREADY_LOGGED);

    iPtr->returnLevel = statePtr->returnLevel;
    iPtr->returnCode = statePtr->returnCode;
    iPtr->resetErrorStack = statePtr->resetErrorStack;
    if (iPtr->errorInfo) {
	Tcl_DecrRefCount(iPtr->errorInfo);
    }
    iPtr->errorInfo = statePtr->errorInfo;
    if (iPtr->errorInfo) {
	Tcl_IncrRefCount(iPtr->errorInfo);
    }
    if (iPtr->errorCode) {
	Tcl_DecrRefCount(iPtr->errorCode);
    }
    iPtr->errorCode = statePtr->errorCode;
    if (iPtr->errorCode) {
	Tcl_IncrRefCount(iPtr->errorCode);
    }
    if (iPtr->errorStack) {
	Tcl_DecrRefCount(iPtr->errorStack);
    }
    iPtr->errorStack = statePtr->errorStack;
    if (iPtr->errorStack) {
	Tcl_IncrRefCount(iPtr->errorStack);
    }
    if (iPtr->returnOpts) {
	Tcl_DecrRefCount(iPtr->returnOpts);
    }
    iPtr->returnOpts = statePtr->returnOpts;
    if (iPtr->returnOpts) {
	Tcl_IncrRefCount(iPtr->returnOpts);
    }
    Tcl_SetObjResult(interp, statePtr->objResult);
    Tcl_DiscardInterpState(state);
    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DiscardInterpState --
 *
 *	Accepts a token previously returned by Tcl_SaveInterpState. Frees the
 *	memory it uses.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees memory.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DiscardInterpState(
    Tcl_InterpState state)	/* saved interpreter state */
{
    InterpState *statePtr = (InterpState *) state;

    if (statePtr->errorInfo) {
	Tcl_DecrRefCount(statePtr->errorInfo);
    }
    if (statePtr->errorCode) {
	Tcl_DecrRefCount(statePtr->errorCode);
    }
    if (statePtr->returnOpts) {
	Tcl_DecrRefCount(statePtr->returnOpts);
    }
    if (statePtr->errorStack) {
	Tcl_DecrRefCount(statePtr->errorStack);
    }
    Tcl_DecrRefCount(statePtr->objResult);
    Tcl_Free(statePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetObjResult --
 *	Makes objPtr the interpreter's result value.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores objPtr interp->objResultPtr, increments its reference count, and
 *	decrements the reference count of any existing interp->objResultPtr.
 *
 *	The string result is reset.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetObjResult(
    Tcl_Interp *interp,		/* Interpreter to set the result for. */
    Tcl_Obj *objPtr)		/* The value to set as the result. */
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *oldObjResult = iPtr->objResultPtr;
    if (objPtr == oldObjResult) {
	/* This should be impossible */
	assert(objPtr->refCount != 0);
	return;
    } else {
	iPtr->objResultPtr = objPtr;
	Tcl_IncrRefCount(objPtr);
	TclDecrRefCount(oldObjResult);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetObjResult --
 *
 *	Returns an interpreter's result value as a Tcl object. The object's
 *	reference count is not modified; the caller must do that if it needs
 *	to hold on to a long-term reference to it.
 *
 * Results:
 *	The interpreter's result as an object.
 *
 * Side effects:
 *	If the interpreter has a non-empty string result, the result object is
 *	either empty or stale because some function set interp->result
 *	directly. If so, the string result is moved to the result object then
 *	the string result is reset.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_GetObjResult(
    Tcl_Interp *interp)		/* Interpreter whose result to return. */
{
    Interp *iPtr = (Interp *) interp;

    return iPtr->objResultPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AppendResult --
 *
 *	Append a variable number of strings onto the interpreter's result.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The result of the interpreter given by the first argument is extended
 *	by the strings given by the second and following arguments (up to a
 *	terminating NULL argument).
 *
 *	If the string result is non-empty, the object result forced to be a
 *	duplicate of it first. There will be a string result afterwards.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_AppendResult(
    Tcl_Interp *interp, ...)
{
    va_list argList;
    Tcl_Obj *objPtr;

    va_start(argList, interp);
    objPtr = Tcl_GetObjResult(interp);

    if (Tcl_IsShared(objPtr)) {
	objPtr = Tcl_DuplicateObj(objPtr);
    }
    while (1) {
	const char *bytes = va_arg(argList, char *);

	if (bytes == NULL) {
	    break;
	}
	Tcl_AppendToObj(objPtr, bytes, -1);
    }
    Tcl_SetObjResult(interp, objPtr);
    va_end(argList);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AppendElement --
 *
 *	Convert a string to a valid Tcl list element and append it to the
 *	result (which is ostensibly a list).
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The result in the interpreter given by the first argument is extended
 *	with a list element converted from string. A separator space is added
 *	before the converted list element unless the current result is empty,
 *	contains the single character "{", or ends in " {".
 *
 *	If the string result is empty, the object result is moved to the
 *	string result, then the object result is reset.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_AppendElement(
    Tcl_Interp *interp,		/* Interpreter whose result is to be
				 * extended. */
    const char *element)	/* String to convert to list element and add
				 * to result. */
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *elementPtr = Tcl_NewStringObj(element, -1);
    Tcl_Obj *listPtr = Tcl_NewListObj(1, &elementPtr);
    const char *bytes;
    Tcl_Size length;

    if (Tcl_IsShared(iPtr->objResultPtr)) {
	Tcl_SetObjResult(interp, Tcl_DuplicateObj(iPtr->objResultPtr));
    }
    bytes = TclGetStringFromObj(iPtr->objResultPtr, &length);
    if (TclNeedSpace(bytes, bytes + length)) {
	Tcl_AppendToObj(iPtr->objResultPtr, " ", 1);
    }
    Tcl_AppendObjToObj(iPtr->objResultPtr, listPtr);
    Tcl_DecrRefCount(listPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ResetResult --
 *
 *	This function resets both the interpreter's string and object results.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	It resets the result object to an unshared empty object. It then
 *	restores the interpreter's string result area to its default
 *	initialized state, freeing up any memory that may have been allocated.
 *	It also clears any error information for the interpreter.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_ResetResult(
    Tcl_Interp *interp)		/* Interpreter for which to clear result. */
{
    Interp *iPtr = (Interp *) interp;

    ResetObjResult(iPtr);
    if (iPtr->errorCode) {
	/* Legacy support */
	if (iPtr->flags & ERR_LEGACY_COPY) {
	    Tcl_ObjSetVar2(interp, iPtr->ecVar, NULL,
		    iPtr->errorCode, TCL_GLOBAL_ONLY);
	}
	Tcl_DecrRefCount(iPtr->errorCode);
	iPtr->errorCode = NULL;
    }
    if (iPtr->errorInfo) {
	/* Legacy support */
	if (iPtr->flags & ERR_LEGACY_COPY) {
	    Tcl_ObjSetVar2(interp, iPtr->eiVar, NULL,
		    iPtr->errorInfo, TCL_GLOBAL_ONLY);
	}
	Tcl_DecrRefCount(iPtr->errorInfo);
	iPtr->errorInfo = NULL;
    }
    iPtr->resetErrorStack = 1;
    iPtr->returnLevel = 1;
    iPtr->returnCode = TCL_OK;
    if (iPtr->returnOpts) {
	Tcl_DecrRefCount(iPtr->returnOpts);
	iPtr->returnOpts = NULL;
    }
    iPtr->flags &= ~(ERR_ALREADY_LOGGED | ERR_LEGACY_COPY);
}

/*
 *----------------------------------------------------------------------
 *
 * ResetObjResult --
 *
 *	Function used to reset an interpreter's Tcl result object.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Resets the interpreter's result object to an unshared empty string
 *	object with ref count one. It does not clear any error information in
 *	the interpreter.
 *
 *----------------------------------------------------------------------
 */

static void
ResetObjResult(
    Interp *iPtr)		/* Points to the interpreter whose result
				 * object should be reset. */
{
    Tcl_Obj *objResultPtr = iPtr->objResultPtr;

    if (Tcl_IsShared(objResultPtr)) {
	TclDecrRefCount(objResultPtr);
	TclNewObj(objResultPtr);
	Tcl_IncrRefCount(objResultPtr);
	iPtr->objResultPtr = objResultPtr;
    } else {
	if (objResultPtr->bytes != &tclEmptyString) {
	    if (objResultPtr->bytes) {
		Tcl_Free(objResultPtr->bytes);
	    }
	    objResultPtr->bytes = &tclEmptyString;
	    objResultPtr->length = 0;
	}
	TclFreeInternalRep(objResultPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetErrorCode --
 *
 *	This function is called to record machine-readable information about
 *	an error that is about to be returned.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The errorCode field of the interp is modified to hold all of the
 *	arguments to this function, in a list form with each argument becoming
 *	one element of the list.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetErrorCode(
    Tcl_Interp *interp, ...)
{
    va_list argList;
    Tcl_Obj *errorObj;

    /*
     * Scan through the arguments one at a time, appending them to the
     * errorCode field as list elements.
     */

    va_start(argList, interp);
    TclNewObj(errorObj);

    /*
     * Scan through the arguments one at a time, appending them to the
     * errorCode field as list elements.
     */

    while (1) {
	char *elem = va_arg(argList, char *);

	if (elem == NULL) {
	    break;
	}
	Tcl_ListObjAppendElement(NULL, errorObj, Tcl_NewStringObj(elem, -1));
    }
    Tcl_SetObjErrorCode(interp, errorObj);
    va_end(argList);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetObjErrorCode --
 *
 *	This function is called to record machine-readable information about
 *	an error that is about to be returned. The caller should build a list
 *	object up and pass it to this routine.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The errorCode field of the interp is set to the new value.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetObjErrorCode(
    Tcl_Interp *interp,
    Tcl_Obj *errorObjPtr)
{
    Interp *iPtr = (Interp *) interp;

    if (iPtr->errorCode) {
	Tcl_DecrRefCount(iPtr->errorCode);
    }
    iPtr->errorCode = errorObjPtr;
    Tcl_IncrRefCount(iPtr->errorCode);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetErrorLine --
 *
 *      Returns the line number associated with the current error.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetErrorLine(
    Tcl_Interp *interp)
{
    return ((Interp *) interp)->errorLine;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetErrorLine --
 *
 *      Sets the line number associated with the current error.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetErrorLine(
    Tcl_Interp *interp,
    int value)
{
    ((Interp *) interp)->errorLine = value;
}

/*
 *----------------------------------------------------------------------
 *
 * GetKeys --
 *
 *	Returns a Tcl_Obj * array of the standard keys used in the return
 *	options dictionary.
 *
 *	Broadly sharing one copy of these key values helps with both memory
 *	efficiency and dictionary lookup times.
 *
 * Results:
 *	A Tcl_Obj * array.
 *
 * Side effects:
 *	First time called in a thread, creates the keys (allocating memory)
 *	and arranges for their cleanup at thread exit.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj **
GetKeys(void)
{
    static Tcl_ThreadDataKey returnKeysKey;
    Tcl_Obj **keys = (Tcl_Obj **)Tcl_GetThreadData(&returnKeysKey,
	    KEY_LAST * sizeof(Tcl_Obj *));

    if (keys[0] == NULL) {
	/*
	 * First call in this thread, create the keys...
	 */

	int i;

	TclNewLiteralStringObj(keys[KEY_CODE],	    "-code");
	TclNewLiteralStringObj(keys[KEY_ERRORCODE], "-errorcode");
	TclNewLiteralStringObj(keys[KEY_ERRORINFO], "-errorinfo");
	TclNewLiteralStringObj(keys[KEY_ERRORLINE], "-errorline");
	TclNewLiteralStringObj(keys[KEY_ERRORSTACK],"-errorstack");
	TclNewLiteralStringObj(keys[KEY_LEVEL],	    "-level");
	TclNewLiteralStringObj(keys[KEY_OPTIONS],   "-options");

	for (i = KEY_CODE; i < KEY_LAST; i++) {
	    Tcl_IncrRefCount(keys[i]);
	}

	/*
	 * ... and arrange for their clenaup.
	 */

	Tcl_CreateThreadExitHandler(ReleaseKeys, keys);
    }
    return keys;
}

/*
 *----------------------------------------------------------------------
 *
 * ReleaseKeys --
 *
 *	Called as a thread exit handler to cleanup return options dictionary
 *	keys.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees memory.
 *
 *----------------------------------------------------------------------
 */

static void
ReleaseKeys(
    void *clientData)
{
    Tcl_Obj **keys = (Tcl_Obj **)clientData;
    int i;

    for (i = KEY_CODE; i < KEY_LAST; i++) {
	Tcl_DecrRefCount(keys[i]);
	keys[i] = NULL;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclProcessReturn --
 *
 *	Does the work of the [return] command based on the code, level, and
 *	returnOpts arguments. Note that the code argument must agree with the
 *	-code entry in returnOpts and the level argument must agree with the
 *	-level entry in returnOpts, as is the case for values returned from
 *	TclMergeReturnOptions.
 *
 * Results:
 *	Returns the return code the [return] command should return.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclProcessReturn(
    Tcl_Interp *interp,
    int code,
    int level,
    Tcl_Obj *returnOpts)
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *valuePtr;
    Tcl_Obj **keys = GetKeys();

    /*
     * Store the merged return options.
     */

    if (iPtr->returnOpts != returnOpts) {
	if (iPtr->returnOpts) {
	    Tcl_DecrRefCount(iPtr->returnOpts);
	}
	iPtr->returnOpts = returnOpts;
	Tcl_IncrRefCount(iPtr->returnOpts);
    }

    if (code == TCL_ERROR) {
	if (iPtr->errorInfo) {
	    Tcl_DecrRefCount(iPtr->errorInfo);
	    iPtr->errorInfo = NULL;
	}
	Tcl_DictObjGet(NULL, iPtr->returnOpts, keys[KEY_ERRORINFO],
		&valuePtr);
	if (valuePtr != NULL) {
	    Tcl_Size length;

	    (void)TclGetStringFromObj(valuePtr, &length);
	    if (length) {
		iPtr->errorInfo = valuePtr;
		Tcl_IncrRefCount(iPtr->errorInfo);
		iPtr->flags |= ERR_ALREADY_LOGGED;
	    }
	}
	Tcl_DictObjGet(NULL, iPtr->returnOpts, keys[KEY_ERRORSTACK],
		&valuePtr);
	if (valuePtr != NULL) {
	    Tcl_Size len, valueObjc;
	    Tcl_Obj **valueObjv;

	    if (Tcl_IsShared(iPtr->errorStack)) {
		Tcl_Obj *newObj;

		newObj = Tcl_DuplicateObj(iPtr->errorStack);
		Tcl_DecrRefCount(iPtr->errorStack);
		Tcl_IncrRefCount(newObj);
		iPtr->errorStack = newObj;
	    }

	    /*
	     * List extraction done after duplication to avoid moving the rug
	     * if someone does [return -errorstack [info errorstack]]
	     */

	    if (TclListObjGetElements(interp, valuePtr, &valueObjc,
		    &valueObjv) == TCL_ERROR) {
		return TCL_ERROR;
	    }
	    iPtr->resetErrorStack = 0;
	    TclListObjLength(interp, iPtr->errorStack, &len);

	    /*
	     * Reset while keeping the list internalrep as much as possible.
	     */

	    Tcl_ListObjReplace(interp, iPtr->errorStack, 0, len, valueObjc,
		    valueObjv);
	}
	Tcl_DictObjGet(NULL, iPtr->returnOpts, keys[KEY_ERRORCODE],
		&valuePtr);
	if (valuePtr != NULL) {
	    Tcl_SetObjErrorCode(interp, valuePtr);
	} else {
	    Tcl_SetErrorCode(interp, "NONE", (char *)NULL);
	}

	Tcl_DictObjGet(NULL, iPtr->returnOpts, keys[KEY_ERRORLINE],
		&valuePtr);
	if (valuePtr != NULL) {
	    TclGetIntFromObj(NULL, valuePtr, &iPtr->errorLine);
	}
    }
    if (level != 0) {
	iPtr->returnLevel = level;
	iPtr->returnCode = code;
	return TCL_RETURN;
    }
    if (code == TCL_ERROR) {
	iPtr->flags |= ERR_LEGACY_COPY;
    }
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * TclMergeReturnOptions --
 *
 *	Parses, checks, and stores the options to the [return] command.
 *
 *	The number of arguments (objc) must be even, with the corresponding
 *	objv holding values to be processed as key value .... key value.
 *
 * Results:
 *	Returns TCL_ERROR if any of the option values are invalid. Otherwise,
 *	returns TCL_OK, and writes the returnOpts, code, and level values to
 *	the pointers provided.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
ExpandedOptions(
    Tcl_Interp *interp,		/* Current interpreter. */
    Tcl_Obj **keys,		/* Built-in keys (per thread) */
    Tcl_Obj *returnOpts,	/* Options dict we are building */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    for (;  objc > 1;  objv += 2, objc -= 2) {
	const char *opt = TclGetString(objv[0]);
	const char *compare = TclGetString(keys[KEY_OPTIONS]);

	if ((objv[0]->length == keys[KEY_OPTIONS]->length)
		&& (memcmp(opt, compare, objv[0]->length) == 0)) {
	    /* Process the -options switch to emulate {*} expansion.
	     *
	     * Use lists so duplicate keys are not lost.
	     */

	    Tcl_Size nestc;
	    Tcl_Obj **nestv;

	    if (TCL_ERROR == TclListObjGetElements(interp, objv[1],
		    &nestc, &nestv) || (nestc % 2)) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"bad -options value: expected dictionary but got"
			" \"%s\"", TclGetString(objv[1])));
		Tcl_SetErrorCode(interp, "TCL", "RESULT", "ILLEGAL_OPTIONS",
			(char *)NULL);
		return TCL_ERROR;
	    }

	    if (TCL_ERROR ==
		    ExpandedOptions(interp, keys, returnOpts, nestc, nestv)) {
		return TCL_ERROR;
	    }
	} else {
	    Tcl_DictObjPut(NULL, returnOpts, objv[0], objv[1]);
	}
    }
    return TCL_OK;
}

int
TclMergeReturnOptions(
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[],	/* Argument objects. */
    Tcl_Obj **optionsPtrPtr,	/* If not NULL, points to space for a (Tcl_Obj
				 * *) where the pointer to the merged return
				 * options dictionary should be written. */
    int *codePtr,		/* If not NULL, points to space where the
				 * -code value should be written. */
    int *levelPtr)		/* If not NULL, points to space where the
				 * -level value should be written. */
{
    int code = TCL_OK;
    int level = 1;
    Tcl_Obj *valuePtr;
    Tcl_Obj *returnOpts;
    Tcl_Obj **keys = GetKeys();

    /* All callers are expected to pass an even value for objc. */

    TclNewObj(returnOpts);
    if (TCL_ERROR == ExpandedOptions(interp, keys, returnOpts, objc, objv)) {
	goto error;
    }

    /*
     * Check for bogus -code value.
     */

    Tcl_DictObjGet(NULL, returnOpts, keys[KEY_CODE], &valuePtr);
    if (valuePtr != NULL) {
	if (TclGetCompletionCodeFromObj(interp, valuePtr,
		&code) == TCL_ERROR) {
	    goto error;
	}
	Tcl_DictObjRemove(NULL, returnOpts, keys[KEY_CODE]);
    }

    /*
     * Check for bogus -level value.
     */

    Tcl_DictObjGet(NULL, returnOpts, keys[KEY_LEVEL], &valuePtr);
    if (valuePtr != NULL) {
	if ((TCL_ERROR == TclGetIntFromObj(NULL, valuePtr, &level))
		|| (level < 0)) {
	    /*
	     * Value is not a legal level.
	     */

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad -level value: expected non-negative integer but got"
		    " \"%s\"", TclGetString(valuePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "RESULT", "ILLEGAL_LEVEL", (char *)NULL);
	    goto error;
	}
	Tcl_DictObjRemove(NULL, returnOpts, keys[KEY_LEVEL]);
    }

    /*
     * Check for bogus -errorcode value.
     */

    Tcl_DictObjGet(NULL, returnOpts, keys[KEY_ERRORCODE], &valuePtr);
    if (valuePtr != NULL) {
	Tcl_Size length;

	if (TCL_ERROR == TclListObjLength(NULL, valuePtr, &length )) {
	    /*
	     * Value is not a list, which is illegal for -errorcode.
	     */

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad -errorcode value: expected a list but got \"%s\"",
		    TclGetString(valuePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "RESULT", "ILLEGAL_ERRORCODE",
		    (char *)NULL);
	    goto error;
	}
    }

    /*
     * Check for bogus -errorstack value.
     */

    Tcl_DictObjGet(NULL, returnOpts, keys[KEY_ERRORSTACK], &valuePtr);
    if (valuePtr != NULL) {
	Tcl_Size length;

	if (TCL_ERROR == TclListObjLength(NULL, valuePtr, &length)) {
	    /*
	     * Value is not a list, which is illegal for -errorstack.
	     */

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad -errorstack value: expected a list but got \"%s\"",
		    TclGetString(valuePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "RESULT", "NONLIST_ERRORSTACK",
		    (char *)NULL);
	    goto error;
	}
	if (length % 2) {
	    /*
	     * Errorstack must always be an even-sized list
	     */

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "forbidden odd-sized list for -errorstack: \"%s\"",
		    TclGetString(valuePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "RESULT",
		    "ODDSIZEDLIST_ERRORSTACK", (char *)NULL);
	    goto error;
	}
    }

    /*
     * Convert [return -code return -level X] to [return -code ok -level X+1]
     */

    if (code == TCL_RETURN) {
	level++;
	code = TCL_OK;
    }

    if (codePtr != NULL) {
	*codePtr = code;
    }
    if (levelPtr != NULL) {
	*levelPtr = level;
    }

    if (optionsPtrPtr == NULL) {
	/*
	 * Not passing back the options (?!), so clean them up.
	 */

	Tcl_DecrRefCount(returnOpts);
    } else {
	*optionsPtrPtr = returnOpts;
    }
    return TCL_OK;

  error:
    Tcl_DecrRefCount(returnOpts);
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_GetReturnOptions --
 *
 *	Packs up the interp state into a dictionary of return options.
 *
 * Results:
 *	A dictionary of return options.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_GetReturnOptions(
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *options;
    Tcl_Obj **keys = GetKeys();

    if (iPtr->returnOpts) {
	options = Tcl_DuplicateObj(iPtr->returnOpts);
    } else {
	TclNewObj(options);
    }

    if (result == TCL_RETURN) {
	Tcl_DictObjPut(NULL, options, keys[KEY_CODE],
		Tcl_NewWideIntObj(iPtr->returnCode));
	Tcl_DictObjPut(NULL, options, keys[KEY_LEVEL],
		Tcl_NewWideIntObj(iPtr->returnLevel));
    } else {
	Tcl_DictObjPut(NULL, options, keys[KEY_CODE],
		Tcl_NewWideIntObj(result));
	Tcl_DictObjPut(NULL, options, keys[KEY_LEVEL],
		Tcl_NewWideIntObj(0));
    }

    if (result == TCL_ERROR) {
	if (!iPtr->errorInfo) {
	    /*
	     * No errorLine without errorInfo, e. g. (re)thrown only message,
	     * this shall also avoid transfer of errorLine (if goes to child
	     * interp), because we have anyway nothing excepting message
	     * in the backtrace.
	     */
	    iPtr->errorLine = 1;
	}
	Tcl_AddErrorInfo(interp, "");
	Tcl_DictObjPut(NULL, options, keys[KEY_ERRORSTACK], iPtr->errorStack);
    }
    if (iPtr->errorCode) {
	Tcl_DictObjPut(NULL, options, keys[KEY_ERRORCODE], iPtr->errorCode);
    }
    if (iPtr->errorInfo) {
	Tcl_DictObjPut(NULL, options, keys[KEY_ERRORINFO], iPtr->errorInfo);
	Tcl_DictObjPut(NULL, options, keys[KEY_ERRORLINE],
		Tcl_NewWideIntObj(iPtr->errorLine));
    }
    return options;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclNoErrorStack --
 *
 *	Removes the -errorstack entry from an options dict to avoid reference
 *	cycles.
 *
 * Results:
 *	The (unshared) argument options dict, modified in -place.
 *
 *-------------------------------------------------------------------------
 */

Tcl_Obj *
TclNoErrorStack(
    Tcl_Interp *interp,
    Tcl_Obj *options)
{
    Tcl_Obj **keys = GetKeys();

    Tcl_DictObjRemove(interp, options, keys[KEY_ERRORSTACK]);
    return options;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_SetReturnOptions --
 *
 *	Accepts an interp and a dictionary of return options, and sets the
 *	return options of the interp to match the dictionary.
 *
 * Results:
 *	A standard status code. Usually TCL_OK, but TCL_ERROR if an invalid
 *	option value was found in the dictionary. If a -level value of 0 is in
 *	the dictionary, then the -code value in the dictionary will be
 *	returned (TCL_OK default).
 *
 * Side effects:
 *	Sets the state of the interp.
 *
 *-------------------------------------------------------------------------
 */

int
Tcl_SetReturnOptions(
    Tcl_Interp *interp,
    Tcl_Obj *options)
{
    Tcl_Size objc;
    int level, code;
    Tcl_Obj **objv, *mergedOpts;

    Tcl_IncrRefCount(options);
    if (TCL_ERROR == TclListObjGetElements(interp, options, &objc, &objv)
	    || (objc % 2)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"expected dict but got \"%s\"", TclGetString(options)));
	Tcl_SetErrorCode(interp, "TCL", "RESULT", "ILLEGAL_OPTIONS", (char *)NULL);
	code = TCL_ERROR;
    } else if (TCL_ERROR == TclMergeReturnOptions(interp, objc, objv,
	    &mergedOpts, &code, &level)) {
	code = TCL_ERROR;
    } else {
	code = TclProcessReturn(interp, code, level, mergedOpts);
    }

    Tcl_DecrRefCount(options);
    return code;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_TransferResult --
 *
 *	Transfer the result (and error information) from one interp to another.
 *	Used when one interp has caused another interp to evaluate a script
 *	and then wants to transfer the results back to itself.
 *
 * Results:
 *	The result of targetInterp is set to the result read from sourceInterp.
 *	The return options dictionary of sourceInterp is transferred to
 *	targetInterp as appropriate for the return code value code.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

void
Tcl_TransferResult(
    Tcl_Interp *sourceInterp,	/* Interp whose result and return options
				 * should be moved to the target interp.
				 * After moving result, this interp's result
				 * is reset. */
    int code,			/* The return code value active in
				 * sourceInterp. Controls how the return options
				 * dictionary is retrieved from sourceInterp,
				 * same as in Tcl_GetReturnOptions, to then be
				 * transferred to targetInterp. */
    Tcl_Interp *targetInterp)	/* Interp where result and return options
				 * should be stored. If source and target are
				 * the same, nothing is done. */
{
    Interp *tiPtr = (Interp *) targetInterp;
    Interp *siPtr = (Interp *) sourceInterp;

    if (sourceInterp == targetInterp) {
	return;
    }

    if (code == TCL_OK && siPtr->returnOpts == NULL) {
	/*
	 * Special optimization for the common case of normal command return
	 * code and no explicit return options.
	 */

	if (tiPtr->returnOpts) {
	    Tcl_DecrRefCount(tiPtr->returnOpts);
	    tiPtr->returnOpts = NULL;
	}
    } else {
	Tcl_SetReturnOptions(targetInterp,
		Tcl_GetReturnOptions(sourceInterp, code));
	/*
	 * Add line number if needed: not in line 1 and info contains no number
	 * yet at end of the stack (e. g. proc etc), to avoid double reporting
	 */
	if (tiPtr->errorLine > 1 && tiPtr->errorInfo &&
	    tiPtr->errorInfo->length &&
	    tiPtr->errorInfo->bytes[tiPtr->errorInfo->length-1] != ')'
	) {
	    Tcl_AppendObjToErrorInfo(targetInterp, Tcl_ObjPrintf(
		    "\n    (\"interp eval\" body line %d)", tiPtr->errorLine));
	}
	tiPtr->flags &= ~(ERR_ALREADY_LOGGED);
    }
    Tcl_SetObjResult(targetInterp, Tcl_GetObjResult(sourceInterp));
    Tcl_ResetResult(sourceInterp);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * indent-tabs-mode: nil
 * End:
 */

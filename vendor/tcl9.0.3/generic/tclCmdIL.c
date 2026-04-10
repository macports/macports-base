/*
 * tclCmdIL.c --
 *
 *	This file contains the top-level command routines for most of the Tcl
 *	built-in commands whose names begin with the letters I through L. It
 *	contains only commands in the generic core (i.e., those that don't
 *	depend much upon UNIX facilities).
 *
 * Copyright © 1987-1993 The Regents of the University of California.
 * Copyright © 1993-1997 Lucent Technologies.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 * Copyright © 1998-1999 Scriptics Corporation.
 * Copyright © 2001 Kevin B. Kenny. All rights reserved.
 * Copyright © 2005 Donal K. Fellows.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclRegexp.h"
#include "tclTomMath.h"
#include <math.h>

/*
 * During execution of the "lsort" command, structures of the following type
 * are used to arrange the objects being sorted into a collection of linked
 * lists.
 */

typedef struct SortElement {
    union {			/* The value that we sorting by. */
	const char *strValuePtr;
	Tcl_WideInt wideValue;
	double doubleValue;
	Tcl_Obj *objValuePtr;
    } collationKey;
    union {			/* Object being sorted, or its index. */
	Tcl_Obj *objPtr;
	size_t index;
    } payload;
    struct SortElement *nextPtr;/* Next element in the list, or NULL for end
				 * of list. */
} SortElement;

/*
 * These function pointer types are used with the "lsearch" and "lsort"
 * commands to facilitate the "-nocase" option.
 */

typedef int (*SortStrCmpFn_t) (const char *, const char *);
typedef int (*SortMemCmpFn_t) (const void *, const void *, Tcl_Size);

/*
 * The "lsort" command needs to pass certain information down to the function
 * that compares two list elements, and the comparison function needs to pass
 * success or failure information back up to the top-level "lsort" command.
 * The following structure is used to pass this information.
 */

typedef struct {
    int isIncreasing;		/* Nonzero means sort in increasing order. */
    int sortMode;		/* The sort mode. One of SORTMODE_* values
				 * defined below. */
    Tcl_Obj *compareCmdPtr;	/* The Tcl comparison command when sortMode is
				 * SORTMODE_COMMAND. Preinitialized to hold
				 * base of command. */
    int *indexv;		/* If the -index option was specified, this
				 * holds an encoding of the indexes contained
				 * in the list supplied as an argument to
				 * that option.
				 * NULL if no indexes supplied, and points to
				 * singleIndex field when only one
				 * supplied. */
    Tcl_Size indexc;		/* Number of indexes in indexv array. */
    int singleIndex;		/* Static space for common index case. */
    int unique;
    int numElements;
    Tcl_Interp *interp;		/* The interpreter in which the sort is being
				 * done. */
    int resultCode;		/* Completion code for the lsort command. If
				 * an error occurs during the sort this is
				 * changed from TCL_OK to TCL_ERROR. */
} SortInfo;

/*
 * The "sortMode" field of the SortInfo structure can take on any of the
 * following values.
 */

#define SORTMODE_ASCII		0
#define SORTMODE_INTEGER	1
#define SORTMODE_REAL		2
#define SORTMODE_COMMAND	3
#define SORTMODE_DICTIONARY	4
#define SORTMODE_ASCII_NC	8

/*
 * Definitions for [lseq] command
 */
static const char *const seq_operations[] = {
    "..", "to", "count", "by", NULL
};
typedef enum {
    LSEQ_DOTS, LSEQ_TO, LSEQ_COUNT, LSEQ_BY
} SequenceOperators;
typedef enum {
     NoneArg, NumericArg, RangeKeywordArg, ErrArg, LastArg = 8
} SequenceDecoded;

/*
 * Forward declarations for procedures defined in this file:
 */

static int		DictionaryCompare(const char *left, const char *right);
static Tcl_NRPostProc	IfConditionCallback;
static Tcl_ObjCmdProc	InfoArgsCmd;
static Tcl_ObjCmdProc	InfoBodyCmd;
static Tcl_ObjCmdProc	InfoCmdCountCmd;
static Tcl_ObjCmdProc	InfoCommandsCmd;
static Tcl_ObjCmdProc	InfoCompleteCmd;
static Tcl_ObjCmdProc	InfoDefaultCmd;
/* TIP #348 - New 'info' subcommand 'errorstack' */
static Tcl_ObjCmdProc	InfoErrorStackCmd;
/* TIP #280 - New 'info' subcommand 'frame' */
static Tcl_ObjCmdProc	InfoFrameCmd;
static Tcl_ObjCmdProc	InfoFunctionsCmd;
static Tcl_ObjCmdProc	InfoHostnameCmd;
static Tcl_ObjCmdProc	InfoLevelCmd;
static Tcl_ObjCmdProc	InfoLibraryCmd;
static Tcl_ObjCmdProc	InfoLoadedCmd;
static Tcl_ObjCmdProc	InfoNameOfExecutableCmd;
static Tcl_ObjCmdProc	InfoPatchLevelCmd;
static Tcl_ObjCmdProc	InfoProcsCmd;
static Tcl_ObjCmdProc	InfoScriptCmd;
static Tcl_ObjCmdProc	InfoSharedlibCmd;
static Tcl_ObjCmdProc	InfoCmdTypeCmd;
static Tcl_ObjCmdProc	InfoTclVersionCmd;
static SortElement *	MergeLists(SortElement *leftPtr, SortElement *rightPtr,
			    SortInfo *infoPtr);
static int		SortCompare(SortElement *firstPtr, SortElement *second,
			    SortInfo *infoPtr);
static Tcl_Obj *	SelectObjFromSublist(Tcl_Obj *firstPtr,
			    SortInfo *infoPtr);

/*
 * Array of values describing how to implement each standard subcommand of the
 * "info" command.
 */

static const EnsembleImplMap defaultInfoMap[] = {
    {"args",		   InfoArgsCmd,		    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"body",		   InfoBodyCmd,		    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"cmdcount",	   InfoCmdCountCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"cmdtype",		   InfoCmdTypeCmd,	    TclCompileBasic1ArgCmd, NULL, NULL, 1},
    {"commands",	   InfoCommandsCmd,	    TclCompileInfoCommandsCmd, NULL, NULL, 0},
    {"complete",	   InfoCompleteCmd,	    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"constant",	   TclInfoConstantCmd,	    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"consts",		   TclInfoConstsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"coroutine",	   TclInfoCoroutineCmd,     TclCompileInfoCoroutineCmd, NULL, NULL, 0},
    {"default",		   InfoDefaultCmd,	    TclCompileBasic3ArgCmd, NULL, NULL, 0},
    {"errorstack",	   InfoErrorStackCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"exists",		   TclInfoExistsCmd,	    TclCompileInfoExistsCmd, NULL, NULL, 0},
    {"frame",		   InfoFrameCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"functions",	   InfoFunctionsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"globals",		   TclInfoGlobalsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"hostname",	   InfoHostnameCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"level",		   InfoLevelCmd,	    TclCompileInfoLevelCmd, NULL, NULL, 0},
    {"library",		   InfoLibraryCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"loaded",		   InfoLoadedCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"locals",		   TclInfoLocalsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"nameofexecutable",   InfoNameOfExecutableCmd, TclCompileBasic0ArgCmd, NULL, NULL, 1},
    {"patchlevel",	   InfoPatchLevelCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"procs",		   InfoProcsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"script",		   InfoScriptCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {"sharedlibextension", InfoSharedlibCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"tclversion",	   InfoTclVersionCmd,	    TclCompileBasic0ArgCmd, NULL, NULL, 0},
    {"vars",		   TclInfoVarsCmd,	    TclCompileBasic0Or1ArgCmd, NULL, NULL, 0},
    {NULL, NULL, NULL, NULL, NULL, 0}
};

/*
 *----------------------------------------------------------------------
 *
 * Tcl_IfObjCmd --
 *
 *	This procedure is invoked to process the "if" Tcl command. See the
 *	user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "if" or the name to which
 *	"if" was renamed: e.g., "set z if; $z 1 {puts foo}"
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
Tcl_IfObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRIfObjCmd, clientData, objc, objv);
}

int
TclNRIfObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *boolObj;

    if (objc <= 1) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"wrong # args: no expression after \"%s\" argument",
		TclGetString(objv[0])));
	Tcl_SetErrorCode(interp, "TCL", "WRONGARGS", (char *)NULL);
	return TCL_ERROR;
    }

    /*
     * At this point, objv[1] refers to the main expression to test. The
     * arguments after the expression must be "then" (optional) and a script
     * to execute if the expression is true.
     */

    TclNewObj(boolObj);
    Tcl_NRAddCallback(interp, IfConditionCallback, INT2PTR(objc),
	    (void *) objv, INT2PTR(1), boolObj);
    return Tcl_NRExprObj(interp, objv[1], boolObj);
}

static int
IfConditionCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    int objc = PTR2INT(data[0]);
    Tcl_Obj *const *objv = (Tcl_Obj *const *)data[1];
    int i = PTR2INT(data[2]);
    Tcl_Obj *boolObj = (Tcl_Obj *)data[3];
    int value, thenScriptIndex = 0;
    const char *clause;

    if (result != TCL_OK) {
	TclDecrRefCount(boolObj);
	return result;
    }
    if (Tcl_GetBooleanFromObj(interp, boolObj, &value) != TCL_OK) {
	TclDecrRefCount(boolObj);
	return TCL_ERROR;
    }
    TclDecrRefCount(boolObj);

    while (1) {
	i++;
	if (i >= objc) {
	    goto missingScript;
	}
	clause = TclGetString(objv[i]);
	if ((i < objc) && (strcmp(clause, "then") == 0)) {
	    i++;
	}
	if (i >= objc) {
	    goto missingScript;
	}
	if (value) {
	    thenScriptIndex = i;
	    value = 0;
	}

	/*
	 * The expression evaluated to false. Skip the command, then see if
	 * there is an "else" or "elseif" clause.
	 */

	i++;
	if (i >= objc) {
	    if (thenScriptIndex) {
		/*
		 * TIP #280. Make invoking context available to branch.
		 */

		return TclNREvalObjEx(interp, objv[thenScriptIndex], 0,
			iPtr->cmdFramePtr, thenScriptIndex);
	    }
	    return TCL_OK;
	}
	clause = TclGetString(objv[i]);
	if ((clause[0] != 'e') || (strcmp(clause, "elseif") != 0)) {
	    break;
	}
	i++;

	/*
	 * At this point in the loop, objv and objc refer to an expression to
	 * test, either for the main expression or an expression following an
	 * "elseif". The arguments after the expression must be "then"
	 * (optional) and a script to execute if the expression is true.
	 */

	if (i >= objc) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "wrong # args: no expression after \"%s\" argument",
		    clause));
	    Tcl_SetErrorCode(interp, "TCL", "WRONGARGS", (char *)NULL);
	    return TCL_ERROR;
	}
	if (!thenScriptIndex) {
	    TclNewObj(boolObj);
	    Tcl_NRAddCallback(interp, IfConditionCallback, data[0], data[1],
		    INT2PTR(i), boolObj);
	    return Tcl_NRExprObj(interp, objv[i], boolObj);
	}
    }

    /*
     * Couldn't find a "then" or "elseif" clause to execute. Check now for an
     * "else" clause. We know that there's at least one more argument when we
     * get here.
     */

    if (strcmp(clause, "else") == 0) {
	i++;
	if (i >= objc) {
	    goto missingScript;
	}
    }
    if (i < objc - 1) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"wrong # args: extra words after \"else\" clause in \"if\" command",
		-1));
	Tcl_SetErrorCode(interp, "TCL", "WRONGARGS", (char *)NULL);
	return TCL_ERROR;
    }
    if (thenScriptIndex) {
	/*
	 * TIP #280. Make invoking context available to branch/else.
	 */

	return TclNREvalObjEx(interp, objv[thenScriptIndex], 0,
		iPtr->cmdFramePtr, thenScriptIndex);
    }
    return TclNREvalObjEx(interp, objv[i], 0, iPtr->cmdFramePtr, i);

  missingScript:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "wrong # args: no script following \"%s\" argument",
	    TclGetString(objv[i-1])));
    Tcl_SetErrorCode(interp, "TCL", "WRONGARGS", (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_IncrObjCmd --
 *
 *	This procedure is invoked to process the "incr" Tcl command. See the
 *	user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "incr" or the name to
 *	which "incr" was renamed: e.g., "set z incr; $z i -1"
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
Tcl_IncrObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *newValuePtr, *incrPtr;

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs(interp, 1, objv, "varName ?increment?");
	return TCL_ERROR;
    }

    if (objc == 3) {
	incrPtr = objv[2];
    } else {
	TclNewIntObj(incrPtr, 1);
    }
    Tcl_IncrRefCount(incrPtr);
    newValuePtr = TclIncrObjVar2(interp, objv[1], NULL,
	    incrPtr, TCL_LEAVE_ERR_MSG);
    Tcl_DecrRefCount(incrPtr);

    if (newValuePtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Set the interpreter's object result to refer to the variable's new
     * value object.
     */

    Tcl_SetObjResult(interp, newValuePtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitInfoCmd --
 *
 *	This function is called to create the "info" Tcl command. See the user
 *	documentation for details on what it does.
 *
 * Results:
 *	Handle for the info command, or NULL on failure.
 *
 * Side effects:
 *	none
 *
 *----------------------------------------------------------------------
 */

Tcl_Command
TclInitInfoCmd(
    Tcl_Interp *interp)		/* Current interpreter. */
{
    return TclMakeEnsemble(interp, "info", defaultInfoMap);
}

/*
 *----------------------------------------------------------------------
 *
 * InfoArgsCmd --
 *
 *	Called to implement the "info args" command that returns the argument
 *	list for a procedure. Handles the following syntax:
 *
 *	    info args procName
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoArgsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;
    const char *name;
    Proc *procPtr;
    CompiledLocal *localPtr;
    Tcl_Obj *listObjPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "procname");
	return TCL_ERROR;
    }

    name = TclGetString(objv[1]);
    procPtr = TclFindProc(iPtr, name);
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" isn't a procedure", name));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "PROCEDURE", name, (char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Build a return list containing the arguments.
     */

    listObjPtr = Tcl_NewListObj(0, NULL);
    for (localPtr = procPtr->firstLocalPtr;  localPtr != NULL;
	    localPtr = localPtr->nextPtr) {
	if (TclIsVarArgument(localPtr)) {
	    Tcl_ListObjAppendElement(interp, listObjPtr,
		    Tcl_NewStringObj(localPtr->name, -1));
	}
    }
    Tcl_SetObjResult(interp, listObjPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoBodyCmd --
 *
 *	Called to implement the "info body" command that returns the body for
 *	a procedure. Handles the following syntax:
 *
 *	    info body procName
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoBodyCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;
    const char *name, *bytes;
    Proc *procPtr;
    Tcl_Size numBytes;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "procname");
	return TCL_ERROR;
    }

    name = TclGetString(objv[1]);
    procPtr = TclFindProc(iPtr, name);
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" isn't a procedure", name));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "PROCEDURE", name, (char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Here we used to return procPtr->bodyPtr, except when the body was
     * bytecompiled - in that case, the return was a copy of the body's string
     * rep. In order to better isolate the implementation details of the
     * compiler/engine subsystem, we now always return a copy of the string
     * rep. It is important to return a copy so that later manipulations of
     * the object do not invalidate the internal rep.
     */

    bytes = TclGetStringFromObj(procPtr->bodyPtr, &numBytes);
    Tcl_SetObjResult(interp, Tcl_NewStringObj(bytes, numBytes));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoCmdCountCmd --
 *
 *	Called to implement the "info cmdcount" command that returns the
 *	number of commands that have been executed. Handles the following
 *	syntax:
 *
 *	    info cmdcount
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoCmdCountCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(iPtr->cmdCount));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoCommandsCmd --
 *
 *	Called to implement the "info commands" command that returns the list
 *	of commands in the interpreter that match an optional pattern. The
 *	pattern, if any, consists of an optional sequence of namespace names
 *	separated by "::" qualifiers, which is followed by a glob-style
 *	pattern that restricts which commands are returned. Handles the
 *	following syntax:
 *
 *	    info commands ?pattern?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoCommandsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *cmdName, *pattern;
    const char *simplePattern;
    Tcl_HashEntry *entryPtr;
    Tcl_HashSearch search;
    Namespace *nsPtr;
    Namespace *globalNsPtr = (Namespace *) Tcl_GetGlobalNamespace(interp);
    Namespace *currNsPtr = (Namespace *) Tcl_GetCurrentNamespace(interp);
    Tcl_Obj *listPtr, *elemObjPtr;
    int specificNsInPattern = 0;/* Init. to avoid compiler warning. */
    Tcl_Command cmd;
    Tcl_Size i;

    /*
     * Get the pattern and find the "effective namespace" in which to list
     * commands.
     */

    if (objc == 1) {
	simplePattern = NULL;
	nsPtr = currNsPtr;
	specificNsInPattern = 0;
    } else if (objc == 2) {
	/*
	 * From the pattern, get the effective namespace and the simple
	 * pattern (no namespace qualifiers or ::'s) at the end. If an error
	 * was found while parsing the pattern, return it. Otherwise, if the
	 * namespace wasn't found, just leave nsPtr NULL: we will return an
	 * empty list since no commands there can be found.
	 */

	Namespace *dummy1NsPtr, *dummy2NsPtr;

	pattern = TclGetString(objv[1]);
	TclGetNamespaceForQualName(interp, pattern, NULL, 0, &nsPtr,
		&dummy1NsPtr, &dummy2NsPtr, &simplePattern);

	if (nsPtr != NULL) {	/* We successfully found the pattern's ns. */
	    specificNsInPattern = (strcmp(simplePattern, pattern) != 0);
	}
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
	return TCL_ERROR;
    }

    /*
     * Exit as quickly as possible if we couldn't find the namespace.
     */

    if (nsPtr == NULL) {
	return TCL_OK;
    }

    /*
     * Scan through the effective namespace's command table and create a list
     * with all commands that match the pattern. If a specific namespace was
     * requested in the pattern, qualify the command names with the namespace
     * name.
     */

    listPtr = Tcl_NewListObj(0, NULL);

    if (simplePattern != NULL && TclMatchIsTrivial(simplePattern)) {
	/*
	 * Special case for when the pattern doesn't include any of glob's
	 * special characters. This lets us avoid scans of any hash tables.
	 */

	entryPtr = Tcl_FindHashEntry(&nsPtr->cmdTable, simplePattern);
	if (entryPtr != NULL) {
	    if (specificNsInPattern) {
		cmd = (Tcl_Command)Tcl_GetHashValue(entryPtr);
		TclNewObj(elemObjPtr);
		Tcl_GetCommandFullName(interp, cmd, elemObjPtr);
	    } else {
		cmdName = (const char *)Tcl_GetHashKey(&nsPtr->cmdTable, entryPtr);
		elemObjPtr = Tcl_NewStringObj(cmdName, -1);
	    }
	    Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
	    Tcl_SetObjResult(interp, listPtr);
	    return TCL_OK;
	}
	if ((nsPtr != globalNsPtr) && !specificNsInPattern) {
	    Tcl_HashTable *tablePtr = NULL;	/* Quell warning. */

	    for (i=0 ; i<nsPtr->commandPathLength ; i++) {
		Namespace *pathNsPtr = nsPtr->commandPathArray[i].nsPtr;

		if (pathNsPtr == NULL) {
		    continue;
		}
		tablePtr = &pathNsPtr->cmdTable;
		entryPtr = Tcl_FindHashEntry(tablePtr, simplePattern);
		if (entryPtr != NULL) {
		    break;
		}
	    }
	    if (entryPtr == NULL) {
		tablePtr = &globalNsPtr->cmdTable;
		entryPtr = Tcl_FindHashEntry(tablePtr, simplePattern);
	    }
	    if (entryPtr != NULL) {
		cmdName = (const char *)Tcl_GetHashKey(tablePtr, entryPtr);
		Tcl_ListObjAppendElement(interp, listPtr,
			Tcl_NewStringObj(cmdName, -1));
		Tcl_SetObjResult(interp, listPtr);
		return TCL_OK;
	    }
	}
    } else if (nsPtr->commandPathLength == 0 || specificNsInPattern) {
	/*
	 * The pattern is non-trivial, but either there is no explicit path or
	 * there is an explicit namespace in the pattern. In both cases, the
	 * old matching scheme is perfect.
	 */

	entryPtr = Tcl_FirstHashEntry(&nsPtr->cmdTable, &search);
	while (entryPtr != NULL) {
	    cmdName = (const char *)Tcl_GetHashKey(&nsPtr->cmdTable, entryPtr);
	    if ((simplePattern == NULL)
		    || Tcl_StringMatch(cmdName, simplePattern)) {
		if (specificNsInPattern) {
		    cmd = (Tcl_Command)Tcl_GetHashValue(entryPtr);
		    TclNewObj(elemObjPtr);
		    Tcl_GetCommandFullName(interp, cmd, elemObjPtr);
		} else {
		    elemObjPtr = Tcl_NewStringObj(cmdName, -1);
		}
		Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
	    }
	    entryPtr = Tcl_NextHashEntry(&search);
	}

	/*
	 * If the effective namespace isn't the global :: namespace, and a
	 * specific namespace wasn't requested in the pattern, then add in all
	 * global :: commands that match the simple pattern. Of course, we add
	 * in only those commands that aren't hidden by a command in the
	 * effective namespace.
	 */

	if ((nsPtr != globalNsPtr) && !specificNsInPattern) {
	    entryPtr = Tcl_FirstHashEntry(&globalNsPtr->cmdTable, &search);
	    while (entryPtr != NULL) {
		cmdName = (const char *)Tcl_GetHashKey(&globalNsPtr->cmdTable, entryPtr);
		if ((simplePattern == NULL)
			|| Tcl_StringMatch(cmdName, simplePattern)) {
		    if (Tcl_FindHashEntry(&nsPtr->cmdTable,cmdName) == NULL) {
			Tcl_ListObjAppendElement(interp, listPtr,
				Tcl_NewStringObj(cmdName, -1));
		    }
		}
		entryPtr = Tcl_NextHashEntry(&search);
	    }
	}
    } else {
	/*
	 * The pattern is non-trivial (can match more than one command name),
	 * there is an explicit path, and there is no explicit namespace in
	 * the pattern. This means that we have to traverse the path to
	 * discover all the commands defined.
	 */

	Tcl_HashTable addedCommandsTable;
	int isNew;
	int foundGlobal = (nsPtr == globalNsPtr);

	/*
	 * We keep a hash of the objects already added to the result list.
	 */

	Tcl_InitObjHashTable(&addedCommandsTable);

	entryPtr = Tcl_FirstHashEntry(&nsPtr->cmdTable, &search);
	while (entryPtr != NULL) {
	    cmdName = (const char *)Tcl_GetHashKey(&nsPtr->cmdTable, entryPtr);
	    if ((simplePattern == NULL)
		    || Tcl_StringMatch(cmdName, simplePattern)) {
		elemObjPtr = Tcl_NewStringObj(cmdName, -1);
		Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
		(void) Tcl_CreateHashEntry(&addedCommandsTable,
			elemObjPtr, &isNew);
	    }
	    entryPtr = Tcl_NextHashEntry(&search);
	}

	/*
	 * Search the path next.
	 */

	for (i=0 ; i<nsPtr->commandPathLength ; i++) {
	    Namespace *pathNsPtr = nsPtr->commandPathArray[i].nsPtr;

	    if (pathNsPtr == NULL) {
		continue;
	    }
	    if (pathNsPtr == globalNsPtr) {
		foundGlobal = 1;
	    }
	    entryPtr = Tcl_FirstHashEntry(&pathNsPtr->cmdTable, &search);
	    while (entryPtr != NULL) {
		cmdName = (const char *)Tcl_GetHashKey(&pathNsPtr->cmdTable, entryPtr);
		if ((simplePattern == NULL)
			|| Tcl_StringMatch(cmdName, simplePattern)) {
		    elemObjPtr = Tcl_NewStringObj(cmdName, -1);
		    (void) Tcl_CreateHashEntry(&addedCommandsTable,
			    elemObjPtr, &isNew);
		    if (isNew) {
			Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
		    } else {
			TclDecrRefCount(elemObjPtr);
		    }
		}
		entryPtr = Tcl_NextHashEntry(&search);
	    }
	}

	/*
	 * If the effective namespace isn't the global :: namespace, and a
	 * specific namespace wasn't requested in the pattern, then add in all
	 * global :: commands that match the simple pattern. Of course, we add
	 * in only those commands that aren't hidden by a command in the
	 * effective namespace.
	 */

	if (!foundGlobal) {
	    entryPtr = Tcl_FirstHashEntry(&globalNsPtr->cmdTable, &search);
	    while (entryPtr != NULL) {
		cmdName = (const char *)Tcl_GetHashKey(&globalNsPtr->cmdTable, entryPtr);
		if ((simplePattern == NULL)
			|| Tcl_StringMatch(cmdName, simplePattern)) {
		    elemObjPtr = Tcl_NewStringObj(cmdName, -1);
		    if (Tcl_FindHashEntry(&addedCommandsTable,
			    elemObjPtr) == NULL) {
			Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
		    } else {
			TclDecrRefCount(elemObjPtr);
		    }
		}
		entryPtr = Tcl_NextHashEntry(&search);
	    }
	}

	Tcl_DeleteHashTable(&addedCommandsTable);
    }

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoCompleteCmd --
 *
 *	Called to implement the "info complete" command that determines
 *	whether a string is a complete Tcl command. Handles the following
 *	syntax:
 *
 *	    info complete command
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoCompleteCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "command");
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(
	    TclObjCommandComplete(objv[1])));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoDefaultCmd --
 *
 *	Called to implement the "info default" command that returns the
 *	default value for a procedure argument. Handles the following syntax:
 *
 *	    info default procName arg varName
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoDefaultCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;
    const char *procName, *argName;
    Proc *procPtr;
    CompiledLocal *localPtr;
    Tcl_Obj *valueObjPtr;

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "procname arg varname");
	return TCL_ERROR;
    }

    procName = TclGetString(objv[1]);
    argName = TclGetString(objv[2]);

    procPtr = TclFindProc(iPtr, procName);
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" isn't a procedure", procName));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "PROCEDURE", procName,
		(char *)NULL);
	return TCL_ERROR;
    }

    for (localPtr = procPtr->firstLocalPtr;  localPtr != NULL;
	    localPtr = localPtr->nextPtr) {
	if (TclIsVarArgument(localPtr)
		&& (strcmp(argName, localPtr->name) == 0)) {
	    if (localPtr->defValuePtr != NULL) {
		valueObjPtr = Tcl_ObjSetVar2(interp, objv[3], NULL,
			localPtr->defValuePtr, TCL_LEAVE_ERR_MSG);
		if (valueObjPtr == NULL) {
		    return TCL_ERROR;
		}
		Tcl_SetObjResult(interp, Tcl_NewBooleanObj(1));
	    } else {
		Tcl_Obj *nullObjPtr;
		TclNewObj(nullObjPtr);

		valueObjPtr = Tcl_ObjSetVar2(interp, objv[3], NULL,
			nullObjPtr, TCL_LEAVE_ERR_MSG);
		if (valueObjPtr == NULL) {
		    return TCL_ERROR;
		}
		Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
	    }
	    return TCL_OK;
	}
    }

    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "procedure \"%s\" doesn't have an argument \"%s\"",
	    procName, argName));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "ARGUMENT", argName, (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoErrorStackCmd --
 *
 *	Called to implement the "info errorstack" command that returns information
 *	about the last error's call stack. Handles the following syntax:
 *
 *	    info errorstack ?interp?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoErrorStackCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Interp *target;
    Interp *iPtr;

    if ((objc != 1) && (objc != 2)) {
	Tcl_WrongNumArgs(interp, 1, objv, "?interp?");
	return TCL_ERROR;
    }

    target = interp;
    if (objc == 2) {
	target = Tcl_GetChild(interp, TclGetString(objv[1]));
	if (target == NULL) {
	    return TCL_ERROR;
	}
    }

    iPtr = (Interp *) target;
    Tcl_SetObjResult(interp, iPtr->errorStack);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInfoExistsCmd --
 *
 *	Called to implement the "info exists" command that determines whether
 *	a variable exists. Handles the following syntax:
 *
 *	    info exists varName
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

int
TclInfoExistsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *varName;
    Var *varPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "varName");
	return TCL_ERROR;
    }

    varName = TclGetString(objv[1]);
    varPtr = TclVarTraceExists(interp, varName);

    Tcl_SetObjResult(interp,
	    Tcl_NewBooleanObj(varPtr && varPtr->value.objPtr));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoFrameCmd --
 *	TIP #280
 *
 *	Called to implement the "info frame" command that returns the location
 *	of either the currently executing command, or its caller. Handles the
 *	following syntax:
 *
 *		info frame ?number?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoFrameCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;
    int level, code = TCL_OK;
    CmdFrame *framePtr, **cmdFramePtrPtr = &iPtr->cmdFramePtr;
    CoroutineData *corPtr = iPtr->execEnvPtr->corPtr;
    int topLevel = 0;

    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?number?");
	return TCL_ERROR;
    }

    while (corPtr) {
	while (*cmdFramePtrPtr) {
	    topLevel++;
	    cmdFramePtrPtr = &((*cmdFramePtrPtr)->nextPtr);
	}
	if (corPtr->caller.cmdFramePtr) {
	    *cmdFramePtrPtr = corPtr->caller.cmdFramePtr;
	}
	corPtr = corPtr->callerEEPtr->corPtr;
    }
    topLevel += *cmdFramePtrPtr ? (*cmdFramePtrPtr)->level : 1;

    if (iPtr->cmdFramePtr && topLevel != iPtr->cmdFramePtr->level) {
	framePtr = iPtr->cmdFramePtr;
	while (framePtr) {
	    framePtr->level = topLevel--;
	    framePtr = framePtr->nextPtr;
	}
	if (topLevel) {
	    Tcl_Panic("Broken frame level calculation");
	}
	topLevel = iPtr->cmdFramePtr->level;
    }

    if (objc == 1) {
	/*
	 * Just "info frame".
	 */

	Tcl_SetObjResult(interp, Tcl_NewWideIntObj(topLevel));
	goto done;
    }

    /*
     * We've got "info frame level" and must parse the level first.
     */

    if (TclGetIntFromObj(interp, objv[1], &level) != TCL_OK) {
	code = TCL_ERROR;
	goto done;
    }

    if ((level > topLevel) || (level <= - topLevel)) {
    levelError:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"bad level \"%s\"", TclGetString(objv[1])));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "LEVEL",
		TclGetString(objv[1]), (char *)NULL);
	code = TCL_ERROR;
	goto done;
    }

    /*
     * Let us convert to relative so that we know how many levels to go back
     */

    if (level > 0) {
	level -= topLevel;
    }

    framePtr = iPtr->cmdFramePtr;
    while (++level <= 0) {
	framePtr = framePtr->nextPtr;
	if (!framePtr) {
	    goto levelError;
	}
    }

    Tcl_SetObjResult(interp, TclInfoFrame(interp, framePtr));

  done:
    cmdFramePtrPtr = &iPtr->cmdFramePtr;
    corPtr = iPtr->execEnvPtr->corPtr;
    while (corPtr) {
	CmdFrame *endPtr = corPtr->caller.cmdFramePtr;

	if (endPtr) {
	    if (*cmdFramePtrPtr == endPtr) {
		*cmdFramePtrPtr = NULL;
	    } else {
		CmdFrame *runPtr = *cmdFramePtrPtr;

		while (runPtr->nextPtr != endPtr) {
		    runPtr->level -= endPtr->level;
		    runPtr = runPtr->nextPtr;
		}
		runPtr->level = 1;
		runPtr->nextPtr = NULL;
	    }
	    cmdFramePtrPtr = &corPtr->caller.cmdFramePtr;
	}
	corPtr = corPtr->callerEEPtr->corPtr;
    }
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInfoFrame --
 *
 *	Core of InfoFrameCmd, returns TIP280 dict for a given frame.
 *
 * Results:
 *	Returns TIP280 dict.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclInfoFrame(
    Tcl_Interp *interp,		/* Current interpreter. */
    CmdFrame *framePtr)		/* Frame to get info for. */
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *tmpObj;
    Tcl_Obj *lv[20] = {NULL};		/* Keep uptodate when more keys are added to
				 * the dict. */
    int lc = 0;
    /*
     * This array is indexed by the TCL_LOCATION_... values, except
     * for _LAST.
     */
    static const char *const typeString[TCL_LOCATION_LAST] = {
	"eval", "eval", "eval", "precompiled", "source", "proc"
    };
    Proc *procPtr = NULL;
    int needsFree = -1;

    if (!framePtr) {
	goto precompiled;
    }
    procPtr = framePtr->framePtr ? framePtr->framePtr->procPtr : NULL;

    /*
     * Pull the information and construct the dictionary to return, as list.
     * Regarding use of the CmdFrame fields see tclInt.h, and its definition.
     */

#define ADD_PAIR(name, value) \
	TclNewLiteralStringObj(tmpObj, name); \
	lv[lc++] = tmpObj; \
	lv[lc++] = (value)

    switch (framePtr->type) {
    case TCL_LOCATION_EVAL:
	/*
	 * Evaluation, dynamic script. Type, line, cmd, the latter through
	 * str.
	 */

	ADD_PAIR("type", Tcl_NewStringObj(typeString[framePtr->type], -1));
	if (framePtr->line) {
	    ADD_PAIR("line", Tcl_NewWideIntObj(framePtr->line[0]));
	} else {
	    ADD_PAIR("line", Tcl_NewWideIntObj(1));
	}
	ADD_PAIR("cmd", TclGetSourceFromFrame(framePtr, 0, NULL));
	break;

    case TCL_LOCATION_PREBC:
      precompiled:
	/*
	 * Precompiled. Result contains the type as signal, nothing else.
	 */
	ADD_PAIR("type", Tcl_NewStringObj(typeString[TCL_LOCATION_PREBC], -1));
	break;

    case TCL_LOCATION_BC: {
	/*
	 * Execution of bytecode. Talk to the BC engine to fill out the frame.
	 */

	CmdFrame *fPtr = (CmdFrame *)TclStackAlloc(interp, sizeof(CmdFrame));

	*fPtr = *framePtr;

	/*
	 * Note:
	 * Type BC => f.data.eval.path	  is not used.
	 *	      f.data.tebc.codePtr is used instead.
	 */

	TclGetSrcInfoForPc(fPtr);

	/*
	 * Now filled: cmd.str.(cmd,len), line
	 * Possibly modified: type, path!
	 */

	ADD_PAIR("type", Tcl_NewStringObj(typeString[fPtr->type], -1));
	if (fPtr->line) {
	    ADD_PAIR("line", Tcl_NewWideIntObj(fPtr->line[0]));
	}

	if (fPtr->type == TCL_LOCATION_SOURCE) {
	    ADD_PAIR("file", fPtr->data.eval.path);

	    /*
	     * Death of reference by TclGetSrcInfoForPc.
	     */

	    Tcl_DecrRefCount(fPtr->data.eval.path);
	}

	ADD_PAIR("cmd", TclGetSourceFromFrame(fPtr, 0, NULL));
	if (fPtr->cmdObj && framePtr->cmdObj == NULL) {
	    needsFree = lc - 1;
	}
	TclStackFree(interp, fPtr);
	break;
    }

    case TCL_LOCATION_SOURCE:
	/*
	 * Evaluation of a script file.
	 */

	ADD_PAIR("type", Tcl_NewStringObj(typeString[framePtr->type], -1));
	ADD_PAIR("line", Tcl_NewWideIntObj(framePtr->line[0]));
	ADD_PAIR("file", framePtr->data.eval.path);

	/*
	 * Refcount framePtr->data.eval.path goes up when lv is converted into
	 * the result list object.
	 */

	ADD_PAIR("cmd", TclGetSourceFromFrame(framePtr, 0, NULL));
	break;

    case TCL_LOCATION_PROC:
	Tcl_Panic("TCL_LOCATION_PROC found in standard frame");
	break;
    }

    /*
     * 'proc'. Common to all frame types. Conditional on having an associated
     * Procedure CallFrame.
     */

    if (procPtr != NULL) {
	Tcl_HashEntry *namePtr = procPtr->cmdPtr->hPtr;

	if (namePtr) {
	    Tcl_Obj *procNameObj;

	    /*
	     * This is a regular command.
	     */

	    TclNewObj(procNameObj);
	    Tcl_GetCommandFullName(interp, (Tcl_Command) procPtr->cmdPtr,
		    procNameObj);
	    ADD_PAIR("proc", procNameObj);
	} else if (procPtr->cmdPtr->clientData) {
	    ExtraFrameInfo *efiPtr = (ExtraFrameInfo *)procPtr->cmdPtr->clientData;
	    Tcl_Size i;

	    /*
	     * This is a non-standard command. Luckily, it's told us how to
	     * render extra information about its frame.
	     */

	    for (i=0 ; i<efiPtr->length ; i++) {
		lv[lc++] = Tcl_NewStringObj(efiPtr->fields[i].name, -1);
		if (efiPtr->fields[i].proc) {
		    lv[lc++] =
			efiPtr->fields[i].proc(efiPtr->fields[i].clientData);
		} else {
		    lv[lc++] = (Tcl_Obj *)efiPtr->fields[i].clientData;
		}
	    }
	}
    }

    /*
     * 'level'. Common to all frame types. Conditional on having an associated
     * _visible_ CallFrame.
     */

    if (framePtr && (framePtr->framePtr != NULL) && (iPtr->varFramePtr != NULL)) {
	CallFrame *current = framePtr->framePtr;
	CallFrame *top = iPtr->varFramePtr;
	CallFrame *idx;

	for (idx=top ; idx!=NULL ; idx=idx->callerVarPtr) {
	    if (idx == current) {
		int c = framePtr->framePtr->level;
		int t = iPtr->varFramePtr->level;

		ADD_PAIR("level", Tcl_NewWideIntObj(t - c));
		break;
	    }
	}
    }

    tmpObj = Tcl_NewListObj(lc, lv);
    if (needsFree >= 0) {
	Tcl_DecrRefCount(lv[needsFree]);
    }
    return tmpObj;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoFunctionsCmd --
 *
 *	Called to implement the "info functions" command that returns the list
 *	of math functions matching an optional pattern. Handles the following
 *	syntax:
 *
 *	    info functions ?pattern?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoFunctionsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *script;
    int code;

    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
	return TCL_ERROR;
    }

    script = Tcl_NewStringObj(
"	    ::apply [::list {{pattern *}} {\n"
"		::set cmds {}\n"
"		::foreach cmd [::info commands ::tcl::mathfunc::$pattern] {\n"
"		    ::lappend cmds [::namespace tail $cmd]\n"
"		}\n"
"		::foreach cmd [::info commands tcl::mathfunc::$pattern] {\n"
"		    ::set cmd [::namespace tail $cmd]\n"
"		    ::if {$cmd ni $cmds} {\n"
"			::lappend cmds $cmd\n"
"		    }\n"
"		}\n"
"		::return $cmds\n"
"	    } [::namespace current]] ", -1);

    if (objc == 2) {
	Tcl_Obj *arg = Tcl_NewListObj(1, &(objv[1]));

	Tcl_AppendObjToObj(script, arg);
	Tcl_DecrRefCount(arg);
    }

    Tcl_IncrRefCount(script);
    code = Tcl_EvalObjEx(interp, script, 0);

    Tcl_DecrRefCount(script);

    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoHostnameCmd --
 *
 *	Called to implement the "info hostname" command that returns the host
 *	name. Handles the following syntax:
 *
 *	    info hostname
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoHostnameCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *name;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    name = Tcl_GetHostName();
    if (name) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(name, -1));
	return TCL_OK;
    }

    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    "unable to determine name of host", -1));
    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "HOSTNAME", "UNKNOWN", (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoLevelCmd --
 *
 *	Called to implement the "info level" command that returns information
 *	about the call stack. Handles the following syntax:
 *
 *	    info level ?number?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoLevelCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;

    if (objc == 1) {		/* Just "info level" */
	Tcl_SetObjResult(interp, Tcl_NewWideIntObj((int)iPtr->varFramePtr->level));
	return TCL_OK;
    }

    if (objc == 2) {
	int level;
	CallFrame *framePtr, *rootFramePtr = iPtr->rootFramePtr;

	if (TclGetIntFromObj(interp, objv[1], &level) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (level <= 0) {
	    if (iPtr->varFramePtr == rootFramePtr) {
		goto levelError;
	    }
	    level += iPtr->varFramePtr->level;
	}
	for (framePtr=iPtr->varFramePtr ; framePtr!=rootFramePtr;
		framePtr=framePtr->callerVarPtr) {
	    if ((int)framePtr->level == level) {
		break;
	    }
	}
	if (framePtr == rootFramePtr) {
	    goto levelError;
	}

	Tcl_SetObjResult(interp,
		Tcl_NewListObj(framePtr->objc, framePtr->objv));
	return TCL_OK;
    }

    Tcl_WrongNumArgs(interp, 1, objv, "?number?");
    return TCL_ERROR;

  levelError:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "bad level \"%s\"", TclGetString(objv[1])));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "LEVEL",
	    TclGetString(objv[1]), (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoLibraryCmd --
 *
 *	Called to implement the "info library" command that returns the
 *	library directory for the Tcl installation. Handles the following
 *	syntax:
 *
 *	    info library
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoLibraryCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *libDirName;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    libDirName = Tcl_GetVar2(interp, "tcl_library", NULL, TCL_GLOBAL_ONLY);
    if (libDirName != NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(libDirName, -1));
	return TCL_OK;
    }

    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    "no library has been specified for Tcl", -1));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "VARIABLE", "tcl_library", (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoLoadedCmd --
 *
 *	Called to implement the "info loaded" command that returns the
 *	packages that have been loaded into an interpreter. Handles the
 *	following syntax:
 *
 *	    info loaded ?interp?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoLoadedCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *interpName, *prefix;

    if (objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "?interp? ?prefix?");
	return TCL_ERROR;
    }

    if (objc < 2) {		/* Get loaded pkgs in all interpreters. */
	interpName = NULL;
    } else {			/* Get pkgs just in specified interp. */
	interpName = TclGetString(objv[1]);
    }
    if (objc < 3) {		/* Get loaded files in all packages. */
	prefix = NULL;
    } else {			/* Get pkgs just in specified interp. */
	prefix = TclGetString(objv[2]);
    }
    return TclGetLoadedLibraries(interp, interpName, prefix);
}

/*
 *----------------------------------------------------------------------
 *
 * InfoNameOfExecutableCmd --
 *
 *	Called to implement the "info nameofexecutable" command that returns
 *	the name of the binary file running this application. Handles the
 *	following syntax:
 *
 *	    info nameofexecutable
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoNameOfExecutableCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, TclGetObjNameOfExecutable());
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoPatchLevelCmd --
 *
 *	Called to implement the "info patchlevel" command that returns the
 *	default value for an argument to a procedure. Handles the following
 *	syntax:
 *
 *	    info patchlevel
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoPatchLevelCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *patchlevel;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    patchlevel = Tcl_GetVar2(interp, "tcl_patchLevel", NULL,
	    (TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG));
    if (patchlevel != NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(patchlevel, -1));
	return TCL_OK;
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoProcsCmd --
 *
 *	Called to implement the "info procs" command that returns the list of
 *	procedures in the interpreter that match an optional pattern. The
 *	pattern, if any, consists of an optional sequence of namespace names
 *	separated by "::" qualifiers, which is followed by a glob-style
 *	pattern that restricts which commands are returned. Handles the
 *	following syntax:
 *
 *	    info procs ?pattern?
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoProcsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *cmdName, *pattern;
    const char *simplePattern;
    Namespace *nsPtr;
    Namespace *currNsPtr = (Namespace *) Tcl_GetCurrentNamespace(interp);
    Tcl_Obj *listPtr, *elemObjPtr;
    int specificNsInPattern = 0;/* Init. to avoid compiler warning. */
    Tcl_HashEntry *entryPtr;
    Tcl_HashSearch search;
    Command *cmdPtr, *realCmdPtr;

    /*
     * Get the pattern and find the "effective namespace" in which to list
     * procs.
     */

    if (objc == 1) {
	simplePattern = NULL;
	nsPtr = currNsPtr;
	specificNsInPattern = 0;
    } else if (objc == 2) {
	/*
	 * From the pattern, get the effective namespace and the simple
	 * pattern (no namespace qualifiers or ::'s) at the end. If an error
	 * was found while parsing the pattern, return it. Otherwise, if the
	 * namespace wasn't found, just leave nsPtr NULL: we will return an
	 * empty list since no commands there can be found.
	 */

	Namespace *dummy1NsPtr, *dummy2NsPtr;

	pattern = TclGetString(objv[1]);
	TclGetNamespaceForQualName(interp, pattern, NULL, /*flags*/ 0, &nsPtr,
		&dummy1NsPtr, &dummy2NsPtr, &simplePattern);

	if (nsPtr != NULL) {	/* We successfully found the pattern's ns. */
	    specificNsInPattern = (strcmp(simplePattern, pattern) != 0);
	}
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
	return TCL_ERROR;
    }

    if (nsPtr == NULL) {
	return TCL_OK;
    }

    /*
     * Scan through the effective namespace's command table and create a list
     * with all procs that match the pattern. If a specific namespace was
     * requested in the pattern, qualify the command names with the namespace
     * name.
     */

    listPtr = Tcl_NewListObj(0, NULL);
    if (simplePattern != NULL && TclMatchIsTrivial(simplePattern)) {
	entryPtr = Tcl_FindHashEntry(&nsPtr->cmdTable, simplePattern);
	if (entryPtr != NULL) {
	    cmdPtr = (Command *)Tcl_GetHashValue(entryPtr);

	    if (!TclIsProc(cmdPtr)) {
		realCmdPtr = (Command *)
			TclGetOriginalCommand((Tcl_Command) cmdPtr);
		if (realCmdPtr != NULL && TclIsProc(realCmdPtr)) {
		    goto simpleProcOK;
		}
	    } else {
	    simpleProcOK:
		if (specificNsInPattern) {
		    TclNewObj(elemObjPtr);
		    Tcl_GetCommandFullName(interp, (Tcl_Command) cmdPtr,
			    elemObjPtr);
		} else {
		    elemObjPtr = Tcl_NewStringObj(simplePattern, -1);
		}
		Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
	    }
	}
    } else {
	entryPtr = Tcl_FirstHashEntry(&nsPtr->cmdTable, &search);
	while (entryPtr != NULL) {
	    cmdName = (const char *)Tcl_GetHashKey(&nsPtr->cmdTable, entryPtr);
	    if ((simplePattern == NULL)
		    || Tcl_StringMatch(cmdName, simplePattern)) {
		cmdPtr = (Command *)Tcl_GetHashValue(entryPtr);

		if (!TclIsProc(cmdPtr)) {
		    realCmdPtr = (Command *)
			    TclGetOriginalCommand((Tcl_Command) cmdPtr);
		    if (realCmdPtr != NULL && TclIsProc(realCmdPtr)) {
			goto procOK;
		    }
		} else {
		procOK:
		    if (specificNsInPattern) {
			TclNewObj(elemObjPtr);
			Tcl_GetCommandFullName(interp, (Tcl_Command) cmdPtr,
				elemObjPtr);
		    } else {
			elemObjPtr = Tcl_NewStringObj(cmdName, -1);
		    }
		    Tcl_ListObjAppendElement(interp, listPtr, elemObjPtr);
		}
	    }
	    entryPtr = Tcl_NextHashEntry(&search);
	}
    }

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoScriptCmd --
 *
 *	Called to implement the "info script" command that returns the script
 *	file that is currently being evaluated. Handles the following syntax:
 *
 *	    info script ?newName?
 *
 *	If newName is specified, it will set that as the internal name.
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message. It may change the internal
 *	script filename.
 *
 *----------------------------------------------------------------------
 */

static int
InfoScriptCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Interp *iPtr = (Interp *) interp;

    if ((objc != 1) && (objc != 2)) {
	Tcl_WrongNumArgs(interp, 1, objv, "?filename?");
	return TCL_ERROR;
    }

    if (objc == 2) {
	if (iPtr->scriptFile != NULL) {
	    Tcl_DecrRefCount(iPtr->scriptFile);
	}
	iPtr->scriptFile = objv[1];
	Tcl_IncrRefCount(iPtr->scriptFile);
    }
    if (iPtr->scriptFile != NULL) {
	Tcl_SetObjResult(interp, iPtr->scriptFile);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoSharedlibCmd --
 *
 *	Called to implement the "info sharedlibextension" command that returns
 *	the file extension used for shared libraries. Handles the following
 *	syntax:
 *
 *	    info sharedlibextension
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoSharedlibCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

#ifdef TCL_SHLIB_EXT
    Tcl_SetObjResult(interp, Tcl_NewStringObj(TCL_SHLIB_EXT, -1));
#endif
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoTclVersionCmd --
 *
 *	Called to implement the "info tclversion" command that returns the
 *	version number for this Tcl library. Handles the following syntax:
 *
 *	    info tclversion
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a result in the interpreter's result object. If there is an
 *	error, the result is an error message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoTclVersionCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *version;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    version = Tcl_GetVar2Ex(interp, "tcl_version", NULL,
	    (TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG));
    if (version != NULL) {
	Tcl_SetObjResult(interp, version);
	return TCL_OK;
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * InfoCmdTypeCmd --
 *
 *	Called to implement the "info cmdtype" command that returns the type
 *	of a given command. Handles the following syntax:
 *
 *	    info cmdtype cmdName
 *
 * Results:
 *	Returns TCL_OK if successful and TCL_ERROR if there is an error.
 *
 * Side effects:
 *	Returns a type name. If there is an error, the result is an error
 *	message.
 *
 *----------------------------------------------------------------------
 */

static int
InfoCmdTypeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Command command;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "commandName");
	return TCL_ERROR;
    }
    command = Tcl_FindCommand(interp, TclGetString(objv[1]), NULL,
	    TCL_LEAVE_ERR_MSG);
    if (command == NULL) {
	return TCL_ERROR;
    }

    /*
     * There's one special case: safe child interpreters can't see aliases as
     * aliases as they're part of the security mechanisms.
     */

    if (Tcl_IsSafe(interp)
	    && (((Command *) command)->objProc == TclAliasObjCmd)) {
	Tcl_AppendResult(interp, "native", (char *)NULL);
    } else {
	Tcl_SetObjResult(interp,
		Tcl_NewStringObj(TclGetCommandTypeName(command), -1));
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_JoinObjCmd --
 *
 *	This procedure is invoked to process the "join" Tcl command. See the
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
Tcl_JoinObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* The argument objects. */
{
    Tcl_Size length, listLen;
    int isAbstractList = 0;
    Tcl_Obj *resObjPtr = NULL, *joinObjPtr, **elemPtrs;

    if ((objc < 2) || (objc > 3)) {
	Tcl_WrongNumArgs(interp, 1, objv, "list ?joinString?");
	return TCL_ERROR;
    }

    /*
     * Make sure the list argument is a list object and get its length and a
     * pointer to its array of element pointers.
     */

    if (TclObjTypeHasProc(objv[1], getElementsProc)) {
	listLen = TclObjTypeLength(objv[1]);
	isAbstractList = (listLen ? 1 : 0);
	if (listLen > 1 && TclObjTypeGetElements(interp, objv[1],
		&listLen, &elemPtrs) != TCL_OK) {
	    return TCL_ERROR;
	}
    } else if (TclListObjGetElements(interp, objv[1], &listLen,
	    &elemPtrs) != TCL_OK) {
	return TCL_ERROR;
    }

    if (listLen == 0) {
	/* No elements to join; default empty result is correct. */
	return TCL_OK;
    }
    if (listLen == 1) {
	/* One element; return it */
	if (!isAbstractList) {
	    Tcl_SetObjResult(interp, elemPtrs[0]);
	} else {
	    Tcl_Obj *elemObj;

	    if (TclObjTypeIndex(interp, objv[1], 0, &elemObj) != TCL_OK) {
		return TCL_ERROR;
	    }
	    Tcl_SetObjResult(interp, elemObj);
	}
	return TCL_OK;
    }

    joinObjPtr = (objc == 2) ? Tcl_NewStringObj(" ", 1) : objv[2];
    Tcl_IncrRefCount(joinObjPtr);

    (void)TclGetStringFromObj(joinObjPtr, &length);
    if (length == 0) {
	resObjPtr = TclStringCat(interp, listLen, elemPtrs, 0);
    } else {
	Tcl_Size i;

	TclNewObj(resObjPtr);
	for (i = 0;  i < listLen;  i++) {
	    if (i > 0) {

		/*
		 * NOTE: This code is relying on Tcl_AppendObjToObj() **NOT**
		 * to shimmer joinObjPtr.  If it did, then the case where
		 * objv[1] and objv[2] are the same value would not be safe.
		 * Accessing elemPtrs would crash.
		 */

		Tcl_AppendObjToObj(resObjPtr, joinObjPtr);
	    }
	    Tcl_AppendObjToObj(resObjPtr, elemPtrs[i]);
	}
    }
    Tcl_DecrRefCount(joinObjPtr);
    if (resObjPtr) {
	Tcl_SetObjResult(interp, resObjPtr);
	return TCL_OK;
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LassignObjCmd --
 *
 *	This object-based procedure is invoked to process the "lassign" Tcl
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
Tcl_LassignObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *listPtr;
    Tcl_Size listObjc;		/* The length of the list. */
    Tcl_Size origListObjc;	/* Original length */
    int i;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "list ?varName ...?");
	return TCL_ERROR;
    }

    /*
     * Note: no need to Dup the list to avoid shimmering. That is only
     * needed when Tcl_ListObjGetElements is used since that returns
     * pointers to internal structures. Using Tcl_ListObjIndex does not
     * have that problem. However, we now have to IncrRef each elemObj
     * (see below). I see that as preferable as duping lists is potentially
     * expensive for abstract lists when they have a string representation.
     */
    listPtr = objv[1];

    if (TclListObjLength(interp, listPtr, &listObjc) != TCL_OK) {
	return TCL_ERROR;
    }
    origListObjc = listObjc;

    objc -= 2;
    objv += 2;
    for (i = 0; i < objc && i < listObjc; ++i) {
	Tcl_Obj *elemObj;

	if (Tcl_ListObjIndex(interp, listPtr, i, &elemObj) != TCL_OK) {
	    return TCL_ERROR;
	}
	/*
	 * Must incrref elemObj. If the var name being set is same as the
	 * list value, ObjSetVar2 will shimmer the list to a VAR freeing
	 * the elements in the list (in case list refCount was 1) BEFORE
	 * the elemObj is stored in the var. See tests 6.{25,26}
	 */
	Tcl_IncrRefCount(elemObj);
	if (Tcl_ObjSetVar2(interp, *objv++, NULL, elemObj,
		TCL_LEAVE_ERR_MSG) == NULL) {
	    Tcl_DecrRefCount(elemObj);
	    return TCL_ERROR;
	}
	Tcl_DecrRefCount(elemObj);
    }
    objc -= i;
    listObjc -= i;

    if (objc > 0) {
	/* Still some variables left to be assigned */
	Tcl_Obj *emptyObj;

	TclNewObj(emptyObj);
	Tcl_IncrRefCount(emptyObj);
	while (objc-- > 0) {
	    if (Tcl_ObjSetVar2(interp, *objv++, NULL, emptyObj,
		    TCL_LEAVE_ERR_MSG) == NULL) {
		Tcl_DecrRefCount(emptyObj);
		return TCL_ERROR;
	    }
	}
	Tcl_DecrRefCount(emptyObj);
    }

    if (listObjc > 0) {
	Tcl_Obj *resultObjPtr = NULL;
	Tcl_Size fromIdx = origListObjc - listObjc;
	Tcl_Size toIdx = origListObjc - 1;
	if (TclObjTypeHasProc(listPtr, sliceProc)) {
	    if (TclObjTypeSlice(
		    interp, listPtr, fromIdx, toIdx, &resultObjPtr) != TCL_OK) {
		return TCL_ERROR;
	    }
	} else {
	    resultObjPtr = TclListObjRange(
		interp, listPtr, origListObjc - listObjc, origListObjc - 1);
	    if (resultObjPtr == NULL) {
		return TCL_ERROR;
	    }
	}
	Tcl_SetObjResult(interp, resultObjPtr);
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LindexObjCmd --
 *
 *	This object-based procedure is invoked to process the "lindex" Tcl
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
Tcl_LindexObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *elemPtr;		/* Pointer to the element being extracted. */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "list ?index ...?");
	return TCL_ERROR;
    }

    /*
     * If objc==3, then objv[2] may be either a single index or a list of
     * indices: go to TclLindexList to determine which. If objc>=4, or
     * objc==2, then objv[2 .. objc-2] are all single indices and processed as
     * such in TclLindexFlat.
     */

    if (objc == 3) {
	elemPtr = TclLindexList(interp, objv[1], objv[2]);
    } else {
	elemPtr = TclLindexFlat(interp, objv[1], objc-2, objv+2);
    }

    /*
     * Set the interpreter's object result to the last element extracted.
     */

    if (elemPtr == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, elemPtr);
    Tcl_DecrRefCount(elemPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LinsertObjCmd --
 *
 *	This object-based procedure is invoked to process the "linsert" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A new Tcl list object formed by inserting zero or more elements into a
 *	list.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_LinsertObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,		/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *listPtr;
    Tcl_Size len, index;
    int copied = 0, result;

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "list index ?element ...?");
	return TCL_ERROR;
    }

    result = TclListObjLength(interp, objv[1], &len);
    if (result != TCL_OK) {
	return result;
    }

    /*
     * Get the index. "end" is interpreted to be the index after the last
     * element, such that using it will cause any inserted elements to be
     * appended to the list.
     */

    result = TclGetIntForIndexM(interp, objv[2], /*end*/ len, &index);
    if (result != TCL_OK) {
	return result;
    }
    if (index > len) {
	index = len;
    }

    /*
     * If the list object is unshared we can modify it directly. Otherwise we
     * create a copy to modify: this is "copy on write".
     */

    listPtr = objv[1];
    if (Tcl_IsShared(listPtr)) {
	listPtr = TclListObjCopy(NULL, listPtr);
	copied = 1;
    }

    if ((objc == 4) && (index == len)) {
	/*
	 * Special case: insert one element at the end of the list.
	 */

	result = Tcl_ListObjAppendElement(NULL, listPtr, objv[3]);
	if (result != TCL_OK) {
	    if (copied) {
		Tcl_DecrRefCount(listPtr);
	    }
	    return result;
	}
    } else {
	if (TCL_OK != Tcl_ListObjReplace(interp, listPtr, index, 0,
		(objc-3), &(objv[3]))) {
	    if (copied) {
		Tcl_DecrRefCount(listPtr);
	    }
	    return TCL_ERROR;
	}
    }

    /*
     * Set the interpreter's object result.
     */

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjCmd --
 *
 *	This procedure is invoked to process the "list" Tcl command. See the
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
Tcl_ListObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,		/* Number of arguments. */
    Tcl_Obj *const objv[])
				/* The argument objects. */
{
    /*
     * If there are no list elements, the result is an empty object.
     * Otherwise set the interpreter's result object to be a list object.
     */

    if (objc > 1) {
	Tcl_SetObjResult(interp, Tcl_NewListObj(objc-1, &objv[1]));
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LlengthObjCmd --
 *
 *	This object-based procedure is invoked to process the "llength" Tcl
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
Tcl_LlengthObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])
				/* Argument objects. */
{
    Tcl_Size listLen;
    int result;
    Tcl_Obj *objPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "list");
	return TCL_ERROR;
    }

    result = TclListObjLength(interp, objv[1], &listLen);
    if (result != TCL_OK) {
	return result;
    }

    /*
     * Set the interpreter's object result to an integer object holding the
     * length.
     */

    TclNewUIntObj(objPtr, listLen);
    Tcl_SetObjResult(interp, objPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LpopObjCmd --
 *
 *	This procedure is invoked to process the "lpop" Tcl command. See the
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
Tcl_LpopObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])
				/* Argument objects. */
{
    Tcl_Size listLen;
    int copied = 0, result;
    Tcl_Obj *elemPtr, *stored;
    Tcl_Obj *listPtr;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "listvar ?index?");
	return TCL_ERROR;
    }

    listPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (listPtr == NULL) {
	return TCL_ERROR;
    }

    result = TclListObjLength(interp, listPtr, &listLen);
    if (result != TCL_OK) {
	return result;
    }

    /*
     * First, extract the element to be returned.
     * TclLindexFlat adds a ref count which is handled.
     */

    if (objc == 2) {
	if (!listLen) {
	    /* empty list, throw the same error as with index "end" */
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"index \"end\" out of range", -1));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
	    return TCL_ERROR;
	}

	result = Tcl_ListObjIndex(interp, listPtr, (listLen-1),	&elemPtr);
	if (result != TCL_OK) {
	    return result;
	}

	Tcl_IncrRefCount(elemPtr);
    } else {
	elemPtr = TclLindexFlat(interp, listPtr, objc-2, objv+2);

	if (elemPtr == NULL) {
	    return TCL_ERROR;
	}
    }
    Tcl_SetObjResult(interp, elemPtr);
    Tcl_DecrRefCount(elemPtr);

    /*
     * Second, remove the element.
     * TclLsetFlat adds a ref count which is handled.
     */

    if (objc == 2) {
	if (Tcl_IsShared(listPtr)) {
	    listPtr = TclListObjCopy(NULL, listPtr);
	    copied = 1;
	}
	result = Tcl_ListObjReplace(interp, listPtr, listLen - 1, 1, 0, NULL);
	if (result != TCL_OK) {
	    if (copied) {
		Tcl_DecrRefCount(listPtr);
	    }
	    return result;
	}
    } else {
	Tcl_Obj *newListPtr;
	Tcl_ObjTypeSetElement *proc = TclObjTypeHasProc(listPtr, setElementProc);
	if (proc) {
	    newListPtr = proc(interp, listPtr, objc-2, objv+2, NULL);
	} else {
	    newListPtr = TclLsetFlat(interp, listPtr, objc-2, objv+2, NULL);
	}
	if (newListPtr == NULL) {
	    if (copied) {
		Tcl_DecrRefCount(listPtr);
	    }
	    return TCL_ERROR;
	} else {
	    listPtr = newListPtr;
	    TclUndoRefCount(listPtr);
	}
    }

    stored = Tcl_ObjSetVar2(interp, objv[1], NULL, listPtr, TCL_LEAVE_ERR_MSG);
    if (stored == NULL) {
	return TCL_ERROR;
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LrangeObjCmd --
 *
 *	This procedure is invoked to process the "lrange" Tcl command. See the
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
Tcl_LrangeObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])
				/* Argument objects. */
{
    int result;
    Tcl_Size listLen, first, last;
    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "list first last");
	return TCL_ERROR;
    }

    result = TclListObjLength(interp, objv[1], &listLen);
    if (result != TCL_OK) {
	return result;
    }

    result = TclGetIntForIndexM(interp, objv[2], /*endValue*/ listLen - 1,
	    &first);
    if (result != TCL_OK) {
	return result;
    }

    result = TclGetIntForIndexM(interp, objv[3], /*endValue*/ listLen - 1,
	    &last);
    if (result != TCL_OK) {
	return result;
    }

    if (TclObjTypeHasProc(objv[1], sliceProc)) {
	Tcl_Obj *resultObj;
	int status = TclObjTypeSlice(interp, objv[1], first, last, &resultObj);
	if (status == TCL_OK) {
	    Tcl_SetObjResult(interp, resultObj);
	} else {
	    return TCL_ERROR;
	}
    } else {
	Tcl_Obj *resultObj = TclListObjRange(interp, objv[1], first, last);
	if (resultObj == NULL) {
	    return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, resultObj);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LremoveObjCmd --
 *
 *	This procedure is invoked to process the "lremove" Tcl command. See the
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

static int
LremoveIndexCompare(
    const void *el1Ptr,
    const void *el2Ptr)
{
    Tcl_Size idx1 = *((const Tcl_Size *) el1Ptr);
    Tcl_Size idx2 = *((const Tcl_Size *) el2Ptr);

    /*
     * This will put the larger element first.
     */

    return (idx1 < idx2) ? 1 : (idx1 > idx2) ? -1 : 0;
}

int
Tcl_LremoveObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size i, idxc, prevIdx, first, num;
    Tcl_Size *idxv, listLen;
    Tcl_Obj *listObj;
    int copied = 0, status = TCL_OK;

    /*
     * Parse the arguments.
     */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "list ?index ...?");
	return TCL_ERROR;
    }

    listObj = objv[1];
    if (TclListObjLength(interp, listObj, &listLen) != TCL_OK) {
	return TCL_ERROR;
    }

    idxc = objc - 2;
    if (idxc == 0) {
	Tcl_SetObjResult(interp, listObj);
	return TCL_OK;
    }
    idxv = (Tcl_Size *)Tcl_Alloc((objc - 2) * sizeof(*idxv));
    for (i = 2; i < objc; i++) {
	status = (TclGetIntForIndexM(interp, objv[i], /*endValue*/ listLen - 1,
		&idxv[i - 2]) != TCL_OK);
	if (status != TCL_OK) {
	    goto done;
	}
    }

    /*
     * Sort the indices, large to small so that when we remove an index we
     * don't change the indices still to be processed.
     */

    if (idxc > 1) {
	qsort(idxv, idxc, sizeof(*idxv), LremoveIndexCompare);
    }

    /*
     * Make our working copy, then do the actual removes piecemeal.
     */

    if (Tcl_IsShared(listObj)) {
	listObj = TclListObjCopy(NULL, listObj);
	copied = 1;
    }
    num = 0;
    first = listLen;
    for (i = 0, prevIdx = -1 ; i < idxc ; i++) {
	Tcl_Size idx = idxv[i];

	/*
	 * Repeated index and sanity check.
	 */

	if (idx == prevIdx) {
	    continue;
	}
	prevIdx = idx;
	if (idx < 0 || idx >= listLen) {
	    continue;
	}

	/*
	 * Coalesce adjacent removes to reduce the number of copies.
	 */

	if (num == 0) {
	    num = 1;
	    first = idx;
	} else if (idx + 1 == first) {
	    num++;
	    first = idx;
	} else {
	    /*
	     * Note that this operation can't fail now; we know we have a list
	     * and we're only ever contracting that list.
	     */

	    status = Tcl_ListObjReplace(interp, listObj, first, num, 0, NULL);
	    if (status != TCL_OK) {
		goto done;
	    }
	    listLen -= num;
	    num = 1;
	    first = idx;
	}
    }
    if (num != 0) {
	status = Tcl_ListObjReplace(interp, listObj, first, num, 0, NULL);
	if (status != TCL_OK) {
	    if (copied) {
		Tcl_DecrRefCount(listObj);
	    }
	    goto done;
	}
    }
    Tcl_SetObjResult(interp, listObj);
done:
    Tcl_Free(idxv);
    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LrepeatObjCmd --
 *
 *	This procedure is invoked to process the "lrepeat" Tcl command. See
 *	the user documentation for details on what it does.
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
Tcl_LrepeatObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,		/* Number of arguments. */
    Tcl_Obj *const objv[])
				/* The argument objects. */
{
    Tcl_WideInt elementCount, i;
    Tcl_Size totalElems;
    Tcl_Obj *listPtr, **dataArray = NULL;

    /*
     * Check arguments for legality:
     *		lrepeat count ?value ...?
     */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "count ?value ...?");
	return TCL_ERROR;
    }
    if (TCL_OK != TclGetWideIntFromObj(interp, objv[1], &elementCount)) {
	return TCL_ERROR;
    }
    if (elementCount < 0) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"bad count \"%" TCL_LL_MODIFIER "d\": must be integer >= 0", elementCount));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LREPEAT", "NEGARG",
		(char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Skip forward to the interesting arguments now we've finished parsing.
     */

    objc -= 2;
    objv += 2;

    /* Final sanity check. Do not exceed limits on max list length. */

    if (elementCount && objc > LIST_MAX/elementCount) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"max length of a Tcl list (%" TCL_SIZE_MODIFIER "d elements) exceeded", LIST_MAX));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
	return TCL_ERROR;
    }
    totalElems = objc * elementCount;

    /*
     * Get an empty list object that is allocated large enough to hold each
     * init value elementCount times.
     */

    listPtr = Tcl_NewListObj(totalElems, NULL);
    if (totalElems) {
	ListRep listRep;
	ListObjGetRep(listPtr, &listRep);
	dataArray = ListRepElementsBase(&listRep);
	listRep.storePtr->numUsed = totalElems;
	if (listRep.spanPtr) {
	    /* Future proofing in case Tcl_NewListObj returns a span */
	    listRep.spanPtr->spanStart = listRep.storePtr->firstUsed;
	    listRep.spanPtr->spanLength = listRep.storePtr->numUsed;
	}
    }

    /*
     * Set the elements. Note that we handle the common degenerate case of a
     * single value being repeated separately to permit the compiler as much
     * room as possible to optimize a loop that might be run a very large
     * number of times.
     */

    CLANG_ASSERT(dataArray || totalElems == 0 );
    if (objc == 1) {
	Tcl_Obj *tmpPtr = objv[0];

	tmpPtr->refCount += elementCount;
	for (i=0 ; i<elementCount ; i++) {
	    dataArray[i] = tmpPtr;
	}
    } else {
	Tcl_Size j, k = 0;

	for (i=0 ; i<elementCount ; i++) {
	    for (j=0 ; j<objc ; j++) {
		Tcl_IncrRefCount(objv[j]);
		dataArray[k++] = objv[j];
	    }
	}
    }

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LreplaceObjCmd --
 *
 *	This object-based procedure is invoked to process the "lreplace" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A new Tcl list object formed by replacing zero or more elements of a
 *	list.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_LreplaceObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *listPtr;
    Tcl_Size numToDelete, listLen, first, last;
    int result;

    if (objc < 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"list first last ?element ...?");
	return TCL_ERROR;
    }

    result = TclListObjLength(interp, objv[1], &listLen);
    if (result != TCL_OK) {
	return result;
    }

    /*
     * Get the first and last indexes. "end" is interpreted to be the index
     * for the last element, such that using it will cause that element to be
     * included for deletion.
     */

    result = TclGetIntForIndexM(interp, objv[2], /*end*/ listLen-1, &first);
    if (result != TCL_OK) {
	return result;
    }

    result = TclGetIntForIndexM(interp, objv[3], /*end*/ listLen-1, &last);
    if (result != TCL_OK) {
	return result;
    }

    if (first < 0) {
	first = 0;
    } else if (first > listLen) {
	first = listLen;
    }

    if (last >= listLen) {
	last = listLen - 1;
    }
    if (first <= last) {
	numToDelete = (size_t)last - (size_t)first + 1; /* See [3d3124d01d] */
    } else {
	numToDelete = 0;
    }

    /*
     * If the list object is unshared we can modify it directly, otherwise we
     * create a copy to modify: this is "copy on write".
     */

    listPtr = objv[1];
    if (Tcl_IsShared(listPtr)) {
	listPtr = TclListObjCopy(NULL, listPtr);
    }

    /*
     * Note that we call Tcl_ListObjReplace even when numToDelete == 0 and
     * objc == 4. In this case, the list value of listPtr is not changed (no
     * elements are removed or added), but by making the call we are assured
     * we end up with a list in canonical form. Resist any temptation to
     * optimize this case away.
     */

    if (TCL_OK != Tcl_ListObjReplace(interp, listPtr, first, numToDelete,
	    objc-4, objv+4)) {
	Tcl_DecrRefCount(listPtr);
	return TCL_ERROR;
    }

    /*
     * Set the interpreter's object result.
     */

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LreverseObjCmd --
 *
 *	This procedure is invoked to process the "lreverse" Tcl command. See
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
Tcl_LreverseObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument values. */
{
    Tcl_Obj **elemv;
    Tcl_Size elemc, i, j;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "list");
	return TCL_ERROR;
    }

    /*
     *  Handle AbstractList special case - do not shimmer into a list, if it
     *  supports a private Reverse function, just to reverse it.
     */
    if (TclObjTypeHasProc(objv[1], reverseProc)) {
	Tcl_Obj *resultObj;

	if (TclObjTypeReverse(interp, objv[1], &resultObj) == TCL_OK) {
	    Tcl_SetObjResult(interp, resultObj);
	    return TCL_OK;
	}
    } /* end Abstract List */

    if (TclListObjLength(interp, objv[1], &elemc) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * If the list is empty, just return it. [Bug 1876793]
     */

    if (!elemc) {
	Tcl_SetObjResult(interp, objv[1]);
	return TCL_OK;
    }
    if (TclListObjGetElements(interp, objv[1], &elemc, &elemv) != TCL_OK) {
	return TCL_ERROR;
    }

    if (Tcl_IsShared(objv[1])
	    || ListObjRepIsShared(objv[1])) { /* Bug 1675044 */
	Tcl_Obj *resultObj, **dataArray;
	ListRep listRep;

	resultObj = Tcl_NewListObj(elemc, NULL);

	/* Modify the internal rep in-place */
	ListObjGetRep(resultObj, &listRep);
	listRep.storePtr->numUsed = elemc;
	dataArray = ListRepElementsBase(&listRep);
	if (listRep.spanPtr) {
	    /* Future proofing */
	    listRep.spanPtr->spanStart = listRep.storePtr->firstUsed;
	    listRep.spanPtr->spanLength = listRep.storePtr->numUsed;
	}

	for (i=0,j=elemc-1 ; i<elemc ; i++,j--) {
	    dataArray[j] = elemv[i];
	    Tcl_IncrRefCount(elemv[i]);
	}

	Tcl_SetObjResult(interp, resultObj);
    } else {

	/*
	 * Not shared, so swap "in place". This relies on Tcl_LOGE above
	 * returning a pointer to the live array of Tcl_Obj values.
	 */

	for (i=0,j=elemc-1 ; i<j ; i++,j--) {
	    Tcl_Obj *tmp = elemv[i];

	    elemv[i] = elemv[j];
	    elemv[j] = tmp;
	}
	TclInvalidateStringRep(objv[1]);
	Tcl_SetObjResult(interp, objv[1]);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LsearchObjCmd --
 *
 *	This procedure is invoked to process the "lsearch" Tcl command. See
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
Tcl_LsearchObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument values. */
{
    const char *bytes, *patternBytes;
    int match, result=TCL_OK, bisect;
    Tcl_Size i, length = 0, listc, elemLen, start, index;
    Tcl_Size groupOffset, lower, upper;
    int allocatedIndexVector = 0;
    int isIncreasing;
    Tcl_WideInt patWide, objWide, wide, groupSize;
    int allMatches, inlineReturn, negatedMatch, returnSubindices, noCase;
    double patDouble, objDouble;
    SortInfo sortInfo;
    Tcl_Obj *patObj, **listv, *listPtr, *startPtr, *itemPtr = NULL;
    SortStrCmpFn_t strCmpFn = TclUtfCmp;
    Tcl_RegExp regexp = NULL;
    static const char *const options[] = {
	"-all",	    "-ascii",   "-bisect", "-decreasing", "-dictionary",
	"-exact",   "-glob",    "-increasing", "-index",
	"-inline",  "-integer", "-nocase",     "-not",
	"-real",    "-regexp",  "-sorted",     "-start", "-stride",
	"-subindices", NULL
    };
    enum lsearchoptions {
	LSEARCH_ALL, LSEARCH_ASCII, LSEARCH_BISECT, LSEARCH_DECREASING,
	LSEARCH_DICTIONARY, LSEARCH_EXACT, LSEARCH_GLOB, LSEARCH_INCREASING,
	LSEARCH_INDEX, LSEARCH_INLINE, LSEARCH_INTEGER, LSEARCH_NOCASE,
	LSEARCH_NOT, LSEARCH_REAL, LSEARCH_REGEXP, LSEARCH_SORTED,
	LSEARCH_START, LSEARCH_STRIDE, LSEARCH_SUBINDICES
    };
    enum datatypes {
	ASCII, DICTIONARY, INTEGER, REAL
    } dataType;
    enum modes {
	EXACT, GLOB, REGEXP, SORTED
    };
    enum modes mode;

    mode = GLOB;
    dataType = ASCII;
    isIncreasing = 1;
    allMatches = 0;
    inlineReturn = 0;
    returnSubindices = 0;
    negatedMatch = 0;
    bisect = 0;
    listPtr = NULL;
    startPtr = NULL;
    groupSize = 1;
    groupOffset = 0;
    start = 0;
    noCase = 0;
    sortInfo.compareCmdPtr = NULL;
    sortInfo.isIncreasing = 1;
    sortInfo.sortMode = 0;
    sortInfo.interp = interp;
    sortInfo.resultCode = TCL_OK;
    sortInfo.indexv = NULL;
    sortInfo.indexc = 0;

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-option value ...? list pattern");
	return TCL_ERROR;
    }

    for (i = 1; i < objc-2; i++) {
	enum lsearchoptions idx;
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0, &idx)
		!= TCL_OK) {
	    result = TCL_ERROR;
	    goto done;
	}
	switch (idx) {
	case LSEARCH_ALL:		/* -all */
	    allMatches = 1;
	    break;
	case LSEARCH_ASCII:		/* -ascii */
	    dataType = ASCII;
	    break;
	case LSEARCH_BISECT:		/* -bisect */
	    mode = SORTED;
	    bisect = 1;
	    break;
	case LSEARCH_DECREASING:	/* -decreasing */
	    isIncreasing = 0;
	    sortInfo.isIncreasing = 0;
	    break;
	case LSEARCH_DICTIONARY:	/* -dictionary */
	    dataType = DICTIONARY;
	    break;
	case LSEARCH_EXACT:		/* -increasing */
	    mode = EXACT;
	    break;
	case LSEARCH_GLOB:		/* -glob */
	    mode = GLOB;
	    break;
	case LSEARCH_INCREASING:	/* -increasing */
	    isIncreasing = 1;
	    sortInfo.isIncreasing = 1;
	    break;
	case LSEARCH_INLINE:		/* -inline */
	    inlineReturn = 1;
	    break;
	case LSEARCH_INTEGER:		/* -integer */
	    dataType = INTEGER;
	    break;
	case LSEARCH_NOCASE:		/* -nocase */
	    strCmpFn = TclUtfCasecmp;
	    noCase = 1;
	    break;
	case LSEARCH_NOT:		/* -not */
	    negatedMatch = 1;
	    break;
	case LSEARCH_REAL:		/* -real */
	    dataType = REAL;
	    break;
	case LSEARCH_REGEXP:		/* -regexp */
	    mode = REGEXP;
	    break;
	case LSEARCH_SORTED:		/* -sorted */
	    mode = SORTED;
	    break;
	case LSEARCH_SUBINDICES:	/* -subindices */
	    returnSubindices = 1;
	    break;
	case LSEARCH_START:		/* -start */
	    /*
	     * If there was a previous -start option, release its saved index
	     * because it will either be replaced or there will be an error.
	     */

	    if (startPtr != NULL) {
		Tcl_DecrRefCount(startPtr);
		startPtr = NULL;
	    }
	    if (i > objc-4) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"missing starting index", -1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		result = TCL_ERROR;
		goto done;
	    }
	    i++;
	    if (objv[i] == objv[objc - 2]) {
		/*
		 * Take copy to prevent shimmering problems. Note that it does
		 * not matter if the index obj is also a component of the list
		 * being searched. We only need to copy where the list and the
		 * index are one-and-the-same.
		 */

		startPtr = Tcl_DuplicateObj(objv[i]);
	    } else {
		startPtr = objv[i];
	    }
	    Tcl_IncrRefCount(startPtr);
	    break;
	case LSEARCH_STRIDE:		/* -stride */
	    if (i > objc-4) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-stride\" option must be "
			"followed by stride length", -1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		result = TCL_ERROR;
		goto done;
	    }
	    if (TclGetWideIntFromObj(interp, objv[i+1], &wide) != TCL_OK) {
		result = TCL_ERROR;
		goto done;
	    }
	    if (wide < 1) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"stride length must be at least 1", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSEARCH",
			"BADSTRIDE", (char *)NULL);
		result = TCL_ERROR;
		goto done;
	    }
	    groupSize = wide;
	    i++;
	    break;
	case LSEARCH_INDEX: {		/* -index */
	    Tcl_Obj **indices;
	    Tcl_Size j;

	    if (allocatedIndexVector) {
		TclStackFree(interp, sortInfo.indexv);
		allocatedIndexVector = 0;
	    }
	    if (i > objc-4) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-index\" option must be followed by list index",
			-1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		result = TCL_ERROR;
		goto done;
	    }

	    /*
	     * Store the extracted indices for processing by sublist
	     * extraction. Note that we don't do this using objects because
	     * that has shimmering problems.
	     */

	    i++;
	    if (TclListObjGetElements(interp, objv[i],
		    &sortInfo.indexc, &indices) != TCL_OK) {
		result = TCL_ERROR;
		goto done;
	    }
	    switch (sortInfo.indexc) {
	    case 0:
		sortInfo.indexv = NULL;
		break;
	    case 1:
		sortInfo.indexv = &sortInfo.singleIndex;
		break;
	    default:
		sortInfo.indexv = (int *)
			TclStackAlloc(interp, sizeof(int) * sortInfo.indexc);
		allocatedIndexVector = 1; /* Cannot use indexc field, as it
					   * might be decreased by 1 later. */
	    }

	    /*
	     * Fill the array by parsing each index. We don't know whether
	     * their scale is sensible yet, but we at least perform the
	     * syntactic check here.
	     */

	    for (j=0 ; j<sortInfo.indexc ; j++) {
		int encoded = 0;
		if (TclIndexEncode(interp, indices[j], TCL_INDEX_NONE,
			TCL_INDEX_NONE, &encoded) != TCL_OK) {
		    result = TCL_ERROR;
		}
		if (encoded == (int)TCL_INDEX_NONE) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "index \"%s\" out of range",
			    TclGetString(indices[j])));
		    Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
		    result = TCL_ERROR;
		}
		if (result == TCL_ERROR) {
		    Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
			    "\n    (-index option item number %" TCL_Z_MODIFIER "u)", j));
		    goto done;
		}
		sortInfo.indexv[j] = encoded;
	    }
	    break;
	}
	}
    }

    /*
     * Subindices only make sense if asked for with -index option set.
     */

    if (returnSubindices && sortInfo.indexc==0) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"-subindices cannot be used without -index option", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSEARCH",
		"BAD_OPTION_MIX", (char *)NULL);
	result = TCL_ERROR;
	goto done;
    }

    if (bisect && (allMatches || negatedMatch)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"-bisect is not compatible with -all or -not", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSEARCH",
		"BAD_OPTION_MIX", (char *)NULL);
	result = TCL_ERROR;
	goto done;
    }

    if (mode == REGEXP) {
	/*
	 * We can shimmer regexp/list if listv[i] == pattern, so get the
	 * regexp rep before the list rep. First time round, omit the interp
	 * and hope that the compilation will succeed. If it fails, we'll
	 * recompile in "expensive" mode with a place to put error messages.
	 */

	regexp = Tcl_GetRegExpFromObj(NULL, objv[objc - 1],
		TCL_REG_ADVANCED | TCL_REG_NOSUB |
		(noCase ? TCL_REG_NOCASE : 0));
	if (regexp == NULL) {
	    /*
	     * Failed to compile the RE. Try again without the TCL_REG_NOSUB
	     * flag in case the RE had sub-expressions in it [Bug 1366683]. If
	     * this fails, an error message will be left in the interpreter.
	     */

	    regexp = Tcl_GetRegExpFromObj(interp, objv[objc - 1],
		    TCL_REG_ADVANCED | (noCase ? TCL_REG_NOCASE : 0));
	}

	if (regexp == NULL) {
	    result = TCL_ERROR;
	    goto done;
	}
    }

    /*
     * Make sure the list argument is a list object and get its length and a
     * pointer to its array of element pointers.
     */

    result = TclListObjGetElements(interp, objv[objc - 2], &listc, &listv);
    if (result != TCL_OK) {
	goto done;
    }

    /*
     * Check for sanity when grouping elements of the overall list together
     * because of the -stride option. [TIP #351]
     */

    if (groupSize > 1) {
	if (listc % groupSize) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "list size must be a multiple of the stride length",
		    -1));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSEARCH", "BADSTRIDE",
		    (char *)NULL);
	    result = TCL_ERROR;
	    goto done;
	}
	if (sortInfo.indexc > 0) {
	    /*
	     * Use the first value in the list supplied to -index as the
	     * offset of the element within each group by which to sort.
	     */

	    groupOffset = TclIndexDecode(sortInfo.indexv[0], groupSize - 1);
	    if (groupOffset < 0 || groupOffset >= groupSize) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"when used with \"-stride\", the leading \"-index\""
			" value must be within the group", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSEARCH",
			"BADINDEX", (char *)NULL);
		result = TCL_ERROR;
		goto done;
	    }
	    if (sortInfo.indexc == 1) {
		sortInfo.indexc = 0;
		sortInfo.indexv = NULL;
	    } else {
		sortInfo.indexc--;

		for (i = 0; i < sortInfo.indexc; i++) {
		    sortInfo.indexv[i] = sortInfo.indexv[i+1];
		}
	    }
	}
    }

    /*
     * Get the user-specified start offset.
     */

    if (startPtr) {
	result = TclGetIntForIndexM(interp, startPtr, listc-1, &start);
	if (result != TCL_OK) {
	    goto done;
	}
	if (start == TCL_INDEX_NONE) {
	    start = TCL_INDEX_START;
	}

	/*
	 * If the search started past the end of the list, we just return a
	 * "did not match anything at all" result straight away. [Bug 1374778]
	 */

	if (start >= listc) {
	    if (allMatches || inlineReturn) {
		Tcl_ResetResult(interp);
	    } else {
		TclNewIntObj(itemPtr, -1);
		Tcl_SetObjResult(interp, itemPtr);
	    }
	    goto done;
	}

	/*
	 * If start points within a group, it points to the start of the group.
	 */

	if (groupSize > 1) {
	    start -= (start % groupSize);
	}
    }

    patObj = objv[objc - 1];
    patternBytes = NULL;
    if (mode == EXACT || mode == SORTED) {
	switch (dataType) {
	case ASCII:
	case DICTIONARY:
	    patternBytes = TclGetStringFromObj(patObj, &length);
	    break;
	case INTEGER:
	    result = TclGetWideIntFromObj(interp, patObj, &patWide);
	    if (result != TCL_OK) {
		goto done;
	    }

	    /*
	     * List representation might have been shimmered; restore it. [Bug
	     * 1844789]
	     */

	    TclListObjGetElements(NULL, objv[objc - 2], &listc, &listv);
	    break;
	case REAL:
	    result = Tcl_GetDoubleFromObj(interp, patObj, &patDouble);
	    if (result != TCL_OK) {
		goto done;
	    }

	    /*
	     * List representation might have been shimmered; restore it. [Bug
	     * 1844789]
	     */

	    TclListObjGetElements(NULL, objv[objc - 2], &listc, &listv);
	    break;
	}
    } else {
	patternBytes = TclGetStringFromObj(patObj, &length);
    }

    /*
     * Set default index value to -1, indicating failure; if we find the item
     * in the course of our search, index will be set to the correct value.
     */

    index = -1;
    match = 0;

    if (mode == SORTED && !allMatches && !negatedMatch) {
	/*
	 * If the data is sorted, we can do a more intelligent search. Note
	 * that there is no point in being smart when -all was specified; in
	 * that case, we have to look at all items anyway, and there is no
	 * sense in doing this when the match sense is inverted.
	 */

	/*
	 * With -stride, lower, upper and i are kept as multiples of groupSize.
	 */

	lower = start - groupSize;
	upper = listc;
	itemPtr = NULL;
	while (lower + groupSize != upper && sortInfo.resultCode == TCL_OK) {
	    i = (lower + upper)/2;
	    i -= i % groupSize;

	    Tcl_BounceRefCount(itemPtr);
	    itemPtr = NULL;

	    if (sortInfo.indexc != 0) {
		itemPtr = SelectObjFromSublist(listv[i+groupOffset], &sortInfo);
		if (sortInfo.resultCode != TCL_OK) {
		    result = sortInfo.resultCode;
		    goto done;
		}
	    } else {
		itemPtr = listv[i+groupOffset];
	    }
	    switch (dataType) {
	    case ASCII:
		bytes = TclGetString(itemPtr);
		match = strCmpFn(patternBytes, bytes);
		break;
	    case DICTIONARY:
		bytes = TclGetString(itemPtr);
		match = DictionaryCompare(patternBytes, bytes);
		break;
	    case INTEGER:
		result = TclGetWideIntFromObj(interp, itemPtr, &objWide);
		if (result != TCL_OK) {
		    goto done;
		}
		if (patWide == objWide) {
		    match = 0;
		} else if (patWide < objWide) {
		    match = -1;
		} else {
		    match = 1;
		}
		break;
	    case REAL:
		result = Tcl_GetDoubleFromObj(interp, itemPtr, &objDouble);
		if (result != TCL_OK) {
		    goto done;
		}
		if (patDouble == objDouble) {
		    match = 0;
		} else if (patDouble < objDouble) {
		    match = -1;
		} else {
		    match = 1;
		}
		break;
	    }
	    if (match == 0) {
		/*
		 * Normally, binary search is written to stop when it finds a
		 * match. If there are duplicates of an element in the list,
		 * our first match might not be the first occurrence.
		 * Consider: 0 0 0 1 1 1 2 2 2
		 *
		 * To maintain consistency with standard lsearch semantics, we
		 * must find the leftmost occurrence of the pattern in the
		 * list. Thus we don't just stop searching here. This
		 * variation means that a search always makes log n
		 * comparisons (normal binary search might "get lucky" with an
		 * early comparison).
		 *
		 * In bisect mode though, we want the last of equals.
		 */

		index = i;
		if (bisect) {
		    lower = i;
		} else {
		    upper = i;
		}
	    } else if (match > 0) {
		if (isIncreasing) {
		    lower = i;
		} else {
		    upper = i;
		}
	    } else {
		if (isIncreasing) {
		    upper = i;
		} else {
		    lower = i;
		}
	    }
	}
	if (bisect && index < 0) {
	    index = lower;
	}
    } else {
	/*
	 * We need to do a linear search, because (at least one) of:
	 *   - our matcher can only tell equal vs. not equal
	 *   - our matching sense is negated
	 *   - we're building a list of all matched items
	 */

	if (allMatches) {
	    listPtr = Tcl_NewListObj(0, NULL);
	}
	for (i = start; i < listc; i += groupSize) {
	    match = 0;
	    Tcl_BounceRefCount(itemPtr);
	    itemPtr = NULL;

	    if (sortInfo.indexc != 0) {
		itemPtr = SelectObjFromSublist(listv[i+groupOffset], &sortInfo);
		if (sortInfo.resultCode != TCL_OK) {
		    if (listPtr != NULL) {
			Tcl_DecrRefCount(listPtr);
		    }
		    result = sortInfo.resultCode;
		    goto done;
		}
	    } else {
		itemPtr = listv[i+groupOffset];
	    }

	    switch (mode) {
	    case SORTED:
	    case EXACT:
		switch (dataType) {
		case ASCII:
		    bytes = TclGetStringFromObj(itemPtr, &elemLen);
		    if (length == elemLen) {
			/*
			 * This split allows for more optimal compilation of
			 * memcmp/strcasecmp.
			 */

			if (noCase) {
			    match = (TclUtfCasecmp(bytes, patternBytes) == 0);
			} else {
			    match = (memcmp(bytes, patternBytes, length) == 0);
			}
		    }
		    break;

		case DICTIONARY:
		    bytes = TclGetString(itemPtr);
		    match = (DictionaryCompare(bytes, patternBytes) == 0);
		    break;

		case INTEGER:
		    result = TclGetWideIntFromObj(interp, itemPtr, &objWide);
		    if (result != TCL_OK) {
			if (listPtr != NULL) {
			    Tcl_DecrRefCount(listPtr);
			}
			goto done;
		    }
		    match = (objWide == patWide);
		    break;

		case REAL:
		    result = Tcl_GetDoubleFromObj(interp,itemPtr, &objDouble);
		    if (result != TCL_OK) {
			if (listPtr) {
			    Tcl_DecrRefCount(listPtr);
			}
			goto done;
		    }
		    match = (objDouble == patDouble);
		    break;
		}
		break;

	    case GLOB:
		match = Tcl_StringCaseMatch(TclGetString(itemPtr),
			patternBytes, noCase);
		break;

	    case REGEXP:
		match = Tcl_RegExpExecObj(interp, regexp, itemPtr, 0, 0, 0);
		if (match < 0) {
		    Tcl_DecrRefCount(patObj);
		    if (listPtr != NULL) {
			Tcl_DecrRefCount(listPtr);
		    }
		    result = TCL_ERROR;
		    goto done;
		}
		break;
	    }

	    /*
	     * Invert match condition for -not.
	     */

	    if (negatedMatch) {
		match = !match;
	    }
	    if (!match) {
		continue;
	    }
	    if (!allMatches) {
		index = i;
		break;
	    } else if (inlineReturn) {
		/*
		 * Note that these appends are not expected to fail.
		 */

		if (returnSubindices && (sortInfo.indexc != 0)) {
		    Tcl_BounceRefCount(itemPtr);
		    itemPtr = SelectObjFromSublist(listv[i+groupOffset],
			    &sortInfo);
		    Tcl_ListObjAppendElement(interp, listPtr, itemPtr);
		} else if (returnSubindices && (sortInfo.indexc == 0) && (groupSize > 1)) {
		    Tcl_BounceRefCount(itemPtr);
		    itemPtr = listv[i + groupOffset];
			Tcl_ListObjAppendElement(interp, listPtr, itemPtr);
		} else if (groupSize > 1) {
		    Tcl_ListObjReplace(interp, listPtr, LIST_MAX, 0,
			    groupSize, &listv[i]);
		} else {
		    Tcl_BounceRefCount(itemPtr);
		    itemPtr = listv[i];
		    Tcl_ListObjAppendElement(interp, listPtr, itemPtr);
		}
	    } else if (returnSubindices) {
		Tcl_Size j;

		TclNewIndexObj(itemPtr, i+groupOffset);
		for (j=0 ; j<sortInfo.indexc ; j++) {
		    Tcl_Obj *elObj;
		    size_t elValue = TclIndexDecode(sortInfo.indexv[j], listc);
		    TclNewIndexObj(elObj, elValue);
		    Tcl_ListObjAppendElement(interp, itemPtr, elObj);
		}
		Tcl_ListObjAppendElement(interp, listPtr, itemPtr);
	    } else {
		Tcl_ListObjAppendElement(interp, listPtr, Tcl_NewWideIntObj(i));
	    }
	}
    }

    Tcl_BounceRefCount(itemPtr);
    itemPtr = NULL;

    /*
     * Return everything or a single value.
     */

    if (allMatches) {
	Tcl_SetObjResult(interp, listPtr);
    } else if (!inlineReturn) {
	if (returnSubindices) {
	    Tcl_Size j;

	    TclNewIndexObj(itemPtr, index+groupOffset);
	    for (j=0 ; j<sortInfo.indexc ; j++) {
		Tcl_Obj *elObj;
		size_t elValue = TclIndexDecode(sortInfo.indexv[j], listc);
		TclNewIndexObj(elObj, elValue);
		Tcl_ListObjAppendElement(interp, itemPtr, elObj);
	    }
	    Tcl_SetObjResult(interp, itemPtr);
	} else {
		Tcl_Obj *elObj;
		TclNewIndexObj(elObj, index);
	    Tcl_SetObjResult(interp, elObj);
	}
    } else if (index < 0) {
	/*
	 * Is this superfluous? The result should be a blank object by
	 * default...
	 */

	Tcl_SetObjResult(interp, Tcl_NewObj());
    } else {
	if (returnSubindices) {
	    Tcl_SetObjResult(interp, SelectObjFromSublist(listv[i+groupOffset],
		    &sortInfo));
	} else if (groupSize > 1) {
	    Tcl_SetObjResult(interp, Tcl_NewListObj(groupSize, &listv[index]));
	} else {
	    Tcl_SetObjResult(interp, listv[index]);
	}
    }
    result = TCL_OK;

    /*
     * Cleanup the index list array.
     */

  done:
    /* potential lingering abstract list element */
    Tcl_BounceRefCount(itemPtr);

    if (startPtr != NULL) {
	Tcl_DecrRefCount(startPtr);
    }
    if (allocatedIndexVector) {
	TclStackFree(interp, sortInfo.indexv);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * SequenceIdentifyArgument --
 *   (for [lseq] command)
 *
 *  Given a Tcl_Obj, identify if it is a keyword or a number
 *
 *  Return Value
 *    0 - failure, unexpected value
 *    1 - value is a number
 *    2 - value is an operand keyword
 *    3 - value is a by keyword
 *
 *  The decoded value will be assigned to the appropriate
 *  pointer, numValuePtr reference count is incremented.
 */

static SequenceDecoded
SequenceIdentifyArgument(
     Tcl_Interp *interp,        /* for error reporting  */
     Tcl_Obj *argPtr,           /* Argument to decode   */
     int allowedArgs,		/* Flags if keyword or numeric allowed. */
     Tcl_Obj **numValuePtr,     /* Return numeric value */
     int *keywordIndexPtr)      /* Return keyword enum  */
{
    int result = TCL_ERROR;
    SequenceOperators opmode;
    void *internalPtr;

    if (allowedArgs & NumericArg) {
	/* speed-up a bit (and avoid shimmer for compiled expressions) */
	if (TclHasInternalRep(argPtr, &tclExprCodeType)) {
	   goto doExpr;
	}
	result = Tcl_GetNumberFromObj(NULL, argPtr, &internalPtr, keywordIndexPtr);
	if (result == TCL_OK) {
	    *numValuePtr = argPtr;
	    Tcl_IncrRefCount(argPtr);
	    return NumericArg;
	}
    }
    if (allowedArgs & RangeKeywordArg) {
	result = Tcl_GetIndexFromObj(NULL, argPtr, seq_operations,
			"range operation", 0, &opmode);
    }
    if (result == TCL_OK) {
	if (allowedArgs & LastArg) {
	    /* keyword found, but no followed number */
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		  "missing \"%s\" value.", TclGetString(argPtr)));
	    return ErrArg;
	}
	*keywordIndexPtr = opmode;
	return RangeKeywordArg;
    } else {
	Tcl_Obj *exprValueObj;
	if (!(allowedArgs & NumericArg)) {
	    return NoneArg;
	}
    doExpr:
	/* Check for an index expression */
	if (Tcl_ExprObj(interp, argPtr, &exprValueObj) != TCL_OK) {
	    return ErrArg;
	}
	int keyword;
	/* Determine if result of expression is double or int */
	if (Tcl_GetNumberFromObj(interp, exprValueObj, &internalPtr,
		&keyword) != TCL_OK
	) {
	    return ErrArg;
	}
	*numValuePtr = exprValueObj; /* incremented in Tcl_ExprObj */
	*keywordIndexPtr = keyword; /* type of expression result */
	return NumericArg;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LseqObjCmd --
 *
 *	This procedure is invoked to process the "lseq" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Enumerated possible argument patterns:
 *
 * 1:
 *    lseq n
 * 2:
 *    lseq n n
 * 3:
 *    lseq n n n
 *    lseq n 'to' n
 *    lseq n 'count' n
 *    lseq n 'by' n
 * 4:
 *    lseq n 'to' n n
 *    lseq n n 'by' n
 *    lseq n 'count' n n
 * 5:
 *    lseq n 'to' n 'by' n
 *    lseq n 'count' n 'by' n
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
Tcl_LseqObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,	   /* Current interpreter. */
    int objc,		   /* Number of arguments. */
    Tcl_Obj *const objv[]) /* The argument objects. */
{
    Tcl_Obj *elementCount = NULL;
    Tcl_Obj *start = NULL, *end = NULL, *step = NULL;
    Tcl_WideInt values[5];
    Tcl_Obj *numValues[5];
    Tcl_Obj *numberObj;
    int status = TCL_ERROR, keyword, allowedArgs = NumericArg;
    int useDoubles = 0;
    int remNums = 3;
    Tcl_Obj *arithSeriesPtr;
    SequenceOperators opmode;
    SequenceDecoded decoded;
    int i, arg_key = 0, value_i = 0;
    /* Default constants */
    #define zero ((Interp *)interp)->execEnvPtr->constants[0];
    #define one ((Interp *)interp)->execEnvPtr->constants[1];

    /*
     * Create a decoding key by looping through the arguments and identify
     * what kind of argument each one is.  Encode each argument as a decimal
     * digit.
     */
    if (objc > 6) {
	/* Too many arguments */
	goto syntax;
    }
    for (i = 1; i < objc; i++) {
	arg_key = (arg_key * 10);
	numValues[value_i] = NULL;
	decoded = SequenceIdentifyArgument(interp, objv[i],
			allowedArgs | (i == objc-1 ? LastArg : 0),
			&numberObj, &keyword);
	switch (decoded) {
	  case NoneArg:
	    /*
	     * Unrecognizable argument
	     * Reproduce operation error message
	     */
	    status = Tcl_GetIndexFromObj(interp, objv[i], seq_operations,
			"operation", 0, &opmode);
	    goto done;

	  case NumericArg:
	    remNums--;
	    arg_key += NumericArg;
	    allowedArgs = RangeKeywordArg;
	    /* if last number but 2 arguments remain, next is not numeric */
	    if ((remNums != 1) || ((objc-1-i) != 2)) {
		allowedArgs |= NumericArg;
	    }
	    numValues[value_i] = numberObj;
	    values[value_i] = keyword;  /* TCL_NUMBER_* */
	    if ((keyword == TCL_NUMBER_DOUBLE || keyword == TCL_NUMBER_NAN)) {
		useDoubles++;
	    }
	    value_i++;
	    break;

	  case RangeKeywordArg:
	    arg_key += RangeKeywordArg;
	    allowedArgs = NumericArg;   /* after keyword always numeric only */
	    values[value_i] = keyword;  /* SequenceOperators */
	    value_i++;
	    break;

	  default: /* Error state */
	    status = TCL_ERROR;
	    goto done;
	}
    }

    /*
     * The key encoding defines a valid set of arguments, or indicates an
     * error condition; process the values accordningly.
     */
    switch (arg_key) {

/*    lseq n */
    case 1:
	start = zero;
	elementCount = numValues[0];
	end = NULL;
	step = one;
	useDoubles = 0; /* Can only have Integer value. If a fractional value
			 * is given, this will fail later. In other words,
			 * "3.0" is allowed and used as Integer, but "3.1"
			 * will be flagged as an error. (bug f4a4bd7f1070) */
	break;

/*    lseq n n */
    case 11:
	start = numValues[0];
	end = numValues[1];
	break;

/*    lseq n n n */
    case 111:
	start = numValues[0];
	end = numValues[1];
	step = numValues[2];
	break;

/*    lseq n 'to' n    */
/*    lseq n 'count' n */
/*    lseq n 'by' n    */
    case 121:
	opmode = (SequenceOperators)values[1];
	switch (opmode) {
	case LSEQ_DOTS:
	case LSEQ_TO:
	    start = numValues[0];
	    end = numValues[2];
	    break;
	case LSEQ_BY:
	    start = zero;
	    elementCount = numValues[0];
	    step = numValues[2];
	    break;
	case LSEQ_COUNT:
	    start = numValues[0];
	    elementCount = numValues[2];
	    step = one;
	    break;
	default:
	    goto syntax;
	}
	break;

/*    lseq n 'to' n n    */
/*    lseq n 'count' n n */
    case 1211:
	opmode = (SequenceOperators)values[1];
	switch (opmode) {
	case LSEQ_DOTS:
	case LSEQ_TO:
	    start = numValues[0];
	    end = numValues[2];
	    step = numValues[3];
	    break;
	case LSEQ_COUNT:
	    start = numValues[0];
	    elementCount = numValues[2];
	    step = numValues[3];
	    break;
	case LSEQ_BY:
	    /* Error case */
	    goto syntax;
	    break;
	default:
	    goto syntax;
	    break;
	}
	break;

/*    lseq n n 'by' n */
    case 1121:
	start = numValues[0];
	end = numValues[1];
	opmode = (SequenceOperators)values[2];
	switch (opmode) {
	case LSEQ_BY:
	    step = numValues[3];
	    break;
	case LSEQ_DOTS:
	case LSEQ_TO:
	case LSEQ_COUNT:
	default:
	    goto syntax;
	    break;
	}
	break;

/*    lseq n 'to' n 'by' n    */
/*    lseq n 'count' n 'by' n */
    case 12121:
	start = numValues[0];
	opmode = (SequenceOperators)values[3];
	switch (opmode) {
	case LSEQ_BY:
	    step = numValues[4];
	    break;
	default:
	    goto syntax;
	    break;
	}
	opmode = (SequenceOperators)values[1];
	switch (opmode) {
	case LSEQ_DOTS:
	case LSEQ_TO:
	    start = numValues[0];
	    end = numValues[2];
	    break;
	case LSEQ_COUNT:
	    start = numValues[0];
	    elementCount = numValues[2];
	    break;
	default:
	    goto syntax;
	    break;
	}
	break;

/*    All other argument errors */
    default:
      syntax:
	 Tcl_WrongNumArgs(interp, 1, objv, "n ??op? n ??by? n??");
	 goto done;
	 break;
    }

    /* Count needs to be integer, so try to convert if possible */
    if (elementCount && TclHasInternalRep(elementCount, &tclDoubleType)) {
	double d = elementCount->internalRep.doubleValue;
	/* Don't consider Count type to indicate using double values in seqence */
	useDoubles -= (useDoubles > 0) ? 1 : 0;
	if (!isinf(d) && !isnan(d) && floor(d) == d) {
	    if ((d >= (double)WIDE_MAX) || (d <= (double)WIDE_MIN)) {
		mp_int big;

		if (Tcl_InitBignumFromDouble(NULL, d, &big) == TCL_OK) {
		    elementCount = Tcl_NewBignumObj(&big);
		    keyword = TCL_NUMBER_INT;
		}
		/* Infinity, don't convert, let fail later */
	    } else {
		elementCount = Tcl_NewWideIntObj((Tcl_WideInt)d);
		keyword = TCL_NUMBER_INT;
	    }
	}
    }


    /*
     * Success!  Now lets create the series object.
     */
    arithSeriesPtr = TclNewArithSeriesObj(interp,
		  useDoubles, start, end, step, elementCount);

    status = TCL_ERROR;
    if (arithSeriesPtr) {
	status = TCL_OK;
	Tcl_SetObjResult(interp, arithSeriesPtr);
    }

 done:
    // Free number arguments.
    while (--value_i>=0) {
	if (numValues[value_i]) {
	    if (elementCount == numValues[value_i]) {
		elementCount = NULL;
	    }
	    Tcl_DecrRefCount(numValues[value_i]);
	}
    }
    if (elementCount) {
	Tcl_DecrRefCount(elementCount);
    }

    /* Undef constants */
    #undef zero
    #undef one

    return status;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LsetObjCmd --
 *
 *	This procedure is invoked to process the "lset" Tcl command. See the
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
Tcl_LsetObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument values. */
{
    Tcl_Obj *listPtr;		/* Pointer to the list being altered. */
    Tcl_Obj *finalValuePtr;	/* Value finally assigned to the variable. */

    /*
     * Check parameter count.
     */

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"listVar ?index? ?index ...? value");
	return TCL_ERROR;
    }

    /*
     * Look up the list variable's value.
     */

    listPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (listPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Substitute the value in the value. Return either the value or else an
     * unshared copy of it.
     */

    if (objc == 4) {
	finalValuePtr = TclLsetList(interp, listPtr, objv[2], objv[3]);
    } else {
	if (TclObjTypeHasProc(listPtr, setElementProc)) {
	    finalValuePtr = TclObjTypeSetElement(interp, listPtr,
						       objc-3, objv+2, objv[objc-1]);
	    if (finalValuePtr) {
		Tcl_IncrRefCount(finalValuePtr);
	    }
	} else {
	    finalValuePtr = TclLsetFlat(interp, listPtr, objc-3, objv+2,
					objv[objc-1]);
	}
    }

    /*
     * If substitution has failed, bail out.
     */

    if (finalValuePtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Finally, update the variable so that traces fire.
     */

    listPtr = Tcl_ObjSetVar2(interp, objv[1], NULL, finalValuePtr,
	    TCL_LEAVE_ERR_MSG);
    Tcl_DecrRefCount(finalValuePtr);
    if (listPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Return the new value of the variable as the interpreter result.
     */

    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LsortObjCmd --
 *
 *	This procedure is invoked to process the "lsort" Tcl command. See the
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
Tcl_LsortObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument values. */
{
    int indices, nocase = 0, indexc;
    int sortMode = SORTMODE_ASCII;
    int group, allocatedIndexVector = 0;
    Tcl_Size j, idx, groupOffset, length;
    Tcl_WideInt wide, groupSize;
    Tcl_Obj *resultPtr, *cmdPtr, **listObjPtrs, *listObj, *indexPtr;
    Tcl_Size i, elmArrSize;
    SortElement *elementArray = NULL, *elementPtr;
    SortInfo sortInfo;		/* Information about this sort that needs to
				 * be passed to the comparison function. */
#   define MAXCALLOC 1024000
#   define NUM_LISTS 30
    SortElement *subList[NUM_LISTS+1];
				/* This array holds pointers to temporary
				 * lists built during the merge sort. Element
				 * i of the array holds a list of length
				 * 2**i. */
    static const char *const switches[] = {
	"-ascii", "-command", "-decreasing", "-dictionary", "-increasing",
	"-index", "-indices", "-integer", "-nocase", "-real", "-stride",
	"-unique", NULL
    };
    enum Lsort_Switches {
	LSORT_ASCII, LSORT_COMMAND, LSORT_DECREASING, LSORT_DICTIONARY,
	LSORT_INCREASING, LSORT_INDEX, LSORT_INDICES, LSORT_INTEGER,
	LSORT_NOCASE, LSORT_REAL, LSORT_STRIDE, LSORT_UNIQUE
    } index;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-option value ...? list");
	return TCL_ERROR;
    }

    /*
     * Parse arguments to set up the mode for the sort.
     */

    sortInfo.isIncreasing = 1;
    sortInfo.sortMode = SORTMODE_ASCII;
    sortInfo.indexv = NULL;
    sortInfo.indexc = 0;
    sortInfo.unique = 0;
    sortInfo.interp = interp;
    sortInfo.resultCode = TCL_OK;
    cmdPtr = NULL;
    indices = 0;
    group = 0;
    groupSize = 1;
    groupOffset = 0;
    indexPtr = NULL;
    for (i = 1; i < objc-1; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], switches, "option", 0,
		&index) != TCL_OK) {
	    sortInfo.resultCode = TCL_ERROR;
	    goto done;
	}
	switch (index) {
	case LSORT_ASCII:
	    sortInfo.sortMode = SORTMODE_ASCII;
	    break;
	case LSORT_COMMAND:
	    if (i == objc-2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-command\" option must be followed "
			"by comparison command", -1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    sortInfo.sortMode = SORTMODE_COMMAND;
	    cmdPtr = objv[i+1];
	    i++;
	    break;
	case LSORT_DECREASING:
	    sortInfo.isIncreasing = 0;
	    break;
	case LSORT_DICTIONARY:
	    sortInfo.sortMode = SORTMODE_DICTIONARY;
	    break;
	case LSORT_INCREASING:
	    sortInfo.isIncreasing = 1;
	    break;
	case LSORT_INDEX: {
	    Tcl_Size sortindex;
	    Tcl_Obj **indexv;

	    if (i == objc-2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-index\" option must be followed by list index",
			-1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    if (TclListObjGetElements(interp, objv[i+1], &sortindex,
		    &indexv) != TCL_OK) {
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }

	    /*
	     * Check each of the indices for syntactic correctness. Note that
	     * we do not store the converted values here because we do not
	     * know if this is the only -index option yet and so we can't
	     * allocate any space; that happens after the scan through all the
	     * options is done.
	     */

	    for (j=0 ; j<sortindex ; j++) {
		int encoded = 0;
		int result = TclIndexEncode(interp, indexv[j],
			TCL_INDEX_NONE, TCL_INDEX_NONE, &encoded);

		if ((result == TCL_OK) && (encoded == (int)TCL_INDEX_NONE)) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "index \"%s\" out of range",
			    TclGetString(indexv[j])));
		    Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
		    result = TCL_ERROR;
		}
		if (result == TCL_ERROR) {
		    Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
			    "\n    (-index option item number %" TCL_Z_MODIFIER "u)", j));
		    sortInfo.resultCode = TCL_ERROR;
		    goto done;
		}
	    }
	    indexPtr = objv[i+1];
	    i++;
	    break;
	}
	case LSORT_INTEGER:
	    sortInfo.sortMode = SORTMODE_INTEGER;
	    break;
	case LSORT_NOCASE:
	    nocase = 1;
	    break;
	case LSORT_REAL:
	    sortInfo.sortMode = SORTMODE_REAL;
	    break;
	case LSORT_UNIQUE:
	    sortInfo.unique = 1;
	    break;
	case LSORT_INDICES:
	    indices = 1;
	    break;
	case LSORT_STRIDE:
	    if (i == objc-2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-stride\" option must be "
			"followed by stride length", -1));
		Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING", (char *)NULL);
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    if (TclGetWideIntFromObj(interp, objv[i+1], &wide) != TCL_OK) {
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    if (wide < 2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"stride length must be at least 2", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSORT",
			"BADSTRIDE", (char *)NULL);
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    groupSize = wide;
	    group = 1;
	    i++;
	    break;
	}
    }
    if (nocase && (sortInfo.sortMode == SORTMODE_ASCII)) {
	sortInfo.sortMode = SORTMODE_ASCII_NC;
    }

    /*
     * Now extract the -index list for real, if present. No failures are
     * expected here; the values are all of the right type or convertible to
     * it.
     */

    if (indexPtr) {
	Tcl_Obj **indexv;

	TclListObjGetElements(interp, indexPtr, &sortInfo.indexc, &indexv);
	switch (sortInfo.indexc) {
	case 0:
	    sortInfo.indexv = NULL;
	    break;
	case 1:
	    sortInfo.indexv = &sortInfo.singleIndex;
	    break;
	default:
	    sortInfo.indexv = (int *)
		    TclStackAlloc(interp, sizeof(int) * sortInfo.indexc);
	    allocatedIndexVector = 1;	/* Cannot use indexc field, as it
					 * might be decreased by 1 later. */
	}
	for (j=0 ; j<sortInfo.indexc ; j++) {
	    /* Prescreened values, no errors or out of range possible */
	    TclIndexEncode(NULL, indexv[j], TCL_INDEX_NONE,
		    TCL_INDEX_NONE, &sortInfo.indexv[j]);
	}
    }

    listObj = objv[objc-1];

    if (sortInfo.sortMode == SORTMODE_COMMAND) {
	Tcl_Obj *newCommandPtr, *newObjPtr;

	/*
	 * When sorting using a command, we are reentrant and therefore might
	 * have the representation of the list being sorted shimmered out from
	 * underneath our feet. Take a copy (cheap) to prevent this. [Bug
	 * 1675116]
	 */

	listObj = TclListObjCopy(interp, listObj);
	if (listObj == NULL) {
	    sortInfo.resultCode = TCL_ERROR;
	    goto done;
	}

	/*
	 * The existing command is a list. We want to flatten it, append two
	 * dummy arguments on the end, and replace these arguments later.
	 */

	newCommandPtr = Tcl_DuplicateObj(cmdPtr);
	TclNewObj(newObjPtr);
	Tcl_IncrRefCount(newCommandPtr);
	if (Tcl_ListObjAppendElement(interp, newCommandPtr, newObjPtr)
		!= TCL_OK) {
	    TclDecrRefCount(newCommandPtr);
	    TclDecrRefCount(newObjPtr);
	    sortInfo.resultCode = TCL_ERROR;
	    goto done;
	}
	Tcl_ListObjAppendElement(interp, newCommandPtr, Tcl_NewObj());
	sortInfo.compareCmdPtr = newCommandPtr;
    }

    if (TclObjTypeHasProc(objv[1], getElementsProc)) {
	sortInfo.resultCode =
	    TclObjTypeGetElements(interp, listObj, &length, &listObjPtrs);
    } else {
	sortInfo.resultCode = TclListObjGetElements(interp, listObj,
	    &length, &listObjPtrs);
    }
    if (sortInfo.resultCode != TCL_OK || length <= 0) {
	goto done;
    }

    /*
     * Check for sanity when grouping elements of the overall list together
     * because of the -stride option. [TIP #326]
     */

    if (group) {
	if (length % groupSize) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "list size must be a multiple of the stride length",
		    -1));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSORT", "BADSTRIDE",
		    (char *)NULL);
	    sortInfo.resultCode = TCL_ERROR;
	    goto done;
	}
	length = length / groupSize;
	if (sortInfo.indexc > 0) {
	    /*
	     * Use the first value in the list supplied to -index as the
	     * offset of the element within each group by which to sort.
	     */

	    groupOffset = TclIndexDecode(sortInfo.indexv[0], groupSize - 1);
	    if (groupOffset < 0 || groupOffset >= groupSize) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"when used with \"-stride\", the leading \"-index\""
			" value must be within the group", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LSORT",
			"BADINDEX", (char *)NULL);
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    if (sortInfo.indexc == 1) {
		sortInfo.indexc = 0;
		sortInfo.indexv = NULL;
	    } else {
		sortInfo.indexc--;

		/*
		 * Do not shrink the actual memory block used; that doesn't
		 * work with TclStackAlloc-allocated memory. [Bug 2918962]
		 *
		 * TODO: Consider a pointer increment to replace this
		 * array shift.
		 */

		for (i = 0; i < sortInfo.indexc; i++) {
		    sortInfo.indexv[i] = sortInfo.indexv[i+1];
		}
	    }
	}
    }

    sortInfo.numElements = length;

    indexc = sortInfo.indexc;
    sortMode = sortInfo.sortMode;
    if ((sortMode == SORTMODE_ASCII_NC)
	    || (sortMode == SORTMODE_DICTIONARY)) {
	/*
	 * For this function's purpose all string-based modes are equivalent
	 */

	sortMode = SORTMODE_ASCII;
    }

    /*
     * Initialize the sublists. After the following loop, subList[i] will
     * contain a sorted sublist of length 2**i. Use one extra subList at the
     * end, always at NULL, to indicate the end of the lists.
     */

    for (j=0 ; j<=NUM_LISTS ; j++) {
	subList[j] = NULL;
    }

    /*
     * The following loop creates a SortElement for each list element and
     * begins sorting it into the sublists as it appears.
     */

    elmArrSize = length * sizeof(SortElement);
    if (elmArrSize <= MAXCALLOC) {
	elementArray = (SortElement *)Tcl_Alloc(elmArrSize);
    } else {
	elementArray = (SortElement *)malloc(elmArrSize);
    }
    if (!elementArray) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"no enough memory to proccess sort of %" TCL_Z_MODIFIER "u items", length));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
	sortInfo.resultCode = TCL_ERROR;
	goto done;
    }

    for (i=0; i < length; i++) {
	idx = groupSize * i + groupOffset;
	if (indexc) {
	    /*
	     * If this is an indexed sort, retrieve the corresponding element
	     */
	    indexPtr = SelectObjFromSublist(listObjPtrs[idx], &sortInfo);
	    if (sortInfo.resultCode != TCL_OK) {
		goto done;
	    }
	} else {
	    indexPtr = listObjPtrs[idx];
	}

	/*
	 * Determine the "value" of this object for sorting purposes
	 */

	if (sortMode == SORTMODE_ASCII) {
	    elementArray[i].collationKey.strValuePtr = TclGetString(indexPtr);
	} else if (sortMode == SORTMODE_INTEGER) {
	    Tcl_WideInt a;

	    if (TclGetWideIntFromObj(sortInfo.interp, indexPtr, &a) != TCL_OK) {
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    elementArray[i].collationKey.wideValue = a;
	} else if (sortMode == SORTMODE_REAL) {
	    double a;

	    if (Tcl_GetDoubleFromObj(sortInfo.interp, indexPtr, &a) != TCL_OK) {
		sortInfo.resultCode = TCL_ERROR;
		goto done;
	    }
	    elementArray[i].collationKey.doubleValue = a;
	} else {
	    elementArray[i].collationKey.objValuePtr = indexPtr;
	}

	/*
	 * Determine the representation of this element in the result: either
	 * the objPtr itself, or its index in the original list.
	 */

	if (indices || group) {
	    elementArray[i].payload.index = idx;
	} else {
	    elementArray[i].payload.objPtr = listObjPtrs[idx];
	}

	/*
	 * Merge this element in the preexisting sublists (and merge together
	 * sublists when we have two of the same size).
	 */

	elementArray[i].nextPtr = NULL;
	elementPtr = &elementArray[i];
	for (j=0 ; subList[j] ; j++) {
	    elementPtr = MergeLists(subList[j], elementPtr, &sortInfo);
	    subList[j] = NULL;
	}
	if (j >= NUM_LISTS) {
	    j = NUM_LISTS-1;
	}
	subList[j] = elementPtr;
    }

    /*
     * Merge all sublists
     */

    elementPtr = subList[0];
    for (j=1 ; j<NUM_LISTS ; j++) {
	elementPtr = MergeLists(subList[j], elementPtr, &sortInfo);
    }

    /*
     * Now store the sorted elements in the result list.
     */

    if (sortInfo.resultCode == TCL_OK) {
	ListRep listRep;
	Tcl_Obj **newArray, *objPtr;

	resultPtr = Tcl_NewListObj(sortInfo.numElements * groupSize, NULL);
	ListObjGetRep(resultPtr, &listRep);
	newArray = ListRepElementsBase(&listRep);
	if (group) {
	    for (i=0; elementPtr!=NULL ; elementPtr=elementPtr->nextPtr) {
		idx = elementPtr->payload.index;
		for (j = 0; j < groupSize; j++) {
		    if (indices) {
			TclNewIndexObj(objPtr, idx + j - groupOffset);
			newArray[i++] = objPtr;
			Tcl_IncrRefCount(objPtr);
		    } else {
			objPtr = listObjPtrs[idx + j - groupOffset];
			newArray[i++] = objPtr;
			Tcl_IncrRefCount(objPtr);
		    }
		}
	    }
	} else if (indices) {
	    for (i=0; elementPtr != NULL ; elementPtr = elementPtr->nextPtr) {
		TclNewIndexObj(objPtr, elementPtr->payload.index);
		newArray[i++] = objPtr;
		Tcl_IncrRefCount(objPtr);
	    }
	} else {
	    for (i=0; elementPtr != NULL ; elementPtr = elementPtr->nextPtr) {
		objPtr = elementPtr->payload.objPtr;
		newArray[i++] = objPtr;
		Tcl_IncrRefCount(objPtr);
	    }
	}
	listRep.storePtr->numUsed = i;
	if (listRep.spanPtr) {
	    listRep.spanPtr->spanStart = listRep.storePtr->firstUsed;
	    listRep.spanPtr->spanLength = listRep.storePtr->numUsed;
	}
	Tcl_SetObjResult(interp, resultPtr);
    }

  done:
    if (sortMode == SORTMODE_COMMAND) {
	TclDecrRefCount(sortInfo.compareCmdPtr);
	TclDecrRefCount(listObj);
	sortInfo.compareCmdPtr = NULL;
    }
    if (allocatedIndexVector) {
	TclStackFree(interp, sortInfo.indexv);
    }
    if (elementArray) {
	if (elmArrSize <= MAXCALLOC) {
	    Tcl_Free(elementArray);
	} else {
	    free((char *)elementArray);
	}
    }
    return sortInfo.resultCode;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LeditObjCmd --
 *
 *	This procedure is invoked to process the "ledit" Tcl command. See the
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
Tcl_LeditObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument values. */
{
    Tcl_Obj *listPtr;		/* Pointer to the list being altered. */
    Tcl_Obj *finalValuePtr;	/* Value finally assigned to the variable. */
    int createdNewObj;
    int result;
    Tcl_Size first;
    Tcl_Size last;
    Tcl_Size listLen;
    Tcl_Size numToDelete;

    if (objc < 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"listVar first last ?element ...?");
	return TCL_ERROR;
    }

    listPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (listPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * TODO - refactor the index extraction into a common function shared
     * by Tcl_{Lrange,Lreplace,Ledit}ObjCmd
     */

    result = TclListObjLength(interp, listPtr, &listLen);
    if (result != TCL_OK) {
	return result;
    }

    result = TclGetIntForIndexM(interp, objv[2], /*end*/ listLen-1, &first);
    if (result != TCL_OK) {
	return result;
    }

    result = TclGetIntForIndexM(interp, objv[3], /*end*/ listLen-1, &last);
    if (result != TCL_OK) {
	return result;
    }

    if (first < 0) {
	first = 0;
    } else if (first > listLen) {
	first = listLen;
    }

    if (last >= listLen) {
	last = listLen - 1;
    }
    if (first <= last) {
	numToDelete = (size_t)last - (size_t)first + 1; /* See [3d3124d01d] */
    } else {
	numToDelete = 0;
    }

    if (Tcl_IsShared(listPtr)) {
	listPtr = TclListObjCopy(NULL, listPtr);
	createdNewObj = 1;
    } else {
	createdNewObj = 0;
    }

    result =
	Tcl_ListObjReplace(interp, listPtr, first, numToDelete, objc - 4, objv + 4);
    if (result != TCL_OK) {
	if (createdNewObj) {
	    Tcl_DecrRefCount(listPtr);
	}
	return result;
    }

    /*
     * Tcl_ObjSetVar2 may return a value different from listPtr in the
     * presence of traces etc.
     */
    finalValuePtr =
	Tcl_ObjSetVar2(interp, objv[1], NULL, listPtr, TCL_LEAVE_ERR_MSG);
    if (finalValuePtr == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, finalValuePtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * MergeLists -
 *
 *	This procedure combines two sorted lists of SortElement structures
 *	into a single sorted list.
 *
 * Results:
 *	The unified list of SortElement structures.
 *
 * Side effects:
 *	If infoPtr->unique is set then infoPtr->numElements may be updated.
 *	Possibly others, if a user-defined comparison command does something
 *	weird.
 *
 * Note:
 *	If infoPtr->unique is set, the merge assumes that there are no
 *	"repeated" elements in each of the left and right lists. In that case,
 *	if any element of the left list is equivalent to one in the right list
 *	it is omitted from the merged list.
 *
 *	This simplified mechanism works because of the special way our
 *	MergeSort creates the sublists to be merged and will fail to eliminate
 *	all repeats in the general case where they are already present in
 *	either the left or right list. A general code would need to skip
 *	adjacent initial repeats in the left and right lists before comparing
 *	their initial elements, at each step.
 *
 *----------------------------------------------------------------------
 */

static SortElement *
MergeLists(
    SortElement *leftPtr,	/* First list to be merged; may be NULL. */
    SortElement *rightPtr,	/* Second list to be merged; may be NULL. */
    SortInfo *infoPtr)		/* Information needed by the comparison
				 * operator. */
{
    SortElement *headPtr, *tailPtr;
    int cmp;

    if (leftPtr == NULL) {
	return rightPtr;
    }
    if (rightPtr == NULL) {
	return leftPtr;
    }
    cmp = SortCompare(leftPtr, rightPtr, infoPtr);
    if (cmp > 0 || (cmp == 0 && infoPtr->unique)) {
	if (cmp == 0) {
	    infoPtr->numElements--;
	    leftPtr = leftPtr->nextPtr;
	}
	tailPtr = rightPtr;
	rightPtr = rightPtr->nextPtr;
    } else {
	tailPtr = leftPtr;
	leftPtr = leftPtr->nextPtr;
    }
    headPtr = tailPtr;
    if (!infoPtr->unique) {
	while ((leftPtr != NULL) && (rightPtr != NULL)) {
	    cmp = SortCompare(leftPtr, rightPtr, infoPtr);
	    if (cmp > 0) {
		tailPtr->nextPtr = rightPtr;
		tailPtr = rightPtr;
		rightPtr = rightPtr->nextPtr;
	    } else {
		tailPtr->nextPtr = leftPtr;
		tailPtr = leftPtr;
		leftPtr = leftPtr->nextPtr;
	    }
	}
    } else {
	while ((leftPtr != NULL) && (rightPtr != NULL)) {
	    cmp = SortCompare(leftPtr, rightPtr, infoPtr);
	    if (cmp >= 0) {
		if (cmp == 0) {
		    infoPtr->numElements--;
		    leftPtr = leftPtr->nextPtr;
		}
		tailPtr->nextPtr = rightPtr;
		tailPtr = rightPtr;
		rightPtr = rightPtr->nextPtr;
	    } else {
		tailPtr->nextPtr = leftPtr;
		tailPtr = leftPtr;
		leftPtr = leftPtr->nextPtr;
	    }
	}
    }
    if (leftPtr != NULL) {
	tailPtr->nextPtr = leftPtr;
    } else {
	tailPtr->nextPtr = rightPtr;
    }
    return headPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * SortCompare --
 *
 *	This procedure is invoked by MergeLists to determine the proper
 *	ordering between two elements.
 *
 * Results:
 *	A negative results means the first element comes before the
 *	second, and a positive results means that the second element should
 *	come first. A result of zero means the two elements are equal and it
 *	doesn't matter which comes first.
 *
 * Side effects:
 *	None, unless a user-defined comparison command does something weird.
 *
 *----------------------------------------------------------------------
 */

static int
SortCompare(
    SortElement *elemPtr1, SortElement *elemPtr2,
				/* Values to be compared. */
    SortInfo *infoPtr)		/* Information passed from the top-level
				 * "lsort" command. */
{
    int order = 0;

    if (infoPtr->sortMode == SORTMODE_ASCII) {
	order = TclUtfCmp(elemPtr1->collationKey.strValuePtr,
		elemPtr2->collationKey.strValuePtr);
    } else if (infoPtr->sortMode == SORTMODE_ASCII_NC) {
	order = TclUtfCasecmp(elemPtr1->collationKey.strValuePtr,
		elemPtr2->collationKey.strValuePtr);
    } else if (infoPtr->sortMode == SORTMODE_DICTIONARY) {
	order = DictionaryCompare(elemPtr1->collationKey.strValuePtr,
		elemPtr2->collationKey.strValuePtr);
    } else if (infoPtr->sortMode == SORTMODE_INTEGER) {
	Tcl_WideInt a, b;

	a = elemPtr1->collationKey.wideValue;
	b = elemPtr2->collationKey.wideValue;
	order = ((a >= b) - (a <= b));
    } else if (infoPtr->sortMode == SORTMODE_REAL) {
	double a, b;

	a = elemPtr1->collationKey.doubleValue;
	b = elemPtr2->collationKey.doubleValue;
	order = ((a >= b) - (a <= b));
    } else {
	Tcl_Obj **objv, *paramObjv[2];
	Tcl_Size objc;
	Tcl_Obj *objPtr1, *objPtr2;

	if (infoPtr->resultCode != TCL_OK) {
	    /*
	     * Once an error has occurred, skip any future comparisons so as
	     * to preserve the error message in sortInterp->result.
	     */

	    return 0;
	}

	objPtr1 = elemPtr1->collationKey.objValuePtr;
	objPtr2 = elemPtr2->collationKey.objValuePtr;

	paramObjv[0] = objPtr1;
	paramObjv[1] = objPtr2;

	/*
	 * We made space in the command list for the two things to compare.
	 * Replace them and evaluate the result.
	 */

	TclListObjLength(infoPtr->interp, infoPtr->compareCmdPtr, &objc);
	Tcl_ListObjReplace(infoPtr->interp, infoPtr->compareCmdPtr, objc - 2,
		2, 2, paramObjv);
	TclListObjGetElements(infoPtr->interp, infoPtr->compareCmdPtr,
		&objc, &objv);

	infoPtr->resultCode = Tcl_EvalObjv(infoPtr->interp, objc, objv, 0);

	if (infoPtr->resultCode != TCL_OK) {
	    Tcl_AddErrorInfo(infoPtr->interp, "\n    (-compare command)");
	    return 0;
	}

	/*
	 * Parse the result of the command.
	 */

	if (TclGetIntFromObj(infoPtr->interp,
		Tcl_GetObjResult(infoPtr->interp), &order) != TCL_OK) {
	    Tcl_SetObjResult(infoPtr->interp, Tcl_NewStringObj(
		    "-compare command returned non-integer result", -1));
	    Tcl_SetErrorCode(infoPtr->interp, "TCL", "OPERATION", "LSORT",
		    "COMPARISONFAILED", (char *)NULL);
	    infoPtr->resultCode = TCL_ERROR;
	    return 0;
	}
    }
    if (!infoPtr->isIncreasing) {
	order = -order;
    }
    return order;
}

/*
 *----------------------------------------------------------------------
 *
 * DictionaryCompare
 *
 *	This function compares two strings as if they were being used in an
 *	index or card catalog. The case of alphabetic characters is ignored,
 *	except to break ties. Thus "B" comes before "b" but after "a". Also,
 *	integers embedded in the strings compare in numerical order. In other
 *	words, "x10y" comes after "x9y", not * before it as it would when
 *	using strcmp().
 *
 * Results:
 *	A negative result means that the first element comes before the
 *	second, and a positive result means that the second element should
 *	come first. A result of zero means the two elements are equal and it
 *	doesn't matter which comes first.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
DictionaryCompare(
    const char *left, const char *right)	/* The strings to compare. */
{
    int uniLeft = 0, uniRight = 0, uniLeftLower, uniRightLower;
    int diff, zeros;
    int secondaryDiff = 0;

    while (1) {
		if (isdigit(UCHAR(*right))		/* INTL: digit */
		&& isdigit(UCHAR(*left))) {	/* INTL: digit */
	    /*
	     * There are decimal numbers embedded in the two strings. Compare
	     * them as numbers, rather than strings. If one number has more
	     * leading zeros than the other, the number with more leading
	     * zeros sorts later, but only as a secondary choice.
	     */

	    zeros = 0;
	    while ((*right == '0') && isdigit(UCHAR(right[1]))) {
		right++;
		zeros--;
	    }
	    while ((*left == '0') && isdigit(UCHAR(left[1]))) {
		left++;
		zeros++;
	    }
	    if (secondaryDiff == 0) {
		secondaryDiff = zeros;
	    }

	    /*
	     * The code below compares the numbers in the two strings without
	     * ever converting them to integers. It does this by first
	     * comparing the lengths of the numbers and then comparing the
	     * digit values.
	     */

	    diff = 0;
	    while (1) {
		if (diff == 0) {
		    diff = UCHAR(*left) - UCHAR(*right);
		}
		right++;
		left++;
		if (!isdigit(UCHAR(*right))) {		/* INTL: digit */
		    if (isdigit(UCHAR(*left))) {	/* INTL: digit */
			return 1;
		    } else {
			/*
			 * The two numbers have the same length. See if their
			 * values are different.
			 */

			if (diff != 0) {
			    return diff;
			}
			break;
		    }
		} else if (!isdigit(UCHAR(*left))) {	/* INTL: digit */
		    return -1;
		}
	    }
	    continue;
	}

	/*
	 * Convert character to Unicode for comparison purposes. If either
	 * string is at the terminating null, do a byte-wise comparison and
	 * bail out immediately.
	 */

	if ((*left != '\0') && (*right != '\0')) {
	    left += TclUtfToUniChar(left, &uniLeft);
	    right += TclUtfToUniChar(right, &uniRight);

	    /*
	     * Convert both chars to lower for the comparison, because
	     * dictionary sorts are case-insensitive. Covert to lower, not
	     * upper, so chars between Z and a will sort before A (where most
	     * other interesting punctuations occur).
	     */

	    uniLeftLower = Tcl_UniCharToLower(uniLeft);
	    uniRightLower = Tcl_UniCharToLower(uniRight);
	} else {
	    diff = UCHAR(*left) - UCHAR(*right);
	    break;
	}

	diff = uniLeftLower - uniRightLower;
	if (diff) {
	    return diff;
	}
	if (secondaryDiff == 0) {
	    if (Tcl_UniCharIsUpper(uniLeft) && Tcl_UniCharIsLower(uniRight)) {
		secondaryDiff = -1;
	    } else if (Tcl_UniCharIsUpper(uniRight)
		    && Tcl_UniCharIsLower(uniLeft)) {
		secondaryDiff = 1;
	    }
	}
    }
    if (diff == 0) {
	diff = secondaryDiff;
    }
    return diff;
}

/*
 *----------------------------------------------------------------------
 *
 * SelectObjFromSublist --
 *
 *	This procedure is invoked from lsearch and SortCompare. It is used for
 *	implementing the -index option, for the lsort and lsearch commands.
 *
 * Results:
 *	Returns NULL if a failure occurs, and sets the result in the infoPtr.
 *	Otherwise returns the Tcl_Obj* to the item.
 *
 * Side effects:
 *	None.
 *
 * Note:
 *	No reference counting is done, as the result is only used internally
 *	and never passed directly to user code.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
SelectObjFromSublist(
    Tcl_Obj *objPtr,		/* Obj to select sublist from. */
    SortInfo *infoPtr)		/* Information passed from the top-level
				 * "lsearch" or "lsort" command. */
{
    Tcl_Size i;

    /*
     * Quick check for case when no "-index" option is there.
     */

    if (infoPtr->indexc == 0) {
	return objPtr;
    }

    /*
     * Iterate over the indices, traversing through the nested sublists as we
     * go.
     */

    for (i=0 ; i<infoPtr->indexc ; i++) {
	Tcl_Size listLen;
	int index;
	Tcl_Obj *currentObj, *lastObj=NULL;

	if (TclListObjLength(infoPtr->interp, objPtr, &listLen) != TCL_OK) {
	    infoPtr->resultCode = TCL_ERROR;
	    return NULL;
	}

	index = TclIndexDecode(infoPtr->indexv[i], listLen - 1);

	if (Tcl_ListObjIndex(infoPtr->interp, objPtr, index,
		&currentObj) != TCL_OK) {
	    infoPtr->resultCode = TCL_ERROR;
	    return NULL;
	}
	if (currentObj == NULL) {
	    if (index == TCL_INDEX_NONE) {
		index = TCL_INDEX_END - infoPtr->indexv[i];
		Tcl_SetObjResult(infoPtr->interp, Tcl_ObjPrintf(
			"element end-%d missing from sublist \"%s\"",
			index, TclGetString(objPtr)));
	    } else {
		Tcl_SetObjResult(infoPtr->interp, Tcl_ObjPrintf(
			"element %d missing from sublist \"%s\"",
			index, TclGetString(objPtr)));
	    }
	    Tcl_SetErrorCode(infoPtr->interp, "TCL", "OPERATION", "LSORT",
		    "INDEXFAILED", (char *)NULL);
	    infoPtr->resultCode = TCL_ERROR;
	    return NULL;
	}
	objPtr = currentObj;
	Tcl_BounceRefCount(lastObj);
	lastObj = currentObj;
    }
    return objPtr;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * End:
 */

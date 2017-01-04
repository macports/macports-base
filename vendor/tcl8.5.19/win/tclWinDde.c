/*
 * tclWinDde.c --
 *
 *	This file provides functions that implement the "send" command,
 *	allowing commands to be passed from interpreter to interpreter.
 *
 * Copyright (c) 1997 by Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclPort.h"
#include <dde.h>
#include <ddeml.h>

/*
 * TCL_STORAGE_CLASS is set unconditionally to DLLEXPORT because the Dde_Init
 * declaration is in the source file itself, which is only accessed when we
 * are building a library. DO NOT MOVE BEFORE ANY #include LINES. ONLY USE
 * EXTERN TO INDICATE EXPORTED FUNCTIONS FROM NOW ON.
 */

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT

/*
 * The following structure is used to keep track of the interpreters
 * registered by this process.
 */

typedef struct RegisteredInterp {
    struct RegisteredInterp *nextPtr;
				/* The next interp this application knows
				 * about. */
    char *name;			/* Interpreter's name (malloc-ed). */
    Tcl_Obj *handlerPtr;	/* The server handler command */
    Tcl_Interp *interp;		/* The interpreter attached to this name. */
} RegisteredInterp;

/*
 * Used to keep track of conversations.
 */

typedef struct Conversation {
    struct Conversation *nextPtr;
				/* The next conversation in the list. */
    RegisteredInterp *riPtr;	/* The info we know about the conversation. */
    HCONV hConv;		/* The DDE handle for this conversation. */
    Tcl_Obj *returnPackagePtr;	/* The result package for this conversation. */
} Conversation;

typedef struct DdeEnumServices {
    Tcl_Interp *interp;
    int result;
    ATOM service;
    ATOM topic;
    HWND hwnd;
} DdeEnumServices;

typedef struct ThreadSpecificData {
    Conversation *currentConversations;
				/* A list of conversations currently being
				 * processed. */
    RegisteredInterp *interpListPtr;
				/* List of all interpreters registered in the
				 * current process. */
} ThreadSpecificData;
static Tcl_ThreadDataKey dataKey;

/*
 * The following variables cannot be placed in thread-local storage. The Mutex
 * ddeMutex guards access to the ddeInstance.
 */

static HSZ ddeServiceGlobal = 0;
static DWORD ddeInstance;	/* The application instance handle given to us
				 * by DdeInitialize. */
static int ddeIsServer = 0;

#define TCL_DDE_PACKAGE_NAME	"dde"
#define TCL_DDE_SERVICE_NAME	"TclEval"
#define TCL_DDE_EXECUTE_RESULT	"$TCLEVAL$EXECUTE$RESULT"

#define DDE_FLAG_ASYNC 1
#define DDE_FLAG_BINARY 2
#define DDE_FLAG_FORCE 4

TCL_DECLARE_MUTEX(ddeMutex)

/*
 * Forward declarations for functions defined later in this file.
 */

static LRESULT CALLBACK	DdeClientWindowProc(HWND hwnd, UINT uMsg,
			    WPARAM wParam, LPARAM lParam);
static int		DdeCreateClient(struct DdeEnumServices *es);
static BOOL CALLBACK	DdeEnumWindowsCallback(HWND hwndTarget,
			    LPARAM lParam);
static void		DdeExitProc(ClientData clientData);
static int		DdeGetServicesList(Tcl_Interp *interp,
			    const char *serviceName, const char *topicName);
static HDDEDATA CALLBACK DdeServerProc(UINT uType, UINT uFmt, HCONV hConv,
			    HSZ ddeTopic, HSZ ddeItem, HDDEDATA hData,
			    DWORD dwData1, DWORD dwData2);
static LRESULT		DdeServicesOnAck(HWND hwnd, WPARAM wParam,
			    LPARAM lParam);
static void		DeleteProc(ClientData clientData);
static Tcl_Obj *	ExecuteRemoteObject(RegisteredInterp *riPtr,
			    Tcl_Obj *ddeObjectPtr);
static int		MakeDdeConnection(Tcl_Interp *interp,
			    const char *name, HCONV *ddeConvPtr);
static void		SetDdeError(Tcl_Interp *interp);
static int		DdeObjCmd(ClientData clientData,
			    Tcl_Interp *interp, int objc,
			    Tcl_Obj *const objv[]);

EXTERN int		Dde_Init(Tcl_Interp *interp);
EXTERN int		Dde_SafeInit(Tcl_Interp *interp);

/*
 *----------------------------------------------------------------------
 *
 * Dde_Init --
 *
 *	This function initializes the dde command.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Dde_Init(
    Tcl_Interp *interp)
{
    if (!Tcl_InitStubs(interp, "8.1", 0)) {
	return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "dde", DdeObjCmd, NULL, NULL);
    Tcl_CreateExitHandler(DdeExitProc, NULL);
    return Tcl_PkgProvide(interp, TCL_DDE_PACKAGE_NAME, "1.3.3");
}

/*
 *----------------------------------------------------------------------
 *
 * Dde_SafeInit --
 *
 *	This function initializes the dde command within a safe interp
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Dde_SafeInit(
    Tcl_Interp *interp)
{
    int result = Dde_Init(interp);
    if (result == TCL_OK) {
	Tcl_HideCommand(interp, "dde", "dde");
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Initialize --
 *
 *	Initialize the global DDE instance.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Registers the DDE server proc.
 *
 *----------------------------------------------------------------------
 */

static void
Initialize(void)
{
    int nameFound = 0;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * See if the application is already registered; if so, remove its current
     * name from the registry. The deletion of the command will take care of
     * disposing of this entry.
     */

    if (tsdPtr->interpListPtr != NULL) {
	nameFound = 1;
    }

    /*
     * Make sure that the DDE server is there. This is done only once, add an
     * exit handler tear it down.
     */

    if (ddeInstance == 0) {
	Tcl_MutexLock(&ddeMutex);
	if (ddeInstance == 0) {
	    if (DdeInitialize(&ddeInstance, (PFNCALLBACK) DdeServerProc,
		    CBF_SKIP_REGISTRATIONS | CBF_SKIP_UNREGISTRATIONS
		    | CBF_FAIL_POKES, 0) != DMLERR_NO_ERROR) {
		ddeInstance = 0;
	    }
	}
	Tcl_MutexUnlock(&ddeMutex);
    }
    if ((ddeServiceGlobal == 0) && (nameFound != 0)) {
	Tcl_MutexLock(&ddeMutex);
	if ((ddeServiceGlobal == 0) && (nameFound != 0)) {
	    ddeIsServer = 1;
	    Tcl_CreateExitHandler(DdeExitProc, NULL);
	    ddeServiceGlobal = DdeCreateStringHandle(ddeInstance,
		    TCL_DDE_SERVICE_NAME, 0);
	    DdeNameService(ddeInstance, ddeServiceGlobal, 0L, DNS_REGISTER);
	} else {
	    ddeIsServer = 0;
	}
	Tcl_MutexUnlock(&ddeMutex);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * DdeSetServerName --
 *
 *	This function is called to associate an ASCII name with a Dde server.
 *	If the interpreter has already been named, the name replaces the old
 *	one.
 *
 * Results:
 *	The return value is the name actually given to the interp. This will
 *	normally be the same as name, but if name was already in use for a Dde
 *	Server then a name of the form "name #2" will be chosen, with a high
 *	enough number to make the name unique.
 *
 * Side effects:
 *	Registration info is saved, thereby allowing the "send" command to be
 *	used later to invoke commands in the application. In addition, the
 *	"send" command is created in the application's interpreter. The
 *	registration will be removed automatically if the interpreter is
 *	deleted or the "send" command is removed.
 *
 *----------------------------------------------------------------------
 */

static const char *
DdeSetServerName(
    Tcl_Interp *interp,
    const char *name, /* The name that will be used to refer to the
				 * interpreter in later "send" commands. Must
				 * be globally unique. */
    int flags,		/* DDE_FLAG_FORCE or 0 */
    Tcl_Obj *handlerPtr)	/* Name of the optional proc/command to handle
				 * incoming Dde eval's */
{
    int suffix, offset;
    RegisteredInterp *riPtr, *prevPtr;
    Tcl_DString dString;
    const char *actualName;
    Tcl_Obj *srvListPtr = NULL, **srvPtrPtr = NULL;
    int n, srvCount = 0, lastSuffix, r = TCL_OK;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * See if the application is already registered; if so, remove its current
     * name from the registry. The deletion of the command will take care of
     * disposing of this entry.
     */

    for (riPtr = tsdPtr->interpListPtr, prevPtr = NULL; riPtr != NULL;
	    prevPtr = riPtr, riPtr = riPtr->nextPtr) {
	if (riPtr->interp == interp) {
	    if (name != NULL) {
		if (prevPtr == NULL) {
		    tsdPtr->interpListPtr = tsdPtr->interpListPtr->nextPtr;
		} else {
		    prevPtr->nextPtr = riPtr->nextPtr;
		}
		break;
	    } else {
		/*
		 * The name was NULL, so the caller is asking for the name of
		 * the current interp.
		 */

		return riPtr->name;
	    }
	}
    }

    if (name == NULL) {
	/*
	 * The name was NULL, so the caller is asking for the name of the
	 * current interp, but it doesn't have a name.
	 */

	return "";
    }

    /*
     * Get the list of currently registered Tcl interpreters by calling the
     * internal implementation of the 'dde services' command.
     */

    Tcl_DStringInit(&dString);
    actualName = name;

    if (!(flags & DDE_FLAG_FORCE)) {
	r = DdeGetServicesList(interp, TCL_DDE_SERVICE_NAME, NULL);
	if (r == TCL_OK) {
	    srvListPtr = Tcl_GetObjResult(interp);
	}
	if (r == TCL_OK) {
	    r = Tcl_ListObjGetElements(interp, srvListPtr, &srvCount,
		    &srvPtrPtr);
	}
	if (r != TCL_OK) {
	    OutputDebugString(Tcl_GetStringResult(interp));
	    return NULL;
	}

	/*
	 * Pick a name to use for the application. Use "name" if it's not
	 * already in use. Otherwise add a suffix such as " #2", trying larger
	 * and larger numbers until we eventually find one that is unique.
	 */

	offset = lastSuffix = 0;
	suffix = 1;

	while (suffix != lastSuffix) {
	    lastSuffix = suffix;
	    if (suffix > 1) {
		if (suffix == 2) {
		    Tcl_DStringAppend(&dString, name, -1);
		    Tcl_DStringAppend(&dString, " #", 2);
		    offset = Tcl_DStringLength(&dString);
		    Tcl_DStringSetLength(&dString, offset + TCL_INTEGER_SPACE);
		    actualName = Tcl_DStringValue(&dString);
		}
		sprintf(Tcl_DStringValue(&dString) + offset, "%d", suffix);
	    }

	    /*
	     * See if the name is already in use, if so increment suffix.
	     */

	    for (n = 0; n < srvCount; ++n) {
		Tcl_Obj* namePtr;

		Tcl_ListObjIndex(interp, srvPtrPtr[n], 1, &namePtr);
		if (strcmp(actualName, Tcl_GetString(namePtr)) == 0) {
		    suffix++;
		    break;
		}
	    }
	}
	Tcl_DStringSetLength(&dString,
		offset + (int)strlen(Tcl_DStringValue(&dString)+offset));
    }

    /*
     * We have found a unique name. Now add it to the registry.
     */

    riPtr = (RegisteredInterp *) ckalloc(sizeof(RegisteredInterp));
    riPtr->interp = interp;
    riPtr->name = ckalloc((unsigned int) strlen(actualName) + 1);
    riPtr->nextPtr = tsdPtr->interpListPtr;
    riPtr->handlerPtr = handlerPtr;
    if (riPtr->handlerPtr != NULL) {
	Tcl_IncrRefCount(riPtr->handlerPtr);
    }
    tsdPtr->interpListPtr = riPtr;
    strcpy(riPtr->name, actualName);

    if (Tcl_IsSafe(interp)) {
	Tcl_ExposeCommand(interp, "dde", "dde");
    }

    Tcl_CreateObjCommand(interp, "dde", DdeObjCmd,
	    (ClientData) riPtr, DeleteProc);
    if (Tcl_IsSafe(interp)) {
	Tcl_HideCommand(interp, "dde", "dde");
    }
    Tcl_DStringFree(&dString);

    /*
     * Re-initialize with the new name.
     */

    Initialize();

    return riPtr->name;
}

/*
 *----------------------------------------------------------------------
 *
 * DdeGetRegistrationPtr
 *
 *	Retrieve the registration info for an interpreter.
 *
 * Results:
 *	Returns a pointer to the registration structure or NULL
 *
 * Side effects:
 *	None
 *
 *----------------------------------------------------------------------
 */

static RegisteredInterp *
DdeGetRegistrationPtr(
    Tcl_Interp *interp)
{
    RegisteredInterp *riPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    for (riPtr = tsdPtr->interpListPtr; riPtr != NULL;
	    riPtr = riPtr->nextPtr) {
	if (riPtr->interp == interp) {
	    break;
	}
    }
    return riPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * DeleteProc
 *
 *	This function is called when the command "dde" is destroyed.
 *
 * Results:
 *	none
 *
 * Side effects:
 *	The interpreter given by riPtr is unregistered.
 *
 *----------------------------------------------------------------------
 */

static void
DeleteProc(
    ClientData clientData)	/* The interp we are deleting passed as
				 * ClientData. */
{
    RegisteredInterp *riPtr = (RegisteredInterp *) clientData;
    RegisteredInterp *searchPtr, *prevPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    for (searchPtr = tsdPtr->interpListPtr, prevPtr = NULL;
	    (searchPtr != NULL) && (searchPtr != riPtr);
	    prevPtr = searchPtr, searchPtr = searchPtr->nextPtr) {
	/*
	 * Empty loop body.
	 */
    }

    if (searchPtr != NULL) {
	if (prevPtr == NULL) {
	    tsdPtr->interpListPtr = tsdPtr->interpListPtr->nextPtr;
	} else {
	    prevPtr->nextPtr = searchPtr->nextPtr;
	}
    }
    ckfree(riPtr->name);
    if (riPtr->handlerPtr) {
	Tcl_DecrRefCount(riPtr->handlerPtr);
    }
    Tcl_EventuallyFree(clientData, TCL_DYNAMIC);
}

/*
 *----------------------------------------------------------------------
 *
 * ExecuteRemoteObject --
 *
 *	Takes the package delivered by DDE and executes it in the server's
 *	interpreter.
 *
 * Results:
 *	A list Tcl_Obj * that describes what happened. The first element is
 *	the numerical return code (TCL_ERROR, etc.). The second element is the
 *	result of the script. If the return result was TCL_ERROR, then the
 *	third element will be the value of the global "errorCode", and the
 *	fourth will be the value of the global "errorInfo". The return result
 *	will have a refCount of 0.
 *
 * Side effects:
 *	A Tcl script is run, which can cause all kinds of other things to
 *	happen.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
ExecuteRemoteObject(
    RegisteredInterp *riPtr,	    /* Info about this server. */
    Tcl_Obj *ddeObjectPtr)	    /* The object to execute. */
{
    Tcl_Obj *returnPackagePtr;
    int result = TCL_OK;

    if (riPtr->handlerPtr == NULL && Tcl_IsSafe(riPtr->interp)) {
	Tcl_SetObjResult(riPtr->interp, Tcl_NewStringObj("permission denied: "
		"a handler procedure must be defined for use in a safe "
		"interp", -1));
	result = TCL_ERROR;
    }

    if (riPtr->handlerPtr != NULL) {
	/*
	 * Add the dde request data to the handler proc list.
	 */

	Tcl_Obj *cmdPtr = Tcl_DuplicateObj(riPtr->handlerPtr);

	result = Tcl_ListObjAppendElement(riPtr->interp, cmdPtr,
		ddeObjectPtr);
	if (result == TCL_OK) {
	    ddeObjectPtr = cmdPtr;
	}
    }

    if (result == TCL_OK) {
	result = Tcl_EvalObjEx(riPtr->interp, ddeObjectPtr, TCL_EVAL_GLOBAL);
    }

    returnPackagePtr = Tcl_NewListObj(0, NULL);

    Tcl_ListObjAppendElement(NULL, returnPackagePtr,
	    Tcl_NewIntObj(result));
    Tcl_ListObjAppendElement(NULL, returnPackagePtr,
	    Tcl_GetObjResult(riPtr->interp));

    if (result == TCL_ERROR) {
	Tcl_Obj *errorObjPtr = Tcl_GetVar2Ex(riPtr->interp, "errorCode", NULL,
		TCL_GLOBAL_ONLY);
	if (errorObjPtr) {
	    Tcl_ListObjAppendElement(NULL, returnPackagePtr, errorObjPtr);
	}
	errorObjPtr = Tcl_GetVar2Ex(riPtr->interp, "errorInfo", NULL,
		TCL_GLOBAL_ONLY);
	if (errorObjPtr) {
	    Tcl_ListObjAppendElement(NULL, returnPackagePtr, errorObjPtr);
	}
    }

    return returnPackagePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * DdeServerProc --
 *
 *	Handles all transactions for this server. Can handle execute, request,
 *	and connect protocols. Dde will call this routine when a client
 *	attempts to run a dde command using this server.
 *
 * Results:
 *	A DDE Handle with the result of the dde command.
 *
 * Side effects:
 *	Depending on which command is executed, arbitrary Tcl scripts can be
 *	run.
 *
 *----------------------------------------------------------------------
 */

static HDDEDATA CALLBACK
DdeServerProc(
    UINT uType,			/* The type of DDE transaction we are
				 * performing. */
    UINT uFmt,			/* The format that data is sent or received */
    HCONV hConv,		/* The conversation associated with the
				 * current transaction. */
    HSZ ddeTopic, HSZ ddeItem,	/* String handles. Transaction-type
				 * dependent. */
    HDDEDATA hData,		/* DDE data. Transaction-type dependent. */
    DWORD dwData1, DWORD dwData2)
				/* Transaction-dependent data. */
{
    Tcl_DString dString;
    int len;
    DWORD dlen;
    char *utilString;
    Tcl_Obj *ddeObjectPtr;
    HDDEDATA ddeReturn = NULL;
    RegisteredInterp *riPtr;
    Conversation *convPtr, *prevConvPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    switch(uType) {
    case XTYP_CONNECT:
	/*
	 * Dde is trying to initialize a conversation with us. Check and make
	 * sure we have a valid topic.
	 */

	len = DdeQueryString(ddeInstance, ddeTopic, NULL, 0, 0);
	Tcl_DStringInit(&dString);
	Tcl_DStringSetLength(&dString, len);
	utilString = Tcl_DStringValue(&dString);
	DdeQueryString(ddeInstance, ddeTopic, utilString, (DWORD) len + 1,
		CP_WINANSI);

	for (riPtr = tsdPtr->interpListPtr; riPtr != NULL;
		riPtr = riPtr->nextPtr) {
	    if (stricmp(utilString, riPtr->name) == 0) {
		Tcl_DStringFree(&dString);
		return (HDDEDATA) TRUE;
	    }
	}

	Tcl_DStringFree(&dString);
	return (HDDEDATA) FALSE;

    case XTYP_CONNECT_CONFIRM:
	/*
	 * Dde has decided that we can connect, so it gives us a conversation
	 * handle. We need to keep track of it so we know which execution
	 * result to return in an XTYP_REQUEST.
	 */

	len = DdeQueryString(ddeInstance, ddeTopic, NULL, 0, 0);
	Tcl_DStringInit(&dString);
	Tcl_DStringSetLength(&dString, len);
	utilString = Tcl_DStringValue(&dString);
	DdeQueryString(ddeInstance, ddeTopic, utilString, (DWORD) len + 1,
		CP_WINANSI);
	for (riPtr = tsdPtr->interpListPtr; riPtr != NULL;
		riPtr = riPtr->nextPtr) {
	    if (stricmp(riPtr->name, utilString) == 0) {
		convPtr = (Conversation *) ckalloc(sizeof(Conversation));
		convPtr->nextPtr = tsdPtr->currentConversations;
		convPtr->returnPackagePtr = NULL;
		convPtr->hConv = hConv;
		convPtr->riPtr = riPtr;
		tsdPtr->currentConversations = convPtr;
		break;
	    }
	}
	Tcl_DStringFree(&dString);
	return (HDDEDATA) TRUE;

    case XTYP_DISCONNECT:
	/*
	 * The client has disconnected from our server. Forget this
	 * conversation.
	 */

	for (convPtr = tsdPtr->currentConversations, prevConvPtr = NULL;
		convPtr != NULL;
		prevConvPtr = convPtr, convPtr = convPtr->nextPtr) {
	    if (hConv == convPtr->hConv) {
		if (prevConvPtr == NULL) {
		    tsdPtr->currentConversations = convPtr->nextPtr;
		} else {
		    prevConvPtr->nextPtr = convPtr->nextPtr;
		}
		if (convPtr->returnPackagePtr != NULL) {
		    Tcl_DecrRefCount(convPtr->returnPackagePtr);
		}
		ckfree((char *) convPtr);
		break;
	    }
	}
	return (HDDEDATA) TRUE;

    case XTYP_REQUEST:
	/*
	 * This could be either a request for a value of a Tcl variable, or it
	 * could be the send command requesting the results of the last
	 * execute.
	 */

	if ((uFmt != CF_TEXT) && (uFmt != CF_UNICODETEXT)) {
	    return (HDDEDATA) FALSE;
	}

	ddeReturn = (HDDEDATA) FALSE;
	for (convPtr = tsdPtr->currentConversations; (convPtr != NULL)
		&& (convPtr->hConv != hConv); convPtr = convPtr->nextPtr) {
	    /*
	     * Empty loop body.
	     */
	}

	if (convPtr != NULL) {
	    char *returnString;

	    len = DdeQueryString(ddeInstance, ddeItem, NULL, 0, CP_WINANSI);
	    Tcl_DStringInit(&dString);
	    Tcl_DStringSetLength(&dString, len);
	    utilString = Tcl_DStringValue(&dString);
	    DdeQueryString(ddeInstance, ddeItem, utilString, (DWORD) len + 1,
		    CP_WINANSI);
	    if (stricmp(utilString, TCL_DDE_EXECUTE_RESULT) == 0) {
		if (uFmt == CF_TEXT) {
		    returnString =
			    Tcl_GetStringFromObj(convPtr->returnPackagePtr, &len);
		} else {
		    returnString = (char *)
			    Tcl_GetUnicodeFromObj(convPtr->returnPackagePtr, &len);
		    len = 2 * len + 1;
		}
		ddeReturn = DdeCreateDataHandle(ddeInstance, (BYTE *)returnString,
			(DWORD) len+1, 0, ddeItem, uFmt, 0);
	    } else {
		if (Tcl_IsSafe(convPtr->riPtr->interp)) {
		    ddeReturn = NULL;
		} else {
		    Tcl_Obj *variableObjPtr = Tcl_GetVar2Ex(
			    convPtr->riPtr->interp, utilString, NULL,
			    TCL_GLOBAL_ONLY);
		    if (variableObjPtr != NULL) {
			if (uFmt == CF_TEXT) {
			    returnString = Tcl_GetStringFromObj(
				    variableObjPtr, &len);
			} else {
			    returnString = (char *) Tcl_GetUnicodeFromObj(
				    variableObjPtr, &len);
			    len = 2 * len + 1;
			}
			ddeReturn = DdeCreateDataHandle(ddeInstance,
				(BYTE *)returnString, (DWORD) len+1, 0, ddeItem,
				uFmt, 0);
		    } else {
			ddeReturn = NULL;
		    }
		}
	    }
	    Tcl_DStringFree(&dString);
	}
	return ddeReturn;

    case XTYP_EXECUTE: {
	/*
	 * Execute this script. The results will be saved into a list object
	 * which will be retreived later. See ExecuteRemoteObject.
	 */

	Tcl_Obj *returnPackagePtr;
	Tcl_UniChar *uniStr;

	for (convPtr = tsdPtr->currentConversations; (convPtr != NULL)
		&& (convPtr->hConv != hConv); convPtr = convPtr->nextPtr) {
	    /*
	     * Empty loop body.
	     */
	}

	if (convPtr == NULL) {
	    return (HDDEDATA) DDE_FNOTPROCESSED;
	}

	utilString = (char *) DdeAccessData(hData, &dlen);
	uniStr = (Tcl_UniChar *) utilString;
	if (!dlen) {
	    /* Empty binary array. */
	    ddeObjectPtr = Tcl_NewObj();
	} else if ((dlen & 1) || uniStr[(dlen>>1)-1]) {
	    /* Cannot be unicode, so assume utf-8 */
	    if (!utilString[dlen-1]) {
		dlen--;
	    }
	    ddeObjectPtr = Tcl_NewStringObj(utilString, dlen);
	} else {
	    /* unicode */
	    dlen >>= 1;
	    ddeObjectPtr = Tcl_NewUnicodeObj(uniStr, dlen - 1);
	}
	Tcl_IncrRefCount(ddeObjectPtr);
	DdeUnaccessData(hData);
	if (convPtr->returnPackagePtr != NULL) {
	    Tcl_DecrRefCount(convPtr->returnPackagePtr);
	}
	convPtr->returnPackagePtr = NULL;
	returnPackagePtr = ExecuteRemoteObject(convPtr->riPtr, ddeObjectPtr);
	Tcl_IncrRefCount(returnPackagePtr);
	for (convPtr = tsdPtr->currentConversations; (convPtr != NULL)
		&& (convPtr->hConv != hConv); convPtr = convPtr->nextPtr) {
	    /*
	     * Empty loop body.
	     */
	}
	if (convPtr != NULL) {
	    convPtr->returnPackagePtr = returnPackagePtr;
	} else {
	    Tcl_DecrRefCount(returnPackagePtr);
	}
	Tcl_DecrRefCount(ddeObjectPtr);
	if (returnPackagePtr == NULL) {
	    return (HDDEDATA) DDE_FNOTPROCESSED;
	} else {
	    return (HDDEDATA) DDE_FACK;
	}
    }

    case XTYP_WILDCONNECT: {
	/*
	 * Dde wants a list of services and topics that we support.
	 */

	HSZPAIR *returnPtr;
	int i;
	int numItems;

	for (i = 0, riPtr = tsdPtr->interpListPtr; riPtr != NULL;
		i++, riPtr = riPtr->nextPtr) {
	    /*
	     * Empty loop body.
	     */
	}

	numItems = i;
	ddeReturn = DdeCreateDataHandle(ddeInstance, NULL,
		(numItems + 1) * sizeof(HSZPAIR), 0, 0, 0, 0);
	returnPtr = (HSZPAIR *) DdeAccessData(ddeReturn, &dlen);
	len = dlen;
	for (i = 0, riPtr = tsdPtr->interpListPtr; i < numItems;
		i++, riPtr = riPtr->nextPtr) {
	    returnPtr[i].hszSvc = DdeCreateStringHandle(ddeInstance,
		    TCL_DDE_SERVICE_NAME, CP_WINANSI);
	    returnPtr[i].hszTopic = DdeCreateStringHandle(ddeInstance,
		    riPtr->name, CP_WINANSI);
	}
	returnPtr[i].hszSvc = NULL;
	returnPtr[i].hszTopic = NULL;
	DdeUnaccessData(ddeReturn);
	return ddeReturn;
    }

    default:
	return NULL;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * DdeExitProc --
 *
 *	Gets rid of our DDE server when we go away.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The DDE server is deleted.
 *
 *----------------------------------------------------------------------
 */

static void
DdeExitProc(
    ClientData clientData)	    /* Not used in this handler. */
{
    DdeNameService(ddeInstance, NULL, 0, DNS_UNREGISTER);
    DdeUninitialize(ddeInstance);
    ddeInstance = 0;
}

/*
 *----------------------------------------------------------------------
 *
 * MakeDdeConnection --
 *
 *	This function is a utility used to connect to a DDE server when given
 *	a server name and a topic name.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Passes back a conversation through ddeConvPtr
 *
 *----------------------------------------------------------------------
 */

static int
MakeDdeConnection(
    Tcl_Interp *interp,		/* Used to report errors. */
    const char *name,		/* The connection to use. */
    HCONV *ddeConvPtr)
{
    HSZ ddeTopic, ddeService;
    HCONV ddeConv;

    ddeService = DdeCreateStringHandle(ddeInstance, TCL_DDE_SERVICE_NAME, 0);
    ddeTopic = DdeCreateStringHandle(ddeInstance, name, 0);

    ddeConv = DdeConnect(ddeInstance, ddeService, ddeTopic, NULL);
    DdeFreeStringHandle(ddeInstance, ddeService);
    DdeFreeStringHandle(ddeInstance, ddeTopic);

    if (ddeConv == (HCONV) NULL) {
	if (interp != NULL) {
	    Tcl_AppendResult(interp, "no registered server named \"",
		    name, "\"", NULL);
	}
	return TCL_ERROR;
    }

    *ddeConvPtr = ddeConv;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DdeGetServicesList --
 *
 *	This function obtains the list of DDE services.
 *
 *	The functions between here and this function are all involved with
 *	handling the DDE callbacks for this. They are: DdeCreateClient,
 *	DdeClientWindowProc, DdeServicesOnAck, and DdeEnumWindowsCallback
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Sets the services list into the interp result.
 *
 *----------------------------------------------------------------------
 */

static int
DdeCreateClient(
    struct DdeEnumServices *es)
{
    WNDCLASSEX wc;
    static const char *szDdeClientClassName = "TclEval client class";
    static const char *szDdeClientWindowName = "TclEval client window";

    memset(&wc, 0, sizeof(wc));
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = DdeClientWindowProc;
    wc.lpszClassName = szDdeClientClassName;
    wc.cbWndExtra = sizeof(struct DdeEnumServices *);

    /*
     * Register and create the callback window.
     */

    RegisterClassEx(&wc);
    es->hwnd = CreateWindowEx(0, szDdeClientClassName, szDdeClientWindowName,
	    WS_POPUP, 0, 0, 0, 0, NULL, NULL, NULL, (LPVOID)es);
    return TCL_OK;
}

static LRESULT CALLBACK
DdeClientWindowProc(
    HWND hwnd,			/* What window is the message for */
    UINT uMsg,			/* The type of message received */
    WPARAM wParam,
    LPARAM lParam)		/* (Potentially) our local handle */
{
    switch (uMsg) {
    case WM_CREATE: {
	LPCREATESTRUCT lpcs = (LPCREATESTRUCT) lParam;
	struct DdeEnumServices *es =
		(struct DdeEnumServices *) lpcs->lpCreateParams;

#ifdef _WIN64
	SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR) es);
#else
	SetWindowLong(hwnd, GWL_USERDATA, (LONG) es);
#endif
	return (LRESULT) 0L;
    }
    case WM_DDE_ACK:
	return DdeServicesOnAck(hwnd, wParam, lParam);
    default:
	return DefWindowProc(hwnd, uMsg, wParam, lParam);
    }
}

static LRESULT
DdeServicesOnAck(
    HWND hwnd,
    WPARAM wParam,
    LPARAM lParam)
{
    HWND hwndRemote = (HWND)wParam;
    ATOM service = (ATOM)LOWORD(lParam);
    ATOM topic = (ATOM)HIWORD(lParam);
    struct DdeEnumServices *es;
    char sz[255];

#ifdef _WIN64
    es = (struct DdeEnumServices *) GetWindowLongPtr(hwnd, GWLP_USERDATA);
#else
    es = (struct DdeEnumServices *) GetWindowLong(hwnd, GWL_USERDATA);
#endif

    if ((es->service == (ATOM)0 || es->service == service)
	    && (es->topic == (ATOM)0 || es->topic == topic)) {
	Tcl_Obj *matchPtr = Tcl_NewListObj(0, NULL);
	Tcl_Obj *resultPtr = Tcl_GetObjResult(es->interp);

	GlobalGetAtomName(service, sz, 255);
	Tcl_ListObjAppendElement(NULL, matchPtr, Tcl_NewStringObj(sz, -1));
	GlobalGetAtomName(topic, sz, 255);
	Tcl_ListObjAppendElement(NULL, matchPtr, Tcl_NewStringObj(sz, -1));

	/*
	 * Adding the hwnd as a third list element provides a unique
	 * identifier in the case of multiple servers with the name
	 * application and topic names.
	 */
	/*
	 * Needs a TIP though:
	 * Tcl_ListObjAppendElement(NULL, matchPtr,
	 *	Tcl_NewLongObj((long)hwndRemote));
	 */

	if (Tcl_IsShared(resultPtr)) {
	    resultPtr = Tcl_DuplicateObj(resultPtr);
	}
	if (Tcl_ListObjAppendElement(es->interp, resultPtr,
		matchPtr) == TCL_OK) {
	    Tcl_SetObjResult(es->interp, resultPtr);
	}
    }

    /*
     * Tell the server we are no longer interested.
     */

    PostMessage(hwndRemote, WM_DDE_TERMINATE, (WPARAM)hwnd, 0L);
    return 0L;
}

static BOOL CALLBACK
DdeEnumWindowsCallback(
    HWND hwndTarget,
    LPARAM lParam)
{
    DWORD_PTR dwResult = 0;
    struct DdeEnumServices *es = (struct DdeEnumServices *) lParam;

    SendMessageTimeout(hwndTarget, WM_DDE_INITIATE, (WPARAM)es->hwnd,
	    MAKELONG(es->service, es->topic), SMTO_ABORTIFHUNG, 1000,
	    &dwResult);
    return TRUE;
}

static int
DdeGetServicesList(
    Tcl_Interp *interp,
    const char *serviceName,
    const char *topicName)
{
    struct DdeEnumServices es;

    es.interp = interp;
    es.result = TCL_OK;
    es.service = (serviceName == NULL)
	    ? (ATOM)0 : GlobalAddAtom(serviceName);
    es.topic = (topicName == NULL) ? (ATOM)0 : GlobalAddAtom(topicName);

    Tcl_ResetResult(interp); /* our list is to be appended to result. */
    DdeCreateClient(&es);
    EnumWindows(DdeEnumWindowsCallback, (LPARAM)&es);

    if (IsWindow(es.hwnd)) {
	DestroyWindow(es.hwnd);
    }
    if (es.service != (ATOM)0) {
	GlobalDeleteAtom(es.service);
    }
    if (es.topic != (ATOM)0) {
	GlobalDeleteAtom(es.topic);
    }
    return es.result;
}

/*
 *----------------------------------------------------------------------
 *
 * SetDdeError --
 *
 *	Sets the interp result to a cogent error message describing the last
 *	DDE error.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The interp's result object is changed.
 *
 *----------------------------------------------------------------------
 */

static void
SetDdeError(
    Tcl_Interp *interp)	    /* The interp to put the message in. */
{
    const char *errorMessage;

    switch (DdeGetLastError(ddeInstance)) {
    case DMLERR_DATAACKTIMEOUT:
    case DMLERR_EXECACKTIMEOUT:
    case DMLERR_POKEACKTIMEOUT:
	errorMessage = "remote interpreter did not respond";
	break;
    case DMLERR_BUSY:
	errorMessage = "remote server is busy";
	break;
    case DMLERR_NOTPROCESSED:
	errorMessage = "remote server cannot handle this command";
	break;
    default:
	errorMessage = "dde command failed";
    }

    Tcl_SetObjResult(interp, Tcl_NewStringObj(errorMessage, -1));
}

/*
 *----------------------------------------------------------------------
 *
 * DdeObjCmd --
 *
 *	This function is invoked to process the "dde" Tcl command. See the
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

static int
DdeObjCmd(
    ClientData clientData,	/* Used only for deletion */
    Tcl_Interp *interp,		/* The interp we are sending from */
    int objc,			/* Number of arguments */
    Tcl_Obj *const *objv)	/* The arguments */
{
    static const char *ddeCommands[] = {
	"servername", "execute", "poke", "request", "services", "eval",
	(char *) NULL};
    enum DdeSubcommands {
	DDE_SERVERNAME, DDE_EXECUTE, DDE_POKE, DDE_REQUEST, DDE_SERVICES,
	DDE_EVAL
    };
    static const char *ddeSrvOptions[] = {
	"-force", "-handler", "--", NULL
    };
    enum DdeSrvOptions {
	DDE_SERVERNAME_EXACT, DDE_SERVERNAME_HANDLER, DDE_SERVERNAME_LAST,
    };
    static const char *ddeExecOptions[] = {
	"-async", NULL
    };
    static const char *ddeReqOptions[] = {
	"-binary", NULL
    };

    int index, i, length, argIndex;
    int flags = 0, result = TCL_OK, firstArg = 0;
    HSZ ddeService = NULL, ddeTopic = NULL, ddeItem = NULL, ddeCookie = NULL;
    HDDEDATA ddeData = NULL, ddeItemData = NULL, ddeReturn;
    HCONV hConv = NULL;
    const char *serviceName = NULL, *topicName = NULL, *string;
    DWORD ddeResult;
    Tcl_Obj *objPtr, *handlerPtr = NULL;

    /*
     * Initialize DDE server/client
     */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "command ?arg ...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], ddeCommands, "command", 0,
	    &index) != TCL_OK) {
	return TCL_ERROR;
    }

    switch ((enum DdeSubcommands) index) {
    case DDE_SERVERNAME:
	for (i = 2; i < objc; i++) {
	    if (Tcl_GetIndexFromObj(interp, objv[i], ddeSrvOptions,
		    "option", 0, &argIndex) != TCL_OK) {
		/*
		 * If it is the last argument, it might be a server name
		 * instead of a bad argument.
		 */

		if (i != objc-1) {
		    return TCL_ERROR;
		}
		Tcl_ResetResult(interp);
		break;
	    }
	    if (argIndex == DDE_SERVERNAME_EXACT) {
		flags |= DDE_FLAG_FORCE;
	    } else if (argIndex == DDE_SERVERNAME_HANDLER) {
		if ((objc - i) == 1) {	/* return current handler */
		    RegisteredInterp *riPtr = DdeGetRegistrationPtr(interp);

		    if (riPtr && riPtr->handlerPtr) {
			Tcl_SetObjResult(interp, riPtr->handlerPtr);
		    } else {
			Tcl_ResetResult(interp);
		    }
		    return TCL_OK;
		}
		handlerPtr = objv[++i];
	    } else if (argIndex == DDE_SERVERNAME_LAST) {
		i++;
		break;
	    }
	}

	if ((objc - i) > 1) {
	    Tcl_ResetResult(interp);
	    Tcl_WrongNumArgs(interp, 2, objv,
		    "?-force? ?-handler proc? ?--? ?serverName?");
	    return TCL_ERROR;
	}

	firstArg = (objc == i) ? 1 : i;
	break;
    case DDE_EXECUTE:
	if (objc == 5) {
	    firstArg = 2;
	    break;
	} else if (objc == 6) {
	    if (Tcl_GetIndexFromObj(NULL, objv[2], ddeExecOptions, "option", 0,
		    &argIndex) == TCL_OK) {
		flags |= DDE_FLAG_ASYNC;
		firstArg = 3;
		break;
	    }
	}
	/* otherwise... */
	Tcl_WrongNumArgs(interp, 2, objv,
		"?-async? serviceName topicName value");
	return TCL_ERROR;
    case DDE_POKE:
	if (objc != 6) {
	    Tcl_WrongNumArgs(interp, 2, objv,
		    "serviceName topicName item value");
	    return TCL_ERROR;
	}
	firstArg = 2;
	break;
    case DDE_REQUEST:
	if (objc == 5) {
	    firstArg = 2;
	    break;
	} else if (objc == 6) {
	    int dummy;
	    if (Tcl_GetIndexFromObj(NULL, objv[2], ddeReqOptions, "option", 0,
		    &dummy) == TCL_OK) {
		flags |= DDE_FLAG_BINARY;
		firstArg = 3;
		break;
	    }
	}

	/*
	 * Otherwise ...
	 */

	Tcl_WrongNumArgs(interp, 2, objv,
		"?-binary? serviceName topicName value");
	return TCL_ERROR;
    case DDE_SERVICES:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "serviceName topicName");
	    return TCL_ERROR;
	}
	firstArg = 2;
	break;
    case DDE_EVAL:
	if (objc < 4) {
	wrongDdeEvalArgs:
	    Tcl_WrongNumArgs(interp, 2, objv, "?-async? serviceName args");
	    return TCL_ERROR;
	} else {
	    firstArg = 2;
	    if (Tcl_GetIndexFromObj(NULL, objv[2], ddeExecOptions, "option",
		    0, &argIndex) == TCL_OK) {
		if (objc < 5) {
		    goto wrongDdeEvalArgs;
		}
		flags |= DDE_FLAG_ASYNC;
		firstArg++;
	    }
	    break;
	}
    }

    Initialize();

    if (firstArg != 1) {
	serviceName = Tcl_GetStringFromObj(objv[firstArg], &length);
    } else {
	length = 0;
    }

    if (length == 0) {
	serviceName = NULL;
    } else if ((index != DDE_SERVERNAME) && (index != DDE_EVAL)) {
	ddeService = DdeCreateStringHandle(ddeInstance, (void *) serviceName,
		CP_WINANSI);
    }

    if ((index != DDE_SERVERNAME) && (index != DDE_EVAL)) {
	topicName = Tcl_GetStringFromObj(objv[firstArg + 1], &length);
	if (length == 0) {
	    topicName = NULL;
	} else {
	    ddeTopic = DdeCreateStringHandle(ddeInstance, (void *) topicName,
		    CP_WINANSI);
	}
    }

    switch ((enum DdeSubcommands) index) {
    case DDE_SERVERNAME:
	serviceName = DdeSetServerName(interp, serviceName, flags,
		handlerPtr);
	if (serviceName != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(serviceName, -1));
	} else {
	    Tcl_ResetResult(interp);
	}
	break;

    case DDE_EXECUTE: {
	int dataLength;
	BYTE *dataString = (BYTE *) Tcl_GetStringFromObj(
		objv[firstArg + 2], &dataLength);

	if (dataLength == 0) {
	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("cannot execute null data", -1));
	    result = TCL_ERROR;
	    break;
	}
	hConv = DdeConnect(ddeInstance, ddeService, ddeTopic, NULL);
	DdeFreeStringHandle(ddeInstance, ddeService);
	DdeFreeStringHandle(ddeInstance, ddeTopic);

	if (hConv == NULL) {
	    SetDdeError(interp);
	    result = TCL_ERROR;
	    break;
	}

	ddeData = DdeCreateDataHandle(ddeInstance, dataString,
		(DWORD) dataLength+1, 0, 0, CF_TEXT, 0);
	if (ddeData != NULL) {
	    if (flags & DDE_FLAG_ASYNC) {
		DdeClientTransaction((LPBYTE) ddeData, 0xFFFFFFFF, hConv, 0,
			CF_TEXT, XTYP_EXECUTE, TIMEOUT_ASYNC, &ddeResult);
		DdeAbandonTransaction(ddeInstance, hConv, ddeResult);
	    } else {
		ddeReturn = DdeClientTransaction((LPBYTE) ddeData, 0xFFFFFFFF,
			hConv, 0, CF_TEXT, XTYP_EXECUTE, 30000, NULL);
		if (ddeReturn == 0) {
		    SetDdeError(interp);
		    result = TCL_ERROR;
		}
	    }
	    DdeFreeDataHandle(ddeData);
	} else {
	    SetDdeError(interp);
	    result = TCL_ERROR;
	}
	break;
    }
    case DDE_REQUEST: {
	const char *itemString = Tcl_GetStringFromObj(objv[firstArg + 2],
		&length);

	if (length == 0) {
	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("cannot request value of null data", -1));
	    result = TCL_ERROR;
	    goto cleanup;
	}
	hConv = DdeConnect(ddeInstance, ddeService, ddeTopic, NULL);
	DdeFreeStringHandle(ddeInstance, ddeService);
	DdeFreeStringHandle(ddeInstance, ddeTopic);

	if (hConv == NULL) {
	    SetDdeError(interp);
	    result = TCL_ERROR;
	} else {
	    Tcl_Obj *returnObjPtr;
	    ddeItem = DdeCreateStringHandle(ddeInstance, (void *)itemString,
		    CP_WINANSI);
	    if (ddeItem != NULL) {
		ddeData = DdeClientTransaction(NULL, 0, hConv, ddeItem,
			CF_TEXT, XTYP_REQUEST, 5000, NULL);
		if (ddeData == NULL) {
		    SetDdeError(interp);
		    result = TCL_ERROR;
		} else {
		    DWORD tmp;
		    const char *dataString = (const char *) DdeAccessData(ddeData, &tmp);

		    if (flags & DDE_FLAG_BINARY) {
			returnObjPtr =
				Tcl_NewByteArrayObj((BYTE *) dataString, (int) tmp);
		    } else {
			if (tmp && !dataString[tmp-1]) {
			    --tmp;
			}
			returnObjPtr = Tcl_NewStringObj(dataString,
				(int) tmp);
		    }
		    DdeUnaccessData(ddeData);
		    DdeFreeDataHandle(ddeData);
		    Tcl_SetObjResult(interp, returnObjPtr);
		}
	    } else {
		SetDdeError(interp);
		result = TCL_ERROR;
	    }
	}

	break;
    }
    case DDE_POKE: {
	const char *itemString = Tcl_GetStringFromObj(objv[firstArg + 2],
		&length);
	BYTE *dataString;

	if (length == 0) {
	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("cannot have a null item", -1));
	    result = TCL_ERROR;
	    goto cleanup;
	}
	dataString = (BYTE *) Tcl_GetStringFromObj(objv[firstArg + 3],
		&length);

	hConv = DdeConnect(ddeInstance, ddeService, ddeTopic, NULL);
	DdeFreeStringHandle(ddeInstance, ddeService);
	DdeFreeStringHandle(ddeInstance, ddeTopic);

	if (hConv == NULL) {
	    SetDdeError(interp);
	    result = TCL_ERROR;
	} else {
	    ddeItem = DdeCreateStringHandle(ddeInstance, (void *) itemString,
		    CP_WINANSI);
	    if (ddeItem != NULL) {
		ddeData = DdeClientTransaction(dataString, (DWORD) length+1,
			hConv, ddeItem, CF_TEXT, XTYP_POKE, 5000, NULL);
		if (ddeData == NULL) {
		    SetDdeError(interp);
		    result = TCL_ERROR;
		}
	    } else {
		SetDdeError(interp);
		result = TCL_ERROR;
	    }
	}
	break;
    }

    case DDE_SERVICES:
	result = DdeGetServicesList(interp, serviceName, topicName);
	break;

    case DDE_EVAL: {
	RegisteredInterp *riPtr;
	ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

	if (serviceName == NULL) {
	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("invalid service name \"\"", -1));
	    result = TCL_ERROR;
	    goto cleanup;
	}

	objc -= firstArg + 1;
	objv += firstArg + 1;

	/*
	 * See if the target interpreter is local. If so, execute the command
	 * directly without going through the DDE server. Don't exchange
	 * objects between interps. The target interp could compile an object,
	 * producing a bytecode structure that refers to other objects owned
	 * by the target interp. If the target interp is then deleted, the
	 * bytecode structure would be referring to deallocated objects.
	 */

	for (riPtr = tsdPtr->interpListPtr; riPtr != NULL;
		riPtr = riPtr->nextPtr) {
	    if (stricmp(serviceName, riPtr->name) == 0) {
		break;
	    }
	}

	if (riPtr != NULL) {
	    Tcl_Interp *sendInterp;

	    /*
	     * This command is to a local interp. No need to go through the
	     * server.
	     */

	    Tcl_Preserve((ClientData) riPtr);
	    sendInterp = riPtr->interp;
	    Tcl_Preserve((ClientData) sendInterp);

	    /*
	     * Don't exchange objects between interps. The target interp would
	     * compile an object, producing a bytecode structure that refers
	     * to other objects owned by the target interp. If the target
	     * interp is then deleted, the bytecode structure would be
	     * referring to deallocated objects.
	     */

	    if (Tcl_IsSafe(riPtr->interp) && riPtr->handlerPtr == NULL) {
		Tcl_SetResult(riPtr->interp, "permission denied: "
			"a handler procedure must be defined for use in "
			"a safe interp", TCL_STATIC);
		result = TCL_ERROR;
	    }

	    if (result == TCL_OK) {
		if (objc == 1)
		    objPtr = objv[0];
		else {
		    objPtr = Tcl_ConcatObj(objc, objv);
		}
		if (riPtr->handlerPtr != NULL) {
		    /* add the dde request data to the handler proc list */
		    /*
		     *result = Tcl_ListObjReplace(sendInterp, objPtr, 0, 0, 1,
		     *	    &(riPtr->handlerPtr));
		     */
		    Tcl_Obj *cmdPtr = Tcl_DuplicateObj(riPtr->handlerPtr);
		    result = Tcl_ListObjAppendElement(sendInterp, cmdPtr,
			    objPtr);
		    if (result == TCL_OK) {
			objPtr = cmdPtr;
		    }
		}
	    }
	    if (result == TCL_OK) {
		Tcl_IncrRefCount(objPtr);
		result = Tcl_EvalObjEx(sendInterp, objPtr, TCL_EVAL_GLOBAL);
		Tcl_DecrRefCount(objPtr);
	    }
	    if (interp != sendInterp) {
		if (result == TCL_ERROR) {
		    /*
		     * An error occurred, so transfer error information from
		     * the destination interpreter back to our interpreter.
		     */

		    Tcl_ResetResult(interp);
		    objPtr = Tcl_GetVar2Ex(sendInterp, "errorInfo", NULL,
			    TCL_GLOBAL_ONLY);
		    if (objPtr) {
			string = Tcl_GetStringFromObj(objPtr, &length);
			Tcl_AddObjErrorInfo(interp, string, length);
		    }

		    objPtr = Tcl_GetVar2Ex(sendInterp, "errorCode", NULL,
			    TCL_GLOBAL_ONLY);
		    if (objPtr) {
			Tcl_SetObjErrorCode(interp, objPtr);
		    }
		}
		Tcl_SetObjResult(interp, Tcl_GetObjResult(sendInterp));
	    }
	    Tcl_Release((ClientData) riPtr);
	    Tcl_Release((ClientData) sendInterp);
	} else {
	    /*
	     * This is a non-local request. Send the script to the server and
	     * poll it for a result.
	     */

	    if (MakeDdeConnection(interp, serviceName, &hConv) != TCL_OK) {
	    invalidServerResponse:
		Tcl_SetObjResult(interp,
			Tcl_NewStringObj("invalid data returned from server",
			-1));
		result = TCL_ERROR;
		goto cleanup;
	    }

	    objPtr = Tcl_ConcatObj(objc, objv);
	    string = Tcl_GetStringFromObj(objPtr, &length);
	    ddeItemData = DdeCreateDataHandle(ddeInstance,
		    (BYTE *) string, (DWORD) length+1, 0, 0, CF_TEXT, 0);

	    if (flags & DDE_FLAG_ASYNC) {
		ddeData = DdeClientTransaction((LPBYTE) ddeItemData,
			0xFFFFFFFF, hConv, 0,
			CF_TEXT, XTYP_EXECUTE, TIMEOUT_ASYNC, &ddeResult);
		DdeAbandonTransaction(ddeInstance, hConv, ddeResult);
	    } else {
		ddeData = DdeClientTransaction((LPBYTE) ddeItemData,
			0xFFFFFFFF, hConv, 0,
			CF_TEXT, XTYP_EXECUTE, 30000, NULL);
		if (ddeData != 0) {
		    ddeCookie = DdeCreateStringHandle(ddeInstance,
			    TCL_DDE_EXECUTE_RESULT, CP_WINANSI);
		    ddeData = DdeClientTransaction(NULL, 0, hConv, ddeCookie,
			    CF_TEXT, XTYP_REQUEST, 30000, NULL);
		}
	    }

	    Tcl_DecrRefCount(objPtr);

	    if (ddeData == 0) {
		SetDdeError(interp);
		result = TCL_ERROR;
	    }

	    if (!(flags & DDE_FLAG_ASYNC)) {
		Tcl_Obj *resultPtr;

		/*
		 * The return handle has a two or four element list in it. The
		 * first element is the return code (TCL_OK, TCL_ERROR, etc.).
		 * The second is the result of the script. If the return code
		 * is TCL_ERROR, then the third element is the value of the
		 * variable "errorCode", and the fourth is the value of the
		 * variable "errorInfo".
		 */

		resultPtr = Tcl_NewObj();
		length = DdeGetData(ddeData, NULL, 0, 0);
		Tcl_SetObjLength(resultPtr, length);
		string = Tcl_GetString(resultPtr);
		DdeGetData(ddeData, (BYTE *) string, (DWORD) length, 0);
		Tcl_SetObjLength(resultPtr, (int) strlen(string));

		if (Tcl_ListObjIndex(NULL, resultPtr, 0, &objPtr) != TCL_OK) {
		    Tcl_DecrRefCount(resultPtr);
		    goto invalidServerResponse;
		}
		if (Tcl_GetIntFromObj(NULL, objPtr, &result) != TCL_OK) {
		    Tcl_DecrRefCount(resultPtr);
		    goto invalidServerResponse;
		}
		if (result == TCL_ERROR) {
		    Tcl_ResetResult(interp);

		    if (Tcl_ListObjIndex(NULL, resultPtr, 3,
			    &objPtr) != TCL_OK) {
			Tcl_DecrRefCount(resultPtr);
			goto invalidServerResponse;
		    }
		    length = -1;
		    string = Tcl_GetStringFromObj(objPtr, &length);
		    Tcl_AddObjErrorInfo(interp, string, length);

		    Tcl_ListObjIndex(NULL, resultPtr, 2, &objPtr);
		    Tcl_SetObjErrorCode(interp, objPtr);
		}
		if (Tcl_ListObjIndex(NULL, resultPtr, 1, &objPtr) != TCL_OK) {
		    Tcl_DecrRefCount(resultPtr);
		    goto invalidServerResponse;
		}
		Tcl_SetObjResult(interp, objPtr);
		Tcl_DecrRefCount(resultPtr);
	    }
	}
    }
    }

  cleanup:
    if (ddeCookie != NULL) {
	DdeFreeStringHandle(ddeInstance, ddeCookie);
    }
    if (ddeItem != NULL) {
	DdeFreeStringHandle(ddeInstance, ddeItem);
    }
    if (ddeItemData != NULL) {
	DdeFreeDataHandle(ddeItemData);
    }
    if (ddeData != NULL) {
	DdeFreeDataHandle(ddeData);
    }
    if (hConv != NULL) {
	DdeDisconnect(hConv);
    }
    return result;
}

/*
 * Local variables:
 * mode: c
 * indent-tabs-mode: t
 * tab-width: 8
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

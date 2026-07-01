/*
 * tclAsync.c --
 *
 *	This file provides low-level support needed to invoke signal handlers
 *	in a safe way. The code here doesn't actually handle signals, though.
 *	This code is based on proposals made by Mark Diekhans and Don Libes.
 *
 * Copyright © 1993 The Regents of the University of California.
 * Copyright © 1994 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/* Forward declaration */
struct ThreadSpecificData;

/*
 * One of the following structures exists for each asynchronous handler:
 */

typedef struct AsyncHandler {
    int ready;			/* Non-zero means this handler should be
				 * invoked in the next call to
				 * Tcl_AsyncInvoke. */
    struct AsyncHandler *nextPtr, *prevPtr;
				/* Next, previous in list of all handlers
				 * for the process. */
    Tcl_AsyncProc *proc;	/* Procedure to call when handler is
				 * invoked. */
    void *clientData;	/* Value to pass to handler when it is
				 * invoked. */
    struct ThreadSpecificData *originTsd;
				/* Used in Tcl_AsyncMark to modify thread-
				 * specific data from outside the thread it is
				 * associated to. */
    Tcl_ThreadId originThrdId;	/* Origin thread where this token was created
				 * and where it will be yielded. */
    void *notifierData;	/* Platform notifier data or NULL. */
} AsyncHandler;

typedef struct ThreadSpecificData {
    int asyncReady;		/* This is set to 1 whenever a handler becomes
				 * ready and it is cleared to zero whenever
				 * Tcl_AsyncInvoke is called. It can be
				 * checked elsewhere in the application by
				 * calling Tcl_AsyncReady to see if
				 * Tcl_AsyncInvoke should be invoked. */
    int asyncActive;		/* Indicates whether Tcl_AsyncInvoke is
				 * currently working. If so then we won't set
				 * asyncReady again until Tcl_AsyncInvoke
				 * returns. */
} ThreadSpecificData;
static Tcl_ThreadDataKey dataKey;

/* Mutex to protect linked-list of AsyncHandlers in the process. */
TCL_DECLARE_MUTEX(asyncMutex)

/* List of all existing handlers of the process. */
static AsyncHandler *firstHandler = NULL;
static AsyncHandler *lastHandler = NULL;

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeAsync --
 *
 *	Finalizes the thread local data structure for the async
 *	subsystem.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Cleans up left-over async handlers for the calling thread.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeAsync(void)
{
    AsyncHandler *token, *toDelete = NULL;
    Tcl_ThreadId self = Tcl_GetCurrentThread();

    Tcl_MutexLock(&asyncMutex);
    for (token = firstHandler; token != NULL;) {
	AsyncHandler *nextToken = token->nextPtr;

	if (token->originThrdId == self) {
	    if (token->prevPtr == NULL) {
		firstHandler = token->nextPtr;
		if (firstHandler == NULL) {
		    lastHandler = NULL;
		    break;
		}
	    } else {
		token->prevPtr->nextPtr = token->nextPtr;
		if (token == lastHandler) {
		    lastHandler = token->prevPtr;
		}
	    }
	    if (token->nextPtr != NULL) {
		token->nextPtr->prevPtr = token->prevPtr;
	    }
	    token->nextPtr = toDelete;
	    token->prevPtr = NULL;
	    toDelete = token;
	}
	token = nextToken;
    }
    Tcl_MutexUnlock(&asyncMutex);
    while (toDelete != NULL) {
	token = toDelete;
	toDelete = toDelete->nextPtr;
	Tcl_Free(token);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncCreate --
 *
 *	This procedure creates the data structures for an asynchronous
 *	handler, so that no memory has to be allocated when the handler is
 *	activated.
 *
 * Results:
 *	The return value is a token for the handler, which can be used to
 *	activate it later on.
 *
 * Side effects:
 *	Information about the handler is recorded.
 *
 *----------------------------------------------------------------------
 */

Tcl_AsyncHandler
Tcl_AsyncCreate(
    Tcl_AsyncProc *proc,	/* Procedure to call when handler is
				 * invoked. */
    void *clientData)	/* Argument to pass to handler. */
{
    AsyncHandler *asyncPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    asyncPtr = (AsyncHandler*)Tcl_Alloc(sizeof(AsyncHandler));
    asyncPtr->ready = 0;
    asyncPtr->nextPtr = NULL;
    asyncPtr->prevPtr = NULL;
    asyncPtr->proc = proc;
    asyncPtr->clientData = clientData;
    asyncPtr->originTsd = tsdPtr;
    asyncPtr->originThrdId = Tcl_GetCurrentThread();
    asyncPtr->notifierData = TclpNotifierData();

    Tcl_MutexLock(&asyncMutex);
    if (firstHandler == NULL) {
	firstHandler = asyncPtr;
    } else {
	asyncPtr->prevPtr = lastHandler;
	lastHandler->nextPtr = asyncPtr;
    }
    lastHandler = asyncPtr;
    Tcl_MutexUnlock(&asyncMutex);
    return (Tcl_AsyncHandler) asyncPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncMark --
 *
 *	This procedure is called to request that an asynchronous handler be
 *	invoked as soon as possible. It's typically called from an interrupt
 *	handler, where it isn't safe to do anything that depends on or
 *	modifies application state.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The handler gets marked for invocation later.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_AsyncMark(
    Tcl_AsyncHandler async)		/* Token for handler. */
{
    AsyncHandler *token = (AsyncHandler *) async;

    Tcl_MutexLock(&asyncMutex);
    token->ready = 1;
    if (!token->originTsd->asyncActive) {
	token->originTsd->asyncReady = 1;
	Tcl_ThreadAlert(token->originThrdId);
    }
    Tcl_MutexUnlock(&asyncMutex);

}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncMarkFromSignal --
 *
 *	This procedure is similar to Tcl_AsyncMark but must be used
 *	in POSIX signal contexts. In addition to Tcl_AsyncMark the
 *	signal number is passed.
 *
 * Results:
 *	True, when the handler will be marked, false otherwise.
 *
 * Side effects:
 *	The handler gets marked for invocation later.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_AsyncMarkFromSignal(
    Tcl_AsyncHandler async,		/* Token for handler. */
    int sigNumber)			/* Signal number. */
{
#if TCL_THREADS
    AsyncHandler *token = (AsyncHandler *) async;

    return TclAsyncNotifier(sigNumber, token->originThrdId,
	    token->notifierData, &token->ready, -1);
#else
    (void)sigNumber;

    Tcl_AsyncMark(async);
    return 1;
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclAsyncMarkFromNotifier --
 *
 *	This procedure is called from the notifier thread and
 *	invokes Tcl_AsyncMark for specifically marked handlers.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Handlers get marked for invocation later.
 *
 *----------------------------------------------------------------------
 */

void
TclAsyncMarkFromNotifier(void)
{
    AsyncHandler *token;

    Tcl_MutexLock(&asyncMutex);
    for (token = firstHandler; token != NULL;
	    token = token->nextPtr) {
	if (token->ready == -1) {
	    token->ready = 1;
	    if (!token->originTsd->asyncActive) {
		token->originTsd->asyncReady = 1;
		Tcl_ThreadAlert(token->originThrdId);
	    }
	}
    }
    Tcl_MutexUnlock(&asyncMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncInvoke --
 *
 *	This procedure is called at a "safe" time at background level to
 *	invoke any active asynchronous handlers.
 *
 * Results:
 *	The return value is a normal Tcl result, which is intended to replace
 *	the code argument as the current completion code for interp.
 *
 * Side effects:
 *	Depends on the handlers that are active.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_AsyncInvoke(
    Tcl_Interp *interp,		/* If invoked from Tcl_Eval just after
				 * completing a command, points to
				 * interpreter. Otherwise it is NULL. */
    int code)			/* If interp is non-NULL, this gives
				 * completion code from command that just
				 * completed. */
{
    AsyncHandler *asyncPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    Tcl_ThreadId self = Tcl_GetCurrentThread();

    Tcl_MutexLock(&asyncMutex);

    if (tsdPtr->asyncReady == 0) {
	Tcl_MutexUnlock(&asyncMutex);
	return code;
    }
    tsdPtr->asyncReady = 0;
    tsdPtr->asyncActive = 1;
    if (interp == NULL) {
	code = 0;
    }

    /*
     * Make one or more passes over the list of handlers, invoking at most one
     * handler in each pass. After invoking a handler, go back to the start of
     * the list again so that (a) if a new higher-priority handler gets marked
     * while executing a lower priority handler, we execute the higher-
     * priority handler next, and (b) if a handler gets deleted during the
     * execution of a handler, then the list structure may change so it isn't
     * safe to continue down the list anyway.
     */

    while (1) {
	for (asyncPtr = firstHandler; asyncPtr != NULL;
		asyncPtr = asyncPtr->nextPtr) {
	    if (asyncPtr->originThrdId != self) {
		continue;
	    }
	    if (asyncPtr->ready) {
		break;
	    }
	}
	if (asyncPtr == NULL) {
	    break;
	}
	asyncPtr->ready = 0;
	Tcl_MutexUnlock(&asyncMutex);
	code = asyncPtr->proc(asyncPtr->clientData, interp, code);
	Tcl_MutexLock(&asyncMutex);
    }
    tsdPtr->asyncActive = 0;
    Tcl_MutexUnlock(&asyncMutex);
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncDelete --
 *
 *	Frees up all the state for an asynchronous handler. The handler should
 *	never be used again.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The state associated with the handler is deleted.
 *
 *	Failure to locate the handler in current thread private list
 *	of async handlers will result in panic; exception: the list
 *	is already empty (potential trouble?).
 *	Consequently, threads should create and delete handlers
 *	themselves.  I.e. a handler created by one should not be
 *	deleted by some other thread.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_AsyncDelete(
    Tcl_AsyncHandler async)		/* Token for handler to delete. */
{
    AsyncHandler *asyncPtr = (AsyncHandler *) async;

    /*
     * Assure early handling of the constraint
     */

    if (asyncPtr->originThrdId != Tcl_GetCurrentThread()) {
	Tcl_Panic("Tcl_AsyncDelete: async handler deleted by the wrong thread");
    }

    Tcl_MutexLock(&asyncMutex);
    if (asyncPtr->prevPtr == NULL) {
	firstHandler = asyncPtr->nextPtr;
	if (firstHandler == NULL) {
	    lastHandler = NULL;
	}
    } else {
	asyncPtr->prevPtr->nextPtr = asyncPtr->nextPtr;
	if (asyncPtr == lastHandler) {
	    lastHandler = asyncPtr->prevPtr;
	}
    }
    if (asyncPtr->nextPtr != NULL) {
	asyncPtr->nextPtr->prevPtr = asyncPtr->prevPtr;
    }
    Tcl_MutexUnlock(&asyncMutex);
    Tcl_Free(asyncPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AsyncReady --
 *
 *	This procedure can be used to tell whether Tcl_AsyncInvoke needs to be
 *	called. This procedure is the external interface for checking the
 *	thread-specific asyncReady variable.
 *
 * Results:
 *	The return value is 1 whenever a handler is ready and is 0 when no
 *	handlers are ready.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_AsyncReady(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    return tsdPtr->asyncReady;
}

int *
TclGetAsyncReadyPtr(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    return &(tsdPtr->asyncReady);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/*
 * tclMutexTest.c --
 *
 *	This file implements the testmutex command.
 *
 * Copyright (c) 2025 Ashok P. Nadkarni.  All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#undef BUILD_tcl
#undef STATIC_BUILD
#ifndef USE_TCL_STUBS
#   define USE_TCL_STUBS
#endif
#include "tclInt.h"

#ifdef HAVE_UNISTD_H
#   include <unistd.h>
#   ifdef _POSIX_PRIORITY_SCHEDULING
#       include <sched.h>
#   endif
#endif

#if TCL_THREADS
/*
 * Types related to Tcl_Mutex tests.
 */

TCL_DECLARE_MUTEX(testContextMutex)

static inline void
LockTestContext(
    int numRecursions)
{
    for (int j = 0; j < numRecursions; ++j) {
	Tcl_MutexLock(&testContextMutex);
    }
}

static inline void
UnlockTestContext(
    int numRecursions)
{
    for (int j = 0; j < numRecursions; ++j) {
	Tcl_MutexUnlock(&testContextMutex);
    }
}

/*
 * ProducerConsumerContext is used in producer consumer tests to
 * simulate a resource queue.
 */
typedef struct {
    Tcl_Condition canEnqueue;	/* Signal producer if queue not full */
    Tcl_Condition canDequeue;	/* Signal consumer if queue not empty */
    Tcl_WideUInt totalEnqueued;	/* Total enqueued so far */
    Tcl_WideUInt totalDequeued;	/* Total dequeued so far */
    int available;		/* Number of "resources" available */
    int capacity;		/* Max number allowed in queue */
} ProducerConsumerQueue;
#define CONDITION_TIMEOUT_SECS 5

/*
 * MutexSharedContext holds context shared amongst all threads in a test.
 * Should only be modified under testContextMutex lock unless only single
 * thread has access.
 */
typedef struct {
    int numThreads;		/* Number of threads in test run */
    int numRecursions;		/* Number of mutex lock recursions */
    int numIterations;		/* Number of times each thread should loop */
    int yield;			/* Whether threads should yield when looping */
    union {
	Tcl_WideUInt counter;		/* Used in lock tests */
	ProducerConsumerQueue queue;	/* Used in condition variable tests */
    } u;
} MutexSharedContext;

/*
 * MutexThreadContext holds context specific to each test thread. This
 * is passed as the clientData argument to each test thread.
 */
typedef struct {
    MutexSharedContext *sharedContextPtr; /* Pointer to shared context */
    Tcl_ThreadId threadId;		  /* Only access in creator */
    Tcl_WideUInt numOperations;		  /* Use is dependent on the test */
    Tcl_WideUInt timeouts;		  /* Timeouts on condition variables */
} MutexThreadContext;

/* Used to track how many test threads running. Also used as trigger */
static volatile int mutexThreadCount;

static Tcl_ThreadCreateType	CounterThreadProc(void *clientData);
static int			TestMutexLock(Tcl_Interp *interp,
				    MutexSharedContext *contextPtr);
static int			TestConditionVariable(Tcl_Interp *interp,
				    MutexSharedContext *contextPtr);
static Tcl_ThreadCreateType	ConsumerThreadProc(void *clientData);
static Tcl_ThreadCreateType	ProducerThreadProc(void *clientData);

static inline void
YieldToOtherThreads(void)
{
#if defined(_WIN32)
    Sleep(0);
#elif defined(_POSIX_PRIORITY_SCHEDULING)
    (void) sched_yield();
#else
    volatile int i;
    for (i = 0; i < 1000; ++i) {
	/* Just some random delay */
    }
#endif
}

#ifdef __cplusplus
extern "C" {
#endif
extern int		Tcltest_Init(Tcl_Interp *interp);
#ifdef __cplusplus
}
#endif

// Get the difference (in microseconds) between two Tcl_GetTime() timestamps.
#define USEC_DIFF(before, after) \
    (1000000 * ((after).sec - (before).sec) + ((after).usec - (before).usec))

/*
 *----------------------------------------------------------------------
 *
 * TestMutexCmd --
 *
 *	This procedure is invoked to process the "testmutex" Tcl command.
 *
 *	testmutex counter ?numthreads? ?numrecursions? ?numiterations?
 *	testmutex conditionvariable ?numthreads? ?numrecursions? ?numiterations?
 *
 * Results:
 *	A standard Tcl result.
 *
 *----------------------------------------------------------------------
 */

static int
TestMutexObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    static const char *const mutexOptions[] = {
	"lock", "condition", NULL
    };
    enum options {
	LOCK, CONDITION
    } option;
    MutexSharedContext context = {
	2,		/* numThreads */
	1,		/* numRecursions */
	1000000,	/* numIterations */
	1,		/* yield */
	{0},		/* u.counter */
    };

    if (objc < 2 || objc > 6) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"option ?numthreads? ?numrecursions? ?numiterations? ?yield?");
	return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(interp, objv[1], mutexOptions, "option", 0,
	    &option) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc > 2 && Tcl_GetIntFromObj(interp, objv[2],
	    &context.numThreads) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc > 3 && Tcl_GetIntFromObj(interp, objv[3],
	    &context.numRecursions) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc > 4 && Tcl_GetIntFromObj(interp, objv[4],
	    &context.numIterations) != TCL_OK) {
	return TCL_ERROR;
    }
    if (objc > 5 && Tcl_GetIntFromObj(interp, objv[5],
	    &context.yield) != TCL_OK) {
	return TCL_ERROR;
    }

    if (context.numIterations <= 0 || context.numRecursions <= 0 ||
	    context.numThreads <= 0) {
	Tcl_SetResult(interp,
		"thread, recursion and iteration counts must be positive",
		TCL_STATIC);
	return TCL_ERROR;
    }

    int result = TCL_OK;
    switch (option) {
    case LOCK:
	result = TestMutexLock(interp, &context);
	break;
    case CONDITION:
	result = TestConditionVariable(interp, &context);
	break;
    }
    return result;
}

/*
 *------------------------------------------------------------------------
 *
 * TestMutexLock --
 *
 *	Implements the "testmutex lock" command to test Tcl_MutexLock.
 *
 * Results:
 *	A Tcl result code.
 *
 * Side effects:
 *	Stores a result in the interpreter.
 *
 *------------------------------------------------------------------------
 */
static int
TestMutexLock(
    Tcl_Interp *interp,
    MutexSharedContext *contextPtr)
{
    MutexThreadContext *threadContextsPtr = (MutexThreadContext *)
	    Tcl_Alloc(sizeof(*threadContextsPtr) * contextPtr->numThreads);

    contextPtr->u.counter = 0;
    mutexThreadCount = 0;
    for (int i = 0; i < contextPtr->numThreads; i++) {
	threadContextsPtr[i].sharedContextPtr = contextPtr;
	threadContextsPtr[i].numOperations = 0; /* Init though not used */

	if (Tcl_CreateThread(&threadContextsPtr[i].threadId,
		CounterThreadProc, &threadContextsPtr[i],
		TCL_THREAD_STACK_DEFAULT, TCL_THREAD_JOINABLE) != TCL_OK) {
	    Tcl_Panic("Failed to create %d'th thread\n", i);
	}
    }
    mutexThreadCount = contextPtr->numThreads; /* Will fire off all test threads */

    /* Wait for all threads */
    for (int i = 0; i < contextPtr->numThreads; i++) {
	int threadResult;
	Tcl_JoinThread(threadContextsPtr[i].threadId, &threadResult);
    }
    Tcl_Free(threadContextsPtr);

    Tcl_SetObjResult(interp, Tcl_NewWideUIntObj(contextPtr->u.counter));
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * CounterThreadProc --
 *
 *	Increments a shared counter a specified number of times and exits
 *	the thread.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *------------------------------------------------------------------------
 */
static Tcl_ThreadCreateType
CounterThreadProc(
    void *clientData)
{
    MutexThreadContext *threadContextPtr = (MutexThreadContext *)clientData;
    MutexSharedContext *contextPtr = threadContextPtr->sharedContextPtr;

    /* Spin wait until given the run signal */
    while (mutexThreadCount < contextPtr->numThreads) {
	YieldToOtherThreads();
    }

    for (int i = 0; i < contextPtr->numIterations; i++) {
	LockTestContext(contextPtr->numRecursions);
	Tcl_WideUInt temp = contextPtr->u.counter;
	if (contextPtr->yield) {
	    /* Some delay. No one else is supposed to modify the counter */
	    YieldToOtherThreads();
	}
	contextPtr->u.counter = temp + 1; /* Increment original value read */
	UnlockTestContext(contextPtr->numRecursions);
    }

    Tcl_ExitThread(0);
    TCL_THREAD_CREATE_RETURN;
}

/*
 *------------------------------------------------------------------------
 *
 * TestConditionVariable --
 *
 *	Implements the "testmutex condition" command to test Tcl_Condition*.
 *	The test emulates a producer-consumer scenario.
 *
 * Results:
 *	A Tcl result code.
 *
 * Side effects:
 *	Stores a result in the interpreter.
 *
 *------------------------------------------------------------------------
 */
static int
TestConditionVariable(
    Tcl_Interp *interp,
    MutexSharedContext *contextPtr)
{
    if (contextPtr->numThreads < 2) {
	Tcl_SetResult(interp, "Need at least 2 threads.", TCL_STATIC);
	return TCL_ERROR;
    }
    int numProducers = contextPtr->numThreads / 2;
    int numConsumers = contextPtr->numThreads - numProducers;

    contextPtr->u.queue.canDequeue = NULL;
    contextPtr->u.queue.canEnqueue = NULL;

    /*
     * available tracks how many elements in the virtual queue
     * capacity is max length of virtual queue.
     */
    contextPtr->u.queue.totalEnqueued = 0;
    contextPtr->u.queue.totalDequeued = 0;
    contextPtr->u.queue.available = 0;
    contextPtr->u.queue.capacity = 3; /* Arbitrary for now */

    MutexThreadContext *consumerContextsPtr = (MutexThreadContext *)Tcl_Alloc(
	    sizeof(*consumerContextsPtr) * numConsumers);
    MutexThreadContext *producerContextsPtr = (MutexThreadContext *)Tcl_Alloc(
	    sizeof(*producerContextsPtr) * numProducers);

    mutexThreadCount = 0;

    for (int i = 0; i < numConsumers; i++) {
	consumerContextsPtr[i].sharedContextPtr = contextPtr;
	consumerContextsPtr[i].numOperations = 0;
	consumerContextsPtr[i].timeouts = 0;

	if (Tcl_CreateThread(&consumerContextsPtr[i].threadId,
		ConsumerThreadProc, &consumerContextsPtr[i],
		TCL_THREAD_STACK_DEFAULT, TCL_THREAD_JOINABLE) != TCL_OK) {
	    Tcl_Panic("Failed to create %d'th thread\n", (int) i);
	}
    }

    for (int i = 0; i < numProducers; i++) {
	producerContextsPtr[i].sharedContextPtr = contextPtr;
	producerContextsPtr[i].numOperations = 0;
	producerContextsPtr[i].timeouts = 0;

	if (Tcl_CreateThread(&producerContextsPtr[i].threadId,
		ProducerThreadProc, &producerContextsPtr[i],
		TCL_THREAD_STACK_DEFAULT, TCL_THREAD_JOINABLE) != TCL_OK) {
	    Tcl_Panic("Failed to create %d'th thread\n", (int) i);
	}
    }

    mutexThreadCount = contextPtr->numThreads; /* Will trigger all threads */

    /* Producer total, thread, timeouts, Consumer total, thread, timeouts */
    Tcl_Obj *results[6];
    results[1] = Tcl_NewListObj(numProducers, NULL);
    results[4] = Tcl_NewListObj(numConsumers, NULL);

    Tcl_WideUInt producerTimeouts = 0;
    Tcl_WideUInt producerOperations = 0;
    Tcl_WideUInt consumerTimeouts = 0;
    Tcl_WideUInt consumerOperations = 0;
    for (int i = 0; i < numProducers; i++) {
	int threadResult;
	Tcl_JoinThread(producerContextsPtr[i].threadId, &threadResult);
	producerOperations += producerContextsPtr[i].numOperations;
	Tcl_ListObjAppendElement(NULL, results[1],
		Tcl_NewWideUIntObj(producerContextsPtr[i].numOperations));
	producerTimeouts += producerContextsPtr[i].timeouts;
    }
    for (int i = 0; i < numConsumers; i++) {
	int threadResult;
	Tcl_JoinThread(consumerContextsPtr[i].threadId, &threadResult);
	consumerOperations += consumerContextsPtr[i].numOperations;
	Tcl_ListObjAppendElement(NULL, results[4],
		Tcl_NewWideUIntObj(consumerContextsPtr[i].numOperations));
	consumerTimeouts += consumerContextsPtr[i].timeouts;
    }

    results[0] = Tcl_NewWideUIntObj(producerOperations);
    results[2] = Tcl_NewWideUIntObj(producerTimeouts);
    results[3] = Tcl_NewWideUIntObj(consumerOperations);
    results[5] = Tcl_NewWideUIntObj(consumerTimeouts);
    Tcl_SetObjResult(interp, Tcl_NewListObj(6, results));

    Tcl_Free(producerContextsPtr);
    Tcl_Free(consumerContextsPtr);

    Tcl_ConditionFinalize(&contextPtr->u.queue.canDequeue);
    Tcl_ConditionFinalize(&contextPtr->u.queue.canEnqueue);

    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * ProducerThreadProc --
 *
 *	Acts as a "producer" that enqueues to the virtual resource queue.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *------------------------------------------------------------------------
 */
static Tcl_ThreadCreateType
ProducerThreadProc(
    void *clientData)
{
    MutexThreadContext *threadContextPtr = (MutexThreadContext *)clientData;
    MutexSharedContext *contextPtr = threadContextPtr->sharedContextPtr;

    /* Limit on total number of operations across all threads */
    Tcl_WideUInt limit;
    limit = contextPtr->numThreads * (Tcl_WideUInt) contextPtr->numIterations;

    /* Spin wait until given the run signal */
    while (mutexThreadCount < contextPtr->numThreads) {
	YieldToOtherThreads();
    }

    LockTestContext(contextPtr->numRecursions);
    while (contextPtr->u.queue.totalEnqueued < limit) {
	if (contextPtr->u.queue.available == contextPtr->u.queue.capacity) {
	    Tcl_Time before, after;
	    Tcl_Time timeout = {CONDITION_TIMEOUT_SECS, 0};
	    Tcl_GetTime(&before);
	    Tcl_ConditionWait(&contextPtr->u.queue.canEnqueue,
		    &testContextMutex, &timeout);
	    Tcl_GetTime(&after);
	    if (USEC_DIFF(before, after) >= 1000000 * CONDITION_TIMEOUT_SECS) {
		threadContextPtr->timeouts += 1;
	    }
	} else {
	    contextPtr->u.queue.available += 1; /* Enqueue operation */
	    contextPtr->u.queue.totalEnqueued += 1;
	    threadContextPtr->numOperations += 1;
	    Tcl_ConditionNotify(&contextPtr->u.queue.canDequeue);
	    if (contextPtr->yield) {
		/* Simulate real work by unlocking before yielding */
		UnlockTestContext(contextPtr->numRecursions);
		YieldToOtherThreads();
		LockTestContext(contextPtr->numRecursions);
	    }
	}
    }
    UnlockTestContext(contextPtr->numRecursions);

    Tcl_ExitThread(0);
    TCL_THREAD_CREATE_RETURN;
}

/*
 *------------------------------------------------------------------------
 *
 * ConsumerThreadProc --
 *
 *	Acts as a "consumer" that dequeues from the virtual resource queue.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *------------------------------------------------------------------------
 */
static Tcl_ThreadCreateType
ConsumerThreadProc(
    void *clientData)
{
    MutexThreadContext *threadContextPtr = (MutexThreadContext *)clientData;
    MutexSharedContext *contextPtr = threadContextPtr->sharedContextPtr;

    /* Limit on total number of operations across all threads */
    Tcl_WideUInt limit;
    limit = contextPtr->numThreads * (Tcl_WideUInt) contextPtr->numIterations;

    /* Spin wait until given the run signal */
    while (mutexThreadCount < contextPtr->numThreads) {
	YieldToOtherThreads();
    }

    LockTestContext(contextPtr->numRecursions);
    while (contextPtr->u.queue.totalDequeued < limit) {
	if (contextPtr->u.queue.available == 0) {
	    Tcl_Time before, after;
	    Tcl_Time timeout = {CONDITION_TIMEOUT_SECS, 0};
	    Tcl_GetTime(&before);
	    Tcl_ConditionWait(&contextPtr->u.queue.canDequeue,
		    &testContextMutex, &timeout);
	    Tcl_GetTime(&after);
	    if (USEC_DIFF(before, after) >= 1000000 * CONDITION_TIMEOUT_SECS) {
		threadContextPtr->timeouts += 1;
	    }
	} else {
	    contextPtr->u.queue.totalDequeued += 1;
	    threadContextPtr->numOperations += 1;
	    contextPtr->u.queue.available -= 1;
	    Tcl_ConditionNotify(&contextPtr->u.queue.canEnqueue);
	    if (contextPtr->yield) {
		/* Simulate real work by unlocking before yielding */
		UnlockTestContext(contextPtr->numRecursions);
		YieldToOtherThreads();
		LockTestContext(contextPtr->numRecursions);
	    }
	}
    }
    UnlockTestContext(contextPtr->numRecursions);

    Tcl_ExitThread(0);
    TCL_THREAD_CREATE_RETURN;
}

/*
 *----------------------------------------------------------------------
 *
 * TclMutex_Init --
 *
 *	Initialize the testmutex command.
 *
 * Results:
 *	TCL_OK if the package was properly initialized.
 *
 * Side effects:
 *	Add the "testmutex" command to the interp.
 *
 *----------------------------------------------------------------------
 */

int
TclMutex_Init(
    Tcl_Interp *interp)		/* The current Tcl interpreter */
{
    Tcl_CreateObjCommand(interp, "testmutex", TestMutexObjCmd, NULL, NULL);
    return TCL_OK;
}
#endif /* TCL_THREADS */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/*
 * tclUnixThrd.c --
 *
 *	This file implements the UNIX-specific thread support.
 *
 * Copyright © 1991-1994 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 * Copyright © 2008 George Peter Staplin
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

#if TCL_THREADS

/*
 * TIP #509. Ensures that Tcl's mutexes are reentrant.
 *
 *----------------------------------------------------------------------
 *
 * PMutexInit --
 *
 *	Sets up the memory pointed to by its argument so that it contains the
 *	implementation of a recursive lock. Caller supplies the space.
 *
 *----------------------------------------------------------------------
 *
 * PMutexDestroy --
 *
 *	Tears down the implementation of a recursive lock (but does not
 *	deallocate the space holding the lock).
 *
 *----------------------------------------------------------------------
 *
 * PMutexLock --
 *
 *	Locks a recursive lock. (Similar to pthread_mutex_lock)
 *
 *----------------------------------------------------------------------
 *
 * PMutexUnlock --
 *
 *	Unlocks a recursive lock. (Similar to pthread_mutex_unlock)
 *
 *----------------------------------------------------------------------
 *
 * PCondWait --
 *
 *	Waits on a condition variable linked a recursive lock. (Similar to
 *	pthread_cond_wait)
 *
 *----------------------------------------------------------------------
 *
 * PCondTimedWait --
 *
 *	Waits for a limited amount of time on a condition variable linked to a
 *	recursive lock. (Similar to pthread_cond_timedwait)
 *
 *----------------------------------------------------------------------
 */

/*
 * No correct native support for reentrant mutexes. Emulate them with a counter.
 */

#ifndef PTHREAD_NULL
#   define PTHREAD_NULL (pthread_t)0
#endif

typedef struct PMutex {
    pthread_mutex_t mutex;
    volatile pthread_t thread;
    int counter; // Number of additional locks in the same thread.
} PMutex;

static void
PMutexInit(
    PMutex *pmutexPtr)
{
    pmutexPtr->thread = PTHREAD_NULL;
    pmutexPtr->counter = 0;
    pthread_mutex_init(&pmutexPtr->mutex, NULL);
}

static void
PMutexDestroy(
    PMutex *pmutexPtr)
{
    pthread_mutex_destroy(&pmutexPtr->mutex);
    assert(pthread_equal(pmutexPtr->thread, PTHREAD_NULL) && !pmutexPtr->counter);
}

static void
PMutexLock(
    PMutex *pmutexPtr)
{
    pthread_t mythread = pthread_self();

    if (pthread_equal(pmutexPtr->thread, mythread)) {
	// We own the lock already, so it's recursive.
	pmutexPtr->counter++;
    } else {
	// We don't owns the lock, so we have to lock it. Then we own it.
	pthread_mutex_lock(&pmutexPtr->mutex);
	pmutexPtr->thread = mythread;
    }
}

static void
PMutexUnlock(
    PMutex *pmutexPtr)
{
    assert(pthread_equal(pmutexPtr->thread, pthread_self()));
    if (pmutexPtr->counter) {
	// It's recursive
	pmutexPtr->counter--;
    } else {
	pmutexPtr->thread = PTHREAD_NULL;
	pthread_mutex_unlock(&pmutexPtr->mutex);
    }
}


static void
PCondWait(
    pthread_cond_t *pcondPtr,
    PMutex *pmutexPtr)
{
    pthread_t mythread = pthread_self();

    assert(pthread_equal(pmutexPtr->thread, mythread));
    int counter = pmutexPtr->counter;
    pmutexPtr->counter = 0;
    pmutexPtr->thread = PTHREAD_NULL;
    pthread_cond_wait(pcondPtr, &pmutexPtr->mutex);
    pmutexPtr->thread = mythread;
    pmutexPtr->counter = counter;
}

static void
PCondTimedWait(
    pthread_cond_t *pcondPtr,
    PMutex *pmutexPtr,
    struct timespec *ptime)
{
    pthread_t mythread = pthread_self();

    assert(pthread_equal(pmutexPtr->thread, mythread));
    int counter = pmutexPtr->counter;
    pmutexPtr->counter = 0;
    pmutexPtr->thread = PTHREAD_NULL;
    pthread_cond_timedwait(pcondPtr, &pmutexPtr->mutex, ptime);
    pmutexPtr->thread = mythread;
    pmutexPtr->counter = counter;
}

/*
 * globalLock is used to serialize creation of mutexes, condition variables,
 * and thread local storage. This is the only place that can count on the
 * ability to statically initialize the mutex.
 */

static pthread_mutex_t globalLock = PTHREAD_MUTEX_INITIALIZER;

/*
 * initLock is used to serialize initialization and finalization of Tcl. It
 * cannot use any dynamically allocated storage.
 */

static pthread_mutex_t initLock = PTHREAD_MUTEX_INITIALIZER;

/*
 * allocLock is used by Tcl's version of malloc for synchronization. For
 * obvious reasons, cannot use any dynamically allocated storage.
 */

static PMutex allocLock;
static pthread_once_t allocLockInitOnce = PTHREAD_ONCE_INIT;

static void
allocLockInit(void)
{
    PMutexInit(&allocLock);
}
static PMutex *allocLockPtr = &allocLock;

#endif /* TCL_THREADS */

/*
 *----------------------------------------------------------------------
 *
 * TclpThreadCreate --
 *
 *	This procedure creates a new thread.
 *
 * Results:
 *	TCL_OK if the thread could be created. The thread ID is returned in a
 *	parameter.
 *
 * Side effects:
 *	A new thread is created.
 *
 *----------------------------------------------------------------------
 */

int
TclpThreadCreate(
    Tcl_ThreadId *idPtr,	/* Return, the ID of the thread */
    Tcl_ThreadCreateProc *proc,	/* Main() function of the thread */
    void *clientData,		/* The one argument to Main() */
    size_t stackSize,		/* Size of stack for the new thread */
    int flags)			/* Flags controlling behaviour of the new
				 * thread. */
{
#if TCL_THREADS
    pthread_attr_t attr;
    pthread_t theThread;
    int result;

    pthread_attr_init(&attr);
    pthread_attr_setscope(&attr, PTHREAD_SCOPE_SYSTEM);

#ifdef HAVE_PTHREAD_ATTR_SETSTACKSIZE
    if (stackSize != TCL_THREAD_STACK_DEFAULT) {
	pthread_attr_setstacksize(&attr, stackSize);
#ifdef TCL_THREAD_STACK_MIN
    } else {
	/*
	 * Certain systems define a thread stack size that by default is too
	 * small for many operations. The user has the option of defining
	 * TCL_THREAD_STACK_MIN to a value large enough to work for their
	 * needs. This would look like (for 128K min stack):
	 *    make MEM_DEBUG_FLAGS=-DTCL_THREAD_STACK_MIN=131072L
	 *
	 * This solution is not optimal, as we should allow the user to
	 * specify a size at runtime, but we don't want to slow this function
	 * down, and that would still leave the main thread at the default.
	 */

	size_t size;

	result = pthread_attr_getstacksize(&attr, &size);
	if (!result && (size < TCL_THREAD_STACK_MIN)) {
	    pthread_attr_setstacksize(&attr, (size_t)TCL_THREAD_STACK_MIN);
	}
#endif /* TCL_THREAD_STACK_MIN */
    }
#endif /* HAVE_PTHREAD_ATTR_SETSTACKSIZE */

    if (!(flags & TCL_THREAD_JOINABLE)) {
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    }

    if (pthread_create(&theThread, &attr,
	    (void * (*)(void *))(void *)proc, (void *)clientData) &&
	    pthread_create(&theThread, NULL,
		    (void * (*)(void *))(void *)proc, (void *)clientData)) {
	result = TCL_ERROR;
    } else {
	*idPtr = (Tcl_ThreadId)theThread;
	result = TCL_OK;
    }
    pthread_attr_destroy(&attr);
    return result;
#else
    (void)idPtr;
    (void)proc;
    (void)clientData;
    (void)stackSize;
    (void)flags;
    return TCL_ERROR;
#endif /* TCL_THREADS */
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_JoinThread --
 *
 *	This procedure waits upon the exit of the specified thread.
 *
 * Results:
 *	TCL_OK if the wait was successful, TCL_ERROR else.
 *
 * Side effects:
 *	The result area is set to the exit code of the thread we waited upon.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_JoinThread(
    Tcl_ThreadId threadId,	/* Id of the thread to wait upon. */
    int *state)			/* Reference to the storage the result of the
				 * thread we wait upon will be written into.
				 * May be NULL. */
{
#if TCL_THREADS
    int result;
    unsigned long retcode, *retcodePtr = &retcode;

    result = pthread_join((pthread_t) threadId, (void**) retcodePtr);
    if (state) {
	*state = (int) retcode;
    }
    return (result == 0) ? TCL_OK : TCL_ERROR;
#else
    (void)threadId;
    (void)state;

    return TCL_ERROR;
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclpThreadExit --
 *
 *	This procedure terminates the current thread.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	This procedure terminates the current thread.
 *
 *----------------------------------------------------------------------
 */

TCL_NORETURN void
TclpThreadExit(
    int status)
{
#if TCL_THREADS
    pthread_exit(INT2PTR(status));
#else /* TCL_THREADS */
    exit(status);
#endif /* TCL_THREADS */
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetCurrentThread --
 *
 *	This procedure returns the ID of the currently running thread.
 *
 * Results:
 *	A thread ID.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_ThreadId
Tcl_GetCurrentThread(void)
{
#if TCL_THREADS
    return (Tcl_ThreadId) pthread_self();
#else
    return (Tcl_ThreadId) 0;
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclpInitLock
 *
 *	This procedure is used to grab a lock that serializes initialization
 *	and finalization of Tcl. On some platforms this may also initialize
 *	the mutex used to serialize creation of more mutexes and thread local
 *	storage keys.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Acquire the initialization mutex.
 *
 *----------------------------------------------------------------------
 */

void
TclpInitLock(void)
{
#if TCL_THREADS
    pthread_mutex_lock(&initLock);
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeLock
 *
 *	This procedure is used to destroy all private resources used in this
 *	file.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Destroys everything private. TclpInitLock must be held entering this
 *	function.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeLock(void)
{
#if TCL_THREADS
    /*
     * You do not need to destroy mutexes that were created with the
     * PTHREAD_MUTEX_INITIALIZER macro. These mutexes do not need any
     * destruction: globalLock, allocLock, and initLock.
     */

    pthread_mutex_unlock(&initLock);
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclpInitUnlock
 *
 *	This procedure is used to release a lock that serializes
 *	initialization and finalization of Tcl.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Release the initialization mutex.
 *
 *----------------------------------------------------------------------
 */

void
TclpInitUnlock(void)
{
#if TCL_THREADS
    pthread_mutex_unlock(&initLock);
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclpGlobalLock
 *
 *	This procedure is used to grab a lock that serializes creation and
 *	finalization of serialization objects. This interface is only needed
 *	in finalization; it is hidden during creation of the objects.
 *
 *	This lock must be different than the initLock because the initLock is
 *	held during creation of synchronization objects.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Acquire the global mutex.
 *
 *----------------------------------------------------------------------
 */

void
TclpGlobalLock(void)
{
#if TCL_THREADS
    pthread_mutex_lock(&globalLock);
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclpGlobalUnlock
 *
 *	This procedure is used to release a lock that serializes creation and
 *	finalization of synchronization objects.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Release the global mutex.
 *
 *----------------------------------------------------------------------
 */

void
TclpGlobalUnlock(void)
{
#if TCL_THREADS
    pthread_mutex_unlock(&globalLock);
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetAllocMutex
 *
 *	This procedure returns a pointer to a statically initialized mutex for
 *	use by the memory allocator. The allocator must use this lock, because
 *	all other locks are allocated...
 *
 * Results:
 *	A pointer to a mutex that is suitable for passing to Tcl_MutexLock and
 *	Tcl_MutexUnlock.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Mutex *
Tcl_GetAllocMutex(void)
{
#if TCL_THREADS
    pthread_once(&allocLockInitOnce, allocLockInit);
    return (Tcl_Mutex *) &allocLockPtr;
#else
    return NULL;
#endif
}

#if TCL_THREADS

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MutexLock --
 *
 *	This procedure is invoked to lock a mutex. This procedure handles
 *	initializing the mutex, if necessary. The caller can rely on the fact
 *	that Tcl_Mutex is an opaque pointer. This routine will change that
 *	pointer from NULL after first use.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May block the current thread. The mutex is acquired when this returns.
 *	Will allocate memory for a pthread_mutex_t and initialize this the
 *	first time this Tcl_Mutex is used.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_MutexLock(
    Tcl_Mutex *mutexPtr)	/* Really (PMutex **) */
{
    PMutex *pmutexPtr;

    if (*mutexPtr == NULL) {
	pthread_mutex_lock(&globalLock);
	if (*mutexPtr == NULL) {
	    /*
	     * Double inside global lock check to avoid a race condition.
	     */

	    pmutexPtr = (PMutex *)Tcl_Alloc(sizeof(PMutex));
	    PMutexInit(pmutexPtr);
	    *mutexPtr = (Tcl_Mutex) pmutexPtr;
	    TclRememberMutex(mutexPtr);
	}
	pthread_mutex_unlock(&globalLock);
    }
    pmutexPtr = *((PMutex **) mutexPtr);
    PMutexLock(pmutexPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MutexUnlock --
 *
 *	This procedure is invoked to unlock a mutex. The mutex must have been
 *	locked by Tcl_MutexLock.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The mutex is released when this returns.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_MutexUnlock(
    Tcl_Mutex *mutexPtr)	/* Really (PMutex **) */
{
    PMutex *pmutexPtr = *(PMutex **) mutexPtr;

    PMutexUnlock(pmutexPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFinalizeMutex --
 *
 *	This procedure is invoked to clean up one mutex. This is only safe to
 *	call at the end of time.
 *
 *	This assumes the Global Lock is held.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The mutex list is deallocated.
 *
 *----------------------------------------------------------------------
 */

void
TclpFinalizeMutex(
    Tcl_Mutex *mutexPtr)
{
    PMutex *pmutexPtr = *(PMutex **)mutexPtr;

    if (pmutexPtr != NULL) {
	PMutexDestroy(pmutexPtr);
	Tcl_Free(pmutexPtr);
	*mutexPtr = NULL;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConditionWait --
 *
 *	This procedure is invoked to wait on a condition variable. The mutex
 *	is automically released as part of the wait, and automatically grabbed
 *	when the condition is signaled.
 *
 *	The mutex must be held when this procedure is called.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May block the current thread. The mutex is acquired when this returns.
 *	Will allocate memory for a pthread_mutex_t and initialize this the
 *	first time this Tcl_Mutex is used.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_ConditionWait(
    Tcl_Condition *condPtr,	/* Really (pthread_cond_t **) */
    Tcl_Mutex *mutexPtr,	/* Really (PMutex **) */
    const Tcl_Time *timePtr)	/* Timeout on waiting period */
{
    pthread_cond_t *pcondPtr;
    PMutex *pmutexPtr;
    struct timespec ptime;

    if (*condPtr == NULL) {
	pthread_mutex_lock(&globalLock);

	/*
	 * Double check inside mutex to avoid race, then initialize condition
	 * variable if necessary.
	 */

	if (*condPtr == NULL) {
	    pcondPtr = (pthread_cond_t *)Tcl_Alloc(sizeof(pthread_cond_t));
	    pthread_cond_init(pcondPtr, NULL);
	    *condPtr = (Tcl_Condition) pcondPtr;
	    TclRememberCondition(condPtr);
	}
	pthread_mutex_unlock(&globalLock);
    }
    pmutexPtr = *((PMutex **)mutexPtr);
    pcondPtr = *((pthread_cond_t **)condPtr);
    if (timePtr == NULL) {
	PCondWait(pcondPtr, pmutexPtr);
    } else {
	Tcl_Time now;

	/*
	 * Make sure to take into account the microsecond component of the
	 * current time, including possible overflow situations. [Bug #411603]
	 */

	Tcl_GetTime(&now);
	ptime.tv_sec = timePtr->sec + now.sec +
	    (timePtr->usec + now.usec) / 1000000;
	ptime.tv_nsec = 1000 * ((timePtr->usec + now.usec) % 1000000);
	PCondTimedWait(pcondPtr, pmutexPtr, &ptime);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ConditionNotify --
 *
 *	This procedure is invoked to signal a condition variable.
 *
 *	The mutex must be held during this call to avoid races, but this
 *	interface does not enforce that.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May unblock another thread.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_ConditionNotify(
    Tcl_Condition *condPtr)
{
    pthread_cond_t *pcondPtr = *((pthread_cond_t **)condPtr);

    if (pcondPtr != NULL) {
	pthread_cond_broadcast(pcondPtr);
    } else {
	/*
	 * No-one has used the condition variable, so there are no waiters.
	 */
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFinalizeCondition --
 *
 *	This procedure is invoked to clean up a condition variable. This is
 *	only safe to call at the end of time.
 *
 *	This assumes the Global Lock is held.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The condition variable is deallocated.
 *
 *----------------------------------------------------------------------
 */

void
TclpFinalizeCondition(
    Tcl_Condition *condPtr)
{
    pthread_cond_t *pcondPtr = *(pthread_cond_t **)condPtr;

    if (pcondPtr != NULL) {
	pthread_cond_destroy(pcondPtr);
	Tcl_Free(pcondPtr);
	*condPtr = NULL;
    }
}

/*
 * Additions by AOL for specialized thread memory allocator.
 */

#ifdef USE_THREAD_ALLOC
static pthread_key_t key;

typedef struct {
    Tcl_Mutex tlock;
    PMutex plock;
} AllocMutex;

Tcl_Mutex *
TclpNewAllocMutex(void)
{
    AllocMutex *lockPtr;
    PMutex *plockPtr;

    lockPtr = (AllocMutex *)malloc(sizeof(AllocMutex));
    if (lockPtr == NULL) {
	Tcl_Panic("could not allocate lock");
    }
    plockPtr = &lockPtr->plock;
    lockPtr->tlock = (Tcl_Mutex) plockPtr;
    PMutexInit(&lockPtr->plock);
    return &lockPtr->tlock;
}

void
TclpFreeAllocMutex(
    Tcl_Mutex *mutex)		/* The alloc mutex to free. */
{
    AllocMutex *lockPtr = (AllocMutex *)mutex;

    if (!lockPtr) {
	return;
    }
    PMutexDestroy(&lockPtr->plock);
    free(lockPtr);
}

void
TclpInitAllocCache(void)
{
    pthread_key_create(&key, NULL);
}

void
TclpFreeAllocCache(
    void *ptr)
{
    if (ptr != NULL) {
	/*
	 * Called by TclFinalizeThreadAllocThread() during the thread
	 * finalization initiated from Tcl_FinalizeThread()
	 */

	TclFreeAllocCache(ptr);
	pthread_setspecific(key, NULL);

    } else {
	/*
	 * Called by TclFinalizeThreadAlloc() during the process
	 * finalization initiated from Tcl_Finalize()
	 */

	pthread_key_delete(key);
    }
}

void *
TclpGetAllocCache(void)
{
    return pthread_getspecific(key);
}

void
TclpSetAllocCache(
    void *arg)
{
    pthread_setspecific(key, arg);
}
#endif /* USE_THREAD_ALLOC */

void *
TclpThreadCreateKey(void)
{
    pthread_key_t *ptkeyPtr;

    ptkeyPtr = (pthread_key_t *)TclpSysAlloc(sizeof(pthread_key_t));
    if (NULL == ptkeyPtr) {
	Tcl_Panic("unable to allocate thread key!");
    }

    if (pthread_key_create(ptkeyPtr, NULL)) {
	Tcl_Panic("unable to create pthread key!");
    }

    return ptkeyPtr;
}

void
TclpThreadDeleteKey(
    void *keyPtr)
{
    pthread_key_t *ptkeyPtr = (pthread_key_t *)keyPtr;

    if (pthread_key_delete(*ptkeyPtr)) {
	Tcl_Panic("unable to delete key!");
    }

    TclpSysFree(keyPtr);
}

void
TclpThreadSetGlobalTSD(
    void *tsdKeyPtr,
    void *ptr)
{
    pthread_key_t *ptkeyPtr = (pthread_key_t *)tsdKeyPtr;

    if (pthread_setspecific(*ptkeyPtr, ptr)) {
	Tcl_Panic("unable to set global TSD value");
    }
}

void *
TclpThreadGetGlobalTSD(
    void *tsdKeyPtr)
{
    pthread_key_t *ptkeyPtr = (pthread_key_t *)tsdKeyPtr;

    return pthread_getspecific(*ptkeyPtr);
}

#endif /* TCL_THREADS */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

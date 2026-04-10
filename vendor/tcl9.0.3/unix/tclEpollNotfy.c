/*
 * tclEpollNotfy.c --
 *
 *	This file contains the implementation of the epoll()-based
 *	Linux-specific notifier, which is the lowest-level part of the Tcl
 *	event loop. This file works together with generic/tclNotify.c.
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 * Copyright © 2016 Lucio Andrés Illanes Albornoz <l.illanes@gmx.de>
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#ifndef HAVE_COREFOUNDATION	/* Darwin/Mac OS X CoreFoundation notifier is
				 * in tclMacOSXNotify.c */
#if defined(NOTIFIER_EPOLL) && TCL_THREADS
#ifndef _GNU_SOURCE
#   define _GNU_SOURCE		/* For pipe2(2) */
#endif
#include <fcntl.h>
#include <signal.h>
#include <sys/epoll.h>
#ifdef HAVE_EVENTFD
#include <sys/eventfd.h>
#endif /* HAVE_EVENTFD */
#include <sys/queue.h>

/*
 * This structure is used to keep track of the notifier info for a registered
 * file.
 */

struct PlatformEventData;
typedef struct FileHandler {
    int fd;
    int mask;			/* Mask of desired events: TCL_READABLE,
				 * etc. */
    int readyMask;		/* Mask of events that have been seen since
				 * the last time file handlers were invoked
				 * for this file. */
    Tcl_FileProc *proc;		/* Function to call, in the style of
				 * Tcl_CreateFileHandler. */
    void *clientData;		/* Argument to pass to proc. */
    struct FileHandler *nextPtr;/* Next in list of all files we care about. */
    LIST_ENTRY(FileHandler) readyNode;
				/* Next/previous in list of FileHandlers asso-
				 * ciated with regular files (S_IFREG) that are
				 * ready for I/O. */
    struct PlatformEventData *pedPtr;
				/* Pointer to PlatformEventData associating this
				 * FileHandler with epoll(7) events. */
} FileHandler;

/*
 * The following structure associates a FileHandler and the thread that owns
 * it with the file descriptors of interest and their event masks passed to
 * epoll_ctl(2) and their corresponding event(s) returned by epoll_wait(2).
 */

struct ThreadSpecificData;
struct PlatformEventData {
    FileHandler *filePtr;
    struct ThreadSpecificData *tsdPtr;
};

/*
 * The following structure is what is added to the Tcl event queue when file
 * handlers are ready to fire.
 */

typedef struct {
    Tcl_Event header;		/* Information that is standard for all
				 * events. */
    int fd;			/* File descriptor that is ready. Used to find
				 * the FileHandler structure for the file
				 * (can't point directly to the FileHandler
				 * structure because it could go away while
				 * the event is queued). */
} FileHandlerEvent;

/*
 * The following static structure contains the state information for the
 * epoll based implementation of the Tcl notifier. One of these structures is
 * created for each thread that is using the notifier.
 */

LIST_HEAD(PlatformReadyFileHandlerList, FileHandler);
typedef struct ThreadSpecificData {
    FileHandler *triggerFilePtr;
    FileHandler *firstFileHandlerPtr;
				/* Pointer to head of file handler list. */
    struct PlatformReadyFileHandlerList firstReadyFileHandlerPtr;
				/* Pointer to head of list of FileHandlers
				 * associated with regular files (S_IFREG)
				 * that are ready for I/O. */
    pthread_mutex_t notifierMutex;
				/* Mutex protecting notifier termination in
				 * TclpFinalizeNotifier. */
#ifdef HAVE_EVENTFD
    int triggerEventFd;		/* eventfd(2) used by other threads to wake
				 * up this thread for inter-thread IPC. */
#else
    int triggerPipe[2];		/* pipe(2) used by other threads to wake
				 * up this thread for inter-thread IPC. */
#endif /* HAVE_EVENTFD */
    int eventsFd;		/* epoll(7) file descriptor used to wait for
				 * fds */
    struct epoll_event *readyEvents;
				/* Pointer to at most maxReadyEvents events
				 * returned by epoll_wait(2). */
    size_t maxReadyEvents;	/* Count of epoll_events in readyEvents. */
    int asyncPending;		/* True when signal triggered thread. */
} ThreadSpecificData;

static Tcl_ThreadDataKey dataKey;

/*
 * Forward declarations.
 */

static void		PlatformEventsControl(FileHandler *filePtr,
			    ThreadSpecificData *tsdPtr, int op, int isNew);
static void		PlatformEventsInit(void);
static int		PlatformEventsTranslate(struct epoll_event *event);
static int		PlatformEventsWait(struct epoll_event *events,
			    size_t numEvents, struct timeval *timePtr);

/*
 * Incorporate the base notifier implementation.
 */

#include "tclUnixNotfy.c"

/*
 *----------------------------------------------------------------------
 *
 * TclpInitNotifier --
 *
 *	Initializes the platform specific notifier state.
 *
 * Results:
 *	Returns a handle to the notifier state for this thread.
 *
 * Side effects:
 *	If no initNotifierProc notifier hook exists, PlatformEventsInit is
 *	called.
 *
 *----------------------------------------------------------------------
 */

void *
TclpInitNotifier(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    PlatformEventsInit();
    return tsdPtr;
}


/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsControl --
 *
 *	This function registers interest for the file descriptor and the mask
 *	of TCL_* bits associated with filePtr on the epoll file descriptor
 *	associated with tsdPtr.
 *
 *	Future calls to epoll_wait will return filePtr and tsdPtr alongside
 *	with the event registered here via the PlatformEventData struct.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	- If adding a new file descriptor, a PlatformEventData struct will be
 *	  allocated and associated with filePtr.
 *	- fstat is called on the file descriptor; if it is associated with a
 *	  regular file (S_IFREG,) filePtr is considered to be ready for I/O
 *	  and added to or deleted from the corresponding list in tsdPtr.
 *	- If it is not associated with a regular file, the file descriptor is
 *	  added, modified concerning its mask of events of interest, or
 *	  deleted from the epoll file descriptor of the calling thread.
 *
 *----------------------------------------------------------------------
 */

static void
PlatformEventsControl(
    FileHandler *filePtr,
    ThreadSpecificData *tsdPtr,
    int op,
    int isNew)
{
    struct epoll_event newEvent;
    struct PlatformEventData *newPedPtr;
    Tcl_StatBuf fdStat;

    newEvent.events = 0;
    if (filePtr->mask & (TCL_READABLE | TCL_EXCEPTION)) {
	newEvent.events |= EPOLLIN;
    }
    if (filePtr->mask & TCL_WRITABLE) {
	newEvent.events |= EPOLLOUT;
    }
    if (isNew) {
	newPedPtr = (struct PlatformEventData *)
		Tcl_Alloc(sizeof(struct PlatformEventData));
	newPedPtr->filePtr = filePtr;
	newPedPtr->tsdPtr = tsdPtr;
	filePtr->pedPtr = newPedPtr;
    }
    newEvent.data.ptr = filePtr->pedPtr;

    /*
     * N.B. As discussed in Tcl_WaitForEvent(), epoll(7) does not support
     * regular files (S_IFREG). Therefore, filePtr is in these cases simply
     * added or deleted from the list of FileHandlers associated with regular
     * files belonging to tsdPtr.
     */

    if (TclOSfstat(filePtr->fd, &fdStat) == -1) {
	/*
	 * The tclEpollNotfy PlatformEventsControl function panics if the TclOSfstat
	 * call returns -1, which occurs when using a websocket to a browser and the
	 * browser page is refreshed. It seems the fstat call isn't doing anything
	 * useful, in particular the contents of the statbuf aren't examined afterwards
	 * on success and at best it changes the panic message. Instead we avoid the
	 * panic at the cost of a memory leak. See [010d8f38]
	 */
	return;
    } else if (epoll_ctl(tsdPtr->eventsFd, op, filePtr->fd, &newEvent) == -1) {
       switch (errno) {
	    case EPERM:
		switch (op) {
		case EPOLL_CTL_ADD:
		    if (isNew) {
			LIST_INSERT_HEAD(&tsdPtr->firstReadyFileHandlerPtr, filePtr,
				readyNode);
		    }
		    break;
		case EPOLL_CTL_DEL:
		    LIST_REMOVE(filePtr, readyNode);
		    break;

		}
		break;
	    default:
		Tcl_Panic("epoll_ctl: %s", strerror(errno));
	}
    }
    return;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFinalizeNotifier --
 *
 *	This function closes the eventfd and the epoll file descriptor and
 *	frees the epoll_event structs owned by the thread of the caller.  The
 *	above operations are protected by tsdPtr->notifierMutex, which is
 *	destroyed thereafter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	While tsdPtr->notifierMutex is held:
 *	- The per-thread eventfd(2) is closed, if non-zero, and set to -1.
 *	- The per-thread epoll(7) fd is closed, if non-zero, and set to 0.
 *	- The per-thread epoll_event structs are freed, if any, and set to 0.
 *
 *	tsdPtr->notifierMutex is destroyed.
 *
 *----------------------------------------------------------------------
 */

void
TclpFinalizeNotifier(
    TCL_UNUSED(void *))
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    pthread_mutex_lock(&tsdPtr->notifierMutex);
#ifdef HAVE_EVENTFD
    if (tsdPtr->triggerEventFd) {
	close(tsdPtr->triggerEventFd);
	tsdPtr->triggerEventFd = -1;
    }
#else /* !HAVE_EVENTFD */
    if (tsdPtr->triggerPipe[0]) {
	close(tsdPtr->triggerPipe[0]);
	tsdPtr->triggerPipe[0] = -1;
    }
    if (tsdPtr->triggerPipe[1]) {
	close(tsdPtr->triggerPipe[1]);
	tsdPtr->triggerPipe[1] = -1;
    }
#endif /* HAVE_EVENTFD */
    Tcl_Free(tsdPtr->triggerFilePtr->pedPtr);
    Tcl_Free(tsdPtr->triggerFilePtr);
    if (tsdPtr->eventsFd > 0) {
	close(tsdPtr->eventsFd);
	tsdPtr->eventsFd = 0;
    }
    if (tsdPtr->readyEvents) {
	Tcl_Free(tsdPtr->readyEvents);
	tsdPtr->maxReadyEvents = 0;
    }
    pthread_mutex_unlock(&tsdPtr->notifierMutex);
    if ((errno = pthread_mutex_destroy(&tsdPtr->notifierMutex))) {
	Tcl_Panic("pthread_mutex_destroy: %s", strerror(errno));
    }
}

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsInit --
 *
 *	This function abstracts creating a kqueue fd via the epoll_create
 *	system call and allocating memory for the epoll_event structs in
 *	tsdPtr for the thread of the caller.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The following per-thread entities are initialised:
 *	- notifierMutex is initialised.
 *	- The eventfd(2) is created w/ EFD_CLOEXEC and EFD_NONBLOCK.
 *	- The epoll(7) fd is created w/ EPOLL_CLOEXEC.
 *	- A FileHandler struct is allocated and initialised for the
 *	  eventfd(2), registering interest for TCL_READABLE on it via
 *	  PlatformEventsControl().
 *	- readyEvents and maxReadyEvents are initialised with 512
 *	  epoll_events.
 *
 *----------------------------------------------------------------------
 */

static void
PlatformEventsInit(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    FileHandler *filePtr;

    errno = pthread_mutex_init(&tsdPtr->notifierMutex, NULL);
    if (errno) {
	Tcl_Panic("Tcl_InitNotifier: %s", "could not create mutex");
    }
    filePtr = (FileHandler *) Tcl_Alloc(sizeof(FileHandler));
#ifdef HAVE_EVENTFD
    tsdPtr->triggerEventFd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (tsdPtr->triggerEventFd <= 0) {
	Tcl_Panic("Tcl_InitNotifier: %s", "could not create trigger eventfd");
    }
    filePtr->fd = tsdPtr->triggerEventFd;
#else /* !HAVE_EVENTFD */
    if (pipe2(tsdPtr->triggerPipe, O_CLOEXEC | O_NONBLOCK) != 0) {
	Tcl_Panic("Tcl_InitNotifier: %s", "could not create trigger pipe");
    }
    filePtr->fd = tsdPtr->triggerPipe[0];
#endif /* HAVE_EVENTFD */
    tsdPtr->triggerFilePtr = filePtr;
    if ((tsdPtr->eventsFd = epoll_create1(EPOLL_CLOEXEC)) == -1) {
	Tcl_Panic("epoll_create1: %s", strerror(errno));
    }
    filePtr->mask = TCL_READABLE;
    PlatformEventsControl(filePtr, tsdPtr, EPOLL_CTL_ADD, 1);
    if (!tsdPtr->readyEvents) {
	tsdPtr->maxReadyEvents = 512;
	tsdPtr->readyEvents = (struct epoll_event *) Tcl_Alloc(
		tsdPtr->maxReadyEvents * sizeof(tsdPtr->readyEvents[0]));
    }
    LIST_INIT(&tsdPtr->firstReadyFileHandlerPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsTranslate --
 *
 *	This function translates the platform-specific mask of returned events
 *	in eventPtr to a mask of TCL_* bits.
 *
 * Results:
 *	Returns the translated mask.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
PlatformEventsTranslate(
    struct epoll_event *eventPtr)
{
    int mask;

    mask = 0;
    if (eventPtr->events & (EPOLLIN | EPOLLHUP)) {
	mask |= TCL_READABLE;
    }
    if (eventPtr->events & EPOLLOUT) {
	mask |= TCL_WRITABLE;
    }
    if (eventPtr->events & EPOLLERR) {
	mask |= TCL_EXCEPTION;
    }
    return mask;
}

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsWait --
 *
 *	This function abstracts waiting for I/O events via epoll_wait.
 *
 * Results:
 *	Returns -1 if epoll_wait failed. Returns 0 if polling and if no events
 *	became available whilst polling. Returns a pointer to and the count of
 *	all returned events in all other cases.
 *
 * Side effects:
 *	gettimeofday(2), epoll_wait(2), and gettimeofday(2) are called, in the
 *	specified order.
 *	If timePtr specifies a positive value, it is updated to reflect the
 *	amount of time that has passed; if its value would {under, over}flow,
 *	it is set to zero.
 *
 *----------------------------------------------------------------------
 */

static int
PlatformEventsWait(
    struct epoll_event *events,
    size_t numEvents,
    struct timeval *timePtr)
{
    int numFound;
    struct timeval tv0, tv1, tv_delta;
    int timeout;

    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * If timePtr is NULL, epoll_wait(2) will wait indefinitely. If it
     * specifies a timeout of {0,0}, epoll_wait(2) will poll. Otherwise, the
     * timeout will simply be converted to milliseconds.
     */

    if (!timePtr) {
	timeout = -1;
    } else if (!timePtr->tv_sec && !timePtr->tv_usec) {
	timeout = 0;
    } else {
	timeout = (int) timePtr->tv_sec * 1000;
	if (timePtr->tv_usec) {
	    timeout += (int) timePtr->tv_usec / 1000;
	}
    }

    /*
     * Call (and possibly block on) epoll_wait(2) and substract the delta of
     * gettimeofday(2) before and after the call from timePtr if the latter is
     * not NULL. Return the number of events returned by epoll_wait(2).
     */

    gettimeofday(&tv0, NULL);
    numFound = epoll_wait(tsdPtr->eventsFd, events, (int) numEvents, timeout);
    gettimeofday(&tv1, NULL);
    if (timePtr && (timePtr->tv_sec && timePtr->tv_usec)) {
	timersub(&tv1, &tv0, &tv_delta);
	if (!timercmp(&tv_delta, timePtr, >)) {
	    timersub(timePtr, &tv_delta, timePtr);
	} else {
	    timePtr->tv_sec = 0;
	    timePtr->tv_usec = 0;
	}
    }
    if (tsdPtr->asyncPending) {
	tsdPtr->asyncPending = 0;
	TclAsyncMarkFromNotifier();
    }
    return numFound;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpCreateFileHandler --
 *
 *	This function registers a file handler with the epoll notifier of the
 *	thread of the caller.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Creates a new file handler structure.
 *	PlatformEventsControl() is called for the new file handler structure.
 *
 *----------------------------------------------------------------------
 */

void
TclpCreateFileHandler(
    int fd,			/* Handle of stream to watch. */
    int mask,			/* OR'ed combination of TCL_READABLE,
				 * TCL_WRITABLE, and TCL_EXCEPTION: indicates
				 * conditions under which proc should be
				 * called. */
    Tcl_FileProc *proc,		/* Function to call for each selected
				 * event. */
    void *clientData)		/* Arbitrary data to pass to proc. */
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    FileHandler *filePtr = LookUpFileHandler(tsdPtr, fd, NULL);
    int isNew = (filePtr == NULL);

    if (isNew) {
	filePtr = (FileHandler *) Tcl_Alloc(sizeof(FileHandler));
	filePtr->fd = fd;
	filePtr->readyMask = 0;
	filePtr->nextPtr = tsdPtr->firstFileHandlerPtr;
	tsdPtr->firstFileHandlerPtr = filePtr;
    }
    filePtr->proc = proc;
    filePtr->clientData = clientData;
    filePtr->mask = mask;

    PlatformEventsControl(filePtr, tsdPtr,
	    isNew ? EPOLL_CTL_ADD : EPOLL_CTL_MOD, isNew);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpDeleteFileHandler --
 *
 *	Cancel a previously-arranged callback arrangement for a file on the
 *	epoll file descriptor of the thread of the caller.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	If a callback was previously registered on file, remove it.
 *	PlatformEventsControl() is called for the file handler structure.
 *	The PlatformEventData struct associated with the new file handler
 *	structure is freed.
 *
 *----------------------------------------------------------------------
 */

void
TclpDeleteFileHandler(
    int fd)			/* Stream id for which to remove callback
				 * function. */
{
    FileHandler *filePtr, *prevPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * Find the entry for the given file (and return if there isn't one).
     */

    filePtr = LookUpFileHandler(tsdPtr, fd, &prevPtr);
    if (filePtr == NULL) {
	return;
    }

    /*
     * Update the check masks for this file.
     */

    PlatformEventsControl(filePtr, tsdPtr, EPOLL_CTL_DEL, 0);
    if (filePtr->pedPtr) {
	Tcl_Free(filePtr->pedPtr);
    }

    /*
     * Clean up information in the callback record.
     */

    if (prevPtr == NULL) {
	tsdPtr->firstFileHandlerPtr = filePtr->nextPtr;
    } else {
	prevPtr->nextPtr = filePtr->nextPtr;
    }
    Tcl_Free(filePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpWaitForEvent --
 *
 *	This function is called by Tcl_DoOneEvent to wait for new events on
 *	the message queue. If the block time is 0, then TclpWaitForEvent just
 *	polls without blocking.
 *
 *	The waiting logic is implemented in PlatformEventsWait.
 *
 * Results:
 *	Returns -1 if PlatformEventsWait() would block forever, otherwise
 *	returns 0.
 *
 * Side effects:
 *	Queues file events that are detected by PlatformEventsWait().
 *
 *----------------------------------------------------------------------
 */

int
TclpWaitForEvent(
    const Tcl_Time *timePtr)	/* Maximum block time, or NULL. */
{
    FileHandler *filePtr;
    Tcl_Time vTime;
    struct timeval timeout, *timeoutPtr;
				/* Impl. notes: timeout & timeoutPtr are used
				 * if, and only if threads are not enabled.
				 * They are the arguments for the regular
				 * epoll_wait() used when the core is not
				 * thread-enabled. */
    int mask, numFound, numEvent;
    struct PlatformEventData *pedPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    int numQueued;
    ssize_t i;

    /*
     * Set up the timeout structure. Note that if there are no events to check
     * for, we return with a negative result rather than blocking forever.
     */

    if (timePtr != NULL) {
	/*
	 * TIP #233 (Virtualized Time). Is virtual time in effect? And do we
	 * actually have something to scale? If yes to both then we call the
	 * handler to do this scaling.
	 */

	if (timePtr->sec != 0 || timePtr->usec != 0) {
	    vTime = *timePtr;
	    TclScaleTime(&vTime);
	    timePtr = &vTime;
	}
	timeout.tv_sec = timePtr->sec;
	timeout.tv_usec = timePtr->usec;
	timeoutPtr = &timeout;
    } else {
	timeoutPtr = NULL;
    }

    /*
     * Walk the list of FileHandlers associated with regular files (S_IFREG)
     * belonging to tsdPtr, queue Tcl events for them, and update their mask
     * of events of interest.
     *
     * As epoll(7) does not support regular files, the behaviour of
     * {select,poll}(2) is simply simulated here: fds associated with regular
     * files are added to this list by PlatformEventsControl() and processed
     * here before calling (and possibly blocking) on PlatformEventsWait().
     */

    numQueued = 0;
    LIST_FOREACH(filePtr, &tsdPtr->firstReadyFileHandlerPtr, readyNode) {
	mask = 0;
	if (filePtr->mask & TCL_READABLE) {
	    mask |= TCL_READABLE;
	}
	if (filePtr->mask & TCL_WRITABLE) {
	    mask |= TCL_WRITABLE;
	}

	/*
	 * Don't bother to queue an event if the mask was previously non-zero
	 * since an event must still be on the queue.
	 */

	if (filePtr->readyMask == 0) {
	    FileHandlerEvent *fileEvPtr = (FileHandlerEvent *)
		    Tcl_Alloc(sizeof(FileHandlerEvent));

	    fileEvPtr->header.proc = FileHandlerEventProc;
	    fileEvPtr->fd = filePtr->fd;
	    Tcl_QueueEvent((Tcl_Event *) fileEvPtr, TCL_QUEUE_TAIL);
	    numQueued++;
	}
	filePtr->readyMask = mask;
    }

    /*
     * If any events were queued in the above loop, force PlatformEventsWait()
     * to poll as there already are events that need to be processed at this
     * point.
     */

    if (numQueued) {
	timeout.tv_sec = 0;
	timeout.tv_usec = 0;
	timeoutPtr = &timeout;
    }

    /*
     * Wait or poll for new events, queue Tcl events for the FileHandlers
     * corresponding to them, and update the FileHandlers' mask of events of
     * interest registered by the last call to Tcl_CreateFileHandler().
     *
     * Events for the eventfd(2)/trigger pipe are processed here in order to
     * facilitate inter-thread IPC. If another thread intends to wake up this
     * thread whilst it's blocking on PlatformEventsWait(), it write(2)s to
     * the eventfd(2)/trigger pipe (see Tcl_AlertNotifier(),) which in turn
     * will cause PlatformEventsWait() to return immediately.
     */

    numFound = PlatformEventsWait(tsdPtr->readyEvents,
	    tsdPtr->maxReadyEvents, timeoutPtr);
    for (numEvent = 0; numEvent < numFound; numEvent++) {
	pedPtr = (struct PlatformEventData *)
		tsdPtr->readyEvents[numEvent].data.ptr;
	filePtr = pedPtr->filePtr;
	mask = PlatformEventsTranslate(&tsdPtr->readyEvents[numEvent]);
#ifdef HAVE_EVENTFD
	if (filePtr->fd == tsdPtr->triggerEventFd) {
	    uint64_t eventFdVal;

	    i = read(tsdPtr->triggerEventFd, &eventFdVal, sizeof(eventFdVal));
	    if ((i != sizeof(eventFdVal)) && (errno != EAGAIN)) {
		Tcl_Panic("%s: read from %p->triggerEventFd: %s",
			"Tcl_WaitForEvent", tsdPtr, strerror(errno));
	    }
	    continue;
	}
#else /* !HAVE_EVENTFD */
	if (filePtr->fd == tsdPtr->triggerPipe[0]) {
	    char triggerPipeVal;

	    i = read(tsdPtr->triggerPipe[0], &triggerPipeVal,
		    sizeof(triggerPipeVal));
	    if ((i != sizeof(triggerPipeVal)) && (errno != EAGAIN)) {
		Tcl_Panic("%s: read from %p->triggerPipe[0]: %s",
			"Tcl_WaitForEvent", tsdPtr, strerror(errno));
	    }
	    continue;
	}
#endif /* HAVE_EVENTFD */
	if (!mask) {
	    continue;
	}

	/*
	 * Don't bother to queue an event if the mask was previously non-zero
	 * since an event must still be on the queue.
	 */

	if (filePtr->readyMask == 0) {
	    FileHandlerEvent *fileEvPtr = (FileHandlerEvent *)
		    Tcl_Alloc(sizeof(FileHandlerEvent));

	    fileEvPtr->header.proc = FileHandlerEventProc;
	    fileEvPtr->fd = filePtr->fd;
	    Tcl_QueueEvent((Tcl_Event *) fileEvPtr, TCL_QUEUE_TAIL);
	}
	filePtr->readyMask = mask;
    }
    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TclAsyncNotifier --
 *
 *	This procedure sets the async mark of an async handler to a
 *	given value, if it is called from the target thread.
 *
 * Result:
 *	True, when the handler will be marked, false otherwise.
 *
 * Side effects:
 *	The signal may be resent to the target thread.
 *
 *----------------------------------------------------------------------
 */

int
TclAsyncNotifier(
    int sigNumber,		/* Signal number. */
    Tcl_ThreadId threadId,	/* Target thread. */
    void *clientData,		/* Notifier data. */
    int *flagPtr,		/* Flag to mark. */
    int value)			/* Value of mark. */
{
#if TCL_THREADS
    /*
     * WARNING:
     * This code most likely runs in a signal handler. Thus,
     * only few async-signal-safe system calls are allowed,
     * e.g. pthread_self(), sem_post(), write().
     */

    if (pthread_equal(pthread_self(), (pthread_t) threadId)) {
	ThreadSpecificData *tsdPtr = (ThreadSpecificData *) clientData;

	*flagPtr = value;
	if (tsdPtr != NULL && !tsdPtr->asyncPending) {
	    tsdPtr->asyncPending = 1;
	    TclpAlertNotifier(tsdPtr);
	    return 1;
	}
	return 0;
    }

    /*
     * Re-send the signal to the proper target thread.
     */

    pthread_kill((pthread_t) threadId, sigNumber);
#else
    (void)sigNumber;
    (void)threadId;
    (void)clientData;
    (void)flagPtr;
    (void)value;
#endif
    return 0;
}

#endif /* NOTIFIER_EPOLL && TCL_THREADS */
#else
TCL_MAC_EMPTY_FILE(unix_tclEpollNotfy_c)
#endif /* !HAVE_COREFOUNDATION */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

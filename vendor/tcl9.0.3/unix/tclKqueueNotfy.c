/*
 * tclKqueueNotfy.c --
 *
 *	This file contains the implementation of the kqueue()-based
 *	DragonFly/Free/Net/OpenBSD-specific notifier, which is the lowest-
 *	level part of the Tcl event loop. This file works together with
 *	generic/tclNotify.c.
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
#if defined(NOTIFIER_KQUEUE) && TCL_THREADS

#include <signal.h>
#include <sys/types.h>
#include <sys/event.h>
#include <sys/queue.h>
#include <sys/time.h>

/*
 * This structure is used to keep track of the notifier info for a registered
 * file.
 */

struct PlatformEventData;
typedef struct FileHandler {
    int fd;			/* File descriptor that this is describing a
				 * handler for. */
    int mask;			/* Mask of desired events: TCL_READABLE,
				 * etc. */
    int readyMask;		/* Mask of events that have been seen since
				 * the last time file handlers were invoked
				 * for this file. */
    Tcl_FileProc *proc;		/* Function to call, in the style of
				 * Tcl_CreateFileHandler. */
    void *clientData;	/* Argument to pass to proc. */
    struct FileHandler *nextPtr;/* Next in list of all files we care about. */
    LIST_ENTRY(FileHandler) readyNode;
				/* Next/previous in list of FileHandlers asso-
				 * ciated with regular files (S_IFREG) that are
				 * ready for I/O. */
    struct PlatformEventData *pedPtr;
				/* Pointer to PlatformEventData associating this
				 * FileHandler with kevent(2) events. */
} FileHandler;

/*
 * The following structure associates a FileHandler and the thread that owns
 * it with the file descriptors of interest and their event masks passed to
 * kevent(2) and their corresponding event(s) returned by kevent(2).
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
 * kqueue based implementation of the Tcl notifier. One of these structures is
 * created for each thread that is using the notifier.
 */

LIST_HEAD(PlatformReadyFileHandlerList, FileHandler);
typedef struct ThreadSpecificData {
    FileHandler *firstFileHandlerPtr;
				/* Pointer to head of file handler list. */
    struct PlatformReadyFileHandlerList firstReadyFileHandlerPtr;
				/* Pointer to head of list of FileHandlers
				 * associated with regular files (S_IFREG)
				 * that are ready for I/O. */
    pthread_mutex_t notifierMutex;
				/* Mutex protecting notifier termination in
				 * TclpFinalizeNotifier. */
    int triggerPipe[2];		/* pipe(2) used by other threads to wake
				 * up this thread for inter-thread IPC. */
    int eventsFd;		/* kqueue(2) file descriptor used to wait for
				 * fds. */
    struct kevent *readyEvents;	/* Pointer to at most maxReadyEvents events
				 * returned by kevent(2). */
    size_t maxReadyEvents;	/* Count of kevents in readyEvents. */
    int asyncPending;		/* True when signal triggered thread. */
} ThreadSpecificData;

static Tcl_ThreadDataKey dataKey;

/*
 * Forward declarations of internal functions.
 */

static void		PlatformEventsControl(FileHandler *filePtr,
			    ThreadSpecificData *tsdPtr, int op, int isNew);
static int		PlatformEventsTranslate(struct kevent *eventPtr);
static int		PlatformEventsWait(struct kevent *events,
			    size_t numEvents, struct timeval *timePtr);

/*
 * Incorporate the base notifier implementation.
 */

#include "tclUnixNotfy.c"

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsControl --
 *
 *	This function registers interest for the file descriptor and the mask
 *	of TCL_* bits associated with filePtr on the kqueue file descriptor
 *	associated with tsdPtr.
 *
 *	Future calls to kevent will return filePtr and tsdPtr alongside with
 *	the event registered here via the PlatformEventData struct.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	- If adding a new file descriptor, a PlatformEventData struct will be
 *	  allocated and associated with filePtr.
 *	- fstat is called on the file descriptor; if it is associated with
 *	  a regular file (S_IFREG,) filePtr is considered to be ready for I/O
 *	  and added to or deleted from the corresponding list in tsdPtr.
 *	- If it is not associated with a regular file, the file descriptor is
 *	  added, modified concerning its mask of events of interest, or
 *	  deleted from the epoll file descriptor of the calling thread.
 *	- If deleting a file descriptor, kevent(2) is called twice specifying
 *	  EVFILT_READ first and then EVFILT_WRITE (see note below.)
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
    int numChanges;
    struct kevent changeList[2];
    struct PlatformEventData *newPedPtr;
    Tcl_StatBuf fdStat;

    if (isNew) {
	newPedPtr = (struct PlatformEventData *)
		Tcl_Alloc(sizeof(struct PlatformEventData));
	newPedPtr->filePtr = filePtr;
	newPedPtr->tsdPtr = tsdPtr;
	filePtr->pedPtr = newPedPtr;
    }

    /*
     * N.B. As discussed in Tcl_WaitForEvent(), kqueue(2) does not reproduce
     * the `always ready' {select,poll}(2) behaviour for regular files
     * (S_IFREG) prior to FreeBSD 11.0-RELEASE. Therefore, filePtr is in these
     * cases simply added or deleted from the list of FileHandlers associated
     * with regular files belonging to tsdPtr.
     */

    if (TclOSfstat(filePtr->fd, &fdStat) == -1) {
	Tcl_Panic("fstat: %s", strerror(errno));
    } else if ((fdStat.st_mode & S_IFMT) == S_IFREG
	    || (fdStat.st_mode & S_IFMT) == S_IFDIR
	    || (fdStat.st_mode & S_IFMT) == S_IFLNK) {
	switch (op) {
	case EV_ADD:
	    if (isNew) {
		LIST_INSERT_HEAD(&tsdPtr->firstReadyFileHandlerPtr, filePtr,
			readyNode);
	    }
	    break;
	case EV_DELETE:
	    LIST_REMOVE(filePtr, readyNode);
	    break;
	}
	return;
    }

    numChanges = 0;
    switch (op) {
    case EV_ADD:
	if (filePtr->mask & (TCL_READABLE | TCL_EXCEPTION)) {
	    EV_SET(&changeList[numChanges], (uintptr_t) filePtr->fd,
		    EVFILT_READ, op, 0, 0, filePtr->pedPtr);
	    numChanges++;
	}
	if (filePtr->mask & TCL_WRITABLE) {
	    EV_SET(&changeList[numChanges], (uintptr_t) filePtr->fd,
		    EVFILT_WRITE, op, 0, 0, filePtr->pedPtr);
	    numChanges++;
	}
	if (numChanges) {
	    if (kevent(tsdPtr->eventsFd, changeList, numChanges, NULL, 0,
		    NULL) == -1) {
		Tcl_Panic("kevent: %s", strerror(errno));
	    }
	}
	break;
    case EV_DELETE:
	/*
	 * N.B. kqueue(2) has separate filters for readability and writability
	 * fd events. We therefore need to ensure that fds are ompletely
	 * removed from the kqueue(2) fd when deleting.  This is exacerbated
	 * by changes to filePtr->mask w/o calls to PlatforEventsControl()
	 * after e.g. an exec(3) in a child process.
	 *
	 * As one of these calls can fail, two separate kevent(2) calls are
	 * made for EVFILT_{READ,WRITE}.
	 */
	EV_SET(&changeList[0], (uintptr_t) filePtr->fd, EVFILT_READ, op, 0, 0,
		NULL);
	if ((kevent(tsdPtr->eventsFd, changeList, 1, NULL, 0, NULL) == -1)
		&& (errno != ENOENT)) {
	    Tcl_Panic("kevent: %s", strerror(errno));
	}
	EV_SET(&changeList[0], (uintptr_t) filePtr->fd, EVFILT_WRITE, op, 0, 0,
		NULL);
	if ((kevent(tsdPtr->eventsFd, changeList, 1, NULL, 0, NULL) == -1)
		&& (errno != ENOENT)) {
	    Tcl_Panic("kevent: %s", strerror(errno));
	}
	break;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFinalizeNotifier --
 *
 *	This function closes the pipe and the kqueue file descriptors and
 *	frees the kevent structs owned by the thread of the caller.  The above
 *	operations are protected by tsdPtr->notifierMutex, which is destroyed
 *	thereafter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	While tsdPtr->notifierMutex is held:
 *	The per-thread pipe(2) fds are closed, if non-zero, and set to -1.
 *	The per-thread kqueue(2) fd is closed, if non-zero, and set to 0.
 *	The per-thread kevent structs are freed, if any, and set to 0.
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
    if (tsdPtr->triggerPipe[0]) {
	close(tsdPtr->triggerPipe[0]);
	tsdPtr->triggerPipe[0] = -1;
    }
    if (tsdPtr->triggerPipe[1]) {
	close(tsdPtr->triggerPipe[1]);
	tsdPtr->triggerPipe[1] = -1;
    }
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
 * TclpInitNotifier --
 *
 *	Initializes the platform specific notifier state.
 *
 *	This function abstracts creating a kqueue fd via the kqueue system
 *	call and allocating memory for the kevents structs in tsdPtr for the
 *	thread of the caller.
 *
 * Results:
 *	Returns a handle to the notifier state for this thread.
 *
 * Side effects:
 *	The following per-thread entities are initialised:
 *	- notifierMutex is initialised.
 *	- The pipe(2) is created; fcntl(2) is called on both fds to set
 *	  FD_CLOEXEC and O_NONBLOCK.
 *	- The kqueue(2) fd is created; fcntl(2) is called on it to set
 *	  FD_CLOEXEC.
 *	- A FileHandler struct is allocated and initialised for the event-
 *	  fd(2), registering interest for TCL_READABLE on it via Platform-
 *	  EventsControl().
 *	- readyEvents and maxReadyEvents are initialised with 512 kevents.
 *
 *----------------------------------------------------------------------
 */

void *
TclpInitNotifier(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    int i, fdFl;
    FileHandler *filePtr;

    errno = pthread_mutex_init(&tsdPtr->notifierMutex, NULL);
    if (errno) {
	Tcl_Panic("Tcl_InitNotifier: %s", "could not create mutex");
    }
    if (pipe(tsdPtr->triggerPipe) != 0) {
	Tcl_Panic("Tcl_InitNotifier: %s", "could not create trigger pipe");
    } else for (i = 0; i < 2; i++) {
	if (fcntl(tsdPtr->triggerPipe[i], F_SETFD, FD_CLOEXEC) == -1) {
	    Tcl_Panic("fcntl: %s", strerror(errno));
	} else {
	    fdFl = fcntl(tsdPtr->triggerPipe[i], F_GETFL);
	    fdFl |= O_NONBLOCK;
	}
	if (fcntl(tsdPtr->triggerPipe[i], F_SETFL, fdFl) == -1) {
	    Tcl_Panic("fcntl: %s", strerror(errno));
	}
    }
    if ((tsdPtr->eventsFd = kqueue()) == -1) {
	Tcl_Panic("kqueue: %s", strerror(errno));
    } else if (fcntl(tsdPtr->eventsFd, F_SETFD, FD_CLOEXEC) == -1) {
	Tcl_Panic("fcntl: %s", strerror(errno));
    }
    filePtr = (FileHandler *) Tcl_Alloc(sizeof(FileHandler));
    filePtr->fd = tsdPtr->triggerPipe[0];
    filePtr->mask = TCL_READABLE;
    PlatformEventsControl(filePtr, tsdPtr, EV_ADD, 1);
    if (!tsdPtr->readyEvents) {
	tsdPtr->maxReadyEvents = 512;
	tsdPtr->readyEvents = (struct kevent *) Tcl_Alloc(
		tsdPtr->maxReadyEvents * sizeof(tsdPtr->readyEvents[0]));
    }
    LIST_INIT(&tsdPtr->firstReadyFileHandlerPtr);

    return tsdPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsTranslate --
 *
 *	This function translates the platform-specific mask of returned
 *	events in eventPtr to a mask of TCL_* bits.
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
    struct kevent *eventPtr)
{
    int mask;

    mask = 0;
    if (eventPtr->filter == EVFILT_READ) {
	mask |= TCL_READABLE;
	if (eventPtr->flags & EV_ERROR) {
	    mask |= TCL_EXCEPTION;
	}
    }
    if (eventPtr->filter == EVFILT_WRITE) {
	mask |= TCL_WRITABLE;
	if (eventPtr->flags & EV_ERROR) {
	    mask |= TCL_EXCEPTION;
	}
    }
    return mask;
}

/*
 *----------------------------------------------------------------------
 *
 * PlatformEventsWait --
 *
 *	This function abstracts waiting for I/O events via the kevent system
 *	call.
 *
 * Results:
 *	Returns -1 if kevent failed. Returns 0 if polling and if no events
 *	became available whilst polling. Returns a pointer to and the count of
 *	all returned events in all other cases.
 *
 * Side effects:
 *	gettimeofday(2), kevent(2), and gettimeofday(2) are called, in the
 *	specified order.
 *	If timePtr specifies a positive value, it is updated to reflect the
 *	amount of time that has passed; if its value would {under, over}flow,
 *	it is set to zero.
 *
 *----------------------------------------------------------------------
 */

static int
PlatformEventsWait(
    struct kevent *events,
    size_t numEvents,
    struct timeval *timePtr)
{
    int numFound;
    struct timeval tv0, tv1, tv_delta;
    struct timespec timeout, *timeoutPtr;

    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * If timePtr is NULL, kevent(2) will wait indefinitely. If it specifies a
     * timeout of {0,0}, kevent(2) will poll. Otherwise, the timeout will
     * simply be converted to a timespec.
     */

    if (!timePtr) {
	timeoutPtr = NULL;
    } else if (!timePtr->tv_sec && !timePtr->tv_usec) {
	timeout.tv_sec = 0;
	timeout.tv_nsec = 0;
	timeoutPtr = &timeout;
    } else {
	timeout.tv_sec = timePtr->tv_sec;
	timeout.tv_nsec = timePtr->tv_usec * 1000;
	timeoutPtr = &timeout;
    }

    /*
     * Call (and possibly block on) kevent(2) and substract the delta of
     * gettimeofday(2) before and after the call from timePtr if the latter is
     * not NULL. Return the number of events returned by kevent(2).
     */

    gettimeofday(&tv0, NULL);
    numFound = kevent(tsdPtr->eventsFd, NULL, 0, events, (int) numEvents,
	    timeoutPtr);
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
 *	This function registers a file handler with the kqueue notifier
 *	of the thread of the caller.
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
    void *clientData)	/* Arbitrary data to pass to proc. */
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

    PlatformEventsControl(filePtr, tsdPtr, EV_ADD, isNew);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpDeleteFileHandler --
 *
 *	Cancel a previously-arranged callback arrangement for a file on the
 *	kqueue of the thread of the caller.
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
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    FileHandler *filePtr, *prevPtr;

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

    PlatformEventsControl(filePtr, tsdPtr, EV_DELETE, 0);
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
    int mask;
    Tcl_Time vTime;
    struct timeval timeout, *timeoutPtr;
				/* Impl. notes: timeout & timeoutPtr are used
				 * if, and only if threads are not enabled.
				 * They are the arguments for the regular
				 * epoll_wait() used when the core is not
				 * thread-enabled. */
    int numFound, numEvent;
    struct PlatformEventData *pedPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    int numQueued;
    ssize_t i;
    char buf[1];

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
     * kqueue(2), unlike epoll(7), does support regular files, but EVFILT_READ
     * only `[r]eturns when the file pointer is not at the end of file' as
     * opposed to unconditionally. While FreeBSD 11.0-RELEASE adds support for
     * this mode (NOTE_FILE_POLL,) this is not used for reasons of
     * compatibility.
     *
     * Therefore, the behaviour of {select,poll}(2) is simply simulated here:
     * fds associated with regular files are added to this list by
     * PlatformEventsControl() and processed here before calling (and possibly
     * blocking) on PlatformEventsWait().
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
     * Events for the trigger pipe are processed here in order to facilitate
     * inter-thread IPC. If another thread intends to wake up this thread
     * whilst it's blocking on PlatformEventsWait(), it write(2)s to the other
     * end of the pipe (see Tcl_AlertNotifier(),) which in turn will cause
     * PlatformEventsWait() to return immediately.
     */

    numFound = PlatformEventsWait(tsdPtr->readyEvents,
	    tsdPtr->maxReadyEvents, timeoutPtr);
    for (numEvent = 0; numEvent < numFound; numEvent++) {
	pedPtr = (struct PlatformEventData *)
		tsdPtr->readyEvents[numEvent].udata;
	filePtr = pedPtr->filePtr;
	mask = PlatformEventsTranslate(&tsdPtr->readyEvents[numEvent]);
	if (filePtr->fd == tsdPtr->triggerPipe[0]) {
	    i = read(tsdPtr->triggerPipe[0], buf, 1);
	    if ((i == -1) && (errno != EAGAIN)) {
		Tcl_Panic("Tcl_WaitForEvent: read from %p->triggerPipe: %s",
			tsdPtr, strerror(errno));
	    }
	    continue;
	}
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
	filePtr->readyMask |= mask;
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
    void *clientData,	/* Notifier data. */
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

#endif /* NOTIFIER_KQUEUE && TCL_THREADS */
#else
TCL_MAC_EMPTY_FILE(unix_tclKqueueNotfy_c)
#endif /* !HAVE_COREFOUNDATION */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

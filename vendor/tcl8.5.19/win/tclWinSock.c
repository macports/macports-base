/*
 * tclWinSock.c --
 *
 *	This file contains Windows-specific socket related code.
 *
 * Copyright (c) 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * -----------------------------------------------------------------------
 *
 * General information on how this module works.
 *
 * - Each Tcl-thread with its sockets maintains an internal window to receive
 *   socket messages from the OS.
 *
 * - To ensure that message reception is always running this window is
 *   actually owned and handled by an internal thread. This we call the
 *   co-thread of Tcl's thread.
 *
 * - The whole structure is set up by InitSockets() which is called for each
 *   Tcl thread. The implementation of the co-thread is in SocketThread(),
 *   and the messages are handled by SocketProc(). The connection between
 *   both is not directly visible, it is done through a Win32 window class.
 *   This class is initialized by InitSockets() as well, and used in the
 *   creation of the message receiver windows.
 *
 * - An important thing to note is that *both* thread and co-thread have
 *   access to the list of sockets maintained in the private TSD data of the
 *   thread. The co-thread was given access to it upon creation through the
 *   new thread's client-data.
 *
 *   Because of this dual access the TSD data contains an OS mutex, the
 *   "socketListLock", to mediate exclusion between thread and co-thread.
 *
 *   The co-thread's access is all in SocketProc(). The thread's access is
 *   through SocketEventProc() (1) and the functions called by it.
 *
 *   (Ad 1) This is the handler function for all queued socket events, which
 *          all the OS messages are translated to through the EventSource (2)
 *          driven by the OS messages.
 *
 *   (Ad 2) The main functions for this are SocketSetupProc() and
 *          SocketCheckProc().
 */

#include "tclWinInt.h"

#ifdef _MSC_VER
#   pragma comment (lib, "ws2_32")
#endif

/*
 * Support for control over sockets' KEEPALIVE and NODELAY behavior is
 * currently disabled.
 */

#undef TCL_FEATURE_KEEPALIVE_NAGLE

/*
 * Make sure to remove the redirection defines set in tclWinPort.h that is in
 * use in other sections of the core, except for us.
 */

#undef getservbyname
#undef getsockopt
#undef setsockopt

/*
 * The following variable is used to tell whether this module has been
 * initialized.  If 1, initialization of sockets was successful, if -1 then
 * socket initialization failed (WSAStartup failed).
 */

static int initialized = 0;
TCL_DECLARE_MUTEX(socketMutex)

/*
 * The following variable holds the network name of this host.
 */

static TclInitProcessGlobalValueProc InitializeHostName;
static ProcessGlobalValue hostName = {
    0, 0, NULL, NULL, InitializeHostName, NULL, NULL
};

/*
 * The following defines declare the messages used on socket windows.
 */

#define SOCKET_MESSAGE	    WM_USER+1
#define SOCKET_SELECT	    WM_USER+2
#define SOCKET_TERMINATE    WM_USER+3
#define SELECT		    TRUE
#define UNSELECT	    FALSE

/*
 * The following structure is used to store the data associated with each
 * socket.
 * All members modified by the notifier thread are defined as volatile.
 */

typedef struct SocketInfo {
    Tcl_Channel channel;	/* Channel associated with this socket. */
    SOCKET socket;		/* Windows SOCKET handle. */
    volatile int flags;		/* Bit field comprised of the flags described
				 * below. */
    int watchEvents;		/* OR'ed combination of FD_READ, FD_WRITE,
				 * FD_CLOSE, FD_ACCEPT and FD_CONNECT that
				 * indicate which events are interesting. */
    volatile int readyEvents;	/* OR'ed combination of FD_READ, FD_WRITE,
				 * FD_CLOSE, FD_ACCEPT and FD_CONNECT that
				 * indicate which events have occurred. */
    int selectEvents;		/* OR'ed combination of FD_READ, FD_WRITE,
				 * FD_CLOSE, FD_ACCEPT and FD_CONNECT that
				 * indicate which events are currently being
				 * selected. */
    volatile int acceptEventCount;
				/* Count of the current number of FD_ACCEPTs
				 * that have arrived and not yet processed. */
    Tcl_TcpAcceptProc *acceptProc;
				/* Proc to call on accept. */
    ClientData acceptProcData;	/* The data for the accept proc. */
    volatile int lastError;	/* Error code from last message. */
    struct SocketInfo *nextPtr;	/* The next socket on the per-thread socket
				 * list. */
} SocketInfo;

/*
 * The following structure is what is added to the Tcl event queue when a
 * socket event occurs.
 */

typedef struct {
    Tcl_Event header;		/* Information that is standard for all
				 * events. */
    SOCKET socket;		/* Socket descriptor that is ready. Used to
				 * find the SocketInfo structure for the file
				 * (can't point directly to the SocketInfo
				 * structure because it could go away while
				 * the event is queued). */
} SocketEvent;

/*
 * This defines the minimum buffersize maintained by the kernel.
 */

#define TCP_BUFFER_SIZE 4096

/*
 * The following macros may be used to set the flags field of a SocketInfo
 * structure.
 */

#define SOCKET_ASYNC		(1<<0)	/* The socket is in blocking mode. */
#define SOCKET_EOF		(1<<1)	/* A zero read happened on the
					 * socket. */
#define SOCKET_ASYNC_CONNECT	(1<<2)	/* This socket uses async connect. */
#define SOCKET_PENDING		(1<<3)	/* A message has been sent for this
					 * socket */

typedef struct {
    HWND hwnd;			/* Handle to window for socket messages. */
    HANDLE socketThread;	/* Thread handling the window */
    Tcl_ThreadId threadId;	/* Parent thread. */
    HANDLE readyEvent;		/* Event indicating that a socket event is
				 * ready. Also used to indicate that the
				 * socketThread has been initialized and has
				 * started. */
    HANDLE socketListLock;	/* Win32 Event to lock the socketList */
    SocketInfo *pendingSocketInfo;
				/* This socket is opened but not jet in the
				 * list. This value is also checked by
				 * the event structure. */
    SocketInfo *socketList;	/* Every open socket in this thread has an
				 * entry on this list. */
} ThreadSpecificData;

static Tcl_ThreadDataKey dataKey;
static WNDCLASS windowClass;

/*
 * Static functions defined in this file.
 */

static SocketInfo *	CreateSocket(Tcl_Interp *interp, int port,
			    const char *host, int server, const char *myaddr,
			    int myport, int async);
static int		CreateSocketAddress(LPSOCKADDR_IN sockaddrPtr,
			    const char *host, int port);
static void		InitSockets(void);
static SocketInfo *	NewSocketInfo(SOCKET socket);
static void		SocketExitHandler(ClientData clientData);
static LRESULT CALLBACK	SocketProc(HWND hwnd, UINT message, WPARAM wParam,
			    LPARAM lParam);
static int		SocketsEnabled(void);
static void		TcpAccept(SocketInfo *infoPtr);
static int		WaitForSocketEvent(SocketInfo *infoPtr, int events,
			    int *errorCodePtr);
static DWORD WINAPI	SocketThread(LPVOID arg);
static void		TcpThreadActionProc(ClientData instanceData,
			    int action);

static Tcl_EventCheckProc	SocketCheckProc;
static Tcl_EventProc		SocketEventProc;
static Tcl_EventSetupProc	SocketSetupProc;
static Tcl_DriverBlockModeProc	TcpBlockProc;
static Tcl_DriverCloseProc	TcpCloseProc;
static Tcl_DriverSetOptionProc	TcpSetOptionProc;
static Tcl_DriverGetOptionProc	TcpGetOptionProc;
static Tcl_DriverInputProc	TcpInputProc;
static Tcl_DriverOutputProc	TcpOutputProc;
static Tcl_DriverWatchProc	TcpWatchProc;
static Tcl_DriverGetHandleProc	TcpGetHandleProc;

/*
 * This structure describes the channel type structure for TCP socket
 * based IO.
 */

static Tcl_ChannelType tcpChannelType = {
    "tcp",		    /* Type name. */
    TCL_CHANNEL_VERSION_5,  /* v5 channel */
    TcpCloseProc,	    /* Close proc. */
    TcpInputProc,	    /* Input proc. */
    TcpOutputProc,	    /* Output proc. */
    NULL,		    /* Seek proc. */
    TcpSetOptionProc,	    /* Set option proc. */
    TcpGetOptionProc,	    /* Get option proc. */
    TcpWatchProc,	    /* Set up notifier to watch this channel. */
    TcpGetHandleProc,	    /* Get an OS handle from channel. */
    NULL,		    /* close2proc. */
    TcpBlockProc,	    /* Set socket into (non-)blocking mode. */
    NULL,		    /* flush proc. */
    NULL,		    /* handler proc. */
    NULL,		    /* wide seek proc */
    TcpThreadActionProc,    /* thread action proc */
    NULL,		    /* truncate */
};

/*
 *----------------------------------------------------------------------
 *
 * InitSockets --
 *
 *	Initialize the socket module.  If winsock startup is successful,
 *	registers the event window for the socket notifier code.
 *
 *	Assumes socketMutex is held.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Initializes winsock, registers a new window class and creates a
 *	window for use in asynchronous socket notification.
 *
 *----------------------------------------------------------------------
 */

static void
InitSockets(void)
{
    DWORD id;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    if (!initialized) {
	initialized = 1;
	TclCreateLateExitHandler(SocketExitHandler, (ClientData) NULL);

	/*
	 * Create the async notification window with a new class. We must
	 * create a new class to avoid a Windows 95 bug that causes us to get
	 * the wrong message number for socket events if the message window is
	 * a subclass of a static control.
	 */

	windowClass.style = 0;
	windowClass.cbClsExtra = 0;
	windowClass.cbWndExtra = 0;
	windowClass.hInstance = TclWinGetTclInstance();
	windowClass.hbrBackground = NULL;
	windowClass.lpszMenuName = NULL;
	windowClass.lpszClassName = "TclSocket";
	windowClass.lpfnWndProc = SocketProc;
	windowClass.hIcon = NULL;
	windowClass.hCursor = NULL;

	if (!RegisterClassA(&windowClass)) {
	    TclWinConvertError(GetLastError());
	    goto initFailure;
	}

    }

    /*
     * Check for per-thread initialization.
     */

    if (tsdPtr == NULL) {
	tsdPtr = TCL_TSD_INIT(&dataKey);
	tsdPtr->pendingSocketInfo = NULL;
	tsdPtr->socketList = NULL;
	tsdPtr->hwnd       = NULL;
	tsdPtr->threadId   = Tcl_GetCurrentThread();
	tsdPtr->readyEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
	if (tsdPtr->readyEvent == NULL) {
	    goto initFailure;
	}
	tsdPtr->socketListLock = CreateEvent(NULL, FALSE, TRUE, NULL);
	if (tsdPtr->socketListLock == NULL) {
	    goto initFailure;
	}
	tsdPtr->socketThread = CreateThread(NULL, 256, SocketThread, tsdPtr,
		0, &id);
	if (tsdPtr->socketThread == NULL) {
	    goto initFailure;
	}

	SetThreadPriority(tsdPtr->socketThread, THREAD_PRIORITY_HIGHEST);

	/*
	 * Wait for the thread to signal when the window has been created and
	 * if it is ready to go.
	 */

	WaitForSingleObject(tsdPtr->readyEvent, INFINITE);

	if (tsdPtr->hwnd == NULL) {
	    goto initFailure; /* Trouble creating the window */
	}

	Tcl_CreateEventSource(SocketSetupProc, SocketCheckProc, NULL);
    }
    return;

  initFailure:
    TclpFinalizeSockets();
    initialized = -1;
    return;
}

/*
 *----------------------------------------------------------------------
 *
 * SocketsEnabled --
 *
 *	Check that the WinSock was successfully initialized.
 *
 * Results:
 *	1 if it is.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

    /* ARGSUSED */
static int
SocketsEnabled(void)
{
    int enabled;
    Tcl_MutexLock(&socketMutex);
    enabled = (initialized == 1);
    Tcl_MutexUnlock(&socketMutex);
    return enabled;
}


/*
 *----------------------------------------------------------------------
 *
 * SocketExitHandler --
 *
 *	Callback invoked during exit clean up to delete the socket
 *	communication window and to release the WinSock DLL.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

    /* ARGSUSED */
static void
SocketExitHandler(
    ClientData clientData)		/* Not used. */
{
    Tcl_MutexLock(&socketMutex);
    /*
     * Make sure the socket event handling window is cleaned-up for, at
     * most, this thread.
     */

    TclpFinalizeSockets();
    UnregisterClass("TclSocket", TclWinGetTclInstance());
    initialized = 0;
    Tcl_MutexUnlock(&socketMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * TclpFinalizeSockets --
 *
 *	This function is called from Tcl_FinalizeThread to finalize the
 *	platform specific socket subsystem. Also, it may be called from within
 *	this module to cleanup the state if unable to initialize the sockets
 *	subsystem.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Deletes the event source and destroys the socket thread.
 *
 *----------------------------------------------------------------------
 */

void
TclpFinalizeSockets(void)
{
    ThreadSpecificData *tsdPtr;

    tsdPtr = (ThreadSpecificData *) TclThreadDataKeyGet(&dataKey);
    if (tsdPtr != NULL) {
	if (tsdPtr->socketThread != NULL) {
	    if (tsdPtr->hwnd != NULL) {
		if (PostMessage(tsdPtr->hwnd, SOCKET_TERMINATE, 0, 0)) {
		    /*
		     * Wait for the thread to exit. This ensures that we are
		     * completely cleaned up before we leave this function.
		     */
		    WaitForSingleObject(tsdPtr->readyEvent, INFINITE);
		}
		tsdPtr->hwnd = NULL;
	    }
	    CloseHandle(tsdPtr->socketThread);
	    tsdPtr->socketThread = NULL;
	}
	if (tsdPtr->readyEvent != NULL) {
	    CloseHandle(tsdPtr->readyEvent);
	    tsdPtr->readyEvent = NULL;
	}
	if (tsdPtr->socketListLock != NULL) {
	    CloseHandle(tsdPtr->socketListLock);
	    tsdPtr->socketListLock = NULL;
	}
	Tcl_DeleteEventSource(SocketSetupProc, SocketCheckProc, NULL);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclpHasSockets --
 *
 *	This function determines whether sockets are available on the current
 *	system and returns an error in interp if they are not. Note that
 *	interp may be NULL.
 *
 * Results:
 *	Returns TCL_OK if the system supports sockets, or TCL_ERROR with an
 *	error in interp (if non-NULL).
 *
 * Side effects:
 *	If not already prepared, initializes the TSD structure and socket
 *	message handling thread associated to the calling thread for the
 *	subsystem of the driver.
 *
 *----------------------------------------------------------------------
 */

int
TclpHasSockets(
    Tcl_Interp *interp)		/* Where to write an error message if sockets
				 * are not present, or NULL if no such message
				 * is to be written. */
{
    Tcl_MutexLock(&socketMutex);
    InitSockets();
    Tcl_MutexUnlock(&socketMutex);

    if (SocketsEnabled()) {
	return TCL_OK;
    }
    if (interp != NULL) {
	Tcl_AppendResult(interp, "sockets are not available on this system",
		NULL);
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * SocketSetupProc --
 *
 *	This function is invoked before Tcl_DoOneEvent blocks waiting for an
 *	event.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Adjusts the block time if needed.
 *
 *----------------------------------------------------------------------
 */

void
SocketSetupProc(
    ClientData data,		/* Not used. */
    int flags)			/* Event flags as passed to Tcl_DoOneEvent. */
{
    SocketInfo *infoPtr;
    Tcl_Time blockTime = { 0, 0 };
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    if (!(flags & TCL_FILE_EVENTS)) {
	return;
    }

    /*
     * Check to see if there is a ready socket.	 If so, poll.
     */

    WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
    for (infoPtr = tsdPtr->socketList; infoPtr != NULL;
	    infoPtr = infoPtr->nextPtr) {
	if (infoPtr->readyEvents & infoPtr->watchEvents) {
	    Tcl_SetMaxBlockTime(&blockTime);
	    break;
	}
    }
    SetEvent(tsdPtr->socketListLock);
}

/*
 *----------------------------------------------------------------------
 *
 * SocketCheckProc --
 *
 *	This function is called by Tcl_DoOneEvent to check the socket event
 *	source for events.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May queue an event.
 *
 *----------------------------------------------------------------------
 */

static void
SocketCheckProc(
    ClientData data,		/* Not used. */
    int flags)			/* Event flags as passed to Tcl_DoOneEvent. */
{
    SocketInfo *infoPtr;
    SocketEvent *evPtr;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    if (!(flags & TCL_FILE_EVENTS)) {
	return;
    }

    /*
     * Queue events for any ready sockets that don't already have events
     * queued (caused by persistent states that won't generate WinSock
     * events).
     */

    WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
    for (infoPtr = tsdPtr->socketList; infoPtr != NULL;
	    infoPtr = infoPtr->nextPtr) {
	if ((infoPtr->readyEvents & infoPtr->watchEvents)
		&& !(infoPtr->flags & SOCKET_PENDING)) {
	    infoPtr->flags |= SOCKET_PENDING;
	    evPtr = (SocketEvent *) ckalloc(sizeof(SocketEvent));
	    evPtr->header.proc = SocketEventProc;
	    evPtr->socket = infoPtr->socket;
	    Tcl_QueueEvent((Tcl_Event *) evPtr, TCL_QUEUE_TAIL);
	}
    }
    SetEvent(tsdPtr->socketListLock);
}

/*
 *----------------------------------------------------------------------
 *
 * SocketEventProc --
 *
 *	This function is called by Tcl_ServiceEvent when a socket event
 *	reaches the front of the event queue. This function is responsible for
 *	notifying the generic channel code.
 *
 * Results:
 *	Returns 1 if the event was handled, meaning it should be removed from
 *	the queue. Returns 0 if the event was not handled, meaning it should
 *	stay on the queue. The only time the event isn't handled is if the
 *	TCL_FILE_EVENTS flag bit isn't set.
 *
 * Side effects:
 *	Whatever the channel callback functions do.
 *
 *----------------------------------------------------------------------
 */

static int
SocketEventProc(
    Tcl_Event *evPtr,		/* Event to service. */
    int flags)			/* Flags that indicate what events to handle,
				 * such as TCL_FILE_EVENTS. */
{
    SocketInfo *infoPtr;
    SocketEvent *eventPtr = (SocketEvent *) evPtr;
    int mask = 0;
    int events;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    if (!(flags & TCL_FILE_EVENTS)) {
	return 0;
    }

    /*
     * Find the specified socket on the socket list.
     */

    WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
    for (infoPtr = tsdPtr->socketList; infoPtr != NULL;
	    infoPtr = infoPtr->nextPtr) {
	if (infoPtr->socket == eventPtr->socket) {
	    break;
	}
    }
    SetEvent(tsdPtr->socketListLock);

    /*
     * Discard events that have gone stale.
     */

    if (!infoPtr) {
	return 1;
    }

    infoPtr->flags &= ~SOCKET_PENDING;

    /*
     * Handle connection requests directly.
     */

    if (infoPtr->readyEvents & FD_ACCEPT) {
	TcpAccept(infoPtr);
	return 1;
    }

    /*
     * Mask off unwanted events and compute the read/write mask so we can
     * notify the channel.
     */

    events = infoPtr->readyEvents & infoPtr->watchEvents;

    if (events & FD_CLOSE) {
	/*
	 * If the socket was closed and the channel is still interested in
	 * read events, then we need to ensure that we keep polling for this
	 * event until someone does something with the channel. Note that we
	 * do this before calling Tcl_NotifyChannel so we don't have to watch
	 * out for the channel being deleted out from under us. This may cause
	 * a redundant trip through the event loop, but it's simpler than
	 * trying to do unwind protection.
	 */

	Tcl_Time blockTime = { 0, 0 };
	Tcl_SetMaxBlockTime(&blockTime);
	mask |= TCL_READABLE|TCL_WRITABLE;
    } else if (events & FD_READ) {
	/*
	 * Throw the readable event if an async connect failed.
	 */

	if (infoPtr->lastError) {

	    mask |= TCL_READABLE;
	    
	} else {
	    fd_set readFds;
	    struct timeval timeout;

	    /*
	     * We must check to see if data is really available, since someone
	     * could have consumed the data in the meantime. Turn off async
	     * notification so select will work correctly. If the socket is still
	     * readable, notify the channel driver, otherwise reset the async
	     * select handler and keep waiting.
	     */

	    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
		    (WPARAM) UNSELECT, (LPARAM) infoPtr);

	    FD_ZERO(&readFds);
	    FD_SET(infoPtr->socket, &readFds);
	    timeout.tv_usec = 0;
	    timeout.tv_sec = 0;

	    if (select(0, &readFds, NULL, NULL, &timeout) != 0) {
		mask |= TCL_READABLE;
	    } else {
		infoPtr->readyEvents &= ~(FD_READ);
		SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
			(WPARAM) SELECT, (LPARAM) infoPtr);
	    }
	}
    }

    /*
     * writable event
     */

    if (events & FD_WRITE) {
	mask |= TCL_WRITABLE;
    }

    if (mask) {
	Tcl_NotifyChannel(infoPtr->channel, mask);
    }
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpBlockProc --
 *
 *	Sets a socket into blocking or non-blocking mode.
 *
 * Results:
 *	0 if successful, errno if there was an error.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TcpBlockProc(
    ClientData instanceData,	/* The socket to block/un-block. */
    int mode)			/* TCL_MODE_BLOCKING or
				 * TCL_MODE_NONBLOCKING. */
{
    SocketInfo *infoPtr = (SocketInfo *) instanceData;

    if (mode == TCL_MODE_NONBLOCKING) {
	infoPtr->flags |= SOCKET_ASYNC;
    } else {
	infoPtr->flags &= ~(SOCKET_ASYNC);
    }
    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpCloseProc --
 *
 *	This function is called by the generic IO level to perform channel
 *	type specific cleanup on a socket based channel when the channel is
 *	closed.
 *
 * Results:
 *	0 if successful, the value of errno if failed.
 *
 * Side effects:
 *	Closes the socket.
 *
 *----------------------------------------------------------------------
 */

    /* ARGSUSED */
static int
TcpCloseProc(
    ClientData instanceData,	/* The socket to close. */
    Tcl_Interp *interp)		/* Unused. */
{
    SocketInfo *infoPtr = (SocketInfo *) instanceData;
    /* TIP #218 */
    int errorCode = 0;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (SocketsEnabled()) {
	/*
	 * Clean up the OS socket handle. The default Windows setting for a
	 * socket is SO_DONTLINGER, which does a graceful shutdown in the
	 * background.
	 */

	if (closesocket(infoPtr->socket) == SOCKET_ERROR) {
	    TclWinConvertWSAError((DWORD) WSAGetLastError());
	    errorCode = Tcl_GetErrno();
	}
    }

    /*
     * Clear an eventual tsd info list pointer.
     * This may be called, if an async socket connect fails or is closed
     * between connect and thread action callback.
     */
    if (tsdPtr->pendingSocketInfo != NULL
	    && tsdPtr->pendingSocketInfo == infoPtr) {

	/* get infoPtr lock, because this concerns the notifier thread */
	WaitForSingleObject(tsdPtr->socketListLock, INFINITE);

	tsdPtr->pendingSocketInfo = NULL;

	/* Free list lock */
	SetEvent(tsdPtr->socketListLock);
    }

    /*
     * TIP #218. Removed the code removing the structure from the global
     * socket list. This is now done by the thread action callbacks, and only
     * there. This happens before this code is called. We can free without
     * fear of damaging the list.
     */

    ckfree((char *) infoPtr);
    return errorCode;
}

/*
 *----------------------------------------------------------------------
 *
 * NewSocketInfo --
 *
 *	This function allocates and initializes a new SocketInfo structure.
 *
 * Results:
 *	Returns a newly allocated SocketInfo.
 *
 * Side effects:
 *	None, except for allocation of memory.
 *
 *----------------------------------------------------------------------
 */

static SocketInfo *
NewSocketInfo(
    SOCKET socket)
{
    SocketInfo *infoPtr;
    /* ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey); */

    infoPtr = (SocketInfo *) ckalloc((unsigned) sizeof(SocketInfo));
    infoPtr->channel = 0;
    infoPtr->socket = socket;
    infoPtr->flags = 0;
    infoPtr->watchEvents = 0;
    infoPtr->readyEvents = 0;
    infoPtr->selectEvents = 0;
    infoPtr->acceptEventCount = 0;
    infoPtr->acceptProc = NULL;
    infoPtr->acceptProcData = NULL;
    infoPtr->lastError = 0;

    /*
     * TIP #218. Removed the code inserting the new structure into the global
     * list. This is now handled in the thread action callbacks, and only
     * there.
     */

    infoPtr->nextPtr = NULL;

    return infoPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * CreateSocket --
 *
 *	This function opens a new socket and initializes the SocketInfo
 *	structure.
 *
 * Results:
 *	Returns a new SocketInfo, or NULL with an error in interp.
 *
 * Side effects:
 *	None, except for allocation of memory.
 *
 *----------------------------------------------------------------------
 */

static SocketInfo *
CreateSocket(
    Tcl_Interp *interp,		/* For error reporting; can be NULL. */
    int port,			/* Port number to open. */
    const char *host,		/* Name of host on which to open port. */
    int server,			/* 1 if socket should be a server socket, else
				 * 0 for a client socket. */
    const char *myaddr,		/* Optional client-side address */
    int myport,			/* Optional client-side port */
    int async)			/* If nonzero, connect client socket
				 * asynchronously. */
{
    u_long flag = 1;		/* Indicates nonblocking mode. */
    SOCKADDR_IN sockaddr;	/* Socket address */
    SOCKADDR_IN mysockaddr;	/* Socket address for client */
    SOCKET sock = INVALID_SOCKET;
    SocketInfo *infoPtr=NULL;	/* The returned value. */
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	return NULL;
    }

    if (!CreateSocketAddress(&sockaddr, host, port)) {
	goto error;
    }
    if ((myaddr != NULL || myport != 0) &&
	    !CreateSocketAddress(&mysockaddr, myaddr, myport)) {
	goto error;
    }

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == INVALID_SOCKET) {
	goto error;
    }

    /*
     * Win-NT has a misfeature that sockets are inherited in child processes
     * by default. Turn off the inherit bit.
     */

    SetHandleInformation((HANDLE) sock, HANDLE_FLAG_INHERIT, 0);

    /*
     * Set kernel space buffering
     */

    TclSockMinimumBuffers((void *)sock, TCP_BUFFER_SIZE);

    if (server) {
	/*
	 * Bind to the specified port. Note that we must not call setsockopt
	 * with SO_REUSEADDR because Microsoft allows addresses to be reused
	 * even if they are still in use.
	 *
	 * Bind should not be affected by the socket having already been set
	 * into nonblocking mode. If there is trouble, this is one place to
	 * look for bugs.
	 */

	if (bind(sock, (SOCKADDR *) &sockaddr, sizeof(SOCKADDR_IN))
		== SOCKET_ERROR) {
	    goto error;
	}

	/*
	 * Set the maximum number of pending connect requests to the max value
	 * allowed on each platform (Win32 and Win32s may be different, and
	 * there may be differences between TCP/IP stacks).
	 */

	if (listen(sock, SOMAXCONN) == SOCKET_ERROR) {
	    goto error;
	}

	/*
	 * Add this socket to the global list of sockets.
	 */

	infoPtr = NewSocketInfo(sock);

	/*
	 * Set up the select mask for connection request events.
	 */

	infoPtr->selectEvents = FD_ACCEPT;
	infoPtr->watchEvents |= FD_ACCEPT;

	/*
	 * Register for interest in events in the select mask. Note that this
	 * automatically places the socket into non-blocking mode.
	 */
    
	ioctlsocket(sock, (long) FIONBIO, &flag);
	SendMessage(tsdPtr->hwnd, SOCKET_SELECT, (WPARAM) SELECT,
		(LPARAM) infoPtr);

    } else {
	/*
	 * Try to bind to a local port, if specified.
	 */

	if (myaddr != NULL || myport != 0) {
	    if (bind(sock, (SOCKADDR *) &mysockaddr, sizeof(SOCKADDR_IN))
		    == SOCKET_ERROR) {
		goto error;
	    }
	}

	/*
	 * Allocate socket info structure
	 */

	infoPtr = NewSocketInfo(sock);

	/*
	 * Set the socket into nonblocking mode if the connect should be done
	 * in the background. Activate connect notification.
	 */

	if (async) {

	    /* get infoPtr lock */
	    WaitForSingleObject(tsdPtr->socketListLock, INFINITE);

	    /*
	     * Buffer new infoPtr in the tsd memory as long as it is not in
	     * the info list. This allows the event procedure to process the
	     * event.
	     * Bugfig for 336441ed59 to not ignore notifications until the
	     * infoPtr is in the list..
	     */

	    tsdPtr->pendingSocketInfo = infoPtr;

	    /*
	     * Set connect mask to connect events
	     * This is activated by a SOCKET_SELECT message to the notifier
	     * thread.
	     */

	    infoPtr->selectEvents |= FD_CONNECT | FD_READ | FD_WRITE | FD_CLOSE;
	    infoPtr->flags |= SOCKET_ASYNC_CONNECT;
	    
	    /*
	     * Free list lock
	     */
	    SetEvent(tsdPtr->socketListLock);

	    /*
	     * Activate accept notification and put in async mode
	     * Bug 336441ed59: activate notification before connect
	     * so we do not miss a notification of a fialed connect.
	     */
	    ioctlsocket(sock, (long) FIONBIO, &flag);
	    SendMessage(tsdPtr->hwnd, SOCKET_SELECT, (WPARAM) SELECT,
	            (LPARAM) infoPtr);

	}

	/*
	 * Attempt to connect to the remote socket.
	 */

	if (connect(sock, (SOCKADDR *) &sockaddr,
		sizeof(SOCKADDR_IN)) == SOCKET_ERROR) {
	    TclWinConvertWSAError((DWORD) WSAGetLastError());
	    if (Tcl_GetErrno() != EWOULDBLOCK) {
		goto error;
	    }

	    /*
	     * The connection is progressing in the background.
	     */

	} else {

	    /*
	     * Set up the select mask for read/write events. If the connect
	     * attempt has not completed, include connect events.
	     */

	    infoPtr->selectEvents = FD_READ | FD_WRITE | FD_CLOSE;

	    /*
	     * Register for interest in events in the select mask. Note that this
	     * automatically places the socket into non-blocking mode.
	     */

	    ioctlsocket(sock, (long) FIONBIO, &flag);
	    SendMessage(tsdPtr->hwnd, SOCKET_SELECT, (WPARAM) SELECT,
		    (LPARAM) infoPtr);
	}
    }

    return infoPtr;

  error:
    TclWinConvertWSAError((DWORD) WSAGetLastError());
    if (interp != NULL) {
	Tcl_AppendResult(interp, "couldn't open socket: ",
		Tcl_PosixError(interp), NULL);
    }
    if (infoPtr != NULL) {
	/*
	 * Free the allocated socket info structure and close the socket
	 */
	TcpCloseProc(infoPtr, interp);
    } else if (sock != INVALID_SOCKET) {
	/*
	 * No socket structure jet - just close
	 */
	closesocket(sock);
    }
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * CreateSocketAddress --
 *
 *	This function initializes a sockaddr structure for a host and port.
 *
 * Results:
 *	1 if the host was valid, 0 if the host could not be converted to an IP
 *	address.
 *
 * Side effects:
 *	Fills in the *sockaddrPtr structure.
 *
 *----------------------------------------------------------------------
 */

static int
CreateSocketAddress(
    LPSOCKADDR_IN sockaddrPtr,	/* Socket address */
    const char *host,		/* Host. NULL implies INADDR_ANY */
    int port)			/* Port number */
{
    struct hostent *hostent;	/* Host database entry */
    struct in_addr addr;	/* For 64/32 bit madness */

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	Tcl_SetErrno(EFAULT);
	return 0;
    }

    ZeroMemory(sockaddrPtr, sizeof(SOCKADDR_IN));
    sockaddrPtr->sin_family = AF_INET;
    sockaddrPtr->sin_port = htons((unsigned short) (port & 0xFFFF));
    if (host == NULL) {
	addr.s_addr = INADDR_ANY;
    } else {
	addr.s_addr = inet_addr(host);
	if (addr.s_addr == INADDR_NONE) {
	    hostent = gethostbyname(host);
	    if (hostent != NULL) {
		memcpy(&addr, hostent->h_addr, (size_t) hostent->h_length);
	    } else {
#ifdef	EHOSTUNREACH
		Tcl_SetErrno(EHOSTUNREACH);
#else
#ifdef ENXIO
		Tcl_SetErrno(ENXIO);
#endif
#endif
		return 0;	/* Error. */
	    }
	}
    }

    /*
     * NOTE: On 64 bit machines the assignment below is rumored to not do the
     * right thing. Please report errors related to this if you observe
     * incorrect behavior on 64 bit machines such as DEC Alphas. Should we
     * modify this code to do an explicit memcpy?
     */

    sockaddrPtr->sin_addr.s_addr = addr.s_addr;
    return 1;			/* Success. */
}

/*
 *----------------------------------------------------------------------
 *
 * WaitForSocketEvent --
 *
 *	Waits until one of the specified events occurs on a socket.
 *
 * Results:
 *	Returns 1 on success or 0 on failure, with an error code in
 *	errorCodePtr.
 *
 * Side effects:
 *	Processes socket events off the system queue.
 *
 *----------------------------------------------------------------------
 */

static int
WaitForSocketEvent(
    SocketInfo *infoPtr,	/* Information about this socket. */
    int events,			/* Events to look for. */
    int *errorCodePtr)		/* Where to store errors? */
{
    int result = 1;
    int oldMode;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    /*
     * Be sure to disable event servicing so we are truly modal.
     */

    oldMode = Tcl_SetServiceMode(TCL_SERVICE_NONE);

    /*
     * Reset WSAAsyncSelect so we have a fresh set of events pending.
     * Don't do that if we are waiting for a connect as we may miss
     * a connect (bug 336441ed59).
     */

    if ( 0 == (events & FD_CONNECT) ) {
        SendMessage(tsdPtr->hwnd, SOCKET_SELECT, (WPARAM) UNSELECT,
                (LPARAM) infoPtr);
    
        SendMessage(tsdPtr->hwnd, SOCKET_SELECT, (WPARAM) SELECT,
                (LPARAM) infoPtr);
    }

    while (1) {
	if (infoPtr->lastError) {
	    *errorCodePtr = infoPtr->lastError;
	    result = 0;
	    break;
	} else if (infoPtr->readyEvents & events) {
	    break;
	} else if (infoPtr->flags & SOCKET_ASYNC) {
	    *errorCodePtr = EWOULDBLOCK;
	    result = 0;
	    break;
	}

	/*
	 * Wait until something happens.
	 */

	WaitForSingleObject(tsdPtr->readyEvent, INFINITE);
    }

    (void) Tcl_SetServiceMode(oldMode);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_OpenTcpClient --
 *
 *	Opens a TCP client socket and creates a channel around it.
 *
 * Results:
 *	The channel or NULL if failed. An error message is returned in the
 *	interpreter on failure.
 *
 * Side effects:
 *	Opens a client socket and creates a new channel.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
Tcl_OpenTcpClient(
    Tcl_Interp *interp,		/* For error reporting; can be NULL. */
    int port,			/* Port number to open. */
    const char *host,		/* Host on which to open port. */
    const char *myaddr,		/* Client-side address */
    int myport,			/* Client-side port */
    int async)			/* If nonzero, should connect client socket
				 * asynchronously. */
{
    SocketInfo *infoPtr;
    char channelName[16 + TCL_INTEGER_SPACE];

    if (TclpHasSockets(interp) != TCL_OK) {
	return NULL;
    }

    /*
     * Create a new client socket and wrap it in a channel.
     */

    infoPtr = CreateSocket(interp, port, host, 0, myaddr, myport, async);
    if (infoPtr == NULL) {
	return NULL;
    }

    sprintf(channelName, "sock%" TCL_I_MODIFIER "u", (size_t)infoPtr->socket);

    infoPtr->channel = Tcl_CreateChannel(&tcpChannelType, channelName,
	    (ClientData) infoPtr, (TCL_READABLE | TCL_WRITABLE));
    if (Tcl_SetChannelOption(interp, infoPtr->channel, "-translation",
	    "auto crlf") == TCL_ERROR) {
	Tcl_Close((Tcl_Interp *) NULL, infoPtr->channel);
	return (Tcl_Channel) NULL;
    }
    if (Tcl_SetChannelOption(NULL, infoPtr->channel, "-eofchar", "")
	    == TCL_ERROR) {
	Tcl_Close((Tcl_Interp *) NULL, infoPtr->channel);
	return (Tcl_Channel) NULL;
    }
    return infoPtr->channel;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MakeTcpClientChannel --
 *
 *	Creates a Tcl_Channel from an existing client TCP socket.
 *
 * Results:
 *	The Tcl_Channel wrapped around the preexisting TCP socket.
 *
 * Side effects:
 *	None.
 *
 * NOTE: Code contributed by Mark Diekhans (markd@grizzly.com)
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
Tcl_MakeTcpClientChannel(
    ClientData sock)		/* The socket to wrap up into a channel. */
{
    SocketInfo *infoPtr;
    char channelName[16 + TCL_INTEGER_SPACE];
    ThreadSpecificData *tsdPtr;

    if (TclpHasSockets(NULL) != TCL_OK) {
	return NULL;
    }

    tsdPtr = (ThreadSpecificData *)TclThreadDataKeyGet(&dataKey);

    /*
     * Set kernel space buffering and non-blocking.
     */

    TclSockMinimumBuffers(sock, TCP_BUFFER_SIZE);

    infoPtr = NewSocketInfo((SOCKET) sock);

    /*
     * Start watching for read/write events on the socket.
     */

    infoPtr->selectEvents = FD_READ | FD_CLOSE | FD_WRITE;
    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
	    (WPARAM) SELECT, (LPARAM) infoPtr);

    sprintf(channelName, "sock%" TCL_I_MODIFIER "u", (size_t)infoPtr->socket);
    infoPtr->channel = Tcl_CreateChannel(&tcpChannelType, channelName,
	    (ClientData) infoPtr, (TCL_READABLE | TCL_WRITABLE));
    Tcl_SetChannelOption(NULL, infoPtr->channel, "-translation", "auto crlf");
    return infoPtr->channel;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_OpenTcpServer --
 *
 *	Opens a TCP server socket and creates a channel around it.
 *
 * Results:
 *	The channel or NULL if failed. An error message is returned in the
 *	interpreter on failure.
 *
 * Side effects:
 *	Opens a server socket and creates a new channel.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
Tcl_OpenTcpServer(
    Tcl_Interp *interp,		/* For error reporting - may be NULL. */
    int port,			/* Port number to open. */
    const char *host,		/* Name of local host. */
    Tcl_TcpAcceptProc *acceptProc,
				/* Callback for accepting connections from new
				 * clients. */
    ClientData acceptProcData)	/* Data for the callback. */
{
    SocketInfo *infoPtr;
    char channelName[16 + TCL_INTEGER_SPACE];

    if (TclpHasSockets(interp) != TCL_OK) {
	return NULL;
    }

    /*
     * Create a new client socket and wrap it in a channel.
     */

    infoPtr = CreateSocket(interp, port, host, 1, NULL, 0, 0);
    if (infoPtr == NULL) {
	return NULL;
    }

    infoPtr->acceptProc = acceptProc;
    infoPtr->acceptProcData = acceptProcData;

    sprintf(channelName, "sock%" TCL_I_MODIFIER "u", (size_t)infoPtr->socket);

    infoPtr->channel = Tcl_CreateChannel(&tcpChannelType, channelName,
	    (ClientData) infoPtr, 0);
    if (Tcl_SetChannelOption(interp, infoPtr->channel, "-eofchar", "")
	    == TCL_ERROR) {
	Tcl_Close((Tcl_Interp *) NULL, infoPtr->channel);
	return (Tcl_Channel) NULL;
    }

    return infoPtr->channel;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpAccept --
 *
 *	Accept a TCP socket connection. This is called by SocketEventProc and
 *	it in turns calls the registered accept function.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Invokes the accept proc which may invoke arbitrary Tcl code.
 *
 *----------------------------------------------------------------------
 */

static void
TcpAccept(
    SocketInfo *infoPtr)	/* Socket to accept. */
{
    SOCKET newSocket;
    SocketInfo *newInfoPtr;
    SOCKADDR_IN addr;
    int len;
    char channelName[16 + TCL_INTEGER_SPACE];
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    /*
     * Accept the incoming connection request.
     */

    len = sizeof(SOCKADDR_IN);

    newSocket = accept(infoPtr->socket, (SOCKADDR *)&addr,
	    &len);

    /*
     * Protect access to sockets (acceptEventCount, readyEvents) in socketList
     * by the lock.  Fix for SF Tcl Bug 3056775.
     */
    WaitForSingleObject(tsdPtr->socketListLock, INFINITE);

    /*
     * Clear the ready mask so we can detect the next connection request. Note
     * that connection requests are level triggered, so if there is a request
     * already pending, a new event will be generated.
     */

    if (newSocket == INVALID_SOCKET) {
	infoPtr->acceptEventCount = 0;
	infoPtr->readyEvents &= ~(FD_ACCEPT);

	SetEvent(tsdPtr->socketListLock);
	return;
    }

    /*
     * It is possible that more than one FD_ACCEPT has been sent, so an extra
     * count must be kept. Decrement the count, and reset the readyEvent bit
     * if the count is no longer > 0.
     */

    infoPtr->acceptEventCount--;

    if (infoPtr->acceptEventCount <= 0) {
	infoPtr->readyEvents &= ~(FD_ACCEPT);
    }

    SetEvent(tsdPtr->socketListLock);

    /*
     * Win-NT has a misfeature that sockets are inherited in child processes
     * by default. Turn off the inherit bit.
     */

    SetHandleInformation((HANDLE) newSocket, HANDLE_FLAG_INHERIT, 0);

    /*
     * Allocate socket info structure
     */

    newInfoPtr = NewSocketInfo(newSocket);

    /*
     * Select on read/write events and create the channel.
     */

    newInfoPtr->selectEvents = (FD_READ | FD_WRITE | FD_CLOSE);
    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
	    (WPARAM) SELECT, (LPARAM) newInfoPtr);

    sprintf(channelName, "sock%" TCL_I_MODIFIER "u", (size_t)newInfoPtr->socket);
    newInfoPtr->channel = Tcl_CreateChannel(&tcpChannelType, channelName,
	    (ClientData) newInfoPtr, (TCL_READABLE | TCL_WRITABLE));
    if (Tcl_SetChannelOption(NULL, newInfoPtr->channel, "-translation",
	    "auto crlf") == TCL_ERROR) {
	Tcl_Close((Tcl_Interp *) NULL, newInfoPtr->channel);
	return;
    }
    if (Tcl_SetChannelOption(NULL, newInfoPtr->channel, "-eofchar", "")
	    == TCL_ERROR) {
	Tcl_Close((Tcl_Interp *) NULL, newInfoPtr->channel);
	return;
    }

    /*
     * Invoke the accept callback function.
     */

    if (infoPtr->acceptProc != NULL) {
	(infoPtr->acceptProc) (infoPtr->acceptProcData, newInfoPtr->channel,
		inet_ntoa(addr.sin_addr), ntohs(addr.sin_port));
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TcpInputProc --
 *
 *	This function is called by the generic IO level to read data from a
 *	socket based channel.
 *
 * Results:
 *	The number of bytes read or -1 on error.
 *
 * Side effects:
 *	Consumes input from the socket.
 *
 *----------------------------------------------------------------------
 */

static int
TcpInputProc(
    ClientData instanceData,	/* The socket state. */
    char *buf,			/* Where to store data. */
    int toRead,			/* Maximum number of bytes to read. */
    int *errorCodePtr)		/* Where to store error codes. */
{
    SocketInfo *infoPtr = (SocketInfo *) instanceData;
    int bytesRead;
    DWORD error;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    *errorCodePtr = 0;

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	*errorCodePtr = EFAULT;
	return -1;
    }

    /*
     * First check to see if EOF was already detected, to prevent calling the
     * socket stack after the first time EOF is detected.
     */

    if (infoPtr->flags & SOCKET_EOF) {
	return 0;
    }

    /*
     * Check to see if the socket is connected before trying to read.
     */

    if ((infoPtr->flags & SOCKET_ASYNC_CONNECT)
	    && !WaitForSocketEvent(infoPtr, FD_CONNECT, errorCodePtr)) {
	return -1;
    }

    /*
     * No EOF, and it is connected, so try to read more from the socket. Note
     * that we clear the FD_READ bit because read events are level triggered
     * so a new event will be generated if there is still data available to be
     * read. We have to simulate blocking behavior here since we are always
     * using non-blocking sockets.
     */

    while (1) {
	SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
		(WPARAM) UNSELECT, (LPARAM) infoPtr);
	bytesRead = recv(infoPtr->socket, buf, toRead, 0);
	infoPtr->readyEvents &= ~(FD_READ);

	/*
	 * Check for end-of-file condition or successful read.
	 */

	if (bytesRead == 0) {
	    infoPtr->flags |= SOCKET_EOF;
	}
	if (bytesRead != SOCKET_ERROR) {
	    break;
	}

	/*
	 * If an error occurs after the FD_CLOSE has arrived, then ignore the
	 * error and report an EOF.
	 */

	if (infoPtr->readyEvents & FD_CLOSE) {
	    infoPtr->flags |= SOCKET_EOF;
	    bytesRead = 0;
	    break;
	}

	error = WSAGetLastError();

	/*
	 * If an RST comes, then ignore the error and report an EOF just like
	 * on unix.
	 */

	if (error == WSAECONNRESET) {
	    infoPtr->flags |= SOCKET_EOF;
	    bytesRead = 0;
	    break;
	}

	/*
	 * Check for error condition or underflow in non-blocking case.
	 */

	if ((infoPtr->flags & SOCKET_ASYNC) || (error != WSAEWOULDBLOCK)) {
	    TclWinConvertWSAError(error);
	    *errorCodePtr = Tcl_GetErrno();
	    bytesRead = -1;
	    break;
	}

	/*
	 * In the blocking case, wait until the file becomes readable or
	 * closed and try again.
	 */

	if (!WaitForSocketEvent(infoPtr, FD_READ|FD_CLOSE, errorCodePtr)) {
	    bytesRead = -1;
	    break;
	}
    }

    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
	    (WPARAM) SELECT, (LPARAM) infoPtr);

    return bytesRead;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpOutputProc --
 *
 *	This function is called by the generic IO level to write data to a
 *	socket based channel.
 *
 * Results:
 *	The number of bytes written or -1 on failure.
 *
 * Side effects:
 *	Produces output on the socket.
 *
 *----------------------------------------------------------------------
 */

static int
TcpOutputProc(
    ClientData instanceData,	/* The socket state. */
    const char *buf,		/* Where to get data. */
    int toWrite,		/* Maximum number of bytes to write. */
    int *errorCodePtr)		/* Where to store error codes. */
{
    SocketInfo *infoPtr = (SocketInfo *) instanceData;
    int bytesWritten;
    DWORD error;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    TclThreadDataKeyGet(&dataKey);

    *errorCodePtr = 0;

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	*errorCodePtr = EFAULT;
	return -1;
    }

    /*
     * Check to see if the socket is connected before trying to write.
     */

    if ((infoPtr->flags & SOCKET_ASYNC_CONNECT)
	    && !WaitForSocketEvent(infoPtr, FD_CONNECT, errorCodePtr)) {
	return -1;
    }

    while (1) {
	SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
		(WPARAM) UNSELECT, (LPARAM) infoPtr);

	bytesWritten = send(infoPtr->socket, buf, toWrite, 0);
	if (bytesWritten != SOCKET_ERROR) {
	    /*
	     * Since Windows won't generate a new write event until we hit an
	     * overflow condition, we need to force the event loop to poll
	     * until the condition changes.
	     */

	    if (infoPtr->watchEvents & FD_WRITE) {
		Tcl_Time blockTime = { 0, 0 };
		Tcl_SetMaxBlockTime(&blockTime);
	    }
	    break;
	}

	/*
	 * Check for error condition or overflow. In the event of overflow, we
	 * need to clear the FD_WRITE flag so we can detect the next writable
	 * event. Note that Windows only sends a new writable event after a
	 * send fails with WSAEWOULDBLOCK.
	 */

	error = WSAGetLastError();
	if (error == WSAEWOULDBLOCK) {
	    infoPtr->readyEvents &= ~(FD_WRITE);
	    if (infoPtr->flags & SOCKET_ASYNC) {
		*errorCodePtr = EWOULDBLOCK;
		bytesWritten = -1;
		break;
	    }
	} else {
	    TclWinConvertWSAError(error);
	    *errorCodePtr = Tcl_GetErrno();
	    bytesWritten = -1;
	    break;
	}

	/*
	 * In the blocking case, wait until the file becomes writable or
	 * closed and try again.
	 */

	if (!WaitForSocketEvent(infoPtr, FD_WRITE|FD_CLOSE, errorCodePtr)) {
	    bytesWritten = -1;
	    break;
	}
    }

    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
	    (WPARAM) SELECT, (LPARAM) infoPtr);

    return bytesWritten;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpSetOptionProc --
 *
 *	Sets Tcp channel specific options.
 *
 * Results:
 *	None, unless an error happens.
 *
 * Side effects:
 *	Changes attributes of the socket at the system level.
 *
 *----------------------------------------------------------------------
 */

static int
TcpSetOptionProc(
    ClientData instanceData,	/* Socket state. */
    Tcl_Interp *interp,		/* For error reporting - can be NULL. */
    const char *optionName,	/* Name of the option to set. */
    const char *value)		/* New value for option. */
{
#ifdef TCL_FEATURE_KEEPALIVE_NAGLE
    SocketInfo *infoPtr;
    SOCKET sock;
#endif

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	if (interp) {
	    Tcl_AppendResult(interp, "winsock is not initialized", NULL);
	}
	return TCL_ERROR;
    }

#ifdef TCL_FEATURE_KEEPALIVE_NAGLE
    infoPtr = (SocketInfo *) instanceData;
    sock = infoPtr->socket;

    if (!strcasecmp(optionName, "-keepalive")) {
	BOOL val = FALSE;
	int boolVar, rtn;

	if (Tcl_GetBoolean(interp, value, &boolVar) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (boolVar) {
	    val = TRUE;
	}
	rtn = setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE,
		(const char *) &val, sizeof(BOOL));
	if (rtn != 0) {
	    TclWinConvertWSAError(WSAGetLastError());
	    if (interp) {
		Tcl_AppendResult(interp, "couldn't set socket option: ",
			Tcl_PosixError(interp), NULL);
	    }
	    return TCL_ERROR;
	}
	return TCL_OK;
    } else if (!strcasecmp(optionName, "-nagle")) {
	BOOL val = FALSE;
	int boolVar, rtn;

	if (Tcl_GetBoolean(interp, value, &boolVar) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (!boolVar) {
	    val = TRUE;
	}
	rtn = setsockopt(sock, IPPROTO_TCP, TCP_NODELAY,
		(const char *) &val, sizeof(BOOL));
	if (rtn != 0) {
	    TclWinConvertWSAError(WSAGetLastError());
	    if (interp) {
		Tcl_AppendResult(interp, "couldn't set socket option: ",
			Tcl_PosixError(interp), NULL);
	    }
	    return TCL_ERROR;
	}
	return TCL_OK;
    }

    return Tcl_BadChannelOption(interp, optionName, "keepalive nagle");
#else
    return Tcl_BadChannelOption(interp, optionName, "");
#endif /*TCL_FEATURE_KEEPALIVE_NAGLE*/
}

/*
 *----------------------------------------------------------------------
 *
 * TcpGetOptionProc --
 *
 *	Computes an option value for a TCP socket based channel, or a list of
 *	all options and their values.
 *
 *	Note: This code is based on code contributed by John Haxby.
 *
 * Results:
 *	A standard Tcl result. The value of the specified option or a list of
 *	all options and their values is returned in the supplied DString.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TcpGetOptionProc(
    ClientData instanceData,	/* Socket state. */
    Tcl_Interp *interp,		/* For error reporting - can be NULL */
    const char *optionName,	/* Name of the option to retrieve the value
				 * for, or NULL to get all options and their
				 * values. */
    Tcl_DString *dsPtr)		/* Where to store the computed value;
				 * initialized by caller. */
{
    SocketInfo *infoPtr;
    SOCKADDR_IN sockname;
    SOCKADDR_IN peername;
    struct hostent *hostEntPtr;
    SOCKET sock;
    int size = sizeof(SOCKADDR_IN);
    size_t len = 0;
    char buf[TCL_INTEGER_SPACE];

    /*
     * Check that WinSock is initialized; do not call it if not, to prevent
     * system crashes. This can happen at exit time if the exit handler for
     * WinSock ran before other exit handlers that want to use sockets.
     */

    if (!SocketsEnabled()) {
	if (interp) {
	    Tcl_AppendResult(interp, "winsock is not initialized", NULL);
	}
	return TCL_ERROR;
    }

    infoPtr = (SocketInfo *) instanceData;
    sock = (int) infoPtr->socket;
    if (optionName != NULL) {
	len = strlen(optionName);
    }

    if ((len > 1) && (optionName[1] == 'e') &&
	    (strncmp(optionName, "-error", len) == 0)) {
	int optlen;
	DWORD err;
	int ret;

	optlen = sizeof(int);
	ret = TclWinGetSockOpt((int)sock, SOL_SOCKET, SO_ERROR,
		(char *)&err, &optlen);
	if (ret == SOCKET_ERROR) {
	    err = WSAGetLastError();
	}
	if (err) {
	    TclWinConvertWSAError(err);
	    Tcl_DStringAppend(dsPtr, Tcl_ErrnoMsg(Tcl_GetErrno()), -1);
	}
	return TCL_OK;
    }

    if ((len == 0) || ((len > 1) && (optionName[1] == 'p') &&
	    (strncmp(optionName, "-peername", len) == 0))) {
	if (getpeername(sock, (LPSOCKADDR) &peername, &size) == 0) {
	    if (len == 0) {
		Tcl_DStringAppendElement(dsPtr, "-peername");
		Tcl_DStringStartSublist(dsPtr);
	    }
	    Tcl_DStringAppendElement(dsPtr, inet_ntoa(peername.sin_addr));

	    if (peername.sin_addr.s_addr == 0) {
		hostEntPtr = NULL;
	    } else {
		hostEntPtr = gethostbyaddr((char *) &(peername.sin_addr),
			sizeof(peername.sin_addr), AF_INET);
	    }
	    if (hostEntPtr != NULL) {
		Tcl_DStringAppendElement(dsPtr, hostEntPtr->h_name);
	    } else {
		Tcl_DStringAppendElement(dsPtr, inet_ntoa(peername.sin_addr));
	    }
	    TclFormatInt(buf, ntohs(peername.sin_port));
	    Tcl_DStringAppendElement(dsPtr, buf);
	    if (len == 0) {
		Tcl_DStringEndSublist(dsPtr);
	    } else {
		return TCL_OK;
	    }
	} else {
	    /*
	     * getpeername failed - but if we were asked for all the options
	     * (len==0), don't flag an error at that point because it could be
	     * an fconfigure request on a server socket (such sockets have no
	     * peer). {Copied from unix/tclUnixChan.c}
	     */

	    if (len) {
		TclWinConvertWSAError((DWORD) WSAGetLastError());
		if (interp) {
		    Tcl_AppendResult(interp, "can't get peername: ",
			    Tcl_PosixError(interp), NULL);
		}
		return TCL_ERROR;
	    }
	}
    }

    if ((len == 0) || ((len > 1) && (optionName[1] == 's') &&
	    (strncmp(optionName, "-sockname", len) == 0))) {
	if (getsockname(sock, (LPSOCKADDR) &sockname, &size) == 0) {
	    if (len == 0) {
		Tcl_DStringAppendElement(dsPtr, "-sockname");
		Tcl_DStringStartSublist(dsPtr);
	    }
	    Tcl_DStringAppendElement(dsPtr, inet_ntoa(sockname.sin_addr));
	    if (sockname.sin_addr.s_addr == 0) {
		hostEntPtr = NULL;
	    } else {
		hostEntPtr = gethostbyaddr((char *) &(sockname.sin_addr),
			sizeof(peername.sin_addr), AF_INET);
	    }
	    if (hostEntPtr != NULL) {
		Tcl_DStringAppendElement(dsPtr, hostEntPtr->h_name);
	    } else {
		Tcl_DStringAppendElement(dsPtr, inet_ntoa(sockname.sin_addr));
	    }
	    TclFormatInt(buf, ntohs(sockname.sin_port));
	    Tcl_DStringAppendElement(dsPtr, buf);
	    if (len == 0) {
		Tcl_DStringEndSublist(dsPtr);
	    } else {
		return TCL_OK;
	    }
	} else {
	    if (interp) {
		TclWinConvertWSAError((DWORD) WSAGetLastError());
		Tcl_AppendResult(interp, "can't get sockname: ",
			Tcl_PosixError(interp), NULL);
	    }
	    return TCL_ERROR;
	}
    }

#ifdef TCL_FEATURE_KEEPALIVE_NAGLE
    if (len == 0 || !strncmp(optionName, "-keepalive", len)) {
	int optlen;
	BOOL opt = FALSE;

	if (len == 0) {
	    Tcl_DStringAppendElement(dsPtr, "-keepalive");
	}
	optlen = sizeof(BOOL);
	getsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (char *)&opt, &optlen);
	if (opt) {
	    Tcl_DStringAppendElement(dsPtr, "1");
	} else {
	    Tcl_DStringAppendElement(dsPtr, "0");
	}
	if (len > 0) {
	    return TCL_OK;
	}
    }

    if (len == 0 || !strncmp(optionName, "-nagle", len)) {
	int optlen;
	BOOL opt = FALSE;

	if (len == 0) {
	    Tcl_DStringAppendElement(dsPtr, "-nagle");
	}
	optlen = sizeof(BOOL);
	getsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *)&opt,
		&optlen);
	if (opt) {
	    Tcl_DStringAppendElement(dsPtr, "0");
	} else {
	    Tcl_DStringAppendElement(dsPtr, "1");
	}
	if (len > 0) {
	    return TCL_OK;
	}
    }
#endif /*TCL_FEATURE_KEEPALIVE_NAGLE*/

    if (len > 0) {
#ifdef TCL_FEATURE_KEEPALIVE_NAGLE
	return Tcl_BadChannelOption(interp, optionName,
		"peername sockname keepalive nagle");
#else
	return Tcl_BadChannelOption(interp, optionName, "peername sockname");
#endif /*TCL_FEATURE_KEEPALIVE_NAGLE*/
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TcpWatchProc --
 *
 *	Informs the channel driver of the events that the generic channel code
 *	wishes to receive on this socket.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May cause the notifier to poll if any of the specified conditions are
 *	already true.
 *
 *----------------------------------------------------------------------
 */

static void
TcpWatchProc(
    ClientData instanceData,	/* The socket state. */
    int mask)			/* Events of interest; an OR-ed combination of
				 * TCL_READABLE, TCL_WRITABLE and
				 * TCL_EXCEPTION. */
{
    SocketInfo *infoPtr = (SocketInfo *) instanceData;

    /*
     * Update the watch events mask. Only if the socket is not a server
     * socket. Fix for SF Tcl Bug #557878.
     */

    if (!infoPtr->acceptProc) {
	infoPtr->watchEvents = 0;
	if (mask & TCL_READABLE) {
	    infoPtr->watchEvents |= (FD_READ|FD_CLOSE|FD_ACCEPT);
	}
	if (mask & TCL_WRITABLE) {
	    infoPtr->watchEvents |= (FD_WRITE|FD_CLOSE|FD_CONNECT);
	}

	/*
	 * If there are any conditions already set, then tell the notifier to
	 * poll rather than block.
	 */

	if (infoPtr->readyEvents & infoPtr->watchEvents) {
	    Tcl_Time blockTime = { 0, 0 };
	    Tcl_SetMaxBlockTime(&blockTime);
	}
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TcpGetProc --
 *
 *	Called from Tcl_GetChannelHandle to retrieve an OS handle from inside
 *	a TCP socket based channel.
 *
 * Results:
 *	Returns TCL_OK with the socket in handlePtr.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TcpGetHandleProc(
    ClientData instanceData,	/* The socket state. */
    int direction,		/* Not used. */
    ClientData *handlePtr)	/* Where to store the handle. */
{
    SocketInfo *statePtr = (SocketInfo *) instanceData;

    *handlePtr = (ClientData) statePtr->socket;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * SocketThread --
 *
 *	Helper thread used to manage the socket event handling window.
 *
 * Results:
 *	1 if unable to create socket event window, 0 otherwise.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static DWORD WINAPI
SocketThread(
    LPVOID arg)
{
    MSG msg;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)(arg);

    /*
     * Create a dummy window receiving socket events.
     */

    tsdPtr->hwnd = CreateWindow("TclSocket", "TclSocket",
	    WS_TILED, 0, 0, 0, 0, NULL, NULL, windowClass.hInstance, arg);

    /*
     * Signalize thread creator that we are done creating the window.
     */

    SetEvent(tsdPtr->readyEvent);

    /*
     * If unable to create the window, exit this thread immediately.
     */

    if (tsdPtr->hwnd == NULL) {
	return 1;
    }

    /*
     * Process all messages on the socket window until WM_QUIT. This threads
     * exits only when instructed to do so by the call to
     * PostMessage(SOCKET_TERMINATE) in TclpFinalizeSockets().
     */

    while (GetMessage(&msg, NULL, 0, 0) > 0) {
	DispatchMessage(&msg);
    }

    /*
     * This releases waiters on thread exit in TclpFinalizeSockets()
     */

    SetEvent(tsdPtr->readyEvent);

    return msg.wParam;
}


/*
 *----------------------------------------------------------------------
 *
 * SocketProc --
 *
 *	This function is called when WSAAsyncSelect has been used to register
 *	interest in a socket event, and the event has occurred.
 *
 * Results:
 *	0 on success.
 *
 * Side effects:
 *	The flags for the given socket are updated to reflect the event that
 *	occured.
 *
 *----------------------------------------------------------------------
 */

static LRESULT CALLBACK
SocketProc(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam)
{
    int event, error;
    SOCKET socket;
    SocketInfo *infoPtr;
    int info_found = 0;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
#ifdef _WIN64
	    GetWindowLongPtr(hwnd, GWLP_USERDATA);
#else
	    GetWindowLong(hwnd, GWL_USERDATA);
#endif

    switch (message) {
    default:
	return DefWindowProc(hwnd, message, wParam, lParam);
	break;

    case WM_CREATE:
	/*
	 * Store the initial tsdPtr, it's from a different thread, so it's not
	 * directly accessible, but needed.
	 */

#ifdef _WIN64
	SetWindowLongPtr(hwnd, GWLP_USERDATA,
		(LONG_PTR) ((LPCREATESTRUCT)lParam)->lpCreateParams);
#else
	SetWindowLong(hwnd, GWL_USERDATA,
		(LONG) ((LPCREATESTRUCT)lParam)->lpCreateParams);
#endif
	break;

    case WM_DESTROY:
	PostQuitMessage(0);
	break;

    case SOCKET_MESSAGE:
	event = WSAGETSELECTEVENT(lParam);
	error = WSAGETSELECTERROR(lParam);
	socket = (SOCKET) wParam;

	/*
	 * Find the specified socket on the socket list and update its
	 * eventState flag.
	 */

	WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
	for (infoPtr = tsdPtr->socketList; infoPtr != NULL;
		infoPtr = infoPtr->nextPtr) {
	    if (infoPtr->socket == socket) {
		info_found = 1;
		break;
	    }
	}
	/*
	 * Check if there is a pending info structure not jet in the
	 * list
	 */
	if ( !info_found
		&& tsdPtr->pendingSocketInfo != NULL
		&& tsdPtr->pendingSocketInfo->socket ==socket ) {
	    infoPtr = tsdPtr->pendingSocketInfo;
	    info_found = 1;
	}
	if (info_found) {

	    /*
	     * Update the socket state.
	     *
	     * A count of FD_ACCEPTS is stored, so if an FD_CLOSE event
	     * happens, then clear the FD_ACCEPT count. Otherwise,
	     * increment the count if the current event is an FD_ACCEPT.
	     */

	    if (event & FD_CLOSE) {
	        infoPtr->acceptEventCount = 0;
	        infoPtr->readyEvents &= ~(FD_WRITE|FD_ACCEPT);
	    } else if (event & FD_ACCEPT) {
		infoPtr->acceptEventCount++;
	    }

	    if (event & FD_CONNECT) {
		/*
		 * The socket is now connected, clear the async connect
		 * flag.
		 */

		infoPtr->flags &= ~(SOCKET_ASYNC_CONNECT);

		/*
		 * Remember any error that occurred so we can report
		 * connection failures.
		 */

		if (error != ERROR_SUCCESS) {
		    /* Async Connect error */
		    TclWinConvertWSAError((DWORD) error);
		    infoPtr->lastError = Tcl_GetErrno();
		    /* Fire also readable event on connect failure */
		    infoPtr->readyEvents |= FD_READ;
		}

		/* fire writable event on connect */
		infoPtr->readyEvents |= FD_WRITE;

	    }

	    infoPtr->readyEvents |= event;

	    /*
	     * Wake up the Main Thread.
	     */

	    SetEvent(tsdPtr->readyEvent);
	    Tcl_ThreadAlert(tsdPtr->threadId);
	}
	SetEvent(tsdPtr->socketListLock);
	break;

    case SOCKET_SELECT:
	infoPtr = (SocketInfo *) lParam;
	if (wParam == SELECT) {
            /*
             * Start notification by windows messages on socket events
             */

	    WSAAsyncSelect(infoPtr->socket, hwnd,
		    SOCKET_MESSAGE, infoPtr->selectEvents);
	} else {
	    /*
	     * UNSELECT: Clear the selection mask
	     */

	    WSAAsyncSelect(infoPtr->socket, hwnd, 0, 0);
	}
	break;

    case SOCKET_TERMINATE:
	DestroyWindow(hwnd);
	break;
    }

    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetHostName --
 *
 *	Returns the name of the local host.
 *
 * Results:
 *	A string containing the network name for this machine. The caller must
 *	not modify or free this string.
 *
 * Side effects:
 *	Caches the name to return for future calls.
 *
 *----------------------------------------------------------------------
 */

const char *
Tcl_GetHostName(void)
{
    return Tcl_GetString(TclGetProcessGlobalValue(&hostName));
}

/*
 *----------------------------------------------------------------------
 *
 * InitializeHostName --
 *
 *	This routine sets the process global value of the name of the local
 *	host on which the process is running.
 *
 * Results:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
InitializeHostName(
    char **valuePtr,
    int *lengthPtr,
    Tcl_Encoding *encodingPtr)
{
    WCHAR wbuf[MAX_COMPUTERNAME_LENGTH + 1];
    DWORD length = sizeof(wbuf) / sizeof(WCHAR);
    Tcl_DString ds;

    if ((*tclWinProcs->getComputerNameProc)(wbuf, &length) != 0) {
	/*
	 * Convert string from native to UTF then change to lowercase.
	 */

	Tcl_UtfToLower(Tcl_WinTCharToUtf((TCHAR *) wbuf, -1, &ds));

    } else {
	Tcl_DStringInit(&ds);
	if (TclpHasSockets(NULL) == TCL_OK) {
	    /*
	     * The buffer size of 256 is recommended by the MSDN page that
	     * documents gethostname() as being always adequate.
	     */

	    Tcl_DString inDs;

	    Tcl_DStringInit(&inDs);
	    Tcl_DStringSetLength(&inDs, 256);
	    if (gethostname(Tcl_DStringValue(&inDs),
		    Tcl_DStringLength(&inDs)) == 0) {
		Tcl_ExternalToUtfDString(NULL, Tcl_DStringValue(&inDs), -1,
			&ds);
	    }
	    Tcl_DStringFree(&inDs);
	}
    }

    *encodingPtr = Tcl_GetEncoding(NULL, "utf-8");
    *lengthPtr = Tcl_DStringLength(&ds);
    *valuePtr = ckalloc((unsigned int) (*lengthPtr)+1);
    memcpy(*valuePtr, Tcl_DStringValue(&ds), (size_t)(*lengthPtr)+1);
    Tcl_DStringFree(&ds);
}

/*
 *----------------------------------------------------------------------
 *
 * TclWinGetSockOpt, et al. --
 *
 *	These functions are wrappers that let us bind the WinSock API
 *	dynamically so we can run on systems that don't have the wsock32.dll.
 *	We need wrappers for these interfaces because they are called from the
 *	generic Tcl code.
 *
 * Results:
 *	As defined for each function.
 *
 * Side effects:
 *	As defined for each function.
 *
 *----------------------------------------------------------------------
 */

#undef TclWinGetSockOpt
int
TclWinGetSockOpt(SOCKET s, int level, int optname, char *optval,
	int *optlen)
{
    return getsockopt(s, level, optname, optval, optlen);
}

#undef TclWinSetSockOpt
int
TclWinSetSockOpt(SOCKET s, int level, int optname, const char *optval,
    int optlen)
{
    return setsockopt(s, level, optname, optval, optlen);
}

char *
TclpInetNtoa(struct in_addr addr)
{
    return inet_ntoa(addr);
}

#undef TclWinGetServByName
struct servent *
TclWinGetServByName(
    const char *name,
    const char *proto)
{
    return getservbyname(name, proto);
}

/*
 *----------------------------------------------------------------------
 *
 * TcpThreadActionProc --
 *
 *	Insert or remove any thread local refs to this channel.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Changes thread local list of valid channels.
 *
 *----------------------------------------------------------------------
 */

static void
TcpThreadActionProc(
    ClientData instanceData,
    int action)
{
    ThreadSpecificData *tsdPtr;
    SocketInfo *infoPtr = (SocketInfo *) instanceData;
    int notifyCmd;

    if (action == TCL_CHANNEL_THREAD_INSERT) {
	/*
	 * Ensure that socket subsystem is initialized in this thread, or else
	 * sockets will not work.
	 */

	Tcl_MutexLock(&socketMutex);
	InitSockets();
	Tcl_MutexUnlock(&socketMutex);

	tsdPtr = TCL_TSD_INIT(&dataKey);

	WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
	infoPtr->nextPtr = tsdPtr->socketList;
	tsdPtr->socketList = infoPtr;
	
	if (infoPtr == tsdPtr->pendingSocketInfo) {
	    tsdPtr->pendingSocketInfo = NULL;
	}
	
	SetEvent(tsdPtr->socketListLock);

	notifyCmd = SELECT;
    } else {
	SocketInfo **nextPtrPtr;
	int removed = 0;

	tsdPtr = TCL_TSD_INIT(&dataKey);

	/*
	 * TIP #218, Bugfix: All access to socketList has to be protected by
	 * the lock.
	 */

	WaitForSingleObject(tsdPtr->socketListLock, INFINITE);
	for (nextPtrPtr = &(tsdPtr->socketList); (*nextPtrPtr) != NULL;
		nextPtrPtr = &((*nextPtrPtr)->nextPtr)) {
	    if ((*nextPtrPtr) == infoPtr) {
		(*nextPtrPtr) = infoPtr->nextPtr;
		removed = 1;
		break;
	    }
	}
	SetEvent(tsdPtr->socketListLock);

	/*
	 * This could happen if the channel was created in one thread and then
	 * moved to another without updating the thread local data in each
	 * thread.
	 */

	if (!removed) {
	    Tcl_Panic("file info ptr not on thread channel list");
	}

	notifyCmd = UNSELECT;
    }

    /*
     * Ensure that, or stop, notifications for the socket occur in this
     * thread.
     */

    SendMessage(tsdPtr->hwnd, SOCKET_SELECT,
	    (WPARAM) notifyCmd, (LPARAM) infoPtr);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

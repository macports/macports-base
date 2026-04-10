/*
 * tclUnixChan.c
 *
 *	Common channel driver for Unix channels based on files, command pipes
 *	and TCP sockets.
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 * Copyright © 1998-1999 Scriptics Corporation.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"	/* Internal definitions for Tcl. */
#include "tclFileSystem.h"
#include "tclIO.h"	/* To get Channel type declaration. */

#undef SUPPORTS_TTY
#if defined(HAVE_TERMIOS_H)
#   define SUPPORTS_TTY 1
#   include <termios.h>
#   ifdef HAVE_SYS_IOCTL_H
#	include <sys/ioctl.h>
#   endif /* HAVE_SYS_IOCTL_H */
#   ifdef HAVE_SYS_MODEM_H
#	include <sys/modem.h>
#   endif /* HAVE_SYS_MODEM_H */

#   ifdef FIONREAD
#	define GETREADQUEUE(fd, int)	ioctl((fd), FIONREAD, &(int))
#   elif defined(FIORDCHK)
#	define GETREADQUEUE(fd, int)	int = ioctl((fd), FIORDCHK, NULL)
#   else
#       define GETREADQUEUE(fd, int)    int = 0
#   endif

#   ifdef TIOCOUTQ
#	define GETWRITEQUEUE(fd, int)	ioctl((fd), TIOCOUTQ, &(int))
#   else
#	define GETWRITEQUEUE(fd, int)	int = 0
#   endif

#   if !defined(CRTSCTS) && defined(CNEW_RTSCTS)
#	define CRTSCTS CNEW_RTSCTS
#   endif /* !CRTSCTS&CNEW_RTSCTS */
#   if !defined(PAREXT) && defined(CMSPAR)
#	define PAREXT CMSPAR
#   endif /* !PAREXT&&CMSPAR */

#endif	/* HAVE_TERMIOS_H */

/*
 * The bits supported for describing the closeMode field of TtyState.
 */

enum CloseModeBits {
    CLOSE_DEFAULT,
    CLOSE_DRAIN,
    CLOSE_DISCARD
};

/*
 * Helper macros to make parts of this file clearer. The macros do exactly
 * what they say on the tin. :-) They also only ever refer to their arguments
 * once, and so can be used without regard to side effects.
 */

#define SET_BITS(var, bits)	((var) |= (bits))
#define CLEAR_BITS(var, bits)	((var) &= ~(bits))

/*
 * These structures describe per-instance state of file-based and serial-based
 * channels.
 */

typedef struct {
    Tcl_Channel channel;	/* Channel associated with this file. */
    int fd;			/* File handle. */
    int validMask;		/* OR'ed combination of TCL_READABLE,
				 * TCL_WRITABLE, or TCL_EXCEPTION: indicates
				 * which operations are valid on the file. */
} FileState;

typedef struct {
    FileState fileState;
#ifdef SUPPORTS_TTY
    int closeMode;		/* One of CLOSE_DEFAULT, CLOSE_DRAIN or
				 * CLOSE_DISCARD. */
    int doReset;		/* Whether we should do a terminal reset on
				 * close. */
    struct termios initState;	/* The state of the terminal when it was
				 * opened. */
#endif	/* SUPPORTS_TTY */
} TtyState;

#ifdef SUPPORTS_TTY

/*
 * The following structure is used to set or get the serial port attributes in
 * a platform-independent manner.
 */

typedef struct {
    int baud;
    int parity;
    int data;
    int stop;
} TtyAttrs;

#endif	/* SUPPORTS_TTY */

#define UNSUPPORTED_OPTION(detail) \
    if (interp) {							\
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(				\
		"%s not supported for this platform", (detail)));	\
	Tcl_SetErrorCode(interp, "TCL", "UNSUPPORTED", (char *)NULL);		\
    }

/*
 * Static routines for this file:
 */

static int		FileBlockModeProc(void *instanceData, int mode);
static int		FileCloseProc(void *instanceData,
			    Tcl_Interp *interp, int flags);
static int		FileGetHandleProc(void *instanceData,
			    int direction, void **handlePtr);
static int		FileGetOptionProc(void *instanceData,
			    Tcl_Interp *interp, const char *optionName,
			    Tcl_DString *dsPtr);
static int		FileInputProc(void *instanceData, char *buf,
			    int toRead, int *errorCode);
static int		FileOutputProc(void *instanceData,
			    const char *buf, int toWrite, int *errorCode);
static int		FileTruncateProc(void *instanceData,
			    long long length);
static long long	FileWideSeekProc(void *instanceData,
			    long long offset, int mode, int *errorCode);
static void		FileWatchProc(void *instanceData, int mask);
#ifdef SUPPORTS_TTY
static int		TtyCloseProc(void *instanceData,
			    Tcl_Interp *interp, int flags);
static void		TtyGetAttributes(int fd, TtyAttrs *ttyPtr);
static int		TtyGetOptionProc(void *instanceData,
			    Tcl_Interp *interp, const char *optionName,
			    Tcl_DString *dsPtr);
static int		TtyGetBaud(speed_t speed);
static speed_t		TtyGetSpeed(int baud);
static void		TtyInit(int fd);
static void		TtyModemStatusStr(int status, Tcl_DString *dsPtr);
static int		TtyParseMode(Tcl_Interp *interp, const char *mode,
			    TtyAttrs *ttyPtr);
static void		TtySetAttributes(int fd, TtyAttrs *ttyPtr);
static int		TtySetOptionProc(void *instanceData,
			    Tcl_Interp *interp, const char *optionName,
			    const char *value);
#endif	/* SUPPORTS_TTY */

/*
 * This structure describes the channel type structure for file based IO:
 */

static const Tcl_ChannelType fileChannelType = {
    "file",			/* Type name. */
    TCL_CHANNEL_VERSION_5,
    NULL,			/* Deprecated. */
    FileInputProc,
    FileOutputProc,
    NULL,			/* Deprecated. */
    NULL,			/* Set option proc. */
    FileGetOptionProc,
    FileWatchProc,
    FileGetHandleProc,
    FileCloseProc,
    FileBlockModeProc,
    NULL,			/* Flush proc. */
    NULL,			/* Bubbled event handler proc. */
    FileWideSeekProc,
    NULL,			/* Thread action proc. */
    FileTruncateProc
};

#ifdef SUPPORTS_TTY
/*
 * This structure describes the channel type structure for serial IO.
 * Note that this type is a subclass of the "file" type.
 */

static const Tcl_ChannelType ttyChannelType = {
    "tty",
    TCL_CHANNEL_VERSION_5,
    NULL,			/* Deprecated. */
    FileInputProc,
    FileOutputProc,
    NULL,			/* Deprecated. */
    TtySetOptionProc,
    TtyGetOptionProc,
    FileWatchProc,
    FileGetHandleProc,
    TtyCloseProc,
    FileBlockModeProc,
    NULL,			/* Flush proc. */
    NULL,			/* Bubbled event handler proc. */
    NULL,			/* Seek proc. */
    NULL,			/* Thread action proc. */
    NULL			/* Truncate proc. */
};
#endif	/* SUPPORTS_TTY */

/*
 *----------------------------------------------------------------------
 *
 * FileBlockModeProc --
 *
 *	Helper function to set blocking and nonblocking modes on a file based
 *	channel. Invoked by generic IO level code.
 *
 * Results:
 *	0 if successful, errno when failed.
 *
 * Side effects:
 *	Sets the device into blocking or non-blocking mode.
 *
 *----------------------------------------------------------------------
 */

static int
FileBlockModeProc(
    void *instanceData,		/* File state. */
    int mode)			/* The mode to set. Can be TCL_MODE_BLOCKING
				 * or TCL_MODE_NONBLOCKING. */
{
    FileState *fsPtr = (FileState *)instanceData;

    if (TclUnixSetBlockingMode(fsPtr->fd, mode) < 0) {
	return errno;
    }

    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * FileInputProc --
 *
 *	This function is invoked from the generic IO level to read input from
 *	a file based channel.
 *
 * Results:
 *	The number of bytes read is returned or -1 on error. An output
 *	argument contains a POSIX error code if an error occurs, or zero.
 *
 * Side effects:
 *	Reads input from the input device of the channel.
 *
 *----------------------------------------------------------------------
 */

static int
FileInputProc(
    void *instanceData,		/* File state. */
    char *buf,			/* Where to store data read. */
    int toRead,			/* How much space is available in the
				 * buffer? */
    int *errorCodePtr)		/* Where to store error code. */
{
    FileState *fsPtr = (FileState *)instanceData;
    ssize_t bytesRead;	/* How many bytes were actually read from the
				 * input device? */

    *errorCodePtr = 0;

    /*
     * Assume there is always enough input available. This will block
     * appropriately, and read will unblock as soon as a short read is
     * possible, if the channel is in blocking mode. If the channel is
     * nonblocking, the read will never block.
     */

    do {
	bytesRead = read(fsPtr->fd, buf, toRead);
    } while ((bytesRead < 0) && (errno == EINTR));

    if (bytesRead < 0) {
	*errorCodePtr = errno;
	return -1;
    }
    return (int)bytesRead;
}

/*
 *----------------------------------------------------------------------
 *
 * FileOutputProc--
 *
 *	This function is invoked from the generic IO level to write output to
 *	a file channel.
 *
 * Results:
 *	The number of bytes written is returned or -1 on error. An output
 *	argument contains a POSIX error code if an error occurred, or zero.
 *
 * Side effects:
 *	Writes output on the output device of the channel.
 *
 *----------------------------------------------------------------------
 */

static int
FileOutputProc(
    void *instanceData,		/* File state. */
    const char *buf,		/* The data buffer. */
    int toWrite,		/* How many bytes to write? */
    int *errorCodePtr)		/* Where to store error code. */
{
    FileState *fsPtr = (FileState *)instanceData;
    ssize_t written;

    *errorCodePtr = 0;

    if (toWrite == 0) {
	/*
	 * SF Tcl Bug 465765. Do not try to write nothing into a file. STREAM
	 * based implementations will considers this as EOF (if there is a
	 * pipe behind the file).
	 */

	return 0;
    }
    written = write(fsPtr->fd, buf, toWrite);
    if (written >= 0) {
	return (int)written;
    }
    *errorCodePtr = errno;
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * FileCloseProc, TtyCloseProc --
 *
 *	These functions are called from the generic IO level to perform
 *	channel-type-specific cleanup when a file- or tty-based channel is
 *	closed.
 *
 * Results:
 *	0 if successful, errno if failed.
 *
 * Side effects:
 *	Closes the device of the channel.
 *
 *----------------------------------------------------------------------
 */

static int
FileCloseProc(
    void *instanceData,		/* File state. */
    TCL_UNUSED(Tcl_Interp *),
    int flags)
{
    FileState *fsPtr = (FileState *)instanceData;
    int errorCode = 0;

    if ((flags & (TCL_CLOSE_READ | TCL_CLOSE_WRITE)) != 0) {
	return EINVAL;
    }

    Tcl_DeleteFileHandler(fsPtr->fd);

    /*
     * Do not close standard channels while in thread-exit.
     */

    if (!TclInThreadExit()
	    || ((fsPtr->fd != 0) && (fsPtr->fd != 1) && (fsPtr->fd != 2))) {
	if (close(fsPtr->fd) < 0) {
	    errorCode = errno;
	}
    }
    Tcl_Free(fsPtr);
    return errorCode;
}

#ifdef SUPPORTS_TTY
static int
TtyCloseProc(
    void *instanceData,
    Tcl_Interp *interp,
	int flags)
{
    TtyState *ttyPtr = (TtyState*)instanceData;

    if ((flags & (TCL_CLOSE_READ | TCL_CLOSE_WRITE)) != 0) {
	return EINVAL;
    }
    /*
     * If we've been asked by the user to drain or flush, do so now.
     */

    switch (ttyPtr->closeMode) {
    case CLOSE_DRAIN:
	tcdrain(ttyPtr->fileState.fd);
	break;
    case CLOSE_DISCARD:
	tcflush(ttyPtr->fileState.fd, TCIOFLUSH);
	break;
    default:
	/* Do nothing */
	break;
    }

    /*
     * If we've had our state changed from the default, reset now.
     */

    if (ttyPtr->doReset) {
	tcsetattr(ttyPtr->fileState.fd, TCSANOW, &ttyPtr->initState);
    }

    /*
     * Delegate to close for files.
     */

    return FileCloseProc(instanceData, interp, flags);
}
#endif /* SUPPORTS_TTY */

/*
 *----------------------------------------------------------------------
 *
 * FileWideSeekProc --
 *
 *	This function is called by the generic IO level to move the access
 *	point in a file based channel, with offsets expressed as wide
 *	integers.
 *
 * Results:
 *	-1 if failed, the new position if successful. An output argument
 *	contains the POSIX error code if an error occurred, or zero.
 *
 * Side effects:
 *	Moves the location at which the channel will be accessed in future
 *	operations.
 *
 *----------------------------------------------------------------------
 */

static long long
FileWideSeekProc(
    void *instanceData,		/* File state. */
    long long offset,		/* Offset to seek to. */
    int mode,			/* Relative to where should we seek? Can be
				 * one of SEEK_START, SEEK_CUR or SEEK_END. */
    int *errorCodePtr)		/* To store error code. */
{
    FileState *fsPtr = (FileState *)instanceData;
    long long newLoc;

    newLoc = TclOSseek(fsPtr->fd, (Tcl_SeekOffset) offset, mode);

    *errorCodePtr = (newLoc == -1) ? errno : 0;
    return newLoc;
}

/*
 *----------------------------------------------------------------------
 *
 * FileWatchProc --
 *
 *	Initialize the notifier to watch the fd from this channel.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Sets up the notifier so that a future event on the channel will
 *	be seen by Tcl.
 *
 *----------------------------------------------------------------------
 */

/*
 * Bug ad5a57f2f271: Tcl_NotifyChannel is not a Tcl_FileProc,
 * so do not pass it to directly to Tcl_CreateFileHandler.
 * Instead, pass a wrapper which is a Tcl_FileProc.
 */
static void
FileWatchNotifyChannelWrapper(
    void *clientData,
    int mask)
{
    Tcl_Channel channel = (Tcl_Channel)clientData;
    Tcl_NotifyChannel(channel, mask);
}

static void
FileWatchProc(
    void *instanceData,		/* The file state. */
    int mask)			/* Events of interest; an OR-ed combination of
				 * TCL_READABLE, TCL_WRITABLE and
				 * TCL_EXCEPTION. */
{
    FileState *fsPtr = (FileState *)instanceData;

    /*
     * Make sure we only register for events that are valid on this file.
     */

    mask &= fsPtr->validMask;
    if (mask) {
	Tcl_CreateFileHandler(fsPtr->fd, mask,
		FileWatchNotifyChannelWrapper, fsPtr->channel);
    } else {
	Tcl_DeleteFileHandler(fsPtr->fd);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FileGetHandleProc --
 *
 *	Called from Tcl_GetChannelHandle to retrieve OS handles from a file
 *	based channel.
 *
 * Results:
 *	Returns TCL_OK with the fd in handlePtr, or TCL_ERROR if there is no
 *	handle for the specified direction.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
FileGetHandleProc(
    void *instanceData,		/* The file state. */
    int direction,		/* TCL_READABLE or TCL_WRITABLE */
    void **handlePtr)		/* Where to store the handle. */
{
    FileState *fsPtr = (FileState *)instanceData;

    if (direction & fsPtr->validMask) {
	*handlePtr = INT2PTR(fsPtr->fd);
	return TCL_OK;
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * FileGetOptionProc --
 *
 *	Gets an option associated with an open file. If the optionName arg is
 *	non-NULL, retrieves the value of that option. If the optionName arg is
 *	NULL, retrieves a list of alternating option names and values for the
 *	given channel.
 *
 * Results:
 *	A standard Tcl result. Also sets the supplied DString to the string
 *	value of the option(s) returned.  Sets error message if needed
 *	(by calling Tcl_BadChannelOption).
 *
 *----------------------------------------------------------------------
 */

static inline const char *
GetTypeFromMode(
    int mode)
{
    /*
     * TODO: deduplicate with tclCmdAH.c
     */

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

static Tcl_Obj *
StatOpenFile(
    FileState *fsPtr)
{
    Tcl_StatBuf statBuf;	/* Not allocated on heap; we're definitely
				 * API-synchronized with how Tcl is built! */
    Tcl_Obj *dictObj;
    unsigned short mode;

    if (TclOSfstat(fsPtr->fd, &statBuf) < 0) {
	return NULL;
    }

    /*
     * TODO: merge with TIP 594 implementation (it's silly to have a
     * duplicate!)
     */

    TclNewObj(dictObj);
#define STORE_ELEM(name, value) TclDictPut(NULL, dictObj, name, value)

    STORE_ELEM("dev",     Tcl_NewWideIntObj((long) statBuf.st_dev));
    STORE_ELEM("ino",     Tcl_NewWideIntObj((Tcl_WideInt) statBuf.st_ino));
    STORE_ELEM("nlink",   Tcl_NewWideIntObj((long) statBuf.st_nlink));
    STORE_ELEM("uid",     Tcl_NewWideIntObj((long) statBuf.st_uid));
    STORE_ELEM("gid",     Tcl_NewWideIntObj((long) statBuf.st_gid));
    STORE_ELEM("size",    Tcl_NewWideIntObj((Tcl_WideInt) statBuf.st_size));
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
    STORE_ELEM("blocks",  Tcl_NewWideIntObj((Tcl_WideInt) statBuf.st_blocks));
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
    STORE_ELEM("blksize", Tcl_NewWideIntObj((long) statBuf.st_blksize));
#endif
#ifdef HAVE_STRUCT_STAT_ST_RDEV
    if (S_ISCHR(statBuf.st_mode) || S_ISBLK(statBuf.st_mode)) {
	STORE_ELEM("rdev", Tcl_NewWideIntObj((long) statBuf.st_rdev));
    }
#endif
    STORE_ELEM("atime",   Tcl_NewWideIntObj(
	    Tcl_GetAccessTimeFromStat(&statBuf)));
    STORE_ELEM("mtime",   Tcl_NewWideIntObj(
	    Tcl_GetModificationTimeFromStat(&statBuf)));
    STORE_ELEM("ctime",   Tcl_NewWideIntObj(
	    Tcl_GetChangeTimeFromStat(&statBuf)));
    mode = (unsigned short) statBuf.st_mode;
    STORE_ELEM("mode",    Tcl_NewWideIntObj(mode));
    STORE_ELEM("type",    Tcl_NewStringObj(GetTypeFromMode(mode), -1));
#undef STORE_ELEM

    return dictObj;
}

static int
FileGetOptionProc(
    void *instanceData,
    Tcl_Interp *interp,
    const char *optionName,
    Tcl_DString *dsPtr)
{
    FileState *fsPtr = (FileState *)instanceData;
    int valid = 0;		/* Flag if valid option parsed. */
    size_t len;

    if (optionName == NULL) {
	len = 0;
	valid = 1;
    } else {
	len = strlen(optionName);
    }

    /*
     * Get option -stat
     * Option is readonly and returned by [fconfigure chan -stat] but not
     * returned by [fconfigure chan] without explicit option name.
     */

    if ((len > 1) && (strncmp(optionName, "-stat", len) == 0)) {
	Tcl_Obj *dictObj = StatOpenFile(fsPtr);
	const char *dictContents;
	Tcl_Size dictLength;

	if (dictObj == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "couldn't read file channel status: %s",
		    Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}

	/*
	 * Transfer dictionary to the DString. Note that we don't do this as
	 * an element as this is an option that can't be retrieved with a
	 * general probe.
	 */

	dictContents = TclGetStringFromObj(dictObj, &dictLength);
	Tcl_DStringAppend(dsPtr, dictContents, dictLength);
	Tcl_DecrRefCount(dictObj);
	return TCL_OK;
    }

    if (valid) {
	return TCL_OK;
    }
    return Tcl_BadChannelOption(interp, optionName,
		"stat");
}

#ifdef SUPPORTS_TTY
/*
 *----------------------------------------------------------------------
 *
 * TtyModemStatusStr --
 *
 *	Converts a RS232 modem status list of readable flags
 *
 *----------------------------------------------------------------------
 */

static void
TtyModemStatusStr(
    int status,			/* RS232 modem status */
    Tcl_DString *dsPtr)		/* Where to store string */
{
#ifdef TIOCM_CTS
    Tcl_DStringAppendElement(dsPtr, "CTS");
    Tcl_DStringAppendElement(dsPtr, (status & TIOCM_CTS) ? "1" : "0");
#endif /* TIOCM_CTS */
#ifdef TIOCM_DSR
    Tcl_DStringAppendElement(dsPtr, "DSR");
    Tcl_DStringAppendElement(dsPtr, (status & TIOCM_DSR) ? "1" : "0");
#endif /* TIOCM_DSR */
#ifdef TIOCM_RNG
    Tcl_DStringAppendElement(dsPtr, "RING");
    Tcl_DStringAppendElement(dsPtr, (status & TIOCM_RNG) ? "1" : "0");
#endif /* TIOCM_RNG */
#ifdef TIOCM_CD
    Tcl_DStringAppendElement(dsPtr, "DCD");
    Tcl_DStringAppendElement(dsPtr, (status & TIOCM_CD) ? "1" : "0");
#endif /* TIOCM_CD */
}

/*
 *----------------------------------------------------------------------
 *
 * TtySetOptionProc --
 *
 *	Sets an option on a channel.
 *
 * Results:
 *	A standard Tcl result. Also sets the interp's result on error if
 *	interp is not NULL.
 *
 * Side effects:
 *	May modify an option on a device. Sets Error message if needed (by
 *	calling Tcl_BadChannelOption).
 *
 *----------------------------------------------------------------------
 */

static int
TtySetOptionProc(
    void *instanceData,		/* File state. */
    Tcl_Interp *interp,		/* For error reporting - can be NULL. */
    const char *optionName,	/* Which option to set? */
    const char *value)		/* New value for option. */
{
    TtyState *fsPtr = (TtyState *)instanceData;
    size_t len, vlen;
    TtyAttrs tty;
    Tcl_Size argc;
    const char **argv;
    struct termios iostate;

    len = strlen(optionName);
    vlen = strlen(value);

    /*
     * Option -mode baud,parity,databits,stopbits
     */

    if ((len > 2) && (strncmp(optionName, "-mode", len) == 0)) {
	if (TtyParseMode(interp, value, &tty) != TCL_OK) {
	    return TCL_ERROR;
	}

	/*
	 * system calls results should be checked there. - dl
	 */

	TtySetAttributes(fsPtr->fileState.fd, &tty);
	return TCL_OK;
    }

    /*
     * Option -handshake none|xonxoff|rtscts|dtrdsr
     */

    if ((len > 1) && (strncmp(optionName, "-handshake", len) == 0)) {
	/*
	 * Reset all handshake options. DTR and RTS are ON by default.
	 */

	tcgetattr(fsPtr->fileState.fd, &iostate);
	CLEAR_BITS(iostate.c_iflag, IXON | IXOFF | IXANY);
#ifdef CRTSCTS
	CLEAR_BITS(iostate.c_cflag, CRTSCTS);
#endif /* CRTSCTS */
	if (strncasecmp(value, "NONE", vlen) == 0) {
	    /*
	     * Leave all handshake options disabled.
	     */
	} else if (strncasecmp(value, "XONXOFF", vlen) == 0) {
	    SET_BITS(iostate.c_iflag, IXON | IXOFF | IXANY);
	} else if (strncasecmp(value, "RTSCTS", vlen) == 0) {
#ifdef CRTSCTS
	    SET_BITS(iostate.c_cflag, CRTSCTS);
#else /* !CRTSTS */
	    UNSUPPORTED_OPTION("-handshake RTSCTS");
	    return TCL_ERROR;
#endif /* CRTSCTS */
	} else if (strncasecmp(value, "DTRDSR", vlen) == 0) {
	    UNSUPPORTED_OPTION("-handshake DTRDSR");
	    return TCL_ERROR;
	} else {
	    if (interp) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"bad value for -handshake: must be one of"
			" xonxoff, rtscts, dtrdsr or none", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "FCONFIGURE",
			"VALUE", (char *)NULL);
	    }
	    return TCL_ERROR;
	}
	tcsetattr(fsPtr->fileState.fd, TCSADRAIN, &iostate);
	return TCL_OK;
    }

    /*
     * Option -xchar {\x11 \x13}
     */

    if ((len > 1) && (strncmp(optionName, "-xchar", len) == 0)) {
	if (Tcl_SplitList(interp, value, &argc, &argv) == TCL_ERROR) {
	    return TCL_ERROR;
	} else if (argc != 2) {
	badXchar:
	    if (interp) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"bad value for -xchar: should be a list of"
			" two elements with each a single 8-bit character", -1));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "XCHAR", (char *)NULL);
	    }
	    Tcl_Free(argv);
	    return TCL_ERROR;
	}

	tcgetattr(fsPtr->fileState.fd, &iostate);

	iostate.c_cc[VSTART] = argv[0][0];
	iostate.c_cc[VSTOP] = argv[1][0];
	if (argv[0][0] & 0x80 || argv[1][0] & 0x80) {
	    Tcl_UniChar character = 0;
	    Tcl_Size charLen;

	    charLen = TclUtfToUniChar(argv[0], &character);
	    if ((character > 0xFF) || argv[0][charLen]) {
		goto badXchar;
	    }
	    iostate.c_cc[VSTART] = (cc_t)character;
	    charLen = TclUtfToUniChar(argv[1], &character);
	    if ((character > 0xFF) || argv[1][charLen]) {
		goto badXchar;
	    }
	    iostate.c_cc[VSTOP] = (cc_t)character;
	}
	Tcl_Free(argv);

	tcsetattr(fsPtr->fileState.fd, TCSADRAIN, &iostate);
	return TCL_OK;
    }

    /*
     * Option -timeout msec
     */

    if ((len > 2) && (strncmp(optionName, "-timeout", len) == 0)) {
	int msec;

	tcgetattr(fsPtr->fileState.fd, &iostate);
	if (Tcl_GetInt(interp, value, &msec) != TCL_OK) {
	    return TCL_ERROR;
	}
	iostate.c_cc[VMIN] = 0;
	iostate.c_cc[VTIME] = (msec==0) ? 0 : (msec<100) ? 1 : (cc_t)((msec+50)/100);
	tcsetattr(fsPtr->fileState.fd, TCSADRAIN, &iostate);
	return TCL_OK;
    }

    /*
     * Option -ttycontrol {DTR 1 RTS 0 BREAK 0}
     */

    if ((len > 4) && (strncmp(optionName, "-ttycontrol", len) == 0)) {
#if defined(TIOCMGET) && defined(TIOCMSET)
	int control, flag;
	Tcl_Size i;

	if (Tcl_SplitList(interp, value, &argc, &argv) == TCL_ERROR) {
	    return TCL_ERROR;
	}
	if ((argc % 2) == 1) {
	    if (interp) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"bad value for -ttycontrol: should be a list of"
			" signal,value pairs", -1));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "FCONFIGURE",
			"VALUE", (char *)NULL);
	    }
	    Tcl_Free(argv);
	    return TCL_ERROR;
	}

	ioctl(fsPtr->fileState.fd, TIOCMGET, &control);
	for (i = 0; i < argc-1; i += 2) {
	    if (Tcl_GetBoolean(interp, argv[i+1], &flag) == TCL_ERROR) {
		Tcl_Free(argv);
		return TCL_ERROR;
	    }
	    if (strncasecmp(argv[i], "DTR", strlen(argv[i])) == 0) {
		if (flag) {
		    SET_BITS(control, TIOCM_DTR);
		} else {
		    CLEAR_BITS(control, TIOCM_DTR);
		}
	    } else if (strncasecmp(argv[i], "RTS", strlen(argv[i])) == 0) {
		if (flag) {
		    SET_BITS(control, TIOCM_RTS);
		} else {
		    CLEAR_BITS(control, TIOCM_RTS);
		}
	    } else if (strncasecmp(argv[i], "BREAK", strlen(argv[i])) == 0) {
#if defined(TIOCSBRK) && defined(TIOCCBRK)
		if (flag) {
		    ioctl(fsPtr->fileState.fd, TIOCSBRK, NULL);
		} else {
		    ioctl(fsPtr->fileState.fd, TIOCCBRK, NULL);
		}
#else /* TIOCSBRK & TIOCCBRK */
		UNSUPPORTED_OPTION("-ttycontrol BREAK");
		Tcl_Free(argv);
		return TCL_ERROR;
#endif /* TIOCSBRK & TIOCCBRK */
	    } else {
		if (interp) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "bad signal \"%s\" for -ttycontrol: must be"
			    " DTR, RTS or BREAK", argv[i]));
		    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "FCONFIGURE",
			"VALUE", (char *)NULL);
		}
		Tcl_Free(argv);
		return TCL_ERROR;
	    }
	} /* -ttycontrol options loop */

	ioctl(fsPtr->fileState.fd, TIOCMSET, &control);
	Tcl_Free(argv);
	return TCL_OK;
#else /* TIOCMGET&TIOCMSET */
	UNSUPPORTED_OPTION("-ttycontrol");
#endif /* TIOCMGET&TIOCMSET */
    }

    /*
     * Option -closemode drain|discard
     */

    if ((len > 2) && (strncmp(optionName, "-closemode", len) == 0)) {
	if (strncasecmp(value, "DEFAULT", vlen) == 0) {
	    fsPtr->closeMode = CLOSE_DEFAULT;
	} else if (strncasecmp(value, "DRAIN", vlen) == 0) {
	    fsPtr->closeMode = CLOSE_DRAIN;
	} else if (strncasecmp(value, "DISCARD", vlen) == 0) {
	    fsPtr->closeMode = CLOSE_DISCARD;
	} else {
	    if (interp) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"bad mode \"%s\" for -closemode: must be"
			" default, discard, or drain", value));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "FCONFIGURE",
			"VALUE", (char *)NULL);
	    }
	    return TCL_ERROR;
	}
	return TCL_OK;
    }

    /*
     * Option -inputmode normal|password|raw
     */

    if ((len > 2) && (strncmp(optionName, "-inputmode", len) == 0)) {
	if (tcgetattr(fsPtr->fileState.fd, &iostate) < 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"couldn't read serial terminal control state: %s",
			Tcl_PosixError(interp)));
	    }
	    return TCL_ERROR;
	}
	if (strncasecmp(value, "NORMAL", vlen) == 0) {
	    SET_BITS(iostate.c_iflag, BRKINT | IGNPAR | ISTRIP | ICRNL | IXON);
	    SET_BITS(iostate.c_oflag, OPOST);
	    SET_BITS(iostate.c_lflag, ECHO | ECHONL | ICANON | ISIG);
	} else if (strncasecmp(value, "PASSWORD", vlen) == 0) {
	    SET_BITS(iostate.c_iflag, BRKINT | IGNPAR | ISTRIP | ICRNL | IXON);
	    SET_BITS(iostate.c_oflag, OPOST);
	    CLEAR_BITS(iostate.c_lflag, ECHO);
	    /*
	     * Note: password input turns out to be best if you echo the
	     * newline that the user types. Theoretically we could get users
	     * to do the processing of this in their scripts, but it always
	     * feels highly unnatural to do so in practice.
	     */
	    SET_BITS(iostate.c_lflag, ECHONL | ICANON | ISIG);
	} else if (strncasecmp(value, "RAW", vlen) == 0) {
#ifdef HAVE_CFMAKERAW
	    cfmakeraw(&iostate);
#else /* !HAVE_CFMAKERAW */
	    CLEAR_BITS(iostate.c_iflag, IGNBRK | BRKINT | PARMRK | ISTRIP
		    | INLCR | IGNCR | ICRNL | IXON);
	    CLEAR_BITS(iostate.c_oflag, OPOST);
	    CLEAR_BITS(iostate.c_lflag, ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	    CLEAR_BITS(iostate.c_cflag, CSIZE | PARENB);
	    SET_BITS(iostate.c_cflag, CS8);
#endif /* HAVE_CFMAKERAW */
	} else if (strncasecmp(value, "RESET", vlen) == 0) {
	    /*
	     * Reset to the initial state, whatever that is.
	     */

	    memcpy(&iostate, &fsPtr->initState, sizeof(struct termios));
	} else {
	    if (interp) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"bad mode \"%s\" for -inputmode: must be"
			" normal, password, raw, or reset", value));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "FCONFIGURE",
			"VALUE", (char *)NULL);
	    }
	    return TCL_ERROR;
	}
	if (tcsetattr(fsPtr->fileState.fd, TCSADRAIN, &iostate) < 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"couldn't update serial terminal control state: %s",
			Tcl_PosixError(interp)));
	    }
	    return TCL_ERROR;
	}

	/*
	 * If we've changed the state from default, schedule a reset later.
	 * Note that this specifically does not detect changes made by calling
	 * an external stty program; that is deliberate, as it maintains
	 * compatibility with existing code!
	 *
	 * This mechanism in Tcl is not intended to be a full replacement for
	 * what stty does; it just handles a few common cases and tries not to
	 * leave things in a broken state.
	 */

	fsPtr->doReset = (memcmp(&iostate, &fsPtr->initState,
		sizeof(struct termios)) != 0);
	return TCL_OK;
    }

    return Tcl_BadChannelOption(interp, optionName,
	    "closemode inputmode mode handshake timeout ttycontrol xchar");
}

/*
 *----------------------------------------------------------------------
 *
 * TtyGetOptionProc --
 *
 *	Gets a mode associated with an IO channel. If the optionName arg is
 *	non-NULL, retrieves the value of that option. If the optionName arg is
 *	NULL, retrieves a list of alternating option names and values for the
 *	given channel.
 *
 * Results:
 *	A standard Tcl result. Also sets the supplied DString to the string
 *	value of the option(s) returned.  Sets error message if needed
 *	(by calling Tcl_BadChannelOption).
 *
 *----------------------------------------------------------------------
 */

static int
TtyGetOptionProc(
    void *instanceData,		/* File state. */
    Tcl_Interp *interp,		/* For error reporting - can be NULL. */
    const char *optionName,	/* Option to get. */
    Tcl_DString *dsPtr)		/* Where to store value(s). */
{
    TtyState *fsPtr = (TtyState *)instanceData;
    size_t len;
    char buf[3*TCL_INTEGER_SPACE + 16];
    int valid = 0;		/* Flag if valid option parsed. */
    struct termios iostate;

    if (optionName == NULL) {
	len = 0;
    } else {
	len = strlen(optionName);
    }

    /*
     * Get option -closemode
     */

    if (len == 0) {
	Tcl_DStringAppendElement(dsPtr, "-closemode");
    }
    if (len==0 || (len>1 && strncmp(optionName, "-closemode", len)==0)) {
	switch (fsPtr->closeMode) {
	case CLOSE_DRAIN:
	    Tcl_DStringAppendElement(dsPtr, "drain");
	    break;
	case CLOSE_DISCARD:
	    Tcl_DStringAppendElement(dsPtr, "discard");
	    break;
	default:
	    Tcl_DStringAppendElement(dsPtr, "default");
	    break;
	}
    }

    /*
     * Get option -inputmode
     *
     * This is a great simplification of the underlying reality, but actually
     * represents what almost all scripts really want to know.
     */

    if (len == 0) {
	Tcl_DStringAppendElement(dsPtr, "-inputmode");
    }
    if (len==0 || (len>1 && strncmp(optionName, "-inputmode", len)==0)) {
	valid = 1;
	if (tcgetattr(fsPtr->fileState.fd, &iostate) < 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"couldn't read serial terminal control state: %s",
			Tcl_PosixError(interp)));
	    }
	    return TCL_ERROR;
	}
	if (iostate.c_lflag & ICANON) {
	    if (iostate.c_lflag & ECHO) {
		Tcl_DStringAppendElement(dsPtr, "normal");
	    } else {
		Tcl_DStringAppendElement(dsPtr, "password");
	    }
	} else {
	    Tcl_DStringAppendElement(dsPtr, "raw");
	}
    }

    /*
     * Get option -mode
     */

    if (len == 0) {
	Tcl_DStringAppendElement(dsPtr, "-mode");
    }
    if (len==0 || (len>2 && strncmp(optionName, "-mode", len)==0)) {
	TtyAttrs tty;

	valid = 1;
	TtyGetAttributes(fsPtr->fileState.fd, &tty);
	snprintf(buf, sizeof(buf), "%d,%c,%d,%d", tty.baud, tty.parity, tty.data, tty.stop);
	Tcl_DStringAppendElement(dsPtr, buf);
    }

    /*
     * Get option -xchar
     */

    if (len == 0) {
	Tcl_DStringAppendElement(dsPtr, "-xchar");
	Tcl_DStringStartSublist(dsPtr);
    }
    if (len==0 || (len>1 && strncmp(optionName, "-xchar", len)==0)) {
	Tcl_DString ds;

	valid = 1;
	tcgetattr(fsPtr->fileState.fd, &iostate);
	Tcl_DStringInit(&ds);

	Tcl_ExternalToUtfDStringEx(NULL, NULL, (char *) &iostate.c_cc[VSTART], 1, TCL_ENCODING_PROFILE_TCL8, &ds, NULL);
	Tcl_DStringAppendElement(dsPtr, Tcl_DStringValue(&ds));
	TclDStringClear(&ds);

	Tcl_ExternalToUtfDStringEx(NULL, NULL, (char *) &iostate.c_cc[VSTOP], 1, TCL_ENCODING_PROFILE_TCL8, &ds, NULL);
	Tcl_DStringAppendElement(dsPtr, Tcl_DStringValue(&ds));
	Tcl_DStringFree(&ds);
    }
    if (len == 0) {
	Tcl_DStringEndSublist(dsPtr);
    }

    /*
     * Get option -queue
     * Option is readonly and returned by [fconfigure chan -queue] but not
     * returned by unnamed [fconfigure chan].
     */

    if ((len > 1) && (strncmp(optionName, "-queue", len) == 0)) {
	int inQueue=0, outQueue=0, inBuffered, outBuffered;

	valid = 1;
	GETREADQUEUE(fsPtr->fileState.fd, inQueue);
	GETWRITEQUEUE(fsPtr->fileState.fd, outQueue);
	inBuffered = Tcl_InputBuffered(fsPtr->fileState.channel);
	outBuffered = Tcl_OutputBuffered(fsPtr->fileState.channel);

	snprintf(buf, sizeof(buf), "%d", inBuffered+inQueue);
	Tcl_DStringAppendElement(dsPtr, buf);
	snprintf(buf, sizeof(buf), "%d", outBuffered+outQueue);
	Tcl_DStringAppendElement(dsPtr, buf);
    }

#if defined(TIOCMGET)
    /*
     * Get option -ttystatus
     * Option is readonly and returned by [fconfigure chan -ttystatus] but not
     * returned by unnamed [fconfigure chan].
     */

    if ((len > 4) && (strncmp(optionName, "-ttystatus", len) == 0)) {
	int status;

	valid = 1;
	ioctl(fsPtr->fileState.fd, TIOCMGET, &status);
	TtyModemStatusStr(status, dsPtr);
    }
#endif /* TIOCMGET */

#if defined(TIOCGWINSZ)
    /*
     * Get option -winsize
     * Option is readonly and returned by [fconfigure chan -winsize] but not
     * returned by [fconfigure chan] without explicit option name.
     */

    if ((len > 1) && (strncmp(optionName, "-winsize", len) == 0)) {
	struct winsize ws;

	valid = 1;
	if (ioctl(fsPtr->fileState.fd, TIOCGWINSZ, &ws) < 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"couldn't read terminal size: %s",
			Tcl_PosixError(interp)));
	    }
	    return TCL_ERROR;
	}
	snprintf(buf, sizeof(buf), "%d", ws.ws_col);
	Tcl_DStringAppendElement(dsPtr, buf);
	snprintf(buf, sizeof(buf), "%d", ws.ws_row);
	Tcl_DStringAppendElement(dsPtr, buf);
    }
#endif /* TIOCGWINSZ */

    if (valid) {
	return TCL_OK;
    }
    return Tcl_BadChannelOption(interp, optionName,
	    "closemode inputmode mode queue ttystatus winsize xchar");
}

static const struct {int baud; speed_t speed;} speeds[] = {
#ifdef B0
    {0, B0},
#endif
#ifdef B50
    {50, B50},
#endif
#ifdef B75
    {75, B75},
#endif
#ifdef B110
    {110, B110},
#endif
#ifdef B134
    {134, B134},
#endif
#ifdef B150
    {150, B150},
#endif
#ifdef B200
    {200, B200},
#endif
#ifdef B300
    {300, B300},
#endif
#ifdef B600
    {600, B600},
#endif
#ifdef B1200
    {1200, B1200},
#endif
#ifdef B1800
    {1800, B1800},
#endif
#ifdef B2400
    {2400, B2400},
#endif
#ifdef B4800
    {4800, B4800},
#endif
#ifdef B9600
    {9600, B9600},
#endif
#ifdef B14400
    {14400, B14400},
#endif
#ifdef B19200
    {19200, B19200},
#endif
#ifdef EXTA
    {19200, EXTA},
#endif
#ifdef B28800
    {28800, B28800},
#endif
#ifdef B38400
    {38400, B38400},
#endif
#ifdef EXTB
    {38400, EXTB},
#endif
#ifdef B57600
    {57600, B57600},
#endif
#ifdef _B57600
    {57600, _B57600},
#endif
#ifdef B76800
    {76800, B76800},
#endif
#ifdef B115200
    {115200, B115200},
#endif
#ifdef _B115200
    {115200, _B115200},
#endif
#ifdef B153600
    {153600, B153600},
#endif
#ifdef B230400
    {230400, B230400},
#endif
#ifdef B307200
    {307200, B307200},
#endif
#ifdef B460800
    {460800, B460800},
#endif
#ifdef B500000
    {500000, B500000},
#endif
#ifdef B576000
    {576000, B576000},
#endif
#ifdef B921600
    {921600, B921600},
#endif
#ifdef B1000000
    {1000000, B1000000},
#endif
#ifdef B1152000
    {1152000, B1152000},
#endif
#ifdef B1500000
    {1500000,B1500000},
#endif
#ifdef B2000000
    {2000000, B2000000},
#endif
#ifdef B2500000
    {2500000,B2500000},
#endif
#ifdef B3000000
    {3000000,B3000000},
#endif
#ifdef B3500000
    {3500000,B3500000},
#endif
#ifdef B4000000
    {4000000,B4000000},
#endif
    {-1, 0}
};

/*
 *---------------------------------------------------------------------------
 *
 * TtyGetSpeed --
 *
 *	Given an integer baud rate, get the speed_t value that should be
 *	used to select that baud rate.
 *
 * Results:
 *	As above.
 *
 *---------------------------------------------------------------------------
 */

static speed_t
TtyGetSpeed(
    int baud)			/* The baud rate to look up. */
{
    int bestIdx, bestDiff, i, diff;

    bestIdx = 0;
    bestDiff = 1000000;

    /*
     * If the baud rate does not correspond to one of the known mask values,
     * choose the mask value whose baud rate is closest to the specified baud
     * rate.
     */

    for (i = 0; speeds[i].baud >= 0; i++) {
	diff = speeds[i].baud - baud;
	if (diff < 0) {
	    diff = -diff;
	}
	if (diff < bestDiff) {
	    bestIdx = i;
	    bestDiff = diff;
	}
    }
    return speeds[bestIdx].speed;
}

/*
 *---------------------------------------------------------------------------
 *
 * TtyGetBaud --
 *
 *	Return the integer baud rate corresponding to a given speed_t value.
 *
 * Results:
 *	As above. If the mask value was not recognized, 0 is returned.
 *
 *---------------------------------------------------------------------------
 */

static int
TtyGetBaud(
    speed_t speed)		/* Speed mask value to look up. */
{
    int i;

    for (i = 0; speeds[i].baud >= 0; i++) {
	if (speeds[i].speed == speed) {
	    return speeds[i].baud;
	}
    }
    return 0;
}

/*
 *---------------------------------------------------------------------------
 *
 * TtyGetAttributes --
 *
 *	Get the current attributes of the specified serial device.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static void
TtyGetAttributes(
    int fd,			/* Open file descriptor for serial port to be
				 * queried. */
    TtyAttrs *ttyPtr)		/* Buffer filled with serial port
				 * attributes. */
{
    struct termios iostate;
    int baud, parity, data, stop;

    tcgetattr(fd, &iostate);

    baud = TtyGetBaud(cfgetospeed(&iostate));

    parity = 'n';
#ifdef PAREXT
    switch ((int) (iostate.c_cflag & (PARENB | PARODD | PAREXT))) {
    case PARENB			  :	parity = 'e'; break;
    case PARENB | PARODD	  :	parity = 'o'; break;
    case PARENB |	   PAREXT :	parity = 's'; break;
    case PARENB | PARODD | PAREXT :	parity = 'm'; break;
    }
#else /* !PAREXT */
    switch ((int) (iostate.c_cflag & (PARENB | PARODD))) {
    case PARENB		 :		parity = 'e'; break;
    case PARENB | PARODD :		parity = 'o'; break;
    }
#endif /* PAREXT */

    data = iostate.c_cflag & CSIZE;
    data = (data == CS5) ? 5 : (data == CS6) ? 6 : (data == CS7) ? 7 : 8;

    stop = (iostate.c_cflag & CSTOPB) ? 2 : 1;

    ttyPtr->baud    = baud;
    ttyPtr->parity  = parity;
    ttyPtr->data    = data;
    ttyPtr->stop    = stop;
}

/*
 *---------------------------------------------------------------------------
 *
 * TtySetAttributes --
 *
 *	Set the current attributes of the specified serial device.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static void
TtySetAttributes(
    int fd,			/* Open file descriptor for serial port to be
				 * modified. */
    TtyAttrs *ttyPtr)		/* Buffer containing new attributes for serial
				 * port. */
{
    struct termios iostate;
    int parity, data, flag;

    tcgetattr(fd, &iostate);
    cfsetospeed(&iostate, TtyGetSpeed(ttyPtr->baud));
    cfsetispeed(&iostate, TtyGetSpeed(ttyPtr->baud));

    flag = 0;
    parity = ttyPtr->parity;
    if (parity != 'n') {
	SET_BITS(flag, PARENB);
#ifdef PAREXT
	CLEAR_BITS(iostate.c_cflag, PAREXT);
	if ((parity == 'm') || (parity == 's')) {
	    SET_BITS(flag, PAREXT);
	}
#endif /* PAREXT */
	if ((parity == 'm') || (parity == 'o')) {
	    SET_BITS(flag, PARODD);
	}
    }
    data = ttyPtr->data;
    SET_BITS(flag,
	    (data == 5) ? CS5 :
	    (data == 6) ? CS6 :
	    (data == 7) ? CS7 : CS8);
    if (ttyPtr->stop == 2) {
	SET_BITS(flag, CSTOPB);
    }

    CLEAR_BITS(iostate.c_cflag, PARENB | PARODD | CSIZE | CSTOPB);
    SET_BITS(iostate.c_cflag, flag);

    tcsetattr(fd, TCSADRAIN, &iostate);
}

/*
 *---------------------------------------------------------------------------
 *
 * TtyParseMode --
 *
 *	Parse the "-mode" argument to the fconfigure command. The argument is
 *	of the form baud,parity,data,stop.
 *
 * Results:
 *	The return value is TCL_OK if the argument was successfully parsed,
 *	TCL_ERROR otherwise. If TCL_ERROR is returned, an error message is
 *	left in the interp's result (if interp is non-NULL).
 *
 *---------------------------------------------------------------------------
 */

static int
TtyParseMode(
    Tcl_Interp *interp,		/* If non-NULL, interp for error return. */
    const char *mode,		/* Mode string to be parsed. */
    TtyAttrs *ttyPtr)		/* Filled with data from mode string */
{
    int i, end;
    char parity;
    const char *bad = "bad value for -mode";

    i = sscanf(mode, "%d,%c,%d,%d%n",
	    &ttyPtr->baud,
	    &parity,
	    &ttyPtr->data,
	    &ttyPtr->stop, &end);
    if ((i != 4) || (mode[end] != '\0')) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s: should be baud,parity,data,stop", bad));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "SERIALMODE", (char *)NULL);
	}
	return TCL_ERROR;
    }

    /*
     * Only allow setting mark/space parity on platforms that support it Make
     * sure to allow for the case where strchr is a macro. [Bug: 5089]
     *
     * We cannot if/else/endif the strchr arguments, it has to be the whole
     * function. On AIX this function is apparently a macro, and macros do
     * not allow preprocessor directives in their arguments.
     */

#ifdef PAREXT
#define PARITY_CHARS	"noems"
#define PARITY_MSG	"n, o, e, m, or s"
#else
#define PARITY_CHARS	"noe"
#define PARITY_MSG	"n, o, or e"
#endif /* PAREXT */

    if (strchr(PARITY_CHARS, parity) == NULL) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s parity: should be %s", bad, PARITY_MSG));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "SERIALMODE", (char *)NULL);
	}
	return TCL_ERROR;
    }
    ttyPtr->parity = parity;
    if ((ttyPtr->data < 5) || (ttyPtr->data > 8)) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s data: should be 5, 6, 7, or 8", bad));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "SERIALMODE", (char *)NULL);
	}
	return TCL_ERROR;
    }
    if ((ttyPtr->stop < 0) || (ttyPtr->stop > 2)) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s stop: should be 1 or 2", bad));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "SERIALMODE", (char *)NULL);
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * TtyInit --
 *
 *	Given file descriptor that refers to a serial port, initialize the
 *	serial port to a set of sane values so that Tcl can talk to a device
 *	located on the serial port.
 *
 * Side effects:
 *	Serial device initialized to non-blocking raw mode, similar to sockets
 *	All other modes can be simulated on top of this in Tcl.
 *
 *---------------------------------------------------------------------------
 */

static void
TtyInit(
    int fd)			/* Open file descriptor for serial port to be
				 * initialized. */
{
    struct termios iostate;
    tcgetattr(fd, &iostate);

    if (iostate.c_iflag != IGNBRK
	    || iostate.c_oflag != 0
	    || iostate.c_lflag != 0
	    || iostate.c_cflag & CREAD
	    || iostate.c_cc[VMIN] != 1
	    || iostate.c_cc[VTIME] != 0) {
	iostate.c_iflag = IGNBRK;
	iostate.c_oflag = 0;
	iostate.c_lflag = 0;
	iostate.c_cflag |= CREAD;
	iostate.c_cc[VMIN] = 1;
	iostate.c_cc[VTIME] = 0;

	tcsetattr(fd, TCSADRAIN, &iostate);
    }
}
#endif	/* SUPPORTS_TTY */

/*
 *----------------------------------------------------------------------
 *
 * TclpOpenFileChannel --
 *
 *	Open an file based channel on Unix systems.
 *
 * Results:
 *	The new channel or NULL. If NULL, the output argument errorCodePtr is
 *	set to a POSIX error and an error message is left in the interp's
 *	result if interp is not NULL.
 *
 * Side effects:
 *	May open the channel and may cause creation of a file on the file
 *	system.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
TclpOpenFileChannel(
    Tcl_Interp *interp,		/* Interpreter for error reporting; can be
				 * NULL. */
    Tcl_Obj *pathPtr,		/* Name of file to open. */
    int mode,			/* POSIX open mode. */
    int permissions)		/* If the open involves creating a file, with
				 * what modes to create it? */
{
    int fd, channelPermissions;
    TtyState *fsPtr;
    const char *native, *translation;
    char channelName[16 + TCL_INTEGER_SPACE];
    const Tcl_ChannelType *channelTypePtr;

    switch (mode & O_ACCMODE) {
    case O_RDONLY:
	channelPermissions = TCL_READABLE;
	break;
    case O_WRONLY:
	channelPermissions = TCL_WRITABLE;
	break;
    case O_RDWR:
	channelPermissions = (TCL_READABLE | TCL_WRITABLE);
	break;
    default:
	/*
	 * This may occurr if modeString was "", for example.
	 */

	Tcl_Panic("TclpOpenFileChannel: invalid mode value");
	return NULL;
    }

    native = (const char *)Tcl_FSGetNativePath(pathPtr);
    if (native == NULL) {
	if (interp != (Tcl_Interp *) NULL) {
	    /*
	     * We need this just to ensure we return the correct error messages under
	     * some circumstances (relative paths only), so because the normalization
	     * is very expensive, don't invoke it for native or absolute paths.
	     * Note: since paths starting with ~ are absolute, it also considers tilde expansion,
	     * (proper error message of tests *io-40.17 "tilde substitution in open")
	     */
	    if (((!TclFSCwdIsNative()
		    && (Tcl_FSGetPathType(pathPtr) != TCL_PATH_ABSOLUTE))
		    || (*TclGetString(pathPtr) == '~'))  /* possible tilde expansion */
		    && Tcl_FSGetNormalizedPath(interp, pathPtr) == NULL) {
		return NULL;
	    }

	    Tcl_AppendResult(interp, "couldn't open \"",
		    TclGetString(pathPtr),
		    "\": filename is invalid on this platform", (char *)NULL);
	}
	return NULL;
    }

#ifdef DJGPP
    SET_BITS(mode, O_BINARY);
#endif

    fd = TclOSopen(native, mode, permissions);

    if (fd < 0) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "couldn't open \"%s\": %s",
		    TclGetString(pathPtr), Tcl_PosixError(interp)));
	}
	return NULL;
    }

    /*
     * Set close-on-exec flag on the fd so that child processes will not
     * inherit this fd.
     */

    fcntl(fd, F_SETFD, FD_CLOEXEC);

#ifdef SUPPORTS_TTY
    if (strcmp(native, "/dev/tty") != 0 && isatty(fd)) {
	/*
	 * Initialize the serial port to a set of sane parameters. Especially
	 * important if the remote device is set to echo and the serial port
	 * driver was also set to echo -- as soon as a char were sent to the
	 * serial port, the remote device would echo it, then the serial
	 * driver would echo it back to the device, etc.
	 *
	 * Note that we do not do this if we're dealing with /dev/tty itself,
	 * as that tends to cause Bad Things To Happen when you're working
	 * interactively. Strictly a better check would be to see if the FD
	 * being set up is a device and has the same major/minor as the
	 * initial std FDs (beware reopening!) but that's nearly as messy.
	 */

	translation = "auto crlf";
	channelTypePtr = &ttyChannelType;
	TtyInit(fd);
	snprintf(channelName, sizeof(channelName), "serial%d", fd);
    } else
#endif	/* SUPPORTS_TTY */
    {
	translation = NULL;
	channelTypePtr = &fileChannelType;
	snprintf(channelName, sizeof(channelName), "file%d", fd);
    }

    fsPtr = (TtyState *)Tcl_Alloc(sizeof(TtyState));
    fsPtr->fileState.validMask = channelPermissions | TCL_EXCEPTION;
    fsPtr->fileState.fd = fd;
#ifdef SUPPORTS_TTY
    if (channelTypePtr == &ttyChannelType) {
	fsPtr->closeMode = CLOSE_DEFAULT;
	fsPtr->doReset = 0;
	tcgetattr(fsPtr->fileState.fd, &fsPtr->initState);
    }
#endif /* SUPPORTS_TTY */

    fsPtr->fileState.channel = Tcl_CreateChannel(channelTypePtr, channelName,
	    fsPtr, channelPermissions);

    if (translation != NULL) {
	/*
	 * Gotcha. Most modems need a "\r" at the end of the command sequence.
	 * If you just send "at\n", the modem will not respond with "OK"
	 * because it never got a "\r" to actually invoke the command. So, by
	 * default, newlines are translated to "\r\n" on output to avoid "bug"
	 * reports that the serial port isn't working.
	 */

	if (Tcl_SetChannelOption(interp, fsPtr->fileState.channel,
		"-translation", translation) != TCL_OK) {
	    Tcl_CloseEx(NULL, fsPtr->fileState.channel, 0);
	    return NULL;
	}
    }

    return fsPtr->fileState.channel;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MakeFileChannel --
 *
 *	Makes a Tcl_Channel from an existing OS level file handle.
 *
 * Results:
 *	The Tcl_Channel created around the preexisting OS level file handle.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
Tcl_MakeFileChannel(
    void *handle,		/* OS level handle. */
    int mode)			/* OR'ed combination of TCL_READABLE and
				 * TCL_WRITABLE to indicate file mode. */
{
    TtyState *fsPtr;
    char channelName[16 + TCL_INTEGER_SPACE];
    int fd = (int)PTR2INT(handle);
    const Tcl_ChannelType *channelTypePtr;
    Tcl_StatBuf buf;

    if (mode == 0) {
	return NULL;
    }

#ifdef SUPPORTS_TTY
    if (isatty(fd)) {
	channelTypePtr = &ttyChannelType;
	snprintf(channelName, sizeof(channelName), "serial%d", fd);
    } else
#endif /* SUPPORTS_TTY */
    if (TclOSfstat(fd, &buf) == 0 && S_ISSOCK(buf.st_mode)) {
	struct sockaddr sockaddr;
	socklen_t sockaddrLen = sizeof(sockaddr);

	sockaddr.sa_family = AF_UNSPEC;
	if ((getsockname(fd, (struct sockaddr *)&sockaddr, &sockaddrLen) == 0)
		&& (sockaddrLen > 0)
		&& (sockaddr.sa_family == AF_INET
			|| sockaddr.sa_family == AF_INET6)) {
	    return (Tcl_Channel)TclpMakeTcpClientChannelMode(INT2PTR(fd), mode);
	}
	goto normalChannelAfterAll;
    } else {
    normalChannelAfterAll:
	channelTypePtr = &fileChannelType;
	snprintf(channelName, sizeof(channelName), "file%d", fd);
    }

    fsPtr = (TtyState *)Tcl_Alloc(sizeof(TtyState));
    fsPtr->fileState.fd = fd;
    fsPtr->fileState.validMask = mode | TCL_EXCEPTION;
    fsPtr->fileState.channel = Tcl_CreateChannel(channelTypePtr, channelName,
	    fsPtr, mode);
#ifdef SUPPORTS_TTY
    if (channelTypePtr == &ttyChannelType) {
	fsPtr->closeMode = CLOSE_DEFAULT;
	fsPtr->doReset = 0;
	tcgetattr(fsPtr->fileState.fd, &fsPtr->initState);
    }
#endif /* SUPPORTS_TTY */

    return fsPtr->fileState.channel;
}

/*
 *----------------------------------------------------------------------
 *
 * TclpGetDefaultStdChannel --
 *
 *	Creates channels for standard input, standard output or standard error
 *	output if they do not already exist.
 *
 * Results:
 *	Returns the specified default standard channel, or NULL.
 *
 * Side effects:
 *	May cause the creation of a standard channel and the underlying file.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
TclpGetDefaultStdChannel(
    int type)			/* One of TCL_STDIN, TCL_STDOUT, TCL_STDERR. */
{
    Tcl_Channel channel = NULL;
    int fd = 0;			/* Initializations needed to prevent */
    int mode = 0;		/* compiler warning (used before set). */
    const char *bufMode = NULL;

    /*
     * Some #def's to make the code a little clearer!
     */

#define ERROR_OFFSET	((Tcl_SeekOffset) -1)

    switch (type) {
    case TCL_STDIN:
	if ((TclOSseek(0, 0, SEEK_CUR) == ERROR_OFFSET)
		&& (errno == EBADF)) {
	    return NULL;
	}
	fd = 0;
	mode = TCL_READABLE;
	bufMode = "line";
	break;
    case TCL_STDOUT:
	if ((TclOSseek(1, 0, SEEK_CUR) == ERROR_OFFSET)
		&& (errno == EBADF)) {
	    return NULL;
	}
	fd = 1;
	mode = TCL_WRITABLE;
	bufMode = "line";
	break;
    case TCL_STDERR:
	if ((TclOSseek(2, 0, SEEK_CUR) == ERROR_OFFSET)
		&& (errno == EBADF)) {
	    return NULL;
	}
	fd = 2;
	mode = TCL_WRITABLE;
	bufMode = "none";
	break;
    default:
	Tcl_Panic("TclGetDefaultStdChannel: Unexpected channel type");
	break;
    }

#undef ERROR_OFFSET

    channel = Tcl_MakeFileChannel(INT2PTR(fd), mode);
    if (channel == NULL) {
	return NULL;
    }

    /*
     * Set up the normal channel options for stdio handles.
     */

    if (Tcl_GetChannelType(channel) == &fileChannelType) {
	Tcl_SetChannelOption(NULL, channel, "-translation", "auto");
    } else {
	Tcl_SetChannelOption(NULL, channel, "-translation", "auto crlf");
    }
    Tcl_SetChannelOption(NULL, channel, "-buffering", bufMode);
    return channel;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetOpenFile --
 *
 *	Given a name of a channel registered in the given interpreter, returns
 *	a FILE * for it.
 *
 * Results:
 *	A standard Tcl result. If the channel is registered in the given
 *	interpreter and it is managed by the "file" channel driver, and it is
 *	open for the requested mode, then the output parameter filePtr is set
 *	to a FILE * for the underlying file. On error, the filePtr is not set,
 *	TCL_ERROR is returned and an error message is left in the interp's
 *	result.
 *
 * Side effects:
 *	May invoke fdopen to create the FILE * for the requested file.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetOpenFile(
    Tcl_Interp *interp,		/* Interpreter in which to find file. */
    const char *chanID,		/* String that identifies file. */
    int forWriting,		/* 1 means the file is going to be used for
				 * writing, 0 means for reading. */
    TCL_UNUSED(int),		/* Obsolete argument.
				 * Ignored, we always check that
				 * the channel is open for the requested
				 * mode. */
    void **filePtr)		/* Store pointer to FILE structure here. */
{
    Tcl_Channel chan;
    int chanMode, fd;
    const Tcl_ChannelType *chanTypePtr;
    void *data;
    FILE *f;

    chan = Tcl_GetChannel(interp, chanID, &chanMode);
    if (chan == NULL) {
	return TCL_ERROR;
    }
    if (forWriting && !(chanMode & TCL_WRITABLE)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" wasn't opened for writing", chanID));
	Tcl_SetErrorCode(interp, "TCL", "VALUE", "CHANNEL", "NOT_WRITABLE",
		(char *)NULL);
	return TCL_ERROR;
    } else if (!forWriting && !(chanMode & TCL_READABLE)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" wasn't opened for reading", chanID));
	Tcl_SetErrorCode(interp, "TCL", "VALUE", "CHANNEL", "NOT_READABLE",
		(char *)NULL);
	return TCL_ERROR;
    }

    /*
     * We allow creating a FILE * out of file based, pipe based and socket
     * based channels. We currently do not allow any other channel types,
     * because it is likely that stdio will not know what to do with them.
     */

    chanTypePtr = Tcl_GetChannelType(chan);
    if ((chanTypePtr == &fileChannelType)
#ifdef SUPPORTS_TTY
	    || (chanTypePtr == &ttyChannelType)
#endif /* SUPPORTS_TTY */
	    || (strcmp(chanTypePtr->typeName, "tcp") == 0)
	    || (strcmp(chanTypePtr->typeName, "pipe") == 0)) {
	if (Tcl_GetChannelHandle(chan,
		(forWriting ? TCL_WRITABLE : TCL_READABLE), &data) == TCL_OK) {
	    fd = (int)PTR2INT(data);

	    /*
	     * The call to fdopen below is probably dangerous, since it will
	     * truncate an existing file if the file is being opened for
	     * writing....
	     */

	    f = fdopen(fd, (forWriting ? "w" : "r"));
	    if (f == NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"cannot get a FILE * for \"%s\"", chanID));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "CHANNEL",
			"FILE_FAILURE", (char *)NULL);
		return TCL_ERROR;
	    }
	    *filePtr = f;
	    return TCL_OK;
	}
    }

    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "\"%s\" cannot be used to get a FILE *", chanID));
    Tcl_SetErrorCode(interp, "TCL", "VALUE", "CHANNEL", "NO_DESCRIPTOR",
	    (char *)NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * FileTruncateProc --
 *
 *	Truncates a file to a given length.
 *
 * Results:
 *	0 if the operation succeeded, and -1 if it failed (in which case
 *	*errorCodePtr will be set to errno).
 *
 * Side effects:
 *	The underlying file is potentially truncated. This can have a wide
 *	variety of side effects, including moving file pointers that point at
 *	places later in the file than the truncate point.
 *
 *----------------------------------------------------------------------
 */

static int
FileTruncateProc(
    void *instanceData,
    long long length)
{
    FileState *fsPtr = (FileState *)instanceData;
    int result;

#ifdef HAVE_TYPE_OFF64_T
    /*
     * We assume this goes with the type for now...
     */

    result = ftruncate64(fsPtr->fd, (off64_t) length);
#else
    result = ftruncate(fsPtr->fd, (off_t) length);
#endif
    if (result) {
	return errno;
    }
    return 0;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

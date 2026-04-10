/*
 * tclUnixTest.c --
 *
 *	Contains platform specific test commands for the Unix platform.
 *
 * Copyright © 1996-1997 Sun Microsystems, Inc.
 * Copyright © 1998 Scriptics Corporation.
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

/*
 * The headers are needed for the testalarm command that verifies the use of
 * SA_RESTART in signal handlers.
 */

#include <signal.h>
#include <sys/resource.h>

/*
 * The following macros convert between TclFile's and fd's. The conversion
 * simple involves shifting fd's up by one to ensure that no valid fd is ever
 * the same as NULL. Note that this code is duplicated from tclUnixPipe.c
 */

#define MakeFile(fd)	((TclFile)INT2PTR(((int)(fd))+1))
#define GetFd(file)	(PTR2INT(file)-1)

/*
 * The stuff below is used to keep track of file handlers created and
 * exercised by the "testfilehandler" command.
 */

typedef struct {
    TclFile readFile;		/* File handle for reading from the pipe. NULL
				 * means pipe doesn't exist yet. */
    TclFile writeFile;		/* File handle for writing from the pipe. */
    int readCount;		/* Number of times the file handler for this
				 * file has triggered and the file was
				 * readable. */
    int writeCount;		/* Number of times the file handler for this
				 * file has triggered and the file was
				 * writable. */
} Pipe;

#define MAX_PIPES 10
static Pipe testPipes[MAX_PIPES];

/*
 * The stuff below is used by the testalarm and testgotsig ommands.
 */

static const char *gotsig = "0";

/*
 * Forward declarations of functions defined later in this file:
 */

static Tcl_ObjCmdProc TestalarmCmd;
static Tcl_ObjCmdProc TestchmodCmd;
static Tcl_ObjCmdProc TestfilehandlerCmd;
static Tcl_ObjCmdProc TestfilewaitCmd;
static Tcl_ObjCmdProc TestfindexecutableCmd;
static Tcl_ObjCmdProc TestforkCmd;
static Tcl_ObjCmdProc TestgotsigCmd;
static Tcl_FileProc TestFileHandlerProc;
static void		AlarmHandler(int signum);

/*
 *----------------------------------------------------------------------
 *
 * TclplatformtestInit --
 *
 *	Defines commands that test platform specific functionality for Unix
 *	platforms.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Defines new commands.
 *
 *----------------------------------------------------------------------
 */

int
TclplatformtestInit(
    Tcl_Interp *interp)		/* Interpreter to add commands to. */
{
    Tcl_CreateObjCommand(interp, "testchmod", TestchmodCmd,
	    NULL, NULL);
    Tcl_CreateObjCommand(interp, "testfilehandler", TestfilehandlerCmd,
	    NULL, NULL);
    Tcl_CreateObjCommand(interp, "testfilewait", TestfilewaitCmd,
	    NULL, NULL);
    Tcl_CreateObjCommand(interp, "testfindexecutable", TestfindexecutableCmd,
	    NULL, NULL);
    Tcl_CreateObjCommand(interp, "testfork", TestforkCmd,
	NULL, NULL);
    Tcl_CreateObjCommand(interp, "testalarm", TestalarmCmd,
	    NULL, NULL);
    Tcl_CreateObjCommand(interp, "testgotsig", TestgotsigCmd,
	    NULL, NULL);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TestfilehandlerCmd --
 *
 *	This function implements the "testfilehandler" command. It is used to
 *	test Tcl_CreateFileHandler, Tcl_DeleteFileHandler, and TclWaitForFile.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TestfilehandlerCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Argument strings. */
{
    Pipe *pipePtr;
    int i, mask, timeout;
    static int initialized = 0;
    char buffer[4000];
    TclFile file;

    /*
     * NOTE: When we make this code work on Windows also, the following
     * variable needs to be made Unix-only.
     */

    if (!initialized) {
	for (i = 0; i < MAX_PIPES; i++) {
	    testPipes[i].readFile = NULL;
	}
	initialized = 1;
    }

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option ...");
	return TCL_ERROR;
    }
    pipePtr = NULL;
    if (objc >= 3) {
	if (Tcl_GetIntFromObj(interp, objv[2], &i) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (i >= MAX_PIPES) {
	    Tcl_AppendResult(interp, "bad index ", objv[2], (char *)NULL);
	    return TCL_ERROR;
	}
	pipePtr = &testPipes[i];
    }

    if (strcmp(Tcl_GetString(objv[1]), "close") == 0) {
	for (i = 0; i < MAX_PIPES; i++) {
	    if (testPipes[i].readFile != NULL) {
		TclpCloseFile(testPipes[i].readFile);
		testPipes[i].readFile = NULL;
		TclpCloseFile(testPipes[i].writeFile);
		testPipes[i].writeFile = NULL;
	    }
	}
    } else if (strcmp(Tcl_GetString(objv[1]), "clear") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index");
	    return TCL_ERROR;
	}
	pipePtr->readCount = pipePtr->writeCount = 0;
    } else if (strcmp(Tcl_GetString(objv[1]), "counts") == 0) {
	char buf[TCL_INTEGER_SPACE * 2];

	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index");
	    return TCL_ERROR;
	}
	snprintf(buf, sizeof(buf), "%d %d", pipePtr->readCount, pipePtr->writeCount);
	Tcl_AppendResult(interp, buf, (char *)NULL);
    } else if (strcmp(Tcl_GetString(objv[1]), "create") == 0) {
	if (objc != 5) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index readMode writeMode");
	    return TCL_ERROR;
	}
	if (pipePtr->readFile == NULL) {
	    if (!TclpCreatePipe(&pipePtr->readFile, &pipePtr->writeFile)) {
		Tcl_AppendResult(interp, "couldn't open pipe: ",
			Tcl_PosixError(interp), (char *)NULL);
		return TCL_ERROR;
	    }
#ifdef O_NONBLOCK
	    fcntl(GetFd(pipePtr->readFile), F_SETFL, O_NONBLOCK);
	    fcntl(GetFd(pipePtr->writeFile), F_SETFL, O_NONBLOCK);
#else
	    Tcl_AppendResult(interp, "cannot make pipes non-blocking",
		    (char *)NULL);
	    return TCL_ERROR;
#endif
	}
	pipePtr->readCount = 0;
	pipePtr->writeCount = 0;

	if (strcmp(Tcl_GetString(objv[3]), "readable") == 0) {
	    Tcl_CreateFileHandler(GetFd(pipePtr->readFile), TCL_READABLE,
		    TestFileHandlerProc, pipePtr);
	} else if (strcmp(Tcl_GetString(objv[3]), "off") == 0) {
	    Tcl_DeleteFileHandler(GetFd(pipePtr->readFile));
	} else if (strcmp(Tcl_GetString(objv[3]), "disabled") == 0) {
	    Tcl_CreateFileHandler(GetFd(pipePtr->readFile), 0,
		    TestFileHandlerProc, pipePtr);
	} else {
	    Tcl_AppendResult(interp, "bad read mode \"", Tcl_GetString(objv[3]), "\"", (char *)NULL);
	    return TCL_ERROR;
	}
	if (strcmp(Tcl_GetString(objv[4]), "writable") == 0) {
	    Tcl_CreateFileHandler(GetFd(pipePtr->writeFile), TCL_WRITABLE,
		    TestFileHandlerProc, pipePtr);
	} else if (strcmp(Tcl_GetString(objv[4]), "off") == 0) {
	    Tcl_DeleteFileHandler(GetFd(pipePtr->writeFile));
	} else if (strcmp(Tcl_GetString(objv[4]), "disabled") == 0) {
	    Tcl_CreateFileHandler(GetFd(pipePtr->writeFile), 0,
		    TestFileHandlerProc, pipePtr);
	} else {
	    Tcl_AppendResult(interp, "bad read mode \"", Tcl_GetString(objv[4]), "\"", (char *)NULL);
	    return TCL_ERROR;
	}
    } else if (strcmp(Tcl_GetString(objv[1]), "empty") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index");
	    return TCL_ERROR;
	}

	while (read(GetFd(pipePtr->readFile), buffer, 4000) > 0) {
	    /* Empty loop body. */
	}
    } else if (strcmp(Tcl_GetString(objv[1]), "fill") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index");
	    return TCL_ERROR;
	}

	memset(buffer, 'a', 4000);
	while (write(GetFd(pipePtr->writeFile), buffer, 4000) > 0) {
	    /* Empty loop body. */
	}
    } else if (strcmp(Tcl_GetString(objv[1]), "fillpartial") == 0) {
	char buf[TCL_INTEGER_SPACE];

	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index");
	    return TCL_ERROR;
	}

	memset(buffer, 'b', 10);
	TclFormatInt(buf, write(GetFd(pipePtr->writeFile), buffer, 10));
	Tcl_AppendResult(interp, buf, (char *)NULL);
    } else if (strcmp(Tcl_GetString(objv[1]), "oneevent") == 0) {
	Tcl_DoOneEvent(TCL_FILE_EVENTS|TCL_DONT_WAIT);
    } else if (strcmp(Tcl_GetString(objv[1]), "wait") == 0) {
	if (objc != 5) {
	    Tcl_WrongNumArgs(interp, 2, objv, "index readable|writable timeout");
	    return TCL_ERROR;
	}
	if (pipePtr->readFile == NULL) {
	    Tcl_AppendResult(interp, "pipe ", Tcl_GetString(objv[2]), " doesn't exist", (char *)NULL);
	    return TCL_ERROR;
	}
	if (strcmp(Tcl_GetString(objv[3]), "readable") == 0) {
	    mask = TCL_READABLE;
	    file = pipePtr->readFile;
	} else {
	    mask = TCL_WRITABLE;
	    file = pipePtr->writeFile;
	}
	if (Tcl_GetIntFromObj(interp, objv[4], &timeout) != TCL_OK) {
	    return TCL_ERROR;
	}
	i = TclUnixWaitForFile(GetFd(file), mask, timeout);
	if (i & TCL_READABLE) {
	    Tcl_AppendElement(interp, "readable");
	}
	if (i & TCL_WRITABLE) {
	    Tcl_AppendElement(interp, "writable");
	}
    } else if (strcmp(Tcl_GetString(objv[1]), "windowevent") == 0) {
	Tcl_DoOneEvent(TCL_WINDOW_EVENTS|TCL_DONT_WAIT);
    } else {
	Tcl_AppendResult(interp, "bad option \"", Tcl_GetString(objv[1]),
		"\": must be close, clear, counts, create, empty, fill, "
		"fillpartial, oneevent, wait, or windowevent", (char *)NULL);
	return TCL_ERROR;
    }
    return TCL_OK;
}

static void
TestFileHandlerProc(
    void *clientData,	/* Points to a Pipe structure. */
    int mask)			/* Indicates which events happened:
				 * TCL_READABLE or TCL_WRITABLE. */
{
    Pipe *pipePtr = (Pipe *)clientData;

    if (mask & TCL_READABLE) {
	pipePtr->readCount++;
    }
    if (mask & TCL_WRITABLE) {
	pipePtr->writeCount++;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TestfilewaitCmd --
 *
 *	This function implements the "testfilewait" command. It is used to
 *	test TclUnixWaitForFile.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TestfilewaitCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Argument strings. */
{
    int mask, result, timeout;
    Tcl_Channel channel;
    int fd;
    void *data;

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 2, objv, "file readable|writable|both timeout");
	return TCL_ERROR;
    }
    channel = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), NULL);
    if (channel == NULL) {
	return TCL_ERROR;
    }
    if (strcmp(Tcl_GetString(objv[2]), "readable") == 0) {
	mask = TCL_READABLE;
    } else if (strcmp(Tcl_GetString(objv[2]), "writable") == 0){
	mask = TCL_WRITABLE;
    } else if (strcmp(Tcl_GetString(objv[2]), "both") == 0){
	mask = TCL_WRITABLE|TCL_READABLE;
    } else {
	Tcl_AppendResult(interp, "bad argument \"", Tcl_GetString(objv[2]),
		"\": must be readable, writable, or both", (char *)NULL);
	return TCL_ERROR;
    }
    if (Tcl_GetChannelHandle(channel,
	    (mask & TCL_READABLE) ? TCL_READABLE : TCL_WRITABLE,
	    (void **) &data) != TCL_OK) {
	Tcl_AppendResult(interp, "couldn't get channel file", (char *)NULL);
	return TCL_ERROR;
    }
    fd = PTR2INT(data);
    if (Tcl_GetIntFromObj(interp, objv[3], &timeout) != TCL_OK) {
	return TCL_ERROR;
    }
    result = TclUnixWaitForFile(fd, mask, timeout);
    if (result & TCL_READABLE) {
	Tcl_AppendElement(interp, "readable");
    }
    if (result & TCL_WRITABLE) {
	Tcl_AppendElement(interp, "writable");
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TestfindexecutableCmd --
 *
 *	This function implements the "testfindexecutable" command. It is used
 *	to test TclpFindExecutable.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TestfindexecutableCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Argument strings. */
{
    Tcl_Obj *saveName;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "argv0");
	return TCL_ERROR;
    }

    saveName = TclGetObjNameOfExecutable();
    Tcl_IncrRefCount(saveName);

    TclpFindExecutable(Tcl_GetString(objv[1]));
    Tcl_SetObjResult(interp, TclGetObjNameOfExecutable());

    TclSetObjNameOfExecutable(saveName, NULL);
    Tcl_DecrRefCount(saveName);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TestforkCmd --
 *
 *	This function implements the "testfork" command. It is used to
 *	fork the Tcl process for specific test cases.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
TestforkCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Argument strings. */
{
    pid_t pid;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    pid = fork();
    if (pid == -1) {
	Tcl_AppendResult(interp,
		"Cannot fork", (char *)NULL);
	return TCL_ERROR;
    }
    /* Only needed when pthread_atfork is not present,
     * should not hurt otherwise. */
    if (pid==0) {
	Tcl_InitNotifier();
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(pid));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TestalarmCmd --
 *
 *	Test that EINTR is handled correctly by generating and handling a
 *	signal. This requires using the SA_RESTART flag when registering the
 *	signal handler.
 *
 * Results:
 *	None.
 *
 * Side Effects:
 *	Sets up an signal and async handlers.
 *
 *----------------------------------------------------------------------
 */

static int
TestalarmCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Argument strings. */
{
#ifdef SA_RESTART
    unsigned int sec = 1;
    struct sigaction action;

    if (objc > 1) {
	Tcl_GetIntFromObj(interp, objv[1], (int *)&sec);
    }

    /*
     * Setup the signal handling that automatically retries any interrupted
     * I/O system calls.
     */

    action.sa_handler = AlarmHandler;
    memset((void *)&action.sa_mask, 0, sizeof(sigset_t));
    action.sa_flags = SA_RESTART;

    if (sigaction(SIGALRM, &action, NULL) < 0) {
	Tcl_AppendResult(interp, "sigaction: ", Tcl_PosixError(interp), (char *)NULL);
	return TCL_ERROR;
    }
    (void) alarm(sec);
    return TCL_OK;
#else

    Tcl_AppendResult(interp,
	    "warning: sigaction SA_RESTART not support on this platform",
	    (char *)NULL);
    return TCL_ERROR;
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * AlarmHandler --
 *
 *	Signal handler for the alarm command.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Calls the Tcl Async handler.
 *
 *----------------------------------------------------------------------
 */

static void
AlarmHandler(
    TCL_UNUSED(int) /*signum*/)
{
    gotsig = "1";
}

/*
 *----------------------------------------------------------------------
 *
 * TestgotsigCmd --
 *
 *	Verify the signal was handled after the testalarm command.
 *
 * Results:
 *	None.
 *
 * Side Effects:
 *	Resets the value of gotsig back to '0'.
 *
 *----------------------------------------------------------------------
 */

static int
TestgotsigCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    TCL_UNUSED(int) /*objc*/,
    TCL_UNUSED(Tcl_Obj *const *))
{
    Tcl_AppendResult(interp, gotsig, (char *)NULL);
    gotsig = "0";
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * TestchmodCmd --
 *
 *	Implements the "testchmod" cmd.  Used when testing "file" command.
 *	The only attribute used by the Windows platform is the user write
 *	flag; if this is not set, the file is made read-only.  Otherwise, the
 *	file is made read-write.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Changes permissions of specified files.
 *
 *---------------------------------------------------------------------------
 */

static int
TestchmodCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,			/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)		/* Argument strings. */
{
    int i, mode;
    Tcl_DString ds;

    if (objc < 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "mode file ?file ...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIntFromObj(interp, objv[1], &mode) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_DStringInit(&ds);
    for (i = 2; i < objc; i++) {
	Tcl_DString buffer;
	const char *translated;

	translated = Tcl_TranslateFileName(interp, Tcl_GetString(objv[i]), &buffer);
	if (translated == NULL) {
	    Tcl_DStringFree(&ds);
	    return TCL_ERROR;
	}
	Tcl_UtfToExternalDString(NULL, translated, -1, &ds);
	if (chmod(Tcl_DStringValue(&ds), mode) != 0) {
	    Tcl_AppendResult(interp, translated, ": ", Tcl_PosixError(interp),
		    (char *)NULL);
	    Tcl_DStringFree(&ds);
	    return TCL_ERROR;
	}
	Tcl_DStringFree(&buffer);
	Tcl_DStringSetLength(&ds, 0);
    }
    Tcl_DStringFree(&ds);
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * End:
 */

/*
 * tclPanic.c --
 *
 *	Source code for the "Tcl_Panic" library procedure for Tcl; individual
 *	applications will probably call Tcl_SetPanicProc() to set an
 *	application-specific panic procedure.
 *
 * Copyright © 1988-1993 The Regents of the University of California.
 * Copyright © 1994 Sun Microsystems, Inc.
 * Copyright © 1998-1999 Scriptics Corporation.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#if defined(_WIN32) || defined(__CYGWIN__)
    MODULE_SCOPE void tclWinDebugPanic(const char *format, ...);
#endif

/*
 * The panicProc variable contains a pointer to an application specific panic
 * procedure.
 */

static Tcl_PanicProc *panicProc = NULL;

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetPanicProc --
 *
 *	Replace the default panic behavior with the specified function.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Sets the panicProc variable.
 *
 *----------------------------------------------------------------------
 */

const char *
Tcl_SetPanicProc(
    Tcl_PanicProc *proc)
{
    panicProc = proc;
    return Tcl_InitSubsystems();
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Panic --
 *
 *	Print an error message and kill the process.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The process dies, entering the debugger if possible.
 *
 *----------------------------------------------------------------------
 */

/*
 * The following comment is here so that Coverity's static analyzer knows that
 * a Tcl_Panic() call can never return and avoids lots of false positives.
 */

/* coverity[+kill] */
TCL_NORETURN void
Tcl_Panic(
    const char *format,
    ...)
{
    va_list argList;
    char *arg1, *arg2, *arg3;	/* Additional arguments (variable in number)
				 * to pass to fprintf. */
    char *arg4, *arg5, *arg6, *arg7, *arg8;

    va_start(argList, format);
    arg1 = va_arg(argList, char *);
    arg2 = va_arg(argList, char *);
    arg3 = va_arg(argList, char *);
    arg4 = va_arg(argList, char *);
    arg5 = va_arg(argList, char *);
    arg6 = va_arg(argList, char *);
    arg7 = va_arg(argList, char *);
    arg8 = va_arg(argList, char *);
    va_end (argList);

    if (panicProc != NULL) {
	panicProc(format, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
    } else {
#if defined(_WIN32) || defined(__CYGWIN__)
    tclWinDebugPanic(format, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);
#else
	fprintf(stderr, format, arg1, arg2, arg3, arg4, arg5, arg6, arg7,
		arg8);
	fprintf(stderr, "\n");
	fflush(stderr);
#endif
    }
#if defined(__GNUC__)
    __builtin_trap();
#elif defined(_WIN64)
    __debugbreak();
#elif defined(_MSC_VER) && defined (_M_IX86)
    _asm {int 3}
#elif defined(_WIN32)
    DebugBreak();
#endif
#if defined(_WIN32)
    ExitProcess(1);
#else
    abort();
#endif
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

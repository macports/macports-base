/*
 * tclXsignal.c --
 *
 * Tcl Unix signal support routines and the signal and commands.  The #ifdefs
 * around several common Unix signals existing are for Windows.
 *-----------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXsignal.c,v 1.3 2005/02/04 01:34:01 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * If either SIGCLD or SIGCHLD are defined, define them both.  This makes
 * the interchangeable.  Windows doesn't have this signal.
 */

#if defined(SIGCLD) || defined(SIGCHLD)
#   ifndef SIGCLD
#      define SIGCLD SIGCHLD
#   endif
#   ifndef SIGCHLD
#      define SIGCHLD SIGCLD
#   endif
#endif

#ifndef MAXSIG
#  ifdef NSIG
#    define MAXSIG NSIG
#  else
#    define MAXSIG 32
#  endif
#endif

/*
 * Encore UMAX doesn't define SIG_ERR!.
 */
#ifndef SIG_ERR
#   define SIG_ERR  (void (*)())-1
#endif

/*
 * Value returned by Tcl_SignalId when an invalid signal is passed in.
 * Pointer is used as a quick check of a valid signal number.
 */
static CONST char *unknownSignalIdMsg;

/*
 * Signal name table maps name to number.  Note, it is possible to have
 * more than MAXSIG entries in this table if the system defines multiple
 * symbols that have the same value.
 */

#define SIG_NAME_MAX 9  /* Maximum length of any signal name */

static struct {
    char *name;
    short num;
} sigNameTable [] = {
#ifdef SIGABRT
    {"ABRT",    SIGABRT},
#endif
#ifdef SIGALRM
    {"ALRM",    SIGALRM},
#endif
#ifdef SIGBUS
    {"BUS",     SIGBUS},
#endif
#ifdef SIGCHLD
    {"CHLD",    SIGCHLD},
#endif
#ifdef SIGCLD
    {"CLD",     SIGCLD},
#endif
#ifdef SIGCONT
    {"CONT",    SIGCONT},
#endif
#ifdef SIGEMT
    {"EMT",     SIGEMT},
#endif
#ifdef SIGFPE
    {"FPE",     SIGFPE},
#endif
#ifdef SIGHUP
    {"HUP",     SIGHUP},
#endif
#ifdef SIGILL
    {"ILL",     SIGILL},
#endif
#ifdef SIGINT
    {"INT",     SIGINT},
#endif
#ifdef SIGIO
    {"IO",      SIGIO},
#endif
#ifdef SIGIOT
    {"IOT",     SIGIOT},
#endif
#ifdef SIGKILL
    {"KILL",    SIGKILL},
#endif
#ifdef SIGLOST
    {"LOST",    SIGLOST},
#endif
#ifdef SIGPIPE
    {"PIPE",    SIGPIPE},
#endif
#ifdef SIGPOLL
    {"POLL",    SIGPOLL},
#endif
#ifdef SIGPROF
    {"PROF",    SIGPROF},
#endif
#ifdef SIGPWR
    {"PWR",     SIGPWR},
#endif
#ifdef SIGQUIT
    {"QUIT",    SIGQUIT},
#endif
#ifdef SIGSEGV
    {"SEGV",    SIGSEGV},
#endif
#ifdef SIGSTOP
    {"STOP",    SIGSTOP},
#endif
#ifdef SIGSYS
    {"SYS",     SIGSYS},
#endif
#ifdef SIGTERM
    {"TERM",    SIGTERM},
#endif
#ifdef SIGTRAP
    {"TRAP",    SIGTRAP},
#endif
#ifdef SIGTSTP
    {"TSTP",    SIGTSTP},
#endif
#ifdef SIGTTIN
    {"TTIN",    SIGTTIN},
#endif
#ifdef SIGTTOU
    {"TTOU",    SIGTTOU},
#endif
#ifdef SIGURG
    {"URG",     SIGURG},
#endif
#ifdef SIGUSR1
    {"USR1",    SIGUSR1},
#endif
#ifdef SIGUSR2
    {"USR2",    SIGUSR2},
#endif
#ifdef SIGVTALRM
    {"VTALRM",  SIGVTALRM},
#endif
#ifdef SIGWINCH
    {"WINCH",   SIGWINCH},
#endif
#ifdef SIGXCPU
    {"XCPU",    SIGXCPU},
#endif
#ifdef SIGXFSZ
    {"XFSZ",    SIGXFSZ},
#endif
    {NULL,         -1}};

#ifndef RETSIGTYPE
#   define RETSIGTYPE void
#endif

typedef RETSIGTYPE (*signalProcPtr_t) _ANSI_ARGS_((int));


/*
 * Defines if this is not Posix.
 */
#ifndef SIG_BLOCK
#   define SIG_BLOCK       1
#   define SIG_UNBLOCK     2
#endif

/*
 * SunOS has sigaction but uses SA_INTERRUPT rather than SA_RESTART which
 * has the opposite meaning.
 */
#ifndef NO_SIGACTION
#if defined(SA_INTERRUPT) && !defined(SA_RESTART)
#define USE_SA_INTERRUPT
#endif
#endif


/*
 * Symbolic signal actions that can be associated with a signal.
 */
static char *SIGACT_DEFAULT = "default";
static char *SIGACT_IGNORE  = "ignore";
static char *SIGACT_ERROR   = "error";
static char *SIGACT_TRAP    = "trap";
static char *SIGACT_UNKNOWN = "unknown";

static Tcl_Interp	**interpTable = NULL;
static Tcl_AsyncHandler asyncHandler = NULL;
static int              interpTableSize  = 0;
static int              numInterps  = 0;

/*
 * Application signal error handler.  Called after normal signal processing,
 * when a signal results in an error.   Its main purpose in life is to allow
 * interactive command loops to clear their input buffer on SIGINT.  This is
 * not currently a generic interface, but should be. Only one maybe active.
 */
static TclX_AppSignalErrorHandler appSigErrorHandler = NULL;
static ClientData                 appSigErrorClientData = NULL;

/*
 * Counters of signals that have occured but have not been processed.
 */
static unsigned signalsReceived[MAXSIG];

/*
 * Table of commands to evaluate when a signal occurs.  If the command is
 * NULL and the signal is received, an error is returned.
 */
static char *signalTrapCmds[MAXSIG];

/*
 * Prototypes of internal functions.
 */
static CONST84 char *
GetSignalName _ANSI_ARGS_((int signalNum));

static int
GetSignalState _ANSI_ARGS_((int              signalNum,
                            signalProcPtr_t *sigProcPtr,
                            int             *restart));

static int
SetSignalState _ANSI_ARGS_((int             signalNum,
                            signalProcPtr_t sigFunc,
                            int             restart));

static int
BlockSignals _ANSI_ARGS_((Tcl_Interp    *interp,
                          int            action,
                          unsigned char  signals [MAXSIG]));

static Tcl_Obj *
SignalBlocked _ANSI_ARGS_((int signalNum));

static int
SigNameToNum _ANSI_ARGS_((Tcl_Interp *interp,
                          char       *sigName,
                          int        *sigNumPtr));

static int
ParseSignalSpec _ANSI_ARGS_((Tcl_Interp *interp,
                             char       *signalStr,
                             int         allowZero));

static RETSIGTYPE
SignalTrap _ANSI_ARGS_((int signalNum));

static int
FormatTrapCode  _ANSI_ARGS_((Tcl_Interp  *interp,
                             int          signalNum,
                             Tcl_DString *command));

static int
EvalTrapCode _ANSI_ARGS_((Tcl_Interp *interp,
                          int         signalNum));

static int
ProcessASignal _ANSI_ARGS_((Tcl_Interp *interp,
                            int         background,
                            int         signalNum));

static int
ProcessSignals _ANSI_ARGS_((ClientData  clientData,
                            Tcl_Interp *interp,
                            int         cmdResultCode));

static int
ParseSignalList _ANSI_ARGS_((Tcl_Interp    *interp,
                             Tcl_Obj       *signalListObjPtr,
                             unsigned char  signals [MAXSIG]));

static int
SetSignalActions _ANSI_ARGS_((Tcl_Interp      *interp,
                              unsigned char    signals [MAXSIG],
                              signalProcPtr_t  actionFunc,
                              int              restart,
                              char            *command));

static int
FormatSignalListEntry _ANSI_ARGS_((Tcl_Interp *interp,
                                   int         signalNum,
                                   Tcl_Obj    *sigStatesObjPtr));

static int
ProcessSignalListEntry _ANSI_ARGS_((Tcl_Interp *interp,
                                    char       *signalName,
                                    Tcl_Obj    *stateObjPtr));

static int
GetSignalStates _ANSI_ARGS_((Tcl_Interp    *interp,
                             unsigned char  signals [MAXSIG]));

static int
SetSignalStates _ANSI_ARGS_((Tcl_Interp *interp,
                             Tcl_Obj    *sigStatesObjPtr));

static void
SignalCmdCleanUp _ANSI_ARGS_((ClientData  clientData,
                              Tcl_Interp *interp));

static int
TclX_SignalObjCmd _ANSI_ARGS_((ClientData   clientData,
                               Tcl_Interp  *interp,
                               int          objc,
                               Tcl_Obj     *CONST objv[]));

static int
TclX_KillObjCmd _ANSI_ARGS_((ClientData   clientData,
                             Tcl_Interp  *interp,
                             int          objc,
                             Tcl_Obj     *CONST objv[]));


/*-----------------------------------------------------------------------------
 * GetSignalName --
 *     Get the name for a signal.  This normalized SIGCHLD.
 * Parameters:
 *   o signalNum - Signal number convert.
 * Results
 *   Static signal name.
 *-----------------------------------------------------------------------------
 */
static CONST84 char *
GetSignalName (signalNum)
    int signalNum;
{
#ifdef SIGCHLD
    /*
     * Force name to always be SIGCHLD, even if system defines only SIGCLD.
     */
    if (signalNum == SIGCHLD)
        return "SIGCHLD";
#endif

    return Tcl_SignalId (signalNum);
}

/*-----------------------------------------------------------------------------
 * GetSignalState --
 *     Get the current state of the specified signal.
 * Parameters:
 *   o signalNum - Signal number to query.
 *   o sigProcPtr - The signal function is returned here.
 *   o restart - Restart systems calls on signal.
 * Results
 *   TCL_OK or TCL_ERROR (check errno).
 *-----------------------------------------------------------------------------
 */
static int
GetSignalState (signalNum, sigProcPtr, restart)
    int              signalNum;
    signalProcPtr_t *sigProcPtr;
    int             *restart;
{
#ifndef NO_SIGACTION
    struct sigaction currentState;

    if (sigaction (signalNum, NULL, &currentState) < 0)
        return TCL_ERROR;
    *sigProcPtr = currentState.sa_handler;
#ifdef USE_SA_INTERRUPT
    *restart = ((currentState.sa_flags & SA_INTERRUPT) == 0);
#else
    *restart = ((currentState.sa_flags & SA_RESTART) != 0);
#endif
    return TCL_OK;
#else
    signalProcPtr_t  actionFunc;

#ifdef SIGKILL
    if (signalNum == SIGKILL) {
        *sigProcPtr = SIG_DFL;
        return TCL_OK;
    }
#endif
    actionFunc = signal (signalNum, SIG_DFL);
    if (actionFunc == SIG_ERR)
        return TCL_ERROR;
    if (actionFunc != SIG_DFL)
        signal (signalNum, actionFunc);  /* reset */
    *sigProcPtr = actionFunc;
    restart = FALSE;
    return TCL_OK;
#endif
}

/*-----------------------------------------------------------------------------
 * SetSignalState --
 *     Set the state of a signal.
 * Parameters:
 *   o signalNum - Signal number to query.
 *   o sigFunc - The signal function or SIG_DFL or SIG_IGN.
 *   o restart - Restart systems calls on signal.
 * Results
 *   TCL_OK or TCL_ERROR (check errno).
 *-----------------------------------------------------------------------------
 */
static int
SetSignalState (signalNum, sigFunc, restart)
    int             signalNum;
    signalProcPtr_t sigFunc;
    int             restart;
{
#ifndef NO_SIGACTION
    struct sigaction newState;
    
    newState.sa_handler = sigFunc;
    sigfillset (&newState.sa_mask);
    newState.sa_flags = 0;
#ifdef USE_SA_INTERRUPT
    if (!restart) {
        newState.sa_flags |= SA_INTERRUPT;
    }
#else
    if (restart) {
        newState.sa_flags |= SA_RESTART;
    }
#endif

    if (sigaction (signalNum, &newState, NULL) < 0)
        return TCL_ERROR;

    return TCL_OK;
#else
    if (signal (signalNum, sigFunc) == SIG_ERR)
        return TCL_ERROR;
    else
        return TCL_OK;
#endif
}

/*-----------------------------------------------------------------------------
 * BlockSignals --
 *     
 *    Block or unblock the specified signals.  Returns an error if not a Posix
 * system.
 *
 * Parameters::
 *   o interp - Error messages are returned in result.
 *   o action - SIG_BLOCK or SIG_UNBLOCK.
 *   o signals - Boolean array indexed by signal number that indicates
 *     the requested signals.
 * Returns:
 *   TCL_OK or TCL_ERROR, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
BlockSignals (interp, action, signals)
    Tcl_Interp    *interp;
    int            action;
    unsigned char  signals [];
{
#ifndef NO_SIGACTION
    int      signalNum;
    sigset_t sigBlockSet;

    sigemptyset (&sigBlockSet);

    for (signalNum = 0; signalNum < MAXSIG; signalNum++) {
        if (signals [signalNum])
            sigaddset (&sigBlockSet, signalNum);
    }

    if (sigprocmask (action, &sigBlockSet, NULL)) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    return TCL_OK;
#else
    TclX_AppendObjResult (interp,
                          "Posix signals are not available on this system, ",
                          "can not block signals");
    return TCL_ERROR;
#endif
}

/*-----------------------------------------------------------------------------
 * SignalBlocked --
 *     
 *    Determine if a signal is blocked.  On non-Posix systems, always returns
 * FALSE.
 *
 * Parameters::
 *   o signalNum - The signal to determine the state for.
 * Returns:
 *   NULL if an error occured (with error in errno), otherwise a pointer to a
 * boolean object.
 *-----------------------------------------------------------------------------
 */
static Tcl_Obj *
SignalBlocked (signalNum)
    int signalNum;
{
#ifndef NO_SIGACTION
    sigset_t sigBlockSet;

    if (sigprocmask (SIG_BLOCK, NULL, &sigBlockSet)) {
        return NULL;
    }
    return Tcl_NewBooleanObj (sigismember (&sigBlockSet, signalNum));
#else
    return Tcl_NewBooleanObj (FALSE);
#endif
}

/*-----------------------------------------------------------------------------
 * SigNameToNum --
 *    Converts a UNIX signal name to its number, returns -1 if not found.
 * the name may be upper or lower case and may optionally have the leading
 * "SIG" omitted.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o sigName - Name of signal to convert.
 *   o sigNumPtr - Signal number is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
SigNameToNum (interp, sigName, sigNumPtr)
    Tcl_Interp *interp;
    char       *sigName;
    int        *sigNumPtr;
{
    char  sigNameUp [SIG_NAME_MAX+1];  /* Upshifted signal name */
    char *sigNamePtr; 
    int   idx;

    /*
     * Copy and upshift requested name.
     */
    if (strlen (sigName) > SIG_NAME_MAX)
        goto invalidSignal;   /* Name too long */

    TclX_UpShift (sigNameUp, sigName);

    if (STRNEQU (sigNameUp, "SIG", 3))
        sigNamePtr = &sigNameUp [3];
    else
        sigNamePtr = sigNameUp;

    for (idx = 0; sigNameTable [idx].num != -1; idx++) {
        if (STREQU (sigNamePtr, sigNameTable [idx].name)) {
            *sigNumPtr = sigNameTable [idx].num;
            return TCL_OK;
        }
    }

  invalidSignal:
    TclX_AppendObjResult (interp, "invalid signal \"", sigName, "\"",
                          (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * ParseSignalSpec --
 *  
 *   Parse a signal specified as either a name or a number.
 * 
 * Parameters:
 *   o interp - Interpreter for returning errors.
 *   o signalStr - The signal name or number string.
 *   o allowZero - Allow zero as a valid signal number (for kill).
 * Returns:
 *   The signal number converted, or -1 if an error occures.
 *-----------------------------------------------------------------------------
 */
static int
ParseSignalSpec (interp, signalStr, allowZero)
    Tcl_Interp *interp;
    char       *signalStr;
    int         allowZero;
{
    int  signalNum;

    /*
     * If its a number, validate that number is actual a valid signal number
     * for this system.  If either fail, try it as a name.  Just let
     * SigNameToNum generate the error message if its a number, but not a
     * valid signal.
     */
    if (TclX_StrToInt (signalStr, 0, &signalNum)) {
        if (allowZero && (signalNum == 0))
            return 0;
        if (Tcl_SignalId (signalNum) != unknownSignalIdMsg)
            return signalNum;
    }
    if (SigNameToNum (interp, signalStr, &signalNum) != TCL_OK)
        return -1;
    return signalNum;
}

/*-----------------------------------------------------------------------------
 * SignalTrap --
 *
 *   Trap handler for UNIX signals.  Sets tells all registered interpreters
 * that a trap has occured and saves the trap info.  The first interpreter to
 * call it's async signal handler will process all pending signals.
 *-----------------------------------------------------------------------------
 */
static RETSIGTYPE
SignalTrap (signalNum)
    int signalNum;
{
    if (asyncHandler == NULL)
	return;
    /*
     * Record the count of the number of this type of signal that has occured
     * and tell all the interpreters to call the async handler when safe.
     */
    signalsReceived [signalNum]++;

    Tcl_AsyncMark (asyncHandler);

#ifdef NO_SIGACTION
    /*
     * For old-style Unix signals, the signal must be explictly re-enabled.
     * Not done for SIGCHLD, as we would continue to the signal until the
     * wait is done.  This is fixed by Posix signals and is not necessary under
     * BSD, but it done this way for consistency.
     */
#ifdef SIGCHLD
    if (signalNum != SIGCHLD) {
        if (SetSignalState (signalNum, SignalTrap, FALSE) == TCL_ERROR)
            Tcl_Panic ("SignalTrap bug");
    }
#else
    if (SetSignalState (signalNum, SignalTrap, FALSE) == TCL_ERROR)
        Tcl_Panic ("SignalTrap bug");
#endif /* SIGCHLD */
#endif /* NO_SIGACTION */
}

/*-----------------------------------------------------------------------------
 * FormatTrapCode --
 *     Format the signal name into the signal trap command.  Replacing %S with
 * the signal name.
 *
 * Parameters:
 *   o interp (I/O) - The interpreter to return errors in.
 *   o signalNum - The signal number of the signal that occured.
 *   o command - The resulting command adter the formatting.
 *-----------------------------------------------------------------------------
 */
static int
FormatTrapCode (interp, signalNum, command)
    Tcl_Interp  *interp;
    int          signalNum;
    Tcl_DString *command;
{
    char *copyPtr, *scanPtr;

    Tcl_DStringInit (command);

    copyPtr = scanPtr = signalTrapCmds [signalNum];

    while (*scanPtr != '\0') {
        if (*scanPtr != '%') {
            scanPtr++;
            continue;
        }
        if (scanPtr [1] == '%') {
            scanPtr += 2;
            continue;
        }
        Tcl_DStringAppend (command, copyPtr, (scanPtr - copyPtr));

        switch (scanPtr [1]) {
          case 'S': {
              Tcl_DStringAppend (command, GetSignalName (signalNum), -1);
              break;
          }
          default:
            goto badSpec;
        }
        scanPtr += 2;
        copyPtr = scanPtr;
    }
    Tcl_DStringAppend (command, copyPtr, copyPtr - scanPtr);

    return TCL_OK;

    /*
     * Handle bad % specification currently pointed to by scanPtr.
     */
  badSpec:
    {
        char badSpec [2];
        
        badSpec [0] = scanPtr [1];
        badSpec [1] = '\0';
        TclX_AppendObjResult (interp, "bad signal trap command formatting ",
                              "specification \"%", badSpec,
                              "\", expected one of \"%%\" or \"%S\"",
                              (char *) NULL);
        return TCL_ERROR;
    }
}

/*-----------------------------------------------------------------------------
 * EvalTrapCode --
 *     Run code as the result of a signal.  The symbolic signal name is
 * formatted into the command replacing %S with the symbolic signal name.
 *
 * Parameters:
 *   o interp - The interpreter to run the signal in. If an error
 *     occures, then the result will be left in the interp.
 *   o signalNum - The signal number of the signal that occured.
 * Return:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
EvalTrapCode (interp, signalNum)
    Tcl_Interp *interp;
    int         signalNum;
{
    int          result;
    Tcl_DString  command;
    Tcl_Obj     *saveObjPtr;

    saveObjPtr = TclX_SaveResultErrorInfo (interp);
    Tcl_ResetResult (interp);

    /*
     * Format the signal name into the command.  This also allows the signal
     * to be reset in the command.
     */

    result = FormatTrapCode (interp,
                             signalNum,
                             &command);
    if (result == TCL_OK)
        result = Tcl_GlobalEval (interp, 
                                 command.string);

    Tcl_DStringFree (&command);

    if (result == TCL_ERROR) {
        char errorInfo [128];

        sprintf (errorInfo, "\n    while executing signal trap code for %s%s",
                 Tcl_SignalId (signalNum), " signal");
        Tcl_AddErrorInfo (interp, errorInfo);

        return TCL_ERROR;
    }
    
    TclX_RestoreResultErrorInfo (interp, saveObjPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * ProcessASignal --
 *  
 *   Do processing on the specified signal.
 *
 * Parameters:
 *   o interp - Result will contain the result of the signal handling
 *     code that was evaled.
 *   o background - Signal handler was called from the event loop with
 *     no current interp.
 *   o signalNum - The signal to process.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ProcessASignal (interp, background, signalNum)
    Tcl_Interp *interp;
    int         background;
    int         signalNum;
{
    int result = TCL_OK;

    /*
     * Either return an error or evaluate code associated with this signal.
     * If evaluating code, call it for each time the signal occured.
     */
    if (signalTrapCmds [signalNum] == NULL) {
        CONST84 char *signalName = GetSignalName (signalNum);

        signalsReceived [signalNum] = 0;
        Tcl_SetErrorCode (interp, "POSIX", "SIG", signalName, (char*) NULL);
        TclX_AppendObjResult (interp, signalName, " signal received", 
                              (char *)NULL);
        Tcl_SetVar (interp, "errorInfo", "", TCL_GLOBAL_ONLY);
        result = TCL_ERROR;

        /*
         * Let the application at signals that generate errors.
         */
        if (appSigErrorHandler != NULL)
            result = (*appSigErrorHandler) (interp,
                                            appSigErrorClientData,
                                            background,
                                            signalNum);
    } else {
        while (signalsReceived [signalNum] > 0) {
            (signalsReceived [signalNum])--;
            result = EvalTrapCode (interp, signalNum);
            if (result == TCL_ERROR)
                break;
        }
    }
    return result;
}

/*-----------------------------------------------------------------------------
 * ProcessSignals --
 *  
 *   Called by the async handler to process pending signals in a safe state
 * interpreter state.  This is often called just after a command completes.
 * The results of the command are passed to this procedure and may be altered
 * by it.  If trap code is specified for the signal that was received, then
 * the trap will be executed, otherwise an error result will be returned
 * indicating that the signal occured.  If an error is returned, clear the
 * errorInfo variable.  This makes sure it exists and that it is empty,
 * otherwise bogus or non-existant information will be returned if this
 * routine was called somewhere besides Tcl_Eval.  If a signal was received
 * multiple times and a trap is set on it, then that trap will be executed for
 * each time the signal was received.
 * 
 * Parameters:
 *   o clientData - Not used.
 *   o interp (I/O) - interp result should contain the result for
 *     the command that just executed.  This will either be restored or
 *     replaced with a new result.  If this is NULL, then no interpreter
 *     is directly available (i.e. event loop).  In this case, the first
 *     interpreter in internal interpreter table is used.  If an error results
 *     from signal processing, it is handled via Tcl_BackgroundError.
 *   o cmdResultCode - The integer result returned by the command that
 *     Tcl_Eval just completed.  Should be TCL_OK if not called from
 *     Tcl_Eval.
 * Returns:
 *   Either the original result code, an error result if one of the
 *   trap commands returned an error, or an error indicating the
 *   a signal occured.
 *-----------------------------------------------------------------------------
 */
static int
ProcessSignals (clientData, interp, cmdResultCode)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         cmdResultCode;
{
    Tcl_Interp *sigInterp;
    Tcl_Obj    *errStateObjPtr;
    int         signalNum, result;

    /*
     * Get the interpreter if it wasn't supplied, if none is available,
     * bail out.
     */
    if (interp == NULL) {
        if (numInterps == 0)
            return cmdResultCode;
        sigInterp = interpTable [0];
    } else {
        sigInterp = interp;
    }

    errStateObjPtr = TclX_SaveResultErrorInfo (sigInterp);

    /*
     * Process all signals.  Don't process any more if one returns an error.
     */
    result = TCL_OK;

    for (signalNum = 1; signalNum < MAXSIG; signalNum++) {
        if (signalsReceived [signalNum] == 0)
            continue;
        result = ProcessASignal (sigInterp,
                                 (interp == NULL),
                                 signalNum);
        if (result == TCL_ERROR)
            break;
    }

    /*
     * Restore result and error state if we didn't get an error in signal
     * handling.
     */
    if (result != TCL_ERROR) {
        TclX_RestoreResultErrorInfo (sigInterp, errStateObjPtr) ;
    } else {
        Tcl_DecrRefCount (errStateObjPtr);
        cmdResultCode = TCL_ERROR;
    }

    /*
     * Reset the signal received flag in case more signals are pending.
     */
    for (signalNum = 1; signalNum < MAXSIG; signalNum++) {
        if (signalsReceived [signalNum] != 0)
            break;
    }
    if (signalNum < MAXSIG) {
	if (asyncHandler)
	    Tcl_AsyncMark (asyncHandler);
    }

    /*
     * If a signal handler returned an error and an interpreter was not
     * supplied, call the background error handler.
     */
    if ((result == TCL_ERROR) && (interp == NULL)) {
        Tcl_BackgroundError (sigInterp);
    }
    return cmdResultCode;
}

/*-----------------------------------------------------------------------------
 * ParseSignalList --
 *  
 *   Parse a list of signal names or numbers.  Also handles the special case
 * of the signal being a single entry of "*".
 * 
 * Parameters:
 *   o interp - Interpreter for returning errors.
 *   o signalListObjPtr - The Tcl list object of signals to convert.
 *   o signals - Boolean array indexed by signal number that indicates
 *     which signals are set.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ParseSignalList (interp, signalListObjPtr, signals)
    Tcl_Interp    *interp;
    Tcl_Obj       *signalListObjPtr;
    unsigned char  signals [MAXSIG];
{
    Tcl_Obj **signalObjv;
    char     *signalStr;
    int       signalObjc, signalNum, idx, cnt;

    if (Tcl_ListObjGetElements (interp, signalListObjPtr,
                                &signalObjc, &signalObjv) != TCL_OK)
        return TCL_ERROR;

    if (signalObjc == 0) {
        TclX_AppendObjResult (interp, "signal list may not be empty",
                              (char *) NULL);
        return TCL_ERROR;
    }

    memset (signals, FALSE, sizeof (unsigned char) * MAXSIG);

    /*
     * Handle the wild card signal.  Don't return signals that can't be
     * modified.
     */
    signalStr = Tcl_GetStringFromObj (signalObjv [0], NULL);
    if (STREQU (signalStr, "*")) {
        if (signalObjc != 1)
            goto wildMustBeAlone;
        cnt = 0;
        for (idx = 0; sigNameTable [idx].name != NULL; idx++) {
            signalNum = sigNameTable [idx].num;
#ifdef SIGKILL
            if ((signalNum == SIGKILL) || (signalNum == SIGSTOP))
                continue;
#endif
            signals [signalNum] = TRUE;
        }
        goto okExit;
    }

    /*
     * Handle individually specified signals.
     */
    for (idx = 0; idx < signalObjc; idx++) {
        signalStr = Tcl_GetStringFromObj (signalObjv [idx], NULL);
        if (STREQU (signalStr, "*"))
            goto wildMustBeAlone;

        signalNum = ParseSignalSpec (interp,
                                     signalStr,
                                     FALSE);  /* Zero not valid */
        if (signalNum < 0)
            return TCL_ERROR;
        signals [signalNum] = TRUE;
    }

  okExit:
    return TCL_OK;

  wildMustBeAlone:
    TclX_AppendObjResult (interp, "when \"*\" is specified in the signal ",
                          "list, no other signals may be specified",
                          (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * SetSignalActions --
 *     
 *    Set the signal state for the specified signals.  
 *
 * Parameters::
 *   o interp - The list is returned in the result.
 *   o signals - Boolean array indexed by signal number that indicates
 *     the requested signals.
 *   o actionFunc - The function to run when the signal is received.
 *   o restart - Restart systems calls on signal.
 *   o command - If the function is the "trap" function, this is the
 *     Tcl command to run when the trap occurs.  Otherwise, NULL.
 * Returns:
 *   TCL_OK or TCL_ERROR, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
SetSignalActions (interp, signals, actionFunc, restart, command)
    Tcl_Interp      *interp;
    unsigned char    signals [MAXSIG];
    signalProcPtr_t  actionFunc;
    int              restart;
    char            *command;
{
    int signalNum;

    for (signalNum = 0; signalNum < MAXSIG; signalNum++) {
        if (!signals [signalNum])
            continue;

        if (signalTrapCmds [signalNum] != NULL) {
            ckfree (signalTrapCmds [signalNum]);
            signalTrapCmds [signalNum] = NULL;
        }
        if (command != NULL)
            signalTrapCmds [signalNum] = ckstrdup (command);

        if (SetSignalState (signalNum, actionFunc, restart) == TCL_ERROR) {
            TclX_AppendObjResult (interp, Tcl_PosixError (interp),
                                  " while setting ", Tcl_SignalId (signalNum),
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * FormatSignalListEntry --
 *     
 *    Retrieve a signal's state and format a keyed list entry used to describe
 * a that state.
 *
 * Parameters::
 *   o interp - Error messages are returned here.
 *   o signalNum - The signal to get the state for.
 *   o sigStatesObjPtr - Keyed list to add entry to.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
FormatSignalListEntry (interp, signalNum, sigStatesObjPtr)
    Tcl_Interp *interp;
    int         signalNum;
    Tcl_Obj    *sigStatesObjPtr;
{
    Tcl_Obj *stateObjv [4], *stateObjPtr;
    signalProcPtr_t  actionFunc;
    char *actionStr, *idStr;
    int restart;

    if (GetSignalState (signalNum, &actionFunc, &restart) == TCL_ERROR)
        goto unixSigError;

    if (actionFunc == SIG_DFL) {
        actionStr = SIGACT_DEFAULT;
    } else if (actionFunc == SIG_IGN) {
        actionStr = SIGACT_IGNORE;
    } else if (actionFunc == SignalTrap) {
        if (signalTrapCmds [signalNum] == NULL) {
            actionStr = SIGACT_ERROR;
        } else {
            actionStr = SIGACT_TRAP;
        }
    } else {
        actionStr = SIGACT_UNKNOWN;
    }

    stateObjv [1] = SignalBlocked (signalNum);
    if (stateObjv [1] == NULL)
        goto unixSigError;
    stateObjv [0] = Tcl_NewStringObj (actionStr, -1);
    if (signalTrapCmds [signalNum] != NULL) {
        stateObjv [2] = Tcl_NewStringObj (signalTrapCmds [signalNum], -1);
    } else {
        stateObjv [2] = Tcl_NewStringObj ("", -1);
    }
    stateObjv [3] = Tcl_NewBooleanObj(restart);

    stateObjPtr = Tcl_NewListObj (4, stateObjv);
    Tcl_IncrRefCount (stateObjPtr);

    /*
     * Dup the string so we don't pass a const char to KLSet.
     */
    idStr = ckstrdup(Tcl_SignalId(signalNum));
    if (TclX_KeyedListSet (interp, sigStatesObjPtr, idStr,
		stateObjPtr) != TCL_OK) {
	ckfree(idStr);
        Tcl_DecrRefCount (stateObjPtr);
        return TCL_ERROR;
    }
    ckfree(idStr);
    Tcl_DecrRefCount (stateObjPtr);

    return TCL_OK;

  unixSigError:
    TclX_AppendObjResult (interp, Tcl_PosixError (interp),
                          " while getting ", Tcl_SignalId (signalNum),
                          (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * ProcessSignalListEntry --
 *     
 *    Parse a keyed list entry used to describe a signal state and set the
 * signal to that state.  If the signal action is specified as "unknown",
 * it is ignored.
 *
 * Parameters::
 *   o interp - Error messages are returned here.
 *   o signalName - Signal name.
 *   o stateObjPtr - Signal state information from keyed list.
 * Returns:
 *   TCL_OK or TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
static int
ProcessSignalListEntry (interp, signalName, stateObjPtr)
    Tcl_Interp *interp;
    char       *signalName;
    Tcl_Obj    *stateObjPtr;
{
    Tcl_Obj **stateObjv;
    int stateObjc;
    char *actionStr, *cmdStr;
    int signalNum, blocked;
    signalProcPtr_t  actionFunc = NULL;
    int restart = FALSE;
    unsigned char signals [MAXSIG];

    /*
     * Get state list.
     */
    if (Tcl_ListObjGetElements (interp, stateObjPtr,
                                &stateObjc, &stateObjv) != TCL_OK)
        return TCL_ERROR;
    if (stateObjc < 2 || stateObjc > 4)
        goto invalidEntry;
    
    /*
     * Parse the signal name and action.
     */
    if (SigNameToNum (interp, signalName, &signalNum) != TCL_OK)
        return TCL_ERROR;
    
    actionStr = Tcl_GetStringFromObj (stateObjv [0], NULL);
    cmdStr = NULL;
    if (stateObjc > 2) {
        cmdStr = Tcl_GetStringFromObj (stateObjv [2], NULL);
        if (cmdStr[0] == '\0') {
            cmdStr = NULL;
        }
    }
    if (STREQU (actionStr, SIGACT_DEFAULT)) {
        actionFunc = SIG_DFL;
        if (cmdStr != NULL)
            goto invalidEntry;
    } else if (STREQU (actionStr, SIGACT_IGNORE)) {
        actionFunc = SIG_IGN;
        if (cmdStr != NULL)
            goto invalidEntry;
    } else if (STREQU (actionStr, SIGACT_ERROR)) {
        actionFunc = SignalTrap;
        if (cmdStr != NULL)
            goto invalidEntry;
    } else if (STREQU (actionStr, SIGACT_TRAP)) {
        actionFunc = SignalTrap;
        if (cmdStr == NULL)    /* Must have command */
            goto invalidEntry;
    } else if (STREQU (actionStr, SIGACT_UNKNOWN)) {
        if (cmdStr != NULL)
            goto invalidEntry;
        return TCL_OK;  /* Ignore non-Tcl signals */
    }

    if (Tcl_GetBooleanFromObj (interp, stateObjv [1], &blocked) != TCL_OK)
        return TCL_ERROR;
    if (stateObjc > 3) {
        if (Tcl_GetBooleanFromObj (interp, stateObjv [3], &restart) != TCL_OK)
            return TCL_ERROR;
    }
    
    memset (signals, FALSE, sizeof (unsigned char) * MAXSIG);
    signals [signalNum] = TRUE;

    /*
     * Set signal actions and handle blocking if its supported on this
     * system.  If the signal is to be blocked, we do it before setting up
     * the handler.  If its to be unblocked, we do it after.
     */
#ifndef NO_SIGACTION
    if (blocked) {
        if (BlockSignals (interp, SIG_BLOCK, signals) != TCL_OK)
            return TCL_ERROR;
    }
#endif
    if (SetSignalActions (interp, signals, actionFunc, restart,
                          cmdStr) != TCL_OK)
        return TCL_ERROR;
#ifndef NO_SIGACTION
    if (!blocked) {
        if (BlockSignals (interp, SIG_UNBLOCK, signals) != TCL_OK)
            return TCL_ERROR;
    }
#endif
    
    return TCL_OK;

  invalidEntry:
    TclX_AppendObjResult (interp, "invalid signal keyed list entry for ",
                          signalName, (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * GetSignalStates --
 *     
 *    Return a keyed list containing the signal states for the specified
 * signals.
 *
 * Parameters::
 *   o interp - The list is returned in the result.
 *   o signals - Boolean array indexed by signal number that indicates
 *     the requested signals.
 * Returns:
 *   TCL_OK or TCL_ERROR, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
GetSignalStates (interp, signals)
    Tcl_Interp    *interp;
    unsigned char  signals [MAXSIG];
{
    int signalNum;
    Tcl_Obj *sigStatesObjPtr;

    sigStatesObjPtr = TclX_NewKeyedListObj ();

    for (signalNum = 0; signalNum < MAXSIG; signalNum++) {
        if (!signals [signalNum])
            continue;
        if (FormatSignalListEntry (interp, 
                                   signalNum,
                                   sigStatesObjPtr) != TCL_OK) {
            Tcl_DecrRefCount (sigStatesObjPtr);
            return TCL_ERROR;
        }
    }

    Tcl_SetObjResult (interp, sigStatesObjPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * SetSignalStates --
 *     
 *    Set signal states from keyed list in the format returned by
 * GetSignalStates.
 *
 * Parameters::
 *   o interp - Errors are returned in the result.
 *   o sigStatesObjPtr - Keyed list to add entry to.
 * Returns:
 *   TCL_OK or TCL_ERROR, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
SetSignalStates (interp, sigStatesObjPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *sigStatesObjPtr;
{
    Tcl_Obj *keysListObj, **keysObjv, *stateObjPtr;
    int keysObjc, idx;
    char *signalName;

    if (TclX_KeyedListGetKeys (interp, sigStatesObjPtr, NULL,
                               &keysListObj) != TCL_OK)
        return TCL_ERROR;
    if (Tcl_ListObjGetElements (interp, keysListObj,
                                &keysObjc, &keysObjv) != TCL_OK)
        return TCL_ERROR;
                               
    for (idx = 0; idx < keysObjc; idx++) {
        signalName = Tcl_GetStringFromObj (keysObjv [idx], NULL);
        if (TclX_KeyedListGet (interp, sigStatesObjPtr, signalName,
                               &stateObjPtr) != TCL_OK)
            return TCL_ERROR;
        if (ProcessSignalListEntry (interp, signalName, stateObjPtr) != TCL_OK)
            return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_SignalObjCmd --
 *     Implements the Tcl signal command:
 *         signal action siglist ?command?
 *-----------------------------------------------------------------------------
 */
static int
TclX_SignalObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    unsigned char signals [MAXSIG];
    char *argStr, *actionStr;
    int firstArg = 1;
    int numArgs;
    int restart = FALSE;

    while (firstArg < objc) {
        argStr = Tcl_GetStringFromObj (objv [firstArg], NULL);
        if (argStr[0] != '-') {
            break;
        }
        if (STREQU (argStr, "-restart")) {
            restart = TRUE;
        } else {
            TclX_AppendObjResult(interp, "invalid option \"", argStr,
                                 "\", expected -restart", NULL);
            return TCL_ERROR;
        }
        firstArg++;
    }
    numArgs = objc - firstArg;

    if ((numArgs < 2) || (numArgs > 3)) {
        TclX_WrongArgs (interp, objv [0], "?-restart? action signalList ?command?");
        return TCL_ERROR;
    }
#ifdef NO_SIG_RESTART
    if (restart) {
        TclX_AppendObjResult(interp, "restarting of system calls from signals is not available on this system",
                             NULL);
        return TCL_ERROR;
    }
#endif

    actionStr = Tcl_GetStringFromObj (objv [firstArg], NULL);

    /*
     * Do the specified action on the signals.  "set" has a special format
     * for the signal list, so do it first.
     */
    if (STREQU (actionStr, "set")) {
        if (numArgs != 2)
            goto cmdNotValid;
        return SetSignalStates (interp, objv [firstArg+1]);
    }

    if (ParseSignalList (interp,
                         objv [firstArg+1],
                         signals) != TCL_OK)
        return TCL_ERROR;

    if (STREQU (actionStr, SIGACT_TRAP)) {
        if (numArgs != 3) {
            TclX_AppendObjResult (interp, "command required for ",
                                  "trapping signals", (char *) NULL);
            return TCL_ERROR;
        }
        return SetSignalActions (interp,
                                 signals,
                                 SignalTrap,
                                 restart,
                                 Tcl_GetStringFromObj (objv [firstArg+2], NULL));
    }

    if (numArgs != 2)
        goto cmdNotValid;
    
    if (STREQU (actionStr, SIGACT_DEFAULT)) {
        return SetSignalActions (interp,
                                 signals,
                                 SIG_DFL,
                                 restart,
                                 NULL);
    }

    if (STREQU (actionStr, SIGACT_IGNORE)) {
        return SetSignalActions (interp,
                                 signals,
                                 SIG_IGN,
                                 restart,
                                 NULL);
    }

    if (STREQU (actionStr, SIGACT_ERROR)) {
        return SetSignalActions (interp,
                                 signals,
                                 SignalTrap,
                                 restart,
                                 NULL);
    }

    if (STREQU (actionStr, "get")) {
        return GetSignalStates (interp,
                                signals);
    }

    if (STREQU (actionStr, "block")) {
        return BlockSignals (interp,
                             SIG_BLOCK,
                             signals);
    }

    if (STREQU (actionStr, "unblock")) {
        return BlockSignals (interp,
                             SIG_UNBLOCK,
                             signals);
    }

    /*
     * Not a valid action.
     */
    TclX_AppendObjResult (interp, "invalid signal action specified: ", 
                          actionStr, ": expected one of \"default\", ",
                          "\"ignore\", \"error\", \"trap\", \"get\", ",
                          "\"set\", \"block\", or \"unblock\"", (char *) NULL);
    return TCL_ERROR;


  cmdNotValid:
    TclX_AppendObjResult (interp, "command may not be ",
                          "specified for \"", actionStr, "\" action",
                          (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_KillObjCmd --
 *     Implements the Tcl kill command:
 *        kill ?-pgroup? ?signal? idlist
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *-----------------------------------------------------------------------------
 */
static int
TclX_KillObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    int    signalNum, nextArg, idx, procId, procObjc;
    int    pgroup = FALSE;
    char  *cmdStr, *argStr;
    Tcl_Obj **procObjv;
    
#ifdef SIGTERM
#   define DEFAULT_KILL_SIGNAL SIGTERM
#else
#   define DEFAULT_KILL_SIGNAL SIGINT
#endif

    if (objc < 2)
        goto usage;

    nextArg = 1;
    argStr = Tcl_GetStringFromObj (objv [nextArg], NULL);
    if (STREQU (argStr, "-pgroup")) {
        pgroup = TRUE;
        nextArg++;
    }
        
    if (((objc - nextArg) < 1) || ((objc - nextArg) > 2))
        goto usage;

    /*
     * Get the signal.
     */
    if ((objc - nextArg) == 1) {
        signalNum = DEFAULT_KILL_SIGNAL;
    } else {
        argStr = Tcl_GetStringFromObj (objv [nextArg], NULL);
        signalNum = ParseSignalSpec (interp,
                                     argStr,
                                     TRUE);  /* Allow zero */
        if (signalNum < 0)
            return TCL_ERROR;
        nextArg++;
    }

    if (Tcl_ListObjGetElements (interp, objv [nextArg], &procObjc, 
                       &procObjv) != TCL_OK)
        return TCL_ERROR;

    cmdStr = Tcl_GetStringFromObj (objv [0], NULL);

    for (idx = 0; idx < procObjc; idx++) {
        if (Tcl_GetIntFromObj (interp, procObjv [idx], &procId) != TCL_OK)
            goto errorExit;
        
        if (pgroup)
            procId = -procId;

        if (TclXOSkill (interp, procId, signalNum, cmdStr) != TCL_OK)
            goto errorExit;
    }

    return TCL_OK;
        
  errorExit:
    return TCL_ERROR;

  usage:
    TclX_WrongArgs (interp, objv [0], "?-pgroup? ?signal? idlist");
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * SignalCmdCleanUp --
 *
 *   Clean up the signal data structure when an interpreter is deleted. If
 * this is the last interpreter, clean up all tables.
 *
 * Parameters:
 *   o clientData - Not used.
 *   o interp - Interp that is being deleted.
 *-----------------------------------------------------------------------------
 */
static void
SignalCmdCleanUp (clientData, interp)
    ClientData  clientData;
    Tcl_Interp *interp;
{
    int  idx;

    for (idx = 0; idx < numInterps; idx++) {
        if (interpTable [idx] == interp)
            break;
    }
    if (idx == numInterps)
        Tcl_Panic ("signal interp lost");

    interpTable [idx] = interpTable [--numInterps];

    /*
     * If there are no more interpreters, clean everything up.
     */
    if (numInterps == 0) {
        ckfree ((char *) interpTable);
        interpTable = NULL;
        interpTableSize = 0;

	Tcl_AsyncDelete(asyncHandler);

        for (idx = 0; idx < MAXSIG; idx++) {
            if (signalTrapCmds [idx] != NULL) {
                ckfree (signalTrapCmds [idx]);
                signalTrapCmds [idx] = NULL;
            }
        }
    }
}

/*-----------------------------------------------------------------------------
 * TclX_SetupSigInt --
 *    Set up SIGINT to the "error" state if the current state is default.
 * This is done because shells set SIGINT to ignore for background processes
 * so that they don't die on signals generated by the user at the keyboard.
 * Tcl only enables SIGINT catching if it is an interactive session.
 *-----------------------------------------------------------------------------
 */
void
TclX_SetupSigInt ()
{
    signalProcPtr_t  actionFunc;
    int restart;

    if ((GetSignalState (SIGINT, &actionFunc, &restart) == TCL_OK) &&
        (actionFunc == SIG_DFL)) {
        SetSignalState (SIGINT, SignalTrap, FALSE);
    }
}

/*-----------------------------------------------------------------------------
 * TclX_SetAppSignalErrorHandler --
 *
 *   Set the current application signal error handler.  This is kind of a
 * hack.  It just saves the handler and client data in globals.
 *
 * Parameters:
 *   o errorFunc - Error handling function.
 *   o clientData - Client data to pass to function
 *-----------------------------------------------------------------------------
 */
void
TclX_SetAppSignalErrorHandler (errorFunc, clientData)
    TclX_AppSignalErrorHandler errorFunc;
    ClientData                 clientData;
{
    appSigErrorHandler = errorFunc;
    appSigErrorClientData = clientData;
}

/*-----------------------------------------------------------------------------
 * TclX_SignalInit --
 *      Initializes singal handling for a interpreter.
 *-----------------------------------------------------------------------------
 */
void
TclX_SignalInit (interp)
    Tcl_Interp *interp;
{
    int		idx;

    /*
     * If this is the first interpreter, set everything up.
     */
    if (numInterps == 0) {
        interpTableSize = 4;
        interpTable = (Tcl_Interp **)
            ckalloc (sizeof (Tcl_Interp *) * interpTableSize);

        for (idx = 0; idx < MAXSIG; idx++) {
            signalsReceived [idx] = 0;
            signalTrapCmds [idx] = NULL;
        }
	asyncHandler = Tcl_AsyncCreate (ProcessSignals, (ClientData) NULL);
        /*
         * Get address of "unknown signal" message.
         */
        unknownSignalIdMsg = Tcl_SignalId (20000);
    }

    /*
     * If there is not room in this table for another interp, expand it.
     */
    if (numInterps == interpTableSize) {
        interpTable = (Tcl_Interp **)
			ckrealloc((char *)interpTable,
				  sizeof(Tcl_Interp *) * interpTableSize * 2);
        interpTableSize *= 2;
    }

    /*
     * Add this interpreter to the list and set up a async handler.
     * Arange for clean up on the interpreter being deleted.
     */
    interpTable [numInterps] = interp;
    numInterps++;

    Tcl_CallWhenDeleted (interp, SignalCmdCleanUp, (ClientData) NULL);

    Tcl_CreateObjCommand (interp, "signal", TclX_SignalObjCmd,
                          (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);
    Tcl_CreateObjCommand (interp, "kill", TclX_KillObjCmd,
                          (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);
}



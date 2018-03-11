/*
 * tclXdebug.c --
 *
 * Tcl command execution trace command.
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
 * $Id: tclXdebug.c,v 1.3 2002/09/26 00:19:18 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Client data structure for the cmdtrace command.
 */
#define ARG_TRUNCATE_SIZE 40
#define CMD_TRUNCATE_SIZE 60

typedef struct traceInfo_t {
    Tcl_Interp       *interp;
    Tcl_Trace         traceId;
    int               inTrace;
    int               noEval;
    int               noTruncate;
    int               procCalls;
    int               depth;
    char             *callback;
    Tcl_Obj          *errorStatePtr;
    Tcl_AsyncHandler  errorAsyncHandler;
    Tcl_Channel       channel;
    } traceInfo_t, *traceInfo_pt;

/*
 * Prototypes of internal functions.
 */
static void
TraceDelete _ANSI_ARGS_((Tcl_Interp   *interp,
                         traceInfo_pt  infoPtr));

static void
PrintStr _ANSI_ARGS_((Tcl_Channel  channel,
                      CONST84 char *string,
                      int          numChars,
                      int          quoted));

static void
PrintArg _ANSI_ARGS_((Tcl_Channel  channel,
                      CONST84 char *argStr,
                      int          noTruncate));

static void
TraceCode  _ANSI_ARGS_((traceInfo_pt infoPtr,
                        int          level,
                        char        *command,
                        int          argc,
                        CONST84 char **argv));

static int
TraceCallbackErrorHandler _ANSI_ARGS_((ClientData  clientData,
                                       Tcl_Interp *interp,
                                       int         code));

static void
TraceCallBack _ANSI_ARGS_((Tcl_Interp   *interp,
                           traceInfo_pt  infoPtr,
                           int           level,
                           char         *command,
                           int           argc,
                           CONST84 char **argv));

static void
CmdTraceRoutine _ANSI_ARGS_((ClientData    clientData,
                             Tcl_Interp   *interp,
                             int           level,
                             char         *command,
                             Tcl_CmdProc  *cmdProc,
                             ClientData    cmdClientData,
                             int           argc,
                             CONST84 char **argv));

static int
TclX_CmdtraceObjCmd _ANSI_ARGS_((ClientData clientData, 
                                 Tcl_Interp *interp,
                                 int objc,
                                 Tcl_Obj *CONST objv[]));

static void
DebugCleanUp _ANSI_ARGS_((ClientData  clientData,
                          Tcl_Interp *interp));


/*-----------------------------------------------------------------------------
 * TraceDelete --
 *
 *   Delete the trace if active, reseting the structure.
 *-----------------------------------------------------------------------------
 */
static void
TraceDelete (interp, infoPtr)
    Tcl_Interp   *interp;
    traceInfo_pt  infoPtr;
{
    if (infoPtr->traceId != NULL) {
        Tcl_DeleteTrace (interp, infoPtr->traceId);
        infoPtr->depth = 0;
        infoPtr->traceId = NULL;
        if (infoPtr->callback != NULL) {
            ckfree (infoPtr->callback);
            infoPtr->callback = NULL;
        }
    }
    if (infoPtr->errorAsyncHandler != NULL) {
        Tcl_AsyncDelete (infoPtr->errorAsyncHandler);
        infoPtr->errorAsyncHandler = NULL;
    }
}

/*-----------------------------------------------------------------------------
 * PrintStr --
 *
 *     Print an string, truncating it to the specified number of characters.
 * If the string contains newlines, \n is substituted.
 *-----------------------------------------------------------------------------
 */
static void
PrintStr (channel, string, numChars, quoted)
    Tcl_Channel  channel;
    CONST84 char *string;
    int          numChars;
    int          quoted;
{
    int idx;

    if (quoted) 
        Tcl_Write (channel, "{", 1);
    for (idx = 0; idx < numChars; idx++) {
        if (string [idx] == '\n') {
            Tcl_Write (channel, "\\n", 2);
        } else {
            Tcl_Write (channel, &(string [idx]), 1);
        }
    }
    if (numChars < (int) strlen (string))
        Tcl_Write (channel, "...", 3);
    if (quoted) 
        Tcl_Write (channel, "}", 1);
}

/*-----------------------------------------------------------------------------
 * PrintArg --
 *
 *   Print an argument string, truncating and adding "..." if its longer
 * then ARG_TRUNCATE_SIZE.  If the string contains white spaces, quote
 * it with braces.
 *-----------------------------------------------------------------------------
 */
static void
PrintArg (channel, argStr, noTruncate)
    Tcl_Channel  channel;
    CONST84 char *argStr;
    int          noTruncate;
{
    int idx, argLen, printLen;
    int quoted;

    argLen = strlen (argStr);
    printLen = argLen;
    if ((!noTruncate) && (printLen > ARG_TRUNCATE_SIZE))
        printLen = ARG_TRUNCATE_SIZE;

    quoted = (printLen == 0);

    for (idx = 0; idx < printLen; idx++)
        if (ISSPACE (argStr [idx])) {
            quoted = TRUE;
            break;
        }

    PrintStr (channel, argStr, printLen, quoted);
}

/*-----------------------------------------------------------------------------
 * TraceCode --
 *
 *   Print out a trace of a code line.  Level is used for indenting
 * and marking lines and may be eval or procedure level.
 *-----------------------------------------------------------------------------
 */
static void
TraceCode (infoPtr, level, command, argc, argv)
    traceInfo_pt infoPtr;
    int          level;
    char        *command;
    int          argc;
    CONST84 char **argv;
{
    int idx, cmdLen, printLen;
    char buf [32];

    sprintf (buf, "%2d:", level);
    Tcl_Write(infoPtr->channel, buf, -1); 

    if (level > 20)
        level = 20;
    for (idx = 0; idx < level; idx++) 
        Tcl_Write (infoPtr->channel, "  ", 2);

    if (infoPtr->noEval) {
        cmdLen = printLen = strlen (command);
        if ((!infoPtr->noTruncate) && (printLen > CMD_TRUNCATE_SIZE))
            printLen = CMD_TRUNCATE_SIZE;

        PrintStr (infoPtr->channel, (CONST84 char *) command, printLen, FALSE);
      } else {
          for (idx = 0; idx < argc; idx++) {
              if (idx > 0)
                  Tcl_Write (infoPtr->channel, " ", 1);
              PrintArg (infoPtr->channel,
                        argv [idx], 
                        infoPtr->noTruncate);
          }
    }

    TclX_WriteNL (infoPtr->channel);
    Tcl_Flush (infoPtr->channel);
}


/*-----------------------------------------------------------------------------
 * TraceCallbackErrorHandler --
 *
 *   Async handler that processes an callback error.  Generates either an
 * immediate or background error.
 *-----------------------------------------------------------------------------
 */
static int
TraceCallbackErrorHandler (clientData, interp, code)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         code;
{
    traceInfo_pt infoPtr = (traceInfo_pt) clientData;

    /*
     * Put back error message and state.  If not interp passed in, the error
     * is handled in the background.
     */
    TclX_RestoreResultErrorInfo (infoPtr->interp, infoPtr->errorStatePtr);
    infoPtr->errorStatePtr = NULL;
    if (interp == NULL) {
        Tcl_BackgroundError (infoPtr->interp);
    }    
    
    TraceDelete (interp, infoPtr);

    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TraceCallBack --
 *
 *   Build and call a callback for the command that was just executed. The
 * following arguments are appended to the command:
 *   1) command - A string containing the text of the command, before any
 *      argument substitution.
 *   2) argv - A list of the final argument information that will be passed to
 *     the command after command, variable, and backslash substitution.
 *   3) evalLevel - The Tcl_Eval level.
 *   4) procLevel - The procedure level.
 * The code should allow for additional substitution of arguments in future
 * versions (such as a procedure with args as the last argument).  The value
 * of result, errorInfo and errorCode are preserved.  All other state must be
 * preserved by the procedure.  An error will result in an error being flagged
 * in the control block and async mark being called to handle the error
 * once the command has completed.
 *-----------------------------------------------------------------------------
 */
static void
TraceCallBack (interp, infoPtr, level, command, argc, argv)
    Tcl_Interp   *interp;
    traceInfo_pt  infoPtr;
    int           level;
    char         *command;
    int           argc;
    CONST84 char **argv;
{
    Interp       *iPtr = (Interp *) interp;
    Tcl_DString   callback;
    Tcl_Obj      *saveObjPtr;
    char         *cmdList;
    char          numBuf [32];

    Tcl_DStringInit (&callback);

    /*
     * Build the command to evaluate.
     */
    Tcl_DStringAppend (&callback, infoPtr->callback, -1);

    Tcl_DStringStartSublist (&callback);
    Tcl_DStringAppendElement (&callback, command);
    Tcl_DStringEndSublist (&callback);

    Tcl_DStringStartSublist (&callback);
    cmdList = Tcl_Merge (argc, argv);
    Tcl_DStringAppendElement (&callback, cmdList);
    ckfree (cmdList);
    Tcl_DStringEndSublist (&callback);

    sprintf (numBuf, "%d", level);
    Tcl_DStringAppendElement (&callback, numBuf);

    sprintf (numBuf, "%d",  ((iPtr->varFramePtr == NULL) ? 0 : 
             iPtr->varFramePtr->level));
    Tcl_DStringAppendElement (&callback, numBuf);

    saveObjPtr = TclX_SaveResultErrorInfo (interp);

    /*
     * Evaluate the command.  If an error occurs, set up the handler to be
     * called when its possible.
     */
    if (Tcl_Eval (interp, Tcl_DStringValue (&callback)) == TCL_ERROR) {
        Tcl_AddObjErrorInfo (interp, "\n    (\"cmdtrace\" callback command)",
                             -1);
        infoPtr->errorStatePtr = TclX_SaveResultErrorInfo (interp);
        Tcl_AsyncMark (infoPtr->errorAsyncHandler);
    }

    TclX_RestoreResultErrorInfo (interp, saveObjPtr);

    Tcl_DStringFree (&callback);
}

/*-----------------------------------------------------------------------------
 * CmdTraceRoutine --
 *
 *  Routine called by Tcl_Eval to trace a command.
 *-----------------------------------------------------------------------------
 */
static void
CmdTraceRoutine (clientData, interp, level, command, cmdProc, cmdClientData, 
                 argc, argv)
    ClientData    clientData;
    Tcl_Interp   *interp;
    int           level;
    char         *command;
    Tcl_CmdProc  *cmdProc;
    ClientData    cmdClientData;
    int           argc;
    CONST84 char **argv;
{
    Interp       *iPtr = (Interp *) interp;
    traceInfo_pt  infoPtr = (traceInfo_pt) clientData;
    int           procLevel;

    /*
     * If we are in an error.  
     */
    if (infoPtr->inTrace || (infoPtr->errorStatePtr != NULL)) {
        return;
    }
    infoPtr->inTrace = TRUE;

    if (infoPtr->procCalls) {
        if (TclFindProc (iPtr, argv [0]) != NULL) {
            if (infoPtr->callback != NULL) {
                TraceCallBack (interp, infoPtr, level, command, argc, argv);
            } else {
                procLevel = (iPtr->varFramePtr == NULL) ? 0 : 
                    iPtr->varFramePtr->level;
                TraceCode (infoPtr, procLevel, command, argc, argv);
            }
        }
    } else {
        if (infoPtr->callback != NULL) {
            TraceCallBack (interp, infoPtr, level, command, argc, argv);
        } else {
            TraceCode (infoPtr, level, command, argc, argv);
        }
    }
    infoPtr->inTrace = FALSE;
}

/*-----------------------------------------------------------------------------
 * Tcl_CmdtraceObjCmd --
 *
 * Implements the TCL trace command:
 *     cmdtrace level|on ?noeval? ?notruncate? ?procs? ?fileid? ?command cmd?
 *     cmdtrace off
 *     cmdtrace depth
 *-----------------------------------------------------------------------------
 */
static int
TclX_CmdtraceObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    traceInfo_pt  infoPtr = (traceInfo_pt) clientData;
    int idx;
    char *argStr, *callback;
    Tcl_Obj *channelId;

    if (objc < 2)
        goto argumentError;
    argStr = Tcl_GetStringFromObj (objv [1], NULL);

    /*
     * Handle `depth' sub-command.
     */
    if (STREQU (argStr, "depth")) {
        if (objc != 2)
            goto argumentError;
        Tcl_SetIntObj (Tcl_GetObjResult (interp),  infoPtr->depth);
        return TCL_OK;
    }

    /*
     * If a trace is in progress, delete it now.
     */
    TraceDelete (interp, infoPtr);

    /*
     * Handle off sub-command.
     */
    if (STREQU (argStr, "off")) {
        if (objc != 2)
            goto argumentError;
        return TCL_OK;
    }

    infoPtr->noEval     = FALSE;
    infoPtr->noTruncate = FALSE;
    infoPtr->procCalls  = FALSE;
    infoPtr->channel    = NULL;
    channelId           = NULL;
    callback            = NULL;

    if (STREQU (argStr, "on")) {
        infoPtr->depth = MAXINT;
    } else {
        if (Tcl_GetIntFromObj (interp, objv [1], &(infoPtr->depth)) != TCL_OK)
            return TCL_ERROR;
    }

    for (idx = 2; idx < objc; idx++) {
        argStr = Tcl_GetStringFromObj (objv [idx], NULL);
        if (STREQU (argStr, "notruncate")) {
            if (infoPtr->noTruncate)
                goto argumentError;
            infoPtr->noTruncate = TRUE;
            continue;
        }
        if (STREQU (argStr, "noeval")) {
            if (infoPtr->noEval)
                goto argumentError;
            infoPtr->noEval = TRUE;
            continue;
        }
        if (STREQU (argStr, "procs")) {
            if (infoPtr->procCalls)
                goto argumentError;
            infoPtr->procCalls = TRUE;
            continue;
        }
        if (STRNEQU (argStr, "std", 3) || 
                STRNEQU (argStr, "file", 4)) {
            if (channelId != NULL)
                goto argumentError;
            if (callback != NULL)
                goto mixCommandAndFile;
            channelId = objv [idx];
            continue;
        }
        if (STREQU (argStr, "command")) {
            if (callback != NULL)
                goto argumentError;
            if (channelId != NULL)
                goto mixCommandAndFile;
            if (idx == objc - 1)
                goto missingCommand;
            callback = Tcl_GetStringFromObj (objv [++idx], NULL);
            continue;
        }
        goto invalidOption;
    }

    if (callback != NULL) {
        infoPtr->callback = ckstrdup (callback);
        infoPtr->errorAsyncHandler =
            Tcl_AsyncCreate (TraceCallbackErrorHandler, 
                             (ClientData) infoPtr);

    } else {
        if (channelId == NULL) {
            infoPtr->channel = TclX_GetOpenChannel (interp,
                                                    "stdout",
                                                    TCL_WRITABLE);
        } else {
            infoPtr->channel = TclX_GetOpenChannelObj (interp,
                                                       channelId,
                                                       TCL_WRITABLE);
        }
        if (infoPtr->channel == NULL)
            return TCL_ERROR;
    }
    infoPtr->traceId =
        Tcl_CreateTrace (interp,
                         infoPtr->depth,
                         (Tcl_CmdTraceProc*) CmdTraceRoutine,
                         (ClientData) infoPtr);
    return TCL_OK;

  argumentError:
    TclX_AppendObjResult (interp, tclXWrongArgs, objv [0], 
                          " level | on ?noeval? ?notruncate? ?procs?",
                          "?fileid? ?command cmd? | off | depth",
                          (char *) NULL);
    return TCL_ERROR;

  missingCommand:
    TclX_AppendObjResult (interp, "command option requires an argument",
                          (char *) NULL);
    return TCL_ERROR;

  mixCommandAndFile:
    TclX_AppendObjResult (interp, "can not specify both the command option ",
                          "and a file handle", (char *) NULL);
    return TCL_ERROR;

  invalidOption:
    TclX_AppendObjResult (interp, "invalid option: expected ",
                          "one of \"noeval\", \"notruncate\", \"procs\", ",
                          "\"command\", or a file id", (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * DebugCleanUp --
 *
 *  Release the debug data area when the interpreter is deleted.
 *-----------------------------------------------------------------------------
 */
static void
DebugCleanUp (clientData, interp)
    ClientData  clientData;
    Tcl_Interp *interp;
{
    traceInfo_pt infoPtr = (traceInfo_pt) clientData;

    TraceDelete (interp, infoPtr);
    ckfree ((char *) infoPtr);
}

/*-----------------------------------------------------------------------------
 * TclX_DebugInit --
 *
 *  Initialize the TCL debugging commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_DebugInit (interp)
    Tcl_Interp *interp;
{
    traceInfo_pt infoPtr;

    infoPtr = (traceInfo_pt) ckalloc (sizeof (traceInfo_t));

    infoPtr->interp = interp;
    infoPtr->traceId = NULL;
    infoPtr->inTrace = FALSE;
    infoPtr->noEval = FALSE;
    infoPtr->noTruncate = FALSE;
    infoPtr->procCalls = FALSE;
    infoPtr->depth = 0;
    infoPtr->callback = NULL;
    infoPtr->errorStatePtr = NULL;
    infoPtr->errorAsyncHandler = NULL;
    infoPtr->channel = NULL;

    Tcl_CallWhenDeleted (interp, DebugCleanUp, (ClientData) infoPtr);

    Tcl_CreateObjCommand (interp, "cmdtrace",
                          TclX_CmdtraceObjCmd, 
                          (ClientData) infoPtr,
                          (Tcl_CmdDeleteProc*) NULL);
}





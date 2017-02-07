/* 
 * tclXcmdloop --
 *
 *   Interactive command loop, C and Tcl callable.
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
 * $Id: tclXcmdloop.c,v 1.3 2002/09/26 00:19:18 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Client data entry for asynchronous command reading.  This is associated
 * with a given instance of a async command loop.  I allows for recursive
 * commands loops on the same channel (and even multiple, but the results
 * out be unpredicatable).
 */
typedef struct {
    Tcl_Interp  *interp;       /* Interp for command eval.            */
    Tcl_Channel  channel;      /* Input channel.                      */
    int          options;      /* Command loop options.               */
    Tcl_DString  command;      /* Buffer for command being read.      */
    int          partial;      /* Partial command in buffer?          */
    char        *endCommand;   /* Command to execute at end of loop.  */
    char        *prompt1;      /* Prompts to use.                     */
    char        *prompt2;
} asyncLoopData_t;


/*
 * Prototypes of internal functions.
 */
static int
IsSetVarCmd _ANSI_ARGS_((char  *command));

static void
OutputPrompt _ANSI_ARGS_((Tcl_Interp *interp,
                          int         topLevel,
                          char       *prompt1,
                          char       *prompt2));

static int
AsyncSignalErrorHandler _ANSI_ARGS_((Tcl_Interp *interp,
                                     ClientData  clientData,
                                     int         background,
                                     int         signalNum));


static void
AsyncCommandHandler _ANSI_ARGS_((ClientData clientData,
                                 int        mask));

static int
SyncSignalErrorHandler _ANSI_ARGS_((Tcl_Interp *interp,
                                    ClientData  clientData,
                                    int         background,
                                    int         signalNum));

static void
AsyncCommandHandlerDelete _ANSI_ARGS_((ClientData clientData));

static int 
TclX_CommandloopObjCmd _ANSI_ARGS_((ClientData clientData, 
                                    Tcl_Interp *interp,
                                    int objc,
                                    Tcl_Obj *CONST objv[]));

/*-----------------------------------------------------------------------------
 * IsSetVarCmd --
 *    Determine if a command is a `set' command that sets a variable
 * (i.e. two arguments).
 *
 * Parameters:
 *   o command (I) - Command to check.
 * Returns:
 *   TRUE if it is a set that sets a variable, FALSE if its some other command.
 *-----------------------------------------------------------------------------
 */
static int
IsSetVarCmd (command)
    char  *command;
{
    Tcl_Parse tclParse;
    int numWords;

    if ((!STRNEQU (command, "set", 3)) || (!ISSPACE (command [3])))
        return FALSE;  /* Quick check */

    Tcl_ParseCommand(NULL, command, -1, 1, &tclParse);
    numWords = tclParse.numWords;
    Tcl_FreeParse(&tclParse);
    return numWords > 2 ? TRUE : FALSE;
}

/*-----------------------------------------------------------------------------
 * TclX_PrintResult --
 *   Print the result of a Tcl_Eval.  It can optionally not echo "set" commands
 * that successfully set a variable.
 *
 * Parameters:
 *   o interp (I) - A pointer to the interpreter.  Result of command should be
 *     in interp result.
 *   o intResult (I) - The integer result returned by Tcl_Eval.
 *   o checkCmd (I) - If not NULL and the command was sucessful, check to
 *     set if this is a "set" command setting a variable.  If so, don't echo
 *     the result. 
 *-----------------------------------------------------------------------------
 */
void
TclX_PrintResult (interp, intResult, checkCmd)
    Tcl_Interp *interp;
    int         intResult;
    char       *checkCmd;
{
    Tcl_Channel stdoutChan,  stderrChan;
    char *resultStr;

    /*
     * If the command was supplied and it was a successful set of a variable,
     * don't output the result.
     */
    if ((checkCmd != NULL) && (intResult == TCL_OK) && IsSetVarCmd (checkCmd))
        return;

    stdoutChan = Tcl_GetStdChannel(TCL_STDOUT);
    stderrChan = Tcl_GetStdChannel(TCL_STDERR);

    if (intResult == TCL_OK) {
        if (stdoutChan == NULL)
            return;
        resultStr = Tcl_GetStringFromObj(Tcl_GetObjResult(interp), NULL);
        if (resultStr [0] != '\0') {
            if (stderrChan != NULL)
                Tcl_Flush (stderrChan);
            Tcl_WriteChars(stdoutChan, resultStr, -1);
            TclX_WriteNL(stdoutChan);
            Tcl_Flush(stdoutChan);
        }
    } else {
        char msg [64];

        if (stderrChan == NULL)
            return;
        if (stdoutChan != NULL)
            Tcl_Flush (stdoutChan);

        if (intResult == TCL_ERROR) {
            strcpy(msg, "Error: ");
        } else {
            sprintf(msg, "Bad return code (%d): ", intResult);
        }
        resultStr = Tcl_GetStringFromObj(Tcl_GetObjResult(interp), NULL);
        Tcl_WriteChars(stderrChan, msg, -1);
        Tcl_WriteChars(stderrChan, resultStr, -1);
        TclX_WriteNL(stderrChan);
        Tcl_Flush(stderrChan);
    }
}

/*-----------------------------------------------------------------------------
 * OutputPrompt --
 *   Outputs a prompt by executing either the command string in tcl_prompt1 or
 * tcl_prompt2 or a specified prompt string.  Also involkes any pending async
 * handlers, as these need to be done before the eval of the prompt, or they
 * might result in an error in the prompt.
 *
 * Parameters:
 *   o interp (I) - A pointer to the interpreter.
 *   o topLevel (I) - If TRUE, output the top level prompt (tcl_prompt1).
 *   o prompt1 (I) - If not NULL, use this command instead of the value of
 *     tcl_prompt1.  In this case, the result of the command is used rather
 *     than the output.
 *   o prompt2 (I) - If not NULL, use this command instead of the value of
 *     tcl_prompt2.  In this case, the result of the command is used rather
 *     than the output.
 *-----------------------------------------------------------------------------
 */
static void
OutputPrompt (interp, topLevel, prompt1, prompt2)
    Tcl_Interp *interp;
    int         topLevel;
    char       *prompt1;
    char       *prompt2;
{
    char *promptHook;
    char *resultStr;
    int result, useResult, promptDone = FALSE;
    Tcl_Channel stdoutChan, stderrChan;

    stdoutChan = Tcl_GetStdChannel (TCL_STDOUT);
    stderrChan = Tcl_GetStdChannel (TCL_STDERR);

    /*
     * If a signal came in, process it.  This prevents signals that are queued
     * from generating prompt hook errors.
     */
    if (Tcl_AsyncReady ()) {
        Tcl_AsyncInvoke (interp, TCL_OK); 
    }

    if (stderrChan != NULL)
        Tcl_Flush (stderrChan);

    /*
     * Determine prompt command to evaluate.
     */
    if (topLevel) {
        if (prompt1 != NULL) {
            promptHook = prompt1;
            useResult = TRUE;
        } else {
            promptHook = (char *) Tcl_GetVar (interp, "tcl_prompt1",
		    TCL_GLOBAL_ONLY);
            useResult = FALSE;
        }
    } else {
        if (prompt2 != NULL) {
            promptHook = prompt2;
            useResult = TRUE;
        } else {
            promptHook = (char *) Tcl_GetVar (interp, "tcl_prompt2",
		    TCL_GLOBAL_ONLY);
            useResult = FALSE;
        }
    }

    if (promptHook != NULL) {
        result = Tcl_Eval (interp, promptHook);
        resultStr = Tcl_GetStringFromObj (Tcl_GetObjResult (interp), NULL);
        if (result == TCL_ERROR) {
            if (stderrChan != NULL) {
                Tcl_WriteChars(stderrChan, "Error in prompt hook: ", -1);
                Tcl_WriteChars(stderrChan, resultStr, -1);
                TclX_WriteNL (stderrChan);
            }
        } else {
            if (useResult && (stdoutChan != NULL))
                Tcl_WriteChars(stdoutChan, resultStr, -1);
            promptDone = TRUE;
        }
    } 

    if (stdoutChan != NULL) {
        if (!promptDone)
            Tcl_Write (stdoutChan, topLevel ? "%" : ">", 1);
        Tcl_Flush (stdoutChan);
    }
    Tcl_ResetResult (interp);
}

/*-----------------------------------------------------------------------------
 * AsyncSignalErrorHandler --
 *   Handler for signals that generate errors.   If no code is currently
 * executing (i.e, it the event loop), we want the input buffer to be
 * cleared on SIGINT.
 *
 * Parameters:
 *   o interp (I) - The interpreter used to process the signal.  The error
 *     message is in the result.
 *   o clientData (I) - Pointer to the asyncLoopData structure.
 *   o background (I) - TRUE if signal was handled in the background (i.e
 *     the event loop) rather than in an interp.
 * Returns:
 *  The Tcl result code to continue with.   TCL_OK if we have handled the
 * signal, TCL_ERROR if not.
 *-----------------------------------------------------------------------------
 */
static int
AsyncSignalErrorHandler (interp, clientData, background, signalNum)
    Tcl_Interp *interp;
    ClientData  clientData;
    int         background;
    int         signalNum;
{
    if (background & (signalNum == SIGINT)) {
        asyncLoopData_t *dataPtr = (asyncLoopData_t *) clientData;
        Tcl_Channel stdoutChan = Tcl_GetStdChannel (TCL_STDOUT);

        Tcl_DStringFree (&dataPtr->command);
        dataPtr->partial = FALSE;

        Tcl_ResetResult (interp);
        
        if (dataPtr->options & TCLX_CMDL_INTERACTIVE) {
            if (stdoutChan != NULL)
                TclX_WriteNL (stdoutChan);
            OutputPrompt (dataPtr->interp, !dataPtr->partial,
                          dataPtr->prompt1, dataPtr->prompt2);
        }
        return TCL_OK;
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * AsyncCommandHandler --
 *   Handler for async command reading. This procedure is invoked by the event
 * dispatcher whenever the input becomes readable.  It grabs the next line of
 * input characters, adds them to a command being assembled, and executes the
 * command if it's complete.
 *
 * Parameters:
 *   o clientData (I) - Pointer to the asyncLoopData structure.
 *   o mask (I) - Not used.
 *-----------------------------------------------------------------------------
 */
static void
AsyncCommandHandler (clientData, mask)
    ClientData clientData;
    int        mask;
{
    asyncLoopData_t *dataPtr = (asyncLoopData_t *) clientData;
    int code;
    char *cmd, *resultStr;

    /*
     * Make sure that we are the current signal error handler.  This
     * handles recusive event loop calls.
     */
    TclX_SetAppSignalErrorHandler (AsyncSignalErrorHandler, clientData);

    if (Tcl_Gets (dataPtr->channel, &dataPtr->command) < 0) {
        /*
         * Handler EINTR error special.
         */
        if (!(Tcl_Eof (dataPtr->channel) ||
              Tcl_InputBlocked (dataPtr->channel)) &&
            (Tcl_GetErrno () == EINTR)) {
            if (Tcl_AsyncReady ()) {
                Tcl_AsyncInvoke (NULL, TCL_OK); 
            }
            return;  /* Let the event loop call us again. */
        }

        /*
         * Handle EOF or error.
         */
        if (dataPtr->options & TCLX_CMDL_EXIT_ON_EOF) {
            Tcl_Exit (0);
        } else {
            AsyncCommandHandlerDelete (clientData);
        }
        return;
    }
 
   cmd = Tcl_DStringAppend (&dataPtr->command, "\n", -1);
    
    if (!Tcl_CommandComplete (cmd)) {
        dataPtr->partial = TRUE;
        goto prompt;
    }
    dataPtr->partial = FALSE;

    /*
     * Disable the stdin channel handler while evaluating the command;
     * otherwise if the command re-enters the event loop we might process
     * commands from stdin before the current command is finished.  Among
     * other things, this will trash the text of the command being evaluated.
     */

    Tcl_CreateChannelHandler (dataPtr->channel, 0,
                              AsyncCommandHandler, clientData);
    code = Tcl_RecordAndEval (dataPtr->interp, cmd, TCL_EVAL_GLOBAL);
    Tcl_CreateChannelHandler (dataPtr->channel, TCL_READABLE,
                              AsyncCommandHandler, clientData);

    resultStr = Tcl_GetStringFromObj (Tcl_GetObjResult (dataPtr->interp),
                                      NULL);
    if (resultStr [0] != '\0') {
        if (dataPtr->options & TCLX_CMDL_INTERACTIVE) {
            TclX_PrintResult (dataPtr->interp, code, cmd);
        }
    }
    Tcl_DStringFree (&dataPtr->command);

    /*
     * Output a prompt.
     */
  prompt:
    if (dataPtr->options & TCLX_CMDL_INTERACTIVE) {
        OutputPrompt (dataPtr->interp, !dataPtr->partial,
                      dataPtr->prompt1, dataPtr->prompt2);
    }
    Tcl_ResetResult (dataPtr->interp);
}

/*-----------------------------------------------------------------------------
 * AsyncCommandHandlerDelete --
 *   Delete an async command handler.
 *
 * Parameters:
 *   o clientData (I) - Pointer to the asyncLoopData structure for the
 *     handler being deleted.
 *-----------------------------------------------------------------------------
 */
static void
AsyncCommandHandlerDelete (clientData)
    ClientData clientData;
{
    asyncLoopData_t *dataPtr = (asyncLoopData_t *) clientData;

    /*
     * Remove handlers from system.
     */
    Tcl_DeleteChannelHandler (dataPtr->channel, AsyncCommandHandler, 
                              clientData);
    Tcl_DeleteCloseHandler (dataPtr->channel, AsyncCommandHandlerDelete,
                            clientData);
    TclX_SetAppSignalErrorHandler (NULL, NULL);
    
    /*
     * If there is an end command, eval it.
     */
    if (dataPtr->endCommand != NULL) {
        if (Tcl_GlobalEval (dataPtr->interp, dataPtr->endCommand) != TCL_OK)
            Tcl_BackgroundError (dataPtr->interp);
        Tcl_ResetResult (dataPtr->interp);
    }

    /*
     * Free resources.
     */          
    Tcl_DStringFree (&dataPtr->command);
    if (dataPtr->endCommand != NULL)
        ckfree (dataPtr->endCommand);
    if (dataPtr->prompt1 != NULL)
        ckfree (dataPtr->prompt1);
    if (dataPtr->prompt2 != NULL)
        ckfree (dataPtr->prompt2);
    ckfree ((char *) dataPtr);
}

/*-----------------------------------------------------------------------------
 * TclX_AsyncCommandLoop --
 *   Establish an async command handler on stdin.
 *
 * Parameters:
 *   o interp (I) - A pointer to the interpreter
 *   o options (I) - Async command loop options:
 *     o TCLX_CMDL_INTERACTIVE - Print a prompt and the result of command
 *       execution.
 *     o TCLX_CMDL_EXIT_ON_EOF - Exit when an EOF is encountered.
 *   o endCommand (I) - If not NULL, a command to evaluate when the command
 *     handler is removed, either by closing the channel or hitting EOF.
 *   o prompt1 (I) - If not NULL, the command to evalute get the main prompt.
 *     If NULL, the current value of tcl_prompt1 is evaluted to output the
 *     main prompt.  NOTE: prompt1 returns a result while tcl_prompt1
 *     outputs a result.
 *   o prompt2 (I) - If not NULL, the command to evalute get the secondary
 *     prompt.  If NULL, the current value of tcl_prompt is evaluted to
 *     output the secondary prompt.  NOTE: prompt2 returns a result while
 *     tcl_prompt2 outputs a result.
 * Returns:
 *   TCL_OK or TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
int
TclX_AsyncCommandLoop (interp, options, endCommand, prompt1, prompt2)
    Tcl_Interp *interp;
    int         options;
    char       *endCommand;
    char       *prompt1;
    char       *prompt2;
{
    Tcl_Channel stdinChan;
    asyncLoopData_t *dataPtr;

    stdinChan = TclX_GetOpenChannel (interp, "stdin", TCL_READABLE);
    if (stdinChan == NULL)
        return TCL_ERROR;

    dataPtr = (asyncLoopData_t *) ckalloc (sizeof (asyncLoopData_t));
    
    dataPtr->interp = interp;
    dataPtr->channel = stdinChan;
    dataPtr->options = options;
    Tcl_DStringInit (&dataPtr->command);
    dataPtr->partial = FALSE;
    if (endCommand == NULL)
        dataPtr->endCommand = NULL;
    else
        dataPtr->endCommand = ckstrdup (endCommand);
    if (prompt1 == NULL)
        dataPtr->prompt1 = NULL;
    else
        dataPtr->prompt1 = ckstrdup (prompt1);
    if (prompt2 == NULL)
        dataPtr->prompt2 = NULL;
    else
        dataPtr->prompt2 = ckstrdup (prompt2);

    Tcl_DeleteCloseHandler (stdinChan, AsyncCommandHandlerDelete,
                            (ClientData) dataPtr);
    Tcl_CreateChannelHandler (stdinChan, TCL_READABLE,
                              AsyncCommandHandler, (ClientData) dataPtr);
    TclX_SetAppSignalErrorHandler (AsyncSignalErrorHandler,
                                   (ClientData) dataPtr);

    /*
     * Output initial prompt.
     */
    if (dataPtr->options & TCLX_CMDL_INTERACTIVE) {
        OutputPrompt (dataPtr->interp, !dataPtr->partial,
                      dataPtr->prompt1, dataPtr->prompt2);
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * SyncSignalErrorHandler --
 *   Handler for signals that generate errors.  We want to clear the input
 * buffer on SIGINT.
 *
 * Parameters:
 *   o interp (I) - The interpreter used to process the signal.  The error
 *     message is in the result.
 *   o clientData (I) - Pointer to a int to set to TRUE if SIGINT occurs.
 *   o background (I) - Ignored.
 * Returns:
 *  The Tcl result code to continue with.   TCL_OK if we have handled the
 * signal, TCL_ERROR if not.
 *-----------------------------------------------------------------------------
 */
static int
SyncSignalErrorHandler (interp, clientData, background, signalNum)
    Tcl_Interp *interp;
    ClientData  clientData;
    int         background;
    int         signalNum;
{
    if (signalNum == SIGINT) {
        *((int *) clientData) = TRUE;
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_CommandLoop --
 *   Run a syncronous Tcl command loop.  EOF terminates the loop.
 *
 * Parameters:
 *   o interp (I) - A pointer to the interpreter
 *   o options (I) - Command loop options:
 *     o TCLX_CMDL_INTERACTIVE - Print a prompt and the result of command
 *       execution.
 *   o prompt1 (I) - If not NULL, the command to evalute get the main prompt.
 *     If NULL, the current value of tcl_prompt1 is evaluted to output the
 *     main prompt.  NOTE: prompt1 returns a result while tcl_prompt1
 *     outputs a result.
 *   o prompt2 (I) - If not NULL, the command to evalute get the secondary
 *     prompt.  If NULL, the current value of tcl_prompt is evaluted to
 *     output the secondary prompt.  NOTE: prompt2 returns a result while
 *     tcl_prompt2 outputs a result.
 * Returns:
 *   TCL_OK or TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
int
TclX_CommandLoop (interp, options, endCommand, prompt1, prompt2)
    Tcl_Interp *interp;
    int         options;
    char       *endCommand;
    char       *prompt1;
    char       *prompt2;
{
    Tcl_DString command;
    int result, partial = FALSE, gotSigIntError = FALSE,
      gotInterrupted = FALSE;
    Tcl_Channel stdinChan, stdoutChan;

    Tcl_DStringInit (&command);

    while (TRUE) {
        /*
         * Always set signal error handler so recursive command loops work.
         */
        TclX_SetAppSignalErrorHandler (SyncSignalErrorHandler,
                                       &gotSigIntError);

        /*
         * If a signal handlers are pending, process them.
         */
        if (Tcl_AsyncReady ()) {
            result = Tcl_AsyncInvoke (interp, TCL_OK); 
            if ((result != TCL_OK) && !gotSigIntError)
                TclX_PrintResult (interp, result, NULL);
        }

        /*
         * Drop any pending command if SIGINT occured since the last time we
         * were through here, event if its already been processed.
         */
        if (gotSigIntError) {
            Tcl_DStringFree (&command);
            partial = FALSE;
            stdoutChan = Tcl_GetStdChannel (TCL_STDOUT);
            if (stdoutChan != NULL)
                TclX_WriteNL (stdoutChan);
        }

        /*
         * Output a prompt and input a command.
         */
        stdinChan = Tcl_GetStdChannel (TCL_STDIN);
        if (stdinChan == NULL)
            goto endOfFile;

        /*
         * Only ouput prompt if we didn't get interrupted or if the
         * interruption was SIGINT
         */
        if ((options & TCLX_CMDL_INTERACTIVE) &&
            (!gotInterrupted || gotSigIntError)) {
            OutputPrompt (interp, !partial, prompt1, prompt2);
        }

        /*
         * Reset these flags for the next round
         */
        gotSigIntError = FALSE;
        gotInterrupted = FALSE; 

        result = Tcl_Gets (stdinChan, &command);
        if (result < 0) {
            if (Tcl_Eof (stdinChan) || Tcl_InputBlocked (stdinChan))
                goto endOfFile;
            if (Tcl_GetErrno () == EINTR) {
                gotInterrupted = TRUE; 
                continue;  /* Process signals above */
            }
            TclX_AppendObjResult (interp, "command input error on stdin: ",
                                  Tcl_PosixError (interp), (char *) NULL);
            return TCL_ERROR;
        }

        /*
         * Newline was stripped by Tcl_DStringGets, but is needed for
         * command-complete checking, add it back in.  If the command is
         * not complete, get the next line.
         */
        Tcl_DStringAppend (&command, "\n", 1);

        if (!Tcl_CommandComplete (command.string)) {
            partial = TRUE;
            continue;  /* Next line */
        }

        /*
         * Finally have a complete command, go eval it and maybe output the
         * result.
         */
        result = Tcl_RecordAndEval (interp, command.string, 0);

        if ((options & TCLX_CMDL_INTERACTIVE) || (result != TCL_OK))
            TclX_PrintResult (interp, result, command.string);

        partial = FALSE;
        Tcl_DStringFree (&command);
    }
  endOfFile:
    Tcl_DStringFree (&command);
    if (endCommand != NULL) {
        if (Tcl_Eval (interp, endCommand) == TCL_ERROR) {
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_CommandloopObjCmd --
 *    Implements the commandloop command:
 *       commandloop -async -interactive on|off|tty -prompt1 cmd
 *                   -prompt2 cmd -endcommand cmd
 * Results:
 *   Standard TCL results.
 *-----------------------------------------------------------------------------
 */
static int
TclX_CommandloopObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    int options = 0, async = FALSE, argIdx, interactive;
    char *argStr,  *endCommand = NULL;
    char *prompt1 = NULL, *prompt2 = NULL;

    interactive = isatty (0);
    for (argIdx = 1; argIdx < objc; argIdx++) {
        argStr = Tcl_GetStringFromObj (objv [argIdx], NULL);
        if (argStr [0] != '-')
            break;
        if (STREQU (argStr, "-async")) {
            async = TRUE;
        } else if (STREQU (argStr, "-prompt1")) {
            if (argIdx == objc - 1)
                goto argRequired;
            prompt1 = Tcl_GetStringFromObj (objv [++argIdx], NULL);;
        } else if (STREQU (argStr, "-prompt2")) {
            if (argIdx == objc - 1)
                goto argRequired;
            prompt2 = Tcl_GetStringFromObj (objv [++argIdx], NULL);
        } else if (STREQU (argStr, "-interactive")) {
            if (argIdx == objc - 1)
                goto argRequired;
            argIdx++;
            argStr = Tcl_GetStringFromObj (objv [argIdx], NULL);
            if (STREQU (argStr, "tty")) {
                interactive = TRUE;
            } else {
                if (Tcl_GetBooleanFromObj (interp, objv [argIdx],
                                           &interactive) != TCL_OK)
                    return TCL_ERROR;
            }
        } else if (STREQU (argStr, "-endcommand")) {
            if (argIdx == objc - 1)
                goto argRequired;
            endCommand = Tcl_GetStringFromObj (objv [++argIdx], NULL);
        } else {
            goto unknownOption;
        }
    }
    if (argIdx != objc)
        goto wrongArgs;

    if (interactive)
        options |= TCLX_CMDL_INTERACTIVE;

    if (async) {
        return TclX_AsyncCommandLoop (interp,
                                      options,
                                      endCommand,
                                      prompt1,
                                      prompt2);
    } else {
        return TclX_CommandLoop (interp,
                                 options,
                                 endCommand,
                                 prompt1,
                                 prompt2);
    }


    /*
     * Argument error message generation.  argStr should contain the
     * option being processed.
     */
  argRequired:
    TclX_AppendObjResult (interp, "argument required for ", argStr,
                          " option", (char *) NULL);
    return TCL_ERROR;

  unknownOption:
    TclX_AppendObjResult (interp, "unknown option \"", argStr,
                          "\", expected one of \"-async\", ",
                          "\"-interactive\", \"-prompt1\", \"-prompt2\", ",
                          " or \"-endcommand\"", (char *) NULL);
    return TCL_ERROR;
    
  wrongArgs:
    TclX_WrongArgs (interp, objv [0],
                    "?-async? ?-interactive on|off|tty? ?-prompt1 cmd? ?-prompt2 cmd? ?-endcommand cmd?");
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_CmdloopInit --
 *     Initialize the coommandloop command.
 *-----------------------------------------------------------------------------
 */
void
TclX_CmdloopInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
                          "commandloop",
                          TclX_CommandloopObjCmd, 
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
    
}


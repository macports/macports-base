/*
 * tclXdup.c
 *
 * Extended Tcl dup command.
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
 * $Id: tclXdup.c,v 1.3 2005/04/26 20:01:33 hobbs Exp $
 *-----------------------------------------------------------------------------
 */
#include "tclExtdInt.h"

/*
 * Prototypes of internal functions.
 */
static int
DupChannelOptions _ANSI_ARGS_((Tcl_Interp  *interp,
                               Tcl_Channel  srcChannel,
                               Tcl_Channel  targetChannel));

static Tcl_Channel
DupFileChannel _ANSI_ARGS_((Tcl_Interp *interp,
                            char       *srcFileId,
                            char       *targetFileId));

static int
TclX_DupObjCmd _ANSI_ARGS_((ClientData   clientData,
                            Tcl_Interp  *interp,
                            int          objc,
                            Tcl_Obj     *CONST objv[]));


/*-----------------------------------------------------------------------------
 * DupChannelOptions --
 *
 *   Set the channel options of one channel to those of another.
 *
 * Parameters:
 *   o interp (I) - Errors returned in result.
 *   o srcChannel (I) - Channel to get the options.
 *   o targetChannel (I) - Channel to set the options on.
 * Result:
 *   TCL_OK or TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
static int
DupChannelOptions (interp, srcChannel, targetChannel)
    Tcl_Interp  *interp;
    Tcl_Channel  srcChannel;
    Tcl_Channel  targetChannel;
{
    Tcl_DString strValues;
    CONST84 char *option, *value, **optArgv = NULL;
    int optArgc, idx;

    Tcl_DStringInit (&strValues);

    if (Tcl_GetChannelOption (interp, srcChannel, NULL, &strValues) != TCL_OK) {
        goto errorExit;
    }

    /*
     * Split the list for each name/value pair and set the new channel.
     * Only modify blocking if its not the default, as setting blocking on
     * standard files generates an error on some systems.  Skip options
     * that can't be set.
     */
    if (Tcl_SplitList(interp, strValues.string, &optArgc, &optArgv) != TCL_OK) {
        goto errorExit;
    }
    if ((optArgc % 2) != 0) {
        Tcl_Panic("channel didn't return keyword/value pairs");
    }

    for (idx = 0; idx < optArgc; idx += 2) {
        option = optArgv[idx];
        value = optArgv[idx+1];
        if (STREQU (option, "-blocking") && (value [0] != '0')) {
            continue;
        }
        if (STREQU (option, "-peername") || STREQU (option, "-sockname")) {
            continue;
        }
        if (Tcl_SetChannelOption (interp, targetChannel, option,
                                  value) != TCL_OK) {
            goto errorExit;
        }
    }

    Tcl_DStringFree (&strValues);
    if (optArgv != NULL) {
        ckfree((char *)optArgv);
    }
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&strValues);
    if (optArgv != NULL) {
        ckfree((char *)optArgv);
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * DupFileChannel --
 *   Do common work for all platforms for duplicate a channel
 *
 * Parameters:
 *   o interp (I) - If an error occures, the error message is in result.
 *   o srcChannelId (I) - The id of the channel to dup.
 *   o targetChannelId (I) - The id for the new file.  NULL if any id maybe
 *     used.
 * Returns:
 *   The unregistered channel, or NULL if an error occurs.
 *-----------------------------------------------------------------------------
 */
static Tcl_Channel
DupFileChannel (interp, srcChannelId, targetChannelId)
    Tcl_Interp *interp;
    char       *srcChannelId;
    char       *targetChannelId;
{
    Tcl_Channel srcChannel, newChannel = NULL;
    Tcl_ChannelType *channelType;
    int mode;

    srcChannel = Tcl_GetChannel (interp, srcChannelId, &mode);
    if (srcChannel == NULL) {
        return NULL;
    }
    channelType = Tcl_GetChannelType (srcChannel);
    if (STREQU (channelType->typeName, "pipe")) {
        TclX_AppendObjResult (interp, "can not \"dup\" a Tcl command ",
                              "pipeline created with the \"open\" command",
                              (char *) NULL);
        return NULL;
    }
    
    /*
     * If writable, flush out the buffer.
     */
    if (mode & TCL_WRITABLE) {
        if (Tcl_Flush (srcChannel) == TCL_ERROR)
            goto posixError;
    }

    /*
     * Use OS dependent function to actually dup the channel.
     */
    newChannel = TclXOSDupChannel (interp, srcChannel, mode, targetChannelId);
    if (newChannel == NULL)
        return NULL;

    /*
     * If the channel is open for reading and seekable, seek the new channel
     * to the same position. Tcl_Tell returns -1 if seek is not supported.
     */
    if (mode & TCL_READABLE) {
	int seekOffset = (int) Tcl_Tell (srcChannel);
	if (seekOffset >= 0) {
            if (Tcl_Seek (newChannel, seekOffset, SEEK_SET) < 0)
                goto posixError;
        }
    }
    
    if (DupChannelOptions (interp, srcChannel, newChannel) != TCL_OK)
        goto errorExit;

    return newChannel;

  posixError:
    Tcl_ResetResult (interp);
    TclX_AppendObjResult (interp, "dup of \"", srcChannelId, "\" failed: ",
                          Tcl_PosixError (interp), (char *) NULL);

  errorExit:
    if (newChannel != NULL) {
        Tcl_Close (NULL, newChannel);
    }
    return NULL;
}

/*-----------------------------------------------------------------------------
 * TclX_DupObjCmd --
 *    Implements the dup TCL command:
 *        dup channelId ?targetChannelId?
 *-----------------------------------------------------------------------------
 */
static int
TclX_DupObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    Tcl_Channel newChannel;
    int bindFnum, fnum;
    char *srcChannelId, *targetChannelId;

    if ((objc < 2) || (objc > 3)) {
        return TclX_WrongArgs (interp, objv [0],
                               "channelId ?targetChannelId?");
    }

    /*
     * If a number is supplied, bind it to a file handle rather than doing
     * a dup.
     */
    if (objv [1]->typePtr == Tcl_GetObjType ("int")) {
        bindFnum = TRUE;
    } else {
        srcChannelId = Tcl_GetStringFromObj (objv [1], NULL);
        if (ISDIGIT (srcChannelId [0])) {
            if (Tcl_ConvertToType (interp, objv [1],
                                   Tcl_GetObjType ("int")) != TCL_OK)
                goto badFnum;
            bindFnum = TRUE;
        } else {
            bindFnum = FALSE;
        }
    }
    if (bindFnum) {
        if (objc != 2)
            goto bind2ndArg;
        if (Tcl_GetIntFromObj (interp, objv [1], &fnum) != TCL_OK)
            return TCL_ERROR;
        newChannel = TclXOSBindOpenFile (interp,  fnum);
    } else {
        if (objc > 2) {
            targetChannelId = Tcl_GetStringFromObj (objv [2], NULL);
        } else {
            targetChannelId = NULL;
        }
        newChannel = DupFileChannel (interp,
                                     srcChannelId,
                                     targetChannelId);
    }
    if (newChannel == NULL)
        return TCL_ERROR;

    Tcl_RegisterChannel (interp, newChannel);
    Tcl_SetStringObj (Tcl_GetObjResult (interp),
                      Tcl_GetChannelName (newChannel), -1);
    return TCL_OK;

  badFnum:
    Tcl_ResetResult (interp);
    TclX_AppendObjResult (interp, "invalid integer file number \"",
                          Tcl_GetStringFromObj (objv [1], NULL),
                          "\", expected unsigned integer or Tcl file id",
                          (char *) NULL);
    return TCL_ERROR;

  bind2ndArg:
    TclX_AppendObjResult (interp, "the second argument, targetChannelId, ",
                          "is not allow when binding a file number to ",
                          "a Tcl channel", (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_DupInit --
 *   Initialize the dip command in an interpreter.
 *
 * Parameters:
 *   o interp - Interpreter to add commandsto.
 *-----------------------------------------------------------------------------
 */
void
TclX_DupInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
			  "dup",
			  TclX_DupObjCmd, 
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}



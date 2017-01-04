/*
 * tclXwinDup.c
 *
 * Support for the dup command on Windows.
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
 * $Id: tclXwinDup.c,v 1.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"


/*-----------------------------------------------------------------------------
 * ConvertChannelName --
 *
 *   Convert a requested channel name to one of the standard channel ids.
 * 
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channelName - Desired channel, one of "stdin", "stdout" or "stderr".
 *   o handleIdPtr - One of STD_{INPUT|OUTPUT|ERROR}_HANDLE is returned.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 * FIX: Make Unix version parallel this one.
 *-----------------------------------------------------------------------------
 */
static int
ConvertChannelName (Tcl_Interp *interp,
                    char       *channelName,
                    DWORD      *handleIdPtr)
{
    if (channelName [0] == 's') {
        if (STREQU (channelName, "stdin"))
            *handleIdPtr = STD_INPUT_HANDLE;
        else if (STREQU (channelName, "stdout"))
            *handleIdPtr = STD_OUTPUT_HANDLE;
        else if (STREQU (channelName, "stderr"))
            *handleIdPtr = STD_ERROR_HANDLE;
    } else if (STRNEQU (channelName, "file", 4) ||
               STRNEQU (channelName, "sock", 4)) {
        TclX_AppendObjResult (interp, "on MS Windows, only stdin, ",
                              "stdout or stderr maybe the dup target",
                              (char *) NULL);
        return TCL_ERROR;
    } else {
        TclX_AppendObjResult (interp, "invalid channel id: ",
                              channelName, (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSDupChannel --
 *   OS dependent duplication of a channel.
 *
 * Parameters:
 *   o interp (I) - If an error occures, the error message is in result.
 *   o srcChannel (I) - The channel to dup.
 *   o mode (I) - The channel mode.
 *   o targetChannelId (I) - The id for the new file.  NULL if any id maybe
 *     used.
 * Returns:
 *   The unregistered new channel, or NULL if an error occured.
 *-----------------------------------------------------------------------------
 */
Tcl_Channel
TclXOSDupChannel (interp, srcChannel, mode, targetChannelId)
    Tcl_Interp *interp;
    Tcl_Channel srcChannel;
    int         mode;
    char       *targetChannelId;
{
    Tcl_Channel newChannel = NULL;
    int direction;
    int result;
    HANDLE srcFileHand, newFileHand = INVALID_HANDLE_VALUE;
    int sockType;
    int sockTypeLen = sizeof(sockType);

    /*
     * On Windows, the channels we can dup share the same file for the read and
     * write directions, so use either.
     */
    if (mode & TCL_READABLE) {
	direction = TCL_READABLE;
    } else {
	direction = TCL_WRITABLE;
    }

    result = (Tcl_GetChannelHandle (srcChannel, direction,
				    (ClientData *) &srcFileHand));
    if (result != TCL_OK) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (srcChannel),
                              "\" has no device handle", (char *) NULL);
	return NULL;
    }

    switch (GetFileType (srcFileHand))
    {
    case FILE_TYPE_PIPE:
	if (getsockopt((SOCKET)srcFileHand, SOL_SOCKET, SO_TYPE,
		       (void *)&sockType, &sockTypeLen) == 0) {
	    TclXNotAvailableError (interp, "duping a socket");
	    return NULL;
	}
	break;

    default:
	break;
    }

    /*
     * Duplicate the channel's file.
     */
    if (!DuplicateHandle (GetCurrentProcess (),
                          srcFileHand,
                          GetCurrentProcess (),
                          &newFileHand,
                          0, FALSE,
                          DUPLICATE_SAME_ACCESS)) {
	TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "dup failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }

    /*
     * If a standard target channel is specified, close the target if its open
     * and make the new channel one of the std channels.
     */
    if (targetChannelId != NULL) {
        Tcl_Channel oldChannel;
        DWORD stdHandleId;

        if (ConvertChannelName (interp, targetChannelId,
                                &stdHandleId) != TCL_OK)
            goto errorExit;

        oldChannel = Tcl_GetChannel (interp, targetChannelId, NULL);
        if (oldChannel != NULL) {
            Tcl_UnregisterChannel (interp, oldChannel);
        }
        SetStdHandle (stdHandleId, newFileHand);
     }
    
    newChannel = Tcl_MakeFileChannel ((ClientData) newFileHand, mode);
    return newChannel;

  errorExit:
    if (newFileHand != INVALID_HANDLE_VALUE)
        CloseHandle (newFileHand);
    return NULL;
}

/*-----------------------------------------------------------------------------
 * TclXOSBindOpenFile --
 *   Bind a open file number of a channel.
 *
 * Parameters:
 *   o interp (I) - If an error occures, the error message is in result.
 *   o fileNum (I) - The file number of the open file.
 * Returns:
 *   The unregistered channel or NULL if an error occurs.
 *-----------------------------------------------------------------------------
 */
Tcl_Channel
TclXOSBindOpenFile (interp, fileNum)
    Tcl_Interp *interp;
    int         fileNum;
{
    HANDLE fileHandle;
    int mode, isSocket;
    char channelName[20];
    char fileNumStr[20];
    Tcl_Channel channel = NULL;
    int sockType;
    int sockTypeLen = sizeof(sockType);

    /*
     * Make sure file is open and determine the access mode and file type.
     * Currently, we just make sure it's open, and assume both read and write.
     * FIX: find an API under Windows that returns the read/write info.
     */
    fileHandle = (HANDLE) fileNum;
    switch (GetFileType (fileHandle))
    {
    case FILE_TYPE_UNKNOWN:
        TclWinConvertError (GetLastError ());
        goto posixError;
    case FILE_TYPE_PIPE:
	isSocket = getsockopt((SOCKET)fileHandle, SOL_SOCKET, SO_TYPE,
			       (void *)&sockType, &sockTypeLen) == 0;
   	break;
    default:
	isSocket = 0;
	break;
    }

    mode = TCL_READABLE | TCL_WRITABLE;

    sprintf (fileNumStr, "%d", fileNum);

    if (isSocket)
        sprintf (channelName, "sock%s", fileNumStr);
    else
        sprintf (channelName, "file%s", fileNumStr);

    if (Tcl_GetChannel (interp, channelName, NULL) != NULL) {
        Tcl_ResetResult (interp);
        TclX_AppendObjResult (interp, "file number \"", fileNumStr,
                              "\" is already bound to a Tcl channel",
                              (char *) NULL);
        return NULL;
    }
    Tcl_ResetResult (interp);

    if (isSocket) {
        channel = Tcl_MakeTcpClientChannel ((ClientData) fileNum);
    } else {
        channel = Tcl_MakeFileChannel ((ClientData) fileNum, mode);
    }
    Tcl_RegisterChannel (interp, channel);

    return channel;

  posixError:
    TclX_AppendObjResult (interp, "binding open file ", fileNumStr,
                          " to Tcl channel failed: ", Tcl_PosixError (interp),
                          (char *) NULL);

    if (channel != NULL) {
        Tcl_UnregisterChannel (interp, channel);
    }
    return NULL;
}



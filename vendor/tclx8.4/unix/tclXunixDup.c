/*
 * tclXunixDup.c
 *
 * Support for the dup command on Unix.
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
 * $Id: tclXunixDup.c,v 8.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Prototypes of internal functions.
 */
static int
ConvertFileHandle _ANSI_ARGS_((Tcl_Interp *interp,
                               char       *handle));

/*-----------------------------------------------------------------------------
 * ConvertFileHandle --
 *
 * Convert a file handle to its file number. The file handle maybe one 
 * of "stdin", "stdout" or "stderr" or "fileNNN", were NNN is the file
 * number.  If the handle is invalid, -1 is returned and a error message
 * will be returned in result.  This is used when the file may
 * not be currently open.
 *
 *-----------------------------------------------------------------------------
 */
static int
ConvertFileHandle (interp, handle)
    Tcl_Interp *interp;
    char       *handle;
{
    int fileId = -1;

    if (handle [0] == 's') {
        if (STREQU (handle, "stdin"))
            fileId = 0;
        else if (STREQU (handle, "stdout"))
            fileId = 1;
        else if (STREQU (handle, "stderr"))
            fileId = 2;
    } else {
       if (STRNEQU (handle, "file", 4))
           TclX_StrToInt (&handle [4], 10, &fileId);
       if (STRNEQU (handle, "sock", 4))
           TclX_StrToInt (&handle [4], 10, &fileId);
    }
    if (fileId < 0)
        TclX_AppendObjResult (interp, "invalid channel id: ", handle,
                              (char *) NULL);
    return fileId;
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
    ClientData handle;
    Tcl_ChannelType *channelType;
    Tcl_Channel newChannel = NULL;
    int srcFileNum, newFileNum = -1;

    /*
     * On Unix, the channels we can dup share the same file for the read and
     * write directions, so use either.  Duping of pipelines can't work.
     */
    if (mode & TCL_READABLE) {
        Tcl_GetChannelHandle (srcChannel, TCL_READABLE, &handle);
    } else {
        Tcl_GetChannelHandle (srcChannel, TCL_WRITABLE, &handle);
    }
    srcFileNum = (int) handle;
    channelType = Tcl_GetChannelType (srcChannel);

    /*
     * If a target id is specified, close that channel if its open.  Dup
     * the file.
     */
    if (targetChannelId != NULL) {
        Tcl_Channel oldChannel;
        int chkFileNum;

        newFileNum = ConvertFileHandle (interp, targetChannelId);
        if (newFileNum < 0)
            return NULL;

        oldChannel = Tcl_GetChannel (interp, targetChannelId, NULL);
        if (oldChannel != NULL) {
            Tcl_UnregisterChannel (interp, oldChannel);
        }

        chkFileNum = dup2 (srcFileNum, newFileNum);
        if (chkFileNum < 0)
            goto posixError;
        if (chkFileNum != newFileNum) {
            TclX_AppendObjResult (interp, "dup: desired file number not ",
                                  "returned", (char *) NULL);
            close (newFileNum);
            return NULL;
        }
    } else {
        newFileNum = dup (srcFileNum);
        if (newFileNum < 0)
            goto posixError;
    }
    
    if (STREQU (channelType->typeName, "tcp")) {
        newChannel = Tcl_MakeTcpClientChannel ((ClientData) newFileNum);
    } else {
        newChannel = Tcl_MakeFileChannel ((ClientData) newFileNum,
                                          mode);
    }
    return newChannel;

  posixError:
    Tcl_ResetResult (interp);
    TclX_AppendObjResult (interp, "dup of \"", Tcl_GetChannelName (srcChannel),
                          " failed: ", Tcl_PosixError (interp), (char *) NULL);
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
    int         fcntlMode;
    int         mode = 0;
    int         nonBlocking;
    int         isSocket;
    struct stat fileStat;
    char        channelName[20];
    Tcl_Channel channel = NULL;

    /*
     * Make sure file is open and determine the access mode and file type.
     */
    fcntlMode = fcntl (fileNum, F_GETFL, 0);
    if (fcntlMode == -1)
        goto posixError;

    switch (fcntlMode & O_ACCMODE) {
      case O_RDONLY:
        mode = TCL_READABLE;
        break;
      case O_WRONLY:
        mode = TCL_WRITABLE;
        break;
      case O_RDWR:
        mode = TCL_READABLE | TCL_WRITABLE;
        break;
    }
    nonBlocking = ((fcntlMode & (O_NONBLOCK | O_NDELAY)) != 0);

    if (fstat (fileNum, &fileStat) < 0)
        goto posixError;

    /*
     * If its a socket but RDONLY or WRONLY, enter it as a file.  This is
     * a pipe under BSD.
     */
    isSocket = S_ISSOCK (fileStat.st_mode) &&
        (mode == (TCL_READABLE | TCL_WRITABLE)) ;

    /*
     * FIX: some FreeBSD 2.2 SNAPs claim that a pipe is a socket, event though
     * they are not implemented as such, which causes socket operations to
     * fail is we bind it to a socket channel.  If it claims to be a socket,
     * the times will tell the difference, they are zero for sockets.
     */
#ifdef __FreeBSD__
    if (isSocket && (fileStat.st_ctime != 0))
        isSocket = FALSE;
#endif

    if (isSocket)
        sprintf (channelName, "sock%d", fileNum);
    else
        sprintf (channelName, "file%d", fileNum);

    if (Tcl_GetChannel (interp, channelName, NULL) != NULL) {
        char numBuf [32];
        Tcl_ResetResult (interp);

        sprintf (numBuf, "%d", fileNum);
        TclX_AppendObjResult (interp, "file number \"", numBuf,
                              "\" is already bound to a Tcl file ",
                              "channel", (char *) NULL);
        return NULL;
    }
    Tcl_ResetResult (interp);

    if (isSocket) {
        channel = Tcl_MakeTcpClientChannel ((ClientData) fileNum);
    } else {
        channel = Tcl_MakeFileChannel ((ClientData) fileNum,
                                       mode);
    }
    Tcl_RegisterChannel (interp, channel);

    /*
     * Set channel options.
     */
    if (nonBlocking) {
        if (TclX_SetChannelOption (interp,
                                   channel,
                                   TCLX_COPT_BLOCKING,
                                   TCLX_MODE_NONBLOCKING) == TCL_ERROR)
            goto errorExit;
    }
    if (isatty (fileNum)) {
        if (TclX_SetChannelOption (interp,
                                   channel,
                                   TCLX_COPT_BUFFERING,
                                   TCLX_BUFFERING_LINE) == TCL_ERROR)
            goto errorExit;
    }

    return channel;

  posixError:
    {
        char numBuf [32];

        Tcl_ResetResult (interp);
        sprintf (numBuf, "%d", fileNum);

        TclX_AppendObjResult (interp, "binding open file ", numBuf,
                              " to Tcl channel failed: ",
                              Tcl_PosixError (interp),
                              (char *) NULL);
    }
        
  errorExit:
    if (channel != NULL) {
        Tcl_UnregisterChannel (interp, channel);
    }
    return NULL;
}



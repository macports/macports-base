/*
 * tclXunixSock.c --
 *
 * Deprecated server creation commands, which are not supported on platforms
 * other than Unix. These commands are deprecated in favor of the Tcl socket
 * functionality, however they can't be implemented as backwards
 * compatibility procs.
 *---------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXunixSock.c,v 8.3 2004/11/23 00:13:14 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

#define SERVER_BUF      1
#define SERVER_NOBUF    2

/*
 * Prototypes of internal functions.
 */
static void
CloseForError _ANSI_ARGS_((Tcl_Interp *interp,
                           Tcl_Channel channel,
                           int         fileNum));

static int
BindFileHandles _ANSI_ARGS_((Tcl_Interp *interp,
                             unsigned    options,
                             int         socketFD));


/*-----------------------------------------------------------------------------
 * CloseForError --
 *
 *   Close a file on error.  If the file is associated with a channel, close
 * it too. The error number will be saved and not lost.
 *
 * Parameters:
 *   o interp (I) - Current interpreter.
 *   o channel (I) - Channel to close if not NULL.
 *   o fileNum (I) - File number to close if >= 0.
 *-----------------------------------------------------------------------------
 */
static void
CloseForError (interp, channel, fileNum)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         fileNum;
{
    int saveErrNo = Tcl_GetErrno ();

    /*
     * Always close fileNum, even if channel close is done, as it doesn't
     * close stdin, stdout or stderr numbers.
     */
    if (channel != NULL)
        Tcl_UnregisterChannel (interp, channel);
    if (fileNum >= 0)
        close (fileNum);
     Tcl_SetErrno (saveErrNo);
}

/*-----------------------------------------------------------------------------
 * BindFileHandles --
 *
 *   Bind the file handles for a socket to one or two Tcl file channels.
 * Binding to two handles is for compatibility with older interfaces.
 * If an error occurs, both file descriptors will be closed and cleaned up.
 *
 * Parameters:
 *   o interp (O) - File handles or error messages are return in result.
 *   o options (I) - Options set controling buffering and handle allocation:
 *       o SERVER_BUF - Two file handle buffering.
 *       o SERVER_NOBUF - No buffering.
 *   o socketFD (I) - File number of the socket that was opened.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
BindFileHandles (interp, options, socketFD)
    Tcl_Interp *interp;
    unsigned    options;
    int         socketFD;
{
    Tcl_Channel channel;

    channel = Tcl_MakeTcpClientChannel ((ClientData) socketFD);
    Tcl_RegisterChannel (interp, channel);

    if (options & SERVER_NOBUF) {
        if (TclX_SetChannelOption (interp, channel, TCLX_COPT_BUFFERING,
                                   TCLX_BUFFERING_NONE) == TCL_ERROR)
            goto errorExit;
    }

    Tcl_AppendElement (interp, Tcl_GetChannelName (channel));
    return TCL_OK;

  errorExit:
    CloseForError (interp, channel, socketFD);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_ServerCreateCmd --
 *     Implements the TCL server_create command:
 *
 *        server_create ?options?
 *
 *  Creates a socket, binds the address and port on the local machine 
 * (optionally specified by the caller), and starts the port listening 
 * for connections by calling listen (2).
 *
 *  Options may be "-myip ip_address", "-myport port_number",
 * "-myport reserved", and "-backlog backlog".
 *
 * Results:
 *   If successful, a Tcl fileid is returned.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_ServerCreateCmd (clientData, interp, argc, argv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         argc;
    char      **argv;
{
    int socketFD = -1, nextArg;
    struct sockaddr_in  local;
    int myPort, value;
    int backlog = 5;
    int getReserved = FALSE;
    Tcl_Channel channel = NULL;

    /*
     * Parse arguments.
     */
    bzero ((VOID *) &local, sizeof (local));
    local.sin_family = AF_INET;
    local.sin_addr.s_addr = INADDR_ANY;
    nextArg = 1;

    while ((nextArg < argc) && (argv [nextArg][0] == '-')) {
        if (STREQU ("-myip", argv [nextArg])) {
            if (nextArg >= argc - 1)
                goto missingArg;
            nextArg++;
            if (TclXOSInetAtoN (interp, argv [nextArg],
                                &local.sin_addr) == TCL_ERROR)
                return TCL_ERROR;
        } else if (STREQU ("-myport", argv [nextArg])) {
            if (nextArg >= argc - 1)
                goto missingArg;
            nextArg++;
            if (STREQU (argv [nextArg], "reserved")) {
                getReserved = TRUE;
            } else {
                if (Tcl_GetInt (interp, argv [nextArg], &myPort) != TCL_OK)
                    return TCL_ERROR;
                local.sin_port = htons (myPort);
            }
        } else if (STREQU ("-backlog", argv [nextArg])) {
            if (nextArg >= argc - 1)
                goto missingArg;
            nextArg++;
            if (Tcl_GetInt (interp, argv [nextArg], &backlog) != TCL_OK)
                return TCL_ERROR;
        } else if (STREQU ("-reuseaddr", argv [nextArg])) {
            /* Ignore for compatibility */
        } else {
            TclX_AppendObjResult (interp, "expected ",
                                  "\"-myip\", \"-myport\", or \"-backlog\", ",
                                  "got \"", argv [nextArg], "\"",
                                  (char *) NULL);
            return TCL_ERROR;
        }
        nextArg++;
    }

    if (nextArg != argc) {
        TclX_AppendObjResult (interp, tclXWrongArgs, argv[0],
                              " ?options?", (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Allocate a reserved port if requested.
     */
    if (getReserved) {
        int port;
        if (rresvport (&port) < 0)
            goto unixError;
        local.sin_port = port;
    }

    /*
     * Open a socket and bind an address and port to it.
     */
    socketFD = socket (local.sin_family, SOCK_STREAM, 0);
    if (socketFD < 0)
        goto unixError;

    value = 1;
    if (setsockopt (socketFD, SOL_SOCKET, SO_REUSEADDR,
                    (void*) &value, sizeof (value)) < 0) {
        goto unixError;
    }
    if (bind (socketFD, (struct sockaddr *) &local, sizeof (local)) < 0) {
        goto unixError;
    }

    if (listen (socketFD, backlog) < 0)
        goto unixError;

    channel = Tcl_MakeTcpClientChannel ((ClientData) socketFD);
    Tcl_RegisterChannel (interp, channel);

    TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), (char *) NULL);
    return TCL_OK;

    /*
     * Exit points for errors.
     */
  missingArg:
    TclX_AppendObjResult (interp, "missing argument for ", argv [nextArg],
                          (char *) NULL);
    return TCL_ERROR;

  unixError:
    TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
    CloseForError (interp, channel, socketFD);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_ServerAcceptCmd --
 *     Implements the TCL server_accept command:
 *
 *        server_accept ?options? file
 *
 *  Accepts an IP connection request to a socket created by server_create.
 *  Options maybe -buf orr -nobuf.
 *
 * Results:
 *   If successful, a Tcl fileid.
 *-----------------------------------------------------------------------------
 */
static int
TclX_ServerAcceptCmd (clientData, interp, argc, argv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         argc;
    char      **argv;
{
    Tcl_Channel          channel;
    unsigned             options;
    int                  acceptSocketFD, addrLen;
    int                  socketFD = -1;
    int                  nextArg;
    struct sockaddr_in   connectSocket;

    /*
     * Parse arguments.
     */

    nextArg = 1;
    options = SERVER_BUF;

    while ((nextArg < argc) && (argv [nextArg][0] == '-')) {
        if (STREQU ("-buf", argv [nextArg])) {
            options &= ~SERVER_NOBUF;
            options |= SERVER_BUF;
        } else if (STREQU ("-nobuf", argv [nextArg])) {
            options &= ~SERVER_BUF;
            options |= SERVER_NOBUF;
        } else {
            TclX_AppendObjResult (interp, "expected \"-buf\" or \"-nobuf\", ",
                                  "got \"", argv [nextArg], "\"",
                                  (char *) NULL);
            return TCL_ERROR;
        }
        nextArg++;
    }

    if (nextArg != argc - 1) {
        TclX_AppendObjResult (interp, tclXWrongArgs, argv[0],
                              " ?options? fileid", (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Accept a socket connection on the socket created by server_create.
     */
    bzero ((VOID *) &connectSocket, sizeof (connectSocket));

    channel = TclX_GetOpenChannel (interp, argv [nextArg], 0);
    if (channel == NULL)
        return TCL_ERROR;

    if (Tcl_GetChannelHandle (channel, 
			      TCL_READABLE, 
			      (ClientData *)&acceptSocketFD) 
	== TCL_ERROR) {
        if (Tcl_GetChannelHandle (channel, 
				  TCL_WRITABLE,
				  (ClientData *)&acceptSocketFD) 
	    == TCL_ERROR)
	        return TCL_ERROR;
    }
    if (acceptSocketFD < 0)
	return TCL_ERROR;

    addrLen = sizeof (connectSocket);
    socketFD = accept (acceptSocketFD, 
                       (struct sockaddr *)&connectSocket, 
                       &addrLen);
    if (socketFD < 0)
        goto unixError;

    /*
     * Set up channels and we are done.
     */
    return BindFileHandles (interp, options, socketFD);

    /*
     * Exit points for errors.
     */
  unixError:
    TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
    if (socketFD >= 0)
        close (socketFD);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_ServerInit --
 *     
 *   Initialize the server commands in the specified interpreter.
 *-----------------------------------------------------------------------------
 */
void
TclX_ServerInit (interp)
    Tcl_Interp *interp;
{
    /*
     * These commands are deprecated in favor of the Tcl socket -server
     * functionality, however they can't be implemented as backwards
     * compatibility procs.
     */
    Tcl_CreateCommand (interp, "server_accept", TclX_ServerAcceptCmd,
                       (ClientData) NULL, (void (*)()) NULL);
    Tcl_CreateCommand (interp, "server_create", TclX_ServerCreateCmd,
                       (ClientData) NULL, (void (*)()) NULL);
}



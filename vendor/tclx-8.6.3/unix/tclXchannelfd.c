/*
 * tclXchannelfd.c --
 *
 * OS system dependent interface for unix systems.  The idea behind these
 * functions is to provide interfaces to various functions that vary on the
 * various platforms.  These functions either implement the call in a manner
 * approriate to the platform or return an error indicating the functionality
 * is not available on that platform.  This results in code with minimal
 * number of #ifdefs.
 *-----------------------------------------------------------------------------
 * Copyright 2017 Shannon Noe
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*-----------------------------------------------------------------------------
 * ChannelToFd --
 *
 *    Convert a channel to a file descriptor.
 *
 * Parameters:
 *   o channel - Channel to get file number for.
 *   o direction - TCL_READABLE or TCL_WRITABLE, or zero.  If zero, then
 *     return the first of the read and write numbers.
 *   o type - The type of the file. not set if an error occurs.
 *
 * Returns:
 *   The unix file descriptor of the channel.
 *-----------------------------------------------------------------------------
 */
static int
ChannelToFd (Tcl_Channel 		channel,
             int         		direction)
{
	ClientData handle;
	int fd = -1;

	if (direction == 0) {
		if (Tcl_GetChannelHandle (channel, TCL_READABLE, &handle) != TCL_OK &&
		    Tcl_GetChannelHandle (channel, TCL_WRITABLE, &handle) != TCL_OK) {
			return -1;
		}
	} else {
		if (Tcl_GetChannelHandle (channel, direction, &handle) != TCL_OK) {
			return -1;
		}
	}

	memcpy(&fd, &handle, sizeof(fd));

	return fd;
}

static int
TclX_ChannelFdObjCmd (ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj*const objv[])
{
	const char          *channelName;
	Tcl_Channel	     channel;
	int                  fd;

	if (objc < 2)
		return TclX_WrongArgs (interp, objv [0], "arg ?arg...?");

	channelName = Tcl_GetStringFromObj (objv [1], NULL);

	if (channelName) {
		channel = Tcl_GetChannel (interp, channelName, NULL);
        if (channel) {
		    fd = ChannelToFd(channel, 0);

		    if (fd != -1) {
			    Tcl_SetObjResult (interp, Tcl_NewIntObj(fd));
			    return TCL_OK;
		    }
        }
	}

	Tcl_SetResult(interp, "failed to get file descriptor from channel", TCL_STATIC);
	return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_ChannelFdInit --
 *     Initialize the channelfd command.
 *-----------------------------------------------------------------------------
 */
void
TclX_ChannelFdInit (Tcl_Interp *interp)
{
	Tcl_CreateObjCommand (interp,
			"channelfd",
			TclX_ChannelFdObjCmd,
			(ClientData) NULL,
			(Tcl_CmdDeleteProc*) NULL);
}

/* vim: set ts=4 sw=4 sts=4 et : */

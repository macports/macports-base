/*
 * tclXselect.c
 *
 * Select command.  This is the generic code associated with the select system
 * call.  It relies on the Unix style select, which operates on bit sets of
 * file numbers.  Platform specific code is called to translate channels into
 * file numbers, but all operations are generic.  On Win32, this only works
 * on sockets.  Ideally, it would push more code into the platform specific
 * modules and work on more file types.  However, right now, I don't see a
 * good way to do this on Win32.
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
 * $Id: tclXselect.c,v 1.7 2005/07/27 22:31:15 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#ifndef NO_SELECT

#include "tclExtdInt.h"

/*
 * A few systems (A/UX 2.0) have select but no macros, define em in this case.
 */
#ifndef FD_SET
#   define FD_SET(fd,fdset)     (fdset)->fds_bits[0] |= (1<<(fd))
#   define FD_CLR(fd,fdset)     (fdset)->fds_bits[0] &= ~(1<<(fd))
#   define FD_ZERO(fdset)       (fdset)->fds_bits[0] = 0
#   define FD_ISSET(fd,fdset)   (((fdset)->fds_bits[0]) & (1<<(fd)))
#endif

/*
 * Data kept about a file channel.
 */
typedef struct {
    Tcl_Obj     *channelIdObj;
    Tcl_Channel  channel;
#ifdef WIN32
    /*
     * XXX Not strictly correct, according to TclX's usage of fds, but we
     * XXX expect noone to really being using select hardcore on Windows
     */
    unsigned int readFd;
    unsigned int writeFd;
#else
    int readFd;
    int writeFd;
#endif
} channelData_t;

/*
 * Prototypes of internal functions.
 */
static int
ParseSelectFileList _ANSI_ARGS_((Tcl_Interp     *interp,
                                 int             chanAccess,
                                 Tcl_Obj        *handleList,
                                 fd_set         *fileSetPtr,
                                 channelData_t **channelListPtr,
                                 int            *maxFileIdPtr));

static int
FindPendingData _ANSI_ARGS_((int            fileDescCnt,
                             channelData_t *channelList,
                             fd_set        *fileDescSetPtr));

static Tcl_Obj *
ReturnSelectedFileList _ANSI_ARGS_((fd_set        *fileDescSetPtr,
                                    int            fileDescCnt,
                                    channelData_t *channelListPtr));

static int 
TclX_SelectObjCmd _ANSI_ARGS_((ClientData clientData, 
                               Tcl_Interp *interp,
                               int objc,
                               Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * ParseSelectFileList --
 *
 *   Parse a list of file handles for select.
 *
 * Parameters:
 *   o interp - Error messages are returned in the result.
 *   o chanAccess - TCL_READABLE for read direction, TCL_WRITABLE for write
 *     direction or both for both files.
 *   o handleList (I) - The list of file handles to parse, may be empty.
 *   o fileSetPtr - The select fd_set for the parsed handles is
 *     filled in.
 *   o channelListPtr - A pointer to a dynamically allocated list of
 *     the channels that are in the set.  If the list is empty, NULL is
 *     returned.
 *   o maxFileIdPtr (I/O) - If a file id greater than the current value is
 *     encountered, it will be set to that file id.
 * Returns:
 *   The number of files in the list, or -1 if an error occured.
 * FIX: Should really pass in access and only get channels that are 
 * requested.
 *-----------------------------------------------------------------------------
 */
static int
ParseSelectFileList (interp, chanAccess, handleList, fileSetPtr,
                     channelListPtr, maxFileIdPtr)
    Tcl_Interp    *interp;
    int            chanAccess;
    Tcl_Obj       *handleList;
    fd_set        *fileSetPtr;
    channelData_t **channelListPtr;
    int           *maxFileIdPtr;
{
    int handleCnt, idx;
    Tcl_Obj **handleObjv;
    channelData_t *channelList;

    /*
     * Optimize empty list handling.
     */
    if (TclX_IsNullObj (handleList)) {
        *channelListPtr = NULL;
        return 0;
    }

    if (Tcl_ListObjGetElements (interp, handleList, &handleCnt,
                                &handleObjv) != TCL_OK) {
        return -1;
    }

    /*
     * Handle case of an empty list.
     */
    if (handleCnt == 0) {
        *channelListPtr = NULL;
        return 0;
    }

    channelList =
        (channelData_t*) ckalloc (sizeof (channelData_t) * handleCnt);

    for (idx = 0; idx < handleCnt; idx++) {
        channelList [idx].channelIdObj = handleObjv [idx];
        channelList [idx].channel =
            TclX_GetOpenChannelObj (interp,
                                    handleObjv [idx],
                                    chanAccess);
        if (channelList [idx].channel == NULL)
            goto errorExit;

        if (chanAccess & TCL_READABLE) {
            if (TclXOSGetSelectFnum (interp, channelList [idx].channel,
			TCL_READABLE,
			&channelList [idx].readFd) != TCL_OK)
                goto errorExit;
            FD_SET (channelList [idx].readFd, fileSetPtr);
            if ((int)channelList [idx].readFd > *maxFileIdPtr)
                *maxFileIdPtr = (int)channelList [idx].readFd;
        } else {
            channelList [idx].readFd = -1;
        }

        if (chanAccess & TCL_WRITABLE) {
            if (TclXOSGetSelectFnum (interp, channelList [idx].channel,
			TCL_WRITABLE,
			&channelList [idx].writeFd) != TCL_OK)
                goto errorExit;
            FD_SET (channelList [idx].writeFd, fileSetPtr);
            if ((int)channelList [idx].writeFd > *maxFileIdPtr)
                *maxFileIdPtr = (int)channelList [idx].writeFd;
        } else {
            channelList [idx].writeFd = -1;
        }
    }

    *channelListPtr = channelList;
    return handleCnt;

  errorExit:
    ckfree ((char *) channelList);
    return -1;

}

/*-----------------------------------------------------------------------------
 * FindPendingData --
 *
 *   Scan a list of read files to determine if any of them have data pending
 * in their buffers.
 *
 * Parameters:
 *   o fileDescCnt (I) - Number of descriptors in the list.
 *   o channelListPtr (I) - A pointer to a list of the channel data for
 *     the channels to check.
 *   o fileDescSetPtr (I) - A select fd_set with will have a bit set for
 *     every file that has data pending it its buffer.
 * Returns:
 *   TRUE if any where found that had pending data, FALSE if none were found.
 *-----------------------------------------------------------------------------
 */
static int
FindPendingData (fileDescCnt, channelList, fileDescSetPtr)
    int            fileDescCnt;
    channelData_t *channelList;
    fd_set        *fileDescSetPtr;
{
    int idx, found = FALSE;

    FD_ZERO (fileDescSetPtr);

    for (idx = 0; idx < fileDescCnt; idx++) {
        if (Tcl_InputBuffered (channelList [idx].channel)) {
            FD_SET (channelList [idx].readFd, fileDescSetPtr);
            found = TRUE;
        }
    }
    return found;
}

/*-----------------------------------------------------------------------------
 * ReturnSelectedFileList --
 *
 *   Take the resulting file descriptor sets from a select, and the
 *   list of file descritpors and build up a list of Tcl file handles.
 *
 * Parameters:
 *   o fileDescSetPtr (I) - The select fd_set.
 *   o fileDescCnt (I) - Number of descriptors in the list.
 *   o channelListPtr (I) - A pointer to a list of the FILE pointers for
 *     files that are in the set.
 * Returns:
 *   List of file handles.
 *-----------------------------------------------------------------------------
 */
static Tcl_Obj *
ReturnSelectedFileList (fileDescSetPtr, fileDescCnt, channelList) 
    fd_set        *fileDescSetPtr;
    int            fileDescCnt;
    channelData_t *channelList;
{
    int idx, handleCnt;
    Tcl_Obj *fileHandleList = Tcl_NewListObj (0, NULL);

    handleCnt = 0;
    for (idx = 0; idx < fileDescCnt; idx++) {
        if (((channelList [idx].readFd >= 0) &&
             FD_ISSET (channelList [idx].readFd, fileDescSetPtr)) ||
            ((channelList [idx].writeFd >= 0) &&
             FD_ISSET (channelList [idx].writeFd, fileDescSetPtr))) {
            Tcl_ListObjAppendElement (NULL, fileHandleList,
                                      channelList [idx].channelIdObj);
            handleCnt++;
        }
    }

    return fileHandleList;
}

/*-----------------------------------------------------------------------------
 * TclX_SelectObjCmd --
 *  Implements the select TCL command:
 *      select readhandles ?writehandles? ?excepthandles? ?timeout?
 *
 *  This command is extra smart in the fact that it checks for read data
 * pending in the stdio buffer first before doing a select.
 *   
 * Results:
 *     A list in the form:
 *        {readhandles writehandles excepthandles}
 *     or {} it the timeout expired.
 *-----------------------------------------------------------------------------
 */
static int
TclX_SelectObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    static int chanAccess [] = {TCL_READABLE, TCL_WRITABLE, 0};
    int idx;
    fd_set fdSets [3], readPendingFDSet;
    int descCnts [3];
    channelData_t *descLists [3];
    Tcl_Obj *handleSetList [3];
    int numSelected, maxFileId = 0, pending;
    int result = TCL_ERROR;
    struct timeval  timeoutRec;
    struct timeval *timeoutRecPtr;

    if (objc < 2) {
        return TclX_WrongArgs (interp, objv [0], 
                      " readFileIds ?writeFileIds? ?exceptFileIds? ?timeout?");
    }

    /*
     * Initialize. 0 == read, 1 == write and 2 == exception.
     */
    for (idx = 0; idx < 3; idx++) {
        FD_ZERO (&fdSets [idx]);
        descCnts [idx] = 0;
        descLists [idx] = NULL;
    }

    /*
     * Parse the file handles and set everything up for the select call.
     */
    for (idx = 0; (idx < 3) && (idx < objc - 1); idx++) {
        descCnts [idx] = ParseSelectFileList (interp, 
                                              chanAccess [idx],
                                              objv [idx + 1],
                                              &fdSets [idx],
                                              &descLists [idx],
                                              &maxFileId);
        if (descCnts [idx] < 0)
            goto exitPoint;
    }

    /*
     * Get the time out.  Zero is different that not specified.
     */
    timeoutRecPtr = NULL;
    if ((objc > 4) && !TclX_IsNullObj (objv [4])) {
        double  timeout, seconds, microseconds;

        if (Tcl_GetDoubleFromObj (interp, objv [4], &timeout) != TCL_OK)
            goto exitPoint;
        if (timeout < 0.0) {
            TclX_AppendObjResult (interp, "timeout must be greater than ",
                                  "or equal to zero", (char *) NULL);
            goto exitPoint;
        }
        seconds = floor (timeout);
        microseconds = (timeout - seconds) * 1000000.0;
        timeoutRec.tv_sec = (long) seconds;
        timeoutRec.tv_usec = (long) microseconds;
        timeoutRecPtr = &timeoutRec;
    }

    /*
     * Check if any data is pending in the read buffers.  If there is,
     * then do the select, but don't block in it.
     */
    pending = FindPendingData (descCnts [0], descLists [0], &readPendingFDSet);
    if (pending) {
        timeoutRec.tv_sec = 0;
        timeoutRec.tv_usec = 0;
        timeoutRecPtr = &timeoutRec;
    }

    /*
     * All set, do the select.
     */
    numSelected = select (maxFileId + 1,
                          &fdSets [0], &fdSets [1], &fdSets [2],
                          timeoutRecPtr);
    if (numSelected < 0) {
        TclX_AppendObjResult (interp, "select error: ",
                              Tcl_PosixError (interp), (char *) NULL);
        goto exitPoint;
    }
    
    /*
     * If there is read data pending in the buffers, force the bits to be set
     * in the read fdSet.
     */
    if (pending) {
        for (idx = 0; idx < descCnts [0]; idx++) {
            if (FD_ISSET (descLists [0] [idx].readFd, &readPendingFDSet))
                FD_SET (descLists [0] [idx].readFd, &(fdSets [0]));
        }
    }

    /*
     * Return the result, either a 3 element list, or leave the result
     * empty if the timeout occured.
     */
    if (numSelected > 0 || pending) {
        for (idx = 0; idx < 3; idx++) {
            handleSetList [idx] =
                ReturnSelectedFileList (&fdSets [idx],
                                        descCnts [idx],
                                        descLists [idx]);
        }
        Tcl_SetObjResult (interp, Tcl_NewListObj (3, handleSetList)); 
    }

    result = TCL_OK;

  exitPoint:
    for (idx = 0; idx < 3; idx++) {
        if (descLists [idx] != NULL)
            ckfree ((char *) descLists [idx]);
    }
    return result;
}
#else /* NO_SELECT */
/*-----------------------------------------------------------------------------
 * TclX_SelectCmd --
 *     Dummy select command that returns an error for systems that don't
 *     have select.
 *-----------------------------------------------------------------------------
 */
static int
TclX_SelectObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    Tcl_AppendResult(interp, Tcl_GetString(objv[0]),
	    " is not available on this OS", (char *) NULL);
    return TCL_ERROR;
}
#endif /* NO_SELECT */


/*-----------------------------------------------------------------------------
 * TclX_SelectInit --
 *     Initialize the select command.
 *-----------------------------------------------------------------------------
 */
void
TclX_SelectInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
                          "select",
                          TclX_SelectObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
}


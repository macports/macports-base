/*
 * tclXbsearch.c
 *
 * Extended Tcl binary file search command.
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
 * $Id: tclXbsearch.c,v 1.3 2005/04/26 20:01:33 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Control block used to pass data used by the binary search routines.
 */
typedef struct binSearchCB_t {
    Tcl_Interp   *interp;         /* Pointer to the interpreter.             */
    char         *key;            /* The key to search for.                  */

    Tcl_Channel   channel;        /* I/O channel.                            */
    Tcl_DString   lineBuf;        /* Dynamic buffer to hold a line of file.  */
    off_t         lastRecOffset;  /* Offset of last record read.             */
    int           cmpResult;      /* -1, 0 or 1 result of string compare.    */
    char         *tclProc;        /* Name of Tcl comparsion proc, or NULL.   */
    } binSearchCB_t;

/*
 * Prototypes of internal functions.
 */
static int
StandardKeyCompare _ANSI_ARGS_((char *key,
                                char *line));

static int
TclProcKeyCompare _ANSI_ARGS_((binSearchCB_t *searchCBPtr));

static int
ReadAndCompare _ANSI_ARGS_((off_t          fileOffset,
                            binSearchCB_t *searchCBPtr));

static int
BinSearch _ANSI_ARGS_((binSearchCB_t *searchCBPtr));

static int 
TclX_BsearchObjCmd _ANSI_ARGS_((ClientData clientData, 
                                Tcl_Interp *interp,
                                int objc,
                                Tcl_Obj *CONST objv[]));

/*-----------------------------------------------------------------------------
 *
 * StandardKeyCompare --
 *    Standard comparison routine for BinSearch, compares the key to the
 *    first white-space seperated field in the line.
 *
 * Parameters:
 *   o key (I) - The key to search for.
 *   o line (I) - The line to compare the key to.
 *
 * Results:
 *   o < 0 if key < line-key
 *   o = 0 if key == line-key
 *   o > 0 if key > line-key.
 *-----------------------------------------------------------------------------
 */
static int
StandardKeyCompare (key, line)
    char *key;
    char *line;
{
    int  cmpResult, fieldLen;
    char saveChar;

    fieldLen = strcspn (line, " \t\r\n\v\f");

    saveChar = line [fieldLen];
    line [fieldLen] = 0;
    cmpResult = strcmp (key, line);
    line [fieldLen] = saveChar;

    return cmpResult;
}

/*-----------------------------------------------------------------------------
 * TclProcKeyCompare --
 *    Comparison routine for BinSearch that runs a Tcl procedure to, 
 *    compare the key to a line from the file.
 *
 * Parameters:
 *   o searchCBPtr (I/O) - The search control block, the line should be in
 *     lineBuf, the comparsion result is returned in cmpResult.
 *
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
TclProcKeyCompare (searchCBPtr)
    binSearchCB_t *searchCBPtr;
{
    CONST84 char *cmdArgv [3];
    char *command, *oldResult;
    int   result;

    cmdArgv [0] = searchCBPtr->tclProc;
    cmdArgv [1] = searchCBPtr->key;
    cmdArgv [2] = searchCBPtr->lineBuf.string;
    command = Tcl_Merge (3, cmdArgv);

    result = Tcl_Eval (searchCBPtr->interp, command);

    ckfree (command);
    if (result == TCL_ERROR)
        return TCL_ERROR;

    if (Tcl_GetIntFromObj (searchCBPtr->interp,
                           Tcl_GetObjResult (searchCBPtr->interp),
                           &searchCBPtr->cmpResult) != TCL_OK) {
        oldResult = Tcl_GetStringFromObj (
            Tcl_GetObjResult (searchCBPtr->interp), NULL);
        oldResult = ckstrdup (oldResult);

        Tcl_ResetResult (searchCBPtr->interp);
        TclX_AppendObjResult (searchCBPtr->interp, "invalid integer \"",
                              oldResult, "\" returned from compare proc \"",
                              searchCBPtr->tclProc, "\"", (char *) NULL);
        ckfree (oldResult);
        return TCL_ERROR;
    }
    Tcl_ResetResult (searchCBPtr->interp);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * ReadAndCompare --
 *    Search for the next line in the file starting at the specified
 *    offset.  Read the line into the dynamic buffer and compare it to
 *    the key using the specified comparison method.  The start of the
 *    last line read is saved in the control block, and if the start of
 *    the same line is found in the search, then it will not be recompared.
 *    This is needed since the search algorithm has to hit the same line
 *    a couple of times before failing, due to the fact that the records are
 *    not fixed length.
 *
 * Parameters:
 *   o fileOffset (I) - The offset of the next byte of the search, not
 *     necessarly the start of a record.
 *   o searchCBPtr (I/O) - The search control block, the comparsion result
 *     is returned in cmpResult.  If the EOF is hit, a less-than result is
 *     returned.
 *
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ReadAndCompare (fileOffset, searchCBPtr)
    off_t          fileOffset;
    binSearchCB_t *searchCBPtr;
{
    if (Tcl_Seek (searchCBPtr->channel, fileOffset, SEEK_SET) < 0)
        goto posixError;

    /*
     * Go to beginning of next line by reading the remainder of the current
     * one.
     */
    if (fileOffset != 0) {
        if (Tcl_Gets (searchCBPtr->channel, &searchCBPtr->lineBuf) < 0) {
            if (Tcl_Eof (searchCBPtr->channel) ||
                Tcl_InputBlocked (searchCBPtr->channel)) {
                TclX_AppendObjResult (searchCBPtr->interp,
                                    "bsearch got unexpected EOF on \"",
                                    Tcl_GetChannelName (searchCBPtr->channel),
                                     "\"", (char *) NULL);
                return TCL_ERROR;
            }
            goto posixError;
        }
    }
    fileOffset = (off_t) Tcl_Tell (searchCBPtr->channel);  /* Offset of next line */

    /*
     * If this is the same line as before, then just leave the comparison
     * result unchanged.
     */
    if (fileOffset == searchCBPtr->lastRecOffset)
        return TCL_OK;

    searchCBPtr->lastRecOffset = fileOffset;

    Tcl_DStringSetLength (&searchCBPtr->lineBuf, 0);

    /* 
     * Read the line. Only compare if EOF was not hit, otherwise, treat as if
     * we went above the key we are looking for.
     */
    if (Tcl_Gets (searchCBPtr->channel, &searchCBPtr->lineBuf) < 0) {
        if (Tcl_Eof (searchCBPtr->channel) ||
            Tcl_InputBlocked (searchCBPtr->channel)) {
            searchCBPtr->cmpResult = -1;
            return TCL_OK;
        }
        goto posixError;
    }

    /*
     * Compare the line.
     */
    if (searchCBPtr->tclProc == NULL) {
        searchCBPtr->cmpResult =
            StandardKeyCompare (searchCBPtr->key, 
                                searchCBPtr->lineBuf.string);
    } else {
        if (TclProcKeyCompare (searchCBPtr) != TCL_OK)
            return TCL_ERROR;
    }

    return TCL_OK;

  posixError:
   TclX_AppendObjResult (searchCBPtr->interp,
                        Tcl_GetChannelName (searchCBPtr->channel), ": ",
                        Tcl_PosixError (searchCBPtr->interp), (char *) NULL);
   return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * BinSearch --
 *      Binary search a sorted ASCII file.
 *
 * Parameters:
 *   o searchCBPtr (I/O) - The search control block, if the line is found,
 *     it is returned in lineBuf.
 * Results:
 *     TCL_OK - If the key was found.
 *     TCL_BREAK - If it was not found.
 *     TCL_ERROR - If there was an error.
 *
 * based on getpath.c from smail 2.5 (9/15/87)
 *
 *-----------------------------------------------------------------------------
 */
static int
BinSearch (searchCBPtr)
    binSearchCB_t *searchCBPtr;
{
    off_t middle, high, low;

    low = 0;
    if (TclXOSGetFileSize (searchCBPtr->channel, &high) != TCL_OK)
        goto posixError;

    /*
     * "Binary search routines are never written right the first time around."
     * - Robert G. Sheldon.
     */

    while (TRUE) {
        middle = (high + low + 1) / 2;

        if (ReadAndCompare (middle, searchCBPtr) != TCL_OK)
            return TCL_ERROR;

        if (searchCBPtr->cmpResult == 0)
            return TCL_OK;     /* Found   */
        
        if (low >= middle)  
            return TCL_BREAK;  /* Failure */

        /*
         * Close window.
         */
        if (searchCBPtr->cmpResult > 0) {
            low = middle;
        } else {
            high = middle - 1;
        }
    }

  posixError:
   TclX_AppendObjResult (searchCBPtr->interp,
                         Tcl_GetChannelName (searchCBPtr->channel), ": ",
                         Tcl_PosixError (searchCBPtr->interp), (char *) NULL);
   return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_BsearchObjCmd --
 *     Implements the TCL bsearch command:
 *        bsearch filehandle key ?retvar?
 *-----------------------------------------------------------------------------
 */
static int
TclX_BsearchObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    int status;
    binSearchCB_t searchCB;

    if ((objc < 3) || (objc > 5)) {
        TclX_WrongArgs (interp, objv [0], 
                        "handle key ?retvar? ?compare_proc?");
        return TCL_ERROR;
    }

    searchCB.channel = TclX_GetOpenChannelObj (interp,
                                               objv [1],
                                               TCL_READABLE);
    if (searchCB.channel == NULL)
        return TCL_ERROR;

    searchCB.interp = interp;
    searchCB.key = Tcl_GetStringFromObj (objv [2], NULL);
    searchCB.lastRecOffset = -1;
    searchCB.tclProc = (objc == 5) ? Tcl_GetStringFromObj (objv [4], NULL) :
        NULL;

    Tcl_DStringInit (&searchCB.lineBuf);

    status = BinSearch (&searchCB);
    if (status == TCL_ERROR) {
        Tcl_DStringFree (&searchCB.lineBuf);
        return TCL_ERROR;
    }

    if (status == TCL_BREAK) {
        if ((objc >= 4) && !TclX_IsNullObj (objv [3]))
            Tcl_SetBooleanObj (Tcl_GetObjResult (interp), FALSE);
        goto okExit;
    }

    if ((objc == 3) || TclX_IsNullObj (objv [3])) {
        Tcl_SetStringObj (Tcl_GetObjResult (interp),
                          Tcl_DStringValue (&searchCB.lineBuf),
                          -1);
    } else {
        Tcl_Obj *valPtr;

        valPtr = Tcl_NewStringObj (Tcl_DStringValue (&searchCB.lineBuf),
                                   -1);
        if (Tcl_ObjSetVar2(interp, objv[3], NULL, valPtr,
                           TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL) {
            Tcl_DecrRefCount (valPtr);
            goto errorExit;
        }
        Tcl_SetBooleanObj (Tcl_GetObjResult (interp), TRUE);
    }

  okExit:
    Tcl_DStringFree (&searchCB.lineBuf);
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&searchCB.lineBuf);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_BsearchInit --
 *     Initialize the bsearch command.
 *-----------------------------------------------------------------------------
 */
void
TclX_BsearchInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
                          "bsearch",
                          TclX_BsearchObjCmd, 
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
}

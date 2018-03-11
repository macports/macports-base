/*
 * tclXflock.c
 *
 * Extended Tcl flock and funlock commands.
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
 * $Id: tclXflock.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */
/* FIX: Need to add an interface to F_GETLK */

#include "tclExtdInt.h"

/*
 * Prototypes of internal functions.
 */
static int
ParseLockUnlockArgs _ANSI_ARGS_((Tcl_Interp     *interp,
                                 int             objc,
                                 Tcl_Obj *CONST  objv[],
                                 int             argIdx,
                                 TclX_FlockInfo *lockInfoPtr));

static int
TclX_FlockObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int         objc,
                              Tcl_Obj    *CONST objv[]));

static int
TclX_FunlockObjCmd _ANSI_ARGS_((ClientData clientData, 
                             Tcl_Interp *interp,
                             int         objc,
                             Tcl_Obj    *CONST objv[]));


/*-----------------------------------------------------------------------------
 * ParseLockUnlockArgs --
 *
 * Parse the positional arguments common to both the flock and funlock
 * commands:
 *   ... fileId ?start? ?length? ?origin?
 *
 * Parameters:
 *   o interp - Pointer to the interpreter, errors returned in result.
 *   o objc - Count of arguments supplied to the comment.
 *   o objv - Commant argument vector.
 *   o argIdx - Index of the first common agument to parse.
 *   o access - Set of TCL_READABLE or TCL_WRITABLE or zero to
 *     not do error checking.
 *   o lockInfoPtr - Lock info structure, start, length and whence are
 *     initialized by this routine.  The access and block fields should already
 *     be filled in.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ParseLockUnlockArgs (interp, objc, objv, argIdx, lockInfoPtr)
    Tcl_Interp     *interp;
    int             objc;
    Tcl_Obj *CONST  objv[];
    int             argIdx;
    TclX_FlockInfo *lockInfoPtr;
{
    lockInfoPtr->start  = 0;
    lockInfoPtr->len    = 0;
    lockInfoPtr->whence = 0;

    lockInfoPtr->channel = TclX_GetOpenChannelObj (interp, objv [argIdx],
                                                   lockInfoPtr->access);
    if (lockInfoPtr->channel == NULL)
        return TCL_ERROR;
    argIdx++;

    if ((argIdx < objc) && !TclX_IsNullObj (objv [argIdx])) {
        if (TclX_GetOffsetFromObj (interp, objv [argIdx],
                                   &lockInfoPtr->start) != TCL_OK)
            return TCL_ERROR;
    }
    argIdx++;

    if ((argIdx < objc) && !TclX_IsNullObj (objv [argIdx])) {
        if (TclX_GetOffsetFromObj (interp, objv [argIdx],
                                   &lockInfoPtr->len) != TCL_OK)
            return TCL_ERROR;
    }
    argIdx++;

    if (argIdx < objc) {
        char *originStr = Tcl_GetStringFromObj (objv [argIdx], NULL);
        if (STREQU (originStr, "start")) {
            lockInfoPtr->whence = 0;
        } else if (STREQU (originStr, "current")) {
            lockInfoPtr->whence = 1;
        } else if (STREQU (originStr, "end")) {
            lockInfoPtr->whence = 2;
        } else {
            TclX_AppendObjResult (interp, "bad origin \"",  originStr,
                                  "\": should be \"start\", \"current\", ",
                                  "or \"end\"",  (char *) NULL);
            return TCL_ERROR;
        }
    }

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_FlockCmd --
 *
 * Implements the `flock' Tcl command:
 *    flock ?-read|-write? ?-nowait? fileId ?start? ?length? ?origin?
 *-----------------------------------------------------------------------------
 */
static int
TclX_FlockObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    int argIdx;
    TclX_FlockInfo lockInfo;

    if (objc < 2)
        goto invalidArgs;

    lockInfo.access = 0;
    lockInfo.block = TRUE;

    /*
     * Parse off the options.
     */
    for (argIdx = 1; argIdx < objc; argIdx++) {
        char *optStr = Tcl_GetStringFromObj (objv [argIdx], NULL);
        if (optStr [0] != '-')
            break;
        if (STREQU (optStr, "-read")) {
            lockInfo.access |= TCL_READABLE;
            continue;
        }
        if (STREQU (optStr, "-write")) {
            lockInfo.access |= TCL_WRITABLE;
            continue;
        }
        if (STREQU (optStr, "-nowait")) {
            lockInfo.block = FALSE;
            continue;
        }
        TclX_AppendObjResult (interp, "invalid option \"", optStr,
                              "\" expected one of \"-read\", \"-write\", or ",
                              "\"-nowait\"", (char *) NULL);
        return TCL_ERROR;
    }

    if (lockInfo.access == (TCL_READABLE | TCL_WRITABLE)) {
        TclX_AppendObjResult (interp,
                              "can not specify both \"-read\" and \"-write\"",
                              (char *) NULL);
        return TCL_ERROR;
    }

    if (lockInfo.access == 0)
        lockInfo.access = TCL_WRITABLE;

    /*
     * Make sure there are enough arguments left and then parse the 
     * positional ones.
     */
    if ((argIdx > objc - 1) || (argIdx < objc - 4))
        goto invalidArgs;

    if (ParseLockUnlockArgs (interp, objc, objv, argIdx, &lockInfo) != TCL_OK)
        return TCL_ERROR;

    if (TclXOSFlock (interp, &lockInfo) != TCL_OK)
        return TCL_ERROR;

    if (!lockInfo.block) {
        Tcl_SetBooleanObj (Tcl_GetObjResult (interp),
                           lockInfo.gotLock);
    }
    return TCL_OK;

    /*
     * Code to return error messages.
     */
  invalidArgs:
    return TclX_WrongArgs (interp, objv [0],
               "?-read|-write? ?-nowait? fileId ?start? ?length? ?origin?");
}

/*-----------------------------------------------------------------------------
 * TclX_FunlockCmd --
 *
 * Implements the `funlock' Tcl command:
 *    funlock fileId ?start? ?length? ?origin?
 *-----------------------------------------------------------------------------
 */
static int
TclX_FunlockObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    TclX_FlockInfo lockInfo;

    if ((objc < 2) || (objc > 5)) {
        return TclX_WrongArgs (interp, objv [0], 
                               "fileId ?start? ?length? ?origin?");
    }

    lockInfo.access = 0;  /* Read or write */
    if (ParseLockUnlockArgs (interp, objc, objv, 1, &lockInfo) != TCL_OK)
        return TCL_ERROR;

    return TclXOSFunlock (interp, &lockInfo);
}


/*-----------------------------------------------------------------------------
 * TclX_FlockInit --
 *     Initialize the flock and funlock command.
 *-----------------------------------------------------------------------------
 */
void
TclX_FlockInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
                          "flock",
                          TclX_FlockObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
                          "funlock",
                          TclX_FunlockObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
}


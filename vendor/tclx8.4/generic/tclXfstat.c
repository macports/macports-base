/*
 * tclXfstat.c
 *
 * Extended Tcl fstat command.
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
 * $Id: tclXfstat.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */
#include "tclExtdInt.h"

#ifndef S_IFMT
#   define S_IFMT  0170000
#endif

/*
 * Table to convert file mode to symbolic file type.  Note, the S_ macros
 * are not used because the BSD macros don't distinguish between a fifo and
 * a socket.
 */
static struct {
    int intType;
    char *strType;
} modeToSymTable [] = {
    {S_IFIFO,  "fifo"},
    {S_IFCHR,  "characterSpecial"},
    {S_IFDIR,  "directory"},
#ifdef S_IFBLK
    {S_IFBLK,  "blockSpecial"},
#endif
    {S_IFREG,  "file"},
#ifdef S_IFLNK
    {S_IFLNK,  "link"},
#endif
#ifdef S_IFSOCK
    {S_IFSOCK, "socket"},
#endif
    {0,        NULL}
};

/*
 * Prototypes of internal functions.
 */
static char *
StrFileType _ANSI_ARGS_((struct stat  *statBufPtr));

static void
ReturnStatList _ANSI_ARGS_((Tcl_Interp   *interp,
                            int           ttyDev,
                            struct stat  *statBufPtr));

static int
ReturnStatArray _ANSI_ARGS_((Tcl_Interp   *interp,
                             int           ttyDev,
                             struct stat  *statBufPtr,
                             Tcl_Obj      *arrayObj));

static int
ReturnStatItem _ANSI_ARGS_((Tcl_Interp   *interp,
                            Tcl_Channel   channel,
                            int           ttyDev,
                            struct stat  *statBufPtr,
                            char         *itemName));

static int 
TclX_FstatObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * StrFileType --
 *
 *   Looks at stat mode and returns a text string indicating what type of
 * file it is.
 *
 * Parameters:
 *   o statBufPtr (I) - Pointer to a buffer initialized by stat or fstat.
 * Returns:
 *   A pointer static text string representing the type of the file.
 *-----------------------------------------------------------------------------
 */
static char *
StrFileType (statBufPtr)
    struct stat  *statBufPtr;
{
    int idx;

    for (idx = 0; modeToSymTable [idx].strType != NULL; idx++) {
        if ((statBufPtr->st_mode & S_IFMT) == modeToSymTable [idx].intType)
            return modeToSymTable [idx].strType;
    }
    return "unknown";
}

/*-----------------------------------------------------------------------------
 * ReturnStatList --
 *
 *   Return file stat infomation as a keyed list.
 *
 * Parameters:
 *   o interp (I) - The list is returned in result.
 *   o ttyDev (O) - A boolean indicating if the device is associated with a
 *     tty.
 *   o statBufPtr (I) - Pointer to a buffer initialized by stat or fstat.
 *-----------------------------------------------------------------------------
 */
static void
ReturnStatList (interp,ttyDev, statBufPtr)
    Tcl_Interp   *interp;
    int           ttyDev;
    struct stat  *statBufPtr;
{
    Tcl_Obj *keylPtr = TclX_NewKeyedListObj ();
    
    TclX_KeyedListSet (interp, keylPtr, "atime",
                       Tcl_NewLongObj ((long) statBufPtr->st_atime));
    TclX_KeyedListSet (interp, keylPtr, "ctime",
                       Tcl_NewLongObj ((long) statBufPtr->st_ctime));
    TclX_KeyedListSet (interp, keylPtr, "dev",
                       Tcl_NewIntObj ((int) statBufPtr->st_dev));
    TclX_KeyedListSet (interp, keylPtr, "gid",
                       Tcl_NewIntObj ((int) statBufPtr->st_gid));
    TclX_KeyedListSet (interp, keylPtr, "ino",
                       Tcl_NewIntObj ((int) statBufPtr->st_ino));
    TclX_KeyedListSet (interp, keylPtr, "mode",
                       Tcl_NewIntObj ((int) statBufPtr->st_mode));
    TclX_KeyedListSet (interp, keylPtr, "mtime",
                       Tcl_NewLongObj ((long) statBufPtr->st_mtime));
    TclX_KeyedListSet (interp, keylPtr, "nlink",
                       Tcl_NewIntObj ((int) statBufPtr->st_nlink));
    TclX_KeyedListSet (interp, keylPtr, "size",
                       Tcl_NewLongObj ((long) statBufPtr->st_size));
    TclX_KeyedListSet (interp, keylPtr, "uid",
                       Tcl_NewIntObj ((int) statBufPtr->st_uid));
    TclX_KeyedListSet (interp, keylPtr, "tty",
                       Tcl_NewBooleanObj (ttyDev));
    TclX_KeyedListSet (interp, keylPtr, "type",
                       Tcl_NewStringObj (StrFileType (statBufPtr), -1));
    Tcl_SetObjResult (interp, keylPtr);
}

/*-----------------------------------------------------------------------------
 * ReturnStatArray --
 *
 *   Return file stat infomation in an array.
 *
 * Parameters:
 *   o interp (I) - Current interpreter, error return in result.
 *   o ttyDev (O) - A boolean indicating if the device is associated with a
 *     tty.
 *   o statBufPtr (I) - Pointer to a buffer initialized by stat or fstat.
 *   o arrayObj (I) - The the array to return the info in.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ReturnStatArray (interp, ttyDev, statBufPtr, arrayObj)
    Tcl_Interp   *interp;
    int           ttyDev;
    struct stat  *statBufPtr;
    Tcl_Obj      *arrayObj;
{
    char *varName = Tcl_GetStringFromObj (arrayObj, NULL);

    if  (Tcl_SetVar2Ex(interp, varName, "dev",
                       Tcl_NewIntObj((int)statBufPtr->st_dev),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "ino",
                       Tcl_NewIntObj((int)statBufPtr->st_ino),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "mode",
                       Tcl_NewIntObj((int)statBufPtr->st_mode),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "nlink",
                       Tcl_NewIntObj((int)statBufPtr->st_nlink),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "uid",
                       Tcl_NewIntObj((int)statBufPtr->st_uid),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "gid",
                       Tcl_NewIntObj((int)statBufPtr->st_gid),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "size",
                       Tcl_NewLongObj((long)statBufPtr->st_size),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "atime",
                       Tcl_NewLongObj((long)statBufPtr->st_atime),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "mtime",
                         Tcl_NewLongObj((long)statBufPtr->st_mtime),
                         TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if  (Tcl_SetVar2Ex(interp, varName, "ctime",
                       Tcl_NewLongObj((long)statBufPtr->st_ctime),
                       TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if (Tcl_SetVar2Ex(interp, varName, "tty",
                      Tcl_NewBooleanObj(ttyDev),
                      TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    if (Tcl_SetVar2Ex(interp, varName, "type",
                      Tcl_NewStringObj(StrFileType(statBufPtr), -1),
                      TCL_LEAVE_ERR_MSG) == NULL)
        goto errorExit;

    return TCL_OK;

  errorExit:
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * ReturnStatItem --
 *
 *   Return a single file status item.
 *
 * Parameters:
 *   o interp (I) - Item or error returned in result.
 *   o channel (I) - Channel the file is assoicated with.
 *   o ttyDev (O) - A boolean indicating if the device is associated with a
 *     tty.
 *   o statBufPtr (I) - Pointer to a buffer initialized by stat or fstat.
 *   o itemName (I) - The name of the desired item.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ReturnStatItem (interp, channel, ttyDev, statBufPtr, itemName)
    Tcl_Interp   *interp;
    Tcl_Channel   channel;
    int           ttyDev;
    struct stat  *statBufPtr;
    char         *itemName;
{
    Tcl_Obj *objPtr;

    if (STREQU (itemName, "dev"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_dev);
    else if (STREQU (itemName, "ino"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_ino);
    else if (STREQU (itemName, "mode"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_mode);
    else if (STREQU (itemName, "nlink"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_nlink);
    else if (STREQU (itemName, "uid"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_uid);
    else if (STREQU (itemName, "gid"))
        objPtr = Tcl_NewIntObj ((int) statBufPtr->st_gid);
    else if (STREQU (itemName, "size"))
        objPtr = Tcl_NewLongObj ((long) statBufPtr->st_size);
    else if (STREQU (itemName, "atime"))
        objPtr = Tcl_NewLongObj ((long) statBufPtr->st_atime);
    else if (STREQU (itemName, "mtime"))
        objPtr = Tcl_NewLongObj ((long) statBufPtr->st_mtime);
    else if (STREQU (itemName, "ctime"))
        objPtr = Tcl_NewLongObj ((long) statBufPtr->st_ctime);
    else if (STREQU (itemName, "type"))
        objPtr = Tcl_NewStringObj (StrFileType (statBufPtr), -1);
    else if (STREQU (itemName, "tty"))
        objPtr = Tcl_NewBooleanObj (ttyDev);
    else if (STREQU (itemName, "remotehost")) {
        objPtr = TclXGetHostInfo (interp, channel, TRUE);
        if (objPtr == NULL)
            return TCL_ERROR;
    } else if (STREQU (itemName, "localhost")) {
        objPtr = TclXGetHostInfo (interp, channel, FALSE);
        if (objPtr == NULL)
            return TCL_ERROR;
    } else {
        TclX_AppendObjResult (interp, "Got \"", itemName,
                              "\", expected one of ",
                              "\"atime\", \"ctime\", \"dev\", \"gid\", ",
                              "\"ino\", \"mode\", \"mtime\", \"nlink\", ",
                              "\"size\", \"tty\", \"type\", \"uid\", ",
                              "\"remotehost\", or \"localhost\"",
                              (char *) NULL);
        return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, objPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_FstatObjCmd --
 *      Implements the fstat TCL command:
 *         fstat fileId ?item?|?stat arrayvar?
 *-----------------------------------------------------------------------------
 */
static int
TclX_FstatObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Channel channel;
    struct stat statBuf;
    int ttyDev;

    if ((objc < 2) || (objc > 4)) {
        return TclX_WrongArgs (interp, objv [0], 
                               "fileId ?item?|?stat arrayVar?");
    }
    
    channel = TclX_GetOpenChannelObj (interp, objv [1], 0);
    if (channel == NULL)
        return TCL_ERROR;
    
    if (TclXOSFstat (interp, channel, &statBuf, &ttyDev)) {
        return TCL_ERROR;
    }

    /*
     * Return data in the requested format.
     */
    if (objc >= 3) {
        char *itemName = Tcl_GetStringFromObj (objv [2], NULL);

        if (objc == 4) {
            if (!STREQU (itemName, "stat")) {
                TclX_AppendObjResult (interp,
                                      "expected item name of \"stat\" when ",
                                      "using array name", (char *) NULL);
                return TCL_ERROR;
            }
            return ReturnStatArray (interp, ttyDev, &statBuf, objv [3]);
        } else {
            return ReturnStatItem (interp, channel, ttyDev, &statBuf,
                                   itemName);
        }
    }
    ReturnStatList (interp, ttyDev, &statBuf);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_FstatInit --
 *     Initialize the fstat command.
 *-----------------------------------------------------------------------------
 */
void
TclX_FstatInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
                          "fstat",
                          TclX_FstatObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
}

/*
 * tclXfilecmds.c
 *
 * Extended Tcl file-related commands.
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
 * $Id: tclXfilecmds.c,v 1.2 2002/09/26 00:19:18 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

static char *FILE_ID_OPT = "-fileid";

/*
 * Prototypes of internal functions.
 */
static int
TruncateByPath  _ANSI_ARGS_((Tcl_Interp  *interp,
                             char        *filePath,
                             off_t        newSize));

static int
ReadDirCallback _ANSI_ARGS_((Tcl_Interp  *interp,
                             char        *path,
                             char        *fileName,
                             int          caseSensitive,
                             ClientData   clientData));

static int 
TclX_PipeObjCmd _ANSI_ARGS_((ClientData  clientData,
                             Tcl_Interp *interp,
                             int         objc,
                             Tcl_Obj    *CONST objv[]));

static int
TclX_FtruncateObjCmd _ANSI_ARGS_((ClientData  clientData, 
                                  Tcl_Interp *interp, 
                                  int         objc,
                                  Tcl_Obj    *CONST objv[]));

static int
TclX_ReaddirObjCmd _ANSI_ARGS_((ClientData clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj    *CONST objv[]));


/*-----------------------------------------------------------------------------
 * Tcl_PipeObjCmd --
 *     Implements the pipe TCL command:
 *         pipe ?fileId_var_r fileId_var_w?
 *
 * Results:
 *      Standard TCL result.
 *-----------------------------------------------------------------------------
 */
static int
TclX_PipeObjCmd (clientData, interp, objc, objv)
     ClientData  clientData;
     Tcl_Interp *interp;
     int         objc;
     Tcl_Obj    *CONST objv[];
{
    Tcl_Channel   channels [2];
    CONST84 char *channelNames [2];

    if (!((objc == 1) || (objc == 3)))
	return TclX_WrongArgs (interp, objv [0], "?fileId_var_r fileId_var_w?");

    if (TclXOSpipe (interp, channels) != TCL_OK)
        return TCL_ERROR;


    channelNames [0] = Tcl_GetChannelName (channels [0]);
    channelNames [1] = Tcl_GetChannelName (channels [1]);
    
    if (objc == 1) {
        TclX_AppendObjResult (interp, channelNames [0], " ",
                              channelNames [1], (char *) NULL);
    } else {
        if (Tcl_ObjSetVar2(interp, objv[1], NULL, Tcl_NewStringObj(channelNames [0], -1),
                           TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL)
            goto errorExit;

        if (Tcl_ObjSetVar2(interp, objv[2], NULL,
                           Tcl_NewStringObj(channelNames [1], -1),
                           TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL)
            goto errorExit;
    }

    return TCL_OK;

  errorExit:
    Tcl_Close (NULL, channels [0]);
    Tcl_Close (NULL, channels [1]);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TruncateByPath --
 * 
 *  Truncate a file via path, if this is available on this system.
 *
 * Parameters:
 *   o interp (I) - Error messages are returned in the interpreter.
 *   o filePath (I) - Path to file.
 *   o newSize (I) - Size to truncate the file to.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
TruncateByPath (interp, filePath, newSize)
    Tcl_Interp  *interp;
    char        *filePath;
    off_t        newSize;
{
#ifndef NO_TRUNCATE
    Tcl_DString  pathBuf;

    Tcl_DStringInit (&pathBuf);

    filePath = Tcl_TranslateFileName (interp, filePath, &pathBuf);
    if (filePath == NULL) {
        Tcl_DStringFree (&pathBuf);
        return TCL_ERROR;
    }
    if (truncate (filePath, newSize) != 0) {
        TclX_AppendObjResult (interp, filePath, ": ", Tcl_PosixError (interp),
                              (char *) NULL);
        Tcl_DStringFree (&pathBuf);
        return TCL_ERROR;
    }

    Tcl_DStringFree (&pathBuf);
    return TCL_OK;
#else
    TclX_AppendObjResult (interp, "truncating files by path is not available ",
                          "on this system", (char *) NULL);
    return TCL_ERROR;
#endif
}

/*-----------------------------------------------------------------------------
 * Tcl_FtruncateObjCmd --
 *     Implements the Tcl ftruncate command:
 *     ftruncate [-fileid] file newsize
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_FtruncateObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    int           objIdx, fileIds;
    off_t         newSize;
    long          convSize;
    Tcl_Channel   channel;
    char         *switchString;
    char         *pathString;

    fileIds = FALSE;
    for (objIdx = 1; objIdx < objc ; objIdx++) {
        switchString = Tcl_GetStringFromObj (objv [objIdx], NULL);
	if (*switchString != '-')
            break;
        if (STREQU (switchString, FILE_ID_OPT)) {
            fileIds = TRUE;
        } else {
            TclX_AppendObjResult (interp, "Invalid option \"", switchString,
                                  "\", expected \"", FILE_ID_OPT, "\"",
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }

    if (objIdx != objc - 2)
        return TclX_WrongArgs (interp, objv [0], "[-fileid] file newsize");

    if (Tcl_GetLongFromObj (interp, objv [objIdx + 1], &convSize) != TCL_OK)
        return TCL_ERROR;

    newSize = convSize;
    if (fileIds) {
        channel = TclX_GetOpenChannelObj (interp, objv [objIdx], 0);
        if (channel == NULL)
            return TCL_ERROR;
        return TclXOSftruncate (interp, channel, newSize,
                                "-fileid option");
    } else {
	pathString = Tcl_GetStringFromObj (objv [objIdx], NULL);
        return TruncateByPath (interp, pathString, newSize);
    }
}

/*-----------------------------------------------------------------------------
 * ReadDirCallback --
 *
 *   Callback procedure for walking directories.
 * Parameters:
 *   o interp (I) - Interp is passed though.
 *   o path (I) - Normalized path to directory.
 *   o fileName (I) - Tcl normalized file name in directory.
 *   o caseSensitive (I) - Are the file names case sensitive?  Always
 *     TRUE on Unix.
 *   o clientData (I) - Tcl_DString to append names to.
 * Returns:
 *   TCL_OK.
 *-----------------------------------------------------------------------------
 */
static int
ReadDirCallback (interp, path, fileName, caseSensitive, clientData)
    Tcl_Interp  *interp;
    char        *path;
    char        *fileName;
    int          caseSensitive;
    ClientData   clientData;
{
    Tcl_Obj *fileListObj = (Tcl_Obj *) clientData;
    Tcl_Obj *fileNameObj;
    int      result;

    fileNameObj = Tcl_NewStringObj (fileName, -1);
    result = Tcl_ListObjAppendElement (interp, fileListObj, fileNameObj);
    return result;
}

/*-----------------------------------------------------------------------------
 * Tcl_ReaddirObjCmd --
 *     Implements the rename TCL command:
 *         readdir ?-hidden? dirPath
 *
 * Results:
 *      Standard TCL result.
 *-----------------------------------------------------------------------------
 */
static int
TclX_ReaddirObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_DString  pathBuf;
    char        *dirPath;
    int          hidden, status;
    Tcl_Obj     *fileListObj;
    char        *switchString;
    int          dirPathLen;
    
    if ((objc < 2) || (objc > 3))
        return TclX_WrongArgs (interp, objv [0], "?-hidden? dirPath");

    if (objc == 2) {
        dirPath = Tcl_GetStringFromObj (objv [1], &dirPathLen);
        hidden = FALSE;
    } else {
        switchString = Tcl_GetStringFromObj (objv [1], NULL);
        if (!STREQU (switchString, "-hidden")) {
            TclX_AppendObjResult (interp,
                                  "expected option of \"-hidden\", got \"",
                                  switchString, "\"", (char *) NULL);
            return TCL_ERROR;
        }
        dirPath = Tcl_GetStringFromObj (objv [2], NULL);
        hidden = TRUE;
    }

    Tcl_DStringInit (&pathBuf);

    fileListObj = Tcl_NewObj ();

    dirPath = Tcl_TranslateFileName (interp, dirPath, &pathBuf);
    if (dirPath == NULL) {
        goto errorExit;
    }

    status = TclXOSWalkDir (interp,
                            dirPath,
                            hidden,
                            ReadDirCallback,
                            (ClientData) fileListObj);
    if (status == TCL_ERROR)
        goto errorExit;

    Tcl_DStringFree (&pathBuf);
    Tcl_SetObjResult (interp, fileListObj);
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&pathBuf);
    Tcl_DecrRefCount (fileListObj);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_FilecmdsInit --
 *     Initialize the file commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_FilecmdsInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
			  "pipe",
			  TclX_PipeObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "ftruncate",
			  TclX_FtruncateObjCmd,
			  (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
                          "readdir",
			  TclX_ReaddirObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}


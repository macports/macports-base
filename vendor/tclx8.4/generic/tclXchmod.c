/* 
 * tclXchmod.c --
 *
 *  Chmod, chown and chgrp Tcl commands.
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
 * $Id: tclXchmod.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Type used for returning parsed mode informtion.
 */
typedef struct {
    char  *symMode;  /* Symbolic mode. If NULL, use absolute mode. */
    int    absMode;  /* Numeric mode. */
} modeInfo_t;

static char *FILE_ID_OPT = "-fileid";

/*
 * Prototypes of internal functions.
 */
static int
ConvSymMode _ANSI_ARGS_((Tcl_Interp  *interp,
                         char        *symMode,
                         int          modeVal));
static int 
TclX_ChmodObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));

static int 
TclX_ChownObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));

static int 
TclX_ChgrpObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * ConvSymMode --
 *   Parse and convert symbolic file permissions as specified by chmod(C).
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o symMode - The symbolic permissions to parse.
 *   o modeVal - The existing permissions value on a file.
 *
 * Returns:
 *   The new permissions, or -1 if invalid permissions where supplied.
 *-----------------------------------------------------------------------------
 */
static int
ConvSymMode (interp, symMode, modeVal)
    Tcl_Interp  *interp;
    char        *symMode;
    int          modeVal;
{
    int  user, group, other;
    char operator, *scanPtr;
    int  rwxMask, ugoMask, setUID, sticky, locking;
    int  newMode;

    scanPtr = symMode;

    while (*scanPtr != '\0') {
        user = group = other = FALSE;

        /* 
         * Scan who field.
         */
        while (! ((*scanPtr == '+') || 
                  (*scanPtr == '-') || 
                  (*scanPtr == '='))) {
            switch (*scanPtr) {
                case 'a':
                    user = group = other = TRUE;
                    break;
                case 'u':
                    user = TRUE;
                    break;
                case 'g':
                    group = TRUE;
                    break;
                case 'o':
                    other = TRUE;
                    break;
                default:
                    goto invalidMode;
            }
            scanPtr++;
        }

        /*
         * If none where specified, that means all.
         */

        if (! (user || group || other))
            user = group = other = TRUE;

        operator = *scanPtr++;

        /* 
         * Decode the permissions
         */

        rwxMask = 0;
        setUID = sticky = locking = FALSE;

        /* 
         * Scan permissions field
         */
        while (! ((*scanPtr == ',') || (*scanPtr == 0))) {
            switch (*scanPtr) {
                case 'r':
                    rwxMask |= 4;
                    break;
                case 'w':
                    rwxMask |= 2;
                    break;
                case 'x':
                    rwxMask |= 1;
                    break;
                case 's':
                    setUID = TRUE;
                    break;
                case 't':
                    sticky = TRUE;
                    break;
                case 'l':
                    locking = TRUE;
                    break;
                default:
                    goto invalidMode;
            }
            scanPtr++;
        }

        /*
         * Build mode map of specified values.
         */

        newMode = 0;
        ugoMask = 0;
        if (user) {
            newMode |= rwxMask << 6;
            ugoMask |= 0700;
        }
        if (group) {
            newMode |= rwxMask << 3;
            ugoMask |= 0070;
        }
        if (other) {
            newMode |= rwxMask;
            ugoMask |= 0007;
        }
        if (setUID && user)
            newMode |= 04000;
        if ((setUID || locking) && group)
            newMode |= 02000;
        if (sticky)
            newMode |= 01000;

        /* 
         * Add to cumulative mode based on operator.
         */

        if (operator == '+')
            modeVal |= newMode;
        else if (operator == '-')
            modeVal &= ~newMode;
        else if (operator == '=')
            modeVal |= (modeVal & ugoMask) | newMode;
        if (*scanPtr == ',')
            scanPtr++;
    }

    return modeVal;

  invalidMode:
    TclX_AppendObjResult (interp, "invalid file mode \"", symMode, "\"",
                          (char *) NULL);
    return -1;
}

/*-----------------------------------------------------------------------------
 * ChmodFileNameObj --
 *   Change the mode of a file by name.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o modeInfo - Infomation with the mode to set the file to.
 *   o fileName - Name of the file to change.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ChmodFileNameObj (interp, modeInfo, fileNameObj)
    Tcl_Interp  *interp;
    modeInfo_t   modeInfo;
    Tcl_Obj     *fileNameObj;
{
    char         *filePath;
    struct stat   fileStat;
    Tcl_DString   pathBuf;
    int           newMode;
    char         *fileName;

    Tcl_DStringInit (&pathBuf);

    fileName = Tcl_GetStringFromObj (fileNameObj, NULL);
    filePath = Tcl_TranslateFileName (interp, fileName, &pathBuf);
    if (filePath == NULL) {
        Tcl_DStringFree (&pathBuf);
        return TCL_ERROR;
    }

    if (modeInfo.symMode != NULL) {
        if (stat (filePath, &fileStat) != 0)
            goto fileError;
        newMode = ConvSymMode (interp, modeInfo.symMode,
                               fileStat.st_mode & 07777);
        if (newMode < 0)
            goto errorExit;
    } else {
        newMode = modeInfo.absMode;
    }
    if (TclXOSchmod (interp, filePath, (unsigned short) newMode) < 0)
        return TCL_ERROR;

    Tcl_DStringFree (&pathBuf);
    return TCL_OK;

  fileError:
    TclX_AppendObjResult (interp, filePath, ": ",
                          Tcl_PosixError (interp), (char *) NULL);
  errorExit:
    Tcl_DStringFree (&pathBuf);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * ChmodFileIdObj --
 *   Change the mode of a file by file id.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o modeInfo - Infomation with the mode to set the file to.
 *   o fileId - The Tcl file id.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ChmodFileIdObj (interp, modeInfo, fileIdObj)
    Tcl_Interp  *interp;
    modeInfo_t   modeInfo;
    Tcl_Obj     *fileIdObj;
{
    Tcl_Channel channel;
    struct stat fileStat;
    int         newMode;

    channel = TclX_GetOpenChannelObj (interp, fileIdObj, 0);
    if (channel == NULL) {
        return TCL_ERROR;
    }

    if (modeInfo.symMode != NULL) {
        if (TclXOSFstat (interp, channel, &fileStat, NULL) != 0)
            return TCL_ERROR;
        newMode = ConvSymMode (interp, modeInfo.symMode,
                               fileStat.st_mode & 07777);
        if (newMode < 0)
            return TCL_ERROR;
    } else {
        newMode = modeInfo.absMode;
    }
    if (TclXOSfchmod (interp, channel, (unsigned short) newMode,
                      FILE_ID_OPT) == TCL_ERROR)
        return TCL_ERROR;

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_ChmodObjCmd --
 *     Implements the TCL chmod command:
 *     chmod [fileid] mode filelist
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_ChmodObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int           objIdx, idx, fileObjc, fileIds, result;
    modeInfo_t    modeInfo;
    Tcl_Obj     **fileObjv;
    char         *fileIdsString;
    char         *modeString;
    int          modeBits;

    /*
     * Options are not parsable just looking for "-", since modes can
     * start with "-".
     */
    fileIds = FALSE;
    objIdx = 1;
    if (objc > 1) {
	fileIdsString = Tcl_GetStringFromObj (objv [objIdx], NULL);
        if (STREQU (fileIdsString, FILE_ID_OPT)) {
	    fileIds = TRUE;
	    objIdx++;
	}
    }

    if (objIdx != objc - 2)
	return TclX_WrongArgs (interp, objv [0], "[-fileid] mode filelist");

    modeString = Tcl_GetStringFromObj (objv [objIdx], NULL);
    if (ISDIGIT (modeString[0])) {
        if (Tcl_GetIntFromObj (interp, objv [objIdx], &modeBits) 
	  != TCL_OK)
            return TCL_ERROR;
	modeInfo.absMode = modeBits;
        modeInfo.symMode = NULL;
    } else {
        modeInfo.symMode = modeString;
    }

    if (Tcl_ListObjGetElements (interp, objv [objIdx + 1], &fileObjc,
                       &fileObjv) != TCL_OK)
        return TCL_ERROR;

    result = TCL_OK;
    for (idx = 0; (idx < fileObjc) && (result == TCL_OK); idx++) {
        if (fileIds) {
            result = ChmodFileIdObj (interp, modeInfo, fileObjv [idx]); 
        } else {
            result = ChmodFileNameObj (interp, modeInfo, fileObjv [idx]);
        }
    }

    return result;
}

/*-----------------------------------------------------------------------------
 * Tcl_ChownObjCmd --
 *     Implements the TCL chown command:
 *     chown [-fileid] userGrpSpec filelist
 *
 * The valid formats of userGrpSpec are:
 *   {owner}. {owner group} or {owner {}}
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *-----------------------------------------------------------------------------
 */
static int
TclX_ChownObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj      *CONST *objv;
{
    int        objIdx, ownerObjc, fileIds;
    Tcl_Obj  **ownerObjv = NULL;
    unsigned   options;
    char      *fileIdsSwitch;
    char      *owner, *group;
    int        groupStrLen;


    /*
     * Parse options.
     */
    fileIds = FALSE;
    for (objIdx = 1; objIdx < objc ; objIdx++) {
	fileIdsSwitch = Tcl_GetStringFromObj (objv[objIdx], NULL);
        if (fileIdsSwitch[0] != '-')
            break;
        if (STREQU (fileIdsSwitch, FILE_ID_OPT)) {
            fileIds = TRUE;
        } else {
            TclX_AppendObjResult (interp, "Invalid option \"", fileIdsSwitch,
                                  "\", expected \"", FILE_ID_OPT, "\"",
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }

    if (objIdx != objc - 2)
	return TclX_WrongArgs (interp, objv[0],
                          "[-fileid] user|{user group} filelist");
    /*
     * Parse the owner/group parameter.
     */
    if (Tcl_ListObjGetElements (interp, objv [objIdx], &ownerObjc,
				&ownerObjv) != TCL_OK)
        return TCL_ERROR;

    if ((ownerObjc < 1) || (ownerObjc > 2)) {
        TclX_AppendObjResult (interp,
                              "owner arg should be: user or {user group}",
                              (char *) NULL);
        goto errorExit;
    }
    options = TCLX_CHOWN;
    owner = Tcl_GetStringFromObj (ownerObjv [0], NULL);
    group = NULL;
    if (ownerObjc == 2) {
        options |= TCLX_CHGRP;
	group = Tcl_GetStringFromObj (ownerObjv [1], &groupStrLen);
        if (groupStrLen == 0)
            group = NULL;
    }

    /*
     * Finally, change ownership.
     */
    if (fileIds) {
        if (TclXOSFChangeOwnGrpObj (interp, options, owner, group,
				objv [objIdx + 1], "chown -fileid") != TCL_OK)
            goto errorExit;
    } else {
        if (TclXOSChangeOwnGrpObj (interp, options, owner, group,
			       objv [objIdx + 1], "chown") != TCL_OK)
            goto errorExit;
    }

    return TCL_OK;

  errorExit:
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * Tcl_ChgrpObjCmd --
 *     Implements the TCL chgrp command:
 *     chgrp [-fileid] group filelist
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */
static int
TclX_ChgrpObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    int        objIdx, fileIds;
    char      *fileIdsSwitch, *groupString;

    fileIds = FALSE;
    for (objIdx = 1; objIdx < objc; objIdx++) {
	fileIdsSwitch = Tcl_GetStringFromObj (objv [objIdx], NULL);
        if (fileIdsSwitch[0] != '-')
            break;
        if (STREQU (fileIdsSwitch, FILE_ID_OPT)) {
            fileIds = TRUE;
        } else {
            TclX_AppendObjResult (interp, "Invalid option \"", fileIdsSwitch,
                                  "\", expected \"", FILE_ID_OPT, "\"",
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }

    if (objIdx != objc - 2)
	return TclX_WrongArgs (interp, objv [0], "[-fileid] group filelist");

    groupString = Tcl_GetStringFromObj (objv [objIdx], NULL);
    
    if (fileIds) {
        if (TclXOSFChangeOwnGrpObj (interp, TCLX_CHGRP, NULL, groupString,
				objv [objIdx + 1], "chgrp - fileid") != TCL_OK)
            goto errorExit;
    } else {
        if (TclXOSChangeOwnGrpObj (interp, TCLX_CHGRP, NULL, groupString,
			       objv [objIdx + 1], "chgrp") != TCL_OK)
            goto errorExit;
    }

    return TCL_OK;

  errorExit:
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_ChmodInit --
 *     Initialize the chmod, chgrp and chown commands.
 *-----------------------------------------------------------------------------
 */
void
TclX_ChmodInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
			  "chgrp",
			  TclX_ChgrpObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "chmod",
			  TclX_ChmodObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
                          "chown",
			  TclX_ChownObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}

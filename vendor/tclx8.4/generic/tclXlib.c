/*
 * tclXlib.c --
 *
 * Tcl commands to load libraries of Tcl code.
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
 * $Id: tclXlib.c,v 1.5 2008/12/15 20:00:27 andreas_kupries Exp $
 *-----------------------------------------------------------------------------
 */

/*-----------------------------------------------------------------------------
 * The Extended Tcl library code is integrated with Tcl's by providing a
 * modified version of the Tcl auto_load proc that calls tclx_load_tndxs.
 * 
 * The following data structures are kept as Tcl variables so they can be
 * accessed from Tcl:
 *
 *   o auto_index - An array indexed by command name and contains code to
 *     execute to make the command available.  Normally contains either:
 *       "source file"
 *       "auto_pkg_load package"
 *   o auto_pkg_index - Indexed by package name.
 *-----------------------------------------------------------------------------
 */
#include "tclExtdInt.h"

/*
 * Names of Tcl variables that are used.
 */
static char *AUTO_INDEX     = "auto_index";
static char *AUTO_PKG_INDEX = "auto_pkg_index";

/*
 * Command to pass to Tcl_GlobalEval to load the file autoload.tcl.
 * This is a global rather than a local so it will work with K&R compilers.
 * Its writable so it works with gcc.
 */
#ifdef HAVE_TCL_STANDALONE
static char autoloadCmd [] =
"if [catch {source -rsrc autoload}] {\n\
    source [file join $tclx_library autoload.tcl]\n\
}";
#else
static char autoloadCmd [] =
    "source [file join $tclx_library autoload.tcl]";
#endif

/*
 * Indicates the type of library index.
 */
typedef enum {
    TCLLIB_TNDX,       /* *.tndx                    */
    TCLLIB_TND         /* *.tnd (.tndx in 8.3 land) */
} indexNameClass_t;

/*
 * Prototypes of internal functions.
 */
static int
EvalFilePart _ANSI_ARGS_((Tcl_Interp  *interp,
                          char        *fileName,
                          off_t        offset,
                          off_t        length));

static char *
MakeAbsFile _ANSI_ARGS_((Tcl_Interp  *interp,
                         char        *fileName,
                         Tcl_DString *absNamePtr));

static int
SetPackageIndexEntry _ANSI_ARGS_((Tcl_Interp *interp,
                                  CONST84 char *packageName,
                                  CONST84 char *fileName,
                                  off_t       offset,
                                  unsigned    length));

static int
GetPackageIndexEntry _ANSI_ARGS_((Tcl_Interp *interp,
                                  char       *packageName,
                                  char      **fileNamePtr,
                                  off_t      *offsetPtr,
                                  unsigned   *lengthPtr));

static int
SetProcIndexEntry _ANSI_ARGS_((Tcl_Interp *interp,
                               CONST84 char *procName,
                               CONST84 char *package));

static void
AddLibIndexErrorInfo _ANSI_ARGS_((Tcl_Interp *interp,
                                  char       *indexName));

static int
ProcessIndexFile _ANSI_ARGS_((Tcl_Interp *interp,
                              char       *tlibFilePath,
                              char       *tndxFilePath));

static int
BuildPackageIndex  _ANSI_ARGS_((Tcl_Interp *interp,
                                char       *tlibFilePath));

static int
LoadPackageIndex _ANSI_ARGS_((Tcl_Interp       *interp,
                              char             *tlibFilePath,
                              indexNameClass_t  indexNameClass));

static int
LoadDirIndexCallback _ANSI_ARGS_((Tcl_Interp  *interp,
                                  char        *dirPath,
                                  char        *fileName,
                                  int          caseSensitive,
                                  ClientData   clientData));

static int
LoadDirIndexes _ANSI_ARGS_((Tcl_Interp  *interp,
                            char        *dirName));

static int
TclX_load_tndxsObjCmd _ANSI_ARGS_((ClientData  clientData,
                                   Tcl_Interp *interp,
                                   int         objc,
                                   Tcl_Obj    *CONST objv[]));
                                   
static int
TclX_Auto_load_pkgObjCmd _ANSI_ARGS_((ClientData clientData, 
                                      Tcl_Interp *interp,
                                      int objc,
                                      Tcl_Obj *CONST objv[]));

static int
TclX_LoadlibindexObjCmd _ANSI_ARGS_((ClientData clientData, 
                                     Tcl_Interp *interp,
                                     int objc,
                                     Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * EvalFilePart --
 *
 *   Read in a byte range of a file and evaulate it.
 *
 * Parameters:
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o fileName - The file to evaulate.
 *   o offset - Byte offset into the file of the area to evaluate
 *   o length - Number of bytes to evaulate.
 *-----------------------------------------------------------------------------
 */
static int
EvalFilePart (interp, fileName, offset, length)
    Tcl_Interp  *interp;
    char        *fileName;
    off_t        offset;
    off_t        length;
{
    Interp *iPtr = (Interp *) interp;
    int result, major, minor;
    off_t fileSize;
    Tcl_DString pathBuf, cmdBuf;
    char *buf;
    Tcl_Channel channel = NULL;

    Tcl_ResetResult (interp);
    Tcl_DStringInit (&pathBuf);
    Tcl_DStringInit (&cmdBuf);

    fileName = Tcl_TranslateFileName (interp, fileName, &pathBuf);
    if (fileName == NULL)
        goto errorExit;

    channel = Tcl_OpenFileChannel (interp, fileName, "r", 0);
    if (channel == NULL)
        goto errorExit;

    if (TclXOSGetFileSize (channel, &fileSize) == TCL_ERROR)
        goto posixError;

    if ((fileSize < offset + length) || (offset < 0)) {
        TclX_AppendObjResult (interp,
                              "range to eval outside of file bounds in \"",
                              fileName, "\", index file probably corrupt",
                              (char *) NULL);
        goto errorExit;
    }

    if (Tcl_Seek (channel, offset, SEEK_SET) < 0)
        goto posixError;

    Tcl_DStringSetLength (&cmdBuf, length + 1);
    if (Tcl_Read (channel, cmdBuf.string, length) != length) {
        if (Tcl_Eof (channel))
            goto prematureEof;
        else
            goto posixError;
    }
    cmdBuf.string [length] = '\0';

    if (Tcl_Close (NULL, channel) != 0)
        goto posixError;
    channel = NULL;

    /*
     * The internal scriptFile element changed from char* to Tcl_Obj* in 8.4.
     */
    Tcl_GetVersion(&major, &minor, NULL, NULL);
    if ((major > 8) || (minor > 3)) {
	Tcl_Obj *oldScriptFile = (Tcl_Obj *) iPtr->scriptFile;
	Tcl_Obj *newobj = Tcl_NewStringObj(fileName, -1);
	Tcl_IncrRefCount(newobj);
	iPtr->scriptFile = (void *) newobj;
	result = Tcl_GlobalEval (interp, cmdBuf.string);
	iPtr->scriptFile = (void *) oldScriptFile;
	Tcl_DecrRefCount(newobj);
    } else {
	char *oldScriptFile = (char *) iPtr->scriptFile;
	iPtr->scriptFile = (void *) fileName;
	result = Tcl_GlobalEval (interp, cmdBuf.string);
	iPtr->scriptFile = (void *) oldScriptFile;
    }
    
    Tcl_DStringFree (&pathBuf);
    Tcl_DStringFree (&cmdBuf);

    if (result != TCL_ERROR) {
        return TCL_OK;
    }

    /*
     * An error occured in the command, record information telling where it
     * came from.
     */
    buf = ckalloc (strlen (fileName) + 64);
    sprintf (buf, "\n    (file \"%s\" line %d)", fileName,
             ERRORLINE(interp));
    Tcl_AddErrorInfo (interp, buf);
    ckfree (buf);
    goto errorExit;

    /*
     * Errors accessing the file once its opened are handled here.
     */
  posixError:
    TclX_AppendObjResult (interp, "error accessing: ", fileName, ": ",
                       Tcl_PosixError (interp), (char *) NULL);
    goto errorExit;

  prematureEof:
    TclX_AppendObjResult (interp, "premature EOF on: ", fileName,
                          (char *) NULL);
    goto errorExit;

  errorExit:
    if (channel != NULL)
        Tcl_Close (NULL, channel);
    Tcl_DStringFree (&pathBuf);
    Tcl_DStringFree (&cmdBuf);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * MakeAbsFile --
 *
 * Convert a file name to an absolute path.  This handles file name translation
 * and preappend the current directory name if the path is relative.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o fileName - File name (should not start with a "/").
 *   o absNamePtr - The name is returned in this dynamic string.  It
 *     should be initialized.
 * Returns:
 *   A pointer to the file name in the dynamic string or NULL if an error
 * occured.
 *-----------------------------------------------------------------------------
 */
static char *
MakeAbsFile (interp, fileName, absNamePtr)
    Tcl_Interp  *interp;
    char        *fileName;
    Tcl_DString *absNamePtr;
{
    char  *curDir;
    Tcl_DString joinBuf, cwdBuffer;

    Tcl_DStringSetLength (absNamePtr, 1);
    Tcl_DStringInit (&cwdBuffer);

    fileName = Tcl_TranslateFileName (interp, fileName, absNamePtr);
    if (fileName == NULL)
        goto errorExit;

    /*
     * If its already absolute.  If name translation didn't actually
     * copy the name to the buffer, we must do it now.
     */
    if (Tcl_GetPathType (fileName) == TCL_PATH_ABSOLUTE) {
        if (fileName != absNamePtr->string) {
            Tcl_DStringAppend (absNamePtr, fileName, -1);
        }
        return Tcl_DStringValue (absNamePtr);
    }

    /*
     * Otherwise its relative to the current directory, get the directory
     * and join into a path.
     */
    curDir = Tcl_GetCwd (interp, &cwdBuffer);
    if (curDir == NULL)
        goto errorExit;

    Tcl_DStringInit (&joinBuf);
    TclX_JoinPath (curDir, fileName, &joinBuf);
    Tcl_DStringSetLength (absNamePtr, 0);
    Tcl_DStringAppend (absNamePtr, joinBuf.string, -1);
    Tcl_DStringFree (&joinBuf);

    Tcl_DStringFree (&cwdBuffer);
    return Tcl_DStringValue (absNamePtr);

  errorExit:
    Tcl_DStringFree (&cwdBuffer);
    return NULL;
}

/*-----------------------------------------------------------------------------
 * SetPackageIndexEntry --
 *
 * Set a package entry in the auto_pkg_index array in the form:
 *
 *     auto_pkg_index($packageName) [list $filename $offset $length]
 *
 * Duplicate package entries are overwritten.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o packageName - Package name.
 *   o fileName - Absolute file name of the file containing the package.
 *   o offset - String containing the numeric start of the package.
 *   o length - String containing the numeric length of the package.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
SetPackageIndexEntry (interp, packageName, fileName, offset, length)
     Tcl_Interp *interp;
     CONST84 char *packageName;
     CONST84 char *fileName;
     off_t       offset;
     unsigned    length;
{
    Tcl_Obj *pkgDataObjv [3], *pkgDataPtr;

    /*
     * Build up the list of values to save.
     */
    pkgDataObjv [0] = Tcl_NewStringObj (fileName, -1);
    pkgDataObjv [1] = Tcl_NewIntObj ((int) offset);
    pkgDataObjv [2] = Tcl_NewIntObj ((int) length);
    pkgDataPtr = Tcl_NewListObj (3, pkgDataObjv);

    if (Tcl_SetVar2Ex(interp, AUTO_PKG_INDEX, packageName, pkgDataPtr,
                      TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG) == NULL) {
        Tcl_DecrRefCount (pkgDataPtr);
        return TCL_ERROR;
    }

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * GetPackageIndexEntry --
 *
 * Get a package entry from the auto_pkg_index array.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o packageName - Package name to find.
 *   o fileNamePtr - The file name for the library file is returned here.
 *     This should be freed by the caller.
 *   o offsetPtr - Start of the package in the library.
 *   o lengthPtr - Length of the package in the library.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
GetPackageIndexEntry (interp, packageName, fileNamePtr, offsetPtr, lengthPtr)
    Tcl_Interp *interp;
    char       *packageName;
    char      **fileNamePtr;
    off_t       *offsetPtr;
    unsigned   *lengthPtr;
{
    int   pkgDataObjc;
    Tcl_Obj **pkgDataObjv, *pkgDataPtr;
   
    /*
     * Look up the package entry in the array.
     */
    pkgDataPtr = Tcl_GetVar2Ex(interp, AUTO_PKG_INDEX, packageName,
                               TCL_GLOBAL_ONLY);
    if (pkgDataPtr == NULL) {
        TclX_AppendObjResult (interp, "entry not found in \"auto_pkg_index\"",
                              " for package \"", packageName, "\"",
                              (char *) NULL);
        goto errorExit;
    }

    /*
     * Extract the data from the array entry.
     */
    if (Tcl_ListObjGetElements (interp, pkgDataPtr,
                                &pkgDataObjc, &pkgDataObjv) != TCL_OK)
        goto invalidEntry;
    if (pkgDataObjc != 3)
        goto invalidEntry;

    if (TclX_GetOffsetFromObj (interp, pkgDataObjv [1], offsetPtr) != TCL_OK)
        goto invalidEntry;
    if (TclX_GetUnsignedFromObj (interp, pkgDataObjv [2], lengthPtr) != TCL_OK)
        goto invalidEntry;

    *fileNamePtr = Tcl_GetStringFromObj (pkgDataObjv [0], NULL);
    *fileNamePtr = ckstrdup (*fileNamePtr);

    return TCL_OK;
    
    /*
     * Exit point when an invalid entry is found.
     */
  invalidEntry:
    Tcl_ResetResult (interp);
    TclX_AppendObjResult (interp, "invalid entry in \"auto_pkg_index\"",
                          " for package \"", packageName, "\"",
                          (char *) NULL);
  errorExit:
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * SetProcIndexEntry --
 *
 * Set the proc entry in the auto_index array.  These entry contains a command
 * to make the proc available from a package.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o procName - The Tcl proc name.
 *   o package - Pacakge containing the proc.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
SetProcIndexEntry (interp, procName, package)
    Tcl_Interp *interp;
    CONST84 char *procName;
    CONST84 char *package;
{
    Tcl_DString  command;
    CONST84 char *result;

    Tcl_DStringInit (&command);
    Tcl_DStringAppendElement (&command, "auto_load_pkg");
    Tcl_DStringAppendElement (&command, package);

    result = Tcl_SetVar2 (interp, AUTO_INDEX, procName, command.string,
                          TCL_GLOBAL_ONLY | TCL_LEAVE_ERR_MSG);

    Tcl_DStringFree (&command);

    return (result == NULL) ? TCL_ERROR : TCL_OK;
}

/*-----------------------------------------------------------------------------
 * AddLibIndexErrorInfo --
 *
 * Add information to the error info stack about index that just failed.
 * This is generic for both tclIndex and .tlib indexs
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o indexName - The name of the index.
 *-----------------------------------------------------------------------------
 */
static void
AddLibIndexErrorInfo (interp, indexName)
    Tcl_Interp *interp;
    char       *indexName;
{
    char *msg;

    msg = ckalloc (strlen (indexName) + 60);
    strcpy (msg, "\n    while loading Tcl library index \"");
    strcat (msg, indexName);
    strcat (msg, "\"");
    Tcl_AddObjErrorInfo (interp, msg, -1);
    ckfree (msg);
}


/*-----------------------------------------------------------------------------
 * ProcessIndexFile --
 *
 * Open and process a package library index file (.tndx).  Creates entries
 * in the auto_index and auto_pkg_index arrays.  Existing entries are over
 * written.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o tlibFilePath - Absolute path name to the library file.
 *   o tndxFilePath - Absolute path name to the library file index.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ProcessIndexFile (interp, tlibFilePath, tndxFilePath)
     Tcl_Interp *interp;
     char       *tlibFilePath;
     char       *tndxFilePath;
{
    Tcl_Channel  indexChannel = NULL;
    Tcl_DString  lineBuffer;
    int          lineArgc, idx, result, tmpNum;
    CONST84 char **lineArgv = NULL;
    off_t        offset;
    unsigned     length;

    Tcl_DStringInit (&lineBuffer);

    indexChannel = Tcl_OpenFileChannel (interp, tndxFilePath, "r", 0);
    if (indexChannel == NULL)
        return TCL_ERROR;
    
    while (TRUE) {
        Tcl_DStringSetLength (&lineBuffer, 0);
        if (Tcl_Gets (indexChannel, &lineBuffer) < 0) {
            if (Tcl_Eof (indexChannel))
                goto reachedEOF;
            else
                goto fileError;
        }

        if ((Tcl_SplitList (interp, lineBuffer.string, &lineArgc,
                            &lineArgv) != TCL_OK) || (lineArgc < 4))
            goto formatError;
        
        /*
         * lineArgv [0] is the package name.
         * lineArgv [1] is the package offset in the library.
         * lineArgv [2] is the package length in the library.
         * lineArgv [3-n] are the entry procedures for the package.
         */
        if (Tcl_GetInt (interp, lineArgv [1], &tmpNum) != TCL_OK)
            goto errorExit;
        if (tmpNum < 0)
            goto formatError;
        offset = (off_t) tmpNum;

        if (Tcl_GetInt (interp, lineArgv [2], &tmpNum) != TCL_OK)
            goto errorExit;
        if (tmpNum < 0)
            goto formatError;
        length = (unsigned) tmpNum;

        result = SetPackageIndexEntry (interp, lineArgv [0], tlibFilePath,
                                       offset, length);
        if (result == TCL_ERROR)
            goto errorExit;

        /*
         * If the package is not duplicated, add the commands to load
         * the procedures.
         */
        if (result != TCL_CONTINUE) {
            for (idx = 3; idx < lineArgc; idx++) {
                if (SetProcIndexEntry (interp, lineArgv [idx],
                                       lineArgv [0]) != TCL_OK)
                    goto errorExit;
            }
        }
        ckfree ((char *) lineArgv);
        lineArgv = NULL;
    }

  reachedEOF:
    Tcl_DStringFree (&lineBuffer);    
    if (Tcl_Close (NULL, indexChannel) != TCL_OK)
        goto fileError;

    return TCL_OK;

    /*
     * Handle format error in library input line.
     */
  formatError:
    Tcl_ResetResult (interp);
    TclX_AppendObjResult (interp, "format error in library index \"",
                          tndxFilePath, "\" (", lineBuffer.string, ")",
                          (char *) NULL);
    goto errorExit;

  fileError:
    TclX_AppendObjResult (interp, "error accessing package index file \"",
                          tndxFilePath, "\": ", Tcl_PosixError (interp),
                          (char *) NULL);
    goto errorExit;

    /*
     * Error exit here, releasing resources and closing the file.
     */
  errorExit:
    if (lineArgv != NULL)
        ckfree ((char *) lineArgv);
    Tcl_DStringFree (&lineBuffer);
    if (indexChannel != NULL)
        Tcl_Close (NULL, indexChannel);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * BuildPackageIndex --
 *
 * Call the "buildpackageindex" Tcl procedure to rebuild a package index.
 * This is found in the directory pointed to by the $tclx_library variable.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o tlibFilePath - Absolute path name to the library file.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
BuildPackageIndex (interp, tlibFilePath)
     Tcl_Interp *interp;
     char       *tlibFilePath;
{
    Tcl_DString  command;
    int          result;

    Tcl_DStringInit (&command);

    Tcl_DStringAppend (&command, 
		       "if [catch {source -rsrc buildidx}] {source [file join $tclx_library buildidx.tcl]};", -1);
    Tcl_DStringAppend (&command, "buildpackageindex ", -1);
    Tcl_DStringAppend (&command, tlibFilePath, -1);

    result = Tcl_GlobalEval (interp, command.string);

    Tcl_DStringFree (&command);

    if (result == TCL_ERROR)
        return TCL_ERROR;
    Tcl_ResetResult (interp);
    return result;
}

/*-----------------------------------------------------------------------------
 * LoadPackageIndex --
 *
 * Load a package .tndx file.  Rebuild .tndx if non-existant or out of
 * date.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o tlibFilePath - Absolute path name to the library file.
 *   o indexNameClass - TCLLIB_TNDX if the index file should the suffix
 *     ".tndx" or TCLLIB_TND if it should have ".tnd".
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
LoadPackageIndex (interp, tlibFilePath, indexNameClass)
    Tcl_Interp       *interp;
    char             *tlibFilePath;
    indexNameClass_t  indexNameClass;
{
    Tcl_DString tndxFilePath;

    struct stat  tlibStat;
    struct stat  tndxStat;

    Tcl_DStringInit (&tndxFilePath);

    /*
     * Modify library file path to be the index file path.
     */
    Tcl_DStringAppend (&tndxFilePath, tlibFilePath, -1);
    tndxFilePath.string [tndxFilePath.length - 3] = 'n';
    tndxFilePath.string [tndxFilePath.length - 2] = 'd';
    if (indexNameClass == TCLLIB_TNDX)
        tndxFilePath.string [tndxFilePath.length - 1] = 'x';

    /*
     * Get library's modification time.  If the file can't be accessed, set
     * time so the library does not get built.  Other code will report the
     * error.
     */
    if (stat (tlibFilePath, &tlibStat) < 0)
        tlibStat.st_mtime = MAXINT;

    /*
     * Get the time for the index.  If the file does not exists or is
     * out of date, rebuild it.
     */
    if ((stat (tndxFilePath.string, &tndxStat) < 0) ||
        (tndxStat.st_mtime < tlibStat.st_mtime)) {
        if (BuildPackageIndex (interp, tlibFilePath) != TCL_OK)
            goto errorExit;
    }

    if (ProcessIndexFile (interp, tlibFilePath, tndxFilePath.string) != TCL_OK)
        goto errorExit;
    Tcl_DStringFree (&tndxFilePath);
    return TCL_OK;

  errorExit:
    AddLibIndexErrorInfo (interp, tndxFilePath.string);
    Tcl_DStringFree (&tndxFilePath);

    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * LoadDirIndexCallback --
 *
 *   Function called for every directory entry for LoadDirIndexes.
 *
 * Parameters
 *   o interp - Interp is passed though.
 *   o dirPath - Normalized path to directory.
 *   o fileName - Tcl normalized file name in directory.
 *   o caseSensitive - Are the file names case sensitive?  Always
 *     TRUE on Unix.
 *   o clientData - Pointer to a boolean that is set to TRUE if an error
 *     occures while porocessing the index file.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
LoadDirIndexCallback (interp, dirPath, fileName, caseSensitive, clientData)
    Tcl_Interp  *interp;
    char        *dirPath;
    char        *fileName;
    int          caseSensitive;
    ClientData   clientData;
{
    int *indexErrorPtr = (int *) clientData;
    int nameLen;
    char *chkName;
    indexNameClass_t indexNameClass;
    Tcl_DString chkNameBuf, filePath;

    /*
     * If the volume not case sensitive, convert the name to lower case.
     */
    Tcl_DStringInit (&chkNameBuf);
    chkName = fileName;
    if (!caseSensitive) {
        chkName = Tcl_DStringAppend (&chkNameBuf, fileName, -1);
        TclX_DownShift (chkName, chkName);
    }

    /*
     * Figure out if its an index file.
     */
    nameLen = strlen (chkName);
    if ((nameLen > 5) && STREQU (chkName + nameLen - 5, ".tlib")) {
        indexNameClass = TCLLIB_TNDX;
    } else if ((nameLen > 4) && STREQU (chkName + nameLen - 4, ".tli")) {
        indexNameClass = TCLLIB_TND;
    } else {
        Tcl_DStringFree (&chkNameBuf);
        return TCL_OK;  /* Not an index, skip */
    }
    Tcl_DStringFree (&chkNameBuf);

    /*
     * Assemble full path to library file.
     */
    Tcl_DStringInit (&filePath);
    TclX_JoinPath (dirPath, fileName, &filePath);

    /*
     * Skip index it can't be accessed.
     */
    if (access (filePath.string, R_OK) < 0)
        goto exitPoint;

    /*
     * Process the index according to its type.
     */
    if (LoadPackageIndex (interp, filePath.string,
                          indexNameClass) != TCL_OK)
        goto errorExit;

  exitPoint:
    Tcl_DStringFree (&filePath);
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&filePath);
    *indexErrorPtr = TRUE;
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * LoadDirIndexes --
 *
 *     Load the indexes for all package library (.tlib) or a Ousterhout
 *  "tclIndex" file in a directory.  Nonexistent or unreadable directories
 *  are skipped.
 *
 * Parameters
 *   o interp - A pointer to the interpreter, error returned in result.
 *   o dirName - The absolute path name of the directory to search for
 *     libraries.
 *-----------------------------------------------------------------------------
 */
static int
LoadDirIndexes (interp, dirName)
    Tcl_Interp  *interp;
    char        *dirName;
{
    int indexError = FALSE;

    /*
     * This is a little tricky.  We want to skip directories we can't read,
     * read, but if we get an error processing an index, we want
     * to report it.  A boolean is passed in to indicate if the error
     * returned involved parsing the file.
     */
    if (TclXOSWalkDir (interp, dirName, FALSE, /* hidden */
                       LoadDirIndexCallback,
                       (ClientData) &indexError) == TCL_ERROR) {
        if (!indexError) {
            Tcl_ResetResult (interp);
            return TCL_OK;
        }
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_load_tndxsObjCmd --
 *
 *   Implements the command:
 *      tclx_load_tndxs dir
 *
 * Which is called from auto_load to load a .tndx files in a directory.
 *-----------------------------------------------------------------------------
 */
static int
TclX_load_tndxsObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    char *dirname;

    if (objc != 2) {
        return TclX_WrongArgs (interp, objv [0], "dir");
    }
    dirname = Tcl_GetStringFromObj (objv[1], NULL);
    return LoadDirIndexes (interp, dirname);
}

/*-----------------------------------------------------------------------------
 * TclX_Auto_load_pkgObjCmd --
 *
 *   Implements the command:
 *      auto_load_pkg package
 *
 * Which is called to load a .tlib package who's index has already been loaded.
 *-----------------------------------------------------------------------------
 */
static int
TclX_Auto_load_pkgObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    char     *fileName;
    off_t     offset;
    unsigned  length;
    int       result;

    if (objc != 2) {
        return TclX_WrongArgs (interp, objv [0], "package");
    }

    if (GetPackageIndexEntry (interp, Tcl_GetStringFromObj (objv [1], NULL),
                              &fileName, &offset, &length) != TCL_OK)
        return TCL_ERROR;

    result = EvalFilePart (interp, fileName, offset, length);
    ckfree (fileName);

    return result;
}

/*-----------------------------------------------------------------------------
 * TclX_LoadlibindexObjCmd --
 *
 *   This procedure is invoked to process the "Loadlibindex" Tcl command:
 *
 *      loadlibindex libfile
 *
 * which loads the index for a package library (.tlib) or a Ousterhout
 * "tclIndex" file.  New package definitions will override existing ones.
 *-----------------------------------------------------------------------------
 */
static int
TclX_LoadlibindexObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    char        *pathName;
    Tcl_DString  pathNameBuf;
    int          pathLen;

    Tcl_DStringInit (&pathNameBuf);

    if (objc != 2) {
        return TclX_WrongArgs (interp, objv [0], "libFile");
    }

    pathName = MakeAbsFile (interp,
                            Tcl_GetStringFromObj (objv [1], NULL),
                            &pathNameBuf);
    if (pathName == NULL)
        return TCL_ERROR;

    /*
     * Find the length of the directory name. Validate that we have a .tlib
     * extension or file name is "tclIndex" and call the routine to process
     * the specific type of index.
     */
    pathLen = strlen (pathName);

    if ((pathLen > 5) && STREQU (pathName + pathLen - 5, ".tlib")) {
        if (LoadPackageIndex (interp, pathName, TCLLIB_TNDX) != TCL_OK)
            goto errorExit;
    } else if ((pathLen > 4) && STREQU (pathName + pathLen - 4, ".tli")) {
        if (LoadPackageIndex (interp, pathName, TCLLIB_TND) != TCL_OK)
            goto errorExit;
    } else {
        TclX_AppendObjResult (interp, "invalid library name, must have ",
                              "an extension of \".tlib\", or \".tli\", got \"",
                              Tcl_GetStringFromObj (objv [1], NULL), "\"",
                              (char *) NULL);
        goto errorExit;
    }

    Tcl_DStringFree (&pathNameBuf);
    return TCL_OK;

  errorExit:
    Tcl_DStringFree (&pathNameBuf);
    return TCL_ERROR;;
}

/*-----------------------------------------------------------------------------
 * TclX_LibraryInit --
 *
 *   Initialize the Extended Tcl library facility commands.
 *-----------------------------------------------------------------------------
 */
int
TclX_LibraryInit (interp)
    Tcl_Interp *interp;
{
    int result;

    /* Hack in our own auto-loading */
    result = Tcl_EvalEx(interp, autoloadCmd, -1, TCL_EVAL_GLOBAL);
    if (result == TCL_ERROR) {
        return TCL_ERROR;
    }
    
    Tcl_CreateObjCommand (interp, "tclx_load_tndxs",
                          TclX_load_tndxsObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
    Tcl_CreateObjCommand (interp, "auto_load_pkg",
                          TclX_Auto_load_pkgObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
    Tcl_CreateObjCommand (interp, "loadlibindex",
                          TclX_LoadlibindexObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_ResetResult (interp);
    return TCL_OK;
}

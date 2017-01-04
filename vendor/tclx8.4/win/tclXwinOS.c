/*
 * tclXwinOS.c --
 *
 * OS system dependent interface for Windows systems.  The idea behind these
 * functions is to provide interfaces to various functions that vary on the
 * various platforms.  These functions either implement the call in a manner
 * approriate to the platform or return an error indicating the functionality
 * is not available on that platform.  This results in code with minimal
 * number of #ifdefs.
 *-----------------------------------------------------------------------------
 * Copyright 1996-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXwinOS.c,v 1.8 2005/07/12 19:03:15 hobbs Exp $
 *-----------------------------------------------------------------------------
 * The code for reading directories is based on TclMatchFiles from the Tcl
 * distribution file win/tclWinFile.c
 * Copyright (c) 1995 Sun Microsystems, Inc.
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

typedef enum {
    TCLX_WIN_CONSOLE,
    TCLX_WIN_FILE,
    TCLX_WIN_PIPE,
    TCLX_WIN_SOCKET
} tclXwinFileType;


/*-----------------------------------------------------------------------------
 * TclXNotAvailableError --
 *   Return an error about functionality not being available under Windows.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o funcName - Command or other name to use in not available error.
 * Returns:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXNotAvailableError (Tcl_Interp *interp,
                       char       *funcName)
{
    Tcl_AppendResult(interp, funcName, " is not available on MS Windows",
	    (char *) NULL);
    return TCL_ERROR;
}
int
TclXNotAvailableObjError (Tcl_Interp *interp,
			  Tcl_Obj *obj)
{
    char *funcName = Tcl_GetStringFromObj(obj, NULL);

    Tcl_AppendResult(interp, funcName, " is not available on MS Windows",
	    (char *) NULL);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_SplitWinCmdLine --
 *   Parse the window command line into arguments.
 *
 * Parameters:
 *   o argcPtr - Count of arguments is returned here.
 *   o argvPtr - Argument vector is returned here.
 * Notes:
 *   This code taken from the Tcl file tclAppInit.c: Copyright (c) 1996 by
 * Sun Microsystems, Inc.
 *-----------------------------------------------------------------------------
 */

/*
 *-------------------------------------------------------------------------
 *
 * setargv --
 *
 *	Parse the Windows command line string into argc/argv.  Done here
 *	because we don't trust the builtin argument parser in crt0.  
 *	Windows applications are responsible for breaking their command
 *	line into arguments.
 *
 *	2N backslashes + quote -> N backslashes + begin quoted string
 *	2N + 1 backslashes + quote -> literal
 *	N backslashes + non-quote -> literal
 *	quote + quote in a quoted string -> single quote
 *	quote + quote not in quoted string -> empty string
 *	quote -> begin quoted string
 *
 * Results:
 *	Fills argcPtr with the number of arguments and argvPtr with the
 *	array of arguments.
 *
 * Side effects:
 *	Memory allocated.
 *
 *--------------------------------------------------------------------------
 */
void
TclX_SplitWinCmdLine (int    *argcPtr,
                      char ***argvPtr)
{
    char *cmdLine, *p, *arg, *argSpace;
    char **argv;
    int argc, size, inquote, copy, slashes;
    
    cmdLine = GetCommandLine();

    /*
     * Precompute an overly pessimistic guess at the number of arguments
     * in the command line by counting non-space spans.
     */

    size = 2;
    for (p = cmdLine; *p != '\0'; p++) {
	if (isspace(*p)) {
	    size++;
	    while (isspace(*p)) {
		p++;
	    }
	    if (*p == '\0') {
		break;
	    }
	}
    }
    argSpace = (char *) ckalloc((unsigned) (size * sizeof(char *) 
	    + strlen(cmdLine) + 1));
    argv = (char **) argSpace;
    argSpace += size * sizeof(char *);
    size--;

    p = cmdLine;
    for (argc = 0; argc < size; argc++) {
	argv[argc] = arg = argSpace;
	while (isspace(*p)) {
	    p++;
	}
	if (*p == '\0') {
	    break;
	}

	inquote = 0;
	slashes = 0;
	while (1) {
	    copy = 1;
	    while (*p == '\\') {
		slashes++;
		p++;
	    }
	    if (*p == '"') {
		if ((slashes & 1) == 0) {
		    copy = 0;
		    if ((inquote) && (p[1] == '"')) {
			p++;
			copy = 1;
		    } else {
			inquote = !inquote;
		    }
                }
                slashes >>= 1;
            }

            while (slashes) {
		*arg = '\\';
		arg++;
		slashes--;
	    }

	    if ((*p == '\0') || (!inquote && isspace(*p))) {
		break;
	    }
	    if (copy != 0) {
		*arg = *p;
		arg++;
	    }
	    p++;
        }
	*arg = '\0';
	argSpace = arg + 1;
    }
    argv[argc] = NULL;

    *argcPtr = argc;
    *argvPtr = argv;
}


/*-----------------------------------------------------------------------------
 * ChannelToHandle --
 *
 *    Convert a channel to a handle.
 *
 * Parameters:
 *   o channel - Channel to get file number for.
 *   o direction - TCL_READABLE or TCL_WRITABLE, or zero.  If zero, then
 *     return the first of the read and write numbers.
 *   o type - The type of the file. not set if an error occurs.
 *
 * Returns:
 *   The file handle or INVALID_HANDLE_VALUE if a HANDLE is not associated 
 * with this access direction, or if the channel does not have a HANDLE
 * of the Windows variety. We hope that the channel driver does not return
 * a HANDLE that we cannot use.
 *-----------------------------------------------------------------------------
 */
static HANDLE
ChannelToHandle (Tcl_Channel		channel,
                 int         		direction,
                 tclXwinFileType	*typePtr)
{
    ClientData handle;
    int	sockType;
    int	sockTypeLen = sizeof(sockType);
    
    if (direction == 0) {
        if (Tcl_GetChannelHandle (channel, TCL_READABLE, &handle) != TCL_OK &&
	    Tcl_GetChannelHandle (channel, TCL_WRITABLE, &handle) != TCL_OK) {
	    handle = INVALID_HANDLE_VALUE;
	}
    } else {
        if (Tcl_GetChannelHandle (channel, direction, &handle) != TCL_OK) {
	    handle = INVALID_HANDLE_VALUE;
	}
    }

    /*
     * Call GetFileType() even on invalid handles to set errno,
     * also will coerce INVALID_SOCKET to INVALID_HANDLE,  they
     * may not be the same on some machines.
     */
    switch (GetFileType ((HANDLE) handle)) {
	case FILE_TYPE_DISK:
	    *typePtr = TCLX_WIN_FILE;
	    break;
	case FILE_TYPE_CHAR:
	    *typePtr = TCLX_WIN_CONSOLE;
	    break;
	case FILE_TYPE_PIPE:
	    if (getsockopt ((SOCKET)handle, SOL_SOCKET, SO_TYPE, 
			    (void *)&sockType, &sockTypeLen) == 0) {
		*typePtr = TCLX_WIN_SOCKET;
	    } else {
		*typePtr = TCLX_WIN_PIPE;
	    }
	    break;
	case FILE_TYPE_UNKNOWN:
	    handle = INVALID_HANDLE_VALUE;
	    break;
    }
    
    return (HANDLE) handle;
}

/*-----------------------------------------------------------------------------
 * ChannelToSocket --
 *
 *    Convert a channel to a socket.
 *
 * Parameters:
 *   o interp - An error is returned if the channel is not a socket.
 *   o channel - Channel to get file number for.
 * Returns:
 *   The socket number or INVALID_SOCKET if an error occurs.
 *-----------------------------------------------------------------------------
 */
static SOCKET
ChannelToSocket (Tcl_Interp  *interp,
                 Tcl_Channel  channel)
{
    ClientData handle;
    tclXwinFileType type;

    handle = ChannelToHandle(channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE || type != TCLX_WIN_SOCKET) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" is not a socket", (char *) NULL);
        return INVALID_SOCKET;
    }

    return (SOCKET) handle;
}

/*-----------------------------------------------------------------------------
 * ConvertToUnixTime --
 *
 *    Convert a FILETIME structure to Unix style time.
 *
 * Parameters:
 *   o fileTime - Time to convert.
 * Returns:
 *   Unix time: seconds since Jan 1, 1970.
 *-----------------------------------------------------------------------------
 */
static time_t
ConvertToUnixTime (FILETIME fileTime)
{
    /* FIX: Write me */
    return 0;
}

/*-----------------------------------------------------------------------------
 * TclXOSgetpriority --
 *   System dependent interface to getpriority functionality, which is not
 * available* on windows.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o priority - Process priority is returned here.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSgetpriority (Tcl_Interp *interp,
                   int        *priority,
                   char       *funcName)
{
    /*FIX: this should work */
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSincrpriority--
 *   System dependent interface to increment or decrement the current priority,
 * which is not available on windows.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o priorityIncr - Amount to adjust the priority by.
 *   o priority - The new priority..
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSincrpriority (Tcl_Interp *interp,
                    int         priorityIncr,
                    int        *priority,
                    char       *funcName)
{
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSpipe --
 *   System dependent interface to create a pipes for the pipe command.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o channels - Two element array to return read and write channels in.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSpipe (interp, channels)
    Tcl_Interp  *interp;
    Tcl_Channel *channels;
{
    HANDLE readHandle, writeHandle;
    SECURITY_ATTRIBUTES sec;

    sec.nLength = sizeof(SECURITY_ATTRIBUTES);
    sec.lpSecurityDescriptor = NULL;
    sec.bInheritHandle = FALSE;

    if (!CreatePipe (&readHandle, &writeHandle, &sec, 0)) {
	TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "pipe creation failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    channels [0] = Tcl_MakeFileChannel ((ClientData) readHandle,
                                        TCL_READABLE);
    Tcl_RegisterChannel (interp, channels [0]);

    channels [1] = Tcl_MakeFileChannel ((ClientData) writeHandle,
                                        TCL_WRITABLE);
    Tcl_RegisterChannel (interp, channels [1]);

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSsetitimer --
 *   System dependent interface to setitimer functionality, which is not
 * available on windows.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o seconds (I/O) - Seconds to pause for, it is updated with the time
 *     remaining on the last alarm.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSsetitimer (Tcl_Interp *interp,
                 double      *seconds,
                 char       *funcName)
{
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSsleep --
 *   System dependent interface to sleep functionality.
 *
 * Parameters:
 *   o seconds - Seconds to sleep.
 *-----------------------------------------------------------------------------
 */
void
TclXOSsleep (unsigned seconds)
{
    Tcl_Sleep(seconds*1000);
}

/*-----------------------------------------------------------------------------
 * TclXOSsync --
 *   System dependent interface to sync functionality.
 *-----------------------------------------------------------------------------
 */
void
TclXOSsync ()
{
    _flushall ();
}

/*-----------------------------------------------------------------------------
 * TclXOSfsync --
 *   System dependent interface to fsync functionality.  Does a _flushall,
 * since fsync is not available.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o channel - The channel to sync.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSfsync (Tcl_Interp *interp,
             Tcl_Channel channel)
{
    if (Tcl_Flush (channel) < 0)
        goto posixError;

    _flushall ();
    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSsystem --
 *   System dependent interface to system functionality (executing a command
 * with the standard system shell).
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o command - Command to execute.
 *   o exitCode - Exit code of the child process.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSsystem (Tcl_Interp *interp,
              char       *command,
              int        *exitCode)
{
    PROCESS_INFORMATION pi;
    STARTUPINFO si;
    BOOL bSuccess;

    memset (&si, 0, sizeof (si));

    bSuccess = CreateProcess (command,
                              NULL, NULL, NULL,
                              0,
                              CREATE_NEW_PROCESS_GROUP,
                              NULL, NULL,
                              &si, &pi);
    if (!bSuccess) {
        TclX_AppendObjResult (interp, "process creation failed",
                              (char *) NULL);
        return TCL_ERROR;
    }
    CloseHandle (pi.hThread);
    WaitForSingleObject (pi.hProcess, INFINITE);
    GetExitCodeProcess (pi.hProcess, exitCode);
    CloseHandle (pi.hProcess);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_OSlink --
 *
 *   System dependent interface to link functionality, which is not
 *   available on windows.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o srcPath - File to link.
 *   o targetPath - Path to new link.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_OSlink (Tcl_Interp *interp,
             char       *srcPath,
             char       *targetPath,
             char       *funcName)
{
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclX_OSsymlink --
 *   System dependent interface to symlink functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o srcPath - Value of symbolic link.
 *   o targetPath - Path to new symbolic link.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_OSsymlink (Tcl_Interp *interp,
                char       *srcPath,
                char       *targetPath,
                char       *funcName)
{
    /* FIX: make an alias */
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSElapsedTime --
 *   System dependent interface to get the elapsed CPU and real time.  CPU time
 * is not available under windows and zero is always returned.
 *
 * Parameters:
 *   o realTime - Elapsed real time, in milliseconds is returned here.
 *   o cpuTime - Elapsed CPU time, zero is always returned.
 *-----------------------------------------------------------------------------
 */
void
TclXOSElapsedTime (clock_t *realTime,
                   clock_t *cpuTime)
{
    static DWORD startTime = 0;
  
    /*
     * If this is the first call, get base time.
     */
    if (startTime == 0) {
	startTime = GetTickCount ();
    }
    *realTime = GetTickCount () - startTime;
    *cpuTime = 0;
}

/*-----------------------------------------------------------------------------
 * TclXOSkill --
 *   System dependent interface to terminate a process.  Apparently,
 *   it's not possible to send a specific signal in windows?
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o pid - Process id, negative process group, etc.
 *   o signal - Signal to send.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSkill (Tcl_Interp *interp,
            pid_t       pid,
            int         signal,
            char       *funcName)
{
    HANDLE processHandle;

    processHandle = OpenProcess(PROCESS_TERMINATE, FALSE, (int) pid);
    if (processHandle == NULL) {
	Tcl_AppendResult(interp, "invalid pid", (char *) NULL);
	return TCL_ERROR;
    }

    TerminateProcess(processHandle, 7);
    CloseHandle(processHandle);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSFstat --
 *   System dependent interface to get status information on an open file.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channel - Channel to get file number for.
 *   o statBuf - Status information, made to look as much like Unix as
 *     possible.
 *   o ttyDev - If not NULL, a boolean indicating if the device is
 *     associated with a tty. (Always FALSE on windows).
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSFstat (Tcl_Interp  *interp,
             Tcl_Channel  channel,
             struct stat *statBuf,
             int         *ttyDev)
{
    HANDLE handle;
    tclXwinFileType type;
    FILETIME creation, access, modify;

    /* FIX: More of this information is availiable from
     *      GetFileInformationByHandle
     */

    handle = ChannelToHandle (channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" has no device handle", (char *) NULL);
	return TCL_ERROR;
    }

    /*
     * These don't translate to windows.
     */
    statBuf->st_dev = 0;
    statBuf->st_ino = 0;
    statBuf->st_rdev = 0;

    statBuf->st_mode = 0;
    switch (type) {
      case TCLX_WIN_PIPE:
        statBuf->st_mode |= S_IFIFO;
        break;
      case TCLX_WIN_FILE:
        statBuf->st_mode |= S_IFREG;
        break;
      case TCLX_WIN_SOCKET:
        statBuf->st_mode |= S_IFSOCK;
        break;
      case TCLX_WIN_CONSOLE:
        statBuf->st_mode |= S_IFCHR;
        break;
    }        

    statBuf->st_nlink = (type == TCLX_WIN_FILE) ? 1 : 0;
    statBuf->st_uid = 0;   /* FIX??? */
    statBuf->st_gid = 0;

    switch (type) {
      case TCLX_WIN_FILE:
      case TCLX_WIN_PIPE:
        statBuf->st_size = GetFileSize (handle, NULL);
        if (statBuf->st_size < 0)
            goto winError;

        if (!GetFileTime (handle, &creation, &access, &modify)) {
            goto winError;
        }
        statBuf->st_atime = ConvertToUnixTime (creation);
        statBuf->st_mtime = ConvertToUnixTime (access);
        statBuf->st_ctime = ConvertToUnixTime (modify);
        break;

      case TCLX_WIN_SOCKET:
      case TCLX_WIN_CONSOLE:
        statBuf->st_size = 0;
        statBuf->st_atime = 0;
        statBuf->st_mtime = 0;
        statBuf->st_ctime = 0;
        break;
    }        

    if (ttyDev != NULL)
        *ttyDev = (type == TCLX_WIN_CONSOLE) ? 1 : 0;
    return TCL_OK;

  winError:
    TclWinConvertError (GetLastError ());
    TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;

}

/*-----------------------------------------------------------------------------
 * TclXOSWalkDir --
 *   System dependent interface to reading the contents of a directory.  The
 * specified directory is walked and a callback is called on each entry.
 * The "." and ".." entries are skipped.
 *
 * Parameters:
 *   o interp - Interp to return errors in.
 *   o path - Path to the directory.
 *   o hidden - Include hidden files.  Ignored on Unix.
 *   o callback - Callback function to call on each directory entry.
 *     It should return TCL_OK to continue processing, TCL_ERROR if an
 *     error occured and TCL_BREAK to stop processing.  The parameters are:
 *        o interp - Interp is passed though.
 *        o path - Normalized path to directory.
 *        o fileName - Tcl normalized file name in directory.
 *        o caseSensitive - Are the file names case sensitive?
 *        o clientData - Client data that was passed.
 *   o clientData - Client data to pass to callback.
 * Results:
 *   TCL_OK if completed directory walk.  TCL_BREAK if callback returned
 * TCL_BREAK and TCL_ERROR if an error occured.
 *-----------------------------------------------------------------------------
 */
int
TclXOSWalkDir (Tcl_Interp       *interp,
               char             *path,
               int               hidden,
               TclX_WalkDirProc *callback,
               ClientData        clientData)
{
    char drivePattern[4] = "?:\\";
    char *p, *dir, *root, c;
    int result = TCL_OK;
    Tcl_DString pathBuf;
    DWORD atts, volFlags;
    HANDLE handle;
    WIN32_FIND_DATA data;
    BOOL found;

    /*
     * Convert the path to normalized form since some interfaces only
     * accept backslashes.  Also, ensure that the directory ends with a
     * separator character.
     */
    Tcl_DStringInit (&pathBuf);
    Tcl_DStringAppend (&pathBuf, path, -1);
    if (Tcl_DStringLength (&pathBuf) == 0) {
        Tcl_DStringAppend (&pathBuf, ".", 1);
    }
    for (p = Tcl_DStringValue( &pathBuf); *p != '\0'; p++) {
        if (*p == '/') {
            *p = '\\';
        }
    }
    p--;
    if (*p != '\\' && *p != ':') {
        Tcl_DStringAppend(&pathBuf, "\\", 1);
    }
    dir = Tcl_DStringValue(&pathBuf);
    
    /*
     * First verify that the specified path is actually a directory.
     */
    atts = GetFileAttributes (dir);
    if ((atts == 0xFFFFFFFF) || ((atts & FILE_ATTRIBUTE_DIRECTORY) == 0)) {
        Tcl_DStringFree (&pathBuf);
        return TCL_OK;
    }

    /*
     * Next check the volume information for the directory to see whether
     * comparisons should be case sensitive or not.  If the root is null, then
     * we use the root of the current directory.  If the root is just a drive
     * specifier, we use the root directory of the given drive.
     */
    switch (Tcl_GetPathType (dir)) {
      case TCL_PATH_RELATIVE:
        found = GetVolumeInformation (NULL, NULL, 0, NULL,
                                      NULL, &volFlags, NULL, 0);
        break;
      case TCL_PATH_VOLUME_RELATIVE:
        if (*dir == '\\') {
            root = NULL;
        } else {
            root = drivePattern;
            *root = *dir;
        }
        found = GetVolumeInformation (root, NULL, 0, NULL,
                                      NULL, &volFlags, NULL, 0);
        break;
      case TCL_PATH_ABSOLUTE:
        if (dir[1] == ':') {
            root = drivePattern;
            *root = *dir;
            found = GetVolumeInformation (root, NULL, 0, NULL,
                                          NULL, &volFlags, NULL, 0);
        } else if (dir[1] == '\\') {
            p = strchr(dir+2, '\\');
            p = strchr(p+1, '\\');
            p++;
            c = *p;
            *p = 0;
            found = GetVolumeInformation (dir, NULL, 0, NULL,
                                          NULL, &volFlags, NULL, 0);
            *p = c;
        }
        break;
    }

    if (!found) {
        Tcl_DStringFree (&pathBuf);
        TclWinConvertError (GetLastError ());
        Tcl_ResetResult (interp);
        TclX_AppendObjResult (interp,
                              "couldn't read volume information for \"",
                              path, "\": ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * We need to check all files in the directory, so append a *.*
     * to the path. 
     */
    dir = Tcl_DStringAppend (&pathBuf, "*.*", 3);

    /*
     * Now open the directory for reading and iterate over the contents.
     */
    handle = FindFirstFile (dir, &data);
    Tcl_DStringFree (&pathBuf);

    if (handle == INVALID_HANDLE_VALUE) {
        TclWinConvertError (GetLastError ());
        Tcl_ResetResult (interp);
        TclX_AppendObjResult (interp, "couldn't read directory \"",
                              path, "\": ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Now iterate over all of the files in the directory.
     */
    for (found = 1; found; found = FindNextFile (handle, &data)) {
        /*
         * Ignore hidden files if not requested.
         */
        if ((data.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN) && !hidden)
            continue;

        /*
         * Skip "." and "..".
         */
        if (STREQU (data.cFileName, ".") || STREQU (data.cFileName, ".."))
            continue;

        /*
         * Call the callback with this file.
         */
        result = (*callback) (interp, path, data.cFileName,
                              (volFlags & FS_CASE_SENSITIVE), clientData);
        if (!((result == TCL_OK) || (result == TCL_CONTINUE)))
            break;
    }

    Tcl_DStringFree (&pathBuf);
    FindClose (handle);
    return result;
}

/*-----------------------------------------------------------------------------
 * TclXOSGetFileSize --
 *   System dependent interface to get the size of an open file.
 *
 * Parameters:
 *   o channel - Channel.
 *   o fileSize - File size is returned here.
 * Results:
 *   TCL_OK or TCL_ERROR.  A POSIX error will be set.
 *-----------------------------------------------------------------------------
 */
int
TclXOSGetFileSize (Tcl_Channel  channel,
                   off_t       *fileSize)
{
    HANDLE handle; 
    tclXwinFileType type;

    handle = ChannelToHandle (channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE) {
	return TCL_ERROR;
    }
    
    switch (type) {
      case TCLX_WIN_PIPE:
      case TCLX_WIN_FILE:
        *fileSize = GetFileSize (handle, NULL);
        if (*fileSize < 0) {
            TclWinConvertError (GetLastError ());
            return TCL_ERROR;
        }
        break;
      case TCLX_WIN_SOCKET:
      case TCLX_WIN_CONSOLE:
        *fileSize = 0;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSftruncate --
 *   System dependent interface to ftruncate functionality. 
 *
 * Parameters:
 *   o interp - Error messages are returned in the interpreter.
 *   o channel - Channel to truncate.
 *   o newSize - Size to truncate the file to.
 *   o funcName - Command or other name to use in not available error.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSftruncate (Tcl_Interp  *interp,
                 Tcl_Channel  channel,
                 off_t        newSize,
                 char        *funcName)
{
    HANDLE handle;
    int pos;
    tclXwinFileType type;

    handle = ChannelToHandle (channel, TCL_WRITABLE, &type);

    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" was not open for write access",
                              (char *) NULL);
        return TCL_ERROR;
    }
    if (type != TCLX_WIN_FILE) {
        TclX_AppendObjResult (interp, "truncation of \"",
                              Tcl_GetChannelName (channel),
                              "\" failed: can only truncate disk files",
                              (char *) NULL);
	return TCL_ERROR;
    }
    pos = (int) Tcl_Tell (channel);
    if (SetFilePointer (handle, (LONG)newSize, NULL,
                        FILE_BEGIN) == 0xFFFFFFFF) {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "truncation of \"",
                              Tcl_GetChannelName (channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }
    /*
     * FIX: we really ought to interpolate zeros when extending the file,
     * since SetEndOfFile does not promise to do this.
     */
    if (!SetEndOfFile (handle)) {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "truncation of \"",
                              Tcl_GetChannelName (channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        if (pos >= 0) {
            (void) SetFilePointer (handle, (LONG)pos, NULL, FILE_BEGIN);
        }
        return TCL_ERROR;
    }
    if (pos >= 0) {
        if (SetFilePointer (handle, (LONG)pos, NULL,
                            FILE_BEGIN) == 0xFFFFFFFF) {
            TclWinConvertError (GetLastError ());
            TclX_AppendObjResult (interp, "couldn't restore position after ",
                                  "truncating \"",
                                  Tcl_GetChannelName (channel),
                                  "\": ", Tcl_PosixError (interp),
                                  (char *) NULL);
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSfork --
 *   System dependent interface to fork functionality.  Not supported on
 * windows.
 *
 * Parameters:
 *   o interp - An error  is returned in result.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSfork (Tcl_Interp *interp,
            Tcl_Obj    *funcNameObj)
{
    return TclXNotAvailableObjError (interp, funcNameObj);
}

/*-----------------------------------------------------------------------------
 * TclXOSexecl --
 *   System dependent interface to execl functionality.  On windows, this is
 * the equivlant of a fork and an execl, so a process id is returned.
 *
 * Parameters:
 *   o interp - A process id or errors are returned in result.
 *   o path - Path to the program.
 *   o argList - NULL terminated argument vector.
 * Results:
 *   TCL_ERROR or does not return.
 *-----------------------------------------------------------------------------
 */
int
TclXOSexecl (Tcl_Interp *interp,
             char       *path,
             char      **argList)
{
    int pid;
    char numBuf [32];

    pid = spawnvp (_P_NOWAIT , path, argList);
    if (pid == -1) {
        TclX_AppendObjResult (interp, "exec of \"", path, "\" failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    sprintf (numBuf, "%d", pid);
    Tcl_SetResult (interp, numBuf, TCL_VOLATILE);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSInetAtoN --
 *
 *   Convert an internet address to an "struct in_addr" representation.
 *
 * Parameters:
 *   o interp - If not NULL, an error message is return in the result.
 *     If NULL, no error message is generated.
 *   o strAddress - String address to convert.
 *   o inAddress - Converted internet address is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSInetAtoN (Tcl_Interp     *interp,
                char           *strAddress,
                struct in_addr *inAddress)
{
    inAddress->s_addr = inet_addr (strAddress);
    if (inAddress->s_addr != INADDR_NONE)
        return TCL_OK;
    if (interp != NULL) {
        TclX_AppendObjResult (interp, "malformed address: \"",
                              strAddress, "\"", (char *) NULL);
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSgetpeername --
 *   System dependent interface to getpeername functionality.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channel - Channel associated with the socket.
 *   o sockaddr - Pointer to sockaddr structure.
 *   o sockaddrSize - Size of the sockaddr struct.
 * Results:
 *   TCL_OK or TCL_ERROR, sets a posix error.
 *-----------------------------------------------------------------------------
 */
int
TclXOSgetpeername (Tcl_Interp *interp,
                   Tcl_Channel channel,
                   void       *sockaddr,
                   int         sockaddrSize)
{
    SOCKET sock;

    sock = ChannelToSocket (interp, channel);
    if (sock == INVALID_SOCKET)
        return TCL_ERROR;
    if (getpeername (sock, (struct sockaddr *) sockaddr, &sockaddrSize) < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSgetsockname --
 *   System dependent interface to getsockname functionality.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channel - Channel associated with the socket.
 *   o sockaddr - Pointer to sockaddr structure.
 *   o sockaddrSize - Size of the sockaddr struct.
 * Results:
 *   TCL_OK or TCL_ERROR, sets a posix error.
 *-----------------------------------------------------------------------------
 */
int
TclXOSgetsockname (Tcl_Interp *interp,
                   Tcl_Channel channel,
                   void       *sockaddr,
                   int         sockaddrSize)
{
    SOCKET sock;

    sock = ChannelToSocket (interp, channel);
    if (sock == INVALID_SOCKET)
        return TCL_ERROR;

    if (getsockname (sock, (struct sockaddr *) sockaddr, &sockaddrSize) < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSgetsockopt --
 *    Get the value of a integer socket option.
 *     
 * Parameters:
 *   o interp - Errors are returned in the result.
 *   o channel - Channel associated with the socket.
 *   o option - Socket option to get.
 *   o valuePtr -  Integer value is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSgetsockopt (interp, channel, option, valuePtr)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int          option;
    int         *valuePtr;
{
    int valueLen = sizeof (*valuePtr);
    SOCKET sock;

    sock = ChannelToSocket (interp, channel);
    if (sock == INVALID_SOCKET)
        return TCL_ERROR;

    if (getsockopt (sock, SOL_SOCKET, option, 
                    (void*) valuePtr, &valueLen) != 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSsetsockopt --
 *    Set the value of a integer socket option.
 *     
 * Parameters:
 *   o interp - Errors are returned in the result.
 *   o channel - Channel associated with the socket.
 *   o option - Socket option to get.
 *   o value - Valid integer value for the option.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSsetsockopt (interp, channel, option, value)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int          option;
    int          value;
{
    int valueLen = sizeof (value);
    SOCKET sock;

    sock = ChannelToSocket (interp, channel);
    if (sock == INVALID_SOCKET)
        return TCL_ERROR;

    if (setsockopt (sock, SOL_SOCKET, option,
                    (void*) &value, valueLen) != 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSchmod --
 *   System dependent interface to chmod functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o fileName - Name of to set the mode on.
 *   o mode - New, unix style file access mode.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSchmod (interp, fileName, mode)
    Tcl_Interp *interp;
    char       *fileName;
    int         mode;
{
#if 0
    /*FIX:*/
    if (chmod (fileName, (unsigned short) mode) < 0) {
        TclX_AppendObjResult (interp, "chmod failed on \"", fileName, "\": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
#else
    TclX_AppendObjResult (interp, "chmod is not available on this system",
                      (char *) NULL);
    return TCL_ERROR;
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSfchmod --
 *   System dependent interface to fchmod functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o channel - Channel to set the mode on.
 *   o mode - New, unix style file access mode.
 *   o funcName - Command or other string to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSfchmod (interp, channel, mode, funcName)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         mode;
    char       *funcName;
{
#if 0
  FIX:
    if (fchmod (ChannelToFnum (channel, 0), (unsigned short) mode) < 0) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
#else
    TclX_AppendObjResult (interp, funcName, " is not available on this system",
                          (char *) NULL);
    return TCL_ERROR;
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSChangeOwnGrp --
 *   Change the owner and/or group of a file by file name.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o options - Option flags are:
 *     o TCLX_CHOWN - Change file's owner.
 *     o TCLX_CHGRP - Change file's group.
 *   o ownerStr - String containing owner name or id.  NULL if TCLX_CHOWN
 *     not specified.
 *   o groupStr - String containing owner name or id.  NULL if TCLX_CHOWN
 *     not specified.  If NULL and TCLX_CHOWN is specified, the user's group
 *     is used.
 *   o files - NULL terminated list of file names.
 *   o funcName - Command or other name to use in not available error.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */

int
TclXOSChangeOwnGrpObj (interp, options, ownerStr, groupStr, files, funcName)
    Tcl_Interp  *interp;
    unsigned     options;
    char        *ownerStr;
    char        *groupStr;
    Tcl_Obj	*files;
    char       *funcName;
{
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSFChangeOwnGrp --
 *   Change the owner and/or group of a file by open channel.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o options - Option flags are:
 *     o TCLX_CHOWN - Change file's owner.
 *     o TCLX_CHGRP - Change file's group.
 *   o ownerStr - String containing owner name or id.  NULL if TCLX_CHOWN
 *     not specified.
 *   o groupStr - String containing owner name or id.  NULL if TCLX_CHOWN
 *     not specified.  If NULL and TCLX_CHOWN is specified, the user's group
 *     is used.
 *   o channelIds - NULL terminated list of channel ids.
 *   o funcName - Command or other name to use in not available error.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSFChangeOwnGrpObj (interp, options, ownerStr, groupStr, channelIds, funcName)
    Tcl_Interp *interp;
    unsigned    options;
    char       *ownerStr;
    char       *groupStr;
    Tcl_Obj    *channelIds;
    char       *funcName;
{
    return TclXNotAvailableError (interp, funcName);
}

/*-----------------------------------------------------------------------------
 * TclXOSGetSelectFnum --
 *   Convert a channel its read and write file numbers for use in select.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o channel - Channel to get the numbers for.
 *   o direction - TCL_READABLE or TCL_WRITABLE.
 *   o fnumPtr - The file number for the direction is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSGetSelectFnum (Tcl_Interp *interp,
                     Tcl_Channel channel,
                     int         direction,
                     int        *fnumPtr)
{
    tclXwinFileType type;
    HANDLE handle = ChannelToHandle (channel, direction, &type);
    
    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp,  "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" was not open for requested access",
                              (char *) NULL);
        return TCL_ERROR;
    }

    if (type != TCLX_WIN_SOCKET) {
        TclX_AppendObjResult (interp, "channel \"",
			      Tcl_GetChannelName (channel),
                              "\" is not a socket; select only works on ",
                              "sockets on Windows", (char *) NULL);
        return TCL_ERROR;
    }

    *fnumPtr = (int) handle;
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSHaveFlock --
 *   System dependent interface to determine if file locking is available.
 * Returns:
 *   TRUE if file locking is available, FALSE if it is not.
 *-----------------------------------------------------------------------------
 */
int
TclXOSHaveFlock ()
{
    OVERLAPPED start;

    start.Internal = 0;
    start.InternalHigh = 0;
    start.Offset = 0;
    start.OffsetHigh = 0;
    start.hEvent = 0;

    if (!LockFileEx (NULL, 0, 0, 0, 0, &start)) {
        if (GetLastError () == ERROR_CALL_NOT_IMPLEMENTED)
            return FALSE;
    }
    return TRUE;
}

/*-----------------------------------------------------------------------------
 * LockUnlockSetup --
 *
 *    Do common setup work for locking or unlocking a file.
 *
 * Parameters:
 *   o interp - Errors are return in the result.
 *   o lockInfoPtr - Lock specification.
 *   o startPtr - Start of area to lock is returned in struct.
 *   o lengthLowPtr - Low-order 32 bits of length of the file to lock.
 *   o lengthHighPtr - High-order 32 bits of length of the file to lock.  Files
 *     of length greater than 32 bits are not support.  This is only to allow
 *     for locking the entier range of the file
 *   o whichMsg - Either "lock" or "unlock", for error messages.
 * Returns:
 *   The file handle or NULL if an error occurs.
 *-----------------------------------------------------------------------------
 */
static HANDLE
LockUnlockSetup (Tcl_Interp     *interp,
                 TclX_FlockInfo *lockInfoPtr,
                 LPOVERLAPPED    startPtr,
                 LPDWORD         lengthLowPtr,
                 LPDWORD         lengthHighPtr,
                 char           *whichMsg)
{
    HANDLE handle;
    tclXwinFileType type;

    /*
     * Get the handle and validate that this is something we can lock.
     */
    handle = ChannelToHandle (lockInfoPtr->channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (lockInfoPtr->channel),
                              "\" has no device handle", (char *) NULL);
	return handle;
    }

    switch (type) {
      case TCLX_WIN_PIPE:
        TclX_AppendObjResult (interp,
                              "can't lock a pipe line under MS Windows",
                              (char *) NULL);
        return INVALID_HANDLE_VALUE;
      case TCLX_WIN_FILE:
        break;
      case TCLX_WIN_SOCKET:
        TclX_AppendObjResult (interp, "can't lock a socket under windows",
                              (char *) NULL);
        return INVALID_HANDLE_VALUE;
      case TCLX_WIN_CONSOLE:
        break;  /* FIX: Is this legal?? */
      default:
        panic ("unknown win channel type %d\n", type);
    }
    
    /*
     * Calculate actual offset of the start.
     */
    switch (lockInfoPtr->whence) {
      case 0:  /* start */
        startPtr->Offset = lockInfoPtr->start;
        break;
      case 1:  /* current */
        startPtr->Offset = SetFilePointer (handle, 0, NULL, FILE_CURRENT);
        if (startPtr->Offset == 0xFFFFFFFF)
            goto winError;
        startPtr->Offset += lockInfoPtr->start;
        break;
      case 2:  /* end */
        startPtr->Offset = GetFileSize (handle, NULL);
        if (startPtr->Offset < 0)
            goto winError;
        startPtr->Offset += lockInfoPtr->start;
        break;
    }
    startPtr->Internal = 0;
    startPtr->InternalHigh = 0;
    startPtr->OffsetHigh = 0;
    startPtr->hEvent = 0;

    /*
     * Determine length of lock.  If zero, the remained of the file is locked
     * out its maximum length.
     */
    *lengthHighPtr = 0;
    if (lockInfoPtr->len == 0) {
        *lengthHighPtr = 0x7FFFFFFF;
        *lengthLowPtr = 0xFFFFFFFF;
    } else {
        *lengthLowPtr = lockInfoPtr->len;
    }
    return handle;

  winError:
    TclWinConvertError (GetLastError ());
    lockInfoPtr->gotLock = FALSE;
    TclX_AppendObjResult (interp, whichMsg, " of \"",
                          Tcl_GetChannelName (lockInfoPtr->channel),
                          "\" failed: ", Tcl_PosixError (interp),
                          (char *) NULL);
    return INVALID_HANDLE_VALUE;
}

/*-----------------------------------------------------------------------------
 * TclXOSFlock --
 *   System dependent interface to locking a file.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o lockInfoPtr - Lock specification, gotLock will be initialized.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSFlock (interp, lockInfoPtr)
    Tcl_Interp     *interp;
    TclX_FlockInfo *lockInfoPtr;
{
    HANDLE handle;
    DWORD flags, lengthHigh, lengthLow;
    OVERLAPPED start;

    handle = LockUnlockSetup (interp,
                              lockInfoPtr,
                              &start,
                              &lengthLow,
                              &lengthHigh,
                              "lock");

    if (handle == INVALID_HANDLE_VALUE)
        return TCL_ERROR;

    flags = 0;
    if (lockInfoPtr->access == TCL_WRITABLE)
        flags |= LOCKFILE_EXCLUSIVE_LOCK;
    if (!lockInfoPtr->block)
        flags |= LOCKFILE_FAIL_IMMEDIATELY;

    if (!LockFileEx (handle, flags, 0, lengthLow, lengthHigh, &start)) {
        if (GetLastError () == ERROR_LOCK_VIOLATION) {
            lockInfoPtr->gotLock = FALSE;
            return TCL_OK;
        }
        goto winError;
    }
    lockInfoPtr->gotLock = TRUE;
    return TCL_OK;

  winError:
    if (GetLastError () == ERROR_CALL_NOT_IMPLEMENTED) {
        TclX_AppendObjResult (interp, "file locking is not yet available on ",
                              "Windows 3.1 and 95", (char *) NULL);
    } else {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "lock of \"",
                              Tcl_GetChannelName (lockInfoPtr->channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
    }
    lockInfoPtr->gotLock = FALSE;
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSFunlock --
 *   System dependent interface to unlocking a file.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o lockInfoPtr - Lock specification.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSFunlock (interp, lockInfoPtr)
    Tcl_Interp     *interp;
    TclX_FlockInfo *lockInfoPtr;
{
    HANDLE handle;
    DWORD lengthHigh, lengthLow;
    OVERLAPPED start;

    handle = LockUnlockSetup (interp,
                              lockInfoPtr,
                              &start,
                              &lengthLow,
                              &lengthHigh,
                              "unlock");
    if (handle == INVALID_HANDLE_VALUE)
        return TCL_ERROR;

    if (!UnlockFileEx (handle, 0, lengthLow, lengthHigh, &start)) {
        goto winError;
    }
    return TCL_OK;

  winError:
    if (GetLastError () == ERROR_CALL_NOT_IMPLEMENTED) {
        TclX_AppendObjResult (interp, "file locking is not yet available on ",
                              "Windows 3.1 and 95", (char *) NULL);
    } else {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "unlock of \"",
                              Tcl_GetChannelName (lockInfoPtr->channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSGetAppend --
 *   System dependent interface determine if a channel is in force append mode.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o channel - Channel to get mode for.  The write file is used.
 *   o valuePtr - TRUE is returned if in append mode, FALSE if not.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSGetAppend (interp, channel, valuePtr)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int        *valuePtr;
{
    return TclXNotAvailableError (interp,
                                  "append mode");
}

/*-----------------------------------------------------------------------------
 * TclXOSSetAppend --
 *   System dependent interface set force append mode on a channel.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o channel - Channel to get mode for.  The write file is used.
 *   o value - TRUE to enable, FALSE to disable.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSSetAppend (interp, channel, value)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         value;
{
    return TclXNotAvailableError (interp,
                                  "append mode");
}

/*-----------------------------------------------------------------------------
 * TclXOSGetCloseOnExec --
 *   System dependent interface determine if a channel has close-on-exec set.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o channel - Channel to get mode for.  The write file is used.
 *   o valuePtr - TRUE is close-on-exec, FALSE if not.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSGetCloseOnExec (interp, channel, valuePtr)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int        *valuePtr;
{
    HANDLE handle;
    tclXwinFileType type;
    DWORD flags;

    handle = ChannelToHandle (channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" has no device handle", (char *) NULL);
	return TCL_ERROR;
    }

    /*
     * The following works on Windows NT, but not on Windows 95.
     */
    if (!GetHandleInformation (handle, &flags)) {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "getting close-on-exec for \"",
                              Tcl_GetChannelName (channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * N.B. The value of the CLOEXEC flag is the inverse of HANDLE_FLAG_INHERIT.
     */
    *valuePtr = (flags & HANDLE_FLAG_INHERIT) ? 0 : 1;
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSSetCloseOnExec --
 *   System dependent interface set close-on-exec on a channel.
 *
 * Parameters:
 *   o interp - Pointer to the current interpreter, error messages will be
 *     returned in the result.
 *   o channel - Channel to get mode for.  The write file is used.
 *   o value - TRUE to enable, FALSE to disable.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSSetCloseOnExec (interp, channel, value)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         value;
{
    HANDLE handle;
    tclXwinFileType type;

    handle = ChannelToHandle (channel, 0, &type);

    if (handle == INVALID_HANDLE_VALUE) {
        TclX_AppendObjResult (interp, "channel \"",
                              Tcl_GetChannelName (channel),
                              "\" has no device handle", (char *) NULL);
	return TCL_ERROR;
    }

    /*
     * The following works on Windows NT, but not on Windows 95.
     * N.B. The value of the CLOEXEC flag is the inverse of HANDLE_FLAG_INHERIT.
     */
    if (!SetHandleInformation (handle,
                               HANDLE_FLAG_INHERIT,
                               value ? 0 : HANDLE_FLAG_INHERIT)) {
        TclWinConvertError (GetLastError ());
        TclX_AppendObjResult (interp, "setting close-on-exec for \"",
                              Tcl_GetChannelName (channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}



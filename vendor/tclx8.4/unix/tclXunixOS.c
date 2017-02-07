/*
 * tclXunixOS.c --
 *
 * OS system dependent interface for Unix systems.  The idea behind these
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
 * $Id: tclXunixOS.c,v 8.9 2005/07/12 19:03:15 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

#ifndef NO_GETPRIORITY
#include <sys/resource.h>
#endif

/*
 * Tcl 8.4 had some weird and unnecessary ifdef'ery for readdir
 * readdir() should be thread-safe according to the Single Unix Spec.
 * [Bug #1095909]
 */
#ifdef readdir
#undef readdir
#endif

/*
 * Cheat a little to avoid configure checking for floor and ceil being
 * This breaks with GNU libc headers...really should check with autoconf.
 */
#ifndef __GNU_LIBRARY__
extern
double floor ();

extern
double ceil ();
#endif

/*
 * Prototypes of internal functions.
 */
static int
ChannelToFnum _ANSI_ARGS_((Tcl_Channel channel,
                           int         direction));

static int
ConvertOwnerGroup _ANSI_ARGS_((Tcl_Interp  *interp,
                               unsigned     options,
                               char        *ownerStr,
                               char        *groupStr,
                               uid_t       *ownerId,
                               gid_t       *groupId));


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
TclXNotAvailableError (interp, funcName)
    Tcl_Interp *interp;
    char       *funcName;
{
    TclX_AppendObjResult (interp, funcName, " is not available on this system",
                          (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * ChannelToFnum --
 *
 *    Convert a channel to a file number.
 *
 * Parameters:
 *   o channel - Channel to get file number for.
 *   o direction - TCL_READABLE or TCL_WRITABLE, or zero.  If zero, then
 *     return the first of the read and write numbers.
 * Returns:
 *   The file number or -1 if a file number is not associated with this access
 * direction.  Normally the resulting file number is just passed to a system
 * call and let the system calls generate an error when -1 is returned.
 *-----------------------------------------------------------------------------
 */
static int
ChannelToFnum (channel, direction)
    Tcl_Channel channel;
    int         direction;
{
    ClientData handle;

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
    return (int) handle;
}

/*-----------------------------------------------------------------------------
 * TclXOSTicksToMS --
 *
 *   Convert clock ticks to milliseconds.
 *
 * Parameters:
 *   o numTicks - Number of ticks.
 * Returns:
 *   Milliseconds.
 *-----------------------------------------------------------------------------
 */
clock_t
TclXOSTicksToMS (numTicks)
    clock_t numTicks;
{
    static clock_t msPerTick = 0;

    /*
     * Some systems (SVR4) implement CLK_TCK as a call to sysconf, so lets only
     * reference it once in the life of this process.
     */
    if (msPerTick == 0)
        msPerTick = CLK_TCK;

    if (msPerTick <= 100) {
        /*
         * On low resolution systems we can do this all with integer math. Note
         * that the addition of half the clock hertz results in appoximate
         * rounding instead of truncation.
         */
        return (numTicks) * (1000 + msPerTick / 2) / msPerTick;
    } else {
        /*
         * On systems (Cray) where the question is ticks per millisecond, not
         * milliseconds per tick, we need to use floating point arithmetic.
         */
        return ((numTicks) * 1000.0 / msPerTick);
    }
}

/*-----------------------------------------------------------------------------
 * TclXOSgetpriority --
 *   System dependent interface to getpriority functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o priority - Process priority is returned here.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSgetpriority (interp, priority, funcName)
    Tcl_Interp *interp;
    int        *priority;
    char       *funcName;
{
#ifndef NO_GETPRIORITY
    *priority = getpriority (PRIO_PROCESS, 0);
#else
    *priority = nice (0);
#endif
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSincrpriority--
 *   System dependent interface to increment or decrement the current priority.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o priorityIncr - Amount to adjust the priority by.
 *   o priority - The new priority..
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSincrpriority (interp, priorityIncr, priority, funcName)
    Tcl_Interp *interp;
    int         priorityIncr;
    int        *priority;
    char       *funcName;
{
    errno = 0;  /* Old priority might be -1 */

#ifndef NO_GETPRIORITY
    *priority = getpriority (PRIO_PROCESS, 0) + priorityIncr;
    if (errno == 0) {
        setpriority (PRIO_PROCESS, 0, *priority);
    }
#else
    *priority = nice (priorityIncr);
#endif
    if (errno != 0) {
        TclX_AppendObjResult (interp, "failed to increment priority: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
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
    int fileNums [2];

    if (pipe (fileNums) < 0) {
        TclX_AppendObjResult (interp, "pipe creation failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    channels [0] = Tcl_MakeFileChannel ((ClientData) fileNums [0],
                                        TCL_READABLE);
    Tcl_RegisterChannel (interp, channels [0]);

    channels [1] = Tcl_MakeFileChannel ((ClientData) fileNums [1],
                                        TCL_WRITABLE);
    Tcl_RegisterChannel (interp, channels [1]);

    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclXOSsetitimer --
 *   System dependent interface to setitimer functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o seconds (I/O) - Seconds to pause for, it is updated with the time
 *     remaining on the last alarm.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSsetitimer (interp, seconds, funcName)
    Tcl_Interp *interp;
    double     *seconds;
    char       *funcName;
{
/*
 * A million microseconds per seconds.
 */
#define TCL_USECS_PER_SEC (1000L * 1000L)

#ifndef NO_SETITIMER
    double secFloor;
    struct itimerval  timer, oldTimer;

    secFloor = floor (*seconds);

    timer.it_value.tv_sec     = secFloor;
    timer.it_value.tv_usec    = (long) ((*seconds - secFloor) *
                                        (double) TCL_USECS_PER_SEC);
    timer.it_interval.tv_sec  = 0;
    timer.it_interval.tv_usec = 0;  

    if (setitimer (ITIMER_REAL, &timer, &oldTimer) < 0) {
        TclX_AppendObjResult (interp, "unable to obtain timer: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    *seconds  = oldTimer.it_value.tv_sec;
    *seconds += ((double) oldTimer.it_value.tv_usec) /
        ((double) TCL_USECS_PER_SEC);

    return TCL_OK;
#else
    unsigned useconds;

    useconds = ceil (*seconds);
    *seconds = alarm (useconds);

    return TCL_OK;
#endif
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
TclXOSsleep (seconds)
    unsigned seconds;
{
    Tcl_Sleep (seconds*1000);
}

/*-----------------------------------------------------------------------------
 * TclXOSsync --
 *   System dependent interface to sync functionality.
 *-----------------------------------------------------------------------------
 */
void
TclXOSsync ()
{
    sync ();
}

/*-----------------------------------------------------------------------------
 * TclXOSfsync --
 *   System dependent interface to fsync functionality.  Does a sync if fsync
 * is not available.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o channel - The  channel to sync.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSfsync (interp, channel)
    Tcl_Interp *interp;
    Tcl_Channel channel;
{
    if (Tcl_Flush (channel) < 0)
        goto posixError;

#ifndef NO_FSYNC
    if (fsync (ChannelToFnum (channel, TCL_WRITABLE)) < 0)
        goto posixError;
#else
    sync ();
#endif
    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                          Tcl_PosixError (interp), (char *) NULL);
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
TclXOSsystem (interp, command, exitCode)
    Tcl_Interp *interp;
    char       *command;
    int        *exitCode;
{
    int errPipes [2], childErrno;
    pid_t pid;
    WAIT_STATUS_TYPE waitStatus;

    errPipes [0] = errPipes [1] = -1;

    /*
     * Create a close on exec pipe to get status back from the child if
     * the exec fails.
     */
    if (pipe (errPipes) != 0) {
        TclX_AppendObjResult (interp, "couldn't create pipe: ",
                              Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }
    if (fcntl (errPipes [1], F_SETFD, FD_CLOEXEC) != 0) {
        TclX_AppendObjResult (interp, "couldn't set close on exec for pipe: ",
                              Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }

    pid = fork ();
    if (pid == -1) {
        TclX_AppendObjResult (interp, "couldn't fork child process: ",
                              Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }
    if (pid == 0) {
        close (errPipes [0]);
        execl ("/bin/sh", "sh", "-c", command, (char *) NULL);
        write (errPipes [1], &errno, sizeof (errno));
        _exit (127);
    }

    close (errPipes [1]);
    if (read (errPipes [0], &childErrno, sizeof (childErrno)) > 0) {
        errno = childErrno;
        TclX_AppendObjResult (interp, "couldn't execing /bin/sh: ",
                              Tcl_PosixError (interp), (char *) NULL);
        waitpid (pid, (int *) &waitStatus, 0);
        goto errorExit;
    }
    close (errPipes [0]);

    if (waitpid (pid, (int *) &waitStatus, 0) < 0) {
        TclX_AppendObjResult (interp, "wait failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    
    /*
     * Return status based on wait result.
     */
    if (WIFEXITED (waitStatus)) {
        *exitCode = WEXITSTATUS (waitStatus);
        return TCL_OK;
    }

    if (WIFSIGNALED (waitStatus)) {
        Tcl_SetErrorCode (interp, "SYSTEM", "SIG",
                          Tcl_SignalId (WTERMSIG (waitStatus)), (char *) NULL);
        TclX_AppendObjResult (interp, "system command terminate with signal ",
                              Tcl_SignalId (WTERMSIG (waitStatus)),
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Should never get this status back unless the implementation is
     * really brain-damaged.
     */
    if (WIFSTOPPED (waitStatus)) {
        TclX_AppendObjResult (interp, "system command child stopped",
                              (char *) NULL);
        return TCL_ERROR;
    }

  errorExit:
    close (errPipes [0]);
    close (errPipes [1]);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_OSlink --
 *   System dependent interface to link functionality.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o srcPath - File to link.
 *   o targetPath - Path to new link.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_OSlink (interp, srcPath, targetPath, funcName)
    Tcl_Interp *interp;
    char       *srcPath;
    char       *targetPath;
    char       *funcName;
{
    if (link (srcPath, targetPath) != 0) {
        TclX_AppendObjResult (interp, "linking \"", srcPath, "\" to \"",
                              targetPath, "\" failed: ", 
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
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
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_OSsymlink (interp, srcPath, targetPath, funcName)
    Tcl_Interp *interp;
    char       *srcPath;
    char       *targetPath;
    char       *funcName;
{
#ifdef S_IFLNK
    if (symlink (srcPath, targetPath) != 0) {
        TclX_AppendObjResult (interp, "creating symbolic link \"",
                              targetPath, "\" failed: ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
#else
    TclX_AppendObjResult (interp, 
                          "symbolic links are not supported on this",
                          " Unix system", (char *) NULL);
    return TCL_ERROR;
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSElapsedTime --
 *   System dependent interface to get the elapsed CPU and real time. 
 *
 * Parameters:
 *   o realTime - Elapsed real time, in milliseconds is returned here.
 *   o cpuTime - Elapsed CPU time, in milliseconds is returned here.
 *-----------------------------------------------------------------------------
 */
void
TclXOSElapsedTime (realTime, cpuTime)
    clock_t *realTime;
    clock_t *cpuTime;
{
/*
 * If times returns elapsed real time, this is easy.  If it returns a status,
 * real time must be obtained in other ways.
 */
#ifndef TIMES_RETS_STATUS
    struct tms cpuTimes;

    *realTime = TclXOSTicksToMS (times (&cpuTimes));
    *cpuTime = TclXOSTicksToMS (cpuTimes.tms_utime + cpuTimes.tms_stime);
#else
    static struct timeval startTime = {0, 0};
    struct timeval currentTime;
    struct tms cpuTimes;

    /*
     * If this is the first call, get base time.
     */
    if ((startTime.tv_sec == 0) && (startTime.tv_usec == 0))
        gettimeofday (&startTime, NULL);
    
    gettimeofday (&currentTime, NULL);
    currentTime.tv_sec  = currentTime.tv_sec  - startTime.tv_sec;
    currentTime.tv_usec = currentTime.tv_usec - startTime.tv_usec;
    *realTime = (currentTime.tv_sec  * 1000) + (currentTime.tv_usec / 1000);
    times (&cpuTimes);
    *cpuTime = TclXOSTicksToMS (cpuTimes.tms_utime + cpuTimes.tms_stime);
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSkill --
 *   System dependent interface to send a signal to a process.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o pid - Process id, negative process group, etc.
 *   o signal - Signal to send.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSkill (interp, pid, signal, funcName)
    Tcl_Interp *interp;
    pid_t       pid;
    int         signal;
    char       *funcName;
{
    if (kill (pid, signal) < 0) {
        char pidStr [32];

        TclX_AppendObjResult (interp, "sending signal ",
                              (signal == 0) ? 0 : Tcl_SignalId (signal),
                              (char *) NULL);
        if (pid > 0) {
            sprintf (pidStr, "%d", pid);
            TclX_AppendObjResult (interp, " to process ", pidStr,
                                  (char *) NULL);
        } else if (pid == 0) {
            sprintf (pidStr, "%d", getpgrp ());
            TclX_AppendObjResult (interp, " to current process group (", 
                                  pidStr, ")", (char *) NULL);
        } else if (pid == -1) {
            TclX_AppendObjResult (interp, " to all processess ", 
                                  (char *) NULL);
        } else if (pid < -1) {
            sprintf (pidStr, "%d", -pid);
            TclX_AppendObjResult (interp, " to process group ", 
                                  pidStr, (char *) NULL);
        }
        TclX_AppendObjResult (interp, " failed: ", 
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSFstat --
 *   System dependent interface to get status information on an open file.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channel - Channel to get the status of.
 *   o statBuf - Status information, made to look as much like Unix as
 *     possible.
 *   o ttyDev - If not NULL, a boolean indicating if the device is
 *     associated with a tty.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSFstat (interp, channel, statBuf, ttyDev)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    struct stat *statBuf;
    int         *ttyDev;
{
    int fileNum = ChannelToFnum (channel, 0);

    if (fstat (fileNum, statBuf) < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    if (ttyDev != NULL)
        *ttyDev = isatty (fileNum);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSSeakable --
 *   System dependent interface to determine if a channel is seekable.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o channel - Channel to get the status of.
 *   o seekable - TRUE is return if seekable, FALSE if not.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSSeekable (interp, channel, seekablePtr)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int         *seekablePtr;
{
    struct stat statBuf;
    int fileNum = ChannelToFnum (channel, TCL_READABLE);

    if (fileNum < 0) {
        *seekablePtr = FALSE;
        return TCL_OK;
    }

    if (fstat (fileNum, &statBuf) < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    if (S_ISREG (statBuf.st_mode)) {
        *seekablePtr = TRUE;
    } else {
        *seekablePtr = FALSE;
    }
    return TCL_OK;
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
 *        o caseSensitive - Are the file names case sensitive?  Always
 *          TRUE on Unix.
 *        o clientData - Client data that was passed.
 *   o clientData - Client data to pass to callback.
 * Results:
 *   TCL_OK if completed directory walk.  TCL_BREAK if callback returned
 * TCL_BREAK and TCL_ERROR if an error occured.
 *-----------------------------------------------------------------------------
*/
int
TclXOSWalkDir (interp, path, hidden, callback, clientData)
    Tcl_Interp       *interp;
    char             *path;
    int               hidden;
    TclX_WalkDirProc *callback;
    ClientData        clientData;
{
    DIR *handle;
    struct dirent *entryPtr;
    int result = TCL_OK;

    handle = opendir (path);
    if (handle == NULL)  {
        if (interp != NULL)
            TclX_AppendObjResult (interp, "open of directory \"", path,
                                  "\" failed: ", Tcl_PosixError (interp),
                                  (char *) NULL);
        return TCL_ERROR;
    }

    while (TRUE) {
        entryPtr = readdir (handle);
        if (entryPtr == NULL) {
            break;
        }
        if (entryPtr->d_name [0] == '.') {
            if (entryPtr->d_name [1] == '\0')
                continue;
            if ((entryPtr->d_name [1] == '.') &&
                (entryPtr->d_name [2] == '\0'))
                continue;
        }
        result = (*callback) (interp, path, entryPtr->d_name,
                              TRUE, clientData);
        if (!((result == TCL_OK) || (result == TCL_CONTINUE)))
            break;
    }
    if (result == TCL_ERROR) {
        closedir (handle);
        return TCL_ERROR;
    }
    if (closedir (handle) < 0) {
        if (interp != NULL)
            TclX_AppendObjResult (interp, "close of directory failed: ",
                                  Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
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
TclXOSGetFileSize (channel, fileSize)
    Tcl_Channel  channel;
    off_t       *fileSize;
{
    struct stat statBuf;

    if (fstat (ChannelToFnum (channel, 0), &statBuf)) {
        return TCL_ERROR;
    }
    *fileSize = statBuf.st_size;
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
TclXOSftruncate (interp, channel, newSize, funcName)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    off_t        newSize;
    char        *funcName;
{
#if (!defined(NO_FTRUNCATE)) || defined(HAVE_CHSIZE) 
    int stat;

#ifndef NO_FTRUNCATE
    stat = ftruncate (ChannelToFnum (channel, 0), newSize);
#else
    stat = chsize (ChannelToFnum (channel, 0), newSize);
#endif
    if (stat != 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
#else
    return TclXNotAvailableError (interp, funcName);
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSfork --
 *   System dependent interface to fork functionality.
 *
 * Parameters:
 *   o interp - A format process id or errors are returned in result.
 *   o funcName - Command or other name to use in not available error.
 * Results:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclXOSfork (interp, funcNameObj)
    Tcl_Interp *interp;
    Tcl_Obj    *funcNameObj;
{
    pid_t pid;
    
    pid = fork ();
    if (pid < 0) {
        TclX_AppendObjResult (interp, "fork failed: ", 
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    Tcl_SetIntObj (Tcl_GetObjResult (interp), (int)pid);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclXOSexecl --
 *   System dependent interface to execl functionality.
 *
 * Parameters:
 *   o interp - Errors are returned in result.
 *   o path - Path to the program.
 *   o argList - NULL terminated argument vector.
 * Results:
 *   TCL_ERROR or does not return.
 *-----------------------------------------------------------------------------
 */
int
TclXOSexecl (interp, path, argList)
    Tcl_Interp *interp;
    char       *path;
    char      **argList;
{
    execvp (path, argList);

    /*
     * Can only make it here on an error.
     */
    TclX_AppendObjResult (interp, "exec of \"", path, "\" failed: ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
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
TclXOSInetAtoN (interp, strAddress, inAddress)
    Tcl_Interp     *interp;
    char           *strAddress;
    struct in_addr *inAddress;
{
#ifndef NO_INET_ATON
    if (inet_aton (strAddress, inAddress))
        return TCL_OK;
#else
    inAddress->s_addr = inet_addr (strAddress);
    if (inAddress->s_addr != INADDR_NONE)
        return TCL_OK;
#endif
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
TclXOSgetpeername (interp, channel, sockaddr, sockaddrSize)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    void       *sockaddr;
    int         sockaddrSize;
{

    if (getpeername (ChannelToFnum (channel, 0),
		(struct sockaddr *) sockaddr, &sockaddrSize) < 0) {
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
TclXOSgetsockname (interp, channel, sockaddr, sockaddrSize)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    void       *sockaddr;
    int         sockaddrSize;
{
    if (getsockname (ChannelToFnum (channel, 0),
		(struct sockaddr *) sockaddr, &sockaddrSize) < 0) {
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

    if (getsockopt (ChannelToFnum (channel, 0), SOL_SOCKET, option, 
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

    if (setsockopt (ChannelToFnum (channel, 0), SOL_SOCKET, option,
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
    if (chmod (fileName, mode) < 0) {
        TclX_AppendObjResult (interp, fileName, ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
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
#ifndef NO_FCHMOD
    if (fchmod (ChannelToFnum (channel, 0), mode) < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), ": ",
                              Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
#else
    return TclXNotAvailableError (interp, funcName);
#endif
}

/*-----------------------------------------------------------------------------
 * ConvertOwnerGroup --
 *   Convert the owner and group specification to ids.
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
 *   o ownerId - Owner id is returned here.
 *   o groupId - Group id is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ConvertOwnerGroup (interp, options, ownerStr, groupStr, ownerId, groupId)
    Tcl_Interp  *interp;
    unsigned     options;
    char        *ownerStr;
    char        *groupStr;
    uid_t       *ownerId;
    gid_t       *groupId;
{
    struct passwd *passwdPtr = NULL;
    struct group *groupPtr = NULL;
    int tmpId;

    if (options & TCLX_CHOWN) {
        passwdPtr = getpwnam (ownerStr);
        if (passwdPtr != NULL) {
            *ownerId = passwdPtr->pw_uid;
        } else {
            if (!TclX_StrToInt (ownerStr, 10, &tmpId))
                goto unknownUser;
            /*
             * Check for overflow.
             */
            *ownerId = tmpId;
            if ((int) (*ownerId) != tmpId)
                goto unknownUser;
        }
    }

    if (options & TCLX_CHGRP) {
        if (groupStr == NULL) {
            if (passwdPtr == NULL) {
                passwdPtr = getpwuid (*ownerId);
                if (passwdPtr == NULL)
                    goto noGroupForUser;
            }
            *groupId = passwdPtr->pw_gid;
        } else {
            groupPtr = getgrnam (groupStr);
            if (groupPtr != NULL) {
                *groupId = groupPtr->gr_gid;
            } else {
                if (!TclX_StrToInt (groupStr, 10, &tmpId))
                    goto unknownGroup;
                /*
                 * Check for overflow.
                 */
                *groupId = tmpId;
                if ((int) (*groupId) != tmpId)
                    goto unknownGroup;
            }
        }
    }

    endpwent ();
    return TCL_OK;

  unknownUser:
    TclX_AppendObjResult (interp, "unknown user id: ", 
                          ownerStr, (char *) NULL);
    goto errorExit;

  noGroupForUser:
    TclX_AppendObjResult (interp, "can't find group for user id: ", 
                          ownerStr, (char *) NULL);
    goto errorExit;

  unknownGroup:
    TclX_AppendObjResult (interp, "unknown group id: ", groupStr, 
                          (char *) NULL);
    goto errorExit;

  errorExit:
    endpwent ();
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSChangeOwnGrpObj --
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
TclXOSChangeOwnGrpObj (interp, options, ownerStr, groupStr, fileListObj, funcName)
    Tcl_Interp  *interp;
    unsigned     options;
    char        *ownerStr;
    char        *groupStr;
    Tcl_Obj     *fileListObj;
    char        *funcName;
{
    int          idx;
    struct stat  fileStat;
    uid_t        ownerId;
    gid_t        groupId;
    char        *filePath;
    Tcl_DString  pathBuf;
    char        *fileNameString;
    Tcl_Obj    **filesObjv;
    int          fileCount;

    if (ConvertOwnerGroup (interp, options, ownerStr, groupStr,
                           &ownerId, &groupId) != TCL_OK)
        return TCL_ERROR;

    if (Tcl_ListObjGetElements (interp, fileListObj, &fileCount, &filesObjv)
	    != TCL_OK)
	return TCL_ERROR;

    Tcl_DStringInit (&pathBuf);

    for (idx = 0; idx < fileCount; idx++) {
	fileNameString = Tcl_GetStringFromObj (filesObjv [idx], NULL);
        filePath = Tcl_TranslateFileName (interp, fileNameString, &pathBuf);
        if (filePath == NULL) {
            Tcl_DStringFree (&pathBuf);
            return TCL_ERROR;
        }

        /*
         * If we are not changing both owner and group, we need to get the
         * old ids.
         */
        if ((options & (TCLX_CHOWN | TCLX_CHGRP)) !=
            (TCLX_CHOWN | TCLX_CHGRP)) {
            if (stat (filePath, &fileStat) != 0)
                goto fileError;
            if ((options & TCLX_CHOWN) == 0)
                ownerId = fileStat.st_uid;
            if ((options & TCLX_CHGRP) == 0)
                groupId = fileStat.st_gid;
        }
        if (chown (filePath, ownerId, groupId) < 0)
            goto fileError;
    }
    return TCL_OK;

  fileError:
    TclX_AppendObjResult (interp, filePath, ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    Tcl_DStringFree (&pathBuf);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclXOSFChangeOwnGrpObj --
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
TclXOSFChangeOwnGrpObj (interp, options, ownerStr, groupStr, channelIdsObj,
                        funcName)
    Tcl_Interp *interp;
    unsigned    options;
    char       *ownerStr;
    char       *groupStr;
    Tcl_Obj    *channelIdsObj;
    char       *funcName;
{
#ifndef NO_FCHOWN
    int          idx, fnum;
    struct stat  fileStat;
    uid_t        ownerId;
    gid_t        groupId;
    Tcl_Channel  channel;
    Tcl_Obj    **channelIdsListObj;
    int          channelCount;

    if (ConvertOwnerGroup (interp, options, ownerStr, groupStr,
                           &ownerId, &groupId) != TCL_OK)
        return TCL_ERROR;

    if (Tcl_ListObjGetElements (interp, channelIdsObj,
	    &channelCount, &channelIdsListObj) != TCL_OK)
	return TCL_ERROR;

    for (idx = 0; idx < channelCount; idx++) {
        channel = TclX_GetOpenChannelObj (interp, channelIdsListObj [idx], 0);
        if (channel == NULL) {
            return TCL_ERROR;
	}
        fnum = ChannelToFnum (channel, 0);
        
        /*
         * If we are not changing both owner and group, we need to get the
         * old ids.
         */
        if ((options & (TCLX_CHOWN | TCLX_CHGRP)) !=
            (TCLX_CHOWN | TCLX_CHGRP)) {
            if (fstat (fnum, &fileStat) != 0)
                goto fileError;
            if ((options & TCLX_CHOWN) == 0)
                ownerId = fileStat.st_uid;
            if ((options & TCLX_CHGRP) == 0)
                groupId = fileStat.st_gid;
        }
        if (fchown (fnum, ownerId, groupId) < 0)
            goto fileError;
    }
    return TCL_OK;

  fileError:
    TclX_AppendObjResult (interp, channelIdsListObj [idx], ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
#else
    return TclXNotAvailableError (interp, funcName);
#endif
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
TclXOSFChangeOwnGrp (interp, options, ownerStr, groupStr, channelIds, funcName)
    Tcl_Interp *interp;
    unsigned    options;
    char       *ownerStr;
    char       *groupStr;
    char      **channelIds;
    char       *funcName;
{
#ifndef NO_FCHOWN
    int idx, fnum;
    struct stat fileStat;
    uid_t ownerId;
    gid_t groupId;
    Tcl_Channel channel;

    if (ConvertOwnerGroup (interp, options, ownerStr, groupStr,
                           &ownerId, &groupId) != TCL_OK)
        return TCL_ERROR;

    for (idx = 0; channelIds [idx] != NULL; idx++) {
        channel = TclX_GetOpenChannel (interp, channelIds [idx], 0);
        if (channel == NULL)
            return TCL_ERROR;
        fnum = ChannelToFnum (channel, 0);
        
        /*
         * If we are not changing both owner and group, we need to get the
         * old ids.
         */
        if ((options & (TCLX_CHOWN | TCLX_CHGRP)) !=
            (TCLX_CHOWN | TCLX_CHGRP)) {
            if (fstat (fnum, &fileStat) != 0)
                goto fileError;
            if ((options & TCLX_CHOWN) == 0)
                ownerId = fileStat.st_uid;
            if ((options & TCLX_CHGRP) == 0)
                groupId = fileStat.st_gid;
        }
        if (fchown (fnum, ownerId, groupId) < 0)
            goto fileError;
    }
    return TCL_OK;

  fileError:
    TclX_AppendObjResult (interp, channelIds [idx], ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
#else
    return TclXNotAvailableError (interp, funcName);
#endif
}

/*-----------------------------------------------------------------------------
 * TclXOSGetSelectFnum --
 *   Convert a channel its read or write file numbers for use in select.
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
TclXOSGetSelectFnum (interp, channel, direction, fnumPtr)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         direction;
    int        *fnumPtr;
{
    ClientData handle;

    if (Tcl_GetChannelHandle (channel, direction, &handle) != TCL_OK) {
        TclX_AppendObjResult (interp,  "channel ",
                              Tcl_GetChannelName (channel),
                              " was not open for requested access",
                              (char *) NULL);
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
#ifdef F_SETLKW
    return TRUE;
#else
    return FALSE;
#endif
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
#ifdef F_SETLKW
    int fnum, stat;
    struct flock flockInfo;
    
    flockInfo.l_start = lockInfoPtr->start;
    flockInfo.l_len = lockInfoPtr->len;
    flockInfo.l_type =
        (lockInfoPtr->access == TCL_WRITABLE) ? F_WRLCK : F_RDLCK;
    flockInfo.l_whence = lockInfoPtr->whence;

    fnum = ChannelToFnum (lockInfoPtr->channel, lockInfoPtr->access);

    stat = fcntl (fnum, lockInfoPtr->block ?  F_SETLKW : F_SETLK, 
                  &flockInfo);

    /*
     * Handle status from non-blocking lock.
     */
    if ((stat < 0) && (!lockInfoPtr->block) &&
        ((errno == EACCES) || (errno == EAGAIN))) {
        lockInfoPtr->gotLock = FALSE;
        return TCL_OK;
    }
    
    if (stat < 0) {
        lockInfoPtr->gotLock = FALSE;
        TclX_AppendObjResult (interp, "lock of \"",
                              Tcl_GetChannelName (lockInfoPtr->channel),
                              "\" failed: ", Tcl_PosixError (interp),
                              (char *) NULL);
        return TCL_ERROR;
    }

    lockInfoPtr->gotLock = TRUE;
    return TCL_OK;
#else
    return TclXNotAvailableError (interp,
                                  "file locking");
#endif
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
#ifdef F_SETLKW
    int fnum, stat;
    struct flock flockInfo;
    
    flockInfo.l_start = lockInfoPtr->start;
    flockInfo.l_len = lockInfoPtr->len;
    flockInfo.l_type = F_UNLCK;
    flockInfo.l_whence = lockInfoPtr->whence;

    fnum = ChannelToFnum (lockInfoPtr->channel, lockInfoPtr->access);

    stat = fcntl (fnum, F_SETLK, &flockInfo);
    if (stat < 0) {
        TclX_AppendObjResult (interp, "lock of \"",
                              Tcl_GetChannelName (lockInfoPtr->channel),
                              "\" failed: ", Tcl_PosixError (interp));
        return TCL_ERROR;
    }

    return TCL_OK;
#else
    return TclXNotAvailableError (interp,
                                  "file locking");
#endif
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
    int fnum, mode;

    fnum = ChannelToFnum (channel, TCL_WRITABLE);
    if (fnum < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel),
                              " is not open for write access",
                              (char *) NULL);
        return TCL_ERROR;
    }

    mode = fcntl (fnum, F_GETFL, 0);
    if (mode == -1)
        goto posixError;

    *valuePtr = ((mode & O_APPEND) != 0);
    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp,  Tcl_GetChannelName (channel), ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
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
    int fnum, mode;

    fnum = ChannelToFnum (channel, TCL_WRITABLE);
    if (fnum < 0) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel),
                              " is not open for write access",
                              (char *) NULL);
        return TCL_ERROR;
    }

    mode = fcntl (fnum, F_GETFL, 0);
    if (mode == -1)
        goto posixError;

    mode = (mode & ~O_APPEND) | (value ? O_APPEND : 0);

    if (fcntl (fnum, F_SETFL, mode) == -1)
        goto posixError;

    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp,  Tcl_GetChannelName (channel), ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
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
    int     readFnum;
    int     writeFnum;
    int     readMode = 0;
    int     writeMode = 0;

    readFnum = ChannelToFnum (channel, TCL_READABLE);
    writeFnum = ChannelToFnum (channel, TCL_WRITABLE);

    if (readFnum >= 0) {
        readMode = fcntl (readFnum, F_GETFD, 0);
        if (readMode == -1)
            goto posixError;
    }
    if (writeFnum >= 0) {
        writeMode = fcntl (writeFnum, F_GETFD, 0);
        if (writeMode == -1)
            goto posixError;
    }

    /*
     * It's an error if both files are not the same.  This could only happen
     * if they were set outside of TclX.  While this maybe overly strict,
     * this may prevent bugs.
     */
    if ((readFnum >= 0) && (writeFnum >= 0) &&
        ((readMode & 1) != (writeMode & 1))) {
        TclX_AppendObjResult (interp, Tcl_GetChannelName (channel), 
                              ": read file of channel has close-on-exec ",
                              (readMode & 1) ? "on" : "off",
                              " and write file has it ",
                              (writeMode & 1) ? "on" : "off",
                              "; don't know how to get attribute for a ",
                              "channel configure this way", (char *) NULL);
        return TCL_ERROR;
    }

    *valuePtr = (readFnum >= 0) ? (readMode & 1) : (writeMode & 1);
    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp,  Tcl_GetChannelName (channel), ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
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
    int readFnum, writeFnum;

    readFnum = ChannelToFnum (channel, TCL_READABLE);
    writeFnum = ChannelToFnum (channel, TCL_WRITABLE);

    if (readFnum > 0) {
        if (fcntl (readFnum, F_SETFD, value ? 1 : 0) == -1)
            goto posixError;
    }
    if ((writeFnum > 0) && (readFnum != writeFnum)) {
        if (fcntl (writeFnum, F_SETFD, value ? 1 : 0) == -1)
            goto posixError;
    }
    return TCL_OK;

  posixError:
    TclX_AppendObjResult (interp,  Tcl_GetChannelName (channel), ": ",
                          Tcl_PosixError (interp), (char *) NULL);
    return TCL_ERROR;
}



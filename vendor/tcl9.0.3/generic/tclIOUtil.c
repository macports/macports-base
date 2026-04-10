/*
 * tclIOUtil.c --
 *
 *	Provides an interface for managing filesystems in Tcl, and also for
 *	creating a filesystem interface in Tcl arbitrary facilities.  All
 *	filesystem operations are performed via this interface.  Vince Darley
 *	is the primary author.  Other signifiant contributors are Karl
 *	Lehenbauer, Mark Diekhans and Peter da Silva.
 *
 * Copyright © 1991-1994 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 * Copyright © 2001-2004 Vincent Darley.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclIO.h"
#ifdef _WIN32
#   include "tclWinInt.h"
#endif
#include "tclFileSystem.h"

#ifdef TCL_TEMPLOAD_NO_UNLINK
#ifndef NO_FSTATFS
#include <sys/statfs.h>
#endif
#endif

/*
 * struct FilesystemRecord --
 *
 * An item in a linked list of registered filesystems
 */

typedef struct FilesystemRecord {
    void *clientData;		/* Client-specific data for the filesystem
				 * (can be NULL) */
    const Tcl_Filesystem *fsPtr;/* Pointer to filesystem dispatch table. */
    struct FilesystemRecord *nextPtr;
				/* The next registered filesystem, or NULL to
				 * indicate the end of the list. */
    struct FilesystemRecord *prevPtr;
				/* The previous filesystem, or NULL to indicate
				 * the ned of the list */
} FilesystemRecord;

/*
 */

typedef struct {
    int initialized;
    size_t cwdPathEpoch;	/* Compared with the global cwdPathEpoch to
				 * determine whether cwdPathPtr is stale. */
    size_t filesystemEpoch;
    Tcl_Obj *cwdPathPtr;	/* A private copy of cwdPathPtr. Updated when
				 * the value is accessed  and cwdPathEpoch has
				 * changed. */
    void *cwdClientData;
    FilesystemRecord *filesystemList;
    size_t claims;
} ThreadSpecificData;

/*
 * Forward declarations.
 */

static Tcl_NRPostProc	EvalFileCallback;
static FilesystemRecord*FsGetFirstFilesystem(void);
static void		FsThrExitProc(void *cd);
static Tcl_Obj *	FsListMounts(Tcl_Obj *pathPtr, const char *pattern);
static void		FsAddMountsToGlobResult(Tcl_Obj *resultPtr,
			    Tcl_Obj *pathPtr, const char *pattern,
			    Tcl_GlobTypeData *types);
static void		FsUpdateCwd(Tcl_Obj *cwdObj, void *clientData);
static void		FsRecacheFilesystemList(void);
static void		Claim(void);
static void		Disclaim(void);

static void *		DivertFindSymbol(Tcl_Interp *interp,
			    Tcl_LoadHandle loadHandle, const char *symbol);
static void		DivertUnloadFile(Tcl_LoadHandle loadHandle);

/*
 * Functions that provide native filesystem support. They are private and
 * should be used only here.  They should be called instead of calling Tclp...
 * native filesystem functions.  Others should use the Tcl_FS... functions
 * which ensure correct and complete virtual filesystem support.
 */

static Tcl_FSFilesystemSeparatorProc NativeFilesystemSeparator;
static Tcl_FSFreeInternalRepProc NativeFreeInternalRep;
static Tcl_FSFileAttrStringsProc NativeFileAttrStrings;
static Tcl_FSFileAttrsGetProc	NativeFileAttrsGet;
static Tcl_FSFileAttrsSetProc	NativeFileAttrsSet;

/*
 * Functions that support the native filesystem functions listed above.  They
 * are the same for win/unix, and not in tclInt.h because they are and should
 * be used only here.
 */

MODULE_SCOPE const char *const		tclpFileAttrStrings[];
MODULE_SCOPE const TclFileAttrProcs	tclpFileAttrProcs[];

/*
 * These these functions are not static either because routines in the native
 * (win/unix) directories call them or they are actually implemented in those
 * directories. They should be called from outside Tcl's native filesystem
 * routines. If we ever built the native filesystem support into a separate
 * code library, this could actually be enforced.
 */

Tcl_FSFilesystemPathTypeProc	TclpFilesystemPathType;
Tcl_FSInternalToNormalizedProc	TclpNativeToNormalized;
Tcl_FSStatProc			TclpObjStat;
Tcl_FSAccessProc		TclpObjAccess;
Tcl_FSMatchInDirectoryProc	TclpMatchInDirectory;
Tcl_FSChdirProc			TclpObjChdir;
Tcl_FSLstatProc			TclpObjLstat;
Tcl_FSCopyFileProc		TclpObjCopyFile;
Tcl_FSDeleteFileProc		TclpObjDeleteFile;
Tcl_FSRenameFileProc		TclpObjRenameFile;
Tcl_FSCreateDirectoryProc	TclpObjCreateDirectory;
Tcl_FSCopyDirectoryProc		TclpObjCopyDirectory;
Tcl_FSRemoveDirectoryProc	TclpObjRemoveDirectory;
Tcl_FSLinkProc			TclpObjLink;
Tcl_FSListVolumesProc		TclpObjListVolumes;

/*
 * The native filesystem dispatch table.  This could me made public but it
 * should only be accessed by the functions it points to, or perhaps
 * subordinate helper functions.
 */

const Tcl_Filesystem tclNativeFilesystem = {
    "native",
    sizeof(Tcl_Filesystem),
    TCL_FILESYSTEM_VERSION_2,
    TclNativePathInFilesystem,
    TclNativeDupInternalRep,
    NativeFreeInternalRep,
    TclpNativeToNormalized,
    TclNativeCreateNativeRep,
    TclpObjNormalizePath,
    TclpFilesystemPathType,
    NativeFilesystemSeparator,
    TclpObjStat,
    TclpObjAccess,
    TclpOpenFileChannel,
    TclpMatchInDirectory,
    TclpUtime,
#ifndef S_IFLNK
    NULL,
#else
    TclpObjLink,
#endif /* S_IFLNK */
    TclpObjListVolumes,
    NativeFileAttrStrings,
    NativeFileAttrsGet,
    NativeFileAttrsSet,
    TclpObjCreateDirectory,
    TclpObjRemoveDirectory,
    TclpObjDeleteFile,
    TclpObjCopyFile,
    TclpObjRenameFile,
    TclpObjCopyDirectory,
    TclpObjLstat,
    /* Needs casts since we're using version_2. */
    (Tcl_FSLoadFileProc *)(void *) TclpDlopen,
    (Tcl_FSGetCwdProc *) TclpGetNativeCwd,
    TclpObjChdir
};

/*
 * An initial record in the linked list for the native filesystem.  Remains at
 * the tail of the list and is never freed.  Currently the native filesystem is
 * hard-coded.  It may make sense to modify this to accommodate unconventional
 * uses of Tcl that provide no native filesystem.
 */

static FilesystemRecord nativeFilesystemRecord = {
    NULL,
    &tclNativeFilesystem,
    NULL,
    NULL
};

/*
 * Incremented each time the linked list of filesystems is modified.  For
 * multithreaded builds, invalidates all cached filesystem internal
 * representations.
 */

static size_t theFilesystemEpoch = 1;

/*
 * The linked list of filesystems.  To minimize locking each thread maintains a
 * local copy of this list.
 *
 */

static FilesystemRecord *filesystemList = &nativeFilesystemRecord;
TCL_DECLARE_MUTEX(filesystemMutex)

/*
 * A files-system indepent sense of the current directory.
 */

static Tcl_Obj *cwdPathPtr = NULL;
static size_t cwdPathEpoch = 0;	    /* The pathname of the current directory */
static void *cwdClientData = NULL;
TCL_DECLARE_MUTEX(cwdMutex)

static Tcl_ThreadDataKey fsDataKey;

/*
 * When a temporary copy of a file is created on the native filesystem in order
 * to load the file, an FsDivertLoad structure is created to track both the
 * actual unloadProc/clientData combination which was used, and the original and
 * modified filenames.  This makes it possible to correctly undo the entire
 * operation in order to unload the library.
 */

typedef struct {
    Tcl_LoadHandle loadHandle;
    Tcl_FSUnloadFileProc *unloadProcPtr;
    Tcl_Obj *divertedFile;
    const Tcl_Filesystem *divertedFilesystem;
    void *divertedFileNativeRep;
} FsDivertLoad;

/*
 * Obsolete string-based APIs that should be removed in a future release,
 * perhaps in Tcl 9.
 */

/* Obsolete */
int
Tcl_Stat(
    const char *path,		/* Pathname of file to stat (in current system
				 * encoding). */
    struct stat *oldStyleBuf)	/* Filled with results of stat call. */
{
    int ret;
    Tcl_StatBuf buf;
    Tcl_Obj *pathPtr = Tcl_NewStringObj(path,-1);

    Tcl_IncrRefCount(pathPtr);
    ret = Tcl_FSStat(pathPtr, &buf);
    Tcl_DecrRefCount(pathPtr);
    if (ret != -1) {
#ifndef TCL_WIDE_INT_IS_LONG
	Tcl_WideInt tmp1, tmp2, tmp3 = 0;

# define OUT_OF_RANGE(x) \
	(((Tcl_WideInt)(x)) < LONG_MIN || \
	 ((Tcl_WideInt)(x)) > LONG_MAX)
# define OUT_OF_URANGE(x) \
	(((Tcl_WideUInt)(x)) > ((Tcl_WideUInt)ULONG_MAX))

	/*
	 * Perform the result-buffer overflow check manually.
	 *
	 * Note that ino_t/ino64_t is unsigned...
	 *
	 * Workaround gcc warning of "comparison is always false due to
	 * limited range of data type" by assigning to tmp var of type
	 * Tcl_WideInt.
	 */

	tmp1 = (Tcl_WideInt) buf.st_ino;
	tmp2 = (Tcl_WideInt) buf.st_size;
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
	tmp3 = (Tcl_WideInt) buf.st_blocks;
#endif

	if (OUT_OF_URANGE(tmp1) || OUT_OF_RANGE(tmp2) || OUT_OF_RANGE(tmp3)) {
#if defined(EFBIG)
	    errno = EFBIG;
#elif defined(EOVERFLOW)
	    errno = EOVERFLOW;
#else
#error "What status should be returned for file size out of range?"
#endif
	    return -1;
	}

#   undef OUT_OF_RANGE
#   undef OUT_OF_URANGE
#endif /* !TCL_WIDE_INT_IS_LONG */

	/*
	 * Copy across all supported fields, with possible type coercion on
	 * those fields that change between the normal and lf64 versions of
	 * the stat structure (on Solaris at least). This is slow when the
	 * structure sizes coincide, but that's what you get for using an
	 * obsolete interface.
	 */

	oldStyleBuf->st_mode	= buf.st_mode;
	oldStyleBuf->st_ino	= (ino_t) buf.st_ino;
	oldStyleBuf->st_dev	= buf.st_dev;
	oldStyleBuf->st_rdev	= buf.st_rdev;
	oldStyleBuf->st_nlink	= buf.st_nlink;
	oldStyleBuf->st_uid	= buf.st_uid;
	oldStyleBuf->st_gid	= buf.st_gid;
	oldStyleBuf->st_size	= (off_t) buf.st_size;
	oldStyleBuf->st_atime	= Tcl_GetAccessTimeFromStat(&buf);
	oldStyleBuf->st_mtime	= Tcl_GetModificationTimeFromStat(&buf);
	oldStyleBuf->st_ctime	= Tcl_GetChangeTimeFromStat(&buf);
#ifdef HAVE_STRUCT_STAT_ST_BLKSIZE
	oldStyleBuf->st_blksize	= buf.st_blksize;
#endif
#ifdef HAVE_STRUCT_STAT_ST_BLOCKS
#ifdef HAVE_BLKCNT_T
	oldStyleBuf->st_blocks	= (blkcnt_t) buf.st_blocks;
#else
	oldStyleBuf->st_blocks	= (unsigned long) buf.st_blocks;
#endif
#endif
    }
    return ret;
}

/* Obsolete */
int
Tcl_Access(
    const char *path,		/* Pathname of file to access (in current
				 * system encoding). */
    int mode)			/* Permission setting. */
{
    int ret;
    Tcl_Obj *pathPtr = Tcl_NewStringObj(path,-1);

    Tcl_IncrRefCount(pathPtr);
    ret = Tcl_FSAccess(pathPtr,mode);
    Tcl_DecrRefCount(pathPtr);

    return ret;
}

/* Obsolete */
Tcl_Channel
Tcl_OpenFileChannel(
    Tcl_Interp *interp,		/* Interpreter for error reporting. May be
				 * NULL. */
    const char *path,		/* Pathname of file to open. */
    const char *modeString,	/* A list of POSIX open modes or a string such
				 * as "rw". */
    int permissions)		/* The modes to use if creating a new file. */
{
    Tcl_Channel ret;
    Tcl_Obj *pathPtr = Tcl_NewStringObj(path,-1);

    Tcl_IncrRefCount(pathPtr);
    ret = Tcl_FSOpenFileChannel(interp, pathPtr, modeString, permissions);
    Tcl_DecrRefCount(pathPtr);

    return ret;
}

/* Obsolete */
int
Tcl_Chdir(
    const char *dirName)
{
    int ret;
    Tcl_Obj *pathPtr = Tcl_NewStringObj(dirName,-1);
    Tcl_IncrRefCount(pathPtr);
    ret = Tcl_FSChdir(pathPtr);
    Tcl_DecrRefCount(pathPtr);
    return ret;
}

/* Obsolete */
char *
Tcl_GetCwd(
    Tcl_Interp *interp,
    Tcl_DString *cwdPtr)
{
    Tcl_Obj *cwd = Tcl_FSGetCwd(interp);

    if (cwd == NULL) {
	return NULL;
    }
    Tcl_DStringInit(cwdPtr);
    TclDStringAppendObj(cwdPtr, cwd);
    Tcl_DecrRefCount(cwd);
    return Tcl_DStringValue(cwdPtr);
}

int
Tcl_EvalFile(
    Tcl_Interp *interp,		/* Interpreter in which to evaluate the script. */
    const char *fileName)	/* Pathname of the file containing the script.
				 * Performs Tilde-substitution on this
				 * pathaname. */
{
    int ret;
    Tcl_Obj *pathPtr = Tcl_NewStringObj(fileName,-1);

    Tcl_IncrRefCount(pathPtr);
    ret = Tcl_FSEvalFile(interp, pathPtr);
    Tcl_DecrRefCount(pathPtr);
    return ret;
}

/*
 * The basic filesystem implementation.
 */

static void
FsThrExitProc(
    void *cd)
{
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)cd;
    FilesystemRecord *fsRecPtr = NULL, *tmpFsRecPtr = NULL;

    /*
     * Discard the cwd copy.
     */

    if (tsdPtr->cwdPathPtr != NULL) {
	Tcl_DecrRefCount(tsdPtr->cwdPathPtr);
	tsdPtr->cwdPathPtr = NULL;
    }
    if (tsdPtr->cwdClientData != NULL) {
	NativeFreeInternalRep(tsdPtr->cwdClientData);
    }

    /*
     * Discard the filesystems cache.
     */

    fsRecPtr = tsdPtr->filesystemList;
    while (fsRecPtr != NULL) {
	tmpFsRecPtr = fsRecPtr->nextPtr;
	fsRecPtr->fsPtr = NULL;
	Tcl_Free(fsRecPtr);
	fsRecPtr = tmpFsRecPtr;
    }
    tsdPtr->filesystemList = NULL;
    tsdPtr->initialized = 0;
}

int
TclFSCwdIsNative(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    /* if not yet initialized - ensure we'll once obtain cwd */
    if (!tsdPtr->cwdPathEpoch) {
	Tcl_Obj *temp = Tcl_FSGetCwd(NULL);
	if (temp) { Tcl_DecrRefCount(temp); }
    }

    if (tsdPtr->cwdClientData != NULL) {
	return 1;
    } else {
	return 0;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclFSCwdPointerEquals --
 *	Determine whether the given pathname is equal to the current working
 *	directory.
 *
 * Results:
 *	1 if equal, 0 otherwise.
 *
 * Side effects:
 *	Updates TSD if needed.
 *
 *	Stores a pointer to the current directory in *pathPtrPtr if it is not
 *	already there and the current directory is not NULL.
 *
 *	If *pathPtrPtr is not null its reference count is decremented
 *	before it is replaced.
 *----------------------------------------------------------------------
 */

int
TclFSCwdPointerEquals(
    Tcl_Obj **pathPtrPtr)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    Tcl_MutexLock(&cwdMutex);
    if (tsdPtr->cwdPathPtr == NULL
	    || tsdPtr->cwdPathEpoch != cwdPathEpoch) {
	if (tsdPtr->cwdPathPtr != NULL) {
	    Tcl_DecrRefCount(tsdPtr->cwdPathPtr);
	}
	if (tsdPtr->cwdClientData != NULL) {
	    NativeFreeInternalRep(tsdPtr->cwdClientData);
	}
	if (cwdPathPtr == NULL) {
	    tsdPtr->cwdPathPtr = NULL;
	} else {
	    tsdPtr->cwdPathPtr = Tcl_DuplicateObj(cwdPathPtr);
	    Tcl_IncrRefCount(tsdPtr->cwdPathPtr);
	}
	if (cwdClientData == NULL) {
	    tsdPtr->cwdClientData = NULL;
	} else {
	    tsdPtr->cwdClientData = TclNativeDupInternalRep(cwdClientData);
	}
	tsdPtr->cwdPathEpoch = cwdPathEpoch;
    }
    Tcl_MutexUnlock(&cwdMutex);

    if (tsdPtr->initialized == 0) {
	Tcl_CreateThreadExitHandler(FsThrExitProc, tsdPtr);
	tsdPtr->initialized = 1;
    }

    if (pathPtrPtr == NULL) {
	return (tsdPtr->cwdPathPtr == NULL);
    }

    if (tsdPtr->cwdPathPtr == *pathPtrPtr) {
	return 1;
    } else {
	Tcl_Size len1, len2;
	const char *str1, *str2;

	str1 = TclGetStringFromObj(tsdPtr->cwdPathPtr, &len1);
	str2 = TclGetStringFromObj(*pathPtrPtr, &len2);
	if ((len1 == len2) && !memcmp(str1, str2, len1)) {
	    /*
	     * The values are equal but the objects are different.  Cache the
	     * current structure in place of the old one.
	     */

	    Tcl_DecrRefCount(*pathPtrPtr);
	    *pathPtrPtr = tsdPtr->cwdPathPtr;
	    Tcl_IncrRefCount(*pathPtrPtr);
	    return 1;
	} else {
	    return 0;
	}
    }
}

static void
FsRecacheFilesystemList(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);
    FilesystemRecord *fsRecPtr, *tmpFsRecPtr = NULL, *toFree = NULL, *list;

    /*
     * Trash the current cache.
     */

    fsRecPtr = tsdPtr->filesystemList;
    while (fsRecPtr != NULL) {
	tmpFsRecPtr = fsRecPtr->nextPtr;
	fsRecPtr->nextPtr = toFree;
	toFree = fsRecPtr;
	fsRecPtr = tmpFsRecPtr;
    }

    /*
     * Locate tail of the global filesystem list.
     */

    Tcl_MutexLock(&filesystemMutex);
    fsRecPtr = filesystemList;
    while (fsRecPtr != NULL) {
	tmpFsRecPtr = fsRecPtr;
	fsRecPtr = fsRecPtr->nextPtr;
    }

    /*
     * Refill the cache, honouring the order.
     */

    list = NULL;
    fsRecPtr = tmpFsRecPtr;
    while (fsRecPtr != NULL) {
	tmpFsRecPtr = (FilesystemRecord *)Tcl_Alloc(sizeof(FilesystemRecord));
	*tmpFsRecPtr = *fsRecPtr;
	tmpFsRecPtr->nextPtr = list;
	tmpFsRecPtr->prevPtr = NULL;
	list = tmpFsRecPtr;
	fsRecPtr = fsRecPtr->prevPtr;
    }
    tsdPtr->filesystemList = list;
    tsdPtr->filesystemEpoch = theFilesystemEpoch;
    Tcl_MutexUnlock(&filesystemMutex);

    while (toFree) {
	FilesystemRecord *next = toFree->nextPtr;

	toFree->fsPtr = NULL;
	Tcl_Free(toFree);
	toFree = next;
    }

    /*
     * Make sure the above gets released on thread exit.
     */

    if (tsdPtr->initialized == 0) {
	Tcl_CreateThreadExitHandler(FsThrExitProc, tsdPtr);
	tsdPtr->initialized = 1;
    }
}

static FilesystemRecord *
FsGetFirstFilesystem(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);
    if (tsdPtr->filesystemList == NULL || ((tsdPtr->claims == 0)
	    && (tsdPtr->filesystemEpoch != theFilesystemEpoch))) {
	FsRecacheFilesystemList();
    }
    return tsdPtr->filesystemList;
}

/*
 * The epoch can is changed when a filesystems is added or removed, when
 * "system encoding" changes, and when env(HOME) changes.
 */

int
TclFSEpochOk(
    size_t filesystemEpoch)
{
    return (filesystemEpoch == 0 || filesystemEpoch == theFilesystemEpoch);
}

static void
Claim(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    tsdPtr->claims++;
}

static void
Disclaim(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    tsdPtr->claims--;
}

size_t
TclFSEpoch(void)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    return tsdPtr->filesystemEpoch;
}

/*
 * If non-NULL, take posession of clientData and free it later.
 */

static void
FsUpdateCwd(
    Tcl_Obj *cwdObj,
    void *clientData)
{
    Tcl_Size len = 0;
    const char *str = NULL;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    if (cwdObj != NULL) {
	str = TclGetStringFromObj(cwdObj, &len);
    }

    Tcl_MutexLock(&cwdMutex);
    if (cwdPathPtr != NULL) {
	Tcl_DecrRefCount(cwdPathPtr);
    }
    if (cwdClientData != NULL) {
	NativeFreeInternalRep(cwdClientData);
    }

    if (cwdObj == NULL) {
	cwdPathPtr = NULL;
	cwdClientData = NULL;
    } else {
	/*
	 * This must be stored as a string obj!
	 */

	cwdPathPtr = Tcl_NewStringObj(str, len);
	Tcl_IncrRefCount(cwdPathPtr);
	cwdClientData = TclNativeDupInternalRep(clientData);
    }

    if (++cwdPathEpoch == 0) {
	++cwdPathEpoch;
    }
    tsdPtr->cwdPathEpoch = cwdPathEpoch;
    Tcl_MutexUnlock(&cwdMutex);

    if (tsdPtr->cwdPathPtr) {
	Tcl_DecrRefCount(tsdPtr->cwdPathPtr);
    }
    if (tsdPtr->cwdClientData) {
	NativeFreeInternalRep(tsdPtr->cwdClientData);
    }

    if (cwdObj == NULL) {
	tsdPtr->cwdPathPtr = NULL;
	tsdPtr->cwdClientData = NULL;
    } else {
	tsdPtr->cwdPathPtr = Tcl_NewStringObj(str, len);
	tsdPtr->cwdClientData = clientData;
	Tcl_IncrRefCount(tsdPtr->cwdPathPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeFilesystem --
 *
 *	Clean up the filesystem.  After this, any call to a Tcl_FS... function
 *	fails.
 *
 *	If TclResetFilesystem is called later, it restores the filesystem to a
 *	pristine state.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees memory allocated for the filesystem.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeFilesystem(void)
{
    FilesystemRecord *fsRecPtr;

    /*
     * Assume that only one thread is active. Otherwise mutexes would be needed
     * around this code.
     * TO DO:  This assumption is false, isn't it?
     */

    if (cwdPathPtr != NULL) {
	Tcl_DecrRefCount(cwdPathPtr);
	cwdPathPtr = NULL;
	cwdPathEpoch = 0;
    }
    if (cwdClientData != NULL) {
	NativeFreeInternalRep(cwdClientData);
	cwdClientData = NULL;
    }

    /*
     * Remove all filesystems, freeing any allocated memory that is no longer
     * needed.
     */

    TclZipfsFinalize();
    fsRecPtr = filesystemList;
    while (fsRecPtr != NULL) {
	FilesystemRecord *tmpFsRecPtr = fsRecPtr->nextPtr;

	/*
	 * The native filesystem is static, so don't free it.
	 */

	if (fsRecPtr != &nativeFilesystemRecord) {
	    Tcl_Free(fsRecPtr);
	}
	fsRecPtr = tmpFsRecPtr;
    }
    if (++theFilesystemEpoch == 0) {
	++theFilesystemEpoch;
    }
    filesystemList = NULL;

    /*
     * filesystemList is now NULL. Any attempt to use the filesystem is likely
     * to fail.
     */

#ifdef _WIN32
    TclWinEncodingsCleanup();
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * TclResetFilesystem --
 *
 *	Restore the filesystem to a pristine state.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
TclResetFilesystem(void)
{
    filesystemList = &nativeFilesystemRecord;
    if (++theFilesystemEpoch == 0) {
	++theFilesystemEpoch;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSRegister --
 *
 *	Prepends to the list of registered fileystems a new FilesystemRecord
 *	for the given Tcl_Filesystem, which is added even if it is already in
 *	the list.  To determine whether the filesystem is already in the list,
 *	use Tcl_FSData().
 *
 *	Functions that use the list generally process it from head to tail and
 *	use the first filesystem that is suitable.  Therefore, when adding a
 *	diagnostic filsystem (one which simply reports all fs activity), it
 *	must be at the head of the list.  I.e. it must be the last one
 *	registered.
 *
 * Results:
 *	TCL_OK, or TCL_ERROR if memory for a new node in the list could
 *	not be allocated.
 *
 * Side effects:
 *	Allocates memory for a filesystem record and modifies the list of
 *	registered filesystems.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSRegister(
    void *clientData,		/* Client-specific data for this filesystem. */
    const Tcl_Filesystem *fsPtr)/* The filesystem record for the new fs. */
{
    FilesystemRecord *newFilesystemPtr;

    if (fsPtr == NULL) {
	return TCL_ERROR;
    }

    newFilesystemPtr = (FilesystemRecord *)Tcl_Alloc(sizeof(FilesystemRecord));

    newFilesystemPtr->clientData = clientData;
    newFilesystemPtr->fsPtr = fsPtr;

    Tcl_MutexLock(&filesystemMutex);

    newFilesystemPtr->nextPtr = filesystemList;
    newFilesystemPtr->prevPtr = NULL;
    if (filesystemList) {
	filesystemList->prevPtr = newFilesystemPtr;
    }
    filesystemList = newFilesystemPtr;

    /*
     * Increment the filesystem epoch counter since existing pathnames might
     * conceivably now belong to different filesystems.
     */

    if (++theFilesystemEpoch == 0) {
	++theFilesystemEpoch;
    }
    Tcl_MutexUnlock(&filesystemMutex);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSUnregister --
 *
 *	Removes the record for given filesystem from the list of registered
 *	filesystems. Refuses to remove the built-in (native) filesystem.  This
 *	might be changed in the future to allow a smaller Tcl core in which the
 *	native filesystem is not used at all, e.g. initializing Tcl over a
 *	network connection.
 *
 * Results:
 *	TCL_OK if the function pointer was successfully removed, or TCL_ERROR
 *	otherwise.
 *
 * Side effects:
 *	The list of registered filesystems is updated.  Memory for the
 *	corresponding FilesystemRecord is eventually freed.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSUnregister(
    const Tcl_Filesystem *fsPtr)/* The filesystem record to remove. */
{
    int retVal = TCL_ERROR;
    FilesystemRecord *fsRecPtr;

    Tcl_MutexLock(&filesystemMutex);

    /*
     * Traverse filesystemList in search of the record whose
     * 'fsPtr' member matches 'fsPtr' and remove that record from the list.
     * Do not revmoe the record for the native filesystem.
     */

    fsRecPtr = filesystemList;
    while ((retVal == TCL_ERROR) && (fsRecPtr != &nativeFilesystemRecord)) {
	if (fsRecPtr->fsPtr == fsPtr) {
	    if (fsRecPtr->prevPtr) {
		fsRecPtr->prevPtr->nextPtr = fsRecPtr->nextPtr;
	    } else {
		filesystemList = fsRecPtr->nextPtr;
	    }
	    if (fsRecPtr->nextPtr) {
		fsRecPtr->nextPtr->prevPtr = fsRecPtr->prevPtr;
	    }

	    /*
	     * Each cached pathname could now belong to a different filesystem,
	     * so increment the filesystem epoch counter to ensure that cached
	     * information about the removed filesystem is not used.
	     */

	    if (++theFilesystemEpoch == 0) {
		++theFilesystemEpoch;
	    }

	    Tcl_Free(fsRecPtr);

	    retVal = TCL_OK;
	} else {
	    fsRecPtr = fsRecPtr->nextPtr;
	}
    }

    Tcl_MutexUnlock(&filesystemMutex);
    return retVal;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSMatchInDirectory --
 *
 *	Search in the given pathname for files matching the given pattern.
 *	Used by [glob].  Processes just one pattern for one directory.  Callers
 *	such as TclGlob and DoGlob implement manage the searching of multiple
 *	directories in cases such as
 *		glob -dir $dir -join * pkgIndex.tcl
 *
 * Results:
 *
 *	TCL_OK, or TCL_ERROR
 *
 * Side effects:
 *	resultPtr is populated, or in the case of an TCL_ERROR, an error message is
 *	set in the interpreter.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSMatchInDirectory(
    Tcl_Interp *interp,		/* Interpreter to receive error messages, or
				 * NULL */
    Tcl_Obj *resultPtr,		/* List that results are added to. */
    Tcl_Obj *pathPtr,		/* Pathname of directory to search. If NULL,
				 * the current working directory is used. */
    const char *pattern,	/* Pattern to match.  If NULL, pathPtr must be
				 * a fully-specified pathname of a single
				 * file/directory which already exists and is
				 * of the correct type. */
    Tcl_GlobTypeData *types)	/* Specifies acceptable types.
				 * May be NULL. The directory flag is
				 * particularly significant. */
{
    const Tcl_Filesystem *fsPtr;
    Tcl_Obj *cwd, *tmpResultPtr, **elemsPtr;
    Tcl_Size resLength, i;
    int ret = -1;

    if (types != NULL && (types->type & TCL_GLOB_TYPE_MOUNT)) {
	/*
	 * Currently external callers may not query mounts, which would be a
	 * valuable future step. This is the only routine that knows about
	 * mounts, so we're being called recursively by ourself. Return no
	 * matches.
	 */

	return TCL_OK;
    }

    if (pathPtr != NULL) {
	fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    } else {
	fsPtr = NULL;
    }

    if (fsPtr != NULL) {
	/*
	 * A corresponding filesystem was found. Search within it.
	 */

	if (fsPtr->matchInDirectoryProc == NULL) {
	    Tcl_SetErrno(ENOENT);
	    return -1;
	}
	ret = fsPtr->matchInDirectoryProc(interp, resultPtr, pathPtr, pattern,
		types);
	if (ret == TCL_OK && pattern != NULL) {
	    FsAddMountsToGlobResult(resultPtr, pathPtr, pattern, types);
	}
	return ret;
    }

    if (pathPtr != NULL && TclGetString(pathPtr)[0] != '\0') {
	/*
	 * There is a pathname but it belongs to no known filesystem. Mayday!
	 */

	Tcl_SetErrno(ENOENT);
	return -1;
    }

    /*
     * The pathname is empty or NULL so search in the current working
     * directory.  matchInDirectoryProc prefixes each result with this
     * directory, so trim it from each result.  Deal with this here in the
     * generic code because otherwise every filesystem implementation of
     * Tcl_FSMatchInDirectory has to do it.
     */

    cwd = Tcl_FSGetCwd(NULL);
    if (cwd == NULL) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "glob couldn't determine the current working directory",
		    -1));
	}
	return TCL_ERROR;
    }

    fsPtr = Tcl_FSGetFileSystemForPath(cwd);
    if (fsPtr != NULL && fsPtr->matchInDirectoryProc != NULL) {
	TclNewObj(tmpResultPtr);
	Tcl_IncrRefCount(tmpResultPtr);
	ret = fsPtr->matchInDirectoryProc(interp, tmpResultPtr, cwd, pattern,
		types);
	if (ret == TCL_OK) {
	    FsAddMountsToGlobResult(tmpResultPtr, cwd, pattern, types);

	    /*
	     * resultPtr and tmpResultPtr are guaranteed to be distinct.
	     */

	    ret = TclListObjGetElements(interp, tmpResultPtr,
		    &resLength, &elemsPtr);
	    for (i=0 ; ret==TCL_OK && i<resLength ; i++) {
		ret = Tcl_ListObjAppendElement(interp, resultPtr,
			TclFSMakePathRelative(interp, elemsPtr[i], cwd));
	    }
	}
	TclDecrRefCount(tmpResultPtr);
    }
    Tcl_DecrRefCount(cwd);
    return ret;
}

/*
 *----------------------------------------------------------------------
 *
 * FsAddMountsToGlobResult --
 *	Adds any mounted pathnames to a set of results so that simple things
 *	like 'glob *' merge mounts and listings correctly.  Used by the
 *	Tcl_FSMatchInDirectory.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores a result in resultPtr.
 *
 *----------------------------------------------------------------------
 */

static void
FsAddMountsToGlobResult(
    Tcl_Obj *resultPtr,		/* The current list of matching pathnames. Must
				 * not be shared. */
    Tcl_Obj *pathPtr,		/* The directory that was searched. */
    const char *pattern,	/* Pattern to match mounts against. */
    Tcl_GlobTypeData *types)	/* Acceptable types.  May be NULL. The
				 * directory flag is particularly significant. */
{
    Tcl_Size mLength, gLength, i;
    int dir = (types == NULL || (types->type & TCL_GLOB_TYPE_DIR));
    Tcl_Obj *mounts = FsListMounts(pathPtr, pattern);

    if (mounts == NULL) {
	return;
    }

    if (TclListObjLength(NULL, mounts, &mLength) != TCL_OK || mLength == 0) {
	goto endOfMounts;
    }
    if (TclListObjLength(NULL, resultPtr, &gLength) != TCL_OK) {
	goto endOfMounts;
    }
    for (i=0 ; i<mLength ; i++) {
	Tcl_Obj *mElt;
	Tcl_Size j;
	int found = 0;

	Tcl_ListObjIndex(NULL, mounts, i, &mElt);

	for (j=0 ; j<gLength ; j++) {
	    Tcl_Obj *gElt;

	    Tcl_ListObjIndex(NULL, resultPtr, j, &gElt);
	    if (Tcl_FSEqualPaths(mElt, gElt)) {
		found = 1;
		if (!dir) {
		    /*
		     * We don't want to list this.
		     */

		    Tcl_ListObjReplace(NULL, resultPtr, j, 1, 0, NULL);
		    gLength--;
		}
		break;		/* Break out of for loop. */
	    }
	}
	if (!found && dir) {
	    Tcl_Obj *norm;
	    Tcl_Size len, mlen;

	    /*
	     * mElt is normalized and lies inside pathPtr so
	     * add to the result the right representation of mElt,
	     * i.e. the representation relative to pathPtr.
	     */

	    norm = Tcl_FSGetNormalizedPath(NULL, pathPtr);
	    if (norm != NULL) {
		const char *path, *mount;

		mount = TclGetStringFromObj(mElt, &mlen);
		path = TclGetStringFromObj(norm, &len);
		if (path[len-1] == '/') {
		    /*
		     * Deal with the root of the volume.
		     */

		    len--;
		}
		len++;		/* account for '/' in the mElt [Bug 1602539] */

		mElt = TclNewFSPathObj(pathPtr, mount + len, mlen - len);
		Tcl_ListObjAppendElement(NULL, resultPtr, mElt);
	    }
	    /*
	     * Not comparing mounts to mounts, so no need to increment gLength
	     */
	}
    }

  endOfMounts:
    Tcl_DecrRefCount(mounts);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSMountsChanged --
 *
 *	Announecs that mount points have changed or that the system encoding
 *	has changed.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The shared 'theFilesystemEpoch' is incremented, invalidating every
 *	exising cached internal representation of a pathname.  Avoid calling
 *	Tcl_FSMountsChanged whenever possible.  It must be called when:
 *
 *	(1) A filesystem is registered or unregistered. This is only necessary
 *	if the new filesystem accepts file pathnames as-is.  Normally the
 *	filesystem is really a shell which doesn't yet have any mount points
 *	established and so its 'pathInFilesystem' routine always fails.
 *	However, for safety, Tcl calls 'Tcl_FSMountsChanged' each time a
 *	filesystem is registered or unregistered.
 *
 *	(2) An additional mount point is established inside an existing
 *	filesystem (except for the native file system; see note below).
 *
 *	(3) A filesystem changes the list of available volumes (except for the
 *	native file system; see note below).
 *
 *	(4) The mapping from a string representation of a file to a full,
 *	normalized pathname changes.
 *
 *	Tcl has no control over (2) and (3), so each registered filesystem must
 *	call Tcl_FSMountsChnaged in each of those circumstances.
 *
 *	The reason for the exception in 2,3 for the native filesystem is that
 *	the native filesystem claims every file without determining whether
 *	the file exists, or even whether the pathname makes sense.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_FSMountsChanged(
    TCL_UNUSED(const Tcl_Filesystem *) /*fsPtr*/)
    /*
     * fsPtr is currently unused.  In the future it might invalidate files for
     * a particular filesystem, or take some other more advanced action.
     */
{
    /*
     * Increment the filesystem epoch to invalidate every existing cached
     * internal representation.
     */

    Tcl_MutexLock(&filesystemMutex);
    if (++theFilesystemEpoch == 0) {
	++theFilesystemEpoch;
    }
    Tcl_MutexUnlock(&filesystemMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSData --
 *
 *	Retrieves the clientData member of the given filesystem.
 *
 * Results:
 *	A clientData value, or NULL if the given filesystem is not registered.
 *	The clientData value itself may also be NULL.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_FSData(
    const Tcl_Filesystem *fsPtr) /* The filesystem to find in the list of
				  *  registered filesystems. */
{
    void *retVal = NULL;
    FilesystemRecord *fsRecPtr = FsGetFirstFilesystem();

    /*
     * Find the filesystem in and retrieve its clientData.
     */

    while ((retVal == NULL) && (fsRecPtr != NULL)) {
	if (fsRecPtr->fsPtr == fsPtr) {
	    retVal = fsRecPtr->clientData;
	}
	fsRecPtr = fsRecPtr->nextPtr;
    }

    return retVal;
}

/*
 *---------------------------------------------------------------------------
 *
 * TclFSNormalizeToUniquePath --
 *
 *	Converts the given pathname, containing no ../, ./ components, into a
 *	unique pathname for the given platform. On Unix the resulting pathname
 *	is free of symbolic links/aliases, and on Windows it is the long
 *	case-preserving form.
 *
 *
 * Results:
 *	Stores the resulting pathname in pathPtr and returns the offset of the
 *	last byte processed in pathPtr.
 *
 * Side effects:
 *	None (beyond the memory allocation for the result).
 *
 * Special notes:
 *	If the filesystem-specific normalizePathProcs can reintroduce ../, ./
 *	components into the pathname, this function does not return the correct
 *	result. This may be possible with symbolic links on unix.
 *
 *
 *---------------------------------------------------------------------------
 */

int
TclFSNormalizeToUniquePath(
    Tcl_Interp *interp,		/* Used for error messages. */
    Tcl_Obj *pathPtr,		/* An Pathname to normalize in-place.  Must be
				 * unshared. */
    int startAt)		/* Offset the string of pathPtr to start at.
				 * Must either be 0 or offset of a directory
				 * separator at the end of a pathname part that
				 * is already normalized, I.e. not the index of
				 * the byte just after the separator.  */
{
    FilesystemRecord *fsRecPtr, *firstFsRecPtr;

    Tcl_Size i;
    int isVfsPath = 0;
    const char *path;

    /*
     * Pathnames starting with a UNC prefix and ending with a colon character
     * are reserved for VFS use.  These names can not conflict with real UNC
     * pathnames per https://msdn.microsoft.com/en-us/library/gg465305.aspx and
     * rfc3986's definition of reg-name.
     *
     * We check these first to avoid useless calls to the native filesystem's
     * normalizePathProc.
     */
    path = TclGetStringFromObj(pathPtr, &i);

    if ((i >= 3) && ((path[0] == '/' && path[1] == '/')
	    || (path[0] == '\\' && path[1] == '\\'))) {
	for (i = 2; ; i++) {
	    if (path[i] == '\0') {
		break;
	    }
	    if (path[i] == path[0]) {
		break;
	    }
	}
	--i;
	if (path[i] == ':') {
	    isVfsPath = 1;
	}
    }

    /*
     * Call the the normalizePathProc routine of each registered filesystem.
     */
    firstFsRecPtr = FsGetFirstFilesystem();

    Claim();

    if (!isVfsPath) {
	/*
	 * Find and call the native filesystem handler first if there is one
	 * because the root of Tcl's filesystem is always a native filesystem
	 * (i.e., '/' on unix is native).
	 */

	for (fsRecPtr=firstFsRecPtr; fsRecPtr!=NULL; fsRecPtr=fsRecPtr->nextPtr) {
	    if (fsRecPtr->fsPtr != &tclNativeFilesystem) {
		continue;
	    }

	    /*
	     * TODO: Always call the normalizePathProc here because it should
	     * always exist.
	     */

	    if (fsRecPtr->fsPtr->normalizePathProc != NULL) {
		startAt = fsRecPtr->fsPtr->normalizePathProc(interp, pathPtr,
			startAt);
	    }
	    break;
	}
    }

    for (fsRecPtr=firstFsRecPtr; fsRecPtr!=NULL; fsRecPtr=fsRecPtr->nextPtr) {
	if (fsRecPtr->fsPtr == &tclNativeFilesystem) {
	    /*
	     * Skip the native system this time through.
	     */
	    continue;
	}

	if (fsRecPtr->fsPtr->normalizePathProc != NULL) {
	    startAt = fsRecPtr->fsPtr->normalizePathProc(interp, pathPtr,
		    startAt);
	}

	/*
	 * This efficiency check could be added:
	 *		if (retVal == length-of(pathPtr)) {break;}
	 * but there's not much benefit.
	 */
    }
    Disclaim();

    return startAt;
}

/*
 *---------------------------------------------------------------------------
 *
 * TclGetOpenMode --
 *
 *	Computes a POSIX mode mask for opening a file.
 *
 * Results:
 *	The mode to pass to "open", or -1 if an error occurs.
 *
 * Side effects:
 *	Sets *modeFlagsPtr to 1 to tell the caller to
 *	seek to EOF after opening the file, or to 0 otherwise.
 *
 *	Adds CHANNEL_RAW_MODE to *modeFlagsPtr to tell the caller
 *	to configure the channel as a binary channel.
 *
 *	If there is an error and interp is not NULL, sets
 *	interpreter result to an error message.
 *
 * Special note:
 *	Based on a prototype implementation contributed by Mark Diekhans.
 *
 *---------------------------------------------------------------------------
 */

int
TclGetOpenMode(
    Tcl_Interp *interp,		/* Interpreter, possibly NULL, to use for
				 * error reporting. */
    const char *modeString,	/* Mode string, e.g. "r+" or "RDONLY CREAT" */
    int *modeFlagsPtr)
{
    int mode, c, gotRW;
    Tcl_Size modeArgc, i;
    const char **modeArgv = NULL, *flag;

    /*
     * Check for the simpler fopen-like access modes like "r" which are
     * distinguished from the POSIX access modes by the presence of a
     * lower-case first letter.
     */

    *modeFlagsPtr = 0;
    mode = O_RDONLY;

    /*
     * Guard against wide characters before using byte-oriented routines.
     */

    if (!(modeString[0] & 0x80)
	    && islower(UCHAR(modeString[0]))) { /* INTL: ISO only. */
	switch (modeString[0]) {
	case 'r':
	    break;
	case 'w':
	    mode = O_WRONLY|O_CREAT|O_TRUNC;
	    break;
	case 'a':
	    /*
	     * Add O_APPEND for proper automatic seek-to-end-on-write by the
	     * OS. [Bug 680143]
	     */

	    mode = O_WRONLY|O_CREAT|O_APPEND;
	    *modeFlagsPtr |= 1;
	    break;
	default:
	    goto error;
	}
	i = 1;
	while (i<3 && modeString[i]) {
	    if (modeString[i] == modeString[i-1]) {
		goto error;
	    }
	    switch (modeString[i++]) {
	    case '+':
		/*
		 * Remove O_APPEND so that the seek command works. [Bug
		 * 1773127]
		 */

		mode = (mode & ~(O_ACCMODE|O_APPEND)) | O_RDWR;
		break;
	    case 'b':
		*modeFlagsPtr |= CHANNEL_RAW_MODE;
		break;
	    default:
		goto error;
	    }
	}
	if (modeString[i] != 0) {
	    goto error;
	}
	return mode;

    error:
	*modeFlagsPtr = 0;
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "illegal access mode \"%s\"", modeString));
	    Tcl_SetErrorCode(interp, "TCL", "OPENMODE", "INVALID", (char *)NULL);
	}
	return -1;
    }

    /*
     * The access modes are specified as a list of POSIX modes like O_CREAT.
     *
     * Tcl_SplitList must work correctly when interp is NULL.
     */

    if (Tcl_SplitList(interp, modeString, &modeArgc, &modeArgv) != TCL_OK) {
    invAccessMode:
	if (interp != NULL) {
	    Tcl_AddErrorInfo(interp,
		    "\n    while processing open access modes \"");
	    Tcl_AddErrorInfo(interp, modeString);
	    Tcl_AddErrorInfo(interp, "\"");
	    Tcl_SetErrorCode(interp, "TCL", "OPENMODE", "INVALID", (char *)NULL);
	}
	if (modeArgv) {
	    Tcl_Free((void *)modeArgv);
	}
	return -1;
    }

    gotRW = 0;
    for (i = 0; i < modeArgc; i++) {
	flag = modeArgv[i];
	c = flag[0];
	if ((c == 'R') && (strcmp(flag, "RDONLY") == 0)) {
	    if (gotRW) {
	    invRW:
		if (interp != NULL) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
				"invalid access mode \"%s\": modes RDONLY, "
				"RDWR, and WRONLY cannot be combined", flag));
		}
		goto invAccessMode;
	    }
	    mode = (mode & ~O_ACCMODE) | O_RDONLY;
	    gotRW = 1;
	} else if ((c == 'W') && (strcmp(flag, "WRONLY") == 0)) {
	    if (gotRW) {
		goto invRW;
	    }
	    mode = (mode & ~O_ACCMODE) | O_WRONLY;
	    gotRW = 1;
	} else if ((c == 'R') && (strcmp(flag, "RDWR") == 0)) {
	    if (gotRW) {
		goto invRW;
	    }
	    mode = (mode & ~O_ACCMODE) | O_RDWR;
	    gotRW = 1;
	} else if ((c == 'A') && (strcmp(flag, "APPEND") == 0)) {
	    if (mode & O_APPEND) {
	    accessFlagRepeated:
		if (interp) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"access mode \"%s\" repeated", flag));
		}
	    goto invAccessMode;
	    }
	    mode |= O_APPEND;
	    *modeFlagsPtr |= 1;
	} else if ((c == 'C') && (strcmp(flag, "CREAT") == 0)) {
	    if (mode & O_CREAT) {
	    goto accessFlagRepeated;
	    }
	    mode |= O_CREAT;
	} else if ((c == 'E') && (strcmp(flag, "EXCL") == 0)) {
	    if (mode & O_EXCL) {
		goto accessFlagRepeated;
	    }
	    mode |= O_EXCL;
	} else if ((c == 'N') && (strcmp(flag, "NOCTTY") == 0)) {
#ifdef O_NOCTTY
	    if (mode & O_NOCTTY) {
		goto accessFlagRepeated;
	    }
	    mode |= O_NOCTTY;
#else
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"access mode \"%s\" not supported by this system",
			flag));
	    }
	    goto invAccessMode;
#endif

	} else if ((c == 'N') && (strcmp(flag, "NONBLOCK") == 0)) {
#ifdef O_NONBLOCK
	    if (mode & O_NONBLOCK) {
		goto accessFlagRepeated;
	    }
	    mode |= O_NONBLOCK;
#else
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"access mode \"%s\" not supported by this system",
			flag));
	    }
	    goto invAccessMode;
#endif
	} else if ((c == 'T') && (strcmp(flag, "TRUNC") == 0)) {
	    if (mode & O_TRUNC) {
		goto accessFlagRepeated;
	    }
	    mode |= O_TRUNC;
	} else if ((c == 'B') && (strcmp(flag, "BINARY") == 0)) {
	    if (*modeFlagsPtr & CHANNEL_RAW_MODE) {
		goto accessFlagRepeated;
	    }
	    *modeFlagsPtr |= CHANNEL_RAW_MODE;
	} else {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"invalid access mode \"%s\": must be APPEND, BINARY, "
			"CREAT, EXCL, NOCTTY, NONBLOCK, RDONLY, RDWR, "
			"TRUNC, or WRONLY", flag));
	    }
	    goto invAccessMode;
	}
    }

    Tcl_Free((void *)modeArgv);

    if (!gotRW) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "access mode must include either RDONLY, RDWR, or WRONLY",
		    -1));
	}
	return -1;
    }
    return mode;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSEvalFile, Tcl_FSEvalFileEx, TclNREvalFile --
 *
 *	Reads a file and evaluates it as a script.
 *
 *	Tcl_FSEvalFile is Tcl_FSEvalFileEx without the encodingName argument.
 *
 *	TclNREvalFile is an NRE-enabled version of Tcl_FSEvalFileEx.
 *
 * Results:
 *	A standard Tcl result, which is either the result of executing the
 *	file or an error indicating why the file couldn't be read.
 *
 * Side effects:
 *	Arbitrary, depending on the contents of the script.  While the script
 *	is evaluated iPtr->scriptFile is a reference to pathPtr, and after the
 *	evaluation completes, has its original value restored again.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSEvalFile(
    Tcl_Interp *interp,		/* Interpreter that evaluates the script. */
    Tcl_Obj *pathPtr)		/* Pathname of file containing the script.
				 * Tilde-substitution is performed on this
				 * pathname. */
{
    return Tcl_FSEvalFileEx(interp, pathPtr, NULL);
}

int
Tcl_FSEvalFileEx(
    Tcl_Interp *interp,		/* Interpreter that evaluates the script. */
    Tcl_Obj *pathPtr,		/* Pathname of the file to process.
				 * Tilde-substitution is performed on this
				 * pathname. */
    const char *encodingName)	/* Either the name of an encoding or NULL to
				 * use the utf-8 encoding. */
{
    Tcl_Size length;
    int result = TCL_ERROR;
    Tcl_StatBuf statBuf;
    Tcl_Obj *oldScriptFile;
    Interp *iPtr;
    const char *string;
    Tcl_Channel chan;
    Tcl_Obj *objPtr;

    if (Tcl_FSGetNormalizedPath(interp, pathPtr) == NULL) {
	return result;
    }

    if (Tcl_FSStat(pathPtr, &statBuf) == -1) {
	Tcl_SetErrno(errno);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	return result;
    }
    chan = Tcl_FSOpenFileChannel(interp, pathPtr, "r", 0644);
    if (chan == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	return result;
    }

    /*
     * The eof character is \x1A (^Z). Tcl uses it on every platform to allow
     * for scripted documents. [Bug: 2040]
     */

    Tcl_SetChannelOption(interp, chan, "-eofchar", "\x1A");

    /*
     * If the encoding is specified, set the channel to that encoding.
     * Otherwise use utf-8.  If the encoding is unknown report an error.
     */

    if (encodingName == NULL) {
	encodingName = "utf-8";
    }
    if (Tcl_SetChannelOption(interp, chan, "-encoding", encodingName)
	    != TCL_OK) {
	Tcl_CloseEx(interp,chan,0);
	return result;
    }

    TclNewObj(objPtr);
    Tcl_IncrRefCount(objPtr);

    /*
     * Read first character of stream to check for utf-8 BOM
     */

    if (Tcl_ReadChars(chan, objPtr, 1, 0) == TCL_IO_FAILURE) {
	Tcl_CloseEx(interp, chan, 0);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	goto end;
    }
    string = TclGetString(objPtr);

    /*
     * If first character is not a BOM, append the remaining characters.
     * Otherwise, replace them. [Bug 3466099]
     */

    if (Tcl_ReadChars(chan, objPtr, TCL_INDEX_NONE,
	    memcmp(string, "\xEF\xBB\xBF", 3)) == TCL_IO_FAILURE) {
	Tcl_CloseEx(interp, chan, 0);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	goto end;
    }

    if (Tcl_CloseEx(interp, chan, 0) != TCL_OK) {
	goto end;
    }

    iPtr = (Interp *) interp;
    oldScriptFile = iPtr->scriptFile;
    iPtr->scriptFile = pathPtr;
    Tcl_IncrRefCount(iPtr->scriptFile);
    string = TclGetStringFromObj(objPtr, &length);

    /*
     * TIP #280:  Open a frame for the evaluated script.
     */

    iPtr->evalFlags |= TCL_EVAL_FILE;
    result = TclEvalEx(interp, string, length, 0, 1, NULL, string);

    /*
     * Restore the original iPtr->scriptFile value, but because the value may
     * have hanged during evaluation, don't assume it currently points to
     * pathPtr.
     */

    if (iPtr->scriptFile != NULL) {
	Tcl_DecrRefCount(iPtr->scriptFile);
    }
    iPtr->scriptFile = oldScriptFile;

    if (result == TCL_RETURN) {
	result = TclUpdateReturnInfo(iPtr);
    } else if (result == TCL_ERROR) {
	/*
	 * Record information about where the error occurred.
	 */

	const char *pathString = TclGetStringFromObj(pathPtr, &length);
	int limit = 150;
	int overflow = (length > limit);

	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (file \"%.*s%s\" line %d)",
		(overflow ? limit : (int)length), pathString,
		(overflow ? "..." : ""), Tcl_GetErrorLine(interp)));
    }

  end:
    Tcl_DecrRefCount(objPtr);
    return result;
}

int
TclNREvalFile(
    Tcl_Interp *interp,		/* Interpreter in which to evaluate the script. */
    Tcl_Obj *pathPtr,		/* Pathname of a file containing the script to
				 * evaluate. Tilde-substitution is performed on
				 * this pathname. */
    const char *encodingName)	/* The name of an encoding to use, or NULL to
				 *  use the utf-8 encoding. */
{
    Tcl_StatBuf statBuf;
    Tcl_Obj *oldScriptFile, *objPtr;
    Interp *iPtr;
    Tcl_Channel chan;
    const char *string;

    if (Tcl_FSGetNormalizedPath(interp, pathPtr) == NULL) {
	return TCL_ERROR;
    }

    if (Tcl_FSStat(pathPtr, &statBuf) == -1) {
	Tcl_SetErrno(errno);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    chan = Tcl_FSOpenFileChannel(interp, pathPtr, "r", 0644);
    if (chan == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    TclPkgFileSeen(interp, TclGetString(pathPtr));

    /*
     * The eof character is \x1A (^Z). Tcl uses it on every platform to allow
     * for scripted documents. [Bug: 2040]
     */

    Tcl_SetChannelOption(interp, chan, "-eofchar", "\x1A");

    /*
     * If the encoding is specified, set the channel to that encoding.
     * Otherwise use utf-8.  If the encoding is unknown report an error.
     */

    if (encodingName == NULL) {
	encodingName = "utf-8";
    }
    if (Tcl_SetChannelOption(interp, chan, "-encoding", encodingName)
	    != TCL_OK) {
	Tcl_CloseEx(interp, chan, 0);
	return TCL_ERROR;
    }

    TclNewObj(objPtr);
    Tcl_IncrRefCount(objPtr);

    /*
     * Read first character of stream to check for utf-8 BOM
     */

    if (Tcl_ReadChars(chan, objPtr, 1, 0) == TCL_IO_FAILURE) {
	Tcl_CloseEx(interp, chan, 0);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	Tcl_DecrRefCount(objPtr);
	return TCL_ERROR;
    }
    string = TclGetString(objPtr);

    /*
     * If first character is not a BOM, append the remaining characters.
     * Otherwise, replace them. [Bug 3466099]
     */

    if (Tcl_ReadChars(chan, objPtr, TCL_INDEX_NONE,
	    memcmp(string, "\xEF\xBB\xBF", 3)) == TCL_IO_FAILURE) {
	Tcl_CloseEx(interp, chan, 0);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't read file \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
	Tcl_DecrRefCount(objPtr);
	return TCL_ERROR;
    }

    if (Tcl_CloseEx(interp, chan, 0) != TCL_OK) {
	Tcl_DecrRefCount(objPtr);
	return TCL_ERROR;
    }

    iPtr = (Interp *) interp;
    oldScriptFile = iPtr->scriptFile;
    iPtr->scriptFile = pathPtr;
    Tcl_IncrRefCount(iPtr->scriptFile);

    /*
     * TIP #280:  Open a frame for the evaluated script.
     */

    iPtr->evalFlags |= TCL_EVAL_FILE;
    TclNRAddCallback(interp, EvalFileCallback, oldScriptFile, pathPtr, objPtr,
	    NULL);
    return TclNREvalObjEx(interp, objPtr, 0, NULL, INT_MIN);
}

static int
EvalFileCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    Tcl_Obj *oldScriptFile = (Tcl_Obj *)data[0];
    Tcl_Obj *pathPtr = (Tcl_Obj *)data[1];
    Tcl_Obj *objPtr = (Tcl_Obj *)data[2];

    /*
     * Restore the original iPtr->scriptFile value, but because the value may
     * have hanged during evaluation, don't assume it currently points to
     * pathPtr.
     */

    if (iPtr->scriptFile != NULL) {
	Tcl_DecrRefCount(iPtr->scriptFile);
    }
    iPtr->scriptFile = oldScriptFile;

    if (result == TCL_RETURN) {
	result = TclUpdateReturnInfo(iPtr);
    } else if (result == TCL_ERROR) {
	/*
	 * Record information about where the error occurred.
	 */

	Tcl_Size length;
	const char *pathString = TclGetStringFromObj(pathPtr, &length);
	const int limit = 150;
	int overflow = (length > limit);

	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (file \"%.*s%s\" line %d)",
		(overflow ? limit : (int)length), pathString,
		(overflow ? "..." : ""), Tcl_GetErrorLine(interp)));
    }

    Tcl_DecrRefCount(objPtr);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetErrno --
 *
 *	Currently the global variable "errno", but could in the future change
 *	to something else.
 *
 * Results:
 *	The current Tcl error number.
 *
 * Side effects:
 *	None. The value of the Tcl error code variable is only defined if it
 *	was set by a previous call to Tcl_SetErrno.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetErrno(void)
{
    /*
     * On some platforms errno is thread-local, as implemented by the C
     * library.
     */

    return errno;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetErrno --
 *
 *	Sets the Tcl error code to the given value. On some saner platforms
 *	this is implemented in the C library as a thread-local value , but this
 *	is *really* unsafe to assume!
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Modifies the Tcl error code value.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_SetErrno(
    int err)			/* The new value. */
{
    /*
     * On some platforms, errno is implemented by the C library as a thread
     * local value
     */

    errno = err;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PosixError --
 *
 *	Typically called after a UNIX kernel call returns an error.  Sets the
 *	interpreter errorCode to machine-parsable information about the error.
 *
 * Results:
 *	A human-readable sring describing the error.
 *
 * Side effects:
 *	Sets the errorCode value of the interpreter.
 *
 *----------------------------------------------------------------------
 */

const char *
Tcl_PosixError(
    Tcl_Interp *interp)		/* Interpreter to set the errorCode of */
{
    const char *id, *msg;

    msg = Tcl_ErrnoMsg(errno);
    id = Tcl_ErrnoId();
    if (interp) {
	Tcl_SetErrorCode(interp, "POSIX", id, msg, (char *)NULL);
    }
    return msg;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSStat --
 *	Calls 'statProc' of the filesystem corresponding to pathPtr.
 *
 *	Replaces the standard library "stat" routine.
 *
 * Results:
 *	See stat documentation.
 *
 * Side effects:
 *	See stat documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSStat(
    Tcl_Obj *pathPtr,		/* Pathname of the file to call stat on (in
				 *  current system encoding). */
    Tcl_StatBuf *buf)		/* A buffer to hold the results of the call to
				 *  stat. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL && fsPtr->statProc != NULL) {
	return fsPtr->statProc(pathPtr, buf);
    }
    Tcl_SetErrno(ENOENT);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSLstat --
 *	Calls the 'lstatProc' of the filesystem corresponding to pathPtr.
 *
 *	Replaces the library version of lstat.  If the filesystem doesn't
 *	provide lstatProc but does provide statProc, Tcl falls back to
 *	statProc.
 *
 * Results:
 *	See lstat documentation.
 *
 * Side effects:
 *	See lstat documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSLstat(
    Tcl_Obj *pathPtr,		/* Pathname of the file to call stat on (in
				 * current system encoding). */
    Tcl_StatBuf *buf)		/* Filled with results of that call to stat. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL) {
	if (fsPtr->lstatProc != NULL) {
	    return fsPtr->lstatProc(pathPtr, buf);
	}
	if (fsPtr->statProc != NULL) {
	    return fsPtr->statProc(pathPtr, buf);
	}
    }
    Tcl_SetErrno(ENOENT);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSAccess --
 *
 *	Calls 'accessProc' of the filesystem corresponding to pathPtr.
 *
 *	Replaces the library version of access.
 *
 * Results:
 *	See access documentation.
 *
 * Side effects:
 *	See access documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSAccess(
    Tcl_Obj *pathPtr,		/* Pathname of file to access (in current
				 * system encoding). */
    int mode)			/* Permission setting. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL && fsPtr->accessProc != NULL) {
	return fsPtr->accessProc(pathPtr, mode);
    }
    Tcl_SetErrno(ENOENT);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSOpenFileChannel --
 *
 *	Calls 'openfileChannelProc' of the filesystem corresponding to
 *	pathPtr.
 *
 * Results:
 *	The new channel, or NULL if the named file could not be opened.
 *
 * Side effects:
 *	Opens a channel, possibly creating the corresponding the file on the
 *	filesystem.
 *
 *----------------------------------------------------------------------
 */

Tcl_Channel
Tcl_FSOpenFileChannel(
    Tcl_Interp *interp,		/* Interpreter for error reporting, or NULL */
    Tcl_Obj *pathPtr,		/* Pathname of file to open. */
    const char *modeString,	/* A list of POSIX open modes or a string such
				 * as "rw". */
    int permissions)		/* What modes to use if opening the file
				 * involves creating it. */
{
    const Tcl_Filesystem *fsPtr;
    Tcl_Channel retVal = NULL;
    fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    if (fsPtr != NULL && fsPtr->openFileChannelProc != NULL) {
	int mode, modeFlags;

	/*
	 * Parse the mode to determine whether to seek at the outset
	 * and/or set the channel into binary mode.
	 */

	mode = TclGetOpenMode(interp, modeString, &modeFlags);
	if (mode == -1) {
	    return NULL;
	}

	/*
	 * Open the file.
	 */

	retVal = fsPtr->openFileChannelProc(interp, pathPtr, mode,
		permissions);
	if (retVal == NULL) {
	    return NULL;
	}

	/*
	 * Seek and/or set binary mode as determined above.
	 */

	if ((modeFlags & 1) && Tcl_Seek(retVal, (Tcl_WideInt) 0, SEEK_END)
		< (Tcl_WideInt) 0) {
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"could not seek to end of file while opening \"%s\": %s",
			TclGetString(pathPtr), Tcl_PosixError(interp)));
	    }
	    Tcl_CloseEx(NULL, retVal, 0);
	    return NULL;
	}
	if (modeFlags & CHANNEL_RAW_MODE) {
	    Tcl_SetChannelOption(interp, retVal, "-translation", "binary");
	}
	return retVal;
    }

    /*
     * File doesn't belong to any filesystem that can open it.
     */

    Tcl_SetErrno(ENOENT);
    if (interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't open \"%s\": %s",
		TclGetString(pathPtr), Tcl_PosixError(interp)));
    }
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSUtime --
 *
 *	Calls 'uTimeProc' of the filesystem corresponding to the given
 *	pathname.
 *
 *	Replaces the library version of utime.
 *
 * Results:
 *	See utime documentation.
 *
 * Side effects:
 *	See utime documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSUtime(
    Tcl_Obj *pathPtr,		/* Pathaname of file to call uTimeProc on */
    struct utimbuf *tval)	/* Specifies the access/modification
				 * times to use. Should not be modified. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    int err;

    if (fsPtr == NULL) {
	err = ENOENT;
    } else {
	if (fsPtr->utimeProc != NULL) {
	    return fsPtr->utimeProc(pathPtr, tval);
	}
	err = ENOTSUP;
    }
    Tcl_SetErrno(err);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * NativeFileAttrStrings --
 *
 *	Implements the platform-dependent 'file attributes' subcommand for the
 *	native filesystem, for listing the set of possible attribute strings.
 *	Part of Tcl's native filesystem support. Placed here because it is used
 *	under both Unix and Windows.
 *
 * Results:
 *	An array of strings
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static const char *const *
NativeFileAttrStrings(
    TCL_UNUSED(Tcl_Obj *),
    TCL_UNUSED(Tcl_Obj **))
{
    return tclpFileAttrStrings;
}

/*
 *----------------------------------------------------------------------
 *
 * NativeFileAttrsGet --
 *
 *	Implements the platform-dependent 'file attributes' subcommand for the
 *	native filesystem for 'get' operations.  Part of Tcl's native
 *	filesystem support.  Defined here because it is used under both Unix
 *	and Windows.
 *
 * Results:
 *	Standard Tcl return code.
 *
 *	If there was no error, stores in objPtrRef a pointer to a new object
 *	having a refCount of zero and  holding the result.  The caller should
 *	store it somewhere, e.g. as the Tcl result, or decrement its refCount
 *	to free it.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
NativeFileAttrsGet(
    Tcl_Interp *interp,		/* The interpreter for error reporting. */
    int index,			/* index of the attribute command. */
    Tcl_Obj *pathPtr,		/* Pathname of the file */
    Tcl_Obj **objPtrRef)	/* Where to store the a pointer to the result. */
{
    return tclpFileAttrProcs[index].getProc(interp, index, pathPtr,objPtrRef);
}

/*
 *----------------------------------------------------------------------
 *
 * NativeFileAttrsSet --
 *
 *	Implements the platform-dependent 'file attributes' subcommand for the
 *	native filesystem for 'set' operations.  A part of Tcl's native
 *	filesystem support, it is defined here because it is used under both
 *	Unix and Windows.
 *
 * Results:
 *	A standard Tcl return code.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
NativeFileAttrsSet(
    Tcl_Interp *interp,		/* The interpreter for error reporting. */
    int index,			/* index of the attribute command. */
    Tcl_Obj *pathPtr,		/* Pathname of the file */
    Tcl_Obj *objPtr)		/* The value to set. */
{
    return tclpFileAttrProcs[index].setProc(interp, index, pathPtr, objPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSFileAttrStrings --
 *
 *	Implements part of the hookable 'file attributes'
 *	subcommand.
 *
 *	Calls 'fileAttrStringsProc' of the filesystem corresponding to the
 *	given pathname.
 *
 * Results:
 *	Returns an array of strings, or returns NULL and stores in objPtrRef
 *	a pointer to a new Tcl list having a refCount of zero, and containing
 *	the file attribute strings.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

const char *const *
Tcl_FSFileAttrStrings(
    Tcl_Obj *pathPtr,
    Tcl_Obj **objPtrRef)
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL && fsPtr->fileAttrStringsProc != NULL) {
	return fsPtr->fileAttrStringsProc(pathPtr, objPtrRef);
    }
    Tcl_SetErrno(ENOENT);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFSFileAttrIndex --
 *
 *	Given an attribute name, determines the index of the attribute in the
 *	attribute table.
 *
 * Results:
 *	A standard Tcl result code.
 *
 *	If there is no error, stores the index in *indexPtr.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclFSFileAttrIndex(
    Tcl_Obj *pathPtr,		/* Pathname of the file. */
    const char *attributeName,	/* The name of the attribute. */
    int *indexPtr)		/* A place to store the result. */
{
    Tcl_Obj *listObj = NULL;
    const char *const *attrTable;

    /*
     * Get the attribute table for the file.
     */

    attrTable = Tcl_FSFileAttrStrings(pathPtr, &listObj);
    if (listObj != NULL) {
	Tcl_IncrRefCount(listObj);
    }

    if (attrTable != NULL) {
	/*
	 * It's a constant attribute table, so use T_GIFO.
	 */

	Tcl_Obj *tmpObj = Tcl_NewStringObj(attributeName, -1);
	int result;

	result = Tcl_GetIndexFromObj(NULL, tmpObj, attrTable, NULL, TCL_EXACT,
		indexPtr);
	TclDecrRefCount(tmpObj);
	if (listObj != NULL) {
	    TclDecrRefCount(listObj);
	}
	return result;
    } else if (listObj != NULL) {
	/*
	 * It's a non-constant attribute list, so do a literal search.
	 */

	Tcl_Size i, objc;
	Tcl_Obj **objv;

	if (TclListObjGetElements(NULL, listObj, &objc, &objv) != TCL_OK) {
	    TclDecrRefCount(listObj);
	    return TCL_ERROR;
	}
	for (i=0 ; i<objc ; i++) {
	    if (!strcmp(attributeName, TclGetString(objv[i]))) {
		TclDecrRefCount(listObj);
		*indexPtr = i;
		return TCL_OK;
	    }
	}
	TclDecrRefCount(listObj);
	return TCL_ERROR;
    } else {
	return TCL_ERROR;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSFileAttrsGet --
 *
 *	Implements read access for the hookable 'file attributes' subcommand.
 *
 *	Calls 'fileAttrsGetProc' of the filesystem corresponding to the given
 *	pathname.
 *
 * Results:
 *	A standard Tcl return code.
 *
 *	On success, stores in objPtrRef a pointer to a new Tcl_Obj having a
 *	refCount of zero, and containing the result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSFileAttrsGet(
    Tcl_Interp *interp,		/* The interpreter for error reporting. */
    int index,			/* The index of the attribute command. */
    Tcl_Obj *pathPtr,		/* The pathname of the file. */
    Tcl_Obj **objPtrRef)	/* A place to store the result. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL && fsPtr->fileAttrsGetProc != NULL) {
	return fsPtr->fileAttrsGetProc(interp, index, pathPtr, objPtrRef);
    }
    Tcl_SetErrno(ENOENT);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSFileAttrsSet --
 *
 *	Implements write access for the hookable 'file
 *	attributes' subcommand.
 *
 *	Calls 'fileAttrsSetProc' for the filesystem corresponding to the given
 *	pathname.
 *
 * Results:
 *	A standard Tcl return code.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSFileAttrsSet(
    Tcl_Interp *interp,		/* The interpreter for error reporting. */
    int index,			/* The index of the attribute command. */
    Tcl_Obj *pathPtr,		/* The pathname of the file. */
    Tcl_Obj *objPtr)		/* A place to store the result. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr != NULL && fsPtr->fileAttrsSetProc != NULL) {
	return fsPtr->fileAttrsSetProc(interp, index, pathPtr, objPtr);
    }
    Tcl_SetErrno(ENOENT);
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSGetCwd --
 *
 *	Replaces the library version of getcwd().
 *
 *	Most virtual filesystems do not implement cwdProc. Tcl maintains its
 *	own record of the current directory which it keeps synchronized with
 *	the filesystem corresponding to the pathname of the current directory
 *	if the filesystem provides a cwdProc (the native filesystem does).
 *
 *	If Tcl's current directory is not in the native filesystem, Tcl's
 *	current directory and the current directory of the process are
 *	different.  To avoid confusion, extensions should call Tcl_FSGetCwd to
 *	obtain the current directory from Tcl rather than from the operating
 *	system.
 *
 * Results:
 *	Returns a pointer to a Tcl_Obj having a refCount of 1 and containing
 *	the current thread's local copy of the global cwdPathPtr value.
 *
 *	Returns NULL if the current directory could not be determined, and
 *	leaves an error message in the interpreter's result.
 *
 * Side effects:
 *	Various objects may be freed and allocated.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSGetCwd(
    Tcl_Interp *interp)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);

    if (TclFSCwdPointerEquals(NULL)) {
	FilesystemRecord *fsRecPtr;
	Tcl_Obj *retVal = NULL;

	/*
	 * This is the first time this routine has been called. Call
	 * 'getCwdProc' for each registered filsystems until one returns
	 * something other than NULL, which is a pointer to the pathname of the
	 * current directory.
	 */

	fsRecPtr = FsGetFirstFilesystem();
	Claim();
	for (; (retVal == NULL) && (fsRecPtr != NULL);
		fsRecPtr = fsRecPtr->nextPtr) {
	    void *retCd;
	    TclFSGetCwdProc2 *proc2;

	    if (fsRecPtr->fsPtr->getCwdProc == NULL) {
		continue;
	    }

	    if (fsRecPtr->fsPtr->version == TCL_FILESYSTEM_VERSION_1) {
		retVal = fsRecPtr->fsPtr->getCwdProc(interp);
		continue;
	    }

	    proc2 = (TclFSGetCwdProc2 *) fsRecPtr->fsPtr->getCwdProc;
	    retCd = proc2(NULL);
	    if (retCd != NULL) {
		Tcl_Obj *norm;

		/*
		 * Found the pathname of the current directory.
		 */

		retVal = fsRecPtr->fsPtr->internalToNormalizedProc(retCd);
		Tcl_IncrRefCount(retVal);
		norm = TclFSNormalizeAbsolutePath(interp,retVal);
		if (norm != NULL) {
		    /*
		     * Assign to global storage the pathname of the current
		     * directory and copy it into thread-local storage as
		     * well.
		     *
		     * At system startup multiple threads could in principle
		     * call this function simultaneously, which is a little
		     * peculiar, but should be fine given the mutex locks in
		     * FSUPdateCWD.  Once some value is assigned to the global
		     * variable the 'else' branch below is always taken, which
		     * is simpler.
		     */

		    FsUpdateCwd(norm, retCd);
		    Tcl_DecrRefCount(norm);
		} else {
		    fsRecPtr->fsPtr->freeInternalRepProc(retCd);
		}
		Tcl_DecrRefCount(retVal);
		retVal = NULL;
		Disclaim();
		goto cdDidNotChange;
	    } else if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"error getting working directory name: %s",
			Tcl_PosixError(interp)));
	    }
	}
	Disclaim();

	if (retVal != NULL) {
	    /*
	     * On some platforms the pathname of the current directory might
	     * not be normalized.  For efficiency, ensure that it is
	     * normalized.  For the sake of efficiency, we want a completely
	     * normalized current working directory at all times.
	     */

	    Tcl_Obj *norm = TclFSNormalizeAbsolutePath(interp, retVal);

	    if (norm != NULL) {
		/*
		 * We found a current working directory, which is now in our
		 * global storage. We must make a copy. Norm already has a
		 * refCount of 1.
		 *
		 * Threading issue: Multiple threads at system startup could in
		 * principle call this function simultaneously. They will
		 * therefore each set the cwdPathPtr independently, which is a
		 * bit peculiar, but should be fine. Once we have a cwd, we'll
		 * always be in the 'else' branch below which is simpler.
		 */

		void *cd = (void *) Tcl_FSGetNativePath(norm);

		FsUpdateCwd(norm, TclNativeDupInternalRep(cd));
		Tcl_DecrRefCount(norm);
	    }
	    Tcl_DecrRefCount(retVal);
	} else {
	    /*
	     * retVal is NULL.  There is no current directory, which could be
	     * problematic.
	    */
	}
    } else {
	/*
	 * There is a thread-local value for the pathname of the current
	 * directory.  Give corresponding filesystem a chance update the value
	 * if it is out-of-date. This allows an error to be thrown if, for
	 * example, the permissions on the current working directory have
	 * changed.
	 */

	const Tcl_Filesystem *fsPtr =
		Tcl_FSGetFileSystemForPath(tsdPtr->cwdPathPtr);
	void *retCd = NULL;
	Tcl_Obj *retVal, *norm;

	if (fsPtr == NULL || fsPtr->getCwdProc == NULL) {
	    /*
	     * There is no corresponding filesystem or the filesystem does not
	     * have a getCwd routine. Just assume current local value is ok.
	     */
	    goto cdDidNotChange;
	}

	if (fsPtr->version == TCL_FILESYSTEM_VERSION_1) {
	    retVal = fsPtr->getCwdProc(interp);
	} else {
	    /*
	     * New API.
	     */

	    TclFSGetCwdProc2 *proc2 = (TclFSGetCwdProc2 *) fsPtr->getCwdProc;

	    retCd = proc2(tsdPtr->cwdClientData);
	    if (retCd == NULL && interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"error getting working directory name: %s",
			Tcl_PosixError(interp)));
	    }

	    if (retCd == tsdPtr->cwdClientData) {
		goto cdDidNotChange;
	    }

	    /*
	     * Looks like a new current directory.
	     */

	    retVal = fsPtr->internalToNormalizedProc(retCd);
	    Tcl_IncrRefCount(retVal);
	}

	if (retVal == NULL) {
	    /*
	     * The current directory could not be determined.  Reset the
	     * current direcory to ensure, for example, that 'pwd' does actually
	     * throw the correct error in Tcl.  This is tested for in the test
	     * suite on unix.
	     */

	    FsUpdateCwd(NULL, NULL);
	    goto cdDidNotChange;
	}

	norm = TclFSNormalizeAbsolutePath(interp, retVal);

	if (norm == NULL) {
	     /*
	     * 'norm' shouldn't ever be NULL, but we are careful.
	     */

	    /* Do nothing */
	    if (retCd != NULL) {
		fsPtr->freeInternalRepProc(retCd);
	    }
	} else if (norm == tsdPtr->cwdPathPtr) {
	    goto cdEqual;
	} else {
	     /*
	     * Determine whether the filesystem's answer is the same as the
	     * cached local value.  Since both 'norm' and 'tsdPtr->cwdPathPtr'
	     * are normalized pathnames, do something more efficient than
	     * calling 'Tcl_FSEqualPaths', and in addition avoid a nasty
	     * infinite loop bug when trying to normalize tsdPtr->cwdPathPtr.
	     */

	    Tcl_Size len1, len2;
	    const char *str1, *str2;

	    str1 = TclGetStringFromObj(tsdPtr->cwdPathPtr, &len1);
	    str2 = TclGetStringFromObj(norm, &len2);
	    if ((len1 == len2) && (strcmp(str1, str2) == 0)) {
		/*
		 * The pathname values are equal so retain the old pathname
		 * object which is probably already shared and free the
		 * normalized pathname that was just produced.
		 */
	    cdEqual:
		Tcl_DecrRefCount(norm);
		if (retCd != NULL) {
		    fsPtr->freeInternalRepProc(retCd);
		}
	    } else {
		/*
		 * The pathname of the current directory is not the same as
		 * this thread's local cached value.  Replace the local value.
		 */
		FsUpdateCwd(norm, retCd);
		Tcl_DecrRefCount(norm);
	    }
	}
	Tcl_DecrRefCount(retVal);
    }

  cdDidNotChange:
    if (tsdPtr->cwdPathPtr != NULL) {
	Tcl_IncrRefCount(tsdPtr->cwdPathPtr);
    }

    return tsdPtr->cwdPathPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSChdir --
 *
 *	Replaces the library version of chdir().
 *
 *	Calls 'chdirProc' of the filesystem that corresponds to the given
 *	pathname.
 *
 * Results:
 *	See chdir() documentation.
 *
 * Side effects:
 *	See chdir() documentation.
 *
 *	On success stores in cwdPathPtr the pathname of the new current
 *	directory.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSChdir(
    Tcl_Obj *pathPtr)
{
    const Tcl_Filesystem *fsPtr, *oldFsPtr = NULL;
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&fsDataKey);
    int retVal = -1;

    if (tsdPtr->cwdPathPtr != NULL) {
	oldFsPtr = Tcl_FSGetFileSystemForPath(tsdPtr->cwdPathPtr);
    }
    if (Tcl_FSGetNormalizedPath(NULL, pathPtr) == NULL) {
	Tcl_SetErrno(ENOENT);
	return retVal;
    }

    fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    if (fsPtr != NULL) {
	if (fsPtr->chdirProc != NULL) {
	    /*
	     * If this fails Tcl_SetErrno() has already been called.
	     */

	    retVal = fsPtr->chdirProc(pathPtr);
	} else {
	    /*
	     * Fallback to stat-based implementation.
	     */

	    Tcl_StatBuf buf;

	    if ((Tcl_FSStat(pathPtr, &buf) == 0) && (S_ISDIR(buf.st_mode))
		    && (Tcl_FSAccess(pathPtr, R_OK) == 0)) {
		/*
		 * stat was successful, and the file is a directory and is
		 * readable.  Can proceed to change the current directory.
		 */

		retVal = 0;
	    } else {
		 /*
		 * 'Tcl_SetErrno()' has already been called.
		 */
	    }
	}
    } else {
	Tcl_SetErrno(ENOENT);
    }

    if (retVal == 0) {

	 /* Assume that the cwd was actually changed to the normalized value
	  * just calculated, and cache that information.  */

	/*
	 * If the filesystem epoch changed recently, the normalized pathname or
	 * its internal handle may be different from what was found above.
	 * This can easily be the case with scripted documents . Therefore get
	 * the normalized pathname again. The correct value will have been
	 * cached as a result of the Tcl_FSGetFileSystemForPath call, above.
	 */

	Tcl_Obj *normDirName = Tcl_FSGetNormalizedPath(NULL, pathPtr);

	if (normDirName == NULL) {
	    /* Not really true, but what else to do? */
	    Tcl_SetErrno(ENOENT);
	    return -1;
	}
	if (normDirName != pathPtr) { Tcl_IncrRefCount(normDirName); }

	if (fsPtr == &tclNativeFilesystem) {
	    void *cd;
	    void *oldcd = tsdPtr->cwdClientData;

	    /*
	     * Assume that the native filesystem has a getCwdProc and that it
	     * is at version 2.
	     */

	    TclFSGetCwdProc2 *proc2 = (TclFSGetCwdProc2 *) fsPtr->getCwdProc;

	    cd = proc2(oldcd);
	    if (cd != oldcd) {
		/*
		 * Call getCwdProc() and store the resulting internal handle to
		 * compare things with it later.  This might not be
		 * exactly the same string as that of the fully normalized
		 * pathname.  For example, for the Windows internal handle the
		 * separator is the backslash character.  On Unix it might well
		 * be true that the internal handle is the fully normalized
		 * pathname and one could simply use:
		 *	cd = Tcl_FSGetNativePath(pathPtr);
		 * but this can't be guaranteed in the general case.  In fact,
		 * the internal handle could be any value the filesystem
		 * decides to use to identify a node.
		 */

		FsUpdateCwd(normDirName, cd);
	    }
	} else {
	    /*
	     * Tcl_FSGetCwd() synchronizes the file-global cwdPathPtr if
	     * needed.  However, if there is no 'getCwdProc', cwdPathPtr must be
	     * updated right now because there won't be another chance.  This
	     * block of code is currently executed whether or not the
	     * filesystem provides a getCwdProc, but it should in principle
	     * work to only call this block if fsPtr->getCwdProc == NULL.
	     */

	    FsUpdateCwd(normDirName, NULL);
	}

	if (oldFsPtr != NULL && fsPtr != oldFsPtr) {
	    /*
	     * The filesystem of the current directory is not the same as the
	     * filesystem of the previous current directory.  Invalidate All
	     * FsPath objects.
	     */
	    Tcl_FSMountsChanged(NULL);
	}
	if (normDirName != pathPtr) { Tcl_DecrRefCount(normDirName); }
    } else {
	/*
	 * The current directory is now changed or an error occurred and an
	 * error message is now set. Just continue.
	 */
    }

    return retVal;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSLoadFile --
 *
 *	Loads a dynamic shared object by passing the given pathname unmodified
 *	to Tcl_LoadFile, and provides pointers to the functions named by 'sym1'
 *	and 'sym2', and another pointer to a function that unloads the object.
 *
 * Results:
 *	A standard Tcl completion code. If an error occurs, sets the
 *	interpreter's result to an error message.
 *
 * Side effects:
 *	A dynamic shared object is loaded into memory.  This may later be
 *	unloaded by passing the handlePtr to *unloadProcPtr.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSLoadFile(
    Tcl_Interp *interp,		/* Used for error reporting. */
    Tcl_Obj *pathPtr,		/* Pathname of the file containing the dynamic
				 * shared object. */
    const char *sym1, const char *sym2,
				/* Names of two functions to find in the
				 * dynamic shared object. */
    Tcl_LibraryInitProc **proc1Ptr, Tcl_LibraryInitProc **proc2Ptr,
				/* Places to store pointers to the functions
				 * named by sym1 and sym2. */
    Tcl_LoadHandle *handlePtr,	/* A place to store the token for the loaded
				 * object.  Can be passed to
				 * (*unloadProcPtr)() to unload the file. */
    TCL_UNUSED(Tcl_FSUnloadFileProc **))
{
    const char *symbols[3];
    void *procPtrs[2];
    int res;

    symbols[0] = sym1;
    symbols[1] = sym2;
    symbols[2] = NULL;

    res = Tcl_LoadFile(interp, pathPtr, symbols, 0, procPtrs, handlePtr);
    if (res == TCL_OK) {
	*proc1Ptr = (Tcl_LibraryInitProc *) procPtrs[0];
	*proc2Ptr = (Tcl_LibraryInitProc *) procPtrs[1];
    } else {
	*proc1Ptr = *proc2Ptr = NULL;
    }

    return res;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LoadFile --
 *
 *	Load a dynamic shared object by calling 'loadFileProc' of the
 *	filesystem corresponding to the given pathname, and then finds within
 *	the loaded object the functions named in symbols[].
 *
 *	The given pathname is passed unmodified to `loadFileProc`, which
 *	decides how to resolve it.  On POSIX systems the native filesystem
 *	passes the given pathname to dlopen(), which resolves the filename
 *	according to its own set of rules.  This behaviour is not very
 *	compatible with virtual filesystems, and has other problems as
 *	documented for [load], so it is recommended to use an absolute
 *	pathname.
 *
 * Results:
 *	A standard Tcl completion code. If an error occurs, sets the
 *	interpreter result to an error message.
 *
 * Side effects:
 *	Memory is allocated for the new object. May be freed by calling
 *	TclFS_UnloadFile.
 *
 *----------------------------------------------------------------------
 */

/*
 * Modern HPUX allows the unlink (no ETXTBSY error) yet somehow trashes some
 * internal data structures, preventing any additional dynamic shared objects
 * from getting properly loaded. Only the first is ok.  Work around the issue
 * by not unlinking, i.e., emulating the behaviour of the older HPUX which
 * denied removal.
 *
 * Doing the unlink is also an issue within docker containers, whose AUFS
 * bungles this as well, see
 *     https://github.com/dotcloud/docker/issues/1911
 *
 */

#ifdef _WIN32
#define getenv(x) _wgetenv(L##x)
#define atoi(x) _wtoi(x)
#else
#define WCHAR char
#endif

static int
skipUnlink(
    Tcl_Obj *shlibFile)
{
    /*
     * Unlinking is not performed in the following cases:
     *
     * 1. The operating system is HPUX.
     *
     * 2. If the environment variable TCL_TEMPLOAD_NO_UNLINK is present and
     *    set to true (an integer > 0)
     *
     * 3. TCL_TEMPLOAD_NO_UNLINK is not true (an integer > 0) and AUFS
     *    filesystem can be detected (using statfs, if available).
     */

#ifdef hpux
    (void)shlibFile;
    return 1;
#else
    WCHAR *skipstr = getenv("TCL_TEMPLOAD_NO_UNLINK");

    if (skipstr && (skipstr[0] != '\0')) {
	return atoi(skipstr);
    }

#ifndef TCL_TEMPLOAD_NO_UNLINK
    (void)shlibFile;
#else
/* At built time TCL_TEMPLOAD_NO_UNLINK can be set manually to control whether
 * this automatic overriding of unlink is included.
 */
#ifndef NO_FSTATFS
    {
	struct statfs fs;
	/*
	 * Have fstatfs. May not have the AUFS super magic ... Indeed our build
	 * box is too old to have it directly in the headers. Define taken from
	 *     http://mooon.googlecode.com/svn/trunk/linux_include/linux/aufs_type.h
	 *     http://aufs.sourceforge.net/
	 * Better reference will be gladly accepted.
	 */
#ifndef AUFS_SUPER_MAGIC
/* AUFS_SUPER_MAGIC can disable/override the AUFS detection, i.e. for
 * testing if a newer AUFS does not have the bug any more.
*/
#define AUFS_SUPER_MAGIC ('a' << 24 | 'u' << 16 | 'f' << 8 | 's')
#endif /* AUFS_SUPER_MAGIC */
	if ((statfs(TclGetString(shlibFile), &fs) == 0)
		&& (fs.f_type == AUFS_SUPER_MAGIC)) {
	    return 1;
	}
    }
#endif /* ... NO_FSTATFS */
#endif /* ... TCL_TEMPLOAD_NO_UNLINK */

    /*
     * No HPUX, environment variable override, or AUFS detected.  Perform
     * unlink.
     */
    return 0;
#endif /* hpux */
}

int
Tcl_LoadFile(
    Tcl_Interp *interp,		/* Used for error reporting. */
    Tcl_Obj *pathPtr,		/* Pathname of the file containing the dynamic
				 * shared object. */
    const char *const symbols[],/* A null-terminated array of names of
				 * functions to find in the loaded object. */
    int flags,			/* Flags */
    void *procVPtrs,		/* A place to store pointers to the functions
				 *  named by symbols[]. */
    Tcl_LoadHandle *handlePtr)	/* A place to hold a token for the loaded object.
				 * Can be used by TclpFindSymbol. */
{
    void **procPtrs = (void **) procVPtrs;
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    const Tcl_Filesystem *copyFsPtr;
    Tcl_FSUnloadFileProc *unloadProcPtr;
    Tcl_Obj *copyToPtr;
    Tcl_LoadHandle newLoadHandle = NULL;
    Tcl_LoadHandle divertedLoadHandle = NULL;
    Tcl_FSUnloadFileProc *newUnloadProcPtr = NULL;
    FsDivertLoad *tvdlPtr;
    int retVal;
    int i;

    if (fsPtr == NULL) {
	Tcl_SetErrno(ENOENT);
	return TCL_ERROR;
    }

    if (fsPtr->loadFileProc != NULL) {
	retVal = ((Tcl_FSLoadFileProc2 *)(void *)(fsPtr->loadFileProc))
		(interp, pathPtr, handlePtr, &unloadProcPtr, flags);

	if (retVal == TCL_OK) {
	    if (*handlePtr == NULL) {
		return TCL_ERROR;
	    }
	    if (interp) {
		Tcl_ResetResult(interp);
	    }
	    goto resolveSymbols;
	}
	if (Tcl_GetErrno() != EXDEV) {
	    return retVal;
	}
    }

    /*
     * The filesystem doesn't support 'load'. Fall to the following:
     */

    /*
     * Make sure the file is accessible.
     */

    if (Tcl_FSAccess(pathPtr, R_OK) != 0) {
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "couldn't load library \"%s\": %s",
		    TclGetString(pathPtr), Tcl_PosixError(interp)));
	}
	return TCL_ERROR;
    }

#ifdef TCL_LOAD_FROM_MEMORY
    /*
     * The platform supports loading a dynamic shared object from memory.
     * Create a sufficiently large buffer, read the file into it, and then load
     * the dynamic shared object from the buffer:
     */

    {
	Tcl_Size ret;
	size_t size;
	void *buffer;
	Tcl_StatBuf statBuf;
	Tcl_Channel data;

	ret = Tcl_FSStat(pathPtr, &statBuf);
	if (ret < 0) {
	    goto mustCopyToTempAnyway;
	}
	size = statBuf.st_size;

	data = Tcl_FSOpenFileChannel(interp, pathPtr, "rb", 0666);
	if (!data) {
	    if (interp) {
		Tcl_ResetResult(interp);
	    }
	    goto mustCopyToTempAnyway;
	}
	buffer = TclpLoadMemoryGetBuffer(size);
	if (!buffer) {
	    Tcl_CloseEx(interp, data, 0);
	    goto mustCopyToTempAnyway;
	}
	ret = Tcl_Read(data, (char *)buffer, size);
	Tcl_CloseEx(interp, data, 0);
	ret = TclpLoadMemory(buffer, size, ret, TclGetString(pathPtr), handlePtr,
		&unloadProcPtr, flags);
	if (ret == TCL_OK && *handlePtr != NULL) {
	    goto resolveSymbols;
	}
    }

  mustCopyToTempAnyway:
#endif /* TCL_LOAD_FROM_MEMORY */

    /*
     * Get a temporary filename, first to copy the file into, and then to load.
     */

    copyToPtr = TclpTempFileNameForLibrary(interp, pathPtr);
    if (copyToPtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_IncrRefCount(copyToPtr);

    copyFsPtr = Tcl_FSGetFileSystemForPath(copyToPtr);
    if ((copyFsPtr == NULL) || (copyFsPtr == fsPtr)) {
	/*
	 * Tcl_FSLoadFile isn't available for the filesystem of the temporary
	 * file.  In order to avoid a possible infinite loop, do not attempt to
	 * load further.
	 */

	 /*
	  * Try to delete the file we probably created and then exit.
	  */

	Tcl_FSDeleteFile(copyToPtr);
	Tcl_DecrRefCount(copyToPtr);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "couldn't load from current filesystem", -1));
	}
	return TCL_ERROR;
    }

    if (TclCrossFilesystemCopy(interp, pathPtr, copyToPtr) != TCL_OK) {
	Tcl_FSDeleteFile(copyToPtr);
	Tcl_DecrRefCount(copyToPtr);
	return TCL_ERROR;
    }

#ifndef _WIN32
    /*
     * It might be necessary on some systems to set the appropriate permissions
     * on the file.  On Unix we could loop over the file attributes and set any
     * that are called "-permissions" to 0o700, but just do it directly instead:
     */

    {
	int index;
	Tcl_Obj *perm;

	TclNewLiteralStringObj(perm, "0o700");
	Tcl_IncrRefCount(perm);
	if (TclFSFileAttrIndex(copyToPtr, "-permissions", &index) == TCL_OK) {
	    Tcl_FSFileAttrsSet(NULL, index, copyToPtr, perm);
	}
	Tcl_DecrRefCount(perm);
    }
#endif

    /*
     * The cross-filesystem copy may have stored the number of bytes in the
     * result, so reset the result now.
     */

    if (interp) {
	Tcl_ResetResult(interp);
    }

    retVal = Tcl_LoadFile(interp, copyToPtr, symbols, flags, procPtrs,
	    &newLoadHandle);
    if (retVal != TCL_OK) {
	Tcl_FSDeleteFile(copyToPtr);
	Tcl_DecrRefCount(copyToPtr);
	return retVal;
    }

    /*
     * Try to delete the file immediately.  Some operatings systems allow this,
     * and it avoids leaving the copy laying around after exit.
     */

    if (!skipUnlink(copyToPtr) &&
	    (Tcl_FSDeleteFile(copyToPtr) == TCL_OK)) {
	Tcl_DecrRefCount(copyToPtr);

	/*
	 * Tell the caller all the details:  The package list maintained by
	 * 'load' stores the original (vfs) pathname, the handle of object
	 * loaded from the temporary file, and the unloadProcPtr.
	 */

	*handlePtr = newLoadHandle;
	if (interp) {
	    Tcl_ResetResult(interp);
	}
	return TCL_OK;
    }

    /*
     * Divert the unloading in order to unload and cleanup the temporary file.
     */

    tvdlPtr = (FsDivertLoad *)Tcl_Alloc(sizeof(FsDivertLoad));

    /*
     * Remember three pieces of information in order to clean up the diverted
     * load completely on platforms which allow proper unloading of code.
     */

    tvdlPtr->loadHandle = newLoadHandle;
    tvdlPtr->unloadProcPtr = newUnloadProcPtr;

    if (copyFsPtr != &tclNativeFilesystem) {
	/* refCount of copyToPtr is already incremented.  */
	tvdlPtr->divertedFile = copyToPtr;

	/*
	 * This is the filesystem for the temporary file the object was loaded
	 * from.  A reference to copyToPtr is already stored in
	 * tvdlPtr->divertedFile, so need need to increment the refCount again.
	 */

	tvdlPtr->divertedFilesystem = copyFsPtr;
	tvdlPtr->divertedFileNativeRep = NULL;
    } else {
	/*
	 * Grab the native representation.
	 */

	tvdlPtr->divertedFileNativeRep = TclNativeDupInternalRep(
		Tcl_FSGetInternalRep(copyToPtr, copyFsPtr));

	/*
	 * Don't keeep a reference to the Tcl_Obj or the native filesystem.
	 */

	tvdlPtr->divertedFile = NULL;
	tvdlPtr->divertedFilesystem = NULL;
	Tcl_DecrRefCount(copyToPtr);
    }

    copyToPtr = NULL;

    divertedLoadHandle = (Tcl_LoadHandle)Tcl_Alloc(sizeof(struct Tcl_LoadHandle_));
    divertedLoadHandle->clientData = tvdlPtr;
    divertedLoadHandle->findSymbolProcPtr = DivertFindSymbol;
    divertedLoadHandle->unloadFileProcPtr = DivertUnloadFile;
    *handlePtr = divertedLoadHandle;

    if (interp) {
	Tcl_ResetResult(interp);
    }
    return retVal;

  resolveSymbols:
    /*
     * handlePtr now contains a token for the loaded object.
     * Resolve the symbols.
     */

    if (symbols != NULL) {
	for (i=0 ; symbols[i] != NULL; i++) {
	    procPtrs[i] = Tcl_FindSymbol(interp, *handlePtr, symbols[i]);
	    if (procPtrs[i] == NULL) {
		/*
		 * At least one symbol in the list was not found.  Unload the
		 * file and return an error code.  Tcl_FindSymbol should have
		 * already left an appropriate error message.
		 */

		(*handlePtr)->unloadFileProcPtr(*handlePtr);
		*handlePtr = NULL;
		return TCL_ERROR;
	    }
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DivertFindSymbol --
 *
 *	Find a symbol in a shared library loaded by making a copying a file
 *	from the virtual filesystem to a native filesystem.
 *
 *----------------------------------------------------------------------
 */

static void *
DivertFindSymbol(
    Tcl_Interp *interp,		/* The relevant interpreter. */
    Tcl_LoadHandle loadHandle,	/* A handle to the diverted module. */
    const char *symbol)		/* The name of symbol to resolve. */
{
    FsDivertLoad *tvdlPtr = (FsDivertLoad *) loadHandle->clientData;
    Tcl_LoadHandle originalHandle = tvdlPtr->loadHandle;

    return originalHandle->findSymbolProcPtr(interp, originalHandle, symbol);
}

/*
 *----------------------------------------------------------------------
 *
 * DivertUnloadFile --
 *
 *	Unloads an object that was loaded from a temporary file copied from the
 *	virtual filesystem the native filesystem.
 *
 *----------------------------------------------------------------------
 */

static void
DivertUnloadFile(
    Tcl_LoadHandle loadHandle)	/* A handle for the loaded object. */
{
    FsDivertLoad *tvdlPtr = (FsDivertLoad *) loadHandle->clientData;
    Tcl_LoadHandle originalHandle;

    if (tvdlPtr == NULL) {
	/*
	 * tvdlPtr was provided by Tcl_LoadFile so it should not be NULL here.
	 */

	return;
    }
    originalHandle = tvdlPtr->loadHandle;

    /*
     * Call the real 'unloadfile' proc.  This must be called first so that the
     * shared library is actually unloaded by the OS. Otherwise, the following
     * 'delete' may fail because the shared library is still in use.
     */

    originalHandle->unloadFileProcPtr(originalHandle);

    /*
     * Determine which filesystem contains the temporary copy of the file.
     */

    if (tvdlPtr->divertedFilesystem == NULL) {
	/*
	 * Use the function for the native filsystem, which works even at
	 * this late stage.
	 */

	TclpDeleteFile(tvdlPtr->divertedFileNativeRep);
	NativeFreeInternalRep(tvdlPtr->divertedFileNativeRep);
    } else {
	/*
	 * Remove the temporary file.  If encodings have been cleaned up
	 * already, this may crash.
	 */

	if (tvdlPtr->divertedFilesystem->deleteFileProc(tvdlPtr->divertedFile)
		!= TCL_OK) {
	    /*
	     * This may have happened because Tcl is exiting, and encodings may
	     * have already been deleted or something else the filesystem
	     * depends on may be gone.
	     *
	     * TO DO:  Figure out how to delete this file more robustly, or
	     * give the filesystem the information it needs to delete the file
	     * more robustly.  One problem might be that the filesystem cannot
	     * extract the information it needs from the above pathname object
	     * because Tcl's entire filesystem apparatus (the code in this
	     * file) has been finalized and there is no way to get the native
	     * handle of the file.
	     */
	}

	/*
	 * This also decrements the refCount of the Tcl_Filesystem
	 * corresponding to this file. which might cause the filesystem to be
	 * deallocated if Tcl is exiting.
	 */

	Tcl_DecrRefCount(tvdlPtr->divertedFile);
    }

    Tcl_Free(tvdlPtr);
    Tcl_Free(loadHandle);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FindSymbol --
 *
 *	Find a symbol in a loaded object.
 *
 *	Previously filesystem-specific, but has been made portable by having
 *	TclpDlopen return a structure that includes procedure pointers.
 *
 * Results:
 *	Returns a pointer to the symbol if found.  Otherwise, sets
 *	an error message in the interpreter result and returns NULL.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_FindSymbol(
    Tcl_Interp *interp,		/* The relevant interpreter. */
    Tcl_LoadHandle loadHandle,	/* A handle for the loaded object. */
    const char *symbol)		/* The name of the symbol to resolve. */
{
    return loadHandle->findSymbolProcPtr(interp, loadHandle, symbol);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FSUnloadFile --
 *
 *	Unloads a loaded  object if unloading is supported for the object.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_FSUnloadFile(
    Tcl_Interp *interp,		/* The relevant interpreter. */
    Tcl_LoadHandle handle)	/* A handle for the object to unload. */
{
    if (handle->unloadFileProcPtr == NULL) {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "cannot unload: filesystem does not support unloading",
		    -1));
	}
	return TCL_ERROR;
    }
    if (handle->unloadFileProcPtr != NULL) {
	handle->unloadFileProcPtr(handle);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSLink --
 *
 *	Creates or inspects a link by calling 'linkProc' of the filesystem
 *	corresponding to the given pathname.  Replaces the library version of
 *	readlink().
 *
 * Results:
 *	If toPtr is NULL, a Tcl_Obj containing the value the symbolic link for
 *	'pathPtr', or NULL if a symbolic link was not accessible.  The caller
 *	should Tcl_DecrRefCount on the result to release it.  Otherwise NULL.
 *
 *	In this case the result has no additional reference count and need not
 *	be freed. The actual action to perform is given by the 'linkAction'
 *	flags, which is a combination of:
 *
 *		TCL_CREATE_SYMBOLIC_LINK
 *		TCL_CREATE_HARD_LINK
 *
 *	Most filesystems do not support linking across to different
 *	filesystems, so this function usually fails if the filesystem
 *	corresponding to toPtr is not the same as the filesystem corresponding
 *	to pathPtr.
 *
 * Side effects:
 *	Creates or sets a link if toPtr is not NULL.
 *
 *	See readlink().
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSLink(
    Tcl_Obj *pathPtr,		/* Pathaname of file. */
    Tcl_Obj *toPtr,		/* NULL or the pathname of a file to link to. */
    int linkAction)		/* Action to perform. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr) {
	if (fsPtr->linkProc == NULL) {
	    Tcl_SetErrno(ENOTSUP);
	    return NULL;
	} else {
	    return fsPtr->linkProc(pathPtr, toPtr, linkAction);
	}
    }

    /*
     * If S_IFLNK isn't defined the machine doesn't support symbolic links, so
     * the file can't possibly be a symbolic link. Generate an EINVAL error,
     * which is what happens on machines that do support symbolic links when
     * readlink is called for a file that isn't a symbolic link.
     */

#ifndef S_IFLNK
    errno = EINVAL; /* TODO: Change to Tcl_SetErrno()? */
#else
    Tcl_SetErrno(ENOENT);
#endif /* S_IFLNK */
    return NULL;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSListVolumes --
 *
 *	Lists the currently mounted volumes by calling `listVolumesProc` of
 *	each registered filesystem, and combining the results to form a list of
 *	volumes.
 *
 * Results:
 *	The list of volumes, in an object which has refCount 0.
 *
 * Side effects:
 *	None
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSListVolumes(void)
{
    FilesystemRecord *fsRecPtr;
    Tcl_Obj *resultPtr;

    /*
     * Call each "listVolumes" function of each registered filesystem in
     * succession. A non-NULL return value indicates the particular function
     * has succeeded.
     */

    TclNewObj(resultPtr);
    fsRecPtr = FsGetFirstFilesystem();
    Claim();
    while (fsRecPtr != NULL) {
	if (fsRecPtr->fsPtr->listVolumesProc != NULL) {
	    Tcl_Obj *thisFsVolumes = fsRecPtr->fsPtr->listVolumesProc();

	    if (thisFsVolumes != NULL) {
		Tcl_ListObjAppendList(NULL, resultPtr, thisFsVolumes);
		/*
		 * The refCount of each list returned by a `listVolumesProc`
		 * is already incremented.  Do not hang onto the list, though.
		 * It belongs to the filesystem.  Add its contents to the
		 * result we are building, and then decrement the refCount.
		 */
		Tcl_DecrRefCount(thisFsVolumes);
	    }
	}
	fsRecPtr = fsRecPtr->nextPtr;
    }
    Disclaim();

    return resultPtr;
}

/*
 *---------------------------------------------------------------------------
 *
 * FsListMounts --
 *
 *	Lists the mounts mathing the given pattern in the given directory.
 *
 * Results:
 *	A list, having a refCount of 0, of the matching mounts, or NULL if no
 *	search was performed because no filesystem provided a search routine.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static Tcl_Obj *
FsListMounts(
    Tcl_Obj *pathPtr,		/* Pathname of directory to search. */
    const char *pattern)	/* Pattern to match against. */
{
    FilesystemRecord *fsRecPtr;
    Tcl_GlobTypeData mountsOnly = { TCL_GLOB_TYPE_MOUNT, 0, NULL, NULL };
    Tcl_Obj *resultPtr = NULL;

    /*
     * Call the matchInDirectory function of each registered filesystem,
     * passing it 'mountsOnly'.  Results accumulate in resultPtr.
     */

    fsRecPtr = FsGetFirstFilesystem();
    Claim();
    while (fsRecPtr != NULL) {
	if (fsRecPtr->fsPtr != &tclNativeFilesystem &&
		fsRecPtr->fsPtr->matchInDirectoryProc != NULL) {
	    if (resultPtr == NULL) {
		TclNewObj(resultPtr);
	    }
	    fsRecPtr->fsPtr->matchInDirectoryProc(NULL, resultPtr, pathPtr,
		    pattern, &mountsOnly);
	}
	fsRecPtr = fsRecPtr->nextPtr;
    }
    Disclaim();

    return resultPtr;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSSplitPath --
 *
 *	Splits a pathname into its components.
 *
 * Results:
 *	A list with refCount of zero.
 *
 * Side effects:
 *	If lenPtr is not null, sets it to the number of elements in the result.
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSSplitPath(
    Tcl_Obj *pathPtr,		/* The pathname to split. */
    Tcl_Size *lenPtr)		/* A place to hold the number of pathname
				 * elements. */
{
    Tcl_Obj *result = NULL;	/* Just to squelch gcc warnings. */
    const Tcl_Filesystem *fsPtr;
    char separator = '/';
    Tcl_Size driveNameLength;
    const char *p;

    /*
     * Perform platform-specific splitting.
     */

    if (TclFSGetPathType(pathPtr, &fsPtr,
	    &driveNameLength) == TCL_PATH_ABSOLUTE) {
	if (fsPtr == &tclNativeFilesystem) {
	    return TclpNativeSplitPath(pathPtr, lenPtr);
	}
    } else {
	return TclpNativeSplitPath(pathPtr, lenPtr);
    }

    /* Assume each separator is a single character. */

    if (fsPtr->filesystemSeparatorProc != NULL) {
	Tcl_Obj *sep = fsPtr->filesystemSeparatorProc(pathPtr);

	if (sep != NULL) {
	    Tcl_IncrRefCount(sep);
	    separator = TclGetString(sep)[0];
	    Tcl_DecrRefCount(sep);
	}
    }

    /*
     * Add the drive name as first element of the result. The drive name may
     * contain strange characters like colons and sequences of forward slashes
     * For example, 'ftp://' is a valid drive name.
     */

    TclNewObj(result);
    p = TclGetString(pathPtr);
    Tcl_ListObjAppendElement(NULL, result,
	    Tcl_NewStringObj(p, driveNameLength));
    p += driveNameLength;

    /*
     * Add the remaining pathname elements to the list.
     */

    for (;;) {
	const char *elementStart = p;
	Tcl_Size length;

	while ((*p != '\0') && (*p != separator)) {
	    p++;
	}
	length = p - elementStart;
	if (length > 0) {
	    Tcl_Obj *nextElt;
	    nextElt = Tcl_NewStringObj(elementStart, length);
	    Tcl_ListObjAppendElement(NULL, result, nextElt);
	}
	if (*p++ == '\0') {
	    break;
	}
    }

    if (lenPtr != NULL) {
	TclListObjLength(NULL, result, lenPtr);
    }
    return result;
}
/*
 *----------------------------------------------------------------------
 *
 * TclGetPathType --
 *
 *	Helper function used by TclFSGetPathType and TclJoinPath.
 *
 * Results:
 *	One of TCL_PATH_ABSOLUTE, TCL_PATH_RELATIVE, or
 *	TCL_PATH_VOLUME_RELATIVE.
 *
 * Side effects:
 *	See **filesystemPtrptr, *driveNameLengthPtr and **driveNameRef,
 *
 *----------------------------------------------------------------------
 */

Tcl_PathType
TclGetPathType(
    Tcl_Obj *pathPtr,		/* Pathname to determine type of. */
    const Tcl_Filesystem **filesystemPtrPtr,
				/* If not NULL, a place in which to store a
				 * pointer to the filesystem for this pathname
				 * if it is absolute. */
    Tcl_Size *driveNameLengthPtr,
				/* If not NULL, a place in which to store the
				 * length of the volume name. */
    Tcl_Obj **driveNameRef)	/* If not NULL, for an absolute pathname, a
				 * place to store a pointer to an object with a
				 * refCount of 1, and whose value is the name
				 * of the volume. */
{
    Tcl_Size pathLen;
    const char *path = TclGetStringFromObj(pathPtr, &pathLen);
    Tcl_PathType type;

    type = TclFSNonnativePathType(path, pathLen, filesystemPtrPtr,
	    driveNameLengthPtr, driveNameRef);

    if (type != TCL_PATH_ABSOLUTE) {
	type = TclpGetNativePathType(pathPtr, driveNameLengthPtr,
		driveNameRef);
	if ((type == TCL_PATH_ABSOLUTE) && (filesystemPtrPtr != NULL)) {
	    *filesystemPtrPtr = &tclNativeFilesystem;
	}
    }
    return type;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFSNonnativePathType --
 *
 *	Helper function used by TclGetPathType. Checks whether the given
 *	pathname starts with a string which corresponds to a file volume in
 *	some registered filesystem other than the native one.  For speed and
 *	historical reasons the native filesystem has special hard-coded checks
 *	dotted here and there in the filesystem code.
 *
 * Results:
 *	One of TCL_PATH_ABSOLUTE or TCL_PATH_RELATIVE.  The filesystem
 *	reference will be set if and only if it is non-NULL and the function's
 *	return value is TCL_PATH_ABSOLUTE.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_PathType
TclFSNonnativePathType(
    const char *path,		/* Pathname to determine the type of. */
    Tcl_Size pathLen,		/* Length of the pathname. */
    const Tcl_Filesystem **filesystemPtrPtr,
				/* If not NULL, a  place to store a pointer to
				 * the filesystem for this pathname when it is
				 * an absolute pathname. */
    Tcl_Size *driveNameLengthPtr,
				/* If not NULL, a place to store the length of
				 * the volume name if the pathname is absolute. */
    Tcl_Obj **driveNameRef)	/* If not NULL, a place to store a pointer to
				 * an object having its refCount already
				 * incremented, and contining the name of the
				 * volume if the pathname is absolute. */
{
    FilesystemRecord *fsRecPtr;
    Tcl_PathType type = TCL_PATH_RELATIVE;

    /*
     * Determine whether the given pathname is an absolute pathname on some
     * filesystem other than the native filesystem.
     */

    fsRecPtr = FsGetFirstFilesystem();
    Claim();
    while (fsRecPtr != NULL) {
	/*
	 * Skip the native filesystem because otherwise some of the tests
	 * in the Tcl testsuite might fail because some of the tests
	 * artificially change the current platform (between win, unix) but the
	 * list of volumes obtained by calling fsRecPtr->fsPtr->listVolumesProc
	 * reflects the current (real) platform only. In particular, on Unix
	 * '/' matchs the beginning of certain absolute Windows pathnames
	 * starting '//' and those tests go wrong.
	 *
	 * There is another reason to skip the native filesystem:  Since the
	 * tclFilename.c code has nice fast 'absolute path' checkers, there is
	 * no reason to waste time doing that in this frequently-called
	 * function.  It is better to save the overhead of the native
	 * filesystem continuously returning a list of volumes.
	 */

	if ((fsRecPtr->fsPtr != &tclNativeFilesystem)
		&& (fsRecPtr->fsPtr->listVolumesProc != NULL)) {
	    Tcl_Size numVolumes;
	    Tcl_Obj *thisFsVolumes = fsRecPtr->fsPtr->listVolumesProc();

	    if (thisFsVolumes != NULL) {
		if (TclListObjLength(NULL, thisFsVolumes, &numVolumes)
			!= TCL_OK) {
		    /*
		     * This is VERY bad; the listVolumesProc didn't return a
		     * valid list. Set numVolumes to -1 to skip the loop below
		     * and just return with the current value of 'type'.
		     *
		     * It would be better to signal an error here, but
		     * Tcl_Panic seems a bit excessive.
		     */

		    numVolumes = TCL_INDEX_NONE;
		}
		while (numVolumes > 0) {
		    Tcl_Obj *vol;
		    Tcl_Size len;
		    const char *strVol;

		    numVolumes--;
		    Tcl_ListObjIndex(NULL, thisFsVolumes, numVolumes, &vol);
		    strVol = TclGetStringFromObj(vol,&len);
		    if (pathLen < len) {
			continue;
		    }
		    if (strncmp(strVol, path, len) == 0) {
			type = TCL_PATH_ABSOLUTE;
			if (filesystemPtrPtr != NULL) {
			    *filesystemPtrPtr = fsRecPtr->fsPtr;
			}
			if (driveNameLengthPtr != NULL) {
			    *driveNameLengthPtr = len;
			}
			if (driveNameRef != NULL) {
			    *driveNameRef = vol;
			    Tcl_IncrRefCount(vol);
			}
			break;
		    }
		}
		Tcl_DecrRefCount(thisFsVolumes);
		if (type == TCL_PATH_ABSOLUTE) {
		    /*
		     * No need to examine additional filesystems.
		     */

		    break;
		}
	    }
	}
	fsRecPtr = fsRecPtr->nextPtr;
    }
    Disclaim();
    return type;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSRenameFile --
 *
 *	If the two pathnames correspond to the same filesystem, call
 *	'renameFileProc' of that filesystem.  Otherwise return the POSIX error
 *	'EXDEV', and -1.
 *
 * Results:
 *	A standard Tcl error code if a rename function was called, or -1
 *	otherwise.
 *
 * Side effects:
 *	A file may be renamed.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSRenameFile(
    Tcl_Obj *srcPathPtr,	/* The pathname of a file or directory to be
				 * renamed. */
    Tcl_Obj *destPathPtr)	/* The new pathname for the file. */
{
    int retVal = -1;
    const Tcl_Filesystem *fsPtr, *fsPtr2;

    fsPtr = Tcl_FSGetFileSystemForPath(srcPathPtr);
    fsPtr2 = Tcl_FSGetFileSystemForPath(destPathPtr);

    if ((fsPtr == fsPtr2) && (fsPtr != NULL)
	    && (fsPtr->renameFileProc != NULL)) {
	retVal = fsPtr->renameFileProc(srcPathPtr, destPathPtr);
    }
    if (retVal == -1) {
	Tcl_SetErrno(EXDEV);
    }
    return retVal;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSCopyFile --
 *
 *	If both pathnames correspond to the same filesystem, calls
 *	'copyFileProc' of that filesystem.
 *
 *	In the native filesystems, 'copyFileProc' copies a link itself, not the
 *	thing the link points to.
 *
 * Results:
 *	A standard Tcl return code if a copyFileProc was called, or -1
 *	otherwise.
 *
 * Side effects:
 *	A file might be copied.  The POSIX error 'EXDEV' is set if a copy
 *	function was not called.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSCopyFile(
    Tcl_Obj *srcPathPtr,	/* The pathname of file to be copied. */
    Tcl_Obj *destPathPtr)	/* The new pathname to copy the file to. */
{
    int retVal = -1;
    const Tcl_Filesystem *fsPtr, *fsPtr2;

    fsPtr = Tcl_FSGetFileSystemForPath(srcPathPtr);
    fsPtr2 = Tcl_FSGetFileSystemForPath(destPathPtr);

    if (fsPtr == fsPtr2 && fsPtr != NULL && fsPtr->copyFileProc != NULL) {
	retVal = fsPtr->copyFileProc(srcPathPtr, destPathPtr);
    }
    if (retVal == -1) {
	Tcl_SetErrno(EXDEV);
    }
    return retVal;
}

/*
 *---------------------------------------------------------------------------
 *
 * TclCrossFilesystemCopy --
 *
 *	Helper for Tcl_FSCopyFile and Tcl_FSLoadFile.  Copies a file from one
 *	filesystem to another, overwiting any file that already exists.
 *
 * Results:
 *	A standard Tcl return code.
 *
 * Side effects:
 *	A file may be copied.
 *
 *---------------------------------------------------------------------------
 */

int
TclCrossFilesystemCopy(
    Tcl_Interp *interp,		/* For error messages. */
    Tcl_Obj *source,		/* Pathname of file to be copied. */
    Tcl_Obj *target)		/* Pathname to copy the file to. */
{
    int result = TCL_ERROR;
    int prot = 0666;
    Tcl_Channel in, out;
    Tcl_StatBuf sourceStatBuf;
    struct utimbuf tval;

    out = Tcl_FSOpenFileChannel(interp, target, "wb", prot);
    if (out == NULL) {
	/*
	 * Failed to open an output channel.  Bail out.
	 */
	goto done;
    }

    in = Tcl_FSOpenFileChannel(interp, source, "rb", prot);
    if (in == NULL) {
	/*
	 * Could not open an input channel.  Why didn't the caller check this?
	 */

	Tcl_CloseEx(interp, out, 0);
	goto done;
    }

    /*
     * Copy the file synchronously.  TO DO:  Maybe add an asynchronous option
     * to support virtual filesystems that are slow (e.g. network sockets).
     */

    if (TclCopyChannel(interp, in, out, -1, NULL) == TCL_OK) {
	result = TCL_OK;
    }

    /*
     * If the copy failed, assume that copy channel left an error message.
     */

    Tcl_CloseEx(interp, in, 0);
    Tcl_CloseEx(interp, out, 0);

    /*
     * Set modification date of copied file.
     */

    if (Tcl_FSLstat(source, &sourceStatBuf) == 0) {
	tval.actime = Tcl_GetAccessTimeFromStat(&sourceStatBuf);
	tval.modtime = Tcl_GetModificationTimeFromStat(&sourceStatBuf);
	Tcl_FSUtime(target, &tval);
    }

  done:
    return result;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSDeleteFile --
 *
 *	Calls 'deleteFileProc' of the filesystem corresponding to the given
 *	pathname.
 *
 * Results:
 *	A standard Tcl return code.
 *
 * Side effects:
 *	A file may be deleted.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSDeleteFile(
    Tcl_Obj *pathPtr)		/* Pathname of file to be removed (UTF-8). */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    int err;

    if (fsPtr == NULL) {
	err = ENOENT;
    } else {
	if (fsPtr->deleteFileProc != NULL) {
	    return fsPtr->deleteFileProc(pathPtr);
	}
	err = ENOTSUP;
    }
    Tcl_SetErrno(err);
    return -1;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSCreateDirectory --
 *
 *	Calls 'createDirectoryProc' of the filesystem corresponding to the
 *	given pathname.
 *
 * Results:
 *	A standard Tcl return code, or -1 if no createDirectoryProc is found.
 *
 * Side effects:
 *	A directory may be created.  POSIX error 'ENOENT' is set if no
 *	createDirectoryProc is found.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSCreateDirectory(
    Tcl_Obj *pathPtr)		/* Pathname of directory to create (UTF-8). */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    int err;

    if (fsPtr == NULL) {
	err = ENOENT;
    } else {
	if (fsPtr->createDirectoryProc != NULL) {
	    return fsPtr->createDirectoryProc(pathPtr);
	}
	err = ENOTSUP;
    }
    Tcl_SetErrno(err);
    return -1;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSCopyDirectory --
 *
 *	If both pathnames correspond to the same filesystem, calls
 *	'copyDirectoryProc' of that filesystem.
 *
 * Results:
 *	A standard Tcl return code, or -1 if no 'copyDirectoryProc' is found.
 *
 * Side effects:
 *	A directory may be copied. POSIX error 'EXDEV' is set if no
 *	copyDirectoryProc is found.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSCopyDirectory(
    Tcl_Obj *srcPathPtr,	/* The pathname of the directory to be
				 * copied. */
    Tcl_Obj *destPathPtr,	/* The pathname of the target directory. */
    Tcl_Obj **errorPtr)		/* If not NULL, and there is an error, a place
				 * to store a pointer to a new object, with
				 * its refCount already incremented, and
				 * containing the pathname name of file
				 * causing the error. */
{
    int retVal = -1;
    const Tcl_Filesystem *fsPtr, *fsPtr2;

    fsPtr = Tcl_FSGetFileSystemForPath(srcPathPtr);
    fsPtr2 = Tcl_FSGetFileSystemForPath(destPathPtr);

    if (fsPtr == fsPtr2 && fsPtr != NULL && fsPtr->copyDirectoryProc != NULL){
	retVal = fsPtr->copyDirectoryProc(srcPathPtr, destPathPtr, errorPtr);
    }
    if (retVal == -1) {
	Tcl_SetErrno(EXDEV);
    }
    return retVal;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSRemoveDirectory --
 *
 *	Calls 'removeDirectoryProc' of the filesystem corresponding to remove
 *	pathPtr.
 *
 * Results:
 *	A standard Tcl return code, or -1 if no removeDirectoryProc is found.
 *
 * Side effects:
 *	A directory may be removed.  POSIX error 'ENOENT' is set if no
 *	removeDirectoryProc is found.
 *
 *---------------------------------------------------------------------------
 */

int
Tcl_FSRemoveDirectory(
    Tcl_Obj *pathPtr,		/* The pathname of the directory to be removed. */
    int recursive,		/* If zero, removes only an empty directory.
				 * Otherwise, removes the directory and all its
				 * contents.  */
    Tcl_Obj **errorPtr)		/* If not NULL and an error occurs, stores a
				 * place to store a pointer to a new
				 * object having a refCount of 1 and containing
				 * the name of the file that produced an error. */
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr == NULL) {
	Tcl_SetErrno(ENOENT);
	return -1;
    }
    if (fsPtr->removeDirectoryProc == NULL) {
	Tcl_SetErrno(ENOTSUP);
	return -1;
    }

    if (recursive) {
	Tcl_Obj *cwdPtr = Tcl_FSGetCwd(NULL);
	if (cwdPtr != NULL) {
	    const char *cwdStr, *normPathStr;
	    Tcl_Size cwdLen, normLen;
	    Tcl_Obj *normPath = Tcl_FSGetNormalizedPath(NULL, pathPtr);

	    if (normPath != NULL) {
		normPathStr = TclGetStringFromObj(normPath, &normLen);
		cwdStr = TclGetStringFromObj(cwdPtr, &cwdLen);
		if ((cwdLen >= normLen) && (strncmp(normPathStr, cwdStr,
			normLen) == 0)) {
		    /*
		     * The cwd is inside the directory to be removed.  Change
		     * the cwd to [file dirname $path].
		     */

		    Tcl_Obj *dirPtr = TclPathPart(NULL, pathPtr,
			    TCL_PATH_DIRNAME);

		    Tcl_FSChdir(dirPtr);
		    Tcl_DecrRefCount(dirPtr);
		}
	    }
	    Tcl_DecrRefCount(cwdPtr);
	}
    }
    return fsPtr->removeDirectoryProc(pathPtr, recursive, errorPtr);
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSGetFileSystemForPath --
 *
 *	Produces the filesystem that corresponds to the given pathname.
 *
 * Results:
 *	The corresponding Tcl_Filesystem, or NULL if the pathname is invalid.
 *
 * Side effects:
 *	The internal representation of fsPtrPtr is converted to fsPathType if
 *	needed, and that internal representation is updated as needed.
 *
 *---------------------------------------------------------------------------
 */

const Tcl_Filesystem *
Tcl_FSGetFileSystemForPath(
    Tcl_Obj *pathPtr)
{
    FilesystemRecord *fsRecPtr;
    const Tcl_Filesystem *retVal = NULL;

    if (pathPtr == NULL) {
	Tcl_Panic("Tcl_FSGetFileSystemForPath called with NULL object");
	return NULL;
    }

    if (pathPtr->refCount == 0) {
	/*
	 * Avoid possible segfaults or nondeterministic memory leaks where the
	 * reference count has been incorreclty managed.
	 */
	Tcl_Panic("Tcl_FSGetFileSystemForPath called with object with refCount == 0");
	return NULL;
    }

    /* Start with an up-to-date copy of the filesystem. */
    fsRecPtr = FsGetFirstFilesystem();
    Claim();

    /*
     * Ensure that pathPtr is a valid pathname.
     */
    if (TclFSEnsureEpochOk(pathPtr, &retVal) != TCL_OK) {
	/* not a valid pathname */
	Disclaim();
	return NULL;
    } else if (retVal != NULL) {
	/*
	 * Found the filesystem in the internal representation of pathPtr.
	*/
	Disclaim();
	return retVal;
    }

    /*
     * Call each of the "pathInFilesystem" functions in succession until the
     * corresponding filesystem is found.
     */
    for (; fsRecPtr!=NULL ; fsRecPtr=fsRecPtr->nextPtr) {
	void *clientData = NULL;

	if (fsRecPtr->fsPtr->pathInFilesystemProc == NULL) {
	    continue;
	}

	if (fsRecPtr->fsPtr->pathInFilesystemProc(pathPtr, &clientData)!=-1) {
	    /* This is the filesystem for pathPtr.  Assume the type of pathPtr
	     * hasn't been changed by the above call to the
	     * pathInFilesystemProc, and cache this result in the internal
	     * representation of pathPtr.  */

	    TclFSSetPathDetails(pathPtr, fsRecPtr->fsPtr, clientData);
	    Disclaim();
	    return fsRecPtr->fsPtr;
	}
    }
    Disclaim();

    return NULL;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSGetNativePath --
 *
 *  See Tcl_FSGetInternalRep.
 *
 *---------------------------------------------------------------------------
 */

const void *
Tcl_FSGetNativePath(
    Tcl_Obj *pathPtr)
{
    return Tcl_FSGetInternalRep(pathPtr, &tclNativeFilesystem);
}

/*
 *---------------------------------------------------------------------------
 *
 * NativeFreeInternalRep --
 *
 *	Free a native internal representation.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory is released.
 *
 *---------------------------------------------------------------------------
 */

static void
NativeFreeInternalRep(
    void *clientData)
{
    Tcl_Free(clientData);
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSFileSystemInfo --
 *	Produce the type of a pathname and the type of its filesystem.
 *
 *
 * Results:
 *	A list where the first item is the name of the filesystem (e.g.
 *	"native" or "vfs"), and the second item is the type of the given
 *	pathname within that filesystem.
 *
 * Side effects:
 *	The internal representation of pathPtr may be converted to a
 *	fsPathType.
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSFileSystemInfo(
    Tcl_Obj *pathPtr)
{
    Tcl_Obj *resPtr;
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);

    if (fsPtr == NULL) {
	return NULL;
    }

    resPtr = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(NULL, resPtr,
	    Tcl_NewStringObj(fsPtr->typeName, -1));

    if (fsPtr->filesystemPathTypeProc != NULL) {
	Tcl_Obj *typePtr = fsPtr->filesystemPathTypeProc(pathPtr);

	if (typePtr != NULL) {
	    Tcl_ListObjAppendElement(NULL, resPtr, typePtr);
	}
    }

    return resPtr;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FSPathSeparator --
 *
 *	Produces the separator for given pathname.
 *
 * Results:
 *	A Tcl object having a refCount of zero.
 *
 * Side effects:
 *	The internal representation of pathPtr may be converted to a fsPathType
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_FSPathSeparator(
    Tcl_Obj *pathPtr)
{
    const Tcl_Filesystem *fsPtr = Tcl_FSGetFileSystemForPath(pathPtr);
    Tcl_Obj *resultObj;

    if (fsPtr == NULL) {
	return NULL;
    }

    if (fsPtr->filesystemSeparatorProc != NULL) {
	return fsPtr->filesystemSeparatorProc(pathPtr);
    }

    /*
     * Use the standard forward slash character if filesystem does not to
     * provide a filesystemSeparatorProc.
     */

    TclNewLiteralStringObj(resultObj, "/");
    return resultObj;
}

/*
 *---------------------------------------------------------------------------
 *
 * NativeFilesystemSeparator --
 *
 *	This function, part of the native filesystem support, returns the
 *	separator for the given pathname.
 *
 * Results:
 *	The separator character.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static Tcl_Obj *
NativeFilesystemSeparator(
    TCL_UNUSED(Tcl_Obj *) /*pathPtr*/)
{
    const char *separator = NULL;

    switch (tclPlatform) {
    case TCL_PLATFORM_UNIX:
	separator = "/";
	break;
    case TCL_PLATFORM_WINDOWS:
	separator = "\\";
	break;
    }
    return Tcl_NewStringObj(separator,1);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

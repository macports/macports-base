/*
 * tclZipfs.c --
 *
 *	Implementation of the ZIP filesystem used in TIP 430
 *	Adapted from the implementation for AndroWish.
 *
 * Copyright © 2016-2017 Sean Woods <yoda@etoyoc.com>
 * Copyright © 2013-2015 Christian Werner <chw@ch-werner.de>
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * This file is distributed in two ways:
 *   generic/tclZipfs.c file in the TIP430-enabled Tcl cores.
 *   compat/tclZipfs.c file in the tclconfig (TEA) file system, for pre-tip430
 *	projects.
 *
 * Helpful docs:
 * https://pkware.cachefly.net/webdocs/APPNOTE/APPNOTE-6.3.9.TXT
 * https://libzip.org/specifications/appnote_iz.txt
 */

#include "tclInt.h"
#include "tclFileSystem.h"

#ifdef _WIN32
# if defined(_WIN32) && defined (__clang__) && (__clang_major__ > 20)
#   pragma clang diagnostic ignored "-Wc++-keyword"
# endif
#else
#include <sys/mman.h>
#endif /* _WIN32*/

#ifndef MAP_FILE
#define MAP_FILE 0
#endif /* !MAP_FILE */
#define NOBYFOUR
#ifndef TBLS
#define TBLS 1
#endif

#if !defined(_WIN32) && !defined(NO_DLFCN_H)
#include <dlfcn.h>
#endif

/*
 * Macros to report errors only if an interp is present.
 */

#define ZIPFS_ERROR(interp,errstr) \
    do {								\
	if (interp) {							\
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(errstr, -1));	\
	}								\
    } while (0)
#define ZIPFS_MEM_ERROR(interp) \
    do {								\
	if (interp) {							\
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(			\
		    "out of memory", -1));				\
	    Tcl_SetErrorCode(interp, "TCL", "MALLOC", (char *)NULL);	\
	}								\
    } while (0)
#define ZIPFS_POSIX_ERROR(interp,errstr) \
    do {								\
	if (interp) {							\
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(			\
		    "%s: %s", errstr, Tcl_PosixError(interp)));		\
	}								\
    } while (0)
#define ZIPFS_ERROR_CODE(interp,errcode) \
    do {								\
	if (interp) {							\
	    Tcl_SetErrorCode(interp,					\
		    "TCL", "ZIPFS", errcode, (char *)NULL);		\
	}								\
    } while (0)

#include "zlib.h"
#include "crypt.h"
#include "zutil.h"
#include "crc32.h"

static const z_crc_t* crc32tab;

/*
** We are compiling as part of the core.
** TIP430 style zipfs prefix
*/

#define ZIPFS_VOLUME	  "//zipfs:/"
#define ZIPFS_ROOTDIR_DEPTH 3 /* Number of / in root mount */
#define ZIPFS_VOLUME_LEN  9
#define ZIPFS_APP_MOUNT	  ZIPFS_VOLUME "app"
#define ZIPFS_ZIP_MOUNT	  ZIPFS_VOLUME "lib/tcl"
#define ZIPFS_FALLBACK_ENCODING "cp437"

/*
 * Various constants and offsets found in ZIP archive files
 */

#define ZIP_SIG_LEN			4

/*
 * Local header of ZIP archive member (at very beginning of each member).
 * C can't express this structure type even close to portably (thanks for
 * nothing, Clang and MSVC).
 */
enum ZipLocalEntryOffsets {
    ZIP_LOCAL_SIG_OFFS = 0,		/* sig field offset */
    ZIP_LOCAL_VERSION_OFFS = 4,		/* version field offset */
    ZIP_LOCAL_FLAGS_OFFS = 6,		/* flags field offset */
    ZIP_LOCAL_COMPMETH_OFFS = 8,	/* compMethod field offset */
    ZIP_LOCAL_MTIME_OFFS = 10,		/* modTime field offset */
    ZIP_LOCAL_MDATE_OFFS = 12,		/* modDate field offset */
    ZIP_LOCAL_CRC32_OFFS = 14,		/* crc32 field offset */
    ZIP_LOCAL_COMPLEN_OFFS = 18,	/* compLen field offset */
    ZIP_LOCAL_UNCOMPLEN_OFFS = 22,	/* uncompLen field offset */
    ZIP_LOCAL_PATHLEN_OFFS = 26,	/* pathLen field offset */
    ZIP_LOCAL_EXTRALEN_OFFS = 28,	/* extraLen field offset */
    ZIP_LOCAL_HEADER_LEN = 30		/* header part length */
};
#if 0
/* Recent enough GCC can do this. */
#define PACKED_LITTLE_ENDIAN \
    __attribute__((packed, scalar_storage_order("little-endian")))
#else
#undef PACKED_LITTLE_ENDIAN	/* Really don't support this yet! */
#endif
#ifdef PACKED_LITTLE_ENDIAN
/*
 * Local header of ZIP archive member (at very beginning of each member).
 */
struct PACKED_LITTLE_ENDIAN ZipLocalEntry {
    uint32_t sig;		// == ZIP_LOCAL_HEADER_SIG
    uint16_t version;
    uint16_t flags;
    uint16_t compMethod;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compLen;
    uint32_t uncompLen;
    uint16_t pathLen;
    uint16_t extraLen;
};
#endif
#define ZIP_LOCAL_HEADER_SIG		0x04034b50

enum ZipLocalFlags {
    ZIP_LOCAL_FLAGS_UTF8 = 0x0800
};

/*
 * Central header of ZIP archive member at end of ZIP file.
 * C can't express this structure type even close to portably (thanks for
 * nothing, Clang and MSVC).
 */
enum ZipCentralEntryOffsets {
    ZIP_CENTRAL_SIG_OFFS = 0,		/* sig field offset */
    ZIP_CENTRAL_VERSIONMADE_OFFS = 4,	/* versionMade field offset */
    ZIP_CENTRAL_VERSION_OFFS = 6,	/* version field offset */
    ZIP_CENTRAL_FLAGS_OFFS = 8,		/* flags field offset */
    ZIP_CENTRAL_COMPMETH_OFFS = 10,	/* compMethod field offset */
    ZIP_CENTRAL_MTIME_OFFS = 12,	/* modTime field offset */
    ZIP_CENTRAL_MDATE_OFFS = 14,	/* modDate field offset */
    ZIP_CENTRAL_CRC32_OFFS = 16,	/* crc32 field offset */
    ZIP_CENTRAL_COMPLEN_OFFS = 20,	/* compLen field offset */
    ZIP_CENTRAL_UNCOMPLEN_OFFS = 24,	/* uncompLen field offset */
    ZIP_CENTRAL_PATHLEN_OFFS = 28,	/* pathLen field offset */
    ZIP_CENTRAL_EXTRALEN_OFFS = 30,	/* extraLen field offset */
    ZIP_CENTRAL_FCOMMENTLEN_OFFS = 32,	/* commentLen field offset */
    ZIP_CENTRAL_DISKFILE_OFFS = 34,	/* diskFile field offset */
    ZIP_CENTRAL_IATTR_OFFS = 36,	/* intAttr field offset */
    ZIP_CENTRAL_EATTR_OFFS = 38,	/* extAttr field offset */
    ZIP_CENTRAL_LOCALHDR_OFFS = 42,	/* localHeaderOffset field offset */
    ZIP_CENTRAL_HEADER_LEN = 46		/* header part length */
};
#ifdef PACKED_LITTLE_ENDIAN
/*
 * Central header of ZIP archive member at end of ZIP file.
 */
struct PACKED_LITTLE_ENDIAN ZipCentralEntry {
    uint32_t sig;		// == ZIP_CENTRAL_HEADER_SIG
    uint16_t versionMade;
    uint16_t version;
    uint16_t flags;
    uint16_t compMethod;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compLen;
    uint32_t uncompLen;
    uint16_t pathLen;
    uint16_t extraLen;
    uint16_t commentLen;
    uint16_t diskFile;
    uint16_t intAttr;
    uint32_t extAttr;
    uint32_t localHeaderOffset;
};
#endif
#define ZIP_CENTRAL_HEADER_SIG		0x02014b50

/*
 * Central end signature at very end of ZIP file.
 * C can't express this structure type even close to portably (thanks for
 * nothing, Clang and MSVC).
 */
enum ZipCentralMainOffsets {
    ZIP_CENTRAL_END_SIG_OFFS = 0,	/* sig field offset */
    ZIP_CENTRAL_DISKNO_OFFS = 4,	/* diskNum field offset */
    ZIP_CENTRAL_DISKDIR_OFFS = 6,	/* diskDir field offset */
    ZIP_CENTRAL_ENTS_OFFS = 8,		/* entriesOffset field offset */
    ZIP_CENTRAL_TOTALENTS_OFFS = 10,	/* totalEntries field offset */
    ZIP_CENTRAL_DIRSIZE_OFFS = 12,	/* dirSize field offset */
    ZIP_CENTRAL_DIRSTART_OFFS = 16,	/* dirStart field offset */
    ZIP_CENTRAL_COMMENTLEN_OFFS = 20,	/* commentLen field offset */
    ZIP_CENTRAL_END_LEN = 22		/* header part length */
};
#ifdef PACKED_LITTLE_ENDIAN
/*
 * Central end signature at very end of ZIP file.
 */
struct PACKED_LITTLE_ENDIAN ZipCentralMain {
    uint32_t sig;		// == ZIP_CENTRAL_END_SIG
    uint16_t diskNum;
    uint16_t diskDir;
    uint16_t entriesOffset;
    uint16_t totalEntries;
    uint32_t dirSize;
    uint32_t dirStart;
    uint16_t commentLen;
}
#endif
#define ZIP_CENTRAL_END_SIG		0x06054b50

#define ZIP_MIN_VERSION			20
enum ZipCompressionMethods {
    ZIP_COMPMETH_STORED = 0,
    ZIP_COMPMETH_DEFLATED = 8
};

#define ZIP_PASSWORD_END_SIG		0x5a5a4b50
#define ZIP_CRYPT_HDR_LEN		12

#define ZIP_MAX_FILE_SIZE		INT_MAX
#define DEFAULT_WRITE_MAX_SIZE		ZIP_MAX_FILE_SIZE

/*
 * Mutex to protect localtime(3) when no reentrant version available.
 */

#if !defined(_WIN32) && !defined(HAVE_LOCALTIME_R) && TCL_THREADS
TCL_DECLARE_MUTEX(localtimeMutex)
#endif /* !_WIN32 && !HAVE_LOCALTIME_R && TCL_THREADS */

/*
 * Forward declaration.
 */

struct ZipEntry;

/*
 * In-core description of mounted ZIP archive file.
 */

typedef struct ZipFile {
    char *name;			/* Archive name */
    size_t nameLength;		/* Length of archive name */
    char isMemBuffer;		/* When true, not a file but a memory buffer */
    Tcl_Channel chan;		/* Channel handle or NULL */
    unsigned char *data;	/* Memory mapped or malloc'ed file */
    size_t length;		/* Length of memory mapped file */
    void *ptrToFree;		/* Non-NULL if malloc'ed file */
    size_t numFiles;		/* Number of files in archive */
    size_t baseOffset;		/* Archive start */
    size_t passOffset;		/* Password start */
    size_t directoryOffset;	/* Archive directory start */
    size_t directorySize;	/* Size of archive directory */
    unsigned char passBuf[264];	/* Password buffer */
    size_t numOpen;		/* Number of open files on archive */
    struct ZipEntry *entries;	/* List of files in archive */
    struct ZipEntry *topEnts;	/* List of top-level dirs in archive */
    char *mountPoint;		/* Mount point name */
    Tcl_Size mountPointLen;	/* Length of mount point name */
#ifdef _WIN32
    HANDLE mountHandle;		/* Handle used for direct file access. */
#endif /* _WIN32 */
} ZipFile;

/*
 * In-core description of file contained in mounted ZIP archive.
 */

typedef struct ZipEntry {
    char *name;			/* The full pathname of the virtual file */
    ZipFile *zipFilePtr;	/* The ZIP file holding this virtual file */
    size_t offset;		/* Data offset into memory mapped ZIP file */
    int numBytes;		/* Uncompressed size of the virtual file.
				 * -1 for zip64 */
    int numCompressedBytes;	/* Compressed size of the virtual file.
				 * -1 for zip64 */
    int compressMethod;		/* Compress method */
    int isDirectory;		/* 0 if file, 1 if directory, -1 if root */
    int depth;			/* Number of slashes in path. */
    int crc32;			/* CRC-32 as stored in ZIP */
    int timestamp;		/* Modification time */
    int isEncrypted;		/* True if data is encrypted */
    int flags;			/* See ZipEntryFlags for bit definitions. */
    unsigned char *data;	/* File data if written */
    struct ZipEntry *next;	/* Next file in the same archive */
    struct ZipEntry *tnext;	/* Next top-level dir in archive */
} ZipEntry;

enum ZipEntryFlags {
    ZE_F_CRC_COMPARED = 1,	/* If 1, the CRC has been compared. */
    ZE_F_CRC_CORRECT = 2,	/* Only meaningful if ZE_F_CRC_COMPARED is 1 */
    ZE_F_VOLUME = 4		/* Entry corresponds to //zipfs:/ */
};

/*
 * File channel for file contained in mounted ZIP archive.
 *
 * Regarding data buffers:
 * For READ-ONLY files that are not encrypted and not compressed (zip STORE
 * method), ubuf points directly to the mapped zip file data in memory. No
 * additional storage is allocated and so ubufToFree is NULL.
 *
 * In all other combinations of compression and encryption or if channel is
 * writable, storage is allocated for the decrypted and/or uncompressed data
 * and a pointer to it is stored in ubufToFree and ubuf. When channel is
 * closed, ubufToFree is freed if not NULL. ubuf is irrelevant since it may
 * or may not point to allocated storage as above.
 */

typedef struct ZipChannel {
    ZipFile *zipFilePtr;	/* The ZIP file holding this channel */
    ZipEntry *zipEntryPtr;	/* Pointer back to virtual file */
    Tcl_Size maxWrite;		/* Maximum size for write */
    Tcl_Size numBytes;		/* Number of bytes of uncompressed data */
    Tcl_Size cursor;		/* Seek position for next read or write*/
    unsigned char *ubuf;	/* Pointer to the uncompressed data */
    unsigned char *ubufToFree;	/* NULL if ubuf points to memory that does not
				 * need freeing. Else memory to free (ubuf
				 * may point *inside* the block) */
    Tcl_Size ubufSize;		/* Size of allocated ubufToFree */
    int iscompr;		/* True if data is compressed */
    int isDirectory;		/* Set to 1 if directory, or -1 if root */
    int isEncrypted;		/* True if data is encrypted */
    int mode;			/* O_WRITE, O_APPEND, O_TRUNC etc.*/
    unsigned long keys[3];	/* Key for decryption */
} ZipChannel;

static inline int
ZipChannelWritable(
    ZipChannel *info)
{
    return (info->mode & (O_WRONLY | O_RDWR)) != 0;
}

/*
 * Global variables.
 *
 * Most are kept in single ZipFS struct. When build with threading support
 * this struct is protected by the ZipFSMutex (see below).
 *
 * The "fileHash" component is the process-wide global table of all known ZIP
 * archive members in all mounted ZIP archives.
 *
 * The "zipHash" components is the process wide global table of all mounted
 * ZIP archive files.
 */

static struct {
    int initialized;		/* True when initialized */
    int lock;			/* RW lock, see below */
    int waiters;		/* RW lock, see below */
    int wrmax;			/* Maximum write size of a file; only written
				 * to from Tcl code in a trusted interpreter,
				 * so NOT protected by mutex. */
    char *fallbackEntryEncoding;/* The fallback encoding for ZIP entries when
				 * they are believed to not be UTF-8; only
				 * written to from Tcl code in a trusted
				 * interpreter, so not protected by mutex. */
    int idCount;		/* Counter for channel names */
    Tcl_HashTable fileHash;	/* File name to ZipEntry mapping */
    Tcl_HashTable zipHash;	/* Mount to ZipFile mapping */
} ZipFS = {
    0, 0, 0, DEFAULT_WRITE_MAX_SIZE, NULL, 0,
	    {0,{0,0,0,0},0,0,0,0,0,0,0,0,0},
	    {0,{0,0,0,0},0,0,0,0,0,0,0,0,0}
};

/*
 * For password rotation.
 */

static const char pwrot[17] =
    "\x00\x80\x40\xC0\x20\xA0\x60\xE0"
    "\x10\x90\x50\xD0\x30\xB0\x70\xF0";

static int zipfs_tcl_library_init = 0;
static const char *zipfs_literal_tcl_library = NULL;

/* Function prototypes */

static int		CopyImageFile(Tcl_Interp *interp, const char *imgName,
			    Tcl_Channel out);
static int		DescribeMounted(Tcl_Interp *interp,
			    const char *mountPoint);
static int		InitReadableChannel(Tcl_Interp *interp,
			    ZipChannel *info, ZipEntry *z);
static int		InitWritableChannel(Tcl_Interp *interp,
			    ZipChannel *info, ZipEntry *z, int trunc);
static int		ListMountPoints(Tcl_Interp *interp);
static int		ContainsMountPoint(const char *path, int pathLen);
static void		CleanupMount(ZipFile *zf);
static void		SerializeCentralDirectoryEntry(
			    const unsigned char *start,
			    const unsigned char *end, unsigned char *buf,
			    ZipEntry *z, size_t nameLength,
			    long long dataStartOffset);
static void		SerializeCentralDirectorySuffix(
			    const unsigned char *start,
			    const unsigned char *end, unsigned char *buf,
			    int entryCount, long long dataStartOffset,
			    long long directoryStartOffset,
			    long long suffixStartOffset);
static void		SerializeLocalEntryHeader(
			    const unsigned char *start,
			    const unsigned char *end, unsigned char *buf,
			    ZipEntry *z, int nameLength, int align);
static int		IsCryptHeaderValid(ZipEntry *z,
			    unsigned char cryptHdr[ZIP_CRYPT_HDR_LEN]);
static int		DecodeCryptHeader(Tcl_Interp *interp, ZipEntry *z,
			    unsigned long keys[3],
			    unsigned char cryptHdr[ZIP_CRYPT_HDR_LEN]);
static int		ZipFSPathInFilesystemProc(Tcl_Obj *pathPtr,
			    void **clientDataPtr);
static Tcl_Obj *	ZipFSFilesystemPathTypeProc(Tcl_Obj *pathPtr);
static Tcl_Obj *	ZipFSFilesystemSeparatorProc(Tcl_Obj *pathPtr);
static int		ZipFSStatProc(Tcl_Obj *pathPtr, Tcl_StatBuf *buf);
static int		ZipFSAccessProc(Tcl_Obj *pathPtr, int mode);
static Tcl_Channel	ZipFSOpenFileChannelProc(Tcl_Interp *interp,
			    Tcl_Obj *pathPtr, int mode, int permissions);
static int		ZipFSMatchInDirectoryProc(Tcl_Interp *interp,
			    Tcl_Obj *result, Tcl_Obj *pathPtr,
			    const char *pattern, Tcl_GlobTypeData *types);
static void		ZipFSMatchMountPoints(Tcl_Obj *result,
			    Tcl_Obj *normPathPtr, const char *pattern,
			    Tcl_DString *prefix);
static Tcl_Obj *	ZipFSListVolumesProc(void);
static const char *const *ZipFSFileAttrStringsProc(Tcl_Obj *pathPtr,
			    Tcl_Obj **objPtrRef);
static int		ZipFSFileAttrsGetProc(Tcl_Interp *interp, int index,
			    Tcl_Obj *pathPtr, Tcl_Obj **objPtrRef);
static int		ZipFSFileAttrsSetProc(Tcl_Interp *interp, int index,
			    Tcl_Obj *pathPtr, Tcl_Obj *objPtr);
static int		ZipFSLoadFile(Tcl_Interp *interp, Tcl_Obj *path,
			    Tcl_LoadHandle *loadHandle,
			    Tcl_FSUnloadFileProc **unloadProcPtr, int flags);
static int		ZipMapArchive(Tcl_Interp *interp, ZipFile *zf,
			    void *handle);
static void		ZipfsSetup(void);
static int		ZipChannelClose(void *instanceData,
			    Tcl_Interp *interp, int flags);
static Tcl_DriverGetHandleProc	ZipChannelGetFile;
static int		ZipChannelRead(void *instanceData, char *buf,
			    int toRead, int *errloc);
static long long	ZipChannelWideSeek(void *instanceData,
			    long long offset, int mode, int *errloc);
static void		ZipChannelWatchChannel(void *instanceData,
			    int mask);
static int		ZipChannelWrite(void *instanceData,
			    const char *buf, int toWrite, int *errloc);
static int		TclZipfsInitEncodingDirs(void);
static int		TclZipfsMountExe(void);
static int		TclZipfsMountShlib(void);

/*
 * Define the ZIP filesystem dispatch table.
 */

static const Tcl_Filesystem zipfsFilesystem = {
    "zipfs",
    sizeof(Tcl_Filesystem),
    TCL_FILESYSTEM_VERSION_2,
    ZipFSPathInFilesystemProc,
    NULL, /* dupInternalRepProc */
    NULL, /* freeInternalRepProc */
    NULL, /* internalToNormalizedProc */
    NULL, /* createInternalRepProc */
    NULL, /* normalizePathProc */
    ZipFSFilesystemPathTypeProc,
    ZipFSFilesystemSeparatorProc,
    ZipFSStatProc,
    ZipFSAccessProc,
    ZipFSOpenFileChannelProc,
    ZipFSMatchInDirectoryProc,
    NULL, /* utimeProc */
    NULL, /* linkProc */
    ZipFSListVolumesProc,
    ZipFSFileAttrStringsProc,
    ZipFSFileAttrsGetProc,
    ZipFSFileAttrsSetProc,
    NULL, /* createDirectoryProc */
    NULL, /* removeDirectoryProc */
    NULL, /* deleteFileProc */
    NULL, /* copyFileProc */
    NULL, /* renameFileProc */
    NULL, /* copyDirectoryProc */
    NULL, /* lstatProc */
    (Tcl_FSLoadFileProc *) (void *) ZipFSLoadFile,
    NULL, /* getCwdProc */
    NULL, /* chdirProc */
};

/*
 * The channel type/driver definition used for ZIP archive members.
 */
static const Tcl_ChannelType zipChannelType = {
    "zip",
    TCL_CHANNEL_VERSION_5,
    NULL,			/* Deprecated. */
    ZipChannelRead,
    ZipChannelWrite,
    NULL,			/* Deprecated. */
    NULL,			/* Set options proc. */
    NULL,			/* Get options proc. */
    ZipChannelWatchChannel,
    ZipChannelGetFile,
    ZipChannelClose,
    NULL,			/* Set blocking mode for raw channel. */
    NULL,			/* Function to flush channel. */
    NULL,			/* Function to handle bubbled events. */
    ZipChannelWideSeek,
    NULL,			/* Thread action function. */
    NULL,			/* Truncate function. */
};

/*
 *------------------------------------------------------------------------
 *
 * TclIsZipfsPath --
 *
 *    Checks if the passed path has a zipfs volume prefix.
 *
 * Results:
 *    0 if not a zipfs path
 *    else the length of the zipfs volume prefix
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
int
TclIsZipfsPath(
    const char *path)
{
#ifdef _WIN32
    return strncmp(path, ZIPFS_VOLUME, ZIPFS_VOLUME_LEN) ? 0 : ZIPFS_VOLUME_LEN;
#else
    int i;
    for (i = 0; i < ZIPFS_VOLUME_LEN; ++i) {
	if (path[i] != ZIPFS_VOLUME[i] &&
		(path[i] != '\\' || ZIPFS_VOLUME[i] != '/')) {
	    return 0;
	}
    }
    return ZIPFS_VOLUME_LEN;
#endif
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipReadInt, ZipReadShort, ZipWriteInt, ZipWriteShort --
 *
 *	Inline functions to read and write little-endian 16 and 32 bit
 *	integers from/to buffers representing parts of ZIP archives.
 *
 *	These take bufferStart and bufferEnd pointers, which are used to
 *	maintain a guarantee that out-of-bounds accesses don't happen when
 *	reading or writing critical directory structures.
 *
 *-------------------------------------------------------------------------
 */

static inline unsigned int
ZipReadInt(
    const unsigned char *bufferStart,
    const unsigned char *bufferEnd,
    const unsigned char *ptr)
{
    if (ptr < bufferStart || ptr + 4 > bufferEnd) {
	Tcl_Panic("out of bounds read(4): start=%p, end=%p, ptr=%p",
		bufferStart, bufferEnd, ptr);
    }
    return ptr[0] | (ptr[1] << 8) | (ptr[2] << 16) |
	    ((unsigned int)ptr[3] << 24);
}

static inline unsigned short
ZipReadShort(
    const unsigned char *bufferStart,
    const unsigned char *bufferEnd,
    const unsigned char *ptr)
{
    if (ptr < bufferStart || ptr + 2 > bufferEnd) {
	Tcl_Panic("out of bounds read(2): start=%p, end=%p, ptr=%p",
		bufferStart, bufferEnd, ptr);
    }
    return ptr[0] | (ptr[1] << 8);
}

static inline void
ZipWriteInt(
    const unsigned char *bufferStart,
    const unsigned char *bufferEnd,
    unsigned char *ptr,
    unsigned int value)
{
    if (ptr < bufferStart || ptr + 4 > bufferEnd) {
	Tcl_Panic("out of bounds write(4): start=%p, end=%p, ptr=%p",
		bufferStart, bufferEnd, ptr);
    }
    ptr[0] = value & 0xff;
    ptr[1] = (value >> 8) & 0xff;
    ptr[2] = (value >> 16) & 0xff;
    ptr[3] = (value >> 24) & 0xff;
}

static inline void
ZipWriteShort(
    const unsigned char *bufferStart,
    const unsigned char *bufferEnd,
    unsigned char *ptr,
    unsigned short value)
{
    if (ptr < bufferStart || ptr + 2 > bufferEnd) {
	Tcl_Panic("out of bounds write(2): start=%p, end=%p, ptr=%p",
		bufferStart, bufferEnd, ptr);
    }
    ptr[0] = value & 0xff;
    ptr[1] = (value >> 8) & 0xff;
}

/*
 * Need a separate mutex for locating libraries because the search calls
 * TclZipfs_Mount which takes out a write lock on the ZipFSMutex. Since
 * those cannot be nested, we need a separate mutex.
 */
TCL_DECLARE_MUTEX(ZipFSLocateLibMutex)

/*
 *-------------------------------------------------------------------------
 *
 * ReadLock, WriteLock, Unlock --
 *
 *	POSIX like rwlock functions to support multiple readers and single
 *	writer on internal structs.
 *
 *	Limitations:
 *	 - a read lock cannot be promoted to a write lock
 *	 - a write lock may not be nested
 *
 *-------------------------------------------------------------------------
 */

TCL_DECLARE_MUTEX(ZipFSMutex)

#if TCL_THREADS

static Tcl_Condition ZipFSCond;

static inline void
ReadLock(void)
{
    Tcl_MutexLock(&ZipFSMutex);
    while (ZipFS.lock < 0) {
	ZipFS.waiters++;
	Tcl_ConditionWait(&ZipFSCond, &ZipFSMutex, NULL);
	ZipFS.waiters--;
    }
    ZipFS.lock++;
    Tcl_MutexUnlock(&ZipFSMutex);
}

static inline void
WriteLock(void)
{
    Tcl_MutexLock(&ZipFSMutex);
    while (ZipFS.lock != 0) {
	ZipFS.waiters++;
	Tcl_ConditionWait(&ZipFSCond, &ZipFSMutex, NULL);
	ZipFS.waiters--;
    }
    ZipFS.lock = -1;
    Tcl_MutexUnlock(&ZipFSMutex);
}

static inline void
Unlock(void)
{
    Tcl_MutexLock(&ZipFSMutex);
    if (ZipFS.lock > 0) {
	--ZipFS.lock;
    } else if (ZipFS.lock < 0) {
	ZipFS.lock = 0;
    }
    if ((ZipFS.lock == 0) && (ZipFS.waiters > 0)) {
	Tcl_ConditionNotify(&ZipFSCond);
    }
    Tcl_MutexUnlock(&ZipFSMutex);
}

#else /* !TCL_THREADS */
#define ReadLock()	do {} while (0)
#define WriteLock()	do {} while (0)
#define Unlock()	do {} while (0)
#endif /* TCL_THREADS */

/*
 *-------------------------------------------------------------------------
 *
 * DosTimeDate, ToDosTime, ToDosDate --
 *
 *	Functions to perform conversions between DOS time stamps and POSIX
 *	time_t.
 *
 *-------------------------------------------------------------------------
 */

static time_t
DosTimeDate(
    int dosDate,
    int dosTime)
{
    struct tm tm;
    time_t ret;

    memset(&tm, 0, sizeof(tm));
    tm.tm_isdst = -1;			/* let mktime() deal with DST */
    tm.tm_year = ((dosDate & 0xfe00) >> 9) + 80;
    tm.tm_mon = ((dosDate & 0x1e0) >> 5) - 1;
    tm.tm_mday = dosDate & 0x1f;
    tm.tm_hour = (dosTime & 0xf800) >> 11;
    tm.tm_min = (dosTime & 0x7e0) >> 5;
    tm.tm_sec = (dosTime & 0x1f) << 1;
    ret = mktime(&tm);
    if (ret == (time_t) -1) {
	/* fallback to 1980-01-01T00:00:00+00:00 (DOS epoch) */
	ret = (time_t) 315532800;
    }
    return ret;
}

static int
ToDosTime(
    time_t when)
{
    struct tm *tmp, tm;

#if !TCL_THREADS || defined(_WIN32)
    /* Not threaded, or on Win32 which uses thread local storage */
    tmp = localtime(&when);
    tm = *tmp;
#elif defined(HAVE_LOCALTIME_R)
    /* Threaded, have reentrant API */
    tmp = &tm;
    localtime_r(&when, tmp);
#else /* TCL_THREADS && !_WIN32 && !HAVE_LOCALTIME_R */
    /* Only using a mutex is safe. */
    Tcl_MutexLock(&localtimeMutex);
    tmp = localtime(&when);
    tm = *tmp;
    Tcl_MutexUnlock(&localtimeMutex);
#endif
    return (tm.tm_hour << 11) | (tm.tm_min << 5) | (tm.tm_sec >> 1);
}

static int
ToDosDate(
    time_t when)
{
    struct tm *tmp, tm;

#if !TCL_THREADS || defined(_WIN32)
    /* Not threaded, or on Win32 which uses thread local storage */
    tmp = localtime(&when);
    tm = *tmp;
#elif /* TCL_THREADS && !_WIN32 && */ defined(HAVE_LOCALTIME_R)
    /* Threaded, have reentrant API */
    tmp = &tm;
    localtime_r(&when, tmp);
#else /* TCL_THREADS && !_WIN32 && !HAVE_LOCALTIME_R */
    /* Only using a mutex is safe. */
    Tcl_MutexLock(&localtimeMutex);
    tmp = localtime(&when);
    tm = *tmp;
    Tcl_MutexUnlock(&localtimeMutex);
#endif
    return ((tm.tm_year - 80) << 9) | ((tm.tm_mon + 1) << 5) | tm.tm_mday;
}

/*
 *-------------------------------------------------------------------------
 *
 * CountSlashes --
 *
 *	This function counts the number of slashes in a pathname string.
 *
 * Results:
 *	Number of slashes found in string.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static inline size_t
CountSlashes(
    const char *string)
{
    size_t count = 0;
    const char *p = string;

    while (*p != '\0') {
	if (*p == '/') {
	    count++;
	}
	p++;
    }
    return count;
}

/*
 *------------------------------------------------------------------------
 *
 * IsCryptHeaderValid --
 *
 *    Computes the validity of the encryption header CRC for a ZipEntry.
 *
 * Results:
 *    Returns 1 if the header is valid else 0.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
static int
IsCryptHeaderValid(
    ZipEntry *z,
    unsigned char cryptHeader[ZIP_CRYPT_HDR_LEN])
{
    /*
     * There are multiple possibilities. The last one or two bytes of the
     * encryption header should match the last one or two bytes of the
     * CRC of the file. Or the last byte of the encryption header should
     * be the high order byte of the file time. Depending on the archiver
     * and version, any of the might be in used. We follow libzip in checking
     * only one byte against both the crc and the time. Note that by design
     * the check generates high number of false positives in any case.
     * Also, in case a check is passed when it should not, the final CRC
     * calculation will (should) catch it. Only difference is it will be
     * reported as a corruption error instead of incorrect password.
     */
    int dosTime = ToDosTime(z->timestamp);
    if (cryptHeader[11] == (unsigned char)(dosTime >> 8)) {
	/* Infozip style - Tested with test-password.zip */
	return 1;
    }
    /* DOS time did not match, may be CRC does */
    if (z->crc32) {
	/* Pkware style - Tested with test-password2.zip */
	return (cryptHeader[11] == (unsigned char)(z->crc32 >> 24));
    }

    /* No CRC, no way to verify. Assume valid */
    return 1;
}

/*
 *------------------------------------------------------------------------
 *
 * DecodeCryptHeader --
 *
 *    Decodes the crypt header and validates it.
 *
 * Results:
 *    TCL_OK on success, TCL_ERROR on failure.
 *
 * Side effects:
 *    On success, keys[] are updated. On failure, an error message is
 *    left in interp if not NULL.
 *
 *------------------------------------------------------------------------
 */
static int
DecodeCryptHeader(
    Tcl_Interp *interp,
    ZipEntry *z,
    unsigned long keys[3],	/* Updated on success. Must have been
				 * initialized by caller. */
    unsigned char cryptHeader[ZIP_CRYPT_HDR_LEN])
				/* From zip file content */
{
    int i;
    int ch;
    int len = z->zipFilePtr->passBuf[0] & 0xFF;
    char passBuf[260];

    for (i = 0; i < len; i++) {
	ch = z->zipFilePtr->passBuf[len - i];
	passBuf[i] = (ch & 0x0f) | pwrot[(ch >> 4) & 0x0f];
    }
    passBuf[i] = '\0';
    init_keys(passBuf, keys, crc32tab);
    memset(passBuf, 0, sizeof(passBuf));
    unsigned char encheader[ZIP_CRYPT_HDR_LEN];
    memcpy(encheader, cryptHeader, ZIP_CRYPT_HDR_LEN);
    for (i = 0; i < ZIP_CRYPT_HDR_LEN; i++) {
	ch = cryptHeader[i];
	ch ^= decrypt_byte(keys, crc32tab);
	encheader[i] = ch;
	update_keys(keys, crc32tab, ch);
    }
    if (!IsCryptHeaderValid(z, encheader)) {
	ZIPFS_ERROR(interp, "invalid password");
	ZIPFS_ERROR_CODE(interp, "PASSWORD");
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * DecodeZipEntryText --
 *
 *	Given a sequence of bytes from an entry in a ZIP central directory,
 *	convert that into a Tcl string. This is complicated because we don't
 *	actually know what encoding is in use! So we try to use UTF-8, and if
 *	that goes wrong, we fall back to a user-specified encoding, or to an
 *	encoding we specify (Windows code page 437), or to ISO 8859-1 if
 *	absolutely nothing else works.
 *
 *	During Tcl startup, we skip the user-specified encoding and cp437, as
 *	we may well not have any loadable encodings yet. Tcl's own library
 *	files ought to be using ASCII filenames.
 *
 * Results:
 *	The decoded filename; the filename is owned by the argument DString.
 *
 * Side effects:
 *	Updates dstPtr.
 *
 *-------------------------------------------------------------------------
 */

static char *
DecodeZipEntryText(
    const unsigned char *inputBytes,
    unsigned int inputLength,
    Tcl_DString *dstPtr)	/* Must have been initialized by caller! */
{
    Tcl_Encoding encoding;
    const char *src;
    char *dst;
    int dstLen, srcLen = inputLength, flags;
    Tcl_EncodingState state;

    if (inputLength < 1) {
	return Tcl_DStringValue(dstPtr);
    }

    /*
     * We can't use Tcl_ExternalToUtfDString at this point; it has no way to
     * fail. So we use this modified version of it that can report encoding
     * errors to us (so we can fall back to something else).
     *
     * The utf-8 encoding is implemented internally, and so is guaranteed to
     * be present.
     */

    src = (const char *) inputBytes;
    dst = Tcl_DStringValue(dstPtr);
    dstLen = dstPtr->spaceAvl - 1;
    flags = TCL_ENCODING_START | TCL_ENCODING_END;	/* Special flag! */

    while (1) {
	int srcRead, dstWrote;
	int result = Tcl_ExternalToUtf(NULL, tclUtf8Encoding, src, srcLen, flags,
		&state, dst, dstLen, &srcRead, &dstWrote, NULL);
	int soFar = dst + dstWrote - Tcl_DStringValue(dstPtr);

	if (result == TCL_OK) {
	    Tcl_DStringSetLength(dstPtr, soFar);
	    return Tcl_DStringValue(dstPtr);
	} else if (result != TCL_CONVERT_NOSPACE) {
	    break;
	}

	flags &= ~TCL_ENCODING_START;
	src += srcRead;
	srcLen -= srcRead;
	if (Tcl_DStringLength(dstPtr) == 0) {
	    Tcl_DStringSetLength(dstPtr, dstLen);
	}
	Tcl_DStringSetLength(dstPtr, 2 * Tcl_DStringLength(dstPtr) + 1);
	dst = Tcl_DStringValue(dstPtr) + soFar;
	dstLen = Tcl_DStringLength(dstPtr) - soFar - 1;
    }

    /*
     * Something went wrong. Fall back to another encoding. Those *can* use
     * Tcl_ExternalToUtfDString().
     */

    encoding = NULL;
    if (ZipFS.fallbackEntryEncoding) {
	encoding = Tcl_GetEncoding(NULL, ZipFS.fallbackEntryEncoding);
    }
    if (!encoding) {
	encoding = Tcl_GetEncoding(NULL, ZIPFS_FALLBACK_ENCODING);
    }
    if (!encoding) {
	/*
	 * Fallback to internal encoding that always converts all bytes.
	 * Should only happen when a filename isn't UTF-8 and we've not got
	 * our encodings initialised for some reason.
	 */

	encoding = Tcl_GetEncoding(NULL, "iso8859-1");
    }

    char *converted = Tcl_ExternalToUtfDString(encoding,
	    (const char *) inputBytes, inputLength, dstPtr);
    Tcl_FreeEncoding(encoding);
    return converted;
}

/*
 *------------------------------------------------------------------------
 *
 * NormalizeMountPoint --
 *
 *    Converts the passed path into a normalized zipfs mount point
 *    of the form //zipfs:/some/path. On Windows any \ path separators
 *    are converted to /.
 *
 *    Mount points with a volume will raise an error unless the volume is
 *    zipfs root. Thus D:/foo is not a valid mount point.
 *
 *    Relative paths and absolute paths without a volume are mapped under
 *    the zipfs root.
 *
 *    The empty string is mapped to the zipfs root.
 *
 *    dsPtr is initialized by the function and must be cleared by caller
 *    on a successful return.
 *
 * Results:
 *    TCL_OK on success with normalized mount path in dsPtr
 *    TCL_ERROR on fail with error message in interp if not NULL
 *
 *------------------------------------------------------------------------
 */
static int
NormalizeMountPoint(
    Tcl_Interp *interp,
    const char *mountPath,
    Tcl_DString *dsPtr)		/* Must be initialized by caller! */
{
    const char *joiner[2];
    char *joinedPath;
    Tcl_Obj *unnormalizedObj;
    Tcl_Obj *normalizedObj;
    const char *normalizedPath;
    Tcl_Size normalizedLen;
    Tcl_DString dsJoin;

    /*
     * Several things need to happen here
     * - Absolute paths containing volumes (drive letter or UNC) raise error
     *   except of course if the volume is zipfs root
     * - \ -> / and // -> / conversions (except if UNC which is error)
     * - . and .. have to be dealt with
     * The first is explicitly checked, the others are dealt with a
     * combination file join and normalize. Easier than doing it ourselves
     * and not performance sensitive anyways.
     */

    joiner[0] = ZIPFS_VOLUME;
    joiner[1] = mountPath;
    Tcl_DStringInit(&dsJoin);
    joinedPath = Tcl_JoinPath(2, joiner, &dsJoin);

    /* Now joinedPath has all \ -> / and // -> / (except UNC) converted. */

    if (!strncmp(ZIPFS_VOLUME, joinedPath, ZIPFS_VOLUME_LEN)) {
	unnormalizedObj = Tcl_DStringToObj(&dsJoin);
    } else {
	if (joinedPath[0] != '/' || joinedPath[1] == '/') {
	    /* mount path was D:/x, D:x or //unc */
	    goto invalidMountPath;
	}
	unnormalizedObj = Tcl_ObjPrintf(ZIPFS_VOLUME "%s", joinedPath + 1);
    }
    Tcl_IncrRefCount(unnormalizedObj);
    normalizedObj = Tcl_FSGetNormalizedPath(interp, unnormalizedObj);
    if (normalizedObj == NULL) {
	Tcl_DecrRefCount(unnormalizedObj);
	goto errorReturn;
    }
    Tcl_IncrRefCount(normalizedObj); /* BEFORE DecrRefCount on unnormalizedObj */
    Tcl_DecrRefCount(unnormalizedObj);

    /* normalizedObj owned by Tcl!! Do NOT DecrRef without an IncrRef */
    normalizedPath = TclGetStringFromObj(normalizedObj, &normalizedLen);
    Tcl_DStringFree(&dsJoin);
    Tcl_DStringAppend(dsPtr, normalizedPath, normalizedLen);
    Tcl_DecrRefCount(normalizedObj);
    return TCL_OK;

invalidMountPath:
    if (interp) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"Invalid mount path \"%s\"", mountPath));
	ZIPFS_ERROR_CODE(interp, "MOUNT_PATH");
    }

errorReturn:
    Tcl_DStringFree(&dsJoin);
    return TCL_ERROR;
}

/*
 *------------------------------------------------------------------------
 *
 * MapPathToZipfs --
 *
 *    Maps a path as stored in a zip archive to its normalized location
 *    under a given zipfs mount point. Relative paths and Unix style
 *    absolute paths go directly under the mount point. Volume relative
 *    paths and absolute paths that have a volume (drive or UNC) are
 *    stripped of the volume before joining the mount point.
 *
 * Results:
 *    Pointer to normalized path.
 *
 * Side effects:
 *    Stores mapped path in dsPtr.
 *
 *------------------------------------------------------------------------
 */
static char *
MapPathToZipfs(
    Tcl_Interp *interp,
    const char *mountPath,	/* Must be fully normalized */
    const char *path,		/* Archive content path to map */
    Tcl_DString *dsPtr)		/* Must be initialized and cleared
				 * by caller */
{
    const char *joiner[2];
    char *joinedPath;
    Tcl_Obj *unnormalizedObj;
    Tcl_Obj *normalizedObj;
    const char *normalizedPath;
    Tcl_Size normalizedLen;
    Tcl_DString dsJoin;

    assert(TclIsZipfsPath(mountPath));

    joiner[0] = mountPath;
    joiner[1] = path;
#ifndef _WIN32
    /* On Unix C:/foo/bat is not treated as absolute by JoinPath so check ourself */
    if (path[0] && path[1] == ':') {
	joiner[1] += 2;
    }
#endif
    Tcl_DStringInit(&dsJoin);
    joinedPath = Tcl_JoinPath(2, joiner, &dsJoin);

    if (strncmp(ZIPFS_VOLUME, joinedPath, ZIPFS_VOLUME_LEN)) {
	/* path was not relative. Strip off the volume (e.g. UNC) */
	Tcl_Size numParts;
	const char **partsPtr;
	Tcl_SplitPath(path, &numParts, &partsPtr);
	Tcl_DStringFree(&dsJoin);
	partsPtr[0] = mountPath;
	(void)Tcl_JoinPath(numParts, partsPtr, &dsJoin);
	Tcl_Free(partsPtr);
    }
    unnormalizedObj = Tcl_DStringToObj(&dsJoin); /* Also resets dsJoin */
    Tcl_IncrRefCount(unnormalizedObj);
    normalizedObj = Tcl_FSGetNormalizedPath(interp, unnormalizedObj);
    if (normalizedObj == NULL) {
	/* Should not happen but continue... */
	normalizedObj = unnormalizedObj;
    }
    Tcl_IncrRefCount(normalizedObj); /* BEFORE DecrRefCount on unnormalizedObj */
    Tcl_DecrRefCount(unnormalizedObj);

    /* normalizedObj owned by Tcl!! Do NOT DecrRef without an IncrRef */
    normalizedPath = TclGetStringFromObj(normalizedObj, &normalizedLen);
    Tcl_DStringAppend(dsPtr, normalizedPath, normalizedLen);
    Tcl_DecrRefCount(normalizedObj);
    return Tcl_DStringValue(dsPtr);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSLookup --
 *
 *	This function returns the ZIP entry struct corresponding to the ZIP
 *	archive member of the given file name. Caller must hold the right
 *	lock.
 *
 * Results:
 *	Returns the pointer to ZIP entry struct or NULL if the the given file
 *	name could not be found in the global list of ZIP archive members.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static inline ZipEntry *
ZipFSLookup(
    const char *filename)
{
    Tcl_HashEntry *hPtr;
    ZipEntry *z = NULL;

    hPtr = Tcl_FindHashEntry(&ZipFS.fileHash, filename);
    if (hPtr) {
	z = (ZipEntry *) Tcl_GetHashValue(hPtr);
    }
    return z;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSLookupZip --
 *
 *	This function gets the structure for a mounted ZIP archive.
 *	The read lock must be held by the caller.
 *
 * Results:
 *	Returns a pointer to the structure, or NULL if the file is ZIP file is
 *	unknown/not mounted.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static inline ZipFile *
ZipFSLookupZip(
    const char *mountPoint)
{
    Tcl_HashEntry *hPtr;
    ZipFile *zf = NULL;

    hPtr = Tcl_FindHashEntry(&ZipFS.zipHash, mountPoint);
    if (hPtr) {
	zf = (ZipFile *) Tcl_GetHashValue(hPtr);
    }
    return zf;
}

/*
 *------------------------------------------------------------------------
 *
 * ContainsMountPoint --
 *
 *    Check if there is a mount point anywhere under the specified path.
 *    Although the function will work for any path, for efficiency reasons
 *    it should be called only after checking ZipFSLookup does not find
 *    the path.
 *
 *    Caller must hold read lock before calling.
 *
 * Results:
 *    1 - there is at least one mount point under the path
 *    0 - otherwise
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
static int
ContainsMountPoint(
    const char *path,
    int pathLen)
{
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;

    if (ZipFS.zipHash.numEntries == 0) {
	return 0;
    }
    if (pathLen < 0) {
	pathLen = strlen(path);
    }

    /*
     * We are looking for the case where the path is //zipfs:/a/b
     * and there is a mount point //zipfs:/a/b/c/.. below it
     */
    for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &search); hPtr;
	    hPtr = Tcl_NextHashEntry(&search)) {
	ZipFile *zf = (ZipFile *) Tcl_GetHashValue(hPtr);

	if (zf->mountPointLen == 0) {
	    /*
	     * Enumerate the contents of the ZIP; it's mounted on the root.
	     * TODO - a holdover from androwish? Tcl does not allow mounting
	     * outside of the //zipfs:/ area.
	     */
	    ZipEntry *z;

	    for (z = zf->topEnts; z; z = z->tnext) {
		int lenz = (int) strlen(z->name);
		if ((lenz >= pathLen) &&
			(z->name[pathLen] == '/' || z->name[pathLen] == '\0') &&
			(strncmp(z->name, path, pathLen) == 0)) {
		    return 1;
		}
	    }
	} else if ((zf->mountPointLen >= pathLen)
		&& (zf->mountPoint[pathLen] == '/'
			|| zf->mountPoint[pathLen] == '\0'
			|| pathLen == ZIPFS_VOLUME_LEN)
		&& (strncmp(zf->mountPoint, path, pathLen) == 0)) {
	    /* Matched standard mount */
	    return 1;
	}
    }
    return 0;
}

/*
 *-------------------------------------------------------------------------
 *
 * AllocateZipFile, AllocateZipEntry, AllocateZipChannel --
 *
 *	Allocates the memory for a datastructure. Always ensures that it is
 *	zeroed out for safety.
 *
 * Returns:
 *	The allocated structure, or NULL if allocate fails.
 *
 * Side effects:
 *	The interpreter result may be written to on error. Which might fail
 *	(for ZipFile) in a low-memory situation. Always panics if ZipEntry
 *	allocation fails.
 *
 *-------------------------------------------------------------------------
 */

static inline ZipFile *
AllocateZipFile(
    Tcl_Interp *interp,
    size_t mountPointNameLength)
{
    size_t size = sizeof(ZipFile) + mountPointNameLength + 1;
    ZipFile *zf = (ZipFile *) Tcl_AttemptAlloc(size);

    if (!zf) {
	ZIPFS_MEM_ERROR(interp);
    } else {
	memset(zf, 0, size);
    }
    return zf;
}

static inline ZipEntry *
AllocateZipEntry(void)
{
    ZipEntry *z = (ZipEntry *) Tcl_Alloc(sizeof(ZipEntry));
    memset(z, 0, sizeof(ZipEntry));
    return z;
}

static inline ZipChannel *
AllocateZipChannel(
    Tcl_Interp *interp)
{
    ZipChannel *zc = (ZipChannel *) Tcl_AttemptAlloc(sizeof(ZipChannel));

    if (!zc) {
	ZIPFS_MEM_ERROR(interp);
    } else {
	memset(zc, 0, sizeof(ZipChannel));
    }
    return zc;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSCloseArchive --
 *
 *	This function closes a mounted ZIP archive file.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	A memory mapped ZIP archive is unmapped, allocated memory is released.
 *	The ZipFile pointer is *NOT* deallocated by this function.
 *
 *-------------------------------------------------------------------------
 */

static void
ZipFSCloseArchive(
    Tcl_Interp *interp,		/* Current interpreter. */
    ZipFile *zf)
{
    if (zf->nameLength) {
	Tcl_Free(zf->name);
    }
    if (zf->isMemBuffer) {
	/* Pointer to memory */
	if (zf->ptrToFree) {
	    Tcl_Free(zf->ptrToFree);
	    zf->ptrToFree = NULL;
	}
	zf->data = NULL;
	return;
    }

    /*
     * Remove the memory mapping, if we have one.
     */

#ifdef _WIN32
    if (zf->data && !zf->ptrToFree) {
	UnmapViewOfFile(zf->data);
	zf->data = NULL;
    }
    if (zf->mountHandle != INVALID_HANDLE_VALUE) {
	CloseHandle(zf->mountHandle);
    }
#else /* !_WIN32 */
    if ((zf->data != MAP_FAILED) && !zf->ptrToFree) {
	munmap(zf->data, zf->length);
	zf->data = (unsigned char *) MAP_FAILED;
    }
#endif /* _WIN32 */

    if (zf->ptrToFree) {
	Tcl_Free(zf->ptrToFree);
	zf->ptrToFree = NULL;
    }
    if (zf->chan) {
	Tcl_Close(interp, zf->chan);
	zf->chan = NULL;
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFindTOC --
 *
 *	This function takes a memory mapped zip file and indexes the contents.
 *	When "needZip" is zero an embedded ZIP archive in an executable file
 *	is accepted. Note that we do not support ZIP64.
 *
 * Results:
 *	TCL_OK on success, TCL_ERROR otherwise with an error message placed
 *	into the given "interp" if it is not NULL.
 *
 * Side effects:
 *      The given ZipFile struct is filled with information about the ZIP
 *      archive file.  On error, ZipFSCloseArchive is called on zf but
 *      it is not freed.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSFindTOC(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    int needZip,
    ZipFile *zf)
{
    size_t i, minoff;
    const unsigned char *eocdPtr; /* End of Central Directory Record */
    const unsigned char *start = zf->data;
    const unsigned char *end = zf->data + zf->length;

    /*
     * Scan backwards from the end of the file for the signature. This is
     * necessary because ZIP archives aren't the only things that get tagged
     * on the end of executables; digital signatures can also go there.
     */

    eocdPtr = zf->data + zf->length - ZIP_CENTRAL_END_LEN;
    while (eocdPtr >= start) {
	if (*eocdPtr == (ZIP_CENTRAL_END_SIG & 0xFF)) {
	    if (ZipReadInt(start, end, eocdPtr) == ZIP_CENTRAL_END_SIG) {
		break;
	    }
	    eocdPtr -= ZIP_SIG_LEN;
	} else {
	    --eocdPtr;
	}
    }
    if (eocdPtr < zf->data) {
	/*
	 * Didn't find it (or not enough space for a central directory!); not
	 * a ZIP archive. This might be OK or a problem.
	 */

	if (!needZip) {
	    zf->baseOffset = zf->passOffset = zf->length;
	    return TCL_OK;
	}
	ZIPFS_ERROR(interp, "archive directory end signature not found");
	ZIPFS_ERROR_CODE(interp, "END_SIG");

  error:
	ZipFSCloseArchive(interp, zf);
	return TCL_ERROR;

    }

    /*
     * eocdPtr -> End of Central Directory (EOCD) record at this point.
     * Note this is not same as "end of Central Directory" :-) as EOCD
     * is a record/structure in the ZIP spec terminology
     */

    /*
     * How many files in the archive? If that's bogus, we're done here.
     */

    zf->numFiles = ZipReadShort(start, end, eocdPtr + ZIP_CENTRAL_ENTS_OFFS);
    if (zf->numFiles == 0) {
	if (!needZip) {
	    zf->baseOffset = zf->passOffset = zf->length;
	    return TCL_OK;
	}
	ZIPFS_ERROR(interp, "empty archive");
	ZIPFS_ERROR_CODE(interp, "EMPTY");
	goto error;
    }

    /*
     * The Central Directory (CD) is a series of Central Directory File
     * Header (CDFH) records preceding the EOCD (but not necessarily
     * immediately preceding). cdirZipOffset is the offset into the
     * *archive* to the CD (first CDFH). The size of the CD is given by
     * cdirSize. NOTE: offset into archive does NOT mean offset into
     * (zf->data) as other data may precede the archive in the file.
     */
    ptrdiff_t eocdDataOffset = eocdPtr - zf->data;
    unsigned int cdirZipOffset = ZipReadInt(start, end, eocdPtr + ZIP_CENTRAL_DIRSTART_OFFS);
    unsigned int cdirSize = ZipReadInt(start, end, eocdPtr + ZIP_CENTRAL_DIRSIZE_OFFS);

    /*
     * As computed above,
     *    eocdDataOffset < zf->length.
     * In addition, the following consistency checks must be met
     * (1) cdirZipOffset <= eocdDataOffset (to prevent under flow in computation of (2))
     * (2) cdirZipOffset + cdirSize <= eocdDataOffset. Else the CD will be overlapping
     * the EOCD. Note this automatically means cdirZipOffset+cdirSize < zf->length.
     */
    if (!(cdirZipOffset <= (size_t)eocdDataOffset &&
	    cdirSize <= eocdDataOffset - cdirZipOffset)) {
	if (!needZip) {
	    /* Simply point to end od data */
	    zf->directoryOffset = zf->baseOffset = zf->passOffset = zf->length;
	    return TCL_OK;
	}
	ZIPFS_ERROR(interp, "archive directory truncated");
	ZIPFS_ERROR_CODE(interp, "NO_DIR");
	goto error;
    }

    /*
     * Calculate the offset of the CD in the *data*. If there was no extra
     * "junk" preceding the archive, this would just be cdirZipOffset but
     * otherwise we have to account for it.
     */
    if (eocdDataOffset - cdirSize > cdirZipOffset) {
	zf->baseOffset = eocdDataOffset - cdirSize - cdirZipOffset;
    } else {
	zf->baseOffset = 0;
    }
    zf->passOffset = zf->baseOffset;
    zf->directoryOffset = cdirZipOffset + zf->baseOffset;
    zf->directorySize = cdirSize;

    /*
     * Read the central directory.
     */
    const unsigned char *const cdirStart = eocdPtr - cdirSize; /* Start of CD */
    const unsigned char *dirEntry;
    minoff = zf->length;
    for (dirEntry = cdirStart, i = 0; i < zf->numFiles; i++) {
	if ((dirEntry-cdirStart) + ZIP_CENTRAL_HEADER_LEN > (ptrdiff_t)zf->directorySize) {
	    ZIPFS_ERROR(interp, "truncated directory");
	    ZIPFS_ERROR_CODE(interp, "TRUNC_DIR");
	    goto error;
	}
	if (ZipReadInt(start, end, dirEntry) != ZIP_CENTRAL_HEADER_SIG) {
	    ZIPFS_ERROR(interp, "wrong header signature");
	    ZIPFS_ERROR_CODE(interp, "HDR_SIG");
	    goto error;
	}
	int pathlen = ZipReadShort(start, end, dirEntry + ZIP_CENTRAL_PATHLEN_OFFS);
	int comlen = ZipReadShort(start, end, dirEntry + ZIP_CENTRAL_FCOMMENTLEN_OFFS);
	int extra = ZipReadShort(start, end, dirEntry + ZIP_CENTRAL_EXTRALEN_OFFS);
	size_t localhdr_off = ZipReadInt(start, end, dirEntry + ZIP_CENTRAL_LOCALHDR_OFFS);
	const unsigned char *localP = zf->data + zf->baseOffset + localhdr_off;
	if (localP > (cdirStart - ZIP_LOCAL_HEADER_LEN) ||
		ZipReadInt(start, end, localP) != ZIP_LOCAL_HEADER_SIG) {
	    ZIPFS_ERROR(interp, "Failed to find local header");
	    ZIPFS_ERROR_CODE(interp, "LCL_HDR");
	    goto error;
	}
	if (localhdr_off < minoff) {
	    minoff = localhdr_off;
	}
	dirEntry += pathlen + comlen + extra + ZIP_CENTRAL_HEADER_LEN;
    }
    if ((dirEntry-cdirStart) < (ptrdiff_t) zf->directorySize) {
	/* file count and dir size do not match */
	ZIPFS_ERROR(interp, "short file count");
	ZIPFS_ERROR_CODE(interp, "FILE_COUNT");
	goto error;
    }

    zf->passOffset = minoff + zf->baseOffset;

    /*
     * If there's also an encoded password, extract that too (but don't decode
     * yet).
     * TODO - is this even part of the ZIP "standard". The idea of storing
     * a password with the archive seems absurd, encoded or not.
     */

    unsigned char *q = zf->data + zf->passOffset;
    if ((zf->passOffset >= 6) && (start < q-4) &&
	    (ZipReadInt(start, end, q - 4) == ZIP_PASSWORD_END_SIG)) {
	const unsigned char *passPtr;

	i = q[-5];
	passPtr = q - 5 - i;
	if (passPtr >= start && passPtr + i < end) {
	    zf->passBuf[0] = i;
	    memcpy(zf->passBuf + 1, passPtr, i);
	    zf->passOffset -= i ? (5 + i) : 0;
	}
    }

    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSOpenArchive --
 *
 *	This function opens a ZIP archive file for reading. An attempt is made
 *	to memory map that file. Otherwise it is read into an allocated memory
 *	buffer. The ZIP archive header is verified and must be valid for the
 *	function to succeed. When "needZip" is zero an embedded ZIP archive in
 *	an executable file is accepted.
 *
 * Results:
 *	TCL_OK on success, TCL_ERROR otherwise with an error message placed
 *	into the given "interp" if it is not NULL. On error, ZipFSCloseArchive
 *      is called on zf but it is not freed.
 *
 * Side effects:
 *	ZIP archive is memory mapped or read into allocated memory, the given
 *	ZipFile struct is filled with information about the ZIP archive file.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSOpenArchive(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    const char *zipname,	/* Path to ZIP file to open. */
    int needZip,
    ZipFile *zf)
{
    size_t i;
    void *handle;

    zf->nameLength = 0;
    zf->isMemBuffer = 0;
#ifdef _WIN32
    zf->data = NULL;
    zf->mountHandle = INVALID_HANDLE_VALUE;
#else /* !_WIN32 */
    zf->data = (unsigned char *) MAP_FAILED;
#endif /* _WIN32 */
    zf->length = 0;
    zf->numFiles = 0;
    zf->baseOffset = zf->passOffset = 0;
    zf->ptrToFree = NULL;
    zf->passBuf[0] = 0;

    /*
     * Actually open the file.
     */

    zf->chan = Tcl_OpenFileChannel(interp, zipname, "rb", 0);
    if (!zf->chan) {
	return TCL_ERROR;
    }

    /*
     * See if we can get the OS handle. If we can, we can use that to memory
     * map the file, which is nice and efficient. However, it totally depends
     * on the filename pointing to a real regular OS file.
     *
     * Opening real filesystem entities that are not files will lead to an
     * error.
     */

    if (Tcl_GetChannelHandle(zf->chan, TCL_READABLE, &handle) == TCL_OK) {
	if (ZipMapArchive(interp, zf, handle) != TCL_OK) {
	    goto error;
	}
    } else {
	/*
	 * Not an OS file, but rather something in a Tcl VFS. Must copy into
	 * memory.
	 */

	zf->length = Tcl_Seek(zf->chan, 0, SEEK_END);
	if (zf->length == (size_t)TCL_INDEX_NONE) {
	    ZIPFS_POSIX_ERROR(interp, "seek error");
	    goto error;
	}
	/* What's the magic about 64 * 1024 * 1024 ? */
	if ((zf->length <= ZIP_CENTRAL_END_LEN) ||
		(zf->length - ZIP_CENTRAL_END_LEN) >
			(64 * 1024 * 1024 - ZIP_CENTRAL_END_LEN)) {
	    ZIPFS_ERROR(interp, "illegal file size");
	    ZIPFS_ERROR_CODE(interp, "FILE_SIZE");
	    goto error;
	}
	if (Tcl_Seek(zf->chan, 0, SEEK_SET) == -1) {
	    ZIPFS_POSIX_ERROR(interp, "seek error");
	    goto error;
	}
	zf->ptrToFree = zf->data = (unsigned char *) Tcl_AttemptAlloc(zf->length);
	if (!zf->ptrToFree) {
	    ZIPFS_MEM_ERROR(interp);
	    goto error;
	}
	i = Tcl_Read(zf->chan, (char *) zf->data, zf->length);
	if (i != zf->length) {
	    ZIPFS_POSIX_ERROR(interp, "file read error");
	    goto error;
	}
    }
    /*
     * Close the Tcl channel. If the file was mapped, the mapping is
     * unaffected. It is important to close the channel otherwise there is a
     * potential chicken and egg issue at finalization time as the channels
     * are closed before the file systems are dismounted.
     */
    Tcl_Close(interp, zf->chan);
    zf->chan = NULL;
    return ZipFSFindTOC(interp, needZip, zf);

    /*
     * Handle errors by closing the archive. This includes closing the channel
     * handle for the archive file.
     */

  error:
    ZipFSCloseArchive(interp, zf);
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipMapArchive --
 *
 *	Wrapper around the platform-specific parts of mmap() (and Windows's
 *	equivalent) because it's not part of the standard channel API.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipMapArchive(
    Tcl_Interp *interp,		/* Interpreter for error reporting. */
    ZipFile *zf,		/* The archive descriptor structure. */
    void *handle)		/* The OS handle to the open archive. */
{
#ifdef _WIN32
    HANDLE hFile = (HANDLE) handle;
    int readSuccessful;

    /*
     * Determine the file size.
     */

    readSuccessful = GetFileSizeEx(hFile, (PLARGE_INTEGER) &zf->length) != 0;
    if (!readSuccessful) {
	Tcl_WinConvertError(GetLastError());
	ZIPFS_POSIX_ERROR(interp, "failed to retrieve file size");
	return TCL_ERROR;
    }
    if (zf->length < ZIP_CENTRAL_END_LEN) {
	Tcl_SetErrno(EINVAL);
	ZIPFS_POSIX_ERROR(interp, "truncated file");
	return TCL_ERROR;
    }
    if (zf->length > TCL_SIZE_MAX) {
	Tcl_SetErrno(EFBIG);
	ZIPFS_POSIX_ERROR(interp, "zip archive too big");
	return TCL_ERROR;
    }

    /*
     * Map the file.
     */

    zf->mountHandle = CreateFileMappingW(hFile, 0, PAGE_READONLY, 0,
	    zf->length, 0);
    if (zf->mountHandle == INVALID_HANDLE_VALUE) {
	Tcl_WinConvertError(GetLastError());
	ZIPFS_POSIX_ERROR(interp, "file mapping failed");
	return TCL_ERROR;
    }
    zf->data = (unsigned char *)
	    MapViewOfFile(zf->mountHandle, FILE_MAP_READ, 0, 0, zf->length);
    if (!zf->data) {
	Tcl_WinConvertError(GetLastError());
	ZIPFS_POSIX_ERROR(interp, "file mapping failed");
	return TCL_ERROR;
    }
#else /* !_WIN32 */
    int fd = PTR2INT(handle);

    /*
     * Determine the file size.
     */

    zf->length = lseek(fd, 0, SEEK_END);
    if (zf->length == (size_t)-1) {
	ZIPFS_POSIX_ERROR(interp, "failed to retrieve file size");
	return TCL_ERROR;
    }
    if (zf->length < ZIP_CENTRAL_END_LEN) {
	Tcl_SetErrno(EINVAL);
	ZIPFS_POSIX_ERROR(interp, "truncated file");
	return TCL_ERROR;
    }
    lseek(fd, 0, SEEK_SET);

    zf->data = (unsigned char *)
	    mmap(0, zf->length, PROT_READ, MAP_FILE | MAP_PRIVATE, fd, 0);
    if (zf->data == MAP_FAILED) {
	ZIPFS_POSIX_ERROR(interp, "file mapping failed");
	return TCL_ERROR;
    }
#endif /* _WIN32 */
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * IsPasswordValid --
 *
 *	Basic test for whether a passowrd is valid. If the test fails, sets an
 *	error message in the interpreter.
 *
 * Returns:
 *	TCL_OK if the test passes, TCL_ERROR if it fails.
 *
 *-------------------------------------------------------------------------
 */

static inline int
IsPasswordValid(
    Tcl_Interp *interp,
    const char *passwd,
    size_t pwlen)
{
    if ((pwlen > 255) || strchr(passwd, 0xff)) {
	ZIPFS_ERROR(interp, "illegal password");
	ZIPFS_ERROR_CODE(interp, "BAD_PASS");
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSCatalogFilesystem --
 *
 *	This function generates the root node for a ZIPFS filesystem by
 *	reading the ZIP's central directory.
 *
 * Results:
 *	TCL_OK on success, TCL_ERROR otherwise with an error message placed
 *	into the given "interp" if it is not NULL. On error, frees zf!!
 *
 * Side effects:
 *	Will acquire and release the write lock.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSCatalogFilesystem(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    ZipFile *zf,		/* Temporary buffer hold archive descriptors */
    const char *mountPoint,	/* Mount point path. Must be fully normalized */
    const char *passwd,		/* Password for opening the ZIP, or NULL if
				 * the ZIP is unprotected. */
    const char *zipname)	/* Path to ZIP file to build a catalog of. */
{
    int isNew;
    size_t i, pwlen;
    ZipFile *zf0;
    ZipEntry *z;
    Tcl_HashEntry *hPtr;
    Tcl_DString ds, fpBuf;
    unsigned char *q;

    assert(TclIsZipfsPath(mountPoint)); /* Caller should have normalized */

    Tcl_DStringInit(&ds);

    /*
     * Basic verification of the password for sanity.
     */

    pwlen = 0;
    if (passwd) {
	pwlen = strlen(passwd);
	if (IsPasswordValid(interp, passwd, pwlen) != TCL_OK) {
	    ZipFSCloseArchive(interp, zf);
	    Tcl_Free(zf);
	    return TCL_ERROR;
	}
    }

    /*
     * Validate the TOC data. If that's bad, things fall apart.
     */

    if (zf->baseOffset >= zf->length || zf->passOffset >= zf->length ||
	    zf->directoryOffset >= zf->length) {
	ZIPFS_ERROR(interp, "bad zip data");
	ZIPFS_ERROR_CODE(interp, "BAD_ZIP");
	ZipFSCloseArchive(interp, zf);
	Tcl_Free(zf);
	return TCL_ERROR;
    }

    WriteLock();

    hPtr = Tcl_CreateHashEntry(&ZipFS.zipHash, mountPoint, &isNew);
    if (!isNew) {
	if (interp) {
	    zf0 = (ZipFile *) Tcl_GetHashValue(hPtr);
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s is already mounted on %s", zf0->name, mountPoint));
	    ZIPFS_ERROR_CODE(interp, "MOUNTED");
	}
	Unlock();
	ZipFSCloseArchive(interp, zf);
	Tcl_DStringFree(&ds);
	Tcl_Free(zf);
	return TCL_ERROR;
    }

    /*
     * Convert to a real archive descriptor.
     */

    zf->mountPoint = (char *) Tcl_GetHashKey(&ZipFS.zipHash, hPtr);
    zf->mountPointLen = strlen(zf->mountPoint);

    zf->nameLength = strlen(zipname);
    zf->name = (char *) Tcl_Alloc(zf->nameLength + 1);
    memcpy(zf->name, zipname, zf->nameLength + 1);

    Tcl_SetHashValue(hPtr, zf);
    if ((zf->passBuf[0] == 0) && pwlen) {
	int k = 0;

	zf->passBuf[k++] = pwlen;
	for (i = pwlen; i-- > 0 ;) {
	    zf->passBuf[k++] = (passwd[i] & 0x0f)
		    | pwrot[(passwd[i] >> 4) & 0x0f];
	}
	zf->passBuf[k] = '\0';
    }
    /* TODO - is this test necessary? When will mountPoint[0] be \0 ? */
    if (mountPoint[0] != '\0') {
	hPtr = Tcl_CreateHashEntry(&ZipFS.fileHash, mountPoint, &isNew);
	if (isNew) {
	    z = AllocateZipEntry();
	    Tcl_SetHashValue(hPtr, z);

	    z->depth = CountSlashes(mountPoint);
	    assert(z->depth >= ZIPFS_ROOTDIR_DEPTH);
	    z->zipFilePtr = zf;
	    z->isDirectory = (zf->baseOffset == 0) ? 1 : -1; /* root marker */
	    z->offset = zf->baseOffset;
	    z->compressMethod = ZIP_COMPMETH_STORED;
	    z->name = (char *) Tcl_GetHashKey(&ZipFS.fileHash, hPtr);
	    if (!strcmp(z->name, ZIPFS_VOLUME)) {
		z->flags |= ZE_F_VOLUME; /* Mark as root volume */
	    }
	    Tcl_Time t;
	    Tcl_GetTime(&t);
	    z->timestamp = t.sec;
	    z->next = zf->entries;
	    zf->entries = z;
	}
    }
    q = zf->data + zf->directoryOffset;
    Tcl_DStringInit(&fpBuf);
    for (i = 0; i < zf->numFiles; i++) {
	const unsigned char *start = zf->data;
	const unsigned char *end = zf->data + zf->length;
	int extra, isdir = 0, dosTime, dosDate, nbcompr;
	size_t offs, pathlen, comlen;
	unsigned char *lq, *gq = NULL;
	char *fullpath, *path;

	pathlen = ZipReadShort(start, end, q + ZIP_CENTRAL_PATHLEN_OFFS);
	comlen = ZipReadShort(start, end, q + ZIP_CENTRAL_FCOMMENTLEN_OFFS);
	extra = ZipReadShort(start, end, q + ZIP_CENTRAL_EXTRALEN_OFFS);
	Tcl_DStringSetLength(&ds, 0);
	path = DecodeZipEntryText(q + ZIP_CENTRAL_HEADER_LEN, pathlen, &ds);
	if ((pathlen > 0) && (path[pathlen - 1] == '/')) {
	    Tcl_DStringSetLength(&ds, pathlen - 1);
	    path = Tcl_DStringValue(&ds);
	    isdir = 1;
	}
	if ((strcmp(path, ".") == 0) || (strcmp(path, "..") == 0)) {
	    goto nextent;
	}
	lq = zf->data + zf->baseOffset
		+ ZipReadInt(start, end, q + ZIP_CENTRAL_LOCALHDR_OFFS);
	if ((lq < start) || (lq + ZIP_LOCAL_HEADER_LEN > end)) {
	    goto nextent;
	}
	nbcompr = ZipReadInt(start, end, lq + ZIP_LOCAL_COMPLEN_OFFS);
	if (!isdir && (nbcompr == 0)
		&& (ZipReadInt(start, end, lq + ZIP_LOCAL_UNCOMPLEN_OFFS) == 0)
		&& (ZipReadInt(start, end, lq + ZIP_LOCAL_CRC32_OFFS) == 0)) {
	    gq = q;
	    nbcompr = ZipReadInt(start, end, gq + ZIP_CENTRAL_COMPLEN_OFFS);
	}
	offs = (lq - zf->data)
		+ ZIP_LOCAL_HEADER_LEN
		+ ZipReadShort(start, end, lq + ZIP_LOCAL_PATHLEN_OFFS)
		+ ZipReadShort(start, end, lq + ZIP_LOCAL_EXTRALEN_OFFS);
	if (offs + nbcompr > zf->length) {
	    goto nextent;
	}

	if (!isdir && (mountPoint[0] == '\0') && !CountSlashes(path)) {
#ifdef ANDROID
	    /*
	     * When mounting the ZIP archive on the root directory try to
	     * remap top level regular files of the archive to
	     * /assets/.root/... since this directory should not be in a valid
	     * APK due to the leading dot in the file name component. This
	     * trick should make the files AndroidManifest.xml,
	     * resources.arsc, and classes.dex visible to Tcl.
	     */
	    Tcl_DString ds2;

	    Tcl_DStringInit(&ds2);
	    Tcl_DStringAppend(&ds2, "assets/.root/", -1);
	    Tcl_DStringAppend(&ds2, path, -1);
	    if (ZipFSLookup(Tcl_DStringValue(&ds2))) {
		/* should not happen but skip it anyway */
		Tcl_DStringFree(&ds2);
		goto nextent;
	    }
	    Tcl_DStringSetLength(&ds, 0);
	    Tcl_DStringAppend(&ds, Tcl_DStringValue(&ds2),
		    Tcl_DStringLength(&ds2));
	    path = Tcl_DStringValue(&ds);
	    Tcl_DStringFree(&ds2);
#else /* !ANDROID */
	    /*
	     * Regular files skipped when mounting on root.
	     */
	    goto nextent;
#endif /* ANDROID */
	}

	Tcl_DStringSetLength(&fpBuf, 0);
	fullpath = MapPathToZipfs(interp, mountPoint, path, &fpBuf);
	z = AllocateZipEntry();
	z->depth = CountSlashes(fullpath);
	assert(z->depth >= ZIPFS_ROOTDIR_DEPTH);
	z->zipFilePtr = zf;
	z->isDirectory = isdir;
	z->isEncrypted =
		(ZipReadShort(start, end, lq + ZIP_LOCAL_FLAGS_OFFS) & 1)
		&& (nbcompr > ZIP_CRYPT_HDR_LEN);
	z->offset = offs;
	if (gq) {
	    z->crc32 = ZipReadInt(start, end, gq + ZIP_CENTRAL_CRC32_OFFS);
	    dosDate = ZipReadShort(start, end, gq + ZIP_CENTRAL_MDATE_OFFS);
	    dosTime = ZipReadShort(start, end, gq + ZIP_CENTRAL_MTIME_OFFS);
	    z->timestamp = DosTimeDate(dosDate, dosTime);
	    z->numBytes = ZipReadInt(start, end,
		    gq + ZIP_CENTRAL_UNCOMPLEN_OFFS);
	    z->compressMethod = ZipReadShort(start, end,
		    gq + ZIP_CENTRAL_COMPMETH_OFFS);
	} else {
	    z->crc32 = ZipReadInt(start, end, lq + ZIP_LOCAL_CRC32_OFFS);
	    dosDate = ZipReadShort(start, end, lq + ZIP_LOCAL_MDATE_OFFS);
	    dosTime = ZipReadShort(start, end, lq + ZIP_LOCAL_MTIME_OFFS);
	    z->timestamp = DosTimeDate(dosDate, dosTime);
	    z->numBytes = ZipReadInt(start, end,
		    lq + ZIP_LOCAL_UNCOMPLEN_OFFS);
	    z->compressMethod = ZipReadShort(start, end,
		    lq + ZIP_LOCAL_COMPMETH_OFFS);
	}
	z->numCompressedBytes = nbcompr;
	hPtr = Tcl_CreateHashEntry(&ZipFS.fileHash, fullpath, &isNew);
	if (!isNew) {
	    /* should not happen but skip it anyway */
	    Tcl_Free(z);
	    goto nextent;
	}

	Tcl_SetHashValue(hPtr, z);
	z->name = (char *) Tcl_GetHashKey(&ZipFS.fileHash, hPtr);
	z->next = zf->entries;
	zf->entries = z;
	if (isdir && (mountPoint[0] == '\0') && (z->depth == ZIPFS_ROOTDIR_DEPTH)) {
	    z->tnext = zf->topEnts;
	    zf->topEnts = z;
	}

	/*
	 * Make any directory nodes we need. ZIPs are not consistent about
	 * containing directory nodes.
	 */

	if (!z->isDirectory && (z->depth > ZIPFS_ROOTDIR_DEPTH)) {
	    char *dir, *endPtr;
	    ZipEntry *zd;

	    Tcl_DStringSetLength(&ds, strlen(z->name) + 8);
	    Tcl_DStringSetLength(&ds, 0);
	    Tcl_DStringAppend(&ds, z->name, -1);
	    dir = Tcl_DStringValue(&ds);
	    for (endPtr = strrchr(dir, '/'); endPtr && (endPtr != dir);
		    endPtr = strrchr(dir, '/')) {
		Tcl_DStringSetLength(&ds, endPtr - dir);
		hPtr = Tcl_CreateHashEntry(&ZipFS.fileHash, dir, &isNew);
		if (!isNew) {
		    /*
		     * Already made. That's fine.
		     */
		    break;
		}

		zd = AllocateZipEntry();
		zd->depth = CountSlashes(dir);
		assert(zd->depth > ZIPFS_ROOTDIR_DEPTH);
		zd->zipFilePtr = zf;
		zd->isDirectory = 1;
		zd->offset = z->offset;
		zd->timestamp = z->timestamp;
		zd->compressMethod = ZIP_COMPMETH_STORED;
		Tcl_SetHashValue(hPtr, zd);
		zd->name = (char *) Tcl_GetHashKey(&ZipFS.fileHash, hPtr);
		zd->next = zf->entries;
		zf->entries = zd;
		if ((mountPoint[0] == '\0') && (zd->depth == ZIPFS_ROOTDIR_DEPTH)) {
		    zd->tnext = zf->topEnts;
		    zf->topEnts = zd;
		}
	    }
	}
    nextent:
	q += pathlen + comlen + extra + ZIP_CENTRAL_HEADER_LEN;
    }
    Unlock();
    Tcl_DStringFree(&fpBuf);
    Tcl_DStringFree(&ds);
    Tcl_FSMountsChanged(NULL);
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipfsSetup --
 *
 *	Common initialisation code. ZipFS.initialized must *not* be set prior
 *	to the call.
 *
 *-------------------------------------------------------------------------
 */

static void
ZipfsSetup(void)
{
#if TCL_THREADS
    static const Tcl_Time t = { 0, 0 };

    /*
     * Inflate condition variable.
     */

    Tcl_MutexLock(&ZipFSMutex);
    Tcl_ConditionWait(&ZipFSCond, &ZipFSMutex, &t);
    Tcl_MutexUnlock(&ZipFSMutex);
#endif /* TCL_THREADS */

    crc32tab = get_crc_table();
    Tcl_FSRegister(NULL, &zipfsFilesystem);
    Tcl_InitHashTable(&ZipFS.fileHash, TCL_STRING_KEYS);
    Tcl_InitHashTable(&ZipFS.zipHash, TCL_STRING_KEYS);
    ZipFS.idCount = 1;
    ZipFS.wrmax = DEFAULT_WRITE_MAX_SIZE;
    ZipFS.fallbackEntryEncoding = (char *)
	    Tcl_Alloc(strlen(ZIPFS_FALLBACK_ENCODING) + 1);
    strcpy(ZipFS.fallbackEntryEncoding, ZIPFS_FALLBACK_ENCODING);
    ZipFS.initialized = 1;
}

/*
 *-------------------------------------------------------------------------
 *
 * ListMountPoints --
 *
 *	This procedure lists the mount points and what's mounted there, or
 *	reports whether there are any mounts (if there's no interpreter). The
 *	read lock must be held by the caller.
 *
 * Results:
 *	A standard Tcl result. TCL_OK (or TCL_BREAK if no mounts and no
 *	interpreter).
 *
 * Side effects:
 *	Interpreter result may be updated.
 *
 *-------------------------------------------------------------------------
 */

static int
ListMountPoints(
    Tcl_Interp *interp)
{
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    ZipFile *zf;
    Tcl_Obj *resultList;

    if (!interp) {
	/*
	 * Are there any entries in the zipHash? Don't need to enumerate them
	 * all to know.
	 */

	return (ZipFS.zipHash.numEntries ? TCL_OK : TCL_BREAK);
    }

    TclNewObj(resultList);
    for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &search); hPtr;
	    hPtr = Tcl_NextHashEntry(&search)) {
	zf = (ZipFile *) Tcl_GetHashValue(hPtr);
	Tcl_ListObjAppendElement(NULL, resultList, Tcl_NewStringObj(
		zf->mountPoint, -1));
	Tcl_ListObjAppendElement(NULL, resultList, Tcl_NewStringObj(
		zf->name, -1));
    }
    Tcl_SetObjResult(interp, resultList);
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * CleanupMount --
 *
 *    Releases all resources associated with a mounted archive. There
 *    must not be any open files in the archive.
 *
 *    Caller MUST be holding WriteLock() before calling this function.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    Memory associated with the mounted archive is deallocated.
 *------------------------------------------------------------------------
 */
static void
CleanupMount(
    ZipFile *zf)		/* Mount point */
{
    ZipEntry *z, *znext;
    Tcl_HashEntry *hPtr;
    for (z = zf->entries; z; z = znext) {
	znext = z->next;
	hPtr = Tcl_FindHashEntry(&ZipFS.fileHash, z->name);
	if (hPtr) {
	    Tcl_DeleteHashEntry(hPtr);
	}
	if (z->data) {
	    Tcl_Free(z->data);
	}
	Tcl_Free(z);
    }
    zf->entries = NULL;
}

/*
 *-------------------------------------------------------------------------
 *
 * DescribeMounted --
 *
 *	This procedure describes what is mounted at the given the mount point.
 *	The interpreter result is not updated if there is nothing mounted at
 *	the given point. The read lock must be held by the caller.
 *
 * Results:
 *	A standard Tcl result. TCL_OK (or TCL_BREAK if nothing mounted there
 *	and no interpreter).
 *
 * Side effects:
 *	Interpreter result may be updated.
 *
 *-------------------------------------------------------------------------
 */

static int
DescribeMounted(
    Tcl_Interp *interp,
    const char *mountPoint)
{
    if (interp) {
	ZipFile *zf = ZipFSLookupZip(mountPoint);

	if (zf) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(zf->name, -1));
	    return TCL_OK;
	}
    }
    return (interp ? TCL_OK : TCL_BREAK);
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_Mount --
 *
 *	This procedure is invoked to mount a given ZIP archive file on a given
 *	mountpoint with optional ZIP password.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A ZIP archive file is read, analyzed and mounted, resources are
 *	allocated.
 *
 *-------------------------------------------------------------------------
 */

int
TclZipfs_Mount(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    const char *zipname,	/* Path to ZIP file to mount */
    const char *mountPoint,	/* Mount point path. */
    const char *passwd)		/* Password for opening the ZIP, or NULL if
				 * the ZIP is unprotected. */
{
    ZipFile *zf;
    int ret;

    ReadLock();
    if (!ZipFS.initialized) {
	ZipfsSetup();
    }

    /*
     * No mount point, so list all mount points and what is mounted there.
     */

    if (mountPoint == NULL) {
	ret = ListMountPoints(interp);
	Unlock();
	return ret;
    }

    Tcl_DString ds;
    Tcl_DStringInit(&ds);
    ret = NormalizeMountPoint(interp, mountPoint, &ds);
    if (ret != TCL_OK) {
	Unlock();
	return ret;
    }
    mountPoint = Tcl_DStringValue(&ds);

    if (!zipname) {
	/*
	 * Mount point but no file, so describe what is mounted at that mount
	 * point.
	 */

	ret = DescribeMounted(interp, mountPoint);
	Unlock();
    } else {
	/* Have both a mount point and a file (name) to mount there. */

	Tcl_Obj *zipPathObj;
	Tcl_Obj *normZipPathObj;

	Unlock();

	zipPathObj = Tcl_NewStringObj(zipname, -1);
	Tcl_IncrRefCount(zipPathObj);
	normZipPathObj = Tcl_FSGetNormalizedPath(interp, zipPathObj);
	if (normZipPathObj == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "could not normalize zip filename \"%s\"", zipname));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "NORMALIZE", (char *)NULL);
	    ret = TCL_ERROR;
	} else {
	    Tcl_IncrRefCount(normZipPathObj);
	    const char *normPath = Tcl_GetString(normZipPathObj);
	    if (passwd == NULL ||
		    (ret = IsPasswordValid(interp, passwd,
			    strlen(passwd))) == TCL_OK) {
		zf = AllocateZipFile(interp, strlen(mountPoint));
		if (zf == NULL) {
		    ret = TCL_ERROR;
		} else {
		    ret = ZipFSOpenArchive(interp, normPath, 1, zf);
		    if (ret != TCL_OK) {
			Tcl_Free(zf);
		    } else {
			ret = ZipFSCatalogFilesystem(
				interp, zf, mountPoint, passwd, normPath);
			/* Note zf is already freed on error! */
		    }
		}
	    }
	    Tcl_DecrRefCount(normZipPathObj);
	    if (ret == TCL_OK && interp) {
		Tcl_DStringResult(interp, &ds);
	    }
	}
	Tcl_DecrRefCount(zipPathObj);
    }

    Tcl_DStringFree(&ds);
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_MountBuffer --
 *
 *	This procedure is invoked to mount a given ZIP archive file on a given
 *	mountpoint.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A ZIP archive file is read, analyzed and mounted, resources are
 *	allocated.
 *
 *-------------------------------------------------------------------------
 */

int
TclZipfs_MountBuffer(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    const void *data,
    size_t datalen,
    const char *mountPoint,	/* Mount point path. */
    int copy)
{
    ZipFile *zf;
    int ret;

    if (mountPoint == NULL || data == NULL) {
	ZIPFS_ERROR(interp, "mount point and/or data are null");
	return TCL_ERROR;
    }

    /* TODO - how come a *read* lock suffices for initialzing ? */
    ReadLock();
    if (!ZipFS.initialized) {
	ZipfsSetup();
    }

    Tcl_DString ds;
    Tcl_DStringInit(&ds);
    ret = NormalizeMountPoint(interp, mountPoint, &ds);
    if (ret != TCL_OK) {
	Unlock();
	return ret;
    }
    mountPoint = Tcl_DStringValue(&ds);

    Unlock();

    /*
     * Have both a mount point and data to mount there.
     * What's the magic about 64 * 1024 * 1024 ?
     */
    ret = TCL_ERROR;
    if ((datalen <= ZIP_CENTRAL_END_LEN) ||
	    (datalen - ZIP_CENTRAL_END_LEN) >
		    (64 * 1024 * 1024 - ZIP_CENTRAL_END_LEN)) {
	ZIPFS_ERROR(interp, "illegal file size");
	ZIPFS_ERROR_CODE(interp, "FILE_SIZE");
	goto done;
    }
    zf = AllocateZipFile(interp, strlen(mountPoint));
    if (zf == NULL) {
	goto done;
    }
    zf->isMemBuffer = 1;
    zf->length = datalen;

    if (copy) {
	zf->data = (unsigned char *)Tcl_AttemptAlloc(datalen);
	if (zf->data == NULL) {
	    ZipFSCloseArchive(interp, zf);
	    Tcl_Free(zf);
	    ZIPFS_MEM_ERROR(interp);
	    goto done;
	}
	memcpy(zf->data, data, datalen);
	zf->ptrToFree = zf->data;
    } else {
	zf->data = (unsigned char *)data;
	zf->ptrToFree = NULL;
    }
    ret = ZipFSFindTOC(interp, 1, zf);
    if (ret != TCL_OK) {
	Tcl_Free(zf);
    } else {
	/* Note ZipFSCatalogFilesystem will free zf on error */
	ret = ZipFSCatalogFilesystem(
	    interp, zf, mountPoint, NULL, "Memory Buffer");
    }
    if (ret == TCL_OK && interp) {
	Tcl_DStringResult(interp, &ds);
    }

done:
    Tcl_DStringFree(&ds);
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_Unmount --
 *
 *	This procedure is invoked to unmount a given ZIP archive.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A mounted ZIP archive file is unmounted, resources are free'd.
 *
 *-------------------------------------------------------------------------
 */

int
TclZipfs_Unmount(
    Tcl_Interp *interp,		/* Current interpreter. NULLable. */
    const char *mountPoint)	/* Mount point path. */
{
    ZipFile *zf;
    Tcl_HashEntry *hPtr;
    Tcl_DString dsm;
    int ret = TCL_OK, unmounted = 0;

    Tcl_DStringInit(&dsm);

    WriteLock();
    if (!ZipFS.initialized) {
	goto done;
    }

    /*
     * Mount point sometimes is a relative or otherwise denormalized path.
     * But an absolute name is needed as mount point here.
     */

    if (NormalizeMountPoint(interp, mountPoint, &dsm) != TCL_OK) {
	goto done;
    }
    mountPoint = Tcl_DStringValue(&dsm);

    hPtr = Tcl_FindHashEntry(&ZipFS.zipHash, mountPoint);
    /* don't report no-such-mount as an error */
    if (!hPtr) {
	goto done;
    }

    zf = (ZipFile *) Tcl_GetHashValue(hPtr);
    if (zf->numOpen > 0) {
	ZIPFS_ERROR(interp, "filesystem is busy");
	ZIPFS_ERROR_CODE(interp, "BUSY");
	ret = TCL_ERROR;
	goto done;
    }
    Tcl_DeleteHashEntry(hPtr);

    /*
     * Now no longer mounted - the rest of the code won't find it - but we're
     * still cleaning things up.
     */

    CleanupMount(zf);
    ZipFSCloseArchive(interp, zf);

    Tcl_Free(zf);
    unmounted = 1;

  done:
    Unlock();
    Tcl_DStringFree(&dsm);
    if (unmounted) {
	Tcl_FSMountsChanged(NULL);
    }
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMountObjCmd --
 *
 *	This procedure is invoked to process the [zipfs mount] command.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A ZIP archive file is mounted, resources are allocated.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMountObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *mountPoint = NULL, *zipFile = NULL, *password = NULL;
    int result;

    if (objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "?zipfile? ?mountpoint? ?password?");
	return TCL_ERROR;
    }
    /*
     * A single argument is treated as the mountpoint. Two arguments
     * are treated as zipfile and mountpoint.
     */
    if (objc > 1) {
	if (objc == 2) {
	    mountPoint = Tcl_GetString(objv[1]);
	} else {
	    /* 2 < objc < 4 */
	    zipFile = Tcl_GetString(objv[1]);
	    mountPoint = Tcl_GetString(objv[2]);
	    if (objc > 3) {
		password = Tcl_GetString(objv[3]);
	    }
	}
    }

    result = TclZipfs_Mount(interp, zipFile, mountPoint, password);
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMountBufferObjCmd --
 *
 *	This procedure is invoked to process the [zipfs mountdata] command.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A ZIP archive file is mounted, resources are allocated.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMountBufferObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *mountPoint = NULL;	/* Mount point path. */
    unsigned char *data = NULL;
    Tcl_Size length;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data mountpoint");
	return TCL_ERROR;
    }
    data = Tcl_GetBytesFromObj(interp, objv[1], &length);
    mountPoint = Tcl_GetString(objv[2]);
    if (data == NULL) {
	return TCL_ERROR;
    }
    return TclZipfs_MountBuffer(interp, data, length, mountPoint, 1);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSRootObjCmd --
 *
 *	This procedure is invoked to process the [zipfs root] command. It
 *	returns the root that all zipfs file systems are mounted under.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSRootObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,
    Tcl_Obj *const *objv)
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, "");
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(ZIPFS_VOLUME, -1));
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSUnmountObjCmd --
 *
 *	This procedure is invoked to process the [zipfs unmount] command.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A mounted ZIP archive file is unmounted, resources are free'd.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSUnmountObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "mountpoint");
	return TCL_ERROR;
    }
    return TclZipfs_Unmount(interp, TclGetString(objv[1]));
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMkKeyObjCmd --
 *
 *	This procedure is invoked to process the [zipfs mkkey] command.  It
 *	produces a rotated password to be embedded into an image file.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMkKeyObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size len, i = 0;
    const char *pw;
    Tcl_Obj *passObj;
    unsigned char *passBuf;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "password");
	return TCL_ERROR;
    }
    pw = TclGetStringFromObj(objv[1], &len);
    if (len == 0) {
	return TCL_OK;
    }
    if (IsPasswordValid(interp, pw, len) != TCL_OK) {
	return TCL_ERROR;
    }

    passObj = Tcl_NewByteArrayObj(NULL, 264);
    passBuf = Tcl_GetBytesFromObj(NULL, passObj, (Tcl_Size *)NULL);
    while (len > 0) {
	int ch = pw[len - 1];

	passBuf[i++] = (ch & 0x0f) | pwrot[(ch >> 4) & 0x0f];
	len--;
    }
    passBuf[i] = i;
    i++;
    ZipWriteInt(passBuf, passBuf + 264, passBuf + i, ZIP_PASSWORD_END_SIG);
    Tcl_SetByteArrayLength(passObj, i + 4);
    Tcl_SetObjResult(interp, passObj);
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * RandomChar --
 *
 *	Worker for ZipAddFile().  Picks a random character (range: 0..255)
 *	using Tcl's standard PRNG.
 *
 * Returns:
 *	Tcl result code. Updates chPtr with random character on success.
 *
 * Side effects:
 *	Advances the PRNG state. May reenter the Tcl interpreter if the user
 *	has replaced the PRNG.
 *
 *-------------------------------------------------------------------------
 */

static int
RandomChar(
    Tcl_Interp *interp,
    int step,
    int *chPtr)
{
    double r;
    Tcl_Obj *ret;

    if (Tcl_EvalEx(interp, "::tcl::mathfunc::rand", TCL_INDEX_NONE, 0) != TCL_OK) {
	goto failed;
    }
    ret = Tcl_GetObjResult(interp);
    if (Tcl_GetDoubleFromObj(interp, ret, &r) != TCL_OK) {
	goto failed;
    }
    *chPtr = (int) (r * 256);
    return TCL_OK;

  failed:
    Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
	    "\n    (evaluating PRNG step %d for password encoding)",
	    step));
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipAddFile --
 *
 *	This procedure is used by ZipFSMkZipOrImg() to add a single file to
 *	the output ZIP archive file being written. A ZipEntry struct about the
 *	input file is added to the given fileHash table for later creation of
 *	the central ZIP directory.
 *
 *	Tcl *always* encodes filenames in the ZIP as UTF-8. Similarly, it
 *	would always encode comments as UTF-8, if it supported comments.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Input file is read and (compressed and) written to the output ZIP
 *	archive file.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipAddFile(
    Tcl_Interp *interp,		/* Current interpreter. */
    Tcl_Obj *pathObj,		/* Actual name of the file to add. */
    const char *name,		/* Name to use in the ZIP archive, in Tcl's
				 * internal encoding. */
    Tcl_Channel out,		/* The open ZIP archive being built. */
    const char *passwd,		/* Password for encoding the file, or NULL if
				 * the file is to be unprotected. */
    char *buf,			/* Working buffer. */
    int bufsize,		/* Size of buf */
    Tcl_HashTable *fileHash)	/* Where to record ZIP entry metdata so we can
				 * built the central directory. */
{
    const unsigned char *start = (unsigned char *) buf;
    const unsigned char *end = (unsigned char *) buf + bufsize;
    Tcl_Channel in;
    Tcl_HashEntry *hPtr;
    ZipEntry *z;
    z_stream stream;
    Tcl_DString zpathDs;	/* Buffer for the encoded filename. */
    const char *zpathExt;	/* Filename in external encoding (true
				 * UTF-8). */
    const char *zpathTcl;	/* Filename in Tcl's internal encoding. */
    int crc, flush, zpathlen;
    size_t nbyte, nbytecompr;
    Tcl_Size len, olen, align = 0;
    long long headerStartOffset, dataStartOffset, dataEndOffset;
    int mtime = 0, isNew, compMeth;
    unsigned long keys[3], keys0[3];
    char obuf[4096];

    /*
     * Trim leading '/' characters. If this results in an empty string, we've
     * nothing to do.
     */

    zpathTcl = name;
    while (zpathTcl && zpathTcl[0] == '/') {
	zpathTcl++;
    }
    if (!zpathTcl || (zpathTcl[0] == '\0')) {
	return TCL_OK;
    }

    /*
     * Convert to encoded form. Note that we use strlen() here; if someone's
     * crazy enough to embed NULs in filenames, they deserve what they get!
     */

    if (Tcl_UtfToExternalDStringEx(interp, tclUtf8Encoding, zpathTcl,
	    TCL_INDEX_NONE, 0, &zpathDs, NULL) != TCL_OK) {
	Tcl_DStringFree(&zpathDs);
	return TCL_ERROR;
    }
    zpathExt = Tcl_DStringValue(&zpathDs);
    zpathlen = strlen(zpathExt);
    if (zpathlen + ZIP_CENTRAL_HEADER_LEN > bufsize) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"path too long for \"%s\"", TclGetString(pathObj)));
	ZIPFS_ERROR_CODE(interp, "PATH_LEN");
	Tcl_DStringFree(&zpathDs);
	return TCL_ERROR;
    }
    in = Tcl_FSOpenFileChannel(interp, pathObj, "rb", 0);
    if (!in) {
	Tcl_DStringFree(&zpathDs);
#ifdef _WIN32
	/* hopefully a directory */
	if (strcmp("permission denied", Tcl_PosixError(interp)) == 0) {
	    Tcl_Close(interp, in);
	    return TCL_OK;
	}
#endif /* _WIN32 */
	Tcl_Close(interp, in);
	return TCL_ERROR;
    } else {
	Tcl_StatBuf statBuf;

	if (Tcl_FSStat(pathObj, &statBuf) != -1) {
	    mtime = statBuf.st_mtime;
	}
    }
    Tcl_ResetResult(interp);

    /*
     * Compute the CRC.
     */

    crc = 0;
    nbyte = nbytecompr = 0;
    while (1) {
	len = Tcl_Read(in, buf, bufsize);
	if (len < 0) {
	    Tcl_DStringFree(&zpathDs);
	    if (nbyte == 0 && errno == EISDIR) {
		Tcl_Close(interp, in);
		return TCL_OK;
	    }
	readErrorWithChannelOpen:
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf("read error on \"%s\": %s",
		    TclGetString(pathObj), Tcl_PosixError(interp)));
	    Tcl_Close(interp, in);
	    return TCL_ERROR;
	}
	if (len == 0) {
	    break;
	}
	crc = crc32(crc, (unsigned char *) buf, len);
	nbyte += len;
    }
    if (Tcl_Seek(in, 0, SEEK_SET) == -1) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("seek error on \"%s\": %s",
		TclGetString(pathObj), Tcl_PosixError(interp)));
	Tcl_Close(interp, in);
	Tcl_DStringFree(&zpathDs);
	return TCL_ERROR;
    }

    /*
     * Remember where we've got to so far so we can write the header (after
     * writing the file).
     */

    headerStartOffset = Tcl_Tell(out);

    /*
     * Reserve space for the per-file header. Includes writing the file name
     * as we already know that.
     */

    memset(buf, '\0', ZIP_LOCAL_HEADER_LEN);
    memcpy(buf + ZIP_LOCAL_HEADER_LEN, zpathExt, zpathlen);
    len = zpathlen + ZIP_LOCAL_HEADER_LEN;
    if (Tcl_Write(out, buf, len) != len) {
    writeErrorWithChannelOpen:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"write error on \"%s\": %s",
		TclGetString(pathObj), Tcl_PosixError(interp)));
	Tcl_Close(interp, in);
	Tcl_DStringFree(&zpathDs);
	return TCL_ERROR;
    }

    /*
     * Align payload to next 4-byte boundary (if necessary) using a dummy
     * extra entry similar to the zipalign tool from Android's SDK.
     */

    if ((len + headerStartOffset) & 3) {
	unsigned char abuf[8];
	const unsigned char *astart = abuf;
	const unsigned char *aend = abuf + 8;

	align = 4 + ((len + headerStartOffset) & 3);
	ZipWriteShort(astart, aend, abuf, 0xffff);
	ZipWriteShort(astart, aend, abuf + 2, align - 4);
	ZipWriteInt(astart, aend, abuf + 4, 0x03020100);
	if (Tcl_Write(out, (const char *) abuf, align) != align) {
	    goto writeErrorWithChannelOpen;
	}
    }

    /*
     * Set up encryption if we were asked to.
     */

    if (passwd) {
	int i, ch, tmp;
	unsigned char kvbuf[2*ZIP_CRYPT_HDR_LEN];

	init_keys(passwd, keys, crc32tab);
	for (i = 0; i < ZIP_CRYPT_HDR_LEN - 2; i++) {
	    if (RandomChar(interp, i, &ch) != TCL_OK) {
		Tcl_Close(interp, in);
		return TCL_ERROR;
	    }
	    kvbuf[i + ZIP_CRYPT_HDR_LEN] = UCHAR(zencode(keys, crc32tab, ch, tmp));
	}
	Tcl_ResetResult(interp);
	init_keys(passwd, keys, crc32tab);
	for (i = 0; i < ZIP_CRYPT_HDR_LEN - 2; i++) {
	    kvbuf[i] = UCHAR(zencode(keys, crc32tab,
		    kvbuf[i + ZIP_CRYPT_HDR_LEN], tmp));
	}
	kvbuf[i++] = UCHAR(zencode(keys, crc32tab, crc >> 16, tmp));
	kvbuf[i++] = UCHAR(zencode(keys, crc32tab, crc >> 24, tmp));
	len = Tcl_Write(out, (char *) kvbuf, ZIP_CRYPT_HDR_LEN);
	memset(kvbuf, 0, sizeof(kvbuf));
	if (len != ZIP_CRYPT_HDR_LEN) {
	    goto writeErrorWithChannelOpen;
	}
	memcpy(keys0, keys, sizeof(keys0));
	nbytecompr += ZIP_CRYPT_HDR_LEN;
    }

    /*
     * Save where we've got to in case we need to just store this file.
     */

    Tcl_Flush(out);
    dataStartOffset = Tcl_Tell(out);

    /*
     * Compress the stream.
     */

    compMeth = ZIP_COMPMETH_DEFLATED;
    memset(&stream, 0, sizeof(z_stream));
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    if (deflateInit2(&stream, 9, Z_DEFLATED, -15, 8,
	    Z_DEFAULT_STRATEGY) != Z_OK) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"compression init error on \"%s\"", TclGetString(pathObj)));
	ZIPFS_ERROR_CODE(interp, "DEFLATE_INIT");
	Tcl_Close(interp, in);
	Tcl_DStringFree(&zpathDs);
	return TCL_ERROR;
    }

    do {
	len = Tcl_Read(in, buf, bufsize);
	if (len < 0) {
	    deflateEnd(&stream);
	    goto readErrorWithChannelOpen;
	}
	stream.avail_in = len;
	stream.next_in = (unsigned char *) buf;
	flush = Tcl_Eof(in) ? Z_FINISH : Z_NO_FLUSH;
	do {
	    stream.avail_out = sizeof(obuf);
	    stream.next_out = (unsigned char *) obuf;
	    len = deflate(&stream, flush);
	    if (len == Z_STREAM_ERROR) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"deflate error on \"%s\"", TclGetString(pathObj)));
		ZIPFS_ERROR_CODE(interp, "DEFLATE");
		deflateEnd(&stream);
		Tcl_Close(interp, in);
		Tcl_DStringFree(&zpathDs);
		return TCL_ERROR;
	    }
	    olen = sizeof(obuf) - stream.avail_out;
	    if (passwd) {
		Tcl_Size i;
		int tmp;

		for (i = 0; i < olen; i++) {
		    obuf[i] = (char) zencode(keys, crc32tab, obuf[i], tmp);
		}
	    }
	    if (olen && (Tcl_Write(out, obuf, olen) != olen)) {
		deflateEnd(&stream);
		goto writeErrorWithChannelOpen;
	    }
	    nbytecompr += olen;
	} while (stream.avail_out == 0);
    } while (flush != Z_FINISH);
    deflateEnd(&stream);

    /*
     * Work out where we've got to.
     */

    Tcl_Flush(out);
    dataEndOffset = Tcl_Tell(out);

    if (nbyte - nbytecompr <= 0) {
	/*
	 * Compressed file larger than input, write it again uncompressed.
	 */

	if (Tcl_Seek(in, 0, SEEK_SET) != 0) {
	    goto seekErr;
	}
	if (Tcl_Seek(out, dataStartOffset, SEEK_SET) != dataStartOffset) {
	seekErr:
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "seek error: %s", Tcl_PosixError(interp)));
	    Tcl_Close(interp, in);
	    Tcl_DStringFree(&zpathDs);
	    return TCL_ERROR;
	}
	nbytecompr = (passwd ? ZIP_CRYPT_HDR_LEN : 0);
	while (1) {
	    len = Tcl_Read(in, buf, bufsize);
	    if (len < 0) {
		goto readErrorWithChannelOpen;
	    } else if (len == 0) {
		break;
	    }
	    if (passwd) {
		Tcl_Size i;
		int tmp;

		for (i = 0; i < len; i++) {
		    buf[i] = (char) zencode(keys0, crc32tab, buf[i], tmp);
		}
	    }
	    if (Tcl_Write(out, buf, len) != len) {
		goto writeErrorWithChannelOpen;
	    }
	    nbytecompr += len;
	}
	compMeth = ZIP_COMPMETH_STORED;

	/*
	 * Chop off everything after this; it's the over-large compressed data
	 * and we don't know if it is going to get overwritten otherwise.
	 */

	Tcl_Flush(out);
	dataEndOffset = Tcl_Tell(out);
	Tcl_TruncateChannel(out, dataEndOffset);
    }
    Tcl_Close(interp, in);
    Tcl_DStringFree(&zpathDs);
    zpathExt = NULL;

    hPtr = Tcl_CreateHashEntry(fileHash, zpathTcl, &isNew);
    if (!isNew) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"non-unique path name \"%s\"", TclGetString(pathObj)));
	ZIPFS_ERROR_CODE(interp, "DUPLICATE_PATH");
	return TCL_ERROR;
    }

    /*
     * Remember that we've written the file (for central directory generation)
     * and generate the local (per-file) header in the space that we reserved
     * earlier.
     */

    z = AllocateZipEntry();
    Tcl_SetHashValue(hPtr, z);
    z->isEncrypted = (passwd ? 1 : 0);
    z->offset = headerStartOffset;
    z->crc32 = crc;
    z->timestamp = mtime;
    z->numBytes = nbyte;
    z->numCompressedBytes = nbytecompr;
    z->compressMethod = compMeth;
    z->name = (char *) Tcl_GetHashKey(fileHash, hPtr);

    /*
     * Write final local header information.
     */

    SerializeLocalEntryHeader(start, end, (unsigned char *) buf, z,
	    zpathlen, align);
    if (Tcl_Seek(out, headerStartOffset, SEEK_SET) != headerStartOffset) {
	Tcl_DeleteHashEntry(hPtr);
	Tcl_Free(z);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"seek error: %s", Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    if (Tcl_Write(out, buf, ZIP_LOCAL_HEADER_LEN) != ZIP_LOCAL_HEADER_LEN) {
	Tcl_DeleteHashEntry(hPtr);
	Tcl_Free(z);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"write error: %s", Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    Tcl_Flush(out);
    if (Tcl_Seek(out, dataEndOffset, SEEK_SET) != dataEndOffset) {
	Tcl_DeleteHashEntry(hPtr);
	Tcl_Free(z);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"seek error: %s", Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFind --
 *
 *	Worker for ZipFSMkZipOrImg() that discovers the list of files to add.
 *	Simple wrapper around [zipfs find].
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Obj *
ZipFSFind(
    Tcl_Interp *interp,
    Tcl_Obj *dirRoot)
{
    Tcl_Obj *cmd[2];
    int result;

    cmd[0] = Tcl_NewStringObj("::tcl::zipfs::find", -1);
    cmd[1] = dirRoot;
    Tcl_IncrRefCount(cmd[0]);
    result = Tcl_EvalObjv(interp, 2, cmd, 0);
    Tcl_DecrRefCount(cmd[0]);
    if (result != TCL_OK) {
	return NULL;
    }
    return Tcl_GetObjResult(interp);
}

/*
 *-------------------------------------------------------------------------
 *
 * ComputeNameInArchive --
 *
 *	Helper for ZipFSMkZipOrImg() that computes what the actual name of a
 *	file in the ZIP archive should be, stripping a prefix (if appropriate)
 *	and any leading slashes. If the result is an empty string, the entry
 *	should be skipped.
 *
 * Returns:
 *	Pointer to the name (in Tcl's internal encoding), which will be in
 *	memory owned by one of the argument objects.
 *
 * Side effects:
 *	None (if Tcl_Objs have string representations)
 *
 *-------------------------------------------------------------------------
 */

static inline const char *
ComputeNameInArchive(
    Tcl_Obj *pathObj,		/* The path to the origin file */
    Tcl_Obj *directNameObj,	/* User-specified name for use in the ZIP
				 * archive */
    const char *strip,		/* A prefix to strip; may be NULL if no
				 * stripping need be done. */
    Tcl_Size slen)		/* The length of the prefix; must be 0 if no
				 * stripping need be done. */
{
    const char *name;
    Tcl_Size len;

    if (directNameObj) {
	name = TclGetString(directNameObj);
    } else {
	name = TclGetStringFromObj(pathObj, &len);
	if (slen > 0) {
	    if ((len <= slen) || (strncmp(strip, name, slen) != 0)) {
		/*
		 * Guaranteed to be a NUL at the end, which will make this
		 * entry be skipped.
		 */

		return name + len;
	    }
	    name += slen;
	}
    }
    while (name[0] == '/') {
	++name;
    }
    return name;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMkZipOrImg --
 *
 *	This procedure is creates a new ZIP archive file or image file given
 *	output filename, input directory of files to be archived, optional
 *	password, and optional image to be prepended to the output ZIP archive
 *	file. It's the core of the implementation of [zipfs mkzip], [zipfs
 *	mkimg], [zipfs lmkzip] and [zipfs lmkimg].
 *
 *	Tcl *always* encodes filenames in the ZIP as UTF-8. Similarly, it
 *	would always encode comments as UTF-8, if it supported comments.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	A new ZIP archive file or image file is written.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMkZipOrImg(
    Tcl_Interp *interp,		/* Current interpreter. */
    int isImg,			/* Are we making an image? */
    Tcl_Obj *targetFile,	/* What file are we making? */
    Tcl_Obj *dirRoot,		/* What directory do we take files from? Do
				 * not specify at the same time as
				 * mappingList (one must be NULL). */
    Tcl_Obj *mappingList,	/* What files are we putting in, and with what
				 * names? Do not specify at the same time as
				 * dirRoot (one must be NULL). */
    Tcl_Obj *originFile,	/* If we're making an image, what file does
				 * the non-ZIP part of the image come from? */
    Tcl_Obj *stripPrefix,	/* Are we going to strip a prefix from
				 * filenames found beneath dirRoot? If NULL,
				 * do not strip anything (except for dirRoot
				 * itself). */
    Tcl_Obj *passwordObj)	/* The password for encoding things. NULL if
				 * there's no password protection. */
{
    Tcl_Channel out;
    int count, ret = TCL_ERROR;
    Tcl_Size pwlen = 0, slen = 0, len, i = 0;
    Tcl_Size lobjc;
    long long dataStartOffset;	/* The overall file offset of the start of the
				 * data section of the file. */
    long long directoryStartOffset;
				/* The overall file offset of the start of the
				 * central directory. */
    long long suffixStartOffset;/* The overall file offset of the start of the
				 * suffix of the central directory (i.e.,
				 * where this data will be written). */
    Tcl_Obj **lobjv, *list = mappingList;
    ZipEntry *z;
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    Tcl_HashTable fileHash;
    char *strip = NULL, *pw = NULL, passBuf[264], buf[4096];
    unsigned char *start = (unsigned char *) buf;
    unsigned char *end = start + sizeof(buf);

    /*
     * Caller has verified that the number of arguments is correct.
     */

    passBuf[0] = 0;
    if (passwordObj != NULL) {
	pw = TclGetStringFromObj(passwordObj, &pwlen);
	if (IsPasswordValid(interp, pw, pwlen) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (pwlen == 0) {
	    pw = NULL;
	}
    }
    if (dirRoot != NULL) {
	list = ZipFSFind(interp, dirRoot);
	if (!list) {
	    return TCL_ERROR;
	}
    }
    Tcl_IncrRefCount(list);
    if (TclListObjLength(interp, list, &lobjc) != TCL_OK) {
	Tcl_DecrRefCount(list);
	return TCL_ERROR;
    }
    if (mappingList && (lobjc % 2)) {
	Tcl_DecrRefCount(list);
	ZIPFS_ERROR(interp, "need even number of elements");
	ZIPFS_ERROR_CODE(interp, "LIST_LENGTH");
	return TCL_ERROR;
    }
    if (lobjc == 0) {
	Tcl_DecrRefCount(list);
	ZIPFS_ERROR(interp, "empty archive");
	ZIPFS_ERROR_CODE(interp, "EMPTY");
	return TCL_ERROR;
    }
    if (TclListObjGetElements(interp, list, &lobjc, &lobjv) != TCL_OK) {
	Tcl_DecrRefCount(list);
	return TCL_ERROR;
    }
    out = Tcl_FSOpenFileChannel(interp, targetFile, "wb", 0755);
    if (out == NULL) {
	Tcl_DecrRefCount(list);
	return TCL_ERROR;
    }

    /*
     * Copy the existing contents from the image if it is an executable image.
     * Care must be taken because this might include an existing ZIP, which
     * needs to be stripped.
     */

    if (isImg) {
	ZipFile *zf, zf0;
	int isMounted = 0;
	const char *imgName;

	// TODO: normalize the origin file name
	imgName = (originFile != NULL) ? TclGetString(originFile) :
		Tcl_GetNameOfExecutable();
	if (pwlen) {
	    i = 0;
	    for (len = pwlen; len-- > 0;) {
		int ch = pw[len];

		passBuf[i] = (ch & 0x0f) | pwrot[(ch >> 4) & 0x0f];
		i++;
	    }
	    passBuf[i] = i;
	    ++i;
	    passBuf[i++] = (char) ZIP_PASSWORD_END_SIG;
	    passBuf[i++] = (char) (ZIP_PASSWORD_END_SIG >> 8);
	    passBuf[i++] = (char) (ZIP_PASSWORD_END_SIG >> 16);
	    passBuf[i++] = (char) (ZIP_PASSWORD_END_SIG >> 24);
	    passBuf[i] = '\0';
	}

	/*
	 * Check for mounted image.
	 */

	WriteLock();
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &search); hPtr;
		hPtr = Tcl_NextHashEntry(&search)) {
	    zf = (ZipFile *) Tcl_GetHashValue(hPtr);
	    if (strcmp(zf->name, imgName) == 0) {
		isMounted = 1;
		zf->numOpen++;
		break;
	    }
	}
	Unlock();

	if (!isMounted) {
	    zf = &zf0;
	    memset(&zf0, 0, sizeof(ZipFile));
	}
	if (isMounted || ZipFSOpenArchive(interp, imgName, 0, zf) == TCL_OK) {
	    /*
	     * Copy everything up to the ZIP-related suffix.
	     */

	    if ((size_t)Tcl_Write(out, (char *) zf->data,
		    zf->passOffset) != zf->passOffset) {
		memset(passBuf, 0, sizeof(passBuf));
		Tcl_DecrRefCount(list);
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"write error: %s", Tcl_PosixError(interp)));
		Tcl_Close(interp, out);
		if (zf == &zf0) {
		    ZipFSCloseArchive(interp, zf);
		} else {
		    WriteLock();
		    zf->numOpen--;
		    Unlock();
		}
		return TCL_ERROR;
	    }
	    if (zf == &zf0) {
		ZipFSCloseArchive(interp, zf);
	    } else {
		WriteLock();
		zf->numOpen--;
		Unlock();
	    }
	} else {
	    /*
	     * Fall back to read it as plain file which hopefully is a static
	     * tclsh or wish binary with proper zipfs infrastructure built in.
	     */

	    if (CopyImageFile(interp, imgName, out) != TCL_OK) {
		memset(passBuf, 0, sizeof(passBuf));
		Tcl_DecrRefCount(list);
		Tcl_Close(interp, out);
		return TCL_ERROR;
	    }
	}

	/*
	 * Store the password so that the automounter can find it.
	 */

	len = strlen(passBuf);
	if (len > 0) {
	    i = Tcl_Write(out, passBuf, len);
	    if (i != len) {
		Tcl_DecrRefCount(list);
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"write error: %s", Tcl_PosixError(interp)));
		Tcl_Close(interp, out);
		return TCL_ERROR;
	    }
	}
	memset(passBuf, 0, sizeof(passBuf));
	Tcl_Flush(out);
	dataStartOffset = Tcl_Tell(out);
    } else {
	dataStartOffset = 0;
    }

    /*
     * Prepare the contents of the ZIP archive.
     */

    Tcl_InitHashTable(&fileHash, TCL_STRING_KEYS);
    if (mappingList == NULL && stripPrefix != NULL) {
	strip = TclGetStringFromObj(stripPrefix, &slen);
	if (!slen) {
	    strip = NULL;
	}
    }
    for (i = 0; i < lobjc; i += (mappingList ? 2 : 1)) {
	Tcl_Obj *pathObj = lobjv[i];
	const char *name = ComputeNameInArchive(pathObj,
		(mappingList ? lobjv[i + 1] : NULL), strip, slen);

	if (name[0] == '\0') {
	    continue;
	}
	if (ZipAddFile(interp, pathObj, name, out, pw, buf, sizeof(buf),
		&fileHash) != TCL_OK) {
	    goto done;
	}
    }

    /*
     * Construct the contents of the ZIP central directory.
     */

    directoryStartOffset = Tcl_Tell(out);
    count = 0;
    for (i = 0; i < lobjc; i += (mappingList ? 2 : 1)) {
	const char *name = ComputeNameInArchive(lobjv[i],
		(mappingList ? lobjv[i + 1] : NULL), strip, slen);
	Tcl_DString ds;

	hPtr = Tcl_FindHashEntry(&fileHash, name);
	if (!hPtr) {
	    continue;
	}
	z = (ZipEntry *) Tcl_GetHashValue(hPtr);

	if (Tcl_UtfToExternalDStringEx(interp, tclUtf8Encoding, z->name,
		TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	    ret = TCL_ERROR;
	    goto done;
	}
	name = Tcl_DStringValue(&ds);
	len = Tcl_DStringLength(&ds);
	SerializeCentralDirectoryEntry(start, end, (unsigned char *) buf,
		z, len, dataStartOffset);
	if ((Tcl_Write(out, buf, ZIP_CENTRAL_HEADER_LEN)
		!= ZIP_CENTRAL_HEADER_LEN)
		|| (Tcl_Write(out, name, len) != len)) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "write error: %s", Tcl_PosixError(interp)));
	    Tcl_DStringFree(&ds);
	    goto done;
	}
	Tcl_DStringFree(&ds);
	count++;
    }

    /*
     * Finalize the central directory.
     */

    Tcl_Flush(out);
    suffixStartOffset = Tcl_Tell(out);
    SerializeCentralDirectorySuffix(start, end, (unsigned char *) buf,
	    count, dataStartOffset, directoryStartOffset, suffixStartOffset);
    if (Tcl_Write(out, buf, ZIP_CENTRAL_END_LEN) != ZIP_CENTRAL_END_LEN) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"write error: %s", Tcl_PosixError(interp)));
	goto done;
    }
    Tcl_Flush(out);
    ret = TCL_OK;

  done:
    if (ret == TCL_OK) {
	ret = Tcl_Close(interp, out);
    } else {
	Tcl_Close(interp, out);
    }
    Tcl_DecrRefCount(list);
    for (hPtr = Tcl_FirstHashEntry(&fileHash, &search); hPtr;
	    hPtr = Tcl_NextHashEntry(&search)) {
	z = (ZipEntry *) Tcl_GetHashValue(hPtr);
	Tcl_Free(z);
	Tcl_DeleteHashEntry(hPtr);
    }
    Tcl_DeleteHashTable(&fileHash);
    return ret;
}

/*
 * ---------------------------------------------------------------------
 *
 * CopyImageFile --
 *
 *	A simple file copy function that is used (by ZipFSMkZipOrImg) for
 *	anything that is not an image with a ZIP appended.
 *
 * Returns:
 *	A Tcl result code.
 *
 * Side effects:
 *	Writes to an output channel.
 *
 * ---------------------------------------------------------------------
 */

static int
CopyImageFile(
    Tcl_Interp *interp,		/* For error reporting. */
    const char *imgName,	/* Where to copy from. */
    Tcl_Channel out)		/* Where to copy to; already open for writing
				 * binary data. */
{
    Tcl_WideInt i, k;
    Tcl_Size m, n;
    Tcl_Channel in;
    char buf[4096];
    const char *errMsg;

    Tcl_ResetResult(interp);
    in = Tcl_OpenFileChannel(interp, imgName, "rb", 0644);
    if (!in) {
	return TCL_ERROR;
    }

    /*
     * Get the length of the file (and exclude non-files).
     */

    i = Tcl_Seek(in, 0, SEEK_END);
    if (i == -1) {
	errMsg = "seek error";
	goto copyError;
    }
    Tcl_Seek(in, 0, SEEK_SET);

    /*
     * Copy the whole file, 8 blocks at a time (reasonably efficient). Note
     * that this totally ignores things like Windows's Alternate File Streams.
     */

    for (k = 0; k < i; k += m) {
	m = i - k;
	if (m > (Tcl_Size) sizeof(buf)) {
	    m = sizeof(buf);
	}
	n = Tcl_Read(in, buf, m);
	if (n == -1) {
	    errMsg = "read error";
	    goto copyError;
	} else if (n == 0) {
	    break;
	}
	m = Tcl_Write(out, buf, n);
	if (m != n) {
	    errMsg = "write error";
	    goto copyError;
	}
    }
    Tcl_Close(interp, in);
    return TCL_OK;

  copyError:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "%s: %s", errMsg, Tcl_PosixError(interp)));
    Tcl_Close(interp, in);
    return TCL_ERROR;
}

/*
 * ---------------------------------------------------------------------
 *
 * SerializeLocalEntryHeader, SerializeCentralDirectoryEntry,
 * SerializeCentralDirectorySuffix --
 *
 *	Create serialized forms of the structures that make up the ZIP
 *	metadata. Note that the both the local entry and the central directory
 *	entry need to have the name of the entry written directly afterwards.
 *
 *	We could write these as structs except we need to guarantee that we
 *	are writing these out as little-endian values.
 *
 * Side effects:
 *	Both update their buffer arguments, but otherwise change nothing.
 *
 * ---------------------------------------------------------------------
 */

static void
SerializeLocalEntryHeader(
    const unsigned char *start,	/* The start of writable memory. */
    const unsigned char *end,	/* The end of writable memory. */
    unsigned char *buf,		/* Where to serialize to */
    ZipEntry *z,		/* The description of what to serialize. */
    int nameLength,		/* The length of the name. */
    int align)			/* The number of alignment bytes. */
{
    ZipWriteInt(start, end, buf + ZIP_LOCAL_SIG_OFFS, ZIP_LOCAL_HEADER_SIG);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_VERSION_OFFS, ZIP_MIN_VERSION);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_FLAGS_OFFS,
	    z->isEncrypted + ZIP_LOCAL_FLAGS_UTF8);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_COMPMETH_OFFS,
	    z->compressMethod);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_MTIME_OFFS,
	    ToDosTime(z->timestamp));
    ZipWriteShort(start, end, buf + ZIP_LOCAL_MDATE_OFFS,
	    ToDosDate(z->timestamp));
    ZipWriteInt(start, end, buf + ZIP_LOCAL_CRC32_OFFS, z->crc32);
    ZipWriteInt(start, end, buf + ZIP_LOCAL_COMPLEN_OFFS,
	    z->numCompressedBytes);
    ZipWriteInt(start, end, buf + ZIP_LOCAL_UNCOMPLEN_OFFS, z->numBytes);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_PATHLEN_OFFS, nameLength);
    ZipWriteShort(start, end, buf + ZIP_LOCAL_EXTRALEN_OFFS, align);
}

static void
SerializeCentralDirectoryEntry(
    const unsigned char *start,	/* The start of writable memory. */
    const unsigned char *end,	/* The end of writable memory. */
    unsigned char *buf,		/* Where to serialize to */
    ZipEntry *z,		/* The description of what to serialize. */
    size_t nameLength,		/* The length of the name. */
    long long dataStartOffset)	/* The overall file offset of the start of the
				 * data section of the file. */
{
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_SIG_OFFS,
	    ZIP_CENTRAL_HEADER_SIG);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_VERSIONMADE_OFFS,
	    ZIP_MIN_VERSION);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_VERSION_OFFS, ZIP_MIN_VERSION);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_FLAGS_OFFS,
	    z->isEncrypted + ZIP_LOCAL_FLAGS_UTF8);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_COMPMETH_OFFS,
	    z->compressMethod);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_MTIME_OFFS,
	    ToDosTime(z->timestamp));
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_MDATE_OFFS,
	    ToDosDate(z->timestamp));
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_CRC32_OFFS, z->crc32);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_COMPLEN_OFFS,
	    z->numCompressedBytes);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_UNCOMPLEN_OFFS, z->numBytes);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_PATHLEN_OFFS, nameLength);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_EXTRALEN_OFFS, 0);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_FCOMMENTLEN_OFFS, 0);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_DISKFILE_OFFS, 0);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_IATTR_OFFS, 0);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_EATTR_OFFS, 0);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_LOCALHDR_OFFS,
	    z->offset - dataStartOffset);
}

static void
SerializeCentralDirectorySuffix(
    const unsigned char *start,	/* The start of writable memory. */
    const unsigned char *end,	/* The end of writable memory. */
    unsigned char *buf,		/* Where to serialize to */
    int entryCount,		/* The number of entries in the directory */
    long long dataStartOffset,
				/* The overall file offset of the start of the
				 * data file. */
    long long directoryStartOffset,
				/* The overall file offset of the start of the
				 * central directory. */
    long long suffixStartOffset)/* The overall file offset of the start of the
				 * suffix of the central directory (i.e.,
				 * where this data will be written). */
{
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_END_SIG_OFFS,
	    ZIP_CENTRAL_END_SIG);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_DISKNO_OFFS, 0);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_DISKDIR_OFFS, 0);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_ENTS_OFFS, entryCount);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_TOTALENTS_OFFS, entryCount);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_DIRSIZE_OFFS,
	    suffixStartOffset - directoryStartOffset);
    ZipWriteInt(start, end, buf + ZIP_CENTRAL_DIRSTART_OFFS,
	    directoryStartOffset - dataStartOffset);
    ZipWriteShort(start, end, buf + ZIP_CENTRAL_COMMENTLEN_OFFS, 0);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMkZipObjCmd, ZipFSLMkZipObjCmd --
 *
 *	These procedures are invoked to process the [zipfs mkzip] and [zipfs
 *	lmkzip] commands.  See description of ZipFSMkZipOrImg().
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See description of ZipFSMkZipOrImg().
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMkZipObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *stripPrefix, *password;

    if (objc < 3 || objc > 5) {
	Tcl_WrongNumArgs(interp, 1, objv, "outfile indir ?strip? ?password?");
	return TCL_ERROR;
    }
    if (Tcl_IsSafe(interp)) {
	ZIPFS_ERROR(interp, "operation not permitted in a safe interpreter");
	ZIPFS_ERROR_CODE(interp, "SAFE_INTERP");
	return TCL_ERROR;
    }

    stripPrefix = (objc > 3 ? objv[3] : NULL);
    password = (objc > 4 ? objv[4] : NULL);
    return ZipFSMkZipOrImg(interp, 0, objv[1], objv[2], NULL, NULL,
	    stripPrefix, password);
}

static int
ZipFSLMkZipObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *password;

    if (objc < 3 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "outfile inlist ?password?");
	return TCL_ERROR;
    }
    if (Tcl_IsSafe(interp)) {
	ZIPFS_ERROR(interp, "operation not permitted in a safe interpreter");
	ZIPFS_ERROR_CODE(interp, "SAFE_INTERP");
	return TCL_ERROR;
    }

    password = (objc > 3 ? objv[3] : NULL);
    return ZipFSMkZipOrImg(interp, 0, objv[1], NULL, objv[2], NULL,
	    NULL, password);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMkImgObjCmd, ZipFSLMkImgObjCmd --
 *
 *	These procedures are invoked to process the [zipfs mkimg] and [zipfs
 *	lmkimg] commands.  See description of ZipFSMkZipOrImg().
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See description of ZipFSMkZipOrImg().
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMkImgObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *originFile, *stripPrefix, *password;

    if (objc < 3 || objc > 6) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"outfile indir ?strip? ?password? ?infile?");
	return TCL_ERROR;
    }
    if (Tcl_IsSafe(interp)) {
	ZIPFS_ERROR(interp, "operation not permitted in a safe interpreter");
	ZIPFS_ERROR_CODE(interp, "SAFE_INTERP");
	return TCL_ERROR;
    }

    originFile = (objc > 5 ? objv[5] : NULL);
    stripPrefix = (objc > 3 ? objv[3] : NULL);
    password = (objc > 4 ? objv[4] : NULL);
    return ZipFSMkZipOrImg(interp, 1, objv[1], objv[2], NULL,
	    originFile, stripPrefix, password);
}

static int
ZipFSLMkImgObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *originFile, *password;

    if (objc < 3 || objc > 5) {
	Tcl_WrongNumArgs(interp, 1, objv, "outfile inlist ?password? ?infile?");
	return TCL_ERROR;
    }
    if (Tcl_IsSafe(interp)) {
	ZIPFS_ERROR(interp, "operation not permitted in a safe interpreter");
	ZIPFS_ERROR_CODE(interp, "SAFE_INTERP");
	return TCL_ERROR;
    }

    originFile = (objc > 4 ? objv[4] : NULL);
    password = (objc > 3 ? objv[3] : NULL);
    return ZipFSMkZipOrImg(interp, 1, objv[1], NULL, objv[2],
	    originFile, NULL, password);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSCanonicalObjCmd --
 *
 *	This procedure is invoked to process the [zipfs canonical] command.
 *	It returns the canonical name for a file within zipfs
 *
 * Results:
 *	Always TCL_OK provided the right number of arguments are supplied.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSCanonicalObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *mntPoint = NULL;
    Tcl_DString dsPath, dsMount;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "?mountpoint? filename");
	return TCL_ERROR;
    }

    Tcl_DStringInit(&dsPath);
    Tcl_DStringInit(&dsMount);

    if (objc == 2) {
	mntPoint = ZIPFS_VOLUME;
    } else {
	if (NormalizeMountPoint(interp, Tcl_GetString(objv[1]), &dsMount) != TCL_OK) {
	    return TCL_ERROR;
	}
	mntPoint = Tcl_DStringValue(&dsMount);
    }
    (void)MapPathToZipfs(interp, mntPoint, Tcl_GetString(objv[objc - 1]),
	    &dsPath);
    Tcl_SetObjResult(interp, Tcl_DStringToObj(&dsPath));
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSExistsObjCmd --
 *
 *	This procedure is invoked to process the [zipfs exists] command.  It
 *	tests for the existence of a file in the ZIP filesystem and places a
 *	boolean into the interp's result.
 *
 * Results:
 *	Always TCL_OK provided the right number of arguments are supplied.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSExistsObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    char *filename;
    int exists;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "filename");
	return TCL_ERROR;
    }

    filename = TclGetString(objv[1]);

    ReadLock();
    exists = ZipFSLookup(filename) != NULL;
    if (!exists) {
	/* An ancestor directory of a file ? */
	exists = ContainsMountPoint(filename, -1);
    }

    Unlock();

    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(exists));
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSInfoObjCmd --
 *
 *	This procedure is invoked to process the [zipfs info] command.  On
 *	success, it returns a Tcl list made up of name of ZIP archive file,
 *	size uncompressed, size compressed, and archive offset of a file in
 *	the ZIP filesystem.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSInfoObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    char *filename;
    ZipEntry *z;
    int ret;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "filename");
	return TCL_ERROR;
    }
    filename = TclGetString(objv[1]);
    ReadLock();
    z = ZipFSLookup(filename);
    if (z) {
	Tcl_Obj *result = Tcl_GetObjResult(interp);

	Tcl_ListObjAppendElement(interp, result,
		Tcl_NewStringObj(z->zipFilePtr->name, -1));
	Tcl_ListObjAppendElement(interp, result,
		Tcl_NewWideIntObj(z->numBytes));
	Tcl_ListObjAppendElement(interp, result,
		Tcl_NewWideIntObj(z->numCompressedBytes));
	Tcl_ListObjAppendElement(interp, result, Tcl_NewWideIntObj(z->offset));
	ret = TCL_OK;
    } else {
	Tcl_SetErrno(ENOENT);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "path \"%s\" not found in any zipfs volume",
		    filename));
	}
	ret = TCL_ERROR;
    }
    Unlock();
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSListObjCmd --
 *
 *	This procedure is invoked to process the [zipfs list] command.	 On
 *	success, it returns a Tcl list of files of the ZIP filesystem which
 *	match a search pattern (glob or regexp).
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSListObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    char *pattern = NULL;
    Tcl_RegExp regexp = NULL;
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    Tcl_Obj *result = Tcl_GetObjResult(interp);
    const char *options[] = {"-glob", "-regexp", NULL};
    enum list_options { OPT_GLOB, OPT_REGEXP };

    /*
     * Parse arguments.
     */

    if (objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "?(-glob|-regexp)? ?pattern?");
	return TCL_ERROR;
    }
    if (objc == 3) {
	int idx;

	if (Tcl_GetIndexFromObj(interp, objv[1], options, "option",
		0, &idx) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (idx) {
	case OPT_GLOB:
	    pattern = TclGetString(objv[2]);
	    break;
	case OPT_REGEXP:
	    regexp = Tcl_RegExpCompile(interp, TclGetString(objv[2]));
	    if (!regexp) {
		return TCL_ERROR;
	    }
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    } else if (objc == 2) {
	pattern = TclGetString(objv[1]);
    }

    /*
     * Scan for matching entries.
     */

    ReadLock();
    if (pattern) {
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.fileHash, &search);
		hPtr != NULL; hPtr = Tcl_NextHashEntry(&search)) {
	    ZipEntry *z = (ZipEntry *) Tcl_GetHashValue(hPtr);

	    if (Tcl_StringMatch(z->name, pattern)) {
		Tcl_ListObjAppendElement(interp, result,
			Tcl_NewStringObj(z->name, -1));
	    }
	}
    } else if (regexp) {
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.fileHash, &search);
		hPtr; hPtr = Tcl_NextHashEntry(&search)) {
	    ZipEntry *z = (ZipEntry *) Tcl_GetHashValue(hPtr);

	    if (Tcl_RegExpExec(interp, regexp, z->name, z->name)) {
		Tcl_ListObjAppendElement(interp, result,
			Tcl_NewStringObj(z->name, -1));
	    }
	}
    } else {
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.fileHash, &search);
		hPtr; hPtr = Tcl_NextHashEntry(&search)) {
	    ZipEntry *z = (ZipEntry *) Tcl_GetHashValue(hPtr);

	    Tcl_ListObjAppendElement(interp, result,
		    Tcl_NewStringObj(z->name, -1));
	}
    }
    Unlock();
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfsMountExe --
 *
 *	Checks if an archive is mounted on the ZIPFS_APP_MOUNT mount point.
 *	If not, attempts to mount the zip archive attached to the application
 *	executable on to ZIPFS_APP_MOUNT.
 *
 *	Caller should not be holding any locks	when calling this function.
 *
 * Results:
 *	1 -> if an archive is present on ZIPFS_APP_MOUNT
 *	0 -> otherwise
 *
 * Side effects:
 *	May mount the archive at the ZIPFS_APP_MOUNT mount point.
 *
 *-------------------------------------------------------------------------
 */
static int
TclZipfsMountExe()
{
    WriteLock();
    if (!ZipFS.initialized) {
	ZipfsSetup();
    }
    int mounted = (ZipFSLookupZip(ZIPFS_APP_MOUNT) != NULL);
    Unlock();

    if (!mounted) {
	const char *exe = Tcl_GetNameOfExecutable();
	if (exe && *exe) {
	    mounted =
		(TclZipfs_Mount(NULL, exe, ZIPFS_APP_MOUNT, NULL) == TCL_OK);
	    if (!mounted) {
		/*
		 * Even if TclZipFS_Mount returns error, it could be some
		 * other thread mount it in the meanwhile leading to a mount
		 * busy error when this thread tries. Unlikely, but...
		 */
		ReadLock();
		mounted = ZipFSLookupZip(ZIPFS_APP_MOUNT) != NULL;
		Unlock();
	    }
	}
    }
    return mounted;
}
/*
 *-------------------------------------------------------------------------
 *
 * TclZipfsMountShlib --
 *
 *	Checks if an archive is mounted on the ZIPFS_ZIP_MOUNT mount point.
 *	If not, attempts to mount the zip archive attached to the application
 *	executable on to ZIPFS_ZIP_MOUNT.
 *
 *	Caller should not be holding any locks	when calling this function.
 *
 * Results:
 *	1 -> if an archive is present on ZIPFS_ZIP_MOUNT
 *	0 -> otherwise
 *
 * Side effects:
 *	May mount the archive at the ZIPFS_ZIP_MOUNT mount point.
 *
 *-------------------------------------------------------------------------
 */
static int
TclZipfsMountShlib()
{
#if defined(STATIC_BUILD)
    /* Static builds have no shared library */
    return 0;
#else
    WriteLock();
    if (!ZipFS.initialized) {
	ZipfsSetup();
    }
    int mounted = (ZipFSLookupZip(ZIPFS_ZIP_MOUNT) != NULL);
    Unlock();

    if (!mounted) {
	Tcl_Obj *shlibPathObj = TclGetObjNameOfShlib();
	if (shlibPathObj) {
	    mounted = (TclZipfs_Mount(NULL, Tcl_GetString(shlibPathObj),
			      ZIPFS_ZIP_MOUNT, NULL) == TCL_OK);
	    if (!mounted) {
		/*
		 * Even if TclZipFS_Mount returns error, it could be some
		 * other thread mount it in the meanwhile leading to a mount
		 * busy error when this thread tries. Unlikely, but...
		 */
		ReadLock();
		mounted = ZipFSLookupZip(ZIPFS_ZIP_MOUNT) != NULL;
		Unlock();
	    }
	}
    }
    return mounted;
#endif
}


/*
 *-------------------------------------------------------------------------
 *
 * TclZipfsLocateTclLibrary --
 *
 *	This procedure locates the root that Tcl's library files are mounted
 *	under if they are under a zipfs file system archive attached to the
 *	executable or the shared library/DLL. The archives should have been
 *	mounted (if present) before this function is called.
 *
 *	If the libraries are found, the encoding subdirectory is added to
 *	the encoding directory search path.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May initializes the global variable zipfs_literal_tcl_library. Will
 *	never be cleared. The encoding directory paths are modified.
 *
 *-------------------------------------------------------------------------
 */

static void
TclZipfsLocateTclLibrary(
	int appZipfsPresent,	/* non-0 if app zipfs is to be checked */
	int shlibZipfsPresent)  /* non-0 if shared lib is to be checked */
{
    Tcl_Obj *vfsInitScript;
    int found;

    if (zipfs_tcl_library_init) {
	return;
    }

    Tcl_MutexLock(&ZipFSLocateLibMutex);
    if (zipfs_tcl_library_init) {
	/*
	 * Some other thread won the race. Should only have one app thread
	 * doing this, but be safe.
	 */
	Tcl_MutexUnlock(&ZipFSLocateLibMutex);
	return;
    }

    if (appZipfsPresent) {
	vfsInitScript = Tcl_NewStringObj(ZIPFS_APP_MOUNT "/tcl_library/init.tcl", -1);
	Tcl_IncrRefCount(vfsInitScript);
	found = Tcl_FSAccess(vfsInitScript, F_OK);
	Tcl_DecrRefCount(vfsInitScript);
	if (found == TCL_OK) {
	    /* Note this MUST be constant string as never deallocted */
	    zipfs_literal_tcl_library = ZIPFS_APP_MOUNT "/tcl_library";
	    goto unlock_and_return;
	}
    }
    if (shlibZipfsPresent) {
	vfsInitScript = Tcl_NewStringObj(ZIPFS_ZIP_MOUNT "/tcl_library/init.tcl", -1);
	Tcl_IncrRefCount(vfsInitScript);
	found = Tcl_FSAccess(vfsInitScript, F_OK);
	Tcl_DecrRefCount(vfsInitScript);
	if (found == TCL_OK) {
	    /* Note this MUST be constant string as never deallocted */
	    zipfs_literal_tcl_library = ZIPFS_ZIP_MOUNT "/tcl_library";
	    goto unlock_and_return;
	}
    }

unlock_and_return:
    zipfs_tcl_library_init = 1;
    Tcl_MutexUnlock(&ZipFSLocateLibMutex);
    if (zipfs_literal_tcl_library) {
	/* Found it, set up encoding dirs */
	(void)TclZipfsInitEncodingDirs();
    }
    return;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_TclLibrary --
 *
 *	This procedure gets the root that Tcl's library
 *	files are mounted under if they are under a zipfs file system.
 *
 * Results:
 *	A Tcl object holding the location (with zero refcount), or NULL if no
 *	Tcl library can be found.
 *
 *-------------------------------------------------------------------------
 */

Tcl_Obj *
TclZipfs_TclLibrary(void)
{
    /*
     * Ideally, TclZipfsLocateTclLibrary would already been called at
     * startup through TclZipfs_AppHook. However, existing custom
     * applications (e.g. tkinter - Bug [6fbabfe166]) may not do so.
     * So if not already set, try to find it.
     */
    if (!zipfs_tcl_library_init) {
	TclZipfsLocateTclLibrary(TclZipfsMountExe(), TclZipfsMountShlib());
    }

    if (zipfs_literal_tcl_library) {
	return Tcl_NewStringObj(zipfs_literal_tcl_library, -1);
    }

    return NULL;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSTclLibraryObjCmd --
 *
 *	This procedure is invoked to process the
 *	[::tcl::zipfs::tcl_library_init] command, usually called during the
 *	execution of Tcl's interpreter startup. It returns the root that Tcl's
 *	library files are mounted under.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSTclLibraryObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    TCL_UNUSED(int) /*objc*/,
    TCL_UNUSED(Tcl_Obj *const *)) /*objv*/
{
    if (!Tcl_IsSafe(interp)) {
	Tcl_Obj *pResult = TclZipfs_TclLibrary();

	if (!pResult) {
	    TclNewObj(pResult);
	}
	Tcl_SetObjResult(interp, pResult);
    }
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelClose --
 *
 *	This function is called to close a channel.
 *
 * Results:
 *	Always TCL_OK.
 *
 * Side effects:
 *	Resources are free'd.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipChannelClose(
    void *instanceData,
    TCL_UNUSED(Tcl_Interp *),
    int flags)
{
    ZipChannel *info = (ZipChannel *) instanceData;

    if ((flags & (TCL_CLOSE_READ | TCL_CLOSE_WRITE)) != 0) {
	return EINVAL;
    }

    if (info->isEncrypted) {
	info->isEncrypted = 0;
	memset(info->keys, 0, sizeof(info->keys));
    }
    WriteLock();
    if (ZipChannelWritable(info)) {
	/*
	 * Copy channel data back into original file in archive.
	 */
	ZipEntry *z = info->zipEntryPtr;
	assert(info->ubufToFree && info->ubuf);
	unsigned char *newdata;
	newdata = (unsigned char *) Tcl_AttemptRealloc(
		info->ubufToFree,
		info->numBytes ? info->numBytes : 1); /* Bug [23dd83ce7c] */
	if (newdata == NULL) {
	    /* Could not reallocate, keep existing buffer */
	    newdata = info->ubufToFree;
	}
	info->ubufToFree = NULL; /* Now newdata! */
	info->ubuf = NULL;
	info->ubufSize = 0;

	/* Replace old content */
	if (z->data) {
	    Tcl_Free(z->data);
	}
	z->data = newdata; /* May be NULL when ubufToFree was NULL */
	z->numBytes = z->numCompressedBytes = info->numBytes;
	assert(z->data || z->numBytes == 0);
	z->compressMethod = ZIP_COMPMETH_STORED;
	z->timestamp = time(NULL);
	z->isDirectory = 0;
	z->isEncrypted = 0;
	z->offset = 0;
	z->crc32 = 0;
    }
    info->zipFilePtr->numOpen--;
    Unlock();
    if (info->ubufToFree) {
	assert(info->ubuf);
	Tcl_Free(info->ubufToFree);
	info->ubuf = NULL;
	info->ubufToFree = NULL;
	info->ubufSize = 0;
    }
    Tcl_Free(info);
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelRead --
 *
 *	This function is called to read data from channel.
 *
 * Results:
 *	Number of bytes read or -1 on error with error number set.
 *
 * Side effects:
 *	Data is read and file pointer is advanced.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipChannelRead(
    void *instanceData,
    char *buf,
    int toRead,
    int *errloc)
{
    ZipChannel *info = (ZipChannel *) instanceData;
    Tcl_Size nextpos;

    if (info->isDirectory < 0) {
	/*
	 * Special case: when executable combined with ZIP archive file read
	 * data in front of ZIP, i.e. the executable itself.
	 */

	nextpos = info->cursor + toRead;
	if ((size_t)nextpos > info->zipFilePtr->baseOffset) {
	    toRead = info->zipFilePtr->baseOffset - info->cursor;
	    nextpos = info->zipFilePtr->baseOffset;
	}
	if (toRead == 0) {
	    return 0;
	}
	memcpy(buf, info->zipFilePtr->data, toRead);
	info->cursor = nextpos;
	*errloc = 0;
	return toRead;
    }
    if (info->isDirectory) {
	*errloc = EISDIR;
	return -1;
    }
    nextpos = info->cursor + toRead;
    if (nextpos > info->numBytes) {
	toRead = info->numBytes - info->cursor;
	nextpos = info->numBytes;
    }
    if (toRead == 0) {
	return 0;
    }
    if (info->isEncrypted) {
	int i;
	/*
	 * TODO - when is this code ever exercised? Cannot reach it from
	 * tests. In particular, decryption is always done at channel open
	 * to allow for seeks and random reads.
	 */
	for (i = 0; i < toRead; i++) {
	    int ch = info->ubuf[i + info->cursor];

	    buf[i] = zdecode(info->keys, crc32tab, ch);
	}
    } else {
	memcpy(buf, info->ubuf + info->cursor, toRead);
    }
    info->cursor = nextpos;
    *errloc = 0;
    return toRead;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelWrite --
 *
 *	This function is called to write data into channel.
 *
 * Results:
 *	Number of bytes written or -1 on error with error number set.
 *
 * Side effects:
 *	Data is written and file pointer is advanced.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipChannelWrite(
    void *instanceData,
    const char *buf,
    int toWrite,
    int *errloc)
{
    ZipChannel *info = (ZipChannel *) instanceData;
    unsigned long nextpos;

    if (!ZipChannelWritable(info)) {
	*errloc = EINVAL;
	return -1;
    }

    assert(info->ubuf == info->ubufToFree);
    assert(info->ubufToFree && info->ubufSize > 0);
    assert(info->ubufSize <= info->maxWrite);
    assert(info->numBytes <= info->ubufSize);
    assert(info->cursor <= info->numBytes);

    if (toWrite == 0) {
	*errloc = 0;
	return 0;
    }

    if (info->mode & O_APPEND) {
	info->cursor = info->numBytes;
    }

    if (toWrite > (info->maxWrite - info->cursor)) {
	/* File would grow beyond max size permitted */
	/* Don't do partial writes in error case. Or should we? */
	*errloc = EFBIG;
	return -1;
    }

    if (toWrite > (info->ubufSize - info->cursor)) {
	/* grow the buffer. We have already checked will not exceed maxWrite */
	Tcl_Size needed = info->cursor + toWrite;
	/* Tack on a bit for future growth. */
	if (needed < (info->maxWrite - needed/2)) {
	    needed += needed / 2;
	} else {
	    needed = info->maxWrite;
	}
	unsigned char *newBuf = (unsigned char *)
		Tcl_AttemptRealloc(info->ubufToFree, needed);
	if (newBuf == NULL) {
	    *errloc = ENOMEM;
	    return -1;
	}
	info->ubufToFree = newBuf;
	info->ubuf = info->ubufToFree;
	info->ubufSize = needed;
    }
    nextpos = info->cursor + toWrite;
    memcpy(info->ubuf + info->cursor, buf, toWrite);
    info->cursor = nextpos;
    if (info->cursor > info->numBytes) {
	info->numBytes = info->cursor;
    }
    *errloc = 0;
    return toWrite;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelSeek/ZipChannelWideSeek --
 *
 *	This function is called to position file pointer of channel.
 *
 * Results:
 *	New file position or -1 on error with error number set.
 *
 * Side effects:
 *	File pointer is repositioned according to offset and mode.
 *
 *-------------------------------------------------------------------------
 */

static long long
ZipChannelWideSeek(
    void *instanceData,
    long long offset,
    int mode,
    int *errloc)
{
    ZipChannel *info = (ZipChannel *) instanceData;
    Tcl_Size end;

    if (!ZipChannelWritable(info) && (info->isDirectory < 0)) {
	/*
	 * Special case: when executable combined with ZIP archive file, seek
	 * within front of ZIP, i.e. the executable itself.
	 */
	end = info->zipFilePtr->baseOffset;
    } else if (info->isDirectory) {
	*errloc = EINVAL;
	return -1;
    } else {
	end = info->numBytes;
    }
    switch (mode) {
    case SEEK_CUR:
	offset += info->cursor;
	break;
    case SEEK_END:
	offset += end;
	break;
    case SEEK_SET:
	break;
    default:
	*errloc = EINVAL;
	return -1;
    }
    if (offset < 0 || offset > TCL_SIZE_MAX) {
	*errloc = EINVAL;
	return -1;
    }
    if (ZipChannelWritable(info)) {
	if (offset > info->maxWrite) {
	    *errloc = EINVAL;
	    return -1;
	}
	if (offset > info->numBytes) {
	    info->numBytes = offset;
	}
    } else if (offset > end) {
	*errloc = EINVAL;
	return -1;
    }
    info->cursor = (Tcl_Size) offset;
    return info->cursor;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelWatchChannel --
 *
 *	This function is called for event notifications on channel. Does
 *	nothing.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static void
ZipChannelWatchChannel(
    TCL_UNUSED(void *),
    TCL_UNUSED(int) /*mask*/)
{
    return;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelGetFile --
 *
 *	This function is called to retrieve OS handle for channel.
 *
 * Results:
 *	Always TCL_ERROR since there's never an OS handle for a file within a
 *	ZIP archive.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipChannelGetFile(
    TCL_UNUSED(void *),
    TCL_UNUSED(int) /*direction*/,
    TCL_UNUSED(void **) /*handlePtr*/)
{
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipChannelOpen --
 *
 *	This function opens a Tcl_Channel on a file from a mounted ZIP archive
 *	according to given open mode (already parsed by caller).
 *
 * Results:
 *	Tcl_Channel on success, or NULL on error.
 *
 * Side effects:
 *	Memory is allocated, the file from the ZIP archive is uncompressed.
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Channel
ZipChannelOpen(
    Tcl_Interp *interp,		/* Current interpreter. */
    char *filename,		/* What are we opening. */
    int mode)			/* O_WRONLY O_RDWR O_TRUNC flags */
{
    ZipEntry *z;
    ZipChannel *info;
    int flags = 0;
    char cname[128];

    int wr = (mode & (O_WRONLY | O_RDWR)) != 0;

    /* Check for unsupported modes. */

    if ((ZipFS.wrmax <= 0) && wr) {
	Tcl_SetErrno(EACCES);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "writes not permitted: %s",
		    Tcl_PosixError(interp)));
	}
	return NULL;
    }

    if ((mode & (O_APPEND|O_TRUNC)) && !wr) {
	Tcl_SetErrno(EINVAL);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "Invalid flags 0x%x. O_APPEND and "
		    "O_TRUNC require write access: %s",
		    mode, Tcl_PosixError(interp)));
	}
	return NULL;
    }

    /*
     * Is the file there?
     */

    WriteLock();
    z = ZipFSLookup(filename);
    if (!z) {
	Tcl_SetErrno(wr ? ENOTSUP : ENOENT);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "file \"%s\" not %s: %s",
		    filename, wr ? "created" : "found",
		    Tcl_PosixError(interp)));
	}
	goto error;
    }

    if (z->numBytes < 0 || z->numCompressedBytes < 0 ||
	    z->offset >= z->zipFilePtr->length) {
	/* Normally this should only happen for zip64. */
	ZIPFS_ERROR(interp, "file size error (may be zip64)");
	ZIPFS_ERROR_CODE(interp, "FILE_SIZE");
	goto error;
    }

    /* Do we support opening the file that way? */

    if (wr && z->isDirectory) {
	Tcl_SetErrno(EISDIR);
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "unsupported file type: %s",
		    Tcl_PosixError(interp)));
	}
	goto error;
    }
    if ((z->compressMethod != ZIP_COMPMETH_STORED)
	    && (z->compressMethod != ZIP_COMPMETH_DEFLATED)) {
	ZIPFS_ERROR(interp, "unsupported compression method");
	ZIPFS_ERROR_CODE(interp, "COMP_METHOD");
	goto error;
    }
    if (wr) {
	if ((mode & O_TRUNC) == 0 && !z->data && (z->numBytes > ZipFS.wrmax)) {
	    Tcl_SetErrno(EFBIG);
	    ZIPFS_POSIX_ERROR(interp, "file size exceeds max writable");
	    goto error;
	}
	flags = TCL_WRITABLE;
	if (mode & O_RDWR) {
	    flags |= TCL_READABLE;
	}
    } else {
	/* Read-only */
	flags |= TCL_READABLE;
    }

    if (z->isEncrypted) {
	if (z->numCompressedBytes < ZIP_CRYPT_HDR_LEN) {
	    ZIPFS_ERROR(interp,
			"decryption failed: truncated decryption header");
	    ZIPFS_ERROR_CODE(interp, "DECRYPT");
	    goto error;
	}
	if (z->zipFilePtr->passBuf[0] == 0) {
	    ZIPFS_ERROR(interp, "decryption failed - no password provided");
	    ZIPFS_ERROR_CODE(interp, "DECRYPT");
	    goto error;
	}
    }

    info = AllocateZipChannel(interp);
    if (!info) {
	goto error;
    }
    info->zipFilePtr = z->zipFilePtr;
    info->zipEntryPtr = z;
    if (wr) {
	/* Set up a writable channel. */

	if (InitWritableChannel(interp, info, z, mode) == TCL_ERROR) {
	    Tcl_Free(info);
	    goto error;
	}
    } else if (z->data) {
	/* Set up a readable channel for direct data. */

	info->numBytes = z->numBytes;
	info->ubuf = z->data;
	info->ubufToFree = NULL; /* Not dynamically allocated */
	info->ubufSize = 0;
    } else {
	/*
	 * Set up a readable channel.
	 */

	if (InitReadableChannel(interp, info, z) == TCL_ERROR) {
	    Tcl_Free(info);
	    goto error;
	}
    }

    if (z->crc32) {
	if (!(z->flags & ZE_F_CRC_COMPARED)) {
	    int crc = crc32(0, NULL, info->numBytes);
	    crc = crc32(crc, info->ubuf, info->numBytes);
	    z->flags |= ZE_F_CRC_COMPARED;
	    if (crc == z->crc32) {
		z->flags |= ZE_F_CRC_CORRECT;
	    }
	}
	if (!(z->flags & ZE_F_CRC_CORRECT)) {
	    ZIPFS_ERROR(interp, "invalid CRC");
	    ZIPFS_ERROR_CODE(interp, "CRC_FAILED");
	    if (info->ubufToFree) {
		Tcl_Free(info->ubufToFree);
		info->ubufSize = 0;
	    }
	    Tcl_Free(info);
	    goto error;
	}
    }

    /*
     * Wrap the ZipChannel into a Tcl_Channel.
     */

    snprintf(cname, sizeof(cname), "zipfs_%" TCL_Z_MODIFIER "x_%d", z->offset,
	    ZipFS.idCount++);
    z->zipFilePtr->numOpen++;
    Unlock();
    return Tcl_CreateChannel(&zipChannelType, cname, info, flags);

  error:
    Unlock();
    return NULL;
}

/*
 *-------------------------------------------------------------------------
 *
 * InitWritableChannel --
 *
 *	Assistant for ZipChannelOpen() that sets up a writable channel. It's
 *	up to the caller to actually register the channel.
 *
 * Returns:
 *	Tcl result code.
 *
 * Side effects:
 *	Allocates memory for the implementation of the channel. Writes to the
 *	interpreter's result on error.
 *
 *-------------------------------------------------------------------------
 */

static int
InitWritableChannel(
    Tcl_Interp *interp,		/* Current interpreter, or NULL (when errors
				 * will be silent). */
    ZipChannel *info,		/* The channel to set up. */
    ZipEntry *z,		/* The zipped file that the channel will write
				 * to. */
    int mode)			/* O_APPEND, O_TRUNC */
{
    int i, ch;
    unsigned char *cbuf = NULL;

    /*
     * Set up a writable channel.
     */

    info->mode = mode;
    info->maxWrite = ZipFS.wrmax;

    info->ubufSize = z->numBytes ? z->numBytes : 1;
    info->ubufToFree = (unsigned char *)Tcl_AttemptAlloc(info->ubufSize);
    info->ubuf = info->ubufToFree;
    if (info->ubufToFree == NULL) {
	goto memoryError;
    }

    if (z->isEncrypted) {
	assert(z->numCompressedBytes >= ZIP_CRYPT_HDR_LEN); /* caller should have checked*/
	if (DecodeCryptHeader(interp, z, info->keys,
		z->zipFilePtr->data + z->offset) != TCL_OK) {
	    goto error_cleanup;
	}
    }

    if (mode & O_TRUNC) {
	/*
	 * Truncate; nothing there.
	 */

	info->numBytes = 0;
	z->crc32 = 0; /* Truncated, CRC no longer applicable */
    } else if (z->data) {
	/*
	 * Already got uncompressed data.
	 */
	assert(info->ubufSize >= z->numBytes);
	memcpy(info->ubuf, z->data, z->numBytes);
	info->numBytes = z->numBytes;
    } else {
	/*
	 * Need to uncompress the existing data.
	 */

	unsigned char *zbuf = z->zipFilePtr->data + z->offset;

	if (z->isEncrypted) {
	    zbuf += ZIP_CRYPT_HDR_LEN;
	}

	if (z->compressMethod == ZIP_COMPMETH_DEFLATED) {
	    z_stream stream;
	    int err;

	    memset(&stream, 0, sizeof(z_stream));
	    stream.zalloc = Z_NULL;
	    stream.zfree = Z_NULL;
	    stream.opaque = Z_NULL;
	    stream.avail_in = z->numCompressedBytes;
	    if (z->isEncrypted) {
		unsigned int j;

		/* Min length ZIP_CRYPT_HDR_LEN for keys should already been checked. */
		assert(stream.avail_in >= ZIP_CRYPT_HDR_LEN);

		stream.avail_in -= ZIP_CRYPT_HDR_LEN;
		cbuf = (unsigned char *) Tcl_AttemptAlloc(stream.avail_in ? stream.avail_in : 1);
		if (!cbuf) {
		    goto memoryError;
		}
		for (j = 0; j < stream.avail_in; j++) {
		    ch = zbuf[j];
		    cbuf[j] = zdecode(info->keys, crc32tab, ch);
		}
		stream.next_in = cbuf;
	    } else {
		stream.next_in = zbuf;
	    }
	    stream.next_out = info->ubuf;
	    stream.avail_out = info->ubufSize;
	    if (inflateInit2(&stream, -15) != Z_OK) {
		goto corruptionError;
	    }
	    err = inflate(&stream, Z_SYNC_FLUSH);
	    inflateEnd(&stream);
	    if ((err != Z_STREAM_END) &&
		    ((err != Z_OK) || (stream.avail_in != 0))) {
		goto corruptionError;
	    }
	    /* Even if decompression succeeded, counts should be as expected */
	    if ((int) stream.total_out != z->numBytes) {
		goto corruptionError;
	    }
	    info->numBytes = z->numBytes;
	    if (cbuf) {
		Tcl_Free(cbuf);
	    }
	} else if (z->isEncrypted) {
	    /*
	     * Need to decrypt some otherwise-simple stored data.
	     */
	    if (z->numCompressedBytes <= ZIP_CRYPT_HDR_LEN ||
		    (z->numCompressedBytes - ZIP_CRYPT_HDR_LEN) != z->numBytes) {
		goto corruptionError;
	    }
	    int len = z->numCompressedBytes - ZIP_CRYPT_HDR_LEN;
	    assert(len <= info->ubufSize);
	    for (i = 0; i < len; i++) {
		ch = zbuf[i];
		info->ubuf[i] = zdecode(info->keys, crc32tab, ch);
	    }
	    info->numBytes = len;
	} else {
	    /*
	     * Simple stored data. Copy into our working buffer.
	     */
	    assert(info->ubufSize >= z->numBytes);
	    memcpy(info->ubuf, zbuf, z->numBytes);
	    info->numBytes = z->numBytes;
	}
	memset(info->keys, 0, sizeof(info->keys));
    }
    if (mode & O_APPEND) {
	info->cursor = info->numBytes;
    }

    return TCL_OK;

  memoryError:
    ZIPFS_MEM_ERROR(interp);
    goto error_cleanup;

  corruptionError:
    if (cbuf) {
	memset(info->keys, 0, sizeof(info->keys));
	Tcl_Free(cbuf);
    }
    ZIPFS_ERROR(interp, "decompression error");
    ZIPFS_ERROR_CODE(interp, "CORRUPT");

  error_cleanup:
    if (info->ubufToFree) {
	Tcl_Free(info->ubufToFree);
	info->ubufToFree = NULL;
	info->ubuf = NULL;
	info->ubufSize = 0;
    }
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * InitReadableChannel --
 *
 *	Assistant for ZipChannelOpen() that sets up a readable channel. It's
 *	up to the caller to actually register the channel. Caller should have
 *	validated the passed ZipEntry (byte counts in particular)
 *
 * Returns:
 *	Tcl result code.
 *
 * Side effects:
 *	Allocates memory for the implementation of the channel. Writes to the
 *	interpreter's result on error.
 *
 *-------------------------------------------------------------------------
 */

static int
InitReadableChannel(
    Tcl_Interp *interp,		/* Current interpreter, or NULL (when errors
				 * will be silent). */
    ZipChannel *info,		/* The channel to set up. */
    ZipEntry *z)		/* The zipped file that the channel will read
				 * from. */
{
    unsigned char *ubuf = NULL;
    int ch;

    info->iscompr = (z->compressMethod == ZIP_COMPMETH_DEFLATED);
    info->ubuf = z->zipFilePtr->data + z->offset;
    info->ubufToFree = NULL; /* ubuf memory not allocated */
    info->ubufSize = 0;
    info->isDirectory = z->isDirectory;
    info->isEncrypted = z->isEncrypted;
    info->mode = O_RDONLY;

    /* Caller must validate - bug [6ed3447a7e] */
    assert(z->numBytes >= 0 && z->numCompressedBytes >= 0);
    info->numBytes = z->numBytes;

    if (info->isEncrypted) {
	assert(z->numCompressedBytes >= ZIP_CRYPT_HDR_LEN); /* caller should have checked*/
	if (DecodeCryptHeader(interp, z, info->keys, info->ubuf) != TCL_OK) {
	    goto error_cleanup;
	}
	info->ubuf += ZIP_CRYPT_HDR_LEN;
    }

    if (info->iscompr) {
	z_stream stream;
	int err;
	unsigned int j;

	/*
	 * Data to decode is compressed, and possibly encrpyted too. If
	 * encrypted, local variable ubuf is used to hold the decrypted but
	 * still compressed data.
	 */

	memset(&stream, 0, sizeof(z_stream));
	stream.zalloc = Z_NULL;
	stream.zfree = Z_NULL;
	stream.opaque = Z_NULL;
	stream.avail_in = z->numCompressedBytes;
	if (info->isEncrypted) {
	    assert(stream.avail_in >= ZIP_CRYPT_HDR_LEN);
	    stream.avail_in -= ZIP_CRYPT_HDR_LEN;
	    ubuf = (unsigned char *) Tcl_AttemptAlloc(stream.avail_in ? stream.avail_in : 1);
	    if (!ubuf) {
		goto memoryError;
	    }

	    for (j = 0; j < stream.avail_in; j++) {
		ch = info->ubuf[j];
		ubuf[j] = zdecode(info->keys, crc32tab, ch);
	    }
	    stream.next_in = ubuf;
	} else {
	    stream.next_in = info->ubuf;
	}

	info->ubufSize = info->numBytes ? info->numBytes : 1;
	info->ubufToFree = (unsigned char *)Tcl_AttemptAlloc(info->ubufSize);
	info->ubuf = info->ubufToFree;
	stream.next_out = info->ubuf;
	if (!info->ubuf) {
	    goto memoryError;
	}
	stream.avail_out = info->numBytes;
	if (inflateInit2(&stream, -15) != Z_OK) {
	    goto corruptionError;
	}
	err = inflate(&stream, Z_SYNC_FLUSH);
	inflateEnd(&stream);

	/*
	 * Decompression was successful if we're either in the END state, or
	 * in the OK state with no buffered bytes.
	 */

	if ((err != Z_STREAM_END)
		&& ((err != Z_OK) || (stream.avail_in != 0))) {
	    goto corruptionError;
	}
	/* Even if decompression succeeded, counts should be as expected */
	if ((int) stream.total_out != z->numBytes) {
	    goto corruptionError;
	}

	if (ubuf) {
	    info->isEncrypted = 0;
	    memset(info->keys, 0, sizeof(info->keys));
	    Tcl_Free(ubuf);
	}
    } else if (info->isEncrypted) {
	unsigned int j, len;

	/*
	 * Decode encrypted but uncompressed file, since we support Tcl_Seek()
	 * on it, and it can be randomly accessed later.
	 */
	if (z->numCompressedBytes <= ZIP_CRYPT_HDR_LEN ||
		(z->numCompressedBytes - ZIP_CRYPT_HDR_LEN) != z->numBytes) {
	    goto corruptionError;
	}
	len = z->numCompressedBytes - ZIP_CRYPT_HDR_LEN;
	ubuf = (unsigned char *) Tcl_AttemptAlloc(len);
	if (ubuf == NULL) {
	    goto memoryError;
	}
	for (j = 0; j < len; j++) {
	    ch = info->ubuf[j];
	    ubuf[j] = zdecode(info->keys, crc32tab, ch);
	}
	info->ubufSize = len;
	info->ubufToFree = ubuf;
	info->ubuf = info->ubufToFree;
	ubuf = NULL; /* So it does not inadvertently get free on future changes */
	info->isEncrypted = 0;
    }
    return TCL_OK;

  corruptionError:
    ZIPFS_ERROR(interp, "decompression error");
    ZIPFS_ERROR_CODE(interp, "CORRUPT");
    goto error_cleanup;

  memoryError:
    ZIPFS_MEM_ERROR(interp);

  error_cleanup:
    if (ubuf) {
	memset(info->keys, 0, sizeof(info->keys));
	Tcl_Free(ubuf);
    }
    if (info->ubufToFree) {
	Tcl_Free(info->ubufToFree);
	info->ubufToFree = NULL;
	info->ubuf = NULL;
	info->ubufSize = 0;
    }

    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipEntryStat --
 *
 *	This function implements the ZIP filesystem specific version of the
 *	library version of stat.
 *
 * Results:
 *	See stat documentation.
 *
 * Side effects:
 *	See stat documentation.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipEntryStat(
    char *path,
    Tcl_StatBuf *buf)
{
    ZipEntry *z;
    int ret;

    ReadLock();
    z = ZipFSLookup(path);
    if (z) {
	memset(buf, 0, sizeof(Tcl_StatBuf));
	if (z->isDirectory) {
	    buf->st_mode = S_IFDIR | 0555;
	} else {
	    buf->st_mode = S_IFREG | 0555;
	}
	buf->st_size = z->numBytes;
	buf->st_mtime = z->timestamp;
	buf->st_ctime = z->timestamp;
	buf->st_atime = z->timestamp;
	ret = 0;
    } else if (ContainsMountPoint(path, -1)) {
	/* An intermediate dir under which a mount exists */
	memset(buf, 0, sizeof(Tcl_StatBuf));
	Tcl_Time t;
	Tcl_GetTime(&t);
	buf->st_atime = buf->st_mtime = buf->st_ctime = t.sec;
	buf->st_mode = S_IFDIR | 0555;
	ret = 0;
    } else {
	Tcl_SetErrno(ENOENT);
	ret = -1;
    }
    Unlock();
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipEntryAccess --
 *
 *	This function implements the ZIP filesystem specific version of the
 *	library version of access.
 *
 * Results:
 *	See access documentation.
 *
 * Side effects:
 *	See access documentation.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipEntryAccess(
    char *path,
    int mode)
{
    if (mode & X_OK) {
	return -1;
    }

    ReadLock();
    int access;
    ZipEntry *z = ZipFSLookup(path);
    if (z) {
	/* Currently existing files read/write but dirs are read-only */
	access = (z->isDirectory && (mode & W_OK)) ? -1 : 0;
    } else {
	if (mode & W_OK) {
	    access = -1;
	} else {
	    /*
	     * Even if entry does not exist, could be intermediate dir
	     * containing a mount point
	     */
	    access = ContainsMountPoint(path, -1) ? 0 : -1;
	}
    }
    Unlock();
    return access;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSOpenFileChannelProc --
 *
 *	Open a channel to a file in a mounted ZIP archive. Delegates to
 *	ZipChannelOpen().
 *
 * Results:
 *	Tcl_Channel on success, or NULL on error.
 *
 * Side effects:
 *	Allocates memory.
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Channel
ZipFSOpenFileChannelProc(
    Tcl_Interp *interp,		/* Current interpreter. */
    Tcl_Obj *pathPtr,
    int mode,
    TCL_UNUSED(int) /* permissions */)
{
    pathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
    if (!pathPtr) {
	return NULL;
    }

    return ZipChannelOpen(interp, Tcl_GetString(pathPtr), mode);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSStatProc --
 *
 *	This function implements the ZIP filesystem specific version of the
 *	library version of stat.
 *
 * Results:
 *	See stat documentation.
 *
 * Side effects:
 *	See stat documentation.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSStatProc(
    Tcl_Obj *pathPtr,
    Tcl_StatBuf *buf)
{
    pathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
    if (!pathPtr) {
	return -1;
    }
    return ZipEntryStat(TclGetString(pathPtr), buf);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSAccessProc --
 *
 *	This function implements the ZIP filesystem specific version of the
 *	library version of access.
 *
 * Results:
 *	See access documentation.
 *
 * Side effects:
 *	See access documentation.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSAccessProc(
    Tcl_Obj *pathPtr,
    int mode)
{
    pathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
    if (!pathPtr) {
	return -1;
    }
    return ZipEntryAccess(TclGetString(pathPtr), mode);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFilesystemSeparatorProc --
 *
 *	This function returns the separator to be used for a given path. The
 *	object returned should have a refCount of zero
 *
 * Results:
 *	A Tcl object, with a refCount of zero. If the caller needs to retain a
 *	reference to the object, it should call Tcl_IncrRefCount, and should
 *	otherwise free the object.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Obj *
ZipFSFilesystemSeparatorProc(
    TCL_UNUSED(Tcl_Obj *) /*pathPtr*/)
{
    return Tcl_NewStringObj("/", -1);
}

/*
 *-------------------------------------------------------------------------
 *
 * AppendWithPrefix --
 *
 *	Worker for ZipFSMatchInDirectoryProc() that is a wrapper around
 *	Tcl_ListObjAppendElement() which knows about handling prefixes.
 *
 *-------------------------------------------------------------------------
 */

static inline void
AppendWithPrefix(
    Tcl_Obj *result,		/* Where to append a list element to. */
    Tcl_DString *prefix,	/* The prefix to add to the element, or NULL
				 * for don't do that. */
    const char *name,		/* The name to append. */
    size_t nameLen)		/* The length of the name. May be TCL_INDEX_NONE for
				 * append-up-to-NUL-byte. */
{
    if (prefix) {
	size_t prefixLength = Tcl_DStringLength(prefix);

	Tcl_DStringAppend(prefix, name, nameLen);
	Tcl_ListObjAppendElement(NULL, result, Tcl_NewStringObj(
		Tcl_DStringValue(prefix), Tcl_DStringLength(prefix)));
	Tcl_DStringSetLength(prefix, prefixLength);
    } else {
	Tcl_ListObjAppendElement(NULL, result, Tcl_NewStringObj(name, nameLen));
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMatchInDirectoryProc --
 *
 *	This routine is used by the globbing code to search a directory for
 *	all files which match a given pattern.
 *
 * Results:
 *	The return value is a standard Tcl result indicating whether an error
 *	occurred in globbing. Errors are left in interp, good results are
 *	lappend'ed to result (which must be a valid object).
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSMatchInDirectoryProc(
    Tcl_Interp *interp,
    Tcl_Obj *result,		/* Where to append matched items to. */
    Tcl_Obj *pathPtr,		/* Where we are looking. */
    const char *pattern,	/* What names we are looking for. */
    Tcl_GlobTypeData *types)	/* What types we are looking for. */
{
    Tcl_Obj *normPathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
    int scnt, l;
    Tcl_Size prefixLen, len, strip = 0;
    char *pat, *prefix, *path;
    Tcl_DString dsPref, *prefixBuf = NULL;
    int foundInHash, notDuplicate;
    ZipEntry *z;
    int wanted; /* TCL_GLOB_TYPE* */

    if (!normPathPtr) {
	return -1;
    }
    if (types) {
	wanted = types->type;
	if ((wanted & TCL_GLOB_TYPE_MOUNT) && (wanted != TCL_GLOB_TYPE_MOUNT)) {
	    if (interp) {
		ZIPFS_ERROR(interp,
			"Internal error: TCL_GLOB_TYPE_MOUNT should not "
			"be set in conjunction with other glob types.");
	    }
	    return TCL_ERROR;
	}
	if ((wanted & (TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE |
		TCL_GLOB_TYPE_MOUNT)) == 0) {
	    /* Not looking for files,dirs,mounts. zipfs cannot have others */
	    return TCL_OK;
	}
	wanted &=
	    (TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE | TCL_GLOB_TYPE_MOUNT);
    } else {
	wanted = TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE;
    }

    /*
     * The prefix that gets prepended to results.
     */

    prefix = TclGetStringFromObj(pathPtr, &prefixLen);

    /*
     * The (normalized) path we're searching.
     */

    path = TclGetStringFromObj(normPathPtr, &len);

    Tcl_DStringInit(&dsPref);
    if (strcmp(prefix, path) == 0) {
	prefixBuf = NULL;
    } else {
	/*
	 * We need to strip the normalized prefix of the filenames and replace
	 * it with the official prefix that we were expecting to get.
	 */

	strip = len + 1;
	Tcl_DStringAppend(&dsPref, prefix, prefixLen);
	Tcl_DStringAppend(&dsPref, "/", 1);
	prefix = Tcl_DStringValue(&dsPref);
	prefixBuf = &dsPref;
    }

    ReadLock();

    /*
     * Are we globbing the mount points?
     */

    if (wanted & TCL_GLOB_TYPE_MOUNT) {
	ZipFSMatchMountPoints(result, normPathPtr, pattern, prefixBuf);
	goto end;
    }

    /* Should not reach here unless at least one of DIR or FILE is set */
    assert(wanted & (TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE));

    /* Does the path exist in the hash table? */
    z = ZipFSLookup(path);
    if (z) {
	/*
	 * Can we skip the complexity of actual globbing? Without a pattern,
	 * yes; it's a directory existence test.
	 */
	if (!pattern || (pattern[0] == '\0')) {
	    /* TODO - can't seem to get to this code from script for tests. */
	    /* Follow logic of what tclUnixFile.c does */
	    if ((wanted == (TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE)) ||
		    (wanted == TCL_GLOB_TYPE_DIR && z->isDirectory) ||
		    (wanted == TCL_GLOB_TYPE_FILE && !z->isDirectory)) {
		Tcl_ListObjAppendElement(NULL, result, pathPtr);
	    }
	    goto end;
	}
    } else {
	/* Not in the hash table but could be an intermediate dir in a mount */
	if (!pattern || (pattern[0] == '\0')) {
	    /* TODO - can't seem to get to this code from script for tests. */
	    if ((wanted & TCL_GLOB_TYPE_DIR) && ContainsMountPoint(path, len)) {
		Tcl_ListObjAppendElement(NULL, result, pathPtr);
	    }
	    goto end;
	}
    }

    foundInHash = (z != NULL);

    /*
     * We've got to work for our supper and do the actual globbing. And all
     * we've got really is an undifferentiated pile of all the filenames we've
     * got from all our ZIP mounts.
     */

    l = strlen(pattern);
    pat = (char *) Tcl_Alloc(len + l + 2);
    memcpy(pat, path, len);
    while ((len > 1) && (pat[len - 1] == '/')) {
	--len;
    }
    if ((len > 1) || (pat[0] != '/')) {
	pat[len] = '/';
	++len;
    }
    memcpy(pat + len, pattern, l + 1);
    scnt = CountSlashes(pat);

    Tcl_HashTable duplicates;
    notDuplicate = 0;
    Tcl_InitHashTable(&duplicates, TCL_STRING_KEYS);

    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    if (foundInHash) {
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.fileHash, &search); hPtr;
		hPtr = Tcl_NextHashEntry(&search)) {
	    z = (ZipEntry *)Tcl_GetHashValue(hPtr);

	    if ((wanted == (TCL_GLOB_TYPE_DIR | TCL_GLOB_TYPE_FILE)) ||
		    (wanted == TCL_GLOB_TYPE_DIR && z->isDirectory) ||
		    (wanted == TCL_GLOB_TYPE_FILE && !z->isDirectory)) {
		if ((z->depth == scnt) &&
			((z->flags & ZE_F_VOLUME) == 0) /* Bug 14db54d81e */
			&& Tcl_StringCaseMatch(z->name, pat, 0)) {
		    Tcl_CreateHashEntry(&duplicates, z->name + strip,
			    &notDuplicate);
		    assert(notDuplicate);
		    AppendWithPrefix(result, prefixBuf, z->name + strip, -1);
		}
	    }
	}
    }
    if (wanted & TCL_GLOB_TYPE_DIR) {
	/*
	 * Also check paths that are ancestors of a mount. e.g. glob
	 * //zipfs:/a/? with mount at //zipfs:/a/b/c. Also have to be
	 * careful about duplicates, such as when another mount is
	 * //zipfs:/a/b/d
	 */
	Tcl_DString ds;
	Tcl_DStringInit(&ds);
	for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &search); hPtr;
		hPtr = Tcl_NextHashEntry(&search)) {
	    ZipFile *zf = (ZipFile *)Tcl_GetHashValue(hPtr);
	    if (Tcl_StringCaseMatch(zf->mountPoint, pat, 0)) {
		const char *tail = zf->mountPoint + len;
		if (*tail == '\0') {
		    continue;
		}
		const char *end = strchr(tail, '/');
		Tcl_DStringAppend(&ds, zf->mountPoint + strip,
			end ? (Tcl_Size)(end - zf->mountPoint) : -1);
		const char *matchedPath = Tcl_DStringValue(&ds);
		(void)Tcl_CreateHashEntry(
		    &duplicates, matchedPath, &notDuplicate);
		if (notDuplicate) {
		    AppendWithPrefix(
			result, prefixBuf, matchedPath, Tcl_DStringLength(&ds));
		}
		Tcl_DStringFree(&ds);
	    }
	}
    }
    Tcl_DeleteHashTable(&duplicates);
    Tcl_Free(pat);

  end:
    Unlock();
    Tcl_DStringFree(&dsPref);
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSMatchMountPoints --
 *
 *	This routine is a worker for ZipFSMatchInDirectoryProc, used by the
 *	globbing code to search for all mount points files which match a given
 *	pattern.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Adds the matching mounts to the list in result, uses prefix as working
 *	space if it is non-NULL.
 *
 *-------------------------------------------------------------------------
 */

static void
ZipFSMatchMountPoints(
    Tcl_Obj *result,		/* The list of matches being built. */
    Tcl_Obj *normPathPtr,	/* Where we're looking from. */
    const char *pattern,	/* What we're looking for. NULL for a full
				 * list. */
    Tcl_DString *prefix)	/* Workspace filled with a prefix for all the
				 * filenames, or NULL if no prefix is to be
				 * used. */
{
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    int l;
    Tcl_Size normLength;
    const char *path = TclGetStringFromObj(normPathPtr, &normLength);
    Tcl_Size len = normLength;

    if (len < 1) {
	/*
	 * Shouldn't happen. But "shouldn't"...
	 */

	return;
    }
    l = CountSlashes(path);
    if (path[len - 1] == '/') {
	len--;
    } else {
	l++;
    }
    if (!pattern || (pattern[0] == '\0')) {
	pattern = "*";
    }

    for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &search); hPtr;
	    hPtr = Tcl_NextHashEntry(&search)) {
	ZipFile *zf = (ZipFile *) Tcl_GetHashValue(hPtr);

	if (zf->mountPointLen == 0) {
	    ZipEntry *z;

	    /*
	     * Enumerate the contents of the ZIP; it's mounted on the root.
	     * TODO - a holdover from androwish? Tcl does not allow mounting
	     * outside of the //zipfs:/ area.
	     */

	    for (z = zf->topEnts; z; z = z->tnext) {
		Tcl_Size lenz = strlen(z->name);

		if ((lenz > len + 1) && (strncmp(z->name, path, len) == 0)
			&& (z->name[len] == '/')
			&& ((int) CountSlashes(z->name) == l)
			&& Tcl_StringCaseMatch(z->name + len + 1, pattern, 0)) {
		    AppendWithPrefix(result, prefix, z->name, lenz);
		}
	    }
	} else if ((zf->mountPointLen > len + 1)
		&& (strncmp(zf->mountPoint, path, len) == 0)
		&& (zf->mountPoint[len] == '/')
		&& ((int) CountSlashes(zf->mountPoint) == l)
		&& Tcl_StringCaseMatch(zf->mountPoint + len + 1,
			pattern, 0)) {
	    /*
	     * Standard mount; append if it matches.
	     */

	    AppendWithPrefix(result, prefix, zf->mountPoint, zf->mountPointLen);
	}
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSPathInFilesystemProc --
 *
 *	This function determines if the given path object is in the ZIP
 *	filesystem.
 *
 * Results:
 *	TCL_OK when the path object is in the ZIP filesystem, -1 otherwise.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSPathInFilesystemProc(
    Tcl_Obj *pathPtr,
    TCL_UNUSED(void **))
{
    Tcl_Size len;
    char *path;
    int ret, decrRef = 0;

    if (TclFSCwdIsNative() || Tcl_FSGetPathType(pathPtr) == TCL_PATH_ABSOLUTE) {
	/*
	 * The cwd is native (or path is absolute), use the translated path
	 * without worrying about normalization (this will also usually be
	 * shorter so the utf-to-external conversion will be somewhat faster).
	 */

	pathPtr = Tcl_FSGetTranslatedPath(NULL, pathPtr);
	if (pathPtr == NULL) {
	    return -1;
	}
	decrRef = 1; /* Tcl_FSGetTranslatedPath increases refCount */
    } else {
	/*
	 * Make sure the normalized path is set.
	 */

	pathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
	if (!pathPtr) {
	    return -1;
	}
	/* Tcl_FSGetNormalizedPath doesn't increase refCount */
    }
    path = TclGetStringFromObj(pathPtr, &len);

    /*
     * Claim any path under ZIPFS_VOLUME as ours. This is both a necessary
     * and sufficient condition as zipfs mounts at arbitrary paths are
     * not permitted (unlike Androwish).
     */
    ret = (
	(len < ZIPFS_VOLUME_LEN) ||
	strncmp(path, ZIPFS_VOLUME, ZIPFS_VOLUME_LEN)
    ) ? -1 : TCL_OK;

    if (decrRef) {
	Tcl_DecrRefCount(pathPtr);
    }
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSListVolumesProc --
 *
 *	Lists the currently mounted ZIP filesystem volumes.
 *
 * Results:
 *	The list of volumes.
 *
 * Side effects:
 *	None
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Obj *
ZipFSListVolumesProc(void)
{
    return Tcl_NewStringObj(ZIPFS_VOLUME, -1);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFileAttrStringsProc --
 *
 *	This function implements the ZIP filesystem dependent 'file
 *	attributes' subcommand, for listing the set of possible attribute
 *	strings.
 *
 * Results:
 *	An array of strings
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

enum ZipFileAttrs {
    ZIP_ATTR_UNCOMPSIZE,
    ZIP_ATTR_COMPSIZE,
    ZIP_ATTR_OFFSET,
    ZIP_ATTR_MOUNT,
    ZIP_ATTR_ARCHIVE,
    ZIP_ATTR_PERMISSIONS,
    ZIP_ATTR_CRC
};

static const char *const *
ZipFSFileAttrStringsProc(
    TCL_UNUSED(Tcl_Obj *) /*pathPtr*/,
    TCL_UNUSED(Tcl_Obj **) /*objPtrRef*/)
{
    /*
     * Must match up with ZipFileAttrs enum above.
     */

    static const char *const attrs[] = {
	"-uncompsize",
	"-compsize",
	"-offset",
	"-mount",
	"-archive",
	"-permissions",
	"-crc",
	NULL,
    };

    return attrs;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFileAttrsGetProc --
 *
 *	This function implements the ZIP filesystem specific 'file attributes'
 *	subcommand, for 'get' operations.
 *
 * Results:
 *	Standard Tcl return code. The object placed in objPtrRef (if TCL_OK
 *	was returned) is likely to have a refCount of zero. Either way we must
 *	either store it somewhere (e.g. the Tcl result), or Incr/Decr its
 *	refCount to ensure it is properly freed.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSFileAttrsGetProc(
    Tcl_Interp *interp,		/* Current interpreter. */
    int index,
    Tcl_Obj *pathPtr,
    Tcl_Obj **objPtrRef)
{
    Tcl_Size len;
    int ret = TCL_OK;
    char *path;
    ZipEntry *z;

    pathPtr = Tcl_FSGetNormalizedPath(NULL, pathPtr);
    if (!pathPtr) {
	return -1;
    }
    path = TclGetStringFromObj(pathPtr, &len);
    ReadLock();
    z = ZipFSLookup(path);
    if (!z && !ContainsMountPoint(path, -1)) {
	Tcl_SetErrno(ENOENT);
	ZIPFS_POSIX_ERROR(interp, "file not found");
	ret = TCL_ERROR;
	goto done;
    }
    /* z == NULL for intermediate directories that are ancestors of mounts */
    switch (index) {
    case ZIP_ATTR_UNCOMPSIZE:
	TclNewIntObj(*objPtrRef, z ? z->numBytes : 0);
	break;
    case ZIP_ATTR_COMPSIZE:
	TclNewIntObj(*objPtrRef, z ? z->numCompressedBytes : 0);
	break;
    case ZIP_ATTR_OFFSET:
	TclNewIntObj(*objPtrRef, z ? z->offset : 0);
	break;
    case ZIP_ATTR_MOUNT:
	if (z) {
	    *objPtrRef = Tcl_NewStringObj(z->zipFilePtr->mountPoint,
		    z->zipFilePtr->mountPointLen);
	} else {
	    *objPtrRef = Tcl_NewStringObj("", 0);
	}
	break;
    case ZIP_ATTR_ARCHIVE:
	*objPtrRef = Tcl_NewStringObj(z ? z->zipFilePtr->name : "", -1);
	break;
    case ZIP_ATTR_PERMISSIONS:
	*objPtrRef = Tcl_NewStringObj("0o555", -1);
	break;
    case ZIP_ATTR_CRC:
	TclNewIntObj(*objPtrRef, z ? z->crc32 : 0);
	break;
    default:
	ZIPFS_ERROR(interp, "unknown attribute");
	ZIPFS_ERROR_CODE(interp, "FILE_ATTR");
	ret = TCL_ERROR;
    }

  done:
    Unlock();
    return ret;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFileAttrsSetProc --
 *
 *	This function implements the ZIP filesystem specific 'file attributes'
 *	subcommand, for 'set' operations.
 *
 * Results:
 *	Standard Tcl return code.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSFileAttrsSetProc(
    Tcl_Interp *interp,		/* Current interpreter. */
    TCL_UNUSED(int) /*index*/,
    TCL_UNUSED(Tcl_Obj *) /*pathPtr*/,
    TCL_UNUSED(Tcl_Obj *) /*objPtr*/)
{
    ZIPFS_ERROR(interp, "unsupported operation");
    ZIPFS_ERROR_CODE(interp, "UNSUPPORTED_OP");
    return TCL_ERROR;
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSFilesystemPathTypeProc --
 *
 * Results:
 *
 * Side effects:
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Obj *
ZipFSFilesystemPathTypeProc(
    TCL_UNUSED(Tcl_Obj *) /*pathPtr*/)
{
    return Tcl_NewStringObj("zip", -1);
}

/*
 *-------------------------------------------------------------------------
 *
 * ZipFSLoadFile --
 *
 *	This functions deals with loading native object code. If the given
 *	path object refers to a file within the ZIP filesystem, an approriate
 *	error code is returned to delegate loading to the caller (by copying
 *	the file to temp store and loading from there). As fallback when the
 *	file refers to the ZIP file system but is not present, it is looked up
 *	relative to the executable and loaded from there when available.
 *
 * Results:
 *	TCL_OK on success, TCL_ERROR otherwise with error message left.
 *
 * Side effects:
 *	Loads native code into the process address space.
 *
 *-------------------------------------------------------------------------
 */

static int
ZipFSLoadFile(
    Tcl_Interp *interp,		/* Current interpreter. */
    Tcl_Obj *path,
    Tcl_LoadHandle *loadHandle,
    Tcl_FSUnloadFileProc **unloadProcPtr,
    int flags)
{
    Tcl_FSLoadFileProc2 *loadFileProc;
#ifdef ANDROID
    /*
     * Force loadFileProc to native implementation since the package manager
     * already extracted the shared libraries from the APK at install time.
     */

    loadFileProc = (Tcl_FSLoadFileProc2 *) tclNativeFilesystem.loadFileProc;
    if (loadFileProc) {
	return loadFileProc(interp, path, loadHandle, unloadProcPtr, flags);
    }
    Tcl_SetErrno(ENOENT);
    ZIPFS_ERROR(interp, Tcl_PosixError(interp));
    return TCL_ERROR;
#else /* !ANDROID */
    Tcl_Obj *altPath = NULL;
    int ret = TCL_ERROR;
    Tcl_Obj *objs[2] = { NULL, NULL };

    if (Tcl_FSAccess(path, R_OK) == 0) {
	/*
	 * EXDEV should trigger loading by copying to temp store.
	 */

	Tcl_SetErrno(EXDEV);
	ZIPFS_ERROR(interp, Tcl_PosixError(interp));
	return ret;
    }

    objs[1] = TclPathPart(interp, path, TCL_PATH_DIRNAME);
    if (objs[1] && (ZipFSAccessProc(objs[1], R_OK) == 0)) {
	const char *execName = Tcl_GetNameOfExecutable();

	/*
	 * Shared object is not in ZIP but its path prefix is, thus try to
	 * load from directory where the executable came from.
	 */

	TclDecrRefCount(objs[1]);
	objs[1] = TclPathPart(interp, path, TCL_PATH_TAIL);

	/*
	 * Get directory name of executable manually to deal with cases where
	 * [file dirname [info nameofexecutable]] is equal to [info
	 * nameofexecutable] due to VFS effects.
	 */

	if (execName) {
	    const char *p = strrchr(execName, '/');

	    if (p && p > execName + 1) {
		--p;
		objs[0] = Tcl_NewStringObj(execName, p - execName);
	    }
	}
	if (!objs[0]) {
	    objs[0] = TclPathPart(interp, TclGetObjNameOfExecutable(),
		    TCL_PATH_DIRNAME);
	}
	if (objs[0]) {
	    altPath = TclJoinPath(2, objs, 0);
	    if (altPath) {
		Tcl_IncrRefCount(altPath);
		if (Tcl_FSAccess(altPath, R_OK) == 0) {
		    path = altPath;
		}
	    }
	}
    }
    if (objs[0]) {
	Tcl_DecrRefCount(objs[0]);
    }
    if (objs[1]) {
	Tcl_DecrRefCount(objs[1]);
    }

    loadFileProc = (Tcl_FSLoadFileProc2 *) (void *)
	    tclNativeFilesystem.loadFileProc;
    if (loadFileProc) {
	ret = loadFileProc(interp, path, loadHandle, unloadProcPtr, flags);
    } else {
	Tcl_SetErrno(ENOENT);
	ZIPFS_ERROR(interp, Tcl_PosixError(interp));
    }
    if (altPath) {
	Tcl_DecrRefCount(altPath);
    }
    return ret;
#endif /* ANDROID */
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_Init --
 *
 *	Perform per interpreter initialization of this module.
 *
 * Results:
 *	The return value is a standard Tcl result.
 *
 * Side effects:
 *	Initializes this module if not already initialized, and adds module
 *	related commands to the given interpreter.
 *
 *-------------------------------------------------------------------------
 */

int
TclZipfs_Init(
    Tcl_Interp *interp)		/* Current interpreter. */
{
    static const EnsembleImplMap initMap[] = {
	{"mkimg",	ZipFSMkImgObjCmd,	NULL, NULL, NULL, 1},
	{"mkzip",	ZipFSMkZipObjCmd,	NULL, NULL, NULL, 1},
	{"lmkimg",	ZipFSLMkImgObjCmd,	NULL, NULL, NULL, 1},
	{"lmkzip",	ZipFSLMkZipObjCmd,	NULL, NULL, NULL, 1},
	{"mount",	ZipFSMountObjCmd,	NULL, NULL, NULL, 1},
	{"mountdata",	ZipFSMountBufferObjCmd,	NULL, NULL, NULL, 1},
	{"unmount",	ZipFSUnmountObjCmd,	NULL, NULL, NULL, 1},
	{"mkkey",	ZipFSMkKeyObjCmd,	NULL, NULL, NULL, 1},
	{"exists",	ZipFSExistsObjCmd,	NULL, NULL, NULL, 1},
	{"info",	ZipFSInfoObjCmd,	NULL, NULL, NULL, 1},
	{"list",	ZipFSListObjCmd,	NULL, NULL, NULL, 1},
	{"canonical",	ZipFSCanonicalObjCmd,	NULL, NULL, NULL, 1},
	{"root",	ZipFSRootObjCmd,	NULL, NULL, NULL, 1},
	{NULL, NULL, NULL, NULL, NULL, 0}
    };
    static const char findproc[] =
	"namespace eval ::tcl::zipfs {}\n"
	"proc ::tcl::zipfs::Find dir {\n"
	"    set result {}\n"
	"    if {[catch {\n"
	"        concat [glob -directory $dir -nocomplain *] [glob -directory $dir -types hidden -nocomplain *]\n"
	"    } list]} {\n"
	"        return $result\n"
	"    }\n"
	"    foreach file $list {\n"
	"        if {[file tail $file] in {. ..}} {\n"
	"            continue\n"
	"        }\n"
	"        lappend result $file {*}[Find $file]\n"
	"    }\n"
	"    return $result\n"
	"}\n"
	"proc ::tcl::zipfs::find {directoryName} {\n"
	"    return [lsort [Find $directoryName]]\n"
	"}\n";

    /*
     * One-time initialization.
     */

    WriteLock();
    if (!ZipFS.initialized) {
	ZipfsSetup();
    }
    Unlock();

    if (interp) {
	Tcl_Command ensemble;
	Tcl_Obj *mapObj;

	Tcl_EvalEx(interp, findproc, TCL_INDEX_NONE, TCL_EVAL_GLOBAL);
	if (!Tcl_IsSafe(interp)) {
	    Tcl_LinkVar(interp, "::tcl::zipfs::wrmax", (char *) &ZipFS.wrmax,
		    TCL_LINK_INT);
	    Tcl_LinkVar(interp, "::tcl::zipfs::fallbackEntryEncoding",
		    (char *) &ZipFS.fallbackEntryEncoding, TCL_LINK_STRING);
	}
	ensemble = TclMakeEnsemble(interp, "zipfs",
		Tcl_IsSafe(interp) ? (initMap + 4) : initMap);

	/*
	 * Add the [zipfs find] subcommand.
	 */

	Tcl_GetEnsembleMappingDict(NULL, ensemble, &mapObj);
	TclDictPutString(NULL, mapObj, "find", "::tcl::zipfs::find");
	Tcl_CreateObjCommand(interp, "::tcl::zipfs::tcl_library_init",
		ZipFSTclLibraryObjCmd, NULL, NULL);
    }
    return TCL_OK;
}

/*
 *------------------------------------------------------------------------
 *
 * TclZipfsFinalize --
 *
 *    Frees all zipfs resources IRRESPECTIVE of open channels (there should
 *    not be any!) etc. To be called at process exit time (from
 *    Tcl_Finalize->TclFinalizeFilesystem)
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    Frees up archives loaded into memory.
 *
 *------------------------------------------------------------------------
 */
void
TclZipfsFinalize(void)
{
    WriteLock();
    if (!ZipFS.initialized) {
	Unlock();
	return;
    }

    Tcl_HashEntry *hPtr;
    Tcl_HashSearch zipSearch;
    for (hPtr = Tcl_FirstHashEntry(&ZipFS.zipHash, &zipSearch); hPtr;
	    hPtr = Tcl_NextHashEntry(&zipSearch)) {
	ZipFile *zf = (ZipFile *) Tcl_GetHashValue(hPtr);
	Tcl_DeleteHashEntry(hPtr);
	CleanupMount(zf); /* Frees file entries belonging to the archive */
	ZipFSCloseArchive(NULL, zf);
	Tcl_Free(zf);
    }

    Tcl_FSUnregister(&zipfsFilesystem);
    Tcl_DeleteHashTable(&ZipFS.fileHash);
    Tcl_DeleteHashTable(&ZipFS.zipHash);
    if (ZipFS.fallbackEntryEncoding) {
	Tcl_Free(ZipFS.fallbackEntryEncoding);
	ZipFS.fallbackEntryEncoding = NULL;
    }

    ZipFS.initialized = 0;
    Unlock();
}

/*
 * TclZipfsInitEncodingDirs --
 *
 *	Appends the encoding directory under the tcl_library directory
 *	within a ZipFS mount to the encoding directory search path.
 */
static int
TclZipfsInitEncodingDirs(void)
{
    if (zipfs_literal_tcl_library == NULL) {
	return TCL_ERROR;
    }
    Tcl_Obj *subDirObj, *searchPathObj;
    Tcl_Obj *libDirObj = Tcl_NewStringObj(zipfs_literal_tcl_library, -1);
    Tcl_IncrRefCount(libDirObj);
    TclNewLiteralStringObj(subDirObj, "encoding");
    Tcl_IncrRefCount(subDirObj);
    searchPathObj = Tcl_GetEncodingSearchPath();
    if (searchPathObj == NULL) {
	TclNewObj(searchPathObj);
    } else {
	searchPathObj = Tcl_DuplicateObj(searchPathObj);
    }
    Tcl_Obj *fullPathObj = Tcl_FSJoinToPath(libDirObj, 1, &subDirObj);
    Tcl_IncrRefCount(fullPathObj);
    TclListObjAppendIfAbsent(NULL, searchPathObj, fullPathObj);
    Tcl_IncrRefCount(searchPathObj);
    Tcl_DecrRefCount(fullPathObj);
    Tcl_DecrRefCount(subDirObj);
    Tcl_DecrRefCount(libDirObj);
    Tcl_SetEncodingSearchPath(searchPathObj);
    Tcl_DecrRefCount(searchPathObj);
    /* Reinit system encoding after setting search path */
    TclpSetInitialEncodings();
    return TCL_OK;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclZipfs_AppHook --
 *
 *	Performs the argument munging for the shell
 *
 *-------------------------------------------------------------------------
 */

const char *
TclZipfs_AppHook(
#ifdef SUPPORT_BUILTIN_ZIP_INSTALL
    int *argcPtr,		/* Pointer to argc */
#else
    TCL_UNUSED(int *), /*argcPtr*/
#endif
#ifdef _WIN32
    TCL_UNUSED(unsigned short ***)) /* argvPtr */
#else /* !_WIN32 */
    char ***argvPtr)		/* Pointer to argv */
#endif /* _WIN32 */
{
    const char *result;

#ifdef _WIN32
    result = Tcl_FindExecutable(NULL);
#else
    result = Tcl_FindExecutable((*argvPtr)[0]);
#endif
    TclZipfs_Init(NULL);

    /* Always mount archives attached to the application and shared library */
    int appZipfsPresent = TclZipfsMountExe();
    int shlibZipfsPresent = TclZipfsMountShlib();

    /*
     * After BOTH are mounted, look for init.tcl in one of the mounts.
     * Errors ignored as other locations may be available.
     */
    TclZipfsLocateTclLibrary(appZipfsPresent, shlibZipfsPresent);

    if (appZipfsPresent) {
	Tcl_Obj *vfsInitScript;

	TclNewLiteralStringObj(vfsInitScript, ZIPFS_APP_MOUNT "/main.tcl");
	Tcl_IncrRefCount(vfsInitScript);
	if (Tcl_FSAccess(vfsInitScript, F_OK) == 0) {
	    /* Startup script should be set before calling Tcl_AppInit */
	    Tcl_SetStartupScript(vfsInitScript, NULL);
	} else {
	    Tcl_DecrRefCount(vfsInitScript);
	}

#ifdef SUPPORT_BUILTIN_ZIP_INSTALL
#error "SUPPORT_BUILTIN_ZIP_INSTALL not implemented - TODO"
    } else if (*argcPtr > 1) {
	/*
	 * If the first argument is "install", run the supplied installer
	 * script.
	 */

#ifdef _WIN32
	Tcl_DString ds;

	Tcl_DStringInit(&ds);
	archive = Tcl_WCharToUtfDString((*argvPtr)[1], TCL_INDEX_NONE, &ds);
#else /* !_WIN32 */
	archive = (*argvPtr)[1];
#endif /* _WIN32 */
	if (strcmp(archive, "install") == 0) {
	    Tcl_Obj *vfsInitScript;

	    /*
	     * Run this now to ensure the file is present by the time Tcl_Main
	     * wants it.
	     */

	    TclZipfs_TclLibrary();
	    TclNewLiteralStringObj(vfsInitScript,
		    ZIPFS_ZIP_MOUNT "/tcl_library/install.tcl");
	    Tcl_IncrRefCount(vfsInitScript);
	    if (Tcl_FSAccess(vfsInitScript, F_OK) == 0) {
		Tcl_SetStartupScript(vfsInitScript, NULL);
	    }
	    return result;
	} else if (TclZipfs_Mount(NULL, archive, ZIPFS_APP_MOUNT, NULL) == TCL_OK) {
	    Tcl_Obj *vfsInitScript;

	    if (!zipfs_literal_tcl_library) {
		if (TclZipfsLocateTclLibrary() == TCL_OK) {
		    (void) TclZipfsInitEncodingDirs();
		}
	    }

	    TclNewLiteralStringObj(vfsInitScript, ZIPFS_APP_MOUNT "/main.tcl");
	    Tcl_IncrRefCount(vfsInitScript);
	    if (Tcl_FSAccess(vfsInitScript, F_OK) == 0) {
		/*
		 * Startup script should be set before calling Tcl_AppInit
		 */

		Tcl_SetStartupScript(vfsInitScript, NULL);
	    } else {
		Tcl_DecrRefCount(vfsInitScript);
	    }
	}
#ifdef _WIN32
	Tcl_DStringFree(&ds);
#endif /* _WIN32 */
#endif /* SUPPORT_BUILTIN_ZIP_INSTALL */
    }
    return result;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

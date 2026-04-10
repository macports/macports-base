/*
 * tclEncoding.c --
 *
 *	Contains the implementation of the encoding conversion package.
 *
 * Copyright © 1996-1998 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

typedef size_t (LengthProc)(const char *src);

/*
 * The following data structure represents an encoding, which describes how to
 * convert between various character sets and UTF-8.
 */

typedef struct {
    char *name;			/* Name of encoding. Malloced because (1) hash
				 * table entry that owns this encoding may be
				 * freed prior to this encoding being freed,
				 * (2) string passed in the Tcl_EncodingType
				 * structure may not be persistent. */
    Tcl_EncodingConvertProc *toUtfProc;
				/* Function to convert from external encoding
				 * into UTF-8. */
    Tcl_EncodingConvertProc *fromUtfProc;
				/* Function to convert from UTF-8 into
				 * external encoding. */
    Tcl_EncodingFreeProc *freeProc;
				/* If non-NULL, function to call when this
				 * encoding is deleted. */
    void *clientData;		/* Arbitrary value associated with encoding
				 * type. Passed to conversion functions. */
    Tcl_Size nullSize;		/* Number of 0x00 bytes that signify
				 * end-of-string in this encoding. This number
				 * is used to determine the source string
				 * length when the srcLen argument is
				 * negative. This number can be 1, 2, or 4. */
    LengthProc *lengthProc;	/* Function to compute length of
				 * null-terminated strings in this encoding.
				 * If nullSize is 1, this is strlen; if
				 * nullSize is 2, this is a function that
				 * returns the number of bytes in a 0x0000
				 * terminated string; if nullSize is 4, this
				 * is a function that returns the number of
				 * bytes in a 0x00000000 terminated string. */
    size_t refCount;		/* Number of uses of this structure. */
    Tcl_HashEntry *hPtr;	/* Hash table entry that owns this encoding. */
} Encoding;

/*
 * The following structure is the clientData for a dynamically-loaded,
 * table-driven encoding created by LoadTableEncoding(). It maps between
 * Unicode and a single-byte, double-byte, or multibyte (1 or 2 bytes only)
 * encoding.
 */

typedef struct {
    int fallback;		/* Character (in this encoding) to substitute
				 * when this encoding cannot represent a UTF-8
				 * character. */
    char prefixBytes[256];	/* If a byte in the input stream is a lead
				 * byte for a 2-byte sequence, the
				 * corresponding entry in this array is 1,
				 * otherwise it is 0. */
    unsigned short **toUnicode;	/* Two dimensional sparse matrix to map
				 * characters from the encoding to Unicode.
				 * Each element of the toUnicode array points
				 * to an array of 256 shorts. If there is no
				 * corresponding character in Unicode, the
				 * value in the matrix is 0x0000.
				 * malloc'd. */
    unsigned short **fromUnicode;
				/* Two dimensional sparse matrix to map
				 * characters from Unicode to the encoding.
				 * Each element of the fromUnicode array
				 * points to an array of 256 shorts. If there
				 * is no corresponding character the encoding,
				 * the value in the matrix is 0x0000.
				 * malloc'd. */
} TableEncodingData;

/*
 * Each of the following structures is the clientData for a dynamically-loaded
 * escape-driven encoding that is itself comprised of other simpler encodings.
 * An example is "iso-2022-jp", which uses escape sequences to switch between
 * ascii, jis0208, jis0212, gb2312, and ksc5601. Note that "escape-driven"
 * does not necessarily mean that the ESCAPE character is the character used
 * for switching character sets.
 */

typedef struct {
    unsigned sequenceLen;	/* Length of following string. */
    char sequence[16];		/* Escape code that marks this encoding. */
    char name[32];		/* Name for encoding. */
    Encoding *encodingPtr;	/* Encoding loaded using above name, or NULL
				 * if this sub-encoding has not been needed
				 * yet. */
} EscapeSubTable;

typedef struct {
    int fallback;		/* Character (in this encoding) to substitute
				 * when this encoding cannot represent a UTF-8
				 * character. */
    unsigned initLen;		/* Length of following string. */
    char init[16];		/* String to emit or expect before first char
				 * in conversion. */
    unsigned finalLen;		/* Length of following string. */
    char final[16];		/* String to emit or expect after last char in
				 * conversion. */
    char prefixBytes[256];	/* If a byte in the input stream is the first
				 * character of one of the escape sequences in
				 * the following array, the corresponding
				 * entry in this array is 1, otherwise it is
				 * 0. */
    int numSubTables;		/* Length of following array. */
    EscapeSubTable subTables[TCLFLEXARRAY];
				/* Information about each EscapeSubTable used
				 * by this encoding type. The actual size is
				 * as large as necessary to hold all
				 * EscapeSubTables. */
} EscapeEncodingData;

/*
 * Values used when loading an encoding file to identify the type of the
 * file.
 */
enum EncodingTypes {
    ENCODING_SINGLEBYTE = 0,	/* Encoding is single byte per character. */
    ENCODING_DOUBLEBYTE = 1,	/* Encoding is two bytes per character. */
    ENCODING_MULTIBYTE = 2,	/* Encoding is variable bytes per character. */
    ENCODING_ESCAPE = 3		/* Encoding has modes with escapes to move
				 * between them. */
};

/*
 * A list of directories in which Tcl should look for *.enc files. This list
 * is shared by all threads. Access is governed by a mutex lock.
 */

static TclInitProcessGlobalValueProc InitializeEncodingSearchPath;
static ProcessGlobalValue encodingSearchPath = {
    0, 0, NULL, NULL, InitializeEncodingSearchPath, NULL, NULL
};

/*
 * A map from encoding names to the directories in which their data files have
 * been seen. The string value of the map is shared by all threads. Access to
 * the shared string is governed by a mutex lock.
 */

static ProcessGlobalValue encodingFileMap = {
    0, 0, NULL, NULL, NULL, NULL, NULL
};

/*
 * A list of directories making up the "library path". Historically this
 * search path has served many uses, but the only one remaining is a base for
 * the encodingSearchPath above. If the application does not explicitly set
 * the encodingSearchPath, then it is initialized by appending /encoding
 * to each directory in this "libraryPath".
 */

static ProcessGlobalValue libraryPath = {
    0, 0, NULL, NULL, TclpInitLibraryPath, NULL, NULL
};

static int encodingsInitialized = 0;

/*
 * Hash table that keeps track of all loaded Encodings. Keys are the string
 * names that represent the encoding, values are (Encoding *).
 */

static Tcl_HashTable encodingTable;
TCL_DECLARE_MUTEX(encodingMutex)

/*
 * The following are used to hold the default and current system encodings.
 * If NULL is passed to one of the conversion routines, the current setting of
 * the system encoding is used to perform the conversion.
 */

static Tcl_Encoding defaultEncoding = NULL;
static Tcl_Encoding systemEncoding = NULL;
Tcl_Encoding tclIdentityEncoding = NULL;
Tcl_Encoding tclUtf8Encoding = NULL;

/*
 * Names of encoding profiles and corresponding integer values.
 * Keep alphabetical order for error messages.
 */
static const struct TclEncodingProfiles {
    const char *name;
    int value;
} encodingProfiles[] = {
    {"replace", TCL_ENCODING_PROFILE_REPLACE},
    {"strict", TCL_ENCODING_PROFILE_STRICT},
    {"tcl8", TCL_ENCODING_PROFILE_TCL8},
};

#define PROFILE_TCL8(flags_) \
    (ENCODING_PROFILE_GET(flags_) == TCL_ENCODING_PROFILE_TCL8)

#define PROFILE_REPLACE(flags_) \
    (ENCODING_PROFILE_GET(flags_) == TCL_ENCODING_PROFILE_REPLACE)

#define PROFILE_STRICT(flags_) \
    (!PROFILE_TCL8(flags_) && !PROFILE_REPLACE(flags_))

#define UNICODE_REPLACE_CHAR 0xFFFD
#define SURROGATE(c_)		(((c_) & ~0x7FF) == 0xD800)
#define HIGH_SURROGATE(c_)	(((c_) & ~0x3FF) == 0xD800)
#define LOW_SURROGATE(c_)	(((c_) & ~0x3FF) == 0xDC00)

/*
 * The following variable is used in the sparse matrix code for a
 * TableEncoding to represent a page in the table that has no entries.
 */

static unsigned short emptyPage[256];

/*
 * Functions used only in this module.
 */

static Tcl_EncodingConvertProc	BinaryProc;
static Tcl_DupInternalRepProc	DupEncodingInternalRep;
static Tcl_EncodingFreeProc	EscapeFreeProc;
static Tcl_EncodingConvertProc	EscapeFromUtfProc;
static Tcl_EncodingConvertProc	EscapeToUtfProc;
static void			FillEncodingFileMap(void);
static void			FreeEncoding(Tcl_Encoding encoding);
static Tcl_FreeInternalRepProc	FreeEncodingInternalRep;
static Encoding *		GetTableEncoding(EscapeEncodingData *dataPtr,
				    int state);
static Tcl_Encoding		LoadEncodingFile(Tcl_Interp *interp,
				    const char *name);
static Tcl_Encoding		LoadTableEncoding(const char *name, int type,
				    Tcl_Channel chan);
static Tcl_Encoding		LoadEscapeEncoding(const char *name,
				    Tcl_Channel chan);
static Tcl_Channel		OpenEncodingFileChannel(Tcl_Interp *interp,
				    const char *name);
static Tcl_EncodingFreeProc	TableFreeProc;
static Tcl_EncodingConvertProc	TableFromUtfProc;
static Tcl_EncodingConvertProc	TableToUtfProc;
static size_t		unilen(const char *src);
static size_t		unilen4(const char *src);
static Tcl_EncodingConvertProc	Utf32ToUtfProc;
static Tcl_EncodingConvertProc	UtfToUtf32Proc;
static Tcl_EncodingConvertProc	Utf16ToUtfProc;
static Tcl_EncodingConvertProc	UtfToUtf16Proc;
static Tcl_EncodingConvertProc	UtfToUcs2Proc;
static Tcl_EncodingConvertProc	UtfToUtfProc;
static Tcl_EncodingConvertProc	Iso88591FromUtfProc;
static Tcl_EncodingConvertProc	Iso88591ToUtfProc;

/*
 * A Tcl_ObjType for holding a cached Tcl_Encoding in the twoPtrValue.ptr1
 * field of the internalrep. This should help the lifetime of encodings be more
 * useful. See concerns raised in [Bug 1077262].
 */

static const Tcl_ObjType encodingType = {
    "encoding",
    FreeEncodingInternalRep,
    DupEncodingInternalRep,
    NULL,
    NULL,
    TCL_OBJTYPE_V0
};

#define EncodingSetInternalRep(objPtr, encoding) \
    do {								\
	Tcl_ObjInternalRep ir;						\
	ir.twoPtrValue.ptr1 = (encoding);				\
	ir.twoPtrValue.ptr2 = NULL;					\
	Tcl_StoreInternalRep((objPtr), &encodingType, &ir);		\
    } while (0)

#define EncodingGetInternalRep(objPtr, encoding) \
    do {								\
	const Tcl_ObjInternalRep *irPtr;				\
	irPtr = TclFetchInternalRep ((objPtr), &encodingType);		\
	(encoding) = irPtr ? (Tcl_Encoding)irPtr->twoPtrValue.ptr1 : NULL; \
    } while (0)

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetEncodingFromObj --
 *
 *	Writes to (*encodingPtr) the Tcl_Encoding value of (*objPtr), if
 *	possible, and returns TCL_OK. If no such encoding exists, TCL_ERROR is
 *	returned, and if interp is non-NULL, an error message is written
 *	there.
 *
 * Results:
 *	Standard Tcl return code.
 *
 * Side effects:
 *	Caches the Tcl_Encoding value as the internal rep of (*objPtr).
 *
 *----------------------------------------------------------------------
 */

int
Tcl_GetEncodingFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,
    Tcl_Encoding *encodingPtr)
{
    Tcl_Encoding encoding;
    const char *name = TclGetString(objPtr);

    EncodingGetInternalRep(objPtr, encoding);
    if (encoding == NULL) {
	encoding = Tcl_GetEncoding(interp, name);
	if (encoding == NULL) {
	    return TCL_ERROR;
	}
	EncodingSetInternalRep(objPtr, encoding);
    }
    *encodingPtr = Tcl_GetEncoding(NULL, name);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeEncodingInternalRep --
 *
 *	The Tcl_FreeInternalRepProc for the "encoding" Tcl_ObjType.
 *
 *----------------------------------------------------------------------
 */

static void
FreeEncodingInternalRep(
    Tcl_Obj *objPtr)
{
    Tcl_Encoding encoding;

    EncodingGetInternalRep(objPtr, encoding);
    Tcl_FreeEncoding(encoding);
}

/*
 *----------------------------------------------------------------------
 *
 * DupEncodingInternalRep --
 *
 *	The Tcl_DupInternalRepProc for the "encoding" Tcl_ObjType.
 *
 *----------------------------------------------------------------------
 */

static void
DupEncodingInternalRep(
    Tcl_Obj *srcPtr,
    Tcl_Obj *dupPtr)
{
    Tcl_Encoding encoding = Tcl_GetEncoding(NULL, TclGetString(srcPtr));
    EncodingSetInternalRep(dupPtr, encoding);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_GetEncodingSearchPath --
 *
 *	Keeps the per-thread copy of the encoding search path current with
 *	changes to the global copy.
 *
 * Results:
 *	Returns a "list" (Tcl_Obj *) that contains the encoding search path.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_GetEncodingSearchPath(void)
{
    return TclGetProcessGlobalValue(&encodingSearchPath);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetEncodingSearchPath --
 *
 *	Keeps the per-thread copy of the encoding search path current with
 *	changes to the global copy.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_SetEncodingSearchPath(
    Tcl_Obj *searchPath)
{
    Tcl_Size dummy;

    if (TCL_ERROR == TclListObjLength(NULL, searchPath, &dummy)) {
	return TCL_ERROR;
    }
    TclSetProcessGlobalValue(&encodingSearchPath, searchPath);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * FillEncodingFileMap --
 *
 *	Called to update the encoding file map with the current value
 *	of the encoding search path.
 *
 *	Finds *.end files in the directories on the encoding search path and
 *	stores the found pathnames in a map associated with the encoding name.
 *
 *	If $dir is on the encoding search path and the file $dir/foo.enc is
 *	found, stores a "foo" -> $dir entry in the map.  if the "foo" encoding
 *	is needed later, the $dir/foo.enc name can be quickly constructed in
 *	order to read the encoding data.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Entries are added to the encoding file map.
 *
 *---------------------------------------------------------------------------
 */

static void
FillEncodingFileMap(void)
{
    Tcl_Size i, numDirs = 0;
    Tcl_Obj *map, *searchPath;

    searchPath = Tcl_GetEncodingSearchPath();
    Tcl_IncrRefCount(searchPath);
    TclListObjLength(NULL, searchPath, &numDirs);
    map = Tcl_NewDictObj();
    Tcl_IncrRefCount(map);

    for (i = numDirs-1; i != TCL_INDEX_NONE; i--) {
	/*
	 * Iterate backwards through the search path so as we overwrite
	 * entries found, we favor files earlier on the search path.
	 */

	Tcl_Size j, numFiles;
	Tcl_Obj *directory, *matchFileList;
	Tcl_Obj **filev;
	Tcl_GlobTypeData readableFiles = {
	    TCL_GLOB_TYPE_FILE, TCL_GLOB_PERM_R, NULL, NULL
	};

	TclNewObj(matchFileList);
	Tcl_ListObjIndex(NULL, searchPath, i, &directory);
	Tcl_IncrRefCount(directory);
	Tcl_IncrRefCount(matchFileList);
	Tcl_FSMatchInDirectory(NULL, matchFileList, directory, "*.enc",
		&readableFiles);

	TclListObjGetElements(NULL, matchFileList, &numFiles, &filev);
	for (j=0; j<numFiles; j++) {
	    Tcl_Obj *encoding, *fileObj;

	    fileObj = TclPathPart(NULL, filev[j], TCL_PATH_TAIL);
	    encoding = TclPathPart(NULL, fileObj, TCL_PATH_ROOT);
	    Tcl_DictObjPut(NULL, map, encoding, directory);
	    Tcl_DecrRefCount(fileObj);
	    Tcl_DecrRefCount(encoding);
	}
	Tcl_DecrRefCount(matchFileList);
	Tcl_DecrRefCount(directory);
    }
    Tcl_DecrRefCount(searchPath);
    TclSetProcessGlobalValue(&encodingFileMap, map);
    Tcl_DecrRefCount(map);
}

/*
 *---------------------------------------------------------------------------
 *
 * TclInitEncodingSubsystem --
 *
 *	Initialize all resources used by this subsystem on a per-process
 *	basis.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Depends on the memory, object, and IO subsystems.
 *
 *---------------------------------------------------------------------------
 */

/*
 * NOTE: THESE BIT DEFINITIONS SHOULD NOT OVERLAP WITH INTERNAL USE BITS
 * DEFINED IN tcl.h (TCL_ENCODING_* et al). Be cognizant of this
 * when adding bits. TODO - should really be defined in a single file.
 *
 * To prevent conflicting bits, only define bits within 0xff00 mask here.
 */
enum InternalEncodingFlags {
    TCL_ENCODING_LE = 0x100,	/* Used to distinguish LE/BE variants */
    ENCODING_UTF = 0x200,	/* For UTF-8 encoding, allow 4-byte output
				 * sequences */
    ENCODING_INPUT = 0x400	/* For UTF-8/CESU-8 encoding, means
				 * external -> internal */
};

void
TclInitEncodingSubsystem(void)
{
    Tcl_EncodingType type;
    TableEncodingData *dataPtr;
    unsigned size;
    unsigned short i;
    union {
	char c;
	short s;
    } isLe;
    int leFlags;

    if (encodingsInitialized) {
	return;
    }

    /* Note: This DEPENDS on TCL_ENCODING_LE being defined in least sig byte */
    isLe.s = 1;
    leFlags = isLe.c ? TCL_ENCODING_LE : 0;

    Tcl_MutexLock(&encodingMutex);
    Tcl_InitHashTable(&encodingTable, TCL_STRING_KEYS);
    Tcl_MutexUnlock(&encodingMutex);

    /*
     * Create a few initial encodings.  UTF-8 to UTF-8 translation is not a
     * no-op because it turns a stream of improperly formed UTF-8 into a
     * properly formed stream.
     */

    type.encodingName	= NULL;
    type.toUtfProc	= BinaryProc;
    type.fromUtfProc	= BinaryProc;
    type.freeProc	= NULL;
    type.nullSize	= 1;
    type.clientData	= NULL;
    tclIdentityEncoding = Tcl_CreateEncoding(&type);

    type.encodingName	= "utf-8";
    type.toUtfProc	= UtfToUtfProc;
    type.fromUtfProc	= UtfToUtfProc;
    type.freeProc	= NULL;
    type.nullSize	= 1;
    type.clientData	= INT2PTR(ENCODING_UTF);
    tclUtf8Encoding = Tcl_CreateEncoding(&type);
    type.clientData	= NULL;
    type.encodingName	= "cesu-8";
    Tcl_CreateEncoding(&type);

    type.toUtfProc	= Utf16ToUtfProc;
    type.fromUtfProc	= UtfToUcs2Proc;
    type.freeProc	= NULL;
    type.nullSize	= 2;
    type.encodingName	= "ucs-2le";
    type.clientData	= INT2PTR(TCL_ENCODING_LE);
    Tcl_CreateEncoding(&type);
    type.encodingName	= "ucs-2be";
    type.clientData	= NULL;
    Tcl_CreateEncoding(&type);
    type.encodingName	= "ucs-2";
    type.clientData	= INT2PTR(leFlags);
    Tcl_CreateEncoding(&type);

    type.toUtfProc	= Utf32ToUtfProc;
    type.fromUtfProc	= UtfToUtf32Proc;
    type.freeProc	= NULL;
    type.nullSize	= 4;
    type.encodingName	= "utf-32le";
    type.clientData	= INT2PTR(TCL_ENCODING_LE);
    Tcl_CreateEncoding(&type);
    type.encodingName	= "utf-32be";
    type.clientData	= NULL;
    Tcl_CreateEncoding(&type);
    type.encodingName	= "utf-32";
    type.clientData	= INT2PTR(leFlags);
    Tcl_CreateEncoding(&type);

    type.toUtfProc	= Utf16ToUtfProc;
    type.fromUtfProc    = UtfToUtf16Proc;
    type.freeProc	= NULL;
    type.nullSize	= 2;
    type.encodingName	= "utf-16le";
    type.clientData	= INT2PTR(TCL_ENCODING_LE);
    Tcl_CreateEncoding(&type);
    type.encodingName	= "utf-16be";
    type.clientData	= NULL;
    Tcl_CreateEncoding(&type);
    type.encodingName	= "utf-16";
    type.clientData	= INT2PTR(leFlags);
    Tcl_CreateEncoding(&type);

#ifndef TCL_NO_DEPRECATED
    type.encodingName	= "unicode";
    Tcl_CreateEncoding(&type);
#endif

    /*
     * Need the iso8859-1 encoding in order to process binary data, so force
     * it to always be embedded. Note that this encoding *must* be a proper
     * table encoding or some of the escape encodings crash! Hence the ugly
     * code to duplicate the structure of a table encoding here.
     */

    dataPtr = (TableEncodingData *)Tcl_Alloc(sizeof(TableEncodingData));
    memset(dataPtr, 0, sizeof(TableEncodingData));
    dataPtr->fallback = '?';

    size = 256*(sizeof(unsigned short *) + sizeof(unsigned short));
    dataPtr->toUnicode = (unsigned short **)Tcl_Alloc(size);
    memset(dataPtr->toUnicode, 0, size);
    dataPtr->fromUnicode = (unsigned short **)Tcl_Alloc(size);
    memset(dataPtr->fromUnicode, 0, size);

    dataPtr->toUnicode[0] = (unsigned short *) (dataPtr->toUnicode + 256);
    dataPtr->fromUnicode[0] = (unsigned short *) (dataPtr->fromUnicode + 256);
    for (i=1 ; i<256 ; i++) {
	dataPtr->toUnicode[i] = emptyPage;
	dataPtr->fromUnicode[i] = emptyPage;
    }

    for (i=0 ; i<256 ; i++) {
	dataPtr->toUnicode[0][i] = i;
	dataPtr->fromUnicode[0][i] = i;
    }

    type.encodingName	= "iso8859-1";
    type.toUtfProc	= Iso88591ToUtfProc;
    type.fromUtfProc	= Iso88591FromUtfProc;
    type.freeProc	= TableFreeProc;
    type.nullSize	= 1;
    type.clientData	= dataPtr;
    defaultEncoding	= Tcl_CreateEncoding(&type);
    systemEncoding	= Tcl_GetEncoding(NULL, type.encodingName);

    encodingsInitialized = 1;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeEncodingSubsystem --
 *
 *	Release the state associated with the encoding subsystem.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees all of the encodings.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeEncodingSubsystem(void)
{
    Tcl_HashSearch search;
    Tcl_HashEntry *hPtr;

    Tcl_MutexLock(&encodingMutex);
    encodingsInitialized = 0;
    FreeEncoding(systemEncoding);
    systemEncoding = NULL;
    defaultEncoding = NULL;
    FreeEncoding(tclIdentityEncoding);
    tclIdentityEncoding = NULL;
    FreeEncoding(tclUtf8Encoding);
    tclUtf8Encoding = NULL;

    hPtr = Tcl_FirstHashEntry(&encodingTable, &search);
    while (hPtr != NULL) {
	/*
	 * Call FreeEncoding instead of doing it directly to handle refcounts
	 * like escape encodings use. [Bug 524674] Make sure to call
	 * Tcl_FirstHashEntry repeatedly so that all encodings are eventually
	 * cleaned up.
	 */

	FreeEncoding((Tcl_Encoding)Tcl_GetHashValue(hPtr));
	hPtr = Tcl_FirstHashEntry(&encodingTable, &search);
    }

    Tcl_DeleteHashTable(&encodingTable);
    Tcl_MutexUnlock(&encodingMutex);
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_GetEncoding --
 *
 *	Given the name of a encoding, find the corresponding Tcl_Encoding
 *	token. If the encoding did not already exist, Tcl attempts to
 *	dynamically load an encoding by that name.
 *
 * Results:
 *	Returns a token that represents the encoding. If the name didn't refer
 *	to any known or loadable encoding, NULL is returned. If NULL was
 *	returned, an error message is left in interp's result object, unless
 *	interp was NULL.
 *
 * Side effects:
 *	LoadEncodingFile is called if necessary.
 *
 *-------------------------------------------------------------------------
 */

Tcl_Encoding
Tcl_GetEncoding(
    Tcl_Interp *interp,		/* Interp for error reporting, if not NULL. */
    const char *name)		/* The name of the desired encoding. */
{
    Tcl_HashEntry *hPtr;
    Encoding *encodingPtr;

    Tcl_MutexLock(&encodingMutex);
    if (name == NULL) {
	encodingPtr = (Encoding *) systemEncoding;
	encodingPtr->refCount++;
	Tcl_MutexUnlock(&encodingMutex);
	return systemEncoding;
    }

    hPtr = Tcl_FindHashEntry(&encodingTable, name);
    if (hPtr != NULL) {
	encodingPtr = (Encoding *)Tcl_GetHashValue(hPtr);
	encodingPtr->refCount++;
	Tcl_MutexUnlock(&encodingMutex);
	return (Tcl_Encoding) encodingPtr;
    }
    Tcl_MutexUnlock(&encodingMutex);

    return LoadEncodingFile(interp, name);
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FreeEncoding --
 *
 *	Releases an encoding allocated by Tcl_CreateEncoding() or
 *	Tcl_GetEncoding().
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The reference count associated with the encoding is decremented and
 *	the encoding is deleted if nothing is using it anymore.
 *
 *---------------------------------------------------------------------------
 */

void
Tcl_FreeEncoding(
    Tcl_Encoding encoding)
{
    Tcl_MutexLock(&encodingMutex);
    FreeEncoding(encoding);
    Tcl_MutexUnlock(&encodingMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * FreeEncoding --
 *
 *	Decrements the reference count of an encoding.  The caller must hold
 *	encodingMutes.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Releases the resource for an encoding if it is now unused.
 *	The reference count associated with the encoding is decremented and
 *	the encoding may be deleted if nothing is using it anymore.
 *
 *----------------------------------------------------------------------
 */

static void
FreeEncoding(
    Tcl_Encoding encoding)
{
    Encoding *encodingPtr = (Encoding *) encoding;

    if (encodingPtr == NULL) {
	return;
    }
    if (encodingPtr->refCount-- <= 1) {
	if (encodingPtr->freeProc != NULL) {
	    encodingPtr->freeProc(encodingPtr->clientData);
	}
	if (encodingPtr->hPtr != NULL) {
	    Tcl_DeleteHashEntry(encodingPtr->hPtr);
	}
	if (encodingPtr->name) {
	    Tcl_Free(encodingPtr->name);
	}
	Tcl_Free(encodingPtr);
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_GetEncodingName --
 *
 *	Given an encoding, return the name that was used to construct the
 *	encoding.
 *
 * Results:
 *	The name of the encoding.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

const char *
Tcl_GetEncodingName(
    Tcl_Encoding encoding)	/* The encoding whose name to fetch. */
{
    if (encoding == NULL) {
	encoding = systemEncoding;
    }

    return ((Encoding *) encoding)->name;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_GetEncodingNames --
 *
 *	Get the list of all known encodings, including the ones stored as
 *	files on disk in the encoding path.
 *
 * Results:
 *	Modifies interp's result object to hold a list of all the available
 *	encodings.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

void
Tcl_GetEncodingNames(
    Tcl_Interp *interp)		/* Interp to hold result. */
{
    Tcl_HashTable table;
    Tcl_HashSearch search;
    Tcl_HashEntry *hPtr;
    Tcl_Obj *map, *name, *result;
    Tcl_DictSearch mapSearch;
    int dummy, done = 0;

    TclNewObj(result);
    Tcl_InitObjHashTable(&table);

    /*
     * Copy encoding names from loaded encoding table to table.
     */

    Tcl_MutexLock(&encodingMutex);
    for (hPtr = Tcl_FirstHashEntry(&encodingTable, &search); hPtr != NULL;
	    hPtr = Tcl_NextHashEntry(&search)) {
	Encoding *encodingPtr = (Encoding *)Tcl_GetHashValue(hPtr);

	Tcl_CreateHashEntry(&table,
		Tcl_NewStringObj(encodingPtr->name, TCL_INDEX_NONE), &dummy);
    }
    Tcl_MutexUnlock(&encodingMutex);

    FillEncodingFileMap();
    map = TclGetProcessGlobalValue(&encodingFileMap);

    /*
     * Copy encoding names from encoding file map to table.
     */

    Tcl_DictObjFirst(NULL, map, &mapSearch, &name, NULL, &done);
    for (; !done; Tcl_DictObjNext(&mapSearch, &name, NULL, &done)) {
	Tcl_CreateHashEntry(&table, name, &dummy);
    }

    /*
     * Pull all encoding names from table into the result list.
     */

    for (hPtr = Tcl_FirstHashEntry(&table, &search); hPtr != NULL;
	    hPtr = Tcl_NextHashEntry(&search)) {
	Tcl_ListObjAppendElement(NULL, result,
		(Tcl_Obj *) Tcl_GetHashKey(&table, hPtr));
    }
    Tcl_SetObjResult(interp, result);
    Tcl_DeleteHashTable(&table);
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_GetEncodingNulLength --
 *
 *	Given an encoding, return the number of nul bytes used for the
 *	string termination.
 *
 * Results:
 *	The number of nul bytes used for the string termination.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */
Tcl_Size
Tcl_GetEncodingNulLength(
    Tcl_Encoding encoding)
{
    if (encoding == NULL) {
	encoding = systemEncoding;
    }

    return ((Encoding *) encoding)->nullSize;
}

/*
 *------------------------------------------------------------------------
 *
 * Tcl_SetSystemEncoding --
 *
 *	Sets the default encoding that should be used whenever the user passes
 *	a NULL value in to one of the conversion routines. If the supplied
 *	name is NULL, the system encoding is reset to the default system
 *	encoding.
 *
 * Results:
 *	The return value is TCL_OK if the system encoding was successfully set
 *	to the encoding specified by name, TCL_ERROR otherwise. If TCL_ERROR
 *	is returned, an error message is left in interp's result object,
 *	unless interp was NULL.
 *
 * Side effects:
 *	If the passed encoding is the same as the current system
 *	encoding, the call is effectively a no-op. Otherwise, the reference
 *	count of the new system encoding is incremented. The reference count
 *	of the old system encoding is decremented and it may be freed. All
 *	VFS cached information is invalidated.
 *
 *------------------------------------------------------------------------
 */

int
Tcl_SetSystemEncoding(
    Tcl_Interp *interp,		/* Interp for error reporting, if not NULL. */
    const char *name)		/* The name of the desired encoding, or NULL/""
				 * to reset to default encoding. */
{
    Tcl_Encoding encoding = NULL;


    if (name && *name) {
	encoding = Tcl_GetEncoding(interp, name); /* this increases refCount */
	if (encoding == NULL) {
	    return TCL_ERROR;
	}
    }

    /* Don't lock (and change anything, bump epoch) if it remains unchanged. */

    if ((encoding ? encoding : defaultEncoding) == systemEncoding) {
	if (encoding) {
	    Tcl_FreeEncoding(encoding); /* paired to Tcl_GetEncoding */


	}


	return TCL_OK;
    }

    /* Checks above ensure this is only called when system encoding changes */
    Tcl_MutexLock(&encodingMutex);
    if (!encoding) {
	encoding = defaultEncoding; /* need increase its refCount */
	((Encoding *)encoding)->refCount++;
    }

    FreeEncoding(systemEncoding);
    systemEncoding = encoding;
    Tcl_MutexUnlock(&encodingMutex);

    Tcl_FSMountsChanged(NULL);

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_CreateEncoding --
 *
 *	Defines a new encoding, along with the functions that are used to
 *	convert to and from Unicode.
 *
 * Results:
 *	Returns a token that represents the encoding. If an encoding with the
 *	same name already existed, the old encoding token remains valid and
 *	continues to behave as it used to, and is eventually garbage collected
 *	when the last reference to it goes away. Any subsequent calls to
 *	Tcl_GetEncoding with the specified name retrieve the most recent
 *	encoding token.
 *
 * Side effects:
 *	A new record having the name of the encoding is entered into a table of
 *	encodings visible to all interpreters.  For each call to this function,
 *	there should eventually be a call to Tcl_FreeEncoding, which cleans
 *	deletes the record in the table when an encoding is no longer needed.
 *
 *---------------------------------------------------------------------------
 */

Tcl_Encoding
Tcl_CreateEncoding(
    const Tcl_EncodingType *typePtr)
				/* The encoding type. */
{
    Encoding *encodingPtr = (Encoding *)Tcl_Alloc(sizeof(Encoding));
    encodingPtr->name		= NULL;
    encodingPtr->toUtfProc	= typePtr->toUtfProc;
    encodingPtr->fromUtfProc	= typePtr->fromUtfProc;
    encodingPtr->freeProc	= typePtr->freeProc;
    encodingPtr->nullSize	= typePtr->nullSize;
    encodingPtr->clientData	= typePtr->clientData;
    if (typePtr->nullSize == 2) {
	encodingPtr->lengthProc = (LengthProc *) unilen;
    } else if (typePtr->nullSize == 4) {
	encodingPtr->lengthProc = (LengthProc *) unilen4;
    } else {
	encodingPtr->lengthProc = (LengthProc *) strlen;
    }
    encodingPtr->refCount	= 1;
    encodingPtr->hPtr		= NULL;

    if (typePtr->encodingName) {
	Tcl_HashEntry *hPtr;
	int isNew;
	char *name;

	Tcl_MutexLock(&encodingMutex);
	hPtr = Tcl_CreateHashEntry(&encodingTable, typePtr->encodingName, &isNew);
	if (isNew == 0) {
	    /*
	     * Remove old encoding from hash table, but don't delete it until last
	     * reference goes away.
	     */

	    Encoding *replaceMe = (Encoding *)Tcl_GetHashValue(hPtr);
	    replaceMe->hPtr = NULL;
	}

	name = (char *)Tcl_Alloc(strlen(typePtr->encodingName) + 1);
	encodingPtr->name	= strcpy(name, typePtr->encodingName);
	encodingPtr->hPtr	= hPtr;
	Tcl_SetHashValue(hPtr, encodingPtr);

	Tcl_MutexUnlock(&encodingMutex);
    }
    return (Tcl_Encoding) encodingPtr;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_ExternalToUtfDString --
 *
 *	Convert a source buffer from the specified encoding into UTF-8. If any
 *	of the bytes in the source buffer are invalid or cannot be represented
 *	in the target encoding, a default fallback character will be
 *	substituted.
 *
 * Results:
 *	The converted bytes are stored in the DString, which is then NULL
 *	terminated. The return value is a pointer to the value stored in the
 *	DString.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

#undef Tcl_ExternalToUtfDString
char *
Tcl_ExternalToUtfDString(
    Tcl_Encoding encoding,	/* The encoding for the source string, or NULL
				 * for the default system encoding. */
    const char *src,		/* Source string in specified encoding. */
    Tcl_Size srcLen,		/* Source string length in bytes, or < 0 for
				 * encoding-specific string length. */
    Tcl_DString *dstPtr)	/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
    Tcl_ExternalToUtfDStringEx(
	NULL, encoding, src, srcLen, TCL_ENCODING_PROFILE_TCL8, dstPtr, NULL);
    return Tcl_DStringValue(dstPtr);
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_ExternalToUtfDStringEx --
 *
 *	Convert a source buffer from the specified encoding into UTF-8.
 *	"flags" controls the behavior if any of the bytes in
 *	the source buffer are invalid or cannot be represented in utf-8.
 *	Possible flags values:
 *	target encoding. It should be composed by OR-ing the following:
 *	- *At most one* of TCL_ENCODING_PROFILE{DEFAULT,TCL8,STRICT}
 *
 * Results:
 *	The return value is one of
 *	  TCL_OK: success. Converted string in *dstPtr
 *	  TCL_ERROR: error in passed parameters. Error message in interp
 *	  TCL_CONVERT_MULTIBYTE: source ends in truncated multibyte sequence
 *	  TCL_CONVERT_SYNTAX: source is not conformant to encoding definition
 *	  TCL_CONVERT_UNKNOWN: source contained a character that could not
 *	      be represented in target encoding.
 *
 * Side effects:
 *	TCL_OK: The converted bytes are stored in the DString and NUL
 *	    terminated in an encoding-specific manner.
 *	TCL_ERROR: an error, message is stored in the interp if not NULL.
 *	TCL_CONVERT_*: if errorLocPtr is NULL, an error message is stored
 *	    in the interpreter (if not NULL). If errorLocPtr is not NULL,
 *	    no error message is stored as it is expected the caller is
 *	    interested in whatever is decoded so far and not treating this
 *	    as an error condition.
 *
 *	In addition, *dstPtr is always initialized and must be cleared
 *	by the caller irrespective of the return code.
 *
 *-------------------------------------------------------------------------
 */

int
Tcl_ExternalToUtfDStringEx(
    Tcl_Interp *interp,		/* For error messages. May be NULL. */
    Tcl_Encoding encoding,	/* The encoding for the source string, or NULL
				 * for the default system encoding. */
    const char *src,		/* Source string in specified encoding. */
    Tcl_Size srcLen,		/* Source string length in bytes, or < 0 for
				 * encoding-specific string length. */
    int flags,			/* Conversion control flags. */
    Tcl_DString *dstPtr,	/* Uninitialized or free DString in which the
				 * converted string is stored. */
    Tcl_Size *errorLocPtr)	/* Where to store the error location
				 * (or TCL_INDEX_NONE if no error). May
				 * be NULL. */
{
    char *dst;
    Tcl_EncodingState state;
    const Encoding *encodingPtr;
    int result;
    Tcl_Size dstLen, soFar;
    const char *srcStart = src;

    /* DO FIRST - Must always be initialized before returning */
    Tcl_DStringInit(dstPtr);

    dst = Tcl_DStringValue(dstPtr);
    dstLen = dstPtr->spaceAvl - 1;

    if (encoding == NULL) {
	encoding = systemEncoding;
    }
    encodingPtr = (Encoding *)encoding;

    if (src == NULL) {
	srcLen = 0;
    } else if (srcLen == TCL_INDEX_NONE) {
	srcLen = encodingPtr->lengthProc(src);
    }

    flags &= ~TCL_ENCODING_END;
    flags |= TCL_ENCODING_START;
    if (encodingPtr->toUtfProc == UtfToUtfProc) {
	flags |= ENCODING_INPUT;
    }

    while (1) {
	int srcChunkLen, srcChunkRead;
	int dstChunkLen, dstChunkWrote, dstChunkChars;

	if (srcLen > INT_MAX) {
	    srcChunkLen = INT_MAX;
	} else {
	    srcChunkLen = srcLen;
	    flags |= TCL_ENCODING_END; /* Last chunk */
	}
	dstChunkLen = dstLen > INT_MAX ? INT_MAX : dstLen;

	result = encodingPtr->toUtfProc(encodingPtr->clientData, src,
		srcChunkLen, flags, &state, dst, dstChunkLen,
		&srcChunkRead, &dstChunkWrote, &dstChunkChars);
	soFar = dst + dstChunkWrote - Tcl_DStringValue(dstPtr);

	src += srcChunkRead;

	/*
	 * Keep looping in two case -
	 *   - our destination buffer did not have enough room
	 *   - we had not passed in all the data and error indicated fragment
	 *     of a multibyte character
	 * In both cases we have to grow buffer, move the input source pointer
	 * and loop. Otherwise, return the result we got.
	 */
	if ((result != TCL_CONVERT_NOSPACE) &&
		(result != TCL_CONVERT_MULTIBYTE || (flags & TCL_ENCODING_END))) {
	    Tcl_Size nBytesProcessed = (src - srcStart);

	    Tcl_DStringSetLength(dstPtr, soFar);
	    if (errorLocPtr) {
		/*
		 * Do not write error message into interpreter if caller
		 * wants to know error location.
		 */
		*errorLocPtr = result == TCL_OK
			? TCL_INDEX_NONE : nBytesProcessed;
	    } else {
		/* Caller wants error message on failure */
		if (result != TCL_OK && interp != NULL) {
		    char buf[TCL_INTEGER_SPACE];
		    snprintf(buf, sizeof(buf), "%" TCL_SIZE_MODIFIER "d",
			    nBytesProcessed);
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "unexpected byte sequence starting at index %"
			    TCL_SIZE_MODIFIER "d: '\\x%02X'",
			    nBytesProcessed, UCHAR(srcStart[nBytesProcessed])));
		    Tcl_SetErrorCode(
			    interp, "TCL", "ENCODING", "ILLEGALSEQUENCE", buf,
			    (char *)NULL);
		}
	    }
	    if (result != TCL_OK) {
		errno = (result == TCL_CONVERT_NOSPACE) ? ENOMEM : EILSEQ;
	    }
	    return result;
	}

	/* Expand space and continue */
	flags &= ~TCL_ENCODING_START;
	srcLen -= srcChunkRead;
	if (Tcl_DStringLength(dstPtr) == 0) {
	    Tcl_DStringSetLength(dstPtr, dstLen);
	}
	Tcl_DStringSetLength(dstPtr, 2 * Tcl_DStringLength(dstPtr) + 1);
	dst = Tcl_DStringValue(dstPtr) + soFar;
	dstLen = Tcl_DStringLength(dstPtr) - soFar - 1;
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_ExternalToUtf --
 *
 *	Convert a source buffer from the specified encoding into UTF-8.
 *
 * Results:
 *	The return value is one of TCL_OK, TCL_CONVERT_MULTIBYTE,
 *	TCL_CONVERT_SYNTAX, TCL_CONVERT_UNKNOWN, or TCL_CONVERT_NOSPACE, as
 *	documented in tcl.h.
 *
 * Side effects:
 *	The converted bytes are stored in the output buffer.
 *
 *-------------------------------------------------------------------------
 */

int
Tcl_ExternalToUtf(
    TCL_UNUSED(Tcl_Interp *),	/* TODO: Re-examine this. */
    Tcl_Encoding encoding,	/* The encoding for the source string, or NULL
				 * for the default system encoding. */
    const char *src,		/* Source string in specified encoding. */
    Tcl_Size srcLen,		/* Source string length in bytes, or
				 * TCL_INDEX_NONE for encoding-specific string
				 * length. */
    int flags,			/* Conversion control flags. */
    Tcl_EncodingState *statePtr,/* Place for conversion routine to store state
				 * information used during a piecewise
				 * conversion. Contents of statePtr are
				 * initialized and/or reset by conversion
				 * routine under control of flags argument. */
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    Tcl_Size dstLen,		/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const Encoding *encodingPtr;
    int result, srcRead, dstWrote, dstChars = 0;
    int noTerminate = flags & TCL_ENCODING_NO_TERMINATE;
    int charLimited = (flags & TCL_ENCODING_CHAR_LIMIT) && dstCharsPtr;
    int maxChars = INT_MAX;
    Tcl_EncodingState state;

    if (encoding == NULL) {
	encoding = systemEncoding;
    }
    encodingPtr = (Encoding *) encoding;

    if (src == NULL) {
	srcLen = 0;
    } else if (srcLen == TCL_INDEX_NONE) {
	srcLen = encodingPtr->lengthProc(src);
    }
    if (statePtr == NULL) {
	flags |= TCL_ENCODING_START | TCL_ENCODING_END;
	statePtr = &state;
    }
    if (srcLen > INT_MAX) {
	srcLen = INT_MAX;
	flags &= ~TCL_ENCODING_END;
    }
    if (dstLen > INT_MAX) {
	dstLen = INT_MAX;
    }
    if (srcReadPtr == NULL) {
	srcReadPtr = &srcRead;
    }
    if (dstWrotePtr == NULL) {
	dstWrotePtr = &dstWrote;
    }
    if (dstCharsPtr == NULL) {
	dstCharsPtr = &dstChars;
	flags &= ~TCL_ENCODING_CHAR_LIMIT;
    } else if (charLimited) {
	maxChars = *dstCharsPtr;
    }

    if (!noTerminate) {
	if (dstLen < 1) {
	    return TCL_CONVERT_NOSPACE;
	}
	/*
	 * If there are any null characters in the middle of the buffer,
	 * they will converted to the UTF-8 null character (\xC0\x80). To get
	 * the actual \0 at the end of the destination buffer, we need to
	 * append it manually.  First make room for it...
	 */

	dstLen--;
    } else {
	if (dstLen <= 0 && srcLen > 0) {
	    return TCL_CONVERT_NOSPACE;
	}
    }
    if (encodingPtr->toUtfProc == UtfToUtfProc) {
	flags |= ENCODING_INPUT;
    }
    do {
	Tcl_EncodingState savedState = *statePtr;

	result = encodingPtr->toUtfProc(encodingPtr->clientData, src, srcLen,
		flags, statePtr, dst, dstLen, srcReadPtr, dstWrotePtr,
		dstCharsPtr);
	if (*dstCharsPtr <= maxChars) {
	    break;
	}
	dstLen = Tcl_UtfAtIndex(dst, maxChars) - dst + (TCL_UTF_MAX - 1);
	*statePtr = savedState;
    } while (1);
    if (!noTerminate) {
	/* ...and then append it */

	dst[*dstWrotePtr] = '\0';
    }

    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_UtfToExternalDString --
 *
 *	Convert a source buffer from UTF-8 to the specified encoding. If any
 *	of the bytes in the source buffer are invalid or cannot be represented
 *	in the target encoding, a default fallback character is substituted.
 *
 * Results:
 *	The converted bytes are stored in the DString, which is then NULL
 *	terminated in an encoding-specific manner. The return value is a
 *	pointer to the value stored in the DString.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */
#undef Tcl_UtfToExternalDString
char *
Tcl_UtfToExternalDString(
    Tcl_Encoding encoding,	/* The encoding for the converted string, or
				 * NULL for the default system encoding. */
    const char *src,		/* Source string in UTF-8. */
    Tcl_Size srcLen,		/* Source string length in bytes, or < 0 for
				 * strlen(). */
    Tcl_DString *dstPtr)	/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
    Tcl_UtfToExternalDStringEx(
	NULL, encoding, src, srcLen, TCL_ENCODING_PROFILE_TCL8, dstPtr, NULL);
    return Tcl_DStringValue(dstPtr);
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_UtfToExternalDStringEx --
 *
 *	Convert a source buffer from UTF-8 to the specified encoding.
 *	The parameter flags controls the behavior, if any of the bytes in
 *	the source buffer are invalid or cannot be represented in the
 *	target encoding. It should be composed by OR-ing the following:
 *	- *At most one* of TCL_ENCODING_PROFILE_*
 *
 * Results:
 *	The return value is one of
 *	  TCL_OK: success. Converted string in *dstPtr
 *	  TCL_ERROR: error in passed parameters. Error message in interp
 *	  TCL_CONVERT_MULTIBYTE: source ends in truncated multibyte sequence
 *	  TCL_CONVERT_SYNTAX: source is not conformant to encoding definition
 *	  TCL_CONVERT_UNKNOWN: source contained a character that could not
 *	      be represented in target encoding.
 *
 * Side effects:
 *	TCL_OK: The converted bytes are stored in the DString and NUL
 *	    terminated in an encoding-specific manner
 *	TCL_ERROR: an error, message is stored in the interp if not NULL.
 *	TCL_CONVERT_*: if errorLocPtr is NULL, an error message is stored
 *	    in the interpreter (if not NULL). If errorLocPtr is not NULL,
 *	    no error message is stored as it is expected the caller is
 *	    interested in whatever is decoded so far and not treating this
 *	    as an error condition.
 *
 *	In addition, *dstPtr is always initialized and must be cleared
 *	by the caller irrespective of the return code.
 *
 *-------------------------------------------------------------------------
 */

int
Tcl_UtfToExternalDStringEx(
    Tcl_Interp *interp,		/* For error messages. May be NULL. */
    Tcl_Encoding encoding,	/* The encoding for the converted string, or
				 * NULL for the default system encoding. */
    const char *src,		/* Source string in UTF-8. */
    Tcl_Size srcLen,		/* Source string length in bytes, or < 0 for
				 * strlen(). */
    int flags,			/* Conversion control flags. */
    Tcl_DString *dstPtr,	/* Uninitialized or free DString in which the
				 * converted string is stored. */
    Tcl_Size *errorLocPtr)	/* Where to store the error location
				 * (or TCL_INDEX_NONE if no error). May
				 * be NULL. */
{
    char *dst;
    Tcl_EncodingState state;
    const Encoding *encodingPtr;
    int result;
    const char *srcStart = src;
    Tcl_Size dstLen, soFar;

    /* DO FIRST - must always be initialized on return */
    Tcl_DStringInit(dstPtr);

    dst = Tcl_DStringValue(dstPtr);
    dstLen = dstPtr->spaceAvl - 1;

    if (encoding == NULL) {
	encoding = systemEncoding;
    }
    encodingPtr = (Encoding *) encoding;

    if (src == NULL) {
	srcLen = 0;
    } else if (srcLen == TCL_INDEX_NONE) {
	srcLen = strlen(src);
    }

    flags &= ~TCL_ENCODING_END;
    flags |= TCL_ENCODING_START;
    while (1) {
	int srcChunkLen, srcChunkRead;
	int dstChunkLen, dstChunkWrote, dstChunkChars;

	if (srcLen > INT_MAX) {
	    srcChunkLen = INT_MAX;
	} else {
	    srcChunkLen = srcLen;
	    flags |= TCL_ENCODING_END; /* Last chunk */
	}
	dstChunkLen = dstLen > INT_MAX ? INT_MAX : dstLen;

	result = encodingPtr->fromUtfProc(encodingPtr->clientData, src,
		srcChunkLen, flags, &state, dst, dstChunkLen,
		&srcChunkRead, &dstChunkWrote, &dstChunkChars);
	soFar = dst + dstChunkWrote - Tcl_DStringValue(dstPtr);

	/* Move past the part processed in this go around */
	src += srcChunkRead;

	/*
	 * Keep looping in two case -
	 *   - our destination buffer did not have enough room
	 *   - we had not passed in all the data and error indicated fragment
	 *     of a multibyte character
	 * In both cases we have to grow buffer, move the input source pointer
	 * and loop. Otherwise, return the result we got.
	 */
	if ((result != TCL_CONVERT_NOSPACE) &&
		(result != TCL_CONVERT_MULTIBYTE || (flags & TCL_ENCODING_END))) {
	    Tcl_Size nBytesProcessed = (src - srcStart);
	    Tcl_Size i = soFar + encodingPtr->nullSize - 1;
	    /* Loop as DStringSetLength only stores one nul byte at a time */
	    while (i >= soFar) {
		Tcl_DStringSetLength(dstPtr, i--);
	    }
	    if (errorLocPtr) {
		/*
		 * Do not write error message into interpreter if caller
		 * wants to know error location.
		 */
		*errorLocPtr = result == TCL_OK
			? TCL_INDEX_NONE : nBytesProcessed;
	    } else {
		/* Caller wants error message on failure */
		if (result != TCL_OK && interp != NULL) {
		    Tcl_Size pos = Tcl_NumUtfChars(srcStart, nBytesProcessed);
		    int ucs4;
		    char buf[TCL_INTEGER_SPACE];

		    TclUtfToUniChar(&srcStart[nBytesProcessed], &ucs4);
		    snprintf(buf, sizeof(buf), "%" TCL_SIZE_MODIFIER "d",
			    nBytesProcessed);
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "unexpected character at index %" TCL_SIZE_MODIFIER
			    "u: 'U+%06X'",
			    pos, ucs4));
		    Tcl_SetErrorCode(interp, "TCL", "ENCODING", "ILLEGALSEQUENCE",
			    buf, (char *)NULL);
		}
	    }
	    if (result != TCL_OK) {
		errno = (result == TCL_CONVERT_NOSPACE) ? ENOMEM : EILSEQ;
	    }
	    return result;
	}

	flags &= ~TCL_ENCODING_START;
	srcLen -= srcChunkRead;

	if (Tcl_DStringLength(dstPtr) == 0) {
	    Tcl_DStringSetLength(dstPtr, dstLen);
	}
	Tcl_DStringSetLength(dstPtr, 2 * Tcl_DStringLength(dstPtr) + 1);
	dst = Tcl_DStringValue(dstPtr) + soFar;
	dstLen = Tcl_DStringLength(dstPtr) - soFar - 1;
    }
}

/*
 *-------------------------------------------------------------------------
 *
 * Tcl_UtfToExternal --
 *
 *	Convert a buffer from UTF-8 into the specified encoding.
 *
 * Results:
 *	The return value is one of TCL_OK, TCL_CONVERT_MULTIBYTE,
 *	TCL_CONVERT_SYNTAX, TCL_CONVERT_UNKNOWN, or TCL_CONVERT_NOSPACE, as
 *	documented in tcl.h.
 *
 * Side effects:
 *	The converted bytes are stored in the output buffer.
 *
 *-------------------------------------------------------------------------
 */

int
Tcl_UtfToExternal(
    TCL_UNUSED(Tcl_Interp *),	/* TODO: Re-examine this. */
    Tcl_Encoding encoding,	/* The encoding for the converted string, or
				 * NULL for the default system encoding. */
    const char *src,		/* Source string in UTF-8. */
    Tcl_Size srcLen,		/* Source string length in bytes, or
				 * TCL_INDEX_NONE for strlen(). */
    int flags,			/* Conversion control flags. */
    Tcl_EncodingState *statePtr,/* Place for conversion routine to store state
				 * information used during a piecewise
				 * conversion. Contents of statePtr are
				 * initialized and/or reset by conversion
				 * routine under control of flags argument. */
    char *dst,			/* Output buffer in which converted string
				 * is stored. */
    Tcl_Size dstLen,		/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const Encoding *encodingPtr;
    int result, srcRead, dstWrote, dstChars;
    Tcl_EncodingState state;

    if (encoding == NULL) {
	encoding = systemEncoding;
    }
    encodingPtr = (Encoding *) encoding;

    if (src == NULL) {
	srcLen = 0;
    } else if (srcLen == TCL_INDEX_NONE) {
	srcLen = strlen(src);
    }
    if (statePtr == NULL) {
	flags |= TCL_ENCODING_START | TCL_ENCODING_END;
	statePtr = &state;
    }
    if (srcLen > INT_MAX) {
	srcLen = INT_MAX;
	flags &= ~TCL_ENCODING_END;
    }
    if (dstLen > INT_MAX) {
	dstLen = INT_MAX;
    }
    if (srcReadPtr == NULL) {
	srcReadPtr = &srcRead;
    }
    if (dstWrotePtr == NULL) {
	dstWrotePtr = &dstWrote;
    }
    if (dstCharsPtr == NULL) {
	dstCharsPtr = &dstChars;
    }

    if (dstLen < encodingPtr->nullSize) {
	return TCL_CONVERT_NOSPACE;
    }
    dstLen -= encodingPtr->nullSize;
    result = encodingPtr->fromUtfProc(encodingPtr->clientData, src, srcLen,
	    flags, statePtr, dst, dstLen, srcReadPtr,
	    dstWrotePtr, dstCharsPtr);
    /*
     * Buffer is terminated irrespective of result. Not sure this is
     * reasonable but keep for historical/compatibility reasons.
     */
    memset(&dst[*dstWrotePtr], '\0', encodingPtr->nullSize);

    return result;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_FindExecutable --
 *
 *	This function computes the absolute path name of the current
 *	application, given its argv[0] value.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The absolute pathname for the application is computed and stored to be
 *	returned later by [info nameofexecutable].
 *
 *---------------------------------------------------------------------------
 */
#undef Tcl_FindExecutable
const char *
Tcl_FindExecutable(
    const char *argv0)		/* The value of the application's argv[0]
				 * (native). */
{
    const char *version = Tcl_InitSubsystems();
    TclpSetInitialEncodings();
    TclpFindExecutable(argv0);
    return version;
}

/*
 *---------------------------------------------------------------------------
 *
 * OpenEncodingFileChannel --
 *
 *	Open the file believed to hold data for the encoding, "name".
 *
 * Results:
 *	Returns the readable Tcl_Channel from opening the file, or NULL if the
 *	file could not be successfully opened. If NULL was returned, an error
 *	message is left in interp's result object, unless interp was NULL.
 *
 * Side effects:
 *	Channel may be opened. Information about the filesystem may be cached
 *	to speed later calls.
 *
 *---------------------------------------------------------------------------
 */

static Tcl_Channel
OpenEncodingFileChannel(
    Tcl_Interp *interp,		/* Interp for error reporting, if not NULL. */
    const char *name)		/* The name of the encoding file on disk and
				 * also the name for new encoding. */
{
    Tcl_Obj *fileNameObj = Tcl_ObjPrintf("%s.enc", name);
    Tcl_Obj *searchPath = Tcl_DuplicateObj(Tcl_GetEncodingSearchPath());
    Tcl_Obj *map = TclGetProcessGlobalValue(&encodingFileMap);
    Tcl_Obj **dir, *path, *directory = NULL;
    Tcl_Channel chan = NULL;
    Tcl_Size i, numDirs;

    TclListObjGetElements(NULL, searchPath, &numDirs, &dir);
    Tcl_IncrRefCount(fileNameObj);
    TclDictGet(NULL, map, name, &directory);

    /*
     * Check that any cached directory is still on the encoding search path.
     */

    if (NULL != directory) {
	int verified = 0;

	for (i=0; i<numDirs && !verified; i++) {
	    if (dir[i] == directory) {
		verified = 1;
	    }
	}
	if (!verified) {
	    const char *dirString = TclGetString(directory);

	    for (i=0; i<numDirs && !verified; i++) {
		if (strcmp(dirString, TclGetString(dir[i])) == 0) {
		    verified = 1;
		}
	    }
	}
	if (!verified) {
	    /*
	     * Directory no longer on the search path. Remove from cache.
	     */

	    map = Tcl_DuplicateObj(map);
	    TclDictRemove(NULL, map, name);
	    TclSetProcessGlobalValue(&encodingFileMap, map);
	    directory = NULL;
	}
    }

    if (NULL != directory) {
	/*
	 * Got a directory from the cache. Try to use it first.
	 */

	Tcl_IncrRefCount(directory);
	path = Tcl_FSJoinToPath(directory, 1, &fileNameObj);
	Tcl_IncrRefCount(path);
	Tcl_DecrRefCount(directory);
	chan = Tcl_FSOpenFileChannel(NULL, path, "r", 0);
	Tcl_DecrRefCount(path);
    }

    /*
     * Scan the search path until we find it.
     */

    for (i=0; i<numDirs && (chan == NULL); i++) {
	path = Tcl_FSJoinToPath(dir[i], 1, &fileNameObj);
	Tcl_IncrRefCount(path);
	chan = Tcl_FSOpenFileChannel(NULL, path, "r", 0);
	Tcl_DecrRefCount(path);
	if (chan != NULL) {
	    /*
	     * Save directory in the cache.
	     */

	    map = Tcl_DuplicateObj(TclGetProcessGlobalValue(&encodingFileMap));
	    TclDictPut(NULL, map, name, dir[i]);
	    TclSetProcessGlobalValue(&encodingFileMap, map);
	}
    }

    if ((NULL == chan) && (interp != NULL)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unknown encoding \"%s\"", name));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "ENCODING", name, (char *)NULL);
    }
    Tcl_DecrRefCount(fileNameObj);
    Tcl_DecrRefCount(searchPath);

    return chan;
}

/*
 *---------------------------------------------------------------------------
 *
 * LoadEncodingFile --
 *
 *	Read a file that describes an encoding and create a new Encoding from
 *	the data.
 *
 * Results:
 *	The return value is the newly loaded Tcl_Encoding or NULL if the file
 *	didn't exist or could not be processed. If NULL is returned and interp
 *	is not NULL, an error message is left in interp's result object.
 *
 * Side effects:
 *	A corresponding encoding file might be read from persistent storage, in
 *	which case LoadTableEncoding is called.
 *
 *---------------------------------------------------------------------------
 */

static Tcl_Encoding
LoadEncodingFile(
    Tcl_Interp *interp,		/* Interp for error reporting, if not NULL. */
    const char *name)		/* The name of both the encoding file
				 * and the new encoding. */
{
    Tcl_Channel chan = NULL;
    Tcl_Encoding encoding = NULL;
    int ch;

    chan = OpenEncodingFileChannel(interp, name);
    if (chan == NULL) {
	return NULL;
    }

    Tcl_SetChannelOption(NULL, chan, "-encoding", "utf-8");

    while (1) {
	Tcl_DString ds;

	Tcl_DStringInit(&ds);
	Tcl_Gets(chan, &ds);
	ch = Tcl_DStringValue(&ds)[0];
	Tcl_DStringFree(&ds);
	if (ch != '#') {
	    break;
	}
    }

    switch (ch) {
    case 'S':
	encoding = LoadTableEncoding(name, ENCODING_SINGLEBYTE, chan);
	break;
    case 'D':
	encoding = LoadTableEncoding(name, ENCODING_DOUBLEBYTE, chan);
	break;
    case 'M':
	encoding = LoadTableEncoding(name, ENCODING_MULTIBYTE, chan);
	break;
    case 'E':
	encoding = LoadEscapeEncoding(name, chan);
	break;
    }
    if ((encoding == NULL) && (interp != NULL)) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"invalid encoding file \"%s\"", name));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "ENCODING", name, (char *)NULL);
    }
    Tcl_CloseEx(NULL, chan, 0);

    return encoding;
}

/*
 *-------------------------------------------------------------------------
 *
 * LoadTableEncoding --
 *
 *	Helper function for LoadEncodingFile().  Creates a Tcl_EncodingType
 *	structure along with its corresponding TableEncodingData structure, and
 *	passes it to Tcl_Createncoding.
 *
 *	The file contains binary data but begins with a marker to indicate
 *	byte-ordering so a single binary file can be read on big or
 *	little-endian systems.
 *
 * Results:
 *	Returns the new Tcl_Encoding,  or NULL if it could
 *	not be created because the file contained invalid data.
 *
 * Side effects:
 *	See Tcl_CreateEncoding().
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Encoding
LoadTableEncoding(
    const char *name,		/* Name of the new encoding. */
    int type,			/* Type of encoding (ENCODING_?????). */
    Tcl_Channel chan)		/* File containing new encoding. */
{
    Tcl_DString lineString;
    Tcl_Obj *objPtr;
    char *line;
    int i, hi, lo, numPages, symbol, fallback, len;
    unsigned char used[256];
    unsigned size;
    TableEncodingData *dataPtr;
    unsigned short *pageMemPtr, *page;
    Tcl_EncodingType encType;

    /*
     * Speed over memory. Use a full 256 character table to decode hex
     * sequences in the encoding files.
     */

    static const char staticHex[] = {
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*   0 ...  15 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*  16 ...  31 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*  32 ...  47 */
      0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 0, 0, 0, 0, 0, 0, /*  48 ...  63 */
      0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*  64 ...  79 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*  80 ...  95 */
      0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, /*  96 ... 111 */
      0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 0, 0, 0, 0, 0, 0, /* 112 ... 127 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 128 ... 143 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 144 ... 159 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 160 ... 175 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 176 ... 191 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 192 ... 207 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 208 ... 223 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 224 ... 239 */
      0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 240 ... 255 */
    };

    Tcl_DStringInit(&lineString);
    if (Tcl_Gets(chan, &lineString) < 0) {
	return NULL;
    }
    line = Tcl_DStringValue(&lineString);

    fallback = (int) strtol(line, &line, 16);
    symbol = (int) strtol(line, &line, 10);
    numPages = (int) strtol(line, &line, 10);
    Tcl_DStringFree(&lineString);

    if (numPages < 0) {
	numPages = 0;
    } else if (numPages > 256) {
	numPages = 256;
    }

    memset(used, 0, sizeof(used));

#undef PAGESIZE
#define PAGESIZE    (256 * sizeof(unsigned short))

    dataPtr = (TableEncodingData *)Tcl_Alloc(sizeof(TableEncodingData));
    memset(dataPtr, 0, sizeof(TableEncodingData));

    dataPtr->fallback = fallback;

    /*
     * Read the table that maps characters to Unicode. Performs a single
     * malloc to get the memory for the array and all the pages needed by the
     * array.
     */

    size = 256 * sizeof(unsigned short *) + numPages * PAGESIZE;
    dataPtr->toUnicode = (unsigned short **)Tcl_Alloc(size);
    memset(dataPtr->toUnicode, 0, size);
    pageMemPtr = (unsigned short *) (dataPtr->toUnicode + 256);

    TclNewObj(objPtr);
    Tcl_IncrRefCount(objPtr);
    for (i = 0; i < numPages; i++) {
	int ch;
	const char *p;
	Tcl_Size expected = 3 + 16 * (16 * 4 + 1);

	if (Tcl_ReadChars(chan, objPtr, expected, 0) != expected) {
	    return NULL;
	}
	p = TclGetString(objPtr);
	hi = (staticHex[UCHAR(p[0])] << 4) + staticHex[UCHAR(p[1])];
	dataPtr->toUnicode[hi] = pageMemPtr;
	p += 2;
	for (lo = 0; lo < 256; lo++) {
	    if ((lo & 0x0F) == 0) {
		p++;
	    }
	    ch = (staticHex[UCHAR(p[0])] << 12) + (staticHex[UCHAR(p[1])] << 8)
		    + (staticHex[UCHAR(p[2])] << 4) + staticHex[UCHAR(p[3])];
	    if (ch != 0) {
		used[ch >> 8] = 1;
	    }
	    *pageMemPtr = (unsigned short) ch;
	    pageMemPtr++;
	    p += 4;
	}
    }
    TclDecrRefCount(objPtr);

    if (type == ENCODING_DOUBLEBYTE) {
	memset(dataPtr->prefixBytes, 1, sizeof(dataPtr->prefixBytes));
    } else {
	for (hi = 1; hi < 256; hi++) {
	    if (dataPtr->toUnicode[hi] != NULL) {
		dataPtr->prefixBytes[hi] = 1;
	    }
	}
    }

    /*
     * Invert the toUnicode array to produce the fromUnicode array. Performs a
     * single malloc to get the memory for the array and all the pages needed
     * by the array. While reading in the toUnicode array remember what
     * pages are needed for the fromUnicode array.
     */

    if (symbol) {
	used[0] = 1;
    }
    numPages = 0;
    for (hi = 0; hi < 256; hi++) {
	if (used[hi]) {
	    numPages++;
	}
    }
    size = 256 * sizeof(unsigned short *) + numPages * PAGESIZE;
    dataPtr->fromUnicode = (unsigned short **)Tcl_Alloc(size);
    memset(dataPtr->fromUnicode, 0, size);
    pageMemPtr = (unsigned short *) (dataPtr->fromUnicode + 256);

    for (hi = 0; hi < 256; hi++) {
	if (dataPtr->toUnicode[hi] == NULL) {
	    dataPtr->toUnicode[hi] = emptyPage;
	    continue;
	}
	for (lo = 0; lo < 256; lo++) {
	    int ch = dataPtr->toUnicode[hi][lo];

	    if (ch != 0) {
		page = dataPtr->fromUnicode[ch >> 8];
		if (page == NULL) {
		    page = pageMemPtr;
		    pageMemPtr += 256;
		    dataPtr->fromUnicode[ch >> 8] = page;
		}
		page[ch & 0xFF] = (unsigned short) ((hi << 8) + lo);
	    }
	}
    }
    if (type == ENCODING_MULTIBYTE) {
	/*
	 * If multibyte encodings don't have a backslash character, define
	 * one. Otherwise, on Windows, native file names don't work because
	 * the backslash in the file name maps to the unknown character
	 * (question mark) when converting from UTF-8 to external encoding.
	 */

	if (dataPtr->fromUnicode[0] != NULL) {
	    if (dataPtr->fromUnicode[0][(int)'\\'] == '\0') {
		dataPtr->fromUnicode[0][(int)'\\'] = '\\';
	    }
	}
    }
    if (symbol) {
	/*
	 * Make a special symbol encoding that maps each symbol character from
	 * its Unicode code point down into page 0, and also ensure that each
	 * characters on page 0 maps to itself so that a symbol font can be
	 * used to display a simple string like "abcd" and have alpha, beta,
	 * chi, delta show up, rather than have "unknown" chars show up because
	 * strictly speaking the symbol font doesn't have glyphs for those low
	 * ASCII chars.
	 */

	page = dataPtr->fromUnicode[0];
	if (page == NULL) {
	    page = pageMemPtr;
	    dataPtr->fromUnicode[0] = page;
	}
	for (lo = 0; lo < 256; lo++) {
	    if (dataPtr->toUnicode[0][lo] != 0) {
		page[lo] = (unsigned short) lo;
	    }
	}
    }
    for (hi = 0; hi < 256; hi++) {
	if (dataPtr->fromUnicode[hi] == NULL) {
	    dataPtr->fromUnicode[hi] = emptyPage;
	}
    }

    /*
     * For trailing 'R'everse encoding, see [Patch 689341]
     */

    Tcl_DStringInit(&lineString);

    /*
     * Skip leading empty lines.
     */

    while ((len = Tcl_Gets(chan, &lineString)) == 0) {
	/* empty body */
    }
    if (len < 0) {
	goto doneParse;
    }

    /*
     * Require that it starts with an 'R'.
     */

    line = Tcl_DStringValue(&lineString);
    if (line[0] != 'R') {
	goto doneParse;
    }

    /*
     * Read lines until EOF.
     */

    for (TclDStringClear(&lineString);
	    (len = Tcl_Gets(chan, &lineString)) != -1;
	    TclDStringClear(&lineString)) {
	const unsigned char *p;
	int to, from;

	/*
	 * Skip short lines.
	 */

	if (len < 5) {
	    continue;
	}

	/*
	 * Parse the line as a sequence of hex digits.
	 */

	p = (const unsigned char *) Tcl_DStringValue(&lineString);
	to = (staticHex[p[0]] << 12) + (staticHex[p[1]] << 8)
		+ (staticHex[p[2]] << 4) + staticHex[p[3]];
	if (to == 0) {
	    continue;
	}
	for (p += 5, len -= 5; len >= 0 && *p; p += 5, len -= 5) {
	    from = (staticHex[p[0]] << 12) + (staticHex[p[1]] << 8)
		    + (staticHex[p[2]] << 4) + staticHex[p[3]];
	    if (from == 0) {
		continue;
	    }
	    dataPtr->fromUnicode[from >> 8][from & 0xFF] = to;
	}
    }
  doneParse:
    Tcl_DStringFree(&lineString);

    /*
     * Package everything into an encoding structure.
     */

    encType.encodingName    = name;
    encType.toUtfProc	    = TableToUtfProc;
    encType.fromUtfProc	    = TableFromUtfProc;
    encType.freeProc	    = TableFreeProc;
    encType.nullSize	    = (type == ENCODING_DOUBLEBYTE) ? 2 : 1;
    encType.clientData	    = dataPtr;

    return Tcl_CreateEncoding(&encType);
}

/*
 *-------------------------------------------------------------------------
 *
 * LoadEscapeEncoding --
 *
 *	Helper function for LoadEncodingTable(). Loads a state machine that
 *	converts between Unicode and some other encoding.
 *
 *	File contains text data that describes the escape sequences that are
 *	used to choose an encoding and the associated names for the
 *	sub-encodings.
 *
 * Results:
 *	The return value is the new encoding, or NULL if the encoding could
 *	not be created (because the file contained invalid data).
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static Tcl_Encoding
LoadEscapeEncoding(
    const char *name,		/* Name of the new encoding. */
    Tcl_Channel chan)		/* File containing new encoding. */
{
    int i;
    unsigned size;
    Tcl_DString escapeData;
    char init[16], final[16];
    EscapeEncodingData *dataPtr;
    Tcl_EncodingType type;

    init[0] = '\0';
    final[0] = '\0';
    Tcl_DStringInit(&escapeData);

    while (1) {
	Tcl_Size argc;
	const char **argv;
	char *line;
	Tcl_DString lineString;

	Tcl_DStringInit(&lineString);
	if (Tcl_Gets(chan, &lineString) < 0) {
	    break;
	}
	line = Tcl_DStringValue(&lineString);
	if (Tcl_SplitList(NULL, line, &argc, &argv) != TCL_OK) {
	    Tcl_DStringFree(&lineString);
	    continue;
	}
	if (argc >= 2) {
	    if (strcmp(argv[0], "name") == 0) {
		/* do nothing */
	    } else if (strcmp(argv[0], "init") == 0) {
		strncpy(init, argv[1], sizeof(init));
		init[sizeof(init) - 1] = '\0';
	    } else if (strcmp(argv[0], "final") == 0) {
		strncpy(final, argv[1], sizeof(final));
		final[sizeof(final) - 1] = '\0';
	    } else {
		EscapeSubTable est;
		Encoding *e;

		strncpy(est.sequence, argv[1], sizeof(est.sequence));
		est.sequence[sizeof(est.sequence) - 1] = '\0';
		est.sequenceLen = strlen(est.sequence);

		strncpy(est.name, argv[0], sizeof(est.name));
		est.name[sizeof(est.name) - 1] = '\0';

		/*
		 * To avoid infinite recursion in [encoding system iso2022-*]
		 */

		e = (Encoding *) Tcl_GetEncoding(NULL, est.name);
		if ((e != NULL) && (e->toUtfProc != TableToUtfProc)
			&& (e->toUtfProc != Iso88591ToUtfProc)) {
		    Tcl_FreeEncoding((Tcl_Encoding) e);
		    e = NULL;
		}
		est.encodingPtr = e;
		Tcl_DStringAppend(&escapeData, (char *) &est, sizeof(est));
	    }
	}
	Tcl_Free(argv);
	Tcl_DStringFree(&lineString);
    }

    size = offsetof(EscapeEncodingData, subTables)
	    + Tcl_DStringLength(&escapeData);
    dataPtr = (EscapeEncodingData *)Tcl_Alloc(size);
    dataPtr->initLen = strlen(init);
    memcpy(dataPtr->init, init, dataPtr->initLen + 1);
    dataPtr->finalLen = strlen(final);
    memcpy(dataPtr->final, final, dataPtr->finalLen + 1);
    dataPtr->numSubTables =
	    Tcl_DStringLength(&escapeData) / sizeof(EscapeSubTable);
    memcpy(dataPtr->subTables, Tcl_DStringValue(&escapeData),
	    Tcl_DStringLength(&escapeData));
    Tcl_DStringFree(&escapeData);

    memset(dataPtr->prefixBytes, 0, sizeof(dataPtr->prefixBytes));
    for (i = 0; i < dataPtr->numSubTables; i++) {
	dataPtr->prefixBytes[UCHAR(dataPtr->subTables[i].sequence[0])] = 1;
    }
    if (dataPtr->init[0] != '\0') {
	dataPtr->prefixBytes[UCHAR(dataPtr->init[0])] = 1;
    }
    if (dataPtr->final[0] != '\0') {
	dataPtr->prefixBytes[UCHAR(dataPtr->final[0])] = 1;
    }

    /*
     * Package everything into an encoding structure.
     */

    type.encodingName	= name;
    type.toUtfProc	= EscapeToUtfProc;
    type.fromUtfProc    = EscapeFromUtfProc;
    type.freeProc	= EscapeFreeProc;
    type.nullSize	= 1;
    type.clientData	= dataPtr;

    return Tcl_CreateEncoding(&type);
}

/*
 *-------------------------------------------------------------------------
 *
 * BinaryProc --
 *
 *	The default conversion when no other conversion is specified. No
 *	translation is done; source bytes are copied directly to destination
 *	bytes.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
BinaryProc(
    TCL_UNUSED(void *),
    const char *src,		/* Source string (unknown encoding). */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    int result;

    result = TCL_OK;
    dstLen -= TCL_UTF_MAX - 1;
    if (dstLen < 0) {
	dstLen = 0;
    }
    if ((flags & TCL_ENCODING_CHAR_LIMIT) && srcLen > *dstCharsPtr) {
	srcLen = *dstCharsPtr;
    }
    if (srcLen > dstLen) {
	srcLen = dstLen;
	result = TCL_CONVERT_NOSPACE;
    }

    *srcReadPtr = srcLen;
    *dstWrotePtr = srcLen;
    *dstCharsPtr = srcLen;
    memcpy(dst, src, srcLen);
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * UtfToUtfProc --
 *
 *	Converts from UTF-8 to UTF-8. Note that the UTF-8 to UTF-8 translation
 *	is not a no-op, because it turns a stream of improperly formed
 *	UTF-8 into a properly-formed stream.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
UtfToUtfProc(
    void *clientData,		/* additional flags */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* TCL_ENCODING_* conversion control flags. */
    Tcl_EncodingState *statePtr,/* Place for conversion routine to store state
				 * information used during a piecewise
				 * conversion. Contents of statePtr are
				 * initialized and/or reset by conversion
				 * routine under control of flags argument. */
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose;
    const char *dstStart, *dstEnd;
    int result, numChars, charLimit = INT_MAX;
    int ch;
    int profile;

    if (flags & TCL_ENCODING_START) {
	/* *statePtr will hold high surrogate in a split surrogate pair */
	*statePtr = 0;
    }
    result = TCL_OK;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= 6;
    }
    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }

    dstStart = dst;
    flags |= PTR2INT(clientData);

    /*
     * If output is UTF-8 or encoding for Tcl's internal encoding,
     * max space needed is TCL_UTF_MAX. Otherwise, need 6 bytes (CESU-8)
     */
    dstEnd = dst + dstLen - ((flags & (ENCODING_INPUT|ENCODING_UTF)) ? TCL_UTF_MAX : 6);

    /*
     * Macro to output an isolated high surrogate when it is not followed
     * by a low surrogate. NOT to be called for strict profile since
     * that should raise an error.
     */
#define OUTPUT_ISOLATEDSURROGATE                                \
    do {                                                        \
	Tcl_UniChar high;                                       \
	if (PROFILE_REPLACE(profile)) {                         \
	    high = UNICODE_REPLACE_CHAR;                        \
	} else {                                                \
	    high = (Tcl_UniChar)(ptrdiff_t) *statePtr;          \
	}                                                       \
	assert(!(flags & ENCODING_UTF)); /* Must be CESU-8 */   \
	assert(HIGH_SURROGATE(high));                           \
	assert(!PROFILE_STRICT(profile));                       \
	dst += Tcl_UniCharToUtf(high, dst);                     \
	*statePtr = 0; /* Reset state */                        \
    } while (0)

    /*
     * Macro to check for isolated surrogate and either break with
     * an error if profile is strict, or output an appropriate
     * character for replace and tcl8 profiles and continue.
     */
#define CHECK_ISOLATEDSURROGATE                                         \
    if (*statePtr) {                                                    \
	if (PROFILE_STRICT(profile)) {                                  \
	    result = TCL_CONVERT_SYNTAX;                                \
	    break;                                                      \
	}                                                               \
	OUTPUT_ISOLATEDSURROGATE;                                       \
	continue; /* Rerun loop so length checks etc. repeated */       \
    } else                                                              \
	(void) 0

    profile = ENCODING_PROFILE_GET(flags);
    for (numChars = 0; src < srcEnd && numChars <= charLimit; numChars++) {

	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	if (UCHAR(*src) < 0x80 && !((UCHAR(*src) == 0) && (flags & ENCODING_INPUT))) {

	    CHECK_ISOLATEDSURROGATE;
	    /*
	     * Copy 7bit characters, but skip null-bytes when we are in input
	     * mode, so that they get converted to \xC0\x80.
	     */
	    *dst++ = *src++;
	} else if ((UCHAR(*src) == 0xC0) && (src + 1 < srcEnd) &&
		 (UCHAR(src[1]) == 0x80) &&
		 (!(flags & ENCODING_INPUT) || !PROFILE_TCL8(profile))) {
	    /* Special sequence \xC0\x80 */

	    CHECK_ISOLATEDSURROGATE;
	    if (!PROFILE_TCL8(profile) && (flags & ENCODING_INPUT)) {
		if (PROFILE_REPLACE(profile)) {
		    dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		    src += 2;
		} else {
		    /* PROFILE_STRICT */
		    result = TCL_CONVERT_SYNTAX;
		    break;
		}
	    } else {
		/*
		 * Convert 0xC080 to real nulls when we are in output mode,
		 * irrespective of the profile.
		 */
		*dst++ = 0;
		src += 2;
	    }

	} else if (!Tcl_UtfCharComplete(src, srcEnd - src)) {
	    /*
	     * Incomplete byte sequence not because there are insufficient
	     * bytes in source buffer (have already checked that above) but
	     * because the UTF-8 sequence is truncated.
	     */

	    CHECK_ISOLATEDSURROGATE;

	    if (flags & ENCODING_INPUT) {
		/* Incomplete bytes for modified UTF-8 target */
		if (PROFILE_STRICT(profile)) {
		    result = (flags & TCL_ENCODING_CHAR_LIMIT)
			    ? TCL_CONVERT_MULTIBYTE
			    : TCL_CONVERT_SYNTAX;
		    break;
		}
	    }
	    if (PROFILE_REPLACE(profile)) {
		ch = UNICODE_REPLACE_CHAR;
		++src;
	    } else {
		/* TCL_ENCODING_PROFILE_TCL8 */
		char chbuf[2];
		chbuf[0] = UCHAR(*src++);
		chbuf[1] = 0;
		TclUtfToUniChar(chbuf, &ch);
	    }
	    dst += Tcl_UniCharToUtf(ch, dst);
	} else {
	    /* Have a complete character */
	    size_t len = TclUtfToUniChar(src, &ch);

	    Tcl_UniChar savedSurrogate = (Tcl_UniChar) (ptrdiff_t)*statePtr;
	    *statePtr = 0; /* Reset surrogate */

	    if (flags & ENCODING_INPUT) {
		if (((len < 2) && (ch != 0)) || ((ch > 0xFFFF) && !(flags & ENCODING_UTF))) {
		    if (PROFILE_STRICT(profile)) {
			result = TCL_CONVERT_SYNTAX;
			break;
		    } else if (PROFILE_REPLACE(profile)) {
			ch = UNICODE_REPLACE_CHAR;
		    }
		}
	    }

	    const char *saveSrc = src;
	    src += len;
	    if (!(flags & ENCODING_UTF) && !(flags & ENCODING_INPUT)
		    && (ch > 0x7FF)) {
		assert(savedSurrogate == 0); /* Since this flag combo
						will never set *statePtr */
		if (ch > 0xFFFF) {
		    /* CESU-8 6-byte sequence for chars > U+FFFF */
		    ch -= 0x10000;
		    *dst++ = 0xED;
		    *dst++ = (char) (((ch >> 16) & 0x0F) | 0xA0);
		    *dst++ = (char) (((ch >> 10) & 0x3F) | 0x80);
		    ch = (ch & 0x03FF) | 0xDC00;
		}
		*dst++ = (char)(((ch >> 12) | 0xE0) & 0xEF);
		*dst++ = (char)(((ch >> 6) | 0x80) & 0xBF);
		*dst++ = (char)((ch | 0x80) & 0xBF);
		continue;
	    } else if (SURROGATE(ch)) {
		if ((flags & ENCODING_UTF)) {
		    /* UTF-8, not CESU-8, so surrogates should not appear */
		    if (PROFILE_STRICT(profile)) {
			result = (flags & ENCODING_INPUT)
			    ? TCL_CONVERT_SYNTAX : TCL_CONVERT_UNKNOWN;
			src = saveSrc;
			break;
		    } else if (PROFILE_REPLACE(profile)) {
			ch = UNICODE_REPLACE_CHAR;
		    } else {
			/* PROFILE_TCL8 - output as is */
		    }
		} else {
		    /* CESU-8 */
		    if (LOW_SURROGATE(ch)) {
			if (savedSurrogate) {
			    assert(HIGH_SURROGATE(savedSurrogate));
			    ch = 0x10000 + ((savedSurrogate - 0xd800) << 10) + (ch - 0xdc00);
			} else {
			    /* Isolated low surrogate */
			    if (PROFILE_STRICT(profile)) {
				result = (flags & ENCODING_INPUT)
				    ? TCL_CONVERT_SYNTAX : TCL_CONVERT_UNKNOWN;
				src = saveSrc;
				break;
			    } else if (PROFILE_REPLACE(profile)) {
				ch = UNICODE_REPLACE_CHAR;
			    } else {
				/* Tcl8 profile. Output low surrogate as is */
			    }
			}
		    } else {
			assert(HIGH_SURROGATE(ch));
			/* Save the high surrogate */
			*statePtr = (Tcl_EncodingState) (ptrdiff_t) ch;
			if (savedSurrogate) {
			    assert(HIGH_SURROGATE(savedSurrogate));
			    if (PROFILE_STRICT(profile)) {
				result = (flags & ENCODING_INPUT)
				    ? TCL_CONVERT_SYNTAX : TCL_CONVERT_UNKNOWN;
				src = saveSrc;
				break;
			    } else if (PROFILE_REPLACE(profile)) {
				ch = UNICODE_REPLACE_CHAR;
			    } else {
				/* Output the isolated high surrogate */
				ch = savedSurrogate;
			    }
			} else {
			    /* High surrogate saved in *statePtr. Do not output anything just yet. */
			    --numChars; /* Cancel the increment at end of loop */
			    continue;
			}
		    }
		}
	    } else {
		/* Normal character */
		CHECK_ISOLATEDSURROGATE;
	    }

	    dst += Tcl_UniCharToUtf(ch, dst);
	}
    }

    /* Check if an high surrogate left over */
    if (*statePtr) {
	assert(!(flags & ENCODING_UTF)); /* CESU-8, Not UTF-8 */
	if (!(flags & TCL_ENCODING_END)) {
	    /* More data coming */
	} else {
	    /* No more data coming */
	    if (PROFILE_STRICT(profile)) {
		result = (flags & ENCODING_INPUT)
		    ? TCL_CONVERT_SYNTAX : TCL_CONVERT_UNKNOWN;
	    } else {
		if (PROFILE_REPLACE(profile)) {
		    ch = UNICODE_REPLACE_CHAR;
		} else {
		    ch = (Tcl_UniChar) (ptrdiff_t) *statePtr;
		}
		if (dst < dstEnd) {
		    dst += Tcl_UniCharToUtf(ch, dst);
		    ++numChars;
		} else {
		    /* No room in destination */
		    result = TCL_CONVERT_NOSPACE;
		}
	    }
	}
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * Utf32ToUtfProc --
 *
 *	Convert from UTF-32 to UTF-8.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
Utf32ToUtfProc(
    void *clientData,		/* additional flags, e.g. TCL_ENCODING_LE */
    const char *src,		/* Source string in Unicode. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd;
    const char *dstEnd, *dstStart;
    int result, numChars, charLimit = INT_MAX;
    int ch = 0, bytesLeft = srcLen % 4;

    flags |= PTR2INT(clientData);
    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }
    result = TCL_OK;

    /*
     * Check alignment with utf-32 (4 == sizeof(UTF-32))
     */
    if (bytesLeft != 0) {
	/* We have a truncated code unit */
	result = TCL_CONVERT_MULTIBYTE;
	srcLen -= bytesLeft;
    }

    srcStart = src;
    srcEnd = src + srcLen;

    dstStart = dst;
    dstEnd = dst + dstLen - TCL_UTF_MAX;

    for (numChars = 0; src < srcEnd && numChars <= charLimit; numChars++) {
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}

	if (flags & TCL_ENCODING_LE) {
	    ch = (unsigned int)(src[3] & 0xFF) << 24 | (src[2] & 0xFF) << 16
		    | (src[1] & 0xFF) << 8 | (src[0] & 0xFF);
	} else {
	    ch = (unsigned int)(src[0] & 0xFF) << 24 | (src[1] & 0xFF) << 16
		    | (src[2] & 0xFF) << 8 | (src[3] & 0xFF);
	}
	if ((unsigned)ch > 0x10FFFF) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
		break;
	    }
	    ch = UNICODE_REPLACE_CHAR;
	} else if (SURROGATE(ch)) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
		break;
	    }
	    if (PROFILE_REPLACE(flags)) {
		ch = UNICODE_REPLACE_CHAR;
	    }
	}

	/*
	 * Special case for 1-byte utf chars for speed. Make sure we work with
	 * unsigned short-size data.
	 */

	if ((unsigned)ch - 1 < 0x7F) {
	    *dst++ = (ch & 0xFF);
	} else {
	    dst += Tcl_UniCharToUtf(ch, dst);
	}
	src += 4;
    }

    if ((flags & TCL_ENCODING_END) && (result == TCL_CONVERT_MULTIBYTE)) {
	/* We have a code fragment left-over at the end */
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	} else {
	    /* destination is not full, so we really are at the end now */
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
	    } else {
		/* PROFILE_REPLACE or PROFILE_TCL8 */
		result = TCL_OK;
		dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		numChars++;
		src += bytesLeft; /* Go past truncated code unit */
	    }
	}
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * UtfToUtf32Proc --
 *
 *	Convert from UTF-8 to UTF-32.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
UtfToUtf32Proc(
    void *clientData,		/* additional flags, e.g. TCL_ENCODING_LE */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose, *dstStart, *dstEnd;
    int result, numChars;
    int ch, len;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd = dst + dstLen - sizeof(Tcl_UniChar);
    flags |= PTR2INT(clientData);

    result = TCL_OK;
    for (numChars = 0; src < srcEnd; numChars++) {
	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);
	if (SURROGATE(ch)) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_UNKNOWN;
		break;
	    }
	    if (PROFILE_REPLACE(flags)) {
		ch = UNICODE_REPLACE_CHAR;
	    }
	}
	src += len;
	if (flags & TCL_ENCODING_LE) {
	    *dst++ = (ch & 0xFF);
	    *dst++ = ((ch >> 8) & 0xFF);
	    *dst++ = ((ch >> 16) & 0xFF);
	    *dst++ = ((ch >> 24) & 0xFF);
	} else {
	    *dst++ = ((ch >> 24) & 0xFF);
	    *dst++ = ((ch >> 16) & 0xFF);
	    *dst++ = ((ch >> 8) & 0xFF);
	    *dst++ = (ch & 0xFF);
	}
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * Utf16ToUtfProc --
 *
 *	Convert from UTF-16 to UTF-8.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
Utf16ToUtfProc(
    void *clientData,		/* additional flags, e.g. TCL_ENCODING_LE */
    const char *src,		/* Source string in Unicode. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd;
    const char *dstEnd, *dstStart;
    int result, numChars, charLimit = INT_MAX;
    unsigned short ch = 0;

    flags |= PTR2INT(clientData);
    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }
    result = TCL_OK;

    /*
     * Check alignment with utf-16 (2 == sizeof(UTF-16))
     */

    if ((srcLen % 2) != 0) {
	result = TCL_CONVERT_MULTIBYTE;
	srcLen--;
    }

#if 0
    /*
     * If last code point is a high surrogate, we cannot handle that yet,
     * unless we are at the end.
     */

    if (!(flags & TCL_ENCODING_END) && (srcLen >= 2) &&
	    ((src[srcLen - ((flags & TCL_ENCODING_LE)?1:2)] & 0xFC) == 0xD8)) {
	result = TCL_CONVERT_MULTIBYTE;
	srcLen-= 2;
    }
#endif

    srcStart = src;
    srcEnd = src + srcLen;

    dstStart = dst;
    dstEnd = dst + dstLen - TCL_UTF_MAX;

    for (numChars = 0; src < srcEnd && numChars <= charLimit; src += 2, numChars++) {
	if (dst > dstEnd && !HIGH_SURROGATE(ch)) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}

	unsigned short prev = ch;
	if (flags & TCL_ENCODING_LE) {
	    ch = (src[1] & 0xFF) << 8 | (src[0] & 0xFF);
	} else {
	    ch = (src[0] & 0xFF) << 8 | (src[1] & 0xFF);
	}
	if (HIGH_SURROGATE(prev)) {
	    if (LOW_SURROGATE(ch)) {
		/*
		 * High surrogate was followed by a low surrogate.
		 * Tcl_UniCharToUtf would have stashed away the state in dst.
		 * Call it again to combine that state with the low surrogate.
		 * We also have to compensate the numChars as two UTF-16 units
		 * have been combined into one character.
		 */
		dst += Tcl_UniCharToUtf(ch | TCL_COMBINE, dst);
	    } else {
		/* High surrogate was not followed by a low surrogate */
		if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_SYNTAX;
		    src -= 2;	/* Go back to beginning of high surrogate */
		    dst--;		/* Also undo writing a single byte too much */
		    break;
		}
		if (PROFILE_REPLACE(flags)) {
		    /*
		     * Previous loop wrote a single byte to mark the high surrogate.
		     * Replace it with the replacement character.
		     */
		    ch = UNICODE_REPLACE_CHAR;
		    dst--;
		    numChars++;
		    dst += Tcl_UniCharToUtf(ch, dst);
		} else {
		    /*
		     * Bug [10c2c17c32]. If Hi surrogate not followed by Lo
		     * surrogate, finish 3-byte UTF-8
		     */
		    dst += Tcl_UniCharToUtf(-1, dst);
		}
		/* Loop around again so destination space and other checks are done */
		prev = 0; /* Reset high surrogate tracker */
		src -= 2;
	    }
	} else {
	    /* Previous char was not a high surrogate */

	    /*
	     * Special case for 1-byte utf chars for speed. Make sure we work with
	     * unsigned short-size data. Order checks based on expected frequency.
	     */
	    if ((unsigned)ch - 1 < 0x7F) {
		/* ASCII except nul */
		*dst++ = (ch & 0xFF);
	    } else if (!SURROGATE(ch)) {
		/* Not ASCII, not surrogate */
		dst += Tcl_UniCharToUtf(ch, dst);
	    } else if (HIGH_SURROGATE(ch)) {
		dst += Tcl_UniCharToUtf(ch | TCL_COMBINE, dst);
		/* Do not count this just yet. Compensate for numChars++ in loop counter */
		numChars--;
	    } else {
		assert(LOW_SURROGATE(ch));
		if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_SYNTAX;
		    break;
		}
		if (PROFILE_REPLACE(flags)) {
		    ch = UNICODE_REPLACE_CHAR;
		}
		dst += Tcl_UniCharToUtf(ch, dst);
	    }
	}
    }

    /*
     * When the above loop ends, result may have the following values:
     * 1. TCL_OK - full source buffer was completely processed.
     *    src, dst, numChars will hold values up to that point BUT
     *    there may be a leftover high surrogate we need to deal with.
     * 2. TCL_CONVERT_NOSPACE - Ran out of room in the destination buffer.
     *    Same considerations as (1)
     * 3. TCL_CONVERT_SYNTAX - decoding error.
     * 4. TCL_CONVERT_MULTIBYTE - the buffer passed in was not fully
     *    processed, because there was a trailing single byte. However,
     *    we *may* have processed the requested number of characters already
     *    in which case the trailing byte does not matter. We still
     *    *may* still be a leftover high surrogate as in (1) and (2).
     */
    switch (result) {
    case TCL_CONVERT_MULTIBYTE: /* FALLTHRU */
    case TCL_OK: /* FALLTHRU */
    case TCL_CONVERT_NOSPACE:
	if (HIGH_SURROGATE(ch)) {
	    if (flags & TCL_ENCODING_END) {
		/*
		 * No more data expected. There will be space for output of
		 * one character (essentially overwriting the dst area holding
		 * high surrogate state)
		 */
		assert((dst-1) <= dstEnd);
		if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_SYNTAX;
		    src -= 2;
		    dst--;
		} else if (PROFILE_REPLACE(flags)) {
		    dst--;
		    numChars++;
		    dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		} else {
		    /* Bug [10c2c17c32]. If Hi surrogate, finish 3-byte UTF-8 */
		    numChars++;
		    dst += Tcl_UniCharToUtf(-1, dst);
		}
	    } else {
		/* More data is expected. Revert the surrogate state */
		src -= 2;
		dst--;
		/* Note: leave result of TCL_CONVERT_NOSPACE as is */
		if (result == TCL_OK) {
		    result = TCL_CONVERT_MULTIBYTE;
		}
	    }
	} else if ((flags & TCL_ENCODING_END) && (result == TCL_CONVERT_MULTIBYTE)) {
	    /*
	     * If we had a trailing byte at the end AND this is the last
	     * fragment AND profile is not "strict", stick FFFD in its place.
	     * Note in this case we DO need to check for room in dst.
	     */
	    if (dst > dstEnd) {
		result = TCL_CONVERT_NOSPACE;
	    } else {
		if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_SYNTAX;
		} else {
		    /* PROFILE_REPLACE or PROFILE_TCL8 */
		    result = TCL_OK;
		    dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		    numChars++;
		    src++;
		}
	    }
	}
	break;
    case TCL_CONVERT_SYNTAX:
	break; /* Nothing to do */
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * UtfToUtf16Proc --
 *
 *	Convert from UTF-8 to UTF-16.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
UtfToUtf16Proc(
    void *clientData,		/* additional flags, e.g. TCL_ENCODING_LE */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose, *dstStart, *dstEnd;
    int result, numChars;
    int ch, len;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd   = dst + dstLen - 2; /* 2 -> sizeof a UTF-16 code unit */
    flags |= PTR2INT(clientData);

    result = TCL_OK;
    for (numChars = 0; src < srcEnd; numChars++) {
	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);
	if (SURROGATE(ch)) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_UNKNOWN;
		break;
	    }
	    if (PROFILE_REPLACE(flags)) {
		ch = UNICODE_REPLACE_CHAR;
	    }
	}
	if (ch <= 0xFFFF) {
	    if (flags & TCL_ENCODING_LE) {
		*dst++ = (ch & 0xFF);
		*dst++ = (ch >> 8);
	    } else {
		*dst++ = (ch >> 8);
		*dst++ = (ch & 0xFF);
	    }
	} else {
	    if ((dst+2) > dstEnd) {
		/* Surrogates need 2 more bytes! Bug [66da4d4228] */
		result = TCL_CONVERT_NOSPACE;
		break;
	    }
	    if (flags & TCL_ENCODING_LE) {
		*dst++ = (((ch - 0x10000) >> 10) & 0xFF);
		*dst++ = (((ch - 0x10000) >> 18) & 0x3) | 0xD8;
		*dst++ = (ch & 0xFF);
		*dst++ = ((ch >> 8) & 0x3) | 0xDC;
	    } else {
		*dst++ = (((ch - 0x10000) >> 18) & 0x3) | 0xD8;
		*dst++ = (((ch - 0x10000) >> 10) & 0xFF);
		*dst++ = ((ch >> 8) & 0x3) | 0xDC;
		*dst++ = (ch & 0xFF);
	    }
	}
	src += len;
    }
    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * UtfToUcs2Proc --
 *
 *	Convert from UTF-8 to UCS-2.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
UtfToUcs2Proc(
    void *clientData,		/* additional flags, e.g. TCL_ENCODING_LE */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose, *dstStart, *dstEnd;
    int result, numChars, len;
    Tcl_UniChar ch = 0;

    flags |= PTR2INT(clientData);
    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd   = dst + dstLen - 2; /* 2 - size of UCS code unit */

    result = TCL_OK;
    for (numChars = 0; src < srcEnd; numChars++) {
	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);
	if (ch > 0xFFFF) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_UNKNOWN;
		break;
	    }
	    ch = UNICODE_REPLACE_CHAR;
	}
	if (PROFILE_STRICT(flags) && SURROGATE(ch)) {
	    result = TCL_CONVERT_SYNTAX;
	    break;
	}

	src += len;

	/*
	 * Need to handle this in a way that won't cause misalignment by
	 * casting dst to a Tcl_UniChar. [Bug 1122671]
	 */

	if (flags & TCL_ENCODING_LE) {
	    *dst++ = (ch & 0xFF);
	    *dst++ = (ch >> 8);
	} else {
	    *dst++ = (ch >> 8);
	    *dst++ = (ch & 0xFF);
	}
    }
    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * TableToUtfProc --
 *
 *	Convert from the encoding specified by the TableEncodingData into
 *	UTF-8.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
TableToUtfProc(
    void *clientData,		/* TableEncodingData that specifies
				 * encoding. */
    const char *src,		/* Source string in specified encoding. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd;
    const char *dstEnd, *dstStart, *prefixBytes;
    int result, byte, numChars, charLimit = INT_MAX;
    Tcl_UniChar ch = 0;
    const unsigned short *const *toUnicode;
    const unsigned short *pageZero;
    TableEncodingData *dataPtr = (TableEncodingData *)clientData;

    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }
    srcStart = src;
    srcEnd = src + srcLen;

    dstStart = dst;
    dstEnd = dst + dstLen - TCL_UTF_MAX;

    toUnicode = (const unsigned short *const *) dataPtr->toUnicode;
    prefixBytes = dataPtr->prefixBytes;
    pageZero = toUnicode[0];

    result = TCL_OK;
    for (numChars = 0; src < srcEnd && numChars <= charLimit; numChars++) {
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	byte = *((unsigned char *) src);
	if (prefixBytes[byte]) {
	    if (src >= srcEnd-1) {
		/* Prefix byte but nothing after it */
		if (!(flags & TCL_ENCODING_END)) {
		    /* More data to come */
		    result = TCL_CONVERT_MULTIBYTE;
		    break;
		} else if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_SYNTAX;
		    break;
		} else if (PROFILE_REPLACE(flags)) {
		    ch = UNICODE_REPLACE_CHAR;
		} else {
		    /* For prefix bytes, we don't fallback to cp1252, see [1355b9a874] */
		    ch = byte;
		}
	    } else {
		ch = toUnicode[byte][*((unsigned char *)++src)];
	    }
	} else {
	    ch = pageZero[byte];
	}
	if ((ch == 0) && (byte != 0)) {
	    /* Prefix+suffix pair is invalid */
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
		break;
	    }
	    if (prefixBytes[byte]) {
		src--;
	    }
	    if (PROFILE_REPLACE(flags)) {
		ch = UNICODE_REPLACE_CHAR;
	    } else {
		char chbuf[2];
		chbuf[0] = byte;
		chbuf[1] = 0;
		TclUtfToUniChar(chbuf, &ch);
	    }
	}

	/*
	 * Special case for 1-byte Utf chars for speed.
	 */

	if ((unsigned)ch - 1 < 0x7F) {
	    *dst++ = (char) ch;
	} else {
	    dst += Tcl_UniCharToUtf(ch, dst);
	}
	src++;
    }

    assert(src <= srcEnd);
    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * TableFromUtfProc --
 *
 *	Convert from UTF-8 into the encoding specified by the
 *	TableEncodingData.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
TableFromUtfProc(
    void *clientData,		/* TableEncodingData that specifies
				 * encoding. */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose;
    const char *dstStart, *dstEnd, *prefixBytes;
    Tcl_UniChar ch = 0;
    int result, len, word, numChars;
    TableEncodingData *dataPtr = (TableEncodingData *)clientData;
    const unsigned short *const *fromUnicode;

    result = TCL_OK;

    prefixBytes = dataPtr->prefixBytes;
    fromUnicode = (const unsigned short *const *) dataPtr->fromUnicode;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd = dst + dstLen - 1;

    for (numChars = 0; src < srcEnd; numChars++) {
	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);

	/* Unicode chars > +U0FFFF cannot be represented in any table encoding */
	if (ch & 0xFFFF0000) {
	    word = 0;
	} else {
	    word = fromUnicode[(ch >> 8)][ch & 0xFF];
	}

	if ((word == 0) && (ch != 0)) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_UNKNOWN;
		break;
	    }
	    word = dataPtr->fallback; /* Both profiles REPLACE and TCL8 */
	}
	if (prefixBytes[(word >> 8)] != 0) {
	    if (dst + 1 > dstEnd) {
		result = TCL_CONVERT_NOSPACE;
		break;
	    }
	    dst[0] = (char) (word >> 8);
	    dst[1] = (char) word;
	    dst += 2;
	} else {
	    if (dst > dstEnd) {
		result = TCL_CONVERT_NOSPACE;
		break;
	    }
	    dst[0] = (char) word;
	    dst++;
	}
	src += len;
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * Iso88591ToUtfProc --
 *
 *	Convert from the "iso8859-1" encoding into UTF-8.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
Iso88591ToUtfProc(
    TCL_UNUSED(void *),
    const char *src,		/* Source string in specified encoding. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd;
    const char *dstEnd, *dstStart;
    int result, numChars, charLimit = INT_MAX;

    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }
    srcStart = src;
    srcEnd = src + srcLen;

    dstStart = dst;
    dstEnd = dst + dstLen - TCL_UTF_MAX;

    result = TCL_OK;
    for (numChars = 0; src < srcEnd && numChars <= charLimit; numChars++) {
	Tcl_UniChar ch = 0;

	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	ch = *((unsigned char *) src);

	/*
	 * Special case for 1-byte utf chars for speed.
	 */

	if ((unsigned)ch - 1 < 0x7F) {
	    *dst++ = (char) ch;
	} else {
	    dst += Tcl_UniCharToUtf(ch, dst);
	}
	src++;
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * Iso88591FromUtfProc --
 *
 *	Convert from UTF-8 into the encoding "iso8859-1".
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
Iso88591FromUtfProc(
    TCL_UNUSED(void *),
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    TCL_UNUSED(Tcl_EncodingState *),
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    const char *srcStart, *srcEnd, *srcClose;
    const char *dstStart, *dstEnd;
    int result = TCL_OK, numChars;
    Tcl_UniChar ch = 0;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd = dst + dstLen - 1;

    for (numChars = 0; src < srcEnd; numChars++) {
	int len;

	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);

	/*
	 * Check for illegal characters.
	 */

	if (ch > 0xFF) {
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_UNKNOWN;
		break;
	    }
	    /*
	     * Plunge on, using '?' as a fallback character.
	     */

	    ch = '?'; /* Profiles TCL8 and REPLACE */
	}

	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	*(dst++) = (char) ch;
	src += len;
    }

    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *---------------------------------------------------------------------------
 *
 * TableFreeProc --
 *
 *	This function is invoked when an encoding is deleted. It deletes the
 *	memory used by the TableEncodingData.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory freed.
 *
 *---------------------------------------------------------------------------
 */

static void
TableFreeProc(
    void *clientData)		/* TableEncodingData that specifies
				 * encoding. */
{
    TableEncodingData *dataPtr = (TableEncodingData *)clientData;

    /*
     * Make sure we aren't freeing twice on shutdown. [Bug 219314]
     */

    Tcl_Free(dataPtr->toUnicode);
    dataPtr->toUnicode = NULL;
    Tcl_Free(dataPtr->fromUnicode);
    dataPtr->fromUnicode = NULL;
    Tcl_Free(dataPtr);
}

/*
 *-------------------------------------------------------------------------
 *
 * EscapeToUtfProc --
 *
 *	Convert from the encoding specified by the EscapeEncodingData into
 *	UTF-8.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
EscapeToUtfProc(
    void *clientData,		/* EscapeEncodingData that specifies
				 * encoding. */
    const char *src,		/* Source string in specified encoding. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    Tcl_EncodingState *statePtr,/* Place for conversion routine to store state
				 * information used during a piecewise
				 * conversion. Contents of statePtr are
				 * initialized and/or reset by conversion
				 * routine under control of flags argument. */
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    EscapeEncodingData *dataPtr = (EscapeEncodingData *)clientData;
    const char *prefixBytes, *tablePrefixBytes, *srcStart, *srcEnd;
    const unsigned short *const *tableToUnicode;
    const Encoding *encodingPtr;
    int state, result, numChars, charLimit = INT_MAX;
    const char *dstStart, *dstEnd;

    if (flags & TCL_ENCODING_CHAR_LIMIT) {
	charLimit = *dstCharsPtr;
    }
    result = TCL_OK;
    tablePrefixBytes = NULL;
    tableToUnicode = NULL;
    prefixBytes = dataPtr->prefixBytes;
    encodingPtr = NULL;

    srcStart = src;
    srcEnd = src + srcLen;

    dstStart = dst;
    dstEnd = dst + dstLen - TCL_UTF_MAX;

    state = PTR2INT(*statePtr);
    if (flags & TCL_ENCODING_START) {
	state = 0;
    }

    for (numChars = 0; src < srcEnd && numChars <= charLimit; ) {
	int byte, hi, lo, ch;

	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	    break;
	}
	byte = *((unsigned char *) src);
	if (prefixBytes[byte]) {
	    unsigned left, len, longest;
	    int checked, i;
	    const EscapeSubTable *subTablePtr;

	    /*
	     * Saw the beginning of an escape sequence.
	     */

	    left = srcEnd - src;
	    len = dataPtr->initLen;
	    longest = len;
	    checked = 0;

	    if (len <= left) {
		checked++;
		if ((len > 0) && (memcmp(src, dataPtr->init, len) == 0)) {
		    /*
		     * If we see initialization string, skip it, even if we're
		     * not at the beginning of the buffer.
		     */

		    src += len;
		    continue;
		}
	    }

	    len = dataPtr->finalLen;
	    if (len > longest) {
		longest = len;
	    }

	    if (len <= left) {
		checked++;
		if ((len > 0) && (memcmp(src, dataPtr->final, len) == 0)) {
		    /*
		     * If we see finalization string, skip it, even if we're
		     * not at the end of the buffer.
		     */

		    src += len;
		    continue;
		}
	    }

	    subTablePtr = dataPtr->subTables;
	    for (i = 0; i < dataPtr->numSubTables; i++) {
		len = subTablePtr->sequenceLen;
		if (len > longest) {
		    longest = len;
		}
		if (len <= left) {
		    checked++;
		    if ((len > 0) &&
			    (memcmp(src, subTablePtr->sequence, len) == 0)) {
			state = i;
			encodingPtr = NULL;
			subTablePtr = NULL;
			src += len;
			break;
		    }
		}
		subTablePtr++;
	    }

	    if (subTablePtr == NULL) {
		/*
		 * A match was found, the escape sequence was consumed, and
		 * the state was updated.
		 */

		continue;
	    }

	    /*
	     * We have a split-up or unrecognized escape sequence. If we
	     * checked all the sequences, then it's a syntax error, otherwise
	     * we need more bytes to determine a match.
	     */

	    if ((checked == dataPtr->numSubTables + 2)
		    || (flags & TCL_ENCODING_END)) {
		if (!PROFILE_STRICT(flags)) {
		    unsigned skip = longest > left ? left : longest;
		    /* Unknown escape sequence */
		    dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		    src += skip;
		    continue;
		}
		result = TCL_CONVERT_SYNTAX;
	    } else {
		result = TCL_CONVERT_MULTIBYTE;
	    }
	    break;
	}

	if (encodingPtr == NULL) {
	    TableEncodingData *tableDataPtr;

	    encodingPtr = GetTableEncoding(dataPtr, state);
	    tableDataPtr = (TableEncodingData *)encodingPtr->clientData;
	    tablePrefixBytes = tableDataPtr->prefixBytes;
	    tableToUnicode = (const unsigned short *const*)
		    tableDataPtr->toUnicode;
	}

	if (tablePrefixBytes[byte]) {
	    src++;
	    if (src >= srcEnd) {
		src--;
		result = TCL_CONVERT_MULTIBYTE;
		break;
	    }
	    hi = byte;
	    lo = *((unsigned char *) src);
	} else {
	    hi = 0;
	    lo = byte;
	}

	ch = tableToUnicode[hi][lo];
	dst += Tcl_UniCharToUtf(ch, dst);
	src++;
	numChars++;
    }

    if ((flags & TCL_ENCODING_END) && (result == TCL_CONVERT_MULTIBYTE)) {
	/* We have a code fragment left-over at the end */
	if (dst > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	} else {
	    /* destination is not full, so we really are at the end now */
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
	    } else {
		/*
		 * PROFILE_REPLACE or PROFILE_TCL8. The latter is treated
		 * similar to former because Tcl8 was broken in this regard
		 * as it just ignored the byte and truncated which is really
		 * a no-no as per Unicode recommendations.
		 */
		result = TCL_OK;
		dst += Tcl_UniCharToUtf(UNICODE_REPLACE_CHAR, dst);
		numChars++;
		/* TCL_CONVERT_MULTIBYTE means all source consumed */
		src = srcEnd;
	    }
	}
    }

    *statePtr = (Tcl_EncodingState) INT2PTR(state);
    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *-------------------------------------------------------------------------
 *
 * EscapeFromUtfProc --
 *
 *	Convert from UTF-8 into the encoding specified by the
 *	EscapeEncodingData.
 *
 * Results:
 *	Returns TCL_OK if conversion was successful.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

static int
EscapeFromUtfProc(
    void *clientData,		/* EscapeEncodingData that specifies
				 * encoding. */
    const char *src,		/* Source string in UTF-8. */
    int srcLen,			/* Source string length in bytes. */
    int flags,			/* Conversion control flags. */
    Tcl_EncodingState *statePtr,/* Place for conversion routine to store state
				 * information used during a piecewise
				 * conversion. Contents of statePtr are
				 * initialized and/or reset by conversion
				 * routine under control of flags argument. */
    char *dst,			/* Output buffer in which converted string is
				 * stored. */
    int dstLen,			/* The maximum length of output buffer in
				 * bytes. */
    int *srcReadPtr,		/* Filled with the number of bytes from the
				 * source string that were converted. This may
				 * be less than the original source length if
				 * there was a problem converting some source
				 * characters. */
    int *dstWrotePtr,		/* Filled with the number of bytes that were
				 * stored in the output buffer as a result of
				 * the conversion. */
    int *dstCharsPtr)		/* Filled with the number of characters that
				 * correspond to the bytes stored in the
				 * output buffer. */
{
    EscapeEncodingData *dataPtr = (EscapeEncodingData *)clientData;
    const Encoding *encodingPtr;
    const char *srcStart, *srcEnd, *srcClose;
    const char *dstStart, *dstEnd;
    int state, result, numChars;
    const TableEncodingData *tableDataPtr;
    const char *tablePrefixBytes;
    const unsigned short *const *tableFromUnicode;
    Tcl_UniChar ch = 0;

    result = TCL_OK;

    srcStart = src;
    srcEnd = src + srcLen;
    srcClose = srcEnd;
    if ((flags & TCL_ENCODING_END) == 0) {
	srcClose -= TCL_UTF_MAX;
    }

    dstStart = dst;
    dstEnd = dst + dstLen - 1;

    /*
     * RFC 1468 states that the text starts in ASCII, and switches to Japanese
     * characters, and that the text must end in ASCII. [Patch 474358]
     */

    if (flags & TCL_ENCODING_START) {
	state = 0;
	if ((dst + dataPtr->initLen) > dstEnd) {
	    *srcReadPtr = 0;
	    *dstWrotePtr = 0;
	    return TCL_CONVERT_NOSPACE;
	}
	memcpy(dst, dataPtr->init, dataPtr->initLen);
	dst += dataPtr->initLen;
    } else {
	state = PTR2INT(*statePtr);
    }

    encodingPtr = GetTableEncoding(dataPtr, state);
    tableDataPtr = (const TableEncodingData *)encodingPtr->clientData;
    tablePrefixBytes = tableDataPtr->prefixBytes;
    tableFromUnicode = (const unsigned short *const *)
	    tableDataPtr->fromUnicode;

    for (numChars = 0; src < srcEnd; numChars++) {
	unsigned len;
	int word;

	if ((src > srcClose) && (!Tcl_UtfCharComplete(src, srcEnd - src))) {
	    /*
	     * If there is more string to follow, this will ensure that the
	     * last UTF-8 character in the source buffer hasn't been cut off.
	     */

	    result = TCL_CONVERT_MULTIBYTE;
	    break;
	}
	len = TclUtfToUniChar(src, &ch);
	if (ch > 0xFFFF) {
	    /* Bug 201c7a3aa6 crash - tables are 256x256 (64K) */
	    if (PROFILE_STRICT(flags)) {
		result = TCL_CONVERT_SYNTAX;
		break;
	    }
	    /* Will be encoded as encoding specific replacement below */
	    ch = UNICODE_REPLACE_CHAR;
	}
	word = tableFromUnicode[(ch >> 8)][ch & 0xFF];

	if ((word == 0) && (ch != 0)) {
	    int oldState;
	    const EscapeSubTable *subTablePtr;

	    oldState = state;
	    for (state = 0; state < dataPtr->numSubTables; state++) {
		encodingPtr = GetTableEncoding(dataPtr, state);
		tableDataPtr = (const TableEncodingData *)encodingPtr->clientData;
		word = tableDataPtr->fromUnicode[(ch >> 8)][ch & 0xFF];
		if (word != 0) {
		    break;
		}
	    }

	    if (word == 0) {
		state = oldState;
		if (PROFILE_STRICT(flags)) {
		    result = TCL_CONVERT_UNKNOWN;
		    break;
		}
		encodingPtr = GetTableEncoding(dataPtr, state);
		tableDataPtr = (const TableEncodingData *)encodingPtr->clientData;
		word = tableDataPtr->fallback;
	    }

	    tablePrefixBytes = (const char *) tableDataPtr->prefixBytes;
	    tableFromUnicode = (const unsigned short *const *)
		    tableDataPtr->fromUnicode;

	    /*
	     * The state variable has the value of oldState when word is 0.
	     * In this case, the escape sequence should not be copied to dst
	     * because the current character set is not changed.
	     */

	    if (state != oldState) {
		subTablePtr = &dataPtr->subTables[state];
		if ((dst + subTablePtr->sequenceLen) > dstEnd) {
		    /*
		     * If there is no space to write the escape sequence, the
		     * state variable must be changed to the value of oldState
		     * variable because this escape sequence must be written
		     * in the next conversion.
		     */

		    state = oldState;
		    result = TCL_CONVERT_NOSPACE;
		    break;
		}
		memcpy(dst, subTablePtr->sequence, subTablePtr->sequenceLen);
		dst += subTablePtr->sequenceLen;
	    }
	}

	if (tablePrefixBytes[(word >> 8)] != 0) {
	    if (dst + 1 > dstEnd) {
		result = TCL_CONVERT_NOSPACE;
		break;
	    }
	    dst[0] = (char) (word >> 8);
	    dst[1] = (char) word;
	    dst += 2;
	} else {
	    if (dst > dstEnd) {
		result = TCL_CONVERT_NOSPACE;
		break;
	    }
	    dst[0] = (char) word;
	    dst++;
	}
	src += len;
    }

    if ((result == TCL_OK) && (flags & TCL_ENCODING_END)) {
	unsigned len = dataPtr->subTables[0].sequenceLen;

	/*
	 * Certain encodings like iso2022-jp need to write an escape sequence
	 * after all characters have been converted. This logic checks that
	 * enough room is available in the buffer for the escape bytes. The
	 * TCL_ENCODING_END flag is cleared after a final escape sequence has
	 * been added to the buffer so that another call to this method does
	 * not attempt to append escape bytes a second time.
	 */

	if ((dst + dataPtr->finalLen + (state?len:0)) > dstEnd) {
	    result = TCL_CONVERT_NOSPACE;
	} else {
	    if (state) {
		memcpy(dst, dataPtr->subTables[0].sequence, len);
		dst += len;
	    }
	    memcpy(dst, dataPtr->final, dataPtr->finalLen);
	    dst += dataPtr->finalLen;
	    state &= ~TCL_ENCODING_END;
	}
    }

    *statePtr = (Tcl_EncodingState) INT2PTR(state);
    *srcReadPtr = src - srcStart;
    *dstWrotePtr = dst - dstStart;
    *dstCharsPtr = numChars;
    return result;
}

/*
 *---------------------------------------------------------------------------
 *
 * EscapeFreeProc --
 *
 *	Frees resources used by the encoding.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory is freed.
 *
 *---------------------------------------------------------------------------
 */

static void
EscapeFreeProc(
    void *clientData)		/* EscapeEncodingData that specifies
				 * encoding. */
{
    EscapeEncodingData *dataPtr = (EscapeEncodingData *)clientData;
    EscapeSubTable *subTablePtr;
    int i;

    if (dataPtr == NULL) {
	return;
    }

    /*
     * The subTables should be freed recursively in normal operation but not
     * during TclFinalizeEncodingSubsystem because they are also present as a
     * weak reference in the toplevel encodingTable (i.e., they don't have a
     * +1 refcount for this), and unpredictable nuking order could remove them
     * from under the following loop's feet. [Bug 2891556]
     *
     * The encodingsInitialized flag, being reset on entry to TFES, can serve
     * as a "not in finalization" test.
     */

    if (encodingsInitialized) {
	subTablePtr = dataPtr->subTables;
	for (i = 0; i < dataPtr->numSubTables; i++) {
	    FreeEncoding((Tcl_Encoding) subTablePtr->encodingPtr);
	    subTablePtr->encodingPtr = NULL;
	    subTablePtr++;
	}
    }
    Tcl_Free(dataPtr);
}

/*
 *---------------------------------------------------------------------------
 *
 * GetTableEncoding --
 *
 *	Helper function for the EscapeEncodingData conversions. Gets the
 *	encoding (of type TextEncodingData) that represents the specified
 *	state.
 *
 * Results:
 *	The return value is the encoding.
 *
 * Side effects:
 *	If the encoding that represents the specified state has not already
 *	been used by this EscapeEncoding, it will be loaded and cached in the
 *	dataPtr.
 *
 *---------------------------------------------------------------------------
 */

static Encoding *
GetTableEncoding(
    EscapeEncodingData *dataPtr,/* Contains names of encodings. */
    int state)			/* Index in dataPtr of desired Encoding. */
{
    EscapeSubTable *subTablePtr = &dataPtr->subTables[state];
    Encoding *encodingPtr = subTablePtr->encodingPtr;

    if (encodingPtr == NULL) {
	encodingPtr = (Encoding *) Tcl_GetEncoding(NULL, subTablePtr->name);
	if ((encodingPtr == NULL)
		|| (encodingPtr->toUtfProc != TableToUtfProc
		&& encodingPtr->toUtfProc != Iso88591ToUtfProc)) {
	    Tcl_Panic("EscapeToUtfProc: invalid sub table");
	}
	subTablePtr->encodingPtr = encodingPtr;
    }

    return encodingPtr;
}

/*
 *---------------------------------------------------------------------------
 *
 * unilen, unilen4 --
 *
 *	A helper function for the Tcl_ExternalToUtf functions. This function
 *	is similar to strlen for double-byte characters: it returns the number
 *	of bytes in a 0x0000 terminated string.
 *
 * Results:
 *	As above.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

static size_t
unilen(
    const char *src)
{
    unsigned short *p;

    p = (unsigned short *) src;
    while (*p != 0x0000) {
	p++;
    }
    return (char *) p - src;
}

static size_t
unilen4(
    const char *src)
{
    unsigned int *p;

    p = (unsigned int *) src;
    while (*p != 0x00000000) {
	p++;
    }
    return (char *) p - src;
}

/*
 *-------------------------------------------------------------------------
 *
 * InitializeEncodingSearchPath	--
 *
 *	This is the fallback routine that sets the default value of the
 *	encoding search path if the application has not set one via a call to
 *	Tcl_SetEncodingSearchPath() by the first time the search path is needed
 *	to load encoding data.
 *
 *	The default encoding search path is produced by taking each directory
 *	in the library path, appending a subdirectory named "encoding", and if
 *	the resulting directory exists, adding it to the encoding search path.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Sets the encoding search path to an initial value.
 *
 *-------------------------------------------------------------------------
 */

static void
InitializeEncodingSearchPath(
    char **valuePtr,
    size_t *lengthPtr,
    Tcl_Encoding *encodingPtr)
{
    const char *bytes;
    Tcl_Size i, numDirs, numBytes;
    Tcl_Obj *libPathObj, *encodingObj, *searchPathObj;

    TclNewLiteralStringObj(encodingObj, "encoding");
    TclNewObj(searchPathObj);
    Tcl_IncrRefCount(encodingObj);
    Tcl_IncrRefCount(searchPathObj);
    libPathObj = TclGetProcessGlobalValue(&libraryPath);
    Tcl_IncrRefCount(libPathObj);
    TclListObjLength(NULL, libPathObj, &numDirs);

    for (i = 0; i < numDirs; i++) {
	Tcl_Obj *directoryObj, *pathObj;
	Tcl_StatBuf stat;

	Tcl_ListObjIndex(NULL, libPathObj, i, &directoryObj);
	pathObj = Tcl_FSJoinToPath(directoryObj, 1, &encodingObj);
	Tcl_IncrRefCount(pathObj);
	if ((0 == Tcl_FSStat(pathObj, &stat)) && S_ISDIR(stat.st_mode)) {
	    Tcl_ListObjAppendElement(NULL, searchPathObj, pathObj);
	}
	Tcl_DecrRefCount(pathObj);
    }

    Tcl_DecrRefCount(libPathObj);
    Tcl_DecrRefCount(encodingObj);
    *encodingPtr = libraryPath.encoding;
    if (*encodingPtr) {
	((Encoding *)(*encodingPtr))->refCount++;
    }
    bytes = TclGetStringFromObj(searchPathObj, &numBytes);

    *lengthPtr = numBytes;
    *valuePtr = (char *)Tcl_Alloc(numBytes + 1);
    memcpy(*valuePtr, bytes, numBytes + 1);
    Tcl_DecrRefCount(searchPathObj);
}

/*
 *------------------------------------------------------------------------
 *
 * TclEncodingProfileParseName --
 *
 *	Maps an encoding profile name to its integer equivalent.
 *
 * Results:
 *	TCL_OK on success or TCL_ERROR on failure.
 *
 * Side effects:
 *	Returns the profile enum value in *profilePtr
 *
 *------------------------------------------------------------------------
 */
int
TclEncodingProfileNameToId(
    Tcl_Interp *interp,		/* For error messages. May be NULL */
    const char *profileName,	/* Name of profile */
    int *profilePtr)		/* Output */
{
    size_t i;
    size_t numProfiles = sizeof(encodingProfiles) / sizeof(encodingProfiles[0]);

    for (i = 0; i < numProfiles; ++i) {
	if (!strcmp(profileName, encodingProfiles[i].name)) {
	    *profilePtr = encodingProfiles[i].value;
	    return TCL_OK;
	}
    }
    if (interp) {
	/* This code assumes at least two profiles :-) */
	Tcl_Obj *errorObj = Tcl_ObjPrintf("bad profile name \"%s\": must be",
		profileName);
	for (i = 0; i < (numProfiles - 1); ++i) {
	    Tcl_AppendStringsToObj(
		    errorObj, " ", encodingProfiles[i].name, ",", (char *)NULL);
	}
	Tcl_AppendStringsToObj(
		errorObj, " or ", encodingProfiles[numProfiles-1].name, (char *)NULL);

	Tcl_SetObjResult(interp, errorObj);
	Tcl_SetErrorCode(
		interp, "TCL", "ENCODING", "PROFILE", profileName, (char *)NULL);
    }
    return TCL_ERROR;
}

/*
 *------------------------------------------------------------------------
 *
 * TclEncodingProfileValueToName --
 *
 *	Maps an encoding profile value to its name.
 *
 * Results:
 *	Pointer to the name or NULL on failure. Caller must not make
 *	not modify the string and must make a copy to hold on to it.
 *
 * Side effects:
 *	None.
 *------------------------------------------------------------------------
 */
const char *
TclEncodingProfileIdToName(
    Tcl_Interp *interp,		/* For error messages. May be NULL */
    int profileValue)		/* Profile #define value */
{
    size_t i;

    for (i = 0; i < sizeof(encodingProfiles) / sizeof(encodingProfiles[0]); ++i) {
	if (profileValue == encodingProfiles[i].value) {
	    return encodingProfiles[i].name;
	}
    }
    if (interp) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"Internal error. Bad profile id \"%d\".", profileValue));
	Tcl_SetErrorCode(
		interp, "TCL", "ENCODING", "PROFILEID", (char *)NULL);
    }
    return NULL;
}

/*
 *------------------------------------------------------------------------
 *
 * TclGetEncodingProfiles --
 *
 *	Get the list of supported encoding profiles.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The list of profile names is stored in the interpreter result.
 *
 *------------------------------------------------------------------------
 */
void
TclGetEncodingProfiles(
    Tcl_Interp *interp)
{
    size_t i, n;
    Tcl_Obj *objPtr;
    n = sizeof(encodingProfiles) / sizeof(encodingProfiles[0]);
    objPtr = Tcl_NewListObj(n, NULL);
    for (i = 0; i < n; ++i) {
	Tcl_ListObjAppendElement(interp, objPtr,
		Tcl_NewStringObj(encodingProfiles[i].name, TCL_INDEX_NONE));
    }
    Tcl_SetObjResult(interp, objPtr);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

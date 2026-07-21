/*
 * tclZlib.c --
 *
 *	This file provides the interface to the Zlib library.
 *
 * Copyright © 2004-2005 Pascal Scheffers <pascal@scheffers.net>
 * Copyright © 2005 Unitas Software B.V.
 * Copyright © 2008-2012 Donal K. Fellows
 *
 * Parts written by Jean-Claude Wippler, as part of Tclkit, placed in the
 * public domain March 2003.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclIO.h"
#if defined(_WIN32) && defined (__clang__) && (__clang_major__ > 20)
#pragma clang diagnostic ignored "-Wc++-keyword"
#endif
#include "zlib.h"

/*
 * The version of the zlib "package" that this implements. Note that this
 * thoroughly supersedes the versions included with tclkit, which are "1.1",
 * so this is at least "2.0" (there's no general *commitment* to have the same
 * interface, even if that is mostly true).
 */

#define TCL_ZLIB_VERSION	"2.0.1"

/*
 * Magic flags used with wbits fields to indicate that we're handling the gzip
 * format or automatic detection of format. Putting it here is slightly less
 * gross!
 */
enum WBitsFlags {
    WBITS_RAW = (-MAX_WBITS),		/* RAW compressed data */
    WBITS_ZLIB = (MAX_WBITS),		/* Zlib-format compressed data */
    WBITS_GZIP = (MAX_WBITS | 16),	/* Gzip-format compressed data */
    WBITS_AUTODETECT = (MAX_WBITS | 32)	/* Auto-detect format from its header */
};

/*
 * Structure used for handling gzip headers that are generated from a
 * dictionary. It comprises the header structure itself plus some working
 * space that it is very convenient to have attached.
 */

#define MAX_COMMENT_LEN		256

typedef struct {
    gz_header header;
    char nativeFilenameBuf[MAXPATHLEN];
    char nativeCommentBuf[MAX_COMMENT_LEN];
} GzipHeader;

/*
 * Structure used for the Tcl_ZlibStream* commands and [zlib stream ...]
 */

typedef struct {
    Tcl_Interp *interp;
    z_stream stream;		/* The interface to the zlib library. */
    int streamEnd;		/* If we've got to end-of-stream. */
    Tcl_Obj *inData, *outData;	/* Input / output buffers (lists) */
    Tcl_Obj *currentInput;	/* Pointer to what is currently being
				 * inflated. */
    Tcl_Size outPos;		/* Index into output buffer to write to next. */
    int mode;			/* Either TCL_ZLIB_STREAM_DEFLATE or
				 * TCL_ZLIB_STREAM_INFLATE. */
    int format;			/* Flags from the TCL_ZLIB_FORMAT_* */
    int level;			/* Default 5, 0-9 */
    int flush;			/* Stores the flush param for deferred the
				 * decompression. */
    int wbits;			/* The encoded compression mode, so we can
				 * restart the stream if necessary. */
    Tcl_Command cmd;		/* Token for the associated Tcl command. */
    Tcl_Obj *compDictObj;	/* Byte-array object containing compression
				 * dictionary (not dictObj!) to use if
				 * necessary. */
    int flags;			/* Miscellaneous flag bits. */
    GzipHeader *gzHeaderPtr;	/* If we've allocated a gzip header
				 * structure. */
} ZlibStreamHandle;

enum ZlibStreamHandleFlags {
    DICT_TO_SET = 0x1		/* If we need to set a compression dictionary
				 * in the low-level engine at the next
				 * opportunity. */
};

/*
 * Macros to make it clearer in some of the twiddlier accesses what is
 * happening.
 */

#define IsRawStream(zshPtr)	((zshPtr)->format == TCL_ZLIB_FORMAT_RAW)
#define HaveDictToSet(zshPtr)	((zshPtr)->flags & DICT_TO_SET)
#define DictWasSet(zshPtr)	((zshPtr)->flags |= ~DICT_TO_SET)

/*
 * Structure used for stacked channel compression and decompression.
 */

typedef struct {
    Tcl_Channel chan;		/* Reference to the channel itself. */
    Tcl_Channel parent;		/* The underlying source and sink of bytes. */
    int flags;			/* General flag bits, see below... */
    int mode;			/* Either the value TCL_ZLIB_STREAM_DEFLATE
				 * for compression on output, or
				 * TCL_ZLIB_STREAM_INFLATE for decompression
				 * on input. */
    int format;			/* What format of data is going on the wire.
				 * Needed so that the correct [fconfigure]
				 * options can be enabled. */
    unsigned int readAheadLimit;/* The maximum number of bytes to read from
				 * the underlying stream in one go. */
    z_stream inStream;		/* Structure used by zlib for decompression of
				 * input. */
    z_stream outStream;		/* Structure used by zlib for compression of
				 * output. */
    char *inBuffer, *outBuffer;	/* Working buffers. */
    size_t inAllocated, outAllocated;
				/* Sizes of working buffers. */
    GzipHeader inHeader;	/* Header read from input stream, when
				 * decompressing a gzip stream. */
    GzipHeader outHeader;	/* Header to write to an output stream, when
				 * compressing a gzip stream. */
    Tcl_TimerToken timer;	/* Timer used for keeping events fresh. */
    Tcl_Obj *compDictObj;	/* Byte-array object containing compression
				 * dictionary (not dictObj!) to use if
				 * necessary. */
} ZlibChannelData;

/*
 * Value bits for the ZlibChannelData::flags field.
 */
enum ZlibChannelDataFlags {
    ASYNC = 0x01,		/* Set if this is an asynchronous channel. */
    IN_HEADER = 0x02,		/* Set if the inHeader field has been
				 * registered with the input compressor. */
    OUT_HEADER = 0x04,		/* Set if the outputHeader field has been
				 * registered with the output decompressor. */
    STREAM_DECOMPRESS = 0x08,	/* Set to signal decompress pending data. */
    STREAM_DONE = 0x10		/* Set to signal stream end up to transform
				 * input. */
};

/*
 * Size of buffers allocated by default, and the range it can be set to.  The
 * same sorts of values apply to streams, except with different limits (they
 * permit byte-level activity). Channels always use bytes unless told to use
 * larger buffers.
 */

#define DEFAULT_BUFFER_SIZE	4096
#define MIN_NONSTREAM_BUFFER_SIZE 16
#define MAX_BUFFER_SIZE		65536

/*
 * Prototypes for private procedures defined later in this file:
 */

static Tcl_CmdDeleteProc	ZlibStreamCmdDelete;
static Tcl_DriverBlockModeProc	ZlibTransformBlockMode;
static Tcl_DriverClose2Proc	ZlibTransformClose;
static Tcl_DriverGetHandleProc	ZlibTransformGetHandle;
static Tcl_DriverGetOptionProc	ZlibTransformGetOption;
static Tcl_DriverHandlerProc	ZlibTransformEventHandler;
static Tcl_DriverInputProc	ZlibTransformInput;
static Tcl_DriverOutputProc	ZlibTransformOutput;
static Tcl_DriverSetOptionProc	ZlibTransformSetOption;
static Tcl_DriverWatchProc	ZlibTransformWatch;
static Tcl_ObjCmdProc		ZlibAdler32Cmd;
static Tcl_ObjCmdProc		ZlibCompressCmd;
static Tcl_ObjCmdProc		ZlibCRC32Cmd;
static Tcl_ObjCmdProc		ZlibDecompressCmd;
static Tcl_ObjCmdProc		ZlibDeflateCmd;
static Tcl_ObjCmdProc		ZlibGunzipCmd;
static Tcl_ObjCmdProc		ZlibGzipCmd;
static Tcl_ObjCmdProc		ZlibInflateCmd;
static Tcl_ObjCmdProc		ZlibPushCmd;
static Tcl_ObjCmdProc		ZlibStreamCmd;
static Tcl_ObjCmdProc		ZlibStreamImplCmd;
static Tcl_ObjCmdProc		ZlibStreamAddCmd;
static Tcl_ObjCmdProc		ZlibStreamHeaderCmd;
static Tcl_ObjCmdProc		ZlibStreamPutCmd;

static void		ConvertError(Tcl_Interp *interp, int code,
			    uLong adler);
static Tcl_Obj *	ConvertErrorToList(int code, uLong adler);
static inline int	Deflate(z_streamp strm, void *bufferPtr,
			    size_t bufferSize, int flush, size_t *writtenPtr);
static void		ExtractHeader(gz_header *headerPtr, Tcl_Obj *dictObj);
static int		GenerateHeader(Tcl_Interp *interp, Tcl_Obj *dictObj,
			    GzipHeader *headerPtr, int *extraSizePtr);
static int		ResultDecompress(ZlibChannelData *chanDataPtr,
			    char *buf, int toRead, int flush,
			    int *errorCodePtr);
static Tcl_Channel	ZlibStackChannelTransform(Tcl_Interp *interp,
			    int mode, int format, int level, int limit,
			    Tcl_Channel channel, Tcl_Obj *gzipHeaderDictPtr,
			    Tcl_Obj *compDictObj);
static void		ZlibStreamCleanup(ZlibStreamHandle *zshPtr);
static inline void	ZlibTransformEventTimerKill(
			    ZlibChannelData *chanDataPtr);
static void		ZlibTransformTimerRun(void *clientData);

/*
 * Type of zlib-based compressing and decompressing channels.
 */

static const Tcl_ChannelType zlibChannelType = {
    "zlib",
    TCL_CHANNEL_VERSION_5,
    NULL,			/* Deprecated. */
    ZlibTransformInput,
    ZlibTransformOutput,
    NULL,			/* Deprecated. */
    ZlibTransformSetOption,
    ZlibTransformGetOption,
    ZlibTransformWatch,
    ZlibTransformGetHandle,
    ZlibTransformClose,
    ZlibTransformBlockMode,
    NULL,			/* Flush proc. */
    ZlibTransformEventHandler,
    NULL,			/* Seek proc. */
    NULL,			/* Thread action proc. */
    NULL			/* Truncate proc. */
};

static const EnsembleImplMap zlibImplMap[] = {
    {"adler32",		ZlibAdler32Cmd,	NULL, NULL, NULL, 0},
    {"compress",	ZlibCompressCmd,	NULL, NULL, NULL, 0},
    {"crc32",		ZlibCRC32Cmd,	NULL, NULL, NULL, 0},
    {"decompress",	ZlibDecompressCmd,	NULL, NULL, NULL, 0},
    {"deflate",		ZlibDeflateCmd,	NULL, NULL, NULL, 0},
    {"gunzip",		ZlibGunzipCmd,	NULL, NULL, NULL, 0},
    {"gzip",		ZlibGzipCmd,	NULL, NULL, NULL, 0},
    {"inflate",		ZlibInflateCmd,	NULL, NULL, NULL, 0},
    {"push",		ZlibPushCmd,	NULL, NULL, NULL, 0},
    {"stream",		ZlibStreamCmd,	NULL, NULL, NULL, 0},
    {NULL, NULL, NULL, NULL, NULL, 0}
};

/*
 *----------------------------------------------------------------------
 *
 * Latin1 --
 *	Helper to definitely get the ISO 8859-1 encoding. It's internally
 *	defined by Tcl so this operation should always succeed.
 *
 *----------------------------------------------------------------------
 */
static inline Tcl_Encoding
Latin1(void)
{
    Tcl_Encoding latin1enc = Tcl_GetEncoding(NULL, "iso8859-1");

    if (latin1enc == NULL) {
	Tcl_Panic("no latin-1 encoding");
    }
    return latin1enc;
}

/*
 *----------------------------------------------------------------------
 *
 * ConvertError --
 *
 *	Utility function for converting a zlib error into a Tcl error.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Updates the interpreter result and errorcode.
 *
 *----------------------------------------------------------------------
 */

static void
ConvertError(
    Tcl_Interp *interp,		/* Interpreter to store the error in. May be
				 * NULL, in which case nothing happens. */
    int code,			/* The zlib error code. */
    uLong adler)		/* The checksum expected (for Z_NEED_DICT) */
{
    const char *codeStr, *codeStr2 = NULL;
    char codeStrBuf[TCL_INTEGER_SPACE];

    if (interp == NULL) {
	return;
    }

    switch (code) {
	/*
	 * Firstly, the case that is *different* because it's really coming
	 * from the OS and is just being reported via zlib. It should be
	 * really uncommon because Tcl handles all I/O rather than delegating
	 * it to zlib, but proving it can't happen is hard.
	 */

    case Z_ERRNO:
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		Tcl_PosixError(interp), TCL_AUTO_LENGTH));
	return;

	/*
	 * Normal errors/conditions, some of which have additional detail and
	 * some which don't. (This is not defined by array lookup because zlib
	 * error codes are sometimes negative.)
	 */

    case Z_STREAM_ERROR:
	codeStr = "STREAM";
	break;
    case Z_DATA_ERROR:
	codeStr = "DATA";
	break;
    case Z_MEM_ERROR:
	codeStr = "MEM";
	break;
    case Z_BUF_ERROR:
	codeStr = "BUF";
	break;
    case Z_VERSION_ERROR:
	codeStr = "VERSION";
	break;
    case Z_NEED_DICT:
	codeStr = "NEED_DICT";
	codeStr2 = codeStrBuf;
	snprintf(codeStrBuf, sizeof(codeStrBuf), "%lu", adler);
	break;

	/*
	 * These should _not_ happen! This function is for dealing with error
	 * cases, not non-errors!
	 */

    case Z_OK:
	Tcl_Panic("unexpected zlib result in error handler: Z_OK");
    case Z_STREAM_END:
	Tcl_Panic("unexpected zlib result in error handler: Z_STREAM_END");

	/*
	 * Anything else is bad news; it's unexpected. Convert to generic
	 * error.
	 */

    default:
	codeStr = "UNKNOWN";
	codeStr2 = codeStrBuf;
	snprintf(codeStrBuf, sizeof(codeStrBuf), "%d", code);
	break;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(zError(code), TCL_AUTO_LENGTH));

    /*
     * Tricky point! We might pass NULL twice here (and will when the error
     * type is known).
     */

    Tcl_SetErrorCode(interp, "TCL", "ZLIB", codeStr, codeStr2, (char *)NULL);
}

static Tcl_Obj *
ConvertErrorToList(
    int code,			/* The zlib error code. */
    uLong adler)		/* The checksum expected (for Z_NEED_DICT) */
{
    Tcl_Obj *objv[4];

    TclNewLiteralStringObj(objv[0], "TCL");
    TclNewLiteralStringObj(objv[1], "ZLIB");
    switch (code) {
    case Z_STREAM_ERROR:
	TclNewLiteralStringObj(objv[2], "STREAM");
	return Tcl_NewListObj(3, objv);
    case Z_DATA_ERROR:
	TclNewLiteralStringObj(objv[2], "DATA");
	return Tcl_NewListObj(3, objv);
    case Z_MEM_ERROR:
	TclNewLiteralStringObj(objv[2], "MEM");
	return Tcl_NewListObj(3, objv);
    case Z_BUF_ERROR:
	TclNewLiteralStringObj(objv[2], "BUF");
	return Tcl_NewListObj(3, objv);
    case Z_VERSION_ERROR:
	TclNewLiteralStringObj(objv[2], "VERSION");
	return Tcl_NewListObj(3, objv);
    case Z_ERRNO:
	TclNewLiteralStringObj(objv[2], "POSIX");
	objv[3] = Tcl_NewStringObj(Tcl_ErrnoId(), TCL_AUTO_LENGTH);
	return Tcl_NewListObj(4, objv);
    case Z_NEED_DICT:
	TclNewLiteralStringObj(objv[2], "NEED_DICT");
	TclNewIntObj(objv[3], (Tcl_WideInt) adler);
	return Tcl_NewListObj(4, objv);

	/*
	 * These should _not_ happen! This function is for dealing with error
	 * cases, not non-errors!
	 */

    case Z_OK:
	Tcl_Panic("unexpected zlib result in error handler: Z_OK");
    case Z_STREAM_END:
	Tcl_Panic("unexpected zlib result in error handler: Z_STREAM_END");

	/*
	 * Catch-all. Should be unreachable because all cases are already
	 * listed above.
	 */

    default:
	TCL_UNREACHABLE();
    }
}

/*
 *----------------------------------------------------------------------
 *
 * GenerateHeader --
 *
 *	Function for creating a gzip header from the contents of a dictionary
 *	(as described in the documentation).
 *
 * Results:
 *	A Tcl result code.
 *
 * Side effects:
 *	Updates the fields of the given gz_header structure. Adds amount of
 *	extra space required for the header to the variable referenced by the
 *	extraSizePtr argument.
 *
 *----------------------------------------------------------------------
 */

static int
GenerateHeader(
    Tcl_Interp *interp,		/* Where to put error messages. */
    Tcl_Obj *dictObj,		/* The dictionary whose contents are to be
				 * parsed. */
    GzipHeader *headerPtr,	/* Where to store the parsed-out values. */
    int *extraSizePtr)		/* Variable to add the length of header
				 * strings (filename, comment) to. */
{
    Tcl_Obj *value;
    int len, result = TCL_ERROR;
    Tcl_Size length;
    Tcl_WideInt wideValue = 0;
    const char *valueStr;
    Tcl_Encoding latin1enc = Latin1();
    static const char *const types[] = {
	"binary", "text"
    };

    if (TclDictGet(interp, dictObj, "comment", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL) {
	Tcl_EncodingState state;
	valueStr = TclGetStringFromObj(value, &length);
	result = Tcl_UtfToExternal(NULL, latin1enc, valueStr, length,
		TCL_ENCODING_START|TCL_ENCODING_END|TCL_ENCODING_PROFILE_STRICT,
		&state, headerPtr->nativeCommentBuf, MAX_COMMENT_LEN - 1, NULL,
		&len, NULL);
	if (result != TCL_OK) {
	    if (interp) {
		if (result == TCL_CONVERT_UNKNOWN) {
		    Tcl_AppendResult(interp,
			    "Comment contains characters > 0xFF", (char *)NULL);
		} else {
		    Tcl_AppendResult(interp, "Comment too large for zip",
			    (char *)NULL);
		}
	    }
	    result = TCL_ERROR; /* TCL_CONVERT_* -> TCL_ERROR */
	    goto error;
	}
	headerPtr->nativeCommentBuf[len] = '\0';
	headerPtr->header.comment = (Bytef *) headerPtr->nativeCommentBuf;
	if (extraSizePtr != NULL) {
	    *extraSizePtr += len;
	}
    }

    if (TclDictGet(interp, dictObj, "crc", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL &&
	    Tcl_GetBooleanFromObj(interp, value, &headerPtr->header.hcrc)) {
	goto error;
    }

    if (TclDictGet(interp, dictObj, "filename", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL) {
	Tcl_EncodingState state;
	valueStr = TclGetStringFromObj(value, &length);
	result = Tcl_UtfToExternal(NULL, latin1enc, valueStr, length,
		TCL_ENCODING_START|TCL_ENCODING_END|TCL_ENCODING_PROFILE_STRICT,
		&state, headerPtr->nativeFilenameBuf, MAXPATHLEN - 1, NULL,
		&len, NULL);
	if (result != TCL_OK) {
	    if (interp) {
		if (result == TCL_CONVERT_UNKNOWN) {
		    Tcl_AppendResult(interp,
			    "Filename contains characters > 0xFF", (char *)NULL);
		} else {
		    Tcl_AppendResult(interp,
			    "Filename too large for zip", (char *)NULL);
		}
	    }
	    result = TCL_ERROR;	/* TCL_CONVERT_* -> TCL_ERROR */
	    goto error;
	}
	headerPtr->nativeFilenameBuf[len] = '\0';
	headerPtr->header.name = (Bytef *) headerPtr->nativeFilenameBuf;
	if (extraSizePtr != NULL) {
	    *extraSizePtr += len;
	}
    }

    if (TclDictGet(interp, dictObj, "os", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL && Tcl_GetIntFromObj(interp, value,
	    &headerPtr->header.os) != TCL_OK) {
	goto error;
    }

    /*
     * Ignore the 'size' field, since that is controlled by the size of the
     * input data.
     */

    if (TclDictGet(interp, dictObj, "time", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL && TclGetWideIntFromObj(interp, value,
	    &wideValue) != TCL_OK) {
	goto error;
    }
    headerPtr->header.time = wideValue;

    if (TclDictGet(interp, dictObj, "type", &value) != TCL_OK) {
	goto error;
    } else if (value != NULL && Tcl_GetIndexFromObj(interp, value, types,
	    "type", TCL_EXACT, &headerPtr->header.text) != TCL_OK) {
	goto error;
    }

    result = TCL_OK;
  error:
    Tcl_FreeEncoding(latin1enc);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * ExtractHeader --
 *
 *	Take the values out of a gzip header and store them in a dictionary.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Updates the dictionary, which must be writable (i.e. refCount < 2).
 *
 *----------------------------------------------------------------------
 */

static void
ExtractHeader(
    gz_header *headerPtr,	/* The gzip header to extract from. */
    Tcl_Obj *dictObj)		/* The dictionary to store in. */
{
    Tcl_Encoding latin1enc = NULL;
				/* RFC 1952 says that header strings are in
				 * ISO 8859-1 (LATIN-1). */
    Tcl_DString tmp;

    if (headerPtr->comment != Z_NULL) {
	latin1enc = Latin1();

	(void) Tcl_ExternalToUtfDString(latin1enc, (char *) headerPtr->comment,
		TCL_AUTO_LENGTH, &tmp);
	TclDictPut(NULL, dictObj, "comment", Tcl_DStringToObj(&tmp));
    }
    TclDictPut(NULL, dictObj, "crc", Tcl_NewBooleanObj(headerPtr->hcrc));
    if (headerPtr->name != Z_NULL) {
	if (latin1enc == NULL) {
	    latin1enc = Latin1();
	}

	(void) Tcl_ExternalToUtfDString(latin1enc, (char *) headerPtr->name,
		TCL_AUTO_LENGTH, &tmp);
	TclDictPut(NULL, dictObj, "filename", Tcl_DStringToObj(&tmp));
    }
    if (headerPtr->os != 255) {
	TclDictPut(NULL, dictObj, "os", Tcl_NewWideIntObj(headerPtr->os));
    }
    if (headerPtr->time != 0 /* magic - no time */) {
	TclDictPut(NULL, dictObj, "time", Tcl_NewWideIntObj(headerPtr->time));
    }
    if (headerPtr->text != Z_UNKNOWN) {
	TclDictPutString(NULL, dictObj, "type",
		headerPtr->text ? "text" : "binary");
    }

    if (latin1enc != NULL) {
	Tcl_FreeEncoding(latin1enc);
    }
}

/*
 * Disentangle the worst of how the zlib API is used.
 */

static int
SetInflateDictionary(
    z_streamp strm,
    Tcl_Obj *compDictObj)
{
    if (compDictObj != NULL) {
	Tcl_Size length = 0;
	unsigned char *bytes = Tcl_GetBytesFromObj(NULL, compDictObj, &length);

	if (bytes == NULL) {
	    return Z_DATA_ERROR;
	}
	return inflateSetDictionary(strm, bytes, length);
    }
    return Z_OK;
}

static int
SetDeflateDictionary(
    z_streamp strm,
    Tcl_Obj *compDictObj)
{
    if (compDictObj != NULL) {
	Tcl_Size length = 0;
	unsigned char *bytes = Tcl_GetBytesFromObj(NULL, compDictObj, &length);

	if (bytes == NULL) {
	    return Z_DATA_ERROR;
	}
	return deflateSetDictionary(strm, bytes, length);
    }
    return Z_OK;
}

static inline int
Deflate(
    z_streamp strm,
    void *bufferPtr,
    size_t bufferSize,
    int flush,
    size_t *writtenPtr)
{
    strm->next_out = (Bytef *) bufferPtr;
    strm->avail_out = bufferSize;
    int e = deflate(strm, flush);
    if (writtenPtr != NULL) {
	*writtenPtr = bufferSize - strm->avail_out;
    }
    return e;
}

static inline void
AppendByteArray(
    Tcl_Obj *listObj,
    void *buffer,
    size_t size)
{
    if (size > 0) {
	Tcl_Obj *baObj = Tcl_NewByteArrayObj((unsigned char *) buffer, size);

	Tcl_ListObjAppendElement(NULL, listObj, baObj);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamInit --
 *
 *	This command initializes a (de)compression context/handle for
 *	(de)compressing data in chunks.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	The variable pointed to by zshandlePtr is initialised and memory
 *	allocated for internal state. Additionally, if interp is not null, a
 *	Tcl command is created and its name placed in the interp result obj.
 *
 * Note:
 *	At least one of interp and zshandlePtr should be non-NULL or the
 *	reference to the stream will be completely lost.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamInit(
    Tcl_Interp *interp,
    int mode,			/* Either TCL_ZLIB_STREAM_INFLATE or
				 * TCL_ZLIB_STREAM_DEFLATE. */
    int format,			/* Flags from the TCL_ZLIB_FORMAT_* set. */
    int level,			/* 0-9 or TCL_ZLIB_COMPRESS_DEFAULT. */
    Tcl_Obj *dictObj,		/* Dictionary containing headers for gzip. */
    Tcl_ZlibStream *zshandlePtr)
{
    int wbits = 0;
    int e;
    ZlibStreamHandle *zshPtr = NULL;
    Tcl_DString cmdname;
    GzipHeader *gzHeaderPtr = NULL;

    switch (mode) {
    case TCL_ZLIB_STREAM_DEFLATE:
	/*
	 * Compressed format is specified by the wbits parameter. See zlib.h
	 * for details.
	 */

	switch (format) {
	case TCL_ZLIB_FORMAT_RAW:
	    wbits = WBITS_RAW;
	    break;
	case TCL_ZLIB_FORMAT_GZIP:
	    wbits = WBITS_GZIP;
	    if (dictObj) {
		gzHeaderPtr = (GzipHeader *) Tcl_Alloc(sizeof(GzipHeader));
		memset(gzHeaderPtr, 0, sizeof(GzipHeader));
		if (GenerateHeader(interp, dictObj, gzHeaderPtr,
			NULL) != TCL_OK) {
		    Tcl_Free(gzHeaderPtr);
		    return TCL_ERROR;
		}
	    }
	    break;
	case TCL_ZLIB_FORMAT_ZLIB:
	    wbits = WBITS_ZLIB;
	    break;
	default:
	    Tcl_Panic("incorrect zlib data format, must be "
		    "TCL_ZLIB_FORMAT_ZLIB, TCL_ZLIB_FORMAT_GZIP or "
		    "TCL_ZLIB_FORMAT_RAW");
	}
	if (level < Z_DEFAULT_COMPRESSION || level > Z_BEST_COMPRESSION) {
	    Tcl_Panic("compression level should be between %d (no compression)"
		    " and %d (best compression) or %d for default compression "
		    "level", Z_NO_COMPRESSION, Z_BEST_COMPRESSION,
		    Z_DEFAULT_COMPRESSION);
	}
	break;
    case TCL_ZLIB_STREAM_INFLATE:
	/*
	 * wbits are the same as DEFLATE, but FORMAT_AUTO is valid too.
	 */

	switch (format) {
	case TCL_ZLIB_FORMAT_RAW:
	    wbits = WBITS_RAW;
	    break;
	case TCL_ZLIB_FORMAT_GZIP:
	    wbits = WBITS_GZIP;
	    gzHeaderPtr = (GzipHeader *) Tcl_Alloc(sizeof(GzipHeader));
	    memset(gzHeaderPtr, 0, sizeof(GzipHeader));
	    gzHeaderPtr->header.name = (Bytef *)
		    gzHeaderPtr->nativeFilenameBuf;
	    gzHeaderPtr->header.name_max = MAXPATHLEN - 1;
	    gzHeaderPtr->header.comment = (Bytef *)
		    gzHeaderPtr->nativeCommentBuf;
	    gzHeaderPtr->header.name_max = MAX_COMMENT_LEN - 1;
	    break;
	case TCL_ZLIB_FORMAT_ZLIB:
	    wbits = WBITS_ZLIB;
	    break;
	case TCL_ZLIB_FORMAT_AUTO:
	    wbits = WBITS_AUTODETECT;
	    break;
	default:
	    Tcl_Panic("incorrect zlib data format, must be "
		    "TCL_ZLIB_FORMAT_ZLIB, TCL_ZLIB_FORMAT_GZIP, "
		    "TCL_ZLIB_FORMAT_RAW or TCL_ZLIB_FORMAT_AUTO");
	}
	break;
    default:
	Tcl_Panic("bad mode, must be TCL_ZLIB_STREAM_DEFLATE or"
		" TCL_ZLIB_STREAM_INFLATE");
    }

    zshPtr = (ZlibStreamHandle *) Tcl_Alloc(sizeof(ZlibStreamHandle));
    zshPtr->interp = interp;
    zshPtr->mode = mode;
    zshPtr->format = format;
    zshPtr->level = level;
    zshPtr->wbits = wbits;
    zshPtr->currentInput = NULL;
    zshPtr->streamEnd = 0;
    zshPtr->compDictObj = NULL;
    zshPtr->flags = 0;
    zshPtr->gzHeaderPtr = gzHeaderPtr;
    memset(&zshPtr->stream, 0, sizeof(z_stream));
    zshPtr->stream.adler = 1;

    /*
     * No output buffer available yet
     */

    if (mode == TCL_ZLIB_STREAM_DEFLATE) {
	e = deflateInit2(&zshPtr->stream, level, Z_DEFLATED, wbits,
		MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
	if (e == Z_OK && zshPtr->gzHeaderPtr) {
	    e = deflateSetHeader(&zshPtr->stream,
		    &zshPtr->gzHeaderPtr->header);
	}
    } else {
	e = inflateInit2(&zshPtr->stream, wbits);
	if (e == Z_OK && zshPtr->gzHeaderPtr) {
	    e = inflateGetHeader(&zshPtr->stream,
		    &zshPtr->gzHeaderPtr->header);
	}
    }

    if (e != Z_OK) {
	ConvertError(interp, e, zshPtr->stream.adler);
	goto error;
    }

    /*
     * I could do all this in C, but this is easier.
     */

    if (interp != NULL) {
	if (Tcl_EvalEx(interp, "::incr ::tcl::zlib::cmdcounter",
		TCL_AUTO_LENGTH, 0) != TCL_OK) {
	    goto error;
	}
	Tcl_DStringInit(&cmdname);
	TclDStringAppendLiteral(&cmdname, "::tcl::zlib::streamcmd_");
	TclDStringAppendObj(&cmdname, Tcl_GetObjResult(interp));
	if (Tcl_FindCommand(interp, Tcl_DStringValue(&cmdname),
		NULL, 0) != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "BUG: Stream command name already exists", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "TCL", "BUG", "EXISTING_CMD", (char *)NULL);
	    Tcl_DStringFree(&cmdname);
	    goto error;
	}
	Tcl_ResetResult(interp);

	/*
	 * Create the command.
	 */

	zshPtr->cmd = Tcl_CreateObjCommand(interp, Tcl_DStringValue(&cmdname),
		ZlibStreamImplCmd, zshPtr, ZlibStreamCmdDelete);
	Tcl_DStringFree(&cmdname);
	if (zshPtr->cmd == NULL) {
	    goto error;
	}
    } else {
	zshPtr->cmd = NULL;
    }

    /*
     * Prepare the buffers for use.
     */

    zshPtr->inData = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(zshPtr->inData);
    zshPtr->outData = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(zshPtr->outData);

    zshPtr->outPos = 0;

    /*
     * Now set the variable pointed to by *zshandlePtr to the pointer to the
     * zsh struct.
     */

    if (zshandlePtr) {
	*zshandlePtr = (Tcl_ZlibStream) zshPtr;
    }

    return TCL_OK;

  error:
    if (zshPtr->compDictObj) {
	Tcl_DecrRefCount(zshPtr->compDictObj);
    }
    if (zshPtr->gzHeaderPtr) {
	Tcl_Free(zshPtr->gzHeaderPtr);
    }
    Tcl_Free(zshPtr);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibStreamCmdDelete --
 *
 *	This is the delete command which Tcl invokes when a zlibstream command
 *	is deleted from the interpreter (on stream close, usually).
 *
 * Results:
 *	None
 *
 * Side effects:
 *	Invalidates the zlib stream handle as obtained from Tcl_ZlibStreamInit
 *
 *----------------------------------------------------------------------
 */

static void
ZlibStreamCmdDelete(
    void *clientData)
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) clientData;

    zshPtr->cmd = NULL;
    ZlibStreamCleanup(zshPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamClose --
 *
 *	This procedure must be called after (de)compression is done to ensure
 *	memory is freed and the command is deleted from the interpreter (if
 *	any).
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Invalidates the zlib stream handle as obtained from Tcl_ZlibStreamInit
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamClose(
    Tcl_ZlibStream zshandle)	/* As obtained from Tcl_ZlibStreamInit. */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;

    /*
     * If the interp is set, deleting the command will trigger
     * ZlibStreamCleanup in ZlibStreamCmdDelete. If no interp is set, call
     * ZlibStreamCleanup directly.
     */

    if (zshPtr->interp && zshPtr->cmd) {
	Tcl_DeleteCommandFromToken(zshPtr->interp, zshPtr->cmd);
    } else {
	ZlibStreamCleanup(zshPtr);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibStreamCleanup --
 *
 *	This procedure is called by either Tcl_ZlibStreamClose or
 *	ZlibStreamCmdDelete to cleanup the stream context.
 *
 * Results:
 *	None
 *
 * Side effects:
 *	Invalidates the zlib stream handle.
 *
 *----------------------------------------------------------------------
 */

void
ZlibStreamCleanup(
    ZlibStreamHandle *zshPtr)
{
    if (!zshPtr->streamEnd) {
	if (zshPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	    deflateEnd(&zshPtr->stream);
	} else {
	    inflateEnd(&zshPtr->stream);
	}
    }

    if (zshPtr->inData) {
	Tcl_DecrRefCount(zshPtr->inData);
    }
    if (zshPtr->outData) {
	Tcl_DecrRefCount(zshPtr->outData);
    }
    if (zshPtr->currentInput) {
	Tcl_DecrRefCount(zshPtr->currentInput);
    }
    if (zshPtr->compDictObj) {
	Tcl_DecrRefCount(zshPtr->compDictObj);
    }
    if (zshPtr->gzHeaderPtr) {
	Tcl_Free(zshPtr->gzHeaderPtr);
    }

    Tcl_Free(zshPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamReset --
 *
 *	This procedure will reinitialize an existing stream handle.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Any data left in the (de)compression buffer is lost.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamReset(
    Tcl_ZlibStream zshandle)	/* As obtained from Tcl_ZlibStreamInit */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;
    int e;

    if (!zshPtr->streamEnd) {
	if (zshPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	    deflateEnd(&zshPtr->stream);
	} else {
	    inflateEnd(&zshPtr->stream);
	}
    }
    Tcl_SetByteArrayLength(zshPtr->inData, 0);
    Tcl_SetByteArrayLength(zshPtr->outData, 0);
    if (zshPtr->currentInput) {
	Tcl_DecrRefCount(zshPtr->currentInput);
	zshPtr->currentInput = NULL;
    }

    zshPtr->outPos = 0;
    zshPtr->streamEnd = 0;
    memset(&zshPtr->stream, 0, sizeof(z_stream));

    /*
     * No output buffer available yet.
     */

    if (zshPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	e = deflateInit2(&zshPtr->stream, zshPtr->level, Z_DEFLATED,
		zshPtr->wbits, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
	if (e == Z_OK && HaveDictToSet(zshPtr)) {
	    e = SetDeflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
	    if (e == Z_OK) {
		DictWasSet(zshPtr);
	    }
	}
    } else {
	e = inflateInit2(&zshPtr->stream, zshPtr->wbits);
	if (IsRawStream(zshPtr) && HaveDictToSet(zshPtr) && e == Z_OK) {
	    e = SetInflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
	    if (e == Z_OK) {
		DictWasSet(zshPtr);
	    }
	}
    }

    if (e != Z_OK) {
	ConvertError(zshPtr->interp, e, zshPtr->stream.adler);
	/* TODO:cleanup */
	return TCL_ERROR;
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamGetCommandName --
 *
 *	This procedure will return the command name associated with the
 *	stream.
 *
 * Results:
 *	A Tcl_Obj with the name of the Tcl command or NULL if no command is
 *	associated with the stream.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
Tcl_ZlibStreamGetCommandName(
    Tcl_ZlibStream zshandle)	/* As obtained from Tcl_ZlibStreamInit */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;
    Tcl_Obj *objPtr;

    if (!zshPtr->interp) {
	return NULL;
    }

    TclNewObj(objPtr);
    Tcl_GetCommandFullName(zshPtr->interp, zshPtr->cmd, objPtr);
    return objPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamEof --
 *
 *	This procedure This function returns 0 or 1 depending on the state of
 *	the (de)compressor. For decompression, eof is reached when the entire
 *	compressed stream has been decompressed. For compression, eof is
 *	reached when the stream has been flushed with TCL_ZLIB_FINALIZE.
 *
 * Results:
 *	Integer.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamEof(
    Tcl_ZlibStream zshandle)	/* As obtained from Tcl_ZlibStreamInit */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;

    return zshPtr->streamEnd;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamChecksum --
 *
 *	Return the checksum of the uncompressed data seen so far by the
 *	stream.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamChecksum(
    Tcl_ZlibStream zshandle)	/* As obtained from Tcl_ZlibStreamInit */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *)zshandle;

    return zshPtr->stream.adler;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamSetCompressionDictionary --
 *
 *	Sets the compression dictionary for a stream. This will be used as
 *	appropriate for the next compression or decompression action performed
 *	on the stream.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_ZlibStreamSetCompressionDictionary(
    Tcl_ZlibStream zshandle,
    Tcl_Obj *compressionDictionaryObj)
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;

    if (compressionDictionaryObj && (NULL == Tcl_GetBytesFromObj(NULL,
	    compressionDictionaryObj, (Tcl_Size *)NULL))) {
	/* Missing or invalid compression dictionary */
	compressionDictionaryObj = NULL;
    }
    if (compressionDictionaryObj != NULL) {
	if (Tcl_IsShared(compressionDictionaryObj)) {
	    compressionDictionaryObj =
		    Tcl_DuplicateObj(compressionDictionaryObj);
	}
	Tcl_IncrRefCount(compressionDictionaryObj);
	zshPtr->flags |= DICT_TO_SET;
    } else {
	zshPtr->flags &= ~DICT_TO_SET;
    }
    if (zshPtr->compDictObj != NULL) {
	Tcl_DecrRefCount(zshPtr->compDictObj);
    }
    zshPtr->compDictObj = compressionDictionaryObj;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamPut --
 *
 *	Add data to the stream for compression or decompression from a
 *	bytearray Tcl_Obj.
 *
 *----------------------------------------------------------------------
 */

#define BUFFER_SIZE_LIMIT	0xFFFF

int
Tcl_ZlibStreamPut(
    Tcl_ZlibStream zshandle,	/* As obtained from Tcl_ZlibStreamInit */
    Tcl_Obj *data,		/* Data to compress/decompress */
    int flush)			/* TCL_ZLIB_NO_FLUSH, TCL_ZLIB_FLUSH,
				 * TCL_ZLIB_FULLFLUSH, or TCL_ZLIB_FINALIZE */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;
    char *dataTmp = NULL;
    int e;
    Tcl_Size size = 0;
    size_t outSize, toStore;
    unsigned char *bytes;

    if (zshPtr->streamEnd) {
	if (zshPtr->interp) {
	    Tcl_SetObjResult(zshPtr->interp, Tcl_NewStringObj(
		    "already past compressed stream end", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(zshPtr->interp, "TCL", "ZIP", "CLOSED", (char *)NULL);
	}
	return TCL_ERROR;
    }

    bytes = Tcl_GetBytesFromObj(zshPtr->interp, data, &size);
    if (bytes == NULL) {
	return TCL_ERROR;
    }

    if (zshPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	zshPtr->stream.next_in = bytes;
	zshPtr->stream.avail_in = size;

	/*
	 * Must not do a zero-length compress unless finalizing. [Bug 25842c161]
	 */

	if (size == 0 && flush != Z_FINISH) {
	    return TCL_OK;
	}

	if (HaveDictToSet(zshPtr)) {
	    e = SetDeflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
	    if (e != Z_OK) {
		ConvertError(zshPtr->interp, e, zshPtr->stream.adler);
		return TCL_ERROR;
	    }
	    DictWasSet(zshPtr);
	}

	/*
	 * deflateBound() doesn't seem to take various header sizes into
	 * account, so we add 100 extra bytes. However, we can also loop
	 * around again so we also set an upper bound on the output buffer
	 * size.
	 */

	outSize = deflateBound(&zshPtr->stream, size) + 100;
	if (outSize > BUFFER_SIZE_LIMIT) {
	    outSize = BUFFER_SIZE_LIMIT;
	}
	dataTmp = (char *) Tcl_Alloc(outSize);

	while (1) {
	    e = Deflate(&zshPtr->stream, dataTmp, outSize, flush, &toStore);

	    /*
	     * Test if we've filled the buffer up and have to ask deflate() to
	     * give us some more. Note that the condition for needing to
	     * repeat a buffer transfer when the result is Z_OK is whether
	     * there is no more space in the buffer we provided; the zlib
	     * library does not necessarily return a different code in that
	     * case. [Bug b26e38a3e4] [Tk Bug 10f2e7872b]
	     */

	    if ((e != Z_BUF_ERROR) && (e != Z_OK || toStore < outSize)) {
		if ((e == Z_OK) || (flush == Z_FINISH && e == Z_STREAM_END)) {
		    break;
		}
		ConvertError(zshPtr->interp, e, zshPtr->stream.adler);
		return TCL_ERROR;
	    }

	    /*
	     * Output buffer too small to hold the data being generated or we
	     * are doing the end-of-stream flush (which can spit out masses of
	     * data). This means we need to put a new buffer into place after
	     * saving the old generated data to the outData list.
	     */

	    AppendByteArray(zshPtr->outData, dataTmp, outSize);

	    if (outSize < BUFFER_SIZE_LIMIT) {
		outSize = BUFFER_SIZE_LIMIT;
		/* There may be *lots* of data left to output... */
		dataTmp = (char *) Tcl_Realloc(dataTmp, outSize);
	    }
	}

	/*
	 * And append the final data block to the outData list.
	 */

	AppendByteArray(zshPtr->outData, dataTmp, toStore);
	Tcl_Free(dataTmp);
    } else {
	/*
	 * This is easy. Just append to the inData list.
	 */

	Tcl_ListObjAppendElement(NULL, zshPtr->inData, data);

	/*
	 * and we'll need the flush parameter for the Inflate call.
	 */

	zshPtr->flush = flush;
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibStreamGet --
 *
 *	Retrieve data (now compressed or decompressed) from the stream into a
 *	bytearray Tcl_Obj.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibStreamGet(
    Tcl_ZlibStream zshandle,	/* As obtained from Tcl_ZlibStreamInit */
    Tcl_Obj *data,		/* A place to append the data. */
    Tcl_Size count)		/* Number of bytes to grab as a maximum, you
				 * may get less! */
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) zshandle;
    int e;
    Tcl_Size listLen, i, itemLen = 0, dataPos = 0;
    Tcl_Obj *itemObj;
    unsigned char *dataPtr, *itemPtr;
    Tcl_Size existing = 0;

    /*
     * Getting beyond the of stream, just return empty string.
     */

    if (zshPtr->streamEnd) {
	return TCL_OK;
    }

    if (NULL == Tcl_GetBytesFromObj(zshPtr->interp, data, &existing)) {
	return TCL_ERROR;
    }

    if (zshPtr->mode == TCL_ZLIB_STREAM_INFLATE) {
	if (count < 0) {
	    /*
	     * The only safe thing to do is restict to 65k. We might cause a
	     * panic for out of memory if we just kept growing the buffer.
	     */

	    count = MAX_BUFFER_SIZE;
	}

	/*
	 * Prepare the place to store the data.
	 */

	dataPtr = Tcl_SetByteArrayLength(data, existing + count);
	dataPtr += existing;

	zshPtr->stream.next_out = dataPtr;
	zshPtr->stream.avail_out = count;
	if (zshPtr->stream.avail_in == 0) {
	    /*
	     * zlib will probably need more data to decompress.
	     */

	    if (zshPtr->currentInput) {
		Tcl_DecrRefCount(zshPtr->currentInput);
		zshPtr->currentInput = NULL;
	    }
	    TclListObjLength(NULL, zshPtr->inData, &listLen);
	    if (listLen > 0) {
		/*
		 * There is more input available, get it from the list and
		 * give it to zlib. At this point, the data must not be shared
		 * since we require the bytearray representation to not vanish
		 * under our feet. [Bug 3081008]
		 */

		Tcl_ListObjIndex(NULL, zshPtr->inData, 0, &itemObj);
		if (Tcl_IsShared(itemObj)) {
		    itemObj = Tcl_DuplicateObj(itemObj);
		}
		itemPtr = Tcl_GetBytesFromObj(NULL, itemObj, &itemLen);
		Tcl_IncrRefCount(itemObj);
		zshPtr->currentInput = itemObj;
		zshPtr->stream.next_in = itemPtr;
		zshPtr->stream.avail_in = itemLen;

		/*
		 * And remove it from the list
		 */

		Tcl_ListObjReplace(NULL, zshPtr->inData, 0, 1, 0, NULL);
	    }
	}

	/*
	 * When dealing with a raw stream, we set the dictionary here, once.
	 * (You can't do it in response to getting Z_NEED_DATA as raw streams
	 * don't ever issue that.)
	 */

	if (IsRawStream(zshPtr) && HaveDictToSet(zshPtr)) {
	    e = SetInflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
	    if (e != Z_OK) {
		ConvertError(zshPtr->interp, e, zshPtr->stream.adler);
		return TCL_ERROR;
	    }
	    DictWasSet(zshPtr);
	}
	e = inflate(&zshPtr->stream, zshPtr->flush);
	if (e == Z_NEED_DICT && HaveDictToSet(zshPtr)) {
	    e = SetInflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
	    if (e == Z_OK) {
		DictWasSet(zshPtr);
		e = inflate(&zshPtr->stream, zshPtr->flush);
	    }
	};
	TclListObjLength(NULL, zshPtr->inData, &listLen);

	while ((zshPtr->stream.avail_out > 0)
		&& (e == Z_OK || e == Z_BUF_ERROR) && (listLen > 0)) {
	    /*
	     * State: We have not satisfied the request yet and there may be
	     * more to inflate.
	     */

	    if (zshPtr->stream.avail_in > 0) {
		if (zshPtr->interp) {
		    Tcl_SetObjResult(zshPtr->interp, Tcl_NewStringObj(
			    "unexpected zlib internal state during"
			    " decompression", TCL_AUTO_LENGTH));
		    Tcl_SetErrorCode(zshPtr->interp, "TCL", "ZIP", "STATE",
			    (char *)NULL);
		}
		Tcl_SetByteArrayLength(data, existing);
		return TCL_ERROR;
	    }

	    if (zshPtr->currentInput) {
		Tcl_DecrRefCount(zshPtr->currentInput);
		zshPtr->currentInput = 0;
	    }

	    /*
	     * Get the next block of data to go to inflate. At this point, the
	     * data must not be shared since we require the bytearray
	     * representation to not vanish under our feet. [Bug 3081008]
	     */

	    Tcl_ListObjIndex(zshPtr->interp, zshPtr->inData, 0, &itemObj);
	    if (Tcl_IsShared(itemObj)) {
		itemObj = Tcl_DuplicateObj(itemObj);
	    }
	    itemPtr = Tcl_GetBytesFromObj(NULL, itemObj, &itemLen);
	    Tcl_IncrRefCount(itemObj);
	    zshPtr->currentInput = itemObj;
	    zshPtr->stream.next_in = itemPtr;
	    zshPtr->stream.avail_in = itemLen;

	    /*
	     * Remove it from the list.
	     */

	    Tcl_ListObjReplace(NULL, zshPtr->inData, 0, 1, 0, NULL);
	    listLen--;

	    /*
	     * And call inflate again.
	     */

	    do {
		e = inflate(&zshPtr->stream, zshPtr->flush);
		if (e != Z_NEED_DICT || !HaveDictToSet(zshPtr)) {
		    break;
		}
		e = SetInflateDictionary(&zshPtr->stream, zshPtr->compDictObj);
		DictWasSet(zshPtr);
	    } while (e == Z_OK);
	}
	if (zshPtr->stream.avail_out > 0) {
	    Tcl_SetByteArrayLength(data,
		    existing + count - zshPtr->stream.avail_out);
	}
	if (!(e==Z_OK || e==Z_STREAM_END || e==Z_BUF_ERROR)) {
	    Tcl_SetByteArrayLength(data, existing);
	    ConvertError(zshPtr->interp, e, zshPtr->stream.adler);
	    return TCL_ERROR;
	}
	if (e == Z_STREAM_END) {
	    zshPtr->streamEnd = 1;
	    if (zshPtr->currentInput) {
		Tcl_DecrRefCount(zshPtr->currentInput);
		zshPtr->currentInput = 0;
	    }
	    inflateEnd(&zshPtr->stream);
	}
    } else {
	TclListObjLength(NULL, zshPtr->outData, &listLen);
	if (count < 0) {
	    count = 0;
	    for (i=0; i<listLen; i++) {
		Tcl_ListObjIndex(NULL, zshPtr->outData, i, &itemObj);
		(void) Tcl_GetBytesFromObj(NULL, itemObj, &itemLen);
		if (i == 0) {
		    count += itemLen - zshPtr->outPos;
		} else {
		    count += itemLen;
		}
	    }
	}

	/*
	 * Prepare the place to store the data.
	 */

	dataPtr = Tcl_SetByteArrayLength(data, existing + count);
	dataPtr += existing;

	while ((count > dataPos) &&
		(TclListObjLength(NULL, zshPtr->outData, &listLen) == TCL_OK)
		&& (listLen > 0)) {
	    /*
	     * Get the next chunk off our list of chunks and grab the data out
	     * of it.
	     */

	    Tcl_ListObjIndex(NULL, zshPtr->outData, 0, &itemObj);
	    itemPtr = Tcl_GetBytesFromObj(NULL, itemObj, &itemLen);
	    if ((itemLen - zshPtr->outPos) >= (count - dataPos)) {
		Tcl_Size len = count - dataPos;

		memcpy(dataPtr + dataPos, itemPtr + zshPtr->outPos, len);
		zshPtr->outPos += len;
		dataPos += len;
		if (zshPtr->outPos == itemLen) {
		    zshPtr->outPos = 0;
		}
	    } else {
		Tcl_Size len = itemLen - zshPtr->outPos;

		memcpy(dataPtr + dataPos, itemPtr + zshPtr->outPos, len);
		dataPos += len;
		zshPtr->outPos = 0;
	    }
	    if (zshPtr->outPos == 0) {
		Tcl_ListObjReplace(NULL, zshPtr->outData, 0, 1, 0, NULL);
		listLen--;
	    }
	}
	Tcl_SetByteArrayLength(data, existing + dataPos);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibDeflate --
 *
 *	Compress the contents of Tcl_Obj *data with compression level in
 *	output format, producing the compressed data in the interpreter
 *	result.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibDeflate(
    Tcl_Interp *interp,
    int format,
    Tcl_Obj *data,
    int level,
    Tcl_Obj *gzipHeaderDictObj)
{
    int wbits = 0, e = 0, extraSize = 0;
    Tcl_Size inLen = 0;
    Byte *inData = NULL;
    z_stream stream;
    GzipHeader header;
    gz_header *headerPtr = NULL;
    Tcl_Obj *obj;

    if (!interp) {
	return TCL_ERROR;
    }

    /*
     * Obtain the pointer to the byte array, we'll pass this pointer straight
     * to the deflate command.
     */

    inData = Tcl_GetBytesFromObj(interp, data, &inLen);
    if (inData == NULL) {
	return TCL_ERROR;
    }

    /*
     * Compressed format is specified by the wbits parameter. See zlib.h for
     * details.
     */

    if (format == TCL_ZLIB_FORMAT_RAW) {
	wbits = WBITS_RAW;
    } else if (format == TCL_ZLIB_FORMAT_GZIP) {
	wbits = WBITS_GZIP;

	/*
	 * Need to allocate extra space for the gzip header and footer. The
	 * amount of space is (a bit less than) 32 bytes, plus a byte for each
	 * byte of string that we add. Note that over-allocation is not a
	 * problem. [Bug 2419061]
	 */

	extraSize = 32;
	if (gzipHeaderDictObj) {
	    headerPtr = &header.header;
	    memset(headerPtr, 0, sizeof(gz_header));
	    if (GenerateHeader(interp, gzipHeaderDictObj, &header,
		    &extraSize) != TCL_OK) {
		return TCL_ERROR;
	    }
	}
    } else if (format == TCL_ZLIB_FORMAT_ZLIB) {
	wbits = WBITS_ZLIB;
    } else {
	Tcl_Panic("incorrect zlib data format, must be TCL_ZLIB_FORMAT_ZLIB, "
		"TCL_ZLIB_FORMAT_GZIP or TCL_ZLIB_FORMAT_ZLIB");
    }

    if (level < Z_DEFAULT_COMPRESSION || level > Z_BEST_COMPRESSION) {
	Tcl_Panic("compression level should be between %d (uncompressed) and "
		"%d (best compression) or %d for default compression level",
		Z_NO_COMPRESSION, Z_BEST_COMPRESSION, Z_DEFAULT_COMPRESSION);
    }

    /*
     * Allocate some space to store the output.
     */

    TclNewObj(obj);

    memset(&stream, 0, sizeof(z_stream));
    stream.avail_in = inLen;
    stream.next_in = inData;

    /*
     * No output buffer available yet, will alloc after deflateInit2.
     */

    e = deflateInit2(&stream, level, Z_DEFLATED, wbits, MAX_MEM_LEVEL,
	    Z_DEFAULT_STRATEGY);
    if (e != Z_OK) {
	goto error;
    }

    if (headerPtr != NULL) {
	e = deflateSetHeader(&stream, headerPtr);
	if (e != Z_OK) {
	    goto error;
	}
    }

    /*
     * Allocate the output buffer from the value of deflateBound(). This is
     * probably too much space. Before returning to the caller, we will reduce
     * it back to the actual compressed size.
     */

    stream.avail_out = deflateBound(&stream, inLen) + extraSize;
    stream.next_out = Tcl_SetByteArrayLength(obj, stream.avail_out);

    /*
     * Perform the compression, Z_FINISH means do it in one go.
     */

    e = deflate(&stream, Z_FINISH);

    if (e != Z_STREAM_END) {
	e = deflateEnd(&stream);

	/*
	 * deflateEnd() returns Z_OK when there are bytes left to compress, at
	 * this point we consider that an error, although we could continue by
	 * allocating more memory and calling deflate() again.
	 */

	if (e == Z_OK) {
	    e = Z_BUF_ERROR;
	}
    } else {
	e = deflateEnd(&stream);
    }

    if (e != Z_OK) {
	goto error;
    }

    /*
     * Reduce the ByteArray length to the actual data length produced by
     * deflate.
     */

    Tcl_SetByteArrayLength(obj, stream.total_out);
    Tcl_SetObjResult(interp, obj);
    return TCL_OK;

  error:
    ConvertError(interp, e, stream.adler);
    TclDecrRefCount(obj);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibInflate --
 *
 *	Decompress data in an object into the interpreter result.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ZlibInflate(
    Tcl_Interp *interp,
    int format,
    Tcl_Obj *data,
    Tcl_Size bufferSize,
    Tcl_Obj *gzipHeaderDictObj)
{
    int wbits = 0, e = 0;
    Tcl_Size inLen = 0, newBufferSize;
    Byte *inData = NULL, *outData = NULL, *newOutData = NULL;
    z_stream stream;
    gz_header header, *headerPtr = NULL;
    Tcl_Obj *obj;
    char *nameBuf = NULL, *commentBuf = NULL;

    if (!interp) {
	return TCL_ERROR;
    }

    inData = Tcl_GetBytesFromObj(interp, data, &inLen);
    if (inData == NULL) {
	return TCL_ERROR;
    }

    /*
     * Compressed format is specified by the wbits parameter. See zlib.h for
     * details.
     */

    switch (format) {
    case TCL_ZLIB_FORMAT_RAW:
	wbits = WBITS_RAW;
	gzipHeaderDictObj = NULL;
	break;
    case TCL_ZLIB_FORMAT_ZLIB:
	wbits = WBITS_ZLIB;
	gzipHeaderDictObj = NULL;
	break;
    case TCL_ZLIB_FORMAT_GZIP:
	wbits = WBITS_GZIP;
	break;
    case TCL_ZLIB_FORMAT_AUTO:
	wbits = WBITS_AUTODETECT;
	break;
    default:
	Tcl_Panic("incorrect zlib data format, must be TCL_ZLIB_FORMAT_ZLIB, "
		"TCL_ZLIB_FORMAT_GZIP, TCL_ZLIB_FORMAT_RAW or "
		"TCL_ZLIB_FORMAT_AUTO");
    }

    if (gzipHeaderDictObj) {
	headerPtr = &header;
	memset(headerPtr, 0, sizeof(gz_header));
	nameBuf = (char *) Tcl_Alloc(MAXPATHLEN);
	header.name = (Bytef *) nameBuf;
	header.name_max = MAXPATHLEN - 1;
	commentBuf = (char *) Tcl_Alloc(MAX_COMMENT_LEN);
	header.comment = (Bytef *) commentBuf;
	header.comm_max = MAX_COMMENT_LEN - 1;
    }

    if (bufferSize < 1) {
	/*
	 * Start with a buffer (up to) 3 times the size of the input data.
	 */

	if (inLen < 32 * 1024 * 1024) {
	    bufferSize = 3 * inLen;
	} else if (inLen < 256 * 1024 * 1024) {
	    bufferSize = 2 * inLen;
	} else {
	    bufferSize = inLen;
	}
    }

    TclNewObj(obj);
    outData = Tcl_SetByteArrayLength(obj, bufferSize);
    memset(&stream, 0, sizeof(z_stream));
    stream.avail_in = inLen+1;	/* +1 because zlib can "over-request"
				 * input (but ignore it!) */
    stream.next_in = inData;
    stream.avail_out = bufferSize;
    stream.next_out = outData;

    /*
     * Initialize zlib for decompression.
     */

    e = inflateInit2(&stream, wbits);
    if (e != Z_OK) {
	goto error;
    }
    if (headerPtr) {
	e = inflateGetHeader(&stream, headerPtr);
	if (e != Z_OK) {
	    inflateEnd(&stream);
	    goto error;
	}
    }

    /*
     * Start the decompression cycle.
     */

    while (1) {
	e = inflate(&stream, Z_FINISH);
	if (e != Z_BUF_ERROR) {
	    break;
	}

	/*
	 * Not enough room in the output buffer. Increase it by five times the
	 * bytes still in the input buffer. (Because 3 times didn't do the
	 * trick before, 5 times is what we do next.) Further optimization
	 * should be done by the user, specify the decompressed size!
	 */

	if ((stream.avail_in == 0) && (stream.avail_out > 0)) {
	    e = Z_STREAM_ERROR;
	    break;
	}
	newBufferSize = bufferSize + 5 * stream.avail_in;
	if (newBufferSize == bufferSize) {
	    newBufferSize = bufferSize + 1000;
	}
	newOutData = Tcl_SetByteArrayLength(obj, newBufferSize);

	/*
	 * Set next out to the same offset in the new location.
	 */

	stream.next_out = newOutData + stream.total_out;

	/*
	 * And increase avail_out with the number of new bytes allocated.
	 */

	stream.avail_out += newBufferSize - bufferSize;
	outData = newOutData;
	bufferSize = newBufferSize;
    }

    if (e != Z_STREAM_END) {
	inflateEnd(&stream);
	goto error;
    }

    e = inflateEnd(&stream);
    if (e != Z_OK) {
	goto error;
    }

    /*
     * Reduce the BA length to the actual data length produced by deflate.
     */

    Tcl_SetByteArrayLength(obj, stream.total_out);
    if (headerPtr != NULL) {
	ExtractHeader(&header, gzipHeaderDictObj);
	TclDictPut(NULL, gzipHeaderDictObj, "size",
		Tcl_NewWideIntObj(stream.total_out));
	Tcl_Free(nameBuf);
	Tcl_Free(commentBuf);
    }
    Tcl_SetObjResult(interp, obj);
    return TCL_OK;

  error:
    TclDecrRefCount(obj);
    ConvertError(interp, e, stream.adler);
    if (nameBuf) {
	Tcl_Free(nameBuf);
    }
    if (commentBuf) {
	Tcl_Free(commentBuf);
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ZlibCRC32, Tcl_ZlibAdler32 --
 *
 *	Access to the checksumming engines.
 *
 *----------------------------------------------------------------------
 */

unsigned int
Tcl_ZlibCRC32(
    unsigned int crc,
    const unsigned char *buf,
    Tcl_Size len)
{
    /* Nothing much to do, just wrap the crc32(). */
    return crc32(crc, (Bytef *) buf, len);
}

unsigned int
Tcl_ZlibAdler32(
    unsigned int adler,
    const unsigned char *buf,
    Tcl_Size len)
{
    return adler32(adler, (Bytef *) buf, len);
}

/*
 *----------------------------------------------------------------------
 *
 * GetLevelFromObj --
 *
 *	Helper for getting the compression level for compression operations.
 *
 *	levelPtr is assumed to point to a variable that has been initialised
 *	to Z_DEFAULT_COMPRESSION (or that will be initialised to that on code
 *	paths that don't go through this function); the default compression
 *	level is to be selected by *not* invoking this function.
 *
 *----------------------------------------------------------------------
 */
static int
GetLevelFromObj(
    Tcl_Interp *interp,		/* Where to put error messages. NULLable. */
    Tcl_Obj *levelObj,		/* Value to parse. NULL for default. */
    int *levelPtr)		/* Where to write the compression level. */
{
    int level;

    if (levelObj == NULL) {
	*levelPtr = Z_DEFAULT_COMPRESSION;
	return TCL_OK;
    }
    if (TclGetIntFromObj(interp, levelObj, &level) != TCL_OK) {
	return TCL_ERROR;
    }
    if (level < Z_NO_COMPRESSION || level > Z_BEST_COMPRESSION) {
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "level must be %d to %d",
		    Z_NO_COMPRESSION, Z_BEST_COMPRESSION));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "COMPRESSIONLEVEL", (char *)NULL);
	}
	return TCL_ERROR;
    }
    *levelPtr = level;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * GetBufferSizeFromObj --
 *
 *	Helper for getting the buffer size for decompression operations.
 *
 *	Not intended for streaming decompression operations, where buffer
 *	sizes can be smaller.
 *
 *----------------------------------------------------------------------
 */
static int
GetBufferSizeFromObj(
    Tcl_Interp *interp,		/* Where to put error messages. NULLable. */
    Tcl_Obj *bufferSizeObj,	/* Value to parse. */
    size_t *bufferSizePtr)	/* Where to write the buffer size. */
{
    Tcl_WideInt wideLen;

    if (TclGetWideIntFromObj(interp, bufferSizeObj, &wideLen) != TCL_OK) {
	return TCL_ERROR;
    }
    if (wideLen < MIN_NONSTREAM_BUFFER_SIZE || wideLen > MAX_BUFFER_SIZE) {
	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "buffer size must be %d to %d",
		    MIN_NONSTREAM_BUFFER_SIZE, MAX_BUFFER_SIZE));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "BUFFERSIZE", (char *)NULL);
	}
	return TCL_ERROR;
    }
    *bufferSizePtr = (size_t) wideLen;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibAdler32Cmd --
 *
 *	Implementation of the [zlib adler32] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibAdler32Cmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Size dlen = 0;
    const unsigned char *data;
    unsigned int start;

    if (objc < 1 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?startValue?");
	return TCL_ERROR;
    }
    data = Tcl_GetBytesFromObj(interp, objv[1], &dlen);
    if (data == NULL) {
	return TCL_ERROR;
    }
    if (objc < 3) {
	start = Tcl_ZlibAdler32(0, NULL, 0);
    } else if (Tcl_GetIntFromObj(interp, objv[2], (int *) &start) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(
	    Tcl_ZlibAdler32(start, data, dlen)));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibCRC32Cmd --
 *
 *	Implementation of the [zlib crc32] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibCRC32Cmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Size dlen = 0;
    const unsigned char *data;
    unsigned int start;

    if (objc < 1 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?startValue?");
	return TCL_ERROR;
    }
    data = Tcl_GetBytesFromObj(interp, objv[1], &dlen);
    if (data == NULL) {
	return TCL_ERROR;
    }
    if (objc < 3) {
	start = Tcl_ZlibCRC32(0, NULL, 0);
    } else if (Tcl_GetIntFromObj(interp, objv[2], (int *) &start) != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(
	    Tcl_ZlibCRC32(start, data, dlen)));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibDeflateCmd --
 *
 *	Implementation of the [zlib deflate] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibDeflateCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    int level;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?level?");
	return TCL_ERROR;
    }
    if (GetLevelFromObj(interp, (objc > 2 ? objv[2] : NULL), &level) != TCL_OK) {
	return TCL_ERROR;
    }
    return Tcl_ZlibDeflate(interp, TCL_ZLIB_FORMAT_RAW, objv[1], level, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibCompressCmd --
 *
 *	Implementation of the [zlib compress] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibCompressCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    int level;

    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?level?");
	return TCL_ERROR;
    }
    if (GetLevelFromObj(interp, (objc > 2 ? objv[2] : NULL), &level) != TCL_OK) {
	return TCL_ERROR;
    }
    return Tcl_ZlibDeflate(interp, TCL_ZLIB_FORMAT_ZLIB, objv[1], level, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibGzipCmd --
 *
 *	Implementation of the [zlib gzip] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibGzipCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const gzipopts[] = {
	"-header", "-level", NULL
    };
    Tcl_Obj *headerDictObj = NULL;
    int level = Z_DEFAULT_COMPRESSION, i, option;

    /*
     * Legacy argument format support.
     */

    if (objc == 3 && Tcl_GetIntFromObj(NULL, objv[2], &level) == TCL_OK) {
	if (GetLevelFromObj(interp, objv[2], &level) != TCL_OK) {
	    Tcl_AddErrorInfo(interp, "\n    (in level parameter)");
	    return TCL_ERROR;
	}
	return Tcl_ZlibDeflate(interp, TCL_ZLIB_FORMAT_GZIP, objv[1],
		level, NULL);
    }

    if (objc < 2 || objc > 6 || (objc & 1)) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"data ?-level level? ?-header header?");
	return TCL_ERROR;
    }
    for (i=2 ; i<objc ; i+=2) {
	if (Tcl_GetIndexFromObj(interp, objv[i], gzipopts, "option", 0,
		&option) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (option) {
	case 0:		// -header
	    headerDictObj = objv[i + 1];
	    break;
	case 1:		// -level
	    if (GetLevelFromObj(interp, objv[i + 1], &level) != TCL_OK) {
		Tcl_AddErrorInfo(interp, "\n    (in -level option)");
		return TCL_ERROR;
	    }
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }
    return Tcl_ZlibDeflate(interp, TCL_ZLIB_FORMAT_GZIP, objv[1], level,
	    headerDictObj);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibInflateCmd --
 *
 *	Implementation of the [zlib inflate] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibInflateCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    size_t buffersize = 0;
    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?bufferSize?");
	return TCL_ERROR;
    }
    if (objc > 2 && GetBufferSizeFromObj(interp, objv[2], &buffersize) != TCL_OK) {
	return TCL_ERROR;
    }
    return Tcl_ZlibInflate(interp, TCL_ZLIB_FORMAT_RAW, objv[1], buffersize, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibDecompressCmd --
 *
 *	Implementation of the [zlib decompress] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibDecompressCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    size_t buffersize = 0;
    if (objc < 2 || objc > 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "data ?bufferSize?");
	return TCL_ERROR;
    }
    if (objc > 2 && GetBufferSizeFromObj(interp, objv[2], &buffersize) != TCL_OK) {
	return TCL_ERROR;
    }
    return Tcl_ZlibInflate(interp, TCL_ZLIB_FORMAT_ZLIB, objv[1], buffersize, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibGunzipCmd --
 *
 *	Implementation of the [zlib gunzip] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibGunzipCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const gunzipopts[] = {
	"-buffersize", "-headerVar", NULL
    };
    Tcl_Obj *headerVarObj = NULL, *headerDictObj = NULL;
    size_t buffersize = 0;
    int i, option;

    if (objc < 2 || objc > 6 || (objc & 1)) {
	Tcl_WrongNumArgs(interp, 2, objv, "data ?-headerVar varName?");
	return TCL_ERROR;
    }

    for (i=2 ; i<objc ; i+=2) {
	if (Tcl_GetIndexFromObj(interp, objv[i], gunzipopts, "option", 0,
		&option) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (option) {
	case 0:		// -buffersize
	    if (GetBufferSizeFromObj(interp, objv[i + 1], &buffersize) != TCL_OK) {
		return TCL_ERROR;
	    }
	    break;
	case 1:		// -headerVar
	    headerVarObj = objv[i + 1];
	    TclNewObj(headerDictObj);
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    if (Tcl_ZlibInflate(interp, TCL_ZLIB_FORMAT_GZIP, objv[1], buffersize,
	    headerDictObj) != TCL_OK) {
	if (headerDictObj) {
	    TclDecrRefCount(headerDictObj);
	}
	return TCL_ERROR;
    }

    if (headerVarObj && Tcl_ObjSetVar2(interp, headerVarObj, NULL,
	    headerDictObj, TCL_LEAVE_ERR_MSG) == NULL) {
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibStreamCmd --
 *
 *	Implementation of the [zlib stream] command.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibStreamCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const stream_formats[] = {
	"compress", "decompress", "deflate", "gunzip", "gzip", "inflate",
	NULL
    };
    enum zlibFormats {
	FMT_COMPRESS, FMT_DECOMPRESS, FMT_DEFLATE, FMT_GUNZIP, FMT_GZIP,
	FMT_INFLATE
    } fmt;
    int i, format, mode = 0, option, level;
    enum objIndices {
	OPT_COMPRESSION_DICTIONARY = 0,
	OPT_GZIP_HEADER = 1,
	OPT_COMPRESSION_LEVEL = 2,
	OPT_END = -1
    };
    Tcl_Obj *obj[3] = { NULL, NULL, NULL };
#define compDictObj	obj[OPT_COMPRESSION_DICTIONARY]
#define gzipHeaderObj	obj[OPT_GZIP_HEADER]
#define levelObj	obj[OPT_COMPRESSION_LEVEL]
    typedef struct {
	const char *name;
	enum objIndices offset;
    } OptDescriptor;
    static const OptDescriptor compressionOpts[] = {
	{ "-dictionary", OPT_COMPRESSION_DICTIONARY },
	{ "-level",	 OPT_COMPRESSION_LEVEL },
	{ NULL, OPT_END }
    };
    static const OptDescriptor gzipOpts[] = {
	{ "-header",	 OPT_GZIP_HEADER },
	{ "-level",	 OPT_COMPRESSION_LEVEL },
	{ NULL, OPT_END }
    };
    static const OptDescriptor expansionOpts[] = {
	{ "-dictionary", OPT_COMPRESSION_DICTIONARY },
	{ NULL, OPT_END }
    };
    static const OptDescriptor gunzipOpts[] = {
	{ NULL, OPT_END }
    };
    const OptDescriptor *desc = NULL;
    Tcl_ZlibStream zh;

    if (objc < 2 || (objc & 1)) {
	Tcl_WrongNumArgs(interp, 1, objv, "mode ?-option value...?");
	return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(interp, objv[1], stream_formats, "mode", 0,
	    &fmt) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * The format determines the compression mode and the options that may be
     * specified.
     */

    switch (fmt) {
    case FMT_DEFLATE:
	desc = compressionOpts;
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_RAW;
	break;
    case FMT_INFLATE:
	desc = expansionOpts;
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_RAW;
	break;
    case FMT_COMPRESS:
	desc = compressionOpts;
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_ZLIB;
	break;
    case FMT_DECOMPRESS:
	desc = expansionOpts;
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_ZLIB;
	break;
    case FMT_GZIP:
	desc = gzipOpts;
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_GZIP;
	break;
    case FMT_GUNZIP:
	desc = gunzipOpts;
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_GZIP;
	break;
    default:
	TCL_UNREACHABLE();
    }

    /*
     * Parse the options.
     */

    for (i=2 ; i<objc ; i+=2) {
	if (Tcl_GetIndexFromObjStruct(interp, objv[i], desc,
		sizeof(OptDescriptor), "option", 0, &option) != TCL_OK) {
	    return TCL_ERROR;
	}
	obj[desc[option].offset] = objv[i + 1];
    }

    /*
     * If a compression level was given, parse it (integral: 0..9). Otherwise
     * use the default.
     */

    if (GetLevelFromObj(interp, levelObj, &level) != TCL_OK) {
	Tcl_AddErrorInfo(interp, "\n    (in -level option)");
	return TCL_ERROR;
    }

    if (compDictObj) {
	if (NULL == Tcl_GetBytesFromObj(interp, compDictObj, (Tcl_Size *)NULL)) {
	    return TCL_ERROR;
	}
    }

    /*
     * Construct the stream now we know its configuration.
     */

    if (Tcl_ZlibStreamInit(interp, mode, format, level, gzipHeaderObj,
	    &zh) != TCL_OK) {
	return TCL_ERROR;
    }
    if (compDictObj != NULL) {
	Tcl_ZlibStreamSetCompressionDictionary(zh, compDictObj);
    }
    Tcl_SetObjResult(interp, Tcl_ZlibStreamGetCommandName(zh));
    return TCL_OK;
#undef compDictObj
#undef gzipHeaderObj
#undef levelObj
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibPushCmd --
 *
 *	Implementation of the [zlib push] subcommand.
 *
 *----------------------------------------------------------------------
 */
static int
ZlibPushCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const stream_formats[] = {
	"compress", "decompress", "deflate", "gunzip", "gzip", "inflate",
	NULL
    };
    enum zlibFormats {
	FMT_COMPRESS, FMT_DECOMPRESS, FMT_DEFLATE, FMT_GUNZIP, FMT_GZIP,
	FMT_INFLATE
    } fmt;
    Tcl_Channel chan;
    int chanMode, format, mode = 0, level, i;
    static const char *const pushCompressOptions[] = {
	"-dictionary", "-header", "-level", NULL
    };
    static const char *const pushDecompressOptions[] = {
	"-dictionary", "-header", "-level", "-limit", NULL
    };
    const char *const *pushOptions = pushDecompressOptions;
    enum pushOptionsEnum {poDictionary, poHeader, poLevel, poLimit} option;
    Tcl_Obj *headerObj = NULL, *compDictObj = NULL;
    int limit = DEFAULT_BUFFER_SIZE;
    Tcl_Size dummy;

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "mode channel ?options...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], stream_formats, "mode", 0,
	    &fmt) != TCL_OK) {
	return TCL_ERROR;
    }
    switch (fmt) {
    case FMT_DEFLATE:
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_RAW;
	pushOptions = pushCompressOptions;
	break;
    case FMT_INFLATE:
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_RAW;
	break;
    case FMT_COMPRESS:
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_ZLIB;
	pushOptions = pushCompressOptions;
	break;
    case FMT_DECOMPRESS:
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_ZLIB;
	break;
    case FMT_GZIP:
	mode = TCL_ZLIB_STREAM_DEFLATE;
	format = TCL_ZLIB_FORMAT_GZIP;
	pushOptions = pushCompressOptions;
	break;
    case FMT_GUNZIP:
	mode = TCL_ZLIB_STREAM_INFLATE;
	format = TCL_ZLIB_FORMAT_GZIP;
	break;
    default:
	TCL_UNREACHABLE();
    }

    if (TclGetChannelFromObj(interp, objv[2], &chan, &chanMode, 0) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Sanity checks.
     */

    if (mode == TCL_ZLIB_STREAM_DEFLATE && !(chanMode & TCL_WRITABLE)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"compression may only be applied to writable channels",
		TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "ZIP", "UNWRITABLE", (char *)NULL);
	return TCL_ERROR;
    }
    if (mode == TCL_ZLIB_STREAM_INFLATE && !(chanMode & TCL_READABLE)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"decompression may only be applied to readable channels",
		TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "ZIP", "UNREADABLE", (char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Parse options.
     */

    level = Z_DEFAULT_COMPRESSION;
    for (i=3 ; i<objc ; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], pushOptions, "option", 0,
		&option) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (++i > objc - 1) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "value missing for %s option", pushOptions[option]));
	    Tcl_SetErrorCode(interp, "TCL", "ZIP", "NOVAL", (char *)NULL);
	    return TCL_ERROR;
	}
	switch (option) {
	case poHeader:		/* -header headerDict */
	    headerObj = objv[i];
	    if (Tcl_DictObjSize(interp, headerObj, &dummy) != TCL_OK) {
		goto genericOptionError;
	    }
	    break;
	case poLevel:		/* -level compLevel */
	    if (GetLevelFromObj(interp, objv[i], &level) != TCL_OK) {
		goto genericOptionError;
	    }
	    break;
	case poLimit:		/* -limit numBytes */
	    if (Tcl_GetIntFromObj(interp, objv[i], &limit) != TCL_OK) {
		goto genericOptionError;
	    }
	    if (limit < 1 || limit > MAX_BUFFER_SIZE) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"read ahead limit must be 1 to %d",
			MAX_BUFFER_SIZE));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "BUFFERSIZE", (char *)NULL);
		goto genericOptionError;
	    }
	    break;
	case poDictionary:	/* -dictionary compDict */
	    if (format == TCL_ZLIB_FORMAT_GZIP) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"a compression dictionary may not be set in the "
			"gzip format", TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(interp, "TCL", "ZIP", "BADOPT", (char *)NULL);
		goto genericOptionError;
	    }
	    compDictObj = objv[i];
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    if (compDictObj && (NULL == Tcl_GetBytesFromObj(interp, compDictObj,
	    (Tcl_Size *)NULL))) {
	return TCL_ERROR;
    }

    if (ZlibStackChannelTransform(interp, mode, format, level, limit, chan,
	    headerObj, compDictObj) == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, objv[2]);
    return TCL_OK;

  genericOptionError:
    Tcl_AddErrorInfo(interp, "\n    (in ");
    Tcl_AddErrorInfo(interp, pushOptions[option]);
    Tcl_AddErrorInfo(interp, " option)");
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibStreamImplCmd --
 *
 *	Implementation of the commands returned by [zlib stream].
 *
 *----------------------------------------------------------------------
 */
static int
ZlibStreamImplCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_ZlibStream zstream = (Tcl_ZlibStream) clientData;
    int count, code;
    Tcl_Obj *obj;
    static const char *const cmds[] = {
	"add", "checksum", "close", "eof", "finalize", "flush",
	"fullflush", "get", "header", "put", "reset",
	NULL
    };
    enum zlibStreamCommands {
	zs_add, zs_checksum, zs_close, zs_eof, zs_finalize, zs_flush,
	zs_fullflush, zs_get, zs_header, zs_put, zs_reset
    } command;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option data ?...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], cmds, "option", 0,
	    &command) != TCL_OK) {
	return TCL_ERROR;
    }

    switch (command) {
    case zs_add:		/* $strm add ?$flushopt? $data */
	return ZlibStreamAddCmd(zstream, interp, objc, objv);
    case zs_header:		/* $strm header */
	return ZlibStreamHeaderCmd(zstream, interp, objc, objv);
    case zs_put:		/* $strm put ?$flushopt? $data */
	return ZlibStreamPutCmd(zstream, interp, objc, objv);

    case zs_get:		/* $strm get ?count? */
	if (objc > 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "?count?");
	    return TCL_ERROR;
	}

	count = -1;
	if (objc >= 3) {
	    if (Tcl_GetIntFromObj(interp, objv[2], &count) != TCL_OK) {
		return TCL_ERROR;
	    }
	}
	TclNewObj(obj);
	code = Tcl_ZlibStreamGet(zstream, obj, count);
	if (code == TCL_OK) {
	    Tcl_SetObjResult(interp, obj);
	} else {
	    TclDecrRefCount(obj);
	}
	return code;
    case zs_flush:		/* $strm flush */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	TclNewObj(obj);
	Tcl_IncrRefCount(obj);
	code = Tcl_ZlibStreamPut(zstream, obj, Z_SYNC_FLUSH);
	TclDecrRefCount(obj);
	return code;
    case zs_fullflush:		/* $strm fullflush */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	TclNewObj(obj);
	Tcl_IncrRefCount(obj);
	code = Tcl_ZlibStreamPut(zstream, obj, Z_FULL_FLUSH);
	TclDecrRefCount(obj);
	return code;
    case zs_finalize:		/* $strm finalize */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}

	/*
	 * The flush commands slightly abuse the empty result obj as input
	 * data.
	 */

	TclNewObj(obj);
	Tcl_IncrRefCount(obj);
	code = Tcl_ZlibStreamPut(zstream, obj, Z_FINISH);
	TclDecrRefCount(obj);
	return code;
    case zs_close:		/* $strm close */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	return Tcl_ZlibStreamClose(zstream);
    case zs_eof:		/* $strm eof */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, Tcl_NewBooleanObj(Tcl_ZlibStreamEof(zstream)));
	return TCL_OK;
    case zs_checksum:		/* $strm checksum */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, Tcl_NewWideIntObj(
		(uint32_t) Tcl_ZlibStreamChecksum(zstream)));
	return TCL_OK;
    case zs_reset:		/* $strm reset */
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	return Tcl_ZlibStreamReset(zstream);
    default:
	TCL_UNREACHABLE();
    }
}

static int
ZlibStreamAddCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_ZlibStream zstream = (Tcl_ZlibStream) clientData;
    int code, buffersize = -1, flush = -1, i;
    Tcl_Obj *obj, *compDictObj = NULL;
    static const char *const add_options[] = {
	"-buffer", "-dictionary", "-finalize", "-flush", "-fullflush", NULL
    };
    enum addOptions {
	ao_buffer, ao_dictionary, ao_finalize, ao_flush, ao_fullflush
    } index;

    for (i=2; i<objc-1; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], add_options, "option", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}

	switch (index) {
	case ao_flush:		/* -flush */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_SYNC_FLUSH;
	    }
	    break;
	case ao_fullflush:	/* -fullflush */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_FULL_FLUSH;
	    }
	    break;
	case ao_finalize:	/* -finalize */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_FINISH;
	    }
	    break;
	case ao_buffer:		/* -buffer bufferSize */
	    if (i == objc - 2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-buffer\" option must be followed by integer "
			"decompression buffersize", TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(interp, "TCL", "ZIP", "NOVAL", (char *)NULL);
		return TCL_ERROR;
	    }
	    if (Tcl_GetIntFromObj(interp, objv[++i], &buffersize) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if (buffersize < 1 || buffersize > MAX_BUFFER_SIZE) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"buffer size must be 1 to %d",
			MAX_BUFFER_SIZE));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "BUFFERSIZE", (char *)NULL);
		return TCL_ERROR;
	    }
	    break;
	case ao_dictionary:	/* -dictionary compDict */
	    if (i == objc - 2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-dictionary\" option must be followed by"
			" compression dictionary bytes", TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(interp, "TCL", "ZIP", "NOVAL", (char *)NULL);
		return TCL_ERROR;
	    }
	    compDictObj = objv[++i];
	    break;
	default:
	    TCL_UNREACHABLE();
	}

	if (flush == -2) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "\"-flush\", \"-fullflush\" and \"-finalize\" options"
		    " are mutually exclusive", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "TCL", "ZIP", "EXCLUSIVE", (char *)NULL);
	    return TCL_ERROR;
	}
    }
    if (flush == -1) {
	flush = 0;
    }

    /*
     * Set the compression dictionary if requested.
     */

    if (compDictObj != NULL) {
	Tcl_Size len = 0;

	if (NULL == Tcl_GetBytesFromObj(interp, compDictObj, &len)) {
	    return TCL_ERROR;
	}

	if (len == 0) {
	    compDictObj = NULL;
	}
	Tcl_ZlibStreamSetCompressionDictionary(zstream, compDictObj);
    }

    /*
     * Send the data to the stream core, along with any flushing directive.
     */

    if (Tcl_ZlibStreamPut(zstream, objv[objc - 1], flush) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Get such data out as we can (up to the requested length).
     */

    TclNewObj(obj);
    code = Tcl_ZlibStreamGet(zstream, obj, buffersize);
    if (code == TCL_OK) {
	Tcl_SetObjResult(interp, obj);
    } else {
	TclDecrRefCount(obj);
    }
    return code;
}

static int
ZlibStreamPutCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_ZlibStream zstream = (Tcl_ZlibStream) clientData;
    int flush = -1, i;
    Tcl_Obj *compDictObj = NULL;
    static const char *const put_options[] = {
	"-dictionary", "-finalize", "-flush", "-fullflush", NULL
    };
    enum putOptions {
	po_dictionary, po_finalize, po_flush, po_fullflush
    } index;

    for (i=2; i<objc-1; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], put_options, "option", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}

	switch (index) {
	case po_flush:		/* -flush */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_SYNC_FLUSH;
	    }
	    break;
	case po_fullflush:	/* -fullflush */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_FULL_FLUSH;
	    }
	    break;
	case po_finalize:	/* -finalize */
	    if (flush >= 0) {
		flush = -2;
	    } else {
		flush = Z_FINISH;
	    }
	    break;
	case po_dictionary:	/* -dictionary compDict */
	    if (i == objc - 2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"\"-dictionary\" option must be followed by"
			" compression dictionary bytes", TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(interp, "TCL", "ZIP", "NOVAL", (char *)NULL);
		return TCL_ERROR;
	    }
	    compDictObj = objv[++i];
	    break;
	default:
	    TCL_UNREACHABLE();
	}
	if (flush == -2) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "\"-flush\", \"-fullflush\" and \"-finalize\" options"
		    " are mutually exclusive", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "TCL", "ZIP", "EXCLUSIVE", (char *)NULL);
	    return TCL_ERROR;
	}
    }
    if (flush == -1) {
	flush = 0;
    }

    /*
     * Set the compression dictionary if requested.
     */

    if (compDictObj != NULL) {
	Tcl_Size len = 0;

	if (NULL == Tcl_GetBytesFromObj(interp, compDictObj, &len)) {
	    return TCL_ERROR;
	}
	if (len == 0) {
	    compDictObj = NULL;
	}
	Tcl_ZlibStreamSetCompressionDictionary(zstream, compDictObj);
    }

    /*
     * Send the data to the stream core, along with any flushing directive.
     */

    return Tcl_ZlibStreamPut(zstream, objv[objc - 1], flush);
}

static int
ZlibStreamHeaderCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    ZlibStreamHandle *zshPtr = (ZlibStreamHandle *) clientData;
    Tcl_Obj *resultObj;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 2, objv, NULL);
	return TCL_ERROR;
    } else if (zshPtr->mode != TCL_ZLIB_STREAM_INFLATE
	    || zshPtr->format != TCL_ZLIB_FORMAT_GZIP) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"only gunzip streams can produce header information",
		TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "ZIP", "BADOP", (char *)NULL);
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    ExtractHeader(&zshPtr->gzHeaderPtr->header, resultObj);
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *	Set of functions to support channel stacking.
 *----------------------------------------------------------------------
 */

static inline int
HaveFlag(
    ZlibChannelData *chanDataPtr,
    int flag)
{
    return (chanDataPtr->flags & flag) != 0;
}

/*
 *
 * ZlibTransformClose --
 *
 *	How to shut down a stacked compressing/decompressing transform.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformClose(
    void *instanceData,
    Tcl_Interp *interp,
    int flags)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    int e, result = TCL_OK;
    size_t written;

    if ((flags & (TCL_CLOSE_READ | TCL_CLOSE_WRITE)) != 0) {
	return EINVAL;
    }

    /*
     * Delete the support timer.
     */

    ZlibTransformEventTimerKill(chanDataPtr);

    /*
     * Flush any data waiting to be compressed.
     */

    if (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	chanDataPtr->outStream.avail_in = 0;
	do {
	    e = Deflate(&chanDataPtr->outStream, chanDataPtr->outBuffer,
		    chanDataPtr->outAllocated, Z_FINISH, &written);

	    /*
	     * Can't be sure that deflate() won't declare the buffer to be
	     * full (with Z_BUF_ERROR) so handle that case.
	     */

	    if (e == Z_BUF_ERROR) {
		e = Z_OK;
		written = chanDataPtr->outAllocated;
	    }
	    if (e != Z_OK && e != Z_STREAM_END) {
		/* TODO: is this the right way to do errors on close? */
		if (!TclInThreadExit()) {
		    ConvertError(interp, e, chanDataPtr->outStream.adler);
		}
		result = TCL_ERROR;
		break;
	    }
	    if (written && Tcl_WriteRaw(chanDataPtr->parent,
		    chanDataPtr->outBuffer, written) == TCL_IO_FAILURE) {
		/* TODO: is this the right way to do errors on close?
		 * Note: when close is called from FinalizeIOSubsystem then
		 * interp may be NULL */
		if (!TclInThreadExit() && interp) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "error while finalizing file: %s",
			    Tcl_PosixError(interp)));
		}
		result = TCL_ERROR;
		break;
	    }
	} while (e != Z_STREAM_END);
	(void) deflateEnd(&chanDataPtr->outStream);
    } else {
	/*
	 * If we have unused bytes from the read input (overshot by
	 * Z_STREAM_END or on possible error), unget them back to the parent
	 * channel, so that they appear as not being read yet.
	 */
	if (chanDataPtr->inStream.avail_in) {
	    Tcl_Ungets(chanDataPtr->parent,
		    (char *) chanDataPtr->inStream.next_in,
		    chanDataPtr->inStream.avail_in, 0);
	}

	(void) inflateEnd(&chanDataPtr->inStream);
    }

    /*
     * Release all memory.
     */

    if (chanDataPtr->compDictObj) {
	Tcl_DecrRefCount(chanDataPtr->compDictObj);
	chanDataPtr->compDictObj = NULL;
    }

    if (chanDataPtr->inBuffer) {
	Tcl_Free(chanDataPtr->inBuffer);
	chanDataPtr->inBuffer = NULL;
    }
    if (chanDataPtr->outBuffer) {
	Tcl_Free(chanDataPtr->outBuffer);
	chanDataPtr->outBuffer = NULL;
    }
    Tcl_Free(chanDataPtr);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformInput --
 *
 *	Reader filter that does decompression.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformInput(
    void *instanceData,
    char *buf,
    int toRead,
    int *errorCodePtr)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    Tcl_DriverInputProc *inProc =
	    Tcl_ChannelInputProc(Tcl_GetChannelType(chanDataPtr->parent));
    int readBytes, gotBytes;

    if (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	return inProc(Tcl_GetChannelInstanceData(chanDataPtr->parent), buf,
		toRead, errorCodePtr);
    }

    gotBytes = 0;
    readBytes = chanDataPtr->inStream.avail_in; /* how many bytes in buffer now */
    while (!HaveFlag(chanDataPtr, STREAM_DONE) && toRead > 0) {
	unsigned int n;
	int decBytes;

	/* if starting from scratch or continuation after full decompression */
	if (!chanDataPtr->inStream.avail_in) {
	    /* buffer to start, we can read to whole available buffer */
	    chanDataPtr->inStream.next_in = (Bytef *) chanDataPtr->inBuffer;
	}
	/*
	 * If done - no read needed anymore, check we have to copy rest of
	 * decompressed data, otherwise return with size (or 0 for Eof)
	 */
	if (HaveFlag(chanDataPtr, STREAM_DECOMPRESS)) {
	    goto copyDecompressed;
	}
	/*
	 * The buffer is exhausted, but the caller wants even more. We now
	 * have to go to the underlying channel, get more bytes and then
	 * transform them for delivery. We may not get what we want (full EOF
	 * or temporarily out of data).
	 */

	/* Check free buffer size and adjust size of next chunk to read. */
	n = chanDataPtr->inAllocated - ((char *)
		chanDataPtr->inStream.next_in - chanDataPtr->inBuffer);
	if (n <= 0) {
	    /* Normally unreachable: not enough input buffer to uncompress.
	     * Todo: firstly try to realloc inBuffer upto MAX_BUFFER_SIZE.
	     */
	    *errorCodePtr = ENOBUFS;
	    return -1;
	}
	if (n > chanDataPtr->readAheadLimit) {
	    n = chanDataPtr->readAheadLimit;
	}
	readBytes = Tcl_ReadRaw(chanDataPtr->parent,
		(char *) chanDataPtr->inStream.next_in, n);

	/*
	 * Three cases here:
	 *  1.	Got some data from the underlying channel (readBytes > 0) so
	 *	it should be fed through the decompression engine.
	 *  2.	Got an error (readBytes == -1) which we should report up except
	 *	for the case where we can convert it to a short read.
	 *  3.	Got an end-of-data from EOF or blocking (readBytes == 0). If
	 *	it is EOF, try flushing the data out of the decompressor.
	 */

	if (readBytes == -1) {
	    /* See ReflectInput() in tclIORTrans.c */
	    if (Tcl_InputBlocked(chanDataPtr->parent) && (gotBytes > 0)) {
		break;
	    }

	    *errorCodePtr = Tcl_GetErrno();
	    return -1;
	}

	/* more bytes (or Eof if readBytes == 0) */
	chanDataPtr->inStream.avail_in += readBytes;

copyDecompressed:

	/*
	 * Transform the read chunk, if not empty. Anything we get
	 * back is a transformation result to be put into our buffers, and
	 * the next iteration will put it into the result.
	 * For the case readBytes is 0 which signaling Eof in parent, the
	 * partial data waiting is converted and returned.
	 */

	decBytes = ResultDecompress(chanDataPtr, buf, toRead,
		(readBytes != 0) ? Z_NO_FLUSH : Z_SYNC_FLUSH,  errorCodePtr);
	if (decBytes == -1) {
	    return -1;
	}
	gotBytes += decBytes;
	buf += decBytes;
	toRead -= decBytes;

	if ((decBytes == 0) || HaveFlag(chanDataPtr, STREAM_DECOMPRESS)) {
	    /*
	     * The drain delivered nothing (or buffer too small to decompress).
	     * Time to deliver what we've got.
	     */
	    if (!gotBytes && !HaveFlag(chanDataPtr, STREAM_DONE)) {
		/* if no-data, but not ready - avoid signaling Eof,
		 * continue in blocking mode, otherwise EAGAIN */
		if (Tcl_InputBlocked(chanDataPtr->parent)) {
		    continue;
		}
		*errorCodePtr = EAGAIN;
		return -1;
	    }
	    break;
	}

	/*
	 * Loop until the request is satisfied (or no data available from
	 * above, possibly EOF).
	 */
    }

    return gotBytes;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformOutput --
 *
 *	Writer filter that does compression.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformOutput(
    void *instanceData,
    const char *buf,
    int toWrite,
    int *errorCodePtr)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    Tcl_DriverOutputProc *outProc =
	    Tcl_ChannelOutputProc(Tcl_GetChannelType(chanDataPtr->parent));
    int e;
    size_t produced;
    Tcl_Obj *errObj;

    if (chanDataPtr->mode == TCL_ZLIB_STREAM_INFLATE) {
	return outProc(Tcl_GetChannelInstanceData(chanDataPtr->parent), buf,
		toWrite, errorCodePtr);
    }

    /*
     * No zero-length writes. Flushes must be explicit.
     */

    if (toWrite == 0) {
	return 0;
    }

    chanDataPtr->outStream.next_in = (Bytef *) buf;
    chanDataPtr->outStream.avail_in = toWrite;
    while (chanDataPtr->outStream.avail_in > 0) {
	e = Deflate(&chanDataPtr->outStream, chanDataPtr->outBuffer,
		chanDataPtr->outAllocated, Z_NO_FLUSH, &produced);
	if (e != Z_OK || produced == 0) {
	    break;
	}

	if (Tcl_WriteRaw(chanDataPtr->parent, chanDataPtr->outBuffer,
		produced) == TCL_IO_FAILURE) {
	    *errorCodePtr = Tcl_GetErrno();
	    return -1;
	}
    }

    if (e == Z_OK) {
	return toWrite - chanDataPtr->outStream.avail_in;
    }

    errObj = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(NULL, errObj, Tcl_NewStringObj(
	    "-errorcode", TCL_AUTO_LENGTH));
    Tcl_ListObjAppendElement(NULL, errObj,
	    ConvertErrorToList(e, chanDataPtr->outStream.adler));
    Tcl_ListObjAppendElement(NULL, errObj,
	    Tcl_NewStringObj(chanDataPtr->outStream.msg, TCL_AUTO_LENGTH));
    Tcl_SetChannelError(chanDataPtr->parent, errObj);
    *errorCodePtr = EINVAL;
    return -1;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformFlush --
 *
 *	How to perform a flush of a compressing transform.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformFlush(
    Tcl_Interp *interp,
    ZlibChannelData *chanDataPtr,
    int flushType)
{
    int e;
    size_t len;

    chanDataPtr->outStream.avail_in = 0;
    do {
	/*
	 * Get the bytes to go out of the compression engine.
	 */

	e = Deflate(&chanDataPtr->outStream, chanDataPtr->outBuffer,
		chanDataPtr->outAllocated, flushType, &len);
	if (e != Z_OK && e != Z_BUF_ERROR) {
	    ConvertError(interp, e, chanDataPtr->outStream.adler);
	    return TCL_ERROR;
	}

	/*
	 * Write the bytes we've received to the next layer.
	 */

	if (len > 0 && Tcl_WriteRaw(chanDataPtr->parent, chanDataPtr->outBuffer,
		len) == TCL_IO_FAILURE) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "problem flushing channel: %s",
		    Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}

	/*
	 * If we get to this point, either we're in the Z_OK or the
	 * Z_BUF_ERROR state. In the former case, we're done. In the latter
	 * case, it's because there's more bytes to go than would fit in the
	 * buffer we provided, and we need to go round again to get some more.
	 *
	 * We also stop the loop if we would have done a zero-length write.
	 * Those can cause problems at the OS level.
	 */
    } while (len > 0 && e == Z_BUF_ERROR);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformSetOption --
 *
 *	Writing side of [fconfigure] on our channel.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformSetOption(			/* not used */
    void *instanceData,
    Tcl_Interp *interp,
    const char *optionName,
    const char *value)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    Tcl_DriverSetOptionProc *setOptionProc =
	    Tcl_ChannelSetOptionProc(Tcl_GetChannelType(chanDataPtr->parent));
    static const char *compressChanOptions = "dictionary flush";
    static const char *gzipChanOptions = "flush";
    static const char *decompressChanOptions = "dictionary limit";
    static const char *gunzipChanOptions = "flush limit";
    int haveFlushOpt = (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE);

    if (optionName && (strcmp(optionName, "-dictionary") == 0)
	    && (chanDataPtr->format != TCL_ZLIB_FORMAT_GZIP)) {
	Tcl_Obj *compDictObj;
	int code;

	TclNewStringObj(compDictObj, value, strlen(value));
	Tcl_IncrRefCount(compDictObj);
	if (NULL == Tcl_GetBytesFromObj(interp, compDictObj, (Tcl_Size *)NULL)) {
	    Tcl_DecrRefCount(compDictObj);
	    return TCL_ERROR;
	}
	if (chanDataPtr->compDictObj) {
	    TclDecrRefCount(chanDataPtr->compDictObj);
	}
	chanDataPtr->compDictObj = compDictObj;
	code = Z_OK;
	if (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	    code = SetDeflateDictionary(&chanDataPtr->outStream, compDictObj);
	    if (code != Z_OK) {
		ConvertError(interp, code, chanDataPtr->outStream.adler);
		return TCL_ERROR;
	    }
	} else if (chanDataPtr->format == TCL_ZLIB_FORMAT_RAW) {
	    code = SetInflateDictionary(&chanDataPtr->inStream, compDictObj);
	    if (code != Z_OK) {
		ConvertError(interp, code, chanDataPtr->inStream.adler);
		return TCL_ERROR;
	    }
	}
	return TCL_OK;
    }

    if (haveFlushOpt) {
	if (optionName && strcmp(optionName, "-flush") == 0) {
	    int flushType;

	    if (value[0] == 'f' && strcmp(value, "full") == 0) {
		flushType = Z_FULL_FLUSH;
	    } else if (value[0] == 's' && strcmp(value, "sync") == 0) {
		flushType = Z_SYNC_FLUSH;
	    } else {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"unknown -flush type \"%s\": must be full or sync",
			value));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "FLUSH", (char *)NULL);
		return TCL_ERROR;
	    }

	    /*
	     * Try to actually do the flush now.
	     */

	    return ZlibTransformFlush(interp, chanDataPtr, flushType);
	}
    } else {
	if (optionName && strcmp(optionName, "-limit") == 0) {
	    int newLimit;

	    if (Tcl_GetInt(interp, value, &newLimit) != TCL_OK) {
		return TCL_ERROR;
	    } else if (newLimit < 1 || newLimit > MAX_BUFFER_SIZE) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"-limit must be between 1 and 65536", TCL_AUTO_LENGTH));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "READLIMIT",
			(char *)NULL);
		return TCL_ERROR;
	    }
	}
    }

    if (setOptionProc == NULL) {
	if (chanDataPtr->format == TCL_ZLIB_FORMAT_GZIP) {
	    return Tcl_BadChannelOption(interp, optionName,
		    (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE)
		    ? gzipChanOptions : gunzipChanOptions);
	} else {
	    return Tcl_BadChannelOption(interp, optionName,
		    (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE)
		    ? compressChanOptions : decompressChanOptions);
	}
    }

    /*
     * Pass all unknown options down, to deeper transforms and/or the base
     * channel.
     */

    return setOptionProc(Tcl_GetChannelInstanceData(chanDataPtr->parent),
	    interp, optionName, value);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformGetOption --
 *
 *	Reading side of [fconfigure] on our channel.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformGetOption(
    void *instanceData,
    Tcl_Interp *interp,
    const char *optionName,
    Tcl_DString *dsPtr)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    Tcl_DriverGetOptionProc *getOptionProc =
	    Tcl_ChannelGetOptionProc(Tcl_GetChannelType(chanDataPtr->parent));
    static const char *compressChanOptions = "checksum dictionary";
    static const char *gzipChanOptions = "checksum";
    static const char *decompressChanOptions = "checksum dictionary limit";
    static const char *gunzipChanOptions = "checksum header limit";

    /*
     * The "crc" option reports the current CRC (calculated with the Adler32
     * or CRC32 algorithm according to the format) given the data that has
     * been processed so far.
     */

    if (optionName == NULL || strcmp(optionName, "-checksum") == 0) {
	uLong crc;
	char buf[12];

	if (chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE) {
	    crc = chanDataPtr->outStream.adler;
	} else {
	    crc = chanDataPtr->inStream.adler;
	}

	snprintf(buf, sizeof(buf), "%lu", crc);
	if (optionName == NULL) {
	    Tcl_DStringAppendElement(dsPtr, "-checksum");
	    Tcl_DStringAppendElement(dsPtr, buf);
	} else {
	    Tcl_DStringAppend(dsPtr, buf, TCL_AUTO_LENGTH);
	    return TCL_OK;
	}
    }

    if ((chanDataPtr->format != TCL_ZLIB_FORMAT_GZIP) &&
	    (optionName == NULL || strcmp(optionName, "-dictionary") == 0)) {
	/*
	 * Embedded NUL bytes are ok; they'll be C080-encoded.
	 */

	if (optionName == NULL) {
	    Tcl_DStringAppendElement(dsPtr, "-dictionary");
	    if (chanDataPtr->compDictObj) {
		Tcl_DStringAppendElement(dsPtr,
			TclGetString(chanDataPtr->compDictObj));
	    } else {
		Tcl_DStringAppendElement(dsPtr, "");
	    }
	} else {
	    if (chanDataPtr->compDictObj) {
		Tcl_Size length;
		const char *str = TclGetStringFromObj(chanDataPtr->compDictObj,
			&length);

		Tcl_DStringAppend(dsPtr, str, length);
	    }
	    return TCL_OK;
	}
    }

    /*
     * The "header" option, which is only valid on inflating gzip channels,
     * reports the header that has been read from the start of the stream.
     */

    if (HaveFlag(chanDataPtr, IN_HEADER) && ((optionName == NULL) ||
	    (strcmp(optionName, "-header") == 0))) {
	Tcl_Obj *tmpObj;

	TclNewObj(tmpObj);
	ExtractHeader(&chanDataPtr->inHeader.header, tmpObj);
	if (optionName == NULL) {
	    Tcl_DStringAppendElement(dsPtr, "-header");
	    Tcl_DStringAppendElement(dsPtr, TclGetString(tmpObj));
	    Tcl_DecrRefCount(tmpObj);
	} else {
	    TclDStringAppendObj(dsPtr, tmpObj);
	    Tcl_DecrRefCount(tmpObj);
	    return TCL_OK;
	}
    }

    /*
     * Now we do the standard processing of the stream we wrapped.
     */

    if (getOptionProc) {
	return getOptionProc(Tcl_GetChannelInstanceData(chanDataPtr->parent),
		interp, optionName, dsPtr);
    }
    if (optionName == NULL) {
	return TCL_OK;
    }
    if (chanDataPtr->format == TCL_ZLIB_FORMAT_GZIP) {
	return Tcl_BadChannelOption(interp, optionName,
		(chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE)
		? gzipChanOptions : gunzipChanOptions);
    } else {
	return Tcl_BadChannelOption(interp, optionName,
		(chanDataPtr->mode == TCL_ZLIB_STREAM_DEFLATE)
		? compressChanOptions : decompressChanOptions);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformWatch, ZlibTransformEventHandler --
 *
 *	If we have data pending, trigger a readable event after a short time
 *	(in order to allow a real event to catch up).
 *
 *----------------------------------------------------------------------
 */

static void
ZlibTransformWatch(
    void *instanceData,
    int mask)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;
    Tcl_DriverWatchProc *watchProc;

    /*
     * This code is based on the code in tclIORTrans.c
     */

    watchProc = Tcl_ChannelWatchProc(Tcl_GetChannelType(chanDataPtr->parent));
    watchProc(Tcl_GetChannelInstanceData(chanDataPtr->parent), mask);

    if (!(mask & TCL_READABLE) || !HaveFlag(chanDataPtr, STREAM_DECOMPRESS)) {
	ZlibTransformEventTimerKill(chanDataPtr);
    } else if (chanDataPtr->timer == NULL) {
	chanDataPtr->timer = Tcl_CreateTimerHandler(SYNTHETIC_EVENT_TIME,
		ZlibTransformTimerRun, chanDataPtr);
    }
}

static int
ZlibTransformEventHandler(
    void *instanceData,
    int interestMask)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;

    ZlibTransformEventTimerKill(chanDataPtr);
    return interestMask;
}

static inline void
ZlibTransformEventTimerKill(
    ZlibChannelData *chanDataPtr)
{
    if (chanDataPtr->timer != NULL) {
	Tcl_DeleteTimerHandler(chanDataPtr->timer);
	chanDataPtr->timer = NULL;
    }
}

static void
ZlibTransformTimerRun(
    void *clientData)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) clientData;

    chanDataPtr->timer = NULL;
    Tcl_NotifyChannel(chanDataPtr->chan, TCL_READABLE);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformGetHandle --
 *
 *	Anything that needs the OS handle is told to get it from what we are
 *	stacked on top of.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformGetHandle(
    void *instanceData,
    int direction,
    void **handlePtr)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;

    return Tcl_GetChannelHandle(chanDataPtr->parent, direction, handlePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibTransformBlockMode --
 *
 *	We need to keep track of the blocking mode; it changes our behavior.
 *
 *----------------------------------------------------------------------
 */

static int
ZlibTransformBlockMode(
    void *instanceData,
    int mode)
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *) instanceData;

    if (mode == TCL_MODE_NONBLOCKING) {
	chanDataPtr->flags |= ASYNC;
    } else {
	chanDataPtr->flags &= ~ASYNC;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ZlibStackChannelTransform --
 *
 *	Stacks either compression or decompression onto a channel.
 *
 * Results:
 *	The stacked channel, or NULL if there was an error.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Channel
ZlibStackChannelTransform(
    Tcl_Interp *interp,		/* Where to write error messages. */
    int mode,			/* Whether this is a compressing transform
				 * (TCL_ZLIB_STREAM_DEFLATE) or a
				 * decompressing transform
				 * (TCL_ZLIB_STREAM_INFLATE). Note that
				 * compressing transforms require that the
				 * channel is writable, and decompressing
				 * transforms require that the channel is
				 * readable. */
    int format,			/* One of the TCL_ZLIB_FORMAT_* values that
				 * indicates what compressed format to allow.
				 * TCL_ZLIB_FORMAT_AUTO is only supported for
				 * decompressing transforms. */
    int level,			/* What compression level to use. Ignored for
				 * decompressing transforms. */
    int limit,			/* The limit on the number of bytes to read
				 * ahead; always at least 1. */
    Tcl_Channel channel,	/* The channel to attach to. */
    Tcl_Obj *gzipHeaderDictPtr,	/* A description of header to use, or NULL to
				 * use a default. Ignored if not compressing
				 * to produce gzip-format data. */
    Tcl_Obj *compDictObj)	/* Byte-array object containing compression
				 * dictionary (not dictObj!) to use if
				 * necessary. */
{
    ZlibChannelData *chanDataPtr = (ZlibChannelData *)
	    Tcl_Alloc(sizeof(ZlibChannelData));
    Tcl_Channel chan;
    int wbits = 0;

    if (mode != TCL_ZLIB_STREAM_DEFLATE && mode != TCL_ZLIB_STREAM_INFLATE) {
	Tcl_Panic("unknown mode: %d", mode);
    }

    memset(chanDataPtr, 0, sizeof(ZlibChannelData));
    chanDataPtr->mode = mode;
    chanDataPtr->format = format;
    chanDataPtr->readAheadLimit = limit;

    if (format == TCL_ZLIB_FORMAT_GZIP || format == TCL_ZLIB_FORMAT_AUTO) {
	if (mode == TCL_ZLIB_STREAM_DEFLATE) {
	    if (gzipHeaderDictPtr) {
		chanDataPtr->flags |= OUT_HEADER;
		if (GenerateHeader(interp, gzipHeaderDictPtr,
			&chanDataPtr->outHeader, NULL) != TCL_OK) {
		    goto error;
		}
	    }
	} else {
	    chanDataPtr->flags |= IN_HEADER;
	    chanDataPtr->inHeader.header.name = (Bytef *)
		    &chanDataPtr->inHeader.nativeFilenameBuf;
	    chanDataPtr->inHeader.header.name_max = MAXPATHLEN - 1;
	    chanDataPtr->inHeader.header.comment = (Bytef *)
		    &chanDataPtr->inHeader.nativeCommentBuf;
	    chanDataPtr->inHeader.header.comm_max = MAX_COMMENT_LEN - 1;
	}
    }

    if (compDictObj != NULL) {
	chanDataPtr->compDictObj = Tcl_DuplicateObj(compDictObj);
	Tcl_IncrRefCount(chanDataPtr->compDictObj);
	Tcl_GetBytesFromObj(NULL, chanDataPtr->compDictObj, (Tcl_Size *)NULL);
    }

    switch (format) {
    case  TCL_ZLIB_FORMAT_RAW:
	wbits = WBITS_RAW;
	break;
    case TCL_ZLIB_FORMAT_ZLIB:
	wbits = WBITS_ZLIB;
	break;
    case TCL_ZLIB_FORMAT_GZIP:
	wbits = WBITS_GZIP;
	break;
    case TCL_ZLIB_FORMAT_AUTO:
	wbits = WBITS_AUTODETECT;
	break;
    default:
	Tcl_Panic("bad format: %d", format);
    }

    /*
     * Initialize input inflater or the output deflater.
     */

    if (mode == TCL_ZLIB_STREAM_INFLATE) {
	if (inflateInit2(&chanDataPtr->inStream, wbits) != Z_OK) {
	    goto error;
	}
	chanDataPtr->inAllocated = DEFAULT_BUFFER_SIZE;
	if (chanDataPtr->inAllocated < chanDataPtr->readAheadLimit) {
	    chanDataPtr->inAllocated = chanDataPtr->readAheadLimit;
	}
	chanDataPtr->inBuffer = (char *) Tcl_Alloc(chanDataPtr->inAllocated);
	if (HaveFlag(chanDataPtr, IN_HEADER)) {
	    if (inflateGetHeader(&chanDataPtr->inStream,
		    &chanDataPtr->inHeader.header) != Z_OK) {
		goto error;
	    }
	}
	if (chanDataPtr->format == TCL_ZLIB_FORMAT_RAW
		&& chanDataPtr->compDictObj) {
	    if (SetInflateDictionary(&chanDataPtr->inStream,
		    chanDataPtr->compDictObj) != Z_OK) {
		goto error;
	    }
	}
    } else {
	if (deflateInit2(&chanDataPtr->outStream, level, Z_DEFLATED, wbits,
		MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY) != Z_OK) {
	    goto error;
	}
	chanDataPtr->outAllocated = DEFAULT_BUFFER_SIZE;
	chanDataPtr->outBuffer = (char *) Tcl_Alloc(chanDataPtr->outAllocated);
	if (HaveFlag(chanDataPtr, OUT_HEADER)) {
	    if (deflateSetHeader(&chanDataPtr->outStream,
		    &chanDataPtr->outHeader.header) != Z_OK) {
		goto error;
	    }
	}
	if (chanDataPtr->compDictObj) {
	    if (SetDeflateDictionary(&chanDataPtr->outStream,
		    chanDataPtr->compDictObj) != Z_OK) {
		goto error;
	    }
	}
    }

    chan = Tcl_StackChannel(interp, &zlibChannelType, chanDataPtr,
	    Tcl_GetChannelMode(channel), channel);
    if (chan == NULL) {
	goto error;
    }
    chanDataPtr->chan = chan;
    chanDataPtr->parent = Tcl_GetStackedChannel(chan);
    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    Tcl_GetChannelName(chan), TCL_AUTO_LENGTH));
    return chan;

  error:
    if (chanDataPtr->inBuffer) {
	Tcl_Free(chanDataPtr->inBuffer);
	inflateEnd(&chanDataPtr->inStream);
    }
    if (chanDataPtr->outBuffer) {
	Tcl_Free(chanDataPtr->outBuffer);
	deflateEnd(&chanDataPtr->outStream);
    }
    if (chanDataPtr->compDictObj) {
	Tcl_DecrRefCount(chanDataPtr->compDictObj);
    }
    Tcl_Free(chanDataPtr);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * ResultDecompress --
 *
 *	Extract uncompressed bytes from the compression engine and store them
 *	in our buffer (buf) up to toRead bytes.
 *
 * Result:
 *	Number of bytes decompressed or -1 if error (with *errorCodePtr updated
 *	with reason).
 *
 * Side effects:
 *	After execution it updates chanDataPtr->inStream (next_in, avail_in) to
 *	reflect the data that has been decompressed.
 *
 *----------------------------------------------------------------------
 */

static int
ResultDecompress(
    ZlibChannelData *chanDataPtr,
    char *buf,
    int toRead,
    int flush,
    int *errorCodePtr)
{
    int e, written, resBytes = 0;
    Tcl_Obj *errObj;

    chanDataPtr->flags &= ~STREAM_DECOMPRESS;
    chanDataPtr->inStream.next_out = (Bytef *) buf;
    chanDataPtr->inStream.avail_out = toRead;
    while (chanDataPtr->inStream.avail_out > 0) {
	e = inflate(&chanDataPtr->inStream, flush);

	/*
	 * Apply a compression dictionary if one is needed and we have one.
	 */

	if (e == Z_NEED_DICT && chanDataPtr->compDictObj) {
	    e = SetInflateDictionary(&chanDataPtr->inStream,
		    chanDataPtr->compDictObj);
	    if (e == Z_OK) {
		/*
		 * A repetition of Z_NEED_DICT now is just an error.
		 */

		e = inflate(&chanDataPtr->inStream, flush);
	    }
	}

	/*
	 * avail_out is now the left over space in the output.  Therefore
	 * "toRead - avail_out" is the amount of bytes generated.
	 */

	written = toRead - chanDataPtr->inStream.avail_out;

	/*
	 * The cases where we're definitely done.
	 */

	if (e == Z_STREAM_END) {
	    chanDataPtr->flags |= STREAM_DONE;
	    resBytes += written;
	    break;
	}
	if (e == Z_OK) {
	    if (written == 0) {
		break;
	    }
	    resBytes += written;
	}

	if ((flush == Z_SYNC_FLUSH) && (e == Z_BUF_ERROR)) {
	    break;
	}

	/*
	 * Z_BUF_ERROR can be ignored as per http://www.zlib.net/zlib_how.html
	 *
	 * Just indicates that the zlib couldn't consume input/produce output,
	 * and is fixed by supplying more input.
	 *
	 * Otherwise, we've got errors and need to report to higher-up.
	 */

	if ((e != Z_OK) && (e != Z_BUF_ERROR)) {
	    goto handleError;
	}

	/*
	 * Check if the inflate stopped early.
	 */

	if (chanDataPtr->inStream.avail_in <= 0 && flush != Z_SYNC_FLUSH) {
	    break;
	}
    }

    if (!HaveFlag(chanDataPtr, STREAM_DONE)) {
	/* if we have pending input data, but no available output buffer */
	if (chanDataPtr->inStream.avail_in
		&& !chanDataPtr->inStream.avail_out) {
	    /* next time try to decompress it got readable (new output buffer) */
	    chanDataPtr->flags |= STREAM_DECOMPRESS;
	}
    }

    return resBytes;

  handleError:
    errObj = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(NULL, errObj, Tcl_NewStringObj(
	    "-errorcode", TCL_AUTO_LENGTH));
    Tcl_ListObjAppendElement(NULL, errObj,
	    ConvertErrorToList(e, chanDataPtr->inStream.adler));
    Tcl_ListObjAppendElement(NULL, errObj,
	    Tcl_NewStringObj(chanDataPtr->inStream.msg, TCL_AUTO_LENGTH));
    Tcl_SetChannelError(chanDataPtr->parent, errObj);
    *errorCodePtr = EINVAL;
    return -1;
}

/*
 *----------------------------------------------------------------------
 *	Finally, the TclZlibInit function. Used to install the zlib API.
 *----------------------------------------------------------------------
 */

int
TclZlibInit(
    Tcl_Interp *interp)
{
    Tcl_Config cfg[2];

    /*
     * This does two things. It creates a counter used in the creation of
     * stream commands, and it creates the namespace that will contain those
     * commands.
     */

    Tcl_EvalEx(interp, "namespace eval ::tcl::zlib {variable cmdcounter 0}",
	    TCL_AUTO_LENGTH, 0);

    /*
     * Create the public scripted interface to this file's functionality.
     */

    TclMakeEnsemble(interp, "zlib", zlibImplMap);

    /*
     * Store the underlying configuration information.
     *
     * TODO: Describe whether we're using the system version of the library or
     * a compatibility version built into Tcl?
     */

    cfg[0].key = "zlibVersion";
    cfg[0].value = zlibVersion();
    cfg[1].key = NULL;
    Tcl_RegisterConfig(interp, "zlib", cfg, "utf-8");

    /*
     * Allow command type introspection to do something sensible with streams.
     */

    TclRegisterCommandTypeName(ZlibStreamImplCmd, "zlibStream");

    /*
     * Formally provide the package as a Tcl built-in.
     */

    return Tcl_PkgProvideEx(interp, "tcl::zlib", TCL_ZLIB_VERSION, NULL);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

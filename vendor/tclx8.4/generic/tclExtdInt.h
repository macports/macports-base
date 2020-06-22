/*
 * tclExtdInt.h
 *
 * Standard internal include file for Extended Tcl.
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
 * $Id: tclExtdInt.h,v 1.8 2008/12/15 20:00:27 andreas_kupries Exp $
 *-----------------------------------------------------------------------------
 */

#ifndef TCLEXTDINT_H
#define TCLEXTDINT_H

#include "tclExtend.h"

/* Keep it before tcl*Port, otherwise a clash in TclpPanic.
 */
#include "tclInt.h"

#if defined(__WIN32__) || defined(_WIN32)
#   include "tclXwinPort.h"
#else
#   include "tclXunixPort.h"
#endif

/*
 * Internal interp flags compatibility - removed in Tcl 8.5 sources.
 */
#ifndef ERR_IN_PROGRESS
#define ERR_IN_PROGRESS	2
#endif
#ifndef ERROR_CODE_SET
#define ERROR_CODE_SET 8
#endif

/*
 * Assert macro for use in TclX.  Some GCCs libraries are missing a function
 * used by their macro, so we define our own.
 */
#ifdef TCLX_DEBUG
#   define TclX_Assert(expr) ((expr) ? (void)0 : \
                              Tcl_Panic("TclX assertion failure: %s:%d \"%s\"\n",\
                                    __FILE__, __LINE__, "expr"))
#else
#   define TclX_Assert(expr)
#endif

/*
 * Get ranges of integers and longs.
 * If no MAXLONG, assume sizeof (long) == sizeof (int).
 */
#ifndef MAXINT
#    ifdef INT_MAX	/* POSIX */
#        define MAXINT INT_MAX
#    else
#        define BITSPERBYTE   8
#        define BITS(type)    (BITSPERBYTE * (int)sizeof(type))
#        define HIBITI        (1 << BITS(int) - 1)
#        define MAXINT        (~HIBITI)
#    endif
#endif

#ifndef MININT
#    ifdef INT_MIN		/* POSIX */
#        define MININT INT_MIN
#    else
#        define MININT (-MAXINT)-1
#    endif
#endif

#ifndef MAXLONG
#    ifdef LONG_MAX /* POSIX */
#        define MAXLONG LONG_MAX
#    else
#        define MAXLONG MAXINT  
#    endif
#endif

/*
 * Boolean constants.
 */
#ifndef TRUE
#    define TRUE   (1)
#    define FALSE  (0)
#endif

/*
 * Defines used by TclX_Get/SetChannelOption.  Defines name TCLX_COPT_ are the
 * options and the others are the value
 */
#define TCLX_COPT_BLOCKING      1
#define TCLX_MODE_BLOCKING      0
#define TCLX_MODE_NONBLOCKING   1

#define TCLX_COPT_BUFFERING     2
#define TCLX_BUFFERING_FULL     0
#define TCLX_BUFFERING_LINE     1
#define TCLX_BUFFERING_NONE     2

/*
 * Two values are always returned for translation, one for the read side and
 * one for the write.  They are returned masked into one word.
 */

#define TCLX_COPT_TRANSLATION      3
#define TCLX_TRANSLATE_READ_SHIFT  8
#define TCLX_TRANSLATE_READ_MASK   0xFF00
#define TCLX_TRANSLATE_WRITE_MASK  0x00FF

#define TCLX_TRANSLATE_UNSPECIFIED 0 /* For only one direction specified */
#define TCLX_TRANSLATE_AUTO        1
#define TCLX_TRANSLATE_LF          2
#define TCLX_TRANSLATE_BINARY      2  /* same as LF */
#define TCLX_TRANSLATE_CR          3
#define TCLX_TRANSLATE_CRLF        4
#define TCLX_TRANSLATE_PLATFORM    5

/*
 * Flags used by chown/chgrp.
 */
#define TCLX_CHOWN  0x1
#define TCLX_CHGRP  0x2

/*
 * Structure use to pass file locking information.  Parallels the Posix
 * struct flock, but use to pass info from the generic code to the system
 * dependent code.
 */
typedef struct {
    Tcl_Channel channel;      /* Channel to lock */
    int         access;       /* TCL_READABLE and/or TCL_WRITABLE */
    int         block;        /* Block if lock is not available */
    off_t       start;        /* Starting offset */
    off_t       len;          /* len = 0 means until end of file */
    pid_t       pid;          /* Lock owner */
    short       whence;       /* Type of start */
    int         gotLock;      /* Succeeded? */
} TclX_FlockInfo;

/*
 * Used to return argument messages by most commands.
 * FIX: Should be internal, got thought TclX_WrongArgs.
 */
extern char *tclXWrongArgs;
extern Tcl_Obj *tclXWrongArgsObj;

/*
 * Macros to do string compares.  They pre-check the first character before
 * checking of the strings are equal.
 */

#define STREQU(str1, str2) \
        (((str1)[0] == (str2)[0]) && (strcmp(str1, str2) == 0))
#define STRNEQU(str1, str2, cnt) \
        (((str1)[0] == (str2)[0]) && (strncmp(str1, str2, cnt) == 0))

#define OBJSTREQU(obj1, str1) \
	(strcmp(Tcl_GetStringFromObj(obj1, NULL), str1) == 0)

#define OBJSTRNEQU(obj1, str1, cnt) \
	(strncmp(Tcl_GetStringFromObj(obj1, NULL), str1, cnt) == 0)
/*
 * Macro to do ctype functions with 8 bit character sets.
 */
#define ISSPACE(c) (isspace ((unsigned char) c))
#define ISDIGIT(c) (isdigit ((unsigned char) c))
#define ISLOWER(c) (islower ((unsigned char) c))

/*
 * Macro that behaves like strdup, only uses ckalloc.  Also macro that does the
 * same with a string that might contain zero bytes,
 */
#define ckstrdup(sourceStr) \
  (strcpy (ckalloc (strlen (sourceStr) + 1), sourceStr))

#define ckbinstrdup(sourceStr, length) \
  ((char *) memcpy (ckalloc (length + 1), sourceStr, length + 1))

/*
 * Handle hiding of errorLine in 8.6
 */
#if (TCL_MAJOR_VERSION == 8) && (TCL_MINOR_VERSION < 6)
#define ERRORLINE(interp) ((interp)->errorLine)
#else
#define ERRORLINE(interp) (Tcl_GetErrorLine(interp))
#endif

/*
 * Callback type for walking directories.
 */
typedef int
(TclX_WalkDirProc) _ANSI_ARGS_((Tcl_Interp  *interp,
                                char        *path,
                                char        *fileName,
                                int          caseSensitive,
                                ClientData   clientData));

/*
 * Prototypes for utility procedures.
 */

extern int
TclX_CreateObjCommand _ANSI_ARGS_((Tcl_Interp* interp, char* cmdName,
				   Tcl_ObjCmdProc *proc, ClientData clientData,
				   Tcl_CmdDeleteProc *deleteProc, int flags));
extern void *
TclX_StructOffset _ANSI_ARGS_((void *nsPtr, size_t offset,
	unsigned int offType));

/*
 * Macro to use to fill in "offset" fields of a structure.
 * Computes number of bytes from beginning of structure to a given field.
 * Based off Tk_Offset
 */

#ifdef offsetof
#define TclX_Offset(type, field) ((size_t) offsetof(type, field))
#else
#define TclX_Offset(type, field) ((size_t) ((char *) &((type *) 0)->field))
#endif

/* Special flags for "TclX_CreateObjCommand".
 */

#define TCLX_CMD_NOPREFIX	1  /* don't define with "exp_" prefix */
#define TCLX_CMD_REDEFINE	2  /* stomp on old commands with same name */

/*
 * UTF-8 compatibility handling
 */
#ifndef TCL_UTF_MAX
#define Tcl_WriteChars	Tcl_Write
#endif

#define TclX_WriteNL(channel) (Tcl_Write (channel, "\n", 1))

extern int
TclX_StrToOffset _ANSI_ARGS_((CONST char *string,
                              int         base,
                              off_t      *offsetPtr));

int
TclX_GetUnsignedFromObj _ANSI_ARGS_((Tcl_Interp *interp,
                                     Tcl_Obj    *objPtr,
                                     unsigned   *valuePtr));

extern int
TclX_GetChannelOption _ANSI_ARGS_((Tcl_Interp  *interp,
                                   Tcl_Channel  channel,
                                   int          option,
                                   int         *valuePtr));

extern Tcl_Obj *
TclXGetHostInfo _ANSI_ARGS_((Tcl_Interp *interp,
                             Tcl_Channel channel,
                             int         remoteHost));

extern Tcl_Channel
TclX_GetOpenChannel _ANSI_ARGS_((Tcl_Interp *interp,
                                 char       *handle,
                                 int         chanAccess));

extern Tcl_Channel
TclX_GetOpenChannelObj _ANSI_ARGS_((Tcl_Interp *interp,
                                    Tcl_Obj    *handle,
                                    int         chanAccess));

extern int
TclX_GetOffsetFromObj _ANSI_ARGS_((Tcl_Interp *interp,
                                   Tcl_Obj    *objPtr,
                                   off_t      *offsetPtr));

extern int
TclX_RelativeExpr _ANSI_ARGS_((Tcl_Interp  *interp,
                               Tcl_Obj     *exprPtr,
                               int          stringLen,
                               int         *exprResultPtr));

extern int
TclX_SetChannelOption _ANSI_ARGS_((Tcl_Interp  *interp,
                                   Tcl_Channel  channel,
                                   int          option,
                                   int          value));

extern char *
TclX_JoinPath _ANSI_ARGS_((char        *path1,
                           char        *path2,
                           Tcl_DString *joinedPath));

extern int  
TclX_WrongArgs _ANSI_ARGS_((Tcl_Interp *interp, 
                            Tcl_Obj    *commandNameObj, 
			    char       *string));

extern int
TclX_IsNullObj _ANSI_ARGS_((Tcl_Obj *objPtr));



/*
 * Definitions required to initialize all extended commands.
 */

extern void
TclX_BsearchInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_ChmodInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_CmdloopInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_DebugInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_DupInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_FcntlInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_FilecmdsInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_FstatInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_FlockInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_FilescanInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_GeneralInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_IdInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_KeyedListInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_LgetsInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_ListInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_MathInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_MsgCatInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_ProcessInit _ANSI_ARGS_((Tcl_Interp *interp));

void
TclX_ProfileInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_RestoreResultErrorInfo _ANSI_ARGS_((Tcl_Interp *interp,
                                         Tcl_Obj    *saveObjPtr));

extern Tcl_Obj *
TclX_SaveResultErrorInfo _ANSI_ARGS_((Tcl_Interp  *interp));

extern void
TclX_SelectInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_SignalInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_StringInit _ANSI_ARGS_((Tcl_Interp *interp));

extern int
TclX_LibraryInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_SocketInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_OsCmdsInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_PlatformCmdsInit _ANSI_ARGS_((Tcl_Interp *interp));

extern void
TclX_ServerInit _ANSI_ARGS_((Tcl_Interp *interp));

/*
 * From TclXxxxDup.c
 */
Tcl_Channel
TclXOSDupChannel _ANSI_ARGS_((Tcl_Interp *interp,
                              Tcl_Channel srcChannel,
                              int         mode,
                              char       *targetChannelId));

Tcl_Channel
TclXOSBindOpenFile _ANSI_ARGS_((Tcl_Interp *interp,
                                int         fileNum));

/*
 * from tclXxxxOS.c
 */
extern int
TclXNotAvailableError _ANSI_ARGS_((Tcl_Interp *interp,
                                   char       *funcName));
extern int
TclXNotAvailableObjError _ANSI_ARGS_((Tcl_Interp *interp,
				      Tcl_Obj *obj));

extern clock_t
TclXOSTicksToMS _ANSI_ARGS_((clock_t numTicks));

extern int
TclXOSgetpriority _ANSI_ARGS_((Tcl_Interp *interp,
                               int        *priority,
                               char       *funcName));

extern int
TclXOSincrpriority _ANSI_ARGS_((Tcl_Interp *interp,
                                int         priorityIncr,
                                int        *priority,
                                char       *funcName));

extern int
TclXOSpipe _ANSI_ARGS_((Tcl_Interp *interp,
                        Tcl_Channel *channels));

extern int
TclXOSsetitimer _ANSI_ARGS_((Tcl_Interp *interp,
                             double     *seconds,
                             char       *funcName));

extern void
TclXOSsleep _ANSI_ARGS_((unsigned seconds));

extern void
TclXOSsync _ANSI_ARGS_((void));

extern int
TclXOSfsync _ANSI_ARGS_((Tcl_Interp *interp,
                         Tcl_Channel channel));

extern int
TclXOSsystem _ANSI_ARGS_((Tcl_Interp *interp,
                          char       *command,
                          int        *exitCode));

extern int
TclX_OSlink _ANSI_ARGS_((Tcl_Interp *interp,
                         char       *srcPath,
                         char       *destPath,
                         char       *funcName));
extern int
TclX_OSsymlink _ANSI_ARGS_((Tcl_Interp *interp,
                            char       *srcPath,
                            char       *destPath,
                            char       *funcName));

extern void
TclXOSElapsedTime _ANSI_ARGS_((clock_t *realTime,
                               clock_t *cpuTime));

extern int
TclXOSkill _ANSI_ARGS_((Tcl_Interp *interp,
                        pid_t       pid,
                        int         signal,
                        char       *funcName));

extern int
TclXOSFstat _ANSI_ARGS_((Tcl_Interp  *interp,
                         Tcl_Channel  channel,
                         struct stat *statBuf,
                         int         *ttyDev));
    
extern int
TclXOSSeekable _ANSI_ARGS_((Tcl_Interp  *interp,
                            Tcl_Channel  channel,
                            int         *seekablePtr));

extern int
TclXOSWalkDir _ANSI_ARGS_((Tcl_Interp       *interp,
                           char             *path,
                           int               hidden,
                           TclX_WalkDirProc *callback,
                           ClientData        clientData));

extern int
TclXOSGetFileSize _ANSI_ARGS_((Tcl_Channel  channel,
                               off_t       *fileSize));

extern int
TclXOSftruncate _ANSI_ARGS_((Tcl_Interp  *interp,
                             Tcl_Channel  channel,
                             off_t        newSize,
                             char        *funcName));

extern int
TclXOSfork _ANSI_ARGS_((Tcl_Interp *interp,
                        Tcl_Obj    *funcNameObj));

extern int
TclXOSexecl _ANSI_ARGS_((Tcl_Interp *interp,
                         char       *path,
                         char      **argList));

extern int
TclXOSInetAtoN _ANSI_ARGS_((Tcl_Interp     *interp,
                            char           *strAddress,
                            struct in_addr *inAddress));

extern int
TclXOSgetpeername _ANSI_ARGS_((Tcl_Interp *interp,
                               Tcl_Channel channel,
                               void       *sockaddr,
                               int         sockaddrSize));

extern int
TclXOSgetsockname _ANSI_ARGS_((Tcl_Interp *interp,
                               Tcl_Channel channel,
                               void       *sockaddr,
                               int         sockaddrSize));

extern int
TclXOSgetsockopt _ANSI_ARGS_((Tcl_Interp  *interp,
                              Tcl_Channel  channel,
                              int          option,
                              int         *valuePtr));

extern int
TclXOSsetsockopt _ANSI_ARGS_((Tcl_Interp  *interp,
                              Tcl_Channel  channel,
                              int          option,
                              int          value));

extern int
TclXOSchmod _ANSI_ARGS_((Tcl_Interp *interp,
                         char       *fileName,
                         int         mode));

extern int
TclXOSfchmod _ANSI_ARGS_((Tcl_Interp *interp,
                          Tcl_Channel channel,
                          int         mode,
                          char       *funcName));
extern int  
TclXOSChangeOwnGrpObj _ANSI_ARGS_((Tcl_Interp  *interp,
                                   unsigned     options,
                                   char        *ownerStr,
                                   char        *groupStr,
                                   Tcl_Obj     *fileList,
                                   char        *funcName));

extern int
TclXOSFChangeOwnGrpObj _ANSI_ARGS_((Tcl_Interp *interp,
                                    unsigned    options,
                                    char       *ownerStr,
                                    char       *groupStr,
                                    Tcl_Obj    *channelIdList,
                                    char       *funcName));

int
TclXOSGetSelectFnum _ANSI_ARGS_((Tcl_Interp *interp,
                                 Tcl_Channel channel,
                                 int         direction,
                                 int *fnumPtr));

int
TclXOSHaveFlock _ANSI_ARGS_((void));

int
TclXOSFlock _ANSI_ARGS_((Tcl_Interp     *interp,
                         TclX_FlockInfo *lockInfoPtr));

int
TclXOSFunlock _ANSI_ARGS_((Tcl_Interp     *interp,
                           TclX_FlockInfo *lockInfoPtr));

int
TclXOSGetAppend _ANSI_ARGS_((Tcl_Interp *interp,
                             Tcl_Channel channel,
                             int        *valuePtr));

int
TclXOSSetAppend _ANSI_ARGS_((Tcl_Interp *interp,
                             Tcl_Channel channel,
                             int         value));

int
TclXOSGetCloseOnExec _ANSI_ARGS_((Tcl_Interp *interp,
                                  Tcl_Channel channel,
                                  int        *valuePtr));

int
TclXOSSetCloseOnExec _ANSI_ARGS_((Tcl_Interp *interp,
                                  Tcl_Channel channel,
                                  int         value));
#endif



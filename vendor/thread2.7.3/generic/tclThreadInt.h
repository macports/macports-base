/*
 * --------------------------------------------------------------------------
 * tclthreadInt.h --
 *
 * Global internal header file for the thread extension.
 *
 * Copyright (c) 2002 ActiveState Corporation.
 * Copyright (c) 2002 by Zoran Vasiljevic.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 * ---------------------------------------------------------------------------
 */

#ifndef _TCL_THREAD_INT_H_
#define _TCL_THREAD_INT_H_

#include "tclThread.h"
#include <stdlib.h> /* For strtoul */
#include <string.h> /* For memset and friends */

/*
 * Used to tag functions that are only to be visible within the module being
 * built and not outside it (where this is supported by the linker).
 */

#ifndef MODULE_SCOPE
#   ifdef __cplusplus
#	define MODULE_SCOPE extern "C"
#   else
#	define MODULE_SCOPE extern
#   endif
#endif

/*
 * For linking against NaviServer/AOLserver require V4 at least
 */

#ifdef NS_AOLSERVER
# include <ns.h>
# if !defined(NS_MAJOR_VERSION) || NS_MAJOR_VERSION < 4
#  error "unsupported NaviServer/AOLserver version"
# endif
#endif

/*
 * Allow for some command names customization.
 * Only thread:: and tpool:: are handled here.
 * Shared variable commands are more complicated.
 * Look into the threadSvCmd.h for more info.
 */

#define THREAD_CMD_PREFIX "thread::"
#define TPOOL_CMD_PREFIX  "tpool::"

/*
 * Exported from threadSvCmd.c file.
 */

MODULE_SCOPE int Sv_Init(Tcl_Interp *interp);

/*
 * Exported from threadSpCmd.c file.
 */

MODULE_SCOPE int Sp_Init(Tcl_Interp *interp);

/*
 * Exported from threadPoolCmd.c file.
 */

MODULE_SCOPE int Tpool_Init(Tcl_Interp *interp);

/*
 * Macros for splicing in/out of linked lists
 */

#define SpliceIn(a,b)                          \
    (a)->nextPtr = (b);                        \
    if ((b) != NULL)                           \
        (b)->prevPtr = (a);                    \
    (a)->prevPtr = NULL, (b) = (a)

#define SpliceOut(a,b)                         \
    if ((a)->prevPtr != NULL)                  \
        (a)->prevPtr->nextPtr = (a)->nextPtr;  \
    else                                       \
        (b) = (a)->nextPtr;                    \
    if ((a)->nextPtr != NULL)                  \
        (a)->nextPtr->prevPtr = (a)->prevPtr

/*
 * Version macros
 */

#define TCL_MINIMUM_VERSION(major,minor) \
  ((TCL_MAJOR_VERSION > (major)) || \
    ((TCL_MAJOR_VERSION == (major)) && (TCL_MINOR_VERSION >= (minor))))

/*
 * Utility macros
 */

#define TCL_CMD(a,b,c) \
  if (Tcl_CreateObjCommand((a),(b),(c),(ClientData)NULL, NULL) == NULL) \
    return TCL_ERROR

#define OPT_CMP(a,b) \
  ((a) && (b) && (*(a)==*(b)) && (*(a+1)==*(b+1)) && (!strcmp((a),(b))))

#ifndef TCL_TSD_INIT
#define TCL_TSD_INIT(keyPtr) \
  (ThreadSpecificData*)Tcl_GetThreadData((keyPtr),sizeof(ThreadSpecificData))
#endif

/*
 * Structure to pass to NsThread_Init. This holds the module
 * and virtual server name for proper interp initializations.
 */

typedef struct {
    char *modname;
    char *server;
} NsThreadInterpData;

/*
 * Handle binary compatibility regarding
 * Tcl_GetErrorLine in 8.x
 * See Tcl bug #3562640.
 */

MODULE_SCOPE int threadTclVersion;

typedef struct {
    void *unused1;
    void *unused2;
    int errorLine;
} tclInterpType;

#if defined(TCL_TIP285)
# undef Tcl_GetErrorLine
# if defined(USE_TCL_STUBS)
#   define Tcl_GetErrorLine(interp) ((threadTclVersion>85)? \
    ((int (*)(Tcl_Interp *))((&(tclStubsPtr->tcl_PkgProvideEx))[605]))(interp): \
    (((tclInterpType *)(interp))->errorLine))
#   undef Tcl_AddErrorInfo
#   define Tcl_AddErrorInfo(interp, msg) ((threadTclVersion>85)? \
    ((void (*)(Tcl_Interp *, Tcl_Obj *))((&(tclStubsPtr->tcl_PkgProvideEx))[574]))(interp, Tcl_NewStringObj(msg, -1)): \
    ((void (*)(Tcl_Interp *, const char *))((&(tclStubsPtr->tcl_PkgProvideEx))[66]))(interp, msg))
#   undef Tcl_BackgroundError
#   define Tcl_BackgroundError(interp) ((threadTclVersion>85)? \
    ((void (*)(Tcl_Interp *, int))((&(tclStubsPtr->tcl_PkgProvideEx))[609]))(interp, TCL_ERROR): \
    ((void (*)(Tcl_Interp *))((&(tclStubsPtr->tcl_PkgProvideEx))[76]))(interp))
# else
#   define Tcl_GetErrorLine(interp) (((tclInterpType *)(interp))->errorLine)
# endif
#endif


/* 8.5, 8.4, or less - Emulate access to the error-line information
 * This is TIP 336, unrelated to 285 (async cancellation).  When doing
 * a static link of the thread package (use case: basekits, tclkits,
 * ...)  and the core Tcl is < 8.6 we cannot use TCL_TIP285 to get
 * things done, because USE_TCL_STUBS is not set for static builds,
 * causing the check in threadCmd.c to bomb.
 */

#ifndef TCL_TIP285
# if !TCL_MINIMUM_VERSION(8,6)
#   define Tcl_GetErrorLine(interp) (((tclInterpType *)(interp))->errorLine)
# endif
#endif

#endif /* _TCL_THREAD_INT_H_ */

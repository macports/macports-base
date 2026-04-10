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
#include <stdarg.h> /* For va_list */

/*
 * MSVC 8.0 started to mark many standard C library functions depreciated
 * including the *printf family and others. Tell it to shut up.
 * (_MSC_VER is 1200 for VC6, 1300 or 1310 for vc7.net, 1400 for 8.0)
 */
#if defined(_MSC_VER)
#   pragma warning(disable:4090) /* see: https://developercommunity.visualstudio.com/t/c-compiler-incorrect-propagation-of-const-qualifie/390711 */
#   pragma warning(disable:4146)
#   pragma warning(disable:4244)
#   if _MSC_VER >= 1400
#	pragma warning(disable:4267)
#	pragma warning(disable:4996)
#   endif
#endif

/*
 * Used to tag functions that are only to be visible within the module being
 * built and not outside it (where this is supported by the linker).
 */

#ifndef MODULE_SCOPE
#   ifdef __cplusplus
#       define MODULE_SCOPE extern "C"
#   else
#       define MODULE_SCOPE extern
#   endif
#endif

#if defined(_WIN32) && defined(_MSC_VER) && _MSC_VER < 1900
#  define snprintf _snprintf
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

#if (TCL_MAJOR_VERSION == 8) && defined(USE_TCL_STUBS)
#undef Tcl_Free
#define Tcl_Free(p) tclStubsPtr->tcl_Free((char *)(p))
#undef Tcl_Realloc
#define Tcl_Realloc(p,m) tclStubsPtr->tcl_Realloc((char *)(p),(m))
#endif

#ifndef JOIN
#  define JOIN(a,b) JOIN1(a,b)
#  define JOIN1(a,b) a##b
#endif

#ifndef TCL_UNUSED
#   if defined(__cplusplus)
#	define TCL_UNUSED(T) T
#   elif defined(__GNUC__) && (__GNUC__ > 2)
#	define TCL_UNUSED(T) T JOIN(dummy, __LINE__) __attribute__((unused))
#   else
#	define TCL_UNUSED(T) T JOIN(dummy, __LINE__)
#   endif
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

MODULE_SCOPE const char *SvInit(Tcl_Interp *interp);

/*
 * Exported from threadSpCmd.c file.
 */

MODULE_SCOPE const char *SpInit(Tcl_Interp *interp);

/*
 * Exported from threadPoolCmd.c file.
 */

MODULE_SCOPE const char *TpoolInit(Tcl_Interp *interp);

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
 * Utility macros
 */

#if TCL_MAJOR_VERSION < 9
# define Tcl_CreateObjCommand2 Tcl_CreateObjCommand
#endif
#define TCL_CMD(a,b,c) \
  if (Tcl_CreateObjCommand2((a),(b),(c),NULL, NULL) == NULL) \
    return NULL;

#define OPT_CMP(a,b) \
  ((a) && (b) && ((a)[0]==(b)[0]) && ((a)[1]==(b)[1]) && (!strcmp((a),(b))))

#ifndef TCL_TSD_INIT
#define TCL_TSD_INIT(keyPtr) \
  (ThreadSpecificData*)Tcl_GetThreadData((keyPtr),sizeof(ThreadSpecificData))
#endif

#ifdef TCL_QUEUE_ALERT_IF_EMPTY
static inline void
ThreadQueueEvent(Tcl_ThreadId thrId, Tcl_Event *evPtr, Tcl_QueuePosition position) {
    Tcl_ThreadQueueEvent(thrId, evPtr, position|TCL_QUEUE_ALERT_IF_EMPTY);
}
#else
static inline void
ThreadQueueEvent(Tcl_ThreadId thrId, Tcl_Event *evPtr, Tcl_QueuePosition position) {
    Tcl_ThreadQueueEvent(thrId, evPtr, position);
    Tcl_ThreadAlert(thrId);
}
#endif

/*
 * Structure to pass to NsThread_Init. This holds the module
 * and virtual server name for proper interp initializations.
 */

typedef struct {
    char *modname;
    char *server;
} NsThreadInterpData;

#endif /* _TCL_THREAD_INT_H_ */

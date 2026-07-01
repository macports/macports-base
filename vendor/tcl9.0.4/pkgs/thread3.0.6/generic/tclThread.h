/*
 * --------------------------------------------------------------------------
 * tclthread.h --
 *
 * Global header file for the thread extension.
 *
 * Copyright (c) 2002 ActiveState Corporation.
 * Copyright (c) 2002 by Zoran Vasiljevic.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 * ---------------------------------------------------------------------------
 */

/*
 * Thread extension version numbers are not stored here
 * because this isn't a public export file.
 */

#ifndef _TCL_THREAD_H_
#define _TCL_THREAD_H_

#include <tcl.h>

/*
 * Bunch of Tcl8 and Tcl9 compatibility definitions.
 */
#ifndef TCL_INDEX_NONE
# define TCL_INDEX_NONE (-1)
#endif

#if TCL_MAJOR_VERSION < 9
  typedef Tcl_ObjCmdProc Tcl_ObjCmdProc2;
# undef Tcl_Size
  typedef int Tcl_Size;
#endif
#ifndef TCL_HASH_TYPE
# if TCL_MAJOR_VERSION < 9
#   define TCL_HASH_TYPE unsigned
# else
#   define TCL_HASH_TYPE size_t
# endif
#endif

#ifndef TCL_Z_MODIFIER
#   if defined(__GNUC__) && !defined(_WIN32)
#	define TCL_Z_MODIFIER	"z"
#   elif defined(_WIN64)
#	define TCL_Z_MODIFIER	TCL_LL_MODIFIER
#   else
#	define TCL_Z_MODIFIER	""
#   endif
#endif /* !TCL_Z_MODIFIER */

/*
 * Exported from threadCmd.c file.
 */
#ifdef __cplusplus
extern "C" {
#endif
DLLEXPORT int Thread_Init(Tcl_Interp *interp);
#ifdef __cplusplus
}
#endif

#endif /* _TCL_THREAD_H_ */

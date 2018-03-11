/* 
 * tclExtend.h
 *
 *    External declarations for the extended Tcl library.
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
 * $Id: tclExtend.h,v 1.5 2002/09/26 00:23:29 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#ifndef TCLEXTEND_H
#define TCLEXTEND_H

#include <stdio.h>
#include "tcl.h"

/*
 * The following is needed on Windows to deal with export/import of DLL
 * functions.  See tcl???/win/README.
 */
#if defined(BUILD_tclx) || defined(BUILD_TCLX)
# undef TCL_STORAGE_CLASS
# define TCL_STORAGE_CLASS DLLEXPORT
#endif

#ifndef CONST84
#  define CONST84
#endif

/*
 * The TCLX_DEBUG flag turns on asserts etc.  Its an internal flag, however
 * its normally true for alpha and beta release and false for final releases,
 * so we put the flag right by the version numbers in hopes that we will
 * remember to change it.
#define TCLX_DEBUG
 */

#define TCLX_PATCHLEVEL		0

/*
 * Generic void pointer.
 */
typedef void *void_pt;

/*
 * Flags to command loop functions.
 */
#define TCLX_CMDL_INTERACTIVE	(1<<0)
#define TCLX_CMDL_EXIT_ON_EOF	(1<<1)

/*
 * Application signal error handler.  Called after normal signal processing,
 * when a signal results in an error.	Its main purpose in life is to allow
 * interactive command loops to clear their input buffer on SIGINT.  This is
 * not currently a generic interface, but should be. Only one maybe active.
 * This is an undocumented interface.  Its in the external file in case
 * someone needs this facility.	 It might change in the future.	 Let us
 * know if you need this functionality.
 */
typedef int
(*TclX_AppSignalErrorHandler) _ANSI_ARGS_((Tcl_Interp *interp,
					   ClientData  clientData,
					   int	       background,
					   int	       signalNum));

/*
 * Exported TclX initialization functions.
 */

EXTERN int	Tclx_Init _ANSI_ARGS_((Tcl_Interp *interp));

EXTERN int	Tclx_SafeInit _ANSI_ARGS_((Tcl_Interp *interp));

EXTERN int	Tclx_InitStandAlone _ANSI_ARGS_((Tcl_Interp *interp));

EXTERN void	TclX_PrintResult _ANSI_ARGS_((Tcl_Interp *interp,
			      int	  intResult,
			      char	 *checkCmd));

EXTERN void	TclX_SetupSigInt _ANSI_ARGS_((void));

EXTERN void	TclX_SetAppSignalErrorHandler _ANSI_ARGS_((
	TclX_AppSignalErrorHandler errorFunc, ClientData clientData));

EXTERN void	TclX_SetAppInfo _ANSI_ARGS_((int   defaultValues,
			     char *appName,
			     char *appLongName,
			     char *appVersion,
			     int   appPatchlevel));

EXTERN void	TclX_SplitWinCmdLine _ANSI_ARGS_((int *argcPtr,
	char ***argvPtr));

/*
 * Exported utility functions.
 */
EXTERN void	TclX_AppendObjResult _ANSI_ARGS_(TCL_VARARGS_DEF(Tcl_Interp *, interpArg));

EXTERN char *	TclX_DownShift _ANSI_ARGS_((char *targetStr, CONST char *sourceStr));

EXTERN int	TclX_StrToInt _ANSI_ARGS_((CONST char *string, int base, int *intPtr));

EXTERN int	TclX_StrToUnsigned _ANSI_ARGS_((CONST char *string,
				int	    base,
				unsigned   *unsignedPtr));

EXTERN char *	TclX_UpShift _ANSI_ARGS_((char	     *targetStr,
			  CONST char *sourceStr));

/*
 * Exported keyed list object manipulation functions.
 */
EXTERN Tcl_Obj * TclX_NewKeyedListObj _ANSI_ARGS_((void));

EXTERN int	TclX_KeyedListGet _ANSI_ARGS_((Tcl_Interp *interp,
			       Tcl_Obj	  *keylPtr,
			       char	  *key,
			       Tcl_Obj	 **valuePtrPtr));

EXTERN int	TclX_KeyedListSet _ANSI_ARGS_((Tcl_Interp *interp,
			       Tcl_Obj	  *keylPtr,
			       char	  *key,
			       Tcl_Obj	  *valuePtr));

EXTERN int	TclX_KeyedListDelete _ANSI_ARGS_((Tcl_Interp *interp,
				  Tcl_Obj    *keylPtr,
				  char	     *key));

EXTERN int	TclX_KeyedListGetKeys _ANSI_ARGS_((Tcl_Interp *interp,
				   Tcl_Obj    *keylPtr,
				   char	      *key,
				   Tcl_Obj   **listObjPtrPtr));

/*
 * Exported handle table manipulation functions.
 */
EXTERN void_pt	TclX_HandleAlloc _ANSI_ARGS_((void_pt	headerPtr,
			      char     *handlePtr));

EXTERN void	TclX_HandleFree _ANSI_ARGS_((void_pt  headerPtr,
			     void_pt  entryPtr));

EXTERN void_pt	TclX_HandleTblInit _ANSI_ARGS_((CONST char *handleBase,
				int	    entrySize,
				int	    initEntries));

EXTERN void	TclX_HandleTblRelease _ANSI_ARGS_((void_pt headerPtr));

EXTERN int	TclX_HandleTblUseCount _ANSI_ARGS_((void_pt headerPtr,
				    int	    amount));

EXTERN void_pt	TclX_HandleWalk _ANSI_ARGS_((void_pt   headerPtr,
			    int	     *walkKeyPtr));

EXTERN void	TclX_WalkKeyToHandle _ANSI_ARGS_((void_pt   headerPtr,
				 int	   walkKey,
				 char	  *handlePtr));

EXTERN void_pt	TclX_HandleXlate _ANSI_ARGS_((Tcl_Interp  *interp,
			     void_pt	  headerPtr,
			     CONST  char *handle));

EXTERN void_pt	TclX_HandleXlateObj _ANSI_ARGS_((Tcl_Interp    *interp,
				void_pt	       headerPtr,
				Tcl_Obj	      *handleObj));
/*
 * Command loop functions.
 */
EXTERN int	TclX_CommandLoop _ANSI_ARGS_((Tcl_Interp *interp,
			      int	  options,
			      char	 *endCommand,
			      char	 *prompt1,
			      char	 *prompt2));

EXTERN int	TclX_AsyncCommandLoop _ANSI_ARGS_((Tcl_Interp *interp,
				int	       options,
				char	      *endCommand,
				char	      *prompt1,
				char	      *prompt2));

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLIMPORT

#endif

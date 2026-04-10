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
 * $Id: tclExtend.h,v 1.4 2002/09/26 00:19:18 hobbs Exp $
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
(*TclX_AppSignalErrorHandler) (Tcl_Interp *interp,
                               ClientData  clientData,
                               int	       background,
                               int	       signalNum);

/*
 * Exported TclX initialization functions.
 */

EXTERN int	Tclx_Init (Tcl_Interp *interp);

EXTERN int	Tclx_SafeInit (Tcl_Interp *interp);

EXTERN int	Tclx_InitStandAlone (Tcl_Interp *interp);

EXTERN void	TclX_PrintResult (Tcl_Interp *interp,
                              int	  intResult,
                              char	 *checkCmd);

EXTERN void	TclX_SetupSigInt (void);

EXTERN void	TclX_SetAppSignalErrorHandler (
	TclX_AppSignalErrorHandler errorFunc, ClientData clientData);

EXTERN void	TclX_SetAppInfo (int   defaultValues,
                             char *appName,
                             char *appLongName,
                             char *appVersion,
                             int   appPatchlevel);

EXTERN void	TclX_SplitWinCmdLine (int *argcPtr, char ***argvPtr);

/*
 * Exported utility functions.
 */

#if defined(__GNUC__) && __GNUC__ >= 4
__attribute__((sentinel))
#endif
EXTERN void	TclX_AppendObjResult (Tcl_Interp *interp, ...);

EXTERN char *	TclX_DownShift (char *targetStr, const char *sourceStr);

EXTERN int	TclX_StrToInt (const char *string, int base, int *intPtr);

EXTERN int	TclX_StrToUnsigned (const char *string,
                                int	    base,
                                unsigned   *unsignedPtr);

EXTERN char *	TclX_UpShift (char	     *targetStr,
                              const char *sourceStr);

/*
 * Exported keyed list object manipulation functions.
 */
EXTERN Tcl_Obj * TclX_NewKeyedListObj (void);

EXTERN int	TclX_KeyedListGet (Tcl_Interp *interp,
                               Tcl_Obj	  *keylPtr,
                               char	  *key,
                               Tcl_Obj	 **valuePtrPtr);

EXTERN int	TclX_KeyedListSet (Tcl_Interp *interp,
                               Tcl_Obj	  *keylPtr,
                               char	  *key,
                               Tcl_Obj	  *valuePtr);

EXTERN int	TclX_KeyedListDelete (Tcl_Interp *interp,
                                  Tcl_Obj    *keylPtr,
                                  char	     *key);

EXTERN int	TclX_KeyedListGetKeys (Tcl_Interp *interp,
                                   Tcl_Obj    *keylPtr,
                                   char	      *key,
                                   Tcl_Obj   **listObjPtrPtr);

/*
 * Exported handle table manipulation functions.
 */
EXTERN void_pt	TclX_HandleAlloc (void_pt	headerPtr,
                                  char     *handlePtr);

EXTERN void	TclX_HandleFree (void_pt  headerPtr,
                             void_pt  entryPtr);

EXTERN void_pt	TclX_HandleTblInit (const char *handleBase,
                                    int	    entrySize,
                                    int	    initEntries);

EXTERN void	TclX_HandleTblRelease (void_pt headerPtr);

EXTERN int	TclX_HandleTblUseCount (void_pt headerPtr,
                                    int	    amount);

EXTERN void_pt	TclX_HandleWalk (void_pt   headerPtr,
                                 int	     *walkKeyPtr);

EXTERN void	TclX_WalkKeyToHandle (void_pt   headerPtr,
                                  int	   walkKey,
                                  char	  *handlePtr);

EXTERN void_pt	TclX_HandleXlate (Tcl_Interp  *interp,
                                  void_pt	  headerPtr,
                                  const  char *handle);

EXTERN void_pt	TclX_HandleXlateObj (Tcl_Interp    *interp,
                                     void_pt	       headerPtr,
                                     Tcl_Obj	      *handleObj);
/*
 * Command loop functions.
 */
EXTERN int	TclX_CommandLoop (Tcl_Interp *interp,
                              int	  options,
                              char	 *endCommand,
                              char	 *prompt1,
                              char	 *prompt2);

EXTERN int	TclX_AsyncCommandLoop (Tcl_Interp *interp,
                                   int	       options,
                                   char	      *endCommand,
                                   char	      *prompt1,
                                   char	      *prompt2);

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLIMPORT

#endif

/* vim: set ts=4 sw=4 sts=4 et : */

/*
 * tclXinit.c --
 *
 * Extended Tcl initialzation and initialization utilitied.
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
 * $Id: tclXinit.c,v 1.4 2005/03/24 05:11:15 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Tcl procedure to search for an init for TclX startup file.  
 */

static char initScript[] = "if {[info proc ::tclx::Init]==\"\"} {\n\
  namespace eval ::tclx {}\n\
  proc ::tclx::Init {} {\n"
#ifdef MAC_TCL
"    source -rsrc tclx.tcl\n"
#else
"    global tclx_library\n\
    tcl_findLibrary tclx " PACKAGE_VERSION " " FULL_VERSION " tclx.tcl TCLX_LIBRARY tclx_library\n"
#endif
"  }\n\
}\n\
::tclx::Init";

/*
 * Prototypes of internal functions.
 */
static int	Tclxcmd_Init _ANSI_ARGS_((Tcl_Interp *interp));


/*-----------------------------------------------------------------------------
 * Tclx_Init --
 *
 *   Initialize all Extended Tcl commands, set auto_path and source the
 * Tcl init file.
 *-----------------------------------------------------------------------------
 */
int
Tclx_Init (interp)
    Tcl_Interp *interp;
{
    if (Tclx_SafeInit(interp) != TCL_OK) {
	return TCL_ERROR;
    }

    if ((Tcl_EvalEx(interp, initScript, -1,
	    TCL_EVAL_GLOBAL | TCL_EVAL_DIRECT) != TCL_OK)
	    || (TclX_LibraryInit(interp) != TCL_OK)) {
	Tcl_AddErrorInfo(interp, "\n    (in TclX_Init)");
	return TCL_ERROR;
    }

    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * Tclx_SafeInit --
 *
 *   Initialize safe Extended Tcl commands.
 *-----------------------------------------------------------------------------
 */
int
Tclx_SafeInit (interp)
    Tcl_Interp *interp;
{
    if (
#ifdef USE_TCL_STUBS
	(Tcl_InitStubs(interp, "8.0", 0) == NULL)
#else
	(Tcl_PkgRequire(interp, "Tcl", "8.0", 0) == NULL)
#endif
	|| (Tclxcmd_Init(interp) != TCL_OK)
	|| (Tcl_PkgProvide(interp, "Tclx", PACKAGE_VERSION) != TCL_OK)
	) {
	Tcl_AddErrorInfo (interp, "\n    (in TclX_SafeInit)");
	return TCL_ERROR;
    }

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tclxcmd_Init --
 *
 *   Add the Extended Tcl commands to the specified interpreter (except for
 * the library commands that override that standard Tcl procedures).  This
 * does no other startup.
 *-----------------------------------------------------------------------------
 */
static int
Tclxcmd_Init (interp)
    Tcl_Interp *interp;
{
    /*
     * These are ok in safe interps.
     */
    TclX_SetAppInfo(TRUE, "TclX", "Extended Tcl",
	    PACKAGE_VERSION, TCLX_PATCHLEVEL);

    TclX_BsearchInit (interp);
    TclX_FstatInit (interp);
    TclX_FlockInit (interp);
    TclX_FilescanInit (interp);
    TclX_GeneralInit (interp);
    TclX_IdInit (interp);
    TclX_KeyedListInit (interp);
    TclX_LgetsInit (interp);
    TclX_ListInit (interp);
    TclX_MathInit (interp);
    TclX_ProfileInit (interp);
    TclX_SelectInit (interp);
    TclX_StringInit (interp);

    if (!Tcl_IsSafe(interp)) {
	/*
	 * Add these only in trusted interps.
	 */
	TclX_ChmodInit (interp);
	TclX_CmdloopInit (interp);
	TclX_DebugInit (interp);
	TclX_DupInit (interp);
	TclX_FcntlInit (interp);
	TclX_FilecmdsInit (interp);
	TclX_FstatInit (interp);
	TclX_MsgCatInit (interp);
	TclX_ProcessInit (interp);
	TclX_SignalInit (interp);
	TclX_OsCmdsInit (interp);
	TclX_PlatformCmdsInit (interp);
	TclX_SocketInit (interp);
	TclX_ServerInit (interp);
    }

    return TCL_OK;
}

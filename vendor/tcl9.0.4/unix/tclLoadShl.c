/*
 * tclLoadShl.c --
 *
 *	This procedure provides a version of the TclLoadFile that works with
 *	the "shl_load" and "shl_findsym" library procedures for dynamic
 *	loading (e.g. for HP machines).
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include <dl.h>
#include "tclInt.h"

/*
 * Static functions defined within this file.
 */

static void *		FindSymbol(Tcl_Interp *interp,
			    Tcl_LoadHandle loadHandle, const char *symbol);
static void		UnloadFile(Tcl_LoadHandle handle);

/*
 *----------------------------------------------------------------------
 *
 * TclpDlopen --
 *
 *	Dynamically loads a binary code file into memory and returns a handle
 *	to the new code.
 *
 * Results:
 *	A standard Tcl completion code. If an error occurs, an error message
 *	is left in the interp's result.
 *
 * Side effects:
 *	New code suddenly appears in memory.
 *
 *---------------------------------------------------------------------------
 */

int
TclpDlopen(
    Tcl_Interp *interp,		/* Used for error reporting. */
    Tcl_Obj *pathPtr,		/* Name of the file containing the desired
				 * code (UTF-8). */
    Tcl_LoadHandle *loadHandle,	/* Filled with token for dynamically loaded
				 * file which will be passed back to
				 * (*unloadProcPtr)() to unload the file. */
    Tcl_FSUnloadFileProc **unloadProcPtr,
				/* Filled with address of Tcl_FSUnloadFileProc
				 * function which should be used for this
				 * file. */
    int flags)
{
    shl_t handle;
    Tcl_LoadHandle newHandle;
    const char *native;
    char *fileName = TclGetString(pathPtr);

    /*
     * The flags below used to be BIND_IMMEDIATE; they were changed at the
     * suggestion of Wolfgang Kechel (wolfgang@prs.de): "This enables
     * verbosity for missing symbols when loading a shared lib and allows to
     * load libtk9.0.sl into tclsh9.0 without problems.  In general, this
     * delays resolving symbols until they are actually needed.  Shared libs
     * do no longer need all libraries linked in when they are build."
     */

    /*
     * First try the full path the user gave us.  This is particularly
     * important if the cwd is inside a vfs, and we are trying to load using a
     * relative path.
     */

    native = Tcl_FSGetNativePath(pathPtr);
    handle = shl_load(native, BIND_DEFERRED|BIND_VERBOSE, 0L);

    if (handle == NULL) {
	/*
	 * Let the OS loader examine the binary search path for whatever
	 * string the user gave us which hopefully refers to a file on the
	 * binary path.
	 */

	Tcl_DString ds;

	if (Tcl_UtfToExternalDStringEx(interp, NULL, fileName, TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	    Tcl_DStringFree(&ds);
	    return TCL_ERROR;
	}
	native = Tcl_DStringValue(&ds);
	handle = shl_load(native, BIND_DEFERRED|BIND_VERBOSE|DYNAMIC_PATH, 0L);
	Tcl_DStringFree(&ds);
    }

    if (handle == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't load file \"%s\": %s",
		fileName, Tcl_PosixError(interp)));
	return TCL_ERROR;
    }
    newHandle = (Tcl_LoadHandle)Tcl_Alloc(sizeof(*newHandle));
    newHandle->clientData = handle;
    newHandle->findSymbolProcPtr = &FindSymbol;
    newHandle->unloadFileProcPtr = *unloadProcPtr = &UnloadFile;
    *loadHandle = newHandle;
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FindSymbol --
 *
 *	Looks up a symbol, by name, through a handle associated with a
 *	previously loaded piece of code (shared library).
 *
 * Results:
 *	Returns a pointer to the function associated with 'symbol' if it is
 *	found.  Otherwise returns NULL and may leave an error message in the
 *	interp's result.
 *
 *----------------------------------------------------------------------
 */

static void*
FindSymbol(
    Tcl_Interp *interp,
    Tcl_LoadHandle loadHandle,
    const char *symbol)
{
    Tcl_DString newName;
    Tcl_LibraryInitProc *proc = NULL;
    shl_t handle = (shl_t) loadHandle->clientData;

    /*
     * Some versions of the HP system software still use "_" at the beginning
     * of exported symbols while others don't; try both forms of each name.
     */

    if (shl_findsym(&handle, symbol, (short) TYPE_PROCEDURE,
	    (void *)&proc) != 0) {
	Tcl_DStringInit(&newName);
	TclDStringAppendLiteral(&newName, "_");
	Tcl_DStringAppend(&newName, symbol, TCL_INDEX_NONE);
	if (shl_findsym(&handle, Tcl_DStringValue(&newName),
		(short) TYPE_PROCEDURE, (void *)&proc) != 0) {
	    proc = NULL;
	}
	Tcl_DStringFree(&newName);
    }
    if (proc == NULL && interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"cannot find symbol \"%s\": %s",
		symbol, Tcl_PosixError(interp)));
    }
    return proc;
}

/*
 *----------------------------------------------------------------------
 *
 * UnloadFile --
 *
 *	Unloads a dynamically loaded binary code file from memory.  Code
 *	pointers in the formerly loaded file are no longer valid after calling
 *	this function.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Code removed from memory.
 *
 *----------------------------------------------------------------------
 */

static void
UnloadFile(
    Tcl_LoadHandle loadHandle)	/* loadHandle returned by a previous call to
				 * TclpDlopen(). The loadHandle is a token
				 * that represents the loaded file. */
{
    shl_t handle = (shl_t) loadHandle->clientData;

    shl_unload(handle);
    Tcl_Free(loadHandle);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

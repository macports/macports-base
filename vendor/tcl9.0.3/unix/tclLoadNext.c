/*
 * tclLoadNext.c --
 *
 *	This procedure provides a version of the TclLoadFile that works with
 *	NeXTs rld_* dynamic loading. This file provided by Pedja Bogdanovich.
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include <mach-o/rld.h>
#include <streams/streams.h>

/*
 * Static procedures defined within this file.
 */

static void *		FindSymbol(Tcl_Interp *interp,
			    Tcl_LoadHandle loadHandle, const char *symbol);
static void		UnloadFile(Tcl_LoadHandle loadHandle);

/*
 *---------------------------------------------------------------------------
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
    Tcl_LoadHandle newHandle;
    struct mach_header *header;
    char *fileName;
    char *files[2];
    const char *native;
    int result = 1;

    NXStream *errorStream = NXOpenMemory(0,0,NX_READWRITE);

    fileName = TclGetString(pathPtr);

    /*
     * First try the full path the user gave us. This is particularly
     * important if the cwd is inside a vfs, and we are trying to load using a
     * relative path.
     */

    native = Tcl_FSGetNativePath(pathPtr);
    files = {native,NULL};

    result = rld_load(errorStream, &header, files, NULL);

    if (!result) {
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
	files = {native,NULL};
	result = rld_load(errorStream, &header, files, NULL);
	Tcl_DStringFree(&ds);
    }

    if (!result) {
	char *data;
	int len, maxlen;

	NXGetMemoryBuffer(errorStream, &data, &len, &maxlen);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"couldn't load file \"%s\": %s", fileName, data));
	NXCloseMemory(errorStream, NX_FREEBUFFER);
	return TCL_ERROR;
    }
    NXCloseMemory(errorStream, NX_FREEBUFFER);

    newHandle = (Tcl_LoadHandle)Tcl_Alloc(sizeof(*newHandle));
    newHandle->clientData = INT2PTR(1);
    newHandle->findSymbolProcPtr = &FindSymbol;
    newHandle->unloadFileProcPtr = &UnloadFile;
    *unloadProcPtr = &UnloadFile;
    *loadHandle = newHandle;

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FindSymbol --
 *
 *	Looks up a symbol, by name, through a handle associated with a
 *	previously loaded piece of code (shared library).
 *
 * Results:
 *	Returns a pointer to the function associated with 'symbol' if it is
 *	found. Otherwise returns NULL and may leave an error message in the
 *	interp's result.
 *
 *----------------------------------------------------------------------
 */

static void *
FindSymbol(
    Tcl_Interp *interp,
    Tcl_LoadHandle loadHandle,
    const char *symbol)
{
    Tcl_LibraryInitProc *proc = NULL;

    if (symbol) {
	char sym[strlen(symbol) + 2];

	sym[0] = '_';
	sym[1] = 0;
	strcat(sym, symbol);
	rld_lookup(NULL, sym, (unsigned long *) &proc);
    }
    if (proc == NULL && interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"cannot find symbol \"%s\"", symbol));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "LOAD_SYMBOL", symbol, (char *)NULL);
    }
    return proc;
}

/*
 *----------------------------------------------------------------------
 *
 * UnloadFile --
 *
 *	Unloads a dynamically loaded binary code file from memory. Code
 *	pointers in the formerly loaded file are no longer valid after calling
 *	this function.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Does nothing.  Can anything be done?
 *
 *----------------------------------------------------------------------
 */

static void
UnloadFile(
    Tcl_LoadHandle loadHandle)	/* loadHandle returned by a previous call to
				 * TclpDlopen(). The loadHandle is a token
				 * that represents the loaded file. */
{
    Tcl_Free(loadHandle);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/*
 * tclLoadDl.c --
 *
 *	This procedure provides a version of the TclLoadFile that works with
 *	the "dlopen" and "dlsym" library procedures for dynamic loading.
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#ifdef NO_DLFCN_H
#   include "../compat/dlfcn.h"
#else
#   include <dlfcn.h>
#endif

/*
 * In some systems, like SunOS 4.1.3, the RTLD_NOW flag isn't defined and this
 * argument to dlopen must always be 1. The RTLD_LOCAL flag doesn't exist on
 * some platforms; if it doesn't exist, set it to 0 so it has no effect.
 * See [Bug #3216070]
 */

#ifndef RTLD_NOW
#   define RTLD_NOW 1
#endif

#ifndef RTLD_LOCAL
#   define RTLD_LOCAL 0
#endif

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
    void *handle;
    Tcl_LoadHandle newHandle;
    const char *native;
    int dlopenflags = 0;

    /*
     * First try the full path the user gave us. This is particularly
     * important if the cwd is inside a vfs, and we are trying to load using a
     * relative path.
     */

    native = (const char *)Tcl_FSGetNativePath(pathPtr);
    /*
     * Use (RTLD_NOW|RTLD_LOCAL) as default, see [Bug #3216070]
     */
    if (flags & TCL_LOAD_GLOBAL) {
	dlopenflags |= RTLD_GLOBAL;
    } else {
	dlopenflags |= RTLD_LOCAL;
    }
    if (flags & TCL_LOAD_LAZY) {
	dlopenflags |= RTLD_LAZY;
    } else {
	dlopenflags |= RTLD_NOW;
    }
    handle = dlopen(native, dlopenflags);
    if (handle == NULL) {
	/*
	 * Let the OS loader examine the binary search path for whatever
	 * string the user gave us which hopefully refers to a file on the
	 * binary path.
	 */

	Tcl_DString ds;
	const char *fileName = TclGetString(pathPtr);

	if (Tcl_UtfToExternalDStringEx(interp, NULL, fileName, TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	    Tcl_DStringFree(&ds);
	    return TCL_ERROR;
	}
	native = Tcl_DStringValue(&ds);
	/*
	 * Use (RTLD_NOW|RTLD_LOCAL) as default, see [Bug #3216070]
	 */
	handle = dlopen(native, dlopenflags);
	Tcl_DStringFree(&ds);
    }

    if (handle == NULL) {
	/*
	 * Write the string to a variable first to work around a compiler bug
	 * in the Sun Forte 6 compiler. [Bug 1503729]
	 */

	const char *errorStr = dlerror();

	if (interp) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "couldn't load file \"%s\": %s",
		    TclGetString(pathPtr), errorStr));
	}
	return TCL_ERROR;
    }
    newHandle = (Tcl_LoadHandle)Tcl_Alloc(sizeof(*newHandle));
    newHandle->clientData = handle;
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
    Tcl_Interp *interp,		/* Place to put error messages. */
    Tcl_LoadHandle loadHandle,	/* Value from TcpDlopen(). */
    const char *symbol)		/* Symbol to look up. */
{
    const char *native;		/* Name of the library to be loaded, in
				 * system encoding */
    Tcl_DString newName, ds;	/* Buffers for converting the name to
				 * system encoding and prepending an
				 * underscore*/
    void *handle = loadHandle->clientData;
				/* Native handle to the loaded library */
    void *proc;			/* Address corresponding to the resolved
				 * symbol */

    /*
     * Some platforms still add an underscore to the beginning of symbol
     * names. If we can't find a name without an underscore, try again with
     * the underscore.
     */

    if (Tcl_UtfToExternalDStringEx(interp, NULL, symbol, TCL_INDEX_NONE, 0, &ds, NULL) != TCL_OK) {
	Tcl_DStringFree(&ds);
	return NULL;
    }
    native = Tcl_DStringValue(&ds);
    proc = dlsym(handle, native);	/* INTL: Native. */
    if (proc == NULL) {
	Tcl_DStringInit(&newName);
	TclDStringAppendLiteral(&newName, "_");
	native = Tcl_DStringAppend(&newName, native, TCL_INDEX_NONE);
	proc = dlsym(handle, native);	/* INTL: Native. */
	Tcl_DStringFree(&newName);
    }
#ifdef __cplusplus
    if (proc == NULL) {
	char buf[32];
	snprintf(buf, sizeof(buf), "%d", (int)Tcl_DStringLength(&ds));
	Tcl_DStringInit(&newName);
	TclDStringAppendLiteral(&newName, "__Z");
	Tcl_DStringAppend(&newName, buf, TCL_INDEX_NONE);
	Tcl_DStringAppend(&newName, Tcl_DStringValue(&ds), TCL_INDEX_NONE);
	TclDStringAppendLiteral(&newName, "P10Tcl_Interp");
	native = Tcl_DStringValue(&newName);
	proc = dlsym(handle, native + 1);	/* INTL: Native. */
	if (proc == NULL) {
	    proc = dlsym(handle, native);	/* INTL: Native. */
	}
	if (proc == NULL) {
	    TclDStringAppendLiteral(&newName, "i");
	    native = Tcl_DStringValue(&newName);
	    proc = dlsym(handle, native + 1);	/* INTL: Native. */
	}
	if (proc == NULL) {
	    proc = dlsym(handle, native);	/* INTL: Native. */
	}
	Tcl_DStringFree(&newName);
    }
#endif
    Tcl_DStringFree(&ds);
    if (proc == NULL) {
	const char *errorStr = dlerror();

	if (interp) {
	    if (!errorStr) {
		errorStr = "unknown";
	    }
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "cannot find symbol \"%s\": %s", symbol, errorStr));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "LOAD_SYMBOL", symbol,
		    (char *)NULL);
	}
    }
    return proc;
}

/*
 *----------------------------------------------------------------------
 *
 * UnloadFile --
 *
 *	Unloads a dynamic shared object, after which all pointers to functions
 *	in the formerly-loaded object are no longer valid.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory for the loaded object is deallocated.
 *
 *----------------------------------------------------------------------
 */

static void
UnloadFile(
    Tcl_LoadHandle loadHandle)	/* loadHandle returned by a previous call to
				 * TclpDlopen(). The loadHandle is a token
				 * that represents the loaded file. */
{
    void *handle = loadHandle->clientData;

    dlclose(handle);
    Tcl_Free(loadHandle);
}

/*
 * These functions are fallbacks if we somehow determine that the platform can
 * do loading from memory but the user wishes to disable it. They just report
 * (gracefully) that they fail.
 */

#ifdef TCL_LOAD_FROM_MEMORY

MODULE_SCOPE void *
TclpLoadMemoryGetBuffer(
    TCL_UNUSED(size_t))
{
    return NULL;
}

MODULE_SCOPE int
TclpLoadMemory(
    TCL_UNUSED(void *),
    TCL_UNUSED(size_t),
    TCL_UNUSED(Tcl_Size),
    TCL_UNUSED(const char *),
    TCL_UNUSED(Tcl_LoadHandle *),
    TCL_UNUSED(Tcl_FSUnloadFileProc **),
    TCL_UNUSED(int))
{
    return TCL_ERROR;
}

#endif /* TCL_LOAD_FROM_MEMORY */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

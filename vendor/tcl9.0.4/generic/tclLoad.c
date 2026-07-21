/*
 * tclLoad.c --
 *
 *	This file provides the generic portion (those that are the same on all
 *	platforms) of Tcl's dynamic loading facilities.
 *
 * Copyright © 1995-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/*
 * The following structure describes a library that has been loaded either
 * dynamically (with the "load" command) or statically (as indicated by a call
 * to Tcl_StaticLibrary). All such libraries are linked together into a
 * single list for the process.
 */

typedef struct LoadedLibrary {
    char *fileName;		/* Name of the file from which the library was
				 * loaded. An empty string means the library
				 * is loaded statically. Malloc-ed. */
    char *prefix;		/* Prefix for the library.
				 * Malloc-ed. */
    Tcl_LoadHandle loadHandle;	/* Token for the loaded file which should be
				 * passed to (*unLoadProcPtr)() when the file
				 * is no longer needed. If fileName is NULL,
				 * then this field is irrelevant. */
    Tcl_LibraryInitProc *initProc;
				/* Initialization function to call to
				 * incorporate this library into a trusted
				 * interpreter. */
    Tcl_LibraryInitProc *safeInitProc;
				/* Initialization function to call to
				 * incorporate this library into a safe
				 * interpreter (one that will execute
				 * untrusted scripts). NULL means the library
				 * can't be used in unsafe interpreters. */
    Tcl_LibraryUnloadProc *unloadProc;
				/* Finalization function to unload a library
				 * from a trusted interpreter. NULL means that
				 * the library cannot be unloaded. */
    Tcl_LibraryUnloadProc *safeUnloadProc;
				/* Finalization function to unload a library
				 * from a safe interpreter. NULL means that
				 * the library cannot be unloaded. */
    int interpRefCount;		/* How many times the library has been loaded
				 * in trusted interpreters. */
    int safeInterpRefCount;	/* How many times the library has been loaded
				 * in safe interpreters. */
    struct LoadedLibrary *nextPtr;
				/* Next in list of all libraries loaded into
				 * this application process. NULL means end of
				 * list. */
} LoadedLibrary;

/*
 * TCL_THREADS
 * There is a global list of libraries that is anchored at firstLibraryPtr.
 * Access to this list is governed by a mutex.
 */

static LoadedLibrary *firstLibraryPtr = NULL;
				/* First in list of all libraries loaded into
				 * this process. */

TCL_DECLARE_MUTEX(libraryMutex)

/*
 * The following structure represents a particular library that has been
 * incorporated into a particular interpreter (by calling its initialization
 * function). There is a list of these structures for each interpreter, with
 * an AssocData value (key "load") for the interpreter that points to the
 * first library (if any).
 */

typedef struct InterpLibrary {
    LoadedLibrary *libraryPtr;	/* Points to detailed information about
				 * library. */
    struct InterpLibrary *nextPtr;
				/* Next library in this interpreter, or NULL
				 * for end of list. */
} InterpLibrary;

/*
 * Prototypes for functions that are private to this file:
 */

static void	LoadCleanupProc(void *clientData,
		    Tcl_Interp *interp);
static int	IsStatic(LoadedLibrary *libraryPtr);
static int	UnloadLibrary(Tcl_Interp *interp, Tcl_Interp *target,
		    LoadedLibrary *library, int keepLibrary,
		    const char *fullFileName, int interpExiting);

static int
IsStatic(
    LoadedLibrary *libraryPtr)
{
    return (libraryPtr->fileName[0] == '\0');
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_LoadObjCmd --
 *
 *	This function is invoked to process the "load" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_LoadObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Interp *target;
    LoadedLibrary *libraryPtr, *defaultPtr;
    Tcl_DString pfx, tmp, initName, safeInitName;
    Tcl_DString unloadName, safeUnloadName;
    InterpLibrary *ipFirstPtr, *ipPtr;
    int code, namesMatch, filesMatch, offset;
    const char *symbols[2];
    Tcl_LibraryInitProc *initProc;
    const char *p, *fullFileName, *prefix;
    Tcl_LoadHandle loadHandle;
    Tcl_UniChar ch = 0;
    size_t len;
    int flags = 0;
    Tcl_Obj *const *savedobjv = objv;
    static const char *const options[] = {
	"-global",	"-lazy",	"--",	NULL
    };
    enum loadOptionsEnum {
	LOAD_GLOBAL,	LOAD_LAZY,	LOAD_LAST
    } index;

    while (objc > 2) {
	if (TclGetString(objv[1])[0] != '-') {
	    break;
	}
	if (Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	++objv;
	--objc;
	if (LOAD_GLOBAL == index) {
	    flags |= TCL_LOAD_GLOBAL;
	} else if (LOAD_LAZY == index) {
	    flags |= TCL_LOAD_LAZY;
	} else {
	    break;
	}
    }
    if ((objc < 2) || (objc > 4)) {
	Tcl_WrongNumArgs(interp, 1, savedobjv,
		"?-global? ?-lazy? ?--? fileName ?prefix? ?interp?");
	return TCL_ERROR;
    }
    if (Tcl_FSConvertToPathType(interp, objv[1]) != TCL_OK) {
	return TCL_ERROR;
    }
    fullFileName = TclGetString(objv[1]);

    Tcl_DStringInit(&pfx);
    Tcl_DStringInit(&initName);
    Tcl_DStringInit(&safeInitName);
    Tcl_DStringInit(&unloadName);
    Tcl_DStringInit(&safeUnloadName);
    Tcl_DStringInit(&tmp);

    prefix = NULL;
    if (objc >= 3) {
	prefix = TclGetString(objv[2]);
	if (prefix[0] == '\0') {
	    prefix = NULL;
	}
    }
    if ((fullFileName[0] == 0) && (prefix == NULL)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"must specify either file name or prefix", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD", "NOLIBRARY",
		(char *)NULL);
	code = TCL_ERROR;
	goto done;
    }

    /*
     * Figure out which interpreter we're going to load the library into.
     */

    target = interp;
    if (objc == 4) {
	const char *childIntName = TclGetString(objv[3]);

	target = Tcl_GetChild(interp, childIntName);
	if (target == NULL) {
	    code = TCL_ERROR;
	    goto done;
	}
    }

    /*
     * Scan through the libraries that are currently loaded to see if the
     * library we want is already loaded. We'll use a loaded library if it
     * meets any of the following conditions:
     *  - Its name and file match the once we're looking for.
     *  - Its file matches, and we weren't given a name.
     *  - Its name matches, the file name was specified as empty, and there is
     *	  only no statically loaded library with the same prefix.
     */

    Tcl_MutexLock(&libraryMutex);

    defaultPtr = NULL;
    for (libraryPtr = firstLibraryPtr; libraryPtr != NULL; libraryPtr = libraryPtr->nextPtr) {
	if (prefix == NULL) {
	    namesMatch = 0;
	} else {
	    TclDStringClear(&pfx);
	    Tcl_DStringAppend(&pfx, prefix, -1);
	    TclDStringClear(&tmp);
	    Tcl_DStringAppend(&tmp, libraryPtr->prefix, -1);
	    if (strcmp(Tcl_DStringValue(&tmp),
		    Tcl_DStringValue(&pfx)) == 0) {
		namesMatch = 1;
	    } else {
		namesMatch = 0;
	    }
	}
	TclDStringClear(&pfx);

	filesMatch = (strcmp(libraryPtr->fileName, fullFileName) == 0);
	if (filesMatch && (namesMatch || (prefix == NULL))) {
	    break;
	}
	if (namesMatch && (fullFileName[0] == 0)) {
	    defaultPtr = libraryPtr;
	}
	if (filesMatch && !namesMatch && (fullFileName[0] != 0)) {
	    /*
	     * Can't have two different libraries loaded from the same file.
	     */

	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "file \"%s\" is already loaded for prefix \"%s\"",
		    fullFileName, libraryPtr->prefix));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD",
		    "SPLITPERSONALITY", (char *)NULL);
	    code = TCL_ERROR;
	    Tcl_MutexUnlock(&libraryMutex);
	    goto done;
	}
    }
    Tcl_MutexUnlock(&libraryMutex);
    if (libraryPtr == NULL) {
	libraryPtr = defaultPtr;
    }

    /*
     * Scan through the list of libraries already loaded in the target
     * interpreter. If the library we want is already loaded there, then
     * there's nothing for us to do.
     */

    if (libraryPtr != NULL) {
	ipFirstPtr = (InterpLibrary *)Tcl_GetAssocData(target, "tclLoad", NULL);
	for (ipPtr = ipFirstPtr; ipPtr != NULL; ipPtr = ipPtr->nextPtr) {
	    if (ipPtr->libraryPtr == libraryPtr) {
		code = TCL_OK;
		goto done;
	    }
	}
    }

    if (libraryPtr == NULL) {
	/*
	 * The desired file isn't currently loaded, so load it. It's an error
	 * if the desired library is a static one.
	 */

	if (fullFileName[0] == 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "no library with prefix \"%s\" is loaded statically", prefix));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD", "NOTSTATIC",
		    (char *)NULL);
	    code = TCL_ERROR;
	    goto done;
	}

	/*
	 * Figure out the prefix if it wasn't provided explicitly.
	 */

	if (prefix != NULL) {
	    Tcl_DStringAppend(&pfx, prefix, -1);
	} else {
	    Tcl_Obj *splitPtr, *pkgGuessPtr;
	    Tcl_Size pElements;
	    const char *pkgGuess;

	    /*
	     * Threading note - this call used to be protected by a mutex.
	     */

	    /*
	     * The platform-specific code couldn't figure out the prefix.
	     * Make a guess by taking the last element of the file
	     * name, stripping off any leading "lib" and/or "tcl9", and
	     * then using all of the alphabetic and underline characters
	     * that follow that.
	     */

	    splitPtr = Tcl_FSSplitPath(objv[1], &pElements);
	    Tcl_ListObjIndex(NULL, splitPtr, pElements -1, &pkgGuessPtr);
	    pkgGuess = TclGetString(pkgGuessPtr);
	    if ((pkgGuess[0] == 'l') && (pkgGuess[1] == 'i')
		    && (pkgGuess[2] == 'b')) {
		pkgGuess += 3;
	    }
#ifdef __CYGWIN__
	    else if ((pkgGuess[0] == 'c') && (pkgGuess[1] == 'y')
		    && (pkgGuess[2] == 'g')) {
		pkgGuess += 3;
	    }
#endif /* __CYGWIN__ */
	    if (((pkgGuess[0] == 't')
#ifdef MAC_OSX_TCL
		    || (pkgGuess[0] == 'T')
#endif
		    ) && (pkgGuess[1] == 'c')
		    && (pkgGuess[2] == 'l') && (pkgGuess[3] == '9')) {
		pkgGuess += 4;
	    }
	    for (p = pkgGuess; *p != 0; p += offset) {
		offset = TclUtfToUniChar(p, &ch);
		if (!Tcl_UniCharIsWordChar(UCHAR(ch))
			|| Tcl_UniCharIsDigit(UCHAR(ch))) {
		    break;
		}
	    }
	    if (p == pkgGuess) {
		Tcl_DecrRefCount(splitPtr);
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"cannot figure out prefix for %s",
			fullFileName));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD",
			"WHATLIBRARY", (char *)NULL);
		code = TCL_ERROR;
		goto done;
	    }
	    Tcl_DStringAppend(&pfx, pkgGuess, p - pkgGuess);
	    Tcl_DecrRefCount(splitPtr);

	    /*
	     * Fix the capitalization in the prefix so that the first
	     * character is in caps (or title case) but the others are all
	     * lower-case.
	     */

	    Tcl_DStringSetLength(&pfx,
		    Tcl_UtfToTitle(Tcl_DStringValue(&pfx)));

	}

	/*
	 * Compute the names of the two initialization functions, based on the
	 * prefix.
	 */

	TclDStringAppendDString(&initName, &pfx);
	TclDStringAppendLiteral(&initName, "_Init");
	TclDStringAppendDString(&safeInitName, &pfx);
	TclDStringAppendLiteral(&safeInitName, "_SafeInit");
	TclDStringAppendDString(&unloadName, &pfx);
	TclDStringAppendLiteral(&unloadName, "_Unload");
	TclDStringAppendDString(&safeUnloadName, &pfx);
	TclDStringAppendLiteral(&safeUnloadName, "_SafeUnload");

	/*
	 * Call platform-specific code to load the library and find the two
	 * initialization functions.
	 */

	symbols[0] = Tcl_DStringValue(&initName);
	symbols[1] = NULL;

	Tcl_MutexLock(&libraryMutex);
	code = Tcl_LoadFile(interp, objv[1], symbols, flags, &initProc,
		&loadHandle);
	Tcl_MutexUnlock(&libraryMutex);
	if (code != TCL_OK) {
	    goto done;
	}

	/*
	 * Create a new record to describe this library.
	 */

	libraryPtr = (LoadedLibrary *)Tcl_Alloc(sizeof(LoadedLibrary));
	len = strlen(fullFileName) + 1;
	libraryPtr->fileName	   = (char *)Tcl_Alloc(len);
	memcpy(libraryPtr->fileName, fullFileName, len);
	len = Tcl_DStringLength(&pfx) + 1;
	libraryPtr->prefix	   = (char *)Tcl_Alloc(len);
	memcpy(libraryPtr->prefix, Tcl_DStringValue(&pfx), len);
	libraryPtr->loadHandle	   = loadHandle;
	libraryPtr->initProc	   = initProc;
	libraryPtr->safeInitProc	   = (Tcl_LibraryInitProc *)
		Tcl_FindSymbol(interp, loadHandle,
			Tcl_DStringValue(&safeInitName));
	libraryPtr->unloadProc	   = (Tcl_LibraryUnloadProc *)
		Tcl_FindSymbol(interp, loadHandle,
			Tcl_DStringValue(&unloadName));
	libraryPtr->safeUnloadProc	   = (Tcl_LibraryUnloadProc *)
		Tcl_FindSymbol(interp, loadHandle,
			Tcl_DStringValue(&safeUnloadName));
	libraryPtr->interpRefCount	   = 0;
	libraryPtr->safeInterpRefCount = 0;

	Tcl_MutexLock(&libraryMutex);
	libraryPtr->nextPtr		   = firstLibraryPtr;
	firstLibraryPtr		   = libraryPtr;
	Tcl_MutexUnlock(&libraryMutex);

	/*
	 * The Tcl_FindSymbol calls may have left a spurious error message in
	 * the interpreter result.
	 */

	Tcl_ResetResult(interp);
    }

    /*
     * Invoke the library's initialization function (either the normal one or
     * the safe one, depending on whether or not the interpreter is safe).
     */

    if (Tcl_IsSafe(target)) {
	if (libraryPtr->safeInitProc == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "cannot use library in a safe interpreter: no"
		    " %s_SafeInit procedure", libraryPtr->prefix));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD", "UNSAFE",
		    (char *)NULL);
	    code = TCL_ERROR;
	    goto done;
	}
	code = libraryPtr->safeInitProc(target);
    } else {
	if (libraryPtr->initProc == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "cannot attach library to interpreter: no %s_Init procedure",
		    libraryPtr->prefix));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "LOAD", "ENTRYPOINT",
		    (char *)NULL);
	    code = TCL_ERROR;
	    goto done;
	}
	code = libraryPtr->initProc(target);
    }

    /*
     * Test for whether the initialization failed. If so, transfer the error
     * from the target interpreter to the originating one.
     */

    if (code != TCL_OK) {
	Interp *iPtr = (Interp *) target;
	if (iPtr->legacyResult && *(iPtr->legacyResult) && !iPtr->legacyFreeProc) {
	    /*
	     * A call to Tcl_InitStubs() determined the caller extension
	     * Stubs were introduced in Tcl 8.1, so there's only one possible reason.
	     */
	    Tcl_SetObjResult(target, Tcl_NewStringObj("this extension is compiled for Tcl 8.x", -1));
	    iPtr->legacyResult = NULL;
	    iPtr->legacyFreeProc = (void (*) (void))-1;
	}
	Tcl_TransferResult(target, code, interp);
	goto done;
    }

    /*
     * Record the fact that the library has been loaded in the target
     * interpreter.
     *
     * Update the proper reference count.
     */

    Tcl_MutexLock(&libraryMutex);
    if (Tcl_IsSafe(target)) {
	libraryPtr->safeInterpRefCount++;
    } else {
	libraryPtr->interpRefCount++;
    }
    Tcl_MutexUnlock(&libraryMutex);

    /*
     * Refetch ipFirstPtr: loading the library may have introduced additional
     * static libraries at the head of the linked list!
     */

    ipFirstPtr = (InterpLibrary *)Tcl_GetAssocData(target, "tclLoad", NULL);
    ipPtr = (InterpLibrary *)Tcl_Alloc(sizeof(InterpLibrary));
    ipPtr->libraryPtr = libraryPtr;
    ipPtr->nextPtr = ipFirstPtr;
    Tcl_SetAssocData(target, "tclLoad", LoadCleanupProc, ipPtr);

  done:
    Tcl_DStringFree(&pfx);
    Tcl_DStringFree(&initName);
    Tcl_DStringFree(&safeInitName);
    Tcl_DStringFree(&unloadName);
    Tcl_DStringFree(&safeUnloadName);
    Tcl_DStringFree(&tmp);
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_UnloadObjCmd --
 *
 *	Implements the "unload" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_UnloadObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Interp *target;		/* Which interpreter to unload from. */
    LoadedLibrary *libraryPtr;
    Tcl_DString pfx, tmp;
    InterpLibrary *ipFirstPtr, *ipPtr;
    int i, code, complain = 1, keepLibrary = 0;
    const char *fullFileName = "";
    const char *prefix;
    static const char *const options[] = {
	"-nocomplain", "-keeplibrary", "--", NULL
    };
    enum unloadOptionsEnum {
	UNLOAD_NOCOMPLAIN, UNLOAD_KEEPLIB, UNLOAD_LAST
    } index;

    for (i = 1; i < objc; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0,
		&index) != TCL_OK) {
	    fullFileName = TclGetString(objv[i]);
	    if (fullFileName[0] == '-') {
		/*
		 * It looks like the command contains an option so signal an
		 * error
		 */

		return TCL_ERROR;
	    } else {
		/*
		 * This clearly isn't an option; assume it's the filename. We
		 * must clear the error.
		 */

		Tcl_ResetResult(interp);
		break;
	    }
	}
	switch (index) {
	case UNLOAD_NOCOMPLAIN:		/* -nocomplain */
	    complain = 0;
	    break;
	case UNLOAD_KEEPLIB:		/* -keeplibrary */
	    keepLibrary = 1;
	    break;
	case UNLOAD_LAST:		/* -- */
	    i++;
	    goto endOfForLoop;
	default:
	    TCL_UNREACHABLE();
	}
    }
  endOfForLoop:
    if ((objc-i < 1) || (objc-i > 3)) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-switch ...? fileName ?prefix? ?interp?");
	return TCL_ERROR;
    }
    if (Tcl_FSConvertToPathType(interp, objv[i]) != TCL_OK) {
	return TCL_ERROR;
    }

    fullFileName = TclGetString(objv[i]);
    Tcl_DStringInit(&pfx);
    Tcl_DStringInit(&tmp);

    prefix = NULL;
    if (objc - i >= 2) {
	prefix = TclGetString(objv[i+1]);
	if (prefix[0] == '\0') {
	    prefix = NULL;
	}
    }
    if ((fullFileName[0] == 0) && (prefix == NULL)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"must specify either file name or prefix", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "NOLIBRARY",
		(char *)NULL);
	code = TCL_ERROR;
	goto done;
    }

    /*
     * Figure out which interpreter we're going to load the library into.
     */

    target = interp;
    if (objc - i == 3) {
	const char *childIntName = TclGetString(objv[i + 2]);

	target = Tcl_GetChild(interp, childIntName);
	if (target == NULL) {
	    return TCL_ERROR;
	}
    }

    /*
     * Scan through the libraries that are currently loaded to see if the
     * library we want is already loaded. We'll use a loaded library if it
     * meets any of the following conditions:
     *  - Its prefix and file match the once we're looking for.
     *  - Its file matches, and we weren't given a prefix.
     *  - Its prefix matches, the file name was specified as empty, and there is
     *	  no statically loaded library with the same prefix.
     */

    Tcl_MutexLock(&libraryMutex);

    for (libraryPtr = firstLibraryPtr; libraryPtr != NULL; libraryPtr = libraryPtr->nextPtr) {
	int namesMatch, filesMatch;

	if (prefix == NULL) {
	    namesMatch = 0;
	} else {
	    TclDStringClear(&pfx);
	    Tcl_DStringAppend(&pfx, prefix, -1);
	    TclDStringClear(&tmp);
	    Tcl_DStringAppend(&tmp, libraryPtr->prefix, -1);
	    if (strcmp(Tcl_DStringValue(&tmp),
		    Tcl_DStringValue(&pfx)) == 0) {
		namesMatch = 1;
	    } else {
		namesMatch = 0;
	    }
	}
	TclDStringClear(&pfx);

	filesMatch = (strcmp(libraryPtr->fileName, fullFileName) == 0);
	if (filesMatch && (namesMatch || (prefix == NULL))) {
	    break;
	}
	if (filesMatch && !namesMatch && (fullFileName[0] != 0)) {
	    break;
	}
    }
    Tcl_MutexUnlock(&libraryMutex);
    if (fullFileName[0] == 0) {
	/*
	 * It's an error to try unload a static library.
	 */

	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"library with prefix \"%s\" is loaded statically and cannot be unloaded",
		prefix));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "STATIC",
		(char *)NULL);
	code = TCL_ERROR;
	goto done;
    }
    if (libraryPtr == NULL) {
	/*
	 * The DLL pointed by the provided filename has never been loaded.
	 */

	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"file \"%s\" has never been loaded", fullFileName));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "NEVERLOADED",
		(char *)NULL);
	code = TCL_ERROR;
	goto done;
    }

    /*
     * Scan through the list of libraries already loaded in the target
     * interpreter. If the library we want is already loaded there, then we
     * should proceed with unloading.
     */

    code = TCL_ERROR;
    if (libraryPtr != NULL) {
	ipFirstPtr = (InterpLibrary *)Tcl_GetAssocData(target, "tclLoad", NULL);
	for (ipPtr = ipFirstPtr; ipPtr != NULL; ipPtr = ipPtr->nextPtr) {
	    if (ipPtr->libraryPtr == libraryPtr) {
		code = TCL_OK;
		break;
	    }
	}
    }
    if (code != TCL_OK) {
	/*
	 * The library has not been loaded in this interpreter.
	 */

	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"file \"%s\" has never been loaded in this interpreter",
		fullFileName));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "NEVERLOADED",
		(char *)NULL);
	code = TCL_ERROR;
	goto done;
    }

    code = UnloadLibrary(interp, target, libraryPtr, keepLibrary, fullFileName, 0);

  done:
    Tcl_DStringFree(&pfx);
    Tcl_DStringFree(&tmp);
    if (!complain && (code != TCL_OK)) {
	code = TCL_OK;
	Tcl_ResetResult(interp);
    }
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * UnloadLibrary --
 *
 *	Unloads a library from an interpreter, and also from the process if it
 *	is unloadable, i.e. if it provides an "unload" function.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See description.
 *
 *----------------------------------------------------------------------
 */
static int
UnloadLibrary(
    Tcl_Interp *interp,
    Tcl_Interp *target,
    LoadedLibrary *libraryPtr,
    int keepLibrary,
    const char *fullFileName,
    int interpExiting)
{
    int code;
    InterpLibrary *ipFirstPtr, *ipPtr;
    LoadedLibrary *iterLibraryPtr;
    int trustedRefCount = -1, safeRefCount = -1;
    Tcl_LibraryUnloadProc *unloadProc = NULL;

    /*
     * Ensure that the DLL can be unloaded. If it is a trusted interpreter,
     * libraryPtr->unloadProc must not be NULL for the DLL to be unloadable. If
     * the interpreter is a safe one, libraryPtr->safeUnloadProc must be non-NULL.
     */

    if (Tcl_IsSafe(target)) {
	if (libraryPtr->safeUnloadProc == NULL) {
	    if (!interpExiting) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"file \"%s\" cannot be unloaded under a safe interpreter",
			fullFileName));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "CANNOT",
			(char *)NULL);
		code = TCL_ERROR;
		goto done;
	    }
	}
	unloadProc = libraryPtr->safeUnloadProc;
    } else {
	if (libraryPtr->unloadProc == NULL) {
	    if (!interpExiting) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"file \"%s\" cannot be unloaded under a trusted interpreter",
			fullFileName));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "CANNOT",
			(char *)NULL);
		code = TCL_ERROR;
		goto done;
	    }
	}
	unloadProc = libraryPtr->unloadProc;
    }

    /*
     * We are ready to unload the library. First, evaluate the unload
     * function. If this fails, we cannot proceed with unload. Also, we must
     * specify the proper flag to pass to the unload callback.
     * TCL_UNLOAD_DETACH_FROM_INTERPRETER is defined when the callback should
     * only remove itself from the interpreter; the library will be unloaded
     * in a future call of unload. In case the library will be unloaded just
     * after the callback returns, TCL_UNLOAD_DETACH_FROM_PROCESS is passed.
     */

    if (unloadProc == NULL) {
	code = TCL_OK;
    } else {
	code = TCL_UNLOAD_DETACH_FROM_INTERPRETER;
	if (!keepLibrary) {
	    Tcl_MutexLock(&libraryMutex);
	    trustedRefCount = libraryPtr->interpRefCount;
	    safeRefCount = libraryPtr->safeInterpRefCount;
	    Tcl_MutexUnlock(&libraryMutex);

	    if (Tcl_IsSafe(target)) {
		safeRefCount--;
	    } else {
		trustedRefCount--;
	    }

	    if (safeRefCount <= 0 && trustedRefCount <= 0) {
		code = TCL_UNLOAD_DETACH_FROM_PROCESS;
	    }
	}
	code = unloadProc(target, code);
    }

    if (code != TCL_OK) {
	Tcl_TransferResult(target, code, interp);
	goto done;
    }

    /*
     * Remove this library from the interpreter's library cache.
     */

    if (!interpExiting) {
	ipFirstPtr = (InterpLibrary *)Tcl_GetAssocData(target, "tclLoad", NULL);
	if (ipFirstPtr) {
	    ipPtr = ipFirstPtr;
	    if (ipPtr->libraryPtr == libraryPtr) {
		ipFirstPtr = ipFirstPtr->nextPtr;
	    } else {
		InterpLibrary *ipPrevPtr;

		for (ipPrevPtr = ipPtr; ipPtr != NULL;
			ipPrevPtr = ipPtr, ipPtr = ipPtr->nextPtr) {
		    if (ipPtr->libraryPtr == libraryPtr) {
			ipPrevPtr->nextPtr = ipPtr->nextPtr;
			break;
		    }
		}
	    }
	    Tcl_Free(ipPtr);
	    Tcl_SetAssocData(target, "tclLoad", LoadCleanupProc, ipFirstPtr);
	}
    }

    if (IsStatic(libraryPtr)) {
	goto done;
    }

    /*
     * The unload function was called succesfully.
     */

    Tcl_MutexLock(&libraryMutex);
    if (Tcl_IsSafe(target)) {
	libraryPtr->safeInterpRefCount--;

	/*
	 * Do not let counter get negative.
	 */

	if (libraryPtr->safeInterpRefCount < 0) {
	    libraryPtr->safeInterpRefCount = 0;
	}
    } else {
	libraryPtr->interpRefCount--;

	/*
	 * Do not let counter get negative.
	 */

	if (libraryPtr->interpRefCount < 0) {
	    libraryPtr->interpRefCount = 0;
	}
    }
    trustedRefCount = libraryPtr->interpRefCount;
    safeRefCount = libraryPtr->safeInterpRefCount;
    Tcl_MutexUnlock(&libraryMutex);

    code = TCL_OK;
    if (libraryPtr->safeInterpRefCount <= 0 && libraryPtr->interpRefCount <= 0
	    && (unloadProc != NULL) && !keepLibrary) {
	/*
	 * Unload the shared library from the application memory...
	 */

#if defined(TCL_UNLOAD_DLLS) || defined(_WIN32)
	/*
	 * Some Unix dlls are poorly behaved - registering things like atexit
	 * calls that can't be unregistered. If you unload such dlls, you get
	 * a core on exit because it wants to call a function in the dll after
	 * it's been unloaded.
	 */

	if (!IsStatic(libraryPtr)) {
	    Tcl_MutexLock(&libraryMutex);
	    if (Tcl_FSUnloadFile(interp, libraryPtr->loadHandle) == TCL_OK) {
		/*
		 * Remove this library from the loaded library cache.
		 */

		iterLibraryPtr = libraryPtr;
		if (iterLibraryPtr == firstLibraryPtr) {
		    firstLibraryPtr = libraryPtr->nextPtr;
		} else {
		    for (libraryPtr = firstLibraryPtr; libraryPtr != NULL;
			    libraryPtr = libraryPtr->nextPtr) {
			if (libraryPtr->nextPtr == iterLibraryPtr) {
			    libraryPtr->nextPtr = iterLibraryPtr->nextPtr;
			    break;
			}
		    }
		}

		Tcl_Free(iterLibraryPtr->fileName);
		Tcl_Free(iterLibraryPtr->prefix);
		Tcl_Free(iterLibraryPtr);
		Tcl_MutexUnlock(&libraryMutex);
	    } else {
		code = TCL_ERROR;
	    }
	}
#else
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"file \"%s\" cannot be unloaded: unloading disabled",
		fullFileName));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "UNLOAD", "DISABLED",
		NULL);
	code = TCL_ERROR;
#endif
    }

  done:
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_StaticLibrary --
 *
 *	This function is invoked to indicate that a particular library has
 *	been linked statically with an application.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Once this function completes, the library becomes loadable via the
 *	"load" command with an empty file name.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_StaticLibrary(
    Tcl_Interp *interp,		/* If not NULL, it means that the library has
				 * already been loaded into the given
				 * interpreter by calling the appropriate init
				 * proc. */
    const char *prefix,	/* Prefix. */
    Tcl_LibraryInitProc *initProc,
				/* Function to call to incorporate this
				 * library into a trusted interpreter. */
    Tcl_LibraryInitProc *safeInitProc)
				/* Function to call to incorporate this
				 * library into a safe interpreter (one that
				 * will execute untrusted scripts). NULL means
				 * the library can't be used in safe
				 * interpreters. */
{
    LoadedLibrary *libraryPtr;
    InterpLibrary *ipPtr, *ipFirstPtr;

    /*
     * Check to see if someone else has already reported this library as
     * statically loaded in the process.
     */

    Tcl_MutexLock(&libraryMutex);
    for (libraryPtr = firstLibraryPtr; libraryPtr != NULL; libraryPtr = libraryPtr->nextPtr) {
	if ((libraryPtr->initProc == initProc)
		&& (libraryPtr->safeInitProc == safeInitProc)
		&& (strcmp(libraryPtr->prefix, prefix) == 0)) {
	    break;
	}
    }
    Tcl_MutexUnlock(&libraryMutex);

    /*
     * If the library is not yet recorded as being loaded statically, add it
     * to the list now.
     */

    if (libraryPtr == NULL) {
	libraryPtr = (LoadedLibrary *)Tcl_Alloc(sizeof(LoadedLibrary));
	libraryPtr->fileName	= (char *)Tcl_Alloc(1);
	libraryPtr->fileName[0]	= 0;
	libraryPtr->prefix	= (char *)Tcl_Alloc(strlen(prefix) + 1);
	strcpy(libraryPtr->prefix, prefix);
	libraryPtr->loadHandle	= NULL;
	libraryPtr->initProc	= initProc;
	libraryPtr->safeInitProc	= safeInitProc;
	libraryPtr->unloadProc = NULL;
	libraryPtr->safeUnloadProc = NULL;
	Tcl_MutexLock(&libraryMutex);
	libraryPtr->nextPtr		= firstLibraryPtr;
	firstLibraryPtr		= libraryPtr;
	Tcl_MutexUnlock(&libraryMutex);
    }

    if (interp != NULL) {

	/*
	 * If we're loading the library into an interpreter, determine whether
	 * it's already loaded.
	 */

	ipFirstPtr = (InterpLibrary *)Tcl_GetAssocData(interp, "tclLoad", NULL);
	for (ipPtr = ipFirstPtr; ipPtr != NULL; ipPtr = ipPtr->nextPtr) {
	    if (ipPtr->libraryPtr == libraryPtr) {
		return;
	    }
	}

	/*
	 * Library isn't loaded in the current interp yet. Mark it as now being
	 * loaded.
	 */

	ipPtr = (InterpLibrary *)Tcl_Alloc(sizeof(InterpLibrary));
	ipPtr->libraryPtr = libraryPtr;
	ipPtr->nextPtr = ipFirstPtr;
	Tcl_SetAssocData(interp, "tclLoad", LoadCleanupProc, ipPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetLoadedLibraries --
 *
 *	This function returns information about all of the files that are
 *	loaded (either in a particular interpreter, or for all interpreters).
 *
 * Results:
 *	The return value is a standard Tcl completion code. If successful, a
 *	list of lists is placed in the interp's result. Each sublist
 *	corresponds to one loaded file; its first element is the name of the
 *	file (or an empty string for something that's statically loaded) and
 *	the second element is the prefix of the library in that file.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclGetLoadedLibraries(
    Tcl_Interp *interp,		/* Interpreter in which to return information
				 * or error message. */
    const char *targetName,	/* Name of target interpreter or NULL. If
				 * NULL, return info about all interps;
				 * otherwise, just return info about this
				 * interpreter. */
    const char *prefix)		/* Prefix or NULL. If NULL, return info
				 * for all prefixes. */
{
    Tcl_Interp *target;
    LoadedLibrary *libraryPtr;
    InterpLibrary *ipPtr;
    Tcl_Obj *resultObj, *pkgDesc[2];

    if (targetName == NULL) {
	TclNewObj(resultObj);
	Tcl_MutexLock(&libraryMutex);
	for (libraryPtr = firstLibraryPtr; libraryPtr != NULL;
		libraryPtr = libraryPtr->nextPtr) {
	    pkgDesc[0] = Tcl_NewStringObj(libraryPtr->fileName, -1);
	    pkgDesc[1] = Tcl_NewStringObj(libraryPtr->prefix, -1);
	    Tcl_ListObjAppendElement(NULL, resultObj,
		    Tcl_NewListObj(2, pkgDesc));
	}
	Tcl_MutexUnlock(&libraryMutex);
	Tcl_SetObjResult(interp, resultObj);
	return TCL_OK;
    }

    target = Tcl_GetChild(interp, targetName);
    if (target == NULL) {
	return TCL_ERROR;
    }
    ipPtr = (InterpLibrary *)Tcl_GetAssocData(target, "tclLoad", NULL);

    /*
     * Return information about all of the available libraries.
     */
    if (prefix) {
	resultObj = NULL;

	for (; ipPtr != NULL; ipPtr = ipPtr->nextPtr) {
	    libraryPtr = ipPtr->libraryPtr;

	    if (!strcmp(prefix, libraryPtr->prefix)) {
		resultObj = Tcl_NewStringObj(libraryPtr->fileName, -1);
		break;
	    }
	}

	if (resultObj) {
	    Tcl_SetObjResult(interp, resultObj);
	}
	return TCL_OK;
    }

    /*
     * Return information about only the libraries that are loaded in a given
     * interpreter.
     */

    TclNewObj(resultObj);
    for (; ipPtr != NULL; ipPtr = ipPtr->nextPtr) {
	libraryPtr = ipPtr->libraryPtr;
	pkgDesc[0] = Tcl_NewStringObj(libraryPtr->fileName, -1);
	pkgDesc[1] = Tcl_NewStringObj(libraryPtr->prefix, -1);
	Tcl_ListObjAppendElement(NULL, resultObj, Tcl_NewListObj(2, pkgDesc));
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * LoadCleanupProc --
 *
 *	This function is called to delete all of the InterpLibrary structures
 *	for an interpreter when the interpreter is deleted. It gets invoked
 *	via the Tcl AssocData mechanism.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Storage for all of the InterpLibrary functions for interp get deleted.
 *
 *----------------------------------------------------------------------
 */

static void
LoadCleanupProc(
    void *clientData,		/* Pointer to first InterpLibrary structure
				 * for interp. */
    Tcl_Interp *interp)
{
    InterpLibrary *ipPtr = (InterpLibrary *)clientData, *nextPtr;
    LoadedLibrary *libraryPtr;

    while (ipPtr) {
	libraryPtr = ipPtr->libraryPtr;
	UnloadLibrary(interp, interp, libraryPtr, 0, "", 1);
	/* UnloadLibrary doesn't free it by interp delete, so do it here and
	 * repeat for next. */
	nextPtr = ipPtr->nextPtr;
	Tcl_Free(ipPtr);
	ipPtr = nextPtr;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeLoad --
 *
 *	This function is invoked just before the application exits. It frees
 *	all of the LoadedLibrary structures.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory is freed.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeLoad(void)
{
    LoadedLibrary *libraryPtr;

    /*
     * No synchronization here because there should just be one thread alive
     * at this point. Logically, libraryMutex should be grabbed at this point,
     * but the Mutexes get finalized before the call to this routine. The only
     * subsystem left alive at this point is the memory allocator.
     */

    while (firstLibraryPtr != NULL) {
	libraryPtr = firstLibraryPtr;
	firstLibraryPtr = libraryPtr->nextPtr;

#if defined(TCL_UNLOAD_DLLS) || defined(_WIN32)
	/*
	 * Some Unix dlls are poorly behaved - registering things like atexit
	 * calls that can't be unregistered. If you unload such dlls, you get
	 * a core on exit because it wants to call a function in the dll after
	 * it has been unloaded.
	 */

	if (!IsStatic(libraryPtr)) {
	    Tcl_FSUnloadFile(NULL, libraryPtr->loadHandle);
	}
#endif

	Tcl_Free(libraryPtr->fileName);
	Tcl_Free(libraryPtr->prefix);
	Tcl_Free(libraryPtr);
    }
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

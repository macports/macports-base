/*
 * tclPkg.c --
 *
 *	This file implements package and version control for Tcl via the
 *	"package" command and a few C APIs.
 *
 * Copyright (c) 1996 Sun Microsystems, Inc.
 * Copyright (c) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * TIP #268.
 * Heavily rewritten to handle the extend version numbers, and extended
 * package requirements.
 */

#include "tclInt.h"

/*
 * Each invocation of the "package ifneeded" command creates a structure of
 * the following type, which is used to load the package into the interpreter
 * if it is requested with a "package require" command.
 */

typedef struct PkgAvail {
    char *version;		/* Version string; malloc'ed. */
    char *script;		/* Script to invoke to provide this version of
				 * the package. Malloc'ed and protected by
				 * Tcl_Preserve and Tcl_Release. */
    struct PkgAvail *nextPtr;	/* Next in list of available versions of the
				 * same package. */
} PkgAvail;

/*
 * For each package that is known in any way to an interpreter, there is one
 * record of the following type. These records are stored in the
 * "packageTable" hash table in the interpreter, keyed by package name such as
 * "Tk" (no version number).
 */

typedef struct Package {
    char *version;		/* Version that has been supplied in this
				 * interpreter via "package provide"
				 * (malloc'ed). NULL means the package doesn't
				 * exist in this interpreter yet. */
    PkgAvail *availPtr;		/* First in list of all available versions of
				 * this package. */
    ClientData clientData;	/* Client data. */
} Package;

/*
 * Prototypes for functions defined in this file:
 */

static int		CheckVersionAndConvert(Tcl_Interp *interp,
			    const char *string, char **internal, int *stable);
static int		CompareVersions(char *v1i, char *v2i,
			    int *isMajorPtr);
static int		CheckRequirement(Tcl_Interp *interp,
			    const char *string);
static int		CheckAllRequirements(Tcl_Interp *interp, int reqc,
			    Tcl_Obj *const reqv[]);
static int		RequirementSatisfied(char *havei, const char *req);
static int		SomeRequirementSatisfied(char *havei, int reqc,
			    Tcl_Obj *const reqv[]);
static void		AddRequirementsToResult(Tcl_Interp *interp, int reqc,
			    Tcl_Obj *const reqv[]);
static void		AddRequirementsToDString(Tcl_DString *dstring,
			    int reqc, Tcl_Obj *const reqv[]);
static Package *	FindPackage(Tcl_Interp *interp, const char *name);
static const char *	PkgRequireCore(Tcl_Interp *interp, const char *name,
			    int reqc, Tcl_Obj *const reqv[],
			    ClientData *clientDataPtr);

/*
 * Helper macros.
 */

#define DupBlock(v,s,len) \
    ((v) = ckalloc(len), memcpy((v),(s),(len)))
#define DupString(v,s) \
    do { \
	unsigned local__len = (unsigned) (strlen(s) + 1); \
	DupBlock((v),(s),local__len); \
    } while (0)

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PkgProvide / Tcl_PkgProvideEx --
 *
 *	This function is invoked to declare that a particular version of a
 *	particular package is now present in an interpreter. There must not be
 *	any other version of this package already provided in the interpreter.
 *
 * Results:
 *	Normally returns TCL_OK; if there is already another version of the
 *	package loaded then TCL_ERROR is returned and an error message is left
 *	in the interp's result.
 *
 * Side effects:
 *	The interpreter remembers that this package is available, so that no
 *	other version of the package may be provided for the interpreter.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_PkgProvide
int
Tcl_PkgProvide(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of package. */
    const char *version)	/* Version string for package. */
{
    return Tcl_PkgProvideEx(interp, name, version, NULL);
}

int
Tcl_PkgProvideEx(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of package. */
    const char *version,	/* Version string for package. */
    ClientData clientData)	/* clientdata for this package (normally used
				 * for C callback function table) */
{
    Package *pkgPtr;
    char *pvi, *vi;
    int res;

    pkgPtr = FindPackage(interp, name);
    if (pkgPtr->version == NULL) {
	DupString(pkgPtr->version, version);
	pkgPtr->clientData = clientData;
	return TCL_OK;
    }

    if (CheckVersionAndConvert(interp, pkgPtr->version, &pvi,
	    NULL) != TCL_OK) {
	return TCL_ERROR;
    } else if (CheckVersionAndConvert(interp, version, &vi, NULL) != TCL_OK) {
	ckfree(pvi);
	return TCL_ERROR;
    }

    res = CompareVersions(pvi, vi, NULL);
    ckfree(pvi);
    ckfree(vi);

    if (res == 0) {
	if (clientData != NULL) {
	    pkgPtr->clientData = clientData;
	}
	return TCL_OK;
    }
    Tcl_AppendResult(interp, "conflicting versions provided for package \"",
	    name, "\": ", pkgPtr->version, ", then ", version, NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PkgRequire / Tcl_PkgRequireEx / Tcl_PkgRequireProc --
 *
 *	This function is called by code that depends on a particular version
 *	of a particular package. If the package is not already provided in the
 *	interpreter, this function invokes a Tcl script to provide it. If the
 *	package is already provided, this function makes sure that the
 *	caller's needs don't conflict with the version that is present.
 *
 * Results:
 *	If successful, returns the version string for the currently provided
 *	version of the package, which may be different from the "version"
 *	argument. If the caller's requirements cannot be met (e.g. the version
 *	requested conflicts with a currently provided version, or the required
 *	version cannot be found, or the script to provide the required version
 *	generates an error), NULL is returned and an error message is left in
 *	the interp's result.
 *
 * Side effects:
 *	The script from some previous "package ifneeded" command may be
 *	invoked to provide the package.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_PkgRequire
const char *
Tcl_PkgRequire(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    const char *version,	/* Version string for desired version; NULL
				 * means use the latest version available. */
    int exact)			/* Non-zero means that only the particular
				 * version given is acceptable. Zero means use
				 * the latest compatible version. */
{
    return Tcl_PkgRequireEx(interp, name, version, exact, NULL);
}

const char *
Tcl_PkgRequireEx(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    const char *version,	/* Version string for desired version; NULL
				 * means use the latest version available. */
    int exact,			/* Non-zero means that only the particular
				 * version given is acceptable. Zero means use
				 * the latest compatible version. */
    ClientData *clientDataPtr)	/* Used to return the client data for this
				 * package. If it is NULL then the client data
				 * is not returned. This is unchanged if this
				 * call fails for any reason. */
{
    Tcl_Obj *ov;
    const char *result = NULL;

    /*
     * If an attempt is being made to load this into a standalone executable
     * on a platform where backlinking is not supported then this must be a
     * shared version of Tcl (Otherwise the load would have failed). Detect
     * this situation by checking that this library has been correctly
     * initialised. If it has not been then return immediately as nothing will
     * work.
     */

    if (tclEmptyStringRep == NULL) {
	/*
	 * OK, so what's going on here?
	 *
	 * First, what are we doing? We are performing a check on behalf of
	 * one particular caller, Tcl_InitStubs(). When a package is stub-
	 * enabled, it is statically linked to libtclstub.a, which contains a
	 * copy of Tcl_InitStubs(). When a stub-enabled package is loaded, its
	 * *_Init() function is supposed to call Tcl_InitStubs() before
	 * calling any other functions in the Tcl library. The first Tcl
	 * function called by Tcl_InitStubs() through the stub table is
	 * Tcl_PkgRequireEx(), so this code right here is the first code that
	 * is part of the original Tcl library in the executable that gets
	 * executed on behalf of a newly loaded stub-enabled package.
	 *
	 * One easy error for the developer/builder of a stub-enabled package
	 * to make is to forget to define USE_TCL_STUBS when compiling the
	 * package. When that happens, the package will contain symbols that
	 * are references to the Tcl library, rather than function pointers
	 * referencing the stub table. On platforms that lack backlinking,
	 * those unresolved references may cause the loading of the package to
	 * also load a second copy of the Tcl library, leading to all kinds of
	 * trouble. We would like to catch that error and report a useful
	 * message back to the user. That's what we're doing.
	 *
	 * Second, how does this work? If we reach this point, then the global
	 * variable tclEmptyStringRep has the value NULL. Compare that with
	 * the definition of tclEmptyStringRep near the top of the file
	 * generic/tclObj.c. It clearly should not have the value NULL; it
	 * should point to the char tclEmptyString. If we see it having the
	 * value NULL, then somehow we are seeing a Tcl library that isn't
	 * completely initialized, and that's an indicator for the error
	 * condition described above. (Further explanation is welcome.)
	 *
	 * Third, so what do we do about it? This situation indicates the
	 * package we just loaded wasn't properly compiled to be stub-enabled,
	 * yet it thinks it is stub-enabled (it called Tcl_InitStubs()). We
	 * want to report that the package just loaded is broken, so we want
	 * to place an error message in the interpreter result and return NULL
	 * to indicate failure to Tcl_InitStubs() so that it will also fail.
	 * (Further explanation why we don't want to Tcl_Panic() is welcome.
	 * After all, two Tcl libraries can't be a good thing!)
	 *
	 * Trouble is that's going to be tricky. We're now using a Tcl library
	 * that's not fully initialized. In particular, it doesn't have a
	 * proper value for tclEmptyStringRep. The Tcl_Obj system heavily
	 * depends on the value of tclEmptyStringRep and all of Tcl depends
	 * (increasingly) on the Tcl_Obj system, we need to correct that flaw
	 * before making the calls to set the interpreter result to the error
	 * message. That's the only flaw corrected; other problems with
	 * initialization of the Tcl library are not remedied, so be very
	 * careful about adding any other calls here without checking how they
	 * behave when initialization is incomplete.
	 */

	tclEmptyStringRep = &tclEmptyString;
	Tcl_AppendResult(interp, "Cannot load package \"", name,
		"\" in standalone executable: This package is not "
		"compiled with stub support", NULL);
	return NULL;
    }

    /*
     * Translate between old and new API, and defer to the new function.
     */

    if (version == NULL) {
	result = PkgRequireCore(interp, name, 0, NULL, clientDataPtr);
    } else {
	if (exact && TCL_OK
		!= CheckVersionAndConvert(interp, version, NULL, NULL)) {
	    return NULL;
	}
	ov = Tcl_NewStringObj(version, -1);
	if (exact) {
	    Tcl_AppendStringsToObj(ov, "-", version, NULL);
	}
	Tcl_IncrRefCount(ov);
	result = PkgRequireCore(interp, name, 1, &ov, clientDataPtr);
	TclDecrRefCount(ov);
    }

    return result;
}

int
Tcl_PkgRequireProc(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    int reqc,			/* Requirements constraining the desired
				 * version. */
    Tcl_Obj *const reqv[],	/* 0 means to use the latest version
				 * available. */
    ClientData *clientDataPtr)
{
    const char *result =
	    PkgRequireCore(interp, name, reqc, reqv, clientDataPtr);

    if (result == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(result, -1));
    return TCL_OK;
}

static const char *
PkgRequireCore(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    int reqc,			/* Requirements constraining the desired
				 * version. */
    Tcl_Obj *const reqv[],	/* 0 means to use the latest version
				 * available. */
    ClientData *clientDataPtr)
{
    Interp *iPtr = (Interp *) interp;
    Package *pkgPtr;
    PkgAvail *availPtr, *bestPtr, *bestStablePtr;
    char *availVersion, *bestVersion;
				/* Internal rep. of versions */
    int availStable, code, satisfies, pass;
    char *script, *pkgVersionI;
    Tcl_DString command;

    if (TCL_OK != CheckAllRequirements(interp, reqc, reqv)) {
	return NULL;
    }

    /*
     * It can take up to three passes to find the package: one pass to run the
     * "package unknown" script, one to run the "package ifneeded" script for
     * a specific version, and a final pass to lookup the package loaded by
     * the "package ifneeded" script.
     */

    for (pass=1 ;; pass++) {
	pkgPtr = FindPackage(interp, name);
	if (pkgPtr->version != NULL) {
	    break;
	}

	/*
	 * Check whether we're already attempting to load some version of this
	 * package (circular dependency detection).
	 */

	if (pkgPtr->clientData != NULL) {
	    Tcl_AppendResult(interp, "circular package dependency: "
		    "attempt to provide ", name, " ",
		    (char *) pkgPtr->clientData, " requires ", name, NULL);
	    AddRequirementsToResult(interp, reqc, reqv);
	    return NULL;
	}

	/*
	 * The package isn't yet present. Search the list of available
	 * versions and invoke the script for the best available version. We
	 * are actually locating the best, and the best stable version. One of
	 * them is then chosen based on the selection mode.
	 */

	bestPtr = NULL;
	bestStablePtr = NULL;
	bestVersion = NULL;

	for (availPtr = pkgPtr->availPtr; availPtr != NULL;
		availPtr = availPtr->nextPtr) {
	    if (CheckVersionAndConvert(interp, availPtr->version,
		    &availVersion, &availStable) != TCL_OK) {
		/*
		 * The provided version number has invalid syntax. This
		 * should not happen. This should have been caught by the
		 * 'package ifneeded' registering the package.
		 */

		continue;
	    }

	    if (bestPtr != NULL) {
		int res = CompareVersions(availVersion, bestVersion, NULL);

		/*
		 * Note: Use internal reps!
		 */

		if (res <= 0) {
		    /*
		     * The version of the package sought is not as good as the
		     * currently selected version. Ignore it.
		     */

		    ckfree(availVersion);
		    availVersion = NULL;
		    continue;
		}
	    }

	    /* We have found a version which is better than our max. */

	    if (reqc > 0) {
		/* Check satisfaction of requirements. */

		satisfies = SomeRequirementSatisfied(availVersion, reqc, reqv);
		if (!satisfies) {
		    ckfree(availVersion);
		    availVersion = NULL;
		    continue;
		}
	    }

	    bestPtr = availPtr;

	    if (bestVersion != NULL) {
		ckfree(bestVersion);
	    }
	    bestVersion = availVersion;

	    /*
	     * If this new best version is stable then it also has to be
	     * better than the max stable version found so far.
	     */

	    if (availStable) {
		bestStablePtr = availPtr;
	    }
	}

	if (bestVersion != NULL) {
	    ckfree(bestVersion);
	}

	/*
	 * Now choose a version among the two best. For 'latest' we simply
	 * take (actually keep) the best. For 'stable' we take the best
	 * stable, if there is any, or the best if there is nothing stable.
	 */

	if ((iPtr->packagePrefer == PKG_PREFER_STABLE)
		&& (bestStablePtr != NULL)) {
	    bestPtr = bestStablePtr;
	}

	if (bestPtr != NULL) {
	    /*
	     * We found an ifneeded script for the package. Be careful while
	     * executing it: this could cause reentrancy, so (a) protect the
	     * script itself from deletion and (b) don't assume that bestPtr
	     * will still exist when the script completes.
	     */

	    const char *versionToProvide = bestPtr->version;
	    script = bestPtr->script;

	    pkgPtr->clientData = (ClientData) versionToProvide;
	    Tcl_Preserve((ClientData) script);
	    Tcl_Preserve((ClientData) versionToProvide);
	    code = Tcl_EvalEx(interp, script, -1, TCL_EVAL_GLOBAL);
	    Tcl_Release((ClientData) script);

	    pkgPtr = FindPackage(interp, name);
	    if (code == TCL_OK) {
		Tcl_ResetResult(interp);
		if (pkgPtr->version == NULL) {
		    code = TCL_ERROR;
		    Tcl_AppendResult(interp, "attempt to provide package ",
			    name, " ", versionToProvide,
			    " failed: no version of package ", name,
			    " provided", NULL);
		} else {
		    char *pvi, *vi;

		    if (CheckVersionAndConvert(interp, pkgPtr->version, &pvi,
			    NULL) != TCL_OK) {
			code = TCL_ERROR;
		    } else if (CheckVersionAndConvert(interp,
			    versionToProvide, &vi, NULL) != TCL_OK) {
			ckfree(pvi);
			code = TCL_ERROR;
		    } else {
			int res = CompareVersions(pvi, vi, NULL);

			ckfree(pvi);
			ckfree(vi);
			if (res != 0) {
			    code = TCL_ERROR;
			    Tcl_AppendResult(interp,
				    "attempt to provide package ", name, " ",
				    versionToProvide, " failed: package ",
				    name, " ", pkgPtr->version,
				    " provided instead", NULL);
			}
		    }
		}
	    } else if (code != TCL_ERROR) {
		Tcl_Obj *codePtr = Tcl_NewIntObj(code);

		Tcl_ResetResult(interp);
		Tcl_AppendResult(interp, "attempt to provide package ", name,
			" ", versionToProvide, " failed: bad return code: ",
			TclGetString(codePtr), NULL);
		TclDecrRefCount(codePtr);
		code = TCL_ERROR;
	    }

	    if (code == TCL_ERROR) {
		Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
			"\n    (\"package ifneeded %s %s\" script)",
			name, versionToProvide));
	    }
	    Tcl_Release((ClientData) versionToProvide);

	    if (code != TCL_OK) {
		/*
		 * Take a non-TCL_OK code from the script as an indication the
		 * package wasn't loaded properly, so the package system
		 * should not remember an improper load.
		 *
		 * This is consistent with our returning NULL. If we're not
		 * willing to tell our caller we got a particular version, we
		 * shouldn't store that version for telling future callers
		 * either.
		 */

		if (pkgPtr->version != NULL) {
		    ckfree(pkgPtr->version);
		    pkgPtr->version = NULL;
		}
		pkgPtr->clientData = NULL;
		return NULL;
	    }

	    break;
	}

	/*
	 * The package is not in the database. If there is a "package unknown"
	 * command, invoke it (but only on the first pass; after that, we
	 * should not get here in the first place).
	 */

	if (pass > 1) {
	    break;
	}

	script = ((Interp *) interp)->packageUnknown;
	if (script != NULL) {
	    Tcl_DStringInit(&command);
	    Tcl_DStringAppend(&command, script, -1);
	    Tcl_DStringAppendElement(&command, name);
	    AddRequirementsToDString(&command, reqc, reqv);

	    code = Tcl_EvalEx(interp, Tcl_DStringValue(&command),
		    Tcl_DStringLength(&command), TCL_EVAL_GLOBAL);
	    Tcl_DStringFree(&command);

	    if ((code != TCL_OK) && (code != TCL_ERROR)) {
		Tcl_Obj *codePtr = Tcl_NewIntObj(code);
		Tcl_ResetResult(interp);
		Tcl_AppendResult(interp, "bad return code: ",
			TclGetString(codePtr), NULL);
		Tcl_DecrRefCount(codePtr);
		code = TCL_ERROR;
	    }
	    if (code == TCL_ERROR) {
		Tcl_AddErrorInfo(interp,
			"\n    (\"package unknown\" script)");
		return NULL;
	    }
	    Tcl_ResetResult(interp);
	}
    }

    if (pkgPtr->version == NULL) {
	Tcl_AppendResult(interp, "can't find package ", name, NULL);
	AddRequirementsToResult(interp, reqc, reqv);
	return NULL;
    }

    /*
     * At this point we know that the package is present. Make sure that the
     * provided version meets the current requirements.
     */

    if (reqc == 0) {
	satisfies = 1;
    } else {
	CheckVersionAndConvert(interp, pkgPtr->version, &pkgVersionI, NULL);
	satisfies = SomeRequirementSatisfied(pkgVersionI, reqc, reqv);

	ckfree(pkgVersionI);
    }

    if (satisfies) {
	if (clientDataPtr) {
	    *clientDataPtr = pkgPtr->clientData;
	}
	return pkgPtr->version;
    }

    Tcl_AppendResult(interp, "version conflict for package \"", name,
	    "\": have ", pkgPtr->version, ", need", NULL);
    AddRequirementsToResult(interp, reqc, reqv);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PkgPresent / Tcl_PkgPresentEx --
 *
 *	Checks to see whether the specified package is present. If it is not
 *	then no additional action is taken.
 *
 * Results:
 *	If successful, returns the version string for the currently provided
 *	version of the package, which may be different from the "version"
 *	argument. If the caller's requirements cannot be met (e.g. the version
 *	requested conflicts with a currently provided version), NULL is
 *	returned and an error message is left in interp->result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_PkgPresent
const char *
Tcl_PkgPresent(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    const char *version,	/* Version string for desired version; NULL
				 * means use the latest version available. */
    int exact)			/* Non-zero means that only the particular
				 * version given is acceptable. Zero means use
				 * the latest compatible version. */
{
    return Tcl_PkgPresentEx(interp, name, version, exact, NULL);
}

const char *
Tcl_PkgPresentEx(
    Tcl_Interp *interp,		/* Interpreter in which package is now
				 * available. */
    const char *name,		/* Name of desired package. */
    const char *version,	/* Version string for desired version; NULL
				 * means use the latest version available. */
    int exact,			/* Non-zero means that only the particular
				 * version given is acceptable. Zero means use
				 * the latest compatible version. */
    ClientData *clientDataPtr)	/* Used to return the client data for this
				 * package. If it is NULL then the client data
				 * is not returned. This is unchanged if this
				 * call fails for any reason. */
{
    Interp *iPtr = (Interp *) interp;
    Tcl_HashEntry *hPtr;
    Package *pkgPtr;

    hPtr = Tcl_FindHashEntry(&iPtr->packageTable, name);
    if (hPtr) {
	pkgPtr = Tcl_GetHashValue(hPtr);
	if (pkgPtr->version != NULL) {
	    /*
	     * At this point we know that the package is present. Make sure
	     * that the provided version meets the current requirement by
	     * calling Tcl_PkgRequireEx() to check for us.
	     */

	    const char *foundVersion = Tcl_PkgRequireEx(interp, name, version,
		    exact, clientDataPtr);

	    if (foundVersion == NULL) {
		Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "PACKAGE", name,
			NULL);
	    }
	    return foundVersion;
	}
    }

    if (version != NULL) {
	Tcl_AppendResult(interp, "package ", name, " ", version,
		" is not present", NULL);
    } else {
	Tcl_AppendResult(interp, "package ", name, " is not present", NULL);
    }
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "PACKAGE", name, NULL);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PackageObjCmd --
 *
 *	This function is invoked to process the "package" Tcl command. See the
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

	/* ARGSUSED */
int
Tcl_PackageObjCmd(
    ClientData dummy,		/* Not used. */
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    static const char *pkgOptions[] = {
	"forget",  "ifneeded", "names",   "prefer",   "present",
	"provide", "require",  "unknown", "vcompare", "versions",
	"vsatisfies", NULL
    };
    enum pkgOptions {
	PKG_FORGET,  PKG_IFNEEDED, PKG_NAMES,   PKG_PREFER,   PKG_PRESENT,
	PKG_PROVIDE, PKG_REQUIRE,  PKG_UNKNOWN, PKG_VCOMPARE, PKG_VERSIONS,
	PKG_VSATISFIES
    };
    Interp *iPtr = (Interp *) interp;
    int optionIndex, exact, i, satisfies;
    PkgAvail *availPtr, *prevPtr;
    Package *pkgPtr;
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    Tcl_HashTable *tablePtr;
    const char *version;
    char *argv2, *argv3, *argv4, *iva = NULL, *ivb = NULL;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], pkgOptions, "option", 0,
	    &optionIndex) != TCL_OK) {
	return TCL_ERROR;
    }
    switch ((enum pkgOptions) optionIndex) {
    case PKG_FORGET: {
	char *keyString;

	for (i = 2; i < objc; i++) {
	    keyString = TclGetString(objv[i]);
	    hPtr = Tcl_FindHashEntry(&iPtr->packageTable, keyString);
	    if (hPtr == NULL) {
		continue;
	    }
	    pkgPtr = Tcl_GetHashValue(hPtr);
	    Tcl_DeleteHashEntry(hPtr);
	    if (pkgPtr->version != NULL) {
		ckfree(pkgPtr->version);
	    }
	    while (pkgPtr->availPtr != NULL) {
		availPtr = pkgPtr->availPtr;
		pkgPtr->availPtr = availPtr->nextPtr;
		Tcl_EventuallyFree((ClientData)availPtr->version, TCL_DYNAMIC);
		Tcl_EventuallyFree((ClientData)availPtr->script, TCL_DYNAMIC);
		ckfree((char *) availPtr);
	    }
	    ckfree((char *) pkgPtr);
	}
	break;
    }
    case PKG_IFNEEDED: {
	int length, res;
	char *argv3i, *avi;

	if ((objc != 4) && (objc != 5)) {
	    Tcl_WrongNumArgs(interp, 2, objv, "package version ?script?");
	    return TCL_ERROR;
	}
	argv3 = TclGetString(objv[3]);
	if (CheckVersionAndConvert(interp, argv3, &argv3i, NULL) != TCL_OK) {
	    return TCL_ERROR;
	}
	argv2 = TclGetString(objv[2]);
	if (objc == 4) {
	    hPtr = Tcl_FindHashEntry(&iPtr->packageTable, argv2);
	    if (hPtr == NULL) {
		ckfree(argv3i);
		return TCL_OK;
	    }
	    pkgPtr = Tcl_GetHashValue(hPtr);
	} else {
	    pkgPtr = FindPackage(interp, argv2);
	}
	argv3 = Tcl_GetStringFromObj(objv[3], &length);

	for (availPtr = pkgPtr->availPtr, prevPtr = NULL; availPtr != NULL;
		prevPtr = availPtr, availPtr = availPtr->nextPtr) {
	    if (CheckVersionAndConvert(interp, availPtr->version, &avi,
		    NULL) != TCL_OK) {
		ckfree(argv3i);
		return TCL_ERROR;
	    }

	    res = CompareVersions(avi, argv3i, NULL);
	    ckfree(avi);

	    if (res == 0){
		if (objc == 4) {
		    ckfree(argv3i);
		    Tcl_SetResult(interp, availPtr->script, TCL_VOLATILE);
		    return TCL_OK;
		}
		Tcl_EventuallyFree((ClientData)availPtr->script, TCL_DYNAMIC);
		break;
	    }
	}
	ckfree(argv3i);

	if (objc == 4) {
	    return TCL_OK;
	}
	if (availPtr == NULL) {
	    availPtr = (PkgAvail *) ckalloc(sizeof(PkgAvail));
	    DupBlock(availPtr->version, argv3, (unsigned) length + 1);

	    if (prevPtr == NULL) {
		availPtr->nextPtr = pkgPtr->availPtr;
		pkgPtr->availPtr = availPtr;
	    } else {
		availPtr->nextPtr = prevPtr->nextPtr;
		prevPtr->nextPtr = availPtr;
	    }
	}
	argv4 = Tcl_GetStringFromObj(objv[4], &length);
	DupBlock(availPtr->script, argv4, (unsigned) length + 1);
	break;
    }
    case PKG_NAMES:
	if (objc != 2) {
	    Tcl_WrongNumArgs(interp, 2, objv, NULL);
	    return TCL_ERROR;
	}
	tablePtr = &iPtr->packageTable;
	for (hPtr = Tcl_FirstHashEntry(tablePtr, &search); hPtr != NULL;
		hPtr = Tcl_NextHashEntry(&search)) {
	    pkgPtr = Tcl_GetHashValue(hPtr);
	    if ((pkgPtr->version != NULL) || (pkgPtr->availPtr != NULL)) {
		Tcl_AppendElement(interp, Tcl_GetHashKey(tablePtr, hPtr));
	    }
	}
	break;
    case PKG_PRESENT: {
	const char *name;
	if (objc < 3) {
	    goto require;
	}
	argv2 = TclGetString(objv[2]);
	if ((argv2[0] == '-') && (strcmp(argv2, "-exact") == 0)) {
	    if (objc != 5) {
		goto requireSyntax;
	    }
	    exact = 1;
	    name = TclGetString(objv[3]);
	} else {
	    exact = 0;
	    name = argv2;
	}

	hPtr = Tcl_FindHashEntry(&iPtr->packageTable, name);
	if (hPtr != NULL) {
	    pkgPtr = Tcl_GetHashValue(hPtr);
	    if (pkgPtr->version != NULL) {
		goto require;
	    }
	}

	version = NULL;
	if (exact) {
	    version = TclGetString(objv[4]);
	    if (CheckVersionAndConvert(interp, version, NULL,
		    NULL) != TCL_OK) {
		return TCL_ERROR;
	    }
	} else {
	    if (CheckAllRequirements(interp, objc-3, objv+3) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if ((objc > 3) && (CheckVersionAndConvert(interp,
		    TclGetString(objv[3]), NULL, NULL) == TCL_OK)) {
		version = TclGetString(objv[3]);
	    }
	}
	Tcl_PkgPresentEx(interp, name, version, exact, NULL);
	return TCL_ERROR;
	break;
    }
    case PKG_PROVIDE:
	if ((objc != 3) && (objc != 4)) {
	    Tcl_WrongNumArgs(interp, 2, objv, "package ?version?");
	    return TCL_ERROR;
	}
	argv2 = TclGetString(objv[2]);
	if (objc == 3) {
	    hPtr = Tcl_FindHashEntry(&iPtr->packageTable, argv2);
	    if (hPtr != NULL) {
		pkgPtr = Tcl_GetHashValue(hPtr);
		if (pkgPtr->version != NULL) {
		    Tcl_SetResult(interp, pkgPtr->version, TCL_VOLATILE);
		}
	    }
	    return TCL_OK;
	}
	argv3 = TclGetString(objv[3]);
	if (CheckVersionAndConvert(interp, argv3, NULL, NULL) != TCL_OK) {
	    return TCL_ERROR;
	}
	return Tcl_PkgProvideEx(interp, argv2, argv3, NULL);
    case PKG_REQUIRE:
    require:
	if (objc < 3) {
	requireSyntax:
	    Tcl_WrongNumArgs(interp, 2, objv,
		    "?-exact? package ?requirement...?");
	    return TCL_ERROR;
	}

	version = NULL;

	argv2 = TclGetString(objv[2]);
	if ((argv2[0] == '-') && (strcmp(argv2, "-exact") == 0)) {
	    Tcl_Obj *ov;
	    int res;

	    if (objc != 5) {
		goto requireSyntax;
	    }

	    version = TclGetString(objv[4]);
	    if (CheckVersionAndConvert(interp, version, NULL,
		    NULL) != TCL_OK) {
		return TCL_ERROR;
	    }

	    /*
	     * Create a new-style requirement for the exact version.
	     */

	    ov = Tcl_NewStringObj(version, -1);
	    Tcl_AppendStringsToObj(ov, "-", version, NULL);
	    version = NULL;
	    argv3 = TclGetString(objv[3]);

	    Tcl_IncrRefCount(ov);
	    res = Tcl_PkgRequireProc(interp, argv3, 1, &ov, NULL);
	    TclDecrRefCount(ov);
	    return res;
	} else {
	    if (CheckAllRequirements(interp, objc-3, objv+3) != TCL_OK) {
		return TCL_ERROR;
	    }

	    return Tcl_PkgRequireProc(interp, argv2, objc-3, objv+3, NULL);
	}
	break;
    case PKG_UNKNOWN: {
	int length;

	if (objc == 2) {
	    if (iPtr->packageUnknown != NULL) {
		Tcl_SetResult(interp, iPtr->packageUnknown, TCL_VOLATILE);
	    }
	} else if (objc == 3) {
	    if (iPtr->packageUnknown != NULL) {
		ckfree(iPtr->packageUnknown);
	    }
	    argv2 = Tcl_GetStringFromObj(objv[2], &length);
	    if (argv2[0] == 0) {
		iPtr->packageUnknown = NULL;
	    } else {
		DupBlock(iPtr->packageUnknown, argv2, (unsigned) length+1);
	    }
	} else {
	    Tcl_WrongNumArgs(interp, 2, objv, "?command?");
	    return TCL_ERROR;
	}
	break;
    }
    case PKG_PREFER: {
	static const char *pkgPreferOptions[] = {
	    "latest", "stable", NULL
	};

	/*
	 * See tclInt.h for the enum, just before Interp.
	 */

	if (objc > 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "?latest|stable?");
	    return TCL_ERROR;
	} else if (objc == 3) {
	    /*
	     * Seting the value.
	     */

	    int newPref;

	    if (Tcl_GetIndexFromObj(interp, objv[2], pkgPreferOptions,
		    "preference", 0, &newPref) != TCL_OK) {
		return TCL_ERROR;
	    }

	    if (newPref < iPtr->packagePrefer) {
		iPtr->packagePrefer = newPref;
	    }
	}

	/*
	 * Always return current value.
	 */

	Tcl_SetObjResult(interp,
		Tcl_NewStringObj(pkgPreferOptions[iPtr->packagePrefer], -1));
	break;
    }
    case PKG_VCOMPARE:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "version1 version2");
	    return TCL_ERROR;
	}
	argv3 = TclGetString(objv[3]);
	argv2 = TclGetString(objv[2]);
	if (CheckVersionAndConvert(interp, argv2, &iva, NULL) != TCL_OK ||
		CheckVersionAndConvert(interp, argv3, &ivb, NULL) != TCL_OK) {
	    if (iva != NULL) {
		ckfree(iva);
	    }

	    /*
	     * ivb cannot be set in this branch.
	     */

	    return TCL_ERROR;
	}

	/*
	 * Comparison is done on the internal representation.
	 */

	Tcl_SetObjResult(interp,
		Tcl_NewIntObj(CompareVersions(iva, ivb, NULL)));
	ckfree(iva);
	ckfree(ivb);
	break;
    case PKG_VERSIONS:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "package");
	    return TCL_ERROR;
	}
	argv2 = TclGetString(objv[2]);
	hPtr = Tcl_FindHashEntry(&iPtr->packageTable, argv2);
	if (hPtr != NULL) {
	    pkgPtr = Tcl_GetHashValue(hPtr);
	    for (availPtr = pkgPtr->availPtr; availPtr != NULL;
		    availPtr = availPtr->nextPtr) {
		Tcl_AppendElement(interp, availPtr->version);
	    }
	}
	break;
    case PKG_VSATISFIES: {
	char *argv2i = NULL;

	if (objc < 4) {
	    Tcl_WrongNumArgs(interp, 2, objv,
		    "version requirement requirement...");
	    return TCL_ERROR;
	}

	argv2 = TclGetString(objv[2]);
	if (CheckVersionAndConvert(interp, argv2, &argv2i, NULL) != TCL_OK) {
	    return TCL_ERROR;
	} else if (CheckAllRequirements(interp, objc-3, objv+3) != TCL_OK) {
	    ckfree(argv2i);
	    return TCL_ERROR;
	}

	satisfies = SomeRequirementSatisfied(argv2i, objc-3, objv+3);
	ckfree(argv2i);

	Tcl_SetObjResult(interp, Tcl_NewBooleanObj(satisfies));
	break;
    }
    default:
	Tcl_Panic("Tcl_PackageObjCmd: bad option index to pkgOptions");
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FindPackage --
 *
 *	This function finds the Package record for a particular package in a
 *	particular interpreter, creating a record if one doesn't already
 *	exist.
 *
 * Results:
 *	The return value is a pointer to the Package record for the package.
 *
 * Side effects:
 *	A new Package record may be created.
 *
 *----------------------------------------------------------------------
 */

static Package *
FindPackage(
    Tcl_Interp *interp,		/* Interpreter to use for package lookup. */
    const char *name)		/* Name of package to fine. */
{
    Interp *iPtr = (Interp *) interp;
    Tcl_HashEntry *hPtr;
    int isNew;
    Package *pkgPtr;

    hPtr = Tcl_CreateHashEntry(&iPtr->packageTable, name, &isNew);
    if (isNew) {
	pkgPtr = (Package *) ckalloc(sizeof(Package));
	pkgPtr->version = NULL;
	pkgPtr->availPtr = NULL;
	pkgPtr->clientData = NULL;
	Tcl_SetHashValue(hPtr, pkgPtr);
    } else {
	pkgPtr = Tcl_GetHashValue(hPtr);
    }
    return pkgPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFreePackageInfo --
 *
 *	This function is called during interpreter deletion to free all of the
 *	package-related information for the interpreter.
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
TclFreePackageInfo(
    Interp *iPtr)		/* Interpereter that is being deleted. */
{
    Package *pkgPtr;
    Tcl_HashSearch search;
    Tcl_HashEntry *hPtr;
    PkgAvail *availPtr;

    for (hPtr = Tcl_FirstHashEntry(&iPtr->packageTable, &search);
	    hPtr != NULL; hPtr = Tcl_NextHashEntry(&search)) {
	pkgPtr = Tcl_GetHashValue(hPtr);
	if (pkgPtr->version != NULL) {
	    ckfree(pkgPtr->version);
	}
	while (pkgPtr->availPtr != NULL) {
	    availPtr = pkgPtr->availPtr;
	    pkgPtr->availPtr = availPtr->nextPtr;
	    Tcl_EventuallyFree((ClientData)availPtr->version, TCL_DYNAMIC);
	    Tcl_EventuallyFree((ClientData)availPtr->script, TCL_DYNAMIC);
	    ckfree((char *) availPtr);
	}
	ckfree((char *) pkgPtr);
    }
    Tcl_DeleteHashTable(&iPtr->packageTable);
    if (iPtr->packageUnknown != NULL) {
	ckfree(iPtr->packageUnknown);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * CheckVersionAndConvert --
 *
 *	This function checks to see whether a version number has valid syntax.
 *	It also generates a semi-internal representation (string rep of a list
 *	of numbers).
 *
 * Results:
 *	If string is a properly formed version number the TCL_OK is returned.
 *	Otherwise TCL_ERROR is returned and an error message is left in the
 *	interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
CheckVersionAndConvert(
    Tcl_Interp *interp,		/* Used for error reporting. */
    const char *string,		/* Supposedly a version number, which is
				 * groups of decimal digits separated by
				 * dots. */
    char **internal,		/* Internal normalized representation */
    int *stable)		/* Flag: Version is (un)stable. */
{
    const char *p = string;
    char prevChar;
    int hasunstable = 0;
    /*
     * 4* assuming that each char is a separator (a,b become ' -x ').
     * 4+ to have spce for an additional -2 at the end
     */
    char *ibuf = ckalloc(4 + 4*strlen(string));
    char *ip = ibuf;

    /*
     * Basic rules
     * (1) First character has to be a digit.
     * (2) All other characters have to be a digit or '.'
     * (3) Two '.'s may not follow each other.
     *
     * TIP 268, Modified rules
     * (1) s.a.
     * (2) All other characters have to be a digit, 'a', 'b', or '.'
     * (3) s.a.
     * (4) Only one of 'a' or 'b' may occur.
     * (5) Neither 'a', nor 'b' may occur before or after a '.'
     */

    if (!isdigit(UCHAR(*p))) {				/* INTL: digit */
	goto error;
    }

    *ip++ = *p;

    for (prevChar = *p, p++; *p != 0; p++) {
	if (!isdigit(UCHAR(*p)) &&			/* INTL: digit */
		((*p!='.' && *p!='a' && *p!='b') ||
		((hasunstable && (*p=='a' || *p=='b')) ||
		((prevChar=='a' || prevChar=='b' || prevChar=='.')
			&& (*p=='.')) ||
		((*p=='a' || *p=='b' || *p=='.') && prevChar=='.')))) {
	    goto error;
	}

	if (*p == 'a' || *p == 'b') {
	    hasunstable = 1;
	}

	/*
	 * Translation to the internal rep. Regular version chars are copied
	 * as is. The separators are translated to numerics. The new separator
	 * for all parts is space.
	 */

	if (*p == '.') {
	    *ip++ = ' ';
	    *ip++ = '0';
	    *ip++ = ' ';
	} else if (*p == 'a') {
	    *ip++ = ' ';
	    *ip++ = '-';
	    *ip++ = '2';
	    *ip++ = ' ';
	} else if (*p == 'b') {
	    *ip++ = ' ';
	    *ip++ = '-';
	    *ip++ = '1';
	    *ip++ = ' ';
	} else {
	    *ip++ = *p;
	}

	prevChar = *p;
    }
    if (prevChar!='.' && prevChar!='a' && prevChar!='b') {
	*ip = '\0';
	if (internal != NULL) {
	    *internal = ibuf;
	} else {
	    ckfree(ibuf);
	}
	if (stable != NULL) {
	    *stable = !hasunstable;
	}
	return TCL_OK;
    }

  error:
    ckfree(ibuf);
    Tcl_AppendResult(interp, "expected version number but got \"", string,
	    "\"", NULL);
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * CompareVersions --
 *
 *	This function compares two version numbers (in internal rep).
 *
 * Results:
 *	The return value is -1 if v1 is less than v2, 0 if the two version
 *	numbers are the same, and 1 if v1 is greater than v2. If *satPtr is
 *	non-NULL, the word it points to is filled in with 1 if v2 >= v1 and
 *	both numbers have the same major number or 0 otherwise.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
CompareVersions(
    char *v1, char *v2,		/* Versions strings, of form 2.1.3 (any number
				 * of version numbers). */
    int *isMajorPtr)		/* If non-null, the word pointed to is filled
				 * in with a 0/1 value. 1 means that the
				 * difference occured in the first element. */
{
    int thisIsMajor, res, flip;
    char *s1, *e1, *s2, *e2, o1, o2;

    /*
     * Each iteration of the following loop processes one number from each
     * string, terminated by a " " (space). If those numbers don't match then
     * the comparison is over; otherwise, we loop back for the next number.
     *
     * TIP 268.
     * This is identical the function 'ComparePkgVersion', but using the new
     * space separator as used by the internal rep of version numbers. The
     * special separators 'a' and 'b' have already been dealt with in
     * 'CheckVersionAndConvert', they were translated into numbers as well.
     * This keeps the comparison sane. Otherwise we would have to compare
     * numerics, the separators, and also deal with the special case of
     * end-of-string compared to separators. The semi-list rep we get here is
     * much easier to handle, as it is still regular.
     *
     * Rewritten to not compute a numeric value for the extracted version
     * number, but do string comparison. Skip any leading zeros for that to
     * work. This change breaks through the 32bit-limit on version numbers.
     */

    thisIsMajor = 1;
    s1 = v1;
    s2 = v2;

    while (1) {
	/*
	 * Parse one decimal number from the front of each string. Skip
	 * leading zeros. Terminate found number for upcoming string-wise
	 * comparison, if needed.
	 */

	while ((*s1 != 0) && (*s1 == '0')) {
	    s1++;
	}
	while ((*s2 != 0) && (*s2 == '0')) {
	    s2++;
	}

	/*
	 * s1, s2 now point to the beginnings of the numbers to compare. Test
	 * for their signs first, as shortcut to the result (different signs),
	 * or determines if result has to be flipped (both negative). If there
	 * is no shortcut we have to insert terminators later to limit the
	 * strcmp.
	 */

	if ((*s1 == '-') && (*s2 != '-')) {
	    /* s1 < 0, s2 >= 0 => s1 < s2 */
	    res = -1;
	    break;
	}
	if ((*s1 != '-') && (*s2 == '-')) {
	    /* s1 >= 0, s2 < 0 => s1 > s2 */
	    res = 1;
	    break;
	}

	if ((*s1 == '-') && (*s2 == '-')) {
	    /* a < b => -a > -b, etc. */
	    s1++;
	    s2++;
	    flip = 1;
	} else {
	    flip = 0;
	}

	/*
	 * The string comparison is needed, so now we determine where the
	 * numbers end.
	 */

	e1 = s1;
	while ((*e1 != 0) && (*e1 != ' ')) {
	    e1++;
	}
	e2 = s2;
	while ((*e2 != 0) && (*e2 != ' ')) {
	    e2++;
	}

	/*
	 * s1 .. e1 and s2 .. e2 now bracket the numbers to compare. Insert
	 * terminators, compare, and restore actual contents. First however
	 * another shortcut. Compare lengths. Shorter string is smaller
	 * number! Thus we strcmp only strings of identical length.
	 */

	if ((e1-s1) < (e2-s2)) {
	    res = -1;
	} else if ((e2-s2) < (e1-s1)) {
	    res = 1;
	} else {
	    o1 = *e1;
	    *e1 = '\0';
	    o2 = *e2;
	    *e2 = '\0';

	    res = strcmp(s1, s2);
	    res = (res < 0) ? -1 : (res ? 1 : 0);

	    *e1 = o1;
	    *e2 = o2;
	}

	/*
	 * Stop comparing segments when a difference has been found. Here we
	 * may have to flip the result to account for signs.
	 */

	if (res != 0) {
	    if (flip) {
		res = -res;
	    }
	    break;
	}

	/*
	 * Go on to the next version number if the current numbers match.
	 * However stop processing if the end of both numbers has been
	 * reached.
	 */

	s1 = e1;
	s2 = e2;

	if (*s1 != 0) {
	    s1++;
	} else if (*s2 == 0) {
	    /*
	     * s1, s2 both at the end => identical
	     */

	    res = 0;
	    break;
	}
	if (*s2 != 0) {
	    s2++;
	}
	thisIsMajor = 0;
    }

    if (isMajorPtr != NULL) {
	*isMajorPtr = thisIsMajor;
    }

    return res;
}

/*
 *----------------------------------------------------------------------
 *
 * CheckAllRequirements --
 *
 *	This function checks to see whether all requirements in a set have
 *	valid syntax.
 *
 * Results:
 *	TCL_OK is returned if all requirements are valid. Otherwise TCL_ERROR
 *	is returned and an error message is left in the interp's result.
 *
 * Side effects:
 *	May modify the interpreter result.
 *
 *----------------------------------------------------------------------
 */

static int
CheckAllRequirements(
    Tcl_Interp *interp,
    int reqc,			/* Requirements to check. */
    Tcl_Obj *const reqv[])
{
    int i;

    for (i = 0; i < reqc; i++) {
	if ((CheckRequirement(interp, TclGetString(reqv[i])) != TCL_OK)) {
	    return TCL_ERROR;
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * CheckRequirement --
 *
 *	This function checks to see whether a requirement has valid syntax.
 *
 * Results:
 *	If string is a properly formed requirement then TCL_OK is returned.
 *	Otherwise TCL_ERROR is returned and an error message is left in the
 *	interp's result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
CheckRequirement(
    Tcl_Interp *interp,		/* Used for error reporting. */
    const char *string)		/* Supposedly a requirement. */
{
    /*
     * Syntax of requirement = version
     *			     = version-version
     *			     = version-
     */

    char *dash = NULL, *buf;

    dash = strchr(string, '-');
    if (dash == NULL) {
	/*
	 * No dash found, has to be a simple version.
	 */

	return CheckVersionAndConvert(interp, string, NULL, NULL);
    }

    if (strchr(dash+1, '-') != NULL) {
	/*
	 * More dashes found after the first. This is wrong.
	 */

	Tcl_AppendResult(interp, "expected versionMin-versionMax but got \"",
		string, "\"", NULL);
	return TCL_ERROR;
    }

    /*
     * Exactly one dash is present. Copy the string, split at the location of
     * dash and check that both parts are versions. Note that the max part can
     * be empty. Also note that the string allocated with strdup() must be
     * freed with free() and not ckfree().
     */

    DupString(buf, string);
    dash = buf + (dash - string);
    *dash = '\0';		/* buf now <=> min part */
    dash++;			/* dash now <=> max part */

    if ((CheckVersionAndConvert(interp, buf, NULL, NULL) != TCL_OK) ||
	    ((*dash != '\0') &&
	    (CheckVersionAndConvert(interp, dash, NULL, NULL) != TCL_OK))) {
	ckfree(buf);
	return TCL_ERROR;
    }

    ckfree(buf);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * AddRequirementsToResult --
 *
 *	This function accumulates requirements in the interpreter result.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The interpreter result is extended.
 *
 *----------------------------------------------------------------------
 */

static void
AddRequirementsToResult(
    Tcl_Interp *interp,
    int reqc,			/* Requirements constraining the desired
				 * version. */
    Tcl_Obj *const reqv[])	/* 0 means to use the latest version
				 * available. */
{
    if (reqc > 0) {
	int i;

	for (i = 0; i < reqc; i++) {
	    int length;
	    char *v = Tcl_GetStringFromObj(reqv[i], &length);

	    if ((length & 0x1) && (v[length/2] == '-')
		    && (strncmp(v, v+((length+1)/2), length/2) == 0)) {
		Tcl_AppendResult(interp, " exactly ", v+((length+1)/2), NULL);
	    } else {
		Tcl_AppendResult(interp, " ", v, NULL);
	    }
	}
    }
}

/*
 *----------------------------------------------------------------------
 *
 * AddRequirementsToDString --
 *
 *	This function accumulates requirements in a DString.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The DString argument is extended.
 *
 *----------------------------------------------------------------------
 */

static void
AddRequirementsToDString(
    Tcl_DString *dsPtr,
    int reqc,			/* Requirements constraining the desired
				 * version. */
    Tcl_Obj *const reqv[])	/* 0 means to use the latest version
				 * available. */
{
    if (reqc > 0) {
	int i;

	for (i = 0; i < reqc; i++) {
	    Tcl_DStringAppend(dsPtr, " ", 1);
	    Tcl_DStringAppend(dsPtr, TclGetString(reqv[i]), -1);
	}
    } else {
	Tcl_DStringAppend(dsPtr, " 0-", -1);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * SomeRequirementSatisfied --
 *
 *	This function checks to see whether a version satisfies at least one
 *	of a set of requirements.
 *
 * Results:
 *	If the requirements are satisfied 1 is returned. Otherwise 0 is
 *	returned. The function assumes that all pieces have valid syntax. And
 *	is allowed to make that assumption.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
SomeRequirementSatisfied(
    char *availVersionI,	/* Candidate version to check against the
				 * requirements. */
    int reqc,			/* Requirements constraining the desired
				 * version. */
    Tcl_Obj *const reqv[])	/* 0 means to use the latest version
				 * available. */
{
    int i;

    for (i = 0; i < reqc; i++) {
	if (RequirementSatisfied(availVersionI, TclGetString(reqv[i]))) {
	    return 1;
	}
    }
    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * RequirementSatisfied --
 *
 *	This function checks to see whether a version satisfies a requirement.
 *
 * Results:
 *	If the requirement is satisfied 1 is returned. Otherwise 0 is
 *	returned. The function assumes that all pieces have valid syntax, and
 *	is allowed to make that assumption.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
RequirementSatisfied(
    char *havei,		/* Version string, of candidate package we
				 * have. */
    const char *req)		/* Requirement string the candidate has to
				 * satisfy. */
{
    /*
     * The have candidate is already in internal rep.
     */

    int satisfied, res;
    char *dash = NULL, *buf, *min, *max;

    dash = strchr(req, '-');
    if (dash == NULL) {
	/*
	 * No dash found, is a simple version, fallback to regular check. The
	 * 'CheckVersionAndConvert' cannot fail. We pad the requirement with
	 * 'a0', i.e '-2' before doing the comparison to properly accept
	 * unstables as well.
	 */

	char *reqi = NULL;
	int thisIsMajor;

	CheckVersionAndConvert(NULL, req, &reqi, NULL);
	strcat(reqi, " -2");
	res = CompareVersions(havei, reqi, &thisIsMajor);
	satisfied = (res == 0) || ((res == 1) && !thisIsMajor);
	ckfree(reqi);
	return satisfied;
    }

    /*
     * Exactly one dash is present (Assumption of valid syntax). Copy the req,
     * split at the location of dash and check that both parts are versions.
     * Note that the max part can be empty.
     */

    DupString(buf, req);
    dash = buf + (dash - req);
    *dash = '\0';		/* buf now <=> min part */
    dash++;			/* dash now <=> max part */

    if (*dash == '\0') {
	/*
	 * We have a min, but no max. For the comparison we generate the
	 * internal rep, padded with 'a0' i.e. '-2'.
	 */

	CheckVersionAndConvert(NULL, buf, &min, NULL);
	strcat(min, " -2");
	satisfied = (CompareVersions(havei, min, NULL) >= 0);
	ckfree(min);
	ckfree(buf);
	return satisfied;
    }

    /*
     * We have both min and max, and generate their internal reps. When
     * identical we compare as is, otherwise we pad with 'a0' to ove the range
     * a bit.
     */

    CheckVersionAndConvert(NULL, buf, &min, NULL);
    CheckVersionAndConvert(NULL, dash, &max, NULL);

    if (CompareVersions(min, max, NULL) == 0) {
	satisfied = (CompareVersions(min, havei, NULL) == 0);
    } else {
	strcat(min, " -2");
	strcat(max, " -2");
	satisfied = ((CompareVersions(min, havei, NULL) <= 0) &&
		(CompareVersions(havei, max, NULL) < 0));
    }

    ckfree(min);
    ckfree(max);
    ckfree(buf);
    return satisfied;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PkgInitStubsCheck --
 *
 *	This is a replacement routine for Tcl_InitStubs() that is called
 *	from code where -DUSE_TCL_STUBS has not been enabled.
 *
 * Results:
 *	Returns the version of a conforming stubs table, or NULL, if
 *	the table version doesn't satisfy the requested requirements,
 *	according to historical practice.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

const char *
Tcl_PkgInitStubsCheck(
    Tcl_Interp *interp,
    const char * version,
    int exact)
{
    const char *actualVersion = Tcl_PkgPresent(interp, "Tcl", version, 0);

    if (exact && actualVersion) {
	const char *p = version;
	int count = 0;

	while (*p) {
	    count += !isdigit(UCHAR(*p++));
	}
	if (count == 1) {
	    if (0 != strncmp(version, actualVersion, strlen(version))) {
		/* Construct error message */
		Tcl_PkgPresent(interp, "Tcl", version, 1);
		return NULL;
	    }
	} else {
	    return Tcl_PkgPresent(interp, "Tcl", version, 1);
	}
    }
    return actualVersion;
}
/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

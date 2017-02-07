/*
 * tclStubLib.c --
 *
 *	Stub object that will be statically linked into extensions that want
 *	to access Tcl.
 *
 * Copyright (c) 1998-1999 by Scriptics Corporation.
 * Copyright (c) 1998 Paul Duffin.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

TclStubs *tclStubsPtr = NULL;
TclPlatStubs *tclPlatStubsPtr = NULL;
TclIntStubs *tclIntStubsPtr = NULL;
TclIntPlatStubs *tclIntPlatStubsPtr = NULL;
TclTomMathStubs* tclTomMathStubsPtr = NULL;

/*
 * Use our own ISDIGIT to avoid linking to libc on windows
 */

#define ISDIGIT(c) (((unsigned)((c)-'0')) <= 9)

/*
 *----------------------------------------------------------------------
 *
 * Tcl_InitStubs --
 *
 *	Tries to initialise the stub table pointers and ensures that the
 *	correct version of Tcl is loaded.
 *
 * Results:
 *	The actual version of Tcl that satisfies the request, or NULL to
 *	indicate that an error occurred.
 *
 * Side effects:
 *	Sets the stub table pointers.
 *
 *----------------------------------------------------------------------
 */
#undef Tcl_InitStubs
CONST char *
Tcl_InitStubs(
    Tcl_Interp *interp,
    CONST char *version,
    int exact)
{
    Interp *iPtr = (Interp *) interp;
    CONST char *actualVersion = NULL;
    ClientData pkgData = NULL;
    TclStubs *stubsPtr = iPtr->stubTable;

    /*
     * We can't optimize this check by caching tclStubsPtr because that
     * prevents apps from being able to load/unload Tcl dynamically multiple
     * times. [Bug 615304]
     */

    if (!stubsPtr || (stubsPtr->magic != TCL_STUB_MAGIC)) {
	iPtr->result = "interpreter uses an incompatible stubs mechanism";
	iPtr->freeProc = TCL_STATIC;
	return NULL;
    }

    actualVersion = stubsPtr->tcl_PkgRequireEx(interp, "Tcl", version, 0, &pkgData);
    if (actualVersion == NULL) {
	return NULL;
    }
    if (exact) {
	CONST char *p = version;
	int count = 0;

	while (*p) {
	    count += !ISDIGIT(*p++);
	}
	if (count == 1) {
	    CONST char *q = actualVersion;

	    p = version;
	    while (*p && (*p == *q)) {
		p++; q++;
	    }
	    if (*p || ISDIGIT(*q)) {
		/* Construct error message */
		stubsPtr->tcl_PkgRequireEx(interp, "Tcl", version, 1, NULL);
		return NULL;
	    }
	} else {
	    actualVersion = stubsPtr->tcl_PkgRequireEx(interp, "Tcl", version, 1, NULL);
	    if (actualVersion == NULL) {
		return NULL;
	    }
	}
    }
    tclStubsPtr = (TclStubs *)pkgData;

    if (tclStubsPtr->hooks) {
	tclPlatStubsPtr = tclStubsPtr->hooks->tclPlatStubs;
	tclIntStubsPtr = tclStubsPtr->hooks->tclIntStubs;
	tclIntPlatStubsPtr = tclStubsPtr->hooks->tclIntPlatStubs;
    } else {
	tclPlatStubsPtr = NULL;
	tclIntStubsPtr = NULL;
	tclIntPlatStubsPtr = NULL;
    }

    return actualVersion;
}

/*
 *----------------------------------------------------------------------
 *
 * TclTomMathInitStubs --
 *
 *	Initializes the Stubs table for Tcl's subset of libtommath
 *
 * Results:
 *	Returns a standard Tcl result.
 *
 * This procedure should not be called directly, but rather through
 * the TclTomMath_InitStubs macro, to insure that the Stubs table
 * matches the header files used in compilation.
 *
 *----------------------------------------------------------------------
 */

#undef TclTomMathInitializeStubs

CONST char*
TclTomMathInitializeStubs(
    Tcl_Interp* interp,		/* Tcl interpreter */
    CONST char* version,	/* Tcl version needed */
    int epoch,			/* Stubs table epoch from the header files */
    int revision		/* Stubs table revision number from the
				 * header files */
) {
    int exact = 0;
    const char* packageName = "tcl::tommath";
    const char* errMsg = NULL;
    ClientData pkgClientData = NULL;
    const char* actualVersion = 
	tclStubsPtr->tcl_PkgRequireEx(interp, packageName, version, exact, &pkgClientData);
    TclTomMathStubs* stubsPtr = (TclTomMathStubs*) pkgClientData;
    if (actualVersion == NULL) {
	return NULL;
    }
    if (pkgClientData == NULL) {
	errMsg = "missing stub table pointer";
    } else if ((stubsPtr->tclBN_epoch)() != epoch) {
	errMsg = "epoch number mismatch";
    } else if ((stubsPtr->tclBN_revision)() != revision) {
	errMsg = "requires a later revision";
    } else {
	tclTomMathStubsPtr = stubsPtr;
	return actualVersion;
    }
    tclStubsPtr->tcl_ResetResult(interp);
    tclStubsPtr->tcl_AppendResult(interp, "error loading ", packageName,
		     " (requested version ", version,
		     ", actual version ", actualVersion,
		     "): ", errMsg, NULL);
    return NULL;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

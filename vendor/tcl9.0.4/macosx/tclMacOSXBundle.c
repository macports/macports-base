/*
 * tclMacOSXBundle.c --
 *
 *	This file implements functions that inspect CFBundle structures on
 *	MacOS X.
 *
 * Copyright © 2001-2009 Apple Inc.
 * Copyright © 2003-2009 Daniel A. Steffen <das@users.sourceforge.net>
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclPort.h"
#include "tclInt.h"

#ifdef HAVE_COREFOUNDATION
#include <CoreFoundation/CoreFoundation.h>

#include <dlfcn.h>

#ifdef TCL_DEBUG_LOAD
#define TclLoadDbgMsg(m, ...) \
    do {								\
	fprintf(stderr, "%s:%d: %s(): " m ".\n",			\
		strrchr(__FILE__, '/')+1, __LINE__, __func__,		\
		##__VA_ARGS__);						\
    } while (0)
#else
#define TclLoadDbgMsg(m, ...)
#endif /* TCL_DEBUG_LOAD */

/*
 * Forward declaration of functions defined in this file:
 */

static short		OpenResourceMap(CFBundleRef bundleRef);

#endif /* HAVE_COREFOUNDATION */

/*
 *----------------------------------------------------------------------
 *
 * OpenResourceMap --
 *
 *	Wrapper that dynamically acquires the address for the function
 *	CFBundleOpenBundleResourceMap before calling it, since it is only
 *	present in full CoreFoundation on Mac OS X and not in CFLite on pure
 *	Darwin. Factored out because it is moderately ugly code.
 *
 *----------------------------------------------------------------------
 */

#ifdef HAVE_COREFOUNDATION

static short
OpenResourceMap(
    CFBundleRef bundleRef)
{
    static int initialized = FALSE;
    static short (*openresourcemap)(CFBundleRef) = NULL;

    if (!initialized) {
	{
	    openresourcemap = (short (*)(CFBundleRef))dlsym(RTLD_NEXT,
		    "CFBundleOpenBundleResourceMap");
#ifdef TCL_DEBUG_LOAD
	    if (!openresourcemap) {
		const char *errMsg = dlerror();

		TclLoadDbgMsg("dlsym() failed: %s", errMsg);
	    }
#endif /* TCL_DEBUG_LOAD */
	}
	initialized = TRUE;
    }

    if (openresourcemap) {
	return openresourcemap(bundleRef);
    }
    return -1;
}

#endif /* HAVE_COREFOUNDATION */

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MacOSXOpenVersionedBundleResources --
 *
 *	Given the bundle and version name for a shared library (version name
 *	can be NULL to indicate latest version), this routine sets libraryPath
 *	to the Resources/Scripts directory in the framework package. If
 *	hasResourceFile is true, it will also open the main resource file for
 *	the bundle.
 *
 * Results:
 *	TCL_OK if the bundle could be opened, and the Scripts folder found.
 *	TCL_ERROR otherwise.
 *
 * Side effects:
 *	libraryVariableName may be set, and the resource file opened.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_MacOSXOpenVersionedBundleResources(
    TCL_UNUSED(Tcl_Interp *),
    const char *bundleName,
    const char *bundleVersion,
    int hasResourceFile,
    Tcl_Size maxPathLen,
    char *libraryPath)
{
#ifdef HAVE_COREFOUNDATION
    CFBundleRef bundleRef, versionedBundleRef = NULL;
    CFStringRef bundleNameRef;
    CFURLRef libURL;

    libraryPath[0] = '\0';

    bundleNameRef = CFStringCreateWithCString(NULL, bundleName,
	    kCFStringEncodingUTF8);

    bundleRef = CFBundleGetBundleWithIdentifier(bundleNameRef);
    CFRelease(bundleNameRef);

    if (bundleVersion && bundleRef) {
	/*
	 * Create bundle from bundleVersion subdirectory of 'Versions'.
	 */

	CFURLRef bundleURL = CFBundleCopyBundleURL(bundleRef);

	if (bundleURL) {
	    CFStringRef bundleVersionRef = CFStringCreateWithCString(NULL,
		    bundleVersion, kCFStringEncodingUTF8);

	    if (bundleVersionRef) {
		CFComparisonResult versionComparison = kCFCompareLessThan;
		CFStringRef bundleTailRef = CFURLCopyLastPathComponent(
			bundleURL);

		if (bundleTailRef) {
		    versionComparison = CFStringCompare(bundleTailRef,
			    bundleVersionRef, 0);
		    CFRelease(bundleTailRef);
		}
		if (versionComparison != kCFCompareEqualTo) {
		    CFURLRef versURL = CFURLCreateCopyAppendingPathComponent(
			    NULL, bundleURL, CFSTR("Versions"), TRUE);

		    if (versURL) {
			CFURLRef versionedBundleURL =
				CFURLCreateCopyAppendingPathComponent(
				NULL, versURL, bundleVersionRef, TRUE);

			if (versionedBundleURL) {
			    versionedBundleRef = CFBundleCreate(NULL,
				    versionedBundleURL);
			    if (versionedBundleRef) {
				bundleRef = versionedBundleRef;
			    }
			    CFRelease(versionedBundleURL);
			}
			CFRelease(versURL);
		    }
		}
		CFRelease(bundleVersionRef);
	    }
	    CFRelease(bundleURL);
	}
    }

    if (bundleRef) {
	if (hasResourceFile) {
	    (void) OpenResourceMap(bundleRef);
	}

	libURL = CFBundleCopyResourceURL(bundleRef, CFSTR("Scripts"),
		NULL, NULL);

	if (libURL) {
	    /*
	     * FIXME: This is a quick fix, it is probably not right for
	     * internationalization.
	     */

	    CFURLGetFileSystemRepresentation(libURL, TRUE,
		    (unsigned char *) libraryPath, maxPathLen);
	    CFRelease(libURL);
	}
	if (versionedBundleRef) {
	    {
		CFRelease(versionedBundleRef);
	    }
	}
    }

    if (libraryPath[0]) {
	return TCL_OK;
    }
#endif /* HAVE_COREFOUNDATION */
    return TCL_ERROR;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

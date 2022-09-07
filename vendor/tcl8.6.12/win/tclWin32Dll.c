/*
 * tclWin32Dll.c --
 *
 *	This file contains the DLL entry point and other low-level bit bashing
 *	code that needs inline assembly.
 *
 * Copyright (c) 1995-1996 Sun Microsystems, Inc.
 * Copyright (c) 1998-2000 Scriptics Corporation.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclWinInt.h"
#if defined(HAVE_INTRIN_H)
#   include <intrin.h>
#endif

/*
 * The following variables keep track of information about this DLL on a
 * per-instance basis. Each time this DLL is loaded, it gets its own new data
 * segment with its own copy of all static and global information.
 */

static HINSTANCE hInstance;	/* HINSTANCE of this DLL. */

/*
 * VC++ 5.x has no 'cpuid' assembler instruction, so we must emulate it
 */

#if defined(_MSC_VER) && (_MSC_VER <= 1100) && defined (_M_IX86)
#define cpuid	__asm __emit 0fh __asm __emit 0a2h
#endif

/*
 * The following declaration is for the VC++ DLL entry point.
 */

BOOL APIENTRY		DllMain(HINSTANCE hInst, DWORD reason,
			    LPVOID reserved);

/*
 * The following structure and linked list is to allow us to map between
 * volume mount points and drive letters on the fly (no Win API exists for
 * this).
 */

typedef struct MountPointMap {
    WCHAR *volumeName;		/* Native wide string volume name. */
    WCHAR driveLetter;		/* Drive letter corresponding to the volume
				 * name. */
    struct MountPointMap *nextPtr;
				/* Pointer to next structure in list, or
				 * NULL. */
} MountPointMap;

/*
 * This is the head of the linked list, which is protected by the mutex which
 * follows, for thread-enabled builds.
 */

MountPointMap *driveLetterLookup = NULL;
TCL_DECLARE_MUTEX(mountPointMap)

/*
 * We will need this below.
 */

#ifdef _WIN32
#ifndef STATIC_BUILD

/*
 *----------------------------------------------------------------------
 *
 * DllEntryPoint --
 *
 *	This wrapper function is used by Borland to invoke the initialization
 *	code for Tcl. It simply calls the DllMain routine.
 *
 * Results:
 *	See DllMain.
 *
 * Side effects:
 *	See DllMain.
 *
 *----------------------------------------------------------------------
 */

BOOL APIENTRY
DllEntryPoint(
    HINSTANCE hInst,		/* Library instance handle. */
    DWORD reason,		/* Reason this function is being called. */
    LPVOID reserved)		/* Not used. */
{
    return DllMain(hInst, reason, reserved);
}

/*
 *----------------------------------------------------------------------
 *
 * DllMain --
 *
 *	This routine is called by the VC++ C run time library init code, or
 *	the DllEntryPoint routine. It is responsible for initializing various
 *	dynamically loaded libraries.
 *
 * Results:
 *	TRUE on sucess, FALSE on failure.
 *
 * Side effects:
 *	Initializes most rudimentary Windows bits.
 *
 *----------------------------------------------------------------------
 */

BOOL APIENTRY
DllMain(
    HINSTANCE hInst,		/* Library instance handle. */
    DWORD reason,		/* Reason this function is being called. */
    LPVOID reserved)		/* Not used. */
{
    (void)reserved;

    switch (reason) {
    case DLL_PROCESS_ATTACH:
	DisableThreadLibraryCalls(hInst);
	TclWinInit(hInst);
	return TRUE;

	/*
	 * DLL_PROCESS_DETACH is unnecessary as the user should call
	 * Tcl_Finalize explicitly before unloading Tcl.
	 */
    }

    return TRUE;
}
#endif /* !STATIC_BUILD */
#endif /* _WIN32 */

/*
 *----------------------------------------------------------------------
 *
 * TclWinGetTclInstance --
 *
 *	Retrieves the global library instance handle.
 *
 * Results:
 *	Returns the global library instance handle.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

HINSTANCE
TclWinGetTclInstance(void)
{
    return hInstance;
}

/*
 *----------------------------------------------------------------------
 *
 * TclWinInit --
 *
 *	This function initializes the internal state of the tcl library.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Initializes the tclPlatformId variable.
 *
 *----------------------------------------------------------------------
 */

void
TclWinInit(
    HINSTANCE hInst)		/* Library instance handle. */
{
    OSVERSIONINFOW os;

    hInstance = hInst;
    os.dwOSVersionInfoSize = sizeof(OSVERSIONINFOW);
    GetVersionExW(&os);

    /*
     * We no longer support Win32s or Win9x or Windows CE, so just in case
     * someone manages to get a runtime there, make sure they know that.
     */

    if (os.dwPlatformId != VER_PLATFORM_WIN32_NT) {
	Tcl_Panic("Windows NT is the only supported platform");
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclWinGetPlatformId --
 *
 *	Determines whether running under NT, 95, or Win32s, to allow runtime
 *	conditional code.
 *
 * Results:
 *	The return value is always:
 *	VER_PLATFORM_WIN32_NT	Win32 on Windows NT, 2000, XP
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclWinGetPlatformId(void)
{
    return VER_PLATFORM_WIN32_NT;
}

/*
 *-------------------------------------------------------------------------
 *
 * TclWinNoBackslash --
 *
 *	We're always iterating through a string in Windows, changing the
 *	backslashes to slashes for use in Tcl.
 *
 * Results:
 *	All backslashes in given string are changed to slashes.
 *
 * Side effects:
 *	None.
 *
 *-------------------------------------------------------------------------
 */

char *
TclWinNoBackslash(
    char *path)			/* String to change. */
{
    char *p;

    for (p = path; *p != '\0'; p++) {
	if (*p == '\\') {
	    *p = '/';
	}
    }
    return path;
}

/*
 *---------------------------------------------------------------------------
 *
 * TclWinEncodingsCleanup --
 *
 *	Called during finalization to clean up any memory allocated in our
 *	mount point map which is used to follow certain kinds of symlinks.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

void
TclWinEncodingsCleanup(void)
{
    MountPointMap *dlIter, *dlIter2;

    /*
     * Clean up the mount point map.
     */

    Tcl_MutexLock(&mountPointMap);
    dlIter = driveLetterLookup;
    while (dlIter != NULL) {
	dlIter2 = dlIter->nextPtr;
	ckfree(dlIter->volumeName);
	ckfree(dlIter);
	dlIter = dlIter2;
    }
    Tcl_MutexUnlock(&mountPointMap);
}

/*
 *---------------------------------------------------------------------------
 *
 * TclWinResetInterfaces --
 *
 *	Called during finalization to reset us to a safe state for reuse.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */
void
TclWinResetInterfaces(void)
{
}

/*
 *--------------------------------------------------------------------
 *
 * TclWinDriveLetterForVolMountPoint
 *
 *	Unfortunately, Windows provides no easy way at all to get hold of the
 *	drive letter for a volume mount point, but we need that information to
 *	understand paths correctly. So, we have to build an associated array
 *	to find these correctly, and allow quick and easy lookup from volume
 *	mount points to drive letters.
 *
 *	We assume here that we are running on a system for which the wide
 *	character interfaces are used, which is valid for Win 2000 and WinXP
 *	which are the only systems on which this function will ever be called.
 *
 * Result:
 *	The drive letter, or -1 if no drive letter corresponds to the given
 *	mount point.
 *
 *--------------------------------------------------------------------
 */

char
TclWinDriveLetterForVolMountPoint(
    const WCHAR *mountPoint)
{
    MountPointMap *dlIter, *dlPtr2;
    WCHAR Target[55];		/* Target of mount at mount point */
    WCHAR drive[4] = L"A:\\";

    /*
     * Detect the volume mounted there. Unfortunately, there is no simple way
     * to map a unique volume name to a DOS drive letter. So, we have to build
     * an associative array.
     */

    Tcl_MutexLock(&mountPointMap);
    dlIter = driveLetterLookup;
    while (dlIter != NULL) {
	if (wcscmp(dlIter->volumeName, mountPoint) == 0) {
	    /*
	     * We need to check whether this information is still valid, since
	     * either the user or various programs could have adjusted the
	     * mount points on the fly.
	     */

	    drive[0] = (WCHAR) dlIter->driveLetter;

	    /*
	     * Try to read the volume mount point and see where it points.
	     */

	    if (GetVolumeNameForVolumeMountPointW(drive,
		    Target, 55) != 0) {
		if (wcscmp(dlIter->volumeName, Target) == 0) {
		    /*
		     * Nothing has changed.
		     */

		    Tcl_MutexUnlock(&mountPointMap);
		    return (char) dlIter->driveLetter;
		}
	    }

	    /*
	     * If we reach here, unfortunately, this mount point is no longer
	     * valid at all.
	     */

	    if (driveLetterLookup == dlIter) {
		dlPtr2 = dlIter;
		driveLetterLookup = dlIter->nextPtr;
	    } else {
		for (dlPtr2 = driveLetterLookup;
			dlPtr2 != NULL; dlPtr2 = dlPtr2->nextPtr) {
		    if (dlPtr2->nextPtr == dlIter) {
			dlPtr2->nextPtr = dlIter->nextPtr;
			dlPtr2 = dlIter;
			break;
		    }
		}
	    }

	    /*
	     * Now dlPtr2 points to the structure to free.
	     */

	    ckfree(dlPtr2->volumeName);
	    ckfree(dlPtr2);

	    /*
	     * Restart the loop - we could try to be clever and continue half
	     * way through, but the logic is a bit messy, so it's cleanest
	     * just to restart.
	     */

	    dlIter = driveLetterLookup;
	    continue;
	}
	dlIter = dlIter->nextPtr;
    }

    /*
     * We couldn't find it, so we must iterate over the letters.
     */

    for (drive[0] = 'A'; drive[0] <= 'Z'; drive[0]++) {
	/*
	 * Try to read the volume mount point and see where it points.
	 */

	if (GetVolumeNameForVolumeMountPointW(drive,
		Target, 55) != 0) {
	    int alreadyStored = 0;

	    for (dlIter = driveLetterLookup; dlIter != NULL;
		    dlIter = dlIter->nextPtr) {
		if (wcscmp(dlIter->volumeName, Target) == 0) {
		    alreadyStored = 1;
		    break;
		}
	    }
	    if (!alreadyStored) {
		dlPtr2 = (MountPointMap *)ckalloc(sizeof(MountPointMap));
		dlPtr2->volumeName = (WCHAR *)TclNativeDupInternalRep(Target);
		dlPtr2->driveLetter = (char) drive[0];
		dlPtr2->nextPtr = driveLetterLookup;
		driveLetterLookup = dlPtr2;
	    }
	}
    }

    /*
     * Try again.
     */

    for (dlIter = driveLetterLookup; dlIter != NULL;
	    dlIter = dlIter->nextPtr) {
	if (wcscmp(dlIter->volumeName, mountPoint) == 0) {
	    Tcl_MutexUnlock(&mountPointMap);
	    return (char) dlIter->driveLetter;
	}
    }

    /*
     * The volume doesn't appear to correspond to a drive letter - we remember
     * that fact and store '-1' so we don't have to look it up each time.
     */

    dlPtr2 = (MountPointMap *)ckalloc(sizeof(MountPointMap));
    dlPtr2->volumeName = (WCHAR *)TclNativeDupInternalRep((void *)mountPoint);
    dlPtr2->driveLetter = -1;
    dlPtr2->nextPtr = driveLetterLookup;
    driveLetterLookup = dlPtr2;
    Tcl_MutexUnlock(&mountPointMap);
    return -1;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_WinUtfToTChar, Tcl_WinTCharToUtf --
 *
 *	Convert between UTF-8 and Unicode when running Windows.
 *
 *	On Mac and Unix, all strings exchanged between Tcl and the OS are
 *	"char" oriented. We need only one Tcl_Encoding to convert between
 *	UTF-8 and the system's native encoding. We use NULL to represent
 *	that encoding.
 *
 *	On Windows, some strings exchanged between Tcl and the OS are "char"
 *	oriented, while others are in Unicode. We need two Tcl_Encoding APIs
 *	depending on whether we are targeting a "char" or Unicode interface.
 *
 *	Calling Tcl_UtfToExternal() or Tcl_ExternalToUtf() with an encoding
 *	of NULL should always used to convert between UTF-8 and the system's
 *	"char" oriented encoding. The following two functions are used in
 *	Windows-specific code to convert between UTF-8 and Unicode strings.
 *	This saves you the trouble of writing the
 *	following type of fragment over and over:
 *
 *		encoding <- Tcl_GetEncoding("unicode");
 *		nativeBuffer <- UtfToExternal(encoding, utfBuffer);
 *		Tcl_FreeEncoding(encoding);
 *
 *	By convention, in Windows a WCHAR is a Unicode character. If you plan
 *	on targeting a Unicode interface when running on Windows, these
 *	functions should be used. If you plan on targetting a "char" oriented
 *	function on Windows, use Tcl_UtfToExternal() with an encoding of NULL.
 *
 * Results:
 *	The result is a pointer to the string in the desired target encoding.
 *	Storage for the result string is allocated in dsPtr; the caller must
 *	call Tcl_DStringFree() when the result is no longer needed.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

TCHAR *
Tcl_WinUtfToTChar(
    const char *string,		/* Source string in UTF-8. */
    int len,			/* Source string length in bytes, or -1 for
				 * strlen(). */
    Tcl_DString *dsPtr)		/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
#if TCL_UTF_MAX > 4
    Tcl_UniChar ch = 0;
    TCHAR *w, *wString;
    const char *p, *end;
    int oldLength;
#endif

    Tcl_DStringInit(dsPtr);
    if (!string) {
	return NULL;
    }
#if TCL_UTF_MAX > 4

    if (len < 0) {
	len = strlen(string);
    }

    /*
     * Unicode string length in Tcl_UniChars will be <= UTF-8 string length in
     * bytes.
     */

    oldLength = Tcl_DStringLength(dsPtr);

    Tcl_DStringSetLength(dsPtr,
	    oldLength + (int) ((len + 1) * sizeof(TCHAR)));
    wString = (TCHAR *) (Tcl_DStringValue(dsPtr) + oldLength);

    w = wString;
    p = string;
    end = string + len - 4;
    while (p < end) {
	p += TclUtfToUniChar(p, &ch);
	if (ch > 0xFFFF) {
	    *w++ = (WCHAR) (0xD800 + ((ch -= 0x10000) >> 10));
	    *w++ = (WCHAR) (0xDC00 | (ch & 0x3FF));
	} else {
	    *w++ = ch;
	}
    }
    end += 4;
    while (p < end) {
	if (Tcl_UtfCharComplete(p, end-p)) {
	    p += TclUtfToUniChar(p, &ch);
	} else {
	    ch = UCHAR(*p++);
	}
	if (ch > 0xFFFF) {
	    *w++ = (WCHAR) (0xD800 + ((ch -= 0x10000) >> 10));
	    *w++ = (WCHAR) (0xDC00 | (ch & 0x3FF));
	} else {
	    *w++ = ch;
	}
    }
    *w = '\0';
    Tcl_DStringSetLength(dsPtr,
	    oldLength + ((char *) w - (char *) wString));

    return wString;
#else
    return (TCHAR *)Tcl_UtfToUniCharDString(string, len, dsPtr);
#endif
}

char *
Tcl_WinTCharToUtf(
    const TCHAR *string,	/* Source string in Unicode. */
    int len,			/* Source string length in bytes, or -1 for
				 * platform-specific string length. */
    Tcl_DString *dsPtr)		/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
#if TCL_UTF_MAX > 4
    const WCHAR *w, *wEnd;
    char *p, *result;
    int oldLength, blen = 1;
#endif

    Tcl_DStringInit(dsPtr);
    if (!string) {
	return NULL;
    }
    if (len < 0) {
	len = wcslen((WCHAR *)string);
    } else {
	len /= 2;
    }
#if TCL_UTF_MAX > 4
    oldLength = Tcl_DStringLength(dsPtr);
    Tcl_DStringSetLength(dsPtr, oldLength + (len + 1) * 4);
    result = Tcl_DStringValue(dsPtr) + oldLength;

    p = result;
    wEnd = (WCHAR *)string + len;
    for (w = (WCHAR *)string; w < wEnd; ) {
	if (!blen && ((*w & 0xFC00) != 0xDC00)) {
	    /* Special case for handling high surrogates. */
	    p += Tcl_UniCharToUtf(-1, p);
	}
	blen = Tcl_UniCharToUtf(*w, p);
	p += blen;
	if ((*w >= 0xD800) && (blen < 3)) {
	    /* Indication that high surrogate is handled */
	    blen = 0;
	}
	w++;
    }
    if (!blen) {
	/* Special case for handling high surrogates. */
	p += Tcl_UniCharToUtf(-1, p);
    }
    Tcl_DStringSetLength(dsPtr, oldLength + (p - result));

    return result;
#else
    return Tcl_UniCharToUtfDString((Tcl_UniChar *)string, len, dsPtr);
#endif
}

/*
 *------------------------------------------------------------------------
 *
 * TclWinCPUID --
 *
 *	Get CPU ID information on an Intel box under Windows
 *
 * Results:
 *	Returns TCL_OK if successful, TCL_ERROR if CPUID is not supported or
 *	fails.
 *
 * Side effects:
 *	If successful, stores EAX, EBX, ECX and EDX registers after the CPUID
 *	instruction in the four integers designated by 'regsPtr'
 *
 *----------------------------------------------------------------------
 */

int
TclWinCPUID(
    unsigned int index,		/* Which CPUID value to retrieve. */
    unsigned int *regsPtr)	/* Registers after the CPUID. */
{
    int status = TCL_ERROR;

#if defined(HAVE_INTRIN_H) && defined(_WIN64)

    __cpuid((int *)regsPtr, index);
    status = TCL_OK;

#elif defined(__GNUC__)
#   if defined(_WIN64)
    /*
     * Execute the CPUID instruction with the given index, and store results
     * off 'regPtr'.
     */

    __asm__ __volatile__(
	/*
	 * Do the CPUID instruction, and save the results in the 'regsPtr'
	 * area.
	 */

	"movl	%[rptr],	%%edi"		"\n\t"
	"movl	%[index],	%%eax"		"\n\t"
	"cpuid"					"\n\t"
	"movl	%%eax,		0x0(%%edi)"	"\n\t"
	"movl	%%ebx,		0x4(%%edi)"	"\n\t"
	"movl	%%ecx,		0x8(%%edi)"	"\n\t"
	"movl	%%edx,		0xC(%%edi)"	"\n\t"

	:
	/* No outputs */
	:
	[index]		"m"	(index),
	[rptr]		"m"	(regsPtr)
	:
	"%eax", "%ebx", "%ecx", "%edx", "%esi", "%edi", "memory");
    status = TCL_OK;

#   else

    TCLEXCEPTION_REGISTRATION registration;

    /*
     * Execute the CPUID instruction with the given index, and store results
     * off 'regPtr'.
     */

    __asm__ __volatile__(
	/*
	 * Construct an TCLEXCEPTION_REGISTRATION to protect the CPUID
	 * instruction (early 486's don't have CPUID)
	 */

	"leal	%[registration], %%edx"		"\n\t"
	"movl	%%fs:0,		%%eax"		"\n\t"
	"movl	%%eax,		0x0(%%edx)"	"\n\t" /* link */
	"leal	1f,		%%eax"		"\n\t"
	"movl	%%eax,		0x4(%%edx)"	"\n\t" /* handler */
	"movl	%%ebp,		0x8(%%edx)"	"\n\t" /* ebp */
	"movl	%%esp,		0xC(%%edx)"	"\n\t" /* esp */
	"movl	%[error],	0x10(%%edx)"	"\n\t" /* status */

	/*
	 * Link the TCLEXCEPTION_REGISTRATION on the chain
	 */

	"movl	%%edx,		%%fs:0"		"\n\t"

	/*
	 * Do the CPUID instruction, and save the results in the 'regsPtr'
	 * area.
	 */

	"movl	%[rptr],	%%edi"		"\n\t"
	"movl	%[index],	%%eax"		"\n\t"
	"cpuid"					"\n\t"
	"movl	%%eax,		0x0(%%edi)"	"\n\t"
	"movl	%%ebx,		0x4(%%edi)"	"\n\t"
	"movl	%%ecx,		0x8(%%edi)"	"\n\t"
	"movl	%%edx,		0xC(%%edi)"	"\n\t"

	/*
	 * Come here on a normal exit. Recover the TCLEXCEPTION_REGISTRATION and
	 * store a TCL_OK status.
	 */

	"movl	%%fs:0,		%%edx"		"\n\t"
	"movl	%[ok],		%%eax"		"\n\t"
	"movl	%%eax,		0x10(%%edx)"	"\n\t"
	"jmp	2f"				"\n"

	/*
	 * Come here on an exception. Get the TCLEXCEPTION_REGISTRATION that we
	 * previously put on the chain.
	 */

	"1:"					"\t"
	"movl	%%fs:0,		%%edx"		"\n\t"
	"movl	0x8(%%edx),	%%edx"		"\n\t"

	/*
	 * Come here however we exited. Restore context from the
	 * TCLEXCEPTION_REGISTRATION in case the stack is unbalanced.
	 */

	"2:"					"\t"
	"movl	0xC(%%edx),	%%esp"		"\n\t"
	"movl	0x8(%%edx),	%%ebp"		"\n\t"
	"movl	0x0(%%edx),	%%eax"		"\n\t"
	"movl	%%eax,		%%fs:0"		"\n\t"

	:
	/* No outputs */
	:
	[index]		"m"	(index),
	[rptr]		"m"	(regsPtr),
	[registration]	"m"	(registration),
	[ok]		"i"	(TCL_OK),
	[error]		"i"	(TCL_ERROR)
	:
	"%eax", "%ebx", "%ecx", "%edx", "%esi", "%edi", "memory");
    status = registration.status;

#   endif /* !_WIN64 */
#elif defined(_MSC_VER)
#   if defined(_WIN64)

    __cpuid(regsPtr, index);
    status = TCL_OK;

#   elif defined (_M_IX86)
    /*
     * Define a structure in the stack frame to hold the registers.
     */

    struct {
	DWORD dw0;
	DWORD dw1;
	DWORD dw2;
	DWORD dw3;
    } regs;
    regs.dw0 = index;

    /*
     * Execute the CPUID instruction and save regs in the stack frame.
     */

    _try {
	_asm {
	    push    ebx
	    push    ecx
	    push    edx
	    mov	    eax, regs.dw0
	    cpuid
	    mov	    regs.dw0, eax
	    mov	    regs.dw1, ebx
	    mov	    regs.dw2, ecx
	    mov	    regs.dw3, edx
	    pop	    edx
	    pop	    ecx
	    pop	    ebx
	}

	/*
	 * Copy regs back out to the caller.
	 */

	regsPtr[0] = regs.dw0;
	regsPtr[1] = regs.dw1;
	regsPtr[2] = regs.dw2;
	regsPtr[3] = regs.dw3;

	status = TCL_OK;
    } __except(EXCEPTION_EXECUTE_HANDLER) {
	/* do nothing */
    }

#   endif
#else
    /*
     * Don't know how to do assembly code for this compiler and/or
     * architecture.
     */
#endif
    return status;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

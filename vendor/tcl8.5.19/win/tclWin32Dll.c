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

#ifndef TCL_NO_STACK_CHECK
/*
 * The following functions implement stack depth checking
 */
typedef struct ThreadSpecificData {
    int *stackBound;            /* The current stack boundary */
} ThreadSpecificData;
static Tcl_ThreadDataKey dataKey;
#endif /* TCL_NO_STACK_CHECK */

/*
 * The following data structures are used when loading the thunking library
 * for execing child processes under Win32s.
 */

typedef DWORD (WINAPI UT32PROC)(LPVOID lpBuff, DWORD dwUserDefined,
	LPVOID *lpTranslationList);

typedef BOOL (WINAPI UTREGISTER)(HANDLE hModule, LPCSTR SixteenBitDLL,
	LPCSTR InitName, LPCSTR ProcName, UT32PROC **ThirtyTwoBitThunk,
	FARPROC UT32Callback, LPVOID Buff);

typedef VOID (WINAPI UTUNREGISTER)(HANDLE hModule);

/*
 * The following variables keep track of information about this DLL on a
 * per-instance basis. Each time this DLL is loaded, it gets its own new data
 * segment with its own copy of all static and global information.
 */

static HINSTANCE hInstance;	/* HINSTANCE of this DLL. */
static int platformId;		/* Running under NT, or 95/98? */

/*
 * VC++ 5.x has no 'cpuid' assembler instruction, so we must emulate it
 */

#if defined(_MSC_VER) && (_MSC_VER <= 1100)
#define cpuid	__asm __emit 0fh __asm __emit 0a2h
#endif

/*
 * The following function tables are used to dispatch to either the
 * wide-character or multi-byte versions of the operating system calls,
 * depending on whether the Unicode calls are available.
 */

static TclWinProcs asciiProcs = {
    0,

    (BOOL (WINAPI *)(CONST TCHAR *, LPDCB)) BuildCommDCBA,
    (TCHAR *(WINAPI *)(TCHAR *)) CharLowerA,
    (BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR *, BOOL)) CopyFileA,
    (BOOL (WINAPI *)(CONST TCHAR *, LPSECURITY_ATTRIBUTES)) CreateDirectoryA,
    (HANDLE (WINAPI *)(CONST TCHAR *, DWORD, DWORD, SECURITY_ATTRIBUTES *,
	    DWORD, DWORD, HANDLE)) CreateFileA,
    (BOOL (WINAPI *)(CONST TCHAR *, TCHAR *, LPSECURITY_ATTRIBUTES,
	    LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, CONST TCHAR *,
	    LPSTARTUPINFOA, LPPROCESS_INFORMATION)) CreateProcessA,
    (BOOL (WINAPI *)(CONST TCHAR *)) DeleteFileA,
    (HANDLE (WINAPI *)(CONST TCHAR *, WIN32_FIND_DATAT *)) FindFirstFileA,
    (BOOL (WINAPI *)(HANDLE, WIN32_FIND_DATAT *)) FindNextFileA,
    (BOOL (WINAPI *)(WCHAR *, LPDWORD)) GetComputerNameA,
    (DWORD (WINAPI *)(DWORD, WCHAR *)) GetCurrentDirectoryA,
    (DWORD (WINAPI *)(CONST TCHAR *)) GetFileAttributesA,
    (DWORD (WINAPI *)(CONST TCHAR *, DWORD nBufferLength, WCHAR *,
	    TCHAR **)) GetFullPathNameA,
    (DWORD (WINAPI *)(HMODULE, WCHAR *, int)) GetModuleFileNameA,
    (DWORD (WINAPI *)(CONST TCHAR *, WCHAR *, DWORD)) GetShortPathNameA,
    (UINT (WINAPI *)(CONST TCHAR *, CONST TCHAR *, UINT uUnique,
	    WCHAR *)) GetTempFileNameA,
    (DWORD (WINAPI *)(DWORD, WCHAR *)) GetTempPathA,
    (BOOL (WINAPI *)(CONST TCHAR *, WCHAR *, DWORD, LPDWORD, LPDWORD, LPDWORD,
	    WCHAR *, DWORD)) GetVolumeInformationA,
    (HINSTANCE (WINAPI *)(CONST TCHAR *, HANDLE, DWORD)) LoadLibraryExA,
    (TCHAR (WINAPI *)(WCHAR *, CONST TCHAR *)) lstrcpyA,
    (BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR *)) MoveFileA,
    (BOOL (WINAPI *)(CONST TCHAR *)) RemoveDirectoryA,
    (DWORD (WINAPI *)(CONST TCHAR *, CONST TCHAR *, CONST TCHAR *, DWORD,
	    WCHAR *, TCHAR **)) SearchPathA,
    (BOOL (WINAPI *)(CONST TCHAR *)) SetCurrentDirectoryA,
    (BOOL (WINAPI *)(CONST TCHAR *, DWORD)) SetFileAttributesA,

    /*
     * The three NULL function pointers will only be set when
     * Tcl_FindExecutable is called. If you don't ever call that function, the
     * application will crash whenever WinTcl tries to call functions through
     * these null pointers. That is not a bug in Tcl - Tcl_FindExecutable is
     * mandatory in recent Tcl releases.
     */

    NULL,
    NULL,
    /* deleted (int (__cdecl*)(CONST TCHAR *, struct _utimbuf *)) _utime, */
    NULL,
    NULL,
    /* getLongPathNameProc */
    NULL,
    /* Security SDK - not available on 95,98,ME */
    NULL, NULL, NULL, NULL, NULL, NULL,
    /* ReadConsole and WriteConsole */
    (BOOL (WINAPI *)(HANDLE, LPVOID, DWORD, LPDWORD, LPVOID)) ReadConsoleA,
    (BOOL (WINAPI *)(HANDLE, const VOID*, DWORD, LPDWORD, LPVOID)) WriteConsoleA,
    (BOOL (WINAPI *)(LPTSTR, LPDWORD)) GetUserNameA
};

static TclWinProcs unicodeProcs = {
    1,

    (BOOL (WINAPI *)(CONST TCHAR *, LPDCB)) BuildCommDCBW,
    (TCHAR *(WINAPI *)(TCHAR *)) CharLowerW,
    (BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR *, BOOL)) CopyFileW,
    (BOOL (WINAPI *)(CONST TCHAR *, LPSECURITY_ATTRIBUTES)) CreateDirectoryW,
    (HANDLE (WINAPI *)(CONST TCHAR *, DWORD, DWORD, SECURITY_ATTRIBUTES *,
	    DWORD, DWORD, HANDLE)) CreateFileW,
    (BOOL (WINAPI *)(CONST TCHAR *, TCHAR *, LPSECURITY_ATTRIBUTES,
	    LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, CONST TCHAR *,
	    LPSTARTUPINFOA, LPPROCESS_INFORMATION)) CreateProcessW,
    (BOOL (WINAPI *)(CONST TCHAR *)) DeleteFileW,
    (HANDLE (WINAPI *)(CONST TCHAR *, WIN32_FIND_DATAT *)) FindFirstFileW,
    (BOOL (WINAPI *)(HANDLE, WIN32_FIND_DATAT *)) FindNextFileW,
    (BOOL (WINAPI *)(WCHAR *, LPDWORD)) GetComputerNameW,
    (DWORD (WINAPI *)(DWORD, WCHAR *)) GetCurrentDirectoryW,
    (DWORD (WINAPI *)(CONST TCHAR *)) GetFileAttributesW,
    (DWORD (WINAPI *)(CONST TCHAR *, DWORD nBufferLength, WCHAR *,
	    TCHAR **)) GetFullPathNameW,
    (DWORD (WINAPI *)(HMODULE, WCHAR *, int)) GetModuleFileNameW,
    (DWORD (WINAPI *)(CONST TCHAR *, WCHAR *, DWORD)) GetShortPathNameW,
    (UINT (WINAPI *)(CONST TCHAR *, CONST TCHAR *, UINT uUnique,
	    WCHAR *)) GetTempFileNameW,
    (DWORD (WINAPI *)(DWORD, WCHAR *)) GetTempPathW,
    (BOOL (WINAPI *)(CONST TCHAR *, WCHAR *, DWORD, LPDWORD, LPDWORD, LPDWORD,
	    WCHAR *, DWORD)) GetVolumeInformationW,
    (HINSTANCE (WINAPI *)(CONST TCHAR *, HANDLE, DWORD)) LoadLibraryExW,
    (TCHAR (WINAPI *)(WCHAR *, CONST TCHAR *)) lstrcpyW,
    (BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR *)) MoveFileW,
    (BOOL (WINAPI *)(CONST TCHAR *)) RemoveDirectoryW,
    (DWORD (WINAPI *)(CONST TCHAR *, CONST TCHAR *, CONST TCHAR *, DWORD,
	    WCHAR *, TCHAR **)) SearchPathW,
    (BOOL (WINAPI *)(CONST TCHAR *)) SetCurrentDirectoryW,
    (BOOL (WINAPI *)(CONST TCHAR *, DWORD)) SetFileAttributesW,

    /*
     * The three NULL function pointers will only be set when
     * Tcl_FindExecutable is called. If you don't ever call that function, the
     * application will crash whenever WinTcl tries to call functions through
     * these null pointers. That is not a bug in Tcl - Tcl_FindExecutable is
     * mandatory in recent Tcl releases.
     */

    NULL,
    NULL,
    /* deleted (int (__cdecl*)(CONST TCHAR *, struct _utimbuf *)) _wutime, */
    NULL,
    NULL,
    /* getLongPathNameProc */
    NULL,
    /* Security SDK - will be filled in on NT,XP,2000,2003 */
    NULL, NULL, NULL, NULL, NULL, NULL,
    /* ReadConsole and WriteConsole */
    (BOOL (WINAPI *)(HANDLE, LPVOID, DWORD, LPDWORD, LPVOID)) ReadConsoleW,
    (BOOL (WINAPI *)(HANDLE, const VOID*, DWORD, LPDWORD, LPVOID)) WriteConsoleW,
    (BOOL (WINAPI *)(LPTSTR, LPDWORD)) GetUserNameW
};

TclWinProcs *tclWinProcs;
static Tcl_Encoding tclWinTCharEncoding;

#ifdef HAVE_NO_SEH
/*
 * Need to add noinline flag to DllMain declaration so that gcc -O3 does not
 * inline asm code into DllEntryPoint and cause a compile time error because
 * of redefined local labels.
 */

BOOL APIENTRY		DllMain(HINSTANCE hInst, DWORD reason,
			    LPVOID reserved) __attribute__ ((noinline));
#else
/*
 * The following declaration is for the VC++ DLL entry point.
 */

BOOL APIENTRY		DllMain(HINSTANCE hInst, DWORD reason,
			    LPVOID reserved);
#endif /* HAVE_NO_SEH */

/*
 * The following structure and linked list is to allow us to map between
 * volume mount points and drive letters on the fly (no Win API exists for
 * this).
 */

typedef struct MountPointMap {
    CONST WCHAR *volumeName;	/* Native wide string volume name. */
    char driveLetter;		/* Drive letter corresponding to the volume
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

extern Tcl_FSDupInternalRepProc TclNativeDupInternalRep;

#ifdef __WIN32__
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
 *	Establishes 32-to-16 bit thunk and initializes sockets library. This
 *	might call some sycronization functions, but MSDN documentation
 *	states: "Waiting on synchronization objects in DllMain can cause a
 *	deadlock."
 *
 *----------------------------------------------------------------------
 */

BOOL APIENTRY
DllMain(
    HINSTANCE hInst,		/* Library instance handle. */
    DWORD reason,		/* Reason this function is being called. */
    LPVOID reserved)		/* Not used. */
{
#if defined(HAVE_NO_SEH) && !defined(_WIN64)
    TCLEXCEPTION_REGISTRATION registration;
#endif

    switch (reason) {
    case DLL_PROCESS_ATTACH:
	DisableThreadLibraryCalls(hInst);
	TclWinInit(hInst);
	return TRUE;

    case DLL_PROCESS_DETACH:
	/*
	 * Protect the call to Tcl_Finalize. The OS could be unloading us from
	 * an exception handler and the state of the stack might be unstable.
	 */

#if defined(HAVE_NO_SEH) && !defined(_WIN64)
	__asm__ __volatile__ (

	    /*
	     * Construct an TCLEXCEPTION_REGISTRATION to protect the call to
	     * Tcl_Finalize
	     */

	    "leal	%[registration], %%edx"		"\n\t"
	    "movl	%%fs:0,		%%eax"		"\n\t"
	    "movl	%%eax,		0x0(%%edx)"	"\n\t" /* link */
	    "leal	1f,		%%eax"		"\n\t"
	    "movl	%%eax,		0x4(%%edx)"	"\n\t" /* handler */
	    "movl	%%ebp,		0x8(%%edx)"	"\n\t" /* ebp */
	    "movl	%%esp,		0xc(%%edx)"	"\n\t" /* esp */
	    "movl	%[error],	0x10(%%edx)"	"\n\t" /* status */

	    /*
	     * Link the TCLEXCEPTION_REGISTRATION on the chain
	     */

	    "movl	%%edx,		%%fs:0"		"\n\t"

	    /*
	     * Call Tcl_Finalize
	     */

	    "call	_Tcl_Finalize"			"\n\t"

	    /*
	     * Come here on a normal exit. Recover the TCLEXCEPTION_REGISTRATION
	     * and store a TCL_OK status
	     */

	    "movl	%%fs:0,		%%edx"		"\n\t"
	    "movl	%[ok],		%%eax"		"\n\t"
	    "movl	%%eax,		0x10(%%edx)"	"\n\t"
	    "jmp	2f"				"\n"

	    /*
	     * Come here on an exception. Get the TCLEXCEPTION_REGISTRATION that
	     * we previously put on the chain.
	     */

	    "1:"					"\t"
	    "movl	%%fs:0,		%%edx"		"\n\t"
	    "movl	0x8(%%edx),	%%edx"		"\n"


	    /*
	     * Come here however we exited. Restore context from the
	     * TCLEXCEPTION_REGISTRATION in case the stack is unbalanced.
	     */

	    "2:"					"\t"
	    "movl	0xc(%%edx),	%%esp"		"\n\t"
	    "movl	0x8(%%edx),	%%ebp"		"\n\t"
	    "movl	0x0(%%edx),	%%eax"		"\n\t"
	    "movl	%%eax,		%%fs:0"		"\n\t"

	    :
	    /* No outputs */
	    :
	    [registration]	"m"	(registration),
	    [ok]		"i"	(TCL_OK),
	    [error]		"i"	(TCL_ERROR)
	    :
	    "%eax", "%ebx", "%ecx", "%edx", "%esi", "%edi", "memory"
	    );

#else
#ifndef HAVE_NO_SEH
	__try {
#endif
	    Tcl_Finalize();
#ifndef HAVE_NO_SEH
	} __except (EXCEPTION_EXECUTE_HANDLER) {
	    /* empty handler body. */
	}
#endif
#endif

	break;
    }

    return TRUE;
}
#endif /* !STATIC_BUILD */
#endif /* __WIN32__ */

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
    platformId = os.dwPlatformId;

    /*
     * We no longer support Win32s, so just in case someone manages to get a
     * runtime there, make sure they know that.
     */

    if (platformId == VER_PLATFORM_WIN32s) {
	Tcl_Panic("Win32s is not a supported platform");
    }

    tclWinProcs = &asciiProcs;
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
 *	The return value is one of:
 *	    VER_PLATFORM_WIN32s		Win32s on Windows 3.1. (not supported)
 *	    VER_PLATFORM_WIN32_WINDOWS	Win32 on Windows 95, 98, ME.
 *	    VER_PLATFORM_WIN32_NT	Win32 on Windows NT, 2000, XP
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclWinGetPlatformId(void)
{
    return platformId;
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
 *----------------------------------------------------------------------
 *
 * TclpGetStackParams --
 *
 *	Determine the stack params for the current thread: in which
 *	direction does the stack grow, and what is the stack lower (resp.
 *	upper) bound for safe invocation of a new command? This is used to
 *	cache the values needed for an efficient computation of
 *	TclpCheckStackSpace() when the interp is known.
 *
 * Results:
 *	Returns 1 if the stack grows down, in which case a stack lower bound
 *	is stored at stackBoundPtr. If the stack grows up, 0 is returned and
 *	an upper bound is stored at stackBoundPtr. If a bound cannot be
 *	determined NULL is stored at stackBoundPtr.
 *
 *----------------------------------------------------------------------
 */

#ifndef TCL_NO_STACK_CHECK
int
TclpGetCStackParams(
    int **stackBoundPtr)
{
    ThreadSpecificData *tsdPtr = TCL_TSD_INIT(&dataKey);
    SYSTEM_INFO si;		/* The system information, used to
				 * determine the page size */
    MEMORY_BASIC_INFORMATION mbi;
				/* The information about the memory
				 * area in which the stack resides */

    if (!tsdPtr->stackBound
	|| ((UINT_PTR)&tsdPtr < (UINT_PTR)tsdPtr->stackBound)) {

	/* 
	 * Either we haven't determined the stack bound in this thread,
	 * or else we've overflowed the bound that we previously
	 * determined.  We need to find a new stack bound from
	 * Windows.
	 */

	GetSystemInfo(&si);
	if (VirtualQuery((LPCVOID) &tsdPtr, &mbi, sizeof(mbi)) == 0) {

	    /* For some reason, the system didn't let us query the
	     * stack size.  Nevertheless, we got here and haven't
	     * blown up yet.  Don't update the calculated stack bound.
	     * If there is no calculated stack bound yet, set it to
	     * the base of the current page of stack. */

	    if (!tsdPtr->stackBound) {
		tsdPtr->stackBound =
		    (int*) ((UINT_PTR)(&tsdPtr)
			    & ~ (UINT_PTR)(si.dwPageSize - 1));
	    }

	} else {

	    /* The allocation base of the stack segment has to be advanced
	     * by one page (to allow for the guard page maintained in the
	     * C runtime) and then by TCL_WIN_STACK_THRESHOLD (to allow
	     * for the amount of stack that Tcl needs).
	     */

	    tsdPtr->stackBound =
		(int*) ((UINT_PTR)(mbi.AllocationBase)
			+ (UINT_PTR)(si.dwPageSize)
			+ TCL_WIN_STACK_THRESHOLD);
	}
    }
    *stackBoundPtr = tsdPtr->stackBound;
    return 1;
}
#endif


/*
 *---------------------------------------------------------------------------
 *
 * TclWinSetInterfaces --
 *
 *	A helper proc that allows the test library to change the tclWinProcs
 *	structure to dispatch to either the wide-character or multi-byte
 *	versions of the operating system calls, depending on whether Unicode
 *	is the system encoding.
 *
 *	As well as this, we can also try to load in some additional procs
 *	which may/may not be present depending on the current Windows version
 *	(e.g. Win95 will not have the procs below).
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
TclWinSetInterfaces(
    int wide)			/* Non-zero to use wide interfaces, 0
				 * otherwise. */
{
    Tcl_FreeEncoding(tclWinTCharEncoding);

    if (wide) {
	tclWinProcs = &unicodeProcs;
	tclWinTCharEncoding = Tcl_GetEncoding(NULL, "unicode");
	if (tclWinProcs->getFileAttributesExProc == NULL) {
	    HINSTANCE hInstance = LoadLibraryA("kernel32");
	    if (hInstance != NULL) {
		tclWinProcs->getFileAttributesExProc =
			(BOOL (WINAPI *)(CONST TCHAR *, GET_FILEEX_INFO_LEVELS,
			LPVOID)) GetProcAddress(hInstance,
			"GetFileAttributesExW");
		tclWinProcs->createHardLinkProc =
			(BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR*,
			LPSECURITY_ATTRIBUTES)) GetProcAddress(hInstance,
			"CreateHardLinkW");
		tclWinProcs->findFirstFileExProc =
			(HANDLE (WINAPI *)(CONST TCHAR*, UINT, LPVOID, UINT,
			LPVOID, DWORD)) GetProcAddress(hInstance,
			"FindFirstFileExW");
		tclWinProcs->getVolumeNameForVMPProc =
			(BOOL (WINAPI *)(CONST TCHAR*, TCHAR*,
			DWORD)) GetProcAddress(hInstance,
			"GetVolumeNameForVolumeMountPointW");
		tclWinProcs->getLongPathNameProc =
			(DWORD (WINAPI *)(CONST TCHAR*, TCHAR*,
			DWORD)) GetProcAddress(hInstance, "GetLongPathNameW");
		FreeLibrary(hInstance);
	    }
	    hInstance = LoadLibraryA("advapi32");
	    if (hInstance != NULL) {
		tclWinProcs->getFileSecurityProc = (BOOL (WINAPI *)(
			LPCTSTR lpFileName,
			SECURITY_INFORMATION RequestedInformation,
			PSECURITY_DESCRIPTOR pSecurityDescriptor,
			DWORD nLength, LPDWORD lpnLengthNeeded))
			GetProcAddress(hInstance, "GetFileSecurityW");
		tclWinProcs->impersonateSelfProc = (BOOL (WINAPI *) (
			SECURITY_IMPERSONATION_LEVEL ImpersonationLevel))
			GetProcAddress(hInstance, "ImpersonateSelf");
		tclWinProcs->openThreadTokenProc = (BOOL (WINAPI *) (
			HANDLE ThreadHandle, DWORD DesiredAccess,
			BOOL OpenAsSelf, PHANDLE TokenHandle))
			GetProcAddress(hInstance, "OpenThreadToken");
		tclWinProcs->revertToSelfProc = (BOOL (WINAPI *) (void))
			GetProcAddress(hInstance, "RevertToSelf");
		tclWinProcs->mapGenericMaskProc = (VOID (WINAPI *) (
			PDWORD AccessMask, PGENERIC_MAPPING GenericMapping))
			GetProcAddress(hInstance, "MapGenericMask");
		tclWinProcs->accessCheckProc = (BOOL (WINAPI *)(
			PSECURITY_DESCRIPTOR pSecurityDescriptor,
			HANDLE ClientToken, DWORD DesiredAccess,
			PGENERIC_MAPPING GenericMapping,
			PPRIVILEGE_SET PrivilegeSet,
			LPDWORD PrivilegeSetLength, LPDWORD GrantedAccess,
			LPBOOL AccessStatus)) GetProcAddress(hInstance,
			"AccessCheck");
		FreeLibrary(hInstance);
	    }
	}
    } else {
	tclWinProcs = &asciiProcs;
	tclWinTCharEncoding = NULL;
	if (tclWinProcs->getFileAttributesExProc == NULL) {
	    HINSTANCE hInstance = LoadLibraryA("kernel32");
	    if (hInstance != NULL) {
		tclWinProcs->getFileAttributesExProc =
			(BOOL (WINAPI *)(CONST TCHAR *, GET_FILEEX_INFO_LEVELS,
			LPVOID)) GetProcAddress(hInstance,
			"GetFileAttributesExA");
		tclWinProcs->createHardLinkProc =
			(BOOL (WINAPI *)(CONST TCHAR *, CONST TCHAR*,
			LPSECURITY_ATTRIBUTES)) GetProcAddress(hInstance,
			"CreateHardLinkA");
		tclWinProcs->findFirstFileExProc = NULL;
		tclWinProcs->getLongPathNameProc = NULL;
		/*
		 * The 'findFirstFileExProc' function exists on some of
		 * 95/98/ME, but it seems not to work as anticipated.
		 * Therefore we don't set this function pointer. The relevant
		 * code will fall back on a slower approach using the normal
		 * findFirstFileProc.
		 *
		 * (HANDLE (WINAPI *)(CONST TCHAR*, UINT,
		 * LPVOID, UINT, LPVOID, DWORD)) GetProcAddress(hInstance,
		 * "FindFirstFileExA");
		 */
		tclWinProcs->getVolumeNameForVMPProc =
			(BOOL (WINAPI *)(CONST TCHAR*, TCHAR*,
			DWORD)) GetProcAddress(hInstance,
			"GetVolumeNameForVolumeMountPointA");
		FreeLibrary(hInstance);
	    }
	}
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * TclWinResetInterfaceEncodings --
 *
 *	Called during finalization to free up any encodings we use. The
 *	tclWinProcs-> look up table is still ok to use after this call,
 *	provided no encoding conversion is required.
 *
 *	We also clean up any memory allocated in our mount point map which is
 *	used to follow certain kinds of symlinks. That code should never be
 *	used once encodings are taken down.
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
TclWinResetInterfaceEncodings(void)
{
    MountPointMap *dlIter, *dlIter2;
    if (tclWinTCharEncoding != NULL) {
	Tcl_FreeEncoding(tclWinTCharEncoding);
	tclWinTCharEncoding = NULL;
    }

    /*
     * Clean up the mount point map.
     */

    Tcl_MutexLock(&mountPointMap);
    dlIter = driveLetterLookup;
    while (dlIter != NULL) {
	dlIter2 = dlIter->nextPtr;
	ckfree((char*)dlIter->volumeName);
	ckfree((char*)dlIter);
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
 *	After this call, it is best not to use the tclWinProcs-> look up table
 *	since it is likely to be different to what is expected.
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
    tclWinProcs = &asciiProcs;
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
    CONST WCHAR *mountPoint)
{
    MountPointMap *dlIter, *dlPtr2;
    WCHAR Target[55];		/* Target of mount at mount point */
    WCHAR drive[4] = { L'A', L':', L'\\', L'\0' };

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

	    drive[0] = L'A' + (dlIter->driveLetter - 'A');

	    /*
	     * Try to read the volume mount point and see where it points.
	     */

	    if ((*tclWinProcs->getVolumeNameForVMPProc)((TCHAR*)drive,
		    (TCHAR*)Target, 55) != 0) {
		if (wcscmp((WCHAR*)dlIter->volumeName, Target) == 0) {
		    /*
		     * Nothing has changed.
		     */

		    Tcl_MutexUnlock(&mountPointMap);
		    return dlIter->driveLetter;
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

	    ckfree((char*)dlPtr2->volumeName);
	    ckfree((char*)dlPtr2);

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

    for (drive[0] = L'A'; drive[0] <= L'Z'; drive[0]++) {
	/*
	 * Try to read the volume mount point and see where it points.
	 */

	if ((*tclWinProcs->getVolumeNameForVMPProc)((TCHAR*)drive,
		(TCHAR*)Target, 55) != 0) {
	    int alreadyStored = 0;

	    for (dlIter = driveLetterLookup; dlIter != NULL;
		    dlIter = dlIter->nextPtr) {
		if (wcscmp((WCHAR*)dlIter->volumeName, Target) == 0) {
		    alreadyStored = 1;
		    break;
		}
	    }
	    if (!alreadyStored) {
		dlPtr2 = (MountPointMap *) ckalloc(sizeof(MountPointMap));
		dlPtr2->volumeName = TclNativeDupInternalRep(Target);
		dlPtr2->driveLetter = 'A' + (drive[0] - L'A');
		dlPtr2->nextPtr = driveLetterLookup;
		driveLetterLookup  = dlPtr2;
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
	    return dlIter->driveLetter;
	}
    }

    /*
     * The volume doesn't appear to correspond to a drive letter - we remember
     * that fact and store '-1' so we don't have to look it up each time.
     */

    dlPtr2 = (MountPointMap*) ckalloc(sizeof(MountPointMap));
    dlPtr2->volumeName = TclNativeDupInternalRep((ClientData)mountPoint);
    dlPtr2->driveLetter = -1;
    dlPtr2->nextPtr = driveLetterLookup;
    driveLetterLookup  = dlPtr2;
    Tcl_MutexUnlock(&mountPointMap);
    return -1;
}

/*
 *---------------------------------------------------------------------------
 *
 * Tcl_WinUtfToTChar, Tcl_WinTCharToUtf --
 *
 *	Convert between UTF-8 and Unicode when running Windows NT or the
 *	current ANSI code page when running Windows 95.
 *
 *	On Mac, Unix, and Windows 95, all strings exchanged between Tcl and
 *	the OS are "char" oriented. We need only one Tcl_Encoding to convert
 *	between UTF-8 and the system's native encoding. We use NULL to
 *	represent that encoding.
 *
 *	On NT, some strings exchanged between Tcl and the OS are "char"
 *	oriented, while others are in Unicode. We need two Tcl_Encoding APIs
 *	depending on whether we are targeting a "char" or Unicode interface.
 *
 *	Calling Tcl_UtfToExternal() or Tcl_ExternalToUtf() with an encoding of
 *	NULL should always used to convert between UTF-8 and the system's
 *	"char" oriented encoding. The following two functions are used in
 *	Windows-specific code to convert between UTF-8 and Unicode strings
 *	(NT) or "char" strings(95). This saves you the trouble of writing the
 *	following type of fragment over and over:
 *
 *		if (running NT) {
 *		    encoding <- Tcl_GetEncoding("unicode");
 *		    nativeBuffer <- UtfToExternal(encoding, utfBuffer);
 *		    Tcl_FreeEncoding(encoding);
 *		} else {
 *		    nativeBuffer <- UtfToExternal(NULL, utfBuffer);
 *		}
 *
 *	By convention, in Windows a TCHAR is a character in the ANSI code page
 *	on Windows 95, a Unicode character on Windows NT. If you plan on
 *	targeting a Unicode interfaces when running on NT and a "char"
 *	oriented interface while running on 95, these functions should be
 *	used. If you plan on targetting the same "char" oriented function on
 *	both 95 and NT, use Tcl_UtfToExternal() with an encoding of NULL.
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
    CONST char *string,		/* Source string in UTF-8. */
    int len,			/* Source string length in bytes, or < 0 for
				 * strlen(). */
    Tcl_DString *dsPtr)		/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
    return (TCHAR *) Tcl_UtfToExternalDString(tclWinTCharEncoding,
	    string, len, dsPtr);
}

char *
Tcl_WinTCharToUtf(
    CONST TCHAR *string,	/* Source string in Unicode when running NT,
				 * ANSI when running 95. */
    int len,			/* Source string length in bytes, or < 0 for
				 * platform-specific string length. */
    Tcl_DString *dsPtr)		/* Uninitialized or free DString in which the
				 * converted string is stored. */
{
    return Tcl_ExternalToUtfDString(tclWinTCharEncoding,
	    (CONST char *) string, len, dsPtr);
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

#if defined(__GNUC__)
#   if defined(_WIN64)
    /*
     * Execute the CPUID instruction with the given index, and store results
     * off 'regsPtr'.
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
	"movl	%%edx,		0xc(%%edi)"	"\n\t"

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
	"movl	%%esp,		0xc(%%edx)"	"\n\t" /* esp */
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
	"movl	%%edx,		0xc(%%edi)"	"\n\t"

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
	"movl	0xc(%%edx),	%%esp"		"\n\t"
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

#   else
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

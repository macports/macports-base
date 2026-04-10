/*
 * tclStubCall.c --
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#ifndef _WIN32
#   include <dlfcn.h>
#else
#   define dlopen(a,b) (void *)LoadLibraryW(JOIN(L,a))
#   define dlsym(a,b) (void *)GetProcAddress((HMODULE)(a),b)
#   define dlerror() ""
#endif

MODULE_SCOPE void *tclStubsHandle;

/*
 *----------------------------------------------------------------------
 *
 * TclStubCall --
 *
 *	Load the Tcl core dynamically, version "9.0" (or higher, in future versions).
 *
 * Results:
 *	Returns a function from the Tcl dynamic library or a function
 *	returning NULL if that function cannot be found. See PROCNAME table.
 *
 *	The functions Tcl_MainEx and Tcl_MainExW never return.
 *	Tcl_GetMemoryInfo and Tcl_StaticLibrary return (void),
 *	Tcl_SetExitProc returns its previous exitProc and
 *	Tcl_SetPreInitScript returns the previous script. This means that
 *	those 6 functions cannot be used to initialize the stub-table,
 *	only the first 4 functions in the table can do that.
 *
 *----------------------------------------------------------------------
 */

/* Table containing which function will be returned, depending on the "arg" */
static const char PROCNAME[][24] = {
    "_Tcl_SetPanicProc", /* Default, whenever "arg" <= 0 or "arg" > 9 */
    "_Tcl_InitSubsystems", /* "arg" == (void *)1 */
    "_Tcl_FindExecutable", /* "arg" == (void *)2 */
    "_TclZipfs_AppHook", /* "arg" == (void *)3 */
    "_Tcl_MainExW", /* "arg" == (void *)4 */
    "_Tcl_MainEx", /* "arg" == (void *)5 */
    "_Tcl_StaticLibrary", /* "arg" == (void *)6 */
    "_Tcl_SetExitProc", /* "arg" == (void *)7 */
    "_Tcl_GetMemoryInfo", /* "arg" == (void *)8 */
    "_Tcl_SetPreInitScript" /* "arg" == (void *)9 */
};

MODULE_SCOPE const void *nullVersionProc(void) {
	return NULL;
}

static const char CANNOTCALL[] = "Cannot call %s from stubbed extension\n";
static const char CANNOTFIND[] = "Cannot find %s: %s\n";

MODULE_SCOPE void *
TclStubCall(void *arg)
{
    static void *stubFn[] = {NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL};
    size_t index = PTR2UINT(arg);

    if (index >= sizeof(PROCNAME)/sizeof(PROCNAME[0])) {
	/* Any other value means Tcl_SetPanicProc() with non-null panicProc */
	index = 0;
    }
    if (tclStubsHandle == INT2PTR(-1)) {
	if ((index == 0) && (arg != NULL)) {
	    ((Tcl_PanicProc *)arg)(CANNOTCALL, PROCNAME[index] + 1);
	} else {
	    fprintf(stderr, CANNOTCALL, PROCNAME[index] + 1);
	    abort();
	}
    }
    if (!stubFn[index]) {
	if (!tclStubsHandle) {
	    tclStubsHandle = dlopen(CFG_RUNTIME_DLLFILE, RTLD_NOW|RTLD_LOCAL);
	    if (!tclStubsHandle) {
#if defined(_WIN32)
		tclStubsHandle = dlopen(CFG_RUNTIME_BINDIR "\\" CFG_RUNTIME_DLLFILE, RTLD_NOW|RTLD_LOCAL);
#elif defined(__CYGWIN__)
		tclStubsHandle = dlopen(CFG_RUNTIME_BINDIR "/" CFG_RUNTIME_DLLFILE, RTLD_NOW|RTLD_LOCAL);
#else
		tclStubsHandle = dlopen(CFG_RUNTIME_LIBDIR "/" CFG_RUNTIME_DLLFILE, RTLD_NOW|RTLD_LOCAL);
#endif
	    }
	    if (!tclStubsHandle) {
		if ((index == 0) && (arg != NULL)) {
		    ((Tcl_PanicProc *)arg)(CANNOTFIND, CFG_RUNTIME_DLLFILE, dlerror());
		} else {
		    fprintf(stderr, CANNOTFIND, CFG_RUNTIME_DLLFILE, dlerror());
		    abort();
		}
	    }
	}
	stubFn[index] = dlsym(tclStubsHandle, PROCNAME[index] + 1);
	if (!stubFn[index]) {
	    stubFn[index] = dlsym(tclStubsHandle, PROCNAME[index]);
	    if (!stubFn[index]) {
		stubFn[index] = (void *)nullVersionProc;
	    }
	}
    }
    return stubFn[index];
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

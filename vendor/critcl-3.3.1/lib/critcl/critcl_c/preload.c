/*
 * pre-load a shared library
 *   - for situations where a Tcl package depends on another library
 *   - will be superceded by the functionality in TIP #239
 *   - based on tclLoad.c from Tcl 8.4.13 and MyInitTclStubs from Critcl
 */

#include "tcl.h"

TclStubs *tclStubsPtr;
TclPlatStubs *tclPlatStubsPtr;
struct TclIntStubs *tclIntStubsPtr;
struct TclIntPlatStubs *tclIntPlatStubsPtr;

static int
MyInitTclStubs (Tcl_Interp *ip)
{
    typedef struct {
      char *result;
      Tcl_FreeProc *freeProc;
      int errorLine;
      TclStubs *stubTable;
    } HeadOfInterp;

    HeadOfInterp *hoi = (HeadOfInterp*) ip;
 
    if (hoi->stubTable == NULL || hoi->stubTable->magic != TCL_STUB_MAGIC) {
      ip->result = "This extension requires stubs-support.";
      ip->freeProc = TCL_STATIC;
      return 0;
    }

    tclStubsPtr = hoi->stubTable;

    if (Tcl_PkgRequire(ip, "Tcl", "8.1", 0) == NULL) {
      tclStubsPtr = NULL;
      return 0;
    }

    if (tclStubsPtr->hooks != NULL) {
        tclPlatStubsPtr = tclStubsPtr->hooks->tclPlatStubs;
        tclIntStubsPtr = tclStubsPtr->hooks->tclIntStubs;
        tclIntPlatStubsPtr = tclStubsPtr->hooks->tclIntPlatStubs;
    }
 
    return 1;
} 

#ifdef WIN32

#include <windows.h>

typedef struct PreloadInfo {
    Tcl_Obj *dir;
    Tcl_LoadHandle handle;
} PreloadInfo;

static void
removeDLLCopy(ClientData clientData) {
    PreloadInfo *preload = (PreloadInfo *) clientData;
    Tcl_Obj *dir = preload->dir;
    Tcl_LoadHandle handle = preload->handle;
    Tcl_Obj *errorPtr;

    // no idea why, but we have to call FreeLibrary twice for the subsequent
    // Tcl_FSRemoveDirectory to work
    FreeLibrary((HINSTANCE) handle);
    FreeLibrary((HINSTANCE) handle);

    if (Tcl_FSRemoveDirectory(dir, 1, &errorPtr) != TCL_OK) {
	fprintf(stderr, "error removing dir = %s\n", Tcl_GetString(errorPtr));
    }
}

#endif

TCL_DECLARE_MUTEX(packageMutex)

static int
Critcl_Preload(
    ClientData dummy,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *objv[])
{
    int code;
    Tcl_PackageInitProc *proc1, *proc2;
    Tcl_LoadHandle loadHandle;
    Tcl_FSUnloadFileProc *unLoadProcPtr = NULL;
    Tcl_Filesystem *fsPtr;
#ifdef WIN32
    PreloadInfo	*preload = NULL;
#endif

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "fileName");
        return TCL_ERROR;
    }
    if (Tcl_FSConvertToPathType(interp, objv[1]) != TCL_OK) {
        return TCL_ERROR;
    }

#ifdef WIN32
    // if the filesystem holding the dll doesn't support direct loading
    // we need to copy it to a temporary directory and load it from there
    //  - The command "critcl::runtime::precopy" is defined by the support
    //    file "critcl/lib/app-critcl/runtime.tcl". At load time this is
    //    the file "critcl-rt.tcl", sibling to "pkgIndex.tcl".

    if ((fsPtr = Tcl_FSGetFileSystemForPath(objv[1])) != NULL \
		&& fsPtr->loadFileProc == NULL) {
	int len;
	Tcl_Obj *dirs;
	objv[0] = Tcl_NewStringObj("::critcl::runtime::precopy", -1);
	if ((code = Tcl_EvalObjv(interp, 2, objv, 0)) != TCL_OK) {
	    Tcl_SetErrorCode(interp, "could not preload ",
				      Tcl_GetString(objv[1]), 0);
	    return TCL_ERROR;
	}
	objv[1] = Tcl_GetObjResult(interp);
	Tcl_IncrRefCount(objv[1]);
	dirs = Tcl_FSSplitPath(objv[1], &len);
	preload = (PreloadInfo *) ckalloc(sizeof(PreloadInfo));
	preload->dir = Tcl_FSJoinPath(dirs, --len);
	Tcl_IncrRefCount(preload->dir);
    }
#endif

    Tcl_MutexLock(&packageMutex);
    code = Tcl_FSLoadFile(interp, objv[1], NULL, NULL, NULL, NULL,
				  &loadHandle, &unLoadProcPtr);
    Tcl_MutexUnlock(&packageMutex);
#ifdef WIN32
    if (preload) {
	preload->handle = loadHandle;
	Tcl_CreateExitHandler(removeDLLCopy, (ClientData) preload);
    }
#endif
    return code;
}

DLLEXPORT int
Preload_Init(Tcl_Interp *interp)
{
    if (!MyInitTclStubs(interp)) 
        return TCL_ERROR;
    // The Tcl command can't be "preload" because the Tcl source might
    // be copied into the target package (so Tcl procs are available)
    // and we want critcl::runtime::preload to then be a no-op because
    // the preloading is done from the loadlib command when the target
    // package is loaded
    Tcl_CreateObjCommand(interp, "::critcl::runtime::preload", Critcl_Preload, NULL, 0);
    return 0;
}

DLLEXPORT int
Preload_SafeInit(Tcl_Interp *interp)
{
    if (!MyInitTclStubs(interp)) 
        return TCL_ERROR;
    Tcl_CreateObjCommand(interp, "::critcl::runtime::preload", Critcl_Preload, NULL, 0);
    return 0;
}

DLLEXPORT int
Preload_Unload(Tcl_Interp *interp) {}

DLLEXPORT int
Preload_SafeUnload(Tcl_Interp *interp) {}

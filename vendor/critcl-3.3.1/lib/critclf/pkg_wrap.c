/* Simple wrapper
*/
/* Include files
*/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include <float.h>

#include "tcl.h"

#define EXPORT_FUNC __declspec(dllexport)

EXPORT_FUNC int PKGINIT_Init( Tcl_Interp *interp ) ;

#include "wrapfort_lib.c"

static Tcl_Interp *saved_interp; /* TODO: allow several interpreters! */

#if defined(__unix)
#define __stdcall
#endif
#include "FILENAME"


#ifdef CRITCLF
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
#endif

int PKGINIT_Init( Tcl_Interp *interp )
{
   int retcode ;
   int error   ;

/* Register the Fortran logical values
*/
/* TODO
   ftcl_init_log( &ftcl_true, &ftcl_false ) ;
*/

/* Initialise the stubs
*/
#ifdef USE_TCL_STUBS
#ifndef CRITCLF
    if (Tcl_InitStubs(interp, "8.0", 0) == NULL) {
       return TCL_ERROR;
    }
#else
    if (MyInitTclStubs(interp) == 0) {
       return TCL_ERROR;
    }
#endif
#endif


/* Inquire about the package's version
*/
    if (Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 0) == NULL)
    {
       if (TCL_VERSION[0] == '7')
       {
          if (Tcl_PkgRequire(interp, "Tcl", "8.0", 0) == NULL)
          {
             return TCL_ERROR;
          }
       }
    }

    if (Tcl_PkgProvide(interp, "PKGNAME", "1.0") != TCL_OK)
    {
       return TCL_ERROR;
    }

/* Register the package's commands
*/
   retcode = TCL_OK ;

#include "TCLFNAME"

   return retcode ;
}

/* End of file ftempl.c */

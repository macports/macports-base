/* struct::set - critcl - layer 3 declarations
 * Set commands.
 */

#ifndef _M_H
#define _M_H 1

#include "tcl.h"

int sm_ADD	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_CONTAINS	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_DIFFERENCE  (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_EMPTY	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_EQUAL	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_EXCLUDE	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_INCLUDE	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_INTERSECT   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_INTERSECT3  (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_SIZE        (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_SUBSETOF	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_SUBTRACT	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_SYMDIFF	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int sm_UNION	   (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

#endif /* _M_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

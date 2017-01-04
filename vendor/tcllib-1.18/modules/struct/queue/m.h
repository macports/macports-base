/* struct::queue - critcl - layer 3 declarations
 * Method functions.
 */

#ifndef _M_H
#define _M_H 1

#include "tcl.h"
#include <q.h>

int qum_CLEAR   (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int qum_DESTROY (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int qum_PEEK    (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int get);
int qum_PUT     (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int qum_UNGET   (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int qum_SIZE    (Q* qd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

#endif /* _M_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

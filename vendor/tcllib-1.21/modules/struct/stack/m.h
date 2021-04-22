/* struct::stack - critcl - layer 3 declarations
 * Method functions.
 */

#ifndef _M_H
#define _M_H 1

#include "tcl.h"
#include <s.h>

int stm_CLEAR   (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int stm_DESTROY (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int stm_PEEK    (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int pop, int revers);
int stm_PUSH    (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int stm_ROTATE  (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int stm_SIZE    (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int stm_GET     (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int revers);
int stm_TRIM    (S* sd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int ret);

#endif /* _M_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::tree - critcl - layer 3 declarations
 * Method functions.
 */

#ifndef _M_H
#define _M_H 1

#include "tcl.h"
#include <t.h>

int tm_TASSIGN	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_TSET	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_ANCESTORS   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_APPEND	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_ATTR	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_CHILDREN	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_CUT	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_DELETE	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_DEPTH	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_DESCENDANTS (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_DESERIALIZE (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_DESTROY	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_EXISTS	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_GET	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_GETALL	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_HEIGHT	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_INDEX	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_INSERT	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_ISLEAF	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_KEYEXISTS   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_KEYS	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_LAPPEND	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_LEAVES	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_MOVE	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_NEXT	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_NODES	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_NUMCHILDREN (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_PARENT	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_PREVIOUS	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_RENAME	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_ROOTNAME	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_SERIALIZE   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_SET	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_SIZE	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_SPLICE	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_SWAP	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_UNSET	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_WALK	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int tm_WALKPROC	   (T* td, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

#endif /* _M_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::graph - critcl - layer 3 declarations
 * Method functions.
 */

#ifndef _G_METHODS_H
#define _G_METHODS_H 1

#include "tcl.h"
#include <ds.h>

int gm_APPEND	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_ARCS	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_DESERIALIZE    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_DESTROY	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_GASSIGN	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_GET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_GETALL	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_GSET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_KEYEXISTS      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_KEYS	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_LAPPEND	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_NODES	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_SERIALIZE      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_SET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_SWAP	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_UNSET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_WALK	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);

int gm_arc_APPEND     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_ATTR	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_DELETE     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_EXISTS     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_GET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_GETALL     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_GETUNWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_GETWEIGHT  (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_HASWEIGHT  (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_INSERT     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_KEYEXISTS  (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_KEYS	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_LAPPEND    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_RENAME     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_SET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_SETUNWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_SETWEIGHT  (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_SOURCE     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_TARGET     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_UNSET      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_UNSETWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_arc_WEIGHTS    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);

int gm_node_APPEND    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_ATTR      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_DEGREE    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_DELETE    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_EXISTS    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_GET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_GETALL    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_INSERT    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_KEYEXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_KEYS      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_LAPPEND   (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_OPPOSITE  (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_RENAME    (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_SET	      (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);
int gm_node_UNSET     (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv);

#endif /* _G_METHODS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

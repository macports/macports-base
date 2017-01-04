/* struct::graph - critcl - layer 1 declarations
 * (b) Node operations.
 */

#ifndef _G_NODE_H
#define _G_NODE_H 1

#include "tcl.h"
#include <ds.h>

void gn_shimmer  (Tcl_Obj* o, GN* n);
GN*  gn_get_node (G* g, Tcl_Obj* node, Tcl_Interp* interp, Tcl_Obj* graph);

#define gn_shimmer_self(n) \
    gn_shimmer ((n)->base.name, (n))

GN*  gn_new    (G* g, const char* name);
GN*  gn_dup    (G* dst, GN* src);
void gn_delete (GN* n);

void gn_err_duplicate (Tcl_Interp* interp, Tcl_Obj* n, Tcl_Obj* g);
void gn_err_missing   (Tcl_Interp* interp, Tcl_Obj* n, Tcl_Obj* g);

Tcl_Obj* gn_serial_arcs (GN* n, Tcl_Obj* empty, Tcl_HashTable* cn);

#endif /* _G_NODE_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

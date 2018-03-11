/* struct::graph - critcl - layer 1 declarations
 * (b) Node operations.
 */

#ifndef _G_ARC_H
#define _G_ARC_H 1

#include "tcl.h"
#include <ds.h>

void ga_shimmer (Tcl_Obj* o, GA* a);
GA*  ga_get_arc (G* g, Tcl_Obj* arc, Tcl_Interp* interp, Tcl_Obj* graph);

#define ga_shimmer_self(a) \
    ga_shimmer ((a)->base.name, (a))

GA*  ga_new    (G* g, const char* name, GN* src, GN* dst);
GA*  ga_dup    (G* dst, GA* src);
void ga_delete (GA* a);

void ga_arc	  (GA* a);
void ga_notarc	  (GA* a);

void ga_mv_src (GA* a, GN* nsrc);
void ga_mv_dst (GA* a, GN* ndst);

void ga_err_duplicate (Tcl_Interp* interp, Tcl_Obj* a, Tcl_Obj* g);
void ga_err_missing   (Tcl_Interp* interp, Tcl_Obj* a, Tcl_Obj* g);

Tcl_Obj* ga_serial (GA* a, Tcl_Obj* empty, int nodeId);

#endif /* _G_ARC_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

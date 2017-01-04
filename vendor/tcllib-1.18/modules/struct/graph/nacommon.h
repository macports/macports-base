/* struct::graph - critcl - layer 1 declarations
 * (c) Graph functions
 */

#ifndef _G_NACOMMON_H
#define _G_NACOMMON_H 1
/* .................................................. */

#include "tcl.h"
#include <ds.h>

/* .................................................. */

typedef enum attr_mode {
    A_LIST, A_GLOB, A_REGEXP, A_NONE
} attr_mode;

/* .................................................. */

void        gc_add    (GC* c, GCC* gx);
void        gc_remove (GC* c, GCC* gx);
void        gc_setup  (GC* c, GCC* gx, const char* name, G* g);
void        gc_delete (GC* c);
void        gc_rename (GC* c, GCC* gx, Tcl_Obj* newname, Tcl_Interp* interp);

int         gc_filter (int nodes, Tcl_Interp* interp,
		       int oc, Tcl_Obj* const* ov,
		       GCC* gx, GN_GET_GC* gf, G* g);

/* .................................................. */
#endif /* _G_NACOMMON_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

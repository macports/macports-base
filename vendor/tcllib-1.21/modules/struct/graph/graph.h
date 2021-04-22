/* struct::graph - critcl - layer 1 declarations
 * (c) Graph functions
 */

#ifndef _G_GRAPH_H
#define _G_GRAPH_H 1
/* .................................................. */

#include "tcl.h"
#include <ds.h>

/* .................................................. */

G*          g_new         (void);
void        g_delete      (G* g);

const char* g_newnodename (G* g);
const char* g_newarcname  (G* g);

Tcl_Obj*    g_serialize   (Tcl_Interp* interp, Tcl_Obj* go,
			   G* g, int oc, Tcl_Obj* const* ov);
int         g_deserialize (G* dst, Tcl_Interp* interp, Tcl_Obj* src);
int         g_assign      (G* dst, G* src);

Tcl_Obj*    g_ms_serialize (Tcl_Interp* interp, Tcl_Obj* go, G* g,
			    int oc, Tcl_Obj* const* ov);
int	    g_ms_set       (Tcl_Interp* interp, Tcl_Obj* go, G* g,
			    Tcl_Obj* dst);
int	    g_ms_assign    (Tcl_Interp* interp, G* g, Tcl_Obj* src);

/* .................................................. */
#endif /* _G_GRAPH_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

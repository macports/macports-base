/* struct::graph - critcl - layer 1 declarations
 * (c) Graph functions
 */

#ifndef _G_WALK_H
#define _G_WALK_H 1
/* .................................................. */

#include "tcl.h"
#include <ds.h>

#define W_USAGE "node ?-dir forward|backward? ?-order pre|post|both? ?-type bfs|dfs? -command cmd"

/* .................................................. */

enum wtypes {
    WG_BFS, WG_DFS
};

enum worder {
    WO_BOTH, WO_PRE, WO_POST
};

enum wdir {
    WD_BACKWARD, WD_FORWARD
};

int g_walkoptions (Tcl_Interp* interp,
		   int objc, Tcl_Obj* const* objv,
		   int* type, int* order, int* dir,
		   int* cc, Tcl_Obj*** cv);

int g_walk (Tcl_Interp* interp, Tcl_Obj* go, GN* n,
	    int type, int order, int dir,
	    int cc, Tcl_Obj** cv);

/* .................................................. */
#endif /* _G_WALK_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

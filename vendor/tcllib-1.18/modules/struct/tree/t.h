/* struct::tree - critcl - layer 1 declarations
 * (c) Tree functions
 */

#ifndef _T_H
#define _T_H 1

#include "tcl.h"
#include <ds.h>

TPtr t_new	 (void);
void t_delete	 (TPtr t);
void t_structure (TPtr t);
void t_dump      (TPtr t, FILE* f);

int  t_deserialize (TPtr dst, Tcl_Interp* interp, Tcl_Obj* src);
int  t_assign	   (TPtr dst, TPtr src);

enum wtypes {
    WT_BFS, WT_DFS
};

enum worder {
    WO_BOTH, WO_IN, WO_PRE, WO_POST
};

typedef int (*t_walk_function) (Tcl_Interp* interp,
				TN* n, Tcl_Obj* cs,
				Tcl_Obj* da, Tcl_Obj* db,
				Tcl_Obj* action);

int t_walkoptions (Tcl_Interp* interp, int n,
		   int objc, Tcl_Obj* CONST* objv,
		   int* type, int* order, int* remainder,
		   char* usage);

int t_walk (Tcl_Interp* interp, TN* tdn, int type, int order,
	    t_walk_function f, Tcl_Obj* cs,
	    Tcl_Obj* avn, Tcl_Obj* nvn);

int t_walk_invokescript (Tcl_Interp* interp, TN* n, Tcl_Obj* cs,
			 Tcl_Obj* avn, Tcl_Obj* nvn,
			 Tcl_Obj* action);

int t_walk_invokecmd (Tcl_Interp* interp, TN* n, Tcl_Obj* dummy0,
		      Tcl_Obj* dummy1, Tcl_Obj* dummy2,
		      Tcl_Obj* action);

CONST char* t_newnodename (T* td);

#endif /* _T_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

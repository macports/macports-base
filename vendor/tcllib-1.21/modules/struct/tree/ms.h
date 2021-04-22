/* struct::tree - critcl - layer 2 declarations
 * Support for tree methods.
 */

#ifndef _MS_H
#define _MS_H 1

#include "tcl.h"
#include <ds.h>

int	 tms_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int	 tms_assign    (Tcl_Interp* interp, TPtr t, Tcl_Obj* srccmd);
int	 tms_set	      (Tcl_Interp* interp, TPtr t, Tcl_Obj* dstcmd);
Tcl_Obj* tms_serialize (TNPtr n);

int tms_getchildren (TNPtr n, int all,
		    int cmdc, Tcl_Obj** cmdv,
		    Tcl_Obj* tree, Tcl_Interp* interp);

#endif /* _MS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

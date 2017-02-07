/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - ObjType for interned strings.
 */

#ifndef _RDE_DS_OT_H
#define _RDE_DS_OT_H 1

#include "tcl.h"
#include <p.h>   /* State declarations */

long int rde_ot_intern0 (RDE_STATE p,
			 Tcl_Obj* detail);

long int rde_ot_intern1 (RDE_STATE p,
			 const char* operator,
			 Tcl_Obj* detail);

long int rde_ot_intern2 (RDE_STATE p,
			 const char* operator,
			 Tcl_Obj* detail1,
			 Tcl_Obj* detail2);

#endif /* _RDE_DS_OT_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

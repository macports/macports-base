/* struct::stack - critcl - layer 1 declarations
 * (c) Stack functions
 */

#ifndef _S_H
#define _S_H 1

#include "tclpre9compat.h"
#include <ds.h>

SPtr st_new	 (void);
void st_delete	 (SPtr s);
int  st_peek     (SPtr s, Tcl_Interp* interp, Tcl_Size n,
		  int pop, int listall, int revers, int ret);

#endif /* _T_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

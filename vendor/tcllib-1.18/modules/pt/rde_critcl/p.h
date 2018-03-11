/* pt::rde::critcl - critcl - layer 1 declarations
 * (c) PARAM functions
 */

#ifndef _P_H
#define _P_H 1

#include "tcl.h"

typedef struct RDE_STATE_* RDE_STATE;

RDE_STATE param_new    (void);
void      param_delete (RDE_STATE p);
void      param_setcmd (RDE_STATE p, Tcl_Command c);

#endif /* _P_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::queue - critcl - layer 1 declarations
 * (c) Queue functions
 */

#ifndef _Q_H
#define _Q_H 1

#include "tcl.h"
#include <ds.h>

QPtr qu_new	 (void);
void qu_delete	 (QPtr q);

#endif /* _Q_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

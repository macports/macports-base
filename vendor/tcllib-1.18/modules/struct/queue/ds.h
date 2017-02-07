/* struct::queue - critcl - layer 1 declarations
 * (a) Data structures.
 */

#ifndef _DS_H
#define _DS_H 1

#include "tcl.h"

/* Forward declarations of references to queues.
 */

typedef struct Q* QPtr;

/* Queue structure
 */

typedef struct Q {
    Tcl_Command cmd; /* Token of the object command for
		      * the queue */
    Tcl_Obj* unget;  /* List object unget elements */
    Tcl_Obj* queue;  /* List object holding the main queue */
    Tcl_Obj* append; /* List object holding new elements */
    int at;          /* Index of next element to return from the main queue */
} Q;

#endif /* _DS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::stack - critcl - layer 1 declarations
 * (a) Data structures.
 */

#ifndef _DS_H
#define _DS_H 1

#include "tcl.h"

/* Forward declarations of references to stacks.
 */

typedef struct S* SPtr;

/* Node structure.
 */

/* Stack structure
 */

typedef struct S {
    Tcl_Command cmd; /* Token of the object command for
		      * the stack */
    int      max;    /* Max number of objects in stack seen so far */
    Tcl_Obj* stack;  /* List object holding the stack */
} S;

#endif /* _DS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

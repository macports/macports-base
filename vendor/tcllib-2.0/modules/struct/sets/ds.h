/* struct::set - critcl - layer 0 declarations
 * Tcl_ObjType 'set'.
 */

#ifndef _DS_H
#define _DS_H 1

#include "tcl.h"

typedef struct S *SPtr;

typedef struct S {
    Tcl_HashTable el;
} S;

#endif /* _DS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

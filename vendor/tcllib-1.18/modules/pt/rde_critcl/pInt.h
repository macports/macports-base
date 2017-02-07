/* pt::rde::critcl - critcl - layer 1 declarations
 * (c) PARAM functions
 */

#ifndef _P_INT_H
#define _P_INT_H 1

#include <p.h>     /* Public decls */
#include <param.h> /* PARAM architectural state */
#include <util.h>  /* Tracing support */

typedef struct RDE_STRING {
    struct RDE_STRING* next;
    Tcl_Obj*           self;
    int                id;
} RDE_STRING;

typedef struct RDE_STATE_ {
    RDE_PARAM   p;
    Tcl_Command c;

    struct RDE_STRING* sfirst;

    Tcl_HashTable str; /* Table to intern strings, i.e. convert them into
			* unique numerical indices for the PARAM instructions.
			*/

    /* And the counter mapping from ids to strings, this is handed to the
     * PARAM for use.
     */
    long int maxnum; /* NOTE -- */
    long int numstr; /* This is, essentially, an RDE_STACK (char* elements) */
    char**   string; /* Convert over to that instead of replicating the code */

#ifdef RDE_TRACE
    int icount;  /* Instruction counter, when tracing */
#endif
} RDE_STATE_;

long int param_intern (RDE_STATE p, const char* literal);

#endif /* _P_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

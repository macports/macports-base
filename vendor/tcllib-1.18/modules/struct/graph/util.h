/* struct::graph - critcl - layer 0 declarations
 * API general utilities
 */

#ifndef _G_UTIL_H
#define _G_UTIL_H 1

#include <tcl.h>

/* Allocation macros for common situations.
 */

#define ALLOC(type)    (type *) ckalloc (sizeof (type))
#define NALLOC(n,type) (type *) ckalloc ((n) * sizeof (type))
#define REALLOC(x,n,type) (type *) ckrealloc ((char*) x, (n) * sizeof (type))

/* Assertions in general, and asserting the proper range of an array index.
 */

#undef  GRAPH_DEBUG
#define GRAPH_DEBUG 1

#ifdef GRAPH_DEBUG
#define XSTR(x) #x
#define STR(x) XSTR(x)
#define RANGEOK(i,n) ((0 <= (i)) && (i < (n)))
#define ASSERT(x,msg) if (!(x)) { Tcl_Panic (msg " (" #x "), in file " __FILE__ " @line " STR(__LINE__));}
#define ASSERT_BOUNDS(i,n) ASSERT (RANGEOK(i,n),"array index out of bounds: " STR(i) " > " STR(n))
#else
#define ASSERT(x,msg)
#define ASSERT_BOUNDS(i,n)
#endif

/* .................................................. */

/* NL  = Node List. Actually a list of generic pointers.
 * NLQ = NL Queue. Also useable as stack.
 */

typedef struct NL *NLptr;

typedef struct NL {
    NLptr next;
    void* n;
} NL;

typedef struct NLQ {
    NLptr start;
    NLptr end;
} NLQ;

void  g_nlq_init   (NLQ* q);
void  g_nlq_append (NLQ* q, void* n);
void  g_nlq_push   (NLQ* q, void* n);
void* g_nlq_pop    (NLQ* q);
void* g_nlq_clear  (NLQ* q);

#endif /* _G_UTIL_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - General utilities 
 */

#ifndef _RDE_UTIL_H
#define _RDE_UTIL_H 1

#include <tcl.h>

/*
 * Default scope, global
 */

#ifndef SCOPE
#define SCOPE
#endif

/*
 * Allocation macros for common situations.
 */

#define ALLOC(type)    (type *) ckalloc (sizeof (type))
#define NALLOC(n,type) (type *) ckalloc ((n) * sizeof (type))

/*
 * General assertions, and asserting the proper range of an array index.
 */

#undef  RDE_DEBUG
#define RDE_DEBUG 1

#undef  RDE_TRACE
/* #define RDE_TRACE 1 */

/*
 * = = == === ===== ======== ============= =====================
 */

#ifdef RDE_DEBUG
#define STOPAFTER(x) { static int count = (x); count --; if (!count) { Tcl_Panic ("stop"); } }
#define XSTR(x) #x
#define STR(x) XSTR(x)
#define RANGEOK(i,n) ((0 <= (i)) && (i < (n)))
#define ASSERT(x,msg) if (!(x)) { Tcl_Panic (msg " (" #x "), in file " __FILE__ " @line " STR(__LINE__));}
#define ASSERT_BOUNDS(i,n) ASSERT (RANGEOK(i,n),"array index out of bounds: " STR(i) " >= " STR(n))
#else
#define STOPAFTER(x)
#define ASSERT(x,msg)
#define ASSERT_BOUNDS(i,n)
#endif

#ifdef RDE_TRACE
SCOPE void trace_enter (const char* fun);
SCOPE void trace_return (const char *pat, ...);
SCOPE void trace_printf (const char *pat, ...);

#define ENTER(fun)          trace_enter (fun)
#define RETURN(format,x)    trace_return (format,x) ; return x
#define RETURNVOID          trace_return ("%s","(void)") ; return
#define TRACE0(x)           trace_printf0 x
#define TRACE(x)            trace_printf x
#else
#define ENTER(fun)
#define RETURN(f,x) return x
#define RETURNVOID  return
#define TRACE0(x)
#define TRACE(x)
#endif

#endif /* _RDE_UTIL_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

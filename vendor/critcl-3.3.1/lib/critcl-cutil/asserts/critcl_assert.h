#ifndef __CRITCL_CUTIL_ASSERT_H
#define __CRITCL_CUTIL_ASSERT_H 1

/*
 * Copyright (c) 2017-2020 Andreas Kupries <andreas_kupries@users.sourceforge.net>
 * = = == === ===== ======== ============= =====================
 */

#include <tcl.h>

/*
 * Macros for assertions, controlled via CRITCL_ASSERT.
 * Especially a helper to check array bounds, and counted
 * abort.
 */

#ifdef CRITCL_ASSERT

#define CRITCL_CUTIL_XSTR(x) #x
#define CRITCL_CUTIL_STR(x) CRITCL_CUTIL_XSTR(x)
#define CRITCL_CUTIL_RANGEOK(i,n) ((0 <= (i)) && ((i) < (n)))

#define ASSERT(x,msg) if (!(x)) {				\
	Tcl_Panic (msg " (" #x "), in file %s @line %d",	\
		   __FILE__, __LINE__);				\
    }

#define ASSERT_VA(x,msg,format,...) if (!(x)) {				\
	Tcl_Panic (msg " (" #x "), in file %s @line %d, " format,	\
		   __FILE__, __LINE__, __VA_ARGS__);			\
    }

#define ASSERT_BOUNDS(i,n)			\
    ASSERT_VA (CRITCL_CUTIL_RANGEOK(i,n),	\
	       "array index out of bounds",	\
	       CRITCL_CUTIL_STR(i)		\
	       " = (%d) >= (%d) = "		\
	       CRITCL_CUTIL_STR(n),		\
	       i, n)

#define STOPAFTER(x) {				\
	static int count = (x);			\
	count --;				\
	if (!count) { Tcl_Panic ("stop"); }	\
    }

#else /* ! CRITCL_ASSERT */

#define ASSERT(x,msg)
#define ASSERT_VA(x,msg,format,...)
#define ASSERT_BOUNDS(i,n)
#define STOPAFTER(x)

#endif

/*
 * = = == === ===== ======== ============= =====================
 */

#endif /* __CRITCL_CUTIL_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

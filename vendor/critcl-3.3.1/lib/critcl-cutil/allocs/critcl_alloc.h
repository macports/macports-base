#ifndef __CRITCL_UTIL_ALLOC_H
#define __CRITCL_UTIL_ALLOC_H 1

/*
 * Copyright (c) 2017-2020 Andreas Kupries <andreas_kupries@users.sourceforge.net>
 * = = == === ===== ======== ============= =====================
 */

#include <string.h> /* memcpy - See STREP */
#include <tcl.h>

/*
 * Helper macros for easy allocation of structures and arrays.
 */

#define ALLOC(type)        (type *) ckalloc   (sizeof (type))
#define ALLOC_PLUS(type,n) (type *) ckalloc   (sizeof (type) + (n))
#define NALLOC(type,n)     (type *) ckalloc   (sizeof (type) * (n))
#define REALLOC(x,type,n)  (type *) ckrealloc ((char*) x, sizeof (type) * (n))

#define FREE(p) ckfree ((char*)(p))

/*
 * Macros to properly set a string rep from a string or DString. The main
 * point is adding the terminating \0 character. The Tcl core checks for that.
 */

#define STREP(o,str,len)		\
    (o)->length = (len);		\
    (o)->bytes  = ckalloc((len)+1);	\
    memcpy ((o)->bytes, (str), (len));	\
    (o)->bytes[(len)] = '\0'

#define STREP_DS(o,ds) {				\
	int length = Tcl_DStringLength (ds);		\
	STREP(o, Tcl_DStringValue (ds), length);	\
    }

#define STRDUP(v,s) {			    \
        char* str = ckalloc (1+strlen (s)); \
	strcpy (str, s);		    \
	v = str; \
    }

/*
 * = = == === ===== ======== ============= =====================
 */

#endif /* __CRITCL_UTIL_ALLOC_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - Token cache
 */

#include <tc.h>    /* Our public API */
#include <stack.h> /* Stack handling */
#include <util.h>  /* Allocation macros */
#include <string.h>

/*
 * = = == === ===== ======== ============= =====================
 */

typedef struct RDE_TC_ {
    Tcl_Size  max;   /* Max number of bytes in the cache */
    Tcl_Size  num;   /* Current number of bytes in the cache */
    char*     str;   /* Character cache (utf8) */
    RDE_STACK off;   /* Offsets of characters in 'string' */
} RDE_TC_;


/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE RDE_TC
rde_tc_new (void)
{
    RDE_TC tc = ALLOC (RDE_TC_);

    tc->max   = RDE_STACK_INITIAL_SIZE;
    tc->num   = 0;
    tc->str   = NALLOC (RDE_STACK_INITIAL_SIZE, char);
    tc->off   = rde_stack_new (NULL);

    return tc;
}

SCOPE void
rde_tc_del (RDE_TC tc)
{
    rde_stack_del (tc->off);

    ckfree (tc->str);
    ckfree ((char*) tc);
}

SCOPE Tcl_Size
rde_tc_size (RDE_TC tc)
{
    return rde_stack_size (tc->off);
}

SCOPE void
rde_tc_clear (RDE_TC tc)
{
    tc->num   = 0;

    rde_stack_trim (tc->off,  0);
}

SCOPE char*
rde_tc_append (RDE_TC tc, char* string, Tcl_Size len)
{
    Tcl_Size base = tc->num;
    Tcl_Size off  = tc->num;
    char*    ch;

    if (len < 0) {
	len = strlen (string);
    }

    /*
     * Nothing to append, nothing to do. Bail immediately.
     */

    if (!len) {
	return tc->str + base;
    }

    /*
     * Extend character buffer to hold the new string, and copy the string in.
     */

    if ((tc->num + len) >= tc->max) {
	Tcl_Size new = len + (tc->max ? (2 * tc->max) : RDE_STACK_INITIAL_SIZE);
	char*    str = ckrealloc (tc->str, new * sizeof(char));
	ASSERT (str,"Memory allocation failure for token character array");
	tc->max = new;
	tc->str = str;
    }

    tc->num += len;
    ASSERT_BOUNDS(tc->num,tc->max);
    ASSERT_BOUNDS(off,tc->max);
    ASSERT_BOUNDS(off+len-1,tc->max);
    ASSERT_BOUNDS(off+len-1,tc->num);
    memcpy (tc->str + off, string, len);

    /*
     * Now update the offset counter, this is done per character in the new
     * string.
     */

    ch = string;
    while (ch < (string + len)) {
	Tcl_Size    clen;
	Tcl_UniChar uni;

	ASSERT_BOUNDS(off,tc->num);
	rde_stack_push (tc->off,  (void*) (long int) off);

	clen = Tcl_UtfToUniChar (ch, &uni); /* OK tcl9 */

	off += clen;
	ch  += clen;
    }

    return tc->str + base;
}

SCOPE void
rde_tc_get (RDE_TC tc, Tcl_Size at, char** ch, Tcl_Size* len)
{
    Tcl_Size oc, off, end;
    void**   ov;

    rde_stack_get (tc->off, &oc, &ov);

    ASSERT_BOUNDS(at,oc);

    off = (Tcl_Size) (long int) ov [at];
    if ((at+1) == oc) {
	end = tc->num;
    } else {
	end = (Tcl_Size) (long int) ov [at+1];
    }

    TRACE (("rde_tc_get (RDE_TC %p, @ %d) => %d.[%d ... %d]/%d",tc,at,end-off,off,end-1,tc->num));

    ASSERT_BOUNDS(off,tc->num);
    ASSERT_BOUNDS(end-1,tc->num);

    *ch = tc->str + off;
    *len = end - off;
}

SCOPE void
rde_tc_get_s (RDE_TC tc, Tcl_Size at, Tcl_Size last, char** ch, Tcl_Size* len)
{
    Tcl_Size oc, off, end;
    void**   ov;

    rde_stack_get (tc->off, &oc, &ov);

    ASSERT_BOUNDS(at,oc);
    ASSERT_BOUNDS(last,oc);

    off = (Tcl_Size) (long int) ov [at];
    if ((last+1) == oc) {
	end = tc->num;
    } else {
	end = (Tcl_Size) (long int) ov [last+1];
    }

    TRACE (("rde_tc_get_s (RDE_TC %p, @ %d .. %d) => %d.[%d ... %d]/%d",tc,at,last,end-off,off,end-1,tc->num));

    ASSERT_BOUNDS(off,tc->num);
    ASSERT_BOUNDS(end-1,tc->num);

    *ch = tc->str + off;
    *len = end - off;
}

/*
 * = = == === ===== ======== ============= =====================
 */


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

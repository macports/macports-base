/* struct::stack - critcl - layer 1 definitions
 * (c) Stack functions
 */

#include <s.h>
#include <util.h>

/* .................................................. */

S*
st_new (void)
{
    S* s = ALLOC (S);

    s->max   = 0;
    s->stack = Tcl_NewListObj (0,NULL);
    Tcl_IncrRefCount (s->stack);

    return s;
}

void
st_delete (S* s)
{
    /* Delete a stack in toto.
     */

    Tcl_DecrRefCount (s->stack);
    ckfree ((char*) s);
}

int
st_peek (S* s, Tcl_Interp* interp, int n, int pop, int listall, int revers, int ret)
{

    int       listc = 0;
    Tcl_Obj** listv;
    Tcl_Obj*  r;
    int       i, j;

    Tcl_ListObjGetElements (interp, s->stack, &listc, &listv);

    if (n > listc) {
	Tcl_AppendResult (interp,
			  "insufficient items on stack to fill request",
			  NULL);
	return TCL_ERROR;
    }

    if (ret) {
	if ((n == 1) && !listall) {
	    r = listv [listc-1];
	} else {
	    /* Grab range at the top of the stack, and revert order */

	    ASSERT_BOUNDS (listc-n,listc);

	    r = Tcl_NewListObj (n, listv + (listc - n));

	    /*
	     * Note the double negation here. To get the normal order of the
	     * result, the list has to be reversed. To get the reverted order
	     * result, nothing is to be done. So we revers on !revers
	     */

	    if ((n > 1) && !revers) {
		Tcl_ListObjGetElements (interp, r, &listc, &listv);
		for (i = 0, j = listc-1;
		     i < j;
		     i++, j--) {
		    Tcl_Obj* tmp;

		    ASSERT_BOUNDS (i,listc);
		    ASSERT_BOUNDS (j,listc);

		    tmp = listv[i];
		    listv[i] = listv[j];
		    listv[j] = tmp;
		}
	    }
	}

	Tcl_SetObjResult (interp, r);
    }

    if (pop) {
	Tcl_ListObjGetElements (interp, s->stack, &listc, &listv);

	if (n == listc) {
	    /* Complete removal, like clear */

	    Tcl_DecrRefCount (s->stack);

	    s->max   = 0;
	    s->stack = Tcl_NewListObj (0,NULL);
	    Tcl_IncrRefCount (s->stack);

	} else if ((listc-n) < (s->max/2)) {
	    /* Size dropped under threshold, shrink used memory.
	     */

	    Tcl_Obj* r;

	    ASSERT_BOUNDS (listc-n,listc);

	    r = Tcl_NewListObj (listc-n, listv);
	    Tcl_DecrRefCount (s->stack);
	    s->stack = r;
	    Tcl_IncrRefCount (s->stack);
	    s->max = listc - n;
	} else {
	    /* Keep current list, just reduce number of elements held.
	     */

	    ASSERT_BOUNDS (listc-n,listc);

	    Tcl_ListObjReplace (interp, s->stack, listc-n, n, 0, NULL);
	}
    }

    return TCL_OK;
}


/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

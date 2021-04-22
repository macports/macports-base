/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - Tcl_ObjType for interned strings.
 *
 */

#include <ot.h>    /* Our public API */
#include <util.h>  /* Allocation macros */
#include <pInt.h>  /* API to basic intern(ing) of strings */
#include <string.h>

/*
 * = = == === ===== ======== ============= =====================
 */

static void ot_free_rep   (Tcl_Obj* obj);
static void ot_dup_rep    (Tcl_Obj* obj, Tcl_Obj* dup);
static void ot_string_rep (Tcl_Obj* obj);
static int  ot_from_any   (Tcl_Interp* ip, Tcl_Obj* obj);

static Tcl_ObjType ot_type = {
    "tcllib/pt::rde/critcl",
    ot_free_rep,
    ot_dup_rep,
    ot_string_rep,
    ot_from_any
};

static int      IsCached (RDE_STATE p, Tcl_Obj* obj, long int* id);
static long int Make     (RDE_STATE p, Tcl_Obj* obj, const char* str);


/*
 * = = == === ===== ======== ============= =====================
 */

long int
rde_ot_intern0 (RDE_STATE p,
		Tcl_Obj* detail)
{
    long int id;

    TRACE (("rde_ot_intern0 (%p, %p = '%s')", p, detail, Tcl_GetString(detail)));
    if (IsCached (p, detail, &id)) {
	return id;
    }

    TRACE (("INTERNALIZE"));
    return Make (p, detail, Tcl_GetString (detail));
}

long int
rde_ot_intern1 (RDE_STATE p,
		const char* operator,
		Tcl_Obj* detail)
{
    long int id;
    Tcl_DString buf;

    TRACE (("rde_ot_intern1 (%p, '%s' %p = '%s')", p, operator, detail, Tcl_GetString(detail)));
    if (IsCached (p, detail, &id)) {
	return id;
    }

    TRACE (("INTERNALIZE"));

    /* Create a list of operator + detail.
     * Using a DString.
     */

    Tcl_DStringInit (&buf);
    Tcl_DStringAppendElement (&buf, operator);
    Tcl_DStringAppendElement (&buf, Tcl_GetString (detail));

    id = Make (p, detail, Tcl_DStringValue (&buf));

    Tcl_DStringFree (&buf);
    return id;
}

long int
rde_ot_intern2 (RDE_STATE p,
		const char* operator,
		Tcl_Obj* detail1,
		Tcl_Obj* detail2)
{
    long int id;
    Tcl_DString buf;

    TRACE (("rde_ot_intern2 (%p, '%s' %p = '%s', %p = '%s')", p, operator,
	    detail1, Tcl_GetString(detail1)
	    detail2, Tcl_GetString(detail2)));
    if (IsCached (p, detail1, &id)) {
	return id;
    }

    TRACE (("INTERNALIZE"));

    /* Create a list of operator + detail1 + detail2.
     * Using a DString.
     */

    Tcl_DStringInit (&buf);
    Tcl_DStringAppendElement (&buf, operator);
    Tcl_DStringAppendElement (&buf, Tcl_GetString (detail1));
    Tcl_DStringAppendElement (&buf, Tcl_GetString (detail2));

    id = Make (p, detail1, Tcl_DStringValue (&buf));

    Tcl_DStringFree (&buf);
    return id;
}

/*
 * = = == === ===== ======== ============= =====================
 */

static int
IsCached (RDE_STATE p, Tcl_Obj* obj, long int* id)
{
    /*
     * Quick exit if we have a cached and valid value.
     */

    if ((obj->typePtr == &ot_type) &&
	(obj->internalRep.twoPtrValue.ptr1 == p)) {
	RDE_STRING* rs = (RDE_STRING*) obj->internalRep.twoPtrValue.ptr2;
	TRACE (("CACHED %p = %d", rs, rs->id));
	*id = rs->id;
	return 1;
    }

    return 0;
}

static long int
Make (RDE_STATE p, Tcl_Obj* obj, const char* str)
{
    long int    id = param_intern (p, str);
    RDE_STRING* rs = ALLOC (RDE_STRING);

    rs->next = p->sfirst;
    rs->self = obj;
    rs->id   = id;
    p->sfirst = rs;

    /* Invalidate previous int.rep before setting our own.
     * Inlined copy of TclFreeIntRep() macro (tclInt.h)
     */

    if ((obj)->typePtr &&
	(obj)->typePtr->freeIntRepProc) {
        (obj)->typePtr->freeIntRepProc(obj);
    }

    obj->internalRep.twoPtrValue.ptr1 = p;
    obj->internalRep.twoPtrValue.ptr2 = rs;
    obj->typePtr = &ot_type;

    return id;
}

/*
 * = = == === ===== ======== ============= =====================
 */

static void 
ot_free_rep(Tcl_Obj* obj)
{
    RDE_STATE   p  = (RDE_STATE)   obj->internalRep.twoPtrValue.ptr1;
    RDE_STRING* rs = (RDE_STRING*) obj->internalRep.twoPtrValue.ptr2;

    /* Take structure out of the tracking list. */
    if (p->sfirst == rs) {
	p->sfirst = rs->next;
    } else {
	RDE_STRING* iter = p->sfirst;
	while (iter->next != rs) {
	    iter = iter->next;
	}
	iter->next = rs->next;
    }

    /* Drop the now un-tracked structure */
    ckfree ((char*) rs);

    /* Nothing to release in the obj itself, just resetting references. */
    obj->internalRep.twoPtrValue.ptr1 = NULL;
    obj->internalRep.twoPtrValue.ptr2 = NULL;
}
        
static void
ot_dup_rep(Tcl_Obj* obj, Tcl_Obj* dup)
{
    RDE_STRING* ors = (RDE_STRING*) obj->internalRep.twoPtrValue.ptr2;
    RDE_STRING* drs;
    RDE_STATE   p = ((RDE_STATE) obj->internalRep.twoPtrValue.ptr1);

    drs = ALLOC (RDE_STRING);
    drs->next = p->sfirst;
    drs->self = dup;
    drs->id   = ors->id;
    p->sfirst = drs;

    dup->internalRep.twoPtrValue.ptr1 = obj->internalRep.twoPtrValue.ptr1;
    dup->internalRep.twoPtrValue.ptr2 = drs;
    dup->typePtr = &ot_type;
}
        
static void
ot_string_rep(Tcl_Obj* obj)
{
    (void) obj;
    ASSERT (0, "Attempted reconversion of rde string to string rep");
}
    
static int
ot_from_any(Tcl_Interp* ip, Tcl_Obj* obj)
{
    (void) ip;
    (void) obj;
    ASSERT (0, "Illegal conversion into rde string");
    return TCL_ERROR;
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

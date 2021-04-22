/* struct::graph - critcl - layer 1 definitions.
 * (b) Arc operations.
 * Tcl_ObjType for arcs, and shimmering to it.
 */

#include <string.h>
#include <arc.h>

/* .................................................. */

static void free_rep   (Tcl_Obj* obj);
static void dup_rep    (Tcl_Obj* obj, Tcl_Obj* dup);
static void string_rep (Tcl_Obj* obj);
static int  from_any   (Tcl_Interp* ip, Tcl_Obj* obj);

static
Tcl_ObjType ga_type = {
    "tcllib::struct::graph/critcl::arc",
    free_rep,
    dup_rep,
    string_rep,
    from_any
};

/* .................................................. */

static void
free_rep (Tcl_Obj* obj)
{
    /* Nothing to do. The rep is the GA in the G. */
}

static void
dup_rep (Tcl_Obj* obj, Tcl_Obj* dup)
{
    GA* a = (GA*) obj->internalRep.otherValuePtr;

    dup->internalRep.otherValuePtr = a;
    dup->typePtr		   = &ga_type;
}

static void
string_rep (Tcl_Obj* obj)
{
    Tcl_Obj* temp;
    char*    str;
    GA*      a = (GA*) obj->internalRep.otherValuePtr;

    obj->length = a->base.name->length;
    obj->bytes	= ckalloc (obj->length + 1);

    memcpy (obj->bytes, a->base.name->bytes, obj->length + 1);
}

static int
from_any (Tcl_Interp* ip, Tcl_Obj* obj)
{
    Tcl_Panic ("Cannot create GA structure via regular shimmering.");
    return TCL_ERROR;
}

/* .................................................. */

void
ga_shimmer (Tcl_Obj* o, GA* a)
{
    /* Release an existing representation */

    if (o->typePtr && o->typePtr->freeIntRepProc) {
	o->typePtr->freeIntRepProc (o);
    }

    o->typePtr			 = &ga_type;
    o->internalRep.otherValuePtr = a;
}

/* .................................................. */

GA*
ga_get_arc (G* g, Tcl_Obj* arc, Tcl_Interp* interp, Tcl_Obj* graph)
{
    GA*		   a = NULL;
    Tcl_HashEntry* he;

    /* Check if we have a valid cached int.rep. */

#if 0
    /* [x] TODO */
    /* Caching of handles implies that the graphs have to */
    /* keep track of the tcl_obj pointing to them. So that */
    /* the int.rep can be invalidated upon graph deletion */

    if (arc->typePtr == &ga_type) {
	a = (GA*) arc->internalRep.otherValuePtr;
	if (a->graph == g) {
#if 0
	    fprintf (stderr, "cached: %p (%p - %p)\n", a, t, a->graph);
	    fflush(stderr);
#endif
	    return a;
	}
    }
#endif
    /* Incompatible int.rep, or refering to a different
     * graph. We go through the hash table.
     */

    he = Tcl_FindHashEntry (g->arcs.map, Tcl_GetString (arc));

    if (he) {
	a = (GA*) Tcl_GetHashValue (he);

	/* Shimmer the object, cache the arc information.
	 */

	ga_shimmer (arc, a);
	return a;
    }

    /* Arc handle not found. Leave an error message,
     * if possible.
     */

    if (interp != NULL) {
	ga_err_missing (interp, arc, graph);
    }
    return NULL;
}


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

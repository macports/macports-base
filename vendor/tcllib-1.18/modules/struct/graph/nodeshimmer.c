/* struct::graph - critcl - layer 1 definitions.
 * (b) Node operations.
 * Tcl_ObjType for nodes, and shimmering to it.
 */

#include <string.h>
#include <node.h>

/* .................................................. */

static void free_rep   (Tcl_Obj* obj);
static void dup_rep    (Tcl_Obj* obj, Tcl_Obj* dup);
static void string_rep (Tcl_Obj* obj);
static int  from_any   (Tcl_Interp* ip, Tcl_Obj* obj);

static
Tcl_ObjType gn_type = {
    "tcllib::struct::graph/critcl::node",
    free_rep,
    dup_rep,
    string_rep,
    from_any
};

/* .................................................. */

static void
free_rep (Tcl_Obj* obj)
{
    /* Nothing to do. The rep is the GN in the G. */
}

static void
dup_rep (Tcl_Obj* obj, Tcl_Obj* dup)
{
    GN* n = (GN*) obj->internalRep.otherValuePtr;

    dup->internalRep.otherValuePtr = n;
    dup->typePtr		   = &gn_type;
}

static void
string_rep (Tcl_Obj* obj)
{
    Tcl_Obj* temp;
    char*    str;
    GN*      n = (GN*) obj->internalRep.otherValuePtr;

    obj->length = n->base.name->length;
    obj->bytes	= ckalloc (obj->length + 1);

    memcpy (obj->bytes, n->base.name->bytes, obj->length + 1);
}

static int
from_any (Tcl_Interp* ip, Tcl_Obj* obj)
{
    Tcl_Panic ("Cannot create GDN structure via regular shimmering.");
    return TCL_ERROR;
}

/* .................................................. */

void
gn_shimmer (Tcl_Obj* o, GN* n)
{
    /* Release an existing representation */

    if (o->typePtr && o->typePtr->freeIntRepProc) {
	o->typePtr->freeIntRepProc (o);
    }

    o->typePtr			 = &gn_type;
    o->internalRep.otherValuePtr = n;
}

/* .................................................. */

GN*
gn_get_node (G* g, Tcl_Obj* node, Tcl_Interp* interp, Tcl_Obj* graph)
{
    GN*		   n = NULL;
    Tcl_HashEntry* he;

    /* Check if we have a valid cached int.rep. */

#if 0
    /* [x] TODO */
    /* Caching of handles implies that the graphs have to */
    /* keep track of the tcl_obj pointing to them. So that */
    /* the int.rep can be invalidated upon graph deletion */

    if (node->typePtr == &gn_type) {
	n = (GN*) node->internalRep.otherValuePtr;
	if (n->graph == g) {
#if 0
	    fprintf (stderr, "cached: %p (%p - %p)\n", n, t, n->graph);
	    fflush(stderr);
#endif
	    return n;
	}
    }
#endif
    /* Incompatible int.rep, or refering to a different
     * graph. We go through the hash table.
     */

    he = Tcl_FindHashEntry (g->nodes.map, Tcl_GetString (node));

    if (he != NULL) {
	n = (GN*) Tcl_GetHashValue (he);

	/* Shimmer the object, cache the node information.
	 */

	gn_shimmer (node, n);
	return n;
    }

    /* Node handle not found. Leave an error message,
     * if possible.
     */

    if (interp != NULL) {
	gn_err_missing (interp, node, graph);
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

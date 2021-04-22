/* struct::tree - critcl - layer 1 definitions.
 * (b) Node operations.
 * Tcl_ObjType for nodes, and shimmering to it.
 */

#include <string.h>
#include <tn.h>

/* .................................................. */

static void free_rep   (Tcl_Obj* obj);
static void dup_rep    (Tcl_Obj* obj, Tcl_Obj* dup);
static void string_rep (Tcl_Obj* obj);
static int  from_any   (Tcl_Interp* ip, Tcl_Obj* obj);

static
Tcl_ObjType tn_type = {
    "tcllib::struct::tree/critcl::node",
    free_rep,
    dup_rep,
    string_rep,
    from_any
};

/* .................................................. */

static void
free_rep (Tcl_Obj* obj)
{
    /* Nothing to do. The rep is the TN in the T. */
}

static void
dup_rep (Tcl_Obj* obj, Tcl_Obj* dup)
{
    TNPtr n = (TNPtr) obj->internalRep.otherValuePtr;

    dup->internalRep.otherValuePtr = n;
    dup->typePtr		   = &tn_type;
}

static void
string_rep (Tcl_Obj* obj)
{
    Tcl_Obj* temp;
    char*    str;
    TNPtr    n = (TNPtr) obj->internalRep.otherValuePtr;

    obj->length = n->name->length;
    obj->bytes	= ckalloc (obj->length + 1);

    memcpy (obj->bytes, n->name->bytes, obj->length + 1);
}

static int
from_any (Tcl_Interp* ip, Tcl_Obj* obj)
{
    Tcl_Panic ("Cannot create TDN structure via regular shimmering.");
    return TCL_ERROR;
}

/* .................................................. */

void
tn_shimmer (Tcl_Obj* o, TNPtr n)
{
    /* Release an existing representation */

    if (o->typePtr && o->typePtr->freeIntRepProc) {
	o->typePtr->freeIntRepProc (o);
    }

    o->typePtr			 = &tn_type;
    o->internalRep.otherValuePtr = n;
}

/* .................................................. */

TNPtr
tn_get_node (TPtr t, Tcl_Obj* node, Tcl_Interp* interp, Tcl_Obj* tree)
{
    TN*		   n = NULL;
    Tcl_HashEntry* he;

    /* Check if we have a valid cached int.rep. */

#if 0
    /* [x] TODO */
    /* Caching of handles implies that the trees have to */
    /* keep track of the tcl_obj pointing to them. So that */
    /* the int.rep can be invalidated upon tree deletion */

    if (node->typePtr == &tn_type) {
	n = (TN*) node->internalRep.otherValuePtr;
	if (n->tree == t) {
#if 0
	    fprintf (stderr, "cached: %p (%p - %p)\n", n, t, n->tree);
	    fflush(stderr);
#endif
	    return n;
	}
    }
#endif
    /* Incompatible int.rep, or refering to a different
     * tree. We go through the hash table.
     */

    he = Tcl_FindHashEntry (&t->node, Tcl_GetString (node));

    if (he != NULL) {
	n = (TN*) Tcl_GetHashValue (he);

	/* Shimmer the object, cache the node information.
	 */

	tn_shimmer (node, n);
	return n;
    }

    /* Node handle not found. Leave an error message,
     * if possible.
     */

    if (interp != NULL) {
	Tcl_Obj* err = Tcl_NewObj ();

	/* Keep any prefix ... */
	Tcl_AppendObjToObj (err, Tcl_GetObjResult (interp));
	Tcl_AppendToObj	   (err, "node \"", -1);
	Tcl_AppendObjToObj (err, node);
	Tcl_AppendToObj	   (err, "\" does not exist in tree \"", -1);
	Tcl_AppendObjToObj (err, tree);
	Tcl_AppendToObj	   (err, "\"", -1);

	Tcl_SetObjResult (interp, err);
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

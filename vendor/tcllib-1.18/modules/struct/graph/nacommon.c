/* struct::graph - critcl - layer 1 definitions
 * (c) Graph functions
 */

#include <nacommon.h>
#include <util.h>
#include <node.h>

/* .................................................. */

void
gc_add (GC* c, GCC* gx)
{
    GC* first = gx->first;

    gx->n ++;

    c->next   = first;
    c->prev   = NULL;
    gx->first = c;

    if (!first) return;
    first->prev = c;
}

/* .................................................. */

void
gc_remove (GC* c, GCC* gx)
{
    if ((gx->first == c) || c->prev || c->next) {

	if (gx->first == c) {
	    gx->first = c->next;
	}

	if (c->prev) { c->prev->next = c->next; }
	if (c->next) { c->next->prev = c->prev; }

	c->prev = NULL;
	c->next = NULL;

	gx->n --;
    }
}

/* .................................................. */

void
gc_setup (GC* c, GCC* gx, const char* name, G* g)
{
    int new;

    c->name = Tcl_NewStringObj (name, -1);
    Tcl_IncrRefCount (c->name);

    c->he = Tcl_CreateHashEntry(gx->map, name, &new);
    Tcl_SetHashValue (c->he, (ClientData) c);

    c->graph = g;
    c->attr  = NULL;
}

/* .................................................. */

void
gc_delete (GC* c)
{
    Tcl_DecrRefCount	(c->name); c->name = NULL;
    Tcl_DeleteHashEntry (c->he);   c->he   = NULL;
    g_attr_delete       (&c->attr);
    c->graph = NULL;

    /* next/prev are not handled here, but via
     * gc_remove, as type-dependent information
     * is manipulated (node/arc data in the graph).
     */
}

/* .................................................. */

void
gc_rename (GC* c, GCC* gx, Tcl_Obj* newname, Tcl_Interp* interp)
{
    int nnew;

    /* Release current name, ... */
    Tcl_DecrRefCount (c->name);

    /* ... and create a new one, by taking the argument and shimmering it */

    c->name = newname;
    Tcl_IncrRefCount (c->name);

    /* Update the global name mapping as well */

    Tcl_DeleteHashEntry (c->he);
    c->he = Tcl_CreateHashEntry(gx->map, Tcl_GetString (c->name), &nnew);
    Tcl_SetHashValue (c->he, (ClientData) c);

    Tcl_SetObjResult (interp, c->name);
}

/* .................................................. */

int
gc_attr (GCC* gx, int mode, Tcl_Obj* detail, Tcl_Interp* interp, Tcl_Obj* key,
	 GN_GET_GC* gf, G* g)
{
    const char* ky = Tcl_GetString (key);
    int         listc;
    Tcl_Obj**   listv;

    /* Allocate result space, max needed: All nodes */

    ASSERT (gx->map->numEntries == gx->n, "Inconsistent #elements in graph");

    switch (mode) {
    case A_GLOB: {
	/* Iterate over all nodes. Ignore nodes without attributes. Ignore
	 * nodes not matching the pattern (glob). Ignore nodes not having the
	 * attribute.
	 */

	int	       i;
	GC*	       iter;
	const char*    pattern = Tcl_GetString (detail);
	Tcl_HashEntry* he;

	listc = 2 * gx->map->numEntries;
	listv = NALLOC (listc, Tcl_Obj*);

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter= iter->next) {

	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;
	    if (!Tcl_StringMatch(Tcl_GetString (iter->name), pattern)) continue;

	    he = Tcl_FindHashEntry (iter->attr, ky);
	    if (!he) continue;

	    ASSERT_BOUNDS (i,   listc);
	    ASSERT_BOUNDS (i+1, listc);

	    listv [i++] = iter->name;
	    listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	listc = i;
    }
    break;

    case A_LIST: {
	/* Iterate over the specified nodes. Ignore nodes which are not known.
	 * Ignore nodes without attributes. Ignore nodes not having the
	 * attribute. Many occurrences of the same node cause repeated
	 * results.
	 */

	GC*	       iter;
	int	       ec;
	Tcl_Obj**      ev;
	int	       i, j;
	Tcl_HashEntry* he;

	if (Tcl_ListObjGetElements (interp, detail, &ec, &ev) != TCL_OK) {
	    return TCL_ERROR;
	}

	listc = 2 * ((ec > gx->n) ? ec : gx->n);
	listv = NALLOC (listc, Tcl_Obj*);

	for (i = 0, j = 0; i < ec; i++) {
	    ASSERT_BOUNDS (i, ec);

	    iter = (*gf) (g, ev [i], NULL, NULL);

	    if (iter == NULL) continue;
	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;

	    he = Tcl_FindHashEntry (iter->attr, ky);
	    if (!he) continue;

	    ASSERT_BOUNDS (j,   listc);
	    ASSERT_BOUNDS (j+1, listc);

	    listv [j++] = iter->name;
	    listv [j++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	listc = j;
    }
    break;

    case A_REGEXP: {
	/* Iterate over all nodes. Ignore nodes without attributes. Ignore
	 * nodes not matching the pattern (re). Ignore nodes not having the
	 * attribute.
	 */

	int	       i;
	GC*	       iter;
	const char*    pattern = Tcl_GetString (detail);
	Tcl_HashEntry* he;

	listc = 2 * gx->map->numEntries;
	listv = NALLOC (listc, Tcl_Obj*);

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter= iter->next) {

	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;
	    if (Tcl_RegExpMatch(interp, Tcl_GetString (iter->name), pattern) < 1) continue;

	    he = Tcl_FindHashEntry (iter->attr, ky);
	    if (!he) continue;

	    ASSERT_BOUNDS (i,   listc);
	    ASSERT_BOUNDS (i+1, listc);

	    listv [i++] = iter->name;
	    listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	listc = i;
    }
    break;

    case A_NONE: {
	/* Iterate over all nodes. Ignore nodes without attributes. Ignore
	 * nodes not having the attribute.
	 */

	int	       i;
	GC*	       iter;
	Tcl_HashEntry* he;

	listc = 2 * gx->map->numEntries;
	listv = NALLOC (listc, Tcl_Obj*);

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter= iter->next) {

	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;

	    he = Tcl_FindHashEntry (iter->attr, ky);
	    if (!he) continue;

	    ASSERT_BOUNDS (i,   listc);
	    ASSERT_BOUNDS (i+1, listc);

	    listv [i++] = iter->name;
	    listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	listc = i;
    }
    break;
    default:
	Tcl_Panic ("Bad attr search mode");
	break;
    }

    if (listc) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv));
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    }

    ckfree ((char*) listv);
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

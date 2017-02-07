/* struct::graph - critcl - layer 1 declarations
 * (b) Node operations.
 */

#include <arc.h>
#include <node.h>
#include <util.h>

/* .................................................. */

GN*
gn_new (G* g, const char* name)
{
    GN* n;
    int	new;

    if (Tcl_FindHashEntry (g->nodes.map, name) != NULL) {
	Tcl_Panic ("struct::graph(c) gn_new - tried to use duplicate name for new node");
    }

    n = ALLOC (GN);

    gc_setup ((GC*) n, &g->nodes, name, g);
    gc_add   ((GC*) n, &g->nodes);

    gn_shimmer_self (n);

    n->in.first    = NULL;    n->in.n   = 0;
    n->out.first   = NULL;    n->out.n  = 0;

    return n;
}

void
gn_delete (GN* n)
{
    /* We assume that the node may still have incoming and outgoing arcs. They
     * are deleted recursively.
     */

    gc_remove ((GC*) n, &n->base.graph->nodes);
    gc_delete ((GC*) n);

    while (n->in.first)  { ga_delete (n->in.first->a);  }
    while (n->out.first) { ga_delete (n->out.first->a); }

    n->in.first   = NULL;    n->in.n  = 0;
    n->out.first  = NULL;    n->out.n = 0;

    ckfree ((char*) n);
}

/* .................................................. */

void
gn_err_duplicate (Tcl_Interp* interp, Tcl_Obj* n, Tcl_Obj* g)
{
    Tcl_Obj* err = Tcl_NewObj ();

    Tcl_AppendToObj    (err, "node \"", -1);
    Tcl_AppendObjToObj (err, n);
    Tcl_AppendToObj    (err, "\" already exists in graph \"", -1);
    Tcl_AppendObjToObj (err, g);
    Tcl_AppendToObj    (err, "\"", -1);
	    
    Tcl_SetObjResult (interp, err);
}

void
gn_err_missing (Tcl_Interp* interp, Tcl_Obj* n, Tcl_Obj* g)
{
    Tcl_Obj* err = Tcl_NewObj ();

    /* Keep any prefix ... */
    Tcl_AppendObjToObj (err, Tcl_GetObjResult (interp));
    Tcl_AppendToObj    (err, "node \"", -1);
    Tcl_AppendObjToObj (err, n);
    Tcl_AppendToObj    (err, "\" does not exist in graph \"", -1);
    Tcl_AppendObjToObj (err, g);
    Tcl_AppendToObj    (err, "\"", -1);

    Tcl_SetObjResult (interp, err);
}

/* .................................................. */

Tcl_Obj*
gn_serial_arcs (GN* n, Tcl_Obj* empty, Tcl_HashTable* cn)
{
    int       lc;
    Tcl_Obj** lv;
    Tcl_Obj*  arcs;
    GL*       il;
    GA*       a;
    int       i, id;
    Tcl_HashEntry* he;

    /* Quick return if node has no outgoing arcs */

    if (!n->out.n) return empty;

    lc = n->out.n;
    lv = NALLOC (lc, Tcl_Obj*);

    for (i=0, il = n->out.first;
	 il != NULL;
	 il = il->next) {
	a = il->a;
	he = Tcl_FindHashEntry (cn, (char*) a->end->n);

	/* Ignore arcs which lead out of the subgraph spanned up by the nodes
	 * in 'cn'.
	 */

	if (!he) continue;
	ASSERT_BOUNDS(i, lc);
	id = (int) Tcl_GetHashValue (he);
	lv [i] = ga_serial (a, empty, id);
	i++;
    }
    lc = i;

    arcs = Tcl_NewListObj (lc, lv);
    ckfree ((char*) lv);
    return arcs;
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

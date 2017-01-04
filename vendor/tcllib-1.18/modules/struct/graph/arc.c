/* struct::tree - critcl - layer 1 declarations
 * (b) Arc operations.
 */

#include <arc.h>
#include <attr.h>
#include <graph.h>
#include <util.h>

/* .................................................. */

static GL*  gla_link   (GA* a, GL* i, GN* n, GLA* na);
static void gla_unlink (GL* i, GLA* na);

/* .................................................. */

GA*
ga_new (G* g, const char* name, GN* src, GN* dst)
{
    GA* a;

    if (Tcl_FindHashEntry (g->arcs.map, name) != NULL) {
	Tcl_Panic ("struct::graph(c) ga_new - tried to use duplicate name for new arc");
    }

    a = ALLOC (GA);

    gc_setup ((GC*) a, &g->arcs, name, g);
    gc_add   ((GC*) a, &g->arcs);

    ga_shimmer_self (a);

    /* node / arc linkage */

    a->start  = gla_link (a, ALLOC (GL), src, &src->out);
    a->end    = gla_link (a, ALLOC (GL), dst, &dst->in);
    a->weight = NULL; /* New arcs have no weight */

    return a;
}

/* .................................................. */

void
ga_delete (GA* a)
{
    gc_remove ((GC*) a, &a->base.graph->arcs);
    gc_delete ((GC*) a);

    /* interlink removal */

    gla_unlink (a->start, &a->start->n->out);
    gla_unlink (a->end,   &a->end->n->in);

    ckfree ((char*) a->start); a->start = NULL;
    ckfree ((char*) a->end);   a->end   = NULL;

    if (a->weight) {
	Tcl_DecrRefCount (a->weight);
	a->weight = NULL;
    }

    ckfree ((char*) a);
}

/* .................................................. */

void
ga_mv_src (GA* a, GN* nsrc)
{
    GN* src = a->start->n;

    if (src == nsrc) return;

    gla_unlink (a->start, &src->out);
    gla_link   (a, a->start, nsrc, &nsrc->out);
}

/* .................................................. */

void
ga_mv_dst (GA* a, GN* ndst)
{
    GN* dst = a->end->n;

    if (dst == ndst) return;

    gla_unlink (a->end, &dst->in);
    gla_link   (a, a->end, ndst, &ndst->in);
}

/* .................................................. */

Tcl_Obj*
ga_serial (GA* a, Tcl_Obj* empty, int nodeId)
{
    Tcl_Obj* lv [4];

    lv [0] = a->base.name;
    lv [1] = Tcl_NewIntObj (nodeId);
    lv [2] = g_attr_serial (a->base.attr, empty);

    if (a->weight) {
	lv [3] = a->weight;
	return Tcl_NewListObj (4, lv);
    } else {
	return Tcl_NewListObj (3, lv);
    }
}

/* .................................................. */

void
ga_err_duplicate (Tcl_Interp* interp, Tcl_Obj* a, Tcl_Obj* g)
{
    Tcl_Obj* err = Tcl_NewObj ();

    Tcl_AppendToObj    (err, "arc \"", -1);
    Tcl_AppendObjToObj (err, a);
    Tcl_AppendToObj    (err, "\" already exists in graph \"", -1);
    Tcl_AppendObjToObj (err, g);
    Tcl_AppendToObj    (err, "\"", -1);
	    
    Tcl_SetObjResult (interp, err);
}

/* .................................................. */

void
ga_err_missing (Tcl_Interp* interp, Tcl_Obj* a, Tcl_Obj* g)
{
    Tcl_Obj* err = Tcl_NewObj ();

    /* Keep any prefix ... */
    Tcl_AppendObjToObj (err, Tcl_GetObjResult (interp));
    Tcl_AppendToObj    (err, "arc \"", -1);
    Tcl_AppendObjToObj (err, a);
    Tcl_AppendToObj    (err, "\" does not exist in graph \"", -1);
    Tcl_AppendObjToObj (err, g);
    Tcl_AppendToObj    (err, "\"", -1);

    Tcl_SetObjResult (interp, err);
}

/* .................................................. */

static GL*
gla_link (GA* a, GL* il, GN* n, GLA* na)
{
    il->n    = n;
    il->a    = a;

    if (na->first) {
	na->first->prev = il;
    }

    il->prev = NULL;
    il->next = na->first;

    na->first = il;
    na->n ++;

    return il;
}

/* .................................................. */

static void
gla_unlink (GL* il, GLA* na)
{
    if (na->first == il) {
	na->first = il->next;
    }
    if (il->next) {
	il->next->prev = il->prev;
    }
    if (il->prev) {
	il->prev->next = il->next;
    }

    il->n    = NULL;
    il->a    = NULL;
    il->prev = NULL;
    il->next = NULL;

    na->n --;
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

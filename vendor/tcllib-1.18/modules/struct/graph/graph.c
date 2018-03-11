/* struct::graph - critcl - layer 1 definitions
 * (c) Graph functions
 */

#include <arc.h>
#include <attr.h>
#include <graph.h>
#include <node.h>
#include <objcmd.h>
#include <util.h>

/* .................................................. */

static void swap (G* dst, G* src);
static G*   dup  (G* src);

/* .................................................. */

G*
g_new (void)
{
    G* g = ALLOC (G);

    g->nodes.map = ALLOC (Tcl_HashTable);
    g->arcs.map  = ALLOC (Tcl_HashTable);

    Tcl_InitHashTable (g->nodes.map, TCL_STRING_KEYS);
    Tcl_InitHashTable (g->arcs.map,  TCL_STRING_KEYS);

    g->nodes.first = NULL;
    g->nodes.n	   = 0;
    g->arcs.first  = NULL;
    g->arcs.n	   = 0;

    g->attr        = NULL;

    g->cmd	   = NULL;
    g->ncounter	   = 0;
    g->acounter	   = 0;

    return g;
}

/* .................................................. */

void
g_delete (G* g)
{
    /* Delete a graph in toto. Deletes all arcs first, then all nodes. This
     * also handles the nodes/arcs lists. Then the name -> node/arc mapping,
     * and the object name.
     */

    while (g->arcs.first)  { ga_delete ((GA*) g->arcs.first);  }
    while (g->nodes.first) { gn_delete ((GN*) g->nodes.first); }

    Tcl_DeleteHashTable (g->arcs.map);
    Tcl_DeleteHashTable (g->nodes.map);

    ckfree ((char*) g->arcs.map);
    ckfree ((char*) g->nodes.map);

    g->arcs.map  = NULL;
    g->nodes.map = NULL;

    g->cmd = NULL;

    g_attr_delete (&g->attr);
    ckfree ((char*) g);
}

/* .................................................. */

const char*
g_newnodename (G* g)
{
    int ok;
    Tcl_HashEntry* he;

    do {
	g->ncounter ++;
	sprintf (g->handle, "node%d", g->ncounter);

	/* Check that there is no node using that name already */
	he = Tcl_FindHashEntry (g->nodes.map, g->handle);
	ok = (he == NULL);
    } while (!ok);

    return g->handle;
}

/* .................................................. */

const char*
g_newarcname (G* g)
{
    int ok;
    Tcl_HashEntry* he;

    do {
	g->acounter ++;
	sprintf (g->handle, "arc%d", g->acounter);

	/* Check that there is no node using that name already */
	he = Tcl_FindHashEntry (g->arcs.map, g->handle);
	ok = (he == NULL);
    } while (!ok);

    return g->handle;
}

/* .................................................. */

/*
 *---------------------------------------------------------------------------
 *
 * g_ms_serialize --
 *
 *	Generates Tcl value from graph, serialized graph data.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Only internal, memory allocation changes ...
 *
 *---------------------------------------------------------------------------
 */

Tcl_Obj*
g_ms_serialize (Tcl_Interp* interp, Tcl_Obj* go, G* g, int oc, Tcl_Obj* const* ov)
{
    Tcl_Obj*  ser;
    Tcl_Obj*  empty;

    int       lc = 1 + 3 * (oc ? oc : g->nodes.n);
    Tcl_Obj** lv = NALLOC (lc, Tcl_Obj*);

    Tcl_HashTable cn;
    int k, new;
    GN* n;

    /* Enumerate the nodes for the references used in arcs. FUTURE, TODO: Skip
     * this step if there are no arcs! We cannot skip testing the validity of
     * the nodes however, if the set is explicit. In that case we also check
     * and remove duplicates.  */

    Tcl_InitHashTable (&cn, TCL_ONE_WORD_KEYS);

    if (oc) {
	/* Enumerate the specified nodes, remove duplicates along the way */
	Tcl_HashEntry* he;
	int i, j, new;

	j = 0;
	for (i=0; i < oc; i++) {
	    ASSERT_BOUNDS(i, oc);
	    n = gn_get_node (g, ov[i], interp, go);
	    if (!n) {
		goto abort;
	    }
	    if (Tcl_FindHashEntry (&cn, (char*) n)) continue;
	    ASSERT_BOUNDS(j, lc-1);
	    he = Tcl_CreateHashEntry (&cn, (char*) n, &new);
	    lv [j] = n->base.name;
	    Tcl_SetHashValue (he, (ClientData) j);
	    j += 3;
	}
	lc = j + 1;
    } else {
	/* Enumerate all nodes */
	Tcl_HashEntry* he;
	int j, new;

	j = 0;
	for (n = (GN*) g->nodes.first;
	     n != NULL;
	     n = (GN*) n->base.next) {

	    ASSERT_BOUNDS(j, lc-1);
	    he = Tcl_CreateHashEntry (&cn, (char*) n, &new);
	    lv [j] = n->base.name;
	    Tcl_SetHashValue (he, (ClientData) j);
	    j += 3;
	}
	lc = j + 1;
    }

    empty = Tcl_NewObj ();
    Tcl_IncrRefCount (empty);

    /* Fill in the arcs, attributes per node, and graph attributes */

    for (k=0; k < lc-1; k++) {
	ASSERT_BOUNDS(k, lc-1);
	n = gn_get_node (g, lv[k], NULL, NULL);
	k ++;

	ASSERT_BOUNDS(k, lc-1);
	lv [k] = g_attr_serial (n->base.attr, empty);
	k ++;

	ASSERT_BOUNDS(k, lc-1);
	lv [k] = gn_serial_arcs (n, empty, &cn);
    }

    ASSERT_BOUNDS(k, lc);
    lv [k] = g_attr_serial (g->attr, empty);

    /* Put everything together, release scratch space */

    ser = Tcl_NewListObj (lc, lv);

    Tcl_DecrRefCount (empty);
    Tcl_DeleteHashTable(&cn);
    ckfree ((char*) lv);

    return ser;

 abort:
    Tcl_DeleteHashTable(&cn);
    ckfree ((char*) lv);
    return NULL;
}


/* .................................................. */

int
g_deserialize (G* dst, Tcl_Interp* interp, Tcl_Obj* src)
{
    /*
     * SV   = { NODE ATTR/node ARCS ... ATTR/graph }
     *
     * using:
     *		ATTR/x = { key value ... }
     *		ARCS   = { { NAME targetNODEref ATTR/arc } ... }
     *
     * Basic checks:
     * - Is the input a list ?
     * - Is its length a multiple of three modulo 1 ?
     */

    int	      lc, i, j, k;
    Tcl_Obj** lv;
    int	      ac;
    Tcl_Obj** av;
    int	      axc, nref;
    Tcl_Obj** axv;
    int	      nodes;
    G*        new;
    GN*       n;
    GN*       ndst;
    GA*       a;
    int       code = TCL_ERROR;

    if (Tcl_ListObjGetElements (interp, src, &lc, &lv) != TCL_OK) {
	return TCL_ERROR;
    }
    if ((lc % 3) != 1) {
	Tcl_AppendResult (interp,
			  "error in serialization: list length not 1 mod 3.",
			  NULL);
	return TCL_ERROR;
    }

    nodes = (lc-1)/3;

    /* Iteration 1. Check the overall structure of the incoming value (node
     * attributes, arcs, arc attributes, graph attributes).
     */

    if (!g_attr_serok (interp, lv[lc-1], "graph")) {
	return TCL_ERROR;
    }

    for (i=0; i < (lc-1); ) {
	/* Skip node name */
	ASSERT_BOUNDS (i, lc-1);
	i ++ ;
	/* Check node attributes */
	if (!g_attr_serok (interp, lv[i], "node")) {
	    return TCL_ERROR;
	}
	/* Go to the arc information block for the node */
	ASSERT_BOUNDS (i, lc-1);
	i ++;
	/* Check arc information */
	if (Tcl_ListObjGetElements (interp, lv[i], &ac, &av) != TCL_OK) {
	    return TCL_ERROR;
	}
	for (k=0; k < ac; k++) {
	    ASSERT_BOUNDS (k, ac);
	    /* Check each arc */
	    if (Tcl_ListObjGetElements (interp, av[k], &axc, &axv) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if ((axc != 3) && (axc != 4)) {
		Tcl_AppendResult (interp,
				  "error in serialization: arc information length not 3 or 4.",
				  NULL);
		return TCL_ERROR;
	    }
	    /* Check arc attributes */
	    if (!g_attr_serok (interp, axv[2], "arc")) {
		return TCL_ERROR;
	    }
	    /* Check node reference for arc destination */
	    if ((Tcl_GetIntFromObj (interp, axv[1], &nref) != TCL_OK) ||
		(nref % 3) || (nref < 0) || (nref >= lc)) {
		Tcl_ResetResult (interp);
		Tcl_AppendResult (interp,
				  "error in serialization: bad arc destination reference \"",
				  Tcl_GetString (axv[1]),
				  "\".", NULL);
		return TCL_ERROR;
	    }
	}
	/* Go to the next node */
	ASSERT_BOUNDS (i, lc-1);
	i ++;
    }

    /* We now know that the value is structurally sound, i.e. lists, of the
     * specified lengths, fixed, and proper multiples, and that references are
     * kept inside to the proper locations. We can now go over the information
     * again and use it to build up a graph. At that time we can also do the
     * more complex semantic checks (dup nodes, dup arcs).
     *
     * The information is collected directly into a graph structure. We have
     * no better place where to put it. In case of problems we can tear it
     * down again easily, and otherwise we can swap with the actual graph and
     * then tear that one down, effectively replacing it with the new graph.
     */

    new = g_new ();

    /* I. Import the nodes */

    for (i=0; i < (lc-1); i += 3) {
	ASSERT_BOUNDS (i, lc-1);
	n = gn_get_node (new, lv[i], NULL, NULL);
	if (n) {
	    Tcl_AppendResult (interp, 
			      "error in serialization: duplicate node names.",
			      NULL);
	    goto done;
	}
	gn_new (new, Tcl_GetString (lv [i]));
    }

    /* II. Import the arcs */

    for (i=2; i < (lc-1); i += 3) {
	ASSERT_BOUNDS (i, lc-1);
	n = gn_get_node (new, lv[i-2], NULL, NULL);
	Tcl_ListObjGetElements (interp, lv[i], &ac, &av);

	for (k=0; k < ac; k++) {
	    ASSERT_BOUNDS (k, ac);
	    Tcl_ListObjGetElements (interp, av[k], &axc, &axv);
	    a = ga_get_arc (new, axv[0], NULL, NULL);
	    if (a) {
		Tcl_AppendResult (interp, 
				  "error in serialization: duplicate definition of arc \"",
				  Tcl_GetString (axv[0]),"\".", NULL);
		goto done;
	    }
	    Tcl_GetIntFromObj (interp, axv[1], &nref);
	    ndst = gn_get_node (new, lv[nref], NULL, NULL);
	    a = ga_new (new, Tcl_GetString (axv[0]), n, ndst);

	    if (axc == 4) {
		a->weight = axv[3];
		Tcl_IncrRefCount (a->weight);
	    }
	}
    }

    /* III. Import the various attributes */

    for (i=0; i < (lc-1); ) {
	ASSERT_BOUNDS (i, lc-1);
	n = gn_get_node (new, lv[i], NULL, NULL);
	/* Goto node attributes */
	i ++ ;
	/* Import node attributes */
	ASSERT_BOUNDS (i, lc-1);
	g_attr_deserial (&n->base.attr, lv[i]);
	/* Go to the arc information block for the node */
	ASSERT_BOUNDS (i, lc-1);
	i ++;
	/* Check arc information */
	Tcl_ListObjGetElements (interp, lv[i], &ac, &av);
	for (k=0; k < ac; k++) {
	    ASSERT_BOUNDS (k, ac);
	    Tcl_ListObjGetElements (interp, av[k], &axc, &axv);
	    a = ga_get_arc (new, axv[0], NULL, NULL);
	    g_attr_deserial (&a->base.attr, axv[2]);
	}
	/* Go to the next node */
	ASSERT_BOUNDS (i, lc-1);
	i ++;
    }

    g_attr_deserial (&new->attr, lv[lc-1]);

    /* swap dst <-> new. This puts the collected information into the graph
     * associated with the command, and the old information is put into the
     * scratch structure scheduled for destruction, making cleanup automatic.
     */

    swap (dst, new);
    code = TCL_OK;

 done:
    g_delete (new);
    return code;
}

/* .................................................. */

int
g_assign (G* dst, G* src)
{
    G* new = dup (src);
    swap (dst, new);
    g_delete (new);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * g_ms_assign --
 *
 *	Copies the argument graph over into this one. Uses direct
 *	access to internal data structures for matching graph objects, and
 *	goes through a serialize/deserialize combination otherwise.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Only internal, memory allocation changes ...
 *
 *---------------------------------------------------------------------------
 */

int
g_ms_assign (Tcl_Interp* interp, G* g, Tcl_Obj* src)
{
    Tcl_CmdInfo srcInfo;

    if (!Tcl_GetCommandInfo(interp, Tcl_GetString (src), &srcInfo)) {
	Tcl_AppendResult (interp, "invalid command name \"",
			  Tcl_GetString (src), "\"", NULL);
	return TCL_ERROR;
    }

    if (srcInfo.objProc == g_objcmd) {
	/* The source graph object is managed by this code also. We can
	 * retrieve and copy the data directly.
	 */

	G* gsrc = (G*) srcInfo.objClientData;

	return g_assign (g, gsrc);

    } else {
	/* The source graph is not managed by this package. Use
	 * (de)serialization to transfer the information We do not invoke the
	 * command proc directly
	 */

	int	 res;
	Tcl_Obj* ser;
	Tcl_Obj* cmd [2];

	/* Phase 1: Obtain a serialization by invoking the relevant object
	 * method
	 */

	cmd [0] = src;
	cmd [1] = Tcl_NewStringObj ("serialize", -1);

	Tcl_IncrRefCount (cmd [0]);
	Tcl_IncrRefCount (cmd [1]);

	res = Tcl_EvalObjv (interp, 2, cmd, 0);

	Tcl_DecrRefCount (cmd [0]);
	Tcl_DecrRefCount (cmd [1]);

	if (res != TCL_OK) {
	    return TCL_ERROR;
	}

	ser = Tcl_GetObjResult (interp);
	Tcl_IncrRefCount (ser);
	Tcl_ResetResult (interp);

	/* Phase 2: Copy the serializtion into ourselves using the regular
	 * deserialization functionality
	 */

	res = g_deserialize (g, interp, ser);
	Tcl_DecrRefCount (ser);
	return res;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * g_ms_set --
 *
 *	Copies this graph over into the argument graph. Uses direct access to
 *	internal data structures for matching graph objects, and goes through a
 *	serialize/deserialize combination otherwise.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Only internal, memory allocation changes ...
 *
 *---------------------------------------------------------------------------
 */

int
g_ms_set (Tcl_Interp* interp, Tcl_Obj* go, G* g, Tcl_Obj* dst)
{
    Tcl_CmdInfo dstInfo;

    if (!Tcl_GetCommandInfo(interp, Tcl_GetString (dst), &dstInfo)) {
	Tcl_AppendResult (interp, "invalid command name \"",
			  Tcl_GetString (dst), "\"", NULL);
	return TCL_ERROR;
    }

    if (dstInfo.objProc == g_objcmd) {
	/* The destination graph object is managed by this code also We can
	 * retrieve and copy the data directly.
	 */

	G* gdest = (G*) dstInfo.objClientData;

	return g_assign (gdest, g);

    } else {
	/* The destination graph is not managed by this package. Use
	 * (de)serialization to transfer the information We do not invoke the
	 * command proc directly.
	 */

	int	 res;
	Tcl_Obj* ser;
	Tcl_Obj* cmd [3];

	/* Phase 1: Obtain our serialization */

	ser = g_ms_serialize (interp, go, g, 0, NULL);

	/* Phase 2: Copy into destination by invoking the regular
	 * deserialization method
	 */

	cmd [0] = dst;
	cmd [1] = Tcl_NewStringObj ("deserialize", -1);
	cmd [2] = ser;

	Tcl_IncrRefCount (cmd [0]);
	Tcl_IncrRefCount (cmd [1]);
	Tcl_IncrRefCount (cmd [2]);

	res = Tcl_EvalObjv (interp, 3, cmd, 0);

	Tcl_DecrRefCount (cmd [0]);
	Tcl_DecrRefCount (cmd [1]);
	Tcl_DecrRefCount (cmd [2]); /* == ser, is gone now */

	if (res != TCL_OK) {
	    return TCL_ERROR;
	}

	Tcl_ResetResult (interp);
	return TCL_OK;
    }
    return TCL_ERROR;
}


/* .................................................. */

static void
swap (G* dst, G* src)
{
    GC* c;
    G tmp;

    /* Swap the main information */

    tmp  = *dst;
    *dst = *src;
    *src = tmp;

    /* Swap the cmd right back, because this part of the dst structure has to
     * be kept.
     */

    tmp.cmd  = dst->cmd;
    dst->cmd = src->cmd;
    src->cmd = tmp.cmd;

    /* At last fix the node/arc ownership in both structures, or else g_delete
     * will access and destroy the newly created information, and a future
     * delete of the graph accesses long gone memory.
     */

    for (c = src->nodes.first; c != NULL; c = c->next) {
	c->graph = src;
    }
    for (c = src->arcs.first; c != NULL; c = c->next) {
	c->graph = src;
    }

    for (c = dst->nodes.first; c != NULL; c = c->next) {
	c->graph = dst;
    }
    for (c = dst->arcs.first; c != NULL; c = c->next) {
	c->graph = dst;
    }
}

/* .................................................. */

static G*
dup (G* src)
{
    G* new = g_new ();
    GN* no; GN* n;
    GA* ao; GA* a;
    GC* c;

    /* I. Duplicate nodes. NOTE. In the list of nodes in src we break the chain
     * of prev references and use that to point from each src node to its
     * duplicate. This is then used during the duplication of arcs (-> II.) to
     * quickly locate the nodes to connect. After that is done the chain can
     * and is restored.
     */
#define ORIG base.prev

    for (no = (GN*) src->nodes.first;
	 no != NULL;
	 no = (GN*) no->base.next) {

	n = gn_new (new, Tcl_GetString(no->base.name));
	no->ORIG = (GC*) n;
	g_attr_dup (&n->base.attr, no->base.attr);
    }

    /* II. Duplicate the arcs */

    for (ao = (GA*) src->arcs.first;
	 ao != NULL;
	 ao = (GA*) ao->base.next) {
	a = ga_new (new, Tcl_GetString(ao->base.name),
		    (GN*) ao->start->n->ORIG,
		    (GN*) ao->end->n->ORIG);
	g_attr_dup (&a->base.attr, ao->base.attr);

	if (ao->weight) {
	    a->weight = ao->weight;
	    Tcl_IncrRefCount (a->weight);
	}
    }

#undef ORIG

    /* III. Re-chain the nodes in the original */

    c = src->nodes.first;
    if (c) {
	c->prev = NULL;
	c = c->next;

	for (; c != NULL; c = c->next) {
	    if (!c->next) break;
	    c->next->prev = c;
	}
    }

    g_attr_dup (&new->attr, src->attr);
    return new;
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

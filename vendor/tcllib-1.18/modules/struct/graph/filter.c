/* struct::graph - critcl - layer 1 definitions
 * (c) Graph functions
 */

#include <nacommon.h>
#include <util.h>
#include <node.h>

/* .................................................. */

typedef enum NA_MODE {
    NA_ADJ, NA_EMBEDDING, NA_IN, NA_INNER,
    NA_OUT, NA_NONE
} NA_MODE;

typedef struct NA {
    NA_MODE   mode;
    int       nc;
    Tcl_Obj** nv;
    Tcl_Obj*  key;
    Tcl_Obj*  value;
    Tcl_Obj*  filter;
} NA;

typedef struct NARES {
    int       c;
    Tcl_Obj** v;
} NARES;

/* .................................................. */

static int  filter_setup  (NA* na, Tcl_Interp* interp, int oc, Tcl_Obj* const* ov, G* g);
static int  filter_run    (NA* na, Tcl_Interp* interp, int nodes, GCC* gx, GN_GET_GC* gf,
			   Tcl_Obj* go, G* g);
static void filter_none   (Tcl_Interp* interp, GCC* gx, NARES* l);
static void filter_kv     (Tcl_Interp* interp, GCC* gx, NARES* l,
			   GN_GET_GC* gf, G*g, Tcl_Obj* k, Tcl_Obj* v);
static void filter_k      (Tcl_Interp* interp, GCC* gx, NARES* l,
			   GN_GET_GC* gf, G* g, Tcl_Obj* k);
static int  filter_cmd    (Tcl_Interp* interp, GCC* gx, NARES* l,
			   Tcl_Obj* cmd, Tcl_Obj* g);

static void filter_mode_n (NA_MODE mode, GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_n_adj           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_n_emb           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_n_in            (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_n_inn           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_n_out           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a (NA_MODE mode, GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a_adj           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a_emb           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a_in            (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a_inn           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);
static void filter_mode_a_out           (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g);

/* .................................................. */

int
gc_filter (int nodes, Tcl_Interp* interp,
	   int oc, Tcl_Obj* const* ov,
	   GCC* gx, GN_GET_GC* gf, G* g)
{
    NA na;

    if (filter_setup (&na, interp, oc, ov, g) != TCL_OK) {
	return TCL_ERROR;
    }

    return filter_run (&na, interp, nodes, gx, gf, ov [0], g);
}

/* .................................................. */

static int
filter_setup (NA* na, Tcl_Interp* interp, int oc, Tcl_Obj* const* ov, G* g)
{
    /* Syntax: graph arcs                       | all arcs
     *         graph arcs -adj       NODE...    | arcs start|end in node in list
     *         graph arcs -embedding NODE...    | arcs start^end in node in list
     *         graph arcs -filter    CMDPREFIX  | arcs for which CMD returns True.
     *         graph arcs -in        NODE...    | arcs end in node in list
     *         graph arcs -inner     NODE...    | arcs start&end in node in list
     *         graph arcs -key       KEY        | arcs have attribute KEY
     *         graph arcs -out       NODE...    | arcs start in node in list
     *         graph arcs -value     VALUE      | arcs have KEY and VALUE
     *	       [0]   [1]  [2]        [3]
     */

    static const char* restr [] = {
	"-adj",   "-embedding", "-filter", "-in",
	"-inner", "-key",       "-out",    "-value",
	NULL
    };
    enum restr {
	R_ADJ,   R_EMB, R_CMD, R_IN,
	R_INNER, R_KEY, R_OUT, R_VAL
    };
    static const int mode [] = {
	NA_ADJ,   NA_EMBEDDING, -1,     NA_IN,
	NA_INNER, -1,           NA_OUT, -1
    };

    int             ac = oc;
    Tcl_Obj* const* av = ov;
    int             r;

    na->mode   = NA_NONE;
    na->nc     = 0;
    na->nv     = NALLOC (oc, Tcl_Obj*);
    na->key    = NULL;
    na->value  = NULL;
    na->filter = NULL;

    oc -= 2; /* Skip 'graph arcs' */
    ov += 2;

    while (oc) {
	if ('-' == Tcl_GetString (ov[0])[0]) {
	    if (Tcl_GetIndexFromObj (interp, ov [0], restr,
				     "restriction", 0, &r) != TCL_OK) {
		goto abort;
	    }
	    switch (r) {
	    case R_ADJ:
	    case R_EMB:
	    case R_IN:
	    case R_INNER:
	    case R_OUT:
		if (na->mode != NA_NONE) {
		    Tcl_SetObjResult (interp,
		      Tcl_NewStringObj ("invalid restriction: illegal multiple use of \"-in\"|\"-out\"|\"-adj\"|\"-inner\"|\"-embedding\"", -1));
		    goto abort;
		}
		na->mode = mode [r];
		break;
	    case R_CMD:
		if (oc < 2) goto wrongargs;
		if (na->filter) {
		    Tcl_SetObjResult (interp,
		      Tcl_NewStringObj ("invalid restriction: illegal multiple use of \"-filter\"", -1));
		    goto abort;
		}
		na->filter = ov [1];
		oc --;
		ov ++;
		break;
	    case R_KEY:
		if (oc < 2) goto wrongargs;
		if (na->key) {
		    Tcl_SetObjResult (interp,
		      Tcl_NewStringObj ("invalid restriction: illegal multiple use of \"-key\"", -1));
		    goto abort;
		}
		na->key = ov [1];
		oc --;
		ov ++;
		break;
	    case R_VAL:
		if (oc < 2) goto wrongargs;
		if (na->value) {
		    Tcl_SetObjResult (interp,
		      Tcl_NewStringObj ("invalid restriction: illegal multiple use of \"-value\"", -1));
		    goto abort;
		}
		na->value = ov [1];
		oc --;
		ov ++;
		break;
	    }
	    oc --;
	    ov ++;
	} else {
	    /* Save non-options for the list of nodes */
	    ASSERT_BOUNDS (na->nc, ac);
	    na->nv [na->nc] = ov[0];
	    na->nc ++;
	    oc --;
	    ov ++;
	}
    }

    if (na->value && !na->key) {
	Tcl_SetObjResult (interp,
	  Tcl_NewStringObj ("invalid restriction: use of \"-value\" without \"-key\"", -1));
	goto abort;
    }

    if ((na->mode != NA_NONE) && !na->nc) {
    wrongargs:
	Tcl_WrongNumArgs (interp, 2, av,
	  "?-key key? ?-value value? ?-filter cmd? ?-in|-out|-adj|-inner|-embedding node node...?");
	goto abort;
    }

    if (!na->nc) {
	ckfree((char*) na->nv);
	na->nv = NULL;
    } else {
	/* Check that the nodes exist, and
	 * remove duplicates in the same pass
	 */

	int i, j, new;
	Tcl_HashTable cn;
	GN* n;

	Tcl_InitHashTable (&cn, TCL_ONE_WORD_KEYS);

	j=0;
	for (i=0; i < na->nc; i++) {
	    ASSERT_BOUNDS(i, na->nc);
	    n = gn_get_node (g, na->nv[i], interp, av[0]);
	    if (!n) {
		Tcl_DeleteHashTable(&cn);
		goto abort;
	    }
	    if (Tcl_FindHashEntry (&cn, (char*) n)) continue;
	    ASSERT_BOUNDS(j, na->nc);
	    Tcl_CreateHashEntry (&cn, (char*) n, &new);
	    if (j < i) { na->nv[j] = na->nv[i]; }
	    j ++;
	}

	Tcl_DeleteHashTable(&cn);
	na->nc = j;
    }
    return TCL_OK;

 abort:
    ckfree((char*) na->nv);
    return TCL_ERROR;
}

/* .................................................. */

static int
filter_run (NA* na, Tcl_Interp* interp, int nodes, GCC* gx, GN_GET_GC* gf, Tcl_Obj* go, G* g)
{
    NARES l;

    if (!gx->n) {
	/* Nothing to filter, ignore the filters */

	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
	return TCL_OK;
    }

    l.c = -1;
    l.v = NALLOC (gx->n, Tcl_Obj*);

    if (!na->key &&
	!na->filter &&
	(na->mode == NA_NONE)) {
	filter_none (interp, gx, &l);
    } else {
	if (na->mode != NA_NONE) {
	    if (nodes) {
		filter_mode_n (na->mode, gx, &l, na->nc, na->nv, g);
	    } else {
		filter_mode_a (na->mode, gx, &l, na->nc, na->nv, g);
	    }
	}
	if (na->key && na->value) {
	    filter_kv (interp, gx, &l, gf, g, na->key, na->value);
	} else if (na->key) {
	    filter_k  (interp, gx, &l, gf, g, na->key);
	}
	if (na->filter) {
	    if (filter_cmd (interp, gx, &l, na->filter, go) != TCL_OK) {
		ckfree ((char*) l.v);
		return TCL_ERROR;
	    }
	}
    }

    ASSERT(l.c > -1, "No filters applied");
    Tcl_SetObjResult (interp, Tcl_NewListObj (l.c, l.v));
    ckfree ((char*) l.v);
    return TCL_OK;
}

/* .................................................. */

static void
filter_none (Tcl_Interp* interp, GCC* gx, NARES* l)
{
    int i;
    GC* iter;

    for (i = 0, iter = gx->first;
	 iter != NULL;
	 iter = iter->next, i++) {
	ASSERT_BOUNDS (i, gx->n);
	l->v [i] = iter->name;
    }

    ASSERT (i == gx->n, "Bad list of nodes");
    l->c = i;
}

/* .................................................. */

static void
filter_mode_a (NA_MODE mode, GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NS = {node ...}, a set of nodes
     *
     * ARC/in  (NS) := { a | target(a) in NS }     "Arcs going into the node set"
     * ARC/out (NS) := { a | source(a) in NS }     "Arcs coming from the node set"
     * ARC/adj (NS) := ARC/in  (NS) + ARC/out (NS) "Arcs touching the node set"
     * ARC/inn (NS) := ARC/in  (NS) * ARC/out (NS) "Arcs connecting nodes in the set"
     * ARC/emb (NS) := ARC/adj (NS) - ARC/inn (NS) "Arcs touching, yet not connecting"
     *               = ARC/in  (NS) / ARc/out (NS) 'symmetric difference'
     *
     * Note: None of the iterations has to be concerned about space. It is
     * bounded by the number of arcs in the graph, and the list has enough
     * slots.
     */

    switch (mode) {
    case NA_ADJ:       filter_mode_a_adj (gx, l, nc, nv, g); break;
    case NA_EMBEDDING: filter_mode_a_emb (gx, l, nc, nv, g); break;
    case NA_IN:        filter_mode_a_in  (gx, l, nc, nv, g); break;
    case NA_INNER:     filter_mode_a_inn (gx, l, nc, nv, g); break;
    case NA_OUT:       filter_mode_a_out (gx, l, nc, nv, g); break;
    }
}

/* .................................................. */

static void
filter_mode_a_adj (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /* ARC/adj (NS) := ARC/in  (NS) + ARC/out (NS)
     * "Arcs touching the node set"
     */

    /* Iterate over the nodes and collect all incoming and outgoing arcs. We
     * use a hash table to prevent us from entering arcs twice. If we find
     * that all arcs are in the result we stop immediately.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable ht;
    GN*           n;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a, &new);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n, "Overrun");

    if (j < gx->n) {
	for (i=0; i < nc; i++) {
	    ASSERT_BOUNDS(i, nc);
	    n = gn_get_node (g, nv[i], NULL, NULL);
	    for (il = n->out.first; il != NULL; il = il->next) {
		/* Skip if already present - union */
		if (Tcl_FindHashEntry (&ht, (char*) il->a)) continue;
		ASSERT_BOUNDS(j, gx->n);
		Tcl_CreateHashEntry (&ht, (char*) il->a, &new);
		l->v[j] = il->a->base.name;
		j ++;
	    }
	    if (j == gx->n) break;
	}
    }

    ASSERT(j <= gx->n, "Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
}

/* .................................................. */

static void
filter_mode_a_emb (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /* ARC/emb (NS) := ARC/adj (NS) - ARC/inn (NS)
     *               = ARC/in  (NS) / ARc/out (NS)
     * "Arcs touching, yet not connecting"
     */

    /* For the embedding we have to iterate several times. First to collect
     * the relevant arcs in hashtables, then a last time using the hashtables
     * to weed out the inner arcs, i.e the intersection, and collect the
     * others.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable hti;
    Tcl_HashTable hto;
    GN*           n;

    Tcl_InitHashTable (&hti, TCL_ONE_WORD_KEYS);
    Tcl_InitHashTable (&hto, TCL_ONE_WORD_KEYS);

    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    Tcl_CreateHashEntry (&hti, (char*) il->a, &new);
	}
    }
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->out.first; il != NULL; il = il->next) {
	    Tcl_CreateHashEntry (&hto, (char*) il->a, &new);
	}
    }

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    /* Incoming arcs, skip if also outgoing */
	    if (Tcl_FindHashEntry (&hto, (char*) il->a)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* Outgoing arcs, skip if also incoming */
	    if (Tcl_FindHashEntry (&hti, (char*) il->a)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&hti);
    Tcl_DeleteHashTable(&hto);
}

/* .................................................. */

static void
filter_mode_a_in (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /* ARC/in  (NS) := { a | target(a) in NS }
     * "Arcs going into the node set"
     */

    /* Iterate over the nodes and collect all incoming arcs.  */

    int i, j;
    GL* il;
    GN* n;

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    ASSERT_BOUNDS(j, gx->n);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;
}

/* .................................................. */

static void
filter_mode_a_inn (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /* ARC/inn (NS) := ARC/in  (NS) * ARC/out (NS)
     * "Arcs connecting nodes in the set"
     */

    /* Iterate over the nodes and collect all incoming arcs first, in a
     * hashtable. Then iterate a second time to find all outgoing arcs which
     * are also incoming. We skip the second iteration if the first one found all
     * arcs, because then the intersection will remove nothing.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable ht;
    GN*           n;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);

    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    Tcl_CreateHashEntry (&ht, (char*) il->a, &new);
	}
    }

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* Note the !. This is the intersect */
	    if (!Tcl_FindHashEntry (&ht, (char*) il->a)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a, &new);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
}

/* .................................................. */

static void
filter_mode_a_out (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /* ARC/out (NS) := { a | source(a) in NS }
     * "Arcs coming from the node set"
     */

    /* Iterate over the nodes and collect all outcoming arcs.  */

    int i, j;
    GL* il;
    GN* n;

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->out.first; il != NULL; il = il->next) {
	    ASSERT_BOUNDS(j, gx->n);
	    l->v[j] = il->a->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;
}

/* .................................................. */

static void
filter_mode_n (NA_MODE mode, GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/in  (NS) = { source(a) | a in ARC/in  (NS) }
     * NODES/out (NS) = { target(a) | a in ARC/out (NS) }
     * NODES/adj (NS) = NODES/in (NS) + NODES/out (NS)
     * NODES/inn (NS) = NODES/adj (NS) * NS
     * NODES/emb (NS) = NODES/adj (NS) - NS
     */

    switch (mode) {
    case NA_ADJ:       filter_mode_n_adj (gx, l, nc, nv, g); break;
    case NA_EMBEDDING: filter_mode_n_emb (gx, l, nc, nv, g); break;
    case NA_IN:        filter_mode_n_in  (gx, l, nc, nv, g); break;
    case NA_INNER:     filter_mode_n_inn (gx, l, nc, nv, g); break;
    case NA_OUT:       filter_mode_n_out (gx, l, nc, nv, g); break;
    }
}

/* .................................................. */

static void
filter_mode_n_adj (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/adj (NS) = NODES/in (NS) + NODES/out (NS)
     *
     * using:
     *		NODES/in  (NS) = { source(a) | a in ARC/in  (NS) }
     *		NODES/out (NS) = { target(a) | a in ARC/out (NS) }
     */

    /* Iterate over the nodes and collect all incoming and outgoing nodes. We
     * use a hash table to prevent us from entering nodes twice. Should we
     * find that all nodes are in the result during the iteration we stop
     * immediately, it cannot get better.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable ht;
    GN*           n;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	/* foreach n in cn */

	for (il = n->in.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/in (n) */
	    /* il->a in ARC/in (NS) => il->a->start->n in NODES/in (NS) */

	    if (Tcl_FindHashEntry (&ht, (char*) il->a->start->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->start->n, &new);
	    l->v[j] = il->a->start->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/out (n) */
	    /* il->a in ARC/out (NS) => il->a->end->n in NODES/out (NS) */

	    if (Tcl_FindHashEntry (&ht, (char*) il->a->end->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->end->n, &new);
	    l->v[j] = il->a->end->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
    }

    ASSERT(j <= gx->n, "Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
}

/* .................................................. */

static void
filter_mode_n_emb (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/emb (NS) = NODES/adj (NS) - NS
     *
     * using:
     * 		NODES/adj (NS) = NODES/in (NS) + NODES/out (NS)
     *
     * using:
     *		NODES/in  (NS) = { source(a) | a in ARC/in  (NS) }
     *		NODES/out (NS) = { target(a) | a in ARC/out (NS) }
     */

    /* Iterate over the nodes and collect all incoming and outgoing nodes. We
     * use a hash table to prevent us from entering nodes twice. A second hash
     * table is used to skip over the nodes in the set itself.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable ht;
    Tcl_HashTable cn;
    GN*           n;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);
    Tcl_InitHashTable (&cn, TCL_ONE_WORD_KEYS);

    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	/* foreach n in cn */
	Tcl_CreateHashEntry (&cn, (char*) n, &new);
    }

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	/* foreach n in cn */

	for (il = n->in.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/in (n) */
	    /* il->a in ARC/in (NS) => il->a->start->n in NODES/in (NS) */
	    /* - NS */

	    if (Tcl_FindHashEntry (&cn, (char*) il->a->start->n)) continue;
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->start->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->start->n, &new);
	    l->v[j] = il->a->start->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/out (n) */
	    /* il->a in ARC/out (NS) => il->a->end->n in NODES/out (NS) */
	    /* - NS */

	    if (Tcl_FindHashEntry (&cn, (char*) il->a->end->n)) continue;
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->end->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->end->n, &new);
	    l->v[j] = il->a->end->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
    }

    ASSERT(j <= gx->n, "Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
    Tcl_DeleteHashTable(&cn);
}

/* .................................................. */

static void
filter_mode_n_in (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/in (NS) = { source(a) | a in ARC/in (NS) }
     */

    int           i, j, new;
    GL*           il;
    GN*           n;
    Tcl_HashTable ht;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->in.first; il != NULL; il = il->next) {
	    /* il->a in INa (NS) => il->a->start in INn (NS),
	     * modulo already recorded
	     */
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->start->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->start->n, &new);
	    l->v[j] = il->a->start->n->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
}

/* .................................................. */

static void
filter_mode_n_inn (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/inn (NS) = NODES/adj (NS) * NS
     *
     * using:
     * 		NODES/adj (NS) = NODES/in (NS) + NODES/out (NS)
     *
     * using:
     *		NODES/in  (NS) = { source(a) | a in ARC/in  (NS) }
     *		NODES/out (NS) = { target(a) | a in ARC/out (NS) }
     */

    /* Iterate over the nodes and collect all incoming and outgoing nodes. We
     * use a hash table to prevent us from entering nodes twice. A second hash
     * table is used to skip over the nodes _not_ in the set itself.
     */

    int           i, j, new;
    GL*           il;
    Tcl_HashTable ht;
    Tcl_HashTable cn;
    GN*           n;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);
    Tcl_InitHashTable (&cn, TCL_ONE_WORD_KEYS);

    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	/* foreach n in cn */
	Tcl_CreateHashEntry (&cn, (char*) n, &new);
    }

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	/* foreach n in cn */

	for (il = n->in.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/in (n) */
	    /* il->a in ARC/in (NS) => il->a->start->n in NODES/in (NS) */
	    /* * NS */

	    if (!Tcl_FindHashEntry (&cn, (char*) il->a->start->n)) continue;
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->start->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->start->n, &new);
	    l->v[j] = il->a->start->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* foreach a in ARC/out (n) */
	    /* il->a in ARC/out (NS) => il->a->end->n in NODES/out (NS) */
	    /* * NS */

	    if (!Tcl_FindHashEntry (&cn, (char*) il->a->end->n)) continue;
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->end->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->end->n, &new);
	    l->v[j] = il->a->end->n->base.name;
	    j ++;
	}
	if (j == gx->n) break;
    }

    ASSERT(j <= gx->n, "Overrun");
    l->c = j;

    Tcl_DeleteHashTable(&ht);
    Tcl_DeleteHashTable(&cn);
}

/* .................................................. */

static void
filter_mode_n_out (GCC* gx, NARES* l, int nc, Tcl_Obj* const* nv, G* g)
{
    /*
     * NODES/out (NS) = { target(a) | a in ARC/out (NS) }
     */

    int           i, j, new;
    GL*           il;
    GN*           n;
    Tcl_HashTable ht;

    Tcl_InitHashTable (&ht, TCL_ONE_WORD_KEYS);

    j = 0;
    for (i=0; i < nc; i++) {
	ASSERT_BOUNDS(i, nc);
	n = gn_get_node (g, nv[i], NULL, NULL);
	for (il = n->out.first; il != NULL; il = il->next) {
	    /* il->a in OUTa (NS) => il->a->end in OUTn (NS),
	     * modulo already recorded
	     */
	    if (Tcl_FindHashEntry (&ht, (char*) il->a->end->n)) continue;
	    ASSERT_BOUNDS(j, gx->n);
	    Tcl_CreateHashEntry (&ht, (char*) il->a->end->n, &new);
	    l->v[j] = il->a->end->n->base.name;
	    j ++;
	}
    }

    ASSERT(j <= gx->n,"Overrun");
    l->c = j;

    Tcl_DeleteHashTable (&ht);
}

/* .................................................. */

static void
filter_kv (Tcl_Interp* interp, GCC* gx, NARES* l, GN_GET_GC* gf, G* g, Tcl_Obj* k, Tcl_Obj* v)
{
    /* 2 modes:
     * (a) l->c == -1 => Fill with matching entities
     * (b) l->c == 0  => Nothing to do.
     * (c) otherwise  => Filter found entities
     */

    Tcl_HashEntry* he;
    const char*    key;
    const char*    value;
    int            vlen;
    const char*    cmp;
    int            clen;

    /* Skip the step if there is nothing which can be filtered.  */
    if (l->c == 0) return;

    key   = Tcl_GetString (k);
    value = Tcl_GetStringFromObj (v, &vlen);

    if (l->c > 0) {
	/* Filter an existing set of nodes/arcs down to the set of nodes/arcs
	 * passing the filter.
	 */

	int src, dst;
	GC* c;

	for (src = 0, dst = 0; src < l->c; src++) {
	    c = gf (g, l->v [src], NULL, NULL);

	    if (!c->attr) continue;
	    if (!c->attr->numEntries) continue;
	    he = Tcl_FindHashEntry (c->attr, key);
	    if (!he) continue;
	    cmp = Tcl_GetStringFromObj ((Tcl_Obj*) Tcl_GetHashValue(he), &clen);
	    if ((vlen != clen) ||
		(strcmp(value, cmp) != 0)) continue;

	    ASSERT_BOUNDS (dst, l->c);
	    ASSERT_BOUNDS (src, l->c);

	    l->v [dst] = l->v [src];
	    dst++;
	}

	ASSERT (dst <= l->c, "Overrun");
	l->c = dst;

    } else {
	/* There is no set, iterate over nodes/arcs and fill the result with
	 * all nodes/arcs passing the filter.
	 */

	int i;
	GC* iter;

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter = iter->next) {
	    ASSERT_BOUNDS (i, gx->n);

	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;
	    he = Tcl_FindHashEntry (iter->attr, key);
	    if (!he) continue;
	    cmp = Tcl_GetStringFromObj ((Tcl_Obj*) Tcl_GetHashValue(he), &clen);
	    if ((vlen != clen) ||
		(strcmp(value, cmp) != 0)) continue;

	    ASSERT_BOUNDS (i, gx->n);
	    l->v [i] = iter->name;
	    i++;
	}

	ASSERT (i <= gx->n, "Overrun");
	l->c = i;
    }
}

/* .................................................. */

static void
filter_k (Tcl_Interp* interp, GCC* gx, NARES* l, GN_GET_GC* gf, G* g, Tcl_Obj* k)
{
    /* 2 modes:
     * (a) l->c == -1 => Fill with matching entities
     * (b) l->c == 0  => Nothing to do.
     * (c) otherwise  => Filter found entities
     */

    Tcl_HashEntry* he;
    const char*    key;

    /* Skip the step if there is nothing which can be filtered.  */
    if (l->c == 0) return;

    key = Tcl_GetString (k);

    if (l->c > 0) {
	/* Filter an existing set of nodes/arcs down to the set of nodes/arcs
	 * passing the filter.
	 */

	int src, dst;
	GC* c;

	for (src = 0, dst = 0; src < l->c; src++) {
	    c = gf (g, l->v [src], NULL, NULL);

	    if (!c->attr) continue;
	    if (!c->attr->numEntries) continue;
	    he = Tcl_FindHashEntry (c->attr, key);
	    if (!he) continue;

	    ASSERT_BOUNDS (dst, l->c);
	    ASSERT_BOUNDS (src, l->c);

	    l->v [dst] = l->v [src];
	    dst++;
	}

	ASSERT (dst <= l->c, "Overrun");
	l->c = dst;

    } else {
	/* There is no set, iterate over nodes/arcs and fill the result with
	 * all nodes/arcs passing the filter.
	 */

	int i;
	GC* iter;

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter = iter->next) {
	    ASSERT_BOUNDS (i, gx->n);

	    if (!iter->attr) continue;
	    if (!iter->attr->numEntries) continue;
	    he = Tcl_FindHashEntry (iter->attr, key);
	    if (!he) continue;

	    ASSERT_BOUNDS (i, gx->n);
	    l->v [i] = iter->name;
	    i++;
	}

	ASSERT (i <= gx->n, "Overrun");
	l->c = i;
    }
}

/* .................................................. */

static int
filter_cmd (Tcl_Interp* interp, GCC* gx, NARES* l, Tcl_Obj* cmd, Tcl_Obj* g)
{
    /* 2 modes:
     * (a) l->c == -1 => Fill with matching entities
     * (b) l->c == 0  => Nothing to do.
     * (c) otherwise  => Filter found entities
     */

    int       cmdc;
    Tcl_Obj** cmdv;
    int       code = TCL_ERROR;
    int	      ec;
    Tcl_Obj** ev;
    int       flag;
    int       res;
    int       i;

    if (Tcl_ListObjGetElements (interp, cmd, &cmdc, &cmdv) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Skip the step if there is nothing which can be filtered.  */
    if (l->c == 0) {
	return TCL_OK;
    }

    /* -------------------- */
    /* Set up the command vector for the callback. Two placeholders for graph
     * and node/arc arguments.
     */

    ec = cmdc + 2;
    ev = NALLOC (ec, Tcl_Obj*);

    for (i = 0; i < cmdc; i++) {
	ASSERT_BOUNDS (i, ec);
	ev [i] = cmdv [i];
	Tcl_IncrRefCount (ev [i]);
    }

    ASSERT_BOUNDS (cmdc, ec);
    ev [cmdc] = g; /* Graph */
    Tcl_IncrRefCount (ev [cmdc]);

    /* -------------------- */

    if (l->c > 0) {
	/* Filter an existing set of nodes/arcs down to the set of nodes/arcs
	 * passing the filter.
	 */

	int src, dst;

	for (src = 0, dst = 0; src < l->c; src++) {
	    /* Fill the placeholders */

	    ASSERT_BOUNDS (cmdc+1, ec);
	    ASSERT_BOUNDS (src, l->c);
	    ev [cmdc+1] = l->v [src]; /* Node/Arc */

	    /* Run the callback */
	    Tcl_IncrRefCount (ev [cmdc+1]);
	    res = Tcl_EvalObjv (interp, ec, ev, 0);
	    Tcl_DecrRefCount (ev [cmdc+1]);

	    /* Process the result */
	    if (res != TCL_OK) {
		goto abort;
	    }
	    if (Tcl_GetBooleanFromObj (interp,
				       Tcl_GetObjResult (interp),
				       &flag) != TCL_OK) {
		goto abort;
	    }

	    /* Result is valid, use this to decide retain/write over */
	    if (!flag) continue;

	    ASSERT_BOUNDS (dst, l->c);
	    ASSERT_BOUNDS (src, l->c);

	    l->v [dst] = l->v [src];
	    dst++;
	}

	ASSERT (dst <= l->c, "Overrun");
	l->c = dst;

    } else {
	/* There is no set, iterate over nodes/arcs and fill the result with
	 * all nodes/arcs passing the filter.
	 */

	int i;
	GC* iter;

	for (i = 0, iter = gx->first;
	     iter != NULL;
	     iter = iter->next) {
	    ASSERT_BOUNDS (i, gx->n);

	    /* Fill the placeholders */

	    ASSERT_BOUNDS (cmdc+1, ec);
	    ev [cmdc+1] = iter->name; /* Node/Arc */

	    /* Run the callback */
	    Tcl_IncrRefCount (ev [cmdc+1]);
	    res = Tcl_EvalObjv (interp, ec, ev, 0);
	    Tcl_DecrRefCount (ev [cmdc+1]);

	    /* Process the result */
	    if (res != TCL_OK) {
		goto abort;
	    }
	    if (Tcl_GetBooleanFromObj (interp,
				       Tcl_GetObjResult (interp),
				       &flag) != TCL_OK) {
		goto abort;
	    }

	    /* Result is valid, use this to decide retain/write over */
	    if (!flag) continue;

	    ASSERT_BOUNDS (i, gx->n);
	    l->v [i] = iter->name;
	    i++;
	}

	ASSERT (i <= gx->n, "Overrun");
	l->c = i;
    }

    /* -------------------- */
    /* Cleanup state */

    Tcl_ResetResult (interp);
    code = TCL_OK;

 abort:
    /* We do not reset the interp result. It either contains the non-boolean
     * result, or the error message.
     */

    for (i = 0; i < cmdc; i++) {
	ASSERT_BOUNDS (i, ec);
	Tcl_DecrRefCount (ev [i]);
    }

    ASSERT_BOUNDS (cmdc, ec);
    Tcl_DecrRefCount (ev [cmdc]); /* Graph */
    ckfree ((char*) ev);

    /* -------------------- */
    return code;
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

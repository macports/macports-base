
#include "tcl.h"
#include <graph.h>
#include <util.h>
#include <walk.h>

/* .................................................. */

static int walkdfspre  (Tcl_Interp* interp, GN* n, int dir,
			Tcl_HashTable* v, int cc, Tcl_Obj** ev,
			Tcl_Obj* action);
static int walkdfspost (Tcl_Interp* interp, GN* n, int dir,
			Tcl_HashTable* v, int cc, Tcl_Obj** ev,
			Tcl_Obj* action);
static int walkdfsboth (Tcl_Interp* interp, GN* n, int dir,
			Tcl_HashTable* v, int cc, Tcl_Obj** ev,
			Tcl_Obj* enter, Tcl_Obj* leave);
static int walkbfspre  (Tcl_Interp* interp, GN* n, int dir,
			Tcl_HashTable* v, int cc, Tcl_Obj** ev,
			Tcl_Obj* action);

static int walk_invoke (Tcl_Interp* interp, GN* n,
			int cc, Tcl_Obj** ev, Tcl_Obj* action);

static int walk_neighbours (GN* n, Tcl_HashTable* v, int dir,
			    int* nc, GN*** nv);

/* .................................................. */

int
g_walkoptions (Tcl_Interp* interp,
	       int objc, Tcl_Obj* const* objv,
	       int* type, int* order, int* dir,
	       int* cc, Tcl_Obj*** cv)
{
    int       xcc, xtype, xorder, xdir, i;
    Tcl_Obj** xcv;
    Tcl_Obj*  wtype  = NULL;
    Tcl_Obj*  worder = NULL;
    Tcl_Obj*  wdir   = NULL;
    Tcl_Obj*  wcmd   = NULL;

    static CONST char* wtypes [] = {
	"bfs", "dfs", NULL
    };
    static CONST char* worders [] = {
	"both", "pre", "post", NULL
    };
    static CONST char* wdirs [] = {
	"backward", "forward", NULL
    };

    for (i = 3; i < objc; ) {
	ASSERT_BOUNDS (i, objc);
	if (0 == strcmp ("-type", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) {
	    wrongargs:
		Tcl_AppendResult (interp,
				  "value for \"", Tcl_GetString (objv[i]),
				  "\" missing, should be \"",
				  Tcl_GetString (objv [0]), " walk ",
				  W_USAGE, "\"", NULL);
		return TCL_ERROR;
	    }

	    ASSERT_BOUNDS (i+1, objc);
	    wtype = objv [i+1];
	    i += 2;

	} else if (0 == strcmp ("-order", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) goto wrongargs;

	    ASSERT_BOUNDS (i+1, objc);
	    worder = objv [i+1];
	    i += 2;

	} else if (0 == strcmp ("-dir", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) goto wrongargs;

	    ASSERT_BOUNDS (i+1, objc);
	    wdir = objv [i+1];
	    i += 2;

	} else if (0 == strcmp ("-command", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) goto wrongargs;

	    ASSERT_BOUNDS (i+1, objc);
	    wcmd = objv [i+1];
	    i += 2;

	} else {
	    Tcl_AppendResult (interp, "unknown option \"",
			      Tcl_GetString (objv [i]), "\": should be \"",
			      Tcl_GetString (objv [0]), " walk ",
			      W_USAGE, "\"", NULL);
	    return TCL_ERROR;
	    break;
	}
    }

    if (i < objc) {
	Tcl_WrongNumArgs (interp, 2, objv, W_USAGE);
	return TCL_ERROR;
    }

    if (!wcmd) {
    no_command:
	Tcl_AppendResult (interp,
			  "no command specified: should be \"",
			  Tcl_GetString (objv [0]), " walk ",
			  W_USAGE, "\"", NULL);
	return TCL_ERROR;
    } else if (Tcl_ListObjGetElements (interp, wcmd, &xcc, &xcv) != TCL_OK) {
	return TCL_ERROR;
    } else if (xcc == 0) {
	goto no_command;
    }

    xtype  = WG_DFS;
    xorder = WO_PRE;
    xdir   = WD_FORWARD;

    if (wtype &&
	(Tcl_GetIndexFromObj (interp, wtype, wtypes,
			      "search type", 0, &xtype) != TCL_OK)) {
	return TCL_ERROR;
    }

    if (worder &&
	(Tcl_GetIndexFromObj (interp, worder, worders,
			      "search order", 0, &xorder) != TCL_OK)) {
	return TCL_ERROR;
    }

    if (wdir &&
	(Tcl_GetIndexFromObj (interp, wdir, wdirs,
			      "search direction", 0, &xdir) != TCL_OK)) {
	return TCL_ERROR;
    }

    if (xtype == WG_BFS) {
	if (xorder == WO_BOTH) {
	    Tcl_AppendResult (interp,
			      "unable to do a both-order breadth first walk",
			      NULL);
	    return TCL_ERROR;
	}
	if (xorder == WO_POST) {
	    Tcl_AppendResult (interp,
			      "unable to do a post-order breadth first walk",
			      NULL);
	    return TCL_ERROR;
	}
    }

    *type  = xtype;
    *order = xorder;
    *dir   = xdir;
    *cc    = xcc;
    *cv    = xcv;

    return TCL_OK;
}

/* .................................................. */

int
g_walk (Tcl_Interp* interp, Tcl_Obj* go, GN* n,
	int type, int order, int dir,
	int cc, Tcl_Obj** cv)
{
    int       ec, res, i;
    Tcl_Obj** ev;
    Tcl_Obj*  la = NULL;
    Tcl_Obj*  lb = NULL;

    Tcl_HashTable v;

    /* Area to remember which nodes have been visited already */
    Tcl_InitHashTable (&v, TCL_ONE_WORD_KEYS);

    ec = cc + 3;
    ev = NALLOC (ec, Tcl_Obj*);

    for (i=0;i<cc;i++) {
	ev [i] = cv [i];
	Tcl_IncrRefCount (ev [i]);
    }

    /* cc+0 action
     * cc+1 graph  **
     * cc+2 node
     */

    ev [cc+1] = go;
    Tcl_IncrRefCount (ev [cc+1]);

    switch (type) {
    case WG_DFS:
	switch (order) {
	case WO_BOTH:
	    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);
	    lb = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (lb);

	    res = walkdfsboth (interp, n, dir, &v, cc, ev, la, lb);

	    Tcl_DecrRefCount (la);
	    Tcl_DecrRefCount (lb);
	    break;

	case WO_PRE:
	    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);

	    res = walkdfspre (interp, n, dir, &v, cc, ev, la);

	    Tcl_DecrRefCount (la);
	    break;

	case WO_POST:
	    la = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (la);

	    res = walkdfspost (interp, n, dir, &v, cc, ev, la);

	    Tcl_DecrRefCount (la);
	    break;
	}
	break;

    case WG_BFS:
	switch (order) {
	case WO_BOTH:
	case WO_POST: Tcl_Panic ("impossible combination bfs/(both|post)"); break;
	case WO_PRE:
	    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);

	    res = walkbfspre (interp, n, dir, &v, cc, ev, la);

	    Tcl_DecrRefCount (la);
	    break;
	}
	break;
    }

    for (i=0; i<cc; i++) {
	Tcl_DecrRefCount (ev [i]);
    }
    Tcl_DecrRefCount (ev [cc+1]);
    ckfree ((char*) ev);

    Tcl_DeleteHashTable (&v);

    /* Error and Return are passed unchanged. Everything else is ok */

    if (res == TCL_ERROR)  {return res;}
    if (res == TCL_RETURN) {return res;}
    return TCL_OK;
}


/* .................................................. */

int
walk_invoke (Tcl_Interp* interp, GN* n,
	       int cc, Tcl_Obj** ev, Tcl_Obj* action)
{
    int res;

    /* cc+0 action **
     * cc+1 graph
     * cc+2 node   **
     */

    ev [cc+0] = action;        /* enter/leave */
    ev [cc+2] = n->base.name ; /* node */
    /* ec = cc+3 */

    Tcl_IncrRefCount (ev [cc+0]);
    Tcl_IncrRefCount (ev [cc+2]);

    res = Tcl_EvalObjv (interp, cc+3, ev, 0);

    Tcl_DecrRefCount (ev [cc+0]);
    Tcl_DecrRefCount (ev [cc+2]);

    return res;
}

/* .................................................. */

static int
walk_neighbours (GN* n, Tcl_HashTable* vn, int dir,
		 int* nc, GN*** nv)
{
    GLA* neigh;
    GL*  il;
    int  c, i;
    GN** v;

    if (dir == WD_BACKWARD) {
	neigh = &n->in;
    } else {
	neigh = &n->out;
    }

    c = 0;
    v = NULL;

    if (neigh->n) {
	/* We make a copy of the neighbours. This emulates the behaviour of
	 * the Tcl implementation, which will walk to a neighbour of this
	 * node, even if the command moved it to a different node before it
	 * was reached by the loop here. If the node the neighbours is moved
	 * to was already visited nothing else will happen. Ortherwise the
	 * neighbours will be visited multiple times.
	 */

	c = neigh->n;
	v = NALLOC (c, GN*);

	if (dir == WD_BACKWARD) {
	    for (i=0, il = neigh->first;
		 il != NULL;
		 il = il->next) {
		if (Tcl_FindHashEntry (vn, (char*) il->a->start->n)) continue;
		ASSERT_BOUNDS (i, c);
		v [i] = il->a->start->n;
		i++;
	    }
	} else {
	    for (i=0, il = neigh->first;
		 il != NULL;
		 il = il->next) {
		if (Tcl_FindHashEntry (vn, (char*) il->a->end->n)) continue;
		ASSERT_BOUNDS (i, c);
		v [i] = il->a->end->n;
		i++;
	    }
	}

	c = i;
	if (!c) {
	    ckfree ((char*) v);
	    v = NULL;
	}
    }

    *nc = c;
    *nv = v;
}

/* .................................................. */

static int
walkdfspre (Tcl_Interp* interp, GN* n, int dir, Tcl_HashTable* v,
	      int cc, Tcl_Obj** ev, Tcl_Obj* action)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     */

    int  nc, res, new;
    GN** nv;

    /* Current node before neighbours, action is 'enter'. */

    res = walk_invoke (interp, n, cc, ev, action);

    if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	return res;
    }

    Tcl_CreateHashEntry (v, (char*) n, &new);
    walk_neighbours  (n, v, dir, &nc, &nv);

    if (nc) {
	int i;
	for (i = 0; i < nc; i++) {
	    /* Skip nodes already visited deeper in the recursion */
	    if (Tcl_FindHashEntry (v, (char*) nv[i])) continue;

	    res = walkdfspre (interp, nv [i], dir, v, cc, ev, action);

	    /* continue cannot occur, were transformed into ok by the
	     * neighbour.
	     */

	    if (res != TCL_OK) {
		ckfree ((char*) nv);
		return res;
	    }
	}

	ckfree ((char*) nv);
    }

    return TCL_OK;
}

static int
walkdfspost (Tcl_Interp* interp, GN* n, int dir, Tcl_HashTable* v,
	      int cc, Tcl_Obj** ev, Tcl_Obj* action)
{
    int  nc, res, new;
    GN** nv;

    /* Current node after neighbours, action is 'leave'. */

    Tcl_CreateHashEntry (v, (char*) n, &new);
    walk_neighbours  (n, v, dir, &nc, &nv);

    if (nc) {
	int i;
	for (i = 0; i < nc; i++) {
	    /* Skip nodes already visited deeper in the recursion */
	    if (Tcl_FindHashEntry (v, (char*) nv[i])) continue;

	    res = walkdfspost (interp, nv [i], dir, v, cc, ev, action);

	    if ((res == TCL_ERROR) ||
		(res == TCL_BREAK) ||
		(res == TCL_RETURN)) {
		ckfree ((char*) nv);
		return res;
	    }
	}

	ckfree ((char*) nv);
    }

    res = walk_invoke (interp, n, cc, ev, action);

    if ((res == TCL_ERROR) ||
	(res == TCL_BREAK) ||
	(res == TCL_RETURN)) {
	return res;
    }

    return TCL_OK;
}

static int
walkdfsboth (Tcl_Interp* interp, GN* n, int dir, Tcl_HashTable* v,
	       int cc, Tcl_Obj** ev, Tcl_Obj* enter, Tcl_Obj* leave)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     */

    int  nc, res, new;
    GN** nv;

    /* Current node before and after neighbours, action is 'enter' & 'leave'. */

    res = walk_invoke (interp, n, cc, ev, enter);

    if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	return res;
    }

    Tcl_CreateHashEntry (v, (char*) n, &new);
    walk_neighbours  (n, v, dir, &nc, &nv);

    if (nc) {
	int i;
	for (i = 0; i < nc; i++) {
	    /* Skip nodes already visited deeper in the recursion */
	    if (Tcl_FindHashEntry (v, (char*) nv[i])) continue;

	    res = walkdfsboth (interp, nv [i], dir, v, cc, ev, enter, leave);

	    /* continue cannot occur, were transformed into ok by the
	     * neighbour.
	     */

	    if (res != TCL_OK) {
		ckfree ((char*) nv);
		return res;
	    }
	}

	ckfree ((char*) nv);
    }

    res = walk_invoke (interp, n, cc, ev, leave);

    if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	return res;
    }

    return TCL_OK;
}

static int
walkbfspre (Tcl_Interp* interp, GN* n, int dir, Tcl_HashTable* v,
	      int cc, Tcl_Obj** ev, Tcl_Obj* action)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     */

    int  nc, res, new;
    GN** nv;
    NLQ  q;

    g_nlq_init   (&q);
    g_nlq_append (&q, n);

    while (1) {
	n = g_nlq_pop (&q);
	if (!n) break;

	/* Skip nodes already visited deeper in the recursion */
	if (Tcl_FindHashEntry (v, (char*) n)) continue;

	res = walk_invoke (interp, n, cc, ev, action);

	if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	    g_nlq_clear (&q);
	    return res;
	}

	Tcl_CreateHashEntry (v, (char*) n, &new);
	walk_neighbours  (n, v, dir, &nc, &nv);

	if (nc) {
	    int i;
	    for (i = 0; i < nc; i++) {
		g_nlq_append (&q, nv [i]);
	    }

	    ckfree ((char*) nv);
	}
    }

    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

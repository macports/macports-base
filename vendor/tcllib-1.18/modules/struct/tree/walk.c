
#include <string.h>
#include "tcl.h"
#include <t.h>
#include <util.h>

/* .................................................. */

static int t_walkdfspre	 (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* action);
static int t_walkdfspost (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* action);
static int t_walkdfsin	 (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* action);
static int t_walkdfsboth (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* enter, Tcl_Obj* leave);
static int t_walkbfspre	 (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* action);
static int t_walkbfspost (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* action);
static int t_walkbfsboth (Tcl_Interp* interp, TN* tdn, t_walk_function f,
			  Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
			  Tcl_Obj* enter, Tcl_Obj* leave);

/* .................................................. */

int
t_walkoptions (Tcl_Interp* interp, int n,
	       int objc, Tcl_Obj* CONST* objv,
	       int* type, int* order, int* remainder,
	       char* usage)
{
    int i;
    Tcl_Obj* otype  = NULL;
    Tcl_Obj* oorder = NULL;

    static CONST char* wtypes [] = {
	"bfs", "dfs", NULL
    };
    static CONST char* worders [] = {
	"both", "in", "pre", "post", NULL
    };

    for (i = 3; i < objc; ) {
	ASSERT_BOUNDS (i, objc);
	if (0 == strcmp ("-type", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) {
		Tcl_AppendResult (interp,
				  "value for \"-type\" missing",
				  NULL);
		return TCL_ERROR;
	    }

	    ASSERT_BOUNDS (i+1, objc);
	    otype = objv [i+1];
	    i += 2;

	} else if (0 == strcmp ("-order", Tcl_GetString (objv [i]))) {
	    if (objc == (i+1)) {
		Tcl_AppendResult (interp,
				  "value for \"-order\" missing",
				  NULL);
		return TCL_ERROR;
	    }

	    ASSERT_BOUNDS (i+1, objc);
	    oorder = objv [i+1];
	    i += 2;

	} else if (0 == strcmp ("--", Tcl_GetString (objv [i]))) {
	    i++;
	    break;
	} else {
	    break;
	}
    }

    if (i == objc) {
	Tcl_WrongNumArgs (interp, 2, objv, usage);
	return TCL_ERROR;
    }

    if ((objc - i) > n) {
	Tcl_AppendResult (interp, "unknown option \"", NULL);
	Tcl_AppendResult (interp, Tcl_GetString (objv [i]), NULL);
	Tcl_AppendResult (interp, "\"", NULL);
	return TCL_ERROR;
    }

    if (!otype) {
	*type = WT_DFS;
    } else if (Tcl_GetIndexFromObj (interp, otype, wtypes, "search type",
				    0, type) != TCL_OK) {
	return TCL_ERROR;
    }

    if (!oorder) {
	*order = WO_PRE;
    } else if (Tcl_GetIndexFromObj (interp, oorder, worders, "search order",
				    0, order) != TCL_OK) {
	return TCL_ERROR;
    }

    if ((*order == WO_IN) && (*type == WT_BFS)) {
	Tcl_AppendResult (interp,
			  "unable to do a in-order breadth first walk",
			  NULL);
	return TCL_ERROR;
    }

    *remainder = i;
    return TCL_OK;
}

/* .................................................. */

int
t_walk (Tcl_Interp* interp, TN* tdn, int type, int order,
	t_walk_function f, Tcl_Obj* cs,
	Tcl_Obj* avn, Tcl_Obj* nvn)
{
    int	     res;
    Tcl_Obj* la = NULL;
    Tcl_Obj* lb = NULL;

    switch (type)
	{
	case WT_DFS:
	    switch (order)
		{
		case WO_BOTH:
		    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);
		    lb = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (lb);

		    res = t_walkdfsboth (interp, tdn, f, cs, avn, nvn, la, lb);

		    Tcl_DecrRefCount (la);
		    Tcl_DecrRefCount (lb);
		    break;

		case WO_IN:
		    la = Tcl_NewStringObj ("visit",-1); Tcl_IncrRefCount (la);

		    res = t_walkdfsin	(interp, tdn, f, cs, avn, nvn, la);

		    Tcl_DecrRefCount (la);
		    break;

		case WO_PRE:
		    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);

		    res = t_walkdfspre	(interp, tdn, f, cs, avn, nvn, la);

		    Tcl_DecrRefCount (la);
		    break;

		case WO_POST:
		    la = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (la);

		    res = t_walkdfspost (interp, tdn, f, cs, avn, nvn, la);

		    Tcl_DecrRefCount (la);
		    break;
		}
	    break;

	case WT_BFS:
	    switch (order)
		{
		case WO_BOTH:
		    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);
		    lb = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (lb);

		    res = t_walkbfsboth (interp, tdn, f, cs, avn, nvn, la, lb);

		    Tcl_DecrRefCount (la);
		    Tcl_DecrRefCount (lb);
		    break;

		case WO_PRE:
		    la = Tcl_NewStringObj ("enter",-1); Tcl_IncrRefCount (la);

		    res = t_walkbfspre	(interp, tdn, f, cs, avn, nvn, la);

		    Tcl_DecrRefCount (la);
		    break;

		case WO_POST:
		    la = Tcl_NewStringObj ("leave",-1); Tcl_IncrRefCount (la);

		    res = t_walkbfspost (interp, tdn, f, cs, avn, nvn, la);

		    Tcl_DecrRefCount (la);
		    break;
		}
	    break;
	}

    /* Error and Return are passed unchanged. Everything else is ok */

    if (res == TCL_ERROR)  {return res;}
    if (res == TCL_RETURN) {return res;}
    return TCL_OK;
}


/* .................................................. */

int
t_walk_invokescript (Tcl_Interp* interp, TN* n, Tcl_Obj* cs,
		     Tcl_Obj* avn, Tcl_Obj* nvn,
		     Tcl_Obj* action)
{
    int res;

    /* Note: Array elements, like 'a(x)', are not possible as iterator variables */

    if (avn) {
	Tcl_ObjSetVar2 (interp, avn, NULL, action, 0);
    }
    Tcl_ObjSetVar2 (interp, nvn, NULL, n->name, 0);

    res = Tcl_EvalObj(interp, cs);

    return res;
}

int
t_walk_invokecmd (Tcl_Interp* interp, TN* n, Tcl_Obj* dummy0,
		  Tcl_Obj* dummy1, Tcl_Obj* dummy2,
		  Tcl_Obj* action)
{
    int	      res;
    int	      cc = (int)       dummy0;
    Tcl_Obj** ev = (Tcl_Obj**) dummy1; /* cc+3 elements */

    ev [cc]   = dummy2;	   /* Tree */
    ev [cc+1] = n->name;   /* Node */
    ev [cc+2] = action;	   /* Action */

    Tcl_IncrRefCount (ev [cc]);
    Tcl_IncrRefCount (ev [cc+1]);
    Tcl_IncrRefCount (ev [cc+2]);

    res = Tcl_EvalObjv (interp, cc+3, ev, 0);

    Tcl_DecrRefCount (ev [cc]);
    Tcl_DecrRefCount (ev [cc+1]);
    Tcl_DecrRefCount (ev [cc+2]);

    return res;
}

/* .................................................. */

static int
t_walkdfspre (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	      Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	      Tcl_Obj* action)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     * prune /5 - skip children, otherwise ok.
     */

    int res;

    /* Parent before children, action is 'enter'. */

    res = (*f) (interp, tdn, cs, avn, nvn, action);

    if (res == 5) {
	return TCL_OK;
    } else if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	return res;
    }

    if (tdn->nchildren) {
	/* We make a copy of the child array. This emulates the behaviour of
	 * the Tcl implementation, which will walk to a child of this node,
	 * even if the loop body/procedure moved it to a different node before
	 * it was reached by the loop here. If the node it the child is moved
	 * to was already visited nothing else will happen. Ortherwise the
	 * child will be visited multiple times.
	 */

	int i;
	int  nc = tdn->nchildren;
	TN** nv = NALLOC (nc,TN*);
	memcpy (nv, tdn->child, nc*sizeof(TN*));

	for (i = 0; i < nc; i++) {
	    res = t_walkdfspre (interp, nv [i], f, cs, avn, nvn, action);

	    /* prune, continue cannot occur, were transformed into ok
	     * by the child.
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
t_walkdfspost (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	       Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	       Tcl_Obj* action)
{
    int res;

    /* Parent after children, action is 'leave'. */

    if (tdn->nchildren) {
	/* We make a copy of the child array. This emulates the behaviour of
	 * the Tcl implementation, which will walk to a child of this node,
	 * even if the loop body/procedure moved it to a different node before
	 * it was reached by the loop here. If the node it the child is moved
	 * to was already visited nothing else will happen. Ortherwise the
	 * child will be visited multiple times.
	 */

	int i;

	int  nc = tdn->nchildren;
	TN** nv = NALLOC (nc,TN*);
	memcpy (nv, tdn->child, nc*sizeof(TN*));

	for (i = 0; i < nc; i++) {
	    res = t_walkdfspost (interp, nv [i], f, cs, avn, nvn, action);

	    if ((res == TCL_ERROR) ||
		(res == TCL_BREAK) ||
		(res == TCL_RETURN)) {
		ckfree ((char*) nv);
		return res;
	    }
	}

	ckfree ((char*) nv);
    }

    res = (*f) (interp, tdn, cs, avn, nvn, action);

    if ((res == TCL_ERROR) ||
	(res == TCL_BREAK) ||
	(res == TCL_RETURN)) {
	return res;
    } else if (res == 5) {
	/* Illegal pruning */

	Tcl_ResetResult (interp);
	Tcl_AppendResult (interp,
			  "Illegal attempt to prune post-order walking", NULL);
	return TCL_ERROR;
    }

    return TCL_OK;
}

static int
t_walkdfsboth (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	       Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	       Tcl_Obj* enter, Tcl_Obj* leave)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     * prune /5 - skip children, otherwise ok.
     */

    int res;

    /* Parent before and after Children, action is 'enter' & 'leave'. */

    res = (*f) (interp, tdn, cs, avn, nvn, enter);

    if (res != 5) {
	if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	    return res;
	}

	if (tdn->nchildren) {
	    int i;
	    int  nc = tdn->nchildren;
	    TN** nv = NALLOC (nc,TN*);
	    memcpy (nv, tdn->child, nc*sizeof(TN*));

	    for (i = 0; i < nc; i++) {
		res = t_walkdfsboth (interp, nv [i], f, cs, avn, nvn, enter, leave);

		/* prune, continue cannot occur, were transformed into ok
		 * by the child.
		 */

		if (res != TCL_OK) {
		    ckfree ((char*) nv);
		    return res;
		}
	    }

	    ckfree ((char*) nv);
	}
    }

    res = (*f) (interp, tdn, cs, avn, nvn, leave);

    if (res == 5) {
	return TCL_OK;
    } else if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	return res;
    }

    return TCL_OK;
}

static int
t_walkdfsin (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	     Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	     Tcl_Obj* action)
{
    int res;

    /* First child visited first, then parent, then */
    /* the remaining children. Action is 'visit'.   */
    /* This is the correct thing for binary trees.  */
    /* For #children <= 1 the parent is visited */
    /* before the child */

    if (tdn->nchildren == 0) {
	res = (*f) (interp, tdn, cs, avn, nvn, action);

	if ((res == TCL_ERROR) ||
	    (res == TCL_BREAK) ||
	    (res == TCL_RETURN)) {
	    return res;
	} else if (res == 5) {
	    /* Illegal pruning */

	    Tcl_ResetResult (interp);
	    Tcl_AppendResult (interp,
			      "Illegal attempt to prune in-order walking", NULL);
	    return TCL_ERROR;
	}

    } else if (tdn->nchildren == 1) {
	res = (*f) (interp, tdn, cs, avn, nvn, action);

	if ((res == TCL_ERROR) ||
	    (res == TCL_BREAK) ||
	    (res == TCL_RETURN)) {
	    return res;
	} else if (res == 5) {
	    /* Illegal pruning */

	    Tcl_ResetResult (interp);
	    Tcl_AppendResult (interp,
			      "Illegal attempt to prune in-order walking", NULL);
	    return TCL_ERROR;
	}

	return t_walkdfsin (interp, tdn->child [0], f, cs, avn, nvn, action);

    } else {
	int i;
	int  nc = tdn->nchildren;
	TN** nv = NALLOC (nc,TN*);
	memcpy (nv, tdn->child, nc*sizeof(TN*));

	res = t_walkdfsin (interp, tdn->child [0], f, cs, avn, nvn, action);

	if ((res == TCL_ERROR) ||
	    (res == TCL_BREAK) ||
	    (res == TCL_RETURN)) {
	    ckfree ((char*) nv);
	    return res;
	}

	res = (*f) (interp, tdn, cs, avn, nvn, action);

	if ((res == TCL_ERROR) ||
	    (res == TCL_BREAK) ||
	    (res == TCL_RETURN)) {
	    ckfree ((char*) nv);
	    return res;
	} else if (res == 5) {
	    /* Illegal pruning */
	    ckfree ((char*) nv);

	    Tcl_ResetResult (interp);
	    Tcl_AppendResult (interp,
			      "Illegal attempt to prune in-order walking", NULL);
	    return TCL_ERROR;
	}

	for (i = 1; i < nc; i++) {
	    res = t_walkdfsin (interp, nv [i], f, cs, avn, nvn, action);

	    if ((res == TCL_ERROR) ||
		(res == TCL_BREAK) ||
		(res == TCL_RETURN)) {
		ckfree ((char*) nv);
		return res;
	    }
	}

	ckfree ((char*) nv);
    }

    return TCL_OK;
}

static int
t_walkbfsboth (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	       Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	       Tcl_Obj* enter, Tcl_Obj* leave)
{
    /* ok	- next node
     * error	- abort walking
     * break	- pre: abort walking, skip to post, post: abort walking
     * continue - next node
     * return	- abort walking
     * prune /5 - skip children, otherwise ok.
   */

    int res;
    TN* n;
    NLQ q;
    NLQ qb;

    nlq_init (&q);
    nlq_init (&qb);

    nlq_append (&q,  tdn);
    nlq_push   (&qb, tdn);

    while (1) {
	n = nlq_pop (&q);
	if (!n) break;

	res = (*f) (interp, n, cs, avn, nvn, enter);

	if (res == 5) {
	    continue;
	} else if (res == TCL_ERROR) {
	    nlq_clear (&q);
	    nlq_clear (&qb);
	    return res;
	} else if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	    nlq_clear (&q);

	    /* We abort the collection of more nodes, but still run the
	     * backward iteration (post-order phase).
	     */
	    break;
	}

	if (n->nchildren) {
	    int i;
	    for (i = 0; i < n->nchildren; i++) {
		nlq_append (&q,	 n->child [i]);
		nlq_push   (&qb, n->child [i]);
	    }
	}
    }

    /* Backward visit to leave */

    while (1) {
	n = nlq_pop (&qb);
	if (!n) break;

	res = (*f) (interp, n, cs, avn, nvn, leave);

	if (res == 5) {
	    continue;
	} else if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	    nlq_clear (&qb);
	    return res;
	}
    }

    return TCL_OK;
}

static int
t_walkbfspre (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	      Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	      Tcl_Obj* action)
{
    /* ok	- next node
     * error	- abort walking
     * break	- abort walking
     * continue - next node
     * return	- abort walking
     * prune /5 - skip children, otherwise ok.
   */

    int res;
    TN* n;
    NLQ q;

    nlq_init   (&q);
    nlq_append (&q, tdn);

    while (1) {
	n = nlq_pop (&q);
	if (!n) break;

	res = (*f) (interp, n, cs, avn, nvn, action);

	if (res == 5) {
	    continue;
	} else if ((res != TCL_OK) && (res != TCL_CONTINUE)) {
	    nlq_clear (&q);
	    return res;
	}

	if (n->nchildren) {
	    int i;
	    for (i = 0; i < n->nchildren; i++) {
		nlq_append (&q, n->child [i]);
	    }
	}
    }

    return TCL_OK;
}

static int
t_walkbfspost (Tcl_Interp* interp, TN* tdn, t_walk_function f,
	       Tcl_Obj* cs, Tcl_Obj* avn, Tcl_Obj* nvn,
	       Tcl_Obj* action)
{
    int res;
    TN* n;
    NLQ q;
    NLQ qb;

    nlq_init (&q);
    nlq_init (&qb);

    nlq_append (&q,  tdn);
    nlq_push   (&qb, tdn);

    while (1) {
	n = nlq_pop (&q);
	if (!n) break;

	if (n->nchildren) {
	    int i;
	    for (i = 0; i < n->nchildren; i++) {
		nlq_append (&q,	 n->child [i]);
		nlq_push   (&qb, n->child [i]);
	    }
	}
    }

    /* Backward visit to leave */

    while (1) {
	n = nlq_pop (&qb);
	if (!n) break;

	res = (*f) (interp, n, cs, avn, nvn, action);

	if ((res == TCL_ERROR) ||
	    (res == TCL_BREAK) ||
	    (res == TCL_RETURN)) {
	    nlq_clear (&qb);
	    return res;
	} else if (res == 5) {
	    /* Illegal pruning */

	    nlq_clear (&qb);
	    Tcl_ResetResult (interp);
	    Tcl_AppendResult (interp,
			      "Illegal attempt to prune post-order walking", NULL);
	    return TCL_ERROR;
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

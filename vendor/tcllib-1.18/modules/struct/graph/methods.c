/* struct::tree - critcl - layer 3 definitions.
 *
 * -> Method functions.
 *    Implementations for all tree methods.
 */

#include <string.h>
#include <arc.h>
#include <graph.h>
#include <methods.h>
#include <nacommon.h>
#include <node.h>
#include <util.h>
#include <walk.h>

/* ..................................................
 * Handling of all indices, numeric and 'end-x' forms.  Copied straight out of
 * the Tcl core as this is not exported through the public API.
 */

static int TclGetIntForIndex (Tcl_Interp* interp, Tcl_Obj* objPtr,
			      int endValue, int* indexPtr);

/* .................................................. */

#define FAIL(x) if (!(x)) { return TCL_ERROR; }

/* .................................................. */
/*
 *---------------------------------------------------------------------------
 *
 * gm_GASSIGN --
 *
 *	Copies the argument graph over into this graph object. Uses direct
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
gm_GASSIGN (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph =   source
     *	       [0]   [1] [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "source");
	return TCL_ERROR;
    }

    return g_ms_assign (interp, g, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_GSET --
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
gm_GSET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph --> dest(ination)
     *	       [0]  [1]  [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "dest");
	return TCL_ERROR;
    }

    return g_ms_set (interp, objv[0], g, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_APPEND --
 *
 *	Appends a value to an attribute of the graph.
 *	May create the attribute.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_APPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph append key value
     *	       [0]  [1]	    [2]	[3]
     */

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "key value");
	return TCL_ERROR;
    }

    g_attr_extend (&g->attr);
    g_attr_append  (g->attr, interp, objv[2], objv[3]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_ARCS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_ARCS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arcs                       | all arcs
     *         graph arcs -in        NODE...    | arcs end in node in list
     *         graph arcs -out       NODE...    | arcs start in node in list
     *         graph arcs -adj       NODE...    | arcs start|end in node in list
     *         graph arcs -inner     NODE...    | arcs start&end in node in list
     *         graph arcs -embedding NODE...    | arcs start^end in node in list
     *         graph arcs -key       KEY        | arcs have attribute KEY
     *         graph arcs -value     VALUE      | arcs have KEY and VALUE
     *         graph arcs -filter    CMDPREFIX  | arcs for which CMD returns True.
     *	       [0]   [1]  [2]        [3]
     *
     * -value requires -key.
     * -in/-out/-adj/-inner/-embedding are exclusive.
     * Each option can be used at most once.
     */

    return gc_filter (0, interp, objc, objv, &g->arcs,
		      (GN_GET_GC*) ga_get_arc, g);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_APPEND --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_APPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc append ARC KEY VALUE
     *	       [0]   [1] [2]    [3] [4] [5]
     */

    GA* a;

    if (objc != 6) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key value");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_extend (&a->base.attr);
    g_attr_append  (a->base.attr, interp, objv[4], objv[5]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_GETUNWEIGH --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_GETUNWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc getunweighted
     *	       [0]   [1] [2]
     */

    GA* a;
    Tcl_Obj** rv;
    int       rc;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 3, objv, NULL);
	return TCL_ERROR;
    }

    rv = NALLOC (g->arcs.n, Tcl_Obj*);
    rc = 0;

    for (a = (GA*) g->arcs.first; a ; a = (GA*) a->base.next) {
	if (a->weight) continue;

	ASSERT_BOUNDS (rc, g->arcs.n);

	rv [rc++] = a->base.name;
    }

    Tcl_SetObjResult (interp, Tcl_NewListObj (rc, rv));

    ckfree ((char*) rv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_GETWEIGHT --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_GETWEIGHT (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc getweight ARC
     *	       [0]   [1] [2]       [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    if (!a->weight) {
	Tcl_AppendResult (interp,
			  "arc \"", Tcl_GetString (a->base.name), "\" has no weight",
			  NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, a->weight);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_SETUNWEIGH --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_SETUNWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc setunweighted ?weight?
     *	       [0]   [1] [2]           [3]
     */

    GA* a;
    Tcl_Obj* weight;

    if ((objc != 3) && (objc != 4)) {
	Tcl_WrongNumArgs (interp, 3, objv, "?weight?");
	return TCL_ERROR;
    }

    if (objc == 4) {
	weight = objv [3];
    } else {
	weight = Tcl_NewIntObj (0);
    }

    for (a = (GA*) g->arcs.first; a ; a = (GA*) a->base.next) {
	if (a->weight) continue;

	a->weight = weight;
	Tcl_IncrRefCount (weight);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_SETWEIGHT --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_SETWEIGHT (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc setweight ARC WEIGHT
     *	       [0]   [1] [2]       [3] [4]
     */

    GA* a;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc weight");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    if (a->weight) {
	Tcl_DecrRefCount (a->weight);
    }

    a->weight = objv [4];
    Tcl_IncrRefCount (a->weight);

    Tcl_SetObjResult (interp, a->weight);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_UNSETWEIGH --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_UNSETWEIGH (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc unsetweight ARC
     *	       [0]   [1] [2]         [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    if (a->weight) {
	Tcl_DecrRefCount (a->weight);
	a->weight = NULL;
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_HASWEIGHT --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_HASWEIGHT (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc hasweight ARC
     *	       [0]   [1] [2]       [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (a->weight != NULL));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_WEIGHTS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_WEIGHTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc weights
     *	       [0]   [1] [2]
     */

    GA* a;
    Tcl_Obj** rv;
    int       rc, rcmax;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 3, objv, NULL);
	return TCL_ERROR;
    }

    rcmax = 2 * g->arcs.n;
    rv = NALLOC (rcmax, Tcl_Obj*);
    rc = 0;

    for (a = (GA*) g->arcs.first; a ; a = (GA*) a->base.next) {
	if (!a->weight) continue;

	ASSERT_BOUNDS (rc,   rcmax);
	ASSERT_BOUNDS (rc+1, rcmax);

	rv [rc++] = a->base.name;
	rv [rc++] = a->weight;
    }

    Tcl_SetObjResult (interp, Tcl_NewListObj (rc, rv));

    ckfree ((char*) rv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_ATTR --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_ATTR (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc attr KEY
     *         graph arc attr KEY -arcs   LIST
     *         graph arc attr KEY -glob   PATTERN
     *         graph arc attr KEY -regexp PATTERN
     *	       [0]   [1] [2]  [3] [4]     [5]
     */

    static const char* types [] = {
	"-arcs", "-glob","-regexp", NULL
    };
    int modes [] = {
	A_LIST, A_GLOB, A_REGEXP
    };

    int      mode;
    Tcl_Obj* detail;

    if ((objc != 4) && (objc != 6)) {
	Tcl_WrongNumArgs (interp, 3, objv,
			  "key ?-arcs list|-glob pattern|-regexp pattern?");
	return TCL_ERROR;
    }

    if (objc != 6) {
	detail = NULL;
	mode   = A_NONE;
    } else {
	detail = objv [5];
	if (Tcl_GetIndexFromObj (interp, objv [4], types, "type",
				 0, &mode) != TCL_OK) {
	    return TCL_ERROR;
	}
	mode = modes [mode];
    }

    return gc_attr (&g->arcs, mode, detail, interp, objv[3],
		    (GN_GET_GC*) ga_get_arc, g);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_DELETE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_DELETE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc  delete ARC ARC...
     *	       [0]   [1]  [2]    [3] [4+]
     */

    GA* a;
    int i;

    if (objc < 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc arc...");
	return TCL_ERROR;
    }

    for (i=3; i<objc; i++) {
	a = ga_get_arc (g, objv[i], interp, objv[0]);
	FAIL (a);
    }

    for (i=3; i<objc; i++) {
	a = ga_get_arc (g, objv[i], interp, objv[0]);
	ga_delete (a);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_EXISTS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_EXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc exists NAME
     *	       [0]   [1] [2]    [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], NULL, NULL);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (a != NULL));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_FLIP --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_FLIP (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc flip ARC
     *	       [0]   [1] [2]  [3]
     */

    GA*	a;
    GN* src;
    GN* dst;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    src = a->start->n;
    dst = a->end->n;

    if (src != dst) {
	ga_mv_src (a, dst);
	ga_mv_dst (a, src);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_GET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_GET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc get ARC KEY
     *	       [0]   [1] [2] [3] [4]
     */

    GA* a;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    return g_attr_get (a->base.attr, interp, objv[4],
		       objv [3], "\" for arc \"");
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_GETALL --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_GETALL (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc getall ARC ?PATTERN?
     *	       [0]   [1] [2]    [3] [4]
     */

    GA* a;

    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc ?pattern?");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_getall (a->base.attr, interp, objc-4, objv+4);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_INSERT --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_INSERT (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc insert SOURCE TARGET ?ARC?
     *	       [0]   [1] [2]    [3]    [4]    [5]
     */

    GN* src;
    GN* dst;
    GA* a;
    const char* name;

    if ((objc != 5) && (objc != 6)) {
	Tcl_WrongNumArgs (interp, 3, objv, "source target ?arc?");
	return TCL_ERROR;
    }

    Tcl_AppendResult (interp, "source ", NULL);
    src = gn_get_node (g, objv [3], interp, objv[0]);
    FAIL (src);
    Tcl_ResetResult (interp);

    Tcl_AppendResult (interp, "target ", NULL);
    dst = gn_get_node (g, objv [4], interp, objv[0]);
    FAIL (dst);
    Tcl_ResetResult (interp);

    if (objc == 6) {
	/* Explicit arc name, must not exist */

	if (ga_get_arc (g, objv [5], NULL, NULL)) {
	    ga_err_duplicate (interp, objv[5], objv[0]);
	    return TCL_ERROR;
	}

	/* No matching arc found */
	/* Create arc with specified name, */
	/* then insert it */
		
	name = Tcl_GetString (objv [5]);

    } else {
	/* Create a single new node with a generated name, */
	/* then insert it. */

	name = g_newarcname (g);
    }

    a = ga_new (g, name, src, dst);
    Tcl_SetObjResult (interp, Tcl_NewListObj (1, &a->base.name));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_KEYEXISTS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_KEYEXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc keyexists ARC KEY
     *	       [0]   [1] [2]       [3] [4]
     */

    GA*	a;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_kexists (a->base.attr, interp, objv[4]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_KEYS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_KEYS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc keys ARC ?PATTERN?
     *	       [0]  [1]	 [2]  [3] [4]
     */

    GA* a;

    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc ?pattern?");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_keys (a->base.attr, interp, objc-4, objv+4);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_LAPPEND --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_LAPPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc lappend ARC KEY VALUE
     *	       [0]   [1] [2]     [3] [4] [5]
     */

    GA* a;

    if (objc != 6) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key value");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_extend (&a->base.attr);
    g_attr_lappend (a->base.attr, interp, objv[4], objv[5]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_MOVE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_MOVE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc move ARC NEWSRC NEWDST
     *	       [0]   [1] [2]  [3] [4]    [5]
     */

    GA*	a;
    GN* nsrc;
    GN* ndst;

    if (objc != 6) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc newsource newtarget");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    nsrc = gn_get_node (g, objv [4], interp, objv [0]);
    FAIL (nsrc);

    ndst = gn_get_node (g, objv [5], interp, objv [0]);
    FAIL (ndst);

    ga_mv_src (a, nsrc);
    ga_mv_dst (a, ndst);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_MOVE_SRC --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_MOVE_SRC (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc move ARC NEWSRC
     *	       [0]   [1] [2]  [3] [4]
     */

    GA*	a;
    GN* nsrc;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc newsource");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    nsrc = gn_get_node (g, objv [4], interp, objv [0]);
    FAIL (nsrc);

    ga_mv_src (a, nsrc);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_MOVE_TARG --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_MOVE_TARG (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc move ARC NEWDST
     *	       [0]   [1] [2]  [3] [4]
     */

    GA*	a;
    GN* ndst;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc newtarget");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    ndst = gn_get_node (g, objv [4], interp, objv [0]);
    FAIL (ndst);

    ga_mv_dst (a, ndst);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_RENAME --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_RENAME (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc rename ARC NEW
     *	       [0]   [1] [2]    [3] [4]
     */

    GC* c;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc newname");
	return TCL_ERROR;
    }

    c = (GC*) ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (c);

    if (ga_get_arc (g, objv [4], NULL, NULL)) {
	ga_err_duplicate (interp, objv[4], objv[0]);
	return TCL_ERROR;
    }

    gc_rename (c, &g->arcs, objv[4], interp);
    ga_shimmer_self ((GA*) c);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_SET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_SET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc set ARC KEY ?VALUE?
     *	       [0]   [1] [2] [3] [4] [5]
     */

    GA* a;

    if ((objc != 5) && (objc != 6)) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key ?value?");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    if (objc == 5) {
	return g_attr_get (a->base.attr, interp, objv[4],
			   objv [3], "\" for arc \"");
    } else {
	g_attr_extend (&a->base.attr);
	g_attr_set     (a->base.attr, interp, objv[4], objv[5]);
	return TCL_OK;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_SOURCE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_SOURCE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc source ARC
     *	       [0]   [1] [2]    [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    Tcl_SetObjResult (interp, a->start->n->base.name);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_TARGET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_TARGET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc target ARC
     *	       [0]   [1] [2]    [3]
     */

    GA* a;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    Tcl_SetObjResult (interp, a->end->n->base.name);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_NODES --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_NODES (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc target ARC
     *	       [0]   [1] [2]    [3]
     */

    GA* a;
    Tcl_Obj* nv[2];

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    nv[0] = a->start->n->base.name;
    nv[1] = a->end->n->base.name;

    Tcl_SetObjResult (interp, Tcl_NewListObj (2, nv));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_arc_UNSET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_arc_UNSET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc unset ARC KEY
     *	       [0]   [1] [2]   [3] [4]
     */

    GA* a;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "arc key");
	return TCL_ERROR;
    }

    a = ga_get_arc (g, objv [3], interp, objv [0]);
    FAIL (a);

    g_attr_unset (a->base.attr, objv [4]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_DESERIALIZE --
 *
 *	Parses a Tcl value containing a serialized graph and copies it over
 *	the existing graph.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_DESERIALIZE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph deserialize serial
     *	       [0]   [1]	 [2]
     *
     * SV   = { NODE ATTR/node ARCS ... ATTR/graph }
     *
     * using:
     *		ATTR/x = { key value ... }
     *		ARCS   = { { NAME targetNODEref ATTR/arc } ... }
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "serial");
	return TCL_ERROR;
    }

    return g_deserialize (g, interp, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_DESTROY --
 *
 *	Destroys the whole graph object.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Releases memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_DESTROY (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph destroy
     *	       [0]   [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_DeleteCommandFromToken(interp, g->cmd);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_GET --
 *
 *	Returns the value of the named attribute in the graph.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_GET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph get key
     *	       [0]   [1] [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "key");
	return TCL_ERROR;
    }

    return g_attr_get (g->attr, interp, objv[2],
		       objv [0], "\" for graph \"");
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_GETALL --
 *
 *	Returns a dictionary containing all attributes and their values of
 *	the graph.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_GETALL (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph getall ?pattern?
     *	       [0]   [1]    [2]
     */

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?pattern?");
	return TCL_ERROR;
    }

    g_attr_getall (g->attr, interp, objc-2, objv+2);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_KEYEXISTS --
 *
 *	Returns a boolean value signaling whether the graph has the
 *	named attribute or not. True implies that the attribute exists.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_KEYEXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph keyexists key
     *	       [0]  [1]	       [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "key");
	return TCL_ERROR;
    }

    g_attr_kexists (g->attr, interp, objv[2]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_KEYS --
 *
 *	Returns a list containing all attribute names matching the pattern
 *	for the attributes of the graph.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_KEYS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph keys ?pattern?
     *	       [0]  [1]	  [2]
     */

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?pattern?");
	return TCL_ERROR;
    }

    g_attr_keys (g->attr, interp, objc-2, objv+2);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_LAPPEND --
 *
 *	Appends a value as list element to an attribute of the graph.
 *	May create the attribute.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_LAPPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph lappend key value
     *	       [0]  [1]	     [2] [3]
     */

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "key value");
	return TCL_ERROR;
    }

    g_attr_extend (&g->attr);
    g_attr_lappend (g->attr, interp, objv[2], objv[3]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_NODES --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_NODES (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* nwa = nodes with arc, st = starting, en = ending
     *
     * Syntax: graph nodes                       | all nodes
     *         graph nodes -in        NODE...    | nwa en    in node in list
     *         graph nodes -out       NODE...    | nwa st    in node in list
     *         graph nodes -adj       NODE...    | nwa st|en in node in list
     *         graph nodes -inner     NODE...    | nwa st&en in node in list
     *         graph nodes -embedding NODE...    | nwa st^en in node in list
     *         graph nodes -key       KEY        | nodes have attribute KEY
     *         graph nodes -value     VALUE      | nodes have KEY and VALUE
     *         graph nodes -filter    CMDPREFIX  | nodes for which CMD returns True.
     *	       [0]   [1]   [2]        [3]
     *
     * -in/-out/-adj/-inner/-embedding are exclusive.
     * -value requires -key.
     * Each option can be used at most once.
     */

    return gc_filter (1, interp, objc, objv, &g->nodes,
		      (GN_GET_GC*) gn_get_node, g);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_APPEND --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_APPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node append NODE KEY VALUE
     *	       [0]   [1]  [2]    [3]  [4] [5]
     */

    GN* n;

    if (objc != 6) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key value");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    g_attr_extend (&n->base.attr);
    g_attr_append  (n->base.attr, interp, objv[4], objv[5]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_ATTR --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_ATTR (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node attr KEY
     *         graph node attr KEY -nodes   LIST
     *         graph node attr KEY -glob   PATTERN
     *         graph node attr KEY -regexp PATTERN
     *	       [0]   [1]  [2]  [3] [4]     [5]
     */

    static const char* types [] = {
	"-glob", "-nodes", "-regexp", NULL
    };
    int modes [] = {
	A_GLOB, A_LIST, A_REGEXP
    };

    int      mode;
    Tcl_Obj* detail;

    if ((objc != 4) && (objc != 6)) {
	Tcl_WrongNumArgs (interp, 3, objv,
			  "key ?-nodes list|-glob pattern|-regexp pattern?");
	return TCL_ERROR;
    }

    if (objc != 6) {
	detail = NULL;
	mode   = A_NONE;
    } else {
	detail = objv [5];
	if (Tcl_GetIndexFromObj (interp, objv [4], types, "type",
				 0, &mode) != TCL_OK) {
	    return TCL_ERROR;
	}
	mode = modes [mode];
    }

    return gc_attr (&g->nodes, mode, detail, interp, objv[3],
		    (GN_GET_GC*) gn_get_node, g);
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_DEGREE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_DEGREE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node degree -in|-out NODE
     *	       [0]   [1]  [2]    [3]      [4]
     *
     *         graph node degree NODE
     *	       [0]   [1]  [2]    [3]
     */

    GN*      n;
    int      dmode;
    int      degree;
    Tcl_Obj* node;

    static const char* dmode_s [] = {
	"-in", "-out", NULL
    };
    enum dmode_e {
	D_IN, D_OUT, D_ALL
    };

    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 3, objv, "?-in|-out? node");
	return TCL_ERROR;
    }

    if (objc == 5) {
	if (Tcl_GetIndexFromObj (interp, objv [3], dmode_s,
				 "option", 0, &dmode) != TCL_OK) {
	    return TCL_ERROR;
	}

	node  = objv [4];
    } else {
	dmode = D_ALL;
	node  = objv [3];
    }

    n = gn_get_node (g, node, interp, objv [0]);
    FAIL (n);

    switch (dmode) {
    case D_IN:  degree = n->in.n;            break;
    case D_OUT: degree = n->out.n;           break;
    case D_ALL: degree = n->in.n + n->out.n; break;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (degree));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_DELETE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_DELETE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node delete NODE NODE...
     *	       [0]   [1]  [2]    [3]  [4+]
     */

    int i;
    GN* n;

    if (objc < 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "node node...");
	return TCL_ERROR;
    }

    for (i=3; i< objc; i++) {
	n = gn_get_node (g, objv [i], interp, objv [0]);
	FAIL (n);
    }

    for (i=3; i< objc; i++) {
	n = gn_get_node (g, objv [i], interp, objv [0]);
	gn_delete (n);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_EXISTS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_EXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node exists NAME
     *	       [0]   [1]  [2]    [3]
     */

    GN* n;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 3, objv, "node");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], NULL, NULL);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (n != NULL));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_GET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_GET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node get ARC KEY
     *	       [0]   [1]  [2] [3] [4]
     */

    GN* n;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    return g_attr_get (n->base.attr, interp, objv[4],
		       objv [3], "\" for node \"");
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_GETALL --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_GETALL (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph arc getall ARC ?PATTERN?
     *	       [0]   [1] [2]    [3] [4]
     */

    GN* n;

    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 3, objv, "node ?pattern?");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    g_attr_getall (n->base.attr, interp, objc-4, objv+4);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_INSERT --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_INSERT (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node insert ?NODE...?
     *	       [0]   [1]  [2]    [3]
     */

    GN* n;

    if (objc < 3) {
	Tcl_WrongNumArgs (interp, 3, objv, "?node...?");
	return TCL_ERROR;
    }

    if (objc >= 4) {
	int       lc, i;
	Tcl_Obj** lv;

	/* Explicit node names, must not exist */

	for (i=3; i<objc; i++) {
	    if (gn_get_node (g, objv [i], NULL, NULL)) {
		gn_err_duplicate (interp, objv[i], objv[0]);
		return TCL_ERROR;
	    }
	}

	/* No matching nodes found. Create nodes with specified name, then
	 * insert them
	 */

	lc = objc-3;
	lv = NALLOC (lc, Tcl_Obj*);

	for (i=3; i<objc; i++) {
	    n = gn_new (g, Tcl_GetString (objv [i]));
	    lv [i-3] = n->base.name;
	}

	Tcl_SetObjResult (interp, Tcl_NewListObj (lc, lv));
	ckfree ((char*) lv);

    } else {
	/* Create a single new node with a generated name, then insert it. */

	n = gn_new (g, g_newnodename (g));
	Tcl_SetObjResult (interp, Tcl_NewListObj (1, &n->base.name));
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_KEYEXISTS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_KEYEXISTS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node keyexists ARC KEY
     *	       [0]   [1]  [2]       [3] [4]
     */

    GN* n;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    g_attr_kexists (n->base.attr, interp, objv[4]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_KEYS --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_KEYS (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node keys NODE ?PATTERN?
     *	       [0]  [1]	  [2]  [3]  [4]
     */

    GN* n;

    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 3, objv, "node ?pattern?");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    g_attr_keys (n->base.attr, interp, objc-4, objv+4);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_LAPPEND --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_LAPPEND (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node lappend NODE KEY VALUE
     *	       [0]   [1]  [2]     [3]  [4] [5]
     */

    GN* n;

    if (objc != 6) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key value");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    g_attr_extend (&n->base.attr);
    g_attr_lappend (n->base.attr, interp, objv[4], objv[5]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_OPPOSITE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_OPPOSITE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node opposite NODE ARC
     *	       [0]   [1]  [2]      [3]  [4]
     */

    GN* n;
    GA* a;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "node arc");
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (n);

    a = ga_get_arc (g, objv [4], interp, objv [0]);
    FAIL (a);

    if (a->start->n == n) {
	Tcl_SetObjResult (interp, a->end->n->base.name);
    } else if (a->end->n == n) {
	Tcl_SetObjResult (interp, a->start->n->base.name);
    } else {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "node \"", -1);
	Tcl_AppendObjToObj (err, n->base.name);
	Tcl_AppendToObj	   (err, "\" and arc \"", -1);
	Tcl_AppendObjToObj (err, a->base.name);
	Tcl_AppendToObj	   (err, "\" are not connected in graph \"", -1);
	Tcl_AppendObjToObj (err, objv [0]);
	Tcl_AppendToObj	   (err, "\"", -1);

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_RENAME --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_RENAME (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node rename NODE NEW
     *	       [0]   [1]  [2]    [3]  [4]
     */

    GC* c;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "node newname");
	return TCL_ERROR;
    }

    c = (GC*) gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (c);

    if (gn_get_node (g, objv [4], NULL, NULL)) {
	gn_err_duplicate (interp, objv[4], objv[0]);
	return TCL_ERROR;
    }

    gc_rename (c, &g->nodes, objv[4], interp);
    gn_shimmer_self ((GN*) c);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_SET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_SET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node set NODE KEY ?VALUE?
     *	       [0]   [1]  [2] [3]  [4] [5]
     */

    GC* c;

    if ((objc != 5) && (objc != 6)) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key ?value?");
	return TCL_ERROR;
    }

    c = (GC*) gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (c);

    if (objc == 5) {
	return g_attr_get (c->attr, interp, objv[4],
			   objv [3], "\" for node \"");
    } else {
	g_attr_extend (&c->attr);
	g_attr_set     (c->attr, interp, objv[4], objv[5]);
	return TCL_OK;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_node_UNSET --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_node_UNSET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph node unset NODE KEY
     *	       [0]   [1]  [2]   [3]  [4]
     */

    GC* c;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 3, objv, "node key");
	return TCL_ERROR;
    }

    c = (GC*) gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (c);

    g_attr_unset (c->attr, objv [4]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_SERIALIZE --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_SERIALIZE (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph serialize NODE...
     *	       [0]   [1]       [2]
     *
     * SV   = { NODE ATTR/node ARCS ... ATTR/graph }
     *
     * using:
     *		ATTR/x = { key value ... }
     *		ARCS   = { { NAME targetNODEref ATTR/arc } ... }
     */

    Tcl_Obj* sv = g_ms_serialize (interp, objv[0], g, objc-2, objv+2);

    if (!sv) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult (interp, sv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_SET --
 *
 *	Adds an attribute and its value to the graph. May replace an
 *	existing value.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_SET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph set key ?value?
     *	       [0]  [1]  [2] [3]
     */

    if ((objc != 3) && (objc != 4)) {
	Tcl_WrongNumArgs (interp, 2, objv, "key ?value?");
	return TCL_ERROR;
    }

    if (objc == 3) {
	return g_attr_get (g->attr, interp, objv[2],
			   objv [0], "\" for graph \"");
    } else {
	g_attr_extend (&g->attr);
	g_attr_set     (g->attr, interp, objv[2], objv[3]);
	return TCL_OK;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_SWAP --
 *
 *	Swap the names of two nodes.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *      None.
 *
 *---------------------------------------------------------------------------
 */

int
gm_SWAP (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph swap a   b
     *	       [0]  [1]	  [2] [3]
     */

    GN*		  na;
    GN*		  nb;
    const char*   key;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "node1 node2");
	return TCL_ERROR;
    }

    na = gn_get_node (g, objv [2], interp, objv [0]);
    FAIL (na);

    nb = gn_get_node (g, objv [3], interp, objv [0]);
    FAIL (nb);

    if (na == nb) {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "cannot swap node \"", -1);
	Tcl_AppendObjToObj (err, objv [2]);
	Tcl_AppendToObj	   (err, "\" with itself", -1);

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    {
#define SWAP(a,b,t) t = a; a = b ; b = t
#define SWAPS(x,t) SWAP(na->x,nb->x,t)

	/* The two nodes flip all structural information around to trade places */
	/* It might actually be easier to flip the non-structural data */
	/* name, he, attr, data in the node map */

	Tcl_Obj*       to;
	Tcl_HashTable* ta;
	Tcl_HashEntry* th;

	SWAPS (base.name, to);
	SWAPS (base.attr, ta);
	SWAPS (base.he,   th);

	Tcl_SetHashValue (na->base.he, (ClientData) na);
	Tcl_SetHashValue (nb->base.he, (ClientData) nb);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_UNSET --
 *
 *	Removes an attribute and its value from the graph.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_UNSET (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph unset key
     *	       [0]  [1]	   [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "key");
	return TCL_ERROR;
    }

    g_attr_unset (g->attr, objv [2]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * gm_WALK --
 *
 *      
 *	
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
gm_WALK (G* g, Tcl_Interp* interp, int objc, Tcl_Obj* const* objv)
{
    /* Syntax: graph walk NODE ?-type TYPE? ?-order ORDER? ?-dir DIR? -command CMD
     *	       [0]   [1]  [2]  [3]    [4]   [5]     [6]    [7]   [8]  [9]      [10]
     *
     * TYPE  bfs|dfs
     * ORDER pre|post|both
     * DIR   backward|forward
     *
     * bfs => !post && !both
     */

    int       cc, type, order, dir;
    Tcl_Obj** cv;
    GN*       n;

    if (objc < 5) {
	Tcl_WrongNumArgs (interp, 2, objv, W_USAGE);
	return TCL_ERROR;
    }

    n = gn_get_node (g, objv [2], interp, objv [0]);
    FAIL(n);

    if (g_walkoptions (interp, objc, objv,
		       &type, &order, &dir,
		       &cc, &cv) != TCL_OK) {
	return TCL_ERROR;
    }

    return g_walk (interp, objv[0], n, type, order, dir, cc, cv);
}


/* .................................................. */
/* .................................................. */

/*
 * Handling of all indices, numeric and 'end-x' forms.  Copied straight out of
 * the Tcl core as this is not exported through the public API.
 *
 * I.e. a full copy of TclGetIntForIndex, its Tcl_ObjType, and of several
 * supporting functions and macros internal to the core.  :(
 *
 * To avoid clashing with the object type in the core the object type here has
 * been given a different name.
 */

#define UCHAR(c) ((unsigned char) (c))

static void UpdateStringOfEndOffset _ANSI_ARGS_((Tcl_Obj* objPtr));
static int SetEndOffsetFromAny _ANSI_ARGS_((Tcl_Interp* interp,
					    Tcl_Obj* objPtr));

static int TclCheckBadOctal (Tcl_Interp *interp, const char *value);
static int TclFormatInt     (char *buffer, long n);


Tcl_ObjType EndOffsetTypeGraph = {
    "tcllib/struct::graph/end-offset",	/* name */
    (Tcl_FreeInternalRepProc*) NULL,	/* freeIntRepProc */
    (Tcl_DupInternalRepProc*) NULL,	/* dupIntRepProc */
    UpdateStringOfEndOffset,		/* updateStringProc */
    SetEndOffsetFromAny
};

static int
TclGetIntForIndex (Tcl_Interp* interp, Tcl_Obj* objPtr, int endValue, int* indexPtr)
{
    if (Tcl_GetIntFromObj (NULL, objPtr, indexPtr) == TCL_OK) {
	return TCL_OK;
    }

    if (SetEndOffsetFromAny(NULL, objPtr) == TCL_OK) {
	/*
	 * If the object is already an offset from the end of the
	 * list, or can be converted to one, use it.
	 */

	*indexPtr = endValue + objPtr->internalRep.longValue;

    } else {
	/*
	 * Report a parse error.
	 */

	if (interp != NULL) {
	    char *bytes = Tcl_GetString(objPtr);
	    /*
	     * The result might not be empty; this resets it which
	     * should be both a cheap operation, and of little problem
	     * because this is an error-generation path anyway.
	     */
	    Tcl_ResetResult(interp);
	    Tcl_AppendStringsToObj(Tcl_GetObjResult(interp),
				   "bad index \"", bytes,
				   "\": must be integer or end?-integer?",
				   (char *) NULL);
	    if (!strncmp(bytes, "end-", 3)) {
		bytes += 3;
	    }
	    TclCheckBadOctal(interp, bytes);
	}

	return TCL_ERROR;
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * UpdateStringOfEndOffset --
 *
 *	Update the string rep of a Tcl object holding an "end-offset"
 *	expression.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Stores a valid string in the object's string rep.
 *
 * This procedure does NOT free any earlier string rep.	 If it is
 * called on an object that already has a valid string rep, it will
 * leak memory.
 *
 *----------------------------------------------------------------------
 */

static void
UpdateStringOfEndOffset(objPtr)
     register Tcl_Obj* objPtr;
{
    char buffer[TCL_INTEGER_SPACE + sizeof("end") + 1];
    register int len;

    strcpy(buffer, "end");
    len = sizeof("end") - 1;
    if (objPtr->internalRep.longValue != 0) {
	buffer[len++] = '-';
	len += TclFormatInt(buffer+len, -(objPtr->internalRep.longValue));
    }
    objPtr->bytes = ckalloc((unsigned) (len+1));
    strcpy(objPtr->bytes, buffer);
    objPtr->length = len;
}

/*
 *----------------------------------------------------------------------
 *
 * SetEndOffsetFromAny --
 *
 *	Look for a string of the form "end-offset" and convert it
 *	to an internal representation holding the offset.
 *
 * Results:
 *	Returns TCL_OK if ok, TCL_ERROR if the string was badly formed.
 *
 * Side effects:
 *	If interp is not NULL, stores an error message in the
 *	interpreter result.
 *
 *----------------------------------------------------------------------
 */

static int
SetEndOffsetFromAny(interp, objPtr)
     Tcl_Interp* interp;	/* Tcl interpreter or NULL */
     Tcl_Obj* objPtr;		/* Pointer to the object to parse */
{
    int offset;			/* Offset in the "end-offset" expression */
    Tcl_ObjType* oldTypePtr = objPtr->typePtr;
    /* Old internal rep type of the object */
    register char* bytes;	/* String rep of the object */
    int length;			/* Length of the object's string rep */

    /* If it's already the right type, we're fine. */

    if (objPtr->typePtr == &EndOffsetTypeGraph) {
	return TCL_OK;
    }

    /* Check for a string rep of the right form. */

    bytes = Tcl_GetStringFromObj(objPtr, &length);
    if ((*bytes != 'e') || (strncmp(bytes, "end",
				    (size_t)((length > 3) ? 3 : length)) != 0)) {
	if (interp != NULL) {
	    Tcl_ResetResult(interp);
	    Tcl_AppendStringsToObj(Tcl_GetObjResult(interp),
				   "bad index \"", bytes,
				   "\": must be end?-integer?",
				   (char*) NULL);
	}
	return TCL_ERROR;
    }

    /* Convert the string rep */

    if (length <= 3) {
	offset = 0;
    } else if ((length > 4) && (bytes[3] == '-')) {
	/*
	 * This is our limited string expression evaluator.  Pass everything
	 * after "end-" to Tcl_GetInt, then reverse for offset.
	 */
	if (Tcl_GetInt(interp, bytes+4, &offset) != TCL_OK) {
	    return TCL_ERROR;
	}
	offset = -offset;
    } else {
	/*
	 * Conversion failed.  Report the error.
	 */
	if (interp != NULL) {
	    Tcl_ResetResult(interp);
	    Tcl_AppendStringsToObj(Tcl_GetObjResult(interp),
				   "bad index \"", bytes,
				   "\": must be integer or end?-integer?",
				   (char *) NULL);
	}
	return TCL_ERROR;
    }

    /*
     * The conversion succeeded. Free the old internal rep and set
     * the new one.
     */

    if ((oldTypePtr != NULL) && (oldTypePtr->freeIntRepProc != NULL)) {
	oldTypePtr->freeIntRepProc(objPtr);
    }

    objPtr->internalRep.longValue = offset;
    objPtr->typePtr = &EndOffsetTypeGraph;

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCheckBadOctal --
 *
 *	This procedure checks for a bad octal value and appends a
 *	meaningful error to the interp's result.
 *
 * Results:
 *	1 if the argument was a bad octal, else 0.
 *
 * Side effects:
 *	The interpreter's result is modified.
 *
 *----------------------------------------------------------------------
 */

static int
TclCheckBadOctal(interp, value)
     Tcl_Interp *interp;		/* Interpreter to use for error reporting.
				 * If NULL, then no error message is left
				 * after errors. */
     const char *value;		/* String to check. */
{
    register const char *p = value;

    /*
     * A frequent mistake is invalid octal values due to an unwanted
     * leading zero. Try to generate a meaningful error message.
     */

    while (isspace(UCHAR(*p))) {	/* INTL: ISO space. */
	p++;
    }
    if (*p == '+' || *p == '-') {
	p++;
    }
    if (*p == '0') {
	while (isdigit(UCHAR(*p))) {	/* INTL: digit. */
	    p++;
	}
	while (isspace(UCHAR(*p))) {	/* INTL: ISO space. */
	    p++;
	}
	if (*p == '\0') {
	    /* Reached end of string */
	    if (interp != NULL) {
		/*
		 * Don't reset the result here because we want this result
		 * to be added to an existing error message as extra info.
		 */
		Tcl_AppendResult(interp, " (looks like invalid octal number)",
				 (char *) NULL);
	    }
	    return 1;
	}
    }
    return 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFormatInt --
 *
 *	This procedure formats an integer into a sequence of decimal digit
 *	characters in a buffer. If the integer is negative, a minus sign is
 *	inserted at the start of the buffer. A null character is inserted at
 *	the end of the formatted characters. It is the caller's
 *	responsibility to ensure that enough storage is available. This
 *	procedure has the effect of sprintf(buffer, "%d", n) but is faster.
 *
 * Results:
 *	An integer representing the number of characters formatted, not
 *	including the terminating \0.
 *
 * Side effects:
 *	The formatted characters are written into the storage pointer to
 *	by the "buffer" argument.
 *
 *----------------------------------------------------------------------
 */

static int
TclFormatInt(buffer, n)
     char *buffer;		/* Points to the storage into which the
				 * formatted characters are written. */
     long n;			/* The integer to format. */
{
    long intVal;
    int i;
    int numFormatted, j;
    char *digits = "0123456789";

    /*
     * Check first whether "n" is zero.
     */

    if (n == 0) {
	buffer[0] = '0';
	buffer[1] = 0;
	return 1;
    }

    /*
     * Check whether "n" is the maximum negative value. This is
     * -2^(m-1) for an m-bit word, and has no positive equivalent;
     * negating it produces the same value.
     */

    if (n == -n) {
	sprintf(buffer, "%ld", n);
	return strlen(buffer);
    }

    /*
     * Generate the characters of the result backwards in the buffer.
     */

    intVal = (n < 0? -n : n);
    i = 0;
    buffer[0] = '\0';
    do {
	i++;
	buffer[i] = digits[intVal % 10];
	intVal = intVal/10;
    } while (intVal > 0);
    if (n < 0) {
	i++;
	buffer[i] = '-';
    }
    numFormatted = i;

    /*
     * Now reverse the characters.
     */

    for (j = 0;	 j < i;	 j++, i--) {
	char tmp = buffer[i];
	buffer[i] = buffer[j];
	buffer[j] = tmp;
    }
    return numFormatted;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

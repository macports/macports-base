/* struct::set - critcl - layer 3 definitions.
 *
 * -> Set functions.
 *    Implementations for all set commands.
 */

#include "s.h"
#include "m.h"

/* .................................................. */

/*
 *---------------------------------------------------------------------------
 *
 * sm_ADD --
 *
 *	Copies the argument tree over into this tree object. Uses direct
 *	access to internal data structures for matching tree objects, and
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
sm_ADD (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set add SETVAR SET
     *	       [0] [1] [2]    [3]
     */

    SPtr        vs, s;
    Tcl_Obj*    val;
    int         new = 0;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "Avar B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[3], &s) != TCL_OK) {
	return TCL_ERROR;
    }

    val = Tcl_ObjGetVar2(interp, objv[2], NULL, 0);
    if (val == NULL) {
	/* Create missing variable */

	vs  = s_dup (NULL);
	val = s_new (vs);
	(void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);

    } else if (s_get (interp, val, &vs) != TCL_OK) {
	return TCL_ERROR;
    }

    if (s->el.numEntries) {
	int            new, nx = 0;
	Tcl_HashSearch hs;
	Tcl_HashEntry* he;
	CONST char*    key;

	for(he = Tcl_FirstHashEntry(&s->el, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs)) {
	    key = Tcl_GetHashKey (&s->el, he);
	    if (Tcl_FindHashEntry (&vs->el, key) != NULL) continue;
	    /* Key not known to vs, to be added */

	    /* _Now_ unshare the object, if required */

	    if (Tcl_IsShared (val)) {
		val = Tcl_DuplicateObj (val);
		(void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);
		s_get (interp, val, &vs);
	    }

	    (void*) Tcl_CreateHashEntry(&vs->el, key, &new);
	    nx = 1;
	}
	if (nx) {
	    Tcl_InvalidateStringRep(val);
	}
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_CONTAINS --
 *
 *	Copies this tree over into the argument tree. Uses direct access to
 *	internal data structures for matching tree objects, and goes through a
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
sm_CONTAINS (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set contains SET ITEM
     *	       [0] [1]      [2] [3]
     */

    SPtr        s;
    CONST char* item;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "set item");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &s) != TCL_OK) {
	return TCL_ERROR;
    }

    item = Tcl_GetString (objv [3]);

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (s_contains (s, item)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_DIFFERENCE --
 *
 *	Returns a list containing the ancestors of the named node.
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
sm_DIFFERENCE (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set difference SETa SETb
     *	       [0] [1]        [2]  [3]
     */

    SPtr sa, sb;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "A B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      s_new (s_difference (sa, sb)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_EMPTY --
 *
 *	Appends a value to an attribute of the named node.
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
sm_EMPTY (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set empty SET
     *	       [0] [1]   [2]
     */

    SPtr s;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "set");
	return TCL_ERROR;
    }

    if (objv[2]->typePtr == s_ltype ()) {
	int       lc;
	Tcl_Obj** lv;
	Tcl_ListObjGetElements(interp, objv[2], &lc, &lv);
	Tcl_SetObjResult (interp, Tcl_NewIntObj (lc == 0));
	return TCL_OK;
    }

    if (s_get (interp, objv[2], &s) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (s_empty (s)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_EQUAL --
 *
 *	Returns a dictionary mapping from nodes to attribute values, for a
 *	named attribute.
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
sm_EQUAL (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set equal SETa SETb
     *	       [0] [1]   [2]  [3]
     */

    SPtr sa, sb;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "A B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (s_equal (sa, sb)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_EXCLUDE --
 *
 *	Returns a list of all direct or indirect descendants of the named
 *	node, possibly run through a Tcl command prefix for filtering.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory. Per the filter command prefix, if
 *	one has been specified.
 *
 *---------------------------------------------------------------------------
 */

int
sm_EXCLUDE (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set exclude SETVAR ITEM
     *	       [0] [1]     [2]    [3]
     */

    SPtr        vs;
    Tcl_Obj*    val;
    char*       key;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "Avar element");
	return TCL_ERROR;
    }

    val = Tcl_ObjGetVar2(interp, objv[2], NULL, TCL_LEAVE_ERR_MSG);
    if (val == NULL) {
	return TCL_ERROR;
    }
    if (s_get (interp, val, &vs) != TCL_OK) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv[3]);
    if (s_contains (vs, key)) {
	if (Tcl_IsShared (val)) {
	    val = Tcl_DuplicateObj (val);
	    (void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);
	    s_get (interp, val, &vs);
	}

	s_subtract1 (vs, key);
	Tcl_InvalidateStringRep(val);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_INCLUDE --
 *
 *	Deletes the named nodes, but not its children. They are put into the
 *	place where the deleted node was. Complementary to sm_SPLICE.
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
sm_INCLUDE (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set include SETVAR ITEM
     *	       [0] [1]     [2]    [3]
     */

    SPtr        vs;
    Tcl_Obj*    val;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "Avar element");
	return TCL_ERROR;
    }

    val = Tcl_ObjGetVar2(interp, objv[2], NULL, 0);
    if (val == NULL) {
	/* Create missing variable */

	vs = s_dup (NULL);
	s_add1 (vs, Tcl_GetString (objv[3]));
	val = s_new (vs);

	(void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);
    } else {
	/* Extend variable */
	char* key;

	if (s_get (interp, val, &vs) != TCL_OK) {
	    return TCL_ERROR;
	}

	key = Tcl_GetString (objv[3]);
	if (!s_contains (vs, key)) {
	    if (Tcl_IsShared (val)) {
		val = Tcl_DuplicateObj (val);
		(void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);
		s_get (interp, val, &vs);
	    }

	    s_add1 (vs, key);
	    Tcl_InvalidateStringRep(val);
	}
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_INTERSECT --
 *
 *	Deletes the named node and its children.
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
sm_INTERSECT (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set intersect ?SET...?
     *	       [0] [1]       [2]
     */

    SPtr sa, sb, next, acc;
    int  i;

    if (objc == 2) {
	/* intersect nothing = nothing */
	Tcl_SetObjResult (interp, s_new (s_dup (NULL)));
	return TCL_OK;
    }

    for (i = 2; i < objc; i++) {
	if (s_get (interp, objv[i], &sa) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    s_get (interp, objv[2], &sa);

    if (objc == 3) {
	/* intersect with itself = unchanged */
	Tcl_SetObjResult (interp, s_new (s_dup (sa)));
	return TCL_OK;
    }

    acc = sa;
    for (i = 3; i < objc; i++) {
	s_get (interp, objv[i], &sb);
	next = s_intersect (acc, sb);
	if (acc != sa) s_free (acc);
	acc = next;
	if (s_empty (acc)) break;
    }

    if (acc == sa) {
	acc = s_dup (acc);
    }

    Tcl_SetObjResult (interp, s_new (acc));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_INTERSECT3 --
 *
 *	Returns a non-negative integer number describing the distance between
 *	the named node and the root of the tree. A depth of 0 implies that
 *	the node is the root node.
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
sm_INTERSECT3 (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set intersect3 SETa SETb
     *	       [0] [1]        [2]  [3]
     */

    SPtr sa, sb;
    Tcl_Obj* lv [3];

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "A B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    lv [0] = s_new (s_intersect  (sa, sb));
    lv [1] = s_new (s_difference (sa, sb));
    lv [2] = s_new (s_difference (sb, sa));

    Tcl_SetObjResult (interp, Tcl_NewListObj (3, lv));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_SIZE --
 *
 *	Returns a list of all descendants of the named node, possibly run
 *	through a Tcl command prefix for filtering.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory. Per the filter command prefix, if
 *	one has been specified.
 *
 *---------------------------------------------------------------------------
 */

int
sm_SIZE (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set size SET
     *	       [0] [1]  [2]
     */

    SPtr s;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "set");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &s) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (s_size (s)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_SUBSETOF --
 *
 *	Parses a Tcl value containing a serialized tree and copies it over
 *	he existing tree.
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
sm_SUBSETOF (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set subsetof SETa SETb
     *	       [0] [1]      [2]  [3]
     */

    SPtr sa, sb;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "A B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (s_subsetof (sa, sb)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_SUBTRACT --
 *
 *	Destroys the whole tree object.
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
sm_SUBTRACT (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set subtract SETVAR SET
     *	       [0] [1]      [2]    [3]
     */

    SPtr        vs, s;
    Tcl_Obj*    val;
    int         del;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "Avar B");
	return TCL_ERROR;
    }

    val = Tcl_ObjGetVar2(interp, objv[2], NULL, TCL_LEAVE_ERR_MSG);
    if (val == NULL) {
	return TCL_ERROR;
    }
    if (s_get (interp, val, &vs) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &s) != TCL_OK) {
	return TCL_ERROR;
    }

    if (s->el.numEntries) {
	int            new, dx = 0;
	Tcl_HashSearch hs;
	Tcl_HashEntry* he;
	CONST char*    key;

	for(he = Tcl_FirstHashEntry(&s->el, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs)) {
	    key = Tcl_GetHashKey (&s->el, he);
	    if (Tcl_FindHashEntry (&vs->el, key) == NULL) continue;
	    /* Key known to vs, to be removed */

	    /* _Now_ unshare the object, if required */

	    if (Tcl_IsShared (val)) {
		val = Tcl_DuplicateObj (val);
		(void) Tcl_ObjSetVar2 (interp, objv[2], NULL, val, 0);
		s_get (interp, val, &vs);
	    }

	    Tcl_DeleteHashEntry (Tcl_FindHashEntry (&vs->el, key));
	    dx = 1;
	}
	if (dx) {
	    Tcl_InvalidateStringRep(val);
	}
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_SYMDIFF --
 *
 *	Returns a boolean value signaling whether the named node exists in
 *	the tree. True implies existence, and false non-existence.
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
sm_SYMDIFF (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set symdiff SETa SETb
     *	       [0] [1]	   [2]  [3]
     */

    SPtr sa, sb, xa, xb, u;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "A B");
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    if (s_get (interp, objv[2], &sa) != TCL_OK) {
	return TCL_ERROR;
    }
    if (s_get (interp, objv[3], &sb) != TCL_OK) {
	return TCL_ERROR;
    }

    xa = s_difference (sa, sb);
    xb = s_difference (sb, sa);
    u  = s_union      (xa, xb);

    s_free (xa);
    s_free (xb);

    Tcl_SetObjResult (interp, s_new (u));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * sm_UNION --
 *
 *	Returns the value of the named attribute at the given node.
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
sm_UNION (ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: set union ?SET...?
     *	       [0] [1]   [2]
     */

    SPtr sa, acc;
    int  i;

    if (objc == 2) {
	/* union nothing = nothing */
	Tcl_SetObjResult (interp, s_new (s_dup (NULL)));
	return TCL_OK;
    }

    for (i = 2; i < objc; i++) {
	if (s_get (interp, objv[i], &sa) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    acc = s_dup (NULL);

    for (i = 2; i < objc; i++) {
	s_get (interp, objv[i], &sa);
	s_add (acc, sa, NULL);
    }

    Tcl_SetObjResult (interp, s_new (acc));
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

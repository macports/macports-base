/* struct::tree - critcl - layer 3 definitions.
 *
 * -> Method functions.
 *    Implementations for all tree methods.
 */

#include <string.h>
#include "util.h"
#include "m.h"
#include "t.h"
#include "tn.h"
#include "ms.h"

/* ..................................................
 * Handling of all indices, numeric and 'end-x' forms.  Copied straight out of
 * the Tcl core as this is not exported through the public API.
 */

static int TclGetIntForIndex (Tcl_Interp* interp, Tcl_Obj* objPtr,
			      int endValue, int* indexPtr);

/* .................................................. */

/*
 *---------------------------------------------------------------------------
 *
 * tm_TASSIGN --
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
tm_TASSIGN (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree =	source
     *	       [0]  [1] [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "source");
	return TCL_ERROR;
    }

    return tms_assign (interp, t, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_TSET --
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
tm_TSET (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree --> dest(ination)
     *	       [0]  [1] [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "dest");
	return TCL_ERROR;
    }

    return tms_set (interp, t, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_ANCESTORS --
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
tm_ANCESTORS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree ancestors node
     *	       [0]  [1]	      [2]
     */

    TN*	     tn;
    Tcl_Obj* res;
    int	     depth;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    depth = tn_depth (tn);
    if (depth == 0) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    } else {
	int	  i;
	Tcl_Obj** anc = NALLOC (depth, Tcl_Obj*);

	for (i = 0;
	     tn->parent != NULL;
	     i++, tn = tn->parent) {

	    ASSERT_BOUNDS (i, depth);

	    anc [i] = tn->parent->name;
	    /* RefCount++ happens in NewList */
	    /*Tcl_IncrRefCount (anc [i]);*/
	}

	Tcl_SetObjResult (interp, Tcl_NewListObj (i, anc));
	ckfree ((char*) anc);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_APPEND --
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
tm_APPEND (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree append node key value
     *	       [0]  [1]	   [2]	[3] [4]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    CONST char*	   key;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key value");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    tn_extend_attr (tn);

    he	= Tcl_FindHashEntry (tn->attr, key);

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(tn->attr, key, &new);

	Tcl_IncrRefCount (objv [4]);
	Tcl_SetHashValue (he, (ClientData) objv [4]);
	Tcl_SetObjResult (interp, objv [4]);
    } else {
	Tcl_Obj* av = (Tcl_Obj*) Tcl_GetHashValue(he);

	if (Tcl_IsShared (av)) {
	    Tcl_DecrRefCount	  (av);
	    av = Tcl_DuplicateObj (av);
	    Tcl_IncrRefCount	  (av);

	    Tcl_SetHashValue (he, (ClientData) av);
	}

	Tcl_AppendObjToObj (av, objv [4]);
	Tcl_SetObjResult (interp, av);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_ATTR --
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
tm_ATTR (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree attr key ?-query  queryarg?
     *       :		      -nodes  nodelist
     *       :		      -glob   nodepattern
     *       :		      -regexp nodepattern
     *	       [0]  [1]	 [2]  [3]     [4]
     */

    CONST char* key;
    int		type;
    Tcl_Obj*	detail = NULL;
    int		listc = 0;
    Tcl_Obj**	listv = NULL;

    static CONST char* types [] = {
	"-glob", "-nodes","-regexp", NULL
    };
    enum types {
	T_GLOB, T_NODES, T_REGEXP, T_NONE
    };

    if ((objc != 3) && (objc != 5)) {
	Tcl_WrongNumArgs (interp, 2, objv,
			  "key ?-nodes list|-glob pattern|-regexp pattern?");
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [2]);

    if (objc != 5) {
	type = T_NONE;
    } else {
	detail = objv [4];
	if (Tcl_GetIndexFromObj (interp, objv [3], types, "type",
				 0, &type) != TCL_OK) {
	    Tcl_ResetResult (interp);
	    Tcl_WrongNumArgs (interp, 2, objv,
			      "key ?-nodes list|-glob pattern|-regexp pattern?");
	    return TCL_ERROR;
	}
    }

    /* Allocate result space, max needed: All nodes */

    ASSERT (t->node.numEntries == t->nnodes, "Inconsistent #nodes in tree");

    switch (type) {
    case T_GLOB:
	{
	    /* Iterate over all nodes
	     * Ignore nodes without attributes
	     * Ignore nodes not matching the pattern (glob)
	     * Ignore nodes not having the attribute
	     */

	    int		   i;
	    TN*		   iter;
	    CONST char*	   pattern = Tcl_GetString (detail);
	    Tcl_HashEntry* he;

	    listc = 2 * t->node.numEntries;
	    listv = NALLOC (listc, Tcl_Obj*);

	    for (i = 0, iter = t->nodes;
		 iter != NULL;
		 iter= iter->nextnode) {

		if (!iter->attr) continue;
		if (!iter->attr->numEntries) continue;
		if (!Tcl_StringMatch(Tcl_GetString (iter->name), pattern)) continue;

		he = Tcl_FindHashEntry (iter->attr, key);
		if (!he) continue;

		ASSERT_BOUNDS (i,   listc);
		ASSERT_BOUNDS (i+1, listc);

		listv [i++] = iter->name;
		listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }

	    listc = i;
	}
	break;

    case T_NODES:
	{
	    /* Iterate over the specified nodes
	     * Ignore nodes which are not known
	     * Ignore nodes without attributes
	     * Ignore nodes not having the attribute
	     * Many occurrences of the same node cause
	     * repeated results.
	     */

	    TN*		   iter;
	    int		   nodec;
	    Tcl_Obj**	   nodev;
	    int		   i, j;
	    Tcl_HashEntry* he;

	    if (Tcl_ListObjGetElements (interp, detail, &nodec, &nodev) != TCL_OK) {
		return TCL_ERROR;
	    }

	    if (nodec > t->nnodes) {
		listc = 2 * nodec;
	    } else {
		listc = 2 * t->nnodes;
	    }
	    listv = NALLOC (listc, Tcl_Obj*);

	    for (i = 0, j = 0; i < nodec; i++) {

		ASSERT_BOUNDS (i, nodec);
		iter = tn_get_node (t, nodev [i], NULL, NULL);

		if (iter == NULL) continue;
		if (!iter->attr) continue;
		if (!iter->attr->numEntries) continue;

		he = Tcl_FindHashEntry (iter->attr, key);
		if (!he) continue;

		ASSERT_BOUNDS (j,   listc);
		ASSERT_BOUNDS (j+1, listc);

		listv [j++] = iter->name;
		listv [j++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }

	    listc = j;
	}
	break;

    case T_REGEXP:
	{
	    /* Iterate over all nodes
	     * Ignore nodes without attributes
	     * Ignore nodes not matching the pattern (re)
	     * Ignore nodes not having the attribute
	     */

	    int		   i;
	    TN*		   iter;
	    CONST char*	   pattern = Tcl_GetString (detail);
	    Tcl_HashEntry* he;

	    listc = 2 * t->node.numEntries;
	    listv = NALLOC (listc, Tcl_Obj*);

	    for (i = 0, iter = t->nodes;
		 iter != NULL;
		 iter= iter->nextnode) {

		if (!iter->attr) continue;
		if (!iter->attr->numEntries) continue;
		if (Tcl_RegExpMatch(interp, Tcl_GetString (iter->name), pattern) < 1) continue;

		he = Tcl_FindHashEntry (iter->attr, key);
		if (!he) continue;

		ASSERT_BOUNDS (i,   listc);
		ASSERT_BOUNDS (i+1, listc);

		listv [i++] = iter->name;
		listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }

	    listc = i;
	}
	break;

    case T_NONE:
	{
	    /* Iterate over all nodes
	     * Ignore nodes without attributes
	     * Ignore nodes not having the attribute
	     */

	    int		   i;
	    TN*		   iter;
	    Tcl_HashEntry* he;

	    listc = 2 * t->node.numEntries;
	    listv = NALLOC (listc, Tcl_Obj*);

	    for (i = 0, iter = t->nodes;
		 iter != NULL;
		 iter= iter->nextnode) {

		if (!iter->attr) continue;
		if (!iter->attr->numEntries) continue;

		he = Tcl_FindHashEntry (iter->attr, key);
		if (!he) continue;

		ASSERT_BOUNDS (i,   listc);
		ASSERT_BOUNDS (i+1, listc);

		listv [i++] = iter->name;
		listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }

	    listc = i;
	}
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

/*
 *---------------------------------------------------------------------------
 *
 * tm_CHILDREN --
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
tm_CHILDREN (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree children ?-all? node ?filter cmdpfx?
     * 3       tree children  node
     * 4       tree children  -all  node
     * 5       tree children  node  filter cmdpfx
     * 6       tree children  -all  node   filter cmdpfx
     *	       [0]  [1]	     [2]    [3]	   [4]	  [5]
     */

#undef	USAGE
#define USAGE "?-all? node ?filter cmd?"

    TN*	      tn;
    int	      node = 2;
    int	      all  = 0;
    int	      cmdc = 0;
    Tcl_Obj** cmdv = NULL;
    int	      listc = 0;
    Tcl_Obj** listv;

    if ((objc < 3) || (objc > 6)) {
	Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	return TCL_ERROR;
    }

    ASSERT_BOUNDS (node, objc);
    if (0 == strcmp ("-all", Tcl_GetString (objv [node]))) {
	/* -all present */

	if ((objc != 4) && (objc != 6)) {
	    Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	    return TCL_ERROR;
	}

	node ++;
	all = 1;
    } else {
	/* -all missing */

	if ((objc != 3) && (objc != 5)) {
	    Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	    return TCL_ERROR;
	}
    }

    if (objc == (node+3)) {
	ASSERT_BOUNDS (node+1, objc);
	if (strcmp ("filter", Tcl_GetString (objv [node+1]))) {
	    Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	    return TCL_ERROR;
	}

	ASSERT_BOUNDS (node+2, objc);
	if (Tcl_ListObjGetElements (interp, objv [node+2], &cmdc, &cmdv) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (!cmdc) {
	    Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	    return TCL_ERROR;
	}
    }

    ASSERT_BOUNDS (node, objc);
    tn = tn_get_node (t, objv [node], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    return tms_getchildren (tn, all,
			    cmdc, cmdv,
			    objv [0], interp);
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_CUT --
 *
 *	Deletes the named nodes, but not its children. They are put into the
 *	place where the deleted node was. Complementary to tm_SPLICE.
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
tm_CUT (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree cut	  node
     *	       [0]  [1]	  [2]
     */

    TN*	     tn;
    TN*      p;
    Tcl_Obj* res;
    int      i, j;
    TN**     child;
    int	     nchildren;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (tn == t->root) {
	/* Node found, is root, cannot be cut */

	Tcl_AppendResult (interp, "cannot cut root node", NULL);
	return TCL_ERROR;
    }

    tn_cut (tn);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_DELETE --
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
tm_DELETE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree delete node
     *	       [0]  [1]	   [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (tn == t->root) {
	/* Node found, is root, cannot be deleted */

	Tcl_AppendResult (interp, "cannot delete root node", NULL);
	return TCL_ERROR;
    }

    tn_detach (tn);
    tn_delete (tn);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_DEPTH --
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
tm_DEPTH (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree depth node
     *	       [0]  [1]	  [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn_depth (tn)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_DESCENDANTS --
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
tm_DESCENDANTS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree descendants node ?filter cmdprefix?
     *	       [0]  [1]		[2]  [3]     [4]
     */

    TN*	      tn;
    int	      cmdc = 0;
    Tcl_Obj** cmdv = NULL;

    if ((objc < 2) || (objc > 5)) {
	Tcl_WrongNumArgs (interp, 2, objv, "node ?filter cmd?");
	return TCL_ERROR;
    }

    if (objc == 5) {
	if (strcmp ("filter", Tcl_GetString (objv [3]))) {
	    Tcl_WrongNumArgs (interp, 2, objv, "node ?filter cmd?");
	    return TCL_ERROR;
	}
	if (Tcl_ListObjGetElements (interp, objv [4], &cmdc, &cmdv) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (!cmdc) {
	    Tcl_WrongNumArgs (interp, 2, objv, "node ?filter cmd?");
	    return TCL_ERROR;
	}
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    return tms_getchildren (tn, 1 /* all */,
			    cmdc, cmdv,
			    objv [0], interp);
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_DESERIALIZE --
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
tm_DESERIALIZE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree deserialize serial
     *	       [0]  [1]		[2]
     */

    T* tser;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "serial");
	return TCL_ERROR;
    }

    return t_deserialize (t, interp, objv [2]);
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_DESTROY --
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
tm_DESTROY (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree destroy
     *	       [0]  [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_DeleteCommandFromToken(interp, t->cmd);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_EXISTS --
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
tm_EXISTS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree exists node
     *	       [0]  [1]	   [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], NULL, NULL);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn != NULL));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_GET --
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
tm_GET (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree get node key
     *	       [0]  [1] [2]  [3]
     */

    TN*		   tn;
    Tcl_HashEntry* he = NULL;
    CONST char*	   key;
    Tcl_Obj*	   av;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    if (tn->attr) {
	he = Tcl_FindHashEntry (tn->attr, key);
    }

    if ((tn->attr == NULL) || (he == NULL)) {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "invalid key \"", -1);
	Tcl_AppendObjToObj (err, objv [3]);
	Tcl_AppendToObj	   (err, "\" for node \"", -1);
	Tcl_AppendObjToObj (err, objv [2]);
	Tcl_AppendToObj	   (err, "\"", -1);

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    av = (Tcl_Obj*) Tcl_GetHashValue(he);
    Tcl_SetObjResult (interp, av);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_GETALL --
 *
 *	Returns a dictionary containing all attributes and their values of
 *	the specified node.
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
tm_GETALL (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree getall node ?pattern?
     *	       [0]  [1]	   [2]	[3]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    Tcl_HashSearch hs;
    CONST char*	   key;
    int		   i;
    int		   listc;
    Tcl_Obj**	   listv;
    CONST char*	   pattern = NULL;
    int		   matchall = 0;

    if ((objc != 3) && (objc != 4)) {
	Tcl_WrongNumArgs (interp, 2, objv, "node ?pattern?");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if ((tn->attr == NULL) || (tn->attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
	return TCL_OK;
    }

    if (objc == 4) {
	pattern = Tcl_GetString (objv [3]);
	matchall = (strcmp (pattern, "*") == 0);
    }

    listc = 2 * tn->attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    if ((objc == 3) || matchall) {
	/* Unpatterned retrieval, or pattern '*' */

	for (i = 0, he = Tcl_FirstHashEntry(tn->attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (tn->attr, he);

	    ASSERT_BOUNDS (i,	listc);
	    ASSERT_BOUNDS (i+1, listc);

	    listv [i++] = Tcl_NewStringObj (key, -1);
	    listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	ASSERT (i == listc, "Bad attribute retrieval");
    } else {
	/* Filtered retrieval, glob pattern */

	for (i = 0, he = Tcl_FirstHashEntry(tn->attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (tn->attr, he);

	    if (Tcl_StringMatch(key, pattern)) {
		ASSERT_BOUNDS (i,   listc);
		ASSERT_BOUNDS (i+1, listc);

		listv [i++] = Tcl_NewStringObj (key, -1);
		listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }
	}

	ASSERT (i <= listc, "Bad attribute glob retrieval");
	listc = i;
    }

    if (listc) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv));
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    }

    ckfree ((char*) listv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_HEIGHT --
 *
 *	Returns a non-negative integer number describing the distance between
 *	the given node and its farthest child. A value of 0 implies that the
 *	node is a leaf.
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
tm_HEIGHT (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree height node
     *	       [0]  [1]	  [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn_height (tn)));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_INDEX --
 *
 *	Returns a non-negative integer number describing the location of the
 *	specified node within its parent's list of children. An index of 0
 *	implies that the node is the left-most child of its parent.
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
tm_INDEX (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree index node
     *	       [0]  [1]	  [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (tn == tn->tree->root) {
	Tcl_AppendResult (interp, "cannot determine index of root node", NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn->index));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_INSERT --
 *
 *	Creates/inserts/moves a node to specific location in its (new) parent.
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
tm_INSERT (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree insert parent index ?name...?
     *	       [0]  [1]	  [2]	  [3]	[4+]
     */

    TN*	     tn;
    int	     idx;
    Tcl_Obj* res;

    if (objc < 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "parent index ?name...?");
	return TCL_ERROR;
    }

    Tcl_AppendResult (interp, "parent ", NULL);
    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }
    Tcl_ResetResult (interp);

    if (TclGetIntForIndex (interp, objv [3], tn->nchildren, &idx) != TCL_OK) {
	return TCL_ERROR;
    }

    if (objc > 4) {
	/* We have explicit node names. */
	/* Unknown nodes are created. */
	/* Existing nodes are moved. */
	/* Trying to move the root will fail. */

	int i;
	TN* n;

	for (i = 4; i < objc; i++) {
	    ASSERT_BOUNDS (i, objc);
	    n = tn_get_node (t, objv [i], NULL, NULL);

	    if (n == NULL) {
		/* No matching node found */
		/* Create node with specified name, */
		/* then insert it */

		CONST char* name;
		name = Tcl_GetString (objv [i]);

		tn_insert (tn, idx, tn_new (t, name));
		idx++;

	    } else if (n == t->root) {
		/* Node found, is root, immovable */

		Tcl_AppendResult (interp, "cannot move root node", NULL);
		return TCL_ERROR;

	    } else if ((n == tn) || tn_isancestorof (n, tn)) {
		/* Node found, not root, but move is irregular */

		/* The chosen parent is actually a descendant of the */
		/* node to move. The move would create a circle. This */
		/* is not allowed. */

		Tcl_Obj* err = Tcl_NewObj ();

		Tcl_AppendToObj	   (err, "node \"", -1);
		Tcl_AppendObjToObj (err, objv [i]);
		Tcl_AppendToObj	   (err, "\" cannot be its own descendant", -1);

		Tcl_SetObjResult (interp, err);
		return TCL_ERROR;

	    } else {
		/* Node found, move is ok */

		/* If the node is moving within its parent, and its */
		/* old location was before the new location, then   */
		/* decrement the new location, so that it gets put  */
		/* into the right spot. */

		if ((n->parent == tn) && (n->index < idx)) {
		    idx --;
		}

		tn_detach (n);
		tn_insert (tn, idx, n);
		idx++;
	    }
	}

	Tcl_SetObjResult (interp, Tcl_NewListObj (objc-4,objv+4));

    } else {
	/* Create a single new node with a generated name, */
	/* then insert it. */

	CONST char* name = t_newnodename (t);
	TN*	    nn	 = tn_new (t, name);

	tn_insert (tn, idx, nn);
	Tcl_SetObjResult (interp, Tcl_NewListObj (1, &nn->name));
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_ISLEAF --
 *
 *	Returns a boolean value signaling whether the given node is a leaf or
 *	not. True implies that the node is a leaf.
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
tm_ISLEAF (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree isleaf node
     *	       [0]  [1]	  [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn->nchildren == 0));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_KEYEXISTS --
 *
 *	Returns a boolean value signaling whether the given node has the
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
tm_KEYEXISTS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree keyexists node [key]
     *	       [0]  [1]	      [2]  [3]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    CONST char*	   key;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    if ((tn->attr == NULL) || (tn->attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (0));
	return TCL_OK;
    }

    he	= Tcl_FindHashEntry (tn->attr, key);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (he != NULL));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_KEYS --
 *
 *	Returns a list containing all attribute names matching the pattern
 *	for the attributes of the specified node.
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
tm_KEYS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree keys node ?pattern?
     *	       [0]  [1]	 [2]  [3]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    Tcl_HashSearch hs;
    CONST char*	   key;
    int		   i;
    int		   listc;
    Tcl_Obj**	   listv;
    CONST char*	   pattern;
    int		   matchall = 0;

    if ((objc != 3) && (objc != 4)) {
	Tcl_WrongNumArgs (interp, 2, objv, "node ?pattern?");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if ((tn->attr == NULL) || (tn->attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
	return TCL_OK;
    }

    listc = tn->attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    if (objc == 4) {
	pattern	 = Tcl_GetString(objv[3]);
	matchall = (strcmp (pattern, "*") == 0);
    }

    if ((objc == 3) || matchall) {
	/* Unpatterned retrieval, or pattern '*' */

	for (i = 0, he = Tcl_FirstHashEntry(tn->attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    ASSERT_BOUNDS (i, listc);
	    listv [i++] = Tcl_NewStringObj (Tcl_GetHashKey (tn->attr, he), -1);
	}

	ASSERT (i == listc, "Bad key retrieval");

    } else {
	/* Filtered retrieval, glob pattern */

	for (i = 0, he = Tcl_FirstHashEntry(tn->attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (tn->attr, he);
	    if (Tcl_StringMatch(key, pattern)) {
		ASSERT_BOUNDS (i, listc);

		listv [i++] = Tcl_NewStringObj (key, -1);
	    }
	}

	ASSERT (i <= listc, "Bad key glob retrieval");
	listc = i;
    }

    if (listc) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv));
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    }

    ckfree ((char*) listv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_LAPPEND --
 *
 *	Appends a value as list element to an attribute of the named node.
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
tm_LAPPEND (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree lappend node key value
     *	       [0]  [1]	    [2]	 [3] [4]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    CONST char*	   key;
    Tcl_Obj*	   av;

    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key value");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    tn_extend_attr (tn);

    he	= Tcl_FindHashEntry (tn->attr, key);

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(tn->attr, key, &new);

	av = Tcl_NewListObj (0,NULL);
	Tcl_IncrRefCount (av);
	Tcl_SetHashValue (he, (ClientData) av);

    } else {
	av = (Tcl_Obj*) Tcl_GetHashValue(he);

	if (Tcl_IsShared (av)) {
	    Tcl_DecrRefCount	  (av);
	    av = Tcl_DuplicateObj (av);
	    Tcl_IncrRefCount	  (av);

	    Tcl_SetHashValue (he, (ClientData) av);
	}
    }

    Tcl_ListObjAppendElement (interp, av, objv [4]);

    Tcl_SetObjResult (interp, av);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_LEAVES --
 *
 *	Returns a list containing all leaf nodes of the tree.
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
tm_LEAVES (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree leaves
     *	       [0]  [1]
     */

    TN* tn;
    int listc;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    listc = t->nleaves;

    if (listc) {
	int	  i;
	Tcl_Obj** listv = NALLOC (listc, Tcl_Obj*);
	TN*	  iter;

	for (i = 0, iter = t->leaves;
	     iter != NULL;
	     iter = iter->nextleaf, i++) {

	    ASSERT_BOUNDS (i, listc);
	    listv [i] = iter->name;
	}

	ASSERT (i == listc, "Bad list of leaves");

	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv));
	ckfree ((char*) listv);
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_MOVE --
 *
 *	Moves the specified node to a (new) parent.
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
tm_MOVE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree move parent index node ?node...?
     *	       [0]  [1]	 [2]	[3]   [4]   [5+]
     */

    TN*	    tn;
    int	    idx;
    TN*	    n;
    int	    listc;
    TN**    listv;
    int	    i;

    if (objc < 5) {
	Tcl_WrongNumArgs (interp, 2, objv, "parentNode index node ?node...?");
	return TCL_ERROR;
    }

    Tcl_AppendResult (interp, "parent ", NULL);
    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }
    Tcl_ResetResult (interp);

    if (TclGetIntForIndex (interp, objv [3], tn->nchildren, &idx) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Validate all nodes to move before trying to rearrange
     * tree in any way. */

    listc = objc-4;
    listv = NALLOC (listc, TN*);

    for (i=4; i < objc; i++) {
	ASSERT_BOUNDS (i,   objc);
	ASSERT_BOUNDS (i-4, listc);

	n = tn_get_node (t, objv [i], interp, objv [0]);
	listv [i-4] = n;

	if (n == NULL) {
	    /* Node not found, immovable */
	    ckfree ((char*) listv);
	    return TCL_ERROR;

	} else if (n == t->root) {
	    /* Node found, is root, immovable */

	    Tcl_AppendResult (interp, "cannot move root node", NULL);
	    ckfree ((char*) listv);
	    return TCL_ERROR;

	} else if ((n == tn) || tn_isancestorof (n, tn)) {
	    /* Node found, not root, but move is irregular */

	    /* The chosen parent is actually a descendant of the */
	    /* node to move. The move would create a circle. This */
	    /* is not allowed. */

	    Tcl_Obj* err = Tcl_NewObj ();

	    Tcl_AppendToObj    (err, "node \"", -1);
	    Tcl_AppendObjToObj (err, objv [i]);
	    Tcl_AppendToObj    (err, "\" cannot be its own descendant", -1);

	    Tcl_SetObjResult (interp, err);
	    ckfree ((char*) listv);
	    return TCL_ERROR;
	}
    }

    for (i=0; i < listc; i++) {
	ASSERT_BOUNDS (i, listc);
	tn_detach (listv [i]);
    }

    tn_insertmany (tn, idx, listc, listv);

    ckfree ((char*) listv);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_NEXT --
 *
 *	Returns the name of node which is the right sibling of the given node.
 *	The empty string is delivered if the node has no right sibling.
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
tm_NEXT (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree next node
     *	       [0]  [1]	 [2]
     */

    TN*	     tn;
    Tcl_Obj* res;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if ((tn->parent == NULL) ||
	(tn->right  == NULL)) {
	Tcl_SetObjResult (interp, Tcl_NewObj ());
    } else {
	Tcl_SetObjResult (interp, tn->right->name);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_NODES --
 *
 *	Returns a list containing all nodes of the tree.
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
tm_NODES (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree nodes
     *	       [0]  [1]
     */

    TN* tn;
    int listc;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    listc = t->nnodes;
    if (listc) {
	int	  i;
	Tcl_Obj** listv = NALLOC (listc, Tcl_Obj*);
	TN*	  iter;

	for (i = 0, iter = t->nodes;
	     iter != NULL;
	     iter = iter->nextnode, i++) {

	    ASSERT_BOUNDS (i, listc);
	    listv [i] = iter->name;
	}

	ASSERT (i == listc, "Bad list of nodes");

	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv));
	ckfree ((char*) listv);
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL));
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_NUMCHILDREN --
 *
 *	Returns a non-negative integer number, the number of direct children
 *	of the specified node. Zero children implies that the node is a leaf.
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
tm_NUMCHILDREN (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree numchildren node
     *	       [0]  [1]	  [2]
     */

    TN* tn;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (tn->nchildren));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_PARENT --
 *
 *	Returns the name of the parent node for the specified node. Delivers
 *	an empty string if the node is the root of the tree.
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
tm_PARENT (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree parent node
     *	       [0]  [1]	   [2]
     */

    TN* tn;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (tn->parent == NULL) {
	Tcl_SetObjResult (interp, Tcl_NewObj ());
    } else {
	Tcl_SetObjResult (interp, tn->parent->name);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_PREVIOUS --
 *
 *	Returns the name of node which is the left sibling of the given node.
 *	The empty string is delivered if the node has no left sibling.
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
tm_PREVIOUS (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree previous node
     *	       [0]  [1]	     [2]
     */

    TN* tn;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "node");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if ((tn->parent == NULL) ||
	(tn->left   == NULL)) {
	Tcl_SetObjResult (interp, Tcl_NewObj ());
    } else {
	Tcl_SetObjResult (interp, tn->left->name);
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_RENAME --
 *
 *	Gives the specified node a new name.
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
tm_RENAME (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree rename node newname
     *	       [0]  [1]	   [2]	[3]
     */

    TN*	     tn;
    TN*	     new;
    Tcl_Obj* res;
    int	     nnew;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "node newname");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    new = tn_get_node (t, objv [3], NULL, NULL);
    if (new != NULL) {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "unable to rename node to \"", -1);
	Tcl_AppendObjToObj (err, objv [3]);
	Tcl_AppendToObj	   (err, "\", node of that name already present in the tree \"", -1);
	Tcl_AppendObjToObj (err, objv [0]);
	Tcl_AppendToObj	   (err, "\"", -1);

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    /* Release current name, ... */
    Tcl_DecrRefCount (tn->name);

    /* ... and create a new one, by taking the argument
   * and shimmering it */

    tn->name = objv [3];
    Tcl_IncrRefCount (tn->name);
    tn_shimmer (tn->name, tn);

    /* Update the global name mapping as well */

    Tcl_DeleteHashEntry (tn->he);
    tn->he = Tcl_CreateHashEntry(&t->node, Tcl_GetString (tn->name), &nnew);
    Tcl_SetHashValue (tn->he, (ClientData) tn);

    Tcl_SetObjResult (interp, objv [3]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_ROOTNAME --
 *
 *	Returns the name of the root node.
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
tm_ROOTNAME (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree rootname
     *	       [0]  [1]
     */

    TN* tn;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, t->root->name);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_SERIALIZE --
 *
 *	Returns a Tcl value serializing the tree from the optional named node
 *	on downward.
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
tm_SERIALIZE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree serialize ?node?
     *	       [0]  [1]	       [2]
     */

    TN* tn;

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?node?");
	return TCL_ERROR;
    }

    if (objc == 2) {
	tn = t->root;
    } else {
	tn = tn_get_node (t, objv [2], interp, objv [0]);
	if (tn == NULL) {
	    return TCL_ERROR;
	}
    }

    Tcl_SetObjResult (interp, tms_serialize (tn));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_SET --
 *
 *	Adds an attribute and its value to a named node. May replace an
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
tm_SET (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree set node key ?value?
     *	       [0]  [1] [2]  [3]  [4]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    CONST char*	   key;

    if (objc == 4) {
	return tm_GET (t, interp, objc, objv);
    }
    if (objc != 5) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key ?value?");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    tn_extend_attr (tn);

    he = Tcl_FindHashEntry (tn->attr, key);

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(tn->attr, key, &new);
    } else {
	Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
    }

    Tcl_IncrRefCount (objv [4]);
    Tcl_SetHashValue (he, (ClientData) objv [4]);

    Tcl_SetObjResult (interp, objv [4]);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_SIZE --
 *
 *	Returns the number of descendants of a named optional node. Defaults
 *	to #descendants of root.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

int
tm_SIZE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree size ?node?
     *	       [0]  [1]	  [2]
     */

    int n;

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?node?");
	return TCL_ERROR;
    }

    if (objc == 2) {
	/* Descendants of root. Cheap. Is size of */
	/* tree minus root. No need to compute full */
	/* structural information. */

	n = t->nnodes - 1;
    } else {
	TN* tn;

	tn = tn_get_node (t, objv [2], interp, objv [0]);
	if (tn == NULL) {
	    return TCL_ERROR;
	}

	n = tn_ndescendants (tn);
    }

    Tcl_SetObjResult (interp, Tcl_NewIntObj (n));
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_SPLICE --
 *
 *	Replaces a series of nodes in a parent with o new node, and makes the
 *	replaced nodes the children of the new one. Complementary to tm_CUT.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Changes internal pointering of nodes.
 *
 *---------------------------------------------------------------------------
 */

int
tm_SPLICE (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree splice parent from ?to ?node??
     *	       [0]  [1]	  [2]	  [3]  [4] [5]
     */

    TN*	        p;
    TN*	        new;
    int	        from, to, i;
    int	        nc;
    TN**        nv;
    CONST char* name;

    if ((objc < 4) || (objc > 6)) {
	Tcl_WrongNumArgs (interp, 2, objv, "parent from ?to ?node??");
	return TCL_ERROR;
    }

    p = tn_get_node (t, objv [2], interp, objv [0]);
    if (p == NULL) {
	return TCL_ERROR;
    }

    if (TclGetIntForIndex (interp, objv [3], p->nchildren - 1, &from) != TCL_OK) {
	return TCL_ERROR;
    }

    if (objc > 4) {
	if (TclGetIntForIndex (interp, objv [4], p->nchildren - 1, &to) != TCL_OK) {
	    return TCL_ERROR;
	}
    } else {
	to = p->nchildren - 1;
    }

    if (from < 0) {from = 0;}
    if (to >= p->nchildren) {to = p->nchildren - 1;}

    if (objc > 5) {
	new = tn_get_node (t, objv [5], NULL, NULL);
	if (new != NULL) {
	    /* Already present, fail */
	    Tcl_Obj* err = Tcl_NewObj ();

	    Tcl_AppendToObj    (err, "node \"", -1);
	    Tcl_AppendObjToObj (err, objv [5]);
	    Tcl_AppendToObj    (err, "\" already exists in tree \"", -1);
	    Tcl_AppendObjToObj (err, objv [0]);
	    Tcl_AppendToObj    (err, "\"", -1);

	    Tcl_SetObjResult (interp, err);
	    return TCL_ERROR;
	}

	name = Tcl_GetString (objv [5]);
    } else {
	name = t_newnodename (t);
    }

    new = tn_new (t, name);

  /* Move the chosen children to the new node. */
  /* Then insert the new node in their place. */

    nc = to-from+1;

    if (nc > 0) {
	nv = tn_detachmany (p->child [from], nc);
	tn_appendmany (new, nc, nv);
	ckfree ((char*) nv);
    }

    tn_insert (p, from, new);

    Tcl_SetObjResult (interp, new->name);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_SWAP --
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
tm_SWAP (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree swap a   b
     *	       [0]  [1]	 [2] [3]
     */

    TN*		  tna;
    TN*		  tnb;
    CONST char*   key;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "nodea nodeb");
	return TCL_ERROR;
    }

    tna = tn_get_node (t, objv [2], interp, objv [0]);
    if (tna == NULL) {
	return TCL_ERROR;
    }
    if (tna == t->root) {
	Tcl_AppendResult (interp, "cannot swap root node", NULL);
	return TCL_ERROR;
    }

    tnb = tn_get_node (t, objv [3], interp, objv [0]);
    if (tnb == NULL) {
	return TCL_ERROR;
    }
    if (tnb == t->root) {
	Tcl_AppendResult (interp, "cannot swap root node", NULL);
	return TCL_ERROR;
    }

    if (tna == tnb) {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "cannot swap node \"", -1);
	Tcl_AppendObjToObj (err, objv [2]);
	Tcl_AppendToObj	   (err, "\" with itself", -1);

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    {
#define SWAP(a,b,t) t = a; a = b ; b = t
#define SWAPS(x,t) SWAP(tna->x,tnb->x,t)

	/* The two nodes flip all structural information around to trade places */
	/* It might actually be easier to flip the non-structural data */
	/* name, he, attr, data in the node map */

	Tcl_Obj*       to;
	Tcl_HashTable* ta;
	Tcl_HashEntry* th;

	SWAPS (name, to);
	SWAPS (attr, ta);
	SWAPS (he,   th);

	Tcl_SetHashValue (tna->he, (ClientData) tna);
	Tcl_SetHashValue (tnb->he, (ClientData) tnb);
    }

    tna->tree->structure = 0;
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_UNSET --
 *
 *	Removes an attribute and its value from a named node.
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
tm_UNSET (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: tree unset node key
     *	       [0]  [1]	  [2]  [3]
     */

    TN*		   tn;
    Tcl_HashEntry* he;
    CONST char*	   key;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "node key");
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    key = Tcl_GetString (objv [3]);

    if (tn->attr) {
	he  = Tcl_FindHashEntry (tn->attr, key);

	if (he != NULL) {
	    Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
	    Tcl_DeleteHashEntry (he);
	}
    }
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_WALK --
 *
 *	Walks over the tree as per the options and invokes a Tcl script per
 *	node.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Per the Tcl procedure invoked by the method.
 *
 *---------------------------------------------------------------------------
 */

int
tm_WALK (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    int type, order, rem, res;
    Tcl_Obj*  avarname;
    Tcl_Obj*  nvarname;
    int	      lvc;
    Tcl_Obj** lvv;
    TN*	      tn;

#undef	USAGE
#define USAGE "node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? loopvar script"

    /* Syntax: tree walk node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? loopvar script
     *	       [0]  [1]	 [2]   [3]   [4]	[5]	[6]		    [7]	 [8]	 [9]
     *
     * Syntax: tree walk node loopvar script
     *	       [0]  [1]	 [2]  [3]     [4]
     */

    if ((objc < 5) || (objc > 10)) {
	Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (t_walkoptions (interp, 2, objc, objv,
		       &type, &order, &rem, USAGE) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Remainder is 'loopvars script' */

    if (Tcl_ListObjGetElements (interp, objv [rem], &lvc, &lvv) != TCL_OK) {
	return TCL_ERROR;
    }
    if (lvc > 2) {
	Tcl_AppendResult (interp,
			  "too many loop variables, at most two allowed",
			  NULL);
	return TCL_ERROR;
    } else if (lvc == 2) {
	avarname = lvv [0];
	nvarname = lvv [1];

	Tcl_IncrRefCount (avarname);
	Tcl_IncrRefCount (nvarname);
    } else {
	avarname = NULL;
	nvarname = lvv [0];

	Tcl_IncrRefCount (nvarname);
    }

    if (!strlen (Tcl_GetString (objv [rem+1]))) {
	Tcl_AppendResult (interp,
			  "no script specified, or empty",
			  NULL);
	return TCL_ERROR;
    }

    res = t_walk (interp, tn, type, order,
		   t_walk_invokescript,
		   objv [rem+1], avarname, nvarname);

    if (avarname) {
	Tcl_IncrRefCount (avarname);
    }
    if (nvarname) {
	Tcl_IncrRefCount (nvarname);
    }
    return res;
}

/*
 *---------------------------------------------------------------------------
 *
 * tm_WALKPROC --
 *
 *	Walks over the tree as per the options and invokes a named Tcl command
 *	prefix per node.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Per the Tcl procedure invoked by the method.
 *
 *---------------------------------------------------------------------------
 */

int
tm_WALKPROC (T* t, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    int       type, order, rem, i, res;
    TN*	      tn;
    int	      cc;
    Tcl_Obj** cv;
    int	      ec;
    Tcl_Obj** ev;

    /* Syntax: tree walk node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? cmdprefix
     *	       [0]  [1]	 [2]   [3]   [4]	[5]	[6]		    [7]	 [8]
     *
     * Syntax: tree walk node cmdprefix
     *	       [0]  [1]	 [2]  [3]
     */

#undef	USAGE
#define USAGE "node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? cmdprefix"

    if ((objc < 4) || (objc > 9)) {
	Tcl_WrongNumArgs (interp, 2, objv, USAGE);
	return TCL_ERROR;
    }

    tn = tn_get_node (t, objv [2], interp, objv [0]);
    if (tn == NULL) {
	return TCL_ERROR;
    }

    if (t_walkoptions (interp, 1, objc, objv,
		       &type, &order, &rem, USAGE) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Remainder is 'cmd' */

    if (!strlen (Tcl_GetString (objv [rem]))) {
	Tcl_AppendResult (interp,
			  "no script specified, or empty",
			  NULL);
	return TCL_ERROR;
    }
    if (Tcl_ListObjGetElements (interp, objv [rem], &cc, &cv) != TCL_OK) {
	return TCL_ERROR;
    }

    ec = cc + 3;
    ev = NALLOC (ec, Tcl_Obj*);

    for (i = 0; i < cc; i++) {
	ev [i] = cv [i];
	Tcl_IncrRefCount (ev [i]);
    }

    res = t_walk (interp, tn, type, order,
		  t_walk_invokecmd,
		  (Tcl_Obj*) cc, (Tcl_Obj*) ev, objv [0]);

    ckfree ((char*) ev);
    return res;
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

Tcl_ObjType EndOffsetType = {
    "tcllib/struct::tree/end-offset",	/* name */
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

    if (objPtr->typePtr == &EndOffsetType) {
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
    objPtr->typePtr = &EndOffsetType;

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

int
TclCheckBadOctal(interp, value)
     Tcl_Interp *interp;		/* Interpreter to use for error reporting.
				 * If NULL, then no error message is left
				 * after errors. */
     CONST char *value;		/* String to check. */
{
    register CONST char *p = value;

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

int
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

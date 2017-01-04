/* struct::tree - critcl - layer 1 declarations
 * (b) Node operations.
 */

#include <tn.h>
#include <util.h>

/* .................................................. */

static void extend_children  (TNPtr n);
static int  fill_descendants (TNPtr n, int lc, Tcl_Obj** lv, int at);

/* .................................................. */

TNPtr
tn_new (TPtr t, CONST char* name)
{
    TNPtr n = ALLOC (TN);
    int	  new;

    n->name = Tcl_NewStringObj(name, -1);
    Tcl_IncrRefCount (n->name);
    tn_shimmer (n->name, n);

    if (Tcl_FindHashEntry (&t->node, name) != NULL) {
	Tcl_Panic ("struct::tree(c) tn_new - tried to use duplicate name for new node");
    }

    n->he = Tcl_CreateHashEntry(&t->node, name, &new);
    Tcl_SetHashValue (n->he, (ClientData) n);

    n->tree     = t;
    n->nextleaf = NULL;
    n->prevleaf = NULL;
    n->nextnode = NULL;
    n->prevnode = NULL;

    tn_node (n);
    tn_leaf (n);

    n->parent	   = NULL;
    n->child	   = NULL;
    n->maxchildren = 0;
    n->nchildren   = 0;
    n->left	   = NULL;
    n->right	   = NULL;
    n->attr	   = NULL;

    n->index	   = -1;
    n->depth	   = -1;
    n->height	   = -1;
    n->desc	   = -1;

    return n;
}

void
tn_delete (TNPtr n)
{
    T* t = n->tree;

    /* We assume that the node either has no parent or siblings anymore,
     * or that their presence does not matter. The node may still have
     * children. They are deleted recursively. That is the situation
     * where the parent/sibling information does not matter anymore, and
     * can be ignored.
     */

    tn_notleaf (n);
    tn_notnode (n);

    Tcl_DecrRefCount	(n->name); n->name = NULL;
    Tcl_DeleteHashEntry (n->he);   n->he   = NULL;

    if (n->child) {
	int i;

	for (i = 0; i < n->nchildren; i++) {
	    ASSERT_BOUNDS (i, n->nchildren);

	    tn_delete (n->child [i]);
	    n->child [i] = NULL;
	}
	ckfree ((char*) n->child);

	n->child       = NULL;
	n->nchildren   = 0;
	n->maxchildren = 0;
    }

    if (n->attr) {
	Tcl_HashSearch	hs;
	Tcl_HashEntry*	he;

	for(he = Tcl_FirstHashEntry(n->attr, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs)) {
	    Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
	}
	Tcl_DeleteHashTable(n->attr);
	ckfree ((char*) n->attr);
	n->attr = NULL;
    }

    ckfree ((char*) n);
}

/* .................................................. */

void
tn_node (TNPtr n)
{
    TPtr  t	= n->tree;
    TNPtr first = t->nodes;

    t->nnodes ++;

    n->nextnode = first;
    n->prevnode = NULL;
    t->nodes	= n;

    if (!first) return;
    first->prevnode = n;
}

void
tn_notnode (TNPtr n)
{
    T* t = n->tree;

    if ((t->nodes == n) || n->prevnode || n->nextnode) {
	if (t->nodes == n) {
	    t->nodes = n->nextnode;
	}
	if (n->prevnode) {
	    n->prevnode->nextnode = n->nextnode;
	}
	if (n->nextnode) {
	    n->nextnode->prevnode = n->prevnode;
	}
	n->prevnode = NULL;
	n->nextnode = NULL;
	t->nnodes --;
    }
}

void
tn_leaf (TNPtr n)
{
    TPtr  t	= n->tree;
    TNPtr first = t->leaves;

    if ((t->leaves == n) || n->prevleaf || n->nextleaf) {
	/* The node is already a leaf */
	return;
    }

    /* Now make the non-leaf it a leaf */

    t->nleaves ++;

    n->nextleaf = first;
    n->prevleaf = NULL;
    t->leaves	= n;

    if (!first) return;
    first->prevleaf = n;
}

void
tn_notleaf (TNPtr n)
{
    T* t = n->tree;

    if ((t->leaves == n) || n->prevleaf || n->nextleaf) {
	if (t->leaves == n) {
	    t->leaves = n->nextleaf;
	}
	if (n->prevleaf) {
	    n->prevleaf->nextleaf = n->nextleaf;
	}
	if (n->nextleaf) {
	    n->nextleaf->prevleaf = n->prevleaf;
	}
	n->prevleaf = NULL;
	n->nextleaf = NULL;
	t->nleaves --;
    }
}

/* .................................................. */

void
tn_structure (TNPtr n, int depth)
{
    n->depth = depth;
    n->desc  = n->nchildren; /* #direct children */

    depth ++;

    if (n->nchildren) {
	int i, maxh, h;

	for (i = 0, maxh = -1;
	     i < n->nchildren;
	     i++) {
	    ASSERT_BOUNDS (i, n->nchildren);

	    tn_structure (n->child [i], depth);

	    h = n->child [i]->height;

	    if (h > maxh) {
		maxh = h;
	    }
	}

	n->height = maxh + 1;
    } else {
	n->height = 0;
    }

    /* Extend parent with our descendants. Do not count
     * ourselves. This is already done in the parent through
     * the 'direct children' clause above at the beginning
     * of the function.
     */

    if (n->parent) {
	n->parent->desc += n->desc;
    }
}

/* .................................................. */

void
tn_detach (TNPtr n)
{
    /* Detaches the node from the tree by removing it from its parent
     * node. The sibling relationships are squashed as well, and the
     * index information for all right siblings is adjusted. The node
     * does retain its children. After this function is called the node
     * and its children are ready for tn_delete'. Or reinsertion in a
     * different place.
   */

    TNPtr p = n->parent;

    if (p->nchildren == 1) {
	/* This node is the last node in its parent. We can release the
	 * whole array of children now, and declare the parent to be a
	 * leaf again. There is no need to touch the siblings references,
	 * we know that they are NULL.
	 */

	ckfree ((char*) p->child);
	p->child       = NULL;
	p->maxchildren = 0;
	p->nchildren   = 0;

	tn_leaf (p);

    } else {
	/* The node is somewhere in the array of children of its
     * parent. We know the exact location, through 'index'. All
     * siblings to the right are moved down one slot, and their index
     * is adjusted in the same way. This is an O(n)
     * operation. Afterward we adjust the left/right references of the
     * node's siblings, if there are any, and reset the node's sibling
     * references as well.
     */

	int i;
	for (i = n->index; i < (p->nchildren-1); i++) {

	    ASSERT_BOUNDS (i,	p->nchildren);
	    ASSERT_BOUNDS (i+1, p->nchildren);

	    p->child [i] = p->child [i+1];
	    p->child [i]->index --;
	}
	p->nchildren --;
	/* Note regarding the decrement: As the node was _not_ the last
	 * child we know that the condition 'nchildren > 0' still holds, and
	 * that there is no need to free the 'child' array.
     */

	if (n->left) {
	    n->left->right = n->right;
	}
	if (n->right) {
	    n->right->left = n->left;
	}

	n->left	  = NULL;
	n->right  = NULL;
    }

    n->parent = NULL;
    n->tree->structure = 0;
}

TNPtr*
tn_detachmany (TNPtr n, int len)
{
    /* Detaches the node n and its 'len -1' right siblings from the tree
     * by removing them from their parent node. In toto 'len' nodes are
     * removed. The sibling relationships are squashed as well, and the
     * index information for all right siblings is adjusted. The nodes
     * retain their children. After this function is called thes node
     * and their children are ready for tn_delete'. Or reinsertion in a
     * different place.
   *
   * The operation fails with a panic if there are less children we
   * can cut than requested. It also panics when trying to cut
   * nothing.
   *
   * Note: This function does not reset the parent reference in the
   * cut nodes.
   */

    TNPtr* ch;
    TNPtr  p   = n->parent;
    int	   at  = n->index;
    int	   end = at + len;

    ASSERT (end <= p->nchildren, "tn_detachmany - tried to cut too many children");
    ASSERT (len > 0,		 "tn_detachmany - tried to cut nothing");

    if ((at == 0) && (end == p->nchildren)) {
	/* All children are taken. There is no need to copy anything, we
	 * can use the whole array, and reset the other information in the
	 * parent. Note that the condition above implies 'at == 0'. The
	 * parent node becomes a leaf again.
	 */
    
	ch = p->child;

	p->child       = NULL;
	p->maxchildren = 0;
	p->nchildren   = 0;

	tn_leaf (p);

    } else {
	/* Copies the cut nodes into a result array. Shifts the right
     * siblings down, if there are any.
     */

	int i, k;

	ch = NALLOC (len, TNPtr);

    /* Examples. We always have nchildren = 10.
     *
     * _______________________________
     * at  = 2, len = 3.
     * 
     * 01 234 56789 i = 0, k = 2
     *	  012	    i = 3, k = 5
     *
     * 01 234 56789 i = 2, k = 5
     * 01 567 89    i = 7, k = 10
     *
     * _______________________________
     * at  = 7, len = 3.
     * 
     * 0123456 789 i = 0, k = 7
     *	       012 i = 3, k = 10
     *
     * 0123456 789 i = 7, k = 10
     * 0123456	   nothing
     *
     * _______________________________
     * at  = 6, len = 3.
     * 
     * 012345 678 9 i = 0, k = 6
     *	      012   i = 3, k = 9
     *
     * 012345 678 9 i = 6, k = 9
     * 012345 9	    i = 7, k = 10
     *
     * _______________________________
     * at  = 6, len = 1.
     * 
     * 012345 6 789 i = 0, k = 6
     *	      0	    i = 1, k = 7
     *
     * 012345 6 789 i = 6, k = 7
     * 012345 7 89  i = 9, k = 10
     */

	for (i = 0, k = at; i < len; i++, k++) {

	    ASSERT_BOUNDS (k, p->nchildren);
	    ASSERT_BOUNDS (i, len);

	    ch [i] = p->child [k];
	}

	for (i = at, k = end; k < p->nchildren; i++, k++) {

	    ASSERT_BOUNDS (k, p->nchildren);
	    ASSERT_BOUNDS (i, p->nchildren);

	    p->child [i] = p->child [k];
	    p->child [i]->index -= len;
	}

	p->nchildren -= len;

	if (ch [0]->left) {
	    ch [0]->left->right = ch [len-1]->right;
	}
	if (ch [len-1]->right) {
	    ch [len-1]->right->left = ch [0]->left;
	}

	ch [0]->left	  = NULL;
	ch [len-1]->right = NULL;
    }

    n->tree->structure = 0;
    return ch;
}

TNPtr*
tn_detachchildren (TNPtr n, int* nc)
{
    TNPtr* children = n->child;

    *nc = n->nchildren;

    n->child	   = NULL;
    n->maxchildren = 0;
    n->nchildren   = 0;

    tn_leaf (n);
    return children;
}

/* .................................................. */

void
tn_append (TNPtr p, TNPtr n)
{
    /* Appending is O(1) */

    /* The node chosen as parent cannot be a leaf (anymore) */

    int at = p->nchildren;

    tn_notleaf (p); 

  /* Allocate/Extend child array as needed */

    p->nchildren ++;
    extend_children (p);

  /* Link the node into the parent and to its left sibling, if
   * any. This overwrites any existing relationships. Make sure
   * that the node n is either new or was cut before.
   */

    ASSERT_BOUNDS (at, p->nchildren);

    p->child [at] = n;

    n->parent = p;
    n->index  = at;
    n->right  = NULL;

    if (at > 0) {
	TNPtr sib;

	ASSERT_BOUNDS (at-1, p->nchildren);

	sib = p->child [at-1];
	n->left	   = sib;
	sib->right = n;
    }

    p->tree->structure = 0;
}

void
tn_appendmany (TNPtr p, int nc, TNPtr* nv)
{
    int i;

    /* Appending is O(1) */

    /* The node chosen as parent cannot be a leaf (anymore) */

    int at = p->nchildren;

    tn_notleaf (p); 

    /* Allocate/Extend child array as needed */

    p->nchildren += nc;
    extend_children (p);

    /* Link the nodes into the parent and to their left siblings, if
     * any. This overwrites any existing relationships. Make sure that
     * the nodes are either new or were cut before.
     */

    for (i = 0; i < nc; i++, at++) {

	ASSERT_BOUNDS (at, p->nchildren);
	ASSERT_BOUNDS (i, nc);

	p->child [at] = nv [i];

	nv [i]->parent = p;
	nv [i]->index  = at;
	nv [i]->right  = NULL;

	if (at > 0) {
	    TNPtr sib;

	    ASSERT_BOUNDS (at, p->nchildren);

	    sib = p->child [at-1];
	    nv [i]->left = sib;
	    sib->right	 = nv [i];
	}
    }

    p->tree->structure = 0;
}

/* .................................................. */

void
tn_insert (TNPtr p, int at, TNPtr n)
{
    int i, k;

    if (at >= p->nchildren) {
	tn_append (p, n);
	return;
    }

    /* Insertion at beginning, or somewhere in the middle */

    if (at < 0) {
	at = 0;
    }

    /* The node chosen as parent cannot be a leaf */
    /* anymore */

    tn_notleaf (p); 

    /* Allocate/Extend child array as needed */

    p->nchildren ++;
    extend_children (p);

    /* Link the node into the parent and to its left and right siblings,
     * if any. This overwrites any existing relationships. Make sure
     * that the node n is either new or was cut before.
     *
     * Shift all nodes at 'at' and to the right one slot up.
     * Note that 'nchildren' is incremented already.
     */

    for (i = p->nchildren-1, k = i-1; i > at; i--, k--) {

	ASSERT_BOUNDS (i, p->nchildren);
	ASSERT_BOUNDS (k, p->nchildren);

	p->child [i] = p->child [k];
	p->child [i]->index ++;
    }

    p->child [at] = n;

    n->parent = p;
    n->index  = at;

    /* We have to have a right sibling, otherwise it would have been
     * appending. We may have a left sibling.
     */

    ASSERT_BOUNDS (at+1, p->nchildren);

    n->right = p->child [at+1];
    p->child [at+1]->left = n;

    if (at == 0) {
	n->left = NULL;
    } else {
	ASSERT_BOUNDS (at-1, p->nchildren);

	n->left	       = p->child [at-1];
	p->child [at-1]->right = n;
    }

    p->tree->structure = 0;
}

void
tn_insertmany (TNPtr p, int at, int nc, TNPtr* nv)
{
    int i, k;
    if (at >= p->nchildren) {
	tn_appendmany (p, nc, nv);
	return;
    }

    if (at < 0) {
	at = 0;
    }

    /* The node chosen as parent cannot be a leaf */
    /* anymore */

    tn_notleaf (p); 

    /* Allocate/Extend child array as needed */

    p->nchildren += nc;
    extend_children (p);

    /* Link the node into the parent and to its left and right siblings,
     * if any. This overwrites any existing relationships. Make sure
     * that the node n is either new or was cut before.
     *
     * Shift all nodes at 'at' and to the right one slot up.
     * Note that 'nchildren' is incremented already.
     */

    for (i = p->nchildren-1, k = i-nc; k >= at; i--, k--) {

	ASSERT_BOUNDS (i, p->nchildren);
	ASSERT_BOUNDS (k, p->nchildren);

	p->child [i] = p->child [k];
	p->child [i]->index += nc;
    }

    for (i = 0, k = at; i < nc; i++, k++) {

	ASSERT_BOUNDS (i, nc);
	ASSERT_BOUNDS (k, p->nchildren);

	nv [i]->parent = p;
	nv [i]->index  = k;
	p->child [k]   = nv [i];
    }

    for (i = 0, k = at; i < nc; i++, k++) {
	if (k > 0) {
	    ASSERT_BOUNDS (k,	p->nchildren);
	    ASSERT_BOUNDS (k-1, p->nchildren);

	    p->child [k]->left	  = p->child [k-1];
	    p->child [k-1]->right = p->child [k];
	}

	if (k < (p->nchildren-1)) {
	    ASSERT_BOUNDS (k,	p->nchildren);
	    ASSERT_BOUNDS (k+1, p->nchildren);

	    p->child [k]->right	 = p->child [k+1];
	    p->child [k+1]->left = p->child [k];
	}
    }

    p->tree->structure = 0;
}

/* .................................................. */

void
tn_cut (TNPtr n)
{
    TNPtr p  = n->parent; /* Remember the location of n in its */
    int at = n->index;	/* parent, this is the point there its
			 * children are re-inserted */
    int	 nc;
    TNPtr* nv;

    nv = tn_detachchildren (n, &nc);
    tn_detach (n);

    tn_insertmany (p, at, nc, nv);
    ckfree ((char*) nv);

    tn_delete (n);
}

TNPtr
tn_dup (TPtr dst, TNPtr src)
{
    TNPtr dstn;

    dstn = tn_new (dst, Tcl_GetString (src->name));

    if (src->attr) {
	int i, new;
	Tcl_HashSearch hs;
	Tcl_HashEntry* he;
	Tcl_HashEntry* dhe;
	CONST char*    key;
	Tcl_Obj*       val;

	dstn->attr = ALLOC (Tcl_HashTable);
	Tcl_InitHashTable(dstn->attr, TCL_STRING_KEYS);

	for(i = 0, he = Tcl_FirstHashEntry(src->attr, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs), i++) {

	    key = Tcl_GetHashKey (src->attr, he);
	    val = (Tcl_Obj*) Tcl_GetHashValue(he);

	    dhe = Tcl_CreateHashEntry(dstn->attr, key, &new);

	    Tcl_IncrRefCount (val);
	    Tcl_SetHashValue (dhe, (ClientData) val);
	}
    }

    if (src->nchildren) {
	int i;

	dstn->child	  = NALLOC (src->nchildren, TNPtr);
	dstn->maxchildren = src->nchildren;
	dstn->nchildren	  = 0;

	for (i = 0; i < src->nchildren; i++) {

	    ASSERT_BOUNDS (i, src->nchildren);

	    tn_append (dstn,
		       tn_dup (dst, src->child [i]));
	}
    }

    return dstn;
}

/* .................................................. */

void
tn_set_attr (TNPtr n, Tcl_Interp* interp, Tcl_Obj* dict)
{
    Tcl_HashEntry* he;
    CONST char*	   key;
    Tcl_Obj*	   val;
    int		   new, i;
    int		   listc;
    Tcl_Obj**	   listv;

    if (Tcl_ListObjGetElements (interp, dict, &listc, &listv) != TCL_OK) {
	Tcl_Panic ("Malformed nodes attributes, snuck through validation of serialization.");
    }

    if (!listc) {
	return;
    }

    tn_extend_attr (n);

    for (i = 0; i < listc; i+= 2) {

	ASSERT_BOUNDS (i,   listc);
	ASSERT_BOUNDS (i+1, listc);

	key = Tcl_GetString (listv [i]);
	val = listv [i+1];

	he = Tcl_CreateHashEntry(n->attr, key, &new);

	Tcl_IncrRefCount (val);
	Tcl_SetHashValue (he, (ClientData) val);
    }
}

/* .................................................. */

void
tn_extend_attr (TNPtr n)
{
    if (n->attr != NULL) {
	return;
    }

    n->attr = ALLOC (Tcl_HashTable);
    Tcl_InitHashTable(n->attr, TCL_STRING_KEYS);
}

/* .................................................. */

int
tn_depth (TNPtr n)
{
    if (!n->tree->structure) {
	t_structure (n->tree);
    }
    return n->depth;
}

int
tn_height (TNPtr n)
{
    if (!n->tree->structure) {
	t_structure (n->tree);
    }
    return n->height;
}

int
tn_ndescendants (TNPtr n)
{
    if (n == n->tree->root) {
	/* For the root we do not need to know the structure data of the
	 * tree to determine the number of descendants. It is the number
	 * of nodes minus one, i.e. all nodes except the root.
	 */

	return n->tree->nnodes - 1;

    } else if (!n->nchildren) {
	/* If the node has no direct children we know there are no
	 * descendants as well
	 */

	return 0;

    } else if (!n->tree->structure) {
	t_structure (n->tree);
    }

    return n->desc;
}

Tcl_Obj**
tn_getdescendants (TNPtr n, int* nc)
{
    int	      end;
    int	      lc = tn_ndescendants (n);
    Tcl_Obj** lv;

    *nc = lc;

    if (lc == 0) {
	return NULL;
    }

    lv	= NALLOC (lc, Tcl_Obj*);
    end = fill_descendants (n, lc, lv, 0);

    ASSERT (end == lc, "Bad list of descendants");
    return lv;
}

Tcl_Obj**
tn_getchildren (TNPtr n, int* nc)
{
    if (!n->nchildren) {
	*nc = 0;
	return NULL;
    } else {
	int	  i;
	Tcl_Obj** lv;

	*nc = n->nchildren;
	lv  = NALLOC (n->nchildren, Tcl_Obj*);

	for (i = 0; i < n->nchildren; i++) {

	    ASSERT_BOUNDS (i, n->nchildren);

	    lv [i] = n->child [i]->name;
	}

	return lv;
    }
}

int
tn_filternodes (int* nc,   Tcl_Obj** nv,
		int  cmdc, Tcl_Obj** cmdv,
		Tcl_Obj* tree, Tcl_Interp* interp)
{
    int i;
    int	      ec;
    Tcl_Obj** ev;

    if (cmdc && (*nc > 0)) {
	/* Run the filter command over all nodes in the list.
	 * Keep only the nodes passing the filter in the list.
	 */

	int	  lc = *nc;

	int src, dst, res, flag;

	/* Set up the command vector for the callback.
	 * Two placeholders for tree and node arguments.
	 */

	ec = cmdc + 2;
	ev = NALLOC (ec, Tcl_Obj*);

	for (i = 0; i < cmdc; i++) {
	    ASSERT_BOUNDS (i, ec);

	    ev [i] = cmdv [i];
	    Tcl_IncrRefCount (ev [i]);
	}
	ASSERT_BOUNDS (cmdc, ec);

	ev [cmdc] = tree; /* Tree */
	Tcl_IncrRefCount (ev [cmdc]);

	/* Run the callback on each element of the list */

	for (src = 0, dst = 0;
	     src < lc;
	     src++) {

	    /* Fill the placeholders */

	    ASSERT_BOUNDS (cmdc+1, ec);
	    ASSERT_BOUNDS (src, lc);

	    ev [cmdc+1] = nv [src]; /* Node */

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

	    /* Result is valid, use this decide retain/write over */

	    if (!flag)
		continue;

	    ASSERT_BOUNDS (dst, lc);
	    ASSERT_BOUNDS (src, lc);

	    nv [dst] = nv [src];
	    dst++;
	}

	/* Cleanup state */

	Tcl_ResetResult (interp);

	for (i = 0; i < cmdc; i++) {
	    ASSERT_BOUNDS (i, ec);
	    Tcl_DecrRefCount (ev [i]);
	}
	ASSERT_BOUNDS (cmdc, ec);
	Tcl_DecrRefCount (ev [cmdc]); /* Tree */

	ckfree ((char*) ev);

	*nc = dst;
    }

    return TCL_OK;

 abort:
    /* We do not reset the interp result. It either contains
     * the non-boolean result, or the error message
     */

    for (i = 0; i < cmdc; i++) {
	ASSERT_BOUNDS (i, ec);
	Tcl_DecrRefCount (ev [i]);
    }
    ASSERT_BOUNDS (cmdc, ec);
    Tcl_DecrRefCount (ev [cmdc]); /* Tree */

    ckfree ((char*) ev);
    return TCL_ERROR;
}

/* .................................................. */

int
tn_isancestorof (TNPtr na, TNPtr nb)
{
    /* True <=> a is ancestor of b */

    for (nb = nb->parent; nb != NULL; ) {
	if (na == nb) {
	    return 1;
	}
	nb = nb->parent;
    }

    return 0;
}

/* .................................................. */

Tcl_Obj*
tn_get_attr (TNPtr tdn, Tcl_Obj* empty)
{
    int		   i;
    Tcl_Obj*	   res;
    int		   listc;
    Tcl_Obj**	   listv;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    CONST char*	   key;

    if ((tdn->attr == NULL) || (tdn->attr->numEntries == 0)) {
	return empty;
    }

    listc = 2 * tdn->attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    for(i = 0, he = Tcl_FirstHashEntry(tdn->attr, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {

	key = Tcl_GetHashKey (tdn->attr, he);

	ASSERT_BOUNDS (i,   listc);
	ASSERT_BOUNDS (i+1, listc);

	listv [i] = Tcl_NewStringObj (key, -1);	     i++;
	listv [i] = (Tcl_Obj*) Tcl_GetHashValue(he); i++;
    }

    res = Tcl_NewListObj (listc, listv);
    ckfree ((char*) listv);
    return res;
}

int
tn_serialize (TNPtr tdn, int listc, Tcl_Obj** listv, int at, int parent, Tcl_Obj* empty)
{
    int self = at;

    ASSERT_BOUNDS (at+0, listc);
    ASSERT_BOUNDS (at+1, listc);
    ASSERT_BOUNDS (at+2, listc);

    listv [at++] = tdn->name;
    listv [at++] = (parent < 0 ? empty : Tcl_NewIntObj (parent));
    listv [at++] = tn_get_attr (tdn, empty);

    if (tdn->nchildren) {
	int i;
	for (i = 0; i < tdn->nchildren; i++) {
	    at = tn_serialize (tdn->child [i], listc, listv, at, self, empty);
	}
    }

    return at;
}

/* .................................................. */static int
fill_descendants (TNPtr n, int lc, Tcl_Obj** lv, int at)
{
    /* The descendants of the root are simply all nodes except the root
     * itself. That is easy to retrieve.
   */

    if (n == n->tree->root) {
	TNPtr iter;

	for (iter = n->tree->nodes;
	     iter != NULL;
	     iter = iter->nextnode) {

	    /* Skip the root node, it is not a descendant! */
	    if (iter == n) continue;

	    ASSERT_BOUNDS (at, lc);

	    lv [at] = iter->name;
	    at++;
	}
    } else if (n->child) {
	int   i;
	TNPtr c;

	for (i = 0; i < n->nchildren; i++) {
	    c = n->child [i];

	    ASSERT_BOUNDS (at, lc);
	    ASSERT_BOUNDS (i,  n->nchildren);

	    lv [at] = c->name;
	    at++;

	    at = fill_descendants (c, lc, lv, at);
	}
    }

    return at;
}

static void
extend_children (TNPtr n)
{
    if (n->nchildren > n->maxchildren) {
	if (n->child == NULL) {
	    n->child = NALLOC (n->nchildren, TNPtr);
	} else {
	    int	   nc  = 2 * n->nchildren;
	    TNPtr* new = (TNPtr*) attemptckrealloc ((char*) n->child,
						    nc * sizeof (TNPtr));
	    if (new == NULL) {
		nc  = n->nchildren;
		new = (TNPtr*) ckrealloc ((char*) n->child, nc * sizeof (TNPtr));
	    }
	    n->child	   = new;
	    n->maxchildren = nc;
	}
    }
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

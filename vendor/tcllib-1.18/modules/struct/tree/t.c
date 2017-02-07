/* struct::tree - critcl - layer 1 definitions
 * (c) Tree functions
 */

#include <t.h>
#include <tn.h>
#include <util.h>

/* .................................................. */

T*
t_new (void)
{
    T* t = ALLOC (T);

    Tcl_InitHashTable (&t->node, TCL_STRING_KEYS);

    t->cmd	 = NULL;
    t->counter	 = 0;
    t->nodes	 = NULL;
    t->nnodes	 = 0;
    t->leaves	 = NULL;
    t->nleaves	 = 0;
    t->root	 = tn_new (t, "root");
    t->structure = 0;

    return t;
}

void
t_delete (T* t)
{
    /* Delete a tree in toto. Recursively deletes all nodes first,
     * starting at root. This also handles the nodes/leaves lists.
     * Then the name -> node mapping, and the object name. The
     */

    tn_delete (t->root);

    Tcl_DeleteHashTable(&t->node);

    t->cmd = NULL;
    ckfree ((char*) t);
}

/* .................................................. */

void
t_structure (T* t)
{
    /* Computes all structural data,
     * then declares it valid.
   */

    tn_structure (t->root, 0);
    t->structure = 1;
}

/* .................................................. */

int
t_deserialize (T* dst, Tcl_Interp* interp, Tcl_Obj* src)
{
    int	      listc;
    Tcl_Obj** listv;
    int	      nodes;

    int	      root   = -1;
    int*      parent = NULL;

    /* Basic checks:
     * - Is the input a list ?
     * - Is its length a multiple of three ?
     *
     * structure:  node-name parent-index attr-dict
     *		   i+0	     i+1	  i+2
     */

#define NAME(i)	  (i)
#define PARENT(i) ((i)+1)
#define ATTR(i)	  ((i)+2)

    if (Tcl_ListObjGetElements (interp, src, &listc, &listv) != TCL_OK) {
	return TCL_ERROR;
    }
    if ((listc % 3) != 0) {
	Tcl_AppendResult (interp,
			  "error in serialization: list length not a multiple of 3.",
			  NULL);
	return TCL_ERROR;
    }

    nodes = listc/3;

    /* Iterate and check the attribute dictionaries for listness and
     * size (even length).
     */

    {
	int	  ac;
	Tcl_Obj** av;
	int i, j;

	for (i = 0, j = 0;
	     i < listc;
	     i += 3, j++) {

	    ASSERT_BOUNDS (ATTR(i), listc);
	    ASSERT_BOUNDS (j,	    nodes);

	    if (Tcl_ListObjGetElements (interp, listv [ATTR(i)],
					&ac, &av) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if ((ac % 2) != 0) {
		Tcl_AppendResult (interp,
				  "error in serialization: malformed attribute dictionary.",
				  NULL);
		return TCL_ERROR;
	    }
	}
    }

    /* Iterate to locate the definition of root. Fails if there is none,
     * or more than one.
     */

    {
	int i, j;
	CONST char* parent;

	for (i = 0, j = 0, root = -1;
	     i < listc;
	     i += 3, j++) {
	    /* j == i/3 */

	    ASSERT_BOUNDS (PARENT(i), listc);
	    ASSERT_BOUNDS (j,	      nodes);

	    parent = Tcl_GetString (listv [PARENT(i)]);

	    if (0 == strcmp ("", parent)) {
		if (root >= 0) {
		    Tcl_AppendResult (interp,
				      "error in serialization: multiple root nodes.",
				      NULL);
		    return TCL_ERROR;
		}

		root = j;
	    }
	}

	if (root < 0) {
	    Tcl_AppendResult (interp,
			      "error in serialization: no root specified.",
			      NULL);
	    return TCL_ERROR;
	}
    }

    /* Iterate again, check that the non-empty parent references
     * are ok. We use the information we have about root to skip
     * over the empty reference. We save the extracted and parsed
     * references in a temp. allocated array.
     */

    {
	int i, j, index, res;
	Tcl_Obj* p;

	parent = NALLOC (nodes, int);

	ASSERT_BOUNDS (root, nodes);
	parent [root] = -1; /* Sensible, unused */

	for (i = 0, j = 0;
	     i < listc;
	     i += 3, j++) {
	    /* j == i/3 */

	    ASSERT_BOUNDS (PARENT(i), listc);
	    ASSERT_BOUNDS (j,	      nodes);

	    if (j == root)
		continue;

	    p	= listv [PARENT(i)];
	    res = Tcl_GetIntFromObj (interp, p, &index);

	    if (
		(res != TCL_OK) ||
		(index < 0) ||
		(index >= listc) ||
		((index % 3) != 0)
		) {
		Tcl_ResetResult (interp);
		Tcl_AppendResult (interp,
				  "error in serialization: bad parent reference \"",
				  Tcl_GetString (p),
				  "\".", NULL);
		ckfree ((char*) parent);
		return TCL_ERROR;
	    }

	    if (index == i) {
		/* Found a cyclic reference (direct cycle, node defines
		 * itself as its parent)
		 */

		Tcl_AppendResult (interp,
				  "error in serialization: cycle detected.",
				  NULL);
		ckfree ((char*) parent);
		return TCL_ERROR;
	    }

	    parent [j] = index/3;
	}
    }

    /* Iteration over the parent information from the last phase.  We
     * are looking for indirect cycles. We detect them indirectly. If
     * there are cycles we are unable to tag all nodes starting from the
     * root. A tag means that the depth of the node can be computed, and
     * for nodes in a cycle this is not possible.
     */

    {
	int* tag = NALLOC (nodes, int);
	int  i;
	int  changed = 1; /* Flag that last iteration tagged new nodes */
	int  done    = 0; /* #nodes tagged */

	for (i = 0; i < nodes; i++) {

	    ASSERT_BOUNDS (i, nodes);
	    tag [i] = 0;
	}

	ASSERT_BOUNDS (root, nodes);
	tag [root] = 1;
	done ++;

	while (changed) {
	    changed = 0;

	    for (i = 0; i < nodes; i++) {
		ASSERT_BOUNDS (i, nodes);
		if (tag [i])
		    continue;

		/* Assert: parent [i] in 0 .. nodes-1 */
		ASSERT_BOUNDS (parent[i], nodes);
		if (!tag [parent [i]])
		    continue;

		tag [i] = 1;
		changed = 1;
		done ++;
	    }
	}

	ckfree ((char*) tag);

	if (done < nodes) {
	    Tcl_AppendResult (interp,
			      "error in serialization: cycle detected.",
			      NULL);

	    ckfree ((char*) parent);
	    return TCL_ERROR;
	}
    }

    /* Last iteration. Check that the node names are unique.
     */

    {
	int	      i, j, new;
	Tcl_HashTable nx;

	Tcl_InitHashTable (&nx, TCL_STRING_KEYS);

	for (i = 0, j = 0;
	     i < listc;
	     i += 3, j++) {

	    ASSERT_BOUNDS (NAME(i), listc);
	    ASSERT_BOUNDS (j,	    nodes);

	    Tcl_CreateHashEntry (&nx, Tcl_GetString (listv [NAME(i)]),
				 &new);

	    if (!new) {
		Tcl_AppendResult (interp,
				  "error in serialization: duplicate node names.",
				  NULL);
		Tcl_DeleteHashTable(&nx);
		ckfree ((char*) parent);
		return TCL_ERROR;
	    }
	}

	Tcl_DeleteHashTable(&nx);
    }

    /* The serialization has been successfully validated now.
     * We create the nodes, their attributes, and link them
     * into the proper structure per the root and parent
     * information provided to us by the validation.
     */

    {
	int i, j;
	TN** nv = NALLOC (nodes, TN*);
	TN* n;
	TN* p;

	tn_delete (dst->root);

	for (i = 0, j = 0;
	     i < listc;
	     i += 3, j++) {
	    /* j == i/3 */

	    ASSERT_BOUNDS (NAME(i), listc);
	    ASSERT_BOUNDS (j,	    nodes);

	    nv [j] = tn_new (dst, Tcl_GetString (listv [NAME(i)]));
	}

	dst->root = nv [root];

	for (i = 0, j = 0;
	     i < listc;
	     i += 3, j++) {
	    /* j == i/3 */

	    ASSERT_BOUNDS (ATTR(i),   listc);
	    ASSERT_BOUNDS (j,	      nodes);

	    if (j == root) {
		/* We don't append the node, this has already been covered,
		 * but we have to process the attributes.
		 */

		tn_set_attr (nv [j], interp, listv [ATTR(i)]);
		continue;
	    }

	    ASSERT_BOUNDS (parent[j], nodes);

	    n = nv [j];
	    p = nv [parent [j]];

	    tn_append (p, n);
	    tn_set_attr (n, interp, listv [ATTR(i)]);
	}

	ckfree ((char*) nv);
    }

    ckfree ((char*) parent);
    return TCL_OK;
}

/* .................................................. */

int
t_assign (T* dst, T* src)
{
    tn_delete (dst->root);
    dst->root = tn_dup (dst, src->root);
    return TCL_OK;
}

/* .................................................. */

CONST char*
t_newnodename (T* t)
{
    int ok;
    Tcl_HashEntry* he;

    do {
	t->counter ++;
	sprintf (t->handle, "node%d", t->counter);

	/* Check that there is no node using that name already */
	he = Tcl_FindHashEntry (&t->node, t->handle);
	ok = (he == NULL);
    } while (!ok);

    return t->handle;
}

/* .................................................. */

void
t_dump (TPtr t, FILE* f)
{
    /* Write the structural data of the
     * tree (i.e. internal pointers) to
     * the file, as aid in debugging
     */

    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    TNPtr n;

    fprintf (f, "T (%p) {\n",t);fflush(f);
    fprintf (f, ".   Lstart %p '%s'\n", t->leaves, t->leaves?Tcl_GetString(t->leaves->name):"");fflush(f);
    fprintf (f, ".   Nstart %p '%s'\n", t->nodes,  t->nodes ?Tcl_GetString(t->nodes ->name):"");fflush(f);

    for (he = Tcl_FirstHashEntry (&t->node, &hs);
	 he != NULL;
	 he = Tcl_NextHashEntry (&hs)) {
	n = (TNPtr) Tcl_GetHashValue(he);
	fprintf (f, ".   N [%p '%s']",n,Tcl_GetString(n->name))   ;fflush(f);
	fprintf (f, " %p",n->tree);fflush(f);
	fprintf (f, " %p '%s'",n->prevleaf,n->prevleaf?Tcl_GetString(n->prevleaf->name):"");fflush(f);
	fprintf (f, " %p '%s'",n->nextleaf,n->nextleaf?Tcl_GetString(n->nextleaf->name):"");fflush(f);
	fprintf (f, " %p '%s'",n->prevnode,n->prevnode?Tcl_GetString(n->prevnode->name):"");fflush(f);
	fprintf (f, " %p '%s'",n->nextnode,n->nextnode?Tcl_GetString(n->nextnode->name):"");fflush(f);
	fprintf (f, " %p '%s'",n->parent  ,n->parent  ?Tcl_GetString(n->parent->name)  :"");fflush(f);
	fprintf (f, "\n");fflush(f);
    }
    fprintf (f, "}\n");fflush(f);
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

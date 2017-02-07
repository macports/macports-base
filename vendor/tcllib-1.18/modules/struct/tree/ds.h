/* struct::tree - critcl - layer 1 declarations
 * (a) Data structures.
 */

#ifndef _DS_H
#define _DS_H 1

#include "tcl.h"

/* Forward declarations of references to trees & nodes.
 */

typedef struct T*  TPtr;
typedef struct TN* TNPtr;

/* Node structure.
 */

typedef struct TN {
    /* Node identity / handle */
    /* Internal rep should be of type */
    /* 'tcllib::struct::tree/critcl::node'. */
    /* See below. */

    Tcl_Obj*	   name;
    Tcl_HashEntry* he;

    /* Basic linkage of node to its tree */

    TPtr  tree;	     /* Tree the node belongs to */
    TNPtr nextleaf;  /* Double linked list of all */
    TNPtr prevleaf;  /* leaf nodes */
    TNPtr nextnode;  /* Double linked list of all */
    TNPtr prevnode;  /* nodes */

    /* Node navigation. Parent/Children/Siblings */

    TNPtr  parent; /* Parent node */

    TNPtr* child;	/* Array of children. Can
			 * be NULL. leaf node implies
			 * NULL, and vice versa */
    int	   nchildren;	/* # nodes used in previous array */
    int	   maxchildren; /* Size of previous array */

    TNPtr left;	  /* Sibling to the left, NULL if no such  */
    TNPtr right;  /* Sibling to the right, NULL if no such */

    /* Node attributes */

    Tcl_HashTable* attr; /* Node attributes. NULL if the
			  * node has none */

    /* Cache for properties of the node based on the tree
     * structure
     */

    int index;	/* Index of node in 'child' array of its
		 * parent */
    int depth;	/* Distance to root node.
		 * 0 <=> root */
    int height; /* Distance to deepest child.
		 * 0 <=> Leaf. */
    int desc;	/* #Descendants */

} TN;

/* Tree structure
 */

typedef struct T {
    Tcl_Command cmd;	/* Token of the object command for
			 * the tree */

    Tcl_HashTable node; /* Mapping
			 * Node names -> Node structure */

    int counter;	/* Counter used by the generator
			 * of node names */

    TN* root;		/* Root node of the tree. */

    TN* leaves;		/* List of all leaf nodes */
    int nleaves;	/* List length */

    TN* nodes;		/* List of all nodes */
    int nnodes;		/* List length */

    int structure;	/* Boolean flag. Set to true if the
			 * depth/height/desc information
			 * in the nodes is valid. Reset to
			 * false by all operations changing
			 * the structure of the tree. */

    /* Generation of node handles. Tree local storage, makes code thread
     * oblivious.
     */

    char handle [50];

} T;

#endif /* _DS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

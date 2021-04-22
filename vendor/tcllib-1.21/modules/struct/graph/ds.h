/* struct::graph - critcl - layer 1 declarations
 * (a) Data structures.
 */

#ifndef _DS_H
#define _DS_H 1

#include "tcl.h"

/*
 * The data structures for a graph are mainly double-linked lists, combined
 * with hash maps.
 *
 * We have a single structure per interpreter, -> GG.  This structure holds
 * the counter and string buffer for the generation of automatic graph names.
 *
 * We have one structure per graph, -> G. It holds a single hash map for the
 * attributes, and two hash maps with associated lists for nodes and arcs. The
 * maps are for retrieval by name, the lists when searches by various features
 * are done. Beyond we have the counters and string buffer for the generation
 * of automatic arc- and node-names. As the information for nodes and arcs are
 * identical they are pulled together in their own common structure -> GCC.
 *
 * The basic information of both nodes and arcs themselves is the same as
 * well, name and attributes, and the graph owning them. Pulled together in a
 * common structure, -> GC. This also holds the prev/next linkage for the per
 * graph lists starting in GCC. The node/arc structures are pseudo-derived
 * from this structure.
 *
 * Each node manages two lists of arcs, incoming and outgoing ones. The list
 * elements are -> GL structures, also called the interlinks, as they weld
 * nodes and arcs together. Neither node nor arcs refer directly to each
 * other, but go through these interlinks. The indirection allows the
 * insertion, movement and removal of arcs without having to perform complex
 * updates in the node and arc structures. Like shifting array elements, with
 * O(n^2) effort. The list anchors are -> GLA structures, keeping track of the
 * list length as well.
 *
 * Arcs manage their source/target directly, by refering to the relevant
 * interlink structures.
 */

/*
 * Forward declarations of references to graphs, nodes, and arcs.
 */

typedef struct GL* GLPtr; /* node/arc interlink */
typedef struct GC* GCPtr; /* node/arc common */
typedef struct GN* GNPtr; /* node */
typedef struct GA* GAPtr; /* arc */
typedef struct G*  GPtr;  /* graph */
typedef struct GG* GGPtr; /* Per-interp (global) */

/*
 * Chains of arcs, structure for interlinkage between nodes and arcs.
 * Operations API & Impl. -> gl.[ch]
 */

typedef struct GL {
    GNPtr n;    /* Node the interlink belongs to */
    GAPtr a;    /* Arc the  interlink belongs to */
    GLPtr prev; /* Previous interlink in chain */
    GLPtr next; /* Next     interlink in chain */
} GL;

/*
 * Data common to nodes and arcs
 */

typedef struct GC {
    /* Identity / handle */
    /* Internal rep should be of type */
    /* 'tcllib::struct::graph/critcl::{node,arc}'. */
    /* See below. */

    Tcl_Obj*	   name;
    Tcl_HashEntry* he;

    /* Node / Arc attributes */

    Tcl_HashTable* attr; /* NULL if the entity has no attributes */

    /* Basic linkage of node/arc to its graph */

    GPtr  graph; /* Graph the node/arc belongs to */
    GCPtr next;  /* Double linked list of all */
    GCPtr prev;  /* nodes/arc. See GGC for the head */
} GC;

/*
 * Interlink chains, anchor structure
 */

typedef struct GLA {
    GL* first; /* First interlink */
    int n;     /* Number of interlinks */
} GLA;

/*
 * Node structure.
 */

typedef struct GN {
    GC base; /* Basics, common information */

    /* Node navigation. Incoming/Outgoing arcs, via interlink chains. */

    GLA in;
    GLA out;
} GN;

/*
 * Arc structure.
 */

typedef struct GA {
    GC base; /* Basics, common information */

    /* Arc navigation. Start/End node. Indirect specification through an
     * interlink.
     */

    GL* start; /* Interlink to node where arc begins */
    GL* end;   /* Interlink to node where arc ends */

    Tcl_Obj* weight; /* If not NULL the weight of the arc */
} GA;

/*
 * Helper structure for the lists and maps of nodes/arcs.
 */

typedef struct GCC {
    Tcl_HashTable* map;   /* Mapping names -> structure */
    GC*            first; /* Start of entity list */
    int            n;     /* Length of the list */
} GCC;

/*
 * Graph structure.
 */

typedef struct G {
    Tcl_Command    cmd;   /* Token of the object command for * the graph */
    GCC            nodes; /* All nodes */
    GCC            arcs;  /* All arcs */
    Tcl_HashTable* attr;  /* Graph attributes. NULL if the graph has none */

    /* Generation of node and arc handles. Graph local storage, makes the code
     * thread oblivious.
     */

    char handle [50];
    int  ncounter;	/* Counter used by the generator of node names */
    int  acounter;	/* Counter used by the generator of arc names */
} G;

/*
 * 'Global' management. One structure per interpreter.
 */

typedef struct GG {
    long int counter;  /* Graph id generator */
    char     buf [50]; /* Buffer for handle construction */
} GG;


typedef GC* (GN_GET_GC) (G* g, Tcl_Obj* x, Tcl_Interp* interp, Tcl_Obj* graph);

#endif /* _DS_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::graph - critcl - layer 2 definitions
 *
 * -> Support for the graph methods in layer 3.
 */

#include <methods.h>
#include <objcmd.h>

/*
 *---------------------------------------------------------------------------
 *
 * g_objcmd --
 *
 *	Implementation of graph objects, the main dispatcher function.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Per the called methods.
 *
 *---------------------------------------------------------------------------
 */

int
g_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    G*	g = (G*) cd;
    int m;

    static CONST char* methods [] = {
	"-->",	   "=",	    "append",	 "arc",	      "arcs", "deserialize",
	"destroy", "get",   "getall",	 "keyexists", "keys", "lappend",
	"node",	   "nodes", "serialize", "set",	      "swap", "unset",
	"walk",
	NULL
    };
    enum methods {
	M_GSET,	   M_GASSIGN, M_APPEND,	   M_ARC,	M_ARCS, M_DESERIALIZE,
	M_DESTROY, M_GET,     M_GETALL,	   M_KEYEXISTS, M_KEYS, M_LAPPEND,
	M_NODE,	   M_NODES,   M_SERIALIZE, M_SET,	M_SWAP, M_UNSET,
	M_WALK
    };

    static CONST char* a_methods [] = {
	"append",      "attr",   "delete",        "exists",        "flip",
	"get",         "getall", "getunweighted", "getweight",     "hasweight", "insert",
	"keyexists",   "keys",   "lappend",       "move",          "move-source",
	"move-target", "nodes",	 "rename",	  "set",           "setunweighted", "setweight",
	"source",      "target", "unset",         "unsetweight",   "weights",
	NULL
    };
    enum a_methods {
	MA_APPEND,      MA_ATTR,        MA_DELETE,        MA_EXISTS,    MA_FLIP,
	MA_GET,         MA_GETALL,      MA_GETUNWEIGHTED, MA_GETWEIGHT, MA_HASWEIGHT,
	MA_INSERT,      MA_KEYEXISTS,   MA_KEYS,          MA_LAPPEND,   MA_MOVE,
	MA_MOVE_SOURCE, MA_MOVE_TARGET, MA_NODES,	  MA_RENAME,    MA_SET,       MA_SETUNWEIGHTED,
	MA_SETWEIGHT,	MA_SOURCE,      MA_TARGET,        MA_UNSET,     MA_UNSETWEIGHT,
	MA_WEIGHTS
    };

    static CONST char* n_methods [] = {
	"append",  "attr",     "degree", "delete",    "exists",
	"get",	   "getall",   "insert", "keyexists", "keys",
	"lappend", "opposite", "rename", "set",	      "unset",
	NULL
    };
    enum n_methods {
	MN_APPEND,  MN_ATTR,	 MN_DEGREE, MN_DELETE,	  MN_EXISTS,
	MN_GET,	    MN_GETALL,	 MN_INSERT, MN_KEYEXISTS, MN_KEYS,
	MN_LAPPEND, MN_OPPOSITE, MN_RENAME, MN_SET,	  MN_UNSET
    };

    if (objc < 2) {
	Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    } else if (Tcl_GetIndexFromObj (interp, objv [1], methods, "option",
				    0, &m) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Dispatch to methods. They check the #args in detail before performing
     * the requested functionality
     */

    switch (m) {
    case M_GSET:	return gm_GSET	      (g, interp, objc, objv);
    case M_GASSIGN:	return gm_GASSIGN     (g, interp, objc, objv);
    case M_APPEND:	return gm_APPEND      (g, interp, objc, objv);
    case M_ARC:
	if (objc < 3) {
	    Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
	    return TCL_ERROR;
	} else if (Tcl_GetIndexFromObj (interp, objv [2], a_methods, "option",
					0, &m) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (m) {
	case MA_APPEND:	       return gm_arc_APPEND     (g, interp, objc, objv);
	case MA_ATTR:	       return gm_arc_ATTR	(g, interp, objc, objv);
	case MA_DELETE:	       return gm_arc_DELETE     (g, interp, objc, objv);
	case MA_EXISTS:	       return gm_arc_EXISTS     (g, interp, objc, objv);
	case MA_FLIP:          return gm_arc_FLIP       (g, interp, objc, objv);
	case MA_GET:	       return gm_arc_GET	(g, interp, objc, objv);
	case MA_GETALL:	       return gm_arc_GETALL     (g, interp, objc, objv);
	case MA_GETUNWEIGHTED: return gm_arc_GETUNWEIGH (g, interp, objc, objv);
	case MA_GETWEIGHT:     return gm_arc_GETWEIGHT  (g, interp, objc, objv);
	case MA_HASWEIGHT:     return gm_arc_HASWEIGHT  (g, interp, objc, objv);
	case MA_INSERT:	       return gm_arc_INSERT     (g, interp, objc, objv);
	case MA_KEYEXISTS:     return gm_arc_KEYEXISTS  (g, interp, objc, objv);
	case MA_KEYS:	       return gm_arc_KEYS	(g, interp, objc, objv);
	case MA_LAPPEND:       return gm_arc_LAPPEND    (g, interp, objc, objv);
	case MA_MOVE:          return gm_arc_MOVE       (g, interp, objc, objv);
	case MA_MOVE_SOURCE:   return gm_arc_MOVE_SRC   (g, interp, objc, objv);
	case MA_MOVE_TARGET:   return gm_arc_MOVE_TARG  (g, interp, objc, objv);
	case MA_NODES:         return gm_arc_NODES      (g, interp, objc, objv);
	case MA_RENAME:	       return gm_arc_RENAME     (g, interp, objc, objv);
	case MA_SET:	       return gm_arc_SET	(g, interp, objc, objv);
	case MA_SETUNWEIGHTED: return gm_arc_SETUNWEIGH (g, interp, objc, objv);
	case MA_SETWEIGHT:     return gm_arc_SETWEIGHT  (g, interp, objc, objv);
	case MA_SOURCE:	       return gm_arc_SOURCE     (g, interp, objc, objv);
	case MA_TARGET:	       return gm_arc_TARGET     (g, interp, objc, objv);
	case MA_UNSET:	       return gm_arc_UNSET      (g, interp, objc, objv);
	case MA_UNSETWEIGHT:   return gm_arc_UNSETWEIGH (g, interp, objc, objv);
	case MA_WEIGHTS:       return gm_arc_WEIGHTS    (g, interp, objc, objv);
	}
	break;
    case M_ARCS:	return gm_ARCS	      (g, interp, objc, objv);
    case M_DESERIALIZE: return gm_DESERIALIZE (g, interp, objc, objv);
    case M_DESTROY:	return gm_DESTROY     (g, interp, objc, objv);
    case M_GET:		return gm_GET	      (g, interp, objc, objv);
    case M_GETALL:	return gm_GETALL      (g, interp, objc, objv);
    case M_KEYEXISTS:	return gm_KEYEXISTS   (g, interp, objc, objv);
    case M_KEYS:	return gm_KEYS	      (g, interp, objc, objv);
    case M_LAPPEND:	return gm_LAPPEND     (g, interp, objc, objv);
    case M_NODE:
	if (objc < 3) {
	    Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
	    return TCL_ERROR;
	} else if (Tcl_GetIndexFromObj (interp, objv [2], n_methods, "option",
					0, &m) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (m) {
	case MN_APPEND:	   return gm_node_APPEND    (g, interp, objc, objv);
	case MN_ATTR:	   return gm_node_ATTR	    (g, interp, objc, objv);
	case MN_DEGREE:	   return gm_node_DEGREE    (g, interp, objc, objv);
	case MN_DELETE:	   return gm_node_DELETE    (g, interp, objc, objv);
	case MN_EXISTS:	   return gm_node_EXISTS    (g, interp, objc, objv);
	case MN_GET:	   return gm_node_GET	    (g, interp, objc, objv);
	case MN_GETALL:	   return gm_node_GETALL    (g, interp, objc, objv);
	case MN_INSERT:	   return gm_node_INSERT    (g, interp, objc, objv);
	case MN_KEYEXISTS: return gm_node_KEYEXISTS (g, interp, objc, objv);
	case MN_KEYS:	   return gm_node_KEYS	    (g, interp, objc, objv);
	case MN_LAPPEND:   return gm_node_LAPPEND   (g, interp, objc, objv);
	case MN_OPPOSITE:  return gm_node_OPPOSITE  (g, interp, objc, objv);
	case MN_RENAME:	   return gm_node_RENAME    (g, interp, objc, objv);
	case MN_SET:	   return gm_node_SET	    (g, interp, objc, objv);
	case MN_UNSET:	   return gm_node_UNSET	    (g, interp, objc, objv);
	}
	break;
    case M_NODES:	return gm_NODES	      (g, interp, objc, objv);
    case M_SERIALIZE:	return gm_SERIALIZE   (g, interp, objc, objv);
    case M_SET:		return gm_SET	      (g, interp, objc, objv);
    case M_SWAP:	return gm_SWAP	      (g, interp, objc, objv);
    case M_UNSET:	return gm_UNSET	      (g, interp, objc, objv);
    case M_WALK:	return gm_WALK	      (g, interp, objc, objv);
    }
    /* Not coming to this place */
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

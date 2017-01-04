/* pt::rde::critcl - critcl - layer 3 definitions.
 *
 * -> Method functions.
 *    Implementations for all state methods.
 */

#include <m.h>    /* Our public API */
#include <pInt.h> /* State public and internal APIs */
#include <ot.h>   /* Tcl_Objype for interned strings. */
#include <util.h> /* Allocation utilities */
#include <string.h>

/* .................................................. */

int
param_AMARKED (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde amarked
     *         [0] [1]
     */

    long int mc, i;
    void**   mv;
    Tcl_Obj** ov;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_query_amark (p->p, &mc, &mv);

    ov = NALLOC (mc, Tcl_Obj*);

    for (i=0; i < mc; i++) {
	ov [i] = Tcl_NewIntObj ((long int) mv [i]);
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewListObj (mc, ov));

    ckfree ((char*) ov);

    return TCL_OK;
}

int
param_AST (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde ast
     *         [0] [1]
     */

    long int  ac;
    Tcl_Obj** av;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_query_ast (p->p, &ac, &av);

    Tcl_SetObjResult (interp, av [ac-1]);

    return TCL_OK;
}

int
param_ASTS (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde asts
     *         [0] [1]
     */

    long int  ac;
    Tcl_Obj** av;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_query_ast (p->p, &ac, &av);

    Tcl_SetObjResult (interp, Tcl_NewListObj (ac, av));

    return TCL_OK;
}

int
param_CHAN (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde chan
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewStringObj (rde_param_query_in (p->p),
					-1));

    return TCL_OK;
}

int
param_COMPLETE (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* See also pt_cparam_config_critcl.tcl, COMPLETE().
     * Syntax: rde complete
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	long int  ac;
	Tcl_Obj** av;

	rde_param_query_ast (p->p, &ac, &av);

	if (ac > 1) {
	    Tcl_Obj** lv = NALLOC (3+ac, Tcl_Obj*);

	    memcpy(lv + 3, av, ac * sizeof (Tcl_Obj*));
	    lv [0] = Tcl_NewObj ();
	    lv [1] = Tcl_NewIntObj (1 + rde_param_query_lstop (p->p));
	    lv [2] = Tcl_NewIntObj (rde_param_query_cl (p->p));

	    Tcl_SetObjResult (interp, Tcl_NewListObj (3, lv));
	    ckfree ((char*) lv);
	} else if (ac == 0) {
	    /*
	     * Match, but no AST. This is possible if the grammar consists of
	     * only the start expression.
	     */
	    Tcl_SetObjResult (interp, Tcl_NewStringObj ("",-1));
	} else {
	    Tcl_SetObjResult (interp, av [0]);
	}

	return TCL_OK;

    } else {
	Tcl_Obj* xv [1];
	const ERROR_STATE* er = rde_param_query_er (p->p);
	Tcl_Obj* res = rde_param_query_er_tcl (p->p, er);
	/* res = list (location, list(msg)) */

	/* Stick the exception type-tag before the existing elements */
	xv [0] = Tcl_NewStringObj ("pt::rde",-1);
	Tcl_ListObjReplace(interp, res, 0, 0, 1, xv);

	Tcl_SetErrorCode (interp, "PT", "RDE", "SYNTAX", NULL);
	Tcl_SetObjResult (interp, res);
	return TCL_ERROR;
    }
}

int
param_CURRENT (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde current
     *         [0] [1]
     */

    const char* ch;
    long int    len;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    ch = rde_param_query_cc (p->p, &len);
    Tcl_SetObjResult (interp, Tcl_NewStringObj (ch, len));

    return TCL_OK;
}

int
param_DATA (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde data DATA
     *         [0] [1]  [2]
     */

    char* buf;
    int len;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "data");
	return TCL_ERROR;
    }

    buf = Tcl_GetStringFromObj (objv [2], &len);

    rde_param_data (p->p, buf, len);

    return TCL_OK;
}

int
param_DESTROY (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde destroy
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_DeleteCommandFromToken(interp, p->c);
    return TCL_OK;
}

int
param_EMARKED (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde emarked
     *         [0] [1]
     */

    long int      ec, i;
    ERROR_STATE** ev;
    Tcl_Obj**     ov;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_query_es (p->p, &ec, &ev);

    ov = NALLOC (ec, Tcl_Obj*);

    for (i=0; i < ec; i++) {
	ov [i] = rde_param_query_er_tcl (p->p, ev [i]);
    }

    Tcl_SetObjResult (interp, Tcl_NewListObj (ec, ov));

    ckfree ((char*) ov);

    return TCL_OK;
}

int
param_ERROR (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde error
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, 
		      rde_param_query_er_tcl (p->p,
			      rde_param_query_er (p->p)));
    return TCL_OK;
}

int
param_LMARKED (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde lmarked
     *         [0] [1]
     */

    long int  lc, i;
    void**    lv;
    Tcl_Obj** ov;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_query_ls (p->p, &lc, &lv);

    ov = NALLOC (lc, Tcl_Obj*);

    for (i=0; i < lc; i++) {
	ov [i] = Tcl_NewIntObj ((long int) lv [i]);
    }

    Tcl_SetObjResult (interp, Tcl_NewListObj (lc, ov));

    ckfree ((char*) ov);
    return TCL_OK;
}

int
param_LOCATION (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde location
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (rde_param_query_cl (p->p)));

    return TCL_OK;
}

int
param_OK (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde ok
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp,
		      Tcl_NewIntObj (rde_param_query_st (p->p)));

    return TCL_OK;
}

int
param_RESET (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde reset ?CHAN?
     *         [0] [1]   [2]
     */

    int mode;
    Tcl_Channel chan;

    if ((objc != 3) && (objc != 2)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?chan?");
	return TCL_ERROR;
    }

    /*
     * Can't use TclGetChannelFromObj, nice as it would be. This fucntion is
     * not part of Tcl's public C API.
     */

    if (objc == 2) {
	chan = NULL;
    } else {
	chan = Tcl_GetChannel(interp,
			      Tcl_GetString (objv[2]),
			      &mode);

	if (!chan) {
	    return TCL_ERROR;
	}
    }

    rde_param_reset (p->p, chan);

    return TCL_OK;
}

int
param_SCACHED (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde scached
     *         [0] [1]
     */

    Tcl_HashTable* nc;
    Tcl_Obj* res;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    Tcl_HashTable* tablePtr;
    Tcl_Obj* kv [2];

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    nc  = rde_param_query_nc (p->p);
    res = Tcl_NewListObj (0, NULL);

    for(he = Tcl_FirstHashEntry(nc, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {

	Tcl_HashSearch hsc;
	Tcl_HashEntry* hec;
	long int loc = (long int) Tcl_GetHashKey (nc, he);

	kv [0]   = Tcl_NewIntObj (loc);
	tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (he);

	for(hec = Tcl_FirstHashEntry(tablePtr, &hsc);
	    hec != NULL;
	    hec = Tcl_NextHashEntry(&hsc)) {

	    long int    symid = (long int) Tcl_GetHashKey (tablePtr, hec);
	    const char* sym   = rde_param_query_string (p->p, symid);

	    kv [1] = Tcl_NewStringObj (sym,-1);

	    Tcl_ListObjAppendElement (interp, res,
				      Tcl_NewListObj (2, kv));
	}
    }

    Tcl_SetObjResult (interp, res);
    return TCL_OK;
}

int
param_SYMBOLS (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde symbols
     *         [0] [1]
     */

    Tcl_HashTable* nc;
    Tcl_Obj* res;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    Tcl_HashTable* tablePtr;
    Tcl_Obj* kv [2];
    Tcl_Obj* vv [4];

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    nc  = rde_param_query_nc (p->p);
    res = Tcl_NewListObj (0, NULL);

    for(he = Tcl_FirstHashEntry(nc, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {

	Tcl_HashSearch hsc;
	Tcl_HashEntry* hec;
	long int loc = (long int) Tcl_GetHashKey (nc, he);

	kv [0]   = Tcl_NewIntObj (loc);
	tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (he);

	for(hec = Tcl_FirstHashEntry(tablePtr, &hsc);
	    hec != NULL;
	    hec = Tcl_NextHashEntry(&hsc)) {

	    NC_STATE*   scs   = Tcl_GetHashValue (hec);
	    long int    symid = (long int) Tcl_GetHashKey (tablePtr, hec);
	    const char* sym   = rde_param_query_string (p->p, symid);

	    kv [1] = Tcl_NewStringObj (sym,-1);

	    vv [0] = Tcl_NewIntObj (scs->CL);
	    vv [1] = Tcl_NewIntObj (scs->ST);
	    vv [2] = rde_param_query_er_tcl (p->p, scs->ER);
	    vv [3] = (scs->SV ? scs->SV : Tcl_NewObj ());

	    Tcl_ListObjAppendElement (interp, res, Tcl_NewListObj (2, kv));
	    Tcl_ListObjAppendElement (interp, res, Tcl_NewListObj (4, vv));
	}
    }

    Tcl_SetObjResult (interp, res);

    return TCL_OK;
}

int
param_TOKENS (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde tokens ?FROM ?TO??
     *         [0] [1]    [2]   [3]
     */

    long int num, from, to;

    if ((objc < 2) || (objc > 4)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?from? ?to?");
	return TCL_ERROR;
    }

    num = rde_param_query_tc_size (p->p);

    if (objc == 2) {
	from = 0;
	to   = num - 1;
    } else if (objc == 3) {

	if (Tcl_GetLongFromObj (interp, objv [2], &from) != TCL_OK) {
	    return TCL_ERROR;
	}
	to = from;

    } else { /* objc == 4 */
	if (Tcl_GetLongFromObj (interp, objv [2], &from) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (Tcl_GetLongFromObj (interp, objv [3], &to) != TCL_OK) {
	    return TCL_ERROR;
	}
    }

    if (from < 0)  { from = 0; }
    if (to >= num) { to = num-1; }

    if (to < from) {
	Tcl_SetObjResult (interp, Tcl_NewObj ());
    } else {
	long int len;
	char* buf;

	rde_param_query_tc_get_s (p->p, from, to, &buf, &len);

	Tcl_SetObjResult (interp, Tcl_NewStringObj (buf,len));
    }

    return TCL_OK;
}

int
param_VALUE (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde value
     *         [0] [1]
     */

    Tcl_Obj* sv;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    sv = rde_param_query_sv (p->p);
    if (!sv) {
	sv = Tcl_NewObj ();
    }

    Tcl_SetObjResult (interp, sv);

    return TCL_OK;
}

/* .................................................. */

int
param_F_continue (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:fail_continue
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	return TCL_CONTINUE;
    }

    return TCL_OK;
}

int
param_F_return (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:fail_return
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	return TCL_RETURN;
    }

    return TCL_OK;
}

int
param_O_continue (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:ok_continue
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	return TCL_CONTINUE;
    }

    return TCL_OK;
}

int
param_O_return (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:ok_return
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	return TCL_RETURN;
    }

    return TCL_OK;
}

int
param_I_st_fail (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_status_fail
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_status_fail (p->p);

    return TCL_OK;
}

int
param_I_st_neg (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_status_negate
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_status_negate (p->p);

    return TCL_OK;
}

int
param_I_st_ok (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_status_ok
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_status_ok (p->p);

    return TCL_OK;
}

int
param_I_er_clear (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_error_clear
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_clear (p->p);

    return TCL_OK;
}

int
param_I_er_clear_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_error_clear
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_clear (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_I_er_nt (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_error_nonterminal SYMBOL
     *         [0] [1]                 [2]
     */

    long int sym;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    sym = rde_ot_intern1 (p, "n", objv [2]);
    rde_param_i_error_nonterminal (p->p, sym);

    return TCL_OK;
}

int
param_I_er_popmerge (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_error_pop_merge
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);

    return TCL_OK;
}

int
param_I_er_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_error_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_F_loc_pop_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:fail_loc_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
    }

    return TCL_OK;
}

int
param_I_loc_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_pop_discard (p->p);

    return TCL_OK;
}

int
param_O_loc_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_I_loc_pop_rewdis (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_rewind/discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
    } else {
	rde_param_i_loc_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_I_loc_pop_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_pop_rewind (p->p);

    return TCL_OK;
}

int
param_I_loc_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_rewind (p->p);

    return TCL_OK;
}

int
param_I_loc_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_loc_pop_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_push (p->p);

    return TCL_OK;
}

int
param_F_ast_pop_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i:fail_ast_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_rewind (p->p);
    }

    return TCL_OK;
}

int
param_I_ast_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_ast_pop_discard (p->p);

    return TCL_OK;
}

int
param_O_ast_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_I_ast_pop_disrew (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_discard/rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_discard (p->p);
    } else {
	rde_param_i_ast_pop_rewind (p->p);
    }

    return TCL_OK;
}

int
param_I_ast_pop_rewdis (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_rewind/discard
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_rewind (p->p);
    } else {
	rde_param_i_ast_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_I_ast_pop_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_ast_pop_rewind (p->p);

    return TCL_OK;
}

int
param_I_ast_rewind (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_pop_rewind
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_ast_rewind (p->p);

    return TCL_OK;
}

int
param_I_ast_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_ast_push (p->p);

    return TCL_OK;
}

int
param_O_ast_value_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_ast_value_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_value_push (p->p);
    }

    return TCL_OK;
}

int
param_I_symbol_restore (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_symbol_restore SYMBOL
     *         [0] [1]              [2]
     */

    long int sym;
    int found;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));
    found = rde_param_i_symbol_restore (p->p, sym);
    Tcl_SetObjResult (interp, Tcl_NewIntObj (found));

    return TCL_OK;
}

int
param_I_symbol_save (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_symbol_save SYMBOL
     *         [0] [1]           [2]
     */

    long int sym;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));
    rde_param_i_symbol_save (p->p, sym);

    return TCL_OK;
}

int
param_I_value_cleaf (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_value_clear/leaf SYMBOL
     *         [0] [1]                [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_value_clear (p->p);
    } else {
	long int sym;

	/*
	 * We cannot save the interned string id in the Tcl_Obj*, because this
	 * is already taken by the argument of param_I_er_nt aka
	 * i_error_nonterminal, due to literal sharing in procedure bodies.
	 */

	sym = param_intern (p, Tcl_GetString (objv [2]));
	rde_param_i_value_leaf (p->p, sym);
    }

    return TCL_OK;
}

int
param_I_value_clear (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_value_clear
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_value_clear (p->p);

    return TCL_OK;
}

int
param_I_value_creduce (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_value_clear/reduce SYMBOL
     *         [0] [1]                  [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    if (!rde_param_query_st (p->p)) {
	rde_param_i_value_clear (p->p);
    } else {
	long int sym;

	/*
	 * We cannot save the interned string id in the Tcl_Obj*, because this
	 * is already taken by the argument of param_I_er_nt aka
	 * i_error_nonterminal, due to literal sharing in procedure bodies.
	 */

	sym = param_intern (p, Tcl_GetString (objv [2]));
	rde_param_i_value_reduce (p->p, sym);
    }

    return TCL_OK;
}

int
param_I_input_next (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_input_next MSG
     *         [0] [1]          [2]
     */

    long int msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "msg");
	return TCL_ERROR;
    }

    /*
     * interning: msg as is. Already has PE operator in the message.
     */

    msg = rde_ot_intern0 (p, objv [2]);
    rde_param_i_input_next (p->p, msg);

    return TCL_OK;
}

int
param_I_test_alnum (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_alnum
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_alnum (p->p);

    return TCL_OK;
}

int
param_I_test_alpha (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_alpha
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_alpha (p->p);

    return TCL_OK;
}

int
param_I_test_ascii (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_ascii
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_ascii (p->p);

    return TCL_OK;
}

int
param_I_test_char (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    char* ch;

    /* Syntax: rde i_test_char CHAR
     *         [0] [1]         [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "tok");
	return TCL_ERROR;
    }

    /*
     * interning: t + space + char
     */

    ch  = Tcl_GetString (objv [2]);
    msg = rde_ot_intern1 (p, "t", objv [2]);

    rde_param_i_test_char (p->p, ch, msg);
    return TCL_OK;
}

int
param_I_test_control (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_control
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_control (p->p);

    return TCL_OK;
}

int
param_I_test_ddigit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_ddigit
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_ddigit (p->p);

    return TCL_OK;
}

int
param_I_test_digit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_digit
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_digit (p->p);

    return TCL_OK;
}

int
param_I_test_graph (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_graph
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_graph (p->p);

    return TCL_OK;
}

int
param_I_test_lower (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_lower
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_lower (p->p);

    return TCL_OK;
}

int
param_I_test_print (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_print
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_print (p->p);

    return TCL_OK;
}

int
param_I_test_punct (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_punct
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_punct (p->p);

    return TCL_OK;
}

int
param_I_test_range (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    char* chs;
    char* che;

    /* Syntax: rde i_test_range START END
     *         [0] [1]          [2]   [3]
     */

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "toks toke");
	return TCL_ERROR;
    }

    /*
     * interning: .. + space + char + space + char
     */

    chs = Tcl_GetString (objv [2]);
    che = Tcl_GetString (objv [3]);
    msg = rde_ot_intern2 (p, "..", objv [2], objv[3]);

    rde_param_i_test_range (p->p, chs, che, msg);

    return TCL_OK;
}

int
param_I_test_space (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_space
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_space (p->p);

    return TCL_OK;
}

int
param_I_test_upper (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_upper
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_upper (p->p);

    return TCL_OK;
}

int
param_I_test_wordchar (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_wordchar
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_wordchar (p->p);

    return TCL_OK;
}

int
param_I_test_xdigit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde i_test_xdigit
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_test_xdigit (p->p);

    return TCL_OK;
}

int
param_SI_void_state_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_state_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_push (p->p);
    rde_param_i_error_clear (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_value_state_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_state_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_ast_push (p->p);
    rde_param_i_loc_push (p->p);
    rde_param_i_error_clear (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_void_state_merge (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_state_merge
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
    } else {
	rde_param_i_loc_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_SI_value_state_merge (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_state_merge
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_rewind (p->p);
	rde_param_i_loc_pop_rewind (p->p);
    } else {
	rde_param_i_ast_pop_discard (p->p);
	rde_param_i_loc_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_SI_voidvoid_branch (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:voidvoid_branch
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_discard (p->p);
	return TCL_RETURN;
    }
    rde_param_i_loc_rewind (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_voidvalue_branch (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:voidvalue_branch
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_discard (p->p);
	return TCL_RETURN;
    }
    rde_param_i_ast_push (p->p);
    rde_param_i_loc_rewind (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_valuevoid_branch (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:valuevoid_branch
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_discard (p->p);
	rde_param_i_loc_pop_discard (p->p);
	return TCL_RETURN;
    }
    rde_param_i_ast_pop_rewind (p->p);
    rde_param_i_loc_rewind (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_valuevalue_branch (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:valuevalue:branch
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_discard (p->p);
	rde_param_i_loc_pop_discard (p->p);
	return TCL_RETURN;
    }
    rde_param_i_ast_rewind (p->p);
    rde_param_i_loc_rewind (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_voidvoid_part (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:voidvoid_part
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
	return TCL_RETURN;
    }
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_voidvalue_part (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:voidvalue_part
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
	return TCL_RETURN;
    }
    rde_param_i_ast_push (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_valuevalue_part (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:valuevalue_part
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_rewind (p->p);
	rde_param_i_loc_pop_rewind (p->p);
	return TCL_RETURN;
    }
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_next_char (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    char* ch;

    /* Syntax: rde i_next_char CHAR
     *         [0] [1]         [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "tok");
	return TCL_ERROR;
    }

    /*
     * interning: t + space + char
     */

    ch  = Tcl_GetString (objv [2]);
    msg = rde_ot_intern1 (p, "t", objv [2]);

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_char (p->p, ch, msg);
    }
    return TCL_OK;
}

int
param_SI_next_range (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    char* chs;
    char* che;

    /* Syntax: rde i_next_range START END
     *         [0] [1]          [2]   [3]
     */

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "toks toke");
	return TCL_ERROR;
    }

    /*
     * interning: .. + space + char + space + char
     */

    chs = Tcl_GetString (objv [2]);
    che = Tcl_GetString (objv [3]);
    msg = rde_ot_intern2 (p, "..", objv [2], objv[3]);

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_range (p->p, chs, che, msg);
    }
    return TCL_OK;
}

int
param_SI_next_alnum (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_alnum
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "alnum");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_alnum (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_alpha (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_alpha
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "alpha");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_alpha (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_ascii (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_ascii
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "ascii");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_ascii (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_control (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_control
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "control");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_control (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_ddigit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_ddigit
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "ddigit");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_ddigit (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_digit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_digit
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "digit");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_digit (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_graph (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_graph
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "graph");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_graph (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_lower (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_lower
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "lower");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_lower (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_print (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_print
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "print");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_print (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_punct (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_punct
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "punct");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_punct (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_space (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_space
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "space");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_space (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_upper (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_upper
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "upper");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_upper (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_wordchar (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_wordchar
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "wordchar");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_wordchar (p->p);
    }
    return TCL_OK;
}

int
param_SI_next_xdigit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:next_xdigit
     *         [0] [1]
     */

    long int msg;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    msg = param_intern (p, "xdigit");

    rde_param_i_input_next (p->p, msg);
    if (rde_param_query_st (p->p)) {
	rde_param_i_test_xdigit (p->p);
    }
    return TCL_OK;
}

int
param_SI_void2_state_push (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void2_state_push
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_push (p->p);
    rde_param_i_error_push (p->p);

    return TCL_OK;
}

int
param_SI_void_state_merge_ok (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_state_merge_ok
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (!rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_rewind (p->p);
	rde_param_i_status_ok (p->p);
    } else {
	rde_param_i_loc_pop_discard (p->p);
    }

    return TCL_OK;
}

int
param_SI_value_notahead_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_notahead_start
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_push (p->p);
    rde_param_i_ast_push (p->p);

    return TCL_OK;
}

int
param_SI_void_notahead_exit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_notahead_exit
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_pop_rewind (p->p);
    rde_param_i_status_negate  (p->p);

    return TCL_OK;
}

int
param_SI_value_notahead_exit (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_notahead_exit
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_loc_pop_rewind (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_pop_rewind (p->p);
    } else {
	rde_param_i_ast_pop_discard (p->p);
    }
    rde_param_i_status_negate  (p->p);

    return TCL_OK;
}

int
param_SI_kleene_abort (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:kleene_abort
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    if (rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_discard (p->p);
	return TCL_OK;
    } else {
	rde_param_i_loc_pop_rewind (p->p);
	return TCL_RETURN;
    }
}

int
param_SI_kleene_close (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:kleene_close
     *         [0] [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    rde_param_i_error_pop_merge (p->p);
    if (rde_param_query_st (p->p)) {
	rde_param_i_loc_pop_discard (p->p);
	return TCL_OK;
    } else {
	rde_param_i_loc_pop_rewind (p->p);
	rde_param_i_status_ok (p->p);
	return TCL_RETURN;
    }
}

int
param_SI_value_symbol_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_symbol_start SYMBOL
     *         [0] [1]                  [2]
     */

    long int sym;
    int found;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    found = rde_param_i_symbol_restore (p->p, sym);
    if (found) {
	if (rde_param_query_st (p->p)) {
	    rde_param_i_ast_value_push (p->p);
	}
	return TCL_RETURN;
    }

    rde_param_i_loc_push (p->p);
    rde_param_i_ast_push (p->p);
    return TCL_OK;
}

int
param_SI_value_void_symbol_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_void_symbol_start SYMBOL
     *         [0] [1]                  [2]
     */

    long int sym;
    int found;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    found = rde_param_i_symbol_restore (p->p, sym);
    if (found) {
	return TCL_RETURN;
    }

    rde_param_i_loc_push (p->p);
    rde_param_i_ast_push (p->p);
    return TCL_OK;
}

int
param_SI_void_symbol_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_symbol_start SYMBOL
     *         [0] [1]                  [2]
     */

    long int sym;
    int found;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    found = rde_param_i_symbol_restore (p->p, sym);
    if (found) {
	if (rde_param_query_st (p->p)) {
	    rde_param_i_ast_value_push (p->p);
	}
	return TCL_RETURN;
    }

    rde_param_i_loc_push (p->p);
    return TCL_OK;
}

int
param_SI_void_void_symbol_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_void_symbol_start SYMBOL
     *         [0] [1]                  [2]
     */

    long int sym;
    int found;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    found = rde_param_i_symbol_restore (p->p, sym);
    if (found) {
	return TCL_RETURN;
    }

    rde_param_i_loc_push (p->p);
    return TCL_OK;
}

int
param_SI_reduce_symbol_end (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:reduce_symbol_end SYMBOL
     *         [0] [1]           [2]
     */

    long int sym, msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    if (!rde_param_query_st (p->p)) {
	rde_param_i_value_clear (p->p);
    } else {
	rde_param_i_value_reduce (p->p, sym);
    }

    rde_param_i_symbol_save (p->p, sym);

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    msg = rde_ot_intern1 (p, "n", objv [2]);

    rde_param_i_error_nonterminal (p->p, msg);
    rde_param_i_ast_pop_rewind (p->p);
    rde_param_i_loc_pop_discard (p->p);

    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_value_push (p->p);
    }

    return TCL_OK;
}

int
param_SI_void_leaf_symbol_end (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_leaf_symbol_end SYMBOL
     *         [0] [1]           [2]
     */

    long int sym, msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    if (!rde_param_query_st (p->p)) {
	rde_param_i_value_clear (p->p);
    } else {
	rde_param_i_value_leaf (p->p, sym);
    }

    rde_param_i_symbol_save (p->p, sym);

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    msg = rde_ot_intern1 (p, "n", objv [2]);

    rde_param_i_error_nonterminal (p->p, msg);
    rde_param_i_loc_pop_discard (p->p);

    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_value_push (p->p);
    }

    return TCL_OK;
}

int
param_SI_value_leaf_symbol_end (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_leaf_symbol_end SYMBOL
     *         [0] [1]           [2]
     */

    long int sym, msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    if (!rde_param_query_st (p->p)) {
	rde_param_i_value_clear (p->p);
    } else {
	rde_param_i_value_leaf (p->p, sym);
    }

    rde_param_i_symbol_save (p->p, sym);

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    msg = rde_ot_intern1 (p, "n", objv [2]);

    rde_param_i_error_nonterminal (p->p, msg);
    rde_param_i_ast_pop_rewind (p->p);
    rde_param_i_loc_pop_discard (p->p);

    if (rde_param_query_st (p->p)) {
	rde_param_i_ast_value_push (p->p);
    }

    return TCL_OK;
}

int
param_SI_value_clear_symbol_end (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:value_clear_symbol_end SYMBOL
     *         [0] [1]           [2]
     */

    long int sym, msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    rde_param_i_value_clear (p->p);
    rde_param_i_symbol_save (p->p, sym);

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    msg = rde_ot_intern1 (p, "n", objv [2]);

    rde_param_i_error_nonterminal (p->p, msg);
    rde_param_i_ast_pop_rewind (p->p);
    rde_param_i_loc_pop_discard (p->p);

    return TCL_OK;
}

int
param_SI_void_clear_symbol_end (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: rde si:void_clear_symbol_end SYMBOL
     *         [0] [1]           [2]
     */

    long int sym, msg;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "symbol");
	return TCL_ERROR;
    }

    /*
     * We cannot save the interned string id in the Tcl_Obj*, because this is
     * already taken by the argument of param_I_er_nt aka i_error_nonterminal,
     * due to literal sharing in procedure bodies.
     */

    sym = param_intern (p, Tcl_GetString (objv [2]));

    rde_param_i_value_clear (p->p);
    rde_param_i_symbol_save (p->p, sym);

    /*
     * interning: n + space + symbol
     *
     * The obj literal here is very likely shared with the arguments of
     * i_symbol_save/restore, and i_value_leaf/reduce, and derivatives. This
     * here is the only point between these where we save the string id in the
     * Tcl_Obj*.
     */

    msg = rde_ot_intern1 (p, "n", objv [2]);

    rde_param_i_error_nonterminal (p->p, msg);
    rde_param_i_loc_pop_discard (p->p);

    return TCL_OK;
}

int
param_SI_next_str (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    int len, i;
    char* str;

    /* Syntax: rde i_next_char CHAR
     *         [0] [1]         [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "tok");
	return TCL_ERROR;
    }

    /*
     * interning: str + space + char
     */

    str = Tcl_GetStringFromObj (objv [2], &len);
    msg = rde_ot_intern1 (p, "str", objv [2]);

    rde_param_i_next_str (p->p, str, msg);
    return TCL_OK;
}

int
param_SI_next_class (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    long int msg;
    int len, i;
    char* class;

    /* Syntax: rde i_next_char CHAR
     *         [0] [1]         [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "tok");
	return TCL_ERROR;
    }

    /*
     * interning: cl + space + char
     */

    class = Tcl_GetStringFromObj (objv [2], &len);
    msg   = rde_ot_intern1 (p, "cl", objv [2]);

    rde_param_i_next_class (p->p, class, msg);
    return TCL_OK;
}


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

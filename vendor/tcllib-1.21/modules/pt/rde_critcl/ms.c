/* pt::rde::critcl - critcl - layer 2 definitions
 *
 * -> Support for the stack methods in layer 3.
 */

#include <ms.h>   /* Our public API */
#include <m.h>    /* Method declarations */
#include <util.h> /* Trace utilities */
#ifdef RDE_TRACE
#include <pInt.h> /* To have access to icount */
#endif
/* .................................................. */
/*
 *---------------------------------------------------------------------------
 *
 * paramms_objcmd --
 *
 *	Implementation of stack objects, the main dispatcher function.
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
paramms_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    RDE_STATE p = (RDE_STATE) cd;
    int m, res = TCL_ERROR;

    static CONST char* methods [] = {
	"amarked",	"ast",		"asts",		"chan",
	"complete",	"current",	"data",		"destroy",	"emarked",
	"error",	"lmarked",	"location",	"ok",
       	"reset",	"scached",	"symbols",	"tokens",
	"value",	"i:fail_continue",	"i:fail_return",	"i:ok_continue",
	"i:ok_return",	"i_status_fail",	"i_status_negate",	"i_status_ok",
	"i_error_clear","i_error_nonterminal",	"i_error_pop_merge",	"i_error_push",
	"i:fail_loc_pop_rewind",	"i_loc_pop_discard",
	"i_loc_pop_rewind/discard",	"i_loc_pop_rewind",	"i_loc_push",
	"i:fail_ast_pop_rewind",	"i_ast_pop_discard",	"i_ast_pop_discard/rewind",
	"i_ast_pop_rewind/discard",	"i_ast_pop_rewind",	"i_ast_push",
	"i:ok_ast_value_push",	"i_symbol_restore",	"i_symbol_save",
	"i_value_clear/leaf",	"i_value_clear",	"i_value_clear/reduce",
	"i_input_next",	"i_test_alnum",	"i_test_alpha",	"i_test_ascii",	"i_test_char",	"i_test_control",
	"i_test_ddigit","i_test_digit",	"i_test_graph",	"i_test_lower",	"i_test_print",
	"i_test_punct",	"i_test_range",	"i_test_space",	"i_test_upper",	"i_test_wordchar",
	"i_test_xdigit",
	"i:ok_ast_pop_discard",	"i_ast_rewind",
	"i:ok_loc_pop_discard",	"i_loc_rewind",
	"i_error_clear_push",
	"si:void_state_push",
	"si:value_state_push",
	"si:void_state_merge",
	"si:value_state_merge",
	"si:voidvoid_branch",
	"si:voidvalue_branch",
	"si:valuevoid_branch",
	"si:valuevalue_branch",
	"si:voidvoid_part",
	"si:voidvalue_part",
	"si:valuevalue_part",
	"si:next_char",
	"si:next_range",
	"si:next_alnum",	"si:next_alpha",	"si:next_ascii",	"si:next_control",
	"si:next_ddigit","si:next_digit",	"si:next_graph",	"si:next_lower",	"si:next_print",
	"si:next_punct",	"si:next_space",	"si:next_upper",	"si:next_wordchar",
	"si:next_xdigit",

	"si:void2_state_push",
	"si:void_state_merge_ok",
	"si:value_notahead_start",
	"si:void_notahead_exit",
	"si:value_notahead_exit",
	"si:kleene_abort",
	"si:kleene_close",

	"si:value_symbol_start",
	"si:value_void_symbol_start",
	"si:void_symbol_start",
	"si:void_void_symbol_start",
	"si:reduce_symbol_end",
	"si:void_leaf_symbol_end",
	"si:value_leaf_symbol_end",
	"si:value_clear_symbol_end",
	"si:void_clear_symbol_end",

	"si:next_str",
	"si:next_class",
	NULL
    };
    enum methods {
	M_AMARKED,	M_AST,	M_ASTS,	M_CHAN,	M_COMPLETE,	M_CURRENT,
	M_DATA,	M_DESTROY,	M_EMARKED,	M_ERROR,       	M_LMARKED,	M_LOCATION,	M_OK,
       	M_RESET,	M_SCACHED,	M_SYMBOLS,	M_TOKENS,
	M_VALUE,	M_F_continue,	M_F_return,	M_O_continue,	M_O_return,
	M_I_st_fail,	M_I_st_neg,	M_I_st_ok,	M_I_er_clear,	M_I_er_nt,
	M_I_er_popmerge,	M_I_er_push,	M_F_loc_pop_rewind,	M_I_loc_pop_discard,
	M_I_loc_pop_rewdis,	M_I_loc_pop_rewind,	M_I_loc_push,	M_F_ast_pop_rewind,
	M_I_ast_pop_discard,	M_I_ast_pop_disrew,	M_I_ast_pop_rewdis,
	M_I_ast_pop_rewind,	M_I_ast_push,	M_O_ast_value_push,	M_I_symbol_restore,
	M_I_symbol_save,	M_I_value_cleaf,	M_I_value_clear,	M_I_value_creduce,
	M_I_input_next,	M_I_test_alnum,	M_I_test_alpha,	M_I_test_ascii,	M_I_test_char,	M_I_test_control,
	M_I_test_ddigit,	M_I_test_digit,	M_I_test_graph,	M_I_test_lower,	M_I_test_print,
	M_I_test_punct,	M_I_test_range,	M_I_test_space,	M_I_test_upper,	M_I_test_wordchar,
	M_I_test_xdigit,

	M_O_ast_pop_discard,
	M_I_ast_rewind,
	M_O_loc_pop_discard,
	M_I_loc_rewind,
	M_I_er_clear_push,

	M_SI_void_state_push,
	M_SI_value_state_push,
	M_SI_void_state_merge,
	M_SI_value_state_merge,
	M_SI_voidvoid_branch,
	M_SI_voidvalue_branch,
	M_SI_valuevoid_branch,
	M_SI_valuevalue_branch,
	M_SI_voidvoid_part,
	M_SI_voidvalue_part,
	M_SI_valuevalue_part,

	M_SI_next_char,
	M_SI_next_range,
	M_SI_next_alnum,
	M_SI_next_alpha,
	M_SI_next_ascii,
	M_SI_next_control,
	M_SI_next_ddigit,
	M_SI_next_digit,
	M_SI_next_graph,
	M_SI_next_lower,
	M_SI_next_print,
	M_SI_next_punct,
	M_SI_next_space,
	M_SI_next_upper,
	M_SI_next_wordchar,
	M_SI_next_xdigit,

	M_SI_void2_state_push,
	M_SI_void_state_merge_ok,
	M_SI_value_notahead_start,
	M_SI_void_notahead_exit,
	M_SI_value_notahead_exit,
	M_SI_kleene_abort,
	M_SI_kleene_close,

	M_SI_value_symbol_start,
	M_SI_value_void_symbol_start,
	M_SI_void_symbol_start,
	M_SI_void_void_symbol_start,
	M_SI_reduce_symbol_end,
	M_SI_void_leaf_symbol_end,
	M_SI_value_leaf_symbol_end,
	M_SI_value_clear_symbol_end,
	M_SI_void_clear_symbol_end,

	M_SI_next_str,
	M_SI_next_class
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

    TRACE0 (("%8d RDE %s", ++p->icount, Tcl_GetString(objv [1])));
    ENTER (Tcl_GetString(objv [1]));

    switch (m) {
    case M_AMARKED:             res = param_AMARKED           (p, interp, objc, objv); break;
    case M_AST:                 res = param_AST               (p, interp, objc, objv); break;
    case M_ASTS:                res = param_ASTS              (p, interp, objc, objv); break;
    case M_CHAN:                res = param_CHAN              (p, interp, objc, objv); break;
    case M_COMPLETE:            res = param_COMPLETE          (p, interp, objc, objv); break;
    case M_CURRENT:             res = param_CURRENT           (p, interp, objc, objv); break;
    case M_DATA:                res = param_DATA              (p, interp, objc, objv); break;
    case M_DESTROY:             res = param_DESTROY           (p, interp, objc, objv); break;
    case M_EMARKED:             res = param_EMARKED           (p, interp, objc, objv); break;
    case M_ERROR:               res = param_ERROR             (p, interp, objc, objv); break;
    case M_LMARKED:             res = param_LMARKED           (p, interp, objc, objv); break;
    case M_LOCATION:            res = param_LOCATION          (p, interp, objc, objv); break;
    case M_OK:                  res = param_OK                (p, interp, objc, objv); break;
    case M_RESET:               res = param_RESET             (p, interp, objc, objv); break;
    case M_SCACHED:             res = param_SCACHED           (p, interp, objc, objv); break;
    case M_SYMBOLS:             res = param_SYMBOLS           (p, interp, objc, objv); break;
    case M_TOKENS:              res = param_TOKENS            (p, interp, objc, objv); break;
    case M_VALUE:               res = param_VALUE             (p, interp, objc, objv); break;
    case M_F_continue:          res = param_F_continue        (p, interp, objc, objv); break;
    case M_F_return:            res = param_F_return          (p, interp, objc, objv); break;
    case M_O_continue:          res = param_O_continue        (p, interp, objc, objv); break;
    case M_O_return:            res = param_O_return          (p, interp, objc, objv); break;
    case M_I_st_fail:           res = param_I_st_fail         (p, interp, objc, objv); break;
    case M_I_st_neg:            res = param_I_st_neg          (p, interp, objc, objv); break;
    case M_I_st_ok:             res = param_I_st_ok           (p, interp, objc, objv); break;
    case M_I_er_clear:          res = param_I_er_clear        (p, interp, objc, objv); break;
    case M_I_er_clear_push:     res = param_I_er_clear_push   (p, interp, objc, objv); break;
    case M_I_er_nt:             res = param_I_er_nt           (p, interp, objc, objv); break;
    case M_I_er_popmerge:       res = param_I_er_popmerge     (p, interp, objc, objv); break;
    case M_I_er_push:           res = param_I_er_push         (p, interp, objc, objv); break;
    case M_F_loc_pop_rewind:    res = param_F_loc_pop_rewind  (p, interp, objc, objv); break;
    case M_I_loc_pop_discard:   res = param_I_loc_pop_discard (p, interp, objc, objv); break;
    case M_I_loc_pop_rewdis:    res = param_I_loc_pop_rewdis  (p, interp, objc, objv); break;
    case M_I_loc_pop_rewind:    res = param_I_loc_pop_rewind  (p, interp, objc, objv); break;
    case M_I_loc_push:          res = param_I_loc_push        (p, interp, objc, objv); break;
    case M_I_loc_rewind:        res = param_I_loc_rewind      (p, interp, objc, objv); break;
    case M_O_loc_pop_discard:   res = param_O_loc_pop_discard (p, interp, objc, objv); break;
    case M_F_ast_pop_rewind:    res = param_F_ast_pop_rewind  (p, interp, objc, objv); break;
    case M_I_ast_pop_discard:   res = param_I_ast_pop_discard (p, interp, objc, objv); break;
    case M_I_ast_pop_disrew:    res = param_I_ast_pop_disrew  (p, interp, objc, objv); break;
    case M_I_ast_pop_rewdis:    res = param_I_ast_pop_rewdis  (p, interp, objc, objv); break;
    case M_I_ast_pop_rewind:    res = param_I_ast_pop_rewind  (p, interp, objc, objv); break;
    case M_I_ast_push:          res = param_I_ast_push        (p, interp, objc, objv); break;
    case M_I_ast_rewind:        res = param_I_ast_rewind      (p, interp, objc, objv); break;
    case M_O_ast_pop_discard:   res = param_O_ast_pop_discard (p, interp, objc, objv); break;
    case M_O_ast_value_push:    res = param_O_ast_value_push  (p, interp, objc, objv); break;
    case M_I_symbol_restore:    res = param_I_symbol_restore  (p, interp, objc, objv); break;
    case M_I_symbol_save:       res = param_I_symbol_save     (p, interp, objc, objv); break;
    case M_I_value_cleaf:       res = param_I_value_cleaf     (p, interp, objc, objv); break;
    case M_I_value_clear:       res = param_I_value_clear     (p, interp, objc, objv); break;
    case M_I_value_creduce:     res = param_I_value_creduce   (p, interp, objc, objv); break;
    case M_I_input_next:        res = param_I_input_next      (p, interp, objc, objv); break;
    case M_I_test_alnum:        res = param_I_test_alnum      (p, interp, objc, objv); break;
    case M_I_test_alpha:        res = param_I_test_alpha      (p, interp, objc, objv); break;
    case M_I_test_ascii:        res = param_I_test_ascii      (p, interp, objc, objv); break;
    case M_I_test_char:         res = param_I_test_char       (p, interp, objc, objv); break;
    case M_I_test_control:      res = param_I_test_control    (p, interp, objc, objv); break;
    case M_I_test_ddigit:       res = param_I_test_ddigit     (p, interp, objc, objv); break;
    case M_I_test_digit:        res = param_I_test_digit      (p, interp, objc, objv); break;
    case M_I_test_graph:        res = param_I_test_graph      (p, interp, objc, objv); break;
    case M_I_test_lower:        res = param_I_test_lower      (p, interp, objc, objv); break;
    case M_I_test_print:        res = param_I_test_print      (p, interp, objc, objv); break;
    case M_I_test_punct:        res = param_I_test_punct      (p, interp, objc, objv); break;
    case M_I_test_range:        res = param_I_test_range      (p, interp, objc, objv); break;
    case M_I_test_space:        res = param_I_test_space      (p, interp, objc, objv); break;
    case M_I_test_upper:        res = param_I_test_upper      (p, interp, objc, objv); break;
    case M_I_test_wordchar:     res = param_I_test_wordchar   (p, interp, objc, objv); break;
    case M_I_test_xdigit:       res = param_I_test_xdigit     (p, interp, objc, objv); break;

    case M_SI_void_state_push:         res = param_SI_void_state_push   (p, interp, objc, objv); break;
    case M_SI_value_state_push:        res = param_SI_value_state_push  (p, interp, objc, objv); break;
    case M_SI_void_state_merge:        res = param_SI_void_state_merge  (p, interp, objc, objv); break;
    case M_SI_value_state_merge:       res = param_SI_value_state_merge (p, interp, objc, objv); break;
    case M_SI_voidvoid_branch:         res = param_SI_voidvoid_branch   (p, interp, objc, objv); break;
    case M_SI_voidvalue_branch:        res = param_SI_voidvalue_branch  (p, interp, objc, objv); break;
    case M_SI_valuevoid_branch:        res = param_SI_valuevoid_branch  (p, interp, objc, objv); break;
    case M_SI_valuevalue_branch:       res = param_SI_valuevalue_branch (p, interp, objc, objv); break;
    case M_SI_voidvoid_part:           res = param_SI_voidvoid_part     (p, interp, objc, objv); break;
    case M_SI_voidvalue_part:          res = param_SI_voidvalue_part    (p, interp, objc, objv); break;
    case M_SI_valuevalue_part:         res = param_SI_valuevalue_part   (p, interp, objc, objv); break;

    case M_SI_next_char:               res = param_SI_next_char    (p, interp, objc, objv); break;
    case M_SI_next_range:              res = param_SI_next_range   (p, interp, objc, objv); break;
    case M_SI_next_alnum:              res = param_SI_next_alnum   (p, interp, objc, objv); break;
    case M_SI_next_alpha:              res = param_SI_next_alpha   (p, interp, objc, objv); break;
    case M_SI_next_ascii:              res = param_SI_next_ascii   (p, interp, objc, objv); break;
    case M_SI_next_control:            res = param_SI_next_control (p, interp, objc, objv); break;
    case M_SI_next_ddigit:             res = param_SI_next_ddigit  (p, interp, objc, objv); break;
    case M_SI_next_digit:              res = param_SI_next_digit   (p, interp, objc, objv); break;
    case M_SI_next_graph:              res = param_SI_next_graph   (p, interp, objc, objv); break;
    case M_SI_next_lower:              res = param_SI_next_lower   (p, interp, objc, objv); break;
    case M_SI_next_print:              res = param_SI_next_print   (p, interp, objc, objv); break;
    case M_SI_next_punct:              res = param_SI_next_punct   (p, interp, objc, objv); break;
    case M_SI_next_space:              res = param_SI_next_space   (p, interp, objc, objv); break;
    case M_SI_next_upper:              res = param_SI_next_upper   (p, interp, objc, objv); break;
    case M_SI_next_wordchar:           res = param_SI_next_wordchar(p, interp, objc, objv); break;
    case M_SI_next_xdigit:             res = param_SI_next_xdigit  (p, interp, objc, objv); break;
			        
    case M_SI_void2_state_push:        res = param_SI_void2_state_push     (p, interp, objc, objv); break;
    case M_SI_void_state_merge_ok:     res = param_SI_void_state_merge_ok  (p, interp, objc, objv); break;
    case M_SI_value_notahead_start:    res = param_SI_value_notahead_start (p, interp, objc, objv); break;
    case M_SI_void_notahead_exit:      res = param_SI_void_notahead_exit   (p, interp, objc, objv); break;
    case M_SI_value_notahead_exit:     res = param_SI_value_notahead_exit  (p, interp, objc, objv); break;
    case M_SI_kleene_abort:            res = param_SI_kleene_abort         (p, interp, objc, objv); break;
    case M_SI_kleene_close:            res = param_SI_kleene_close         (p, interp, objc, objv); break;

    case M_SI_value_symbol_start:      res = param_SI_value_symbol_start      (p, interp, objc, objv); break;
    case M_SI_value_void_symbol_start: res = param_SI_value_void_symbol_start (p, interp, objc, objv); break;
    case M_SI_void_symbol_start:       res = param_SI_void_symbol_start       (p, interp, objc, objv); break;
    case M_SI_void_void_symbol_start:  res = param_SI_void_void_symbol_start  (p, interp, objc, objv); break;
    case M_SI_reduce_symbol_end:       res = param_SI_reduce_symbol_end       (p, interp, objc, objv); break;
    case M_SI_void_leaf_symbol_end:    res = param_SI_void_leaf_symbol_end    (p, interp, objc, objv); break;
    case M_SI_value_leaf_symbol_end:   res = param_SI_value_leaf_symbol_end   (p, interp, objc, objv); break;
    case M_SI_value_clear_symbol_end:  res = param_SI_value_clear_symbol_end  (p, interp, objc, objv); break;
    case M_SI_void_clear_symbol_end:   res = param_SI_void_clear_symbol_end   (p, interp, objc, objv); break;

    case M_SI_next_str:           res = param_SI_next_str   (p, interp, objc, objv); break;
    case M_SI_next_class:         res = param_SI_next_class (p, interp, objc, objv); break;
    default:
        /* Not coming to this place */
        ASSERT (0,"Reached unreachable location");
    }

    RETURN ("%d",res);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

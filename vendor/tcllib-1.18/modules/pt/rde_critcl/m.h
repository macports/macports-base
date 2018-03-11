/* pt::rde::critcl - critcl - layer 3 declarations
 * Method functions.
 */

#ifndef _M_H
#define _M_H 1

#include "tcl.h"
#include <p.h>

int param_AMARKED           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_AST               (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_ASTS              (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_CHAN              (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_COLUMN            (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_COMPLETE          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_CURRENT           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_DATA              (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_DESTROY           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_EMARKED           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_ERROR             (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_LINE              (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_LMARKED           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_LOCATION          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_OK                (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_POSITION          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_RESET             (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SCACHED           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SYMBOLS           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_TOKENS            (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_VALUE             (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_F_continue        (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_F_return          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_O_continue        (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_O_return          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_st_fail         (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_st_neg          (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_st_ok           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_er_clear        (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_er_clear_push   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_er_nt           (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_er_popmerge     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_er_push         (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_F_loc_pop_rewind  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_loc_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_loc_pop_rewdis  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_loc_pop_rewind  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_loc_push        (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_loc_rewind      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_O_loc_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_F_ast_pop_rewind  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_pop_disrew  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_pop_rewdis  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_pop_rewind  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_push        (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_ast_rewind      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_O_ast_pop_discard (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_O_ast_value_push  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_symbol_restore  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_symbol_save     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_value_cleaf     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_value_clear     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_value_creduce   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_input_next      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_I_test_alnum      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_alpha      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_ascii      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_char       (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_control    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_ddigit     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_digit      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_graph      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_lower      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_print      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_punct      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_range      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_space      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_upper      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_wordchar   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_I_test_xdigit     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_SI_void_state_push   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_state_push  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_state_merge  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_state_merge (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_voidvoid_branch   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_voidvalue_branch  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_valuevoid_branch  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_valuevalue_branch (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_voidvoid_part     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_voidvalue_part    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_valuevalue_part   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_SI_next_char     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_range    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_alnum    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_alpha    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_ascii    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_control  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_ddigit   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_digit    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_graph    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_lower    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_print    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_punct    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_space    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_upper    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_wordchar (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_xdigit   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_SI_void2_state_push     (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_state_merge_ok  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_notahead_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_notahead_exit   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_notahead_exit  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_kleene_abort         (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_kleene_close         (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_SI_value_symbol_start      (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_void_symbol_start (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_symbol_start       (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_void_symbol_start  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_reduce_symbol_end       (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_leaf_symbol_end    (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_leaf_symbol_end   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_value_clear_symbol_end  (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_void_clear_symbol_end   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

int param_SI_next_str   (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);
int param_SI_next_class (RDE_STATE p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv);

#endif /* _M_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

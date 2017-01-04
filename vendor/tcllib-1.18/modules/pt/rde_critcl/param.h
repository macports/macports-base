/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - PARAM architectural state.
 */

#ifndef _RDE_DS_PARAM_H
#define _RDE_DS_PARAM_H 1

#include "tcl.h"
#include <util.h>  /* Scoping */
#include <stack.h> /* Stack handling */

/*
 * The state structure is opaque, its internals are known only to the
 * functions declared here.
 */

typedef struct RDE_PARAM_* RDE_PARAM;

typedef struct ERROR_STATE {
    int       refCount;
    long int  loc;
    RDE_STACK msg; /* long int :: error messages */
} ERROR_STATE;

typedef struct NC_STATE {
    long int     CL;
    long int     ST;
    Tcl_Obj*     SV;
    ERROR_STATE* ER;
} NC_STATE;

/* SKIP START */
/* Admin
 */

SCOPE RDE_PARAM rde_param_new            (long int n, char** strings);
SCOPE void      rde_param_del            (RDE_PARAM p);
SCOPE void      rde_param_reset          (RDE_PARAM p, Tcl_Channel chan);
SCOPE void      rde_param_update_strings (RDE_PARAM p, long int n, char** strings);
SCOPE void      rde_param_data           (RDE_PARAM p, char* buf, long int len);
SCOPE void      rde_param_clientdata     (RDE_PARAM p, ClientData clientData);

/* Accessors
 */

SCOPE ClientData         rde_param_query_clientdata (RDE_PARAM p);
SCOPE void               rde_param_query_amark   (RDE_PARAM p, long int* mc, void*** mv);
SCOPE void               rde_param_query_ast     (RDE_PARAM p, long int* ac, Tcl_Obj*** av);
SCOPE const char*        rde_param_query_in      (RDE_PARAM p);
SCOPE const char*        rde_param_query_cc      (RDE_PARAM p, long int* len);
SCOPE int                rde_param_query_cl      (RDE_PARAM p);
SCOPE const ERROR_STATE* rde_param_query_er      (RDE_PARAM p);
SCOPE Tcl_Obj*           rde_param_query_er_tcl  (RDE_PARAM p, const ERROR_STATE* er);
SCOPE void               rde_param_query_es      (RDE_PARAM p, long int* ec, ERROR_STATE*** ev);
SCOPE void               rde_param_query_ls      (RDE_PARAM p, long int* lc, void*** lv);
SCOPE long int           rde_param_query_lstop   (RDE_PARAM p);
SCOPE Tcl_HashTable*     rde_param_query_nc      (RDE_PARAM p);
SCOPE int                rde_param_query_st      (RDE_PARAM p);
SCOPE Tcl_Obj*           rde_param_query_sv      (RDE_PARAM p);
SCOPE long int           rde_param_query_tc_size (RDE_PARAM p);
SCOPE void               rde_param_query_tc_get_s (RDE_PARAM p, long int at, long int last, char** ch, long int* len);
SCOPE const char*        rde_param_query_string  (RDE_PARAM p, long int id);

/* Instructions
 */

SCOPE void rde_param_i_ast_pop_discard   (RDE_PARAM p);
SCOPE void rde_param_i_ast_pop_rewind    (RDE_PARAM p);
SCOPE void rde_param_i_ast_push          (RDE_PARAM p);
SCOPE void rde_param_i_ast_rewind        (RDE_PARAM p);
SCOPE void rde_param_i_ast_value_push    (RDE_PARAM p);

SCOPE void rde_param_i_error_clear       (RDE_PARAM p);
SCOPE void rde_param_i_error_nonterminal (RDE_PARAM p, long int s);
SCOPE void rde_param_i_error_pop_merge   (RDE_PARAM p);
SCOPE void rde_param_i_error_push        (RDE_PARAM p);

SCOPE void rde_param_i_loc_pop_discard   (RDE_PARAM p);
SCOPE void rde_param_i_loc_pop_rewind    (RDE_PARAM p);
SCOPE void rde_param_i_loc_push          (RDE_PARAM p);
SCOPE void rde_param_i_loc_rewind        (RDE_PARAM p);

SCOPE void rde_param_i_input_next        (RDE_PARAM p, long int m);

SCOPE void rde_param_i_status_fail       (RDE_PARAM p);
SCOPE void rde_param_i_status_ok         (RDE_PARAM p);
SCOPE void rde_param_i_status_negate     (RDE_PARAM p);

SCOPE int  rde_param_i_symbol_restore    (RDE_PARAM p, long int s);
SCOPE void rde_param_i_symbol_save       (RDE_PARAM p, long int s);

SCOPE void rde_param_i_test_char         (RDE_PARAM p, const char* c, long int m);
SCOPE void rde_param_i_test_range        (RDE_PARAM p, const char* s, const char* e, long int m);

SCOPE void rde_param_i_test_alnum        (RDE_PARAM p);
SCOPE void rde_param_i_test_alpha        (RDE_PARAM p);
SCOPE void rde_param_i_test_ascii        (RDE_PARAM p);
SCOPE void rde_param_i_test_control      (RDE_PARAM p);
SCOPE void rde_param_i_test_ddigit       (RDE_PARAM p);
SCOPE void rde_param_i_test_digit        (RDE_PARAM p);
SCOPE void rde_param_i_test_graph        (RDE_PARAM p);
SCOPE void rde_param_i_test_lower        (RDE_PARAM p);
SCOPE void rde_param_i_test_print        (RDE_PARAM p);
SCOPE void rde_param_i_test_punct        (RDE_PARAM p);
SCOPE void rde_param_i_test_space        (RDE_PARAM p);
SCOPE void rde_param_i_test_upper        (RDE_PARAM p);
SCOPE void rde_param_i_test_wordchar     (RDE_PARAM p);
SCOPE void rde_param_i_test_xdigit       (RDE_PARAM p);

SCOPE void rde_param_i_value_clear       (RDE_PARAM p);
SCOPE void rde_param_i_value_leaf        (RDE_PARAM p, long int s);
SCOPE void rde_param_i_value_reduce      (RDE_PARAM p, long int s);

/* Super Instructions - Aggregated common instruction sequences.
 */

SCOPE int  rde_param_i_symbol_start         (RDE_PARAM p, long int s);
SCOPE int  rde_param_i_symbol_start_d       (RDE_PARAM p, long int s);
SCOPE int  rde_param_i_symbol_void_start    (RDE_PARAM p, long int s);
SCOPE int  rde_param_i_symbol_void_start_d  (RDE_PARAM p, long int s);

SCOPE void rde_param_i_symbol_done_d_reduce (RDE_PARAM p, long int s, long int m);
SCOPE void rde_param_i_symbol_done_leaf     (RDE_PARAM p, long int s, long int m);
SCOPE void rde_param_i_symbol_done_d_leaf   (RDE_PARAM p, long int s, long int m);
SCOPE void rde_param_i_symbol_done_void     (RDE_PARAM p, long int s, long int m);
SCOPE void rde_param_i_symbol_done_d_void   (RDE_PARAM p, long int s, long int m);

SCOPE void rde_param_i_next_char     (RDE_PARAM p, const char* c, long int m);
SCOPE void rde_param_i_next_range    (RDE_PARAM p, const char* s, const char* e, long int m);

SCOPE void rde_param_i_next_alnum    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_alpha    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_ascii    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_control  (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_ddigit   (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_digit    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_graph    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_lower    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_print    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_punct    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_space    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_upper    (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_wordchar (RDE_PARAM p, long int m);
SCOPE void rde_param_i_next_xdigit   (RDE_PARAM p, long int m);

SCOPE void rde_param_i_notahead_start_d (RDE_PARAM p);
SCOPE void rde_param_i_notahead_exit_d  (RDE_PARAM p);
SCOPE void rde_param_i_notahead_exit    (RDE_PARAM p);

SCOPE void rde_param_i_state_push_2     (RDE_PARAM p);
SCOPE void rde_param_i_state_push_void  (RDE_PARAM p);
SCOPE void rde_param_i_state_push_value (RDE_PARAM p);

SCOPE void rde_param_i_state_merge_ok    (RDE_PARAM p);
SCOPE void rde_param_i_state_merge_void  (RDE_PARAM p);
SCOPE void rde_param_i_state_merge_value (RDE_PARAM p);

SCOPE int  rde_param_i_kleene_close   (RDE_PARAM p);
SCOPE int  rde_param_i_kleene_abort   (RDE_PARAM p);

SCOPE int  rde_param_i_seq_void2void   (RDE_PARAM p);
SCOPE int  rde_param_i_seq_void2value  (RDE_PARAM p);
SCOPE int  rde_param_i_seq_value2value (RDE_PARAM p);

SCOPE int  rde_param_i_bra_void2void   (RDE_PARAM p);
SCOPE int  rde_param_i_bra_void2value  (RDE_PARAM p);
SCOPE int  rde_param_i_bra_value2void  (RDE_PARAM p);
SCOPE int  rde_param_i_bra_value2value (RDE_PARAM p);

SCOPE void rde_param_i_next_str   (RDE_PARAM p, const char* str,   long int m);
SCOPE void rde_param_i_next_class (RDE_PARAM p, const char* class, long int m);

/* SKIP END */
#endif /* _RDE_DS_PARAM_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

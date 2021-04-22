/*
 * = = == === ===== ======== ============= =====================
 * == pt::rde (critcl) - Data Structures - PARAM architectural state.
 */

#include <param.h> /* Public and private APIs */
#include <stack.h> /* Stack handling */
#include <tc.h>    /* Token cache handling */
#include <util.h>  /* Allocation utilities */
#include <string.h>
#include <ctype.h>  /* is... */
#include <stdlib.h> /* qsort */

/*
 * = = == === ===== ======== ============= =====================
 */

typedef struct RDE_PARAM_ {

    Tcl_Channel   IN;
    Tcl_Obj*      readbuf;
    char*         CC; /* [TCL_UTF_MAX] */
    long int      CC_len;

    RDE_TC        TC;

    long int      CL;
    RDE_STACK     LS; /* long int :: locations */

    ERROR_STATE*  ER;
    RDE_STACK     ES; /* ERROR_STATE* :: errors */

    long int      ST;
    Tcl_Obj*      SV;

    Tcl_HashTable NC;

    /*
     * AS/ARS are actually intertwined. ARS is the top of 'ast' below, with
     * the markers on 'mark' showing where ARS ends and AS with older ARS
     * begins.
     */

    RDE_STACK    ast  ; /* Tcl_Obj* :: ast (node) */
    RDE_STACK    mark ; /* long int :: markers */

    /* Various non PARAM state needed, the only part. An array of all the
     * strings needed by this state instance. The instruction implementations
     * take indices into this array instead of the actual strings, where
     * needed. This field is NOT owned by the state.
     */

    long int numstr; /* String table (error messages), and its size */
    char**  string;

    /*
     * A generic value for the higher layers to associate their own
     * information with the parser's state.
     */

    ClientData clientData;

} RDE_PARAM_;

typedef int (*UniCharClass) (int);

/* See also p.c, param_new(), table of param_intern() calls.
 * ** Keep in sync **
 */
typedef enum test_class_id {
    tc_alnum,
    tc_alpha,
    tc_ascii,
    tc_control,
    tc_ddigit,
    tc_digit,
    tc_graph,
    tc_lower,
    tc_printable,
    tc_punct,
    tc_space,
    tc_upper,
    tc_wordchar,
    tc_xdigit
} test_class_id;

/*
 * = = == === ===== ======== ============= =====================
 */

static void ast_node_free    (void* n);
static void error_state_free (void* es);
static void error_set        (RDE_PARAM p, long int s);
static void nc_clear         (RDE_PARAM p);

static int UniCharIsAscii    (int character);
static int UniCharIsHexDigit (int character);
static int UniCharIsDecDigit (int character);

static void test_class (RDE_PARAM p, UniCharClass class, test_class_id id);
static int  er_int_compare (const void* a, const void* b);

/*
 * = = == === ===== ======== ============= =====================
 */

#define SV_INIT(p)             \
    p->SV = NULL; \
    TRACE (("SV_INIT (%p => %p)", (p), (p)->SV))

#define SV_SET(p,newsv)             \
    if (((p)->SV) != (newsv)) { \
        TRACE (("SV_CLEAR/set (%p => %p)", (p), (p)->SV)); \
        if ((p)->SV) {                  \
	    Tcl_DecrRefCount ((p)->SV); \
        }				    \
        (p)->SV = (newsv);		    \
        TRACE (("SV_SET       (%p => %p)", (p), (p)->SV)); \
        if ((p)->SV) {                  \
	    Tcl_IncrRefCount ((p)->SV); \
        } \
    }

#define SV_CLEAR(p)                 \
    TRACE (("SV_CLEAR (%p => %p)", (p), (p)->SV)); \
    if ((p)->SV) {                  \
	Tcl_DecrRefCount ((p)->SV); \
    }				    \
    (p)->SV = NULL

#define ER_INIT(p)             \
    p->ER = NULL; \
    TRACE (("ER_INIT (%p => %p)", (p), (p)->ER))

#define ER_CLEAR(p)             \
    error_state_free ((p)->ER);	\
    (p)->ER = NULL

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE RDE_PARAM
rde_param_new (long int nstr, char** strings)
{
    RDE_PARAM p;

    ENTER ("rde_param_new");
    TRACE (("\tINT %d strings @ %p", nstr, strings));

    p = ALLOC (RDE_PARAM_);
    p->numstr = nstr;
    p->string = strings;

    p->readbuf = Tcl_NewObj ();
    Tcl_IncrRefCount (p->readbuf);

    TRACE (("\tTcl_Obj* readbuf %p used %d", p->readbuf,p->readbuf->refCount));

    Tcl_InitHashTable (&p->NC, TCL_ONE_WORD_KEYS);

    p->IN   = NULL;
    p->CL   = -1;
    p->ST   = 0;

    ER_INIT (p);
    SV_INIT (p);

    p->CC   = NULL;
    p->CC_len = 0;

    p->TC   = rde_tc_new ();
    p->ES   = rde_stack_new (error_state_free);
    p->LS   = rde_stack_new (NULL);
    p->ast  = rde_stack_new (ast_node_free);
    p->mark = rde_stack_new (NULL);

    RETURN ("%p", p);
}

SCOPE void 
rde_param_del (RDE_PARAM p)
{
    ENTER ("rde_param_del");
    TRACE (("RDE_PARAM %p",p));

    ER_CLEAR (p);                 TRACE (("\ter_clear"));
    SV_CLEAR (p);                 TRACE (("\tsv_clear"));

    nc_clear (p);                 TRACE (("\tnc_clear"));
    Tcl_DeleteHashTable (&p->NC); TRACE (("\tnc hashtable delete"));

    rde_tc_del    (p->TC);        TRACE (("\ttc clear"));
    rde_stack_del (p->ES);        TRACE (("\tes clear"));
    rde_stack_del (p->LS);        TRACE (("\tls clear"));
    rde_stack_del (p->ast);       TRACE (("\tast clear"));
    rde_stack_del (p->mark);      TRACE (("\tmark clear"));

    TRACE (("\tTcl_Obj* readbuf %p used %d", p->readbuf,p->readbuf->refCount));

    Tcl_DecrRefCount (p->readbuf);
    ckfree ((char*) p);

    RETURNVOID;
}

SCOPE void 
rde_param_reset (RDE_PARAM p, Tcl_Channel chan)
{
    ENTER ("rde_param_reset");
    TRACE (("RDE_PARAM   %p",p));
    TRACE (("Tcl_Channel %p",chan));

    p->IN  = chan;
    p->CL  = -1;
    p->ST  = 0;

    p->CC  = NULL;
    p->CC_len = 0;

    ER_CLEAR (p);
    SV_CLEAR (p);
    nc_clear (p);

    rde_tc_clear   (p->TC);
    rde_stack_trim (p->ES,   0);
    rde_stack_trim (p->LS,   0);
    rde_stack_trim (p->ast,  0);
    rde_stack_trim (p->mark, 0);

    TRACE (("\tTcl_Obj* readbuf %p used %d", p->readbuf,p->readbuf->refCount));

    RETURNVOID;
}

SCOPE void
rde_param_update_strings (RDE_PARAM p, long int nstr, char** strings)
{
    ENTER ("rde_param_update_strings");
    TRACE (("RDE_PARAM %p", p));
    TRACE (("INT       %d strings", nstr));

    p->numstr = nstr;
    p->string = strings;

    RETURNVOID;
}

SCOPE void
rde_param_data (RDE_PARAM p, char* buf, long int len)
{
    (void) rde_tc_append (p->TC, buf, len);
}

SCOPE void
rde_param_clientdata (RDE_PARAM p, ClientData clientData)
{
    p->clientData = clientData;
}

/*
 * = = == === ===== ======== ============= =====================
 */

static void
nc_clear (RDE_PARAM p)
{
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    Tcl_HashTable* tablePtr;

    for(he = Tcl_FirstHashEntry(&p->NC, &hs);
	he != NULL;
	he = Tcl_FirstHashEntry(&p->NC, &hs)) {

	Tcl_HashSearch hsc;
	Tcl_HashEntry* hec;

	tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (he);

	for(hec = Tcl_FirstHashEntry(tablePtr, &hsc);
	    hec != NULL;
	    hec = Tcl_NextHashEntry(&hsc)) {

	    NC_STATE* scs = Tcl_GetHashValue (hec);
	    error_state_free (scs->ER);
	    if (scs->SV) { Tcl_DecrRefCount (scs->SV); }
	    ckfree ((char*) scs);
	}

	Tcl_DeleteHashTable (tablePtr);
	ckfree ((char*) tablePtr);
	Tcl_DeleteHashEntry (he);
    }
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE ClientData
rde_param_query_clientdata (RDE_PARAM p)
{
    return p->clientData;
}

SCOPE void
rde_param_query_amark (RDE_PARAM p, long int* mc, void*** mv)
{
    rde_stack_get (p->mark, mc, mv);
}

SCOPE void
rde_param_query_ast (RDE_PARAM p, long int* ac, Tcl_Obj*** av)
{
    rde_stack_get (p->ast, ac, (void***) av);
}

SCOPE const char*
rde_param_query_in (RDE_PARAM p)
{
    return p->IN
	? Tcl_GetChannelName (p->IN)
	: "";
}

SCOPE const char*
rde_param_query_cc (RDE_PARAM p, long int* len)
{
    *len = p->CC_len;
    return p->CC;
}

SCOPE int
rde_param_query_cl (RDE_PARAM p)
{
    return p->CL;
}

SCOPE const ERROR_STATE*
rde_param_query_er (RDE_PARAM p)
{
    return p->ER;
}

SCOPE Tcl_Obj*
rde_param_query_er_tcl (RDE_PARAM p, const ERROR_STATE* er)
{
    Tcl_Obj* res;

    if (!er) {
	/*
	 * Consider keeping one of these around in the main object state, for
	 * quick return.
	 */
	res = Tcl_NewStringObj ("", 0);
    } else {
	Tcl_Obj* ov [2];
	Tcl_Obj** mov;
	long int  mc, i, j;
	void** mv;
	int lastid;
	const char* msg;

	rde_stack_get (er->msg, &mc, &mv);

	/*
	 * Note: We are peeking inside the (message) stack here and are
	 * modifying it in place. This doesn't matter, we are using the stack
	 * code for convenience, not for the ordering.
	 */

	qsort (mv, mc, sizeof (void*), er_int_compare);

	/*
	 * Convert message ids to strings. We ignore duplicates, by comparing
	 * to the last processed id. Here the sorting (see above) comes into
	 * play, we know that duplicates are bunched together in runs, making
	 * it easy to drop them.
	 */

	mov = NALLOC (mc, Tcl_Obj*);
	lastid = -1;
	for (i=0, j=0; i < mc; i++) {
	    ASSERT_BOUNDS (i,mc);

	    if (((long int) mv [i]) == lastid) continue;
	    lastid = (long int) mv [i];

	    ASSERT_BOUNDS((long int) mv[i],p->numstr);
	    msg = p->string [(long int) mv[i]]; /* inlined query_string */

	    ASSERT_BOUNDS (j,mc);
	    mov [j] = Tcl_NewStringObj (msg, -1);
	    j++;
	}

	/*
	 * Assemble the result.
	 */

	ov [0] = Tcl_NewIntObj  (er->loc);
	ov [1] = Tcl_NewListObj (j, mov);

	res = Tcl_NewListObj (2, ov);

	ckfree ((char*) mov);
    }

    return res;
}

SCOPE void
rde_param_query_es (RDE_PARAM p, long int* ec, ERROR_STATE*** ev)
{
    rde_stack_get (p->ES, ec, (void***) ev);
}

SCOPE void
rde_param_query_ls (RDE_PARAM p, long int* lc, void*** lv)
{
    rde_stack_get (p->LS, lc, lv);
}

SCOPE long int
rde_param_query_lstop (RDE_PARAM p)
{
    return (long int) rde_stack_top (p->LS);
}

SCOPE Tcl_HashTable*
rde_param_query_nc (RDE_PARAM p)
{
    return &p->NC;
}

SCOPE int
rde_param_query_st (RDE_PARAM p)
{
    return p->ST;
}

SCOPE Tcl_Obj*
rde_param_query_sv (RDE_PARAM p)
{
    TRACE (("SV_QUERY %p => (%p)", (p), (p)->SV)); \
    return p->SV;
}

SCOPE long int
rde_param_query_tc_size (RDE_PARAM p)
{
    return rde_tc_size (p->TC);
}

SCOPE void
rde_param_query_tc_get_s (RDE_PARAM p, long int at, long int last, char** ch, long int* len)
{
    rde_tc_get_s (p->TC, at, last, ch, len);
}

SCOPE const char*
rde_param_query_string (RDE_PARAM p, long int id)
{
    TRACE (("rde_param_query_string (RDE_PARAM %p, %d/%d)", p, id, p->numstr));

    ASSERT_BOUNDS(id,p->numstr);

    return p->string [id];
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_ast_pop_discard (RDE_PARAM p)
{
    rde_stack_pop (p->mark, 1);
}

SCOPE void
rde_param_i_ast_pop_rewind (RDE_PARAM p)
{
    long int trim = (long int) rde_stack_top (p->mark);

    ENTER ("rde_param_i_ast_pop_rewind");
    TRACE (("RDE_PARAM %p",p));

    rde_stack_pop  (p->mark, 1);
    rde_stack_trim (p->ast, trim);

    TRACE (("SV = (%p rc%d '%s')",
	    p->SV,
	    p->SV ? p->SV->refCount       : -1,
	    p->SV ? Tcl_GetString (p->SV) : ""));
    RETURNVOID;
}

SCOPE void
rde_param_i_ast_rewind (RDE_PARAM p)
{
    long int trim = (long int) rde_stack_top (p->mark);

    ENTER ("rde_param_i_ast_rewind");
    TRACE (("RDE_PARAM %p",p));

    rde_stack_trim (p->ast, trim);

    TRACE (("SV = (%p rc%d '%s')",
	    p->SV,
	    p->SV ? p->SV->refCount       : -1,
	    p->SV ? Tcl_GetString (p->SV) : ""));
    RETURNVOID;
}

SCOPE void
rde_param_i_ast_push (RDE_PARAM p)
{
    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
}

SCOPE void
rde_param_i_ast_value_push (RDE_PARAM p)
{
    ENTER ("rde_param_i_ast_value_push");
    TRACE (("RDE_PARAM %p",p));

    ASSERT(p->SV,"Unable to push undefined semantic value");
    TRACE (("rde_param_i_ast_value_push %p => (%p)", p, p->SV));
    TRACE (("SV = (%p rc%d '%s')", p->SV, p->SV->refCount, Tcl_GetString (p->SV)));

    rde_stack_push (p->ast, p->SV);
    Tcl_IncrRefCount (p->SV);

    RETURNVOID;
}

static void
ast_node_free (void* n)
{
    Tcl_DecrRefCount ((Tcl_Obj*) n);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_error_clear (RDE_PARAM p)
{
    ER_CLEAR (p);
}

SCOPE void
rde_param_i_error_nonterminal (RDE_PARAM p, long int s)
{
    /*
     * Disabled. Generate only low-level errors until we have worked out how
     * to integrate symbol information with them. Do not forget where this
     * instruction is inlined - No such exist, places using the instruction
     * directly call on this function.
     */
    return;
#if 0
    long int pos;
    if (!p->ER) return;
    pos = 1 + (long int) rde_stack_top (p->LS);
    if (p->ER->loc != pos) return;
    error_set (p, s);
    p->ER->loc = pos;
#endif
}

SCOPE void
rde_param_i_error_pop_merge (RDE_PARAM p)
{
    ERROR_STATE* top = (ERROR_STATE*) rde_stack_top (p->ES);

    /*
     * The states are identical. Nothing has to be done in that case.
     */

    if (top == p->ER) {
	rde_stack_pop (p->ES, 1);
	return;
    }

    /*
     * Saved state is nothing, keep current, discard top.
     * No refCount to change.
     */

    if (!top) {
	rde_stack_pop (p->ES, 1);
	return;
    }

    /*
     * Current state is nothing, keep top, dicard current. We 'drop' as we are
     * taking ownership of the error state in 'top' back from the stack.
     */

    if (!p->ER) {
	rde_stack_drop (p->ES, 1);
	p->ER = top;

	/*
	 * Note: The refCount of top is left unchanged. The reference lost
	 * through the drop is taken over by ER.
	 */
	return;
    }

    /*
     * Both top and current have data. Compare their locations to determine
     * which to keep, or discard, respectively.
     *
     * The current state is farther ahead in the input, keep it, and discard
     * the saved information.
     */

    if (top->loc < p->ER->loc) {
	rde_stack_pop (p->ES, 1);
	return;
    }

    /*
     * The saved state is farther ahead than the current one, keep it, discard
     * current. We 'drop' as we are taking ownership of the error state in
     * 'top' back from the stack.
     */

    if (top->loc > p->ER->loc) {
	rde_stack_drop (p->ES, 1);
	error_state_free (p->ER);
	p->ER = top;

	/*
	 * Note: The refCount of top is left unchanged. The reference lost
	 * through the drop is taken over by ER.
	 */
	return;
    }

    /*
     * Both states describe the same location. We merge the message sets. We
     * do not make the set unique however. This can be defered until the data
     * is actually retrieved by the user of the PARAM.
     */

    rde_stack_move (p->ER->msg, top->msg);
    rde_stack_pop  (p->ES, 1);
}

SCOPE void
rde_param_i_error_push (RDE_PARAM p)
{
    rde_stack_push (p->ES, p->ER);
    if (p->ER) { p->ER->refCount ++; }
}

static void
error_set (RDE_PARAM p, long int s)
{
    error_state_free (p->ER);

    p->ER = ALLOC (ERROR_STATE);
    p->ER->refCount = 1;
    p->ER->loc      = p->CL;
    p->ER->msg      = rde_stack_new (NULL);

    ASSERT_BOUNDS(s,p->numstr);

    rde_stack_push (p->ER->msg, (void*) s);
}

static void
error_state_free (void* esx)
{
    ERROR_STATE* es = esx;

    if (!es) return;

    es->refCount --;
    if (es->refCount > 0) return;

    rde_stack_del (es->msg);
    ckfree ((char*) es);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_loc_pop_discard (RDE_PARAM p)
{
    rde_stack_pop (p->LS, 1);
}

SCOPE void
rde_param_i_loc_pop_rewind (RDE_PARAM p)
{
    p->CL = (long int) rde_stack_top (p->LS);
    rde_stack_pop (p->LS, 1);
}

SCOPE void
rde_param_i_loc_push (RDE_PARAM p)
{
    rde_stack_push (p->LS, (void*) p->CL);
}

SCOPE void
rde_param_i_loc_rewind (RDE_PARAM p)
{
    p->CL = (long int) rde_stack_top (p->LS);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_input_next (RDE_PARAM p, long int m)
{
    int leni;
    char* ch;

    ASSERT_BOUNDS(m,p->numstr);

    p->CL ++;

    if (p->CL < rde_tc_size (p->TC)) {
	/*
	 * We are at a known position, we can and do take the associated
	 * character out of the token cache.
	 *
	 * FUTURE :: keep track of what location the data stored in CC is
	 * for. If the location is identical no extraction is required. This
	 * may help when a choice repeatedly tests the same character.
	 */

	rde_tc_get (p->TC, p->CL, &p->CC, &p->CC_len);
	/* Note: BOUNDS(n) <=> [0..(n-1)].
	 * cc_len in [1..utfmax] <=> cc_len-1 in [0...utfmax-1] <=> BOUNDS(utfmax)
	 */
	ASSERT_BOUNDS (p->CC_len-1, TCL_UTF_MAX);

	p->ST = 1;
	ER_CLEAR (p);
	return;
    }

    if (!p->IN || 
	Tcl_Eof (p->IN) ||
	(Tcl_ReadChars (p->IN, p->readbuf, 1, 0) <= 0)) {
	/*
	 * As we are outside of the known range we tried to read a character
	 * from the input, to extend the token cache with. That failed.
	 */

	p->ST = 0;
	error_set (p, m);
	return;
    }

    /*
     * We got a new character, we now extend the token cache, and also make it
     * current.
     */

    ch = Tcl_GetStringFromObj (p->readbuf, &leni);
    ASSERT_BOUNDS (leni, TCL_UTF_MAX);

    p->CC = rde_tc_append (p->TC, ch, leni);
    p->CC_len = leni;

    p->ST = 1;
    ER_CLEAR (p);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_status_fail (RDE_PARAM p)
{
    p->ST = 0;
}

SCOPE void
rde_param_i_status_ok (RDE_PARAM p)
{
    p->ST = 1;
}

SCOPE void
rde_param_i_status_negate (RDE_PARAM p)
{
    p->ST = !p->ST;
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE int 
rde_param_i_symbol_restore (RDE_PARAM p, long int s)
{
    NC_STATE*      scs;
    Tcl_HashEntry* hPtr;
    Tcl_HashTable* tablePtr;

    /*
     * 2-level hash table keyed by location, and symbol ...
     */

    hPtr = Tcl_FindHashEntry (&p->NC, (char*) p->CL);
    if (!hPtr) { return 0; }

    tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (hPtr);
    hPtr = Tcl_FindHashEntry (tablePtr, (char*) s);
    if (!hPtr) { return 0; }

    /*
     * Found information, apply it to the state, restoring the cached
     * situation.
     */

    scs = Tcl_GetHashValue (hPtr);

    p->CL = scs->CL;
    p->ST = scs->ST;

    error_state_free (p->ER);
    p->ER = scs->ER;
    if (p->ER) { p->ER->refCount ++; }

    TRACE (("SV_RESTORE (%p) '%s'",scs->SV, scs->SV ? Tcl_GetString (scs->SV):""));

    SV_SET (p, scs->SV);

    return 1;
}

SCOPE void
rde_param_i_symbol_save (RDE_PARAM p, long int s)
{
    long int       at = (long int) rde_stack_top (p->LS);
    NC_STATE*      scs;
    Tcl_HashEntry* hPtr;
    Tcl_HashTable* tablePtr;
    int            isnew;

    ENTER ("rde_param_i_symbol_save");
    TRACE (("RDE_PARAM %p",p));
    TRACE (("INT       %d",s));

    /*
     * 2-level hash table keyed by location, and symbol ...
     */

    hPtr = Tcl_CreateHashEntry (&p->NC, (char*) at, &isnew);

    if (isnew) {
	tablePtr = ALLOC (Tcl_HashTable);
	Tcl_InitHashTable (tablePtr, TCL_ONE_WORD_KEYS);
	Tcl_SetHashValue (hPtr, tablePtr);
    } else {
	tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (hPtr);
    }

    hPtr = Tcl_CreateHashEntry (tablePtr, (char*) s, &isnew);

    if (isnew) {
	/*
	 * Copy state into new cache entry.
	 */

	scs = ALLOC (NC_STATE);
	scs->CL = p->CL;
	scs->ST = p->ST;

	TRACE (("SV_CACHE (%p '%s')", p->SV, p->SV ? Tcl_GetString(p->SV) : ""));

	scs->SV = p->SV;
	if (scs->SV) { Tcl_IncrRefCount (scs->SV); }

	scs->ER = p->ER;
	if (scs->ER) { scs->ER->refCount ++; }

	Tcl_SetHashValue (hPtr, scs);
    } else {
	/*
	 * Copy state into existing cache entry, overwriting the previous
	 * information.
	 */

	scs = (NC_STATE*) Tcl_GetHashValue (hPtr);

	scs->CL = p->CL;
	scs->ST = p->ST;

	TRACE (("SV_CACHE/over (%p '%s')", p->SV, p->SV ? Tcl_GetString(p->SV) : "" ));

	if (scs->SV) { Tcl_DecrRefCount (scs->SV); }
	scs->SV = p->SV;
	if (scs->SV) { Tcl_IncrRefCount (scs->SV); }

	error_state_free (scs->ER);
	scs->ER = p->ER;
	if (scs->ER) { scs->ER->refCount ++; }
    }

    TRACE (("SV = (%p rc%d '%s')",
	    p->SV,
	    p->SV ? p->SV->refCount       : -1,
	    p->SV ? Tcl_GetString (p->SV) : ""));
    RETURNVOID;
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_test_alnum (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsAlnum, tc_alnum);
}

SCOPE void
rde_param_i_test_alpha (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsAlpha, tc_alpha);
}

SCOPE void
rde_param_i_test_ascii (RDE_PARAM p)
{
    test_class (p, UniCharIsAscii, tc_ascii);
}

SCOPE void
rde_param_i_test_control (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsControl, tc_control);
}

SCOPE void
rde_param_i_test_char (RDE_PARAM p, const char* c, long int msg)
{
    ASSERT_BOUNDS(msg,p->numstr);

    p->ST = Tcl_UtfNcmp (p->CC, c, 1) == 0;

    if (p->ST) {
	ER_CLEAR (p);
    } else {
	error_set (p, msg);
	p->CL --;
    }
}

SCOPE void
rde_param_i_test_ddigit (RDE_PARAM p)
{
    test_class (p, UniCharIsDecDigit, tc_ddigit);
}

SCOPE void
rde_param_i_test_digit (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsDigit, tc_digit);
}

SCOPE void
rde_param_i_test_graph (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsGraph, tc_graph);
}

SCOPE void
rde_param_i_test_lower (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsLower, tc_lower);
}

SCOPE void
rde_param_i_test_print (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsPrint, tc_printable);
}

SCOPE void
rde_param_i_test_punct (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsPunct, tc_punct);
}

SCOPE void
rde_param_i_test_range (RDE_PARAM p, const char* s, const char* e, long int msg)
{
    ASSERT_BOUNDS(msg,p->numstr);

    p->ST =
	(Tcl_UtfNcmp (s, p->CC, 1) <= 0) &&
	(Tcl_UtfNcmp (p->CC, e, 1) <= 0);

    if (p->ST) {
	ER_CLEAR (p);
    } else {
	error_set (p, msg);
	p->CL --;
    }
}

SCOPE void
rde_param_i_test_space (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsSpace, tc_space);
}

SCOPE void
rde_param_i_test_upper (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsUpper, tc_upper);
}

SCOPE void
rde_param_i_test_wordchar (RDE_PARAM p)
{
    test_class (p, Tcl_UniCharIsWordChar, tc_wordchar);
}

SCOPE void
rde_param_i_test_xdigit (RDE_PARAM p)
{
    test_class (p, UniCharIsHexDigit, tc_xdigit);
}

static void
test_class (RDE_PARAM p, UniCharClass class, test_class_id id)
{
    Tcl_UniChar ch;
    Tcl_UtfToUniChar(p->CC, &ch);

    ASSERT_BOUNDS(id,p->numstr);

    p->ST = !!class (ch);

    /* The double-negation normalizes the output of the class function to the
     * regular booleans 0 and 1.
     */

    if (p->ST) {
	ER_CLEAR (p);
    } else {
	error_set (p, id);
	p->CL --;
    }
}

static int
UniCharIsAscii (int character)
{
    return (character >= 0) && (character < 0x80);
}

static int
UniCharIsHexDigit (int character)
{
    return (character >= 0) && (character < 0x80) && isxdigit(character);
}

static int
UniCharIsDecDigit (int character)
{
    return (character >= 0) && (character < 0x80) && isdigit(character);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_value_clear (RDE_PARAM p)
{
    SV_CLEAR (p);
}

SCOPE void
rde_param_i_value_leaf (RDE_PARAM p, long int s)
{
    Tcl_Obj* newsv;
    Tcl_Obj* ov [3];
    long int pos = 1 + (long int) rde_stack_top (p->LS);

    ASSERT_BOUNDS(s,p->numstr);

    ov [0] = Tcl_NewStringObj (p->string[s], -1);
    ov [1] = Tcl_NewIntObj (pos);
    ov [2] = Tcl_NewIntObj (p->CL);

    newsv = Tcl_NewListObj (3, ov);

    TRACE (("rde_param_i_value_leaf => '%s'",Tcl_GetString (newsv)));

    SV_SET (p, newsv);
}

SCOPE void
rde_param_i_value_reduce (RDE_PARAM p, long int s)
{
    Tcl_Obj*  newsv;
    int       i, j;
    Tcl_Obj** ov;
    long int  ac;
    Tcl_Obj** av;

    long int pos   = 1 + (long int) rde_stack_top (p->LS);
    long int mark  = (long int) rde_stack_top (p->mark);
    long int asize = rde_stack_size (p->ast);
    long int new   = asize - mark;

    ASSERT (new >= 0, "Bad number of elements to reduce");

    ov = NALLOC (3+new, Tcl_Obj*);

    ASSERT_BOUNDS(s,p->numstr);

    ov [0] = Tcl_NewStringObj (p->string[s], -1);
    ov [1] = Tcl_NewIntObj (pos);
    ov [2] = Tcl_NewIntObj (p->CL);

    rde_stack_get (p->ast, &ac, (void***) &av);
    for (i = 3, j = mark; j < asize; i++, j++) {
	ASSERT_BOUNDS (i, 3+new);
	ASSERT_BOUNDS (j, ac);
	ov [i] = av [j];
    }

    ASSERT (i == 3+new, "Reduction result incomplete");
    newsv = Tcl_NewListObj (3+new, ov);

    TRACE (("rde_param_i_value_reduce => '%s'",Tcl_GetString (newsv)));

    SV_SET (p, newsv);
    ckfree ((char*) ov);
}

/*
 * = = == === ===== ======== ============= =====================
 */

static int
er_int_compare (const void* a, const void* b)
{
    /* a, b = pointers to element, as void*.
     * Actual element type is (void*), and
     * actually stored data is (long int).
     */

    const void** ael = (const void**) a;
    const void** bel = (const void**) b;

    long int avalue = (long int) *ael;
    long int bvalue = (long int) *bel;

    if (avalue < bvalue) { return -1; }
    if (avalue > bvalue) { return  1; }
    return 0;
}

/*
 * = = == === ===== ======== ============= =====================
 * == Super Instructions.
 */

SCOPE int
rde_param_i_symbol_start (RDE_PARAM p, long int s)
{
    if (rde_param_i_symbol_restore (p, s)) {
	if (p->ST) {
	    rde_stack_push (p->ast, p->SV);
	    Tcl_IncrRefCount (p->SV);
	}
	return 1;
    }

    rde_stack_push (p->LS, (void*) p->CL);
    return 0;
}

SCOPE int
rde_param_i_symbol_start_d (RDE_PARAM p, long int s)
{
    if (rde_param_i_symbol_restore (p, s)) {
	if (p->ST) {
	    rde_stack_push (p->ast, p->SV);
	    Tcl_IncrRefCount (p->SV);
	}
	return 1;
    }

    rde_stack_push (p->LS,   (void*) p->CL);
    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
    return 0;
}

SCOPE int
rde_param_i_symbol_void_start (RDE_PARAM p, long int s)
{
    if (rde_param_i_symbol_restore (p, s)) return 1;

    rde_stack_push (p->LS, (void*) p->CL);
    return 0;
}

SCOPE int
rde_param_i_symbol_void_start_d (RDE_PARAM p, long int s)
{
    if (rde_param_i_symbol_restore (p, s)) return 1;

    rde_stack_push (p->LS,   (void*) p->CL);
    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
    return 0;
}

SCOPE void
rde_param_i_symbol_done_d_reduce (RDE_PARAM p, long int s, long int m)
{
    if (p->ST) {
	rde_param_i_value_reduce (p, s);
    } else {
	SV_CLEAR (p);
    }

    rde_param_i_symbol_save       (p, s);
    rde_param_i_error_nonterminal (p, m);
    rde_param_i_ast_pop_rewind    (p);

    rde_stack_pop (p->LS, 1);

    if (p->ST) {
	rde_stack_push (p->ast, p->SV);
	Tcl_IncrRefCount (p->SV);
    }
}

SCOPE void
rde_param_i_symbol_done_leaf (RDE_PARAM p, long int s, long int m)
{
    if (p->ST) {
	rde_param_i_value_leaf (p, s);
    } else {
	SV_CLEAR (p);
    }

    rde_param_i_symbol_save       (p, s);
    rde_param_i_error_nonterminal (p, m);

    rde_stack_pop (p->LS, 1);

    if (p->ST) {
	rde_stack_push (p->ast, p->SV);
	Tcl_IncrRefCount (p->SV);
    }
}

SCOPE void
rde_param_i_symbol_done_d_leaf (RDE_PARAM p, long int s, long int m)
{
    if (p->ST) {
	rde_param_i_value_leaf (p, s);
    } else {
	SV_CLEAR (p);
    }

    rde_param_i_symbol_save       (p, s);
    rde_param_i_error_nonterminal (p, m);
    rde_param_i_ast_pop_rewind    (p);

    rde_stack_pop (p->LS, 1);

    if (p->ST) {
	rde_stack_push (p->ast, p->SV);
	Tcl_IncrRefCount (p->SV);
    }
}

SCOPE void
rde_param_i_symbol_done_void (RDE_PARAM p, long int s, long int m)
{
    SV_CLEAR (p);
    rde_param_i_symbol_save       (p, s);
    rde_param_i_error_nonterminal (p, m);

    rde_stack_pop (p->LS, 1);
}

SCOPE void
rde_param_i_symbol_done_d_void (RDE_PARAM p, long int s, long int m)
{
    SV_CLEAR (p);
    rde_param_i_symbol_save       (p, s);
    rde_param_i_error_nonterminal (p, m);
    rde_param_i_ast_pop_rewind    (p);

    rde_stack_pop (p->LS, 1);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_next_char (RDE_PARAM p, const char* c, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_char (p, c, m);
}

SCOPE void
rde_param_i_next_range (RDE_PARAM p, const char* s, const char* e, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_range (p, s, e, m);
}

SCOPE void
rde_param_i_next_alnum (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_alnum (p);
}

SCOPE void
rde_param_i_next_alpha (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_alpha (p);
}

SCOPE void
rde_param_i_next_ascii (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_ascii (p);
}

SCOPE void
rde_param_i_next_control (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_control (p);
}

SCOPE void
rde_param_i_next_ddigit (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_ddigit (p);
}

SCOPE void
rde_param_i_next_digit (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_digit (p);
}

SCOPE void
rde_param_i_next_graph (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_graph (p);
}

SCOPE void
rde_param_i_next_lower (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_lower (p);
}

SCOPE void
rde_param_i_next_print (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_print (p);
}

SCOPE void
rde_param_i_next_punct (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_punct (p);
}

SCOPE void
rde_param_i_next_space (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_space (p);
}

SCOPE void
rde_param_i_next_upper (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_upper (p);
}

SCOPE void
rde_param_i_next_wordchar (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_wordchar (p);
}

SCOPE void
rde_param_i_next_xdigit (RDE_PARAM p, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;
    rde_param_i_test_xdigit (p);
}

SCOPE void
rde_param_i_notahead_start_d (RDE_PARAM p)
{
    rde_stack_push (p->LS, (void*) p->CL);
    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
}

SCOPE void
rde_param_i_notahead_exit_d (RDE_PARAM p)
{
    if (p->ST) {
	rde_param_i_ast_pop_rewind (p); 
    } else {
	rde_stack_pop (p->mark, 1);
    }
    p->CL = (long int) rde_stack_top (p->LS);
    rde_stack_pop (p->LS, 1);
    p->ST = !p->ST;
}

SCOPE void
rde_param_i_notahead_exit (RDE_PARAM p)
{
    p->CL = (long int) rde_stack_top (p->LS);
    rde_stack_pop (p->LS, 1);
    p->ST = !p->ST;
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_state_push_2 (RDE_PARAM p)
{
    /* loc_push + error_push */
    rde_stack_push (p->LS, (void*) p->CL);
    rde_stack_push (p->ES, p->ER);
    if (p->ER) { p->ER->refCount ++; }
}

SCOPE void
rde_param_i_state_push_void (RDE_PARAM p)
{
    rde_stack_push (p->LS, (void*) p->CL);
    ER_CLEAR (p);
    rde_stack_push (p->ES, p->ER);
    /* if (p->ER) { p->ER->refCount ++; } */
}

SCOPE void
rde_param_i_state_push_value (RDE_PARAM p)
{
    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
    rde_stack_push (p->LS, (void*) p->CL);
    ER_CLEAR (p);
    rde_stack_push (p->ES, p->ER);
    /* if (p->ER) { p->ER->refCount ++; } */
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_state_merge_ok (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (!p->ST) {
	p->ST = 1;
	p->CL = (long int) rde_stack_top (p->LS);
    }
    rde_stack_pop (p->LS, 1);
}

SCOPE void
rde_param_i_state_merge_void (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (!p->ST) {
	p->CL = (long int) rde_stack_top (p->LS);
    }
    rde_stack_pop (p->LS, 1);
}

SCOPE void
rde_param_i_state_merge_value (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (!p->ST) {
	long int trim = (long int) rde_stack_top (p->mark);
	rde_stack_trim (p->ast, trim);
	p->CL = (long int) rde_stack_top (p->LS);
    }
    rde_stack_pop (p->mark, 1);
    rde_stack_pop (p->LS, 1);
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE int
rde_param_i_kleene_close (RDE_PARAM p)
{
    int stop = !p->ST;
    rde_param_i_error_pop_merge (p);

    if (stop) {
	p->ST = 1;
	p->CL = (long int) rde_stack_top (p->LS);
    }

    rde_stack_pop (p->LS, 1);
    return stop;
}

SCOPE int
rde_param_i_kleene_abort (RDE_PARAM p)
{
    int stop = !p->ST;

    if (stop) {
	p->CL = (long int) rde_stack_top (p->LS);
    }

    rde_stack_pop (p->LS, 1);
    return stop;
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE int
rde_param_i_seq_void2void (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
	return 0;
    } else {
	p->CL = (long int) rde_stack_top (p->LS);
	rde_stack_pop (p->LS, 1);
	return 1;
    }
}

SCOPE int
rde_param_i_seq_void2value (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
	return 0;
    } else {
	p->CL = (long int) rde_stack_top (p->LS);
	rde_stack_pop (p->LS, 1);
	return 1;
    }
}

SCOPE int
rde_param_i_seq_value2value (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
	return 0;
    } else {
	long int trim = (long int) rde_stack_top (p->mark);

	rde_stack_pop  (p->mark, 1);
	rde_stack_trim (p->ast, trim);

	p->CL = (long int) rde_stack_top (p->LS);
	rde_stack_pop (p->LS, 1);
	return 1;
    }
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE int
rde_param_i_bra_void2void (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_pop (p->LS, 1);
    } else {
	p->CL = (long int) rde_stack_top (p->LS);

	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
    }

    return p->ST;
}

SCOPE int
rde_param_i_bra_void2value (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_pop (p->LS, 1);
    } else {
	rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
	p->CL = (long int) rde_stack_top (p->LS);

	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
    }

    return p->ST;
}

SCOPE int
rde_param_i_bra_value2void (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_pop (p->mark, 1);
	rde_stack_pop (p->LS, 1);
    } else {
	long int trim = (long int) rde_stack_top (p->mark);
	rde_stack_pop  (p->mark, 1);
	rde_stack_trim (p->ast, trim);

	p->CL = (long int) rde_stack_top (p->LS);

	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
    }

    return p->ST;
}

SCOPE int
rde_param_i_bra_value2value (RDE_PARAM p)
{
    rde_param_i_error_pop_merge (p);

    if (p->ST) {
	rde_stack_pop (p->mark, 1);
	rde_stack_pop (p->LS, 1);
    } else {
	long int trim = (long int) rde_stack_top (p->mark);
	rde_stack_trim (p->ast, trim);

	p->CL = (long int) rde_stack_top (p->LS);

	rde_stack_push (p->ES, p->ER);
	if (p->ER) { p->ER->refCount ++; }
    }

    return p->ST;
}

/*
 * = = == === ===== ======== ============= =====================
 */

SCOPE void
rde_param_i_next_str (RDE_PARAM p, const char* str, long int m)
{
    int at = p->CL;

    /* Future: Place match string into a shared table of constants, like error
     * messages, indexed by code. Precomputed length information.
     *
     * NOTE how we are modifying the error location after the fact. The
     * message contains the entire string, so the location should be the
     * start of the string in the input, not somewhere in the middle. This
     * matches the Tcl runtimes. Here we have to adjust the stored location
     * due to our progress through the pattern.
     */

    while (*str) {
	rde_param_i_input_next (p, m);
	if (!p->ST) {
	    p->ER->loc = at+1;
	    p->CL = at;
	    return;
	}

	rde_param_i_test_char (p, str, m);
	if (!p->ST) {
	    p->ER->loc = at+1;
	    p->CL = at;
	    return;
	}

	str = Tcl_UtfNext (str);
    }
}

SCOPE void
rde_param_i_next_class (RDE_PARAM p, const char* class, long int m)
{
    rde_param_i_input_next (p, m);
    if (!p->ST) return;

    while (*class) {
	p->ST = Tcl_UtfNcmp (p->CC, class, 1) == 0;

	if (p->ST) {
	    ER_CLEAR (p);
	    return;
	}

	class = Tcl_UtfNext (class);
    }

    error_set (p, m);
    p->CL --;
}

/*
 * = = == === ===== ======== ============= =====================
 */


/*
 * local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

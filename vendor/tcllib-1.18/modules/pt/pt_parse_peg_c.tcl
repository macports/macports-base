## -*- tcl -*-
##
## Critcl-based C/PARAM implementation of the parsing
## expression grammar
##
##	PEG
##
## Generated from file	3_peg_itself
##            for user  aku
##
# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.4
package require critcl
# @sak notprovided pt_parse_peg_c
package provide    pt_parse_peg_c 1.0.1

# Note: The implementation of the PARAM virtual machine
#       underlying the C/PARAM code used below is inlined
#       into the generated parser, allowing for direct access
#       and manipulation of the RDE state, instead of having
#       to dispatch through the Tcl interpreter.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::parse {
    # # ## ### ##### ######## ############# #####################
    ## Supporting code for the main command.

    catch {
	#critcl::cflags -g
	#critcl::debug memory symbols
    }

    # # ## ### ###### ######## #############
    ## RDE runtime, inlined, and made static.

    # This is the C code for the RDE, i.e. the implementation
    # of pt::rde. Only the low-level engine is imported, the
    # Tcl interface layer is ignored.  This generated parser
    # provides its own layer for that.

    critcl::ccode {
	/* -*- c -*- */

	#include <string.h>
	#define SCOPE static

#line 1 "rde_critcl/util.h"

	#ifndef _RDE_UTIL_H
	#define _RDE_UTIL_H 1
	#ifndef SCOPE
	#define SCOPE
	#endif
	#define ALLOC(type)    (type *) ckalloc (sizeof (type))
	#define NALLOC(n,type) (type *) ckalloc ((n) * sizeof (type))
	#undef  RDE_DEBUG
	#define RDE_DEBUG 1
	#undef  RDE_TRACE
	#ifdef RDE_DEBUG
	#define STOPAFTER(x) { static int count = (x); count --; if (!count) { Tcl_Panic ("stop"); } }
	#define XSTR(x) #x
	#define STR(x) XSTR(x)
	#define RANGEOK(i,n) ((0 <= (i)) && (i < (n)))
	#define ASSERT(x,msg) if (!(x)) { Tcl_Panic (msg " (" #x "), in file " __FILE__ " @line " STR(__LINE__));}
	#define ASSERT_BOUNDS(i,n) ASSERT (RANGEOK(i,n),"array index out of bounds: " STR(i) " >= " STR(n))
	#else
	#define STOPAFTER(x)
	#define ASSERT(x,msg)
	#define ASSERT_BOUNDS(i,n)
	#endif
	#ifdef RDE_TRACE
	SCOPE void trace_enter (const char* fun);
	SCOPE void trace_return (const char *pat, ...);
	SCOPE void trace_printf (const char *pat, ...);
	#define ENTER(fun)          trace_enter (fun)
	#define RETURN(format,x)    trace_return (format,x) ; return x
	#define RETURNVOID          trace_return ("%s","(void)") ; return
	#define TRACE0(x)           trace_printf0 x
	#define TRACE(x)            trace_printf x
	#else
	#define ENTER(fun)
	#define RETURN(f,x) return x
	#define RETURNVOID  return
	#define TRACE0(x)
	#define TRACE(x)
	#endif
	#endif 
	

#line 1 "rde_critcl/stack.h"

	#ifndef _RDE_DS_STACK_H
	#define _RDE_DS_STACK_H 1
	typedef void (*RDE_STACK_CELL_FREE) (void* cell);
	typedef struct RDE_STACK_* RDE_STACK;
	static const int RDE_STACK_INITIAL_SIZE = 256;
	#endif 
	

#line 1 "rde_critcl/tc.h"

	#ifndef _RDE_DS_TC_H
	#define _RDE_DS_TC_H 1
	typedef struct RDE_TC_* RDE_TC;
	#endif 
	

#line 1 "rde_critcl/param.h"

	#ifndef _RDE_DS_PARAM_H
	#define _RDE_DS_PARAM_H 1
	typedef struct RDE_PARAM_* RDE_PARAM;
	typedef struct ERROR_STATE {
	    int       refCount;
	    long int  loc;
	    RDE_STACK msg; 
	} ERROR_STATE;
	typedef struct NC_STATE {
	    long int     CL;
	    long int     ST;
	    Tcl_Obj*     SV;
	    ERROR_STATE* ER;
	} NC_STATE;
	#endif 
	

#line 1 "rde_critcl/util.c"

	#ifdef RDE_TRACE
	typedef struct F_STACK {
	    const char*     str;
	    struct F_STACK* down;
	} F_STACK;
	static F_STACK* top   = 0;
	static int      level = 0;
	static void
	push (const char* str)
	{
	    F_STACK* new = ALLOC (F_STACK);
	    new->str = str;
	    new->down = top;
	    top = new;
	    level += 4;
	}
	static void
	pop (void)
	{
	    F_STACK* next = top->down;
	    level -= 4;
	    ckfree ((char*)top);
	    top = next;
	}
	static void
	indent (void)
	{
	    int i;
	    for (i = 0; i < level; i++) {
		fwrite(" ", 1, 1, stdout);
		fflush           (stdout);
	    }
	    if (top) {
		fwrite(top->str, 1, strlen(top->str), stdout);
		fflush                               (stdout);
	    }
	    fwrite(" ", 1, 1, stdout);
	    fflush           (stdout);
	}
	SCOPE void
	trace_enter (const char* fun)
	{
	    push (fun);
	    indent();
	    fwrite("ENTER\n", 1, 6, stdout);
	    fflush                 (stdout);
	}
	static char msg [1024*1024];
	SCOPE void
	trace_return (const char *pat, ...)
	{
	    int len;
	    va_list args;
	    indent();
	    fwrite("RETURN = ", 1, 9, stdout);
	    fflush                   (stdout);
	    va_start(args, pat);
	    len = vsprintf(msg, pat, args);
	    va_end(args);
	    msg[len++] = '\n';
	    msg[len] = '\0';
	    fwrite(msg, 1, len, stdout);
	    fflush             (stdout);
	    pop();
	}
	SCOPE void
	trace_printf (const char *pat, ...)
	{
	    int len;
	    va_list args;
	    indent();
	    va_start(args, pat);
	    len = vsprintf(msg, pat, args);
	    va_end(args);
	    msg[len++] = '\n';
	    msg[len] = '\0';
	    fwrite(msg, 1, len, stdout);
	    fflush             (stdout);
	}
	SCOPE void
	trace_printf0 (const char *pat, ...)
	{
	    int len;
	    va_list args;
	    va_start(args, pat);
	    len = vsprintf(msg, pat, args);
	    va_end(args);
	    msg[len++] = '\n';
	    msg[len] = '\0';
	    fwrite(msg, 1, len, stdout);
	    fflush             (stdout);
	}
	#endif
	

#line 1 "rde_critcl/stack.c"

	typedef struct RDE_STACK_ {
	    long int            max;   
	    long int            top;   
	    RDE_STACK_CELL_FREE freeCellProc; 
	    void**              cell;  
	} RDE_STACK_;
	
	SCOPE RDE_STACK
	rde_stack_new (RDE_STACK_CELL_FREE freeCellProc)
	{
	    RDE_STACK s = ALLOC (RDE_STACK_);
	    s->cell = NALLOC (RDE_STACK_INITIAL_SIZE, void*);
	    s->max  = RDE_STACK_INITIAL_SIZE;
	    s->top  = 0;
	    s->freeCellProc = freeCellProc;
	    return s;
	}
	SCOPE void
	rde_stack_del (RDE_STACK s)
	{
	    if (s->freeCellProc && s->top) {
		long int i;
		for (i=0; i < s->top; i++) {
		    ASSERT_BOUNDS(i,s->max);
		    s->freeCellProc ( s->cell [i] );
		}
	    }
	    ckfree ((char*) s->cell);
	    ckfree ((char*) s);
	}
	SCOPE void
	rde_stack_push (RDE_STACK s, void* item)
	{
	    if (s->top >= s->max) {
		long int new  = s->max ? (2 * s->max) : RDE_STACK_INITIAL_SIZE;
		void**   cell = (void**) ckrealloc ((char*) s->cell, new * sizeof(void*));
		ASSERT (cell,"Memory allocation failure for RDE stack");
		s->max  = new;
		s->cell = cell;
	    }
	    ASSERT_BOUNDS(s->top,s->max);
	    s->cell [s->top] = item;
	    s->top ++;
	}
	SCOPE void*
	rde_stack_top (RDE_STACK s)
	{
	    ASSERT_BOUNDS(s->top-1,s->max);
	    return s->cell [s->top - 1];
	}
	SCOPE void
	rde_stack_pop (RDE_STACK s, long int n)
	{
	    ASSERT (n >= 0, "Bad pop count");
	    if (n == 0) return;
	    if (s->freeCellProc) {
		while (n) {
		    s->top --;
		    ASSERT_BOUNDS(s->top,s->max);
		    s->freeCellProc ( s->cell [s->top] );
		    n --;
		}
	    } else {
		s->top -= n;
	    }
	}
	SCOPE void
	rde_stack_trim (RDE_STACK s, long int n)
	{
	    ASSERT (n >= 0, "Bad trimsize");
	    if (s->freeCellProc) {
		while (s->top > n) {
		    s->top --;
		    ASSERT_BOUNDS(s->top,s->max);
		    s->freeCellProc ( s->cell [s->top] );
		}
	    } else {
		s->top = n;
	    }
	}
	SCOPE void
	rde_stack_drop (RDE_STACK s, long int n)
	{
	    ASSERT (n >= 0, "Bad pop count");
	    if (n == 0) return;
	    s->top -= n;
	}
	SCOPE void
	rde_stack_move (RDE_STACK dst, RDE_STACK src)
	{
	    ASSERT (dst->freeCellProc == src->freeCellProc, "Ownership mismatch");
	    
	    while (src->top > 0) {
		src->top --;
		ASSERT_BOUNDS(src->top,src->max);
		rde_stack_push (dst, src->cell [src->top] );
	    }
	}
	SCOPE void
	rde_stack_get (RDE_STACK s, long int* cn, void*** cc)
	{
	    *cn = s->top;
	    *cc = s->cell;
	}
	SCOPE long int
	rde_stack_size (RDE_STACK s)
	{
	    return s->top;
	}
	

#line 1 "rde_critcl/tc.c"

	typedef struct RDE_TC_ {
	    int       max;   
	    int       num;   
	    char*     str;   
	    RDE_STACK off;   
	} RDE_TC_;
	
	SCOPE RDE_TC
	rde_tc_new (void)
	{
	    RDE_TC tc = ALLOC (RDE_TC_);
	    tc->max   = RDE_STACK_INITIAL_SIZE;
	    tc->num   = 0;
	    tc->str   = NALLOC (RDE_STACK_INITIAL_SIZE, char);
	    tc->off   = rde_stack_new (NULL);
	    return tc;
	}
	SCOPE void
	rde_tc_del (RDE_TC tc)
	{
	    rde_stack_del (tc->off);
	    ckfree (tc->str);
	    ckfree ((char*) tc);
	}
	SCOPE long int
	rde_tc_size (RDE_TC tc)
	{
	    return rde_stack_size (tc->off);
	}
	SCOPE void
	rde_tc_clear (RDE_TC tc)
	{
	    tc->num   = 0;
	    rde_stack_trim (tc->off,  0);
	}
	SCOPE char*
	rde_tc_append (RDE_TC tc, char* string, long int len)
	{
	    long int base = tc->num;
	    long int off  = tc->num;
	    char* ch;
	    int clen;
	    Tcl_UniChar uni;
	    if (len < 0) {
		len = strlen (string);
	    }
	    
	    if (!len) {
		return tc->str + base;
	    }
	    
	    if ((tc->num + len) >= tc->max) {
		int   new = len + (tc->max ? (2 * tc->max) : RDE_STACK_INITIAL_SIZE);
		char* str = ckrealloc (tc->str, new * sizeof(char));
		ASSERT (str,"Memory allocation failure for token character array");
		tc->max = new;
		tc->str = str;
	    }
	    tc->num += len;
	    ASSERT_BOUNDS(tc->num,tc->max);
	    ASSERT_BOUNDS(off,tc->max);
	    ASSERT_BOUNDS(off+len-1,tc->max);
	    ASSERT_BOUNDS(off+len-1,tc->num);
	    memcpy (tc->str + off, string, len);
	    
	    ch = string;
	    while (ch < (string + len)) {
		ASSERT_BOUNDS(off,tc->num);
		rde_stack_push (tc->off,  (void*) off);
		clen = Tcl_UtfToUniChar (ch, &uni);
		off += clen;
		ch  += clen;
	    }
	    return tc->str + base;
	}
	SCOPE void
	rde_tc_get (RDE_TC tc, int at, char** ch, long int* len)
	{
	    long int  oc, off, top, end;
	    void** ov;
	    rde_stack_get (tc->off, &oc, &ov);
	    ASSERT_BOUNDS(at,oc);
	    off = (long int) ov [at];
	    if ((at+1) == oc) {
		end = tc->num;
	    } else {
		end = (long int) ov [at+1];
	    }
	    TRACE (("rde_tc_get (RDE_TC %p, @ %d) => %d.[%d ... %d]/%d",tc,at,end-off,off,end-1,tc->num));
	    ASSERT_BOUNDS(off,tc->num);
	    ASSERT_BOUNDS(end-1,tc->num);
	    *ch = tc->str + off;
	    *len = end - off;
	}
	SCOPE void
	rde_tc_get_s (RDE_TC tc, int at, int last, char** ch, long int* len)
	{
	    long int  oc, off, top, end;
	    void** ov;
	    rde_stack_get (tc->off, &oc, &ov);
	    ASSERT_BOUNDS(at,oc);
	    ASSERT_BOUNDS(last,oc);
	    off = (long int) ov [at];
	    if ((last+1) == oc) {
		end = tc->num;
	    } else {
		end = (long int) ov [last+1];
	    }
	    TRACE (("rde_tc_get_s (RDE_TC %p, @ %d .. %d) => %d.[%d ... %d]/%d",tc,at,last,end-off,off,end-1,tc->num));
	    ASSERT_BOUNDS(off,tc->num);
	    ASSERT_BOUNDS(end-1,tc->num);
	    *ch = tc->str + off;
	    *len = end - off;
	}
	

#line 1 "rde_critcl/param.c"

	typedef struct RDE_PARAM_ {
	    Tcl_Channel   IN;
	    Tcl_Obj*      readbuf;
	    char*         CC; 
	    long int      CC_len;
	    RDE_TC        TC;
	    long int      CL;
	    RDE_STACK     LS; 
	    ERROR_STATE*  ER;
	    RDE_STACK     ES; 
	    long int      ST;
	    Tcl_Obj*      SV;
	    Tcl_HashTable NC;
	    
	    RDE_STACK    ast  ; 
	    RDE_STACK    mark ; 
	    
	    long int numstr; 
	    char**  string;
	    
	    ClientData clientData;
	} RDE_PARAM_;
	typedef int (*UniCharClass) (int);
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
	static void ast_node_free    (void* n);
	static void error_state_free (void* es);
	static void error_set        (RDE_PARAM p, long int s);
	static void nc_clear         (RDE_PARAM p);
	static int UniCharIsAscii    (int character);
	static int UniCharIsHexDigit (int character);
	static int UniCharIsDecDigit (int character);
	static void test_class (RDE_PARAM p, UniCharClass class, test_class_id id);
	static int  er_int_compare (const void* a, const void* b);
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
		
		res = Tcl_NewStringObj ("", 0);
	    } else {
		Tcl_Obj* ov [2];
		Tcl_Obj** mov;
		long int  mc, i, j;
		void** mv;
		int lastid;
		const char* msg;
		rde_stack_get (er->msg, &mc, &mv);
		
		qsort (mv, mc, sizeof (void*), er_int_compare);
		
		mov = NALLOC (mc, Tcl_Obj*);
		lastid = -1;
		for (i=0, j=0; i < mc; i++) {
		    ASSERT_BOUNDS (i,mc);
		    if (((long int) mv [i]) == lastid) continue;
		    lastid = (long int) mv [i];
		    ASSERT_BOUNDS((long int) mv[i],p->numstr);
		    msg = p->string [(long int) mv[i]]; 
		    ASSERT_BOUNDS (j,mc);
		    mov [j] = Tcl_NewStringObj (msg, -1);
		    j++;
		}
		
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
	SCOPE void
	rde_param_i_error_clear (RDE_PARAM p)
	{
	    ER_CLEAR (p);
	}
	SCOPE void
	rde_param_i_error_nonterminal (RDE_PARAM p, long int s)
	{
	    
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
	    
	    if (top == p->ER) {
		rde_stack_pop (p->ES, 1);
		return;
	    }
	    
	    if (!top) {
		rde_stack_pop (p->ES, 1);
		return;
	    }
	    
	    if (!p->ER) {
		rde_stack_drop (p->ES, 1);
		p->ER = top;
		
		return;
	    }
	    
	    if (top->loc < p->ER->loc) {
		rde_stack_pop (p->ES, 1);
		return;
	    }
	    
	    if (top->loc > p->ER->loc) {
		rde_stack_drop (p->ES, 1);
		error_state_free (p->ER);
		p->ER = top;
		
		return;
	    }
	    
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
	SCOPE void
	rde_param_i_input_next (RDE_PARAM p, long int m)
	{
	    int leni;
	    char* ch;
	    ASSERT_BOUNDS(m,p->numstr);
	    p->CL ++;
	    if (p->CL < rde_tc_size (p->TC)) {
		
		rde_tc_get (p->TC, p->CL, &p->CC, &p->CC_len);
		
		ASSERT_BOUNDS (p->CC_len-1, TCL_UTF_MAX);
		p->ST = 1;
		ER_CLEAR (p);
		return;
	    }
	    if (!p->IN || 
		Tcl_Eof (p->IN) ||
		(Tcl_ReadChars (p->IN, p->readbuf, 1, 0) <= 0)) {
		
		p->ST = 0;
		error_set (p, m);
		return;
	    }
	    
	    ch = Tcl_GetStringFromObj (p->readbuf, &leni);
	    ASSERT_BOUNDS (leni, TCL_UTF_MAX);
	    p->CC = rde_tc_append (p->TC, ch, leni);
	    p->CC_len = leni;
	    p->ST = 1;
	    ER_CLEAR (p);
	}
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
	SCOPE int 
	rde_param_i_symbol_restore (RDE_PARAM p, long int s)
	{
	    NC_STATE*      scs;
	    Tcl_HashEntry* hPtr;
	    Tcl_HashTable* tablePtr;
	    
	    hPtr = Tcl_FindHashEntry (&p->NC, (char*) p->CL);
	    if (!hPtr) { return 0; }
	    tablePtr = (Tcl_HashTable*) Tcl_GetHashValue (hPtr);
	    hPtr = Tcl_FindHashEntry (tablePtr, (char*) s);
	    if (!hPtr) { return 0; }
	    
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
	    int       oc, i, j;
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
	static int
	er_int_compare (const void* a, const void* b)
	{
	    
	    const void** ael = (const void**) a;
	    const void** bel = (const void**) b;
	    long int avalue = (long int) *ael;
	    long int bvalue = (long int) *bel;
	    if (avalue < bvalue) { return -1; }
	    if (avalue > bvalue) { return  1; }
	    return 0;
	}
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
	SCOPE void
	rde_param_i_state_push_2 (RDE_PARAM p)
	{
	    
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
	    
	}
	SCOPE void
	rde_param_i_state_push_value (RDE_PARAM p)
	{
	    rde_stack_push (p->mark, (void*) rde_stack_size (p->ast));
	    rde_stack_push (p->LS, (void*) p->CL);
	    ER_CLEAR (p);
	    rde_stack_push (p->ES, p->ER);
	    
	}
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
	SCOPE void
	rde_param_i_next_str (RDE_PARAM p, const char* str, long int m)
	{
	    int at = p->CL;
	    
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
	

    }

    # # ## ### ###### ######## #############
    ## BEGIN of GENERATED CODE. DO NOT EDIT.

    critcl::ccode {
	/* -*- c -*- */

        /*
         * Declaring the parse functions
         */
        
        static void sequence_4 (RDE_PARAM p);
        static void sym_ALNUM (RDE_PARAM p);
        static void sequence_9 (RDE_PARAM p);
        static void sym_ALPHA (RDE_PARAM p);
        static void sequence_14 (RDE_PARAM p);
        static void sym_AND (RDE_PARAM p);
        static void sym_APOSTROPH (RDE_PARAM p);
        static void sequence_21 (RDE_PARAM p);
        static void sym_ASCII (RDE_PARAM p);
        static void choice_26 (RDE_PARAM p);
        static void sequence_29 (RDE_PARAM p);
        static void sym_Attribute (RDE_PARAM p);
        static void choice_37 (RDE_PARAM p);
        static void sym_Char (RDE_PARAM p);
        static void sequence_44 (RDE_PARAM p);
        static void sym_CharOctalFull (RDE_PARAM p);
        static void optional_50 (RDE_PARAM p);
        static void sequence_52 (RDE_PARAM p);
        static void sym_CharOctalPart (RDE_PARAM p);
        static void sequence_57 (RDE_PARAM p);
        static void sym_CharSpecial (RDE_PARAM p);
        static void notahead_61 (RDE_PARAM p);
        static void sequence_64 (RDE_PARAM p);
        static void sym_CharUnescaped (RDE_PARAM p);
        static void optional_72 (RDE_PARAM p);
        static void sequence_74 (RDE_PARAM p);
        static void optional_76 (RDE_PARAM p);
        static void sequence_78 (RDE_PARAM p);
        static void optional_80 (RDE_PARAM p);
        static void sequence_82 (RDE_PARAM p);
        static void sym_CharUnicode (RDE_PARAM p);
        static void notahead_87 (RDE_PARAM p);
        static void sequence_90 (RDE_PARAM p);
        static void kleene_92 (RDE_PARAM p);
        static void sequence_96 (RDE_PARAM p);
        static void sym_Class (RDE_PARAM p);
        static void sequence_101 (RDE_PARAM p);
        static void sym_CLOSE (RDE_PARAM p);
        static void sym_CLOSEB (RDE_PARAM p);
        static void sequence_108 (RDE_PARAM p);
        static void sym_COLON (RDE_PARAM p);
        static void notahead_113 (RDE_PARAM p);
        static void sequence_116 (RDE_PARAM p);
        static void kleene_118 (RDE_PARAM p);
        static void sequence_121 (RDE_PARAM p);
        static void sym_COMMENT (RDE_PARAM p);
        static void sequence_126 (RDE_PARAM p);
        static void sym_CONTROL (RDE_PARAM p);
        static void sym_DAPOSTROPH (RDE_PARAM p);
        static void sequence_133 (RDE_PARAM p);
        static void sym_DDIGIT (RDE_PARAM p);
        static void optional_137 (RDE_PARAM p);
        static void sequence_143 (RDE_PARAM p);
        static void sym_Definition (RDE_PARAM p);
        static void sequence_148 (RDE_PARAM p);
        static void sym_DIGIT (RDE_PARAM p);
        static void sequence_153 (RDE_PARAM p);
        static void sym_DOT (RDE_PARAM p);
        static void notahead_157 (RDE_PARAM p);
        static void sym_EOF (RDE_PARAM p);
        static void sym_EOL (RDE_PARAM p);
        static void sequence_165 (RDE_PARAM p);
        static void kleene_167 (RDE_PARAM p);
        static void sequence_169 (RDE_PARAM p);
        static void sym_Expression (RDE_PARAM p);
        static void sequence_176 (RDE_PARAM p);
        static void sym_Final (RDE_PARAM p);
        static void kleene_182 (RDE_PARAM p);
        static void sequence_186 (RDE_PARAM p);
        static void sym_Grammar (RDE_PARAM p);
        static void sequence_191 (RDE_PARAM p);
        static void sym_GRAPH (RDE_PARAM p);
        static void sequence_197 (RDE_PARAM p);
        static void sym_Header (RDE_PARAM p);
        static void choice_202 (RDE_PARAM p);
        static void choice_206 (RDE_PARAM p);
        static void kleene_208 (RDE_PARAM p);
        static void sequence_210 (RDE_PARAM p);
        static void sym_Ident (RDE_PARAM p);
        static void sequence_215 (RDE_PARAM p);
        static void sym_Identifier (RDE_PARAM p);
        static void sequence_220 (RDE_PARAM p);
        static void sym_IS (RDE_PARAM p);
        static void sequence_225 (RDE_PARAM p);
        static void sym_LEAF (RDE_PARAM p);
        static void notahead_230 (RDE_PARAM p);
        static void sequence_233 (RDE_PARAM p);
        static void kleene_235 (RDE_PARAM p);
        static void sequence_239 (RDE_PARAM p);
        static void notahead_243 (RDE_PARAM p);
        static void sequence_246 (RDE_PARAM p);
        static void kleene_248 (RDE_PARAM p);
        static void sequence_252 (RDE_PARAM p);
        static void choice_254 (RDE_PARAM p);
        static void sym_Literal (RDE_PARAM p);
        static void sequence_259 (RDE_PARAM p);
        static void sym_LOWER (RDE_PARAM p);
        static void sequence_264 (RDE_PARAM p);
        static void sym_NOT (RDE_PARAM p);
        static void sequence_269 (RDE_PARAM p);
        static void sym_OPEN (RDE_PARAM p);
        static void sym_OPENB (RDE_PARAM p);
        static void notahead_278 (RDE_PARAM p);
        static void sequence_281 (RDE_PARAM p);
        static void sym_PEG (RDE_PARAM p);
        static void sequence_286 (RDE_PARAM p);
        static void sym_PLUS (RDE_PARAM p);
        static void choice_291 (RDE_PARAM p);
        static void optional_293 (RDE_PARAM p);
        static void sequence_296 (RDE_PARAM p);
        static void sym_Prefix (RDE_PARAM p);
        static void sequence_317 (RDE_PARAM p);
        static void choice_322 (RDE_PARAM p);
        static void sym_Primary (RDE_PARAM p);
        static void sequence_327 (RDE_PARAM p);
        static void sym_PRINTABLE (RDE_PARAM p);
        static void sequence_332 (RDE_PARAM p);
        static void sym_PUNCT (RDE_PARAM p);
        static void sequence_337 (RDE_PARAM p);
        static void sym_QUESTION (RDE_PARAM p);
        static void sequence_343 (RDE_PARAM p);
        static void choice_346 (RDE_PARAM p);
        static void sym_Range (RDE_PARAM p);
        static void sequence_351 (RDE_PARAM p);
        static void sym_SEMICOLON (RDE_PARAM p);
        static void poskleene_355 (RDE_PARAM p);
        static void sym_Sequence (RDE_PARAM p);
        static void sequence_360 (RDE_PARAM p);
        static void sym_SLASH (RDE_PARAM p);
        static void sequence_365 (RDE_PARAM p);
        static void sym_SPACE (RDE_PARAM p);
        static void sequence_370 (RDE_PARAM p);
        static void sym_STAR (RDE_PARAM p);
        static void sym_StartExpr (RDE_PARAM p);
        static void choice_382 (RDE_PARAM p);
        static void optional_384 (RDE_PARAM p);
        static void sequence_386 (RDE_PARAM p);
        static void sym_Suffix (RDE_PARAM p);
        static void sym_TO (RDE_PARAM p);
        static void sequence_393 (RDE_PARAM p);
        static void sym_UPPER (RDE_PARAM p);
        static void sequence_398 (RDE_PARAM p);
        static void sym_VOID (RDE_PARAM p);
        static void choice_403 (RDE_PARAM p);
        static void kleene_405 (RDE_PARAM p);
        static void sym_WHITESPACE (RDE_PARAM p);
        static void sequence_410 (RDE_PARAM p);
        static void sym_WORDCHAR (RDE_PARAM p);
        static void sequence_415 (RDE_PARAM p);
        static void sym_XDIGIT (RDE_PARAM p);
        
        /*
         * Precomputed table of strings (symbols, error messages, etc.).
         */
        
        static char const* p_string [178] = {
            /*        0 = */   "alnum",
            /*        1 = */   "alpha",
            /*        2 = */   "ascii",
            /*        3 = */   "control",
            /*        4 = */   "ddigit",
            /*        5 = */   "digit",
            /*        6 = */   "graph",
            /*        7 = */   "lower",
            /*        8 = */   "print",
            /*        9 = */   "punct",
            /*       10 = */   "space",
            /*       11 = */   "upper",
            /*       12 = */   "wordchar",
            /*       13 = */   "xdigit",
            /*       14 = */   "str <alnum>",
            /*       15 = */   "n ALNUM",
            /*       16 = */   "ALNUM",
            /*       17 = */   "str <alpha>",
            /*       18 = */   "n ALPHA",
            /*       19 = */   "ALPHA",
            /*       20 = */   "t &",
            /*       21 = */   "n AND",
            /*       22 = */   "AND",
            /*       23 = */   "t '",
            /*       24 = */   "n APOSTROPH",
            /*       25 = */   "APOSTROPH",
            /*       26 = */   "str <ascii>",
            /*       27 = */   "n ASCII",
            /*       28 = */   "ASCII",
            /*       29 = */   "n Attribute",
            /*       30 = */   "Attribute",
            /*       31 = */   "n Char",
            /*       32 = */   "Char",
            /*       33 = */   "t \\\\",
            /*       34 = */   ".. 0 2",
            /*       35 = */   ".. 0 7",
            /*       36 = */   "n CharOctalFull",
            /*       37 = */   "CharOctalFull",
            /*       38 = */   "n CharOctalPart",
            /*       39 = */   "CharOctalPart",
            /*       40 = */   "cl nrt'\\\"\\[\\]\\\\",
            /*       41 = */   "n CharSpecial",
            /*       42 = */   "CharSpecial",
            /*       43 = */   "dot",
            /*       44 = */   "n CharUnescaped",
            /*       45 = */   "CharUnescaped",
            /*       46 = */   "str \173\\u\175",
            /*       47 = */   "n CharUnicode",
            /*       48 = */   "CharUnicode",
            /*       49 = */   "n Class",
            /*       50 = */   "Class",
            /*       51 = */   "t )",
            /*       52 = */   "n CLOSE",
            /*       53 = */   "CLOSE",
            /*       54 = */   "t \\]",
            /*       55 = */   "n CLOSEB",
            /*       56 = */   "CLOSEB",
            /*       57 = */   "t :",
            /*       58 = */   "n COLON",
            /*       59 = */   "COLON",
            /*       60 = */   "t #",
            /*       61 = */   "n COMMENT",
            /*       62 = */   "COMMENT",
            /*       63 = */   "str <control>",
            /*       64 = */   "n CONTROL",
            /*       65 = */   "CONTROL",
            /*       66 = */   "t \173\"\175",
            /*       67 = */   "n DAPOSTROPH",
            /*       68 = */   "DAPOSTROPH",
            /*       69 = */   "str <ddigit>",
            /*       70 = */   "n DDIGIT",
            /*       71 = */   "DDIGIT",
            /*       72 = */   "n Definition",
            /*       73 = */   "Definition",
            /*       74 = */   "str <digit>",
            /*       75 = */   "n DIGIT",
            /*       76 = */   "DIGIT",
            /*       77 = */   "t .",
            /*       78 = */   "n DOT",
            /*       79 = */   "DOT",
            /*       80 = */   "n EOF",
            /*       81 = */   "EOF",
            /*       82 = */   "cl \173\n\r\175",
            /*       83 = */   "n EOL",
            /*       84 = */   "EOL",
            /*       85 = */   "n Expression",
            /*       86 = */   "Expression",
            /*       87 = */   "str END",
            /*       88 = */   "n Final",
            /*       89 = */   "Final",
            /*       90 = */   "n Grammar",
            /*       91 = */   "Grammar",
            /*       92 = */   "str <graph>",
            /*       93 = */   "n GRAPH",
            /*       94 = */   "GRAPH",
            /*       95 = */   "n Header",
            /*       96 = */   "Header",
            /*       97 = */   "cl _:",
            /*       98 = */   "n Ident",
            /*       99 = */   "Ident",
            /*      100 = */   "n Identifier",
            /*      101 = */   "Identifier",
            /*      102 = */   "str <-",
            /*      103 = */   "n IS",
            /*      104 = */   "IS",
            /*      105 = */   "str leaf",
            /*      106 = */   "n LEAF",
            /*      107 = */   "LEAF",
            /*      108 = */   "n Literal",
            /*      109 = */   "Literal",
            /*      110 = */   "str <lower>",
            /*      111 = */   "n LOWER",
            /*      112 = */   "LOWER",
            /*      113 = */   "t !",
            /*      114 = */   "n NOT",
            /*      115 = */   "NOT",
            /*      116 = */   "t (",
            /*      117 = */   "n OPEN",
            /*      118 = */   "OPEN",
            /*      119 = */   "t \173[\175",
            /*      120 = */   "n OPENB",
            /*      121 = */   "OPENB",
            /*      122 = */   "str PEG",
            /*      123 = */   "n PEG",
            /*      124 = */   "PEG",
            /*      125 = */   "t +",
            /*      126 = */   "n PLUS",
            /*      127 = */   "PLUS",
            /*      128 = */   "n Prefix",
            /*      129 = */   "Prefix",
            /*      130 = */   "n Primary",
            /*      131 = */   "Primary",
            /*      132 = */   "str <print>",
            /*      133 = */   "n PRINTABLE",
            /*      134 = */   "PRINTABLE",
            /*      135 = */   "str <punct>",
            /*      136 = */   "n PUNCT",
            /*      137 = */   "PUNCT",
            /*      138 = */   "t ?",
            /*      139 = */   "n QUESTION",
            /*      140 = */   "QUESTION",
            /*      141 = */   "n Range",
            /*      142 = */   "Range",
            /*      143 = */   "t \173;\175",
            /*      144 = */   "n SEMICOLON",
            /*      145 = */   "SEMICOLON",
            /*      146 = */   "n Sequence",
            /*      147 = */   "Sequence",
            /*      148 = */   "t /",
            /*      149 = */   "n SLASH",
            /*      150 = */   "SLASH",
            /*      151 = */   "str <space>",
            /*      152 = */   "n SPACE",
            /*      153 = */   "SPACE",
            /*      154 = */   "t *",
            /*      155 = */   "n STAR",
            /*      156 = */   "STAR",
            /*      157 = */   "n StartExpr",
            /*      158 = */   "StartExpr",
            /*      159 = */   "n Suffix",
            /*      160 = */   "Suffix",
            /*      161 = */   "t -",
            /*      162 = */   "n TO",
            /*      163 = */   "TO",
            /*      164 = */   "str <upper>",
            /*      165 = */   "n UPPER",
            /*      166 = */   "UPPER",
            /*      167 = */   "str void",
            /*      168 = */   "n VOID",
            /*      169 = */   "VOID",
            /*      170 = */   "n WHITESPACE",
            /*      171 = */   "WHITESPACE",
            /*      172 = */   "str <wordchar>",
            /*      173 = */   "n WORDCHAR",
            /*      174 = */   "WORDCHAR",
            /*      175 = */   "str <xdigit>",
            /*      176 = */   "n XDIGIT",
            /*      177 = */   "XDIGIT"
        };
        
        /*
         * Grammar Start Expression
         */
        
        static void MAIN (RDE_PARAM p) {
            sym_Grammar (p);
            return;
        }
        
        /*
         * leaf Symbol 'ALNUM'
         */
        
        static void sym_ALNUM (RDE_PARAM p) {
           /*
            * x
            *     "<alnum>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 16)) return ;
            sequence_4 (p);
            rde_param_i_symbol_done_leaf (p, 16, 15);
            return;
        }
        
        static void sequence_4 (RDE_PARAM p) {
           /*
            * x
            *     "<alnum>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<alnum>", 14);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'ALPHA'
         */
        
        static void sym_ALPHA (RDE_PARAM p) {
           /*
            * x
            *     "<alpha>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 19)) return ;
            sequence_9 (p);
            rde_param_i_symbol_done_leaf (p, 19, 18);
            return;
        }
        
        static void sequence_9 (RDE_PARAM p) {
           /*
            * x
            *     "<alpha>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<alpha>", 17);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'AND'
         */
        
        static void sym_AND (RDE_PARAM p) {
           /*
            * x
            *     '&'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 22)) return ;
            sequence_14 (p);
            rde_param_i_symbol_done_leaf (p, 22, 21);
            return;
        }
        
        static void sequence_14 (RDE_PARAM p) {
           /*
            * x
            *     '&'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "&", 20);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'APOSTROPH'
         */
        
        static void sym_APOSTROPH (RDE_PARAM p) {
           /*
            * '''
            */
        
            if (rde_param_i_symbol_void_start (p, 25)) return ;
            rde_param_i_next_char (p, "'", 23);
            rde_param_i_symbol_done_void (p, 25, 24);
            return;
        }
        
        /*
         * leaf Symbol 'ASCII'
         */
        
        static void sym_ASCII (RDE_PARAM p) {
           /*
            * x
            *     "<ascii>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 28)) return ;
            sequence_21 (p);
            rde_param_i_symbol_done_leaf (p, 28, 27);
            return;
        }
        
        static void sequence_21 (RDE_PARAM p) {
           /*
            * x
            *     "<ascii>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<ascii>", 26);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Attribute'
         */
        
        static void sym_Attribute (RDE_PARAM p) {
           /*
            * x
            *     /
            *         (VOID)
            *         (LEAF)
            *     (COLON)
            */
        
            if (rde_param_i_symbol_start_d (p, 30)) return ;
            sequence_29 (p);
            rde_param_i_symbol_done_d_reduce (p, 30, 29);
            return;
        }
        
        static void sequence_29 (RDE_PARAM p) {
           /*
            * x
            *     /
            *         (VOID)
            *         (LEAF)
            *     (COLON)
            */
        
            rde_param_i_state_push_value (p);
            choice_26 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_COLON (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void choice_26 (RDE_PARAM p) {
           /*
            * /
            *     (VOID)
            *     (LEAF)
            */
        
            rde_param_i_state_push_value (p);
            sym_VOID (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_LEAF (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * value Symbol 'Char'
         */
        
        static void sym_Char (RDE_PARAM p) {
           /*
            * /
            *     (CharSpecial)
            *     (CharOctalFull)
            *     (CharOctalPart)
            *     (CharUnicode)
            *     (CharUnescaped)
            */
        
            if (rde_param_i_symbol_start_d (p, 32)) return ;
            choice_37 (p);
            rde_param_i_symbol_done_d_reduce (p, 32, 31);
            return;
        }
        
        static void choice_37 (RDE_PARAM p) {
           /*
            * /
            *     (CharSpecial)
            *     (CharOctalFull)
            *     (CharOctalPart)
            *     (CharUnicode)
            *     (CharUnescaped)
            */
        
            rde_param_i_state_push_value (p);
            sym_CharSpecial (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_CharOctalFull (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_CharOctalPart (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_CharUnicode (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_CharUnescaped (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * leaf Symbol 'CharOctalFull'
         */
        
        static void sym_CharOctalFull (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     range (0 .. 2)
            *     range (0 .. 7)
            *     range (0 .. 7)
            */
        
            if (rde_param_i_symbol_start (p, 37)) return ;
            sequence_44 (p);
            rde_param_i_symbol_done_leaf (p, 37, 36);
            return;
        }
        
        static void sequence_44 (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     range (0 .. 2)
            *     range (0 .. 7)
            *     range (0 .. 7)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "\\", 33);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_range (p, "0", "2", 34);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_range (p, "0", "7", 35);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_range (p, "0", "7", 35);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'CharOctalPart'
         */
        
        static void sym_CharOctalPart (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     range (0 .. 7)
            *     ?
            *         range (0 .. 7)
            */
        
            if (rde_param_i_symbol_start (p, 39)) return ;
            sequence_52 (p);
            rde_param_i_symbol_done_leaf (p, 39, 38);
            return;
        }
        
        static void sequence_52 (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     range (0 .. 7)
            *     ?
            *         range (0 .. 7)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "\\", 33);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_range (p, "0", "7", 35);
            if (rde_param_i_seq_void2void(p)) return;
            optional_50 (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void optional_50 (RDE_PARAM p) {
           /*
            * ?
            *     range (0 .. 7)
            */
        
            rde_param_i_state_push_2 (p);
            rde_param_i_next_range (p, "0", "7", 35);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        /*
         * leaf Symbol 'CharSpecial'
         */
        
        static void sym_CharSpecial (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     [nrt'\"[]\]
            */
        
            if (rde_param_i_symbol_start (p, 42)) return ;
            sequence_57 (p);
            rde_param_i_symbol_done_leaf (p, 42, 41);
            return;
        }
        
        static void sequence_57 (RDE_PARAM p) {
           /*
            * x
            *     '\'
            *     [nrt'\"[]\]
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "\\", 33);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_class (p, "nrt'\"[]\\", 40);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'CharUnescaped'
         */
        
        static void sym_CharUnescaped (RDE_PARAM p) {
           /*
            * x
            *     !
            *         '\'
            *     <dot>
            */
        
            if (rde_param_i_symbol_start (p, 45)) return ;
            sequence_64 (p);
            rde_param_i_symbol_done_leaf (p, 45, 44);
            return;
        }
        
        static void sequence_64 (RDE_PARAM p) {
           /*
            * x
            *     !
            *         '\'
            *     <dot>
            */
        
            rde_param_i_state_push_void (p);
            notahead_61 (p);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_input_next (p, 43);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void notahead_61 (RDE_PARAM p) {
           /*
            * !
            *     '\'
            */
        
            rde_param_i_loc_push (p);
            rde_param_i_next_char (p, "\\", 33);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * leaf Symbol 'CharUnicode'
         */
        
        static void sym_CharUnicode (RDE_PARAM p) {
           /*
            * x
            *     "\u"
            *     <xdigit>
            *     ?
            *         x
            *             <xdigit>
            *             ?
            *                 x
            *                     <xdigit>
            *                     ?
            *                         <xdigit>
            */
        
            if (rde_param_i_symbol_start (p, 48)) return ;
            sequence_82 (p);
            rde_param_i_symbol_done_leaf (p, 48, 47);
            return;
        }
        
        static void sequence_82 (RDE_PARAM p) {
           /*
            * x
            *     "\u"
            *     <xdigit>
            *     ?
            *         x
            *             <xdigit>
            *             ?
            *                 x
            *                     <xdigit>
            *                     ?
            *                         <xdigit>
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "\\u", 46);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_next_xdigit (p, 13);
            if (rde_param_i_seq_void2void(p)) return;
            optional_80 (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void optional_80 (RDE_PARAM p) {
           /*
            * ?
            *     x
            *         <xdigit>
            *         ?
            *             x
            *                 <xdigit>
            *                 ?
            *                     <xdigit>
            */
        
            rde_param_i_state_push_2 (p);
            sequence_78 (p);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        static void sequence_78 (RDE_PARAM p) {
           /*
            * x
            *     <xdigit>
            *     ?
            *         x
            *             <xdigit>
            *             ?
            *                 <xdigit>
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_xdigit (p, 13);
            if (rde_param_i_seq_void2void(p)) return;
            optional_76 (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void optional_76 (RDE_PARAM p) {
           /*
            * ?
            *     x
            *         <xdigit>
            *         ?
            *             <xdigit>
            */
        
            rde_param_i_state_push_2 (p);
            sequence_74 (p);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        static void sequence_74 (RDE_PARAM p) {
           /*
            * x
            *     <xdigit>
            *     ?
            *         <xdigit>
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_xdigit (p, 13);
            if (rde_param_i_seq_void2void(p)) return;
            optional_72 (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void optional_72 (RDE_PARAM p) {
           /*
            * ?
            *     <xdigit>
            */
        
            rde_param_i_state_push_2 (p);
            rde_param_i_next_xdigit (p, 13);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        /*
         * value Symbol 'Class'
         */
        
        static void sym_Class (RDE_PARAM p) {
           /*
            * x
            *     (OPENB)
            *     *
            *         x
            *             !
            *                 (CLOSEB)
            *             (Range)
            *     (CLOSEB)
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start_d (p, 50)) return ;
            sequence_96 (p);
            rde_param_i_symbol_done_d_reduce (p, 50, 49);
            return;
        }
        
        static void sequence_96 (RDE_PARAM p) {
           /*
            * x
            *     (OPENB)
            *     *
            *         x
            *             !
            *                 (CLOSEB)
            *             (Range)
            *     (CLOSEB)
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            sym_OPENB (p);
            if (rde_param_i_seq_void2value(p)) return;
            kleene_92 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_CLOSEB (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void kleene_92 (RDE_PARAM p) {
           /*
            * *
            *     x
            *         !
            *             (CLOSEB)
            *         (Range)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sequence_90 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void sequence_90 (RDE_PARAM p) {
           /*
            * x
            *     !
            *         (CLOSEB)
            *     (Range)
            */
        
            rde_param_i_state_push_void (p);
            notahead_87 (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Range (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void notahead_87 (RDE_PARAM p) {
           /*
            * !
            *     (CLOSEB)
            */
        
            rde_param_i_loc_push (p);
            sym_CLOSEB (p);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * void Symbol 'CLOSE'
         */
        
        static void sym_CLOSE (RDE_PARAM p) {
           /*
            * x
            *     '\)'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 53)) return ;
            sequence_101 (p);
            rde_param_i_symbol_done_void (p, 53, 52);
            return;
        }
        
        static void sequence_101 (RDE_PARAM p) {
           /*
            * x
            *     '\)'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, ")", 51);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'CLOSEB'
         */
        
        static void sym_CLOSEB (RDE_PARAM p) {
           /*
            * ']'
            */
        
            if (rde_param_i_symbol_void_start (p, 56)) return ;
            rde_param_i_next_char (p, "]", 54);
            rde_param_i_symbol_done_void (p, 56, 55);
            return;
        }
        
        /*
         * void Symbol 'COLON'
         */
        
        static void sym_COLON (RDE_PARAM p) {
           /*
            * x
            *     ':'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 59)) return ;
            sequence_108 (p);
            rde_param_i_symbol_done_void (p, 59, 58);
            return;
        }
        
        static void sequence_108 (RDE_PARAM p) {
           /*
            * x
            *     ':'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, ":", 57);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'COMMENT'
         */
        
        static void sym_COMMENT (RDE_PARAM p) {
           /*
            * x
            *     '#'
            *     *
            *         x
            *             !
            *                 (EOL)
            *             <dot>
            *     (EOL)
            */
        
            if (rde_param_i_symbol_void_start (p, 62)) return ;
            sequence_121 (p);
            rde_param_i_symbol_done_void (p, 62, 61);
            return;
        }
        
        static void sequence_121 (RDE_PARAM p) {
           /*
            * x
            *     '#'
            *     *
            *         x
            *             !
            *                 (EOL)
            *             <dot>
            *     (EOL)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "#", 60);
            if (rde_param_i_seq_void2void(p)) return;
            kleene_118 (p);
            if (rde_param_i_seq_void2void(p)) return;
            sym_EOL (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void kleene_118 (RDE_PARAM p) {
           /*
            * *
            *     x
            *         !
            *             (EOL)
            *         <dot>
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sequence_116 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void sequence_116 (RDE_PARAM p) {
           /*
            * x
            *     !
            *         (EOL)
            *     <dot>
            */
        
            rde_param_i_state_push_void (p);
            notahead_113 (p);
            if (rde_param_i_seq_void2void(p)) return;
            rde_param_i_input_next (p, 43);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void notahead_113 (RDE_PARAM p) {
           /*
            * !
            *     (EOL)
            */
        
            rde_param_i_loc_push (p);
            sym_EOL (p);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * leaf Symbol 'CONTROL'
         */
        
        static void sym_CONTROL (RDE_PARAM p) {
           /*
            * x
            *     "<control>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 65)) return ;
            sequence_126 (p);
            rde_param_i_symbol_done_leaf (p, 65, 64);
            return;
        }
        
        static void sequence_126 (RDE_PARAM p) {
           /*
            * x
            *     "<control>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<control>", 63);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'DAPOSTROPH'
         */
        
        static void sym_DAPOSTROPH (RDE_PARAM p) {
           /*
            * '\"'
            */
        
            if (rde_param_i_symbol_void_start (p, 68)) return ;
            rde_param_i_next_char (p, "\"", 66);
            rde_param_i_symbol_done_void (p, 68, 67);
            return;
        }
        
        /*
         * leaf Symbol 'DDIGIT'
         */
        
        static void sym_DDIGIT (RDE_PARAM p) {
           /*
            * x
            *     "<ddigit>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 71)) return ;
            sequence_133 (p);
            rde_param_i_symbol_done_leaf (p, 71, 70);
            return;
        }
        
        static void sequence_133 (RDE_PARAM p) {
           /*
            * x
            *     "<ddigit>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<ddigit>", 69);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Definition'
         */
        
        static void sym_Definition (RDE_PARAM p) {
           /*
            * x
            *     ?
            *         (Attribute)
            *     (Identifier)
            *     (IS)
            *     (Expression)
            *     (SEMICOLON)
            */
        
            if (rde_param_i_symbol_start_d (p, 73)) return ;
            sequence_143 (p);
            rde_param_i_symbol_done_d_reduce (p, 73, 72);
            return;
        }
        
        static void sequence_143 (RDE_PARAM p) {
           /*
            * x
            *     ?
            *         (Attribute)
            *     (Identifier)
            *     (IS)
            *     (Expression)
            *     (SEMICOLON)
            */
        
            rde_param_i_state_push_value (p);
            optional_137 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_Identifier (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_IS (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_Expression (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_SEMICOLON (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void optional_137 (RDE_PARAM p) {
           /*
            * ?
            *     (Attribute)
            */
        
            rde_param_i_state_push_2 (p);
            sym_Attribute (p);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        /*
         * leaf Symbol 'DIGIT'
         */
        
        static void sym_DIGIT (RDE_PARAM p) {
           /*
            * x
            *     "<digit>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 76)) return ;
            sequence_148 (p);
            rde_param_i_symbol_done_leaf (p, 76, 75);
            return;
        }
        
        static void sequence_148 (RDE_PARAM p) {
           /*
            * x
            *     "<digit>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<digit>", 74);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'DOT'
         */
        
        static void sym_DOT (RDE_PARAM p) {
           /*
            * x
            *     '.'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 79)) return ;
            sequence_153 (p);
            rde_param_i_symbol_done_leaf (p, 79, 78);
            return;
        }
        
        static void sequence_153 (RDE_PARAM p) {
           /*
            * x
            *     '.'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, ".", 77);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'EOF'
         */
        
        static void sym_EOF (RDE_PARAM p) {
           /*
            * !
            *     <dot>
            */
        
            if (rde_param_i_symbol_void_start (p, 81)) return ;
            notahead_157 (p);
            rde_param_i_symbol_done_void (p, 81, 80);
            return;
        }
        
        static void notahead_157 (RDE_PARAM p) {
           /*
            * !
            *     <dot>
            */
        
            rde_param_i_loc_push (p);
            rde_param_i_input_next (p, 43);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * void Symbol 'EOL'
         */
        
        static void sym_EOL (RDE_PARAM p) {
           /*
            * [\n\r]
            */
        
            if (rde_param_i_symbol_void_start (p, 84)) return ;
            rde_param_i_next_class (p, "\n\r", 82);
            rde_param_i_symbol_done_void (p, 84, 83);
            return;
        }
        
        /*
         * value Symbol 'Expression'
         */
        
        static void sym_Expression (RDE_PARAM p) {
           /*
            * x
            *     (Sequence)
            *     *
            *         x
            *             (SLASH)
            *             (Sequence)
            */
        
            if (rde_param_i_symbol_start_d (p, 86)) return ;
            sequence_169 (p);
            rde_param_i_symbol_done_d_reduce (p, 86, 85);
            return;
        }
        
        static void sequence_169 (RDE_PARAM p) {
           /*
            * x
            *     (Sequence)
            *     *
            *         x
            *             (SLASH)
            *             (Sequence)
            */
        
            rde_param_i_state_push_value (p);
            sym_Sequence (p);
            if (rde_param_i_seq_value2value(p)) return;
            kleene_167 (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void kleene_167 (RDE_PARAM p) {
           /*
            * *
            *     x
            *         (SLASH)
            *         (Sequence)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sequence_165 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void sequence_165 (RDE_PARAM p) {
           /*
            * x
            *     (SLASH)
            *     (Sequence)
            */
        
            rde_param_i_state_push_void (p);
            sym_SLASH (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Sequence (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * void Symbol 'Final'
         */
        
        static void sym_Final (RDE_PARAM p) {
           /*
            * x
            *     "END"
            *     (WHITESPACE)
            *     (SEMICOLON)
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 89)) return ;
            sequence_176 (p);
            rde_param_i_symbol_done_void (p, 89, 88);
            return;
        }
        
        static void sequence_176 (RDE_PARAM p) {
           /*
            * x
            *     "END"
            *     (WHITESPACE)
            *     (SEMICOLON)
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "END", 87);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            if (rde_param_i_seq_void2void(p)) return;
            sym_SEMICOLON (p);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Grammar'
         */
        
        static void sym_Grammar (RDE_PARAM p) {
           /*
            * x
            *     (WHITESPACE)
            *     (Header)
            *     *
            *         (Definition)
            *     (Final)
            *     (EOF)
            */
        
            if (rde_param_i_symbol_start_d (p, 91)) return ;
            sequence_186 (p);
            rde_param_i_symbol_done_d_reduce (p, 91, 90);
            return;
        }
        
        static void sequence_186 (RDE_PARAM p) {
           /*
            * x
            *     (WHITESPACE)
            *     (Header)
            *     *
            *         (Definition)
            *     (Final)
            *     (EOF)
            */
        
            rde_param_i_state_push_void (p);
            sym_WHITESPACE (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Header (p);
            if (rde_param_i_seq_value2value(p)) return;
            kleene_182 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_Final (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_EOF (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void kleene_182 (RDE_PARAM p) {
           /*
            * *
            *     (Definition)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sym_Definition (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        /*
         * leaf Symbol 'GRAPH'
         */
        
        static void sym_GRAPH (RDE_PARAM p) {
           /*
            * x
            *     "<graph>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 94)) return ;
            sequence_191 (p);
            rde_param_i_symbol_done_leaf (p, 94, 93);
            return;
        }
        
        static void sequence_191 (RDE_PARAM p) {
           /*
            * x
            *     "<graph>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<graph>", 92);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Header'
         */
        
        static void sym_Header (RDE_PARAM p) {
           /*
            * x
            *     (PEG)
            *     (Identifier)
            *     (StartExpr)
            */
        
            if (rde_param_i_symbol_start_d (p, 96)) return ;
            sequence_197 (p);
            rde_param_i_symbol_done_d_reduce (p, 96, 95);
            return;
        }
        
        static void sequence_197 (RDE_PARAM p) {
           /*
            * x
            *     (PEG)
            *     (Identifier)
            *     (StartExpr)
            */
        
            rde_param_i_state_push_void (p);
            sym_PEG (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Identifier (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_StartExpr (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * leaf Symbol 'Ident'
         */
        
        static void sym_Ident (RDE_PARAM p) {
           /*
            * x
            *     /
            *         [_:]
            *         <alpha>
            *     *
            *         /
            *             [_:]
            *             <alnum>
            */
        
            if (rde_param_i_symbol_start (p, 99)) return ;
            sequence_210 (p);
            rde_param_i_symbol_done_leaf (p, 99, 98);
            return;
        }
        
        static void sequence_210 (RDE_PARAM p) {
           /*
            * x
            *     /
            *         [_:]
            *         <alpha>
            *     *
            *         /
            *             [_:]
            *             <alnum>
            */
        
            rde_param_i_state_push_void (p);
            choice_202 (p);
            if (rde_param_i_seq_void2void(p)) return;
            kleene_208 (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void choice_202 (RDE_PARAM p) {
           /*
            * /
            *     [_:]
            *     <alpha>
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_class (p, "_:", 97);
            if (rde_param_i_bra_void2void(p)) return;
            rde_param_i_next_alpha (p, 1);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void kleene_208 (RDE_PARAM p) {
           /*
            * *
            *     /
            *         [_:]
            *         <alnum>
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                choice_206 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void choice_206 (RDE_PARAM p) {
           /*
            * /
            *     [_:]
            *     <alnum>
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_class (p, "_:", 97);
            if (rde_param_i_bra_void2void(p)) return;
            rde_param_i_next_alnum (p, 0);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Identifier'
         */
        
        static void sym_Identifier (RDE_PARAM p) {
           /*
            * x
            *     (Ident)
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start_d (p, 101)) return ;
            sequence_215 (p);
            rde_param_i_symbol_done_d_reduce (p, 101, 100);
            return;
        }
        
        static void sequence_215 (RDE_PARAM p) {
           /*
            * x
            *     (Ident)
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_value (p);
            sym_Ident (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * void Symbol 'IS'
         */
        
        static void sym_IS (RDE_PARAM p) {
           /*
            * x
            *     "<-"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 104)) return ;
            sequence_220 (p);
            rde_param_i_symbol_done_void (p, 104, 103);
            return;
        }
        
        static void sequence_220 (RDE_PARAM p) {
           /*
            * x
            *     "<-"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<-", 102);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'LEAF'
         */
        
        static void sym_LEAF (RDE_PARAM p) {
           /*
            * x
            *     "leaf"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 107)) return ;
            sequence_225 (p);
            rde_param_i_symbol_done_leaf (p, 107, 106);
            return;
        }
        
        static void sequence_225 (RDE_PARAM p) {
           /*
            * x
            *     "leaf"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "leaf", 105);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Literal'
         */
        
        static void sym_Literal (RDE_PARAM p) {
           /*
            * /
            *     x
            *         (APOSTROPH)
            *         *
            *             x
            *                 !
            *                     (APOSTROPH)
            *                 (Char)
            *         (APOSTROPH)
            *         (WHITESPACE)
            *     x
            *         (DAPOSTROPH)
            *         *
            *             x
            *                 !
            *                     (DAPOSTROPH)
            *                 (Char)
            *         (DAPOSTROPH)
            *         (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start_d (p, 109)) return ;
            choice_254 (p);
            rde_param_i_symbol_done_d_reduce (p, 109, 108);
            return;
        }
        
        static void choice_254 (RDE_PARAM p) {
           /*
            * /
            *     x
            *         (APOSTROPH)
            *         *
            *             x
            *                 !
            *                     (APOSTROPH)
            *                 (Char)
            *         (APOSTROPH)
            *         (WHITESPACE)
            *     x
            *         (DAPOSTROPH)
            *         *
            *             x
            *                 !
            *                     (DAPOSTROPH)
            *                 (Char)
            *         (DAPOSTROPH)
            *         (WHITESPACE)
            */
        
            rde_param_i_state_push_value (p);
            sequence_239 (p);
            if (rde_param_i_bra_value2value(p)) return;
            sequence_252 (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void sequence_239 (RDE_PARAM p) {
           /*
            * x
            *     (APOSTROPH)
            *     *
            *         x
            *             !
            *                 (APOSTROPH)
            *             (Char)
            *     (APOSTROPH)
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            sym_APOSTROPH (p);
            if (rde_param_i_seq_void2value(p)) return;
            kleene_235 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_APOSTROPH (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void kleene_235 (RDE_PARAM p) {
           /*
            * *
            *     x
            *         !
            *             (APOSTROPH)
            *         (Char)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sequence_233 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void sequence_233 (RDE_PARAM p) {
           /*
            * x
            *     !
            *         (APOSTROPH)
            *     (Char)
            */
        
            rde_param_i_state_push_void (p);
            notahead_230 (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Char (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void notahead_230 (RDE_PARAM p) {
           /*
            * !
            *     (APOSTROPH)
            */
        
            rde_param_i_loc_push (p);
            sym_APOSTROPH (p);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        static void sequence_252 (RDE_PARAM p) {
           /*
            * x
            *     (DAPOSTROPH)
            *     *
            *         x
            *             !
            *                 (DAPOSTROPH)
            *             (Char)
            *     (DAPOSTROPH)
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            sym_DAPOSTROPH (p);
            if (rde_param_i_seq_void2value(p)) return;
            kleene_248 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_DAPOSTROPH (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void kleene_248 (RDE_PARAM p) {
           /*
            * *
            *     x
            *         !
            *             (DAPOSTROPH)
            *         (Char)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                sequence_246 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void sequence_246 (RDE_PARAM p) {
           /*
            * x
            *     !
            *         (DAPOSTROPH)
            *     (Char)
            */
        
            rde_param_i_state_push_void (p);
            notahead_243 (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Char (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void notahead_243 (RDE_PARAM p) {
           /*
            * !
            *     (DAPOSTROPH)
            */
        
            rde_param_i_loc_push (p);
            sym_DAPOSTROPH (p);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * leaf Symbol 'LOWER'
         */
        
        static void sym_LOWER (RDE_PARAM p) {
           /*
            * x
            *     "<lower>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 112)) return ;
            sequence_259 (p);
            rde_param_i_symbol_done_leaf (p, 112, 111);
            return;
        }
        
        static void sequence_259 (RDE_PARAM p) {
           /*
            * x
            *     "<lower>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<lower>", 110);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'NOT'
         */
        
        static void sym_NOT (RDE_PARAM p) {
           /*
            * x
            *     '!'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 115)) return ;
            sequence_264 (p);
            rde_param_i_symbol_done_leaf (p, 115, 114);
            return;
        }
        
        static void sequence_264 (RDE_PARAM p) {
           /*
            * x
            *     '!'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "!", 113);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'OPEN'
         */
        
        static void sym_OPEN (RDE_PARAM p) {
           /*
            * x
            *     '\('
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 118)) return ;
            sequence_269 (p);
            rde_param_i_symbol_done_void (p, 118, 117);
            return;
        }
        
        static void sequence_269 (RDE_PARAM p) {
           /*
            * x
            *     '\('
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "(", 116);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'OPENB'
         */
        
        static void sym_OPENB (RDE_PARAM p) {
           /*
            * '['
            */
        
            if (rde_param_i_symbol_void_start (p, 121)) return ;
            rde_param_i_next_char (p, "[", 119);
            rde_param_i_symbol_done_void (p, 121, 120);
            return;
        }
        
        /*
         * void Symbol 'PEG'
         */
        
        static void sym_PEG (RDE_PARAM p) {
           /*
            * x
            *     "PEG"
            *     !
            *         /
            *             [_:]
            *             <alnum>
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 124)) return ;
            sequence_281 (p);
            rde_param_i_symbol_done_void (p, 124, 123);
            return;
        }
        
        static void sequence_281 (RDE_PARAM p) {
           /*
            * x
            *     "PEG"
            *     !
            *         /
            *             [_:]
            *             <alnum>
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "PEG", 122);
            if (rde_param_i_seq_void2void(p)) return;
            notahead_278 (p);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        static void notahead_278 (RDE_PARAM p) {
           /*
            * !
            *     /
            *         [_:]
            *         <alnum>
            */
        
            rde_param_i_loc_push (p);
            choice_206 (p);
            rde_param_i_notahead_exit (p);
            return;
        }
        
        /*
         * leaf Symbol 'PLUS'
         */
        
        static void sym_PLUS (RDE_PARAM p) {
           /*
            * x
            *     '+'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 127)) return ;
            sequence_286 (p);
            rde_param_i_symbol_done_leaf (p, 127, 126);
            return;
        }
        
        static void sequence_286 (RDE_PARAM p) {
           /*
            * x
            *     '+'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "+", 125);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Prefix'
         */
        
        static void sym_Prefix (RDE_PARAM p) {
           /*
            * x
            *     ?
            *         /
            *             (AND)
            *             (NOT)
            *     (Suffix)
            */
        
            if (rde_param_i_symbol_start_d (p, 129)) return ;
            sequence_296 (p);
            rde_param_i_symbol_done_d_reduce (p, 129, 128);
            return;
        }
        
        static void sequence_296 (RDE_PARAM p) {
           /*
            * x
            *     ?
            *         /
            *             (AND)
            *             (NOT)
            *     (Suffix)
            */
        
            rde_param_i_state_push_value (p);
            optional_293 (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_Suffix (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void optional_293 (RDE_PARAM p) {
           /*
            * ?
            *     /
            *         (AND)
            *         (NOT)
            */
        
            rde_param_i_state_push_2 (p);
            choice_291 (p);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        static void choice_291 (RDE_PARAM p) {
           /*
            * /
            *     (AND)
            *     (NOT)
            */
        
            rde_param_i_state_push_value (p);
            sym_AND (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_NOT (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * value Symbol 'Primary'
         */
        
        static void sym_Primary (RDE_PARAM p) {
           /*
            * /
            *     (ALNUM)
            *     (ALPHA)
            *     (ASCII)
            *     (CONTROL)
            *     (DDIGIT)
            *     (DIGIT)
            *     (GRAPH)
            *     (LOWER)
            *     (PRINTABLE)
            *     (PUNCT)
            *     (SPACE)
            *     (UPPER)
            *     (WORDCHAR)
            *     (XDIGIT)
            *     (Identifier)
            *     x
            *         (OPEN)
            *         (Expression)
            *         (CLOSE)
            *     (Literal)
            *     (Class)
            *     (DOT)
            */
        
            if (rde_param_i_symbol_start_d (p, 131)) return ;
            choice_322 (p);
            rde_param_i_symbol_done_d_reduce (p, 131, 130);
            return;
        }
        
        static void choice_322 (RDE_PARAM p) {
           /*
            * /
            *     (ALNUM)
            *     (ALPHA)
            *     (ASCII)
            *     (CONTROL)
            *     (DDIGIT)
            *     (DIGIT)
            *     (GRAPH)
            *     (LOWER)
            *     (PRINTABLE)
            *     (PUNCT)
            *     (SPACE)
            *     (UPPER)
            *     (WORDCHAR)
            *     (XDIGIT)
            *     (Identifier)
            *     x
            *         (OPEN)
            *         (Expression)
            *         (CLOSE)
            *     (Literal)
            *     (Class)
            *     (DOT)
            */
        
            rde_param_i_state_push_value (p);
            sym_ALNUM (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_ALPHA (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_ASCII (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_CONTROL (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_DDIGIT (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_DIGIT (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_GRAPH (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_LOWER (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_PRINTABLE (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_PUNCT (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_SPACE (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_UPPER (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_WORDCHAR (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_XDIGIT (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_Identifier (p);
            if (rde_param_i_bra_value2value(p)) return;
            sequence_317 (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_Literal (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_Class (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_DOT (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void sequence_317 (RDE_PARAM p) {
           /*
            * x
            *     (OPEN)
            *     (Expression)
            *     (CLOSE)
            */
        
            rde_param_i_state_push_void (p);
            sym_OPEN (p);
            if (rde_param_i_seq_void2value(p)) return;
            sym_Expression (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_CLOSE (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * leaf Symbol 'PRINTABLE'
         */
        
        static void sym_PRINTABLE (RDE_PARAM p) {
           /*
            * x
            *     "<print>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 134)) return ;
            sequence_327 (p);
            rde_param_i_symbol_done_leaf (p, 134, 133);
            return;
        }
        
        static void sequence_327 (RDE_PARAM p) {
           /*
            * x
            *     "<print>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<print>", 132);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'PUNCT'
         */
        
        static void sym_PUNCT (RDE_PARAM p) {
           /*
            * x
            *     "<punct>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 137)) return ;
            sequence_332 (p);
            rde_param_i_symbol_done_leaf (p, 137, 136);
            return;
        }
        
        static void sequence_332 (RDE_PARAM p) {
           /*
            * x
            *     "<punct>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<punct>", 135);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'QUESTION'
         */
        
        static void sym_QUESTION (RDE_PARAM p) {
           /*
            * x
            *     '?'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 140)) return ;
            sequence_337 (p);
            rde_param_i_symbol_done_leaf (p, 140, 139);
            return;
        }
        
        static void sequence_337 (RDE_PARAM p) {
           /*
            * x
            *     '?'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "?", 138);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Range'
         */
        
        static void sym_Range (RDE_PARAM p) {
           /*
            * /
            *     x
            *         (Char)
            *         (TO)
            *         (Char)
            *     (Char)
            */
        
            if (rde_param_i_symbol_start_d (p, 142)) return ;
            choice_346 (p);
            rde_param_i_symbol_done_d_reduce (p, 142, 141);
            return;
        }
        
        static void choice_346 (RDE_PARAM p) {
           /*
            * /
            *     x
            *         (Char)
            *         (TO)
            *         (Char)
            *     (Char)
            */
        
            rde_param_i_state_push_value (p);
            sequence_343 (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_Char (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void sequence_343 (RDE_PARAM p) {
           /*
            * x
            *     (Char)
            *     (TO)
            *     (Char)
            */
        
            rde_param_i_state_push_value (p);
            sym_Char (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_TO (p);
            if (rde_param_i_seq_value2value(p)) return;
            sym_Char (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * void Symbol 'SEMICOLON'
         */
        
        static void sym_SEMICOLON (RDE_PARAM p) {
           /*
            * x
            *     ';'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 145)) return ;
            sequence_351 (p);
            rde_param_i_symbol_done_void (p, 145, 144);
            return;
        }
        
        static void sequence_351 (RDE_PARAM p) {
           /*
            * x
            *     ';'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, ";", 143);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'Sequence'
         */
        
        static void sym_Sequence (RDE_PARAM p) {
           /*
            * +
            *     (Prefix)
            */
        
            if (rde_param_i_symbol_start_d (p, 147)) return ;
            poskleene_355 (p);
            rde_param_i_symbol_done_d_reduce (p, 147, 146);
            return;
        }
        
        static void poskleene_355 (RDE_PARAM p) {
           /*
            * +
            *     (Prefix)
            */
        
            rde_param_i_loc_push (p);
            sym_Prefix (p);
            if (rde_param_i_kleene_abort(p)) return;
            while (1) {
                rde_param_i_state_push_2 (p);
                sym_Prefix (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        /*
         * void Symbol 'SLASH'
         */
        
        static void sym_SLASH (RDE_PARAM p) {
           /*
            * x
            *     '/'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_void_start (p, 150)) return ;
            sequence_360 (p);
            rde_param_i_symbol_done_void (p, 150, 149);
            return;
        }
        
        static void sequence_360 (RDE_PARAM p) {
           /*
            * x
            *     '/'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "/", 148);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'SPACE'
         */
        
        static void sym_SPACE (RDE_PARAM p) {
           /*
            * x
            *     "<space>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 153)) return ;
            sequence_365 (p);
            rde_param_i_symbol_done_leaf (p, 153, 152);
            return;
        }
        
        static void sequence_365 (RDE_PARAM p) {
           /*
            * x
            *     "<space>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<space>", 151);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'STAR'
         */
        
        static void sym_STAR (RDE_PARAM p) {
           /*
            * x
            *     '*'
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 156)) return ;
            sequence_370 (p);
            rde_param_i_symbol_done_leaf (p, 156, 155);
            return;
        }
        
        static void sequence_370 (RDE_PARAM p) {
           /*
            * x
            *     '*'
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_char (p, "*", 154);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * value Symbol 'StartExpr'
         */
        
        static void sym_StartExpr (RDE_PARAM p) {
           /*
            * x
            *     (OPEN)
            *     (Expression)
            *     (CLOSE)
            */
        
            if (rde_param_i_symbol_start_d (p, 158)) return ;
            sequence_317 (p);
            rde_param_i_symbol_done_d_reduce (p, 158, 157);
            return;
        }
        
        /*
         * value Symbol 'Suffix'
         */
        
        static void sym_Suffix (RDE_PARAM p) {
           /*
            * x
            *     (Primary)
            *     ?
            *         /
            *             (QUESTION)
            *             (STAR)
            *             (PLUS)
            */
        
            if (rde_param_i_symbol_start_d (p, 160)) return ;
            sequence_386 (p);
            rde_param_i_symbol_done_d_reduce (p, 160, 159);
            return;
        }
        
        static void sequence_386 (RDE_PARAM p) {
           /*
            * x
            *     (Primary)
            *     ?
            *         /
            *             (QUESTION)
            *             (STAR)
            *             (PLUS)
            */
        
            rde_param_i_state_push_value (p);
            sym_Primary (p);
            if (rde_param_i_seq_value2value(p)) return;
            optional_384 (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        static void optional_384 (RDE_PARAM p) {
           /*
            * ?
            *     /
            *         (QUESTION)
            *         (STAR)
            *         (PLUS)
            */
        
            rde_param_i_state_push_2 (p);
            choice_382 (p);
            rde_param_i_state_merge_ok (p);
            return;
        }
        
        static void choice_382 (RDE_PARAM p) {
           /*
            * /
            *     (QUESTION)
            *     (STAR)
            *     (PLUS)
            */
        
            rde_param_i_state_push_value (p);
            sym_QUESTION (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_STAR (p);
            if (rde_param_i_bra_value2value(p)) return;
            sym_PLUS (p);
            rde_param_i_state_merge_value (p);
            return;
        }
        
        /*
         * void Symbol 'TO'
         */
        
        static void sym_TO (RDE_PARAM p) {
           /*
            * '-'
            */
        
            if (rde_param_i_symbol_void_start (p, 163)) return ;
            rde_param_i_next_char (p, "-", 161);
            rde_param_i_symbol_done_void (p, 163, 162);
            return;
        }
        
        /*
         * leaf Symbol 'UPPER'
         */
        
        static void sym_UPPER (RDE_PARAM p) {
           /*
            * x
            *     "<upper>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 166)) return ;
            sequence_393 (p);
            rde_param_i_symbol_done_leaf (p, 166, 165);
            return;
        }
        
        static void sequence_393 (RDE_PARAM p) {
           /*
            * x
            *     "<upper>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<upper>", 164);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'VOID'
         */
        
        static void sym_VOID (RDE_PARAM p) {
           /*
            * x
            *     "void"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 169)) return ;
            sequence_398 (p);
            rde_param_i_symbol_done_leaf (p, 169, 168);
            return;
        }
        
        static void sequence_398 (RDE_PARAM p) {
           /*
            * x
            *     "void"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "void", 167);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * void Symbol 'WHITESPACE'
         */
        
        static void sym_WHITESPACE (RDE_PARAM p) {
           /*
            * *
            *     /
            *         <space>
            *         (COMMENT)
            */
        
            if (rde_param_i_symbol_void_start (p, 171)) return ;
            kleene_405 (p);
            rde_param_i_symbol_done_void (p, 171, 170);
            return;
        }
        
        static void kleene_405 (RDE_PARAM p) {
           /*
            * *
            *     /
            *         <space>
            *         (COMMENT)
            */
        
            while (1) {
                rde_param_i_state_push_2 (p);
                choice_403 (p);
                if (rde_param_i_kleene_close(p)) return;
            }
            return;
        }
        
        static void choice_403 (RDE_PARAM p) {
           /*
            * /
            *     <space>
            *     (COMMENT)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_space (p, 10);
            if (rde_param_i_bra_void2void(p)) return;
            sym_COMMENT (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'WORDCHAR'
         */
        
        static void sym_WORDCHAR (RDE_PARAM p) {
           /*
            * x
            *     "<wordchar>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 174)) return ;
            sequence_410 (p);
            rde_param_i_symbol_done_leaf (p, 174, 173);
            return;
        }
        
        static void sequence_410 (RDE_PARAM p) {
           /*
            * x
            *     "<wordchar>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<wordchar>", 172);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
        /*
         * leaf Symbol 'XDIGIT'
         */
        
        static void sym_XDIGIT (RDE_PARAM p) {
           /*
            * x
            *     "<xdigit>"
            *     (WHITESPACE)
            */
        
            if (rde_param_i_symbol_start (p, 177)) return ;
            sequence_415 (p);
            rde_param_i_symbol_done_leaf (p, 177, 176);
            return;
        }
        
        static void sequence_415 (RDE_PARAM p) {
           /*
            * x
            *     "<xdigit>"
            *     (WHITESPACE)
            */
        
            rde_param_i_state_push_void (p);
            rde_param_i_next_str (p, "<xdigit>", 175);
            if (rde_param_i_seq_void2void(p)) return;
            sym_WHITESPACE (p);
            rde_param_i_state_merge_void (p);
            return;
        }
        
    }

    ## END of GENERATED CODE. DO NOT EDIT.
    # # ## ### ###### ######## #############

    # # ## ### ###### ######## #############
    ## Global PARSER management, per interp

    critcl::ccode {
	/* -*- c -*- */

	typedef struct PARSERg {
	    long int counter;
	    char     buf [50];
	} PARSERg;

	static void
	PARSERgRelease (ClientData cd, Tcl_Interp* interp)
	{
	    ckfree((char*) cd);
	}

	static const char*
	PARSERnewName (Tcl_Interp* interp)
	{
#define KEY "tcllib/parser/pt_parse_peg_c/critcl"

	    Tcl_InterpDeleteProc* proc = PARSERgRelease;
	    PARSERg*                  parserg;

	    parserg = Tcl_GetAssocData (interp, KEY, &proc);
	    if (parserg  == NULL) {
		parserg = (PARSERg*) ckalloc (sizeof (PARSERg));
		parserg->counter = 0;

		Tcl_SetAssocData (interp, KEY, proc,
				  (ClientData) parserg);
	    }

	    parserg->counter ++;
	    sprintf (parserg->buf, "peg%ld", parserg->counter);
	    return parserg->buf;
#undef  KEY
	}

	static void
	PARSERdeleteCmd (ClientData clientData)
	{
	    /*
	     * Release the whole PARSER
	     * (Low-level engine only actually).
	     */
	    rde_param_del ((RDE_PARAM) clientData);
	}
    }

    # # ## ### ##### ######## #############
    ## Functions implementing the object methods, and helper.

    critcl::ccode {
	static int  COMPLETE (RDE_PARAM p, Tcl_Interp* interp);

	static int parser_PARSE  (RDE_PARAM p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
	{
	    int mode;
	    Tcl_Channel chan;

	    if (objc != 3) {
		Tcl_WrongNumArgs (interp, 2, objv, "chan");
		return TCL_ERROR;
	    }

	    chan = Tcl_GetChannel(interp,
				  Tcl_GetString (objv[2]),
				  &mode);

	    if (!chan) {
		return TCL_ERROR;
	    }

	    rde_param_reset (p, chan);
	    MAIN (p) ; /* Entrypoint for the generated code. */
	    return COMPLETE (p, interp);
	}

	static int parser_PARSET (RDE_PARAM p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
	{
	    char* buf;
	    int   len;

	    if (objc != 3) {
		Tcl_WrongNumArgs (interp, 2, objv, "text");
		return TCL_ERROR;
	    }

	    buf = Tcl_GetStringFromObj (objv[2], &len);

	    rde_param_reset (p, NULL);
	    rde_param_data  (p, buf, len);
	    MAIN (p) ; /* Entrypoint for the generated code. */
	    return COMPLETE (p, interp);
	}

	/* See also rde_critcl/m.c, param_COMPLETE() */
	static int COMPLETE (RDE_PARAM p, Tcl_Interp* interp)
	{
	    if (rde_param_query_st (p)) {
		long int  ac;
		Tcl_Obj** av;

		rde_param_query_ast (p, &ac, &av);

		if (ac > 1) {
		    Tcl_Obj** lv = NALLOC (3+ac, Tcl_Obj*);

		    memcpy(lv + 3, av, ac * sizeof (Tcl_Obj*));
		    lv [0] = Tcl_NewObj ();
		    lv [1] = Tcl_NewIntObj (1 + rde_param_query_lstop (p));
		    lv [2] = Tcl_NewIntObj (rde_param_query_cl (p));

		    Tcl_SetObjResult (interp, Tcl_NewListObj (3, lv));
		    ckfree ((char*) lv);

		} else if (ac == 0) {
		    /*
		     * Match, but no AST. This is possible if the grammar
		     * consists of only the start expression.
		     */
		    Tcl_SetObjResult (interp, Tcl_NewStringObj ("",-1));
		} else {
		    Tcl_SetObjResult (interp, av [0]);
		}

		return TCL_OK;
	    } else {
		Tcl_Obj* xv [1];
		const ERROR_STATE* er = rde_param_query_er (p);
		Tcl_Obj* res = rde_param_query_er_tcl (p, er);
		/* res = list (location, list(msg)) */

		/* Stick the exception type-tag before the existing elements */
		xv [0] = Tcl_NewStringObj ("pt::rde",-1);
		Tcl_ListObjReplace(interp, res, 0, 0, 1, xv);

		Tcl_SetErrorCode (interp, "PT", "RDE", "SYNTAX", NULL);
		Tcl_SetObjResult (interp, res);
		return TCL_ERROR;
	    }
	}
    }

    # # ## ### ##### ######## #############
    ## Object command, method dispatch.

    critcl::ccode {
	static int parser_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
	{
	    RDE_PARAM p = (RDE_PARAM) cd;
	    int m, res;

	    static CONST char* methods [] = {
		"destroy", "parse", "parset", NULL
	    };
	    enum methods {
		M_DESTROY, M_PARSE, M_PARSET
	    };

	    if (objc < 2) {
		Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
		return TCL_ERROR;
	    } else if (Tcl_GetIndexFromObj (interp, objv [1], methods, "option",
					    0, &m) != TCL_OK) {
		return TCL_ERROR;
	    }

	    /* Dispatch to methods. They check the #args in
	     * detail before performing the requested
	     * functionality
	     */

	    switch (m) {
		case M_DESTROY:
		    if (objc != 2) {
			Tcl_WrongNumArgs (interp, 2, objv, NULL);
			return TCL_ERROR;
		    }

		Tcl_DeleteCommandFromToken(interp, (Tcl_Command) rde_param_query_clientdata (p));
		return TCL_OK;

		case M_PARSE:	res = parser_PARSE  (p, interp, objc, objv); break;
		case M_PARSET:	res = parser_PARSET (p, interp, objc, objv); break;
		default:
		/* Not coming to this place */
		ASSERT (0,"Reached unreachable location");
	    }

	    return res;
	}
    }

    # # ## ### ##### ######## #############
    # Class command, i.e. object construction.

    critcl::ccommand peg_critcl {dummy interp objc objv} {
	/*
	 * Syntax: No arguments beyond the name
	 */

	RDE_PARAM   parser;
	CONST char* name;
	Tcl_Obj*    fqn;
	Tcl_CmdInfo ci;
	Tcl_Command c;

#define USAGE "?name?"

	if ((objc != 2) && (objc != 1)) {
	    Tcl_WrongNumArgs (interp, 1, objv, USAGE);
	    return TCL_ERROR;
	}

	if (objc < 2) {
	    name = PARSERnewName (interp);
	} else {
	    name = Tcl_GetString (objv [1]);
	}

	if (!Tcl_StringMatch (name, "::*")) {
	    /* Relative name. Prefix with current namespace */

	    Tcl_Eval (interp, "namespace current");
	    fqn = Tcl_GetObjResult (interp);
	    fqn = Tcl_DuplicateObj (fqn);
	    Tcl_IncrRefCount (fqn);

	    if (!Tcl_StringMatch (Tcl_GetString (fqn), "::")) {
		Tcl_AppendToObj (fqn, "::", -1);
	    }
	    Tcl_AppendToObj (fqn, name, -1);
	} else {
	    fqn = Tcl_NewStringObj (name, -1);
	    Tcl_IncrRefCount (fqn);
	}
	Tcl_ResetResult (interp);

	if (Tcl_GetCommandInfo (interp,
				Tcl_GetString (fqn),
				&ci)) {
	    Tcl_Obj* err;

	    err = Tcl_NewObj ();
	    Tcl_AppendToObj    (err, "command \"", -1);
	    Tcl_AppendObjToObj (err, fqn);
	    Tcl_AppendToObj    (err, "\" already exists", -1);

	    Tcl_DecrRefCount (fqn);
	    Tcl_SetObjResult (interp, err);
	    return TCL_ERROR;
	}

	parser = rde_param_new (sizeof(p_string)/sizeof(char*), (char**) p_string);
	c = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
				  parser_objcmd, (ClientData) parser,
				  PARSERdeleteCmd);
	rde_param_clientdata (parser, (ClientData) c);
	Tcl_SetObjResult (interp, fqn);
	Tcl_DecrRefCount (fqn);
	return TCL_OK;
    }

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready (Note: Our package provide is at the top).
return

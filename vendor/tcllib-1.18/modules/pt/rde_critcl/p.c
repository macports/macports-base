/* pt::rde::critcl - critcl - layer 1 definitions
 * (c) PARAM functions
 */

#include <pInt.h> /* Our public and internal APIs */
#include <util.h> /* Allocation macros */
#include <string.h>

/* .................................................. */

static char*
dup_string (const char* str);

/* .................................................. */

RDE_STATE
param_new (void)
{
    RDE_STATE p;

    ENTER ("param_new");

    p = ALLOC (RDE_STATE_);
#ifdef RDE_TRACE
    p->icount = 0;
#endif
    p->c = NULL;

    p->maxnum = 0;
    p->numstr = 0;
    p->string = NULL;
    p->sfirst = NULL;
    Tcl_InitHashTable (&p->str, TCL_STRING_KEYS);

    p->p = rde_param_new (p->numstr, p->string);

    /*
     * Fixed elements of the string table, as needed by the lower level PARAM
     * functions (class tests, see param.c, enum test_class).
     * Further pt_peg_to_cparam.tcl, [::pt::peg::to::cparam::convert]
     * ** Keep in sync **
     *
     * Maybe move the interning into the lower level, i.e. PARAM ?
     */

    param_intern (p, "alnum");
    param_intern (p, "alpha");
    param_intern (p, "ascii");
    param_intern (p, "control");
    param_intern (p, "ddigit");
    param_intern (p, "digit");
    param_intern (p, "graph");
    param_intern (p, "lower");
    param_intern (p, "print");
    param_intern (p, "punct");
    param_intern (p, "space");
    param_intern (p, "upper");
    param_intern (p, "wordchar");
    param_intern (p, "xdigit");

    RETURN ("%p",p);
}

void
param_delete (RDE_STATE p)
{
    RDE_STRING* next;

    ENTER ("param_delete");
    TRACE (("RDE_STATE %p",p));

    while (p->numstr) {
	p->numstr --;
	ASSERT_BOUNDS(p->numstr,p->maxnum);
	ckfree (p->string [p->numstr]);
    }

    Tcl_DeleteHashTable (&p->str);

    /* Process the list of Tcl_Obj* which have references to interned strings.
     * We have to invalidate & release their intreps, and detach them from
     * this state.
     */
    while (p->sfirst) {
	next = p->sfirst->next;

	TRACE (("del intern %p having %p '%s'", p, p->sfirst->self, Tcl_GetString(p->sfirst->self)));

	p->sfirst->self->internalRep.twoPtrValue.ptr1 = NULL;
	p->sfirst->self->internalRep.twoPtrValue.ptr2 = NULL;
	p->sfirst->self->typePtr = NULL;

	ckfree ((char*) p->sfirst);
	p->sfirst = next;
    }

    rde_param_del (p->p);
    ckfree ((char*) p);

    RETURNVOID;
}

void
param_setcmd (RDE_STATE p, Tcl_Command c)
{
    ENTER ("param_setcmd");
    TRACE (("RDE_STATE   %p",p));
    TRACE (("Tcl_Command %p",c));

    p->c = c;

    RETURNVOID;
}

long int
param_intern (RDE_STATE p, const char* literal)
{
    long int res;
    int isnew;
    Tcl_HashEntry* hPtr;

    ENTER ("param_intern");
    TRACE (("RDE_STATE   %p",p));
    TRACE (("CHAR*      '%s'",literal));

    hPtr = Tcl_FindHashEntry (&p->str, literal);
    if (hPtr) {
	res = (long int) Tcl_GetHashValue (hPtr);
	RETURN("CACHED %d",res);
    }

    hPtr = Tcl_CreateHashEntry(&p->str, literal, &isnew);
    ASSERT (isnew, "Should have found entry");

    Tcl_SetHashValue (hPtr, p->numstr);

    if (p->numstr >= p->maxnum) {
	long int new;
	char**   str;

	new  = 2 * (p->maxnum ? p->maxnum : 8);
	TRACE (("extend to %d strings",new));

	str  = (char**) ckrealloc ((char*) p->string, new * sizeof(char*));
	ASSERT (str,"Memory allocation failure for string table");
	p->maxnum = new;
	p->string = str;
    }

    res = p->numstr;

    ASSERT_BOUNDS(res,p->maxnum);
    p->string [res] = dup_string (literal);
    p->numstr ++;

    TRACE (("UPDATE ENGINE"));
    rde_param_update_strings (p->p, p->numstr, p->string);

    RETURN("NEW %d",res);
}
/* .................................................. */

static char*
dup_string (const char* str)
{
    int   n = strlen(str);
    char* s = NALLOC(n+1,char);

    memcpy (s, str, n);
    s[n] = '\0';

    return s;
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

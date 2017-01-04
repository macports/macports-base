/* struct::set - critcl - layer 0 declarations
 * Tcl_ObjType 'set'.
 */

#include <string.h>
#include "s.h"

/* .................................................. */

static void free_rep   (Tcl_Obj* obj);
static void dup_rep    (Tcl_Obj* obj, Tcl_Obj* dup);
static void string_rep (Tcl_Obj* obj);
static int  from_any   (Tcl_Interp* ip, Tcl_Obj* obj);

static
Tcl_ObjType s_type = {
    "tcllib::struct::set/critcl::set",
    free_rep,
    dup_rep,
    string_rep,
    from_any
};

/* .................................................. */

int
s_get (Tcl_Interp* interp, Tcl_Obj* o, SPtr* sStar)
{
    if (o->typePtr != &s_type) {
	int res = from_any (interp, o);
	if (res != TCL_OK) {
	    return res;
	}
    }

    *sStar = (SPtr) o->internalRep.otherValuePtr;
    return TCL_OK;
}

Tcl_Obj*
s_new (SPtr s)
{
    Tcl_Obj* o = Tcl_NewObj();
    Tcl_InvalidateStringRep(o);

    o->internalRep.otherValuePtr = s;
    o->typePtr                   = &s_type;
    return o;
}

Tcl_ObjType*
s_stype (void)
{
    return &s_type;
}

Tcl_ObjType*
s_ltype (void)
{
    static Tcl_ObjType* l;
    if (l == NULL) {
	l = Tcl_GetObjType ("list");
    }
    return l;
}

/* .................................................. */

static void
free_rep (Tcl_Obj* o)
{
    s_free ((SPtr) o->internalRep.otherValuePtr);
    o->internalRep.otherValuePtr = NULL;
}

static void
dup_rep (Tcl_Obj* obj, Tcl_Obj* dup)
{
    SPtr s = s_dup ((SPtr) obj->internalRep.otherValuePtr);

    dup->internalRep.otherValuePtr = s;
    dup->typePtr	           = &s_type;
}

static void
string_rep (Tcl_Obj* obj)
{
    SPtr s        = (SPtr) obj->internalRep.otherValuePtr;
    int  numElems = s->el.numEntries;

    /* iterate hash table and generate list-like string rep */

#   define LOCAL_SIZE 20
    int localFlags[LOCAL_SIZE], *flagPtr;
    int localLen  [LOCAL_SIZE], *lenPtr;
    register int i;
    char *elem, *dst;
    int length;

    Tcl_HashSearch hs;
    Tcl_HashEntry* he;

    /*
     * Convert each key of the hash to string form and then convert it to
     * proper list element form, adding it to the result buffer.  */

    /*
     * Pass 1: estimate space, gather flags.
     */

    if (numElems <= LOCAL_SIZE) {
	flagPtr = localFlags;
	lenPtr  = localLen;
    } else {
	flagPtr = (int *) ckalloc((unsigned) numElems*sizeof(int));
	lenPtr  = (int *) ckalloc((unsigned) numElems*sizeof(int));
    }
    obj->length = 1;

    for(i = 0, he = Tcl_FirstHashEntry(&s->el, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs), i++) {

	elem       = Tcl_GetHashKey (&s->el, he);
	lenPtr [i] = strlen (elem);

	obj->length += Tcl_ScanCountedElement(elem, lenPtr[i],
					&flagPtr[i]) + 1;
    }

    /*
     * Pass 2: copy into string rep buffer.
     */

    obj->bytes = ckalloc((unsigned) obj->length);
    dst = obj->bytes;

    for(i = 0, he = Tcl_FirstHashEntry(&s->el, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs), i++) {

	elem = Tcl_GetHashKey (&s->el, he);

	dst += Tcl_ConvertCountedElement(elem, lenPtr[i],
					 dst, flagPtr[i]);
	*dst = ' ';
	dst++;
    }
    if (flagPtr != localFlags) {
	ckfree((char *) flagPtr);
	ckfree((char *) lenPtr);
    }
    if (dst == obj->bytes) {
	*dst = 0;
    } else {
	dst--;
	*dst = 0;
    }
    obj->length = dst - obj->bytes;
}

static int
from_any (Tcl_Interp* ip, Tcl_Obj* obj)
{
    /* Go through an intermediate list rep.
     */

    int          lc, i, new;
    Tcl_Obj**    lv;
    Tcl_ObjType* oldTypePtr;
    SPtr         s;

    if (Tcl_ListObjGetElements (ip, obj, &lc, &lv) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Remember the old type after the conversion to list, or we will try to
     * free a list intrep using the free-proc of whatever type the word had
     * before. For example 'parsedvarname'. That would be bad. Segfault like
     * bad.
     */

    oldTypePtr = obj->typePtr;

    /* Now, if the value was pure we forcibly generate the string-rep, to
     * capture the existing semantics of the value. Because we now enter the
     * realm of unordered, and the actual value may not be. If so, then not
     * having the string-rep will later cause the generation of an arbitrarily
     * ordered string-rep when the value is shimmered to some other type. This
     * is most visible for lists, which are ordered. A shimmer list->set->list
     * may reorder the elements if we do not capture their order in the
     * string-rep.
     *
     * See test case -15.0 in sets.testsuite demonstrating this.
     * Disable the Tcl_GetString below and see the test fail.
     */

     Tcl_GetString (obj);

    /* Gen hash table from list */

    s = (SPtr) ckalloc (sizeof (S));
    Tcl_InitHashTable(&s->el, TCL_STRING_KEYS);

    for (i=0; i < lc; i++) {
	(void) Tcl_CreateHashEntry(&s->el,
		 Tcl_GetString (lv[i]), &new);
    }

    /*
     * Free the old internalRep before setting the new one. We do this as
     * late as possible to allow the conversion code, in particular
     * Tcl_ListObjGetElements, to use that old internalRep.
     */

    if ((oldTypePtr != NULL) && (oldTypePtr->freeIntRepProc != NULL)) {
	oldTypePtr->freeIntRepProc(obj);
    }

    obj->internalRep.otherValuePtr = s;
    obj->typePtr                   = &s_type;
    return TCL_OK;
}

/* .................................................. */

int
s_size (SPtr a)
{
    return a->el.numEntries;
}

int
s_empty (SPtr a)
{
    return (a->el.numEntries == 0);
}

void
s_free (SPtr a)
{
    Tcl_DeleteHashTable(&a->el);
    ckfree ((char*) a);
}

SPtr
s_dup (SPtr a)
{
    SPtr s = (SPtr) ckalloc (sizeof (S));
    Tcl_InitHashTable(&s->el, TCL_STRING_KEYS);

    if (!a) return s;
    s_add (s, a, NULL);
    return s;
}

int
s_contains (SPtr a, const char* item)
{
    return Tcl_FindHashEntry (&a->el, item) != NULL;
}

SPtr
s_difference (SPtr a, SPtr b)
{
    int            new;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    CONST char*    key;
    SPtr           s;

    /* a - nothing = a. Just duplicate */

    if (!b->el.numEntries) {
	return s_dup (a);
    }

    s = (SPtr) ckalloc (sizeof (S));
    Tcl_InitHashTable(&s->el, TCL_STRING_KEYS);

    /* nothing - b = nothing */

    if (!a->el.numEntries) return s;

    /* Have to get it the hard way, no shortcut */

    for(he = Tcl_FirstHashEntry(&a->el, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {
	key = Tcl_GetHashKey (&a->el, he);

	if (Tcl_FindHashEntry (&b->el, key) != NULL) continue;
	/* key is in a, not in b <=> in (a-b) */

	(void*) Tcl_CreateHashEntry(&s->el, key, &new);
    }

    return s;
}

SPtr
s_intersect (SPtr a, SPtr b)
{
    int            new;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    CONST char*    key;

    SPtr s = (SPtr) ckalloc (sizeof (S));
    Tcl_InitHashTable(&s->el, TCL_STRING_KEYS);

    /* Shortcut when we know that the result is empty */

    if (!a->el.numEntries) return s;
    if (!b->el.numEntries) return s;

    /* Ensure that we iterate over the smaller of the two sets */

    if (b->el.numEntries < a->el.numEntries) {
	SPtr t = a ; a = b ; b = t;
    }

    for(he = Tcl_FirstHashEntry(&a->el, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {
	key = Tcl_GetHashKey (&a->el, he);

	if (Tcl_FindHashEntry (&b->el, key) == NULL) continue;
	/* key is in a, in b <=> in (a*b) */

	(void*) Tcl_CreateHashEntry(&s->el, key, &new);
    }

    return s;
}

SPtr
s_union (SPtr a, SPtr b)
{
    int            new;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    CONST char*    key;

    SPtr s = (SPtr) ckalloc (sizeof (S));
    Tcl_InitHashTable(&s->el, TCL_STRING_KEYS);

    s_add (s, a, NULL);
    s_add (s, b, NULL);

    return s;
}

void
s_add (SPtr a, SPtr b, int* newPtr)
{
    int            new, nx = 0;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    CONST char*    key;

    if (b->el.numEntries) {
	for(he = Tcl_FirstHashEntry(&b->el, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs)) {
	    key = Tcl_GetHashKey (&b->el, he);
	    (void*) Tcl_CreateHashEntry(&a->el, key, &new);
	    if (new) {nx = 1;}
	}
    }
    if(newPtr) {*newPtr = nx;}
}

void
s_add1 (SPtr a, const char* item)
{
    int new;

    (void*) Tcl_CreateHashEntry(&a->el, item, &new);
}

void
s_subtract (SPtr a, SPtr b, int* delPtr)
{
    int            new;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he, *dhe;
    CONST char*    key;
    int            dx = 0;

    if (b->el.numEntries) {
	for(he = Tcl_FirstHashEntry(&b->el, &hs);
	    he != NULL;
	    he = Tcl_NextHashEntry(&hs)) {
	    key = Tcl_GetHashKey (&b->el, he);
	    dhe = Tcl_FindHashEntry(&a->el, key);
	    if (!dhe) continue;
	    /* Key is known, to be removed */
	    dx = 1;
	    Tcl_DeleteHashEntry (dhe);
	}
    }
    if(delPtr) {*delPtr = dx;}
}

void
s_subtract1 (SPtr a, const char* item)
{
    Tcl_HashEntry* he;

    he = Tcl_FindHashEntry(&a->el, item);
    if (!he) return;
    Tcl_DeleteHashEntry (he);
}

int
s_equal (SPtr a, SPtr b)
{
    /* (a == b) <=> (|a| == |b| && (a-b) = {})
     */

    int res = 0;

    if (s_size (a) == s_size(b)) {
	SPtr t = s_difference (a, b);
	res    = s_empty (t);
	s_free (t);
    }
    return res;
}

int
s_subsetof (SPtr a, SPtr b)
{
    /* (a <= b) <=> (|a| <= |b| && (a-b) = {})
     */

    int res = 0;

    if (s_size (a) <= s_size(b)) {
	SPtr t = s_difference (a, b);
	res    = s_empty (t);
	s_free (t);
    }
    return res;
}

/* .................................................. */


/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

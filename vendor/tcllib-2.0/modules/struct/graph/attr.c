/* struct::graph - critcl - layer 1 definitions
 * (c) Graph functions
 */

#include <string.h>
#include <attr.h>
#include <util.h>

/* .................................................. */

Tcl_Obj*
g_attr_serial (Tcl_HashTable* attr, Tcl_Obj* empty)
{
    Tcl_Obj*	   res;
    Tcl_Size	   listc, i;
    Tcl_Obj**	   listv;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;
    const char*	   key;

    if ((attr == NULL) || (attr->numEntries == 0)) {
	return empty;
    }

    listc = 2 * attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    for(i = 0, he = Tcl_FirstHashEntry(attr, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {

	key = Tcl_GetHashKey (attr, he);

	ASSERT_BOUNDS (i,   listc);
	ASSERT_BOUNDS (i+1, listc);

	listv [i] = Tcl_NewStringObj (key, TCL_AUTO_LENGTH); i++; /* OK tcl9 */
	listv [i] = (Tcl_Obj*) Tcl_GetHashValue(he);         i++;
    }

    res = Tcl_NewListObj (listc, listv); /* OK tcl9 */
    ckfree ((char*) listv);
    return res;
}

/* .................................................. */

int
g_attr_serok (Tcl_Interp* interp, Tcl_Obj* aserial, const char* what)
{
    Tcl_Size  lc;
    Tcl_Obj** lv;

    if (Tcl_ListObjGetElements (interp, aserial, &lc, &lv) != TCL_OK) { /* OK tcl9 */
	return 0;
    }
    if ((lc % 2) != 0) {
	Tcl_AppendResult (interp,
			  "error in serialization: malformed ",
			  what, " attribute dictionary.",
			  NULL);
	return 0;
    }
    return 1;
}

/* .................................................. */

void
g_attr_deserial (Tcl_HashTable** Astar, Tcl_Obj* dict)
{
    Tcl_HashEntry* he;
    CONST char*	   key;
    Tcl_Obj*	   val;
    int		   new;
    Tcl_Size	   listc, i;
    Tcl_Obj**	   listv;
    Tcl_HashTable* attr;

    /* NULL can happen via 'g_attr_dup' */
    if (!dict) return;

    Tcl_ListObjGetElements (NULL, dict, &listc, &listv); /* OK tcl9 */

    if (!listc) return;

    g_attr_extend (Astar);
    attr = *Astar;

    for (i = 0; i < listc; i+= 2) {
	ASSERT_BOUNDS (i,   listc);
	ASSERT_BOUNDS (i+1, listc);

	key = Tcl_GetString (listv [i]);
	val = listv [i+1];

	he = Tcl_CreateHashEntry(attr, key, &new);

	Tcl_IncrRefCount (val);
	Tcl_SetHashValue (he, (ClientData) val);
    }
}

/* .................................................. */

void
g_attr_delete (Tcl_HashTable** Astar)
{
    Tcl_HashTable* A = *Astar;
    Tcl_HashSearch hs;
    Tcl_HashEntry* he;

    if (!A) return;
    Astar = NULL;

    for(he = Tcl_FirstHashEntry(A, &hs);
	he != NULL;
	he = Tcl_NextHashEntry(&hs)) {
	Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
    }
    Tcl_DeleteHashTable(A);
    ckfree ((char*) A);
}

/* .................................................. */

void
g_attr_keys (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Size pc, Tcl_Obj* const* pv)
{
    Tcl_Size	   listc, i;
    Tcl_Obj**	   listv;
    Tcl_HashEntry* he;
    Tcl_HashSearch hs;
    const char*	   key;
    const char*	   pattern;
    int		   matchall = 0;

    if ((attr == NULL) || (attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL)); /* OK tcl9 */
	return;
    }

    listc = attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    if (pc) {
	pattern	 = Tcl_GetString(pv[0]);
	matchall = (strcmp (pattern, "*") == 0);
    }

    if (!pc || matchall) {
	/* Unpatterned retrieval, or pattern '*' */

	for (i = 0, he = Tcl_FirstHashEntry(attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    ASSERT_BOUNDS (i, listc);
	    listv [i++] = Tcl_NewStringObj (Tcl_GetHashKey (attr, he), TCL_AUTO_LENGTH); /* OK tcl9 */
	}

	ASSERT (i == listc, "Bad key retrieval");

    } else {
	/* Filtered retrieval, glob pattern */

	for (i = 0, he = Tcl_FirstHashEntry(attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (attr, he);
	    if (Tcl_StringMatch(key, pattern)) {
		ASSERT_BOUNDS (i, listc);

		listv [i++] = Tcl_NewStringObj (key, TCL_AUTO_LENGTH); /* OK tcl9 */
	    }
	}

	ASSERT (i <= listc, "Bad key glob retrieval");
	listc = i;
    }

    if (listc) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv)); /* OK tcl9 */
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL)); /* OK tcl9 */
    }

    ckfree ((char*) listv);
}

/* .................................................. */

void
g_attr_kexists (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Obj* key)
{
    Tcl_HashEntry* he;
    const char*	   ky = Tcl_GetString (key);

    if ((attr == NULL) || (attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (0)); /* OK tcl9 */
	return;
    }

    he	= Tcl_FindHashEntry (attr, ky);

    Tcl_SetObjResult (interp, Tcl_NewIntObj (he != NULL)); /* OK tcl9 */
}

/* .................................................. */

int
g_attr_get (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Obj* key, Tcl_Obj* o, const char* sep)
{
    Tcl_Obj*       av;
    Tcl_HashEntry* he = (attr
			 ? Tcl_FindHashEntry (attr, Tcl_GetString (key))
			 : NULL);

    if (!he) {
	Tcl_Obj* err = Tcl_NewObj ();

	Tcl_AppendToObj	   (err, "invalid key \"", TCL_AUTO_LENGTH); /* OK tcl9 */
	Tcl_AppendObjToObj (err, key);
	Tcl_AppendToObj    (err, sep, TCL_AUTO_LENGTH); /* OK tcl9 */
	Tcl_AppendObjToObj (err, o);
	Tcl_AppendToObj	   (err, "\"", TCL_AUTO_LENGTH); /* OK tcl9 */

	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    av = (Tcl_Obj*) Tcl_GetHashValue(he);
    Tcl_SetObjResult (interp, av);
    return TCL_OK;
}

/* .................................................. */

void
g_attr_getall (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Size pc, Tcl_Obj* const* pv)
{
    Tcl_HashEntry* he;
    Tcl_HashSearch hs;
    const char*	   key;
    Tcl_Size	   listc, i;
    Tcl_Obj**	   listv;
    const char*	   pattern = NULL;
    int		   matchall = 0;

    if ((attr == NULL) || (attr->numEntries == 0)) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL)); /* OK tcl9 */
	return;
    }

    if (pc) {
	pattern = Tcl_GetString (pv [0]);
	matchall = (strcmp (pattern, "*") == 0);
    }

    listc = 2 * attr->numEntries;
    listv = NALLOC (listc, Tcl_Obj*);

    if (!pc || matchall) {
	/* Unpatterned retrieval, or pattern '*' */

	for (i = 0, he = Tcl_FirstHashEntry(attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (attr, he);

	    ASSERT_BOUNDS (i,	listc);
	    ASSERT_BOUNDS (i+1, listc);

	    listv [i++] = Tcl_NewStringObj (key, TCL_AUTO_LENGTH); /* OK tcl9 */
	    listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	}

	ASSERT (i == listc, "Bad attribute retrieval");
    } else {
	/* Filtered retrieval, glob pattern */

	for (i = 0, he = Tcl_FirstHashEntry(attr, &hs);
	     he != NULL;
	     he = Tcl_NextHashEntry(&hs)) {

	    key = Tcl_GetHashKey (attr, he);

	    if (Tcl_StringMatch(key, pattern)) {
		ASSERT_BOUNDS (i,   listc);
		ASSERT_BOUNDS (i+1, listc);

		listv [i++] = Tcl_NewStringObj (key, TCL_AUTO_LENGTH); /* OK tcl9 */
		listv [i++] = (Tcl_Obj*) Tcl_GetHashValue(he);
	    }
	}

	ASSERT (i <= listc, "Bad attribute glob retrieval");
	listc = i;
    }

    if (listc) {
	Tcl_SetObjResult (interp, Tcl_NewListObj (listc, listv)); /* OK tcl9 */
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0, NULL)); /* OK tcl9 */
    }

    ckfree ((char*) listv);
}

/* .................................................. */

void
g_attr_unset (Tcl_HashTable* attr, Tcl_Obj* key)
{
    const char* ky = Tcl_GetString (key);

    if (attr) {
	Tcl_HashEntry* he = Tcl_FindHashEntry (attr, ky);
	if (he) {
	    Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
	    Tcl_DeleteHashEntry (he);
	}
    }
}

/* .................................................. */

void
g_attr_set (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Obj* key, Tcl_Obj* value)
{
    const char*	   ky = Tcl_GetString (key);
    Tcl_HashEntry* he = Tcl_FindHashEntry (attr, ky);

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(attr, ky, &new);
    } else {
	Tcl_DecrRefCount ((Tcl_Obj*) Tcl_GetHashValue(he));
    }

    Tcl_IncrRefCount (value);
    Tcl_SetHashValue (he, (ClientData) value);
    Tcl_SetObjResult (interp, value);
}

/* .................................................. */

void
g_attr_append (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Obj* key, Tcl_Obj* value)
{
    const char*	   ky = Tcl_GetString (key);
    Tcl_HashEntry* he = Tcl_FindHashEntry (attr, ky);

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(attr, ky, &new);

	Tcl_IncrRefCount (value);
	Tcl_SetHashValue (he, (ClientData) value);
    } else {
	Tcl_Obj* av = (Tcl_Obj*) Tcl_GetHashValue(he);

	if (Tcl_IsShared (av)) {
	    Tcl_DecrRefCount	  (av);
	    av = Tcl_DuplicateObj (av);
	    Tcl_IncrRefCount	  (av);

	    Tcl_SetHashValue (he, (ClientData) av);
	}

	Tcl_AppendObjToObj (av, value);
	value = av;
    }

    Tcl_SetObjResult (interp, value);
}

/* .................................................. */

void
g_attr_lappend (Tcl_HashTable* attr, Tcl_Interp* interp, Tcl_Obj* key, Tcl_Obj* value)
{
    const char*	   ky = Tcl_GetString (key);
    Tcl_HashEntry* he = Tcl_FindHashEntry (attr, ky);
    Tcl_Obj*	   av;

    if (he == NULL) {
	int new;
	he = Tcl_CreateHashEntry(attr, ky, &new);

	av = Tcl_NewListObj (0, NULL); /* OK tcl9 */
	Tcl_IncrRefCount (av);
	Tcl_SetHashValue (he, (ClientData) av);

    } else {
	av = (Tcl_Obj*) Tcl_GetHashValue(he);

	if (Tcl_IsShared (av)) {
	    Tcl_DecrRefCount	  (av);
	    av = Tcl_DuplicateObj (av);
	    Tcl_IncrRefCount	  (av);

	    Tcl_SetHashValue (he, (ClientData) av);
	}
    }

    Tcl_ListObjAppendElement (interp, av, value);
    Tcl_SetObjResult (interp, av);
}

/* .................................................. */

void
g_attr_extend (Tcl_HashTable** Astar)
{
    if (*Astar) return;

    *Astar = ALLOC (Tcl_HashTable);
    Tcl_InitHashTable (*Astar, TCL_STRING_KEYS);
}

/* .................................................. */

void
g_attr_dup (Tcl_HashTable** Astar, Tcl_HashTable* src)
{
    g_attr_deserial (Astar,
		     g_attr_serial (src, NULL));
}

/* .................................................. */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

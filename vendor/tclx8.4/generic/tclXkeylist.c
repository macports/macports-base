/* 
 * tclXkeylist.c --
 *
 *  Extended Tcl keyed list commands and interfaces.
 *-----------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXkeylist.c,v 1.8 2005/11/21 18:54:13 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Keyed lists are stored as arrays recursively defined objects.  The data
 * portion of a keyed list entry is a Tcl_Obj which may be a keyed list object
 * or any other Tcl object.  Since determine the structure of a keyed list is
 * lazy (you don't know if an element is data or another keyed list) until it
 * is accessed, the object can be transformed into a keyed list from a Tcl
 * string or list.
 */

/*
 * Adding a hash table over the entries allows for much faster Find
 * access to the keys (hash lookup instead of list search).  This adds
 * a hash table to each keyed list object.  That uses more memory, but
 * you can get an order of magnitude better performance with large
 * keyed list sets.  Uncomment this line to not use the hash table.
 */
/* #define NO_KEYLIST_HASH_TABLE */

/*
 * An entry in a keyed list array.
 *
 * JH: There was the supposition that making the key an object would
 * be faster, but I tried that and didn't find it to be true.  The
 * use of the layered hash table is a big win though.
 */
typedef struct {
    char *key;
    int keyLen;
    Tcl_Obj *valuePtr;
} keylEntry_t;

/*
 * Internal representation of a keyed list object.
 */
typedef struct {
    int		 arraySize;   /* Current slots available in the array.	*/
    int		 numEntries;  /* Number of actual entries in the array. */
    keylEntry_t *entries;     /* Array of keyed list entries.		*/
#ifndef NO_KEYLIST_HASH_TABLE
    Tcl_HashTable *hashTbl;   /* hash table mirror of the entries */
                              /* to improve speed */
#endif
} keylIntObj_t;

/*
 * Amount to increment array size by when it needs to grow.
 */
#define KEYEDLIST_ARRAY_INCR_SIZE 16

/*
 * Macro to duplicate a child entry of a keyed list if it is share by more
 * than the parent.
 * NO_KEYLIST_HASH_TABLE: We don't duplicate the hash table, so ensure
 * that consistency checks allow for portions where not all entries are
 * in the hash table.
 */
#define DupSharedKeyListChild(keylIntPtr, idx) \
    if (Tcl_IsShared(keylIntPtr->entries [idx].valuePtr)) { \
	keylIntPtr->entries [idx].valuePtr = \
	    Tcl_DuplicateObj (keylIntPtr->entries [idx].valuePtr); \
	Tcl_IncrRefCount(keylIntPtr->entries [idx].valuePtr); \
    }

/*
 * Macros to validate an keyed list object or internal representation
 */
#ifdef TCLX_DEBUG
#   define KEYL_OBJ_ASSERT(keylAPtr) {\
	TclX_Assert (keylAPtr->typePtr == &keyedListType); \
	ValidateKeyedList (keylAIntPtr); \
    }
#   define KEYL_REP_ASSERT(keylAIntPtr) \
	ValidateKeyedList (keylAIntPtr)
#else
#  define KEYL_REP_ASSERT(keylAIntPtr)
#endif


/*
 * Prototypes of internal functions.
 */
#ifdef TCLX_DEBUG
static void
ValidateKeyedList _ANSI_ARGS_((keylIntObj_t *keylIntPtr));
#endif
static int
ValidateKey _ANSI_ARGS_((Tcl_Interp *interp, char *key, int keyLen));

static keylIntObj_t *
AllocKeyedListIntRep _ANSI_ARGS_((void));

static void
FreeKeyedListData _ANSI_ARGS_((keylIntObj_t *keylIntPtr));

static void
EnsureKeyedListSpace _ANSI_ARGS_((keylIntObj_t *keylIntPtr,
				  int		newNumEntries));

static void
DeleteKeyedListEntry _ANSI_ARGS_((keylIntObj_t *keylIntPtr,
				  int		entryIdx));

static int
FindKeyedListEntry _ANSI_ARGS_((keylIntObj_t *keylIntPtr,
				char	     *key,
				int	     *keyLenPtr,
				char	    **nextSubKeyPtr));

static void
DupKeyedListInternalRep _ANSI_ARGS_((Tcl_Obj *srcPtr,
				     Tcl_Obj *copyPtr));

static void
FreeKeyedListInternalRep _ANSI_ARGS_((Tcl_Obj *keylPtr));

static int
SetKeyedListFromAny _ANSI_ARGS_((Tcl_Interp *interp,
				 Tcl_Obj    *objPtr));

static void
UpdateStringOfKeyedList _ANSI_ARGS_((Tcl_Obj *keylPtr));

static int 
TclX_KeylgetObjCmd _ANSI_ARGS_((ClientData   clientData,
				Tcl_Interp  *interp,
				int	     objc,
				Tcl_Obj	    *CONST objv[]));

static int
TclX_KeylsetObjCmd _ANSI_ARGS_((ClientData   clientData,
				Tcl_Interp  *interp,
				int	     objc,
				Tcl_Obj	    *CONST objv[]));

static int 
TclX_KeyldelObjCmd _ANSI_ARGS_((ClientData   clientData,
				Tcl_Interp  *interp,
				int	     objc,
				Tcl_Obj	    *CONST objv[]));

static int 
TclX_KeylkeysObjCmd _ANSI_ARGS_((ClientData   clientData,
				 Tcl_Interp  *interp,
				 int	      objc,
				 Tcl_Obj     *CONST objv[]));

/*
 * Type definition.
 */
static Tcl_ObjType keyedListType = {
    "keyedList",	      /* name */
    FreeKeyedListInternalRep, /* freeIntRepProc */
    DupKeyedListInternalRep,  /* dupIntRepProc */
    UpdateStringOfKeyedList,  /* updateStringProc */
    SetKeyedListFromAny	      /* setFromAnyProc */
};


/*-----------------------------------------------------------------------------
 * ValidateKeyedList --
 *   Validate a keyed list (only when TCLX_DEBUG is enabled).
 * Parameters:
 *   o keylIntPtr - Keyed list internal representation.
 *-----------------------------------------------------------------------------
 */
#ifdef TCLX_DEBUG
static void
ValidateKeyedList (keylIntPtr)
    keylIntObj_t *keylIntPtr;
{
    int idx;

    TclX_Assert (keylIntPtr->arraySize >= keylIntPtr->numEntries);
    TclX_Assert (keylIntPtr->arraySize >= 0);
    TclX_Assert (keylIntPtr->numEntries >= 0);
    TclX_Assert ((keylIntPtr->arraySize > 0) ?
		 (keylIntPtr->entries != NULL) : TRUE);
    TclX_Assert ((keylIntPtr->numEntries > 0) ?
		 (keylIntPtr->entries != NULL) : TRUE);

    for (idx = 0; idx < keylIntPtr->numEntries; idx++) {
	keylEntry_t *entryPtr = &(keylIntPtr->entries [idx]);
	TclX_Assert (entryPtr->key != NULL);
	TclX_Assert (entryPtr->valuePtr->refCount >= 1);
	if (entryPtr->valuePtr->typePtr == &keyedListType) {
	    ValidateKeyedList (entryPtr->valuePtr->internalRep.otherValuePtr);
	}
    }
}
#endif

/*-----------------------------------------------------------------------------
 * ValidateKey --
 *   Check that a key or keypath string is a valid value.
 *
 * Parameters:
 *   o interp - Used to return error messages.
 *   o key - Key string to check.
 *   o keyLen - Length of the string, used to check for binary data.
 * Returns:
 *    TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
ValidateKey (interp, key, keyLen)
    Tcl_Interp *interp;
    char *key;
    int keyLen;
{
    if (strlen (key) != (size_t) keyLen) {
	Tcl_AppendStringsToObj(Tcl_GetObjResult(interp),
		"keyed list key may not be a binary string", (char *) NULL);
	return TCL_ERROR;
    }
    if (keyLen == 0) {
	Tcl_AppendStringsToObj(Tcl_GetObjResult(interp),
		"keyed list key may not be an empty string", (char *) NULL);
	return TCL_ERROR;
    }
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * AllocKeyedListIntRep --
 *   Allocate an and initialize the keyed list internal representation.
 *
 * Returns:
 *    A pointer to the keyed list internal structure.
 *-----------------------------------------------------------------------------
 */
static keylIntObj_t *
AllocKeyedListIntRep ()
{
    keylIntObj_t *keylIntPtr;

    keylIntPtr = (keylIntObj_t *) ckalloc (sizeof (keylIntObj_t));
    memset(keylIntPtr, 0, sizeof (keylIntObj_t));
#ifndef NO_KEYLIST_HASH_TABLE
    keylIntPtr->hashTbl = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(keylIntPtr->hashTbl, TCL_STRING_KEYS);
#endif
    return keylIntPtr;
}

/*-----------------------------------------------------------------------------
 * FreeKeyedListData --
 *   Free the internal representation of a keyed list.
 *
 * Parameters:
 *   o keylIntPtr - Keyed list internal structure to free.
 *-----------------------------------------------------------------------------
 */
static void
FreeKeyedListData (keylIntPtr)
    keylIntObj_t *keylIntPtr;
{
    int idx;

    for (idx = 0; idx < keylIntPtr->numEntries ; idx++) {
	ckfree (keylIntPtr->entries [idx].key);
	Tcl_DecrRefCount(keylIntPtr->entries [idx].valuePtr);
    }
    if (keylIntPtr->entries != NULL)
	ckfree ((VOID*) keylIntPtr->entries);
#ifndef NO_KEYLIST_HASH_TABLE
    if (keylIntPtr->hashTbl != NULL) {
	Tcl_DeleteHashTable(keylIntPtr->hashTbl);
	ckfree((char *) (keylIntPtr->hashTbl));
    }
#endif
    ckfree ((VOID*) keylIntPtr);
}

/*-----------------------------------------------------------------------------
 * EnsureKeyedListSpace --
 *   Ensure there is enough room in a keyed list array for a certain number
 * of entries, expanding if necessary.
 *
 * Parameters:
 *   o keylIntPtr - Keyed list internal representation.
 *   o newNumEntries - The number of entries that are going to be added to
 *     the keyed list.
 *-----------------------------------------------------------------------------
 */
static void
EnsureKeyedListSpace (keylIntPtr, newNumEntries)
    keylIntObj_t *keylIntPtr;
    int		  newNumEntries;
{
    KEYL_REP_ASSERT (keylIntPtr);

    if ((keylIntPtr->arraySize - keylIntPtr->numEntries) < newNumEntries) {
	int newSize = keylIntPtr->arraySize + newNumEntries +
	    KEYEDLIST_ARRAY_INCR_SIZE;
	if (keylIntPtr->entries == NULL) {
	    keylIntPtr->entries = (keylEntry_t *)
		ckalloc (newSize * sizeof (keylEntry_t));
	} else {
	    keylIntPtr->entries = (keylEntry_t *)
		ckrealloc ((VOID *) keylIntPtr->entries,
			   newSize * sizeof (keylEntry_t));
	}
	keylIntPtr->arraySize = newSize;
    }

    KEYL_REP_ASSERT (keylIntPtr);
}

/*-----------------------------------------------------------------------------
 * DeleteKeyedListEntry --
 *   Delete an entry from a keyed list.
 *
 * Parameters:
 *   o keylIntPtr - Keyed list internal representation.
 *   o entryIdx - Index of entry to delete.
 *-----------------------------------------------------------------------------
 */
static void
DeleteKeyedListEntry (keylIntPtr, entryIdx)
    keylIntObj_t *keylIntPtr;
    int		  entryIdx;
{
    int idx;

#ifndef NO_KEYLIST_HASH_TABLE
    if (keylIntPtr->hashTbl != NULL) {
	Tcl_HashEntry *entryPtr;
	Tcl_HashSearch search;
	int nidx;

	entryPtr = Tcl_FindHashEntry(keylIntPtr->hashTbl,
		keylIntPtr->entries [entryIdx].key);
	if (entryPtr != NULL) {
	    Tcl_DeleteHashEntry(entryPtr);
	}

	/*
	 * In order to maintain consistency, we have to iterate over
	 * the entire hash table to find and decr relevant idxs.
	 * We have to do this even if the previous index was not found
	 * in the hash table, as Dup'ing doesn't dup the hash tables.
	 */
	for (entryPtr = Tcl_FirstHashEntry(keylIntPtr->hashTbl, &search);
	     entryPtr != NULL; entryPtr = Tcl_NextHashEntry(&search)) {
	    nidx = (int) Tcl_GetHashValue(entryPtr);
	    if (nidx > entryIdx) {
		Tcl_SetHashValue(entryPtr, (ClientData) (nidx - 1));
	    }
	}
    }
#endif

    ckfree (keylIntPtr->entries [entryIdx].key);
    Tcl_DecrRefCount(keylIntPtr->entries [entryIdx].valuePtr);

    for (idx = entryIdx; idx < keylIntPtr->numEntries - 1; idx++)
	keylIntPtr->entries [idx] = keylIntPtr->entries [idx + 1];
    keylIntPtr->numEntries--;

    KEYL_REP_ASSERT (keylIntPtr);
}

/*-----------------------------------------------------------------------------
 * FindKeyedListEntry --
 *   Find an entry in keyed list.
 *
 * Parameters:
 *   o keylIntPtr - Keyed list internal representation.
 *   o key - Name of key to search for.
 *   o keyLenPtr - In not NULL, the length of the key for this
 *     level is returned here.	This excludes subkeys and the `.' delimiters.
 *   o nextSubKeyPtr - If not NULL, the start of the name of the next
 *     sub-key within key is returned.
 * Returns:
 *   Index of the entry or -1 if not found.
 *-----------------------------------------------------------------------------
 */
static int
FindKeyedListEntry (keylIntPtr, key, keyLenPtr, nextSubKeyPtr)
    keylIntObj_t *keylIntPtr;
    char	 *key;
    int		 *keyLenPtr;
    char	**nextSubKeyPtr;
{
    char *keySeparPtr;
    int keyLen, findIdx = -1;

    keySeparPtr = strchr (key, '.');
    if (keySeparPtr != NULL) {
	keyLen = keySeparPtr - key;
    } else {
	keyLen = strlen (key);
    }

#ifndef NO_KEYLIST_HASH_TABLE
    if (keylIntPtr->hashTbl != NULL) {
	Tcl_HashEntry *entryPtr;
	char tmp = key[keyLen];
	if (keySeparPtr != NULL) {
	    /*
	     * A few extra guards in setting this, as if we are passed
	     * a const char, this can crash.
	     */
	    key[keyLen] = '\0';
	}
	entryPtr = Tcl_FindHashEntry(keylIntPtr->hashTbl, key);
	if (entryPtr != NULL) {
	    findIdx = (int) Tcl_GetHashValue(entryPtr);
	}
	if (keySeparPtr != NULL) {
	    key[keyLen] = tmp;
	}
    }
#endif

    if (findIdx == -1) {
	for (findIdx = 0; findIdx < keylIntPtr->numEntries; findIdx++) {
	    if (keylIntPtr->entries [findIdx].keyLen == keyLen
		    && STRNEQU(keylIntPtr->entries [findIdx].key, key, keyLen)) {
		break;
	    }
	}
    }

    if (nextSubKeyPtr != NULL) {
	if (keySeparPtr == NULL) {
	    *nextSubKeyPtr = NULL;
	} else {
	    *nextSubKeyPtr = keySeparPtr + 1;
	}
    }
    if (keyLenPtr != NULL) {
	*keyLenPtr = keyLen;
    }

    if (findIdx >= keylIntPtr->numEntries) {
	return -1;
    }

    return findIdx;
}

/*-----------------------------------------------------------------------------
 * FreeKeyedListInternalRep --
 *   Free the internal representation of a keyed list.
 *
 * Parameters:
 *   o keylPtr - Keyed list object being deleted.
 *-----------------------------------------------------------------------------
 */
static void
FreeKeyedListInternalRep (keylPtr)
    Tcl_Obj *keylPtr;
{
    FreeKeyedListData ((keylIntObj_t *) keylPtr->internalRep.otherValuePtr);
}

/*-----------------------------------------------------------------------------
 * DupKeyedListInternalRep --
 *   Duplicate the internal representation of a keyed list.
 *
 * Parameters:
 *   o srcPtr - Keyed list object to copy.
 *   o copyPtr - Target object to copy internal representation to.
 *-----------------------------------------------------------------------------
 */
static void
DupKeyedListInternalRep (srcPtr, copyPtr)
    Tcl_Obj *srcPtr;
    Tcl_Obj *copyPtr;
{
    keylIntObj_t *srcIntPtr =
	(keylIntObj_t *) srcPtr->internalRep.otherValuePtr;
    keylIntObj_t *copyIntPtr;
    int idx;

    KEYL_REP_ASSERT (srcIntPtr);

    copyIntPtr = (keylIntObj_t *) ckalloc (sizeof (keylIntObj_t));
    copyIntPtr->arraySize = srcIntPtr->arraySize;
    copyIntPtr->numEntries = srcIntPtr->numEntries;
    copyIntPtr->entries = (keylEntry_t *)
	ckalloc (copyIntPtr->arraySize * sizeof (keylEntry_t));
#ifndef NO_KEYLIST_HASH_TABLE
#if 0
    copyIntPtr->hashTbl = (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
    Tcl_InitHashTable(copyIntPtr->hashTbl, TCL_STRING_KEYS);
#else
    /*
     * NO_KEYLIST_HASH_TABLE: We don't duplicate the hash table, so ensure
     * that consistency checks allow for portions where not all entries are
     * in the hash table.
     */
    copyIntPtr->hashTbl = NULL;
#endif
#endif

    for (idx = 0; idx < srcIntPtr->numEntries ; idx++) {
	copyIntPtr->entries [idx].key =
	    ckstrdup (srcIntPtr->entries [idx].key);
	copyIntPtr->entries [idx].keyLen = srcIntPtr->entries [idx].keyLen;
	copyIntPtr->entries [idx].valuePtr =
	    Tcl_DuplicateObj(srcIntPtr->entries [idx].valuePtr);
	Tcl_IncrRefCount(copyIntPtr->entries [idx].valuePtr);
#ifndef NO_KEYLIST_HASH_TABLE
	/*
	 * If we dup the hash table as well and do other better tracking
	 * of all access, then we could remove the entries list.
	 */
#endif
    }

    copyPtr->internalRep.otherValuePtr = (VOID *) copyIntPtr;
    copyPtr->typePtr = &keyedListType;

    KEYL_REP_ASSERT (copyIntPtr);
}

/*-----------------------------------------------------------------------------
 * SetKeyedListFromAny --
 *   Convert an object to a keyed list from its string representation.	Only
 * the first level is converted, as there is no way of knowing how far down
 * the keyed list recurses until lower levels are accessed.
 *
 * Parameters:
 *   o objPtr - Object to convert to a keyed list.
 *-----------------------------------------------------------------------------
 */
static int
SetKeyedListFromAny (interp, objPtr) 
    Tcl_Interp *interp;
    Tcl_Obj    *objPtr;
{
    keylIntObj_t *keylIntPtr;
    keylEntry_t *keyEntryPtr;
    char *key;
    int keyLen, idx, objc, subObjc;
    Tcl_Obj **objv, **subObjv;
#ifndef NO_KEYLIST_HASH_TABLE
    int dummy;
    Tcl_HashEntry *entryPtr;
#endif

    if (Tcl_ListObjGetElements (interp, objPtr, &objc, &objv) != TCL_OK) {
	return TCL_ERROR;
    }

    keylIntPtr = AllocKeyedListIntRep();

    EnsureKeyedListSpace(keylIntPtr, objc);

    for (idx = 0; idx < objc; idx++) {
	if ((Tcl_ListObjGetElements(interp, objv[idx],
		     &subObjc, &subObjv) != TCL_OK)
		|| (subObjc != 2)) {
	    Tcl_ResetResult(interp);
	    Tcl_AppendStringsToObj(Tcl_GetObjResult (interp),
		    "keyed list entry must be a valid, 2 element list, got \"",
		    Tcl_GetString(objv[idx]), "\"", (char *) NULL);
	    FreeKeyedListData(keylIntPtr);
	    return TCL_ERROR;
	}

	key = Tcl_GetStringFromObj(subObjv[0], &keyLen);
	if (ValidateKey(interp, key, keyLen) == TCL_ERROR) {
	    FreeKeyedListData (keylIntPtr);
	    return TCL_ERROR;
	}
	/*
	 * When setting from a random list/string, we cannot allow
	 * keys to have embedded '.' path separators
	 */
	if ((strchr(key, '.') != NULL)) {
	    Tcl_AppendStringsToObj (Tcl_GetObjResult (interp),
		    "keyed list key may not contain a \".\"; ",
		    "it is used as a separator in key paths",
		    (char *) NULL);
	    FreeKeyedListData (keylIntPtr);
	    return TCL_ERROR;
	}
	keyEntryPtr = &(keylIntPtr->entries[idx]);

	keyEntryPtr->key = ckstrdup(key);
	keyEntryPtr->keyLen = keyLen;
	keyEntryPtr->valuePtr = Tcl_DuplicateObj(subObjv[1]);
	Tcl_IncrRefCount(keyEntryPtr->valuePtr);
#ifndef NO_KEYLIST_HASH_TABLE
	entryPtr = Tcl_CreateHashEntry(keylIntPtr->hashTbl,
		keyEntryPtr->key, &dummy);
	Tcl_SetHashValue(entryPtr, (ClientData) idx);
#endif

	keylIntPtr->numEntries++;
    }

    if ((objPtr->typePtr != NULL) &&
	(objPtr->typePtr->freeIntRepProc != NULL)) {
	(*objPtr->typePtr->freeIntRepProc) (objPtr);
    }
    objPtr->internalRep.otherValuePtr = (VOID *) keylIntPtr;
    objPtr->typePtr = &keyedListType;

    KEYL_REP_ASSERT (keylIntPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * UpdateStringOfKeyedList --
 *    Update the string representation of a keyed list.
 *
 * Parameters:
 *   o objPtr - Object to convert to a keyed list.
 *-----------------------------------------------------------------------------
 */
static void
UpdateStringOfKeyedList (keylPtr)
    Tcl_Obj  *keylPtr;
{
#define UPDATE_STATIC_SIZE 32
    int idx, strLen;
    Tcl_Obj **listObjv, *entryObjv [2], *tmpListObj;
    Tcl_Obj *staticListObjv [UPDATE_STATIC_SIZE];
    char *listStr;
    keylIntObj_t *keylIntPtr =
	(keylIntObj_t *) keylPtr->internalRep.otherValuePtr;

    /*
     * Conversion to strings is done via list objects to support binary data.
     */
    if (keylIntPtr->numEntries > UPDATE_STATIC_SIZE) {
	listObjv =
	    (Tcl_Obj **) ckalloc (keylIntPtr->numEntries * sizeof (Tcl_Obj *));
    } else {
	listObjv = staticListObjv;
    }

    /*
     * Convert each keyed list entry to a two element list object.  No
     * need to incr/decr ref counts, the list objects will take care of that.
     * FIX: Keeping key as string object will speed this up.
     */
    for (idx = 0; idx < keylIntPtr->numEntries; idx++) {
	entryObjv [0] = 
	    Tcl_NewStringObj (keylIntPtr->entries [idx].key,
		    keylIntPtr->entries [idx].keyLen);
	entryObjv [1] = keylIntPtr->entries [idx].valuePtr;
	listObjv [idx] = Tcl_NewListObj (2, entryObjv);
    }

    tmpListObj = Tcl_NewListObj (keylIntPtr->numEntries, listObjv);
    Tcl_IncrRefCount(tmpListObj);
    listStr = Tcl_GetStringFromObj (tmpListObj, &strLen);
    keylPtr->bytes = ckbinstrdup (listStr, strLen);
    keylPtr->length = strLen;
    Tcl_DecrRefCount(tmpListObj);

    if (listObjv != staticListObjv)
	ckfree ((VOID*) listObjv);
}

/*-----------------------------------------------------------------------------
 * TclX_NewKeyedListObj --
 *   Create and initialize a new keyed list object.
 *
 * Returns:
 *    A pointer to the object.
 *-----------------------------------------------------------------------------
 */
Tcl_Obj *
TclX_NewKeyedListObj ()
{
    Tcl_Obj *keylPtr = Tcl_NewObj ();
    keylIntObj_t *keylIntPtr = AllocKeyedListIntRep ();

    keylPtr->internalRep.otherValuePtr = (VOID *) keylIntPtr;
    keylPtr->typePtr = &keyedListType;
    return keylPtr;
}

/*-----------------------------------------------------------------------------
 * TclX_KeyedListGet --
 *   Retrieve a key value from a keyed list.
 *
 * Parameters:
 *   o interp - Error message will be return in result if there is an error.
 *   o keylPtr - Keyed list object to get key from.
 *   o key - The name of the key to extract.  Will recusively process sub-keys
 *     seperated by `.'.
 *   o valueObjPtrPtr - If the key is found, a pointer to the key object
 *     is returned here.  NULL is returned if the key is not present.
 * Returns:
 *   o TCL_OK - If the key value was returned.
 *   o TCL_BREAK - If the key was not found.
 *   o TCL_ERROR - If an error occured.
 *-----------------------------------------------------------------------------
 */
int
TclX_KeyedListGet (interp, keylPtr, key, valuePtrPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *keylPtr;
    char       *key;
    Tcl_Obj   **valuePtrPtr;
{
    keylIntObj_t *keylIntPtr;
    char *nextSubKey;
    int findIdx;

    while (1) {
	if (Tcl_ConvertToType (interp, keylPtr, &keyedListType) != TCL_OK)
	    return TCL_ERROR;
	keylIntPtr = (keylIntObj_t *) keylPtr->internalRep.otherValuePtr;
	KEYL_REP_ASSERT (keylIntPtr);

	findIdx = FindKeyedListEntry(keylIntPtr, key, NULL, &nextSubKey);

	/*
	 * If not found, return status.
	 */
	if (findIdx < 0) {
	    *valuePtrPtr = NULL;
	    return TCL_BREAK;
	}

	/*
	 * If we are at the last subkey, return the entry, otherwise recurse
	 * down looking for the entry.
	 */
	if (nextSubKey == NULL) {
	    *valuePtrPtr = keylIntPtr->entries [findIdx].valuePtr;
	    return TCL_OK;
	} else {
	    keylPtr = keylIntPtr->entries [findIdx].valuePtr;
	    key = nextSubKey;
	}
    }
}

/*-----------------------------------------------------------------------------
 * TclX_KeyedListSet --
 *   Set a key value in keyed list object.
 *
 * Parameters:
 *   o interp - Error message will be return in result object.
 *   o keylPtr - Keyed list object to update.
 *   o key - The name of the key to extract.  Will recursively process
 *     sub-key seperated by `.'.
 *   o valueObjPtr - The value to set for the key.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_KeyedListSet (interp, keylPtr, key, valuePtr)
    Tcl_Interp *interp;
    Tcl_Obj    *keylPtr;
    char       *key;
    Tcl_Obj    *valuePtr;
{
    keylIntObj_t *keylIntPtr;
    keylEntry_t *keyEntryPtr;
    char *nextSubKey;
    int findIdx, keyLen, status = TCL_OK;
    Tcl_Obj *newKeylPtr;

    while (1) {
	if (Tcl_ConvertToType (interp, keylPtr, &keyedListType) != TCL_OK)
	    return TCL_ERROR;
	keylIntPtr = (keylIntObj_t *) keylPtr->internalRep.otherValuePtr;
	KEYL_REP_ASSERT (keylIntPtr);

	findIdx = FindKeyedListEntry (keylIntPtr, key, &keyLen, &nextSubKey);

	/*
	 * If we are at the last subkey, either update or add an entry.
	 */
	if (nextSubKey == NULL) {
#ifndef NO_KEYLIST_HASH_TABLE
	    int dummy;
	    Tcl_HashEntry *entryPtr;
#endif
	    if (findIdx < 0) {
		EnsureKeyedListSpace (keylIntPtr, 1);
		findIdx = keylIntPtr->numEntries++;
	    } else {
		ckfree (keylIntPtr->entries [findIdx].key);
		Tcl_DecrRefCount(keylIntPtr->entries [findIdx].valuePtr);
	    }
	    keyEntryPtr = &(keylIntPtr->entries[findIdx]);
	    keyEntryPtr->key = (char *) ckalloc (keyLen + 1);
	    memcpy(keyEntryPtr->key, key, keyLen);
	    keyEntryPtr->key[keyLen] = '\0';
	    keyEntryPtr->keyLen      = keyLen;
	    keyEntryPtr->valuePtr    = valuePtr;
	    Tcl_IncrRefCount(valuePtr);
#ifndef NO_KEYLIST_HASH_TABLE
	    if (keylIntPtr->hashTbl == NULL) {
		keylIntPtr->hashTbl =
		    (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
		Tcl_InitHashTable(keylIntPtr->hashTbl, TCL_STRING_KEYS);
	    }
	    entryPtr = Tcl_CreateHashEntry(keylIntPtr->hashTbl,
		    keyEntryPtr->key, &dummy);
	    Tcl_SetHashValue(entryPtr, (ClientData) findIdx);
#endif
	    Tcl_InvalidateStringRep (keylPtr);

	    KEYL_REP_ASSERT (keylIntPtr);
	    return TCL_OK;
	}

	/*
	 * If we are not at the last subkey, recurse down, creating new
	 * entries if neccessary.  If this level key was not found, it
	 * means we must build new subtree. Don't insert the new tree until we
	 * come back without error.
	 */
	if (findIdx >= 0) {
	    DupSharedKeyListChild (keylIntPtr, findIdx);
	    status = TclX_KeyedListSet (interp,
		    keylIntPtr->entries [findIdx].valuePtr,
		    nextSubKey, valuePtr);
	    if (status == TCL_OK) {
		Tcl_InvalidateStringRep (keylPtr);
	    }
	} else {
#ifndef NO_KEYLIST_HASH_TABLE
	    int dummy;
	    Tcl_HashEntry *entryPtr;
#endif
	    newKeylPtr = TclX_NewKeyedListObj ();
	    Tcl_IncrRefCount(newKeylPtr);
	    if (TclX_KeyedListSet (interp, newKeylPtr,
			nextSubKey, valuePtr) != TCL_OK) {
		Tcl_DecrRefCount(newKeylPtr);
		return TCL_ERROR;
	    }
	    EnsureKeyedListSpace (keylIntPtr, 1);
	    findIdx = keylIntPtr->numEntries++;
	    keyEntryPtr = &(keylIntPtr->entries[findIdx]);
	    keyEntryPtr->key = (char *) ckalloc (keyLen + 1);
	    memcpy(keyEntryPtr->key, key, keyLen);
	    keyEntryPtr->key[keyLen] = '\0';
	    keyEntryPtr->keyLen      = keyLen;
	    keyEntryPtr->valuePtr    = newKeylPtr;
#ifndef NO_KEYLIST_HASH_TABLE
	    if (keylIntPtr->hashTbl == NULL) {
		keylIntPtr->hashTbl =
		    (Tcl_HashTable *) ckalloc(sizeof(Tcl_HashTable));
		Tcl_InitHashTable(keylIntPtr->hashTbl, TCL_STRING_KEYS);
	    }
	    entryPtr = Tcl_CreateHashEntry(keylIntPtr->hashTbl,
		    keyEntryPtr->key, &dummy);
	    Tcl_SetHashValue(entryPtr, (ClientData) findIdx);
#endif
	    Tcl_InvalidateStringRep (keylPtr);
	}

	KEYL_REP_ASSERT (keylIntPtr);
	return status;
    }
}

/*-----------------------------------------------------------------------------
 * TclX_KeyedListDelete --
 *   Delete a key value from keyed list.
 *
 * Parameters:
 *   o interp - Error message will be return in result if there is an error.
 *   o keylPtr - Keyed list object to update.
 *   o key - The name of the key to extract.  Will recusively process
 *     sub-key seperated by `.'.
 * Returns:
 *   o TCL_OK - If the key was deleted.
 *   o TCL_BREAK - If the key was not found.
 *   o TCL_ERROR - If an error occured.
 *-----------------------------------------------------------------------------
 */
int
TclX_KeyedListDelete (interp, keylPtr, key)
    Tcl_Interp *interp;
    Tcl_Obj    *keylPtr;
    char       *key;
{
    keylIntObj_t *keylIntPtr, *subKeylIntPtr;
    char *nextSubKey;
    int findIdx, status;

    if (Tcl_ConvertToType (interp, keylPtr, &keyedListType) != TCL_OK)
	return TCL_ERROR;
    keylIntPtr = (keylIntObj_t *) keylPtr->internalRep.otherValuePtr;

    findIdx = FindKeyedListEntry (keylIntPtr, key, NULL, &nextSubKey);

    /*
     * If not found, return status.
     */
    if (findIdx < 0) {
	KEYL_REP_ASSERT (keylIntPtr);
	return TCL_BREAK;
    }

    /*
     * If we are at the last subkey, delete the entry.
     */
    if (nextSubKey == NULL) {
	DeleteKeyedListEntry (keylIntPtr, findIdx);
	Tcl_InvalidateStringRep (keylPtr);

	KEYL_REP_ASSERT (keylIntPtr);
	return TCL_OK;
    }

    /*
     * If we are not at the last subkey, recurse down.	If the entry is
     * deleted and the sub-keyed list is empty, delete it as well.  Must
     * invalidate string, as it caches all representations below it.
     */
    DupSharedKeyListChild (keylIntPtr, findIdx);

    status = TclX_KeyedListDelete (interp,
				   keylIntPtr->entries [findIdx].valuePtr,
				   nextSubKey);
    if (status == TCL_OK) {
	subKeylIntPtr = (keylIntObj_t *)
	    keylIntPtr->entries [findIdx].valuePtr->internalRep.otherValuePtr;
	if (subKeylIntPtr->numEntries == 0) {
	    DeleteKeyedListEntry (keylIntPtr, findIdx);
	}
	Tcl_InvalidateStringRep (keylPtr);
    }

    KEYL_REP_ASSERT (keylIntPtr);
    return status;
}

/*-----------------------------------------------------------------------------
 * TclX_KeyedListGetKeys --
 *   Retrieve a list of keyed list keys.
 *
 * Parameters:
 *   o interp - Error message will be return in result if there is an error.
 *   o keylPtr - Keyed list object to get key from.
 *   o key - The name of the key to get the sub keys for.  NULL or empty
 *     to retrieve all top level keys.
 *   o listObjPtrPtr - List object is returned here with key as values.
 * Returns:
 *   o TCL_OK - If the zero or more key where returned.
 *   o TCL_BREAK - If the key was not found.
 *   o TCL_ERROR - If an error occured.
 *-----------------------------------------------------------------------------
 */
int
TclX_KeyedListGetKeys (interp, keylPtr, key, listObjPtrPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *keylPtr;
    char       *key;
    Tcl_Obj   **listObjPtrPtr;
{
    keylIntObj_t *keylIntPtr;
    Tcl_Obj *listObjPtr;
    char *nextSubKey;
    int idx, findIdx;

    if (Tcl_ConvertToType (interp, keylPtr, &keyedListType) != TCL_OK)
	return TCL_ERROR;
    keylIntPtr = (keylIntObj_t *) keylPtr->internalRep.otherValuePtr;

    /*
     * If key is not NULL or empty, then recurse down until we go past
     * the end of all of the elements of the key.
     */
    if ((key != NULL) && (key [0] != '\0')) {
	findIdx = FindKeyedListEntry (keylIntPtr, key, NULL, &nextSubKey);
	if (findIdx < 0) {
	    TclX_Assert (keylIntPtr->arraySize >= keylIntPtr->numEntries);
	    return TCL_BREAK;
	}
	TclX_Assert (keylIntPtr->arraySize >= keylIntPtr->numEntries);
	return TclX_KeyedListGetKeys (interp, 
				      keylIntPtr->entries [findIdx].valuePtr,
				      nextSubKey,
				      listObjPtrPtr);
    }

    /*
     * Reached the end of the full key, return all keys at this level.
     */
    listObjPtr = Tcl_NewObj();
    for (idx = 0; idx < keylIntPtr->numEntries; idx++) {
	Tcl_ListObjAppendElement(interp, listObjPtr,
		Tcl_NewStringObj(keylIntPtr->entries[idx].key,
			keylIntPtr->entries[idx].keyLen));
    }
    *listObjPtrPtr = listObjPtr;
    TclX_Assert (keylIntPtr->arraySize >= keylIntPtr->numEntries);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_KeylgetObjCmd --
 *     Implements the TCL keylget command:
 *	   keylget listvar ?key? ?retvar | {}?
 *-----------------------------------------------------------------------------
 */
static int
TclX_KeylgetObjCmd (clientData, interp, objc, objv)
    ClientData	 clientData;
    Tcl_Interp	*interp;
    int		 objc;
    Tcl_Obj	*CONST objv[];
{
    Tcl_Obj *keylPtr, *valuePtr;
    char *key;
    int keyLen, status;

    if ((objc < 2) || (objc > 4)) {
	return TclX_WrongArgs (interp, objv [0],
			       "listvar ?key? ?retvar | {}?");
    }

    /*
     * Handle request for list of keys, use keylkeys command.
     */
    if (objc == 2)
	return TclX_KeylkeysObjCmd (clientData, interp, objc, objv);

    keylPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (keylPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Handle retrieving a value for a specified key.
     */
    key = Tcl_GetStringFromObj (objv [2], &keyLen);
    if (ValidateKey(interp, key, keyLen) == TCL_ERROR) {
	return TCL_ERROR;
    }

    status = TclX_KeyedListGet (interp, keylPtr, key, &valuePtr);
    if (status == TCL_ERROR)
	return TCL_ERROR;

    /*
     * Handle key not found.
     */
    if (status == TCL_BREAK) {
	if (objc == 3) {
	    TclX_AppendObjResult (interp, "key \"",  key,
		    "\" not found in keyed list", (char *) NULL);
	    return TCL_ERROR;
	} else {
	    Tcl_SetBooleanObj (Tcl_GetObjResult (interp), FALSE);
	    return TCL_OK;
	}
    }

    /*
     * No variable specified, so return value in the result.
     */
    if (objc == 3) {
	Tcl_SetObjResult (interp, valuePtr);
	return TCL_OK;
    }

    /*
     * Variable (or empty variable name) specified.
     */
    if (!TclX_IsNullObj(objv [3]) &&
	    (Tcl_ObjSetVar2(interp, objv [3], NULL, valuePtr,
		    TCL_LEAVE_ERR_MSG) == NULL)) {
	return TCL_ERROR;
    }
    Tcl_SetBooleanObj (Tcl_GetObjResult (interp), TRUE);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_KeylsetObjCmd --
 *     Implements the TCL keylset command:
 *	   keylset listvar key value ?key value...?
 *-----------------------------------------------------------------------------
 */
static int
TclX_KeylsetObjCmd (clientData, interp, objc, objv)
    ClientData	 clientData;
    Tcl_Interp	*interp;
    int		 objc;
    Tcl_Obj	*CONST objv[];
{
    Tcl_Obj *keylVarPtr, *newVarObj;
    char *key;
    int idx, keyLen, result = TCL_OK;

    if ((objc < 4) || ((objc % 2) != 0)) {
	return TclX_WrongArgs (interp, objv [0],
			       "listvar key value ?key value...?");
    }

    /*
     * Get the variable that we are going to update.  If the var doesn't exist,
     * create it.  If it is shared by more than being a variable, duplicated
     * it.
     */
    keylVarPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, 0);
    if (keylVarPtr == NULL) {
	newVarObj = keylVarPtr = TclX_NewKeyedListObj();
	Tcl_IncrRefCount(newVarObj);
    } else if (Tcl_IsShared(keylVarPtr)) {
	newVarObj = keylVarPtr = Tcl_DuplicateObj(keylVarPtr);
	Tcl_IncrRefCount(newVarObj);
    } else {
	newVarObj = NULL;
    }

    for (idx = 2; idx < objc; idx += 2) {
	key = Tcl_GetStringFromObj (objv [idx], &keyLen);
	if ((ValidateKey(interp, key, keyLen) == TCL_ERROR)
		|| (TclX_KeyedListSet (interp, keylVarPtr, key, objv [idx+1])
			!= TCL_OK)) {
	    result = TCL_ERROR;
	    break;
	}
    }

    if ((result == TCL_OK) &&
	    (Tcl_ObjSetVar2(interp, objv[1], NULL, keylVarPtr,
		    TCL_LEAVE_ERR_MSG) == NULL)) {
	result = TCL_ERROR;
    }

    if (newVarObj != NULL) {
	Tcl_DecrRefCount(newVarObj);
    }
    return result;
}

/*-----------------------------------------------------------------------------
 * Tcl_KeyldelObjCmd --
 *     Implements the TCL keyldel command:
 *	   keyldel listvar key ?key ...?
 *----------------------------------------------------------------------------
 */
static int
TclX_KeyldelObjCmd (clientData, interp, objc, objv)
    ClientData	 clientData;
    Tcl_Interp	*interp;
    int		 objc;
    Tcl_Obj	*CONST objv[];
{
    Tcl_Obj *keylVarPtr, *keylPtr;
    char *key;
    int idx, keyLen, status;

    if (objc < 3) {
	return TclX_WrongArgs (interp, objv [0], "listvar key ?key ...?");
    }

    /*
     * Get the variable that we are going to update.  If it is shared by more
     * than being a variable, duplicated it.
     */
    keylVarPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (keylVarPtr == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_IsShared (keylVarPtr)) {
	keylPtr = Tcl_DuplicateObj (keylVarPtr);
	keylVarPtr = Tcl_ObjSetVar2(interp, objv[1], NULL, keylPtr,
				   TCL_LEAVE_ERR_MSG);
	if (keylVarPtr == NULL) {
	    Tcl_DecrRefCount(keylPtr);
	    return TCL_ERROR;
	}
	if (keylVarPtr != keylPtr)
	    Tcl_DecrRefCount(keylPtr);
    }
    keylPtr = keylVarPtr;

    for (idx = 2; idx < objc; idx++) {
	key = Tcl_GetStringFromObj (objv [idx], &keyLen);
	if (ValidateKey(interp, key, keyLen) == TCL_ERROR) {
	    return TCL_ERROR;
	}

	status = TclX_KeyedListDelete (interp, keylPtr, key);
	switch (status) {
	  case TCL_BREAK:
	    TclX_AppendObjResult (interp, "key not found: \"",
				  key, "\"", (char *) NULL);
	    return TCL_ERROR;
	  case TCL_ERROR:
	    return TCL_ERROR;
	}
    }

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_KeylkeysObjCmd --
 *     Implements the TCL keylkeys command:
 *	   keylkeys listvar ?key?
 *-----------------------------------------------------------------------------
 */
static int
TclX_KeylkeysObjCmd (clientData, interp, objc, objv)
    ClientData	 clientData;
    Tcl_Interp	*interp;
    int		 objc;
    Tcl_Obj	*CONST objv[];
{
    Tcl_Obj *keylPtr, *listObjPtr;
    char *key;
    int keyLen, status;

    if ((objc < 2) || (objc > 3)) {
	return TclX_WrongArgs (interp, objv [0], "listvar ?key?");
    }

    keylPtr = Tcl_ObjGetVar2(interp, objv[1], NULL, TCL_LEAVE_ERR_MSG);
    if (keylPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * If key argument is not specified, then objv [2] is NULL or empty,
     * meaning get top level keys.
     */
    if (objc < 3) {
	key = NULL;
    } else {
	key = Tcl_GetStringFromObj (objv [2], &keyLen);
	if (ValidateKey(interp, key, keyLen) == TCL_ERROR) {
	    return TCL_ERROR;
	}
    }

    status = TclX_KeyedListGetKeys (interp, keylPtr, key, &listObjPtr);
    switch (status) {
      case TCL_BREAK:
	TclX_AppendObjResult (interp, "key not found: \"", key, "\"",
			      (char *) NULL);
	return TCL_ERROR;
      case TCL_ERROR:
	return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, listObjPtr);

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_KeyedListInit --
 *   Initialize the keyed list commands for this interpreter.
 *
 * Parameters:
 *   o interp - Interpreter to add commands to.
 *-----------------------------------------------------------------------------
 */
void
TclX_KeyedListInit (interp)
    Tcl_Interp *interp;
{
    Tcl_RegisterObjType (&keyedListType);

    Tcl_CreateObjCommand (interp, "keylget", TclX_KeylgetObjCmd,
	    (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, "keylset", TclX_KeylsetObjCmd,
	    (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, "keyldel", TclX_KeyldelObjCmd,
	    (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, "keylkeys", TclX_KeylkeysObjCmd,
	    (ClientData) NULL, (Tcl_CmdDeleteProc*) NULL);
}



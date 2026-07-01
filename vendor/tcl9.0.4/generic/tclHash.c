/*
 * tclHash.c --
 *
 *	Implementation of in-memory hash tables for Tcl and Tcl-based
 *	applications.
 *
 * Copyright © 1991-1993 The Regents of the University of California.
 * Copyright © 1994 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"

/*
 * Prevent macros from clashing with function definitions.
 */

#undef Tcl_CreateHashEntry

/*
 * When there are this many entries per bucket, on average, rebuild the hash
 * table to make it larger.
 */

#define REBUILD_MULTIPLIER	3

/*
 * The following macro takes a preliminary integer hash value and produces an
 * index into a hash tables bucket list. The idea is to make it so that
 * preliminary values that are arbitrarily similar will end up in different
 * buckets. The hash function was taken from a random-number generator.
 */

#define RANDOM_INDEX(tablePtr, i) \
    ((((i)*(size_t)1103515245) >> (tablePtr)->downShift) & (tablePtr)->mask)

/*
 * Prototypes for the array hash key methods.
 */

static Tcl_HashEntry *	AllocArrayEntry(Tcl_HashTable *tablePtr, void *keyPtr);
static int		CompareArrayKeys(void *keyPtr, Tcl_HashEntry *hPtr);
static size_t		HashArrayKey(Tcl_HashTable *tablePtr, void *keyPtr);

/*
 * Prototypes for the string hash key methods.
 */

static Tcl_HashEntry *	AllocStringEntry(Tcl_HashTable *tablePtr,
			    void *keyPtr);

/*
 * Function prototypes for static functions in this file:
 */

static Tcl_HashEntry *	BogusFind(Tcl_HashTable *tablePtr, const char *key);
static Tcl_HashEntry *	BogusCreate(Tcl_HashTable *tablePtr, const char *key,
			    int *newPtr);
static Tcl_HashEntry *	CreateHashEntry(Tcl_HashTable *tablePtr, const char *key,
			    int *newPtr);
static Tcl_HashEntry *	FindHashEntry(Tcl_HashTable *tablePtr, const char *key);
static void		RebuildTable(Tcl_HashTable *tablePtr);

const Tcl_HashKeyType tclArrayHashKeyType = {
    TCL_HASH_KEY_TYPE_VERSION,		/* version */
    TCL_HASH_KEY_RANDOMIZE_HASH,	/* flags */
    HashArrayKey,			/* hashKeyProc */
    CompareArrayKeys,			/* compareKeysProc */
    AllocArrayEntry,			/* allocEntryProc */
    NULL				/* freeEntryProc */
};

const Tcl_HashKeyType tclOneWordHashKeyType = {
    TCL_HASH_KEY_TYPE_VERSION,		/* version */
    0,					/* flags */
    NULL, /* HashOneWordKey, */		/* hashProc */
    NULL, /* CompareOneWordKey, */	/* compareProc */
    NULL, /* AllocOneWordKey, */	/* allocEntryProc */
    NULL  /* FreeOneWordKey, */		/* freeEntryProc */
};

const Tcl_HashKeyType tclStringHashKeyType = {
    TCL_HASH_KEY_TYPE_VERSION,		/* version */
    0,					/* flags */
    TclHashStringKey,			/* hashKeyProc */
    TclCompareStringKeys,		/* compareKeysProc */
    AllocStringEntry,			/* allocEntryProc */
    NULL				/* freeEntryProc */
};

/*
 *----------------------------------------------------------------------
 *
 * Tcl_InitHashTable --
 *
 *	Given storage for a hash table, set up the fields to prepare the hash
 *	table for use.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	TablePtr is now ready to be passed to Tcl_FindHashEntry and
 *	Tcl_CreateHashEntry.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_InitHashTable(
    Tcl_HashTable *tablePtr,	/* Pointer to table record, which is supplied
				 * by the caller. */
    int keyType)		/* Type of keys to use in table:
				 * TCL_STRING_KEYS, TCL_ONE_WORD_KEYS, or an
				 * integer >= 2. */
{
    /*
     * Use a special value to inform the extended version that it must not
     * access any of the new fields in the Tcl_HashTable. If an extension is
     * rebuilt then any calls to this function will be redirected to the
     * extended version by a macro.
     */

    Tcl_InitCustomHashTable(tablePtr, keyType, (const Tcl_HashKeyType *) -1);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_InitCustomHashTable --
 *
 *	Given storage for a hash table, set up the fields to prepare the hash
 *	table for use. This is an extended version of Tcl_InitHashTable which
 *	supports user defined keys.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	TablePtr is now ready to be passed to Tcl_FindHashEntry and
 *	Tcl_CreateHashEntry.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_InitCustomHashTable(
    Tcl_HashTable *tablePtr,	/* Pointer to table record, which is supplied
				 * by the caller. */
    int keyType,		/* Type of keys to use in table:
				 * TCL_STRING_KEYS, TCL_ONE_WORD_KEYS,
				 * TCL_CUSTOM_TYPE_KEYS, TCL_CUSTOM_PTR_KEYS,
				 * or an integer >= 2. */
    const Tcl_HashKeyType *typePtr) /* Pointer to structure which defines the
				 * behaviour of this table. */
{
#if (TCL_SMALL_HASH_TABLE != 4)
    Tcl_Panic("Tcl_InitCustomHashTable: TCL_SMALL_HASH_TABLE is %d, not 4",
	    TCL_SMALL_HASH_TABLE);
#endif

    tablePtr->buckets = tablePtr->staticBuckets;
    tablePtr->staticBuckets[0] = tablePtr->staticBuckets[1] = 0;
    tablePtr->staticBuckets[2] = tablePtr->staticBuckets[3] = 0;
    tablePtr->numBuckets = TCL_SMALL_HASH_TABLE;
    tablePtr->numEntries = 0;
    tablePtr->rebuildSize = TCL_SMALL_HASH_TABLE*REBUILD_MULTIPLIER;
    tablePtr->downShift = 28;
    tablePtr->mask = 3;
    tablePtr->keyType = keyType;
    tablePtr->findProc = FindHashEntry;
    tablePtr->createProc = CreateHashEntry;

    if (typePtr == NULL) {
	/*
	 * The caller has been rebuilt so the hash table is an extended
	 * version.
	 */
    } else if (typePtr != (Tcl_HashKeyType *) -1) {
	/*
	 * The caller is requesting a customized hash table so it must be an
	 * extended version.
	 */

	tablePtr->typePtr = typePtr;
    } else {
	/*
	 * The caller has not been rebuilt so the hash table is not extended.
	 */
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FindHashEntry --
 *
 *	Given a hash table find the entry with a matching key.
 *
 * Results:
 *	The return value is a token for the matching entry in the hash table,
 *	or NULL if there was no matching entry.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
FindHashEntry(
    Tcl_HashTable *tablePtr,	/* Table in which to lookup entry. */
    const char *key)		/* Key to use to find matching entry. */
{
    return CreateHashEntry(tablePtr, key, NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * CreateHashEntry --
 *
 *	Given a hash table with string keys, and a string key, find the entry
 *	with a matching key. If there is no matching entry, then create a new
 *	entry that does match.
 *
 * Results:
 *	The return value is a pointer to the matching entry. If this is a
 *	newly-created entry, then *newPtr will be set to a non-zero value;
 *	otherwise *newPtr will be set to 0. If this is a new entry the value
 *	stored in the entry will initially be 0.
 *
 * Side effects:
 *	A new entry may be added to the hash table.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
CreateHashEntry(
    Tcl_HashTable *tablePtr,	/* Table in which to lookup entry. */
    const char *key,		/* Key to use to find or create matching
				 * entry. */
    int *newPtr)		/* Store info here telling whether a new entry
				 * was created. */
{
    Tcl_HashEntry *hPtr;
    const Tcl_HashKeyType *typePtr;
    size_t hash, index;

    if (tablePtr->keyType == TCL_STRING_KEYS) {
	typePtr = &tclStringHashKeyType;
    } else if (tablePtr->keyType == TCL_ONE_WORD_KEYS) {
	typePtr = &tclOneWordHashKeyType;
    } else if (tablePtr->keyType == TCL_CUSTOM_TYPE_KEYS
	    || tablePtr->keyType == TCL_CUSTOM_PTR_KEYS) {
	typePtr = tablePtr->typePtr;
    } else {
	typePtr = &tclArrayHashKeyType;
    }

    if (typePtr->hashKeyProc) {
	hash = typePtr->hashKeyProc(tablePtr, (void *) key);
	if (typePtr->flags & TCL_HASH_KEY_RANDOMIZE_HASH) {
	    index = RANDOM_INDEX(tablePtr, hash);
	} else {
	    index = hash & tablePtr->mask;
	}
    } else {
	hash = PTR2UINT(key);
	index = RANDOM_INDEX(tablePtr, hash);
    }

    /*
     * Search all of the entries in the appropriate bucket.
     */

    if (typePtr->compareKeysProc) {
	Tcl_CompareHashKeysProc *compareKeysProc = typePtr->compareKeysProc;
	if (typePtr->flags & TCL_HASH_KEY_DIRECT_COMPARE) {
	    for (hPtr = tablePtr->buckets[index]; hPtr != NULL;
		    hPtr = hPtr->nextPtr) {
		if (hash != hPtr->hash) {
		    continue;
		}
		/* if keys pointers or values are equal */
		if ((key == hPtr->key.oneWordValue)
		    || compareKeysProc((void *) key, hPtr)) {
		    if (newPtr && (newPtr != TCL_HASH_FIND)) {
			*newPtr = 0;
		    }
		    return hPtr;
		}
	    }
	} else { /* no direct compare - compare key addresses only */
	    for (hPtr = tablePtr->buckets[index]; hPtr != NULL;
		    hPtr = hPtr->nextPtr) {
		if (hash != hPtr->hash) {
		    continue;
		}
		/* if needle pointer equals content pointer or values equal */
		if ((key == hPtr->key.string)
			|| compareKeysProc((void *) key, hPtr)) {
		    if (newPtr && (newPtr != TCL_HASH_FIND)) {
			*newPtr = 0;
		    }
		    return hPtr;
		}
	    }
	}
    } else {
	for (hPtr = tablePtr->buckets[index]; hPtr != NULL;
		hPtr = hPtr->nextPtr) {
	    if (hash != hPtr->hash) {
		continue;
	    }
	    if (key == hPtr->key.oneWordValue) {
		if (newPtr && (newPtr != TCL_HASH_FIND)) {
		    *newPtr = 0;
		}
		return hPtr;
	    }
	}
    }

    if (!newPtr || (newPtr == TCL_HASH_FIND)) {
	/* This is the findProc functionality, so we are done. */
	return NULL;
    }

    /*
     * Entry not found. Add a new one to the bucket.
     */

    *newPtr = 1;
    if (typePtr->allocEntryProc) {
	hPtr = typePtr->allocEntryProc(tablePtr, (void *) key);
    } else {
	hPtr = (Tcl_HashEntry *)Tcl_Alloc(sizeof(Tcl_HashEntry));
	hPtr->key.oneWordValue = (char *) key;
	Tcl_SetHashValue(hPtr, NULL);
    }

    hPtr->tablePtr = tablePtr;
    hPtr->hash = hash;
    hPtr->nextPtr = tablePtr->buckets[index];
    tablePtr->buckets[index] = hPtr;
    tablePtr->numEntries++;

    /*
     * If the table has exceeded a decent size, rebuild it with many more
     * buckets.
     */

    if (tablePtr->numEntries >= tablePtr->rebuildSize) {
	RebuildTable(tablePtr);
    }
    return hPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DeleteHashEntry --
 *
 *	Remove a single entry from a hash table.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The entry given by entryPtr is deleted from its table and should never
 *	again be used by the caller. It is up to the caller to free the
 *	clientData field of the entry, if that is relevant.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DeleteHashEntry(
    Tcl_HashEntry *entryPtr)
{
    Tcl_HashEntry *prevPtr;
    const Tcl_HashKeyType *typePtr;
    Tcl_HashTable *tablePtr;
    Tcl_HashEntry **bucketPtr;
    size_t index;

    tablePtr = entryPtr->tablePtr;

    if (tablePtr->keyType == TCL_STRING_KEYS) {
	typePtr = &tclStringHashKeyType;
    } else if (tablePtr->keyType == TCL_ONE_WORD_KEYS) {
	typePtr = &tclOneWordHashKeyType;
    } else if (tablePtr->keyType == TCL_CUSTOM_TYPE_KEYS
	    || tablePtr->keyType == TCL_CUSTOM_PTR_KEYS) {
	typePtr = tablePtr->typePtr;
    } else {
	typePtr = &tclArrayHashKeyType;
    }

    if (typePtr->hashKeyProc == NULL
	    || typePtr->flags & TCL_HASH_KEY_RANDOMIZE_HASH) {
	index = RANDOM_INDEX(tablePtr, entryPtr->hash);
    } else {
	index = entryPtr->hash & tablePtr->mask;
    }

    bucketPtr = &tablePtr->buckets[index];

    if (*bucketPtr == entryPtr) {
	*bucketPtr = entryPtr->nextPtr;
    } else {
	for (prevPtr = *bucketPtr; ; prevPtr = prevPtr->nextPtr) {
	    if (prevPtr == NULL) {
		Tcl_Panic("malformed bucket chain in Tcl_DeleteHashEntry");
	    }
	    if (prevPtr->nextPtr == entryPtr) {
		prevPtr->nextPtr = entryPtr->nextPtr;
		break;
	    }
	}
    }

    tablePtr->numEntries--;
    if (typePtr->freeEntryProc) {
	typePtr->freeEntryProc(entryPtr);
    } else {
	Tcl_Free(entryPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DeleteHashTable --
 *
 *	Free up everything associated with a hash table except for the record
 *	for the table itself.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The hash table is no longer useable.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DeleteHashTable(
    Tcl_HashTable *tablePtr)	/* Table to delete. */
{
    Tcl_HashEntry *hPtr, *nextPtr;
    const Tcl_HashKeyType *typePtr;
    Tcl_Size i;

    if (tablePtr->keyType == TCL_STRING_KEYS) {
	typePtr = &tclStringHashKeyType;
    } else if (tablePtr->keyType == TCL_ONE_WORD_KEYS) {
	typePtr = &tclOneWordHashKeyType;
    } else if (tablePtr->keyType == TCL_CUSTOM_TYPE_KEYS
	    || tablePtr->keyType == TCL_CUSTOM_PTR_KEYS) {
	typePtr = tablePtr->typePtr;
    } else {
	typePtr = &tclArrayHashKeyType;
    }

    /*
     * Free up all the entries in the table.
     */

    for (i = 0; i < tablePtr->numBuckets; i++) {
	hPtr = tablePtr->buckets[i];
	while (hPtr != NULL) {
	    nextPtr = hPtr->nextPtr;
	    if (typePtr->freeEntryProc) {
		typePtr->freeEntryProc(hPtr);
	    } else {
		Tcl_Free(hPtr);
	    }
	    hPtr = nextPtr;
	}
    }

    /*
     * Free up the bucket array, if it was dynamically allocated.
     */

    if (tablePtr->buckets != tablePtr->staticBuckets) {
	if (typePtr->flags & TCL_HASH_KEY_SYSTEM_HASH) {
	    TclpSysFree((char *) tablePtr->buckets);
	} else {
	    Tcl_Free(tablePtr->buckets);
	}
    }

    /*
     * Arrange for panics if the table is used again without
     * re-initialization.
     */

    tablePtr->findProc = BogusFind;
    tablePtr->createProc = BogusCreate;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_FirstHashEntry --
 *
 *	Locate the first entry in a hash table and set up a record that can be
 *	used to step through all the remaining entries of the table.
 *
 * Results:
 *	The return value is a pointer to the first entry in tablePtr, or NULL
 *	if tablePtr has no entries in it. The memory at *searchPtr is
 *	initialized so that subsequent calls to Tcl_NextHashEntry will return
 *	all of the entries in the table, one at a time.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_HashEntry *
Tcl_FirstHashEntry(
    Tcl_HashTable *tablePtr,	/* Table to search. */
    Tcl_HashSearch *searchPtr)	/* Place to store information about progress
				 * through the table. */
{
    searchPtr->tablePtr = tablePtr;
    searchPtr->nextIndex = 0;
    searchPtr->nextEntryPtr = NULL;
    return Tcl_NextHashEntry(searchPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_NextHashEntry --
 *
 *	Once a hash table enumeration has been initiated by calling
 *	Tcl_FirstHashEntry, this function may be called to return successive
 *	elements of the table.
 *
 * Results:
 *	The return value is the next entry in the hash table being enumerated,
 *	or NULL if the end of the table is reached.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_HashEntry *
Tcl_NextHashEntry(
    Tcl_HashSearch *searchPtr)	/* Place to store information about progress
				 * through the table. Must have been
				 * initialized by calling
				 * Tcl_FirstHashEntry. */
{
    Tcl_HashEntry *hPtr;
    Tcl_HashTable *tablePtr = searchPtr->tablePtr;

    while (searchPtr->nextEntryPtr == NULL) {
	if (searchPtr->nextIndex >= tablePtr->numBuckets) {
	    return NULL;
	}
	searchPtr->nextEntryPtr =
		tablePtr->buckets[searchPtr->nextIndex];
	searchPtr->nextIndex++;
    }
    hPtr = searchPtr->nextEntryPtr;
    searchPtr->nextEntryPtr = hPtr->nextPtr;
    return hPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_HashStats --
 *
 *	Return statistics describing the layout of the hash table in its hash
 *	buckets.
 *
 * Results:
 *	The return value is a malloc-ed string containing information about
 *	tablePtr. It is the caller's responsibility to free this string.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

char *
Tcl_HashStats(
    Tcl_HashTable *tablePtr)	/* Table for which to produce stats. */
{
#define NUM_COUNTERS 10
    Tcl_Size i;
    size_t count[NUM_COUNTERS], overflow, j;
    double average, tmp;
    Tcl_HashEntry *hPtr;
    char *result, *p;

    /*
     * Compute a histogram of bucket usage.
     */

    for (i = 0; i < NUM_COUNTERS; i++) {
	count[i] = 0;
    }
    overflow = 0;
    average = 0.0;
    for (i = 0; i < tablePtr->numBuckets; i++) {
	j = 0;
	for (hPtr = tablePtr->buckets[i]; hPtr != NULL; hPtr = hPtr->nextPtr) {
	    j++;
	}
	if (j < NUM_COUNTERS) {
	    count[j]++;
	} else {
	    overflow++;
	}
	tmp = (double)j;
	if (tablePtr->numEntries != 0) {
	    average += (tmp+1.0)*(tmp/(double)tablePtr->numEntries)/2.0;
	}
    }

    /*
     * Print out the histogram and a few other pieces of information.
     */

    result = (char *)Tcl_Alloc((NUM_COUNTERS * 60) + 300);
    snprintf(result, 60, "%" TCL_SIZE_MODIFIER "u entries in table, %" TCL_SIZE_MODIFIER "u buckets\n",
	    tablePtr->numEntries, tablePtr->numBuckets);
    p = result + strlen(result);
    for (i = 0; i < NUM_COUNTERS; i++) {
	snprintf(p, 60, "number of buckets with %" TCL_SIZE_MODIFIER "u entries: %" TCL_SIZE_MODIFIER "u\n",
		i, count[i]);
	p += strlen(p);
    }
    snprintf(p, 60, "number of buckets with %d or more entries: %" TCL_SIZE_MODIFIER "u\n",
	    NUM_COUNTERS, overflow);
    p += strlen(p);
    snprintf(p, 60, "average search distance for entry: %.1f", average);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * AllocArrayEntry --
 *
 *	Allocate space for a Tcl_HashEntry containing the array key.
 *
 * Results:
 *	The return value is a pointer to the created entry.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
AllocArrayEntry(
    Tcl_HashTable *tablePtr,	/* Hash table. */
    void *keyPtr)		/* Key to store in the hash table entry. */
{
    Tcl_HashEntry *hPtr;
    size_t count = tablePtr->keyType * sizeof(int);
    size_t size = offsetof(Tcl_HashEntry, key) + count;

    if (size < sizeof(Tcl_HashEntry)) {
	size = sizeof(Tcl_HashEntry);
    }
    hPtr = (Tcl_HashEntry *)Tcl_Alloc(size);

    memcpy(hPtr->key.string, keyPtr, count);
    Tcl_SetHashValue(hPtr, NULL);

    return hPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * CompareArrayKeys --
 *
 *	Compares two array keys.
 *
 * Results:
 *	The return value is 0 if they are different and 1 if they are the
 *	same.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
CompareArrayKeys(
    void *keyPtr,		/* New key to compare. */
    Tcl_HashEntry *hPtr)	/* Existing key to compare. */
{
    size_t count = hPtr->tablePtr->keyType * sizeof(int);

    return !memcmp(keyPtr, hPtr->key.string, count);
}

/*
 *----------------------------------------------------------------------
 *
 * HashArrayKey --
 *
 *	Compute a one-word summary of an array, which can be used to generate
 *	a hash index.
 *
 * Results:
 *	The return value is a one-word summary of the information in
 *	string.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static size_t
HashArrayKey(
    Tcl_HashTable *tablePtr,	/* Hash table. */
    void *keyPtr)		/* Key from which to compute hash value. */
{
    const int *array = (const int *) keyPtr;
    size_t result;
    int count;

    for (result = 0, count = tablePtr->keyType; count > 0;
	    count--, array++) {
	result += *array;
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * AllocStringEntry --
 *
 *	Allocate space for a Tcl_HashEntry containing the string key.
 *
 * Results:
 *	The return value is a pointer to the created entry.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
AllocStringEntry(
    TCL_UNUSED(Tcl_HashTable *),
    void *keyPtr)		/* Key to store in the hash table entry. */
{
    const char *string = (const char *) keyPtr;
    Tcl_HashEntry *hPtr;
    size_t size, allocsize;

    allocsize = size = strlen(string) + 1;
    if (size < sizeof(hPtr->key)) {
	allocsize = sizeof(hPtr->key);
    }
    hPtr = (Tcl_HashEntry *)Tcl_Alloc(offsetof(Tcl_HashEntry, key) + allocsize);
    memset(hPtr, 0, offsetof(Tcl_HashEntry, key) + allocsize);
    memcpy(hPtr->key.string, string, size);
    Tcl_SetHashValue(hPtr, NULL);
    return hPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompareStringKeys --
 *
 *	Compares two string keys.
 *
 * Results:
 *	The return value is 0 if they are different and 1 if they are the
 *	same.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclCompareStringKeys(
    void *keyPtr,		/* New key to compare. */
    Tcl_HashEntry *hPtr)	/* Existing key to compare. */
{
    return !strcmp((char *)keyPtr, hPtr->key.string);
}

/*
 *----------------------------------------------------------------------
 *
 * TclHashStringKey --
 *
 *	Compute a one-word summary of a text string, which can be used to
 *	generate a hash index.
 *
 * Results:
 *	The return value is a one-word summary of the information in string.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

size_t
TclHashStringKey(
    TCL_UNUSED(Tcl_HashTable *),
    void *keyPtr)		/* Key from which to compute hash value. */
{
    const char *string = (const char *)keyPtr;
    size_t result;
    char c;

    /*
     * I tried a zillion different hash functions and asked many other people
     * for advice. Many people had their own favorite functions, all
     * different, but no-one had much idea why they were good ones. I chose
     * the one below (multiply by 9 and add new character) because of the
     * following reasons:
     *
     * 1. Multiplying by 10 is perfect for keys that are decimal strings, and
     *    multiplying by 9 is just about as good.
     * 2. Times-9 is (shift-left-3) plus (old). This means that each
     *    character's bits hang around in the low-order bits of the hash value
     *    for ever, plus they spread fairly rapidly up to the high-order bits
     *    to fill out the hash value. This seems works well both for decimal
     *    and non-decimal strings, but isn't strong against maliciously-chosen
     *    keys.
     *
     * Note that this function is very weak against malicious strings; it's
     * very easy to generate multiple keys that have the same hashcode. On the
     * other hand, that hardly ever actually occurs and this function *is*
     * very cheap, even by comparison with industry-standard hashes like FNV.
     * If real strength of hash is required though, use a custom hash based on
     * Bob Jenkins's lookup3(), but be aware that it's significantly slower.
     * Since Tcl command and namespace names are usually reasonably-named (the
     * main use for string hashes in modern Tcl) speed is far more important
     * than strength.
     *
     * See also HashString in tclLiteral.c.
     * See also TclObjHashKey in tclObj.c.
     *
     * See [tcl-Feature Request #2958832]
     */

    if ((result = UCHAR(*string)) != 0) {
	while ((c = *++string) != 0) {
	    result += (result << 3) + UCHAR(c);
	}
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * BogusFind --
 *
 *	This function is invoked when Tcl_FindHashEntry is called on a
 *	table that has been deleted.
 *
 * Results:
 *	If Tcl_Panic returns (which it shouldn't) this function returns NULL.
 *
 * Side effects:
 *	Generates a panic.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
BogusFind(
    TCL_UNUSED(Tcl_HashTable *),
    TCL_UNUSED(const char *))
{
    Tcl_Panic("called %s on deleted table", "Tcl_FindHashEntry");
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * BogusCreate --
 *
 *	This function is invoked when Tcl_CreateHashEntry is called on a
 *	table that has been deleted.
 *
 * Results:
 *	If panic returns (which it shouldn't) this function returns NULL.
 *
 * Side effects:
 *	Generates a panic.
 *
 *----------------------------------------------------------------------
 */

static Tcl_HashEntry *
BogusCreate(
    TCL_UNUSED(Tcl_HashTable *),
    TCL_UNUSED(const char *),
    TCL_UNUSED(int *))
{
    Tcl_Panic("called %s on deleted table", "Tcl_CreateHashEntry");
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * RebuildTable --
 *
 *	This function is invoked when the ratio of entries to hash buckets
 *	becomes too large. It creates a new table with a larger bucket array
 *	and moves all of the entries into the new table.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Memory gets reallocated and entries get re-hashed to new buckets.
 *
 *----------------------------------------------------------------------
 */

static void
RebuildTable(
    Tcl_HashTable *tablePtr)	/* Table to enlarge. */
{
    size_t count, index, oldSize = tablePtr->numBuckets;
    Tcl_HashEntry **oldBuckets = tablePtr->buckets;
    Tcl_HashEntry **oldChainPtr, **newChainPtr;
    Tcl_HashEntry *hPtr;
    const Tcl_HashKeyType *typePtr;

    /* Avoid outgrowing capability of the memory allocators */
    if (oldSize > UINT_MAX / (4 * sizeof(Tcl_HashEntry *))) {
	tablePtr->rebuildSize = INT_MAX;
	return;
    }

    if (tablePtr->keyType == TCL_STRING_KEYS) {
	typePtr = &tclStringHashKeyType;
    } else if (tablePtr->keyType == TCL_ONE_WORD_KEYS) {
	typePtr = &tclOneWordHashKeyType;
    } else if (tablePtr->keyType == TCL_CUSTOM_TYPE_KEYS
	    || tablePtr->keyType == TCL_CUSTOM_PTR_KEYS) {
	typePtr = tablePtr->typePtr;
    } else {
	typePtr = &tclArrayHashKeyType;
    }

    /*
     * Allocate and initialize the new bucket array, and set up hashing
     * constants for new array size.
     */

    tablePtr->numBuckets *= 4;
    if (typePtr->flags & TCL_HASH_KEY_SYSTEM_HASH) {
	tablePtr->buckets = (Tcl_HashEntry **)TclpSysAlloc(
		tablePtr->numBuckets * sizeof(Tcl_HashEntry *));
    } else {
	tablePtr->buckets =
		(Tcl_HashEntry **)Tcl_Alloc(tablePtr->numBuckets * sizeof(Tcl_HashEntry *));
    }
    for (count = tablePtr->numBuckets, newChainPtr = tablePtr->buckets;
	    count > 0; count--, newChainPtr++) {
	*newChainPtr = NULL;
    }
    tablePtr->rebuildSize *= 4;
    if (tablePtr->downShift > 1) {
	tablePtr->downShift -= 2;
    }
    tablePtr->mask = (tablePtr->mask << 2) + 3;

    /*
     * Rehash all of the existing entries into the new bucket array.
     */

    for (oldChainPtr = oldBuckets; oldSize > 0; oldSize--, oldChainPtr++) {
	for (hPtr = *oldChainPtr; hPtr != NULL; hPtr = *oldChainPtr) {
	    *oldChainPtr = hPtr->nextPtr;
	    if (typePtr->hashKeyProc == NULL
		    || typePtr->flags & TCL_HASH_KEY_RANDOMIZE_HASH) {
		index = RANDOM_INDEX(tablePtr, hPtr->hash);
	    } else {
		index = hPtr->hash & tablePtr->mask;
	    }
	    hPtr->nextPtr = tablePtr->buckets[index];
	    tablePtr->buckets[index] = hPtr;
	}
    }

    /*
     * Free up the old bucket array, if it was dynamically allocated.
     */

    if (oldBuckets != tablePtr->staticBuckets) {
	if (typePtr->flags & TCL_HASH_KEY_SYSTEM_HASH) {
	    TclpSysFree((char *) oldBuckets);
	} else {
	    Tcl_Free(oldBuckets);
	}
    }
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

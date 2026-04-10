/*
 * tclStrIdxTree.h --
 *
 *	Declarations of string index tries and other primitives currently
 *  back-ported from tclSE.
 *
 * Copyright (c) 2016 Serg G. Brester (aka sebres)
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifndef _TCLSTRIDXTREE_H
#define _TCLSTRIDXTREE_H

#include "tclInt.h"

/*
 * Main structures declarations of index tree and entry
 */

typedef struct TclStrIdx TclStrIdx;

/*
 * Top level structure of the tree, or first two fields of the interior
 * structure.
 *
 * Note that this is EXACTLY two pointers so it is the same size as the
 * twoPtrValue of a Tcl_ObjInternalRep. This is how the top level structure
 * of the tree is always allocated. (This type constraint is asserted in
 * TclStrIdxTreeNewObj() so it's guaranteed.)
 *
 * Also note that if firstPtr is not NULL, lastPtr must also be not NULL.
 * The case where firstPtr is not NULL and lastPtr is NULL is special (a
 * smart pointer to one of these) and is not actually a valid instance of
 * this structure.
 */
typedef struct TclStrIdxTree {
    TclStrIdx *firstPtr;
    TclStrIdx *lastPtr;
} TclStrIdxTree;

/*
 * An interior node of the tree. Always directly allocated.
 */
struct TclStrIdx {
    TclStrIdxTree childTree;
    TclStrIdx *nextPtr;
    TclStrIdx *prevPtr;
    Tcl_Obj *key;
    Tcl_Size length;
    void *value;
};

/*
 *----------------------------------------------------------------------
 *
 * TclUtfFindEqual, TclUtfFindEqualNC --
 *
 *	Find largest part of string cs in string cin (case sensitive and not).
 *
 * Results:
 *	Return position of UTF character in cs after last equal character.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static inline const char *
TclUtfFindEqual(
    const char *cs,		/* UTF string to find in cin. */
    const char *cse,		/* End of cs */
    const char *cin,		/* UTF string will be browsed. */
    const char *cine)		/* End of cin */
{
    const char *ret = cs;
    Tcl_UniChar ch1, ch2;

    do {
	cs += TclUtfToUniChar(cs, &ch1);
	cin += TclUtfToUniChar(cin, &ch2);
	if (ch1 != ch2) {
	    break;
	}
    } while ((ret = cs) < cse && cin < cine);
    return ret;
}

static inline const char *
TclUtfFindEqualNC(
    const char *cs,		/* UTF string to find in cin. */
    const char *cse,		/* End of cs */
    const char *cin,		/* UTF string will be browsed. */
    const char *cine,		/* End of cin */
    const char **cinfnd)	/* Return position in cin */
{
    const char *ret = cs;
    Tcl_UniChar ch1, ch2;

    do {
	cs += TclUtfToUniChar(cs, &ch1);
	cin += TclUtfToUniChar(cin, &ch2);
	if (ch1 != ch2) {
	    ch1 = Tcl_UniCharToLower(ch1);
	    ch2 = Tcl_UniCharToLower(ch2);
	    if (ch1 != ch2) {
		break;
	    }
	}
	*cinfnd = cin;
    } while ((ret = cs) < cse && cin < cine);
    return ret;
}

static inline const char *
TclUtfFindEqualNCInLwr(
    const char *cs,		/* UTF string (in anycase) to find in cin. */
    const char *cse,		/* End of cs */
    const char *cin,		/* UTF string (in lowercase) will be browsed. */
    const char *cine,		/* End of cin */
    const char **cinfnd)	/* Return position in cin */
{
    const char *ret = cs;
    Tcl_UniChar ch1, ch2;

    do {
	cs += TclUtfToUniChar(cs, &ch1);
	cin += TclUtfToUniChar(cin, &ch2);
	if (ch1 != ch2) {
	    ch1 = Tcl_UniCharToLower(ch1);
	    if (ch1 != ch2) {
		break;
	    }
	}
	*cinfnd = cin;
    } while ((ret = cs) < cse && cin < cine);
    return ret;
}

/*
 * Primitives to safe set, reset and free references.
 */

#define TclUnsetObjRef(obj) \
    do {								\
	if (obj != NULL) {						\
	    Tcl_DecrRefCount(obj);					\
	    obj = NULL;							\
	}								\
    } while (0)
#define TclInitObjRef(obj, val) \
    do {								\
	obj = (val);							\
	if (obj) {							\
	    Tcl_IncrRefCount(obj);					\
	}								\
    } while (0)
#define TclSetObjRef(obj, val) \
    do {								\
	Tcl_Obj *nval = (val);						\
	if (obj != nval) {						\
	    Tcl_Obj *prev = obj;					\
	    TclInitObjRef(obj, nval);					\
	    if (prev != NULL) {						\
		Tcl_DecrRefCount(prev);					\
	    }								\
	}								\
    } while (0)

/*
 * Prototypes of module functions.
 */

MODULE_SCOPE const char*TclStrIdxTreeSearch(TclStrIdxTree **foundParent,
			    TclStrIdx **foundItem, TclStrIdxTree *tree,
			    const char *start, const char *end);
MODULE_SCOPE int	TclStrIdxTreeBuildFromList(TclStrIdxTree *idxTree,
			    Tcl_Size lstc, Tcl_Obj **lstv, void **values);
MODULE_SCOPE Tcl_Obj *	TclStrIdxTreeNewObj(void);
MODULE_SCOPE TclStrIdxTree*TclStrIdxTreeGetFromObj(Tcl_Obj *objPtr);

#ifdef TEST_STR_IDX_TREE
/* currently unused, debug resp. test purposes only */
MODULE_SCOPE Tcl_ObjCmdProc TclStrIdxTreeTestObjCmd;
#endif

#endif /* _TCLSTRIDXTREE_H */

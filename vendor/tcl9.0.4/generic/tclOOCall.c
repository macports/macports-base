/*
 * tclOOCall.c --
 *
 *	This file contains the method call chain management code for the
 *	object-system core. It also contains everything else that does
 *	inheritance hierarchy traversal.
 *
 * Copyright © 2005-2019 Donal K. Fellows
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "tclInt.h"
#include "tclOOInt.h"

/*
 * Structure containing a CallChain and any other values needed only during
 * the construction of the CallChain.
 */
typedef struct ChainBuilder {
    CallChain *callChainPtr;	/* The call chain being built. */
    size_t filterLength;	/* Number of entries in the call chain that
				 * are due to processing filters and not the
				 * main call chain. */
    Object *oPtr;		/* The object that we are building the chain
				 * for. */
} ChainBuilder;

/*
 * Structures used for traversing the class hierarchy to find out where
 * definitions are supposed to be done.
 */

typedef struct DefineEntry {
    Class *definerCls;
    Tcl_Obj *namespaceName;
} DefineEntry;

typedef struct DefineChain {
    DefineEntry *list;
    int num;
    int size;
} DefineChain;

/*
 * Extra flags used for call chain management.
 */
enum CallChainFlags {
    DEFINITE_PROTECTED = 0x100000,
    DEFINITE_PUBLIC = 0x200000,
    KNOWN_STATE = (DEFINITE_PROTECTED | DEFINITE_PUBLIC),
    SPECIAL = (CONSTRUCTOR | DESTRUCTOR | FORCE_UNKNOWN),
    BUILDING_MIXINS = 0x400000,
    TRAVERSED_MIXIN = 0x800000,
    OBJECT_MIXIN = 0x1000000,
    DEFINE_FOR_CLASS = 0x2000000
};

#define MIXIN_CONSISTENT(flags) \
    (((flags) & OBJECT_MIXIN) ||					\
	!((flags) & BUILDING_MIXINS) == !((flags) & TRAVERSED_MIXIN))

/*
 * Note that the flag bit PRIVATE_METHOD has a confusing name; it's just for
 * Itcl's special type of private.
 */

#define IS_PUBLIC(mPtr)				\
    (((mPtr)->flags & PUBLIC_METHOD) != 0)
#define IS_UNEXPORTED(mPtr)			\
    (((mPtr)->flags & SCOPE_FLAGS) == 0)
#define IS_ITCLPRIVATE(mPtr)				\
    (((mPtr)->flags & PRIVATE_METHOD) != 0)
#define IS_PRIVATE(mPtr)			\
    (((mPtr)->flags & TRUE_PRIVATE_METHOD) != 0)
#define WANT_PUBLIC(flags)			\
    (((flags) & PUBLIC_METHOD) != 0)
#define WANT_UNEXPORTED(flags)			\
    (((flags) & (PRIVATE_METHOD | TRUE_PRIVATE_METHOD)) == 0)
#define WANT_ITCLPRIVATE(flags)			\
    (((flags) & PRIVATE_METHOD) != 0)
#define WANT_PRIVATE(flags)			\
    (((flags) & TRUE_PRIVATE_METHOD) != 0)

/*
 * Name the bits used in the names table values.
 */
enum NameTableValues {
    IN_LIST = 1,		/* Seen an implementation. */
    NO_IMPLEMENTATION = 2	/* Seen, but not implemented yet. */
};

/*
 * Function declarations for things defined in this file.
 */

static void		AddClassFiltersToCallContext(Object *const oPtr,
			    Class *clsPtr, ChainBuilder *const cbPtr,
			    Tcl_HashTable *const doneFilters, int flags);
static void		AddClassMethodNames(Class *clsPtr, int flags,
			    Tcl_HashTable *const namesPtr,
			    Tcl_HashTable *const examinedClassesPtr);
static inline void	AddDefinitionNamespaceToChain(Class *const definerCls,
			    Tcl_Obj *const namespaceName,
			    DefineChain *const definePtr, int flags);
static inline void	AddMethodToCallChain(Method *const mPtr,
			    ChainBuilder *const cbPtr,
			    Tcl_HashTable *const doneFilters,
			    Class *const filterDecl, int flags);
static inline int	AddInstancePrivateToCallContext(Object *const oPtr,
			    Tcl_Obj *const methodNameObj,
			    ChainBuilder *const cbPtr, int flags);
static inline void	AddStandardMethodName(int flags, Tcl_Obj *namePtr,
			    Method *mPtr, Tcl_HashTable *namesPtr);
static inline void	AddPrivateMethodNames(Tcl_HashTable *methodsTablePtr,
			    Tcl_HashTable *namesPtr);
static inline int	AddSimpleChainToCallContext(Object *const oPtr,
			    Class *const contextCls,
			    Tcl_Obj *const methodNameObj,
			    ChainBuilder *const cbPtr,
			    Tcl_HashTable *const doneFilters, int flags,
			    Class *const filterDecl);
static int		AddPrivatesFromClassChainToCallContext(Class *classPtr,
			    Class *const contextCls,
			    Tcl_Obj *const methodNameObj,
			    ChainBuilder *const cbPtr,
			    Tcl_HashTable *const doneFilters, int flags,
			    Class *const filterDecl);
static int		AddSimpleClassChainToCallContext(Class *classPtr,
			    Tcl_Obj *const methodNameObj,
			    ChainBuilder *const cbPtr,
			    Tcl_HashTable *const doneFilters, int flags,
			    Class *const filterDecl);
static void		AddSimpleClassDefineNamespaces(Class *classPtr,
			    DefineChain *const definePtr, int flags);
static inline void	AddSimpleDefineNamespaces(Object *const oPtr,
			    DefineChain *const definePtr, int flags);
static int		CmpStr(const void *ptr1, const void *ptr2);
static void		DupMethodNameRep(Tcl_Obj *srcPtr, Tcl_Obj *dstPtr);
static Tcl_NRPostProc	FinalizeMethodRefs;
static void		FreeMethodNameRep(Tcl_Obj *objPtr);
static inline int	IsStillValid(CallChain *callPtr, Object *oPtr,
			    int flags, int reuseMask);
static Tcl_NRPostProc	ResetFilterFlags;
static Tcl_NRPostProc	SetFilterFlags;
static size_t		SortMethodNames(Tcl_HashTable *namesPtr, int flags,
			    const char ***stringsPtr);
static inline void	StashCallChain(Tcl_Obj *objPtr, CallChain *callPtr);

/*
 * Object type used to manage type caches attached to method names.
 */

static const Tcl_ObjType methodNameType = {
    "TclOO method name",
    FreeMethodNameRep,
    DupMethodNameRep,
    NULL,
    NULL,
    TCL_OBJTYPE_V0
};

/*
 * ----------------------------------------------------------------------
 *
 * TclOODeleteContext --
 *
 *	Destroys a method call-chain context, which should not be in use.
 *
 * ----------------------------------------------------------------------
 */

void
TclOODeleteContext(
    CallContext *contextPtr)
{
    Object *oPtr = contextPtr->oPtr;

    TclOODeleteChain(contextPtr->callPtr);
    if (oPtr != NULL) {
	TclStackFree(oPtr->fPtr->interp, contextPtr);

	/*
	 * Corresponding AddRef() in TclOO.c/TclOOObjectCmdCore
	 */

	TclOODecrRefCount(oPtr);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOODeleteChainCache --
 *
 *	Destroy the cache of method call-chains.
 *
 * ----------------------------------------------------------------------
 */

void
TclOODeleteChainCache(
    Tcl_HashTable *tablePtr)
{
    FOREACH_HASH_DECLS;
    CallChain *callPtr;

    FOREACH_HASH_VALUE(callPtr, tablePtr) {
	if (callPtr) {
	    TclOODeleteChain(callPtr);
	}
    }
    Tcl_DeleteHashTable(tablePtr);
    Tcl_Free(tablePtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOODeleteChain --
 *
 *	Destroys a method call-chain.
 *
 * ----------------------------------------------------------------------
 */

void
TclOODeleteChain(
    CallChain *callPtr)
{
    if (callPtr == NULL || callPtr->refCount-- > 1) {
	return;
    }
    if (callPtr->chain != callPtr->staticChain) {
	Tcl_Free(callPtr->chain);
    }
    Tcl_Free(callPtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOStashContext --
 *
 *	Saves a reference to a method call context in a Tcl_Obj's internal
 *	representation.
 *
 * ----------------------------------------------------------------------
 */

static inline void
StashCallChain(
    Tcl_Obj *objPtr,
    CallChain *callPtr)
{
    Tcl_ObjInternalRep ir;

    callPtr->refCount++;
    TclGetString(objPtr);
    ir.twoPtrValue.ptr1 = callPtr;
    Tcl_StoreInternalRep(objPtr, &methodNameType, &ir);
}

void
TclOOStashContext(
    Tcl_Obj *objPtr,
    CallContext *contextPtr)
{
    StashCallChain(objPtr, contextPtr->callPtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * DupMethodNameRep, FreeMethodNameRep --
 *
 *	Functions to implement the required parts of the Tcl_Obj guts needed
 *	for caching of method contexts in Tcl_Objs.
 *
 * ----------------------------------------------------------------------
 */

static void
DupMethodNameRep(
    Tcl_Obj *srcPtr,
    Tcl_Obj *dstPtr)
{
    StashCallChain(dstPtr, (CallChain *)
	    TclFetchInternalRep(srcPtr, &methodNameType)->twoPtrValue.ptr1);
}

static void
FreeMethodNameRep(
    Tcl_Obj *objPtr)
{
    TclOODeleteChain((CallChain *)
	    TclFetchInternalRep(objPtr, &methodNameType)->twoPtrValue.ptr1);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInvokeContext --
 *
 *	Invokes a single step along a method call-chain context. Note that the
 *	invocation of a step along the chain can cause further steps along the
 *	chain to be invoked. Note that this function is written to be as light
 *	in stack usage as possible.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOInvokeContext(
    void *clientData,		/* The method call context. */
    Tcl_Interp *interp,		/* Interpreter for error reporting, and many
				 * other sorts of context handling (e.g.,
				 * commands, variables) depending on method
				 * implementation. */
    int objc,			/* The number of arguments. */
    Tcl_Obj *const objv[])	/* The arguments as actually seen. */
{
    CallContext *const contextPtr = (CallContext *) clientData;
    Method *const mPtr = contextPtr->callPtr->chain[contextPtr->index].mPtr;
    const int isFilter =
	    contextPtr->callPtr->chain[contextPtr->index].isFilter;

    /*
     * If this is the first step along the chain, we preserve the method
     * entries in the chain so that they do not get deleted out from under our
     * feet.
     */

    if (contextPtr->index == 0) {
	Tcl_Size i;

	for (i = 0 ; i < contextPtr->callPtr->numChain ; i++) {
	    AddRef(contextPtr->callPtr->chain[i].mPtr);
	}

	/*
	 * Ensure that the method name itself is part of the arguments when
	 * we're doing unknown processing.
	 */

	if (contextPtr->callPtr->flags & OO_UNKNOWN_METHOD) {
	    contextPtr->skip--;
	}

	/*
	 * Add a callback to ensure that method references are dropped once
	 * this call is finished.
	 */

	TclNRAddCallback(interp, FinalizeMethodRefs, contextPtr, NULL, NULL,
		NULL);
    }

    /*
     * Save whether we were in a filter and set up whether we are now.
     */

    if (contextPtr->oPtr->flags & FILTER_HANDLING) {
	TclNRAddCallback(interp, SetFilterFlags, contextPtr, NULL,NULL,NULL);
    } else {
	TclNRAddCallback(interp, ResetFilterFlags,contextPtr,NULL,NULL,NULL);
    }
    if (isFilter || contextPtr->callPtr->flags & FILTER_HANDLING) {
	contextPtr->oPtr->flags |= FILTER_HANDLING;
    } else {
	contextPtr->oPtr->flags &= ~FILTER_HANDLING;
    }

    /*
     * Run the method implementation.
     */

    if (mPtr->typePtr->version < TCL_OO_METHOD_VERSION_2) {
	return (mPtr->typePtr->callProc)(mPtr->clientData, interp,
		(Tcl_ObjectContext) contextPtr, objc, objv);
    }
    return (mPtr->type2Ptr->callProc)(mPtr->clientData, interp,
	    (Tcl_ObjectContext) contextPtr, objc, objv);
}

static int
SetFilterFlags(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    CallContext *contextPtr = (CallContext *) data[0];

    contextPtr->oPtr->flags |= FILTER_HANDLING;
    return result;
}

static int
ResetFilterFlags(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    CallContext *contextPtr = (CallContext *) data[0];

    contextPtr->oPtr->flags &= ~FILTER_HANDLING;
    return result;
}

static int
FinalizeMethodRefs(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    CallContext *contextPtr = (CallContext *) data[0];
    Tcl_Size i;

    for (i = 0 ; i < contextPtr->callPtr->numChain ; i++) {
	TclOODelMethodRef(contextPtr->callPtr->chain[i].mPtr);
    }
    return result;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetSortedMethodList, TclOOGetSortedClassMethodList --
 *
 *	Discovers the list of method names supported by an object or class.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOGetSortedMethodList(
    Object *oPtr,		/* The object to get the method names for. */
    Object *contextObj,		/* From what context object we are inquiring.
				 * NULL when the context shouldn't see
				 * object-level private methods. Note that
				 * flags can override this. */
    Class *contextCls,		/* From what context class we are inquiring.
				 * NULL when the context shouldn't see
				 * class-level private methods. Note that
				 * flags can override this. */
    int flags,			/* Whether we just want the public method
				 * names. */
    const char ***stringsPtr)	/* Where to write a pointer to the array of
				 * strings to. */
{
    Tcl_HashTable names;	/* Tcl_Obj* method name to "wanted in list"
				 * mapping. */
    Tcl_HashTable examinedClasses;
				/* Used to track what classes have been looked
				 * at. Is set-like in nature and keyed by
				 * pointer to class. */
    FOREACH_HASH_DECLS;
    Tcl_Size i, numStrings;
    Class *mixinPtr;
    Tcl_Obj *namePtr;
    Method *mPtr;

    Tcl_InitObjHashTable(&names);
    Tcl_InitHashTable(&examinedClasses, TCL_ONE_WORD_KEYS);

    /*
     * Process method names due to the object.
     */

    if (oPtr->methodsPtr) {
	FOREACH_HASH(namePtr, mPtr, oPtr->methodsPtr) {
	    if (IS_PRIVATE(mPtr)) {
		continue;
	    }
	    if (IS_UNEXPORTED(mPtr) && !WANT_UNEXPORTED(flags)) {
		continue;
	    }
	    AddStandardMethodName(flags, namePtr, mPtr, &names);
	}
    }

    /*
     * Process method names due to private methods on the object's class.
     */

    if (WANT_UNEXPORTED(flags)) {
	FOREACH_HASH(namePtr, mPtr, &oPtr->selfCls->classMethods) {
	    if (IS_UNEXPORTED(mPtr)) {
		AddStandardMethodName(flags, namePtr, mPtr, &names);
	    }
	}
    }

    /*
     * Process method names due to private methods on the context's object or
     * class. Which must be correct if either are not NULL.
     */

    if (contextObj && contextObj->methodsPtr) {
	AddPrivateMethodNames(contextObj->methodsPtr, &names);
    }
    if (contextCls) {
	AddPrivateMethodNames(&contextCls->classMethods, &names);
    }

    /*
     * Process (normal) method names from the class hierarchy and the mixin
     * hierarchy.
     */

    AddClassMethodNames(oPtr->selfCls, flags, &names, &examinedClasses);
    FOREACH(mixinPtr, oPtr->mixins) {
	AddClassMethodNames(mixinPtr, flags | TRAVERSED_MIXIN, &names,
		&examinedClasses);
    }

    /*
     * Tidy up, sort the names and resolve finally whether we really want
     * them (processing export layering).
     */

    Tcl_DeleteHashTable(&examinedClasses);
    numStrings = SortMethodNames(&names, flags, stringsPtr);
    Tcl_DeleteHashTable(&names);
    return numStrings;
}

size_t
TclOOGetSortedClassMethodList(
    Class *clsPtr,		/* The class to get the method names for. */
    int flags,			/* Whether we just want the public method
				 * names. */
    const char ***stringsPtr)	/* Where to write a pointer to the array of
				 * strings to. */
{
    Tcl_HashTable names;	/* Tcl_Obj* method name to "wanted in list"
				 * mapping. */
    Tcl_HashTable examinedClasses;
				/* Used to track what classes have been looked
				 * at. Is set-like in nature and keyed by
				 * pointer to class. */
    size_t numStrings;

    Tcl_InitObjHashTable(&names);
    Tcl_InitHashTable(&examinedClasses, TCL_ONE_WORD_KEYS);

    /*
     * Process method names from the class hierarchy and the mixin hierarchy.
     */

    AddClassMethodNames(clsPtr, flags, &names, &examinedClasses);
    Tcl_DeleteHashTable(&examinedClasses);

    /*
     * Process private method names if we should. [TIP 500]
     */

    if (WANT_PRIVATE(flags)) {
	AddPrivateMethodNames(&clsPtr->classMethods, &names);
	flags &= ~TRUE_PRIVATE_METHOD;
    }

    /*
     * Tidy up, sort the names and resolve finally whether we really want
     * them (processing export layering).
     */

    numStrings = SortMethodNames(&names, flags, stringsPtr);
    Tcl_DeleteHashTable(&names);
    return numStrings;
}

/*
 * ----------------------------------------------------------------------
 *
 * SortMethodNames --
 *
 *	Shared helper for TclOOGetSortedMethodList etc. that knows the method
 *	sorting rules.
 *
 * Returns:
 *	The length of the sorted list.
 *
 * ----------------------------------------------------------------------
 */

static size_t
SortMethodNames(
    Tcl_HashTable *namesPtr,	/* The table of names; unsorted, but contains
				 * whether the names are wanted and under what
				 * circumstances. */
    int flags,			/* Whether we are looking for unexported
				 * methods. Full private methods are handled
				 * on insertion to the table. */
    const char ***stringsPtr)	/* Where to store the sorted list of strings
				 * that we produce. Tcl_Alloced() */
{
    const char **strings;
    FOREACH_HASH_DECLS;
    Tcl_Obj *namePtr;
    void *isWanted;
    size_t i = 0;

    /*
     * See how many (visible) method names there are. If none, we do not (and
     * should not) try to sort the list of them.
     */

    if (namesPtr->numEntries == 0) {
	*stringsPtr = NULL;
	return 0;
    }

    /*
     * We need to build the list of methods to sort. We will be using qsort()
     * for this, because it is very unlikely that the list will be heavily
     * sorted when it is long enough to matter.
     */

    strings = (const char **) Tcl_Alloc(sizeof(char *) * namesPtr->numEntries);
    FOREACH_HASH(namePtr, isWanted, namesPtr) {
	if (!WANT_PUBLIC(flags) || (PTR2INT(isWanted) & IN_LIST)) {
	    if (PTR2INT(isWanted) & NO_IMPLEMENTATION) {
		continue;
	    }
	    strings[i++] = TclGetString(namePtr);
	}
    }

    /*
     * Note that 'i' may well be less than names.numEntries when we are
     * dealing with public method names. We don't sort unless there's at least
     * two method names.
     */

    if (i > 0) {
	if (i > 1) {
	    qsort((void *) strings, i, sizeof(char *), CmpStr);
	}
	*stringsPtr = strings;
    } else {
	Tcl_Free((void *)strings);
	*stringsPtr = NULL;
    }
    return i;
}

/*
 * Comparator for SortMethodNames
 */

static int
CmpStr(
    const void *ptr1,
    const void *ptr2)
{
    const char **strPtr1 = (const char **) ptr1;
    const char **strPtr2 = (const char **) ptr2;

    return TclpUtfNcmp2(*strPtr1, *strPtr2, strlen(*strPtr1) + 1);
}

/*
 * ----------------------------------------------------------------------
 *
 * AddClassMethodNames --
 *
 *	Adds the method names defined by a class (or its superclasses) to the
 *	collection being built. The collection is built in a hash table to
 *	ensure that duplicates are excluded. Helper for GetSortedMethodList().
 *
 * ----------------------------------------------------------------------
 */

static void
AddClassMethodNames(
    Class *clsPtr,		/* Class to get method names from. */
    int flags,			/* Whether we are interested in just the
				 * public method names. */
    Tcl_HashTable *const namesPtr,
				/* Reference to the hash table to put the
				 * information in. The hash table maps the
				 * Tcl_Obj * method name to an integral value
				 * describing whether the method is wanted.
				 * This ensures that public/private override
				 * semantics are handled correctly. */
    Tcl_HashTable *const examinedClassesPtr)
				/* Hash table that tracks what classes have
				 * already been looked at. The keys are the
				 * pointers to the classes, and the values are
				 * immaterial. */
{
    Tcl_Size i;

    /*
     * If we've already started looking at this class, stop working on it now
     * to prevent repeated work.
     */

    if (Tcl_FindHashEntry(examinedClassesPtr, clsPtr)) {
	return;
    }

    /*
     * Scope all declarations so that the compiler can stand a good chance of
     * making the recursive step highly efficient. We also hand-implement the
     * tail-recursive case using a while loop; C compilers typically cannot do
     * tail-recursion optimization usefully.
     */

    while (1) {
	FOREACH_HASH_DECLS;
	Tcl_Obj *namePtr;
	Method *mPtr;
	int isNew;

	(void) Tcl_CreateHashEntry(examinedClassesPtr, clsPtr,
		&isNew);
	if (!isNew) {
	    break;
	}

	if (clsPtr->mixins.num != 0) {
	    Class *mixinPtr;

	    FOREACH(mixinPtr, clsPtr->mixins) {
		if (mixinPtr != clsPtr) {
		    AddClassMethodNames(mixinPtr, flags|TRAVERSED_MIXIN,
			    namesPtr, examinedClassesPtr);
		}
	    }
	}

	FOREACH_HASH(namePtr, mPtr, &clsPtr->classMethods) {
	    AddStandardMethodName(flags, namePtr, mPtr, namesPtr);
	}

	if (clsPtr->superclasses.num != 1) {
	    break;
	}
	clsPtr = clsPtr->superclasses.list[0];
    }
    if (clsPtr->superclasses.num != 0) {
	Class *superPtr;

	FOREACH(superPtr, clsPtr->superclasses) {
	    AddClassMethodNames(superPtr, flags, namesPtr,
		    examinedClassesPtr);
	}
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * AddPrivateMethodNames, AddStandardMethodName --
 *
 *	Factored-out helpers for the sorted name list production functions.
 *
 * ----------------------------------------------------------------------
 */

static inline void
AddPrivateMethodNames(
    Tcl_HashTable *methodsTablePtr,
    Tcl_HashTable *namesPtr)
{
    FOREACH_HASH_DECLS;
    Method *mPtr;
    Tcl_Obj *namePtr;

    FOREACH_HASH(namePtr, mPtr, methodsTablePtr) {
	if (IS_PRIVATE(mPtr)) {
	    int isNew;

	    hPtr = Tcl_CreateHashEntry(namesPtr, namePtr, &isNew);
	    Tcl_SetHashValue(hPtr, INT2PTR(IN_LIST));
	}
    }
}

static inline void
AddStandardMethodName(
    int flags,
    Tcl_Obj *namePtr,
    Method *mPtr,
    Tcl_HashTable *namesPtr)
{
    if (!IS_PRIVATE(mPtr)) {
	int isNew;
	Tcl_HashEntry *hPtr =
		Tcl_CreateHashEntry(namesPtr, namePtr, &isNew);

	if (isNew) {
	    int isWanted = (!WANT_PUBLIC(flags) || IS_PUBLIC(mPtr))
		    ? IN_LIST : 0;

	    isWanted |= (mPtr->typePtr == NULL ? NO_IMPLEMENTATION : 0);
	    Tcl_SetHashValue(hPtr, INT2PTR(isWanted));
	} else if ((PTR2INT(Tcl_GetHashValue(hPtr)) & NO_IMPLEMENTATION)
		&& mPtr->typePtr != NULL) {
	    int isWanted = PTR2INT(Tcl_GetHashValue(hPtr));

	    isWanted &= ~NO_IMPLEMENTATION;
	    Tcl_SetHashValue(hPtr, INT2PTR(isWanted));
	}
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * AddInstancePrivateToCallContext --
 *
 *	Add private methods from the instance. Called when the calling Tcl
 *	context is a TclOO method declared by an object that is the same as
 *	the current object. Returns true iff a private method was actually
 *	found and added to the call chain (as this suppresses caching).
 *
 * ----------------------------------------------------------------------
 */

static inline int
AddInstancePrivateToCallContext(
    Object *const oPtr,		/* Object to add call chain entries for. */
    Tcl_Obj *const methodName,	/* Name of method to add the call chain
				 * entries for. */
    ChainBuilder *const cbPtr,	/* Where to add the call chain entries. */
    int flags)			/* What sort of call chain are we building. */
{
    Tcl_HashEntry *hPtr;
    Method *mPtr;
    int donePrivate = 0;

    if (oPtr->methodsPtr) {
	hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, methodName);
	if (hPtr != NULL) {
	    mPtr = (Method *) Tcl_GetHashValue(hPtr);
	    if (IS_PRIVATE(mPtr)) {
		AddMethodToCallChain(mPtr, cbPtr, NULL, NULL, flags);
		donePrivate = 1;
	    }
	}
    }
    return donePrivate;
}

/*
 * ----------------------------------------------------------------------
 *
 * AddSimpleChainToCallContext --
 *
 *	The core of the call-chain construction engine, this handles calling a
 *	particular method on a particular object. Note that filters and
 *	unknown handling are already handled by the logic that uses this
 *	function. Returns true if a private method was one of those found.
 *
 * ----------------------------------------------------------------------
 */

static inline int
AddSimpleChainToCallContext(
    Object *const oPtr,		/* Object to add call chain entries for. */
    Class *const contextCls,	/* Context class; the currently considered
				 * class is equal to this, private methods may
				 * also be added. [TIP 500] */
    Tcl_Obj *const methodNameObj,
				/* Name of method to add the call chain
				 * entries for. */
    ChainBuilder *const cbPtr,	/* Where to add the call chain entries. */
    Tcl_HashTable *const doneFilters,
				/* Where to record what call chain entries
				 * have been processed. */
    int flags,			/* What sort of call chain are we building. */
    Class *const filterDecl)	/* The class that declared the filter. If
				 * NULL, either the filter was declared by the
				 * object or this isn't a filter. */
{
    Tcl_Size i;
    int foundPrivate = 0, blockedUnexported = 0;
    Tcl_HashEntry *hPtr;
    Method *mPtr;

    if (!(flags & (KNOWN_STATE | SPECIAL)) && oPtr->methodsPtr) {
	hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, methodNameObj);

	if (hPtr != NULL) {
	    mPtr = (Method *) Tcl_GetHashValue(hPtr);
	    if (!IS_PRIVATE(mPtr)) {
		if (WANT_PUBLIC(flags)) {
		    if (!IS_PUBLIC(mPtr)) {
			blockedUnexported = 1;
		    } else {
			flags |= DEFINITE_PUBLIC;
		    }
		} else {
		    flags |= DEFINITE_PROTECTED;
		}
	    }
	}
    }
    if (!(flags & SPECIAL)) {
	Class *mixinPtr;

	FOREACH(mixinPtr, oPtr->mixins) {
	    if (contextCls) {
		foundPrivate |= AddPrivatesFromClassChainToCallContext(
			mixinPtr, contextCls, methodNameObj, cbPtr,
			doneFilters, flags|TRAVERSED_MIXIN, filterDecl);
	    }
	    foundPrivate |= AddSimpleClassChainToCallContext(mixinPtr,
		    methodNameObj, cbPtr, doneFilters,
		    flags | TRAVERSED_MIXIN, filterDecl);
	}
	if (oPtr->methodsPtr && !blockedUnexported) {
	    hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, methodNameObj);
	    if (hPtr != NULL) {
		mPtr = (Method *) Tcl_GetHashValue(hPtr);
		if (!IS_PRIVATE(mPtr)) {
		    AddMethodToCallChain(mPtr, cbPtr, doneFilters, filterDecl,
			    flags);
		}
	    }
	}
    }
    if (!oPtr->selfCls) {
	return foundPrivate;
    }
    if (contextCls) {
	foundPrivate |= AddPrivatesFromClassChainToCallContext(oPtr->selfCls,
		contextCls, methodNameObj, cbPtr, doneFilters, flags,
		filterDecl);
    }
    if (!blockedUnexported) {
	foundPrivate |= AddSimpleClassChainToCallContext(oPtr->selfCls,
		methodNameObj, cbPtr, doneFilters, flags, filterDecl);
    }
    return foundPrivate;
}

/*
 * ----------------------------------------------------------------------
 *
 * AddMethodToCallChain --
 *
 *	Utility method that manages the adding of a particular method
 *	implementation to a call-chain.
 *
 * ----------------------------------------------------------------------
 */

static inline void
AddMethodToCallChain(
    Method *const mPtr,		/* Actual method implementation to add to call
				 * chain (or NULL, a no-op). */
    ChainBuilder *const cbPtr,	/* The call chain to add the method
				 * implementation to. */
    Tcl_HashTable *const doneFilters,
				/* Where to record what filters have been
				 * processed. If NULL, not processing filters.
				 * Note that this function does not update
				 * this hashtable. */
    Class *const filterDecl,	/* The class that declared the filter. If
				 * NULL, either the filter was declared by the
				 * object or this isn't a filter. */
    int flags)			/* Used to check if we're mixin-consistent
				 * only. Mixin-consistent means that either
				 * we're looking to add things from a mixin
				 * and we have passed a mixin, or we're not
				 * looking to add things from a mixin and have
				 * not passed a mixin. */
{
    CallChain *callPtr = cbPtr->callChainPtr;
    Tcl_Size i;

    /*
     * Return if this is just an entry used to record whether this is a public
     * method. If so, there's nothing real to call and so nothing to add to
     * the call chain.
     *
     * This is also where we enforce mixin-consistency.
     */

    if (mPtr == NULL || mPtr->typePtr == NULL || !MIXIN_CONSISTENT(flags)) {
	return;
    }

    /*
     * Enforce real private method handling here. We will skip adding this
     * method IF
     *  1) we are not allowing private methods, AND
     *  2) this is a private method, AND
     *  3) this is a class method, AND
     *  4) this method was not declared by the class of the current object.
     *
     * This does mean that only classes really handle private methods. This
     * should be sufficient for [incr Tcl] support though.
     */

    if (!WANT_UNEXPORTED(callPtr->flags)
	    && IS_UNEXPORTED(mPtr)
	    && (mPtr->declaringClassPtr != NULL)
	    && (mPtr->declaringClassPtr != cbPtr->oPtr->selfCls)) {
	return;
    }

    /*
     * First test whether the method is already in the call chain. Skip over
     * any leading filters.
     */

    for (i = cbPtr->filterLength ; i < callPtr->numChain ; i++) {
	if (callPtr->chain[i].mPtr == mPtr &&
		callPtr->chain[i].isFilter == (doneFilters != NULL)) {
	    /*
	     * Call chain semantics states that methods come as *late* in the
	     * call chain as possible. This is done by copying down the
	     * following methods. Note that this does not change the number of
	     * method invocations in the call chain; it just rearranges them.
	     */

	    Class *declCls = callPtr->chain[i].filterDeclarer;

	    for (; i + 1 < callPtr->numChain ; i++) {
		callPtr->chain[i] = callPtr->chain[i + 1];
	    }
	    callPtr->chain[i].mPtr = mPtr;
	    callPtr->chain[i].isFilter = (doneFilters != NULL);
	    callPtr->chain[i].filterDeclarer = declCls;
	    return;
	}
    }

    /*
     * Need to really add the method. This is made a bit more complex by the
     * fact that we are using some "static" space initially, and only start
     * realloc-ing if the chain gets long.
     */

    if (callPtr->numChain == CALL_CHAIN_STATIC_SIZE) {
	callPtr->chain = (MInvoke *)
		Tcl_Alloc(sizeof(MInvoke) * (callPtr->numChain + 1));
	memcpy(callPtr->chain, callPtr->staticChain,
		sizeof(MInvoke) * callPtr->numChain);
    } else if (callPtr->numChain > CALL_CHAIN_STATIC_SIZE) {
	callPtr->chain = (MInvoke *) Tcl_Realloc(callPtr->chain,
		sizeof(MInvoke) * (callPtr->numChain + 1));
    }
    callPtr->chain[i].mPtr = mPtr;
    callPtr->chain[i].isFilter = (doneFilters != NULL);
    callPtr->chain[i].filterDeclarer = filterDecl;
    callPtr->numChain++;
}

/*
 * ----------------------------------------------------------------------
 *
 * InitCallChain --
 *	Encoding of the policy of how to set up a call chain. Doesn't populate
 *	the chain with the method implementation data.
 *
 * ----------------------------------------------------------------------
 */

static inline void
InitCallChain(
    CallChain *callPtr,
    Object *oPtr,
    int flags)
{
    /*
     * Note that it's possible to end up with a NULL oPtr->selfCls here if
     * there is a call into stereotypical object after it has finished running
     * its destructor phase. Such things can't be cached for a long time so the
     * epoch can be bogus. [Bug 7842f33a5c]
     */

    callPtr->flags = flags &
	    (PUBLIC_METHOD | PRIVATE_METHOD | SPECIAL | FILTER_HANDLING);
    if (oPtr->flags & USE_CLASS_CACHE) {
	oPtr = (oPtr->selfCls ? oPtr->selfCls->thisPtr : NULL);
	callPtr->flags |= USE_CLASS_CACHE;
    }
    if (oPtr) {
	callPtr->epoch = oPtr->fPtr->epoch;
	callPtr->objectCreationEpoch = oPtr->creationEpoch;
	callPtr->objectEpoch = oPtr->epoch;
    } else {
	callPtr->epoch = 0;
	callPtr->objectCreationEpoch = 0;
	callPtr->objectEpoch = 0;
    }
    callPtr->refCount = 1;
    callPtr->numChain = 0;
    callPtr->chain = callPtr->staticChain;
}

/*
 * ----------------------------------------------------------------------
 *
 * IsStillValid --
 *
 *	Calculates whether the given call chain can be used for executing a
 *	method for the given object. The condition on a chain from a cached
 *	location being reusable is:
 *	- Refers to the same object (same creation epoch), and
 *	- Still across the same class structure (same global epoch), and
 *	- Still across the same object structure (same local epoch), and
 *	- No public/private/filter magic leakage (same flags, modulo the fact
 *	  that a public chain will satisfy a non-public call).
 *
 * ----------------------------------------------------------------------
 */

static inline int
IsStillValid(
    CallChain *callPtr,
    Object *oPtr,
    int flags,
    int mask)
{
    if ((oPtr->flags & USE_CLASS_CACHE)) {
	/*
	 * If the object is in a weird state (due to stereotype tricks) then
	 * just declare the cache invalid. [Bug 7842f33a5c]
	 */
	if (!oPtr->selfCls) {
	    return 0;
	}
	oPtr = oPtr->selfCls->thisPtr;
	flags |= USE_CLASS_CACHE;
    }
    return ((callPtr->objectCreationEpoch == oPtr->creationEpoch)
	    && (callPtr->epoch == oPtr->fPtr->epoch)
	    && (callPtr->objectEpoch == oPtr->epoch)
	    && ((callPtr->flags & mask) == (flags & mask)));
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetCallContext --
 *
 *	Responsible for constructing the call context, an ordered list of all
 *	method implementations to be called as part of a method invocation.
 *	This method is central to the whole operation of the OO system.
 *
 * ----------------------------------------------------------------------
 */

CallContext *
TclOOGetCallContext(
    Object *oPtr,		/* The object to get the context for. */
    Tcl_Obj *methodNameObj,	/* The name of the method to get the context
				 * for. NULL when getting a constructor or
				 * destructor chain. */
    int flags,			/* What sort of context are we looking for.
				 * Only the bits PUBLIC_METHOD, CONSTRUCTOR,
				 * PRIVATE_METHOD, DESTRUCTOR and
				 * FILTER_HANDLING are useful. */
    Object *contextObj,		/* Context object; when equal to oPtr, it
				 * means that private methods may also be
				 * added. [TIP 500] */
    Class *contextCls,		/* Context class; the currently considered
				 * class is equal to this, private methods may
				 * also be added. [TIP 500] */
    Tcl_Obj *cacheInThisObj)	/* What object to cache in, or NULL if it is
				 * to be in the same object as the
				 * methodNameObj. */
{
    CallContext *contextPtr;
    CallChain *callPtr;
    ChainBuilder cb;
    Tcl_Size i, count;
    int doFilters, donePrivate = 0;
    Tcl_HashEntry *hPtr;
    Tcl_HashTable doneFilters;

    if (cacheInThisObj == NULL) {
	cacheInThisObj = methodNameObj;
    }
    if (flags&(SPECIAL|FILTER_HANDLING) || (oPtr->flags&FILTER_HANDLING)) {
	hPtr = NULL;
	doFilters = 0;

	/*
	 * Check if we have a cached valid constructor or destructor.
	 */

	if (flags & CONSTRUCTOR) {
	    callPtr = oPtr->selfCls->constructorChainPtr;
	    if ((callPtr != NULL)
		    && (callPtr->objectEpoch == oPtr->selfCls->thisPtr->epoch)
		    && (callPtr->epoch == oPtr->fPtr->epoch)) {
		callPtr->refCount++;
		goto returnContext;
	    }
	} else if (flags & DESTRUCTOR) {
	    callPtr = oPtr->selfCls->destructorChainPtr;
	    if ((oPtr->mixins.num == 0) && (callPtr != NULL)
		    && (callPtr->objectEpoch == oPtr->selfCls->thisPtr->epoch)
		    && (callPtr->epoch == oPtr->fPtr->epoch)) {
		callPtr->refCount++;
		goto returnContext;
	    }
	}
    } else {
	/*
	 * Check if we can get the chain out of the Tcl_Obj method name or out
	 * of the cache. This is made a bit more complex by the fact that
	 * there are multiple different layers of cache (in the Tcl_Obj, in
	 * the object, and in the class).
	 */

	const Tcl_ObjInternalRep *irPtr;
	const int reuseMask = (WANT_PUBLIC(flags) ? ~0 : ~PUBLIC_METHOD);

	if ((irPtr = TclFetchInternalRep(cacheInThisObj, &methodNameType))) {
	    callPtr = (CallChain *) irPtr->twoPtrValue.ptr1;
	    if (IsStillValid(callPtr, oPtr, flags, reuseMask)) {
		callPtr->refCount++;
		goto returnContext;
	    }
	    Tcl_StoreInternalRep(cacheInThisObj, &methodNameType, NULL);
	}

	/*
	 * Note that it's possible to end up with a NULL oPtr->selfCls here if
	 * there is a call into stereotypical object after it has finished
	 * running its destructor phase. It's quite a tangle, but at that
	 * point, we simply can't get stereotypes from the cache.
	 * [Bug 7842f33a5c]
	 */

	if (oPtr->flags & USE_CLASS_CACHE && oPtr->selfCls) {
	    if (oPtr->selfCls->classChainCache) {
		hPtr = Tcl_FindHashEntry(oPtr->selfCls->classChainCache,
			methodNameObj);
	    } else {
		hPtr = NULL;
	    }
	} else {
	    if (oPtr->chainCache != NULL) {
		hPtr = Tcl_FindHashEntry(oPtr->chainCache,
			methodNameObj);
	    } else {
		hPtr = NULL;
	    }
	}

	if (hPtr != NULL && Tcl_GetHashValue(hPtr) != NULL) {
	    callPtr = (CallChain *) Tcl_GetHashValue(hPtr);
	    if (IsStillValid(callPtr, oPtr, flags, reuseMask)) {
		callPtr->refCount++;
		goto returnContext;
	    }
	    Tcl_SetHashValue(hPtr, NULL);
	    TclOODeleteChain(callPtr);
	}

	doFilters = 1;
    }

    callPtr = (CallChain *) Tcl_Alloc(sizeof(CallChain));
    InitCallChain(callPtr, oPtr, flags);

    cb.callChainPtr = callPtr;
    cb.filterLength = 0;
    cb.oPtr = oPtr;

    /*
     * If we're working with a forced use of unknown, do that now.
     */

    if (flags & FORCE_UNKNOWN) {
	AddSimpleChainToCallContext(oPtr, NULL,
		oPtr->fPtr->unknownMethodNameObj, &cb, NULL, BUILDING_MIXINS,
		NULL);
	AddSimpleChainToCallContext(oPtr, NULL,
		oPtr->fPtr->unknownMethodNameObj, &cb, NULL, 0, NULL);
	callPtr->flags |= OO_UNKNOWN_METHOD;
	callPtr->epoch = 0;
	if (callPtr->numChain == 0) {
	    TclOODeleteChain(callPtr);
	    return NULL;
	}
	goto returnContext;
    }

    /*
     * Add all defined filters (if any, and if we're going to be processing
     * them; they're not processed for constructors, destructors or when we're
     * in the middle of processing a filter).
     */

    if (doFilters) {
	Tcl_Obj *filterObj;
	Class *mixinPtr;

	doFilters = 1;
	Tcl_InitObjHashTable(&doneFilters);
	FOREACH(mixinPtr, oPtr->mixins) {
	    AddClassFiltersToCallContext(oPtr, mixinPtr, &cb, &doneFilters,
		    TRAVERSED_MIXIN|BUILDING_MIXINS|OBJECT_MIXIN);
	    AddClassFiltersToCallContext(oPtr, mixinPtr, &cb, &doneFilters,
		    OBJECT_MIXIN);
	}
	FOREACH(filterObj, oPtr->filters) {
	    donePrivate |= AddSimpleChainToCallContext(oPtr, contextCls,
		    filterObj, &cb, &doneFilters, BUILDING_MIXINS, NULL);
	    donePrivate |= AddSimpleChainToCallContext(oPtr, contextCls,
		    filterObj, &cb, &doneFilters, 0, NULL);
	}
	AddClassFiltersToCallContext(oPtr, oPtr->selfCls, &cb, &doneFilters,
		BUILDING_MIXINS);
	AddClassFiltersToCallContext(oPtr, oPtr->selfCls, &cb, &doneFilters,
		0);
	Tcl_DeleteHashTable(&doneFilters);
    }
    count = cb.filterLength = callPtr->numChain;

    /*
     * Add the actual method implementations. We have to do this twice to
     * handle class mixins right.
     */

    if (oPtr == contextObj) {
	donePrivate |= AddInstancePrivateToCallContext(oPtr, methodNameObj,
		&cb, flags);
	donePrivate |= (contextObj->flags & HAS_PRIVATE_METHODS);
    }
    donePrivate |= AddSimpleChainToCallContext(oPtr, contextCls,
	    methodNameObj, &cb, NULL, flags|BUILDING_MIXINS, NULL);
    donePrivate |= AddSimpleChainToCallContext(oPtr, contextCls,
	    methodNameObj, &cb, NULL, flags, NULL);

    /*
     * Check to see if the method has no implementation. If so, we probably
     * need to add in a call to the unknown method. Otherwise, set up the
     * cacheing of the method implementation (if relevant).
     */

    if (count == callPtr->numChain) {
	/*
	 * Method does not actually exist. If we're dealing with constructors
	 * or destructors, this isn't a problem.
	 */

	if (flags & SPECIAL) {
	    TclOODeleteChain(callPtr);
	    return NULL;
	}
	AddSimpleChainToCallContext(oPtr, NULL,
		oPtr->fPtr->unknownMethodNameObj, &cb, NULL, BUILDING_MIXINS,
		NULL);
	AddSimpleChainToCallContext(oPtr, NULL,
		oPtr->fPtr->unknownMethodNameObj, &cb, NULL, 0, NULL);
	callPtr->flags |= OO_UNKNOWN_METHOD;
	callPtr->epoch = 0;
	if (count == callPtr->numChain) {
	    TclOODeleteChain(callPtr);
	    return NULL;
	}
    } else if (doFilters && !donePrivate) {
	if (hPtr == NULL) {
	    int isNew;
	    if (oPtr->flags & USE_CLASS_CACHE) {
		if (oPtr->selfCls->classChainCache == NULL) {
		    oPtr->selfCls->classChainCache = (Tcl_HashTable *)
			    Tcl_Alloc(sizeof(Tcl_HashTable));

		    Tcl_InitObjHashTable(oPtr->selfCls->classChainCache);
		}
		hPtr = Tcl_CreateHashEntry(oPtr->selfCls->classChainCache,
			methodNameObj, &isNew);
	    } else {
		if (oPtr->chainCache == NULL) {
		    oPtr->chainCache = (Tcl_HashTable *)
			    Tcl_Alloc(sizeof(Tcl_HashTable));

		    Tcl_InitObjHashTable(oPtr->chainCache);
		}
		hPtr = Tcl_CreateHashEntry(oPtr->chainCache,
			methodNameObj, &isNew);
	    }
	}
	callPtr->refCount++;
	Tcl_SetHashValue(hPtr, callPtr);
	StashCallChain(cacheInThisObj, callPtr);
    } else if (flags & CONSTRUCTOR) {
	if (oPtr->selfCls->constructorChainPtr) {
	    TclOODeleteChain(oPtr->selfCls->constructorChainPtr);
	}
	oPtr->selfCls->constructorChainPtr = callPtr;
	callPtr->refCount++;
    } else if ((flags & DESTRUCTOR) && oPtr->mixins.num == 0) {
	if (oPtr->selfCls->destructorChainPtr) {
	    TclOODeleteChain(oPtr->selfCls->destructorChainPtr);
	}
	oPtr->selfCls->destructorChainPtr = callPtr;
	callPtr->refCount++;
    }

  returnContext:
    contextPtr = (CallContext *)
	    TclStackAlloc(oPtr->fPtr->interp, sizeof(CallContext));
    contextPtr->oPtr = oPtr;

    /*
     * Corresponding TclOODecrRefCount() in TclOODeleteContext
     */

    AddRef(oPtr);
    contextPtr->callPtr = callPtr;
    contextPtr->skip = 2;
    contextPtr->index = 0;
    return contextPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetStereotypeCallChain --
 *
 *	Construct a call-chain for a method that would be used by a
 *	stereotypical instance of the given class (i.e., where the object has
 *	no definitions special to itself).
 *
 * ----------------------------------------------------------------------
 */

CallChain *
TclOOGetStereotypeCallChain(
    Class *clsPtr,		/* The object to get the context for. */
    Tcl_Obj *methodNameObj,	/* The name of the method to get the context
				 * for. NULL when getting a constructor or
				 * destructor chain. */
    int flags)			/* What sort of context are we looking for.
				 * Only the bits PUBLIC_METHOD, CONSTRUCTOR,
				 * PRIVATE_METHOD, DESTRUCTOR and
				 * FILTER_HANDLING are useful. */
{
    CallChain *callPtr;
    ChainBuilder cb;
    Tcl_Size count;
    Foundation *fPtr = clsPtr->thisPtr->fPtr;
    Tcl_HashEntry *hPtr;
    Tcl_HashTable doneFilters;
    Object obj;

    /*
     * Note that it's possible to end up with a NULL clsPtr here if there is
     * a call into stereotypical object after it has finished running its
     * destructor phase. It's quite a tangle, but at that point, we simply
     * can't get stereotypes. [Bug 7842f33a5c]
     */

    if (clsPtr == NULL) {
	return NULL;
    }

    /*
     * Synthesize a temporary stereotypical object so that we can use existing
     * machinery to produce the stereotypical call chain.
     */

    memset(&obj, 0, sizeof(Object));
    obj.fPtr = fPtr;
    obj.selfCls = clsPtr;
    obj.refCount = 1;
    obj.flags = USE_CLASS_CACHE;

    /*
     * Check if we can get the chain out of the Tcl_Obj method name or out of
     * the cache. This is made a bit more complex by the fact that there are
     * multiple different layers of cache (in the Tcl_Obj, in the object, and
     * in the class).
     */

    if (clsPtr->classChainCache != NULL) {
	hPtr = Tcl_FindHashEntry(clsPtr->classChainCache,
		methodNameObj);
	if (hPtr != NULL && Tcl_GetHashValue(hPtr) != NULL) {
	    const int reuseMask = (WANT_PUBLIC(flags) ? ~0 : ~PUBLIC_METHOD);

	    callPtr = (CallChain *) Tcl_GetHashValue(hPtr);
	    if (IsStillValid(callPtr, &obj, flags, reuseMask)) {
		callPtr->refCount++;
		return callPtr;
	    }
	    Tcl_SetHashValue(hPtr, NULL);
	    TclOODeleteChain(callPtr);
	}
    } else {
	hPtr = NULL;
    }

    callPtr = (CallChain *) Tcl_Alloc(sizeof(CallChain));
    memset(callPtr, 0, sizeof(CallChain));
    callPtr->flags = flags & (PUBLIC_METHOD|PRIVATE_METHOD|FILTER_HANDLING);
    callPtr->epoch = fPtr->epoch;
    callPtr->objectCreationEpoch = fPtr->tsdPtr->nsCount;
    callPtr->objectEpoch = clsPtr->thisPtr->epoch;
    callPtr->refCount = 1;
    callPtr->chain = callPtr->staticChain;

    cb.callChainPtr = callPtr;
    cb.filterLength = 0;
    cb.oPtr = &obj;

    /*
     * Add all defined filters (if any, and if we're going to be processing
     * them; they're not processed for constructors, destructors or when we're
     * in the middle of processing a filter).
     */

    Tcl_InitObjHashTable(&doneFilters);
    AddClassFiltersToCallContext(&obj, clsPtr, &cb, &doneFilters,
	    BUILDING_MIXINS);
    AddClassFiltersToCallContext(&obj, clsPtr, &cb, &doneFilters, 0);
    Tcl_DeleteHashTable(&doneFilters);
    count = cb.filterLength = callPtr->numChain;

    /*
     * Add the actual method implementations.
     */

    AddSimpleChainToCallContext(&obj, NULL, methodNameObj, &cb, NULL,
	    flags|BUILDING_MIXINS, NULL);
    AddSimpleChainToCallContext(&obj, NULL, methodNameObj, &cb, NULL, flags,
	    NULL);

    /*
     * Check to see if the method has no implementation. If so, we probably
     * need to add in a call to the unknown method. Otherwise, set up the
     * caching of the method implementation (if relevant).
     */

    if (count == callPtr->numChain) {
	AddSimpleChainToCallContext(&obj, NULL, fPtr->unknownMethodNameObj,
		&cb, NULL, BUILDING_MIXINS, NULL);
	AddSimpleChainToCallContext(&obj, NULL, fPtr->unknownMethodNameObj,
		&cb, NULL, 0, NULL);
	callPtr->flags |= OO_UNKNOWN_METHOD;
	callPtr->epoch = 0;
	if (count == callPtr->numChain) {
	    TclOODeleteChain(callPtr);
	    return NULL;
	}
    } else {
	if (hPtr == NULL) {
	    int isNew;
	    if (clsPtr->classChainCache == NULL) {
		clsPtr->classChainCache = (Tcl_HashTable *)
			Tcl_Alloc(sizeof(Tcl_HashTable));
		Tcl_InitObjHashTable(clsPtr->classChainCache);
	    }
	    hPtr = Tcl_CreateHashEntry(clsPtr->classChainCache,
		    methodNameObj, &isNew);
	}
	callPtr->refCount++;
	Tcl_SetHashValue(hPtr, callPtr);
	StashCallChain(methodNameObj, callPtr);
    }
    return callPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * AddClassFiltersToCallContext --
 *
 *	Logic to make extracting all the filters from the class context much
 *	easier.
 *
 * ----------------------------------------------------------------------
 */

static void
AddClassFiltersToCallContext(
    Object *const oPtr,		/* Object that the filters operate on. */
    Class *clsPtr,		/* Class to get the filters from. */
    ChainBuilder *const cbPtr,	/* Context to fill with call chain entries. */
    Tcl_HashTable *const doneFilters,
				/* Where to record what filters have been
				 * processed. Keys are objects, values are
				 * ignored. */
    int flags)			/* Whether we've gone along a mixin link
				 * yet. */
{
    Tcl_Size i;
    int clearedFlags =
	    flags & ~(TRAVERSED_MIXIN|OBJECT_MIXIN|BUILDING_MIXINS);
    Class *superPtr, *mixinPtr;
    Tcl_Obj *filterObj;

  tailRecurse:
    if (clsPtr == NULL) {
	return;
    }

    /*
     * Add all the filters defined by classes mixed into the main class
     * hierarchy.
     */

    FOREACH(mixinPtr, clsPtr->mixins) {
	AddClassFiltersToCallContext(oPtr, mixinPtr, cbPtr, doneFilters,
		flags|TRAVERSED_MIXIN);
    }

    /*
     * Add all the class filters from the current class. Note that the filters
     * are added starting at the object root, as this allows the object to
     * override how filters work to extend their behaviour.
     */

    if (MIXIN_CONSISTENT(flags)) {
	FOREACH(filterObj, clsPtr->filters) {
	    int isNew;

	    (void) Tcl_CreateHashEntry(doneFilters, filterObj, &isNew);
	    if (isNew) {
		AddSimpleChainToCallContext(oPtr, NULL, filterObj, cbPtr,
			doneFilters, clearedFlags|BUILDING_MIXINS, clsPtr);
		AddSimpleChainToCallContext(oPtr, NULL, filterObj, cbPtr,
			doneFilters, clearedFlags, clsPtr);
	    }
	}
    }

    /*
     * Now process the recursive case. Notice the tail-call optimization.
     */

    switch (clsPtr->superclasses.num) {
    case 1:
	clsPtr = clsPtr->superclasses.list[0];
	goto tailRecurse;
    default:
	FOREACH(superPtr, clsPtr->superclasses) {
	    AddClassFiltersToCallContext(oPtr, superPtr, cbPtr, doneFilters,
		    flags);
	}
	TCL_FALLTHROUGH();
    case 0:
	return;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * AddPrivatesFromClassChainToCallContext --
 *
 *	Helper for AddSimpleChainToCallContext that is used to find private
 *	methds and add them to the call chain. Returns true when a private
 *	method is found and added. [TIP 500]
 *
 * ----------------------------------------------------------------------
 */

static int
AddPrivatesFromClassChainToCallContext(
    Class *classPtr,		/* Class to add the call chain entries for. */
    Class *const contextCls,	/* Context class; the currently considered
				 * class is equal to this, private methods may
				 * also be added. */
    Tcl_Obj *const methodName,	/* Name of method to add the call chain
				 * entries for. */
    ChainBuilder *const cbPtr,	/* Where to add the call chain entries. */
    Tcl_HashTable *const doneFilters,
				/* Where to record what call chain entries
				 * have been processed. */
    int flags,			/* What sort of call chain are we building. */
    Class *const filterDecl)	/* The class that declared the filter. If
				 * NULL, either the filter was declared by the
				 * object or this isn't a filter. */
{
    Tcl_Size i;
    Class *superPtr;

    /*
     * We hard-code the tail-recursive form. It's by far the most common case
     * *and* it is much more gentle on the stack.
     *
     * Note that mixins must be processed before the main class hierarchy.
     * [Bug 1998221]
     *
     * Note also that it's possible to end up with a null classPtr here if
     * there is a call into stereotypical object after it has finished running
     * its destructor phase. [Bug 7842f33a5c]
     */

  tailRecurse:
    if (classPtr == NULL) {
	return 0;
    }
    FOREACH(superPtr, classPtr->mixins) {
	if (AddPrivatesFromClassChainToCallContext(superPtr, contextCls,
		methodName, cbPtr, doneFilters, flags|TRAVERSED_MIXIN,
		filterDecl)) {
	    return 1;
	}
    }

    if (classPtr == contextCls) {
	Tcl_HashEntry *hPtr = Tcl_FindHashEntry(&classPtr->classMethods,
		methodName);

	if (hPtr != NULL) {
	    Method *mPtr = (Method *) Tcl_GetHashValue(hPtr);

	    if (IS_PRIVATE(mPtr)) {
		AddMethodToCallChain(mPtr, cbPtr, doneFilters, filterDecl,
			flags);
		return 1;
	    }
	}
    }

    switch (classPtr->superclasses.num) {
    case 1:
	classPtr = classPtr->superclasses.list[0];
	goto tailRecurse;
    default:
	FOREACH(superPtr, classPtr->superclasses) {
	    if (AddPrivatesFromClassChainToCallContext(superPtr, contextCls,
		    methodName, cbPtr, doneFilters, flags, filterDecl)) {
		return 1;
	    }
	}
	TCL_FALLTHROUGH();
    case 0:
	return 0;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * AddSimpleClassChainToCallContext --
 *
 *	Construct a call-chain from a class hierarchy.
 *
 * ----------------------------------------------------------------------
 */

static int
AddSimpleClassChainToCallContext(
    Class *classPtr,		/* Class to add the call chain entries for. */
    Tcl_Obj *const methodNameObj,
				/* Name of method to add the call chain
				 * entries for. */
    ChainBuilder *const cbPtr,	/* Where to add the call chain entries. */
    Tcl_HashTable *const doneFilters,
				/* Where to record what call chain entries
				 * have been processed. */
    int flags,			/* What sort of call chain are we building. */
    Class *const filterDecl)	/* The class that declared the filter. If
				 * NULL, either the filter was declared by the
				 * object or this isn't a filter. */
{
    Tcl_Size i;
    int privateDanger = 0;
    Class *superPtr;

    /*
     * We hard-code the tail-recursive form. It's by far the most common case
     * *and* it is much more gentle on the stack.
     *
     * Note that mixins must be processed before the main class hierarchy.
     * [Bug 1998221]
     */

  tailRecurse:
    if (classPtr == NULL) {
	return privateDanger;
    }
    FOREACH(superPtr, classPtr->mixins) {
	privateDanger |= AddSimpleClassChainToCallContext(superPtr,
		methodNameObj, cbPtr, doneFilters, flags | TRAVERSED_MIXIN,
		filterDecl);
    }

    if (flags & CONSTRUCTOR) {
	AddMethodToCallChain(classPtr->constructorPtr, cbPtr, doneFilters,
		filterDecl, flags);
    } else if (flags & DESTRUCTOR) {
	AddMethodToCallChain(classPtr->destructorPtr, cbPtr, doneFilters,
		filterDecl, flags);
    } else {
	Tcl_HashEntry *hPtr = Tcl_FindHashEntry(&classPtr->classMethods,
		methodNameObj);

	if (classPtr->flags & HAS_PRIVATE_METHODS) {
	    privateDanger |= 1;
	}
	if (hPtr != NULL) {
	    Method *mPtr = (Method *) Tcl_GetHashValue(hPtr);

	    if (!IS_PRIVATE(mPtr)) {
		if (!(flags & KNOWN_STATE)) {
		    if (flags & PUBLIC_METHOD) {
			if (!IS_PUBLIC(mPtr)) {
			    return privateDanger;
			}
			flags |= DEFINITE_PUBLIC;
		    } else {
			flags |= DEFINITE_PROTECTED;
		    }
		}
		AddMethodToCallChain(mPtr, cbPtr, doneFilters, filterDecl,
			flags);
	    }
	}
    }

    switch (classPtr->superclasses.num) {
    case 1:
	classPtr = classPtr->superclasses.list[0];
	goto tailRecurse;
    default:
	FOREACH(superPtr, classPtr->superclasses) {
	    privateDanger |= AddSimpleClassChainToCallContext(superPtr,
		    methodNameObj, cbPtr, doneFilters, flags, filterDecl);
	}
	TCL_FALLTHROUGH();
    case 0:
	return privateDanger;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOORenderCallChain --
 *
 *	Create a description of a call chain. Used in [info object call],
 *	[info class call], and [self call].
 *
 * ----------------------------------------------------------------------
 */

Tcl_Obj *
TclOORenderCallChain(
    Tcl_Interp *interp,
    CallChain *callPtr)
{
    Tcl_Obj *filterLiteral, *methodLiteral, *objectLiteral, *privateLiteral;
    Tcl_Obj *resultObj, *descObjs[4], **objv;
    Foundation *fPtr = TclOOGetFoundation(interp);
    Tcl_Size i;

    /*
     * Allocate the literals (potentially) used in our description.
     */

    TclNewLiteralStringObj(filterLiteral, "filter");
    TclNewLiteralStringObj(methodLiteral, "method");
    TclNewLiteralStringObj(objectLiteral, "object");
    TclNewLiteralStringObj(privateLiteral, "private");

    /*
     * Do the actual construction of the descriptions. They consist of a list
     * of triples that describe the details of how a method is understood. For
     * each triple, the first word is the type of invocation ("method" is
     * normal, "unknown" is special because it adds the method name as an
     * extra argument when handled by some method types, and "filter" is
     * special because it's a filter method). The second word is the name of
     * the method in question (which differs for "unknown" and "filter" types)
     * and the third word is the full name of the class that declares the
     * method (or "object" if it is declared on the instance).
     */

    objv = (Tcl_Obj **)
	    TclStackAlloc(interp, callPtr->numChain * sizeof(Tcl_Obj *));
    for (i = 0 ; i < callPtr->numChain ; i++) {
	MInvoke *miPtr = &callPtr->chain[i];

	descObjs[0] =
	    miPtr->isFilter ? filterLiteral :
	    callPtr->flags & OO_UNKNOWN_METHOD ? fPtr->unknownMethodNameObj :
	    IS_PRIVATE(miPtr->mPtr) ? privateLiteral :
		    methodLiteral;
	descObjs[1] =
	    callPtr->flags & CONSTRUCTOR ? fPtr->constructorName :
	    callPtr->flags & DESTRUCTOR ? fPtr->destructorName :
		    miPtr->mPtr->namePtr;
	descObjs[2] = miPtr->mPtr->declaringClassPtr
		? Tcl_GetObjectName(interp,
			(Tcl_Object) miPtr->mPtr->declaringClassPtr->thisPtr)
		: objectLiteral;
	descObjs[3] = Tcl_NewStringObj(miPtr->mPtr->typePtr->name,
		TCL_AUTO_LENGTH);

	objv[i] = Tcl_NewListObj(4, descObjs);
    }

    /*
     * Drop the local references to the literals; if they're actually used,
     * they'll live on the description itself.
     */

    Tcl_BounceRefCount(filterLiteral);
    Tcl_BounceRefCount(methodLiteral);
    Tcl_BounceRefCount(objectLiteral);
    Tcl_BounceRefCount(privateLiteral);

    /*
     * Finish building the description and return it.
     */

    resultObj = Tcl_NewListObj(callPtr->numChain, objv);
    TclStackFree(interp, objv);
    return resultObj;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetDefineContextNamespace --
 *
 *	Responsible for determining which namespace to use for definitions.
 *	This is done by building a define chain, which models (strongly!) the
 *	way that a call chain works but with a different internal model.
 *
 *	Then it walks the chain to find the first namespace name that actually
 *	resolves to an existing namespace.
 *
 * Returns:
 *	Name of namespace, or NULL if none can be found. Note that this
 *	function does *not* set an error message in the interpreter on failure.
 *
 * ----------------------------------------------------------------------
 */

#define DEFINE_CHAIN_STATIC_SIZE 4 /* Enough space to store most cases. */

Tcl_Namespace *
TclOOGetDefineContextNamespace(
    Tcl_Interp *interp,		/* In what interpreter should namespace names
				 * actually be resolved. */
    Object *oPtr,		/* The object to get the context for. */
    int forClass)		/* What sort of context are we looking for.
				 * If true, we are going to use this for
				 * [oo::define], otherwise, we are going to
				 * use this for [oo::objdefine]. */
{
    DefineChain define;
    DefineEntry staticSpace[DEFINE_CHAIN_STATIC_SIZE];
    DefineEntry *entryPtr;
    Tcl_Namespace *nsPtr = NULL;
    int i, flags = (forClass ? DEFINE_FOR_CLASS : 0);

    define.list = staticSpace;
    define.num = 0;
    define.size = DEFINE_CHAIN_STATIC_SIZE;

    /*
     * Add the actual define locations. We have to do this twice to handle
     * class mixins right.
     */

    AddSimpleDefineNamespaces(oPtr, &define, flags | BUILDING_MIXINS);
    AddSimpleDefineNamespaces(oPtr, &define, flags);

    /*
     * Go through the list until we find a namespace whose name we can
     * resolve.
     */

    FOREACH_STRUCT(entryPtr, define) {
	if (TclGetNamespaceFromObj(interp, entryPtr->namespaceName,
		&nsPtr) == TCL_OK) {
	    break;
	}
	Tcl_ResetResult(interp);
    }
    if (define.list != staticSpace) {
	Tcl_Free(define.list);
    }
    return nsPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * AddSimpleDefineNamespaces --
 *
 *	Adds to the definition chain all the definitions provided by an
 *	object's class and its mixins, taking into account everything they
 *	inherit from.
 *
 * ----------------------------------------------------------------------
 */

static inline void
AddSimpleDefineNamespaces(
    Object *const oPtr,		/* Object to add define chain entries for. */
    DefineChain *const definePtr,
				/* Where to add the define chain entries. */
    int flags)			/* What sort of define chain are we
				 * building. */
{
    Class *mixinPtr;
    Tcl_Size i;

    FOREACH(mixinPtr, oPtr->mixins) {
	AddSimpleClassDefineNamespaces(mixinPtr, definePtr,
		flags | TRAVERSED_MIXIN);
    }

    AddSimpleClassDefineNamespaces(oPtr->selfCls, definePtr, flags);
}

/*
 * ----------------------------------------------------------------------
 *
 * AddSimpleClassDefineNamespaces --
 *
 *	Adds to the definition chain all the definitions provided by a class
 *	and its superclasses and its class mixins.
 *
 * ----------------------------------------------------------------------
 */

static void
AddSimpleClassDefineNamespaces(
    Class *classPtr,		/* Class to add the define chain entries for. */
    DefineChain *const definePtr,
				/* Where to add the define chain entries. */
    int flags)			/* What sort of define chain are we
				 * building. */
{
    Tcl_Size i;
    Class *superPtr;

    /*
     * We hard-code the tail-recursive form. It's by far the most common case
     * *and* it is much more gentle on the stack.
     */

  tailRecurse:
    FOREACH(superPtr, classPtr->mixins) {
	AddSimpleClassDefineNamespaces(superPtr, definePtr,
		flags | TRAVERSED_MIXIN);
    }

    if (flags & DEFINE_FOR_CLASS) {
	AddDefinitionNamespaceToChain(classPtr, classPtr->clsDefinitionNs,
		definePtr, flags);
    } else {
	AddDefinitionNamespaceToChain(classPtr, classPtr->objDefinitionNs,
		definePtr, flags);
    }

    switch (classPtr->superclasses.num) {
    case 1:
	classPtr = classPtr->superclasses.list[0];
	goto tailRecurse;
    default:
	FOREACH(superPtr, classPtr->superclasses) {
	    AddSimpleClassDefineNamespaces(superPtr, definePtr, flags);
	}
	TCL_FALLTHROUGH();
    case 0:
	return;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * AddDefinitionNamespaceToChain --
 *
 *	Adds a single item to the definition chain (if it is meaningful),
 *	reallocating the space for the chain if necessary.
 *
 * ----------------------------------------------------------------------
 */

static inline void
AddDefinitionNamespaceToChain(
    Class *const definerCls,	/* What class defines this entry. */
    Tcl_Obj *const namespaceName,
				/* The name for this entry (or NULL, a
				 * no-op). */
    DefineChain *const definePtr,
				/* The define chain to add the method
				 * implementation to. */
    int flags)			/* Used to check if we're mixin-consistent
				 * only. Mixin-consistent means that either
				 * we're looking to add things from a mixin
				 * and we have passed a mixin, or we're not
				 * looking to add things from a mixin and have
				 * not passed a mixin. */
{
    int i;

    /*
     * Return if this entry is blank. This is also where we enforce
     * mixin-consistency.
     */

    if (namespaceName == NULL || !MIXIN_CONSISTENT(flags)) {
	return;
    }

    /*
     * First test whether the method is already in the call chain.
     */

    for (i=0 ; i<definePtr->num ; i++) {
	if (definePtr->list[i].definerCls == definerCls) {
	    /*
	     * Call chain semantics states that methods come as *late* in the
	     * call chain as possible. This is done by copying down the
	     * following methods. Note that this does not change the number of
	     * method invocations in the call chain; it just rearranges them.
	     *
	     * We skip changing anything if the place we found was already at
	     * the end of the list.
	     */

	    if (i < definePtr->num - 1) {
		memmove(&definePtr->list[i], &definePtr->list[i + 1],
			sizeof(DefineEntry) * (definePtr->num - i - 1));
		definePtr->list[i].definerCls = definerCls;
		definePtr->list[i].namespaceName = namespaceName;
	    }
	    return;
	}
    }

    /*
     * Need to really add the define. This is made a bit more complex by the
     * fact that we are using some "static" space initially, and only start
     * realloc-ing if the chain gets long.
     */

    if (definePtr->num == definePtr->size) {
	definePtr->size *= 2;
	if (definePtr->num == DEFINE_CHAIN_STATIC_SIZE) {
	    DefineEntry *staticList = definePtr->list;

	    definePtr->list = (DefineEntry *)
		    Tcl_Alloc(sizeof(DefineEntry) * definePtr->size);
	    memcpy(definePtr->list, staticList,
		    sizeof(DefineEntry) * definePtr->num);
	} else {
	    definePtr->list = (DefineEntry *) Tcl_Realloc(definePtr->list,
		    sizeof(DefineEntry) * definePtr->size);
	}
    }
    definePtr->list[i].definerCls = definerCls;
    definePtr->list[i].namespaceName = namespaceName;
    definePtr->num++;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

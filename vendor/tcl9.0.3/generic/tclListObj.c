/*
 * tclListObj.c --
 *
 *	This file contains functions that implement the Tcl list object type.
 *
 * Copyright © 2022 Ashok P. Nadkarni.  All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclTomMath.h"

/*
 * TODO - memmove is fast. Measure at what size we should prefer memmove
 * (for unshared objects only) in lieu of range operations. On the other
 * hand, more cache dirtied?
 */

/*
 * Macros for validation and bug checking.
 */

/*
 * Control whether asserts are enabled. Always enable in debug builds. In non-debug
 * builds, can be set with cdebug="-DENABLE_LIST_ASSERTS" on the nmake command line.
 */
#ifdef ENABLE_LIST_ASSERTS
# ifdef NDEBUG
#  undef NDEBUG /* Activate assert() macro */
# endif
#else
# ifndef NDEBUG
#  define ENABLE_LIST_ASSERTS /* Always activate list asserts in debug mode */
# endif
#endif

#ifdef ENABLE_LIST_ASSERTS

#define LIST_ASSERT(cond_) \
    assert(cond_)
/*
 * LIST_INDEX_ASSERT is to catch errors with negative indices and counts
 * being passed AFTER validation. On Tcl9 length types are unsigned hence
 * the checks against LIST_MAX. On Tcl8 length types are signed hence the
 * also checks against 0.
 */
#define LIST_INDEX_ASSERT(idxarg_) \
    do {								\
	Tcl_Size idx_ = (idxarg_); /* To guard against ++ etc. */	\
	LIST_ASSERT(idx_ >= 0 && idx_ < LIST_MAX);			\
    } while (0)
/* Ditto for counts except upper limit is different */
#define LIST_COUNT_ASSERT(countarg_) \
    do {								\
	Tcl_Size count_ = (countarg_); /* To guard against ++ etc. */	\
	LIST_ASSERT(count_ >= 0 && count_ <= LIST_MAX);			\
    } while (0)

#else // !ENABLE_LIST_ASSERTS
#define LIST_ASSERT(cond_)		((void) 0)
#define LIST_INDEX_ASSERT(idx_)		((void) 0)
#define LIST_COUNT_ASSERT(count_)	((void) 0)
#endif // ENABLE_LIST_ASSERTS

/* Checks for when caller should have already converted to internal list type */
#define LIST_ASSERT_TYPE(listObj_) \
    LIST_ASSERT(TclHasInternalRep((listObj_), &tclListType))

/*
 * If ENABLE_LIST_INVARIANTS is enabled (-DENABLE_LIST_INVARIANTS from the
 * command line), the entire list internal representation is checked for
 * inconsistencies. This has a non-trivial cost so has to be separately
 * enabled and not part of assertions checking. However, the test suite does
 * invoke ListRepValidate directly even without ENABLE_LIST_INVARIANTS.
 */
#ifdef ENABLE_LIST_INVARIANTS
#define LISTREP_CHECK(listRepPtr_) ListRepValidate(listRepPtr_, __FILE__, __LINE__)
#else
#define LISTREP_CHECK(listRepPtr_) (void) 0
#endif

/*
 * Flags used for controlling behavior of allocation of list
 * internal representations.
 *
 * If the LISTREP_PANIC_ON_FAIL bit is set, the function will panic if
 * list is too large or memory cannot be allocated. Without the flag
 * a NULL pointer is returned.
 *
 * The LISTREP_SPACE_FAVOR_NONE, LISTREP_SPACE_FAVOR_FRONT,
 * LISTREP_SPACE_FAVOR_BACK, LISTREP_SPACE_ONLY_BACK flags are used to
 * control additional space when allocating.
 * - If none of these flags is present, the exact space requested is
 *   allocated, nothing more.
 * - Otherwise, if only LISTREP_FAVOR_FRONT is present, extra space is
 *   allocated with more towards the front.
 * - Conversely, if only LISTREP_FAVOR_BACK is present extra space is allocated
 *   with more to the back.
 * - If both flags are present (LISTREP_SPACE_FAVOR_NONE), the extra space
 *   is equally apportioned.
 * - Finally if LISTREP_SPACE_ONLY_BACK is present, ALL extra space is at
 *   the back.
 */
enum ListRepresentationFlags {
    LISTREP_PANIC_ON_FAIL = 1,
    LISTREP_SPACE_FAVOR_FRONT = 2,
    LISTREP_SPACE_FAVOR_BACK = 4,
    LISTREP_SPACE_ONLY_BACK = 8
};
#define LISTREP_SPACE_FAVOR_NONE \
    (LISTREP_SPACE_FAVOR_FRONT | LISTREP_SPACE_FAVOR_BACK)
#define LISTREP_SPACE_FLAGS \
    (LISTREP_SPACE_FAVOR_FRONT | LISTREP_SPACE_FAVOR_BACK \
     | LISTREP_SPACE_ONLY_BACK)

/*
 * Prototypes for non-inline static functions defined later in this file:
 */
static int	MemoryAllocationError(Tcl_Interp *, size_t size);
static ListStore *ListStoreNew(Tcl_Size objc, Tcl_Obj *const objv[], int flags);
static int	ListRepInit(Tcl_Size objc, Tcl_Obj *const objv[], int flags, ListRep *);
static int	ListRepInitAttempt(Tcl_Interp *,
		    Tcl_Size objc,
		    Tcl_Obj *const objv[],
		    ListRep *);
static void	ListRepClone(ListRep *fromRepPtr, ListRep *toRepPtr, int flags);
static void	ListRepUnsharedFreeUnreferenced(const ListRep *repPtr);
static int	TclListObjGetRep(Tcl_Interp *, Tcl_Obj *listPtr, ListRep *repPtr);
static void	ListRepRange(ListRep *srcRepPtr,
		    Tcl_Size rangeStart,
		    Tcl_Size rangeEnd,
		    int preserveSrcRep,
		    ListRep *rangeRepPtr);
static ListStore *ListStoreReallocate(ListStore *storePtr, Tcl_Size numSlots);
static void	ListRepValidate(const ListRep *repPtr, const char *file,
		    int lineNum);
static void	DupListInternalRep(Tcl_Obj *srcPtr, Tcl_Obj *copyPtr);
static void	FreeListInternalRep(Tcl_Obj *listPtr);
static int	SetListFromAny(Tcl_Interp *interp, Tcl_Obj *objPtr);
static void	UpdateStringOfList(Tcl_Obj *listPtr);
static Tcl_Size ListLength(Tcl_Obj *listPtr);

/*
 * The structure below defines the list Tcl object type by means of functions
 * that can be invoked by generic object code.
 *
 * The internal representation of a list object is ListRep defined in tcl.h.
 */

const Tcl_ObjType tclListType = {
    "list",			/* name */
    FreeListInternalRep,	/* freeIntRepProc */
    DupListInternalRep,		/* dupIntRepProc */
    UpdateStringOfList,		/* updateStringProc */
    SetListFromAny,		/* setFromAnyProc */
    TCL_OBJTYPE_V1(ListLength)
};

/* Macros to manipulate the List internal rep */
#define ListRepIncrRefs(repPtr_) \
    do {					\
	(repPtr_)->storePtr->refCount++;	\
	if ((repPtr_)->spanPtr) {		\
	    (repPtr_)->spanPtr->refCount++;	\
	}					\
    } while (0)

/* Returns number of free unused slots at the back of the ListRep's ListStore */
#define ListRepNumFreeTail(repPtr_) \
    ((repPtr_)->storePtr->numAllocated \
     - ((repPtr_)->storePtr->firstUsed + (repPtr_)->storePtr->numUsed))

/* Returns number of free unused slots at the front of the ListRep's ListStore */
#define ListRepNumFreeHead(repPtr_) ((repPtr_)->storePtr->firstUsed)

/* Returns a pointer to the slot corresponding to list index listIdx_ */
#define ListRepSlotPtr(repPtr_, listIdx_) \
    (&(repPtr_)->storePtr->slots[ListRepStart(repPtr_) + (listIdx_)])

/*
 * Macros to replace the internal representation in a Tcl_Obj. There are
 * subtle differences in each so make sure to use the right one to avoid
 * memory leaks, access to freed memory and the like.
 *
 * ListObjStompRep - assumes the Tcl_Obj internal representation can be
 * overwritten AND that the passed ListRep already has reference counts that
 * include the reference from the Tcl_Obj. Basically just copies the pointers
 * and sets the internal Tcl_Obj type to list
 *
 * ListObjOverwriteRep - like ListObjOverwriteRep but additionally
 * increments reference counts on the passed ListRep. Generally used when
 * the string representation of the Tcl_Obj is not to be modified.
 *
 * ListObjReplaceRepAndInvalidate - Like ListObjOverwriteRep but additionally
 * assumes the Tcl_Obj internal rep is valid (and possibly even same as
 * passed ListRep) and frees it first. Additionally invalidates the string
 * representation. Generally used when modifying a Tcl_Obj value.
 */
#define ListObjStompRep(objPtr_, repPtr_) \
    do {								\
	(objPtr_)->internalRep.twoPtrValue.ptr1 = (repPtr_)->storePtr;	\
	(objPtr_)->internalRep.twoPtrValue.ptr2 = (repPtr_)->spanPtr;	\
	(objPtr_)->typePtr = &tclListType;				\
    } while (0)

#define ListObjOverwriteRep(objPtr_, repPtr_) \
    do {								\
	ListRepIncrRefs(repPtr_);					\
	ListObjStompRep(objPtr_, repPtr_);				\
    } while (0)

#define ListObjReplaceRepAndInvalidate(objPtr_, repPtr_) \
    do {								\
	/* Note order important, don't use ListObjOverwriteRep! */	\
	ListRepIncrRefs(repPtr_);					\
	TclFreeInternalRep(objPtr_);					\
	TclInvalidateStringRep(objPtr_);				\
	ListObjStompRep(objPtr_, repPtr_);				\
    } while (0)

/*
 *------------------------------------------------------------------------
 *
 * ListSpanNew --
 *
 *    Allocates and initializes memory for a new ListSpan. The reference
 *    count on the returned struct is 0.
 *
 * Results:
 *    Non-NULL pointer to the allocated ListSpan.
 *
 * Side effects:
 *    The function will panic on memory allocation failure.
 *
 *------------------------------------------------------------------------
 */
static inline ListSpan *
ListSpanNew(
    Tcl_Size firstSlot,		/* Starting slot index of the span */
    Tcl_Size numSlots)		/* Number of slots covered by the span */
{
    ListSpan *spanPtr = (ListSpan *) Tcl_Alloc(sizeof(*spanPtr));
    spanPtr->refCount = 0;
    spanPtr->spanStart = firstSlot;
    spanPtr->spanLength = numSlots;
    return spanPtr;
}

/*
 *------------------------------------------------------------------------
 *
 * ListSpanDecrRefs --
 *
 *   Decrements the reference count on a span, freeing the memory if
 *   it drops to zero or less.
 *
 * Results:
 *   None.
 *
 * Side effects:
 *   The memory may be freed.
 *
 *------------------------------------------------------------------------
 */
static inline void
ListSpanDecrRefs(
    ListSpan *spanPtr)
{
    if (spanPtr->refCount <= 1) {
	Tcl_Free(spanPtr);
    } else {
	spanPtr->refCount -= 1;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * ListSpanMerited --
 *
 *    Creation of a new list may sometimes be done as a span on existing
 *    storage instead of allocating new. The tradeoff is that if the
 *    original list is released, the new span-based list may hold on to
 *    more memory than desired. This function implements heuristics for
 *    deciding which option is better.
 *
 * Results:
 *    Returns non-0 if a span-based list is likely to be more optimal
 *    and 0 if not.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
static inline int
ListSpanMerited(
    Tcl_Size length,		/* Length of the proposed span */
    Tcl_Size usedStorageLength,	/* Number of slots currently in used */
    Tcl_Size allocatedStorageLength) /* Length of the currently allocation */
{
    /*
     * Possible optimizations for future consideration
     * - heuristic LIST_SPAN_THRESHOLD
     * - currently, information about the sharing (ref count) of existing
     * storage is not passed. Perhaps it should be. For example if the
     * existing storage has a "large" ref count, then it might make sense
     * to do even a small span.
     */

    if (length < LIST_SPAN_THRESHOLD) {
	return 0;/* No span for small lists */
    }
    if (length < (allocatedStorageLength / 2 - allocatedStorageLength / 8)) {
	return 0; /* No span if less than 3/8 of allocation */
    }
    if (length < usedStorageLength / 2) {
	return 0; /* No span if less than half current storage */
    }

    return 1;
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepFreeUnreferenced --
 *
 *    Inline wrapper for ListRepUnsharedFreeUnreferenced that does quick checks
 *    before calling it.
 *
 *    IMPORTANT: this function must not be called on an internal
 *    representation of a Tcl_Obj that is itself shared.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    See comments for ListRepUnsharedFreeUnreferenced.
 *
 *------------------------------------------------------------------------
 */
static inline void
ListRepFreeUnreferenced(
    const ListRep *repPtr)
{
    if (! ListRepIsShared(repPtr) && repPtr->spanPtr) {
	/* T:listrep-1.5.1 */
	ListRepUnsharedFreeUnreferenced(repPtr);
    }
}

/*
 *------------------------------------------------------------------------
 *
 * ObjArrayIncrRefs --
 *
 *    Increments the reference counts for Tcl_Obj's in a subarray.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    As above.
 *
 *------------------------------------------------------------------------
 */
static inline void
ObjArrayIncrRefs(
    Tcl_Obj * const *objv,	/* Pointer to the array */
    Tcl_Size startIdx,		/* Starting index of subarray within objv */
    Tcl_Size count)		/* Number of elements in the subarray */
{
    Tcl_Obj *const *end;
    LIST_INDEX_ASSERT(startIdx);
    LIST_COUNT_ASSERT(count);
    objv += startIdx;
    end = objv + count;
    while (objv < end) {
	Tcl_IncrRefCount(*objv);
	++objv;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * ObjArrayDecrRefs --
 *
 *    Decrements the reference counts for Tcl_Obj's in a subarray.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    As above.
 *
 *------------------------------------------------------------------------
 */
static inline void
ObjArrayDecrRefs(
    Tcl_Obj * const *objv,	/* Pointer to the array */
    Tcl_Size startIdx,		/* Starting index of subarray within objv */
    Tcl_Size count)		/* Number of elements in the subarray */
{
    Tcl_Obj * const *end;
    LIST_INDEX_ASSERT(startIdx);
    LIST_COUNT_ASSERT(count);
    objv += startIdx;
    end = objv + count;
    while (objv < end) {
	Tcl_DecrRefCount(*objv);
	++objv;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * ObjArrayCopy --
 *
 *    Copies an array of Tcl_Obj* pointers.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    Reference counts on copied Tcl_Obj's are incremented.
 *
 *------------------------------------------------------------------------
 */
static inline void
ObjArrayCopy(
    Tcl_Obj **to,		/* Destination */
    Tcl_Size count,		/* Number of pointers to copy */
    Tcl_Obj *const from[])	/* Source array of Tcl_Obj* */
{
    Tcl_Obj **end;
    LIST_COUNT_ASSERT(count);
    end = to + count;
    /* TODO - would memmove followed by separate IncrRef loop be faster? */
    while (to < end) {
	Tcl_IncrRefCount(*from);
	*to++ = *from++;
    }
}

/*
 *------------------------------------------------------------------------
 *
 * MemoryAllocationError --
 *
 *    Generates a memory allocation failure error.
 *
 * Results:
 *    Always TCL_ERROR.
 *
 * Side effects:
 *    Error message and code are stored in the interpreter if not NULL.
 *
 *------------------------------------------------------------------------
 */
static int
MemoryAllocationError(
    Tcl_Interp *interp,		/* Interpreter for error message. May be NULL */
    size_t size)		/* Size of attempted allocation that failed */
{
    if (interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"list construction failed: unable to alloc %" TCL_Z_MODIFIER
		"u bytes",
		size));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
    }
    return TCL_ERROR;
}

/*
 *------------------------------------------------------------------------
 *
 * TclListLimitExceededError --
 *
 *    Generates an error for exceeding maximum list size.
 *
 * Results:
 *    Always TCL_ERROR.
 *
 * Side effects:
 *    Error message and code are stored in the interpreter if not NULL.
 *
 *------------------------------------------------------------------------
 */
int
TclListLimitExceededError(
    Tcl_Interp *interp)
{
    /*
     * As an aside, note there is no parameter passed for the bad length
     * because the cverflow is computationally detected and does not fit
     * in Tcl_Size.
     */
    if (interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"max length (%" TCL_SIZE_MODIFIER "d) of a Tcl list exceeded",
		(Tcl_Size)LIST_MAX));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
    }
    return TCL_ERROR;
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepUnsharedShiftDown --
 *
 *    Shifts the "in-use" contents in the ListStore for a ListRep down
 *    by the given number of slots. The ListStore must be unshared and
 *    the free space at the front of the storage area must be big enough.
 *    It is the caller's responsibility to check.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    The contents of the ListRep's ListStore area are shifted down in the
 *    storage area. The ListRep's ListSpan is updated accordingly.
 *
 *------------------------------------------------------------------------
 */
static inline void
ListRepUnsharedShiftDown(
    ListRep *repPtr,
    Tcl_Size shiftCount)
{
    ListStore *storePtr;

    LISTREP_CHECK(repPtr);
    LIST_ASSERT(!ListRepIsShared(repPtr));

    storePtr = repPtr->storePtr;

    LIST_COUNT_ASSERT(shiftCount);
    LIST_ASSERT(storePtr->firstUsed >= shiftCount);

    memmove(&storePtr->slots[storePtr->firstUsed - shiftCount],
	    &storePtr->slots[storePtr->firstUsed],
	    storePtr->numUsed * sizeof(Tcl_Obj *));
    storePtr->firstUsed -= shiftCount;
    if (repPtr->spanPtr) {
	repPtr->spanPtr->spanStart -= shiftCount;
	LIST_ASSERT(repPtr->spanPtr->spanLength == storePtr->numUsed);
    } else {
	/*
	 * If there was no span, firstUsed must have been 0 (Invariant)
	 * AND shiftCount must have been 0 (<= firstUsed on call)
	 * In other words, this would have been a no-op
	 */

	LIST_ASSERT(storePtr->firstUsed == 0);
	LIST_ASSERT(shiftCount == 0);
    }

    LISTREP_CHECK(repPtr);
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepUnsharedShiftUp --
 *
 *    Shifts the "in-use" contents in the ListStore for a ListRep up
 *    by the given number of slots. The ListStore must be unshared and
 *    the free space at the back of the storage area must be big enough.
 *    It is the caller's responsibility to check.
 *    TODO - this function is not currently used.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    The contents of the ListRep's ListStore area are shifted up in the
 *    storage area. The ListRep's ListSpan is updated accordingly.
 *
 *------------------------------------------------------------------------
 */
#if 0
static inline void
ListRepUnsharedShiftUp(
    ListRep *repPtr,
    Tcl_Size shiftCount)
{
    ListStore *storePtr;

    LISTREP_CHECK(repPtr);
    LIST_ASSERT(!ListRepIsShared(repPtr));
    LIST_COUNT_ASSERT(shiftCount);

    storePtr = repPtr->storePtr;
    LIST_ASSERT((storePtr->firstUsed + storePtr->numUsed + shiftCount)
		<= storePtr->numAllocated);

    memmove(&storePtr->slots[storePtr->firstUsed + shiftCount],
	    &storePtr->slots[storePtr->firstUsed],
	    storePtr->numUsed * sizeof(Tcl_Obj *));
    storePtr->firstUsed += shiftCount;
    if (repPtr->spanPtr) {
	repPtr->spanPtr->spanStart += shiftCount;
    } else {
	/* No span means entire original list is span */
	/* Should have been zero before shift - Invariant TBD */
	LIST_ASSERT(storePtr->firstUsed == shiftCount);
	repPtr->spanPtr = ListSpanNew(shiftCount, storePtr->numUsed);
    }

    LISTREP_CHECK(repPtr);
}
#endif

/*
 *------------------------------------------------------------------------
 *
 * ListRepValidate --
 *
 *	Checks all invariants for a ListRep and panics on failure.
 *	Note this is independent of NDEBUG, assert etc.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    Panics if any invariant is not met.
 *
 *------------------------------------------------------------------------
 */
static void
ListRepValidate(
    const ListRep *repPtr,
    const char *file,
    int lineNum)
{
    ListStore *storePtr = repPtr->storePtr;
    const char *condition;

    (void)storePtr; /* To stop gcc from whining about unused vars */

#define INVARIANT(cond_) \
    do {								\
	if (!(cond_)) {							\
	    condition = #cond_;						\
	    goto failure;						\
	}								\
    } while (0)

    /* Separate each condition so line number gives exact reason for failure */
    INVARIANT(storePtr != NULL);
    INVARIANT(storePtr->numAllocated >= 0);
    INVARIANT(storePtr->numAllocated <= LIST_MAX);
    INVARIANT(storePtr->firstUsed >= 0);
    INVARIANT(storePtr->firstUsed < storePtr->numAllocated);
    INVARIANT(storePtr->numUsed >= 0);
    INVARIANT(storePtr->numUsed <= storePtr->numAllocated);
    INVARIANT(storePtr->firstUsed <= (storePtr->numAllocated - storePtr->numUsed));

    if (! ListRepIsShared(repPtr)) {
	/*
	 * If this is the only reference and there is no span, then store
	 * occupancy must begin at 0
	 */
	INVARIANT(repPtr->spanPtr || repPtr->storePtr->firstUsed == 0);
    }

    INVARIANT(ListRepStart(repPtr) >= storePtr->firstUsed);
    INVARIANT(ListRepLength(repPtr) <= storePtr->numUsed);
    INVARIANT(ListRepStart(repPtr) <= (storePtr->firstUsed + storePtr->numUsed - ListRepLength(repPtr)));

#undef INVARIANT
    return;

  failure:
    Tcl_Panic("List internal failure in %s line %d. Condition: %s",
	    file, lineNum, condition);
}

/*
 *------------------------------------------------------------------------
 *
 * TclListObjValidate --
 *
 *    Wrapper around ListRepValidate. Primarily used from test suite.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    Will panic if internal structure is not consistent or if object
 *    cannot be converted to a list object.
 *
 *------------------------------------------------------------------------
 */
void
TclListObjValidate(
    Tcl_Interp *interp,
    Tcl_Obj *listObj)
{
    ListRep listRep;
    if (TclListObjGetRep(interp, listObj, &listRep) != TCL_OK) {
	Tcl_Panic("Object passed to TclListObjValidate cannot be converted to "
		"a list object.");
    }
    ListRepValidate(&listRep, __FILE__, __LINE__);
}

/*
 *----------------------------------------------------------------------
 *
 * ListStoreNew --
 *
 *	Allocates a new ListStore with space for at least objc elements. objc
 *	must be > 0.  If objv!=NULL, initializes with the first objc values
 *	in that array.  If objv==NULL, initalize 0 elements, with space
 *	to add objc more.
 *
 *      Normally the function allocates the exact space requested unless
 *      the flags arguments has any LISTREP_SPACE_*
 *      bits set. See the comments for those #defines.
 *
 * Results:
 *      On success, a pointer to the allocated ListStore is returned.
 *      On allocation failure, panics if LISTREP_PANIC_ON_FAIL is set in
 *      flags; otherwise returns NULL.
 *
 * Side effects:
 *	The ref counts of the elements in objv are incremented on success
 *	since the returned ListStore references them.
 *
 *----------------------------------------------------------------------
 */
static ListStore *
ListStoreNew(
    Tcl_Size objc,
    Tcl_Obj *const objv[],
    int flags)
{
    ListStore *storePtr;
    Tcl_Size capacity;

    /*
     * First check to see if we'd overflow and try to allocate an object
     * larger than our memory allocator allows.
     */
    if (objc > LIST_MAX) {
	if (flags & LISTREP_PANIC_ON_FAIL) {
	    Tcl_Panic("max length of a Tcl list exceeded");
	}
	return NULL;
    }

    storePtr = NULL;
    if (flags & LISTREP_SPACE_FLAGS) {
	/* Caller requests extra space front, back or both */
	storePtr = (ListStore *)TclAttemptAllocElemsEx(
	    objc, sizeof(Tcl_Obj *), offsetof(ListStore, slots), &capacity);
    } else {
	/* Exact allocation */
	capacity = objc;
	storePtr = (ListStore *)Tcl_AttemptAlloc(LIST_SIZE(capacity));
    }
    if (storePtr == NULL) {
	if (flags & LISTREP_PANIC_ON_FAIL) {
	    Tcl_Panic("list creation failed: unable to alloc %" TCL_SIZE_MODIFIER
		    "d bytes",
		    LIST_SIZE(objc));
	}
	return NULL;
    }

    storePtr->refCount = 0;
    storePtr->flags = 0;
    storePtr->numAllocated = capacity;
    if (capacity == objc) {
	storePtr->firstUsed = 0;
    } else {
	Tcl_Size extra = capacity - objc;
	int spaceFlags = flags & LISTREP_SPACE_FLAGS;
	if (spaceFlags == LISTREP_SPACE_ONLY_BACK) {
	    storePtr->firstUsed = 0;
	} else if (spaceFlags == LISTREP_SPACE_FAVOR_FRONT) {
	    /* Leave more space in the front */
	    storePtr->firstUsed =
		extra - (extra / 4); /* NOT same as 3*extra/4 */
	} else if (spaceFlags == LISTREP_SPACE_FAVOR_BACK) {
	    /* Leave more space in the back */
	    storePtr->firstUsed = extra / 4;
	} else {
	    /* Apportion equally */
	    storePtr->firstUsed = extra / 2;
	}
    }

    if (objv) {
	storePtr->numUsed = objc;
	ObjArrayCopy(&storePtr->slots[storePtr->firstUsed], objc, objv);
    } else {
	storePtr->numUsed = 0;
    }

    return storePtr;
}

/*
 *------------------------------------------------------------------------
 *
 * ListStoreReallocate --
 *
 *    Reallocates the memory for a ListStore allocating extra for
 *    possible future growth.
 *
 * Results:
 *    Pointer to the ListStore which may be the same as storePtr or pointer
 *    to a new block of memory. On reallocation failure, NULL is returned.
 *
 *
 * Side effects:
 *    The memory pointed to by storePtr is freed if it a new block has to
 *    be returned.
 *
 *
 *------------------------------------------------------------------------
 */
static ListStore *
ListStoreReallocate(
    ListStore *storePtr,
    Tcl_Size needed)
{
    Tcl_Size capacity;

    if (needed > LIST_MAX) {
	return NULL;
    }
    storePtr = (ListStore *) TclAttemptReallocElemsEx(storePtr,
	    needed, sizeof(Tcl_Obj *), offsetof(ListStore, slots), &capacity);
    /* Only the capacity has changed, fix it in the header */
    if (storePtr) {
	storePtr->numAllocated = capacity;
    }
    return storePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * ListRepInit --
 *
 *      Initializes a ListRep to hold a list internal representation
 *      with space for objc elements.
 *
 *      objc must be > 0. If objv!=NULL, initializes with the first objc
 *      values in that array. If objv==NULL, initalize list internal rep to
 *      have 0 elements, with space to add objc more.
 *
 *	Normally the function allocates the exact space requested unless
 *	the flags arguments has one of the LISTREP_SPACE_* bits set.
 *	See the comments for those #defines.
 *
 *      The reference counts of the ListStore and ListSpan (if present)
 *	pointed to by the initialized repPtr are set to zero.
 *	Caller has to manage them as necessary.
 *
 * Results:
 *      On success, TCL_OK is returned with *listRepPtr initialized.
 *      On failure, panics if LISTREP_PANIC_ON_FAIL is set in flags; otherwise
 *	returns TCL_ERROR with *listRepPtr fields set to NULL.
 *
 * Side effects:
 *	The ref counts of the elements in objv are incremented since the
 *	resulting list now refers to them.
 *
 *----------------------------------------------------------------------
 */
static int
ListRepInit(
    Tcl_Size objc,
    Tcl_Obj *const objv[],
    int flags,
    ListRep *repPtr)
{
    ListStore *storePtr;

    storePtr = ListStoreNew(objc, objv, flags);
    if (storePtr) {
	repPtr->storePtr = storePtr;
	if (storePtr->firstUsed == 0) {
	    repPtr->spanPtr = NULL;
	} else {
	    repPtr->spanPtr =
		ListSpanNew(storePtr->firstUsed, storePtr->numUsed);
	}
	return TCL_OK;
    }
    /*
     * Initialize to keep gcc happy at the call site. Else it complains
     * about possibly uninitialized use.
     */
    repPtr->storePtr = NULL;
    repPtr->spanPtr = NULL;
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * ListRepInitAttempt --
 *
 *	Creates a list internal rep with space for objc elements. See
 *	ListRepInit for requirements for parameters (in particular objc must
 *	be > 0). This function only adds error messages to the interpreter if
 *	not NULL.
 *
 *      The reference counts of the ListStore and ListSpan (if present)
 *	pointed to by the initialized repPtr are set to zero.
 *	Caller has to manage them as necessary.
 *
 * Results:
 *      On success, TCL_OK is returned with *listRepPtr initialized.
 *	On allocation failure, returnes TCL_ERROR with an error message
 *	in the interpreter if non-NULL.
 *
 * Side effects:
 *	The ref counts of the elements in objv are incremented since the
 *	resulting list now refers to them.
 *
 *----------------------------------------------------------------------
 */
static int
ListRepInitAttempt(
    Tcl_Interp *interp,
    Tcl_Size objc,
    Tcl_Obj *const objv[],
    ListRep *repPtr)
{
    int result = ListRepInit(objc, objv, 0, repPtr);

    if (result != TCL_OK && interp != NULL) {
	if (objc > LIST_MAX) {
	    TclListLimitExceededError(interp);
	} else {
	    MemoryAllocationError(interp, LIST_SIZE(objc));
	}
    }
    return result;
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepClone --
 *
 *    Does a deep clone of an existing ListRep.
 *
 *    Normally the function allocates the exact space needed unless
 *    the flags arguments has one of the LISTREP_SPACE_* bits set.
 *    See the comments for those #defines.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    The toRepPtr location is initialized with the ListStore and ListSpan
 *    (if needed) containing a copy of the list elements in fromRepPtr.
 *    The function will panic if memory cannot be allocated.
 *
 *------------------------------------------------------------------------
 */
static void
ListRepClone(
    ListRep *fromRepPtr,
    ListRep *toRepPtr,
    int flags)
{
    Tcl_Obj **fromObjs;
    Tcl_Size numFrom;

    ListRepElements(fromRepPtr, numFrom, fromObjs);
    ListRepInit(numFrom, fromObjs, flags | LISTREP_PANIC_ON_FAIL, toRepPtr);
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepUnsharedFreeUnreferenced --
 *
 *    Frees any Tcl_Obj's from the "in-use" area of the ListStore for a
 *    ListRep that are not actually references from any lists.
 *
 *    IMPORTANT: this function must not be called on a shared internal
 *    representation or the internal representation of a shared Tcl_Obj.
 *
 * Results:
 *    None.
 *
 * Side effects:
 *    The firstUsed and numUsed fields of the ListStore are updated to
 *    reflect the new "in-use" extent.
 *
 *------------------------------------------------------------------------
 */
static void
ListRepUnsharedFreeUnreferenced(
    const ListRep *repPtr)
{
    Tcl_Size count;
    ListStore *storePtr;
    ListSpan *spanPtr;

    LIST_ASSERT(!ListRepIsShared(repPtr));
    LISTREP_CHECK(repPtr);

    storePtr = repPtr->storePtr;
    spanPtr = repPtr->spanPtr;
    if (spanPtr == NULL) {
	LIST_ASSERT(storePtr->firstUsed == 0); /* Invariant TBD */
	return;
    }

    /* Collect garbage at front */
    count = spanPtr->spanStart - storePtr->firstUsed;
    LIST_COUNT_ASSERT(count);
    if (count > 0) {
	/* T:listrep-1.5.1,6.{1:8} */
	ObjArrayDecrRefs(storePtr->slots, storePtr->firstUsed, count);
	storePtr->firstUsed = spanPtr->spanStart;
	LIST_ASSERT(storePtr->numUsed >= count);
	storePtr->numUsed -= count;
    }

    /* Collect garbage at back */
    count = (storePtr->firstUsed + storePtr->numUsed)
	  - (spanPtr->spanStart + spanPtr->spanLength);
    LIST_COUNT_ASSERT(count);
    if (count > 0) {
	/* T:listrep-6.{1:8} */
	ObjArrayDecrRefs(
	    storePtr->slots, spanPtr->spanStart + spanPtr->spanLength, count);
	LIST_ASSERT(storePtr->numUsed >= count);
	storePtr->numUsed -= count;
    }

    LIST_ASSERT(ListRepStart(repPtr) == storePtr->firstUsed);
    LIST_ASSERT(ListRepLength(repPtr) == storePtr->numUsed);
    LISTREP_CHECK(repPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_NewListObj --
 *
 *	This function is normally called when not debugging: i.e., when
 *	TCL_MEM_DEBUG is not defined. It creates a new list object from an
 *	(objc,objv) array: that is, each of the objc elements of the array
 *	referenced by objv is inserted as an element into a new Tcl object.
 *
 *	When TCL_MEM_DEBUG is defined, this function just returns the result
 *	of calling the debugging version Tcl_DbNewListObj.
 *
 * Results:
 *	A new list object is returned that is initialized from the object
 *	pointers in objv. If objc is less than or equal to zero, an empty
 *	object is returned. The new object's string representation is left
 *	NULL. The resulting new list object has ref count 0.
 *
 * Side effects:
 *	The ref counts of the elements in objv are incremented since the
 *	resulting list now refers to them.
 *
 *----------------------------------------------------------------------
 */

#ifdef TCL_MEM_DEBUG
#undef Tcl_NewListObj

Tcl_Obj *
Tcl_NewListObj(
    Tcl_Size objc,		/* Count of objects referenced by objv. */
    Tcl_Obj *const objv[])	/* An array of pointers to Tcl objects. */
{
    return Tcl_DbNewListObj(objc, objv, "unknown", 0);
}

#else /* if not TCL_MEM_DEBUG */

Tcl_Obj *
Tcl_NewListObj(
    Tcl_Size objc,		/* Count of objects referenced by objv. */
    Tcl_Obj *const objv[])	/* An array of pointers to Tcl objects. */
{
    ListRep listRep;
    Tcl_Obj *listObj;

    TclNewObj(listObj);

    if (objc <= 0) {
	return listObj;
    }

    ListRepInit(objc, objv, LISTREP_PANIC_ON_FAIL, &listRep);
    ListObjReplaceRepAndInvalidate(listObj, &listRep);

    return listObj;
}
#endif /* if TCL_MEM_DEBUG */

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DbNewListObj --
 *
 *	This function is normally called when debugging: i.e., when
 *	TCL_MEM_DEBUG is defined. It creates new list objects. It is the same
 *	as the Tcl_NewListObj function above except that it calls
 *	Tcl_DbCkalloc directly with the file name and line number from its
 *	caller. This simplifies debugging since then the [memory active]
 *	command will report the correct file name and line number when
 *	reporting objects that haven't been freed.
 *
 *	When TCL_MEM_DEBUG is not defined, this function just returns the
 *	result of calling Tcl_NewListObj.
 *
 * Results:
 *	A new list object is returned that is initialized from the object
 *	pointers in objv. If objc is less than or equal to zero, an empty
 *	object is returned. The new object's string representation is left
 *	NULL. The new list object has ref count 0.
 *
 * Side effects:
 *	The ref counts of the elements in objv are incremented since the
 *	resulting list now refers to them.
 *
 *----------------------------------------------------------------------
 */

#ifdef TCL_MEM_DEBUG

Tcl_Obj *
Tcl_DbNewListObj(
    Tcl_Size objc,		/* Count of objects referenced by objv. */
    Tcl_Obj *const objv[],	/* An array of pointers to Tcl objects. */
    const char *file,		/* The name of the source file calling this
				 * function; used for debugging. */
    int line)			/* Line number in the source file; used for
				 * debugging. */
{
    Tcl_Obj *listObj;
    ListRep listRep;

    TclDbNewObj(listObj, file, line);

    if (objc <= 0) {
	return listObj;
    }

    ListRepInit(objc, objv, LISTREP_PANIC_ON_FAIL, &listRep);
    ListObjReplaceRepAndInvalidate(listObj, &listRep);

    return listObj;
}

#else /* if not TCL_MEM_DEBUG */

Tcl_Obj *
Tcl_DbNewListObj(
    Tcl_Size objc,		/* Count of objects referenced by objv. */
    Tcl_Obj *const objv[],	/* An array of pointers to Tcl objects. */
    TCL_UNUSED(const char *) /*file*/,
    TCL_UNUSED(int) /*line*/)
{
    return Tcl_NewListObj(objc, objv);
}
#endif /* TCL_MEM_DEBUG */

/*
 *------------------------------------------------------------------------
 *
 * TclNewListObj2 --
 *
 *    Create a new Tcl_Obj list comprising of the concatenation of two
 *    Tcl_Obj* arrays.
 *    TODO - currently this function is not used within tclListObj but
 *    need to see if it would be useful in other files that preallocate
 *    lists and then append.
 *
 * Results:
 *    Non-NULL pointer to the allocate Tcl_Obj.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
#if 0
Tcl_Obj *
TclNewListObj2(
    Tcl_Size objc1,		/* Count of objects referenced by objv1. */
    Tcl_Obj *const objv1[],	/* First array of pointers to Tcl objects. */
    Tcl_Size objc2,		/* Count of objects referenced by objv2. */
    Tcl_Obj *const objv2[])	/* Second array of pointers to Tcl objects. */
{
    Tcl_Obj *listObj;
    ListStore *storePtr;
    Tcl_Size objc = objc1 + objc2;

    listObj = Tcl_NewListObj(objc, NULL);
    if (objc == 0) {
	return listObj; /* An empty object */
    }
    LIST_ASSERT_TYPE(listObj);

    storePtr = ListObjStorePtr(listObj);

    LIST_ASSERT(ListObjSpanPtr(listObj) == NULL);
    LIST_ASSERT(storePtr->firstUsed == 0);
    LIST_ASSERT(storePtr->numUsed == 0);
    LIST_ASSERT(storePtr->numAllocated >= objc);

    if (objc1) {
	ObjArrayCopy(storePtr->slots, objc1, objv1);
    }
    if (objc2) {
	ObjArrayCopy(&storePtr->slots[objc1], objc2, objv2);
    }
    storePtr->numUsed = objc;
    return listObj;
}
#endif

/*
 *----------------------------------------------------------------------
 *
 * TclListObjGetRep --
 *
 *	This function returns a copy of the ListRep stored
 *	as the internal representation of an object. The reference
 *	counts of the (ListStore, ListSpan) contained in the representation
 *	are NOT incremented.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *listRepP
 *	is set to a copy of the descriptor stored as the internal
 *	representation of the Tcl_Obj containing a list. if listPtr does not
 *	refer to a list object and the object can not be converted to one,
 *	TCL_ERROR is returned and an error message will be left in the
 *	interpreter's result if interp is not NULL.
 *
 * Side effects:
 *	The possible conversion of the object referenced by listPtr
 *	to a list object. *repPtr is initialized to the internal rep
 *      if result is TCL_OK, or set to NULL on error.
 *----------------------------------------------------------------------
 */

static int
TclListObjGetRep(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *listObj,		/* List object for which an element array is
				 * to be returned. */
    ListRep *repPtr)		/* Location to store descriptor */
{
    if (!TclHasInternalRep(listObj, &tclListType)) {
	int result;
	result = SetListFromAny(interp, listObj);
	if (result != TCL_OK) {
	    /* Init to keep gcc happy wrt uninitialized fields at call site */
	    repPtr->storePtr = NULL;
	    repPtr->spanPtr = NULL;
	    return result;
	}
    }
    ListObjGetRep(listObj, repPtr);
    LISTREP_CHECK(repPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SetListObj --
 *
 *	Modify an object to be a list containing each of the objc elements of
 *	the object array referenced by objv.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The object is made a list object and is initialized from the object
 *	pointers in objv. If objc is less than or equal to zero, an empty
 *	object is returned. The new object's string representation is left
 *	NULL. The ref counts of the elements in objv are incremented since the
 *	list now refers to them. The object's old string and internal
 *	representations are freed and its type is set NULL.
 *
 *----------------------------------------------------------------------
 */
void
Tcl_SetListObj(
    Tcl_Obj *objPtr,		/* Object whose internal rep to init. */
    Tcl_Size objc,		/* Count of objects referenced by objv. */
    Tcl_Obj *const objv[])	/* An array of pointers to Tcl objects. */
{
    if (Tcl_IsShared(objPtr)) {
	Tcl_Panic("%s called with shared object", "Tcl_SetListObj");
    }

    /*
     * Set the object's type to "list" and initialize the internal rep.
     * However, if there are no elements to put in the list, just give the
     * object an empty string rep and a NULL type. NOTE ListRepInit must
     * not be called with objc == 0!
     */

    if (objc > 0) {
	ListRep listRep;
	/* TODO - perhaps ask for extra space? */
	ListRepInit(objc, objv, LISTREP_PANIC_ON_FAIL, &listRep);
	ListObjReplaceRepAndInvalidate(objPtr, &listRep);
    } else {
	TclFreeInternalRep(objPtr);
	TclInvalidateStringRep(objPtr);
	Tcl_InitStringRep(objPtr, NULL, 0);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclListObjCopy --
 *
 *	Makes a "pure list" copy of a list value. This provides for the C
 *	level a counterpart of the [lrange $list 0 end] command, while using
 *	internals details to be as efficient as possible.
 *
 * Results:
 *	Normally returns a pointer to a new Tcl_Obj, that contains the same
 *	list value as *listPtr does. The returned Tcl_Obj has a refCount of
 *	zero. If *listPtr does not hold a list, NULL is returned, and if
 *	interp is non-NULL, an error message is recorded there.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclListObjCopy(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *listObj)		/* List object for which an element array is
				 * to be returned. */
{
    Tcl_Obj *copyObj;

    if (!TclHasInternalRep(listObj, &tclListType)) {
	if (TclObjTypeHasProc(listObj, lengthProc)) {
	    return Tcl_DuplicateObj(listObj);
	}
	if (SetListFromAny(interp, listObj) != TCL_OK) {
	    return NULL;
	}
    }

    TclNewObj(copyObj);
    TclInvalidateStringRep(copyObj);
    DupListInternalRep(listObj, copyObj);
    return copyObj;
}

/*
 *------------------------------------------------------------------------
 *
 * ListRepRange --
 *
 *	Initializes a ListRep as a range within the passed ListRep.
 *	The range limits are clamped to the list boundaries.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *      The ListStore and ListSpan referenced by in the returned ListRep
 *      may or may not be the same as those passed in. For example, the
 *      ListStore may differ because the range is small enough that a new
 *      ListStore is more memory-optimal. The ListSpan may differ because
 *      it is NULL or shared. Regardless, reference counts on the returned
 *      values are not incremented. Generally, ListObjReplaceRepAndInvalidate
 *      may be used to store the new ListRep back into an object or a
 *      ListRepIncrRefs followed by ListRepDecrRefs to free in case of errors.
 *	Any other use should be carefully reconsidered.
 *      TODO WARNING:- this is an awkward interface and easy for caller
 *      to get wrong. Mostly due to refcount combinations. Perhaps passing
 *      in the source listObj instead of source listRep might simplify.
 *
 *------------------------------------------------------------------------
 */
static void
ListRepRange(
    ListRep *srcRepPtr,		/* Contains source of the range */
    Tcl_Size rangeStart,	/* Index of first element to include */
    Tcl_Size rangeEnd,		/* Index of last element to include */
    int preserveSrcRep,		/* If true, srcRepPtr contents must not be
				 * modified (generally because a shared Tcl_Obj
				 * references it) */
    ListRep *rangeRepPtr)	/* Output. Must NOT be == srcRepPtr */
{
    Tcl_Obj **srcElems;
    Tcl_Size numSrcElems = ListRepLength(srcRepPtr);
    Tcl_Size rangeLen;
    Tcl_Size numAfterRangeEnd;

    LISTREP_CHECK(srcRepPtr);

    /* Take the opportunity to garbage collect */
    /* TODO - we probably do not need the preserveSrcRep here unlike later */
    if (!preserveSrcRep) {
	/* T:listrep-1.{4,5,8,9},2.{4:7},3.{15:18},4.{7,8} */
	ListRepFreeUnreferenced(srcRepPtr);
    } /* else T:listrep-2.{4.2,4.3,5.2,5.3,6.2,7.2,8.1} */

    if (rangeStart < 0) {
	rangeStart = 0;
    }
    if (rangeEnd >= numSrcElems) {
	rangeEnd = numSrcElems - 1;
    }
    if (rangeStart > rangeEnd) {
	/* Empty list of capacity 1. */
	ListRepInit(1, NULL, LISTREP_PANIC_ON_FAIL, rangeRepPtr);
	return;
    }

    rangeLen = rangeEnd - rangeStart + 1;

    /*
     * We can create a range one of four ways:
     *  (0) Range encapsulates entire list
     *  (1) Special case: deleting in-place from end of an unshared object
     *  (2) Use a ListSpan referencing the current ListStore
     *  (3) Creating a new ListStore
     *  (4) Removing all elements outside the range in the current ListStore
     * Option (4) may only be done if caller has not disallowed it AND
     * the ListStore is not shared.
     *
     * The choice depends on heuristics related to speed and memory.
     * TODO - heuristics below need to be measured and tuned.
     *
     * Note: Even if nothing below cause any changes, we still want the
     * string-canonizing effect of [lrange 0 end] so the Tcl_Obj should not
     * be returned as is even if the range encompasses the whole list.
     */
    if (rangeStart == 0 && rangeEnd == (numSrcElems-1)) {
	/* Option 0 - entire list. This may be used to canonicalize */
	/* T:listrep-1.10.1,2.8.1 */
	*rangeRepPtr = *srcRepPtr; /* Note ref counts not incremented */
    } else if (rangeStart == 0 && (!preserveSrcRep)
	    && (!ListRepIsShared(srcRepPtr) && srcRepPtr->spanPtr == NULL)) {
	/* Option 1 - Special case unshared, exclude end elements, no span */
	LIST_ASSERT(srcRepPtr->storePtr->firstUsed == 0); /* If no span */
	ListRepElements(srcRepPtr, numSrcElems, srcElems);
	numAfterRangeEnd = numSrcElems - (rangeEnd + 1);
	/* Assert: Because numSrcElems > rangeEnd earlier */
	if (numAfterRangeEnd != 0) {
	    /* T:listrep-1.{8,9} */
	    ObjArrayDecrRefs(srcElems, rangeEnd + 1, numAfterRangeEnd);
	}
	/* srcRepPtr->storePtr->firstUsed,numAllocated unchanged */
	srcRepPtr->storePtr->numUsed = rangeLen;
	srcRepPtr->storePtr->flags = 0;
	rangeRepPtr->storePtr = srcRepPtr->storePtr; /* Note no incr ref */
	rangeRepPtr->spanPtr = NULL;
    } else if (ListSpanMerited(rangeLen, srcRepPtr->storePtr->numUsed,
	    srcRepPtr->storePtr->numAllocated)) {
	/* Option 2 - because span would be most efficient */
	Tcl_Size spanStart = ListRepStart(srcRepPtr) + rangeStart;
	if (!preserveSrcRep && srcRepPtr->spanPtr
		&& srcRepPtr->spanPtr->refCount <= 1) {
	    /* If span is not shared reuse it */
	    /* T:listrep-2.7.3,3.{16,18} */
	    srcRepPtr->spanPtr->spanStart = spanStart;
	    srcRepPtr->spanPtr->spanLength = rangeLen;
	    *rangeRepPtr = *srcRepPtr;
	} else {
	    /* Span not present or is shared. */
	    /* T:listrep-1.5,2.{5,7},4.{7,8} */
	    rangeRepPtr->storePtr = srcRepPtr->storePtr;
	    rangeRepPtr->spanPtr = ListSpanNew(spanStart, rangeLen);
	}
	/*
	 * We have potentially created a new internal representation that
	 * references the same storage as srcRep but not yet incremented its
	 * reference count. So do NOT call freezombies if preserveSrcRep
	 * is mandated.
	 */
	if (!preserveSrcRep) {
	    /* T:listrep-1.{5.1,5.2,5.4},2.{5,7},3.{16,18},4.{7,8} */
	    ListRepFreeUnreferenced(rangeRepPtr);
	}
    } else if (preserveSrcRep || ListRepIsShared(srcRepPtr)) {
	/* Option 3 - span or modification in place not allowed/desired */
	/* T:listrep-2.{4,6} */
	ListRepElements(srcRepPtr, numSrcElems, srcElems);
	/* TODO - allocate extra space? */
	ListRepInit(rangeLen, &srcElems[rangeStart], LISTREP_PANIC_ON_FAIL,
		rangeRepPtr);
    } else {
	/*
	 * Option 4 - modify in place. Note that because of the invariant
	 * that spanless list stores must start at 0, we have to move
	 * everything to the front.
	 * TODO - perhaps if a span already exists, no need to move to front?
	 * or maybe no need to move all the way to the front?
	 * TODO - if range is small relative to allocation, allocate new?
	 */

	/* Asserts follow from call to ListRepFreeUnreferenced earlier */
	LIST_ASSERT(!preserveSrcRep);
	LIST_ASSERT(!ListRepIsShared(srcRepPtr));
	LIST_ASSERT(ListRepStart(srcRepPtr) == srcRepPtr->storePtr->firstUsed);
	LIST_ASSERT(ListRepLength(srcRepPtr) == srcRepPtr->storePtr->numUsed);

	ListRepElements(srcRepPtr, numSrcElems, srcElems);

	/* Free leading elements outside range */
	if (rangeStart != 0) {
	    /* T:listrep-1.4,3.15 */
	    ObjArrayDecrRefs(srcElems, 0, rangeStart);
	}
	/* Ditto for trailing */
	numAfterRangeEnd = numSrcElems - (rangeEnd + 1);
	/* Assert: Because numSrcElems > rangeEnd earlier */
	if (numAfterRangeEnd != 0) {
	    /* T:listrep-3.17 */
	    ObjArrayDecrRefs(srcElems, rangeEnd + 1, numAfterRangeEnd);
	}
	memmove(&srcRepPtr->storePtr->slots[0],
		&srcRepPtr->storePtr
		     ->slots[srcRepPtr->storePtr->firstUsed + rangeStart],
		rangeLen * sizeof(Tcl_Obj *));
	srcRepPtr->storePtr->firstUsed = 0;
	srcRepPtr->storePtr->numUsed = rangeLen;
	srcRepPtr->storePtr->flags = 0;
	if (srcRepPtr->spanPtr) {
	    /* In case the source has a span, update it for consistency */
	    /* T:listrep-3.{15,17} */
	    srcRepPtr->spanPtr->spanStart = srcRepPtr->storePtr->firstUsed;
	    srcRepPtr->spanPtr->spanLength = srcRepPtr->storePtr->numUsed;
	}
	rangeRepPtr->storePtr = srcRepPtr->storePtr;
	rangeRepPtr->spanPtr = NULL;
    }

    /* TODO - call freezombies here if !preserveSrcRep? */

    /* Note ref counts intentionally not incremented */
    LISTREP_CHECK(rangeRepPtr);
    return;
}

/*
 *----------------------------------------------------------------------
 *
 * TclListObjRange --
 *
 *	Makes a slice of a list value.
 *      *listObj must be known to be a valid list.
 *
 * Results:
 *	Returns a pointer to the sliced list.
 *      This may be a new object or the same object if not shared.
 *	Returns NULL if passed listObj was not a list and could not be
 *	converted to one.
 *
 * Side effects:
 *	The possible conversion of the object referenced by listPtr
 *	to a list object.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclListObjRange(
    Tcl_Interp *interp,		/* May be NULL. Used for error messages */
    Tcl_Obj *listObj,		/* List object to take a range from. */
    Tcl_Size rangeStart,	/* Index of first element to include. */
    Tcl_Size rangeEnd)		/* Index of last element to include. */
{
    ListRep listRep;
    ListRep resultRep;

    int isShared;
    if (TclListObjGetRep(interp, listObj, &listRep) != TCL_OK) {
	return NULL;
    }

    isShared = Tcl_IsShared(listObj);

    ListRepRange(&listRep, rangeStart, rangeEnd, isShared, &resultRep);

    if (isShared) {
	/* T:listrep-1.10.1,2.{4.2,4.3,5.2,5.3,6.2,7.2,8.1} */
	TclNewObj(listObj);
    } /* T:listrep-1.{4.3,5.1,5.2} */
    ListObjReplaceRepAndInvalidate(listObj, &resultRep);
    return listObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclListObjGetElement --
 *
 *	Returns a single element from the array of the elements in a list
 *	object, without doing any bounds checking.  Caller must ensure
 *	that ObjPtr of type 'tclListType' and that index is valid for the
 *	list.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclListObjGetElement(
    Tcl_Obj *objPtr,		/* List object for which an element array is
				 * to be returned. */
    Tcl_Size index)
{
    return ListObjStorePtr(objPtr)->slots[ListObjStart(objPtr) + index];
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjGetElements --
 *
 *	This function returns an (objc,objv) array of the elements in a list
 *	object.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *objcPtr is set to
 *	the count of list elements and *objvPtr is set to a pointer to an
 *	array of (*objcPtr) pointers to each list element. If listPtr does not
 *	refer to a list object and the object can not be converted to one,
 *	TCL_ERROR is returned and an error message will be left in the
 *	interpreter's result if interp is not NULL.
 *
 *	The objects referenced by the returned array should be treated as
 *	readonly and their ref counts are _not_ incremented; the caller must
 *	do that if it holds on to a reference. Furthermore, the pointer and
 *	length returned by this function may change as soon as any function is
 *	called on the list object; be careful about retaining the pointer in a
 *	local data structure.
 *
 * Side effects:
 *	The possible conversion of the object referenced by listPtr
 *	to a list object.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_ListObjGetElements
int
Tcl_ListObjGetElements(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *objPtr,		/* List object for which an element array is
				 * to be returned. */
    Tcl_Size *objcPtr,		/* Where to store the count of objects
				 * referenced by objv. */
    Tcl_Obj ***objvPtr)		/* Where to store the pointer to an array of
				 * pointers to the list's objects. */
{
    ListRep listRep;

    if (TclObjTypeHasProc(objPtr, getElementsProc)) {
	return TclObjTypeGetElements(interp, objPtr, objcPtr, objvPtr);
    }
    if (TclListObjGetRep(interp, objPtr, &listRep) != TCL_OK) {
	return TCL_ERROR;
    }
    ListRepElements(&listRep, *objcPtr, *objvPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjAppendList --
 *
 *	This function appends the elements in the list fromObj
 *	to toObj. toObj must not be shared else the function will panic.
 *
 * Results:
 *	The return value is normally TCL_OK. If fromObj or toObj do not
 *	refer to list values, TCL_ERROR is returned and an error message is
 *	left in the interpreter's result if interp is not NULL.
 *
 * Side effects:
 *	The reference counts of the elements in fromObj are incremented
 *	since the list now refers to them. toObj and fromObj are
 *	converted, if necessary, to list objects. Also, appending the new
 *	elements may cause toObj's array of element pointers to grow.
 *	toObj's old string representation, if any, is invalidated.
 *
 *----------------------------------------------------------------------
 */
int
Tcl_ListObjAppendList(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *toObj,		/* List object to append elements to. */
    Tcl_Obj *fromObj)		/* List obj with elements to append. */
{
    Tcl_Size objc;
    Tcl_Obj **objv;

    if (Tcl_IsShared(toObj)) {
	Tcl_Panic("%s called with shared object", "Tcl_ListObjAppendList");
    }

    if (TclListObjGetElements(interp, fromObj, &objc, &objv) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Insert the new elements starting after the lists's last element.
     * Delete zero existing elements.
     */

    return TclListObjAppendElements(interp, toObj, objc, objv);
}

/*
 *------------------------------------------------------------------------
 *
 * TclListObjAppendElements --
 *
 *      Appends multiple elements to a Tcl_Obj list object. If
 *      the passed Tcl_Obj is not a list object, it will be converted to one
 *      and an error raised if the conversion fails.
 *
 *	The Tcl_Obj must not be shared though the internal representation
 *	may be.
 *
 * Results:
 *	On success, TCL_OK is returned with the specified elements appended.
 *	On failure, TCL_ERROR is returned with an error message in the
 *	interpreter if not NULL.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
int
TclListObjAppendElements(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *toObj,		/* List object to append */
    Tcl_Size elemCount,		/* Number of elements in elemObjs[] */
    Tcl_Obj * const elemObjv[])	/* Objects to append to toObj's list. */
{
    ListRep listRep;
    Tcl_Obj **toObjv;
    Tcl_Size toLen;
    Tcl_Size finalLen;

    if (Tcl_IsShared(toObj)) {
	Tcl_Panic("%s called with shared object", "TclListObjAppendElements");
    }

    if (TclListObjGetRep(interp, toObj, &listRep) != TCL_OK) {
	/* Cannot be converted to a list */
	return TCL_ERROR;
    }

    if (elemCount <= 0) {
	/*
	 * Note that when elemCount <= 0, this routine is logically a
	 * no-op, removing and adding no elements to the list. However, by removing
	 * the string representation, we get the important side effect that the
	 * resulting listPtr is a list in canonical form. This is important.
	 * Resist any temptation to optimize this case further. See bug [e38dce74e2].
	 */
	if (!ListObjIsCanonical(toObj)) {
	    TclInvalidateStringRep(toObj);
	}
	/* Nothing to do. Note AFTER check for list above */
	return TCL_OK;
    }

    ListRepElements(&listRep, toLen, toObjv);
    if (elemCount > LIST_MAX || toLen > (LIST_MAX - elemCount)) {
	return TclListLimitExceededError(interp);
    }

    finalLen = toLen + elemCount;
    if (!ListRepIsShared(&listRep)) {
	/*
	 * Reuse storage if possible. Even if too small, realloc-ing instead
	 * of creating a new ListStore will save us on manipulating Tcl_Obj
	 * reference counts on the elements which is a substantial cost
	 * if the list is not small.
	 */
	Tcl_Size numTailFree;

	ListRepFreeUnreferenced(&listRep); /* Collect garbage before checking room */

	LIST_ASSERT(ListRepStart(&listRep) == listRep.storePtr->firstUsed);
	LIST_ASSERT(ListRepLength(&listRep) == listRep.storePtr->numUsed);
	LIST_ASSERT(toLen == listRep.storePtr->numUsed);

	if (finalLen > listRep.storePtr->numAllocated) {
	    /* T:listrep-1.{2,11},3.6 */
	    ListStore *newStorePtr = ListStoreReallocate(
		    listRep.storePtr, finalLen);
	    if (newStorePtr == NULL) {
		return MemoryAllocationError(interp, LIST_SIZE(finalLen));
	    }
	    LIST_ASSERT(newStorePtr->numAllocated >= finalLen);
	    listRep.storePtr = newStorePtr;
	    /*
	     * WARNING: at this point the Tcl_Obj internal rep potentially
	     * points to freed storage if the reallocation returned a
	     * different location. Overwrite it to bring it back in sync.
	     */
	    ListObjStompRep(toObj, &listRep);
	} /* else T:listrep-3.{4,5} */
	LIST_ASSERT(listRep.storePtr->numAllocated >= finalLen);
	/* Current store big enough */
	numTailFree = ListRepNumFreeTail(&listRep);
	LIST_ASSERT((numTailFree + listRep.storePtr->firstUsed)
		    >= elemCount); /* Total free */
	if (numTailFree < elemCount) {
	    /* Not enough room at back. Move some to front */
	    /* T:listrep-3.5 */
	    Tcl_Size shiftCount = elemCount - numTailFree;
	    /* Divide remaining space between front and back */
	    shiftCount += (listRep.storePtr->numAllocated - finalLen) / 2;
	    LIST_ASSERT(shiftCount <= listRep.storePtr->firstUsed);
	    if (shiftCount) {
		/* T:listrep-3.5 */
		ListRepUnsharedShiftDown(&listRep, shiftCount);
	    }
	} /* else T:listrep-3.{4,6} */
	ObjArrayCopy(
		&listRep.storePtr->slots[
			ListRepStart(&listRep) + ListRepLength(&listRep)],
		elemCount, elemObjv);
	listRep.storePtr->numUsed = finalLen;
	if (listRep.spanPtr) {
	    /* T:listrep-3.{4,5,6} */
	    LIST_ASSERT(listRep.spanPtr->spanStart
			== listRep.storePtr->firstUsed);
	    listRep.spanPtr->spanLength = finalLen;
	} /* else T:listrep-3.6.3 */
	LIST_ASSERT(ListRepStart(&listRep) == listRep.storePtr->firstUsed);
	LIST_ASSERT(ListRepLength(&listRep) == finalLen);
	LISTREP_CHECK(&listRep);

	ListObjReplaceRepAndInvalidate(toObj, &listRep);
	return TCL_OK;
    }

    /*
     * Have to make a new list rep, either shared or no room in old one.
     * If the old list did not have a span (all elements at front), do
     * not leave space in the front either, assuming all appends and no
     * prepends.
     */
    if (ListRepInit(finalLen, NULL,
	    listRep.spanPtr ? LISTREP_SPACE_FAVOR_BACK : LISTREP_SPACE_ONLY_BACK,
	    &listRep) != TCL_OK) {
	return MemoryAllocationError(interp, finalLen);
    }
    LIST_ASSERT(listRep.storePtr->numAllocated >= finalLen);

    if (toLen) {
	/* T:listrep-2.{2,9},4.5 */
	ObjArrayCopy(ListRepSlotPtr(&listRep, 0), toLen, toObjv);
    }
    ObjArrayCopy(ListRepSlotPtr(&listRep, toLen), elemCount, elemObjv);
    listRep.storePtr->numUsed = finalLen;
    if (listRep.spanPtr) {
	/* T:listrep-4.5 */
	LIST_ASSERT(listRep.spanPtr->spanStart == listRep.storePtr->firstUsed);
	listRep.spanPtr->spanLength = finalLen;
    }
    LISTREP_CHECK(&listRep);
    ListObjReplaceRepAndInvalidate(toObj, &listRep);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjAppendElement --
 *
 *	Like 'Tcl_ListObjAppendList', but Appends a single value to a list.
 *
 * Value
 *
 *	TCL_OK
 *
 *	    'objPtr' is appended to the elements of 'listPtr'.
 *
 *	TCL_ERROR
 *
 *	    listPtr does not refer to a list object and the object can not be
 *	    converted to one. An error message will be left in the
 *	    interpreter's result if interp is not NULL.
 *
 * Effect
 *
 *	If 'listPtr' is not already of type 'tclListType', it is converted.
 *	The 'refCount' of 'objPtr' is incremented as it is added to 'listPtr'.
 *	Appending the new element may cause the array of element pointers
 *	in 'listObj' to grow.  Any preexisting string representation of
 *	'listPtr' is invalidated.
 *
 *----------------------------------------------------------------------
 */
int
Tcl_ListObjAppendElement(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *toObj,		/* List object to append elemObj to. */
    Tcl_Obj *elemObj)		/* Object to append to toObj's list. */
{
    /*
     * TODO - compare perf with 8.6 to see if worth optimizing single
     * element case
     */
    return TclListObjAppendElements(interp, toObj, 1, &elemObj);
}

/*
 *------------------------------------------------------------------------
 *
 * TclListObjAppendIfAbsent --
 *
 *	Appends an element elemObj to list toObj if no element with the same
 *	string representation is not already present. If toObj is not a list
 *	object, it will be converted and an error raised if the conversion
 *	fails.
 *
 *	Reference counting:
 *	 - toObj must not be shared else the function will panic.
 *	 - if elemObj is not added to the list, either because it already
 *	   exists or because of an error, it will be freed if there are no
 *	   references to it. Caller can therefore pass in a 0-ref elemObj and
 *	   not have to worry about decrementing it on return. Conversely,
 *	   this means if caller passes in a 0-ref elemObj it should NOT
 *	   decrement the reference count on return irrespective of return
 *	   code.
 *
 *	CAUTION: Linear search (of course)
 *
 * Results:
 *	Standard Tcl result code. Note element being already present is not
 *	an error.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
int
TclListObjAppendIfAbsent(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *toObj,		/* List object to append */
    Tcl_Obj *elemObj)		/* Element to append to toObj's list. */
{
    Tcl_Obj **elemObjs;
    Tcl_Size numElems;
    int result;

    result = Tcl_ListObjGetElements(interp, toObj, &numElems, &elemObjs);
    if (result != TCL_OK) {
	goto vamoose;
    }
    /* Assume it is worth doing a pointer compare over the whole list first */
    for (Tcl_Size i = 0; i < numElems; ++i) {
	if (elemObjs[i] == elemObj) {
	    result = TCL_OK;
	    goto vamoose;
	}
    }
    Tcl_Size elemLen;
    const char *elemStr;
    elemStr = Tcl_GetStringFromObj(elemObj, &elemLen);
    for (Tcl_Size i = 0; i < numElems; ++i) {
	Tcl_Size toLen;
	const char *toStr = Tcl_GetStringFromObj(elemObjs[i], &toLen);
	if (toLen == elemLen && !strncmp(elemStr, toStr, elemLen)) {
	    result = TCL_OK;
	    goto vamoose;
	}
    }
    result = TclListObjAppendElements(interp, toObj, 1, &elemObj);

vamoose: /* Return result after freeing elemObj if unreferenced */
    Tcl_BounceRefCount(elemObj);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjIndex --
 *
 *	Retrieve a pointer to the element of 'listPtr' at 'index'.  The index
 *	of the first element is 0.
 *
 * Returns:
 *	TCL_OK
 *	    A pointer to the element at 'index' is stored in 'objPtrPtr'.  If
 *	    'index' is out of range, NULL is stored in 'objPtrPtr'.  This
 *	    object should be treated as readonly and its 'refCount' is _not_
 *	    incremented. The caller must do that if it holds on to the
 *	    reference.
 *
 *	TCL_ERROR
 *	    'listPtr' is not a valid list. An error message is left in the
 *	    interpreter's result if 'interp' is not NULL.
 *
 * Effect:
 *	If 'listPtr' is not already of type 'tclListType', it is converted.
 *
 *----------------------------------------------------------------------
 */
int
Tcl_ListObjIndex(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *listObj,		/* List object to index into. */
    Tcl_Size index,		/* Index of element to return. */
    Tcl_Obj **objPtrPtr)	/* The resulting Tcl_Obj* is stored here. */
{
    Tcl_Obj **elemObjs;
    Tcl_Size numElems;

    /* Empty string => empty list. Avoid unnecessary shimmering */
    if (listObj->bytes == &tclEmptyString) {
	*objPtrPtr = NULL;
	return TCL_OK;
    }

    int hasAbstractList = TclObjTypeHasProc(listObj,indexProc) != 0;
    if (hasAbstractList) {
	return TclObjTypeIndex(interp, listObj, index, objPtrPtr);
    }

    if (TclListObjGetElements(interp, listObj, &numElems, &elemObjs) != TCL_OK) {
	return TCL_ERROR;
    }
    if ((index < 0) || (index >= numElems)) {
	*objPtrPtr = NULL;
    } else {
	*objPtrPtr = elemObjs[index];
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjLength --
 *
 *	This function returns the number of elements in a list object. If the
 *	object is not already a list object, an attempt will be made to
 *	convert it to one.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *lenPtr will be set
 *	to the integer count of list elements. If listPtr does not refer to a
 *	list object and the object can not be converted to one, TCL_ERROR is
 *	returned and an error message will be left in the interpreter's result
 *	if interp is not NULL.
 *
 * Side effects:
 *	The possible conversion of the argument object to a list object.
 *
 *----------------------------------------------------------------------
 */

#undef Tcl_ListObjLength
int
Tcl_ListObjLength(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *listObj,		/* List object whose #elements to return. */
    Tcl_Size *lenPtr)		/* The resulting length is stored here. */
{
    ListRep listRep;

    /* Empty string => empty list. Avoid unnecessary shimmering */
    if (listObj->bytes == &tclEmptyString) {
	*lenPtr = 0;
	return TCL_OK;
    }

    if (TclObjTypeHasProc(listObj, lengthProc)) {
	*lenPtr = TclObjTypeLength(listObj);
	return TCL_OK;
    }

    if (TclListObjGetRep(interp, listObj, &listRep) != TCL_OK) {
	return TCL_ERROR;
    }
    *lenPtr = ListRepLength(&listRep);
    return TCL_OK;
}

static Tcl_Size
ListLength(
    Tcl_Obj *listPtr)
{
    ListRep listRep;
    ListObjGetRep(listPtr, &listRep);

    return ListRepLength(&listRep);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ListObjReplace --
 *
 *	This function replaces zero or more elements of the list referenced by
 *	listObj with the objects from an (objc,objv) array. The objc elements
 *	of the array referenced by objv replace the count elements in listPtr
 *	starting at first.
 *
 *	If the argument first is zero or negative, it refers to the first
 *	element. If first is greater than or equal to the number of elements
 *	in the list, then no elements are deleted; the new elements are
 *	appended to the list. Count gives the number of elements to replace.
 *	If count is zero or negative then no elements are deleted; the new
 *	elements are simply inserted before first.
 *
 *	The argument objv refers to an array of objc pointers to the new
 *	elements to be added to listPtr in place of those that were deleted.
 *	If objv is NULL, no new elements are added. If listPtr is not a list
 *	object, an attempt will be made to convert it to one.
 *
 * Results:
 *	The return value is normally TCL_OK. If listPtr does not refer to a
 *	list object and can not be converted to one, TCL_ERROR is returned and
 *	an error message will be left in the interpreter's result if interp is
 *	not NULL.
 *
 * Side effects:
 *	The ref counts of the objc elements in objv are incremented since the
 *	resulting list now refers to them. Similarly, the ref counts for
 *	replaced objects are decremented. listObj is converted, if necessary,
 *	to a list object. listObj's old string representation, if any, is
 *	freed.
 *
 *----------------------------------------------------------------------
 */
int
Tcl_ListObjReplace(
    Tcl_Interp *interp,		/* Used for error reporting if not NULL. */
    Tcl_Obj *listObj,		/* List object whose elements to replace. */
    Tcl_Size first,		/* Index of first element to replace. */
    Tcl_Size numToDelete,	/* Number of elements to replace. */
    Tcl_Size numToInsert,	/* Number of objects to insert. */
    Tcl_Obj *const insertObjs[])/* Tcl objects to insert */
{
    ListRep listRep;
    Tcl_Size origListLen;
    Tcl_Size lenChange;
    Tcl_Size leadSegmentLen;
    Tcl_Size tailSegmentLen;
    Tcl_Size numFreeSlots;
    Tcl_Size leadShift;
    Tcl_Size tailShift;
    Tcl_Obj **listObjs;
    int favor;

    if (Tcl_IsShared(listObj)) {
	Tcl_Panic("%s called with shared object", "Tcl_ListObjReplace");
    }

    if (TclObjTypeHasProc(listObj, replaceProc)) {
	return TclObjTypeReplace(interp, listObj, first,
		numToDelete, numToInsert, insertObjs);
    }

    if (TclListObjGetRep(interp, listObj, &listRep) != TCL_OK) {
	/* Cannot be converted to a list */
	return TCL_ERROR;
    }

    /* Make limits sane */
    origListLen = ListRepLength(&listRep);
    if (first < 0) {
	first = 0;
    }
    if (first > origListLen) {
	first = origListLen;	/* So we'll insert after last element. */
    }
    if (numToDelete < 0) {
	numToDelete = 0;
    } else if (first > LIST_MAX - numToDelete /* Handle integer overflow */
	    || origListLen < first + numToDelete) {
	numToDelete = origListLen - first;
    }

    if (numToInsert > LIST_MAX - (origListLen - numToDelete)) {
	return TclListLimitExceededError(interp);
    }

    if ((first+numToDelete) >= origListLen) {
	/* Operating at back of list. Favor leaving space at back */
	favor = LISTREP_SPACE_FAVOR_BACK;
    } else if (first == 0) {
	/* Operating on front of list. Favor leaving space in front */
	favor = LISTREP_SPACE_FAVOR_FRONT;
    } else {
	/* Operating on middle of list. */
	favor = LISTREP_SPACE_FAVOR_NONE;
    }

    /*
     * There are a number of special cases to consider from an optimization
     * point of view.
     * (1) Pure deletes (numToInsert==0) from the front or back can be treated
     * as a range op irrespective of whether the ListStore is shared or not
     * (2) Pure inserts (numToDelete == 0)
     *   (2a) Pure inserts at the back can be treated as appends
     *   (2b) Pure inserts from the *front* can be optimized under certain
     *   conditions by inserting before first ListStore slot in use if there
     *   is room, again irrespective of sharing
     * (3) If the ListStore is shared OR there is insufficient free space
     * OR existing allocation is too large compared to new size, create
     * a new ListStore
     * (4) Unshared ListStore with sufficient free space. Delete, shift and
     * insert within the ListStore.
     */

    /* Note: do not do TclInvalidateStringRep as yet in case there are errors */

    /* Check Case (1) - Treat pure deletes from front or back as range ops */
    if (numToInsert == 0) {
	if (numToDelete == 0) {
	    /*
	     * Should force canonical even for no-op. Remember Tcl_Obj unshared
	     * so OK to invalidate string rep
	     */
	    /* T:listrep-1.10,2.8 */
	    TclInvalidateStringRep(listObj);
	    return TCL_OK;
	}
	if (first == 0) {
	    /* Delete from front, so return tail. */
	    /* T:listrep-1.{4,5},2.{4,5},3.{15,16},4.7 */
	    ListRep tailRep;
	    ListRepRange(&listRep, numToDelete, origListLen-1, 0, &tailRep);
	    ListObjReplaceRepAndInvalidate(listObj, &tailRep);
	    return TCL_OK;
	} else if ((first+numToDelete) >= origListLen) {
	    /* Delete from tail, so return head */
	    /* T:listrep-1.{8,9},2.{6,7},3.{17,18},4.8 */
	    ListRep headRep;
	    ListRepRange(&listRep, 0, first-1, 0, &headRep);
	    ListObjReplaceRepAndInvalidate(listObj, &headRep);
	    return TCL_OK;
	}
	/* Deletion from middle. Fall through to general case */
    }

    /* Garbage collect before checking the pure insert optimization */
    ListRepFreeUnreferenced(&listRep);

    /*
     * Check Case (2) - pure inserts under certain conditions:
     */
    if (numToDelete == 0) {
	/* Case (2a) - Append to list. */
	if (first == origListLen) {
	    /* T:listrep-1.11,2.9,3.{5,6},2.2.1 */
	    return TclListObjAppendElements(
		interp, listObj, numToInsert, insertObjs);
	}

	/*
	 * Case (2b) - pure inserts at front under some circumstances
	 * (i) Insertion must be at head of list
	 * (ii) The list's span must be at head of the in-use slots in the store
	 * (iii) There must be unused room at front of the store
	 * NOTE THIS IS TRUE EVEN IF THE ListStore IS SHARED as it will not
	 * affect the other Tcl_Obj's referencing this ListStore.
	 */
	if (first == 0 &&						 /* (i) */
		ListRepStart(&listRep) == listRep.storePtr->firstUsed && /* (ii) */
		numToInsert <= listRep.storePtr->firstUsed) {		 /* (iii) */
	    Tcl_Size newLen;
	    LIST_ASSERT(numToInsert); /* Else would have returned above */
	    listRep.storePtr->firstUsed -= numToInsert;
	    ObjArrayCopy(&listRep.storePtr->slots[listRep.storePtr->firstUsed],
		    numToInsert, insertObjs);
	    listRep.storePtr->numUsed += numToInsert;
	    newLen = listRep.spanPtr->spanLength + numToInsert;
	    if (listRep.spanPtr && listRep.spanPtr->refCount <= 1) {
		/* An unshared span record, re-use it */
		/* T:listrep-3.1 */
		listRep.spanPtr->spanStart = listRep.storePtr->firstUsed;
		listRep.spanPtr->spanLength = newLen;
	    } else {
		/* Need a new span record */
		if (listRep.storePtr->firstUsed == 0) {
		    listRep.spanPtr = NULL;
		} else {
		    /* T:listrep-4.3 */
		    listRep.spanPtr =
			ListSpanNew(listRep.storePtr->firstUsed, newLen);
		}
	    }
	    ListObjReplaceRepAndInvalidate(listObj, &listRep);
	    return TCL_OK;
	}
    }

    /* Just for readability of the code */
    lenChange = numToInsert - numToDelete;
    leadSegmentLen = first;
    tailSegmentLen = origListLen - (first + numToDelete);
    numFreeSlots = listRep.storePtr->numAllocated - listRep.storePtr->numUsed;

    /*
     * Before further processing, if unshared, try and reallocate to avoid
     * new allocation below. This avoids expensive ref count manipulation
     * later by not having to go through the ListRepInit and
     * ListObjReplaceAndInvalidate below.
     * TODO - we could be smarter about the reallocate. Use of realloc
     * means all new free space is at the back. Instead, the realloc could
     * be an explicit alloc and memmove which would let us redistribute
     * free space.
     */
    if (numFreeSlots < lenChange && !ListRepIsShared(&listRep)) {
	/* T:listrep-1.{1,3,14,18,21},3.{3,10,11,14,27,32,41} */
	ListStore *newStorePtr =
	    ListStoreReallocate(listRep.storePtr, origListLen + lenChange);
	if (newStorePtr == NULL) {
	    return MemoryAllocationError(interp,
		    LIST_SIZE(origListLen + lenChange));
	}
	listRep.storePtr = newStorePtr;
	numFreeSlots =
	    listRep.storePtr->numAllocated - listRep.storePtr->numUsed;
	/*
	 * WARNING: at this point the Tcl_Obj internal rep potentially
	 * points to freed storage if the reallocation returned a
	 * different location. Overwrite it to bring it back in sync.
	 */
	ListObjStompRep(listObj, &listRep);
    }

    /*
     * Case (3) a new ListStore is required
     * (a) The passed-in ListStore is shared
     * (b) There is not enough free space in the unshared passed-in ListStore
     * (c) The new unshared size is much "smaller" (TODO) than the allocated space
     * TODO - for unshared case ONLY, consider a "move" based implementation
     */
    if (ListRepIsShared(&listRep) ||				/* 3a */
	    numFreeSlots < lenChange ||				/* 3b */
	    (origListLen + lenChange) <
		    (listRep.storePtr->numAllocated / 4)) {	/* 3c */
	ListRep newRep;
	Tcl_Obj **toObjs;
	listObjs = &listRep.storePtr->slots[ListRepStart(&listRep)];
	ListRepInit(origListLen + lenChange, NULL,
		LISTREP_PANIC_ON_FAIL | favor, &newRep);
	toObjs = ListRepSlotPtr(&newRep, 0);
	if (leadSegmentLen > 0) {
	    /* T:listrep-2.{2,3,13:18},4.{6,9,13:18} */
	    ObjArrayCopy(toObjs, leadSegmentLen, listObjs);
	}
	if (numToInsert > 0) {
	    /* T:listrep-2.{1,2,3,10:18},4.{1,2,4,6,10:18} */
	    ObjArrayCopy(&toObjs[leadSegmentLen], numToInsert,
		    insertObjs);
	}
	if (tailSegmentLen > 0) {
	    /* T:listrep-2.{1,2,3,10:15},4.{1,2,4,6,9:12,16:18} */
	    ObjArrayCopy(&toObjs[leadSegmentLen + numToInsert],
		    tailSegmentLen, &listObjs[leadSegmentLen+numToDelete]);
	}
	newRep.storePtr->numUsed = origListLen + lenChange;
	if (newRep.spanPtr) {
	    /* T:listrep-2.{1,2,3,10:18},4.{1,2,4,6,9:18} */
	    newRep.spanPtr->spanLength = newRep.storePtr->numUsed;
	}
	LISTREP_CHECK(&newRep);
	ListObjReplaceRepAndInvalidate(listObj, &newRep);
	return TCL_OK;
    }

    /*
     * Case (4) - unshared ListStore with sufficient room.
     * After deleting elements, there will be a corresponding gap. If this
     * gap does not match number of insertions, either the lead segment,
     * or the tail segment, or both will have to be moved.
     * The general strategy is to move the fewest number of elements. If
     *
     * TODO - what about appends to unshared ? Is below sufficiently optimal?
     */

    /* Following must hold for unshared listreps after ListRepFreeUnreferenced above */
    LIST_ASSERT(origListLen == listRep.storePtr->numUsed);
    LIST_ASSERT(origListLen == ListRepLength(&listRep));
    LIST_ASSERT(ListRepStart(&listRep) == listRep.storePtr->firstUsed);

    LIST_ASSERT((numToDelete + numToInsert) > 0);

    /* Base of slot array holding the list elements */
    listObjs = &listRep.storePtr->slots[ListRepStart(&listRep)];

    /*
     * Free up elements to be deleted. Before that, increment the ref counts
     * for objects to be inserted in case there is overlap. T:listobj-11.1
     */
    if (numToInsert) {
	/* T:listrep-1.{1,3,12:21},3.{2,3,7:14,23:41} */
	ObjArrayIncrRefs(insertObjs, 0, numToInsert);
    }
    if (numToDelete) {
	/* T:listrep-1.{6,7,12:21},3.{19:41} */
	ObjArrayDecrRefs(listObjs, first, numToDelete);
    }

    /*
     * TODO - below the moves are optimized but this may result in needing a
     * span allocation. Perhaps for small lists, it may be more efficient to
     * just move everything up front and save on allocating a span.
     */

    /*
     * Calculate shifts if necessary to accommodate insertions.
     * NOTE: all indices are relative to listObjs which is not necessarily the
     * start of the ListStore storage area.
     *
     * leadShift - how much to shift the lead segment
     * tailShift - how much to shift the tail segment
     * insertTarget - index where to insert.
     */

    if (lenChange == 0) {
	/* T:listrep-1.{12,15,19},3.{23,28,33}. Exact fit */
	leadShift = 0;
	tailShift = 0;
    } else if (lenChange < 0) {
	/*
	 * More deletions than insertions. The gap after deletions is large
	 * enough for insertions. Move a segment depending on size.
	 */
	if (leadSegmentLen > tailSegmentLen) {
	    /* Tail segment smaller. Insert after lead, move tail down */
	    /* T:listrep-1.{7,17,20},3.{21,2229,35} */
	    leadShift = 0;
	    tailShift = lenChange;
	} else {
	    /* Lead segment smaller. Insert before tail, move lead up */
	    /* T:listrep-1.{6,13,16},3.{19,20,24,34} */
	    leadShift = -lenChange;
	    tailShift = 0;
	}
    } else {
	LIST_ASSERT(lenChange > 0); /* Reminder */

	/*
	 * We need to make room for the insertions. Again we have multiple
	 * possibilities. We may be able to get by just shifting one segment
	 * or need to shift both. In the former case, favor shifting the
	 * smaller segment.
	 */
	Tcl_Size leadSpace = ListRepNumFreeHead(&listRep);
	Tcl_Size tailSpace = ListRepNumFreeTail(&listRep);
	Tcl_Size finalFreeSpace = leadSpace + tailSpace - lenChange;

	LIST_ASSERT((leadSpace + tailSpace) >= lenChange);
	if (leadSpace >= lenChange
		&& (leadSegmentLen < tailSegmentLen || tailSpace < lenChange)) {
	    /* Move only lead to the front to make more room */
	    /* T:listrep-3.25,36,38, */
	    leadShift = -lenChange;
	    tailShift = 0;
	    /*
	     * Redistribute the remaining free space between the front and
	     * back if either there is no tail space left or if the
	     * entire list is the head anyways. This is an important
	     * optimization for further operations like further asymmetric
	     * insertions.
	     */
	    if (finalFreeSpace > 1 && (tailSpace == 0 || tailSegmentLen == 0)) {
		Tcl_Size postShiftLeadSpace = leadSpace - lenChange;
		if (postShiftLeadSpace > (finalFreeSpace/2)) {
		    Tcl_Size extraShift = postShiftLeadSpace - (finalFreeSpace / 2);
		    leadShift -= extraShift;
		    tailShift = -extraShift; /* Move tail to the front as well */
		}
	    } /* else T:listrep-3.{7,12,25,38} */
	    LIST_ASSERT(leadShift >= 0 || leadSpace >= -leadShift);
	} else if (tailSpace >= lenChange) {
	    /* Move only tail segment to the back to make more room. */
	    /* T:listrep-3.{8,10,11,14,26,27,30,32,37,39,41} */
	    leadShift = 0;
	    tailShift = lenChange;
	    /*
	     * See comments above. This is analogous.
	     */
	    if (finalFreeSpace > 1 && (leadSpace == 0 || leadSegmentLen == 0)) {
		Tcl_Size postShiftTailSpace = tailSpace - lenChange;
		if (postShiftTailSpace > (finalFreeSpace/2)) {
		    /* T:listrep-1.{1,3,14,18,21},3.{2,3,26,27} */
		    Tcl_Size extraShift = postShiftTailSpace - (finalFreeSpace / 2);
		    tailShift += extraShift;
		    leadShift = extraShift; /* Move head to the back as well */
		}
	    }
	    LIST_ASSERT(tailShift <= tailSpace);
	} else {
	    /*
	     * Both lead and tail need to be shifted to make room.
	     * Divide remaining free space equally between front and back.
	     */
	    /* T:listrep-3.{9,13,31,40} */
	    LIST_ASSERT(leadSpace < lenChange);
	    LIST_ASSERT(tailSpace < lenChange);

	    /*
	     * leadShift = leadSpace - (finalFreeSpace/2)
	     * Thus leadShift <= leadSpace
	     * Also,
	     * = leadSpace - (leadSpace + tailSpace - lenChange)/2
	     * = leadSpace/2 - tailSpace/2 + lenChange/2
	     * >= 0 because lenChange > tailSpace
	     */
	    leadShift = leadSpace - (finalFreeSpace / 2);
	    tailShift = lenChange - leadShift;
	    if (tailShift > tailSpace) {
		/* Account for integer division errors */
		leadShift += 1;
		tailShift -= 1;
	    }
	    /*
	     * Following must be true because otherwise one of the previous
	     * if clauses would have been taken.
	     */
	    LIST_ASSERT(leadShift > 0 && leadShift < lenChange);
	    LIST_ASSERT(tailShift > 0 && tailShift < lenChange);
	    leadShift = -leadShift; /* Lead is actually shifted downward */
	}
    }

    /* Careful about order of moves! */
    if (leadShift > 0) {
	/* Will happen when we have to make room at bottom */
	if (tailShift != 0 && tailSegmentLen != 0) {
	    /* T:listrep-1.{1,3,14,18},3.{2,3,26,27} */
	    Tcl_Size tailStart = leadSegmentLen + numToDelete;
	    memmove(&listObjs[tailStart + tailShift],
		    &listObjs[tailStart],
		    tailSegmentLen * sizeof(Tcl_Obj *));
	}
	if (leadSegmentLen != 0) {
	    /* T:listrep-1.{3,6,16,18,21},3.{19,20,34} */
	    memmove(&listObjs[leadShift],
		    &listObjs[0],
		    leadSegmentLen * sizeof(Tcl_Obj *));
	}
    } else {
	if (leadShift != 0 && leadSegmentLen != 0) {
	    /* T:listrep-3.{7,9,12,13,31,36,38,40} */
	    memmove(&listObjs[leadShift],
		    &listObjs[0],
		    leadSegmentLen * sizeof(Tcl_Obj *));
	}
	if (tailShift != 0 && tailSegmentLen != 0) {
	    /* T:listrep-1.{7,17},3.{8:11,13,14,21,22,35,37,39:41} */
	    Tcl_Size tailStart = leadSegmentLen + numToDelete;
	    memmove(&listObjs[tailStart + tailShift],
		    &listObjs[tailStart],
		    tailSegmentLen * sizeof(Tcl_Obj *));
	}
    }
    if (numToInsert) {
	/* Do NOT use ObjArrayCopy here since we have already incr'ed ref counts */
	/* T:listrep-1.{1,3,12:21},3.{2,3,7:14,23:41} */
	memmove(&listObjs[leadSegmentLen + leadShift],
		insertObjs,
		numToInsert * sizeof(Tcl_Obj *));
    }

    listRep.storePtr->firstUsed += leadShift;
    listRep.storePtr->numUsed = origListLen + lenChange;
    listRep.storePtr->flags = 0;

    if (listRep.spanPtr && listRep.spanPtr->refCount <= 1) {
	/* An unshared span record, re-use it, even if not required */
	/* T:listrep-3.{2,3,7:14},3.{19:41} */
	listRep.spanPtr->spanStart = listRep.storePtr->firstUsed;
	listRep.spanPtr->spanLength = listRep.storePtr->numUsed;
    } else {
	/* Need a new span record */
	if (listRep.storePtr->firstUsed == 0) {
	    /* T:listrep-1.{7,12,15,17,19,20} */
	    listRep.spanPtr = NULL;
	} else {
	    /* T:listrep-1.{1,3,6.1,13,14,16,18,21} */
	    listRep.spanPtr = ListSpanNew(listRep.storePtr->firstUsed,
		    listRep.storePtr->numUsed);
	}
    }

    LISTREP_CHECK(&listRep);
    ListObjReplaceRepAndInvalidate(listObj, &listRep);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclLindexList --
 *
 *	This procedure handles the 'lindex' command when objc==3.
 *
 * Results:
 *	Returns a pointer to the object extracted, or NULL if an error
 *	occurred. The returned object already includes one reference count for
 *	the pointer returned.
 *
 * Side effects:
 *	None.
 *
 * Notes:
 *	This procedure is implemented entirely as a wrapper around
 *	TclLindexFlat. All it does is reconfigure the argument format into the
 *	form required by TclLindexFlat, while taking care to manage shimmering
 *	in such a way that we tend to keep the most useful internalreps and/or
 *	avoid the most expensive conversions.
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclLindexList(
    Tcl_Interp *interp,		/* Tcl interpreter. */
    Tcl_Obj *listObj,		/* List being unpacked. */
    Tcl_Obj *argObj)		/* Index or index list. */
{
    Tcl_Size index;		/* Index into the list. */
    Tcl_Obj *indexListCopy;
    Tcl_Obj **indexObjs;
    Tcl_Size numIndexObjs;

    /*
     * Determine whether argPtr designates a list or a single index. We have
     * to be careful about the order of the checks to avoid repeated
     * shimmering; if internal rep is already a list do not shimmer it.
     * see TIP#22 and TIP#33 for the details.
     */
    if (!TclHasInternalRep(argObj, &tclListType)
	    && TclGetIntForIndexM(NULL, argObj, TCL_SIZE_MAX - 1,
		    &index) == TCL_OK) {
	/*
	 * argPtr designates a single index.
	 */
	return TclLindexFlat(interp, listObj, 1, &argObj);
    }

    /*
     * Here we make a private copy of the index list argument to avoid any
     * shimmering issues that might invalidate the indices array below while
     * we are still using it. This is probably unnecessary. It does not appear
     * that any damaging shimmering is possible, and no test has been devised
     * to show any error when this private copy is not made. But it's cheap,
     * and it offers some future-proofing insurance in case the TclLindexFlat
     * implementation changes in some unexpected way, or some new form of
     * trace or callback permits things to happen that the current
     * implementation does not.
     */

    indexListCopy = TclListObjCopy(NULL, argObj);
    if (indexListCopy == NULL) {
	/*
	 * The argument is neither an index nor a well-formed list.
	 * Report the error via TclLindexFlat.
	 * TODO - This is as original code. why not directly return an error?
	 */
	return TclLindexFlat(interp, listObj, 1, &argObj);
    }
    TclListObjGetElements(interp, indexListCopy, &numIndexObjs, &indexObjs);
    listObj = TclLindexFlat(interp, listObj, numIndexObjs, indexObjs);
    Tcl_DecrRefCount(indexListCopy);
    return listObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclLindexFlat --
 *
 *	This procedure is the core of the 'lindex' command, with all index
 *	arguments presented as a flat list.
 *
 * Results:
 *	Returns a pointer to the object extracted, or NULL if an error
 *	occurred. The returned object already includes one reference count for
 *	the pointer returned.
 *
 * Side effects:
 *	None.
 *
 * Notes:
 *	The reference count of the returned object includes one reference
 *	corresponding to the pointer returned. Thus, the calling code will
 *	usually do something like:
 *		Tcl_SetObjResult(interp, result);
 *		Tcl_DecrRefCount(result);
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclLindexFlat(
    Tcl_Interp *interp,		/* Tcl interpreter. */
    Tcl_Obj *listObj,		/* Tcl object representing the list. */
    Tcl_Size indexCount,	/* Count of indices. */
    Tcl_Obj *const indexArray[])/* Array of pointers to Tcl objects that
				 * represent the indices in the list. */
{
    int status;
    Tcl_Size i;

    /* Handle AbstractList as special case */
    if (indexCount == 1 && TclObjTypeHasProc(listObj,indexProc)) {
	Tcl_Size listLen = TclObjTypeLength(listObj);
	Tcl_Size index;
	Tcl_Obj *elemObj = listObj; /* for lindex without indices return list */
	for (i=0 ; i<indexCount && listObj ; i++) {
	    if (TclGetIntForIndexM(interp, indexArray[i], /*endValue*/ listLen-1,
		    &index) != TCL_OK) {
		return NULL;
	    }
	    if (i==0) {
		if (TclObjTypeIndex(interp, listObj, index, &elemObj) != TCL_OK) {
		    return NULL;
		}
	    } else if (index > 0) {
		// TODO: support nested lists
		Tcl_Obj *e2Obj = TclLindexFlat(interp, elemObj, 1, &indexArray[i]);
		Tcl_DecrRefCount(elemObj);
		elemObj = e2Obj;
	    }
	}
	if (elemObj == NULL) {
	    /*
	     * TclObjTypeIndex returns TCL_OK with NULL in elemObj if
	     * index was out of bounds.
	     */
	    TclNewObj(elemObj);
	}
	Tcl_IncrRefCount(elemObj);
	return elemObj;
    }

    Tcl_IncrRefCount(listObj);

    for (i=0 ; i<indexCount && listObj ; i++) {
	Tcl_Size index, listLen = 0;
	Tcl_Obj **elemPtrs = NULL;

	status = Tcl_ListObjLength(interp, listObj, &listLen);
	if (status != TCL_OK) {
	    Tcl_DecrRefCount(listObj);
	    return NULL;
	}

	if (TclGetIntForIndexM(interp, indexArray[i], /*endValue*/ listLen-1,
		&index) == TCL_OK) {
	    if (index < 0 || index >= listLen) {
		/*
		 * Index is out of range. Break out of loop with empty result.
		 * First check remaining indices for validity
		 */

		while (++i < indexCount) {
		    if (TclGetIntForIndexM(interp, indexArray[i],
			    TCL_SIZE_MAX - 1, &index) != TCL_OK) {
			Tcl_DecrRefCount(listObj);
			return NULL;
		    }
		}
		Tcl_DecrRefCount(listObj);
		TclNewObj(listObj);
		Tcl_IncrRefCount(listObj);
	    } else {
		Tcl_Obj *itemObj;
		/* TODO - this will cause shimmering of inner abstract lists! */
		/*
		 * Must set the internal rep again because it may have been
		 * changed by TclGetIntForIndexM. See test lindex-8.4.
		 */
		if (!TclHasInternalRep(listObj, &tclListType)) {
		    status = SetListFromAny(interp, listObj);
		    if (status != TCL_OK) {
			/* The list is not a list at all => error. */
			Tcl_DecrRefCount(listObj);
			return NULL;
		    }
		}

		ListObjGetElements(listObj, listLen, elemPtrs);
		/* increment this reference count first before decrementing
		 * just in case they are the same Tcl_Obj
		 */
		itemObj = elemPtrs[index];
		Tcl_IncrRefCount(itemObj);
		Tcl_DecrRefCount(listObj);
		/* Extract the pointer to the appropriate element. */
		listObj = itemObj;
	    }
	} else {
	    Tcl_DecrRefCount(listObj);
	    listObj = NULL;
	}
    }
    return listObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclLsetList --
 *
 *	Core of the 'lset' command when objc == 4. Objv[2] may be either a
 *	scalar index or a list of indices.
 *      It also handles 'lpop' when given a NULL value.
 *
 * Results:
 *	Returns the new value of the list variable, or NULL if there was an
 *	error. The returned object includes one reference count for the
 *	pointer returned.
 *
 * Side effects:
 *	None.
 *
 * Notes:
 *	This procedure is implemented entirely as a wrapper around
 *	TclLsetFlat. All it does is reconfigure the argument format into the
 *	form required by TclLsetFlat, while taking care to manage shimmering
 *	in such a way that we tend to keep the most useful internalreps and/or
 *	avoid the most expensive conversions.
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclLsetList(
    Tcl_Interp *interp,		/* Tcl interpreter. */
    Tcl_Obj *listObj,		/* Pointer to the list being modified. */
    Tcl_Obj *indexArgObj,	/* Index or index-list arg to 'lset'. */
    Tcl_Obj *valueObj)		/* Value arg to 'lset' or NULL to 'lpop'. */
{
    Tcl_Size indexCount = 0;	/* Number of indices in the index list. */
    Tcl_Obj **indices = NULL;	/* Vector of indices in the index list. */
    Tcl_Obj *retValueObj;	/* Pointer to the list to be returned. */
    Tcl_Size index;		/* Current index in the list - discarded. */
    Tcl_Obj *indexListCopy;

    /*
     * Determine whether the index arg designates a list or a single index.
     * We have to be careful about the order of the checks to avoid repeated
     * shimmering; see TIP #22 and #23 for details.
     */

    if (!TclHasInternalRep(indexArgObj, &tclListType)
	    && TclGetIntForIndexM(NULL, indexArgObj, TCL_SIZE_MAX - 1, &index)
		== TCL_OK) {
	if (TclObjTypeHasProc(listObj, setElementProc)) {
	    indices = &indexArgObj;
	    retValueObj = TclObjTypeSetElement(
		    interp, listObj, 1, indices, valueObj);
	    if (retValueObj) {
		Tcl_IncrRefCount(retValueObj);
	    }
	} else {
	    /* indexArgPtr designates a single index. */
	    /* T:listrep-1.{2.1,12.1,15.1,19.1},2.{2.3,9.3,10.1,13.1,16.1}, 3.{4,5,6}.3 */
	    retValueObj = TclLsetFlat(interp, listObj, 1, &indexArgObj, valueObj);
	}

    } else {

	indexListCopy = TclListObjCopy(NULL,indexArgObj);
	if (!indexListCopy) {
	    /*
	     * indexArgPtr designates something that is neither an index nor a
	     * well formed list. Report the error via TclLsetFlat.
	     */
	    retValueObj = TclLsetFlat(interp, listObj, 1, &indexArgObj, valueObj);
	} else {
	    if (TCL_OK != TclListObjGetElements(
		    interp, indexListCopy, &indexCount, &indices)) {
		Tcl_DecrRefCount(indexListCopy);
		/*
		 * indexArgPtr designates something that is neither an index nor a
		 * well formed list. Report the error via TclLsetFlat.
		 */
		retValueObj = TclLsetFlat(interp, listObj, 1, &indexArgObj, valueObj);
	    } else {

		/*
		 * Let TclLsetFlat perform the actual lset operation.
		 */

		retValueObj = TclLsetFlat(interp, listObj, indexCount, indices, valueObj);
		if (indexListCopy) {
		    Tcl_DecrRefCount(indexListCopy);
		}
	    }
	}
    }
    assert (retValueObj==NULL || retValueObj->typePtr || retValueObj->bytes);
    return retValueObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclLsetFlat --
 *
 *	Core engine of the 'lset' command.
 *      It also handles 'lpop' when given a NULL value.
 *
 * Results:
 *	Returns the new value of the list variable, or NULL if an error
 *	occurred. The returned object includes one reference count for the
 *	pointer returned.
 *
 * Side effects:
 *	On entry, the reference count of the variable value does not reflect
 *	any references held on the stack. The first action of this function is
 *	to determine whether the object is shared, and to duplicate it if it
 *	is. The reference count of the duplicate is incremented. At this
 *	point, the reference count will be 1 for either case, so that the
 *	object will appear to be unshared.
 *
 *	If an error occurs, and the object has been duplicated, the reference
 *	count on the duplicate is decremented so that it is now 0: this
 *	dismisses any memory that was allocated by this function.
 *
 *	If no error occurs, the reference count of the original object is
 *	incremented if the object has not been duplicated, and nothing is done
 *	to a reference count of the duplicate. Now the reference count of an
 *	unduplicated object is 2 (the returned pointer, plus the one stored in
 *	the variable). The reference count of a duplicate object is 1,
 *	reflecting that the returned pointer is the only active reference. The
 *	caller is expected to store the returned value back in the variable
 *	and decrement its reference count. (INST_STORE_* does exactly this.)
 *
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclLsetFlat(
    Tcl_Interp *interp,		/* Tcl interpreter. */
    Tcl_Obj *listObj,		/* Pointer to the list being modified. */
    Tcl_Size indexCount,	/* Number of index args. */
    Tcl_Obj *const indexArray[],
				/* Index args. */
    Tcl_Obj *valueObj)		/* Value arg to 'lset' or NULL to 'lpop'. */
{
    Tcl_Size index, len;
    int result;
    Tcl_Obj *subListObj, *retValueObj;
    Tcl_Obj *pendingInvalidates[10];
    Tcl_Obj **pendingInvalidatesPtr = pendingInvalidates;
    Tcl_Size numPendingInvalidates = 0;

    /*
     * If there are no indices, simply return the new value.  (Without
     * indices, [lset] is a synonym for [set].
     * [lpop] does not use this but protect for NULL valueObj just in case.
     */

    if (indexCount == 0) {
	if (valueObj != NULL) {
	    Tcl_IncrRefCount(valueObj);
	}
	return valueObj;
    }

    /*
     * If the list is shared, make a copy we can modify (copy-on-write).  We
     * use Tcl_DuplicateObj() instead of TclListObjCopy() for a few reasons:
     * 1) we have not yet confirmed listObj is actually a list; 2) We make a
     * verbatim copy of any existing string rep, and when we combine that with
     * the delayed invalidation of string reps of modified Tcl_Obj's
     * implemented below, the outcome is that any error condition that causes
     * this routine to return NULL, will leave the string rep of listObj and
     * all elements to be unchanged.
     */

    subListObj = Tcl_IsShared(listObj) ? Tcl_DuplicateObj(listObj) : listObj;

    /*
     * Anchor the linked list of Tcl_Obj's whose string reps must be
     * invalidated if the operation succeeds.
     */

    retValueObj = subListObj;
    result = TCL_OK;

    /* Allocate if static array for pending invalidations is too small */
    if (indexCount > (Tcl_Size) (sizeof(pendingInvalidates) /
	    sizeof(pendingInvalidates[0]))) {
	pendingInvalidatesPtr =
	    (Tcl_Obj **) Tcl_Alloc(indexCount * sizeof(*pendingInvalidatesPtr));
    }

    /*
     * Loop through all the index arguments, and for each one dive into the
     * appropriate sublist.
     */

    do {
	Tcl_Size elemCount;
	Tcl_Obj *parentList, **elemPtrs;

	/*
	 * Check for the possible error conditions...
	 */

	if (TclListObjGetElements(interp, subListObj,
		&elemCount, &elemPtrs) != TCL_OK) {
	    /* ...the sublist we're indexing into isn't a list at all. */
	    result = TCL_ERROR;
	    break;
	}

	/*
	 * WARNING: the macro TclGetIntForIndexM is not safe for
	 * post-increments, avoid '*indexArray++' here.
	 */

	if (TclGetIntForIndexM(interp, *indexArray, elemCount - 1,
		&index) != TCL_OK) {
	    /* ...the index we're trying to use isn't an index at all. */
	    result = TCL_ERROR;
	    indexArray++; /* Why bother with this increment? TBD */
	    break;
	}
	indexArray++;

	/*
	 * Special case 0-length lists. The Tcl indexing function treat
	 * will return any value beyond length as TCL_SIZE_MAX for this
	 * case.
	 */
	if ((index == TCL_SIZE_MAX) && (elemCount == 0)) {
	    index = 0;
	}
	if (index < 0 || index > elemCount
		|| (valueObj == NULL && index >= elemCount)) {
	    /* ...the index points outside the sublist. */
	    if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"index \"%s\" out of range", TclGetString(indexArray[-1])));
		Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
	    }
	    result = TCL_ERROR;
	    break;
	}

	/*
	 * No error conditions.  As long as we're not yet on the last index,
	 * determine the next sublist for the next pass through the loop,
	 * and take steps to make sure it is an unshared copy, as we intend
	 * to modify it.
	 */

	if (--indexCount) {
	    parentList = subListObj;
	    if (index == elemCount) {
		TclNewObj(subListObj);
	    } else {
		subListObj = elemPtrs[index];
	    }
	    if (Tcl_IsShared(subListObj)) {
		subListObj = Tcl_DuplicateObj(subListObj);
	    }

	    /*
	     * Replace the original elemPtr[index] in parentList with a copy
	     * we know to be unshared.  This call will also deal with the
	     * situation where parentList shares its internalrep with other
	     * Tcl_Obj's.  Dealing with the shared internalrep case can
	     * cause subListObj to become shared again, so detect that case
	     * and make and store another copy.
	     */

	    if (index == elemCount) {
		Tcl_ListObjAppendElement(NULL, parentList, subListObj);
	    } else {
		TclListObjSetElement(NULL, parentList, index, subListObj);
	    }
	    if (Tcl_IsShared(subListObj)) {
		subListObj = Tcl_DuplicateObj(subListObj);
		TclListObjSetElement(NULL, parentList, index, subListObj);
	    }

	    /*
	     * The TclListObjSetElement() calls do not spoil the string rep
	     * of parentList, and that's fine for now, since all we've done
	     * so far is replace a list element with an unshared copy.  The
	     * list value remains the same, so the string rep. is still
	     * valid, and unchanged, which is good because if this whole
	     * routine returns NULL, we'd like to leave no change to the
	     * value of the lset variable.  Later on, when we set valueObj
	     * in its proper place, then all containing lists will have
	     * their values changed, and will need their string reps
	     * spoiled.  We maintain a list of all those Tcl_Obj's
	     * pendingInvalidatesPtr[] so we can spoil them at that time.
	     */

	    pendingInvalidatesPtr[numPendingInvalidates] = parentList;
	    ++numPendingInvalidates;
	}
    } while (indexCount > 0);

    /*
     * Either we've detected and error condition, and exited the loop with
     * result == TCL_ERROR, or we've successfully reached the last index, and
     * we're ready to store valueObj. On success, we need to invalidate
     * the string representations of intermediate lists whose contained
     * list element would have changed.
     */
    if (result == TCL_OK) {
	while (numPendingInvalidates > 0) {
	    Tcl_Obj *objPtr;

	    --numPendingInvalidates;
	    objPtr = pendingInvalidatesPtr[numPendingInvalidates];

	    if (result == TCL_OK) {
		/*
		 * We're going to store valueObj, so spoil string reps of all
		 * containing lists.
		 * TODO - historically, the storing of the internal rep was done
		 * because the ptr2 field of the internal rep was used to chain
		 * objects whose string rep needed to be invalidated. Now this
		 * is no longer the case, so replacing of the internal rep
		 * should not be needed. The TclInvalidateStringRep should
		 * suffice. Formulate a test case before changing.
		 */
		ListRep objInternalRep;
		TclListObjGetRep(NULL, objPtr, &objInternalRep);
		ListObjReplaceRepAndInvalidate(objPtr, &objInternalRep);
	    }
	}
    }

    if (pendingInvalidatesPtr != pendingInvalidates) {
	Tcl_Free(pendingInvalidatesPtr);
    }

    if (result != TCL_OK) {
	/*
	 * Error return; message is already in interp. Clean up any excess
	 * memory.
	 */

	if (retValueObj != listObj) {
	    Tcl_DecrRefCount(retValueObj);
	}
	return NULL;
    }

    /*
     * Store valueObj in proper sublist and return. The -1 is to avoid a
     * compiler warning (not a problem because we checked that we have a
     * proper list - or something convertible to one - above).
     */

    len = -1;
    TclListObjLength(NULL, subListObj, &len);
    if (valueObj == NULL) {
	/* T:listrep-1.{4.2,5.4,6.1,7.1,8.3},2.{4,5}.4 */
	Tcl_ListObjReplace(NULL, subListObj, index, 1, 0, NULL);
    } else if (index == len) {
	/* T:listrep-1.2.1,2.{2.3,9.3},3.{4,5,6}.3 */
	Tcl_ListObjAppendElement(NULL, subListObj, valueObj);
    } else {
	/* T:listrep-1.{12.1,15.1,19.1},2.{10,13,16}.1 */
	TclListObjSetElement(NULL, subListObj, index, valueObj);
	TclInvalidateStringRep(subListObj);
    }
    Tcl_IncrRefCount(retValueObj);
    return retValueObj;
}

/*
 *----------------------------------------------------------------------
 *
 * TclListObjSetElement --
 *
 *	Set a single element of a list to a specified value
 *
 * Results:
 *	The return value is normally TCL_OK. If listObj does not refer to a
 *	list object and cannot be converted to one, TCL_ERROR is returned and
 *	an error message will be left in the interpreter result if interp is
 *	not NULL. Similarly, if index designates an element outside the range
 *	[0..listLength-1], where listLength is the count of elements in the
 *	list object designated by listObj, TCL_ERROR is returned and an error
 *	message is left in the interpreter result.
 *
 * Side effects:
 *	Tcl_Panic if listObj designates a shared object. Otherwise, attempts
 *	to convert it to a list with a non-shared internal rep. Decrements the
 *	ref count of the object at the specified index within the list,
 *	replaces with the object designated by valueObj, and increments the
 *	ref count of the replacement object.
 *
 *----------------------------------------------------------------------
 */
int
TclListObjSetElement(
    Tcl_Interp *interp,		/* Tcl interpreter; used for error reporting
				 * if not NULL. */
    Tcl_Obj *listObj,		/* List object in which element should be
				 * stored. */
    Tcl_Size index,		/* Index of element to store. */
    Tcl_Obj *valueObj)		/* Tcl object to store in the designated list
				 * element. */
{
    ListRep listRep;
    Tcl_Obj **elemPtrs;		/* Pointers to elements of the list. */
    Tcl_Size elemCount;		/* Number of elements in the list. */

    /* Ensure that the listObj parameter designates an unshared list. */

    if (Tcl_IsShared(listObj)) {
	Tcl_Panic("%s called with shared object", "TclListObjSetElement");
    }

    if (TclListObjGetRep(interp, listObj, &listRep) != TCL_OK) {
	return TCL_ERROR;
    }

    elemCount = ListRepLength(&listRep);

    /* Ensure that the index is in bounds. */
    if ((index < 0) || (index >= elemCount)) {
	if (interp != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"index \"%" TCL_SIZE_MODIFIER "d\" out of range", index));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "INDEX", "OUTOFRANGE", (char *)NULL);
	}
	return TCL_ERROR;
    }

    /*
     * Note - garbage collect this only AFTER checking indices above.
     * Do not want to modify listrep and then not store it back in listObj.
     */
    ListRepFreeUnreferenced(&listRep);

    /* Replace a shared internal rep with an unshared copy */
    if (listRep.storePtr->refCount > 1) {
	ListRep newInternalRep;
	/* T:listrep-2.{10,13,16}.1 */
	/* TODO - leave extra space? */
	ListRepClone(&listRep, &newInternalRep, LISTREP_PANIC_ON_FAIL);
	listRep = newInternalRep;
    } /* else T:listrep-1.{12.1,15.1,19.1} */

    /* Retrieve element array AFTER potential cloning above */
    ListRepElements(&listRep, elemCount, elemPtrs);

    /*
     * Add a reference to the new list element and remove from old before
     * replacing it. Order is important!
     */
    Tcl_IncrRefCount(valueObj);
    Tcl_DecrRefCount(elemPtrs[index]);
    elemPtrs[index] = valueObj;

    /* Internal rep may be cloned so replace */
    ListObjReplaceRepAndInvalidate(listObj, &listRep);

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeListInternalRep --
 *
 *	Deallocate the storage associated with a list object's internal
 *	representation.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees listPtr's List* internal representation, if no longer shared.
 *	May decrement the ref counts of element objects, which may free them.
 *
 *----------------------------------------------------------------------
 */
static void
FreeListInternalRep(
    Tcl_Obj *listObj)		/* List object with internal rep to free. */
{
    ListRep listRep;

    ListObjGetRep(listObj, &listRep);
    if (listRep.storePtr->refCount-- <= 1) {
	ObjArrayDecrRefs(
	    listRep.storePtr->slots,
	    listRep.storePtr->firstUsed, listRep.storePtr->numUsed);
	Tcl_Free(listRep.storePtr);
    }
    if (listRep.spanPtr) {
	ListSpanDecrRefs(listRep.spanPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * DupListInternalRep --
 *
 *	Initialize the internal representation of a list Tcl_Obj to share the
 *	internal representation of an existing list object.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The reference count of the List internal rep is incremented.
 *
 *----------------------------------------------------------------------
 */
static void
DupListInternalRep(
    Tcl_Obj *srcObj,		/* Object with internal rep to copy. */
    Tcl_Obj *copyObj)		/* Object with internal rep to set. */
{
    ListRep listRep;
    ListObjGetRep(srcObj, &listRep);
    ListObjOverwriteRep(copyObj, &listRep);
}

/*
 *----------------------------------------------------------------------
 *
 * SetListFromAny --
 *
 *	Attempt to generate a list internal form for the Tcl object "objPtr".
 *
 * Results:
 *	The return value is TCL_OK or TCL_ERROR. If an error occurs during
 *	conversion, an error message is left in the interpreter's result
 *	unless "interp" is NULL.
 *
 * Side effects:
 *	If no error occurs, a list is stored as "objPtr"s internal
 *	representation.
 *
 *----------------------------------------------------------------------
 */
static int
SetListFromAny(
    Tcl_Interp *interp,		/* Used for error reporting if not NULL. */
    Tcl_Obj *objPtr)		/* The object to convert. */
{
    Tcl_Obj **elemPtrs;
    ListRep listRep;

    /*
     * Dictionaries are a special case; they have a string representation such
     * that *all* valid dictionaries are valid lists. Hence we can convert
     * more directly. Only do this when there's no existing string rep; if
     * there is, it is the string rep that's authoritative (because it could
     * describe duplicate keys).
     */

    if (!TclHasStringRep(objPtr) && TclHasInternalRep(objPtr, &tclDictType)) {
	Tcl_Obj *keyPtr, *valuePtr;
	Tcl_DictSearch search;
	int done;
	Tcl_Size size;

	/*
	 * Create the new list representation. Note that we do not need to do
	 * anything with the string representation as the transformation (and
	 * the reverse back to a dictionary) are both order-preserving. Also
	 * note that since we know we've got a valid dictionary (by
	 * representation) we also know that fetching the size of the
	 * dictionary or iterating over it will not fail.
	 */

	Tcl_DictObjSize(NULL, objPtr, &size);
	/* TODO - leave space in front and/or back? */
	if (ListRepInitAttempt(interp, size > 0 ? 2 * size : 1, NULL,
		&listRep) != TCL_OK) {
	    return TCL_ERROR;
	}

	LIST_ASSERT(listRep.spanPtr == NULL); /* Guard against future changes */
	LIST_ASSERT(listRep.storePtr->firstUsed == 0);
	LIST_ASSERT((listRep.storePtr->flags & LISTSTORE_CANONICAL) == 0);

	listRep.storePtr->numUsed = 2 * size;

	/* Populate the list representation. */

	elemPtrs = listRep.storePtr->slots;
	Tcl_DictObjFirst(NULL, objPtr, &search, &keyPtr, &valuePtr, &done);
	while (!done) {
	    *elemPtrs++ = keyPtr;
	    *elemPtrs++ = valuePtr;
	    Tcl_IncrRefCount(keyPtr);
	    Tcl_IncrRefCount(valuePtr);
	    Tcl_DictObjNext(&search, &keyPtr, &valuePtr, &done);
	}
    } else if (TclObjTypeHasProc(objPtr,indexProc)) {
	Tcl_Size elemCount, i;

	elemCount = TclObjTypeLength(objPtr);

	if (ListRepInitAttempt(interp, elemCount, NULL, &listRep) != TCL_OK) {
	    return TCL_ERROR;
	}

	LIST_ASSERT(listRep.spanPtr == NULL); /* Guard against future changes */
	LIST_ASSERT(listRep.storePtr->firstUsed == 0);

	elemPtrs = listRep.storePtr->slots;

	/* Each iteration, store a list element */
	for (i = 0; i < elemCount; i++) {
	    if (TclObjTypeIndex(interp, objPtr, i, elemPtrs) != TCL_OK) {
		return TCL_ERROR;
	    }
	    Tcl_IncrRefCount(*elemPtrs++);/* Since list now holds ref to it. */
	}

	LIST_ASSERT((Tcl_Size)(elemPtrs - listRep.storePtr->slots) == elemCount);

	listRep.storePtr->numUsed = elemCount;

    } else {
	Tcl_Size estCount, length;
	const char *limit, *nextElem = TclGetStringFromObj(objPtr, &length);

	/*
	 * Allocate enough space to hold a (Tcl_Obj *) for each
	 * (possible) list element.
	 */

	estCount = TclMaxListLength(nextElem, length, &limit);
	estCount += (estCount == 0);	/* Smallest list struct holds 1
					 * element. */
	/* TODO - allocate additional space? */
	if (ListRepInitAttempt(interp, estCount, NULL, &listRep) != TCL_OK) {
	    return TCL_ERROR;
	}

	LIST_ASSERT(listRep.spanPtr == NULL); /* Guard against future changes */
	LIST_ASSERT(listRep.storePtr->firstUsed == 0);

	elemPtrs = listRep.storePtr->slots;

	/* Each iteration, parse and store a list element. */

	while (nextElem < limit) {
	    const char *elemStart;
	    char *check;
	    Tcl_Size elemSize;
	    int literal;

	    if (TCL_OK != TclFindElement(interp, nextElem, limit - nextElem,
		    &elemStart, &nextElem, &elemSize, &literal)) {
	    fail:
		while (--elemPtrs >= listRep.storePtr->slots) {
		    Tcl_DecrRefCount(*elemPtrs);
		}
		Tcl_Free(listRep.storePtr);
		return TCL_ERROR;
	    }
	    if (elemStart == limit) {
		break;
	    }

	    TclNewObj(*elemPtrs);
	    TclInvalidateStringRep(*elemPtrs);
	    check = Tcl_InitStringRep(*elemPtrs, literal ? elemStart : NULL,
		    elemSize);
	    if (elemSize && check == NULL) {
		MemoryAllocationError(interp, elemSize);
		goto fail;
	    }
	    if (!literal) {
		Tcl_InitStringRep(*elemPtrs, NULL,
			TclCopyAndCollapse(elemSize, elemStart, check));
	    }

	    Tcl_IncrRefCount(*elemPtrs++);/* Since list now holds ref to it. */
	}

	listRep.storePtr->numUsed =
	    elemPtrs - listRep.storePtr->slots;
    }

    LISTREP_CHECK(&listRep);

    /*
     * Store the new internalRep. We do this as late
     * as possible to allow the conversion code, in particular
     * Tcl_GetStringFromObj, to use the old internalRep.
     */

    /*
     * Note old string representation NOT to be invalidated.
     * So do NOT use ListObjReplaceRepAndInvalidate. InternalRep to be freed AFTER
     * IncrRefs so do not use ListObjOverwriteRep
     */
    ListRepIncrRefs(&listRep);
    TclFreeInternalRep(objPtr);
    objPtr->internalRep.twoPtrValue.ptr1 = listRep.storePtr;
    objPtr->internalRep.twoPtrValue.ptr2 = listRep.spanPtr;
    objPtr->typePtr = &tclListType;

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * UpdateStringOfList --
 *
 *	Update the string representation for a list object.
 *
 *	Any previously-existing string representation is not invalidated, so
 *	storage is lost if this has not been taken care of.
 *
 * Effect
 *
 *	The string representation of 'listPtr' is set to the resulting string.
 *	This string will be empty if the list has no elements. It is assumed
 *	that the list internal representation is not NULL.
 *
 *----------------------------------------------------------------------
 */
static void
UpdateStringOfList(
    Tcl_Obj *listObj)		/* List object with string rep to update. */
{
#   define LOCAL_SIZE 64
    char localFlags[LOCAL_SIZE], *flagPtr = NULL;
    Tcl_Size numElems, i, length;
    size_t bytesNeeded = 0;
    const char *elem, *start;
    char *dst;
    Tcl_Obj **elemPtrs;
    ListRep listRep;

    ListObjGetRep(listObj, &listRep);
    LISTREP_CHECK(&listRep);

    ListRepElements(&listRep, numElems, elemPtrs);

    /*
     * Mark the list as being canonical; although it will now have a string
     * rep, it is one we derived through proper "canonical" quoting and so
     * it's known to be free from nasties relating to [concat] and [eval].
     * However, we only do this if
     *
     * (a) the store is not shared as a shared store may be referenced by
     * multiple lists with different string reps. (see [a366c6efee]), AND
     *
     * (b) list does not have a span. Consider a list generated from a
     * string and then this function called for a spanned list generated
     * from the original list. We cannot mark the list store as canonical as
     * that would also make the originating list canonical, which it may not
     * be. On the other hand, the spanned list itself is always canonical
     * (never generated from a string) so it does not have to be explicitly
     * marked as such. The ListObjIsCanonical macro takes this into account.
     * See the comments there.
     */
    if (listRep.storePtr->refCount < 2 && listRep.spanPtr == NULL) {
	LIST_ASSERT(listRep.storePtr->firstUsed == 0);/* Invariant */
	listRep.storePtr->flags |= LISTSTORE_CANONICAL;
    }

    /* Handle empty list case first, so rest of the routine is simpler. */

    if (numElems == 0) {
	Tcl_InitStringRep(listObj, NULL, 0);
	return;
    }

    /* Pass 1: estimate space, gather flags. */

    if (numElems <= LOCAL_SIZE) {
	flagPtr = localFlags;
    } else {
	/* We know numElems <= LIST_MAX, so this is safe. */
	flagPtr = (char *)Tcl_Alloc(numElems);
    }
    for (i = 0; i < numElems; i++) {
	flagPtr[i] = (i ? TCL_DONT_QUOTE_HASH : 0);
	elem = TclGetStringFromObj(elemPtrs[i], &length);
	bytesNeeded += TclScanElement(elem, length, flagPtr+i);
	if (bytesNeeded > SIZE_MAX - numElems) {
	    Tcl_Panic("max size for a Tcl value (%" TCL_Z_MODIFIER "u bytes) exceeded",
		    SIZE_MAX);
	}
    }
    bytesNeeded += numElems - 1;

    /*
     * Pass 2: copy into string rep buffer.
     */

    start = dst = Tcl_InitStringRep(listObj, NULL, bytesNeeded);
    TclOOM(dst, bytesNeeded);
    for (i = 0; i < numElems; i++) {
	if (i) {
	    flagPtr[i] |= TCL_DONT_QUOTE_HASH;
	}
	elem = TclGetStringFromObj(elemPtrs[i], &length);
	dst += TclConvertElement(elem, length, dst, flagPtr[i]);
	*dst++ = ' ';
    }

    /* Set the string length to what was actually written, the safe choice */
    (void) Tcl_InitStringRep(listObj, NULL, dst - 1 - start);

    if (flagPtr != localFlags) {
	Tcl_Free(flagPtr);
    }
}

/*
 *------------------------------------------------------------------------
 *
 * TclListTestObj --
 *
 *    Returns a list object with a specific internal rep and content.
 *    Used specifically for testing so span can be controlled explicitly.
 *
 * Results:
 *    Pointer to the Tcl_Obj containing the list.
 *
 * Side effects:
 *    None.
 *
 *------------------------------------------------------------------------
 */
Tcl_Obj *
TclListTestObj(
    size_t length,
    size_t leadingSpace,
    size_t endSpace)
{
    ListRep listRep;
    size_t capacity;
    Tcl_Obj *listObj;

    TclNewObj(listObj);

    /* Only a test object so ignoring overflow checks */
    capacity = length + leadingSpace + endSpace;
    if (capacity == 0) {
	return listObj;
    }
    if (capacity > LIST_MAX) {
	return NULL;
    }

    ListRepInit(capacity, NULL, LISTREP_PANIC_ON_FAIL, &listRep);

    ListStore *storePtr = listRep.storePtr;
    size_t i;
    for (i = 0; i < length; ++i) {
	TclNewUIntObj(storePtr->slots[i + leadingSpace], i);
	Tcl_IncrRefCount(storePtr->slots[i + leadingSpace]);
    }
    storePtr->firstUsed = leadingSpace;
    storePtr->numUsed = length;
    if (leadingSpace != 0) {
	listRep.spanPtr = ListSpanNew(leadingSpace, length);
    }
    ListObjReplaceRepAndInvalidate(listObj, &listRep);
    return listObj;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

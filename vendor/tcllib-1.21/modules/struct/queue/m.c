/* struct::queue - critcl - layer 3 definitions.
 *
 * -> Method functions.
 *    Implementations for all queue methods.
 */

#include "util.h"
#include "m.h"
#include "q.h"
#include "ms.h"

static int  qsize  (Q* q, int* u, int* r, int* a);
static void qshift (Q* q);

#undef QUEUE_DUMP
/*#define QUEUE_DUMP 1*/

#if QUEUE_DUMP
static void qdump  (Q* q);
#else
#define qdump(q) /* Ignore */
#endif

/* .................................................. */

/*
 *---------------------------------------------------------------------------
 *
 * qum_CLEAR --
 *
 *	Removes all elements currently on the queue. I.e empties the queue.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Only internal, memory allocation changes ...
 *
 *---------------------------------------------------------------------------
 */

int
qum_CLEAR (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: queue clear
     *	       [0]   [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    /*
     * Delete and recreate the queue memory. A combination of delete/new,
     * except the main structure is left unchanged
     */

    Tcl_DecrRefCount (q->unget);
    Tcl_DecrRefCount (q->queue);
    Tcl_DecrRefCount (q->append);

    q->at     = 0;
    q->unget  = Tcl_NewListObj (0,NULL);
    q->queue  = Tcl_NewListObj (0,NULL);
    q->append = Tcl_NewListObj (0,NULL);

    Tcl_IncrRefCount (q->unget); 
    Tcl_IncrRefCount (q->queue); 
    Tcl_IncrRefCount (q->append);

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * qum_DESTROY --
 *
 *	Destroys the whole queue object.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Releases memory.
 *
 *---------------------------------------------------------------------------
 */

int
qum_DESTROY (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: queue destroy
     *	       [0]   [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_DeleteCommandFromToken(interp, q->cmd);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * qum_PEEK/GET --
 *
 *	(Non-)destructively retrieves one or more elements from the top of the
 *	queue.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Only internal, memory allocation changes ...
 *
 *---------------------------------------------------------------------------
 */

int
qum_PEEK (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int get)
{
    /* Syntax: queue peek|get ?n?
     *	       [0]  [1]       [2]
     */

    int       listc = 0;
    Tcl_Obj** listv;
    Tcl_Obj*  r;
    int       n = 1;
    int       ungetc;
    int       queuec;
    int       appendc;

    if ((objc != 2) && (objc != 3)) {
	Tcl_WrongNumArgs (interp, 2, objv, "?n?");
	return TCL_ERROR;
    }

    if (objc == 3) {
	if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK) {
	    return TCL_ERROR;
	} else if (n < 1) {
	    Tcl_AppendResult (interp, "invalid item count ",
			      Tcl_GetString (objv[2]),
			      NULL);
	    return TCL_ERROR;
	}
    }

    if (n > qsize(q, &ungetc, &queuec, &appendc)) {
	Tcl_AppendResult (interp,
			  "insufficient items in queue to fill request",
			  NULL);
	return TCL_ERROR;
    }

    /* 1. We have item on the unget stack
     *    a. Enough to satisfy request.
     *    b. Not enough.
     * 2. We have items in the return buffer.
     *    a. Enough to satisfy request.
     *    b. Not enough.
     * 3. We have items in the append buffer.
     *    a. Enough to satisfy request.
     *    b. Not enough.
     *
     * Case 3. can assume 2b, because an empty return buffer will be filled
     * from the append buffer before looking at either. Case 3. cannot happen
     * for n==1, the return buffer will contain at least one element.
     *
     * We distinguish between single and multi-element requests.
     *
     * XXX AK optimizations - If we can return everything from a single
     * buffer, be it queue, or append, just return the buffer object, do not
     * create something new.
     */

    if (n == 1) {
	if (ungetc) {
	    /* Pull from unget stack */
	    Tcl_ListObjGetElements (interp, q->unget, &listc, &listv);
	    r = listv [listc-1];
	    Tcl_SetObjResult (interp, r);
	    if (get) {
		/* XXX AK : Should maintain max size info, and proper index, for discard. */
		Tcl_ListObjReplace (interp, q->unget, listc-1, 1, 0, NULL);
	    }
	} else {
	    qshift (q);
	    Tcl_ListObjGetElements (interp, q->queue, &listc, &listv);
	    ASSERT_BOUNDS(q->at,listc);
	    r = listv [q->at];
	    Tcl_SetObjResult (interp, r);
	    /*
	     * Note: Doing the SetObj now is important. It increments the
	     * refcount of 'r', allowing it to survive if the 'qshift' below
	     * kills the internal list (q->queue) holding it.
	     */
	    if (get) {
		q->at ++;
		qshift (q);
	    }
	}
    } else {
	/*
	 * Allocate buffer for result, then fill it using the various data
	 * sources.
	 */

	int i = 0, j;
	Tcl_Obj** resv = NALLOC(n,Tcl_Obj*);

	if (ungetc) {
	    Tcl_ListObjGetElements (interp, q->unget, &listc, &listv);
	    /*
	     * Note how we are iterating backward in listv. unget is managed
	     * as a stack, avoiding mem-copy operations and both push and pop.
	     */
	    for (j = listc-1;
		 j >= 0 && i < n;
		 j--, i++) {
		ASSERT_BOUNDS(i,n);
		ASSERT_BOUNDS(j,listc);
		resv[i] = listv[j];
		Tcl_IncrRefCount (resv[i]);
	    }
	    if (get) {
		/* XXX AK : Should maintain max size info, and proper index, for discard. */
		Tcl_ListObjReplace (interp, q->unget, j, i, 0, NULL);
		/* XXX CHECK index calcs. */
	    }
	}
	if (i < n) {
	    qshift (q);
	    Tcl_ListObjGetElements (interp, q->queue, &listc, &listv);
	    for (j = q->at;
		 j < listc && i < n; 
		 j++, i++) {
		ASSERT_BOUNDS(i,n);
		ASSERT_BOUNDS(j,listc);
		resv[i] = listv[j];
		Tcl_IncrRefCount (resv[i]);
	    }

	    if (get) {
		q->at = j;
		qshift (q);
	    } else if (i < n) {
		/* XX */
		Tcl_ListObjGetElements (interp, q->append, &listc, &listv);
		for (j = 0;
		     j < listc && i < n; 
		     j++, i++) {
		    ASSERT_BOUNDS(i,n);
		    ASSERT_BOUNDS(j,listc);
		    resv[i] = listv[j];
		    Tcl_IncrRefCount (resv[i]);
		}
	    }
	}

	/*
	 * This can happend if and only if we have to pull data from append,
	 * and get is set. Without get XX would have run and filled the result
	 * to completion.
	 */

	if (i < n) {
	    ASSERT(get,"Impossible 2nd return pull witohut get");
	    qshift (q);
	    Tcl_ListObjGetElements (interp, q->queue, &listc, &listv);
	    for (j = q->at;
		 j < listc && i < n; 
		 j++, i++) {
		ASSERT_BOUNDS(i,n);
		ASSERT_BOUNDS(j,listc);
		resv[i] = listv[j];
		Tcl_IncrRefCount (resv[i]);
	    }
	    q->at = j;
	    qshift (q);
	}

	r = Tcl_NewListObj (n, resv);
	Tcl_SetObjResult (interp, r);

	for (i=0;i<n;i++) {
	    Tcl_DecrRefCount (resv[i]);
	}
	ckfree((char*)resv);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * qum_PUT --
 *
 *	Adds one or more elements to the queue.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
qum_PUT (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: queue push item...
     *	       [0]   [1]  [2]
     */

    int i;

    if (objc < 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "item ?item ...?");
	return TCL_ERROR;
    }

    for (i = 2; i < objc; i++) {
	Tcl_ListObjAppendElement (interp, q->append, objv[i]);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * qum_UNGET --
 *
 *	Pushes an element back into the queue.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	May release and allocate memory.
 *
 *---------------------------------------------------------------------------
 */

int
qum_UNGET (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: queue unget item
     *	       [0]   [1]   [2]
     */

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "item");
	return TCL_ERROR;
    }

    if (q->at == 0) {
	/* Need the unget stack */
	Tcl_ListObjAppendElement (interp, q->unget, objv[2]);
    } else {
	/*
	 * We have room in the return buffer, so splice directly instead of
	 * using the unget stack.
	 */

	int queuec = 0;
	Tcl_ListObjLength (NULL, q->queue,  &queuec);

	q->at --;
	ASSERT_BOUNDS(q->at,queuec);
	Tcl_ListObjReplace (interp, q->queue, q->at, 1, 1, &objv[2]);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * qum_SIZE --
 *
 *	Returns the number of elements currently held by the queue.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	None.
 *
 *---------------------------------------------------------------------------
 */

int
qum_SIZE (Q* q, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: queue size
     *	       [0]   [1]
     */

    if ((objc != 2)) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult  (interp, Tcl_NewIntObj (qsize (q, NULL, NULL, NULL)));
    return TCL_OK;
}


static int
qsize (Q* q, int* u, int* r, int* a)
{
    int ungetc  = 0;
    int queuec  = 0;
    int appendc = 0;

    Tcl_ListObjLength (NULL, q->unget,  &ungetc);
    Tcl_ListObjLength (NULL, q->queue,  &queuec);
    Tcl_ListObjLength (NULL, q->append, &appendc);

    if (u) *u = ungetc;
    if (r) *r = queuec;
    if (a) *a = appendc;

    return ungetc + queuec + appendc - q->at;
}

static void
qshift (Q* q)
{
    int queuec = 0;
    int appendc = 0;

    qdump (q);

    /* The queue is not done yet, no shift */
    Tcl_ListObjLength (NULL, q->queue, &queuec);
    if (q->at < queuec) return;

    /* The queue is done, however there is nothing
     * to shift into it, so we don't
     */
    Tcl_ListObjLength (NULL, q->append, &appendc);
    if (!appendc) return;

    q->at = 0;
    Tcl_DecrRefCount (q->queue);
    q->queue  = q->append;
    q->append = Tcl_NewListObj (0,NULL);
    Tcl_IncrRefCount (q->append);

    qdump (q);
}

#ifdef QUEUE_DUMP
static void
qdump (Q* q)
{
    int k;
    int       listc = 0;
    Tcl_Obj** listv;

    fprintf(stderr,"qdump (%p, @%d)\n", q, q->at);fflush(stderr);

    fprintf(stderr,"\tunget %p\n", q->unget);fflush(stderr);
    Tcl_ListObjGetElements (NULL, q->unget, &listc, &listv);
    for (k=0; k < listc; k++) {
	fprintf(stderr,"\tunget %p [%d] = %p '%s' /%d\n", q->unget, k, listv[k], Tcl_GetString(listv[k]), listv[k]->refCount);fflush(stderr);
    }

    fprintf(stderr,"\tqueue %p\n", q->queue);fflush(stderr);
    Tcl_ListObjGetElements (NULL, q->queue, &listc, &listv);
    for (k=0; k < listc; k++) {
	fprintf(stderr,"\tqueue %p [%d] = %p '%s' /%d\n", q->queue, k, listv[k], Tcl_GetString(listv[k]), listv[k]->refCount);fflush(stderr);
    }

    fprintf(stderr,"\tapp.. %p\n", q->append);fflush(stderr);
    Tcl_ListObjGetElements (NULL, q->append, &listc, &listv);
    for (k=0; k < listc; k++) {
	fprintf(stderr,"\tapp.. %p [%d] = %p '%s' /%d\n", q->append, k, listv[k], Tcl_GetString(listv[k]), listv[k]->refCount);fflush(stderr);
    }

    fprintf(stderr,"qdump/ ___________________\n");fflush(stderr);
}
#endif

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::stack - critcl - layer 3 definitions.
 *
 * -> Method functions.
 *    Implementations for all stack methods.
 */

#include "util.h"
#include "m.h"
#include "s.h"
#include "ms.h"

/* .................................................. */

/*
 *---------------------------------------------------------------------------
 *
 * stm_CLEAR --
 *
 *	Removes all elements currently on the stack. I.e empties the stack.
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
stm_CLEAR (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: stack clear
     *	       [0]   [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    /*
     * Delete and recreate the stack memory. A combination of delete/new,
     * except the main structure is left unchanged
     */

    Tcl_DecrRefCount (s->stack);

    s->max   = 0;
    s->stack = Tcl_NewListObj (0,NULL);
    Tcl_IncrRefCount (s->stack);

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_DESTROY --
 *
 *	Destroys the whole stack object.
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
stm_DESTROY (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: stack destroy
     *	       [0]   [1]
     */

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_DeleteCommandFromToken(interp, s->cmd);
    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_GET --
 *
 *	Non-destructively retrieves all elements of the stack.
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
stm_GET (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int revers)
{
    /* Syntax: stack get
     *	       [0]  [1]
     */

    int n;

    if (objc != 2) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_ListObjLength (interp, s->stack, &n);

    if (n) {
	return st_peek (s, interp, n, 0, 1, revers, 1
			/* no pop, list all, <revers>, return result */);
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0,NULL));
	return TCL_OK;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_TRIM --
 *
 *	Destructively retrieves one or more elements from the top of the
 *	stack, trims the stack to a new size.
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
stm_TRIM (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int ret)
{
    /* Syntax: stack trim N
     *	       [0]  [1]   [2]
     */

    int n, len;

    if (objc != 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "newsize");
	return TCL_ERROR;
    }

    if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK) {
	    return TCL_ERROR;
    } else if (n < 0) {
	Tcl_AppendResult (interp, "invalid size ",
			  Tcl_GetString (objv[2]),
			  NULL);
	return TCL_ERROR;
    }

    Tcl_ListObjLength (interp, s->stack, &len);

    if (len > n) {
	return st_peek (s, interp, len-n, 1, 1, 0, ret
			/* pop, list all, normal order, <ret> */);
    } else {
	Tcl_SetObjResult (interp, Tcl_NewListObj (0,NULL));
	return TCL_OK;
    }
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_PEEK/POP --
 *
 *	(Non-)destructively retrieves one or more elements from the top of the
 *	stack.
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
stm_PEEK (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv, int pop, int revers)
{
    /* Syntax: stack peek|pop ?n?
     *	       [0]  [1]       [2]
     */

    int       listc = 0;
    Tcl_Obj** listv;
    Tcl_Obj*  r;
    int       n = 1;
    int       i, j;

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

    return st_peek (s, interp, n, pop, 0, revers, 1
		    /* <pop>, single, <revers>, return result */);
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_PUSH --
 *
 *	Adds one or more elements to the stack.
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
stm_PUSH (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: stack push item...
     *	       [0]   [1]  [2]
     */

    int i;

    if (objc < 3) {
	Tcl_WrongNumArgs (interp, 2, objv, "item ?item ...?");
	return TCL_ERROR;
    }

    for (i = 2; i < objc; i++) {
	Tcl_ListObjAppendElement (interp, s->stack, objv[i]);
    }

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_ROTATE --
 *
 *	Rotates the N top elements of the stack by K steps.
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
stm_ROTATE (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: stack rotate count steps
     *	       [0]   [1]    [2]   [3]
     */

    int       n, steps, start, i, j;
    int	      listc = 0;
    Tcl_Obj** listv = NULL;
    Tcl_Obj** tmp = NULL;

    if (objc != 4) {
	Tcl_WrongNumArgs (interp, 2, objv, "count steps");
	return TCL_ERROR;
    }

    if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK) {
	return TCL_ERROR;
    }
    if (Tcl_GetIntFromObj(interp, objv[3], &steps) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_ListObjGetElements (interp, s->stack, &listc, &listv);

    if (n > listc) {
	Tcl_AppendResult (interp, "insufficient items on stack to fill request",
			  NULL);
	return TCL_ERROR;
    }

    /* Begin rotation */

    start = listc - n;
    steps = steps % n;
    while (steps < 0) steps += n;
    steps = n - steps;
    listv += start;

    tmp = NALLOC(n,Tcl_Obj*);

    for (i = 0; i < n; i++) {
	j = (i + steps) % n;
	ASSERT_BOUNDS (i,n);
	ASSERT_BOUNDS (j,n);
	tmp[i] = listv[j];
    }
    for (i = 0; i < n; i++) {
	ASSERT_BOUNDS (i,n);
	listv[i] = tmp [i];
    }

    ckfree ((char*) tmp);

    return TCL_OK;
}

/*
 *---------------------------------------------------------------------------
 *
 * stm_SIZE --
 *
 *	Returns the number of elements currently held by the stack.
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
stm_SIZE (S* s, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    /* Syntax: stack size
     *	       [0]   [1]
     */

    int listc = 0;

    if ((objc != 2)) {
	Tcl_WrongNumArgs (interp, 2, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_ListObjLength (interp, s->stack, &listc);
    Tcl_SetObjResult  (interp, Tcl_NewIntObj (listc));
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

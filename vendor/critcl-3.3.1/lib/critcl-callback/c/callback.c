/*
 * Callback - Implementation
 */

#include <callback_int.h>

#include <critcl_trace.h>
#include <critcl_assert.h>
#include <critcl_alloc.h>

TRACE_ON;

/*
 * API
 */

critcl_callback_p
critcl_callback_new (Tcl_Interp* interp, Tcl_Size objc, Tcl_Obj** objv, Tcl_Size nargs)
{
    TRACE_FUNC ("((Interp*) %p, objc %d, (Tcl_Obj**) %p, nargs %d)",
		interp, objc, objv, nargs);

    critcl_callback_p c = ALLOC (critcl_callback);
    int total  = objc + nargs;
    c->nfixed  = objc;
    c->nargs   = nargs;
    c->command = NALLOC (Tcl_Obj*, total);
    c->interp  = interp;

    int i;
    for (i = 0; i < objc; i++) {
	TRACE ("D [%3d] = (TclObj*) %p = '%s'", i, objv [i], Tcl_GetString (objv [i]));
	c->command [i] = objv [i];
	Tcl_IncrRefCount (objv [i]);
    }
    for (; i < total; i++) {
	TRACE ("D [%3d] = n/a", i);
	c->command [i] = 0;
    }

    TRACE_RETURN ("(critcl_callback_p) %p", c);
}

void
critcl_callback_extend (critcl_callback_p callback, Tcl_Obj* argument)
{
    TRACE_FUNC ("((critcl_callback_p) %p, (Tcl_Obj*) %p)", callback, argument);
    ASSERT (callback->nargs > 0, "No arguments left to use for extension");

    TRACE ("E [%3d] = (TclObj*) %p = '%s'", callback->nfixed, argument, Tcl_GetString (argument));

    callback->command [callback->nfixed] = argument;
    Tcl_IncrRefCount (argument);

    callback->nargs  --;
    callback->nfixed ++;

    TRACE_RETURN_VOID;
}

void
critcl_callback_destroy (critcl_callback_p callback)
{
    TRACE_FUNC ("((critcl_callback_p) %p)", callback);

    int i;
    for (i = callback->nfixed-1; i > 0; i--) {
	Tcl_DecrRefCount (callback->command [i]);
    }
    FREE (callback->command);
    FREE (callback);

    TRACE_RETURN_VOID;
}

int
critcl_callback_invoke (critcl_callback_p callback, Tcl_Size objc, Tcl_Obj** objv)
{
    TRACE_FUNC ("((critcl_callback_p) %p, objc %d, (Tcl_Obj**) %p)", callback, objc, objv);
    ASSERT (objc <= callback->nargs, "Too many arguments");

    Tcl_Size i, j;

    for (i = 0; i < callback->nfixed; i++) {
	TRACE ("I [%3d] = (TclObj*) %p = '%s'", i, callback->command [i], Tcl_GetString (callback->command [i]));
	Tcl_IncrRefCount (callback->command [i]);
    }
    for (i = callback->nfixed, j = 0 ; j < objc; i++, j++) {
	TRACE ("I [%3d] = (TclObj*) %p = '%s'", i, objv [j], Tcl_GetString (objv [j]));
	Tcl_IncrRefCount (objv [j]);
	callback->command [i] = objv [j];
    }

    int res = Tcl_EvalObjv (callback->interp, i, callback->command, TCL_EVAL_GLOBAL); /* OK tcl9 */

    for (i = 0; i < callback->nfixed; i++) {
	Tcl_DecrRefCount (callback->command [i]);
    }
    for (j = 0 ; j < objc; j++) {
	Tcl_DecrRefCount (objv [j]);
    }

    TRACE ("R (Tcl_Obj*) %p = '%s'", Tcl_GetObjResult (callback->interp),
	   Tcl_GetString (Tcl_GetObjResult (callback->interp)));
    TRACE_RETURN ("(int) %d", res);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

/* struct::queue - critcl - layer 2 definitions
 *
 * -> Support for the queue methods in layer 3.
 */

#include <ms.h>
#include <m.h>
#include <q.h>
#include <util.h>

/* .................................................. */
/*
 *---------------------------------------------------------------------------
 *
 * qums_objcmd --
 *
 *	Implementation of queue objects, the main dispatcher function.
 *
 * Results:
 *	A standard Tcl result code.
 *
 * Side effects:
 *	Per the called methods.
 *
 *---------------------------------------------------------------------------
 */

int
qums_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
{
    Q*  q = (Q*) cd;
    int m;

    static CONST char* methods [] = {
	"clear", "destroy",	"get",
	"peek",	 "put",		"size",
	"unget",
	NULL
    };
    enum methods {
	M_CLEAR, M_DESTROY, M_GET,
	M_PEEK,  M_PUT,     M_SIZE,
	M_UNGET
    };

    if (objc < 2) {
	Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    } else if (Tcl_GetIndexFromObj (interp, objv [1], methods, "option",
				    0, &m) != TCL_OK) {
	return TCL_ERROR;
    }

    /* Dispatch to methods. They check the #args in detail before performing
     * the requested functionality
     */

    switch (m) {
    case M_CLEAR:	return qum_CLEAR   (q, interp, objc, objv);
    case M_DESTROY:	return qum_DESTROY (q, interp, objc, objv);
    case M_GET:		return qum_PEEK    (q, interp, objc, objv, 1 /* get  */);
    case M_PEEK:	return qum_PEEK    (q, interp, objc, objv, 0 /* peek */);
    case M_PUT:		return qum_PUT     (q, interp, objc, objv);
    case M_SIZE:	return qum_SIZE    (q, interp, objc, objv);
    case M_UNGET:	return qum_UNGET   (q, interp, objc, objv);
    }
    /* Not coming to this place */
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] For all that this is a part of how to
[sectref {Using External Libraries} {Use External Libraries}], for the demonstratation
only the basics are needed.

[enum][vset base][example {
    critcl::ccode {
	typedef struct vec2 {
	    double x;
	    double y;
	} vec2;

	typedef vec2* vec2ptr;

	int
	GetVecFromObj (Tcl_Interp* interp, Tcl_Obj* obj, vec2ptr* vec)
	{
	    int len;
	    if (Tcl_ListObjLength (interp, obj, &len) != TCL_OK) return TCL_ERROR;
	    if (len != 2) {
		Tcl_SetObjResult (interp, Tcl_ObjPrintf ("Expected 2 elements, got %d", len));
		return TCL_ERROR;
	    }

	    Tcl_Obj* lv[2];
	    if (Tcl_ListObjGetElements (interp, obj, &lv) != TCL_OK) return TCL_ERROR;

	    double x, y;
	    if (Tcl_GetDoubleFromObj (interp, lv[0], &x) != TCL_OK) return TCL_ERROR;
	    if (Tcl_GetDoubleFromObj (interp, lv[1], &y) != TCL_OK) return TCL_ERROR;

	    *vec = Tcl_Alloc (sizeof (vec2));
	    (*vec)->x = x;
	    (*vec)->y = y;
	    return TCL_OK;
	}
    }

    critcl::argtype vec2 {
	if (GetVecFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    } vec2ptr vec2ptr

    critcl::argtyperelease vec2 {
	/* @A : C variable holding the data to release */
	Tcl_Free ((char*) @A);
    }

    critcl::cproc norm {vec2 vector} double {
	double norm = hypot (vector->x, vector->y);
	return norm;
    }
}][vset rebuild]

[enum] The structure to pass as argument is a 2-dimensional vector. It is actually passed
in as a pointer to a [type vec2] structure.

This pointer is created by the [fun GetVecFromObj] function. It allocates and fills the
structure from the Tcl value, which has to be a list of 2 doubles. The bulk of the code in
[fun GetVecFromObj] is for verifying this and extracting the doubles.

[enum] The [cmd argtyperelease] code releases the pointer when the C function returns. In
other words, the pointer to the structure is owned by the translation layer and exists
only while the function is active.

[enum] While working this code has two disadvantages.

First there is memory churn. Each call of [cmd norm] causes the creation and release of a
temporary [type vec2] structure for the argument.

Second is the need to always extract the data from the [type Tcl_Obj*] value.

[para] Both can be done better.

[para] We will come back to this after explaining how to return structures to Tcl.

[list_end]

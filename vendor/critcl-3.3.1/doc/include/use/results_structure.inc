[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the end of the [sectref {Structure Arguments} previous] section.

[enum] Edit the file [file example.tcl] and add the following code, just after the
definition of the [cmd norm] command.

[example {
    critcl::resulttype vec2 {
	/* rv: result value of function, interp: current Tcl interpreter */
	if (rv == NULL) return TCL_ERROR;
	Tcl_Obj* lv[2];
	lv[0] = Tcl_NewDoubleObj (rv->x);
	lv[1] = Tcl_NewDoubleObj (rv->y);
	Tcl_SetObjResult (interp, Tcl_NewListObj (2, lv));
	Tcl_Free (rv);
	return TCL_OK;
    } vec2ptr ;# C result type

    critcl::cproc add {vec2 a vec2 b} vec2 {
	vec2ptr z = Tcl_Alloc (sizeof (vec2));

	z->x = a->x + b->x;
	z->y = a->y + b->y;

	return z;
    }
}][vset rebuild]

[enum] The new command [cmd add] takes two vectors and return the element-wise sum of both
as a new vector.

[enum] The function allocates and initializes a structure and hands it over to the
translation layer. Which in turn constructs a Tcl list of 2 doubles from it, sets that as
the command's result and at last discards the allocated structure again.

[enum] While working this code has two disadvantages.

First there is memory churn. Each call of [cmd add] causes the creation and release of
three temporary [type vec2] structures. One per argument, and one for the result.

Second is the need to always construct a complex [type Tcl_Obj*] value from the structure.

[para] Both can be done better. This is explained in the next section.

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum][vset base][example {
    critcl::cproc sqrt {
	Tcl_Interp* interp
	double      x
    } object0 {
	if (x < 0) {
	    Tcl_SetObjResult (interp, Tcl_ObjPrintf ("Expected double >=0, but got \"%d\"", x));
	    Tcl_SetErrorCode (interp, "EXAMPLE", "BAD", "DOMAIN", NULL);
	    return NULL;
	}
	return Tcl_NewDoubleObj(sqrt(x));
    }
}][vset rebuild]

[enum] In standard C-based packages commands signal errors by returning [const TCL_ERROR],
placing the error message as the interpreter result, and maybe providing an error code via
[fun Tcl_SetErrorCode].

[enum] When using [cmd critcl::cproc] this is limited and hidden.

[enum] The simple and string types for results do not allow failure. The value is returned
to the translation layer, converted into the interpreter result and then reported as
success ([const TCL_OK]).

[enum] The object types on the other hand do allow for failure.

Return a [const NULL] value to signal failure to the translation layer, which then reports
this to the interpreter via the standard [const TCL_ERROR].

[enum] [emph Attention] Setting the desired error message and code into the interpreter is
still the responsibility of the function body.

[list_end]


[para] To get around this limitation the commands in this section
enable users of [package critcl] to extend the set of argument and
result types understood by [cmd critcl::cproc]. In other words, they
allow them to define their own, custom, types.

[list_begin definitions]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::has-resulttype] [arg name]]

This command tests if the named result-type is known or not.

It returns a boolean value, [const true] if the type is known and
[const false] otherwise.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::resulttype] [arg name] [arg body] [opt [arg ctype]]]

This command defines the result type [arg name], and associates it
with the C code doing the conversion ([arg body]) from C to Tcl.

The C return type of the associated function, also the C type of the
result variable, is [arg ctype]. This type defaults to [arg name] if
it is not specified.

[para] If [arg name] is already declared an error is thrown.

[emph Attention!] The standard result type [const void] is special as
it has no accompanying result variable. This cannot be expressed
by this extension command.

[para] The [arg body]'s responsibility is the conversion of the
functions result into a Tcl result and a Tcl status. The first has to
be set into the interpreter we are in, and the second has to be
returned.

[para] The C code of [arg body] is guaranteed to be called last in the
wrapper around the actual implementation of the [cmd cproc] in
question and has access to the following environment:

[list_begin definitions]
[def [var interp]] A Tcl_Interp* typed C variable referencing the
                   interpreter the result has to be stored into.
[def [var rv]] The C variable holding the result to convert, of type
               [arg ctype].
[list_end]

As examples here are the definitions of two standard result types:

[example {
    resulttype int {
	Tcl_SetObjResult(interp, Tcl_NewIntObj(rv));
	return TCL_OK;
    }

    resulttype ok {
	/* interp result must be set by cproc body */
	return rv;
    } int
}]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::resulttype] [arg name] [method =] [arg origname]]

This form of the [cmd resulttype] command declares [arg name] as an
alias of result type [arg origname], which has to be defined
already. If this is not the case an error is thrown.


[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::has-argtype] [arg name]]

This command tests if the named argument-type is known or not.

It returns a boolean value, [const true] if the type is known and
[const false] otherwise.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::argtype] [arg name] [arg body] [opt [arg ctype]] [opt [arg ctypefun]]]

This command defines the argument type [arg name], and associates it
with the C code doing the conversion ([arg body]) from Tcl to C.

[arg ctype] is the C type of the variable to hold the conversion result
and [arg ctypefun] is the type of the function argument itself.
Both types default to [arg name] if they are the empty string or are not
provided.

[para] If [arg name] is already declared an error is thrown.

[para] [arg body] is a C code fragment that converts a Tcl_Obj* into a
C value which is stored in a helper variable in the underlying function.

[para] [arg body] is called inside its own code block to isolate local
variables, and the following items are in scope:

[list_begin definitions]
[def [var interp]] A variable of type [const Tcl_Interp*] which is the
                   interpreter the code is running in.
[def [const @@]] A placeholder for an expression that evaluates to the
                 [const Tcl_Obj*] to convert.

[def [const @A]] A placeholder for the name of the variable to store the
     	    	 converted argument into.
[list_end]

As examples, here are the definitions of two standard argument types:

[example {
    argtype int {
	if (Tcl_GetIntFromObj(interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }

    argtype float {
	double t;
	if (Tcl_GetDoubleFromObj(interp, @@, &t) != TCL_OK) return TCL_ERROR;
	@A = (float) t;
    }
}]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::argtype] [arg name] [method =] [arg origname]]

This form of the [cmd argtype] command declares [arg name] as an alias
of argument type [arg origname], which has to be defined already. If
this is not the case an error is thrown.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argtypesupport] [arg name] [arg code] [opt [arg guard]]]

This command defines a C code fragment for the already defined
argument type [arg name] which is inserted before all functions
using that type. Its purpose is the definition of any supporting C
types needed by the argument type.

If the type is used by many functions the system ensures that only the
first of the multiple insertions of the code fragment is active, and
the others disabled.

The guard identifier is normally derived from [arg name], but can also
be set explicitly, via [arg guard]. This latter allows different
custom types to share a common support structure without having to
perform their own guarding.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argtyperelease] [arg name] [arg code]]

This command defines a C code fragment for the already defined
argument type [arg name] which is inserted whenever the worker
function of a [cmd critcl::cproc] returns to the shim. It is the
responsibility of this fragment to unconditionally release any
resources the [cmd critcl::argtype] conversion code allocated.

An example of this are the [emph variadic] types for the support of
the special, variadic [arg args] argument to [cmd critcl::cproc]'s.
They allocate a C array for the collected arguments which has to be
released when the worker returns. This command defines the C code
for doing that.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

The following commands append C code fragments to the current module.  Fragments
appear in the module in the order they are appended, so the earlier fragments
(variables, functions, macros, etc.) are visible to later fragments.

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::ccode] [arg fragment]]

Appends the C code in [arg fragment] to the current module and returns the
empty string.

See [sectref {Runtime Behaviour}].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::ccommand] [arg tclname] [arg cname]]

As documented below, except that [arg cname] is the name of a C function
that already exists.


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::ccommand] [arg tclname] [arg arguments] [arg body] [
	opt "[arg option] [arg value]..."]]

Appends the code to create a Tcl command named [arg tclname] and a
corresponding C function whose body is [arg body] and which behaves as
documented for Tcl's own
[uri https://www.tcl-lang.org/man/tcl/TclLib/CrtObjCmd.htm Tcl_CreateObjCommand].

[para]
[arg aguments] is a list of zero to four names for the standard arguments
[const clientdata], [const interp], [const objc], and [const objv].  The
standard default names are used in place of any missing names.

This is a more low-level way than [cmd critcl::cproc] to define a command, as
processing of the items in [const objv] is left to the author, affording
complete control over the handling of the arguments to the command.

See section [sectref {Runtime Behaviour}].

[para]
Returns the empty string.

[para]
Each [arg option] may be one of:

[list_begin options]
[opt_def -clientdata [arg c-expression]]

Provides the client data for the new command.  [const NULL] by default.

[opt_def -delproc [arg c-expression]]

Provides a function pointer of type [uri \
	https://www.tcl-lang.org/man/tcl/TclLib/CrtObjCmd.htm \
	Tcl_CmdDeleteProc
] as the deletion function for the new command.  [const NULL] by default.


[include api_embedc_cnameoption.inc]

[list_end]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cdata] [arg tclname] [arg data]]

Appends the code to create a new Tcl command named [arg tclname] which returns
[arg data] as a [const ByteArray] result.

[para]
Returns the empty string.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cconst] [arg tclname] [arg resulttype] [arg value]]

Appends the code to create a new Tcl command named [arg tclname] which returns
the constant [arg value] having the Tcl type [arg resulttype].  [arg value] can
be a C macro or a function [emph call] (including the parentheses) to any
visible C function that does not take arguments.

Unlike [cmd critcl::cdata], [arg resulttype] can be any type known to
[cmd critcl::cproc].

Its semantics are equivalent to:

[example {
    cproc $tclname {} $resulttype "return $value ;"
}]

[para] This is more efficient than [cmd critcl::cproc] since there is no
C function generated.

[para]
Returns the empty string.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cdefines] [arg {list of glob patterns}] [opt [arg namespace]]]

Arranges for [term {C enum}] and [term #define] values that match one of the
patterns in [term {glob patterns}] to be created in the namespace
[arg namespace], each variable having the same as the corresponding C item.
The default namespace is the global namespace.  A pattern that matches nothing
is ignored.

[para] The Tcl variables are created when the module is compiled, using the
preprocessor in order to properly find all matching C definitions.

[para]
Produces no C code.  The desired C definitions must already exist.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cproc] [arg name] [arg arguments] [arg resulttype] [arg body] \
      [opt "[arg option] [arg value]..."]]

Appends a function having [arg body] as its body, another shim function to
perform the needed conversions, and the code to create a corresponding Tcl
command named [arg tclname].  Unlike [cmd critcl::ccommand] the arguments and
result are typed, and CriTcl generates the code to convert between Tcl_Obj
values and C data types.

See also [sectref {Runtime Behaviour}].

[para]
Returns the empty string.

[para]
[list_begin arguments]

[arg_def string option] Each may be one of:

[list_begin options]

[include api_embedc_cnameoption.inc]

[opt_def -pass-cdata [arg boolean]]

If [const false] (the default), the shim function performing the conversion to
and from Tcl level does not pass the ClientData as the first argument to
the function.

[opt_def -arg-offset [arg int]]

A non-negative integer, [const 0] by default, indicating the number of hidden
arguments preceding the actual procedure arguments.  Used by higher-order code
generators where there are prefix arguments which are not directly seen by the
function but which influence argument counting and extraction.

[list_end]

[arg_def string resulttype] May be a predefined or a custom type.

See [term {CriTcl cproc Type Reference}] for the full list of predefined types and how to
extend them.

Unless otherwise noted, the Tcl return code is always [const TCL_OK].

[arg_def list arguments] Is a multi-dictionary where each key is an
argument type and its value is the argument name.

For example:

[example { int x int y }]

[para] Each argument name must be a valid C identifier.

[para] If the name is a list containing two items, the first item is the name
and the second item is the default value.  A limited form of variadic arguments
can be accomplished using such default values.

For example:

[example { int {x 1} }]

Here [arg x] is an optional argument of type [type int] with a default
value of [const 1].

[para] Argument conversion is completely bypassed when the argument is not
provided, so a custom converter doing validation does not get the chance to
validate the default value.  In this case, the value should be checked in the
body of the function.

[para] Each argument type may be a predefined or custom type.

See [term {CriTcl cproc Type Reference}] for the full list of predefined types and how to
extend them.

[list_end][comment {-- arguments --}]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cproc] [arg name] [arg arguments] [arg resulttype]]

As documented below, but used when the C function named [arg name] already
exists.


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cinit] [arg text] [arg externals]]

Appends the C code in [arg text] and [arg externals], but only after all the
other fragments appended by the previously-listed commands regardless of their
placement in the [vset critcl_script] relative to this command.  Thus, all
their content is visible.  See also [sectref {Runtime Behaviour}].

[para] The C code in [arg text] is placed into the body of the initialization
function of the shared library backing the [vset critcl_script], and is
executed when this library is loaded into the interpreter.  It has access to
the variable [var {Tcl_Interp* interp}] referencing the Tcl interpreter currently
being initialized.

[para] [arg externals] is placed outside and just before the initialization
function, making it a good place for any external symbols required by
initialization function, but which should not be accessible by any other parts
of the C code.

[para] [vset cumulative]

[para]
Returns the empty string.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::include] [arg path]]

This command is a convenient shorthand for

[example {
critcl::code {
  #include <${path}>
}
}]

[comment ---------------------------------------------------------------------]
[list_end]

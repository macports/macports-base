
[list_begin definitions]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd insvariable] [arg ctype] [arg name] [opt [arg comment]] \
     [opt [arg constructor]] [opt [arg destructor]]]

This command specifies a field in the instance structure of the class.

Multiple fields can be specified, and are saved in the order
specified.

[para] [emph Attention:] Specification of an instance variable
precludes the use of an external C [cmd type] for the instance
structure.

[para] [emph Attention:] Specification of an instance variable
automatically causes the definition of an instance variable of type
[const Tcl_Command], and named [const cmd], holding the token of the
instance command, and the definition of an instance method named
[const destroy]. This implicit instance variable is managed by the
system.

[para] Beyond the basic [arg name] and C type of the new variable the
definition may also contain a [arg comment] describing it, and C code
blocks to initialize and release the variable.

These are effectively local forms of the commands [cmd constructor]
and [cmd destructor]. Please read their descriptions for details
regarding the C environment available to the code.

[para] The comment, if specified will be embedded into the generated C
code for easier cross-referencing from generated [file .c] file to
class specification.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd method] [arg name] [method command] [arg arguments] \
	[arg body]]

This command specifies an instance method and the C code block
implementing its functionality. This is the first of three forms. The
method is specified like a [cmd critcl::ccommand], with a fixed set of
C-level arguments. The [arg body] has to perform everything
(i.e. argument extraction, checking, result return, and of course the
actual functionality) by itself.

[para] For this the [arg body] has access to

[list_begin definitions]
[def [var instance]] Pointer to the instance structure.
[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
instance structure is associated with
[def [var objc]] The number of method arguments.
[def [var objv]] The method arguments, as C array of Tcl_Obj pointers.
[list_end]

The [arg arguments] of the definition are only a human readable form
of the method arguments and syntax and are not used in the C code,
except as comments put into the generated code. Again, it is the
responsibility of the [arg body] to check the number of arguments,
extract them, check their types, etc.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd method] [arg name] [method proc] [arg arguments] \
	[arg resulttype] [arg body]]

This command specifies an instance method and the C code block
implementing its functionality.  This is the second of three
forms. The method is specified like a [cmd critcl::cproc].

Contrary to the first variant here the [arg arguments] are computer
readable, expected to be in the same format as the [arg arguments] of
[cmd critcl::cproc]. The same is true for the [arg resulttype].

The system automatically generates a wrapper doing argument checking
and conversion, and result conversion, like for [cmd critcl::cproc].

[para] The [arg body] has access to

[list_begin definitions]
[def [var instance]] Pointer to the instance structure.
[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
instance structure is associated with
[def ...] All [arg arguments] under their specified names and C types
as per their definition.
[list_end]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd method] [arg name] [method as] [arg funname] \
	[opt [arg arg]...]]

This command specifies an instance method and the C code block
implementing its functionality. This is the third and last of three
forms.

[para] The instance method is implemented by the external function
[arg funname], i.e. a function which is declared outside of the instance
code itself, or in a [cmd support] block.

[para] It is assumed that the first four arguments of that function
represent the parameters

[list_begin definitions]
[def [var instance]] Pointer to the instance structure.
[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
instance structure is associated with
[def [var objc]] The number of method arguments.
[def [var objv]] The method arguments, as C array of Tcl_Obj pointers.
[list_end]

Any additional arguments specified will be added after these and are
passed into the C code as is, i.e. are considered to be C expressions.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd method_introspection]]

This command generates one class- and one instance-method both of
which will return a list of the instance methods of the class, and
supporting structures, like the function to compute the information,
and a class variable caching it.

[para] The two methods and the class variable are all named
[const methods].

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

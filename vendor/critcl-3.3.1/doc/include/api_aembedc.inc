
For advanced use, the following commands used by [cmd critcl::cproc] itself are
exposed.

[vset given_cmd "Given an argument declaration as documented for [cmd critcl::cproc],"]

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argnames] [arg arguments]]

[vset given_cmd] returns a list of the corresponding user-visible names.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argcnames] [arg arguments]]

[vset given_cmd] returns a list of the corresponding C variable names for the
user-visible names. The names returned here match the names used in the
declarations and code returned by [cmd ::critcl::argvardecls] and
[cmd ::critcl::argconversion].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argcsignature] [arg arguments]]

[vset given_cmd] returns a list of the corresponding C parameter declarations.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argvardecls] [arg arguments]]

[vset given_cmd] returns a list of the corresponding C variable declarations.
The names used in these declarations match the names returned by
[cmd ::critcl::argcnames].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argconversion] [arg arguments] [opt [arg n]]]

[vset given_cmd] returns a list of C code fragments converting the user visible
arguments found in the declaration from Tcl_Obj* to C types. The names used in
these statements match the names returned by [cmd ::critcl::argcnames].

[para] The generated code assumes that the procedure arguments start
at index [arg n] of the [var objv] array.  The default is [const 1].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argoptional] [arg arguments]]

[vset given_cmd] returns a list of boolean values indicating which arguments
are optional ([const true]), and which are not ([const false]).

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argdefaults] [arg arguments]]

[vset given_cmd] returns a list containing the default values for all optional
arguments.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::argsupport] [arg arguments]]

[vset given_cmd] returns a list of C code fragments needed to define the
necessary supporting types.

[list_end]

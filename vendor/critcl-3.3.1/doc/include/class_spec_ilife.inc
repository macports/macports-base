
[list_begin definitions]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd constructor] [arg body] [opt [arg postbody]]]

This command specifies a C code block surrounding the initialization
of the instance variables, i.e. the fields of the instance structure.

[emph Note] that allocation and release of the instance structure
itself is done by the system and not the responsibility of the user.

[emph {On the other hand}], if an external [cmd type] was specified
for the instance structure, then instance variables are not possible,
and the system has no knowledge of the type's structure. In that case
it is the responsibility of the [arg body] to allocate and free the
structure itself too.

[para] For the initialization (and release) of an instance variable it
is recommended to use the [arg constructor] and [arg destructor]
arguments of the variable's definition (See command [cmd insvariable])
for this instead of using a separate [cmd constructor].

[para] This is an optional command. Using it more than once is allowed
too and each use will add another C code fragment to use during
construction. I.e. multiple calls aggregate.

[para] The C code blocks of multiple calls (including the constructors
of instance variable definitions) are executed in order of specification.

[para] The result of the command is the empty string.

[para] The C code in [arg body] has access to the following
environment:

[list_begin definitions]

[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
instance structure will be associated with. It enables the generation
of a Tcl error message should construction fail.

[def [var instance]] Pointer to the instance structure to initialize.

[def error] A C code label the constructor can jump to should it have
to signal a construction failure. It is the responsibility of the
constructor to release any variables already initialized before
jumping to this label. This also why the 'execution in order of
specification' is documented and can be relied on. It gives us the
knowledge which other constructors have already been run and
initialized what other fields.

[list_end]

[para] The C code in [arg postbody] is responsible for construction
actions to be done after the primary construction was done and the
Tcl-level instance command was successfully created. It has access to
a slightly different environment:

[list_begin definitions]

[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
instance structure will be associated with. It enables the generation
of a Tcl error message should construction fail.

[def [var instance]] Pointer to the instance structure to initialize.

[def [var cmd]] The Tcl_Command token of the Tcl-level instance
command.

[def [var fqn]] The fully qualified name of the instance command,
stored in a Tcl_Obj*.

[list_end]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd destructor] [arg body]]

This command specifies a C code block surrounding the release of the
instance variables, i.e. the fields of the instance structure.

[emph Note] that allocation and release of the instance structure
itself is done by the system and not the responsibility of the user.

[emph {On the other hand}], if an external [cmd type] was specified
for the instance structure, then instance variables are not possible,
and the system has no knowledge of the type's structure. In that case
it is the responsibility of the [arg body] to allocate and free the
structure itself too.

[para] For the initialization (and release) of an instance variable it
is recommended to use the [arg constructor] and [arg destructor]
arguments of the variable's definition (See command [cmd insvariable])
for this instead of using a separate [cmd constructor].

[para] This is an optional command. Using it more than once is allowed
too and each use will add another C code fragment to use during
construction. I.e. multiple calls aggregate.

[para] The C code blocks of multiple calls (including the constructors
of instance variable definitions) are executed in order of specification.

[para] The result of the command is the empty string.

[para] The C code in [arg body] has access to the following
environment:

[list_begin definitions]
[def [var instance]] Pointer to the instance structure to release.
[list_end]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]


[list_begin definitions]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd classconstructor] [arg body]]

This command specifies a C code block surrounding the initialization
of the class variables, i.e. the fields of the class structure.

[emph Note] that allocation and release of the class structure itself
is done by the system andf not the responsibility of the user.

[para] For the initialization (and release) of a class variable it is
recommended to use the [arg constructor] and [arg destructor]
arguments of the variable's definition (See command
[cmd classvariable]) for this instead of using a separate
[cmd classconstructor].

[para] This is an optional command. Using it more than once is allowed
too and each use will add another C code fragment to use during
construction. I.e. multiple calls aggregate.

[para] The C code blocks of multiple calls (including the constructors
of classvariable definitions) are executed in order of specification.

[para] The result of the command is the empty string.

[para] The C code in [arg body] has access to the following
environment:

[list_begin definitions]

[def [var interp]] Pointer to the Tcl interpreter (Tcl_Interp*) the
class structure will be associated with. It enables the generation
of a Tcl error message should construction fail.

[def [var class]] Pointer to the class structure to initialize.

[def error] A C code label the constructor can jump to should it have
to signal a construction failure. It is the responsibility of the
constructor to release any variables already initialized before
jumping to this label. This also why the 'execution in order of
specification' is documented and can be relied on. It gives us the
knowledge which other constructors have already been run and
initialized what other fields.

[list_end]

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd classdestructor] [arg body]]

This command specifies a C code block surrounding the release of the
class variables, i.e. the fields of the class structure.

[emph Note] that allocation and release of the class structure itself
is done by the system and not the responsibility of the user.

[para] For the initialization (and release) of a class variable it is
recommended to use the [arg constructor] and [arg destructor]
arguments of the variable's definition (See command
[cmd classvariable]) for this instead of using a separate
[cmd classconstructor].

[para] This is an optional command. Using it more than once is allowed
too and each use will add another C code fragment to use during
construction. I.e. multiple calls aggregate.

[para] The C code blocks of multiple calls (including the constructors
of class variable definitions) are executed in order of specification.

[para] The result of the command is the empty string.

[para] The C code in [arg body] has access to the same
environment as the class constructor code blocks.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

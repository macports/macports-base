
[list_begin definitions]
[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd include] [arg path]]

This command specifies the path of a header file to include within the
code generated for the class. This is separate from the [cmd support]
because the generated include directives will be put at the very
beginning of the generated code. This is done to allow the use of the
imported declarations within the instance type, and elsewhere.

[para] [vset cumulative]

It is of course possible to not use this command at all, for classes
not making use of external definitions.

[para] The result is the empty string.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd support] [arg code]]

This command specifies supporting C code, i.e. any definitions (types,
functions, etc.) needed by the [emph whole] class and not fitting into
class- and instance-methods. The code is embedded at global level,
outside of any function or other definition.

[para] [vset cumulative]

It is of course possible to not use this command at all, for classes
not requiring supporting code.

[para] The result of the command is the empty string.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd type] [arg name]]

This command specifies the name of an external C type to be used as
the type of the instance structure.

[para] Initialization and release of the structure with the given type
are the responsibility of the user, through [cmd constructor] and
[cmd destructor] code fragments.

[para][emph Attention:] Using this command precludes the use of
regular class- and instance variables. It further precludes the use of
[cmd method-introspection] as well, as this make use of generated
instance-variables.

[para] If class- and/or instance-variable have to be used in
conjunction with an external C type, simply create and use a class- or
instance-variable with that type.

[para] The result of the command is the empty string.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

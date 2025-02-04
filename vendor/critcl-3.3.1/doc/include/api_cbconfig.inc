
This package provides one command for the management of
package-specific, i.e. developer-specified custom build configuration
options.

[list_begin definitions]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::userconfig] [method define] [arg name] [arg description] [arg type] [opt [arg default]]]

This command defines custom build configuration option, with
[arg description], [arg type] and optional [arg default] value.

[para] The type can be either [const bool], or a list of values.

[list_begin enumerated]
[enum] For [const bool] the default value, if specified, must be a
boolean. If it is not specified it defaults to [const true].

[enum] For a list of values the default value, if specified, must be a
value found in this list. If it is not specified it defaults to the
first value of the list.

[list_end]

[para] The [arg description] serves as in-code documentation of the
meaning of the option and is otherwise ignored. When generating a TEA
wrapper the description is used for the [syscmd configure] option
derived from the option declared by the command.

[para] A boolean option [var FOO] are translated into a pair of
configure options, [option --enable-[var FOO]] and
[option --disable-[var FOO]], whereas an option whose [arg type] is a
list of values is translated into a single configure option
[option --with-[var FOO]].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::userconfig] [method query] [arg name]]

This command queries the database of custom build configuration option
for the current [file .critcl] file and returns the chosen value.
This may be the default if no value was set via
[cmd {::critcl::userconfig set}].

[para] It is at this point that definitions and set values are brought
together, with the latter validated against the definition.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::userconfig] [method set] [arg name] [arg value]]

This command is for use by a tool, like the [syscmd critcl] application,
to specify values for custom build configuration options.

[para] At the time this command is used only the association between
option name and value is recorded, and nothing else is done. This
behaviour is necessary as the system may not know if an option of the
specified name exists when the command is invoked, nor its type.

[para] Any and all validation is defered to when the value of an
option is asked for via [cmd {::critcl::userconfig query}].

[para] This means that it is possible to set values for any option we
like, and the value will take effect only if such an option is both
defined and used later on.

[list_end]

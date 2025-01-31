
[list_begin options]
[include options_std.inc]

[opt_def -template string]

The value of this option is a string into which to put
the generated text and the other configuration settings. The various
locations for user-data are expected to be specified with the
placeholders listed below. The default value is "[const @code@]".

[list_begin definitions]

[def [const @user@]]
To be replaced with the value of the option [option -user].

[def [const @format@]]
To be replaced with the the constant [const C/PARAM].

[def [const @file@]]
To be replaced with the value of the option [option -file].

[def [const @name@]]
To be replaced with the value of the option [option -name].

[def [const @code@]]
To be replaced with the generated Tcl code.

[list_end]

The following options are special, in that they will
occur within the generated code, and are replaced there as well.

[list_begin definitions]

[def [const @statedecl@]]
To be replaced with the value of the option [option state-decl].

[def [const @stateref@]]
To be replaced with the value of the option [option state-ref].

[def [const @strings@]]
To be replaced with the value of the option [option string-varname].

[def [const @self@]]
To be replaced with the value of the option [option self-command].

[def [const @def@]]
To be replaced with the value of the option [option fun-qualifier].

[def [const @ns@]]
To be replaced with the value of the option [option namespace].

[def [const @main@]]
To be replaced with the value of the option [option main].

[def [const @prelude@]]
To be replaced with the value of the option [option prelude].

[list_end]

[opt_def -state-decl string]

A C string representing the argument declaration to use in the
generated parsing functions to refer to the parsing state. In essence
type and argument name.

The default value is the string [const {RDE_PARAM p}].


[opt_def -state-ref string]

A C string representing the argument named used in the generated
parsing functions to refer to the parsing state.

The default value is the string [const p].


[opt_def -self-command string]

A C string representing the reference needed to call the generated
parser function (methods ...) from another parser fonction, per the
chosen framework (template).

The default value is the empty string.


[opt_def -fun-qualifier string]

A C string containing the attributes to give to the generated
functions (methods ...), per the chosen framework (template).

The default value is [const static].


[opt_def -namespace string]

The name of the C namespace the parser functions (methods, ...) shall
reside in, or a general prefix to add to the function names.

The default value is the empty string.


[opt_def -main string]

The name of the main function (method, ...) to be called by the chosen
framework (template) to start parsing input.

The default value is [const __main].


[opt_def -string-varname string]

The name of the variable used for the table of strings used by the
generated parser, i.e. error messages, symbol names, etc.

The default value is [const p_string].


[opt_def -prelude string]

A snippet of code to be inserted at the head of each generated parsing
function.

The default value is the empty string.


[opt_def -indent integer]

The number of characters to indent each line of the generated code by.

The default value is [const 0].


[opt_def -comments boolean]

A flag controlling the generation of code comments containing the
original parsing expression a parsing function is for.

The default value is [const on].

[list_end]

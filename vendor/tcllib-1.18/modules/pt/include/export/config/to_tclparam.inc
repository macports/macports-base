
[section Options]

The converter to Tcl/PARAM markup recognizes the following
configuration variables and changes its behaviour as they specify.

[list_begin options]

[opt_def -template string]

The value of this configuration variable is a string into which to put
the generated text and the other configuration settings. The various
locations for user-data are expected to be specified with the
placeholders listed below. The default value is "[const @code@]".

[list_begin definitions]

[def [const @user@]]
To be replaced with the value of the configuration variable [option -user].

[def [const @format@]]
To be replaced with the the constant [const Tcl/PARAM].

[def [const @file@]]
To be replaced with the value of the configuration variable [option -file].

[def [const @name@]]
To be replaced with the value of the configuration variable [option -name].

[def [const @code@]]
To be replaced with the generated Tcl code.

[list_end]

The following configuration variables are special, in that they will
occur within the generated code, and are replaced there as well.

[list_begin definitions]

[def [const @runtime@]]
To be replaced with the value of the configuration variable [option runtime-command].

[def [const @self@]]
To be replaced with the value of the configuration variable [option self-command].

[def [const @def@]]
To be replaced with the value of the configuration variable [option proc-command].

[def [const @ns@]]
To be replaced with the value of the configuration variable [option namespace].

[def [const @main@]]
To be replaced with the value of the configuration variable [option main].

[def [const @prelude@]]
To be replaced with the value of the configuration variable [option prelude].

[list_end]

[opt_def -name string]

The value of this configuration variable is the name of the grammar
for which the conversion is run. The default value is [const a_pe_grammar].

[opt_def -user string]

The value of this configuration variable is the name of the user for
which the conversion is run. The default value is [const unknown].

[opt_def -file string]

The value of this configuration variable is the name of the file or
other entity from which the grammar came, for which the conversion is
run. The default value is [const unknown].


[opt_def -runtime-command string]

A Tcl string representing the Tcl command or reference to it used to
call PARAM instruction from parser procedures, per the chosen
framework (template).

The default value is the empty string.


[opt_def -self-command string]

A Tcl string representing the Tcl command or reference to it used to
call the parser procedures (methods ...) from another parser
procedure, per the chosen framework (template).

The default value is the empty string.


[opt_def -proc-command string]

The name of the Tcl command used to define procedures (methods ...),
per the chosen framework (template).
The default value is [const proc].


[opt_def -namespace string]

The name of the namespace the parser procedures (methods, ...) shall
reside in, including the trailing '::' needed to separate it from the
actual procedure name.

The default value is [const ::].


[opt_def -main string]

The name of the main procedure (method, ...) to be called by the
chosen framework (template) to start parsing input.

The default value is [const __main].


[opt_def -prelude string]

A snippet of code to be insert at the head of each generated parsing
command.

The default value is the empty string.


[opt_def -indent integer]

The number of characters to indent each line of the generated code by.

The default value is [const 0].

[list_end]

While the high parameterizability of this converter, as shown by the
multitude of options it supports, is an advantage to the advanced
user, allowing her to customize the output of the converter as needed,
a novice user will likely not see the forest for the trees.

[para]

To help these latter users two adjunct packages are provided, each
containing a canned configuration which will generate immediately
useful full parsers. These are

[list_begin definitions]
[def [package pt::tclparam::configuration::snit]]

Generated parsers are classes based on the [package snit] package,
i.e. snit::type's.

[def [package pt::tclparam::configuration::tcloo]]

Generated parsers are classes based on the [package OO] package.

[list_end]

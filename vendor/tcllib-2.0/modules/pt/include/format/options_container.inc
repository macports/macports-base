[list_begin options]
[include options_std.inc]

[opt_def -mode [const bulk]|[const incremental]]

The value of this option controls which methods of

[package pt::peg::container] instances are used to specify the
grammar, i.e. preload it into the container. There are two legal
values, as listed below. The default is [const bulk].

[list_begin definitions]
[def [const bulk]]

In this mode the methods [method start], [method add], [method modes],
and [method rules] are used to specify the grammar in a bulk manner,
i.e. as a set of nonterminal symbols, and two dictionaries mapping
from the symbols to their semantic modes and parsing expressions.

[para]

This mode is the default.

[def [const incremental]]

In this mode the methods [method start], [method add], [method mode],
and [method rule] are used to specify the grammar piecemal, with each
nonterminal having its own block of defining commands.

[list_end]

[opt_def -template string]

The value of this option is a string into which to put the generated
code and the other configuration settings. The various locations for
user-data are expected to be specified with the placeholders listed
below. The default value is "[const @code@]".

[list_begin definitions]

[def [const @user@]]
To be replaced with the value of the option [option -user].

[def [const @format@]]
To be replaced with the the constant [const CONTAINER].

[def [const @file@]]
To be replaced with the value of the option [option -file].

[def [const @name@]]
To be replaced with the value of the option [option -name].

[def [const @mode@]]
To be replaced with the value of the option [option -mode].

[def [const @code@]]
To be replaced with the generated code.

[list_end]
[list_end]

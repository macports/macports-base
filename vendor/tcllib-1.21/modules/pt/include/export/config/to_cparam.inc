
[section Options]

The converter to C code recognizes the following configuration
variables and changes its behaviour as they specify.

[include ../../format/options_cparam_rawc.inc]

While the high parameterizability of this converter, as shown by the
multitude of options it supports, is an advantage to the advanced
user, allowing her to customize the output of the converter as needed,
a novice user will likely not see the forest for the trees.

[para]

To help these latter users an adjunct package is provided, containing
a canned configuration which will generate immediately useful full
parsers. It is

[list_begin definitions]
[def [package pt::cparam::configuration::critcl]]

Generated parsers are embedded into a [package Critcl]-based framework.

[list_end]

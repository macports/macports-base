[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin pt::peg::to::[vset PACKAGE] n [vset VERSION]]
[include ../module.inc]
[include ../keywords_convert.inc]
[titledesc "PEG Conversion. Write [vset NAME] format"]
[require pt::peg::to::[vset PACKAGE] [opt [vset VERSION]]]
[include format/[vset REQUIRE].inc]
[description]
[include ../ref_intro.inc]

This package implements the converter from parsing expression grammars
to [vset NAME] markup.

[para]

It resides in the Export section of the Core Layer of Parser Tools,
and can be used either directly with the other packages of this layer,
or indirectly through the export manager provided by
[package pt::peg::export]. The latter is intented for use in untrusted
environments and done through the corresponding export plugin
[package pt::peg::export::[vset PACKAGE]] sitting between converter
and export manager.

[para][image arch_core_eplugins][para]


[section API]

The API provided by this package satisfies the specification of the
Converter API found in the [manpage {Parser Tools Export API}]
specification.


[list_begin definitions]

[call [cmd pt::peg::to::[vset PACKAGE]] [method reset]]

This command resets the configuration of the package to its default
settings.

[call [cmd pt::peg::to::[vset PACKAGE]] [method configure]]

This command returns a dictionary containing the current configuration
of the package.

[call [cmd pt::peg::to::[vset PACKAGE]] [method configure] [arg option]]

This command returns the current value of the specified configuration
[arg option] of the package. For the set of legal options, please read
the section [sectref Options].

[call [cmd pt::peg::to::[vset PACKAGE]] [method configure] [arg option] [arg value]...]

This command sets the given configuration [arg option]s of the
package, to the specified [arg value]s. For the set of legal options,
please read the section [sectref Options].

[call [cmd pt::peg::to::[vset PACKAGE]] [method convert] [arg serial]]

This command takes the canonical serialization of a parsing expression
grammar, as specified in section [sectref {PEG serialization format}],
and contained in [arg serial], and generates [vset NAME] markup
encoding the grammar, per the current package configuration.

The created string is then returned as the result of the command.

[list_end]

[vset TPREFIX {}]
[include config/to_[vset CONFIG].inc]
[include ../format/[vset PACKAGE].inc]
[include ../serial/pegrammar.inc]
[include ../serial/pexpression.inc]
[include ../feedback.inc]
[manpage_end]

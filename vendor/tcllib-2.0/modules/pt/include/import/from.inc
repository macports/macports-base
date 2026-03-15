[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin pt::peg::from::[vset PACKAGE] n [vset VERSION]]
[include ../module.inc]
[include ../keywords_convert.inc]
[titledesc "PEG Conversion. Read [vset NAME] format"]
[require pt::peg::from::[vset PACKAGE] [opt [vset VERSION]]]
[include format/[vset REQUIRE].inc]
[description]
[include ../ref_intro.inc]

This package implements the converter from [vset NAME] markup to
parsing expression grammars.

[para]

It resides in the Import section of the Core Layer of Parser Tools,
and can be used either directly with the other packages of this layer,
or indirectly through the import manager provided by
[package pt::peg::import]. The latter is intented for use in untrusted
environments and done through the corresponding import plugin
[package pt::peg::import::[vset PACKAGE]] sitting between converter
and import manager.

[para][image arch_core_iplugins][para]

[section API]

The API provided by this package satisfies the specification of the
Converter API found in the [manpage {Parser Tools Import API}]
specification.

[list_begin definitions]

[call [cmd pt::peg::from::[vset PACKAGE]] [method convert] [arg text]]

This command takes the [vset NAME] markup encoding a parsing
expression grammar and contained in [arg text], and generates the
canonical serialization of said grammar, as specified in section
[sectref {PEG serialization format}].

The created value is then returned as the result of the command.

[list_end]

[include ../format/[vset PACKAGE].inc]
[include ../serial/pegrammar.inc]
[include ../serial/pexpression.inc]
[include ../feedback.inc]
[manpage_end]

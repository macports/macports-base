[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin pt::peg::import::[vset PACKAGE] n [vset VERSION]]
[include ../module.inc]
[include ../keywords_import.inc]
[titledesc "PEG Import Plugin. Read [vset NAME] format"]
[require pt::peg::import::[vset PACKAGE] [opt [vset VERSION]]]
[require pt::peg::to::[vset PACKAGE]]
[description]
[include ../ref_intro.inc]

This package implements the parsing expression grammar import plugin
processing [vset NAME] markup.

[para]

It resides in the Import section of the Core Layer of Parser Tools and
is intended to be used by [package pt::peg::import], the import
manager, sitting between it and the corresponding core conversion
functionality provided by [package pt::peg::from::[vset PACKAGE]].

[para][image arch_core_iplugins][para]
[para]

While the direct use of this package with a regular interpreter is
possible, this is strongly disrecommended and requires a number of
contortions to provide the expected environment.

The proper way to use this functionality depends on the situation:

[list_begin enumerated]
[enum]

In an untrusted environment the proper access is through the package
[package pt::peg::import] and the import manager objects it
provides.

[enum]

In a trusted environment however simply use the package
[package pt::peg::from::[vset PACKAGE]] and access the core
conversion functionality directly.

[list_end]


[section API]

The API provided by this package satisfies the specification of the
Plugin API found in the [manpage {Parser Tools Import API}]
specification.

[list_begin definitions]

[call [cmd import] [arg text]]

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

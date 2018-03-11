[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin doctools::toc::import::[vset PACKAGE] n 0.1]
[copyright {2009 Andreas Kupries <andreas_kupries@users.sourceforge.net>}]
[moddesc   {Documentation tools}]
[titledesc "[vset NAME] import plugin"]
[category  {Text formatter plugin}]
[require Tcl 8.4]
[require doctools::toc::import::[vset PACKAGE] [opt 0.1]]
[include format/[vset REQUIRE].inc]
[keywords doctools toc {table of contents} deserialization import [vset NAME]]
[description]

This package implements the doctools table of contents import plugin
for the parsing of [vset NAME] markup.

[para]

This is an internal package of doctools, for use by the higher level
management packages handling tables of contents, especially [package \
doctools::toc::import], the import manager.

[para]

Using it from a regular interpreter is possible, however only with
contortions, and is not recommended.

The proper way to use this functionality is through the package
[package doctools::toc::import] and the import manager objects it
provides.


[section API]

The API provided by this package satisfies the specification of the
doctoc import plugin API version 2.

[list_begin definitions]

[call [cmd import] [arg string] [arg configuration]]

This command takes the [arg string] and parses it as [vset NAME]
markup encoding a table of contents, in the context of the specified
[arg configuration] (a dictionary). The result of the command is the
canonical serialization of that table of contents, in the form
specified in section [sectref {ToC serialization format}].

[list_end]


[include config/[vset CONFIG].inc]
[include ../serialization.inc]

[vset CATEGORY doctools]
[include ../../../doctools2base/include/feedback.inc]
[manpage_end]

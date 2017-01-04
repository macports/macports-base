[comment {-*- tcl -*- --- !doctools ---}]
[manpage_begin doctools::toc::export::[vset PACKAGE] n [vset VERSION]]
[copyright {2009 Andreas Kupries <andreas_kupries@users.sourceforge.net>}]
[moddesc   {Documentation tools}]
[titledesc "[vset NAME] export plugin"]
[category  {Text formatter plugin}]
[require Tcl 8.4]
[require doctools::toc::export::[vset PACKAGE] [opt [vset VERSION]]]
[include format/[vset REQUIRE].inc]
[keywords doctools toc {table of contents} serialization export [vset NAME]]
[description]

This package implements the doctools table of contents export plugin
for the generation of [vset NAME] markup.

[para]

This is an internal package of doctools, for use by the higher level
management packages handling tables of contents, especially [package \
doctools::toc::export], the export manager.

[para]

Using it from a regular interpreter is possible, however only with
contortions, and is not recommended.

The proper way to use this functionality is through the package
[package doctools::toc::export] and the export manager objects it
provides.


[section API]

The API provided by this package satisfies the specification of the
doctoc export plugin API version 2.

[list_begin definitions]

[call [cmd export] [arg serial] [arg configuration]]

This command takes the canonical serialization of a table of contents,
as specified in section [sectref {ToC serialization format}], and
contained in [arg serial], the [arg configuration], a dictionary, and
generates [vset NAME] markup encoding the table.

The created string is then returned as the result of the command.

[list_end]

[include config/[vset CONFIG].inc]
[include ../serialization.inc]

[vset CATEGORY doctools]
[include ../../../doctools2base/include/feedback.inc]
[manpage_end]

[include 307.inc]
[include 306.inc]
[include 305.inc]
[include 304.inc]
[include 303.inc]
[include 302.inc]
[include 301.inc]

[section {Changes for version 3}]
[list_begin enumerated]

[enum] The command [cmd critcl::platform] was deprecated in version
2.1, superceded by [cmd critcl::targetplatform], yet kept for
compatibility. Now it has been removed.

[enum] The command [cmd critcl::compiled] was kept with in version 2.1
with semantics in contradiction to its, for compatibility. This
contradiction has been removed, changing the visible semantics of the
command to be in line with its name.

[enum] The change to version 3 became necessary because of the two
incompatible visible changes above.

[enum] Extended the application package with code handling a new
option [option -tea]. Specifying this option invokes a special mode
where critcl generates a TEA package, i.e. wraps the input into a
directory hierarchy and support files which provide it TEA-lookalike
buildsystem.

[para] This new option, and [option -pkg], exclude each other. If
both are specified the last used option takes precedence.

[para] The generated package directory hierarchy is mostly
self-contained, but not fully. It requires not only a working
installation of Tcl, but also working installations of the packages
[package md5] and [package cmdline]. Both of these are provided by the
[package Tcllib] bundle. Not required, but recommended to have
installed are any of the packages which can accelerate md5's
operation, i.e. [package cryptkit], [package tcllibc], or
[package Trf].

[enum] Extended the critcl package with a new command
[cmd critcl::scan] taking the path to a [file .critcl] file,
statically scanning it, and returning license, version, a list of its
companion files, list of imported APIs, and list of
developer-specified custom configuration options. This data is the
foundation for the TEA wrapping described above.

[para] Note that this is a [emph static] scan. While the other build
modes can (must) execute the [file .critcl] file and make
platform-specific decisions regarding the assembled C code, companion
files, etc. the TEA wrap mode is not in a position to make
platform-specific decisions. It has to wrap everything which might
conceivably be needed when actually building. Hence the static scan.

This has however its own set of problems, namely the inability to
figure out any dynamic construction of companion file paths, at least
on its own. Thus:

[enum] Extended the API used by critcl-based packages with the command
[cmd critcl::owns]. While this command is ignored by the regular build
modes the static scanner described above takes its arguments as the
names of companion files which have to be wrapped into the TEA package
and could not be figured by the scanner otherwise, like because of
dynamic paths to [cmd critcl::tsources], [cmd critcl::csources],
getting sourced directly, or simply being adjunct datafiles.

[enum] Extended the API used by critcl-based packages with the command
[cmd critcl::api] for the management of stubs tables, be it their use,
and/or declaration and export.

[para] Please see section [emph {Stubs Table Management}] of the
[package critcl] package documentation for details.

[enum] Extended the API used by critcl-based packages with the command
[cmd critcl::userconfig] for the management of developer-specified
custom configuration options, be it their use and/or declaration.

[para] Please see section [emph {Custom Build Configuration}] of the
[package critcl] package documentation for details.

[enum] Extended the API used by critcl-based packages with the
commands [cmd critcl::description], [cmd critcl::summary],
[cmd critcl::subject], [cmd critcl::meta], and
[cmd critcl::buildrequirement] for the declaration of TEApot meta data
for/about the package.

[para] Please see section [emph {Package Meta Data}] of the
[package critcl] package documentation for details.

[list_end]

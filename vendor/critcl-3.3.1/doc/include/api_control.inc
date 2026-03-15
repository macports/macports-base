
These commands control the details of compilation and linking a
[vset critcl_script].  The information is used only to compile/link the
object for the [vset critcl_script].  For example, information for
[file FOO.tcl] is kept separate from information for [file BAR.tcl].

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cheaders] [opt [arg arg]...]]

Provides additional header locations.

[para] Each argument is a glob pattern.  If an argument begins with [const -]
it is an argument to the compiler.  Otherwise the parent directory of each
matching path is a directory to be searched for header files.  Returns an
error if a pattern matches no files.

[vset relative_pattern]

[para] [const {#include}] lines are not automatically generated for matching
header files.  Use [cmd critcl::include] or [cmd critcl::ccode] as necessary to
add them.

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::csources] [opt [arg {glob pattern}]...]]

Matching paths become inputs to the compilation of the current object
along with the sources for the current [vset critcl_script].  Returns an
error if no paths match a pattern.

[vset relative_pattern]

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::clibraries] [opt [arg {glob pattern}]...]]

provides the link step with additional libraries and library locations.

A [arg {glob pattern}] that begins with [const -] is added as an argument to
the linker.  Otherwise matching files are linked into the shared library.
Returns an error if no paths match a pattern.

[vset relative_pattern]

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::source] [arg {glob pattern}]]

Evaluates as scripts the files matching each [arg {glob pattern}].  Returns an
error if there are no matching files.

[vset relative_pattern]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::tsources] [arg {glob pattern}]...]

Provides the information about additional Tcl script files to source when the
shared library is loaded.

[para] Matching paths are made available to the generated shared library when
it is loaded for the current [vset critcl_script].  Returns an error if a
pattern matches no files.

[vset relative_pattern]

[para] [vset cumulative]

[para] After the shared library has been loaded, the declared files are sourced
in the same order that they were provided as arguments.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::owns] [arg {glob pattern}]...]

Ignored in "compile and run" and "generate package" modes.

In "generate TEA" mode each file matching a [arg {glob pattern}] is a file to
be included in the TEA extension but that could not be ascertained as such from
previous commands like [cmd critcl::csources] and [cmd critcl::tsources],
either because of they were specified dynamically or because they were directly
sourced.


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cflags] [opt [arg arg]...]]

[para] Each [arg arg] is an argument to the compiler.

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::ldflags] [opt [arg arg]...]]

[para] Each [arg arg] is an argument to the linker.

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::framework] [opt [arg arg]...]]

Each [arg arg] is the name of a framework to link on MacOS X.  This command is
ignored if OS X is not the target so that frameworks can be specified
unconditionally.

[para] [vset cumulative]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::tcl] [arg version]]

Specifies the minimum version of the Tcl runtime
to compile and link the package for.  The default is [const 8.4].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::tk]]

Arranges to include the Tk headers and link to the Tk stubs.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::preload] [arg lib]...]

Arranges for the external shared library [arg lib] to be loaded
before the shared library for the [vset critcl_script] is loaded.

[para] [vset cumulative]

[para][include preload_search.inc]

[comment {
	XXX preload - compile & run - will it work ?
}]

For developers who want to understand or modify the internals of the
[package critcl] package, [sectref {Preloading functionality}] explains how
preloading is implemented.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::debug] [arg area]...]

Specifies what debugging features to activate. Internally each area is translated into
area-specific flags for the compiler which are then handed over to
[cmd critcl::cflags].

[list_begin definitions]
[def [const memory]]

Specifies Tcl memory debugging.

[def [const symbols]]

Specifies compilation and linking with debugging symbols for use by a debugger
or other tool.

[def [const all]]

Specifies all available debugging.

[list_end]
[list_end]

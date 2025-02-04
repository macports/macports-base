[section {Changes for version 2.1}]
[list_begin enumerated]

[enum] Fixed bug where [cmd critcl::tsources] interpreted relative
paths as relative to the current working directory instead of
relative to the [file .critcl] file using the command, as all other
commands of this type do.

[enum] Fixed internals, preventing information collected for multiple
[file .critcl] files to leak between them. Notably, [cmd critcl::tk]
is not a global configuration option anymore.

[enum] Fixed the command [cmd critcl::license] to be a null-operation
in mode "compile & run", instead of throwing an error.

[enum] Fixed the critcl application's interference with the "compile &
run" result cache in [option -pkg] mode by having it use a wholly
separate (and by default transient) directory for that mode.

[enum] Fixed bug where changes to a [file .critcl] file did not result
in a rebuild for mode "compile & run". All relevant API commands now
ensure UUID changes.

[enum] Fixed bug in the backend handling of [cmd critcl::debug] where
the companion c-sources of a [file .critcl] file were not compiled
with debug options, although the [file .critcl] file was.

[enum] Fixed bug in [cmd critcl::debug] which prevented recognition of
mode "all" when it was not the first argument to the command.

[enum] Fixed bug in [file preload.c] preventing its compilation on
non-windows platforms.

[enum] Fixed long-standing bug in the handling of namespace qualifiers
in the command name argument of [cmd critcl::cproc] and
[cmd critcl::ccommand]. It is now possible to specify a fully
qualified command name without issues.

[enum] Extended/reworked [cmd critcl::tsources] to be the canonical
way of declaring [file .tcl] companion files even for mode "compile &
run".

[enum] Extended/reworked [cmd critcl::tsources] to allow the use of a
[file .critcl] file as its own Tcl companion file.

[enum] Extended [cmd critcl::framework] to internally check for OS X
build target, and to ignore the declaration if its not.

[enum] Extended [cmd critcl::failed] to be callable more than once in
a [file .critcl] file. The first call forces the build, if it was not
done already, to get the result. Further calls return the cached
result of the first call.

[enum] Extended the handling of environment variable CC in the code
determining the compiler to use to deal with (i.e. remove) paths to
the compiler, compiler file extensions, and compiler options specified
after the compiler itself, leaving only the bare name of the compiler.

[enum] Extended the code handling the search for preloaded libraries
to print the paths it searched, making debugging of a search failure
easier.

[enum] A new command [cmd critcl::tcl] can be used to declare the
version of Tcl minimally needed to build and run the [file .critcl]
file and package. Defaults to 8.4 if not declared. Extended critcl to
have the stubs and headers for all of Tcl 8.4, 8.5, and 8.6.

[enum] A new command [cmd critcl::load] forces the build and load of a
[file .critcl] file. This is the official way for overriding critcl's
default lazy-build-&-load-on-demand scheme for mode "compile & run".

[para] [emph Note] that after using [cmd critcl::load] /
[cmd critcl::failed] in a [file .critcl] file it is not possible to
use critcl commands in that file anymore. Doing so will throw an
error.

[enum] Extended the generation of '#line' pragmas to use
[cmd {info frame}] (if available) to provide the C compiler with exact
line numbers into the [file .critcl] file for the reporting of
warnings and errors.

[enum] Extended [cmd critcl::check] with logging to help with
debugging build-time checks of the environment, plus an additional
optional argument to provide labeling.

[enum] Added a new command [cmd critcl::checklink] which not only
tries to check the environment via compiling the code, but also
its linkability.

[enum] Added a new command [cmd critcl::msg] for messaging, like
command [cmd critcl::error] is for error reporting. Likewise this is a
hook a user of the package is allowed to override. The default
implementation, used by mode [term {compile & run}] does nothing. The
implementation for mode [term {generate package}] prints the message
to stdout.

[para] Envisioned use is for the reporting of results determined by
[cmd critcl::check] and [cmd critcl::checklink] during building, to
help with debugging when something goes wrong with a check.

[enum] Exposed the argument processing internals of [cmd critcl::proc]
for use by advanced users. The new commands are

[list_begin enum]
[enum] [cmd critcl::argnames]
[enum] [cmd critcl::argcnames]
[enum] [cmd critcl::argcsignature]
[enum] [cmd critcl::argvardecls]
[enum] [cmd critcl::argconversion]
[list_end]

Please see section [emph {Advanced Embedded C Code}] of the
[package critcl] package documentation for details.

[enum] Extended the critcl package to intercept [cmd {package
provide}] and record the file -> package name mapping. Plus other
internal changes now allow the use of namespaced package names while
still using proper path names and init function.

[enum] Dropped the unused commands [cmd critcl::optimize] and
[cmd critcl::include].

[enum] Dropped [option -lib] mode from the critcl application.

[enum] Dropped remnants of support for Tcl 8.3 and before.

[list_end]

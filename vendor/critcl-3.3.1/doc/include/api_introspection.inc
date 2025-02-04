
The following commands control compilation and linking.

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::check] [opt [arg label]] [arg text]]

Returns a [const true] if the C code in [arg text] compiles sucessfully, and
[const false] otherwise.  Used to check for availability of features in the
build environment.

If provided, [arg label] is used to uniquely mark the results in the generated
log.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::checklink] [opt [arg label]] [arg text]]

Like [cmd critcl::check] but also links the compiled objects, returning
[const true] if the link is successful and [const false] otherwise.

If specified, [arg label] is used to uniquely mark the results in the generated
log.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::msg] [opt [option -nonewline]] [arg msg]]

Scripts using [cmd critcl::check] and [cmd critcl::checklink] can use this
command to report results.  Does nothing in [term {compile & run}] mode.  Tools
like the [manpage {CriTcl Aplication}] may redefine this command to implement
their own message reporting. For example, [package critcl::app] and any
packages built on it print messages to [term stdout].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::print] [opt [option -nonewline]] [opt [arg chan]] [arg msg]]

Used by the CriTcl internals to report activity.  By default, effectively the
same thing as [cmd ::puts].  Tools directly using either the CriTcl package or
the CriTcl application package may redefine this procedure to implement their
own output functionality.

[para] For example, the newest revisions of
[uri https://chiselapp.com/user/andreas_kupries/repository/Kettle/index Kettle]
use this to highlight build warnings.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::compiled]]

Returns [const true] if the current [vset critcl_script] is already compiled
and [const false] otherwise.

[para] Enables a [vset critcl_script] used as its own Tcl companion file (see
[cmd critcl::tsources]) to distinguish between being sourced for compilation in
[term {compile & run}] mode and being sourced from either the result of
[term {generate package}] mode or during the load phase of
[term {compile & run}] mode.

The result is [const false] in the first case and [const true] in the later two
cases.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::compiling]]

Returns [const true] if a working C compiler is available and [const false]
otherwise.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::done]]

Returns [const true] when [vset critcl_script] has been built and
[const false] otherwise.  Only useful from within a [vset critcl_script].
Enables the Tcl parts of a [vset critcl_script] to distinguish between
[term {prebuilt package}] mode and [term {compile & run}] mode.

[para] See also [sectref {Modes Of Operation/Use}].

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::failed]]

Returns [const true] if the [vset critcl_script] could not be built, and
[const false] otherwise.  Forces the building of the package if it hasn't
already been done, but not its loading.  Thus, a [vset critcl_script] can
check itself for availability of the compiled components.  Only useful from
within a [vset critcl_script].


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::load]]

Like [cmd critcl::failed] except that it also forces the loading of the
generated shared library, and that it returns [const true] on success and
[const false] on failure.  Thus, a [vset critcl_script] can check itself for
availability of the compiled components.  Only useful from within a
[vset critcl_script].

[list_end]

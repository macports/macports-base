
The following command manages global settings, i.e. configuration options which
are independent of any [vset critcl_script].

[para] This command should not be needed to write a [vset critcl_script]. It is
a management command which is only useful to the [manpage {CriTcl Application}]
or similar tools.

[list_begin definitions]

[call [cmd ::critcl::config] [arg option] [opt [arg val]]]

Sets and returns the following global configuration options:

[list_begin options]
[opt_def force bool]

When [const false] (the default), the C files are not built if there is a
cached shared library.

[opt_def lines bool]

When [const true] (the default), #line directives are embedded into the
generated C code.

[include rq_cline.inc]

[para] Developers of higher-level packages generating their own C
code, either directly or indirectly through critcl, should
also read section [sectref {Advanced: Location management}] to see how
critcl helps them in generating their directives.

Examples of such packages come with critcl itself. See
[package critcl::iassoc] and [package critcl::class].

[opt_def trace bool]

When [const false] (the default), no code tracing the entry and exit of
CriTcl-backed commands in the [vset critcl_script] is inserted.  Insertion of
such code implicitly activates the tracing facility in general.  See
[package critcl::cutil].

[opt_def I path]

A single global include path to use for all files. Not set by default.

[opt_def combine enum]
[list_begin definitions]
[def "[const dynamic] (the default)"]

Object files have the suffix [const _pic].

[def [const static]]

Object files have the suffix [const _stub].

[def [const standalone]]

Object files have no suffix, and the generated C files are compiled
without using Tcl/Tk stubs. The result are object files usable for
static linking into a [term {big shell}].

[list_end]


[opt_def language string]
[opt_def keepsrc bool]

When [const false] (the default), the generated [file .c]
files are deleted after the [file .o] files have been built.


[opt_def outdir directory]

The directory where to place a generated shared library. By default, it is
placed into the [sectref {Result Cache}].

[list_end]
[list_end]

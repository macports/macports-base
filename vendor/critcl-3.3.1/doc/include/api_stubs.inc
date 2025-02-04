
CriTcl versions 3 and later provide [cmd critcl::api] to create and manipulate
stubs tables, Tcl's dynamic linking mechanism handling the resolution of
symbols between C extensions.

See [uri http://wiki.tcl-lang.org/285]
for an introduction, and section [sectref {Stubs Tables}]
for the details of CriTcl's particular variant.

[para]
Importing stubs tables, i.e. APIs, from another extension:

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::api] [method import] [arg name] [arg version]]

Adds the following include directives into the [vset critcl_script]
[emph and] each of its companion [file .c] files:

[list_begin enumerated]
[enum] #include <[var name]/[var name]Decls.h>
[enum] #include <[var name]/[var name]StubLib.h>
[list_end]

Returns an error if [file [var name]] isn't in the search path for the
compiler.  See [cmd critcl::cheaders] and the critcl application's [option -I]
and [option -includedir] options.

[para] [emph Important:] If [var name] is a fully-qualified name in a
non-global namespace, e.g.
"c::stack", the namespace separators "::" are converted into underscores
("_") in path names, C code, etc.

[para] [var name]/[var name]Decls.h contains the stubs table type declarations,
mapping macros, etc., and may include package-specific headers.  See
[cmd {critcl::api header}], below.  An [term {#include}] directive is added at
the beginning of the generated code for [vset critcl_script] and at the
beginning of each of its companion [file .c] files.

[para] [var name]/[var name]StubLib.h contains the stubs table variable
definition and the function to initialize it.  An [term {#include}] directive
for it is added to the initialization code for the [vset critcl_script] ,
along with a call to the initializer function.

[para] If [file [var name]/[var name].decls] accompanies
[var name]/[var name]Decls.h, it should contain the external representation of
the stubs table used to generate the headers. The file is read and the internal
representation of the stubs table returned for use by the importing package.
Otherwise, the empy string is returned.

[para] One possible use would be the automatic generation of C code
calling on the functions listed in the imported API.

[para] When generating a TEA package the names of the imported APIs
are used to declare [syscmd configure] options with which the user can
declare a non-standard directory for the headers of the API. Any API
[var name] is translated into a single configure option
[option --with-[var name]-include].

[list_end]


[para] Declaration and export of a stubs table, i.e. API, for
the [vset critcl_script]:

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::api] [method function] [arg resulttype] [arg name] [arg arguments]]

Adds to the public API of the [vset critcl_script] the signature
for the function named [arg name] and having the signature specified by
[arg arguments] and [arg resulttype].  Code is generated for a [file .decls]
file, the corresponding public headers, and a stubs table usable by
[cmd {critcl::api import}].

[para] [arg arguments] is a multidict where each key is an argument type and its
value is the argument name, and [arg resulttype] is a C type.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::api] [method header] [opt [arg {glob pattern}]...]]

Each file matching a [arg {glob pattern}] is copied into the directory
containing the generated headers, and an [term {#include}] directive for it is
added to [file Decls.h] for the [vset critcl_script].

Returns an error if a [arg {glob pattern}] matches nothing.

[para] [vset relative_pattern]

[comment {
	I am intentionally not documenting "critcl::api export".
	I am not convinced yet that this method is needed.
	The default, using the package name as the stubs table
	library and interface names seems to me to be not only
	reasonable, but the only setting truly needed. I simply
	do not see a use case for having the library and interface
	named different than the package.
	(In a bundle, like tcllibc each bundled package still declares
	itself properly).
}]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::api] [method extheader] [opt [arg file]...]]

Like [cmd {::critcl::api header}], but each [arg file] should exist in the
external development environment.  An [term {#include}] directive is added to
[file [var foo]Decls.h], but [arg file] is not copied to the package header
directory. [arg file] is not a glob pattern as CriTcl has no context,
i.e directory, in which to expand such patterns.

[list_end]

As with the headers for an imported API, an [term {#include}] directive is
added to the generated code for the [vset critcl_script] and to
each companion [file .c] file.

[para] In "compile & run" mode the generated header files and any companion
headers are placed in the [sectref {Result Cache}] subdirectory for the
[vset critcl_script]. This directory is added to the include search path of
any other package importing this API and and building in mode "compile & run".

[para] In "generate package" mode [option -includedir] specifies the
subdirectory in the package to place the generated headers in. This
directory is added to the search paths for header files, ensuring that a
package importing an API finds it if the package exporting that API used the
same setting for [option -includedir].

[para] In "generate TEA" mode the static scanner recognizes
[cmd {critcl::api header}] as a source of companion files.
It also uses data from calls to [cmd {critcl::api import}] to
add support for [option --with-[var foo]-include] options into the
generated [file configure(.in)] so that a user may specify custom
locations for the headers of any imported API.

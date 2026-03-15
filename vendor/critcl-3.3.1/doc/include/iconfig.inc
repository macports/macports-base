[include skip.inc]

It explains the syntax of configuration files and the configuration
keys used by [package critcl] to configure its build backend, i.e. how
this part of the system accesses compiler, linker, etc.

[para]

It is recommended to open the file containing the standard
configurations ([file path/to/critcl/Config]) in the editor of your
choice when reading this section of the documentation, using it as an
extended set of examples going beyond the simple defaults shown here.

[para]

First, the keys and the meaning of their values, plus examples drawn
from the standard configurations distributed with the package.

Note that when writing a custom configuration it is not necessary to
specify all the keys listed below, but only those whose default values
are wrong or insufficient for the platform in question.

[list_begin definitions]
[comment {============================================================}]
[def version]
The command to print the compiler version number.
Defaults to [example { gcc -v }]

[comment {============================================================}]
[def compile]
The command to compile a single C source file to an object file.
Defaults to [example { gcc -c -fPIC }]

[comment {============================================================}]
[def debug_memory]
The list of flags for the compiler to enable memory debugging in
Tcl.
Defaults to [example { -DTCL_MEM_DEBUG }]

[comment {============================================================}]
[def debug_symbols]
The list of flags for the compiler to add symbols to the object files
and the resulting library.
Defaults to [example { -g }]

[comment {============================================================}]
[def include]
The compiler flag to add an include directory.
Defaults to [example { -I }]

[comment {============================================================}]
[def tclstubs]
The compiler flag to set USE_TCL_STUBS.
Defaults to [example { -DUSE_TCL_STUBS }]

[comment {============================================================}]
[def tkstubs]
The compiler flag to set USE_TK_STUBS.
Defaults to [example { -DUSE_TK_STUBS }]

[comment {============================================================}]
[def threadflags]
The list of compiler flags to enable a threaded build.
Defaults to [example {
    -DUSE_THREAD_ALLOC=1 -D_REENTRANT=1 -D_THREAD_SAFE=1
    -DHAVE_PTHREAD_ATTR_SETSTACKSIZE=1 -DHAVE_READDIR_R=1
    -DTCL_THREADS=1
}].

[comment {============================================================}]
[def noassert]
The compiler flag to turn off assertions in Tcl code.
Defaults to [example { -DNDEBUG }]

[comment {============================================================}]
[def optimize]
The compiler flag to specify optimization level.
Defaults to [example { -O2 }]

[comment {============================================================}]
[def output]
The compiler flags to set the output file of a compilation.
Defaults to [example { -o [list $outfile] }]

[para] [emph NOTE] the use of Tcl commands and variables here.  At the
time [package critcl] uses the value of this key the value of the
referenced variable is substituted into it. The named variable is the
only variable whose value is defined for this substitution.

[comment {============================================================}]
[def object]
The file extension for object files on the platform.
Defaults to [example { .o }]

[comment {============================================================}]
[def preproc_define]
The command to preprocess a C source file without compiling it, but
leaving #define's in the output. Defaults to [example { gcc -E -dM }]

[comment {============================================================}]
[def preproc_enum]
See [const preproc_define], except that #define's are not left in the
output. Defaults to [example { gcc -E }]

[comment {============================================================}]
[def link]
The command to link one or more object files and create a shared
library. Defaults to [example { gcc -shared }]

[comment {============================================================}]
[def link_preload]
The list of linker flags to use when dependent libraries are
pre-loaded. Defaults to
[example { --unresolved-symbols=ignore-in-shared-libs }]

[comment {============================================================}]
[def strip]
The flag to tell the linker to strip symbols from the shared library.
Defaults to [example { -Wl,-s }]


[comment {============================================================}]
[def ldoutput]
Like [const output], but for the linker.
Defaults to the value of [const output].

[comment {============================================================}]
[def link_debug]
The list of linker flags needed to build a shared library with
symbols. Defaults to the empty string.

One platform requiring this are all variants of Windows, which uses
[example { -debug:full -debugtype:cv }]

[comment {============================================================}]
[def link_release]
The list of linker flags needed to build a shared library without
symbols, i.e. a regular build. Defaults to the empty string.

One platform requiring this are all variants of Windows, which uses
[example { -release -opt:ref -opt:icf,3 -ws:aggressive }]

[comment {============================================================}]
[def sharedlibext]
The file extension for shared library files on the platform.
Defaults to [example { [info sharedlibextension] }]

[comment {============================================================}]
[def platform]
The identifier of the platform used in generated packages.
Defaults to [example { [platform::generic] }]

[comment {============================================================}]
[def target]
The presence of this key marks the configuration as a
cross-compilation target and the value is the actual platform
identifier of the target.  No default.

[list_end]
[para]

The syntax expected from configuration files is governed by the rules below.

Again, it is recommended to open the file containing the standard
configurations ([file path/to/critcl/Config]) in the editor of your
choice when reading this section of the documentation, using it as an
extended set of examples for the syntax>

[list_begin enumerated]
[comment {============================================================}]
[enum] Each logical line of the configuration file consists of one or
more physical lines. In case of the latter the physical lines have to
follow each other and all but the first must be marked by a trailing
backslash. This is the same marker for [term {continuation lines}] as
used by Tcl itself.

[comment {============================================================}]
[enum] A (logical) line starting with the character "#" (modulo
whitespace) is a comment which runs until the end of the line, and is
otherwise ignored.

[comment {============================================================}]
[enum] A (logical) line starting with the word "if" (modulo
whitespace) is interpreted as Tcl's [cmd if] command and executed as
such. I.e. this command has to follow Tcl's syntax for the command,
which may stretch across multiple logical lines. The command will be
run in a save interpreter.

[comment {============================================================}]
[enum] A (logical) line starting with the word "set" (modulo
whitespace) is interpreted as Tcl's [cmd set] command and executed as
such. I.e. this command has to follow Tcl's syntax for the command,
which may stretch across multiple logical lines. The command will be
run in a save interpreter.

[comment {============================================================}]
[enum] A line of the form "[arg platform] [var variable] [arg value]"
defines a platform specific configuration variable and value.

The [var variable] has to be the name of one of the configuration keys
listed earlier in this section, and the [arg platform] string
identifies the platform the setting is for. All settings with the same
identification string form the [term {configuration block}] for this
platform.

[comment {============================================================}]
[enum] A line of the special form
"[arg platform] [const when] [arg expression]"
marks the [arg platform] and all the settings in its
[term {configuration block}] as conditional on the [arg expression].

[para]

If the build platform is not a prefix of [arg platform],
nor vice versa the whole block is ignored.

Otherwise the [arg expression] is evaluated via [cmd expr], in the
same safe interpreter used to run any [cmd set] and [cmd if] commands
found in the configuration file (see above).

[para]

If the expression evaluates to [const true] this configuration block
is considered to be the build platform fo the host and chosen as the
default configuration.

An large example of of this feature is the handling of OS X found in
the standard configuration file, where it selects the architectures to
build based on the version of the operating system, the available SDK,
etc. I.e. it chooses whether the output is universal or not, and
whether it is old-style (ix86 + ppc) versus new-style (ix86 32+64) of
universality.

[comment {============================================================}]
[enum] A line of the special form
"[arg platform] [const copy] [arg sourceplatform]"
copies the configuration variables and values currently defined in the
[term {configuration block}] for [arg sourceplatform] to that of
[arg platform], overwriting existing values, and creating missing
ones. Variables of [arg platform] not defined by by [arg sourceplatform]
are not touched.

[para] The copied values can be overridden later in the configuration
file. Multiple [const copy] lines may exist for a platform and be
intermixed with normal configuration definitions. Only the last definition of a
variable is used.

[comment {============================================================}]
[enum] At last, a line of the form "[var variable] [arg value]"
defines a default configuration variable and value.

[list_end]

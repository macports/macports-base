
[vset teaignored "
[para]
Ignored when generating a TEA package
(see option [option -tea] below).
"]

[vset validated_on_build "
[para] Validated only if one of the input files for the [vset critcl_script]
actually defines and uses a custom build configuration option with that
[arg name].
"]


The following options are understood:

[list_begin options]
[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -v]
[opt_def --version]

Print the version to [const stdout] and exit.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -I path]

Arranges for the compiler to search [arg path] for headers.
[vset cumulative_opt]

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -L path]

Arranges for the linker to search [arg path].
[vset cumulative_opt]

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -cache path]

Sets [arg path] as the directory to use as the result cache. The default is
[file ~/.critcl/<platform>], or [file ~/.critcl/<pid>.<epoch>] when generating
a package.  See option [option -pkg], below.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -clean]

Arranges for all files and directories in the result cache to be deleted before
compilation begins.

[para] Ignored when generating a package because this mode starts out with a
unique and empty result cache.  See option [option -pkg], below.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -config path]

Provides a custom configuration file.  By default a configuration included in
the system core is used.

When specified multiple times the last value is used.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -debug mode]

Activates one of the following debugging modes:


[list_begin definitions]
[def [const memory]]

Track and report memory allocations made by the Tcl core.

[def [const symbols]]

Compile all [file .c] files with debugging symbols.

[def [const all]]

Both [const memory] and [const symbols].

[list_end]

[vset teaignored]

[vset cumulative_opt]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -disable name]

Sets the value of the custom build configuration option
[arg name] to [const false]. It is equivalent to "-with-[arg name] 0".

[vset validated_on_build]

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -enable name]

Sets the value of the custom build configuration option
[arg name] to [const true]. It is equivalent to "-with-[arg name] 1".

[vset validated_on_build]

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -force]

Forces compilation even if a shared library for the file already exists.
Unlike cleaning the cache, this is lazy in the destruction of files and only
affects relevant files.

[para] Ignored when generating a package (see option [option -pkg], below),
which starts out with a unique and empty result cache.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -help]

Prints a short description of command line syntax and options and then exits
the application.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -keep]

Causes the system to cache compiled [file .c] files.

Also prevents the deletion of the unique result cache used by the run when
generating a package (see option [option -pkg] below),

Intended for debugging of [cmd critcl] itself, where it may be necessary to
inspect the generated C code.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -libdir directory]

Adds [arg directory] to the list of directories the linker searches for
libraries in (like [option -L]).  With [option -pkg], generated packages are
saved in [arg directory].

When specified multiple times the last value is used.

The default is [file lib], resolved relative to the current working directory.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -includedir directory]

Adds [arg directory] to the list of directories the compiler searches for
headers in. With [option -pkg], generated header files are saved in
[arg directory].

[vset cumulative_opt]

The last value is used as the destination for generated header files.

The default is the relative directory [file include], resolved relative to the
current working directory.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -pkg]

Generates a package from the [vset critcl_script] files.  Input files are
processed first as usual, but are then bundled into a single library, with
additional generated files to form the library into a standard Tcl package.

[para]

generation. If both options, i.e. [option -pkg] and [option -tea] are
specified the last one specified wins.

[para]

Options [option -clean] and [option -force] are ignored. [option -libdir] is
relevant in both this and [option -tea] mode.

[para]

[vset pkg_namerules]


[para] Examples:

[example {
	... -pkg ... foo

	=> Package name is: foo
	=> Input file is:   foo.tcl
}]

[example {
	... -pkg ... foo bar.tcl

	=> Package name is: foo
	=> Input file is:   bar.tcl
}]

[example {
	... -pkg ... foo.tcl

	=> Package name is: foo
	=> Input file is:   foo.tcl
}]

[example {
	... -pkg ... foo.so bar.tcl

	=> Package name is: foo
	=> Input file is:   bar.tcl
}]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -show]

Prints the configuration of the chosen target to [const stdout] and then exits.

Set [option -target], below.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -showall]

Prints the whole chosen configuration file to [const stdout] and then exits.

See [option -config], above.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -target name]

Overrides the default choice of build target.

Only the last occurrence of this option is used.

The named target must exist in the chosen configuration file.

Use [option -targets] (see below) to get a list of the
acceptable targets.

Use [option -config] to select the configuration file.

[vset teaignored]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -targets]

Prints the list of all known targets from the chosen configuration file to
[const stdout] and then exits.

Use [option -config] to select the configuration file.

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -tea]

Like [option -pkg], except no binaries are generated. Creates a directory
hierarchy containing the [vset critcl_script], its companion files, and a
TEA-conformant build system with most of the needed support code, including
copies of the critcl packages.

[para]

If both [option -pkg] and [option -tea] are specified the last occurrence wins.

[para]

[option -I], [option -L], [option -clean],
[option -force], [option -cache], [option -includedir], [option -enable],
[option -disable], and [option -with-[var FOO]] are
ignored. In contrast, the option [option -libdir] is relevant in both
this and [option -pkg] mode.

[para] [vset pkg_namerules]

[para] Examples:

[example {
	... -tea ... foo

	=> Package name is: foo
	=> Input file is:   foo.tcl
}]

[example {
	... -tea ... foo bar.tcl

	=> Package name is: foo
	=> Input file is:   bar.tcl
}]

[example {
	... -tea ... foo.tcl

	=> Package name is: foo
	=> Input file is:   foo.tcl
}]

[example {
	... -tea ... foo.so bar.tcl

	=> Package name is: foo
	=> Input file is:   bar.tcl
}]

[comment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%]
[opt_def -with-[var name] value]

This option sets the value of the custom build configuration option
[arg name] to [arg value].

[para] The information is validated only if one of the [file .critcl]
input files actually defines and uses a custom build configuration
option with that [arg name].

[vset teaignored]

[list_end]

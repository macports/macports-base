[vset ctlong [term {C Runtime In Tcl}]]
[vset critcl [term CriTcl]]
[vset critcl_script [term {CriTcl script}]]

[vset slogan "Adding C code to [vset tcl_home]/[vset tk_home] has never been easier."]

[vset cumulative     {Calls to this command are cumulative.}]
[vset cumulative_opt {Uses of this option are cumulative.}]

[vset not_needed_for_critcl_script "
These commands are not needed to simply write a [term {CriTcl script}].
"]

[vset pkg_namerules "
The basename of the first file is the name of the package to generate. If
its file extension indicates a shared library ([file .so], [file .sl],
[file .dylib], and [file .dll]) it is also removed from the set of input
files. Each [vset critcl_script] file is kept as part of the input. A single
file without a suffix is assumed to be a [vset critcl_script]. A file without
a suffix, but other input files following is treated like the name of a
shared library proper, and removed from the set of input files.
"]

[vset relative_pattern "
A pattern for a relative path is resolved relative to the directory
containing the [term {CriTcl script}].
"]

[vset relative_path "
A relative path is resolved relative to the directory
containing the [term {CriTcl script}].
"]


[vset see_overview "
	If you are in need of an overview of the whole system instead, please
	go and read the [manpage {Introduction To CriTcl}].
"]

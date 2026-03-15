
While file generation is related to the diversions explained in the
previous section they are not the same.

Even so, like diversions this feature is for higher-level packages
generating their own C code.

[para] Three examples of utility packages using this facility comes
with critcl itself.

See the implementations of packages [package critcl::literals],
[package critcl::bitmap], and [package critcl::enum].

[para] When splitting a package implementation into pieces it is often
sensible to have a number of pure C companion files containing
low-level code, yet these files may require information about the code
in the main [file .critcl] file. Such declarations are normally not
exportable and using the stub table support does not make sense, as
this is completely internal to the package.

[para] With the file generation command below the main [file .critcl]
file can generate any number of header files for the C companions to
pick up.

[list_begin definitions]
[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::make] [arg path] [arg contents]]

This command creates the file [arg path] in a location where the C
companion files of the package are able to pick it up by simple
inclusion of [arg path] during their compilation, without interfering
with the outer system at all.

[para] The generated file will contain the specified [arg contents].

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

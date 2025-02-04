[include skip.inc]

It explains how the preloading of external libraries is realized.

[para]

Whenever a package declares libraries for preloading critcl will build
a supporting shared library providing a Tcl package named "preload".
This package is not distributed separately, but as part of the package
requiring the preload functionality.

This support package exports a single Tcl command

[list_begin definitions]
[call [cmd ::preload] [arg library]]

which is invoked once per libraries to preload, with the absolute path
of that [arg library]. The command then loads the [arg library].

[para]

On windows the command will further use the Tcl command
[cmd ::critcl::runtime::precopy] to copy the [arg library] to the
disk, should its path be in a virtual filesystem which doesn't
directly support the loading of a shared library from it.

[list_end]

The command [cmd ::critcl::runtime::precopy] is provided by the file
[file critcl-rt.tcl] in the generated package, as is the command

[cmd ::critcl::runtime::loadlib] which generates the
[term {ifneeded script}] expected by Tcl's package management. This
generated ifneeded script contains the invocations of [cmd ::preload].

[para]

The C code for the supporting library is found in the file
[file critcl_c/preload.c], which is part of the [package critcl]
package.

[para]

The Tcl code for the supporting runtime [file critcl-rt.tcl] is found
in the file [file runtime.tcl], which is part of the
[package critcl::app] package.

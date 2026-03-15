[comment {-*- mode: tcl ; fill-column: 90 -*-}]

This section offers instructions for installing [vset critcl] on various kinds of Unix and
Unix-related systems, i.e. [term Linux], the various [term BSD]s, etc. It especially
covers [term {Mac OS X}] as well.

[para] Use the instructions in section [sectref {Install On Windows}] when installing on a
Windows platform and not using a unix-like environment as provided by tools like
[vset mingw], [vset cygwin], [vset git4win], [vset wsl], etc.

[list_begin enumerated]

[enum] Change the working directory to the top level directory of the [vset critcl]
checkout obtained by following the instructions of [term {How To Get The CriTcl Sources}].

[enum] Verify that the file [file build.tcl] is marked executable. Make it executable if
it is not.

[enum] Invoke [example { ./build.tcl install }] to perform the installation.

[para] [strong Attention] This command uses default locations for the placement of the
[cmd critcl] application, the various packages, and header files.

[enum] Invoke [example { ./build.tcl dirs }] to see the chosens paths before actually
performing the installation.

[enum] [include include/build_install_options.inc]

These options are especially necessary in all environments not using the semi-standard
[file bin], [file lib], [file include] locations from [syscmd configure].

[para] As an example of such environments, Ubuntu (and possibly Debian) expect Tcl
packages to be installed into the [file /usr/share/tcltk] directory, therefore requiring
the use of [example {--lib-dir /usr/share/tcltk}] for proper installation.

[list_end]

[para] [strong Note] that this guide neither covers the details of the [method install]
method, nor does it cover any of the other methods available through the [cmd build.tcl]
tool of [vset critcl].

These can be found in the [term {CriTcl build.tcl Tool Reference}].

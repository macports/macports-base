[comment {-*- mode: tcl ; fill-column: 90 -*-}]

This section offers instructions for installing [vset critcl] on a Windows (tm) host.

[strong Note] that environments as provided by tools like [vset mingw], [vset cygwin],
[vset git4win], [vset wsl], etc. are classed as Unix-like, and the instructions in section
[sectref {Install On Unix}] apply.

[list_begin enumerated]

[enum] In a DOS box, change the working directory to the top level directory of the
[vset critcl] checkout obtained by following the instructions of
[term {How To Get The CriTcl Sources}].

[enum] In the same DOS box, invoke [example { tclsh.exe ./build.tcl install }] to perform
the installation.

[para] [strong Attention] This command uses default locations for the placement of the
[cmd critcl] application, the various packages, and header files.

[enum] Invoke [example { tclsh.exe ./build.tcl dirs }] to see the chosens paths before
actually performing the installation.

[enum] [include include/build_install_options.inc]

[list_end]

[para] [strong Attention!] The current installer does not put an extension on the
[syscmd critcl] application. This forces users to either explicitly choose the
[syscmd tclsh] to run the application, or manually rename the installed file to
[file critcl.tcl]. The latter assumes that an association for [file .tcl] is available, to
either [syscmd tclsh], or [syscmd wish].

[para] [strong Note] that this guide neither covers the details of the [method install]
method, nor does it cover any of the other methods available through the [cmd build.tcl]
tool of [vset critcl].

These can be found in the [term {CriTcl build.tcl Tool Reference}].

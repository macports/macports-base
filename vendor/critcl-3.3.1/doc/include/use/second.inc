[comment {-*- mode: tcl ; fill-column: 90 -*-}]

To create a minimal package wrapping an external library

[list_begin enumerated]

[enum] Choose a directory to develop in and make it the working directory.

This should not be a checkout of [vset critcl] itself.

[enum] Save the following example to a file. In the following it is assumed that the file
was named [file example.tcl].

[example_begin]
[include second_pkg.inc]
[example_end]

[enum] Build the package. See the [sectref {The First Package - Basics} Basics], if necessary.

[enum] Load the package and invoke the commands.

[para] [emph Attention]. The commands take and return binary data.

This may look very bad in the terminal.

[enum] To test the commands enter
[example {
    set a [compress {hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhello wwwwwwwworld}]

    decompress $a
}] in the interactive [syscmd tclsh]

[list_end]

[para] New commands: [term critcl::cheaders], [term critcl::clibraries], [term critcl::include].

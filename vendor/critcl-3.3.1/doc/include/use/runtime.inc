[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref Basics {basic package}] for the introduction of the
commands referenced below.

[enum] Use the command [cmd critcl::tcl] to tell [vset critcl] the minimal version of Tcl
the package is to be used with.

[para] This determines which Tcl headers all files are compiled against, and what version
of the public Tcl API is available to the C code.

[para] Currently [const 8.4], [const 8.5] and [const 8.6] are supported.

[para] If not specified [const 8.4] is assumed.

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref Basics {basic package}] for the introduction of the
commands referenced below.

[enum] Use the command [cmd critcl::debug] to activate various features supporting debugging.

[para][example {
    critcl::debug memory  ;# Activate Tcl memory debugging (-DTCL_MEM_DEBUG)
    critcl::debug symbols ;# Activate building and linking with debugger symbols (-g)
    critcl::debug all     ;# Shorthand for both `memory` and `symbols`.
}]

[list_end]

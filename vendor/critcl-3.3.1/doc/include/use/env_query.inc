[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Use the command [cmd critcl::check] to immediately check if a piece of C code can
compiled successfully as a means of querying the compiler configuration itself.

[para][example {
    if {[critcl::check {
        #include <FOO.h>
    }]} {
        Do stuff with FOO.h present.
    } else {
        Do stuff without FOO.h
    }
}]

[para] All header and library paths which were registered with [vset critcl] before using
[cmd critcl::check] take part in the attempted compilation.

[para] Use the package [package critcl::util] and various convenience commands it
provides.

[enum] Use the full [term {Power of Tcl (tm)}] itself.

[list_end]

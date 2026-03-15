[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref {Using External Libraries} {basic wrapper package}] for
the introduction of the commands referenced below.

[enum] Use the command [cmd critcl::cflags] to provide additional, non-standard flags to
the compiler.

[para][example {
    critcl::cflags -DBYTE_ORDER=bigendian
}]

[enum] Use the command [cmd critcl::ldflags] to provide additional, non-standard flags to
the linker.

[para][example {
    critcl::ldflags -
}]

[enum] Not answered in the above is how to determine such flags if they are not fixed
across machines or platforms.

[para] This is addressed by the next section.

[list_end]

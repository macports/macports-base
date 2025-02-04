[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref {Using External Libraries} {basic wrapper package}] for
the introduction of the commands referenced below.

[enum] Use the command [cmd critcl::ccode] to write C code residing outside of [cmd cproc]
bodies.

[enum] Or, alternatively, place the C code into one or more [file .c] files and use the
command [cmd critcl::csources] to register them with [vset critcl] for compilation.

[enum] This topic is also treated in section [sectref {Separating Local C Sources}].

[list_end]

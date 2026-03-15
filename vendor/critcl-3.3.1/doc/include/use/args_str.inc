[comment {-*- mode: tcl ; fill-column: 90 -*-}]

Tcl prides itself on the fact that [term {Everything Is A String}].

So how are string values passed into C functions ?

[list_begin enumerated]

[enum] We are now extending the command with a string argument.
[enum][vset base][example {
    critcl::cproc hello {pstring x} void {
	/* critcl_pstring x (.s, .len, .o); */
	printf("hello world, from %s (%d bytes)\n", x.s, x.len);
    }
}][vset rebuild]

[enum] Testing [cmd hello] with any kind of argument the information is printed.

[enum] Of note here is that the command argument [var x] is a structure.

[enum] The example uses only two of the three fields, the pointer to the string data
([var .s]), and the length of the string ([var .len]). In bytes, [strong not] in
characters, because Tcl's internal representation of strings uses a modified UTF-8
encoding. A character consists of between 1 and [const TCL_UTF_MAX] bytes.

[enum] [emph Attention] The pointers ([var .s]) refer into data structures [emph internal]
to and managed by the Tcl interpreter.

Changing them is highly likely to cause subtle and difficult to track down bugs.

Any and all complex arguments must be treated as [term Read-Only]. Never modify them.

[enum] Use the simpler type [type char*] if and only if the length of the string is not
relevant to the command, i.e. not computed, or not used by any of the functions called
from the body of the command.

Its value is essentially just the [var .s] field of [type pstring]'s structure.

This then looks like [example {
    critcl::cproc hello {char* x} void {
	/* char* x; */
	printf("hello world, from %s\n", x);
    }
}]

[list_end]

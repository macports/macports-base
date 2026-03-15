[comment {-*- mode: tcl ; fill-column: 90 -*-}]

Even as a string-oriented language Tcl is capable of handling more complex structures. The first of
it, with Tcl since the beginning are [term lists]. Sets of values indexed by a numeric value.

[para] In C parlance, [term arrays].

[list_begin enumerated]

[enum] We are now extending the command with a [type list] argument.
[enum][vset base][example {
    critcl::cproc hello {list x} void {
	/* critcl_list x (.o, .v, .c); */
	printf("hello world, %d elements in (%s)\n", x.c, Tcl_GetString (x.o));
    }
}][vset rebuild]

[enum] Testing [cmd hello] with any kind of list argument it will print basic information about it.

[enum] Of note here is that the command argument [var x] is a structure.

[enum] The example uses only two of the three fields, the pointer to the original [type Tcl_Obj*]
holding the list ([var .o]), and the length of the list ([var .c]) in elements.

[para] The field [var .v], not used above, is the C array holding the [type Tcl_Obj*] pointers to
the list elements.

[enum] [emph Attention] The pointers [var .o] and [var .v] refer into data structures
[emph internal] to and managed by the Tcl interpreter.

Changing them is highly likely to cause subtle and difficult to track down bugs.

Any and all complex arguments must be treated as [term Read-Only]. Never modify them.

[enum] As a last note, this argument type does not place any constraints on the size of the list, or
on the type of the elements.

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

As mentioned at the end of section [sectref {List Arguments}] the basic [type list] type places no
constraints on the size of the list, nor on the type of the elements.

[para] Both kind of constraints can be done however, alone or together.

[list_begin enumerated]

[enum] We are now extending the command with a length-limited list.
[enum][vset base][example {
    critcl::cproc hello {[5] x} void {
	/* critcl_list x (.o, .v, .c); */
	printf("hello world, %d elements in (%s)\n", x.c, Tcl_GetString (x.o));
    }
}][vset rebuild]

[enum] Testing the new command will show that only lists holding exactly [const 5] elements will be
accepted.

[enum] To accept lists of any length use [const {[]}] or [const {[*]}]. Both forms are actually
aliases of the base type, i.e. [type list].

[enum] To constrain just the type of elements, for example to type [type int], use [example {int[]}]
or [example {[]int}]

[enum] To combine both type and length constraints use the forms [example {int[5]}] or
[example {[5]int}]

[enum] The last, most C-like forms of these contraints place the list indicator syntax on the
argument instead of the type. I.e [example {int a[]}] or [example {int a[5]}]

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Reread the example of the main section. Note specifically the line [example {
    int {level ZSTD_CLEVEL_DEFAULT}
}]

[enum] This line demonstrates that [cmd critcl::cproc] arguments allowed to have default
values, in the same vein as [cmd proc] arguments, and using the same syntax.

[enum] [emph Attention] Default values have to be legal C rvalues and match the C type of
the argument.

[para] They are literally pasted into the generated C code.

[para] They bypass any argument validation done in the generated translation layer. This
means that it is possible to use a value an invoker of the command cannot use from Tcl.

[enum] This kind of in-band signaling of a default versus a regular argument is however
not necessary.

[para] Look at [example {
    critcl::cproc default_or_not {int {x 0}} void {
	if !has_x {
	    printf("called with default\n");
	    return
	}
	printf("called with %d\n", x);
    }
}]

[para] Any argument [arg x] with a default causes [vset critcl] to create a hidden
argument [arg has_x], of type int (boolean).

This argument is set to [const 1] when [arg x] was filled from defaults, and [const 0]
else.

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

Tcl prides itself on the fact that [term {Everything Is A String}].

So how are string values returned from C functions ?

[list_begin enumerated]

[enum] We are now giving the command a string result.

[enum][vset base][example {
    critcl::cproc twice {double x} char* {
	char buf [lb]40[rb];
	sprintf(buf, "%f", 2*x);
	return buf;
    }
}][vset rebuild]

[enum] Note that the name of the command changed. Goodbye [cmd hello], hello [cmd twice].

[enum] Invoke [example { twice 4 }] and the [syscmd tclsh] will print the result [const 8]
in the terminal.

[enum] [emph Attention]. To the translation layer the string pointer is owned by the C
code. A copy is made to become the result seen by Tcl.

[para] While the C code is certainly allowed to allocate the string on the heap if it so
wishes, this comes with the responsibility to free the string as well. Abrogation of that
responsibility will cause memory leaks.

[para] The type [type char*] is recommended to be used with static string buffers, string
constants and the like.

[enum] Conversely, to return heap-allocated strings it is recommended to use the type
[type string] instead.

[para] Replace the definition of [cmd twice] with

[example_begin]
critcl::cproc twice {double x} string {
    char* buf = Tcl_Alloc (40);
    sprintf(buf, "%f", 2*x);
    return buf;
}
[example_end]

[para] Now the translation layer takes ownership of the string from the C code and
transfers that ownership to the Tcl interpreter. This means that the string will be
released when the Tcl interpreter is done with it. The C code has no say in the lifecycle
of the string any longer, and having the C code releasing the string [strong will] cause
issues. Dangling pointers and associated memory corruption and crashes.

[list_end]

[comment {-*- mode: tcl ; fill-column: 90 -*-}]

A function taking neither arguments nor returning results is not very useful.

[list_begin enumerated]

[enum] We are now extending the command to take an argument.

[enum][vset base][example {
    critcl::cproc hello {double x} void {
	/* double x; */
	printf("hello world, we have %f\n", x);
    }
}][vset rebuild]

[enum] When testing the package again, entering the simple [cmd hello] will fail.

[para] The changed command is now expecting an argument, and we gave it none.

[para] Retry by entering [example {hello 5}] instead.
       Now the command behaves as expected and prints the provided value.

[para] Further try and enter [example {hello world}]
       This will fail again.
       The command expected a real number and we gave it something decidedly not so.

[para] These checks (argument count, argument type) are implemented in the translation
layer [vset critcl] generates for the C function. The function body is never invoked.

[list_end]

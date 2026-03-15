[comment {-*- mode: tcl ; fill-column: 90 -*-}]

A function taking neither arguments nor returning results is not very useful.

[list_begin enumerated]

[enum] We are now extending the command to return a result.

[enum][vset base][example {
    critcl::cproc twice {double x} double {
	return 2*x;
    }
}][vset rebuild]

[enum] Note that the name of the command changed. Goodbye [cmd hello], hello [cmd twice].

[enum] Invoke [example { twice 4 }] and the [syscmd tclsh] will print the result [const 8]
in the terminal.

[list_end]

[para] An important limitation of the commands implemented so far is that they cannot
fail. The types used so far ([type void], [type double]) and related scalar types can
return only a value of the specified type, and nothing else. They have no ability to
signal an error to the Tcl script.

[para] We will come back to this after knowing a bit more about the more complex argument
and result types.

[para] Of interest to the eager reader: [term {CriTcl cproc Type Reference}]

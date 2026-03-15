[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum][vset base][example {
    critcl::cproc greetings::hello {} void {
	printf("hello world\n");
    }

    critcl::cproc greetings::hi {} void {
	printf("hi you\n");
    }
}][vset rebuild]

[enum] The command [cmd hello] is now available as [cmd greetings::hello], and a second
command [cmd greetings::hi] was added.

[enum] Tcl has automatically created the namespace [namespace greetings].

[enum] Create a file [file example-policy.tcl] and enter [example {
    namespace eval greetings {
	namespace export hello hi
	namespace ensemble create
    }
}] into it.

[enum] Edit [file example.tcl]. Add the code [example {
    critcl::tsources example-policy.tcl
}][vset rebuild]

[enum] The added Tcl code makes [namespace greetings] available as an [term ensemble]
command.

[para] The commands in the namespace have been registered as methods of the ensemble.

[para] They can now be invoked as [example {
    greetings hello
    greetings hi
}]

[enum] The Tcl builtin command [cmd string] is an ensemble as well, as is [cmd clock].

[list_end]

[para] New commands: [term critcl::tsources]

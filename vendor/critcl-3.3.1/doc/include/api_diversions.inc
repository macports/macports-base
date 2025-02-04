
Diversions are for higher-level packages generating their own C code,
to make their use of critcl's commands generating
[sectref {Embedded C Code}] easier.

[para] These commands normally generate all of their C code for the
current [file .critcl] file, which may not be what is wanted by a
higher-level package.

[para] With a diversion the generator output can be redirected into
memory and from there on then handled and processed as the caller
desires before it is committed to an actual [file .c] file.

[para] An example of such a package comes with critcl itself, see the
implementation of package [package critcl::class].

[para] To help such developers three commands are provided to manage
diversions and the collection of C code in memory. These are:

[list_begin definitions]
[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::collect_begin]]

This command starts the diversion of C code collection into memory.

[para] The result of the command is the empty string.

[para] Multiple calls are allowed, with each call opening a new
nesting level of diversion.


[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::collect_end]]

This command end the diversion of C code collection into memory and
returns the collected C code.

[para] If multiple levels of diversion are open the call only closes
and returns the data from the last level.

[para] The command will throw an error if no diversion is active,
indicating a mismatch in the pairing of [cmd collect_begin] and
[cmd collect_end].

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[call [cmd ::critcl::collect] [arg script]]

This is a convenience command which runs the [arg script] under
diversion and returns the collected C code, ensuring the correct
pairing of [cmd collect_begin] and [cmd collect_end].

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]

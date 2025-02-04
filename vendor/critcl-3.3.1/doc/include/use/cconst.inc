[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the end of the [sectref {Custom Argument Validation} validation] section.
Edit the file [file example.tcl].

Add the code below, just before the [cmd compress] command.

[example {
    critcl::cconst version   char* ZSTD_VERSION_STRING
    critcl::cconst min-level int   1
    critcl::cconst max-level int   ZSTD_maxCLevel()
}][vset rebuild]

[enum] These declarations create three additional commands, each returning the specified
value. A fixed string, an integer, and a function call returning an integer.

[enum] [emph Attention] The values have to be legal C rvalues and match the C type of the
result. They are literally pasted into the generated C code.

[enum] When using [cmd critcl::cconst] [vset critcl] is aware that the result of the
function does not depend on any parameters and is computed in a single C expression.

[para] This enables it do to away with the internal helper function it would need and
generate if [cmd critcl::cproc] had been used instead.

For example [example {
    critcl::cproc version {} char* {
	return ZSTD_VERSION_STRING;
    }
}]

[list_end]

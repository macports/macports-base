
[section {Tcl/PARAM code representation of parsing expression grammars}]

The Tcl/PARAM representation of parsing expression grammars is Tcl
code whose execution will parse input per the grammar. The code is
based on the virtual machine documented in the
[manpage {PackRat Machine Specification}], using its instructions
and a few more to handle control flow.

[para]

Note that the generated code by itself is not functional. It expects
to be embedded into a framework which provides services like the PARAM
state, implementations for the PARAM instructions, etc.

The bulk of such a framework has to be specified through the option
[option -template]. The additional options

[list_begin options]
[opt_def -indent integer]
[opt_def -main string]
[opt_def -namespace string]
[opt_def -prelude string]
[opt_def -proc-command string]
[opt_def -runtime-command string]
[opt_def -self-command string]
[list_end]

provide code snippets which help to glue framework and generated code
together. Their placeholders are in the [emph generated] code.

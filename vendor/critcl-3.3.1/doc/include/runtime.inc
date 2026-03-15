
The default behaviour of critcl, the package is to defer the
compilation, linking, and loading of any C code as much as possible,
given that this is an expensive operation, mainly in the time
required.

In other words, the C code embedded into a [file .critcl] file is
built only when the first C command or procedure it provides is
invoked.

This part of the system uses standard functionality built into the Tcl
core, i.e. the [var auto_index] variable to map from commands to
scripts providing them and the [cmd unknown] command using this
information when the command is needed.

[para] A [emph limitation] of this behaviour is that it is not
possible to just use [cmd {info commands}] check for the existence of
a critcl defined command. It is also necessary to search in the
[var auto_index] array, in case it has not been build yet.

[para] This behaviour can be changed by using the control command
[cmd critcl::load]. When invoked, the building, including loading of
the result, is forced. After this command has been invoked for a
[file .critcl] file further definition of C code in this file is not
allowed any longer.

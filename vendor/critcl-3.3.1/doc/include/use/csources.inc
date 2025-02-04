[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the end of the [sectref {Custom Argument Validation} previous] section.
       Edit the file [file example.tcl].

[enum] Save the contents of the [cmd critcl::ccode] block into a file [file example.c] and
then replace the entire block with

[example {
    critcl::csources example.c

    critcl::ccode {
	extern int GetCompressionLevel (Tcl_Interp* interp, Tcl_Obj* obj, int* level);
    }
}]

[para] When mixing C and Tcl code the different kind of indentation rules for these
languages may come into strong conflict. Further, very large blocks of C code may reduce
overall readability.

[enum] The examples fixes this by moving the code block into a local C file and then
registering this file with [vset critcl].

When building the package [vset critcl] arranges to build all such registered C files as
well.

[enum] [emph Attention]. The C code is now in a separate compilation unit.

The example declares the exported function so that the [cmd cproc]s are again able to see
and use it.

[enum] Now go a step further. Save the declaration into a file [file example.h], and then
use [example {
    critcl::include example.h
}] to import it. Note that this is just a shorthand for [example { critcl::ccode {
	#include "example.h"
    }
}]

[enum] As an alternative solution, start from the beginning of the section and move the
entire original [cmd critcl::ccode] block into a file [file example-check.tcl].

[para] Then replace it with [example {
    critcl::source example-check.tcl
}] to import it into the main code again.

[para] [emph Attention] Tcl's builtin command [cmd source] is [emph {not suitable}] for
importing the separate file due to how [vset critcl] uses the information from
[cmd {info script}] to key various internal datastructures.

[list_end]

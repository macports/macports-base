[comment {-*- mode: tcl ; fill-column: 90 -*-}]

To create a minimal working package

[list_begin enumerated]

[enum] Choose a directory to develop in and make it the working directory. This should
not be a checkout of [vset critcl] itself.

[enum] Save the following example to a file. In the following it is assumed that the file
was named [file example.tcl].

[example_begin]
[include first_pkg.inc]
[example_end]

[enum] Invoke the command [example { critcl -keep -debug all -pkg example.tcl }]

[para] This compiles the example and installs it into a [file lib/] sub directory of the
working directory, generating output similar to

[example {
    Config:   linux-x86_64-gcc
    Build:    linux-x86_64-gcc
    Target:   linux-x86_64
    Source:   example.tcl  (provide critcl-example 1) Building ...
    Library:  example.so
     (tclStubsPtr     =>  const TclStubs *tclStubsPtr;)
     (tclPlatStubsPtr =>  const TclPlatStubs *tclPlatStubsPtr;)
    Package:  lib/example
    Files left in /home/aku/.critcl/pkg2567272.1644845439   
}]

during operation.

[para] The [option -keep] option suppressed the cleanup of the generated C files, object
files, compiler log, etc. normally done at the end of building.

[example {
% ls -l /home/aku/.critcl/pkg2567272.1644845439
total 36
-rw-r--r-- 1 aku aku  1260 Feb 14 18:30 v3118_00000000000000000000000000000004.c
-rw-r--r-- 1 aku aku  2096 Feb 14 18:30 v3118_00000000000000000000000000000004_pic.o
-rw-r--r-- 1 aku aku  1728 Feb 14 18:30 v3118_00000000000000000000000000000009.c
-rw-r--r-- 1 aku aku  2448 Feb 14 18:30 v3118_00000000000000000000000000000009_pic.o
-rwxr-xr-x 1 aku aku 14424 Feb 14 18:30 v3118_00000000000000000000000000000009.so
-rw-r--r-- 1 aku aku  1725 Feb 14 18:30 v3118.log
}]

This enables inspection of the generated C code.

Simply drop the option from the command if that is not desired.

[para] The option [option -debug], with argument [const all] activated Tcl's memory
debugging and caused the generation of the symbol tables needed by [syscmd gdb] or any
other debugger. The alternate arguments [const memory] and [const symbols] activate just
one of the these.

[enum] Now invoke an interactive [syscmd tclsh] and enter the commands:
[list_begin itemized]
[item] [emph {lappend auto_path lib}]
[item] [emph {package require critcl-example}]
[item] [emph {info loaded}]
[item] [emph hello]
[item] [emph exit]
[list_end]

I.e. extend [syscmd tclsh]'s package search path to include the location of the new
package, load the package, verify that the associated shared library is present, invoke
the package command, and stop the session.

[para] When the package command is invoked the terminal will show [const {hello world}],
followed by the prompt.

[list_end]

[para] Commands: [term critcl::compiling], [term critcl::cproc],
[term critcl::description], [term critcl::license], [term critcl::load],
[term critcl::msg], [term critcl::subject], [term critcl::summary], [term critcl::tcl].

[para] Make a copy of [file example.tcl] before going through the sub-sections. Keep it as
a save point to return to from the editing done in the sub-section.

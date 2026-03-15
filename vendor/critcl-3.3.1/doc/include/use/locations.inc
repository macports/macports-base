[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref {Using External Libraries} {basic wrapper package}] for
the introduction of the commands referenced below.

[enum] [emph Attention] Relative paths will be resolved relative to the location of the
[file .tcl] file containing the [vset critcl] commands.

[enum] Use the command [cmd critcl::cheaders] to tell [vset critcl] about non-standard
locations for header files.

[para] Multiple arguments are allowed, and multiple calls as well. The information
accumulates.

[para] Arguments of the form [file -Idirectory] register the directory directly.

[para] For arguments of the form [file path] the directory holding the path is
registered. In other words, it is assumed to be the full path of a header [emph file], and
not a directory.

[para][example {
    critcl::cheaders -I/usr/local/include
    critcl::cheaders local/types.h
    critcl::cheaders other-support/*.h
}]

[enum] Use the command [cmd critcl::include] to actually use a specific header file.

[enum] Use the command [cmd critcl::clibraries] to tell [vset critcl] about non-standard
locations for shared libaries, and about shared libaries to link to

[para] Multiple arguments are allowed, and multiple calls as well. The information
accumulates.

[para] Arguments of the form [file -Ldirectory] register a directory.

[para] Arguments of the form [file -lname] register a shared libary to link to by
name. The library will be looked for in both standard and registered directories.

[para] Arguments of the form [file -path] register a shared libary to link to by full
path.

[para][example {
    critcl::clibraries -L/usr/lib/x86_64-linux-gnu
    critcl::clibraries -lzstd
    critcl::clibraries /usr/lib/x86_64-linux-gnu/libzstd.so
}]

[enum] On Mac OS X use the command [cmd critcl::framework] to name the frameworks to use
in the package.

[para] [emph Attention] Using the command on other platforms is ok, and will be ignored.

[enum] Not answered in the above is how to find the necessary paths if they are not fixed
across machines or platforms.

[para] We will come back to this.

[list_end]

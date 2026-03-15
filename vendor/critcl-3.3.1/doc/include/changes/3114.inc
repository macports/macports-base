[section {Changes for version 3.1.14}]
[list_begin enumerated]

[enum]  Fixed issue #36. Added message to target [const all] of the
        Makefile generated for TEA mode. Additionally tweaked other
        parts of the output to be less noisy.

[enum]  Accepted request implied in issue #54. Unconditionally save
        the compiler/linker build log into key [const log] of the
        dictionary returned by [cmd cresults], and save a copy of only
        the execution output in the new key [const exl] ("execution
        log").

[enum]  Fixed issue #53. Clarified the documentation of commands
        [cmd critcl::load] and [cmd critcl::failed] with regard
        to their results and the throwing of errors (does not happen).

[enum]  Fixed issue #48. Modified mode "compile & run" to allow new
        declarations in a file, after it was build, instead of
        erroring out. The new decls are build when needed. Mode
        "precompile" is unchanged and will continue to trap the
        situation.

[enum]  Fixed issue #52. Updated the local Tcl/Tk headers to
        8.4.20, 8.5.13, and 8.6.4.

[enum]  Fixed issue #45. New feature command [cmd critcl::cconst].

[enum]  [package critcl::util]: New command [cmd locate] to find a
        file across a set of paths, and report an error when not
        found. This is for use in autoconf-like header-searches and
        similar configuration tests.

[enum]  Modified 'AbortWhenCalledAfterBuild' to dump the entire stack
        (info frame!). This should make it easier to determine the
        location of the troubling declaration.

[list_end]

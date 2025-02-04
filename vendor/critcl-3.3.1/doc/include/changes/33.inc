[include 331.inc]

[section {Changes for version 3.3}]
[list_begin enumerated]

[enum] As announced with 3.2:
[list_begin enumerated]

[enum] Removed support for Tcl 8.4 and 8.5.

[enum] Removed support for the argument types
       [type int*],
       [type float*],
       [type double*],
       [type bytearray],
       [type rawchar], and
       [type rawchar*].
[list_end]

[enum] Modified packages to accept operation under Tcl 9.
       Bumped package versions appropriately.
       Bumped copyrights.

[para] The [term {How To Adapt Critcl Packages for Tcl 9}]
       contains the details relevant to writers of [vset critcl]-based packages.

[enum] Set different minimum Tcl requirements for the 8.x and 9.x series.

[para] If no minimum is declared the minimum depends on the Tcl version
       used to run the critcl package or application.

[para] When running under Tcl 9 the default minimum is version [const 9].
       For anything else the new default minimum is [const 8.6].

[para] [strong Reminder]: Support for Tcl 8.4 and 8.5 was removed.

[enum] Made [file ~]-handling portable across the 8.x and 9 boundary
       (via [const HOME] environment variable).

[enum] Bumped embedded [package tclconfig] to version 2.67. Patch supplied by Paul Obermeier.

[enum] [strong {Bug Fix}] [uri https://github.com/andreas-kupries/critcl/issues/127 #127]
[enum] [strong {Bug Fix}] [uri https://github.com/andreas-kupries/critcl/issues/128 #128]
[enum] [strong {Bug Fix}] [uri https://github.com/andreas-kupries/critcl/issues/129 #129]

Fixed various typos in the documentation.

[enum] Reworked internals of [package critcl::cutil]'s tracer to support operation in a
       multi-threaded environment. This new mode is also default. The old single-threaded
       mode can be (re)activated by defining [const CRITCL_TRACE_NOTHREADS].

[para] Package bumped to version 0.4.

[enum] Reworked the installer to add [const tclX] markers to the installation directories of the
       C-based support packages ([package critcl::callback], [package critcl::md5c]), where
       [var X] is the major version number of the [syscmd tclsh] which ran critcl.

[enum] In other words, one of [const tcl8] or [const tcl9].

[enum] Broke lingering dependencies on the Tcllib packages [package cmdline] and [package fileutil].

[para] There are no circularities between Critcl and Tcllib any longer, simplifying installation.

[list_end]

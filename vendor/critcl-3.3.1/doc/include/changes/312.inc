[section {Changes for version 3.1.2}]
[list_begin enumerated]

[enum] Enhancement. In detail:

[enum] Extended [cmd critcl::cproc] to be able to handle optional
       arguments, in a limited way. This is automatically available to
       [package critcl::class] cproc-based methods as well.

[enum] Bugfix in [cmd lassign] emulation for Tcl 8.4.  Properly set
       unused variables to the empty string.  Bumped version of
       emulation package [package lassign84] to 1.0.1.

[list_end]

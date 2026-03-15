[section {Changes for version 3.1.18.1}]
[list_begin enumerated]

[enum] [strong Attention]: While the overall version (of the bundle)
       moves to 3.1.18.1 the versions of packages [package critcl] and
       [package critcl::app] are [strong unchanged].

[enum] [strong Bugfix] Generally removed a number of 8.5-isms which
       slipped into 3.1.18, breaking ability to use it with Tcl 8.4.

[enum] [strong Bugfix] Corrected broken [strong {build.tcl uninstall}].

[enum] [strong Bugfix] Package [package critcl::class] bumped to
       version 1.1.1. Fixed partial template substitution breaking
       compilation of the generated code.

[list_end]

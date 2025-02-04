[section {Changes for version X}]
[list_begin enumerated]

[enum] [strong Feature]. Bumped [Package critcl::cutil] to version
       0.2.1. Simplified the implementation of macro [cmd ASSERT] by
       taking the underlying Tcl_Panic's printf ability into account
       and added a new macro [cmd ASSERT_VA] exporting the same
       ability to the user.

[list_end]

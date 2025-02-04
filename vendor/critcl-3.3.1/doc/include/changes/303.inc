[section {Changes for version 3.0.3}]
[list_begin enumerated]

[enum] Fixed github issues 5 and 8, for the example build.tcl
scripts. Working around a missing variable ::errorInfo. It should
always be present, however there seem to be revisions of Tcl around
which violate this assumption.

[list_end]

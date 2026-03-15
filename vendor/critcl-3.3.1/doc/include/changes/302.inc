[section {Changes for version 3.0.2}]
[list_begin enumerated]

[enum] Fixed issue in compile-and-run mode where commands put into the
auto_index are not found by Tcl's [lb]unknown[rb] command.

[enum] Fixed an array key mismatch breaking usage of client data and
delete function for procedure. Reported by Jos DeCoster, with patch.

[enum] Implemented a command line option [option -L], an equivalent of
option [option -I], just for library search paths.

[enum] Fixed github issues 5 and 8. Working around a missing variable
::errorInfo. It should always be present, however there seem to be
revisions of Tcl around which violate this assumption.

[list_end]

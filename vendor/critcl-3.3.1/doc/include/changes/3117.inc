[section {Changes for version 3.1.17}]
[list_begin enumerated]

[enum] Extension: Allow duplicate arg- and result-type definitions if
       they are fully identical.

[enum] Bugfix. The application mishandled the possibility of
       identical-named [cmd critcl::tsource]s. Possible because
       [cmd critcl::tsource]s can be in subdirectories, a structure
       which is [emph not] retained in the assembled package, causing
       such files to overwrite each other and at least one lost. Fixed
       by adding a serial number to the file names in the assembled
       package.

[enum] Bugfix in the static scanner which made it loose requirement
       information. Further added code to generally cleanup results at
       the end (removal of duplicates, mainly).

[enum] Bugfix: Fixed issue #76.
       Support installation directories which are not in the [var auto_path].
       Without the patch the installed [cmd critcl] will not find its
       own packages and fail. Thank you to
       [uri https://github.com/lupylucke {Simon Bachmann}] for the
       report and patch, and then his patience with me to getting to
       actually apply it.

[enum] Bugfix: Fixed issue #75.
       Extended [cmd critcl::include] to now take multiple paths.

[enum] Added new compatibility package [package lmap84].

[enum] Fixed typos in various documentation files.

[enum] Fixed bug introduced by commit 86f415dd30 (3.1.16 release). The
       separation of [cmd critcl::ccode] into user and work layers
       means that location retrieval has to go one more level up to
       find the user location.

[enum] New supporting package [package critcl::cutil]. Provides common
       C level facilities useful to packages (assertions, tracing,
       memory allocation shorthands).

[enum] Modified package [package critcl] to make use of the new
       tracing facilities to provide tracing of arguments and results
       for [cmd critcl::ccommand] and [cmd critcl::cproc] invokations.

[enum] Modified packages [package critcl] and [package critcl::class]
       to provide better function names for (class) method tracing.
       Bumped package [package critcl::class] to version 1.0.7.

[enum] Extended the support package [package critcl::literals] with
       limited configurability. It is now able to generate code for
       C-level access to the pool without Tcl types (Mode [const c]).
       The previously existing functionality is accesssible under mode
       [const tcl], which also is the default. Both modes can be used
       together.

[enum] Extended the support package [package critcl::emap] with
       limited configurability. It is now able to generate code for
       C-level access to the mapping without Tcl types
       (Mode [const c]). The previously existing functionality is
       accessible under mode [const tcl], which also is the
       default. Both modes can be used together.

[list_end]

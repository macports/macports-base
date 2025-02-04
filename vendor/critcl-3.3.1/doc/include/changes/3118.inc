[section {Changes for version 3.1.18}]
[list_begin enumerated]

[enum] Feature (Developer support). Merged pull request #96 from
       sebres/main-direct-invoke. Enables direct invokation of the
       [file main.tcl] file for starkits from within a dev checkout,
       i.e. outside of a starkit, or starpack.

[enum] Feature. Added channel types to the set of builtin argument and
       result types. The argument types are for simple channel access,
       access requiring unshared channels, and taking the channel
       fully into the C level, away from Tcl. The result type comes in
       variants for newly created channels, known channels, and to
       return taken channels back to Tcl. The first will register the
       returned value in the interpreter, the second assumes that it
       already is.

[enum] Bugfix. Issue #96. Reworked the documentation around the
       argument type [type Tcl_Interp*] to make its special status
       more visible, explain uses, and call it out from result types
       where its use will be necessary or at least useful.

[enum] Feature. Package [package critcl::class] bumped to version 1.1.
       Extended with the ability to create a C API for classes, and
       the ability to disable the generation of the Tcl API.

[enum] Bugfix. Merged pull request #99 from pooryorick/master. Fixes
       to the target directory calculations done by the install code.

[enum] Merged pull request #94 from andreas-kupries/documentation.
       A larger documentation cleanup. The main work was done by
       pooryorick, followed by tweaks done by myself.

[enum] Extended the test suite with lots of cases based on the
       examples for the various generator packages. IOW the new test
       cases replicate/encapsulate the examples and demonstrate that
       the packages used by the examples generate working code.

[enum] Bugfix. Issue #95. Changed the field [const critcl_bytes.s] to
       [type {unsigned char*}] to match Tcl's type. Further constified
       the field to make clear that read-only usage is the common case
       for it.

[enum] Bugfix/Feature. Package [package critcl::cutil] bumped to
       version 0.2.  Fixed missing inclusion of header [file string.h]
       in [file critcl_alloc.h], needed for [fun memcpy] in macro
       [fun STREP].  Added macros [fun ALLOC_PLUS] and [fun STRDUP].
       Moved documentation of [fun STREP...] macros into proper place
       (alloc section, not assert).

[enum] Merged pull request #83 from apnadkarni/vc-fixes.
       Removed deprecated -Gs for MSVC builds, and other Windows fixups.

[enum] Feature. Package [package critcl::iassoc] bumped to version 1.1.
       Refactored internals to generate an include header for use by .c files.
       This now matches what other generator packages do.
       The template file is inlined and removed.

[enum] Merged pull request #82 from gahr/home-symlink
       Modified tests to handle possibility of $HOME a symlink.

[enum] Merged pull request #81 from gahr/test-not-installed
       Modified test support to find uninstalled critcl packages when
       running tests. Handles all but critcl::md5.

[enum] Merged pull request #85 from snoe925/issue-84
       to fix Issue #84 breaking installation on OSX.

[enum] Merged pull request #87 from apnadkarni/tea-fixes to fix Issue
       #86, broken -tea option, generating an incomplete package.

[enum] Feature. New package [package critcl::callback] providing
       C-level functions and data structures to manage callbacks from
       C to Tcl.

[enum] Feature. Package [package critcl::literals] bumped to version
       1.3.  Added mode [const +list] enabling the conversion of
       multiple literals into a list of their strings.

[enum] Feature. Package [package critcl::enum] bumped to version 1.1.
       Added basic mode handling, supporting [const tcl] (default) and
       [const +list] (extension enabling the conversion of multiple
       enum values into a list of their strings).

[enum] Feature. Package [package critcl::emap] bumped to version 1.2.
       Extended existing mode handling with [const +list] extension
       enabling the conversion of multiple emap values into a list of
       their strings.

[enum] Feature. Extended the set of available types by applying a few
       range restrictions to the scalar types ([term int],
       [term long], [term wideint], [term double], [term float]).

       [para] Example: [term {int > 0}] is now a viable type name.

       [para] This is actually more limited than the description might
       let you believe.

       [para] See the package reference for the details.
[list_end]

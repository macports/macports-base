[section {Changes for version 3.0.1}]
[list_begin enumerated]

[enum] Bugfixes all around. In detail:

[enum] Fixed recording of Tcl version requirements. Keep package name
and version together, unbreaking generated meta data and generated
package load command.

[enum] Fixed the build scripts: When installing, or wrapping for TEA,
generate any missing directories

[enum] Modified the build scripts to properly exit the application
when the window of their GUI is closed through the (X) button.

[enum] Removed an 8.5-ism (open wb) which had slipped into the main
build script.

[enum] Modified the example build scripts to separate the output for
the different examples (and packages) by adding empty lines.

[enum] stack::c example bugfix: Include API declarations for use in
the companion files.

[enum] Extended the documentation: Noted the need for a working
installation of a C compiler.

[enum] Extended the Windows target definitions and code to handle the
manifest files used by modern MS development environments. Note that
this code handles both possibilities, environment using manifests, and
(old(er)) environments without.

[enum] Extended the Windows 64bit target definitions and code to
auto-detect the need for the helper library "bufferoverflowU.lib" and
reconfigure the compile and link commands appropriately. We assume
that the library must be linked when present. This should be no harm
if the library is present, yet not needed. Just superfluous. We search
for the library in the paths specified by the environment variable
LIB.

[list_end]

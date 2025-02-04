
The following commands manage the build configuration, i.e. the per-platform
information about compilers, linkers, and their commandline options.

[vset not_needed_for_critcl_script]

[list_begin definitions]

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::readconfig] [arg path]]

Reads the build configuration file at [arg path] and configures the package
using the information for the target platform.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::showconfig] [opt [arg chan]]]

Converts the active build configuration into a human-readable string and
returns it, or if [arg chan] is provided prints the result to that channel.

[comment {
    As a package it would be IMHO better to have these command only
    return the necessary internal data, and have the application
    higher up do the formatting.
}]


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::showallconfig] [opt [arg chan]]]

Converts the set of all known build configurations from the currently active
build configuration file last set with [cmd critcl::readconfig] into a string
and returns it, or if [arg chan] is provided, prints it to that channel.

[comment {
    As a package it would be IMHO better to have these command only
    return the necessary internal data, and have the application
    higher up do the formatting.
}]


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::chooseconfig] [arg target] [opt [arg nomatcherr]]]

Matches [arg target] against all known targets, returning a list containing
all the matching ones. This search is first done on an exact basis, and then
via glob matching. If no known target matches the argument the default is to
return an empty list. However, if the boolean [arg nomatcherr] is specified and
set an error is thrown using [cmd critcl::error] instead.


[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::setconfig] [arg target]]

Configures the package to use the settings of [arg target].

[list_end]

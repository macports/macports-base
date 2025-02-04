
The following commands control the [sectref {Result Cache}].

[vset not_needed_for_critcl_script]

[list_begin definitions]
[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::cache] [opt path]]

Sets and returns the path to the directory for the package's result cache.

[para] The default location is
[file ~/.critcl/[lb]platform::generic[rb]] and usually does not
require any changes.

[comment ---------------------------------------------------------------------]
[call [cmd ::critcl::clean_cache] [opt [arg pattern]...]]

Cleans the result cache, i.e. removes any and all files
and directories in it. If one or more patterns are specified then only
the files and directories matching them are removed.

[list_end]

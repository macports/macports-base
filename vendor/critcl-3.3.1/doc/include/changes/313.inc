[section {Changes for version 3.1.3}]
[list_begin enumerated]

[enum] Enhancement. In detail:

[enum] Added new argument type "pstring", for "Pascal String", a
       counted string, i.e. a combination of string pointer and string
       length.

[enum] Added new methods [cmd critcl::argtypesupport] and
       [cmd ::critcl::argsupport] to define and use additional
       supporting code for an argument type, here used by "pstring"
       above to define the necessary structure.

[enum] Semi-bugfixes in the packages [package critcl::class] and
       [package critcl::iassoc]. Pragmas for the AS meta data scanner
       to ensure that the template files are made part of the package.
       Versions bumped to 1.0.4 and 1.0.1 respectively.

[list_end]

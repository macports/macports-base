[section {Changes for version 3.1.4}]
[list_begin enumerated]

[enum] Bugfix in package [package critcl::class]. Generate a dummy
       field in the class structure if the class has no class
       variables. Without this change the structure would be empty,
       and a number of compilers are not able to handle such a type.

[enum] Fixed a typo which broke the win64 configuration.

[enum] Fixed issue #16, a typo in the documentation of command
       [cmd critcl::class].

[list_end]

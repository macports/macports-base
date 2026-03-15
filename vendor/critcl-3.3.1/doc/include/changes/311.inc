[section {Changes for version 3.1.1}]
[list_begin enumerated]

[enum] Bugfixes all around. In detail:

[enum] Fixed the generation of wrong#args errors for
[cmd critcl::cproc] and derived code ([package critcl::class]
cproc-based methods). Use NULL if there are no arguments, and
take the offset into account.

[enum] Fixed the handling of package names by
[package critcl::class]. Forgot that they may contain namespace
separators. Bumped to version 1.0.1.

[enum] Extended a [package critcl::class] generated error message in
instance creation for clarity. Bumped to version 1.0.2.

[list_end]

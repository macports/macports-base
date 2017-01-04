
[list_begin options]
[include options_std.inc]

[comment {= = == === ===== ======== =============}]
[opt_def -class string]

The value of this option is the name of the class to generate, without
leading colons.

The default value is [const CLASS].

[para]

For a simple value [var X] without colons, like CLASS, the parser
command will be [var X]::[var X]. Whereas for a namespaced value
[var X::Y] the parser command will be [var X::Y].

[comment {= = == === ===== ======== =============}]
[opt_def -package string]

The value of this option is the name of the package to generate.

The default value is [const PACKAGE].

[comment {= = == === ===== ======== =============}]
[opt_def -version string]

The value of this option is the version of the package to generate.

The default value is [const 1].

[comment {= = == === ===== ======== =============}]
[list_end]

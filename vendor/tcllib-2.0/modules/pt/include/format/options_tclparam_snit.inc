
[list_begin options]
[include options_std.inc]

[comment {================================================================================}]
[opt_def -class string]

The value of this option is the name of the class to generate, without
leading colons. Note, it serves double-duty as the name of the package
to generate too, if option [option -package] is not specified, see below.

The default value is [const CLASS], applying if neither option
[option -class] nor [option -package] were specified.

[comment {================================================================================}]
[opt_def -package string]

The value of this option is the name of the package to generate, without
leading colons. Note, it serves double-duty as the name of the class
to generate too, if option [option -class] is not specified, see above.

The default value is [const PACKAGE], applying if neither option
[option -package] nor [option -class] were specified.

[comment {================================================================================}]
[opt_def -version string]

The value of this option is the version of the package to generate.

The default value is [const 1].

[list_end]

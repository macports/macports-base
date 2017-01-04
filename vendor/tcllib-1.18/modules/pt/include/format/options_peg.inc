
[list_begin options]
[include options_std.inc]

[opt_def -template string]

The value of this option is a string into which to put the generated
text and the values of the other options. The various locations for
user-data are expected to be specified with the placeholders listed
below. The default value is "[const @code@]".

[list_begin definitions]

[def [const @user@]]
To be replaced with the value of the option [option -user].

[def [const @format@]]
To be replaced with the the constant [const PEG].

[def [const @file@]]
To be replaced with the value of the option [option -file].

[def [const @name@]]
To be replaced with the value of the option [option -name].

[def [const @code@]]
To be replaced with the generated text.

[list_end]
[list_end]

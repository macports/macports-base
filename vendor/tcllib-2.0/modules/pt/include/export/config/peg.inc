[section Configuration]

The PEG export plugin recognizes the following configuration
variables and changes its behaviour as they specify.

[list_begin arguments]

[arg_def string template]

If this configuration variable is set it is assumed to contain a
string into which to put the generated text and other configuration
data. The various locations are expected to be specified with the
following placeholders:

[list_begin definitions]

[def [const @user@]]
To be replaced with the value of the configuration variable [option user].

[def [const @format@]]
To be replaced with the the constant [const PEG].

[def [const @file@]]
To be replaced with the value of the configuration variable [option file].

[def [const @name@]]
To be replaced with the value of the configuration variable [option name].

[def [const @code@]]
To be replaced with the generated text.

[list_end]

[para]

If this configuration variable is not set, or empty, then the plugin
falls back to a standard template, which is defined as "[const @code@]".

[list_end]

[emph Note] that this plugin may ignore the standard configuration
variables [var user], [var format], [var file], and their values,
depending on the chosen template.

[para]

The content of the standard configuration variable [var name], if set,
is used as name of the grammar in the output. Otherwise the plugin
falls back to the default name [const a_pe_grammar].

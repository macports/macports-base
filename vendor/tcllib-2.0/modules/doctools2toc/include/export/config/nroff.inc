[section Configuration]

The nroff export plugin recognizes the following configuration
variables and changes its behaviour as they specify.

[list_begin arguments]

[arg_def string user]
This standard configuration variable contains the name of the user
running the process which invoked the export plugin.

The plugin puts this information into the provenance comment at the
beginning of the generated document.

[arg_def string file]

This standard configuration variable contains the name of the file the
table of contents came from. This variable may not be set or contain
the empty string.

The plugin puts this information, if defined, i.e. set and not the
empty string, into the provenance comment at the beginning of the
generated document.


[arg_def boolean inline]

If this flag is set (default) the plugin will place the definitions of
the man macro set directly into the output.

[para]

If this flag is not set, the plugin will place a reference to the
definitions of the man macro set into the output, but not the macro
definitions themselves.

[list_end]

[emph Note] that this plugin ignores the standard configuration
variables [var format], and [var map], and their values.

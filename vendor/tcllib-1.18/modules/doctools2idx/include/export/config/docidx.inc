
[include ../../format/docidx.inc]

[section Configuration]

The docidx export plugin recognizes the following configuration
variables and changes its behaviour as they specify.

[list_begin arguments]

[arg_def string user]
This standard configuration variable contains the name of the user
running the process which invoked the export plugin.

The plugin puts this information into the provenance comment at the
beginning of the generated document.

[arg_def string file]

This standard configuration variable contains the name of the file the
index came from. This variable may not be set or contain the empty
string.

The plugin puts this information, if defined, i.e. set and not the
empty string, into the provenance comment at the beginning of the
generated document.


[arg_def boolean newlines]

If this flag is set the plugin will break the generated docidx code
across lines, with each markup command on a separate line.

[para]

If this flag is not set (the default), the whole document will be
written on a single line, with minimum spacing between all elements.


[arg_def boolean indented]

If this flag is set the plugin will indent the markup commands
according to the structure of indices. To make this work this also
implies that [var newlines] is set. This effect is independent of the
value for [var aligned] however.

[para]

If this flag is not set (the default), the output is formatted as per
the values of [var newlines] and [var aligned], and no indenting is
done.


[arg_def boolean aligned]

If this flag is set the generator ensures that the arguments for the
[cmd manpage] and [cmd url] commands in a keyword section are aligned
vertically for a nice table effect. To make this work this also
implies that [var newlines] is set. This effect is independent of the
value for [var indented] however.

[para]

If this flag is not set (the default), the output is formatted as per
the values of [var newlines] and [var indented], and no alignment is
done.

[list_end]

[emph Note] that this plugin ignores the standard configuration
variables [var format], and [var map], and their values.

[section Configuration]

The text export plugin recognizes the following configuration
variables and changes its behaviour as they specify.

[list_begin arguments]

[arg_def dictionary map]

This standard configuration variable contains a dictionary mapping
from the symbolic files names in manpage references to the actual
filenames and/or urls to be used in the output.

[para]

Url references and symbolic file names without a mapping are used
unchanged.

[list_end]

[emph Note] that this plugin ignores the standard configuration
variables [var user], [var file], and [var format], and their values.

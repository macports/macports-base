[section Configuration]

The html export plugin recognizes the following configuration
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


[arg_def dictionary map]

This standard configuration variable contains a dictionary mapping
from the (symbolic) document ids in reference entries to the actual
filenames and/or urls to be used in the output.

[para]

Document ids without a mapping are used unchanged.


[arg_def boolean newlines]

If this flag is set the plugin will break the generated html code
across lines, with each markup command on a separate line.

[para]

If this flag is not set (the default), the whole document will be
written on a single line, with minimum spacing between all elements.


[arg_def boolean indented]

If this flag is set the plugin will indent the markup commands
according to the structure of indices. To make this work this also
implies that [var newlines] is set.

[para]

If this flag is not set (the default), the output is formatted as per
the value of [var newlines], and no indenting is done.


[arg_def string meta]

This variable is meant to hold a fragment of HTML (default: empty).
The fragment it contains will be inserted into the generated output in
the <head> section of the document, just after the <title> tag.


[arg_def string header]

This variable is meant to hold a fragment of HTML (default: empty).
The fragment it contains will be inserted into the generated output
just after the <h1> title tag in the body of the document, in the
class.header <div>'ision.



[arg_def string footer]

This variable is meant to hold a fragment of HTML (default:
empty). The fragment it contains will be inserted into the generated
output just before the </body> tag, in the class.footer <div>'ision.


[arg_def dictionary rid]

The value of this variable (default: empty) maps references to the
identifiers to use as their anchor names. Each reference [var FOO] not
found in the dictionary uses [const REF-][var FOO] as anchor,
i.e. itself prefixed with the string [const REF-].


[arg_def string sepline]

The value of this variable is the string to use for the separator
comments inserted into the output when the outpout is broken across
lines and/or indented. The default string consists of 60 dashes.


[arg_def string class.main]

This variable contains the class name for the main <div>'ivision of
the generated document. The default is [const doctools].


[arg_def string class.header]

This variable contains the class name for the header <div>'ision of
the generated document. The default is [const toc-header].  This
division contains the document title, the user specified [var header],
if any, and a visible separator line.


[arg_def string class.title]

This variable contains the class name for the <h1> tag enclosing the
document title. The default is [const toc-title].


[arg_def string class.navsep]

This variable contains the class name for the <hr> separators in the
header and footer sections of the generated document. The default is
[const toc-navsep].


[arg_def string class.contents]

This variable contains the class name for the XXXXX holding the
keywords and their references in the generated document. The default
is [const toc-contents].


[arg_def string class.ref]

This variable contains the class name for the table elements which are
references to other documents. The default is [const toc-ref].


[arg_def string class.div]

This variable contains the class name for the table elements which are
divisions. The default is [const toc-div].


[arg_def string class.footer]

This variable contains the class name for the footer <div>'ision of
the generated document. The default is [const toc-footer]. This
division contains a browser-visible separator line and the user
specified [var footer], if any.


[list_end]

[emph Note] that this plugin ignores the standard configuration
variable [var format], and its value.

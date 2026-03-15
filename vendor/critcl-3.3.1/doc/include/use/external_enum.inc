[comment {-*- mode: tcl ; fill-column: 90 -*-}]

This section demonstrates how to convert from any kind of enumeration provided by an
external library to Tcl strings, and the converse.

[list_begin enumerated]

[enum] For all that this is a part of how to
[sectref {Using External Libraries} {Use External Libraries}], for the demonstratation
only the basics are needed.

[enum][vset base][example {
    package require critcl::emap

    # no header included due to use of literal ints instead of symbolic names

    critcl::emap::def yaml_sequence_style_t {
	any   0
	block 1
	flow  2
    }

    # encode: style to int
    critcl::cproc encode {yaml_sequence_style_t style} int {
	return style;
    }

    # decode: int to style
    critcl::cproc decode {int style} yaml_sequence_style_t {
	return style;
    }
}][vset rebuild]

[enum] The map converts between the Tcl level strings listed on the left side to the C
values on the right side, and the reverse.

[enum] It automatically generates [cmd critcl::argtype] and [cmd critcl::resulttype]
definitions.

[enum] [emph Attention] Like the default values for [cmd cproc] arguments, and the results
for [cmd cconst] definitions the values on the right side have to be proper C
rvalues. They have to match C type [type int].

[para] In other words, it is perfectly ok to use the symbolic names provided by the header
file of the external library.

[para] [emph Attention] This however comes at a loss in efficiency. As [vset critcl] then
has no insight into the covered range of ints, gaps, etc. it has to perform a linear
search when mapping from C to Tcl. When it knows the exact integer values it can use a
table lookup instead.

[para] [emph Attention] It also falls back to a search if a lookup table would contain more
than 50 entries.

[list_end]

[para] Packages: [term critcl::emap]

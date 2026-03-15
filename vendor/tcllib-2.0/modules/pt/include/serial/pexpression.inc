[comment {-*- text -*-}]
[section {PE serialization format}]

Here we specify the format used by the Parser Tools to serialize
Parsing Expressions as immutable values for transport, comparison,
etc.

[para]

We distinguish between [term regular] and [term canonical]
serializations.

While a parsing expression may have more than one regular
serialization only exactly one of them will be [term canonical].

[list_begin definitions][comment {-- serializations --}]
[def {Regular serialization}]

[list_begin definitions][comment {-- regular points --}]

[def [const {Atomic Parsing Expressions}]]
[list_begin enumerated][comment {-- atomic points --}]

[enum]
The string [const epsilon] is an atomic parsing expression. It matches
the empty string.

[enum]
The string [const dot] is an atomic parsing expression. It matches
any character.

[enum]
The string [const alnum] is an atomic parsing expression. It matches
any Unicode alphabet or digit character. This is a custom extension of
PEs based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const alpha] is an atomic parsing expression. It matches
any Unicode alphabet character. This is a custom extension of PEs
based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const ascii] is an atomic parsing expression. It matches
any Unicode character below U0080. This is a custom extension of PEs
based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const control] is an atomic parsing expression. It matches
any Unicode control character. This is a custom extension of PEs based
on Tcl's builtin command [cmd {string is}].

[enum]
The string [const digit] is an atomic parsing expression. It matches
any Unicode digit character. Note that this includes characters
outside of the [lb]0..9[rb] range. This is a custom extension of PEs
based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const graph] is an atomic parsing expression. It matches
any Unicode printing character, except for space. This is a custom
extension of PEs based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const lower] is an atomic parsing expression. It matches
any Unicode lower-case alphabet character. This is a custom extension
of PEs based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const print] is an atomic parsing expression. It matches
any Unicode printing character, including space. This is a custom
extension of PEs based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const punct] is an atomic parsing expression. It matches
any Unicode punctuation character. This is a custom extension of PEs
based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const space] is an atomic parsing expression. It matches
any Unicode space character. This is a custom extension of PEs based
on Tcl's builtin command [cmd {string is}].

[enum]
The string [const upper] is an atomic parsing expression. It matches
any Unicode upper-case alphabet character. This is a custom extension
of PEs based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const wordchar] is an atomic parsing expression. It
matches any Unicode word character. This is any alphanumeric character
(see alnum), and any connector punctuation characters (e.g.
underscore). This is a custom extension of PEs based on Tcl's builtin
command [cmd {string is}].

[enum]
The string [const xdigit] is an atomic parsing expression. It matches
any hexadecimal digit character. This is a custom extension of PEs
based on Tcl's builtin command [cmd {string is}].

[enum]
The string [const ddigit] is an atomic parsing expression. It matches
any decimal digit character. This is a custom extension of PEs based
on Tcl's builtin command [cmd regexp].

[enum]
The expression
    [lb]list t [var x][rb]
is an atomic parsing expression. It matches the terminal string [var x].

[enum]
The expression
    [lb]list n [var A][rb]
is an atomic parsing expression. It matches the nonterminal [var A].

[list_end][comment {-- atomic points --}]

[def [const {Combined Parsing Expressions}]]
[list_begin enumerated][comment {-- combined points --}]

[enum]
For parsing expressions [var e1], [var e2], ... the result of

    [lb]list / [var e1] [var e2] ... [rb]

is a parsing expression as well.

This is the [term {ordered choice}], aka [term {prioritized choice}].

[enum]
For parsing expressions [var e1], [var e2], ... the result of

    [lb]list x [var e1] [var e2] ... [rb]

is a parsing expression as well.

This is the [term {sequence}].

[enum]
For a parsing expression [var e] the result of

    [lb]list * [var e][rb]

is a parsing expression as well.

This is the [term {kleene closure}], describing zero or more
repetitions.

[enum]
For a parsing expression [var e] the result of

    [lb]list + [var e][rb]

is a parsing expression as well.

This is the [term {positive kleene closure}], describing one or more
repetitions.

[enum]
For a parsing expression [var e] the result of

    [lb]list & [var e][rb]

is a parsing expression as well.

This is the [term {and lookahead predicate}].

[enum]
For a parsing expression [var e] the result of

    [lb]list ! [var e][rb]

is a parsing expression as well.

This is the [term {not lookahead predicate}].


[enum]
For a parsing expression [var e] the result of

    [lb]list ? [var e][rb]

is a parsing expression as well.

This is the [term {optional input}].


[list_end][comment {-- combined points --}]
[list_end][comment {-- regular points --}]

[def {Canonical serialization}]

The canonical serialization of a parsing expression has the format as
specified in the previous item, and then additionally satisfies the
constraints below, which make it unique among all the possible
serializations of this parsing expression.

[list_begin enumerated][comment {-- canonical points --}]
[enum]

The string representation of the value is the canonical representation
of a pure Tcl list. I.e. it does not contain superfluous whitespace.

[enum]

Terminals are [emph not] encoded as ranges (where start and end of the
range are identical).

[comment {
	 Thinking about this I am not sure if that was a good move.
	 There are a lot more equivalent encodings around that just
	 the one I used above. Examples

	 	 {x {t a} {t b} {tc } {t d}}
	 	 {x {x {t a} {t b}} {x {tc } {t d}}}
	 	 {x {x {t a} {t b} {tc } {t d}}}

	 etc. Having the t/.. equivalence added it can now be argued
	 that we should handle these as well. Which essentially
	 amounts to a whole-sale system to simplify parsing
	 expressions. This moves expression equality from intensional
	 to extensional, or as near as is possible.

	 The only counter-argument I have is that the t/.. equivalence
	 is restricted to leaves of the tree, or alternatively, to
	 terminal symbol operators.
}]

[list_end][comment {-- canonical points --}]
[list_end][comment {-- serializations --}]
[para]

[subsection Example]

Assuming the parsing expression shown on the right-hand side of the
rule

[para]
[include ../example/expr_pe.inc]
[para]

then its canonical serialization (except for whitespace) is

[para]
[include ../example/expr_pe_serial.inc]
[para]

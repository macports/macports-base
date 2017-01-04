
[include whatis_json.inc]
[para]

It is formally specified by the rules below:

[list_begin enumerated][comment {-- json points --}]
[enum]
The JSON of any PEG is a JSON object.

[enum]
This object holds a single key, [const pt::grammar::peg], and its
value. This value holds the contents of the grammar.

[enum]
The contents of the grammar are a JSON object holding the set of
nonterminal symbols and the starting expression. The relevant keys and
their values are

[list_begin definitions][comment {-- grammar keywords --}]
[def [const rules]]

The value is a JSON object whose keys are the names of the nonterminal
symbols known to the grammar.

[list_begin enumerated][comment {-- nonterminals --}]
[enum]
Each nonterminal symbol may occur only once.

[enum]
The empty string is not a legal nonterminal symbol.

[enum]
The value for each symbol is a JSON object itself. The relevant
keys and their values in this dictionary are

[list_begin definitions][comment {-- nonterminal keywords --}]
[def [const is]]

The value is a JSON string holding the Tcl serialization of the
parsing expression describing the symbols sentennial structure, as
specified in the section [sectref {PE serialization format}].

[comment {
 This part we could try to expand further into a json data structure
(array of (objects of) arrays ?)
}]

[def [const mode]]

The value is a JSON holding holding one of three values specifying how
a parser should handle the semantic value produced by the symbol.

[include ../modes.inc]
[list_end][comment {-- nonterminal keywords --}]
[list_end][comment {-- nonterminals --}]

[def [const start]]

The value is a JSON string holding the Tcl serialization of the start
parsing expression of the grammar, as specified in the section
[sectref {PE serialization format}].

[list_end][comment {-- grammar keywords --}]

[enum]
The terminal symbols of the grammar are specified implicitly as the
set of all terminal symbols used in the start expression and on the
RHS of the grammar rules.

[list_end][comment {-- json points --}]

[para]

As an aside to the advanced reader, this is pretty much the same as
the Tcl serialization of PE grammars, as specified in section
[sectref {PEG serialization format}], except that the Tcl dictionaries
and lists of that format are mapped to JSON objects and arrays. Only
the parsing expressions themselves are not translated further, but
kept as JSON strings containing a nested Tcl list, and there is no
concept of canonicity for the JSON either.

[subsection Example]

Assuming the following PEG for simple mathematical expressions

[para]
[include ../example/expr_peg.inc]
[para]

a JSON serialization for it is

[para]
[include ../example/expr_json.inc]
[para]

and a Tcl serialization of the same is

[para]
[include ../example/expr_serial.inc]
[para]

The similarity of the latter to the JSON should be quite obvious.

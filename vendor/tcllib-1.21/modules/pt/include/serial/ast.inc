[comment {-*- text -*-}]
[section {AST serialization format}]

Here we specify the format used by the Parser Tools to serialize
Abstract Syntax Trees (ASTs) as immutable values for transport,
comparison, etc.

[para]

Each node in an AST represents a nonterminal symbol of a grammar, and
the range of tokens/characters in the input covered by it. ASTs do not
contain terminal symbols, i.e. tokens/characters. These can be
recovered from the input given a symbol's location.

[para]

We distinguish between [term regular] and [term canonical]
serializations.

While a tree may have more than one regular serialization only exactly
one of them will be [term canonical].


[list_begin definitions][comment {-- serializations --}]
[def {Regular serialization}]

[list_begin enumerated][comment {-- regular points --}]

[enum]
The serialization of any AST is the serialization of its root node.

[enum]
The serialization of any node is a Tcl list containing at least three
elements. 

[list_begin enumerated][comment {-- node elements --}]
[enum]
The first element is the name of the nonterminal symbol stored in the
node.

[enum]
The second and third element are the locations of the first and last
token in the token stream the node represents (covers).

[list_begin enumerated][comment {--- location constraints}]
[enum]
Locations are provided as non-negative integer offsets from the
beginning of the token stream, with the first token found in the
stream located at offset 0 (zero).

[enum]
The end location has to be equal to or larger than the start location.

[list_end][comment {--- location constraints}]

[enum]
All elements after the first three represent the children of the node,
which are themselves nodes. This means that the serializations of
nodes without children, i.e. leaf nodes, have exactly three elements.

The children are stored in the list with the leftmost child first, and
the rightmost child last.

[list_end][comment {-- node elements --}]
[list_end][comment {-- regular points --}]

[def {Canonical serialization}]

The canonical serialization of an abstract syntax tree has the format
as specified in the previous item, and then additionally satisfies the
constraints below, which make it unique among all the possible
serializations of this tree.

[list_begin enumerated][comment {-- canonical points --}]
[enum]

The string representation of the value is the canonical representation
of a pure Tcl list. I.e. it does not contain superfluous whitespace.

[list_end][comment {-- canonical points --}]
[list_end][comment {-- serializations --}]
[para]

[subsection Example]

Assuming the parsing expression grammar below

[para]
[include ../example/expr_peg.inc]
[para]

and the input string 

[example { 120+5 }]

then a parser should deliver the abstract syntax tree below (except for whitespace)

[para]
[include ../example/expr_ast.inc]
[para]

Or, more graphical

[para][image expr_ast][para]

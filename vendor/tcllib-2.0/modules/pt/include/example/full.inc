
In this section we are working a complete example, starting with a PEG
grammar and ending with running the parser generated from it over some
input, following the outline shown in the figure below:

[para][image flow][para]

Our grammar, assumed to the stored in the file [file calculator.peg]
is

[include expr_peg.inc]

From this we create a snit-based parser

[include full_[vset MODE].inc]

which leaves us with the parser package and class written to the file
[file calculator.tcl].

Assuming that this package is then properly installed in a place where
Tcl can find it we can now use this class via a script like

[include parser_use.inc]

where the abstract syntax tree stored in the variable will look like

[para][include expr_ast.inc][para]

assuming that the input file and channel contained the text

[example { 120+5 }]

A more graphical representation of the tree would be

[para][image expr_ast][para]

Regardless, at this point it is the user's responsibility to work with
the tree to reach whatever goal she desires. I.e. analyze it,
transform it, etc. The package [package pt::ast] should be of help
here, providing commands to walk such ASTs structures in various ways.

[para]

One important thing to note is that the parsers used here return a
data structure representing the structure of the input per the grammar
underlying the parser. There are [emph no] callbacks during the
parsing process, i.e. no [term {parsing actions}], as most other
parsers will have.

[para]

Going back to the last snippet of code, the execution of the parser
for some input, note how the parser instance follows the specified
[term {Parser API}].

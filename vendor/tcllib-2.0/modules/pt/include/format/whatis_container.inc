
The [const container] format is another form of describing parsing
expression grammars. While data in this format is executable it does
not constitute a parser for the grammar. It always has to be used in
conjunction with the package [package pt::peg::interp], a grammar
interpreter.

[para]

The format represents grammars by a [cmd snit::type], i.e. class,
whose instances are API-compatible to the instances of the
[package pt::peg::container] package, and which are preloaded with the
grammar in question.

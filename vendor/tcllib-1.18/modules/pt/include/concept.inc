[comment {
	 Description of the concepts used in parsing expression
	 grammars and how their relate to each other. This is useful
	 to understand the chosen serialization.
}]
[list_begin enumerated]
[enum]

A [term {parsing expression grammar}] consists of a
[term {start parsing expression}] and a (possibly empty) list of
[term rules].

[enum]
Each rule defines a nonterminal symbol of the grammar, with its name,
semantic mode, and sentennial structure. The latter is provided by a
[term {parsing expression}].

[enum]
Each nonterminal symbol is specified at most once, with its name as
the identifying part.

[list_end]

[comment {
	 Description of the concepts used in tables of contents and how
	 their relate to each other. This is useful to understand the
	 serialization chosen for tables of contents.
}]
[list_begin enumerated]
[enum]

A [term {table of contents}] consists of a (possibly empty) list of
[term elements].

[enum]
Each element in the list is identified by its label.

[enum]
Each element is either a [term reference], or a [term division].

[enum]
Each reference has an associated document, identified by a symbolic
id, and a textual description.

[enum]
Each division may have an associated document, identified by a
symbolic id. 

[enum]
Each division consists consists of a (possibly empty) list of
[term elements], with each element following the rules as specified in
item 2 and above.

[list_end]

A few notes

[list_begin enumerated]
[enum]
The above rules span up a tree of elements, with references as the
leaf nodes, and divisions as the inner nodes, and each element
representing an entry in the whole table of contents.

[enum]
The identifying labels of any element E are unique within their
division (or toc), and the full label of any element E is the list of
labels for all nodes on the unique path from the root of the tree to
E, including E.

[list_end]

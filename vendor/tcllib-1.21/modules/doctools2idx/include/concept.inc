[comment {
	 Description of the concepts used in keyword indices and how
	 their relate to each other. This is useful to understand the
	 serialization chosen for keyword indices.
}]
[list_begin enumerated]
[enum]
A [term {keyword index}] consists of a (possibly empty) set of [term keywords].

[enum]
Each keyword in the set is identified by its name.

[enum]
Each keyword has a (possibly empty) set of [term references].

[enum]
A reference can be associated with more than one keyword.

[enum]
A reference not associated with at least one keyword is not possible
however.

[enum]
Each reference is identified by its target, specified as either an url
or symbolic filename, depending on the type of reference ([const url],
or [const manpage]).

[enum]
The type of a reference (url, or manpage) depends only on the
reference itself, and not the keywords it is associated with.

[enum]
In addition to a type each reference has a descriptive label as
well. This label depends only on the reference itself, and not the
keywords it is associated with.

[list_end]

A few notes

[list_begin enumerated]
[enum]
Manpage references are intended to be used for references to the
documents the index is made for. Their target is a symbolic file name
identifying the document, and export plugins may replace symbolic with
actual file names, if specified.

[enum]
Url references are intended on the othre hand are inteded to be used
for links to anything else, like websites. Their target is an url.

[enum]
While url and manpage references share a namespace for their
identifiers, this should be no problem, given that manpage identifiers
are symbolic filenames and as such they should never look like urls,
the identifiers for url references.

[list_end]

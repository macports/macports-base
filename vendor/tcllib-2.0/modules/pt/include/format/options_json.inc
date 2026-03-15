
[list_begin options]
[include options_std.inc]

[opt_def -indented boolean]

If this option is set the system will break the generated JSON across
lines and indent it according to its inner structure, with each key of
a dictionary on a separate line.

[para]

If the option is not set (the default), the whole JSON object will be
written on a single line, with minimum spacing between all elements.


[opt_def -aligned boolean]

If this option is set the system will ensure that the values for the
keys in a dictionary are vertically aligned with each other, for a
nice table effect.

To make this work this also implies that [option -indented] is set.

[para]

If the option is not set (the default), the output is formatted as per
the value of [var indented], without trying to align the values for
dictionary keys.

[list_end]

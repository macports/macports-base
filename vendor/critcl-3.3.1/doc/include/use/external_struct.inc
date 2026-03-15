[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Handle structures provided by external libraries using either
[sectref {Structure Types}] or [sectref {Large Structures}] as template.

[enum] [emph Attention]. The choice is with the developer.

[para] This is true even if the external structure is not reference counted by itself.

[para] To reference count a structure [type S] without such simply wrap [type S] into a
local structure which provides the reference count and has a field for [type S] (pointer
or value).

[enum] [emph Attention] Opaque external types, i.e. pointers to structures with hidden
fields, can also be handled by the given templates.

[list_end]

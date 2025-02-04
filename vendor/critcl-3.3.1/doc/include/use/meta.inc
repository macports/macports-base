[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] See and reread the [sectref Basics {basic package}] for the introduction of the
commands referenced below.

[enum] Use the command [cmd critcl::license] to set the package license.

[para] Use the same command to set the package author.

[para] Both arguments are free form text.

[enum] Use the command [cmd critcl::summary] to set a short package description.

[enum] Use the command [cmd critcl::description] to set a longer package description.

[para] The arguments of both commands are free form text.

[enum] Use the command [cmd critcl::subject] to set one or more keywords.

[para] [emph Attention] Contrary to the other commands the arguments accumulate.

[enum] All the commands are optional.

[enum] Their information is not placed into the generated C code.

[enum] In [term {package mode}] the information is placed into the file [file teapot.txt]
of the generated package.

[enum] This file serves as integration point for [term Teapot], the package system of
[term ActiveTcl].

[list_end]


[emph "BEWARE"]
The commands in this package expect binary data as their input.

When a [option -file] is provided then this is ensured by the commands
themselves, as they open the referenced file in binary mode.

When literal data, or a [option -channel] are provided instead, then the
command's [emph {caller is responsible}] for ensuring this fact.

The necessary conversion command is [cmd {encoding convertto utf-8 $string}].

[para]
[emph "ATTENTION"], there is a [emph "Tcl 9 COMPATIBILITY ISSUE"] here.

[para] [emph {Tcl 8.x silently mishandles}] non-binary input by cutting it
internally to size. I.e. by only using the low byte of a higher unicode point.
No error is thrown, the [emph {result is simply wrong}].

[para] [emph {Tcl 9 throws an error}] instead, i.e.
[example {expected byte sequence but character <location> was ...}]

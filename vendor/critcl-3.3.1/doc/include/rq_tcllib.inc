[comment {-*- mode: tcl ; fill-column: 90 -*-}]

The implementation of [vset critcl] uses and depends on 

[list_begin enumerated]
[enum] [package cmdline]
[list_end]

[para] Depending on how Tcl was installed this package may be available already without
action, or not.

Invoke the command

[example {
    echo 'puts [package require cmdline]' | tclsh
}]

to check if the package is present or not. If it is present then its version number will
be printed, else the error message [const {can't find package cmdline}] or similar.

[para] If it is not present install the package as per the instructions for the chosen Tcl
installation.

[para] [strong Note], the package [package cmdline] may not exist as its own installable
package. In such a case check if the chosen Tcl installation provides a [package tcllib]
package and install that. This should install all the packages in the Tcllib bundle,
including [package cmdline].

[para] As a last fallback, go to [vset tcllib_home] and follow the instructions to install
the bundle from scratch.

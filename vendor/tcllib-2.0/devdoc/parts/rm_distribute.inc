
With the release made it has to be published and the world notified of
its existence.

[list_begin enumerated]

[enum]	    Create a proper fossil event for the release, via
	    [uri http://core.tcl-lang.org/tcllib/eventedit].

[para]	    An [uri http://core.tcl-lang.org/tcllib/event/dac0ddcd2e990234143196b4dc438fe01e7b9817 {existing event}] should be used as template.

[enum]	    Update a number of web locations:

[list_begin enumerated]
[enum]	    [uri http://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md {Home page}]
[enum]	    [uri http://core.tcl-lang.org/tcllib/wiki?name=Downloads     Downloads]
[enum]	    [uri http://core.tcl-lang.org/tcllib/wiki?name=Past+Releases {Past Releases}]
[enum]	    [uri http://www.tcl-lang.org/home/release.txt     ]
[enum]	    [uri http://www.tcl-lang.org/software/tcllib/*.tml]
[enum]	    [uri http://wiki.tcl-lang.org/page/Tcllib]
[list_end]

The first location maps to the file [file embedded/index.md] in the
repository itself, as such it can edited as part of the release
process. This is where reference to the new fossil event is added, as
the new current release.

[para] The next two locations are in the fossil tcllib wiki and
require admin or wiki write permissions for
[uri http://core.tcl-lang.org/tcllib].

[para] The last two locations require ssh access to
[uri http://www.tcl-lang.org] and permission to edit
files in the web area.


[enum]	***TODO*** mailing lists and other places to send notes to.

[list_end]

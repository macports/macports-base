
[subsection Tcl]

As we are installing a number of Tcl packages and applications it
should be pretty much obvious that a working installation of Tcl
itself is needed, and I will not belabor the point.

[para] Out of the many possibilities use whatever you are comfortable
with, as long as it provides at the very least Tcl 8.2, or higher.

This may be a Tcl installation provided by your operating system
distribution, from a distribution-independent vendor, or built by
yourself.

[para] [emph Note] that the packages in Tcllib have begun to require
8.4, 8.5, and even 8.6. Older versions of Tcl will not be able to use
such packages. Trying to use them will result in
[emph {package not found}] errors, as their package index files will
not register them in versions of the core unable to use them.

[para] Myself, I used (and still use)
[uri http://www.activestate.com ActiveState's]
ActiveTcl 8.5 distribution during development, as I am most familiar
with it.

[para] [emph {(Disclosure: I, Andreas Kupries, worked for ActiveState until 2016, maintaining ActiveTcl and TclDevKit for them).}].
I am currently working for SUSE Software Canada ULC, although not in
Tcl-related areas.

[para] This distribution can be found at
[uri http://www.activestate.com/activetcl]. Retrieve the archive of
ActiveTcl 8.5 (or higher) for your platform and install it as directed
by ActiveState.

[para] For those wishing to build and install Tcl on their own, the
relevant sources can be found at

[list_begin definitions]
[def Tcl] [uri http://core.tcl-lang.org/tcl/]
[list_end]

together with the necessary instructions on how to build it.

[para] If there are problems with building, installing, or using Tcl,
please file a ticket against [term Tcl], or the vendor of your
distribution, and [emph not] [term Tcllib].

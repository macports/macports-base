
For [term Unix]-like environments Tcllib comes with the standard set
of files to make

[example {
  ./configure
  make install
  # or just
  make
}]

a suitable way of installing it.

This is a standard non-interactive install automatically figuring out
where to place everything, i.e. packages, applications, and the
manpages.

[para][emph {This includes the Tcllibc binary package}].
Therefore requires an installation of Critcl.

[para] To install only specific parts of the project use

[example {
  make install-binaries      # Tcllibc. Requires an installation of Critcl.
  make install-tcl           # Tcl packages and applications.
  make install-libraries     # Tcl packages alone.
  make install-applications  # Applications alone.
  make install-doc           # Nroff manpages.
}]

[para] For a graphical installer invoke

[example {
  ./installer.tcl
}]

instead.

[emph Note] however that this installer handles only the Tcl packages,
applications, and the documentation.

It does [emph not] handle the binary Tcllibc.

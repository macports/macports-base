[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[para] That a working installation of [vset critcl] will require a working installation of
[vset tcl_home] should be obvious.

[para] Installing Tcl however is out of scope here, same as for installing a working C
compiler.

[para] There are too many options, starting from
[uri http://core.tcl-lang.org/tcl {building it from scratch}], installing what is provided
by the platform's package manager ([vset zypper], [vset yum], [vset apt-get], and more),
to using some vendor's [uri https://core.tcl-lang.org/dist.html distribution].

[para] A single piece of advice however.

[para] While [vset critcl] currently supports running on Tcl 8.4 and higher, and the
creation of packages for the same, the last release for this version was in 2013 (9 years
ago at the time of writing). Similarly, the last release for Tcl 8.5 was in 2016 (6 years
ago). Both are official end of life.

[para] Given this I recommend to install and use Tcl 8.6.

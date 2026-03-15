[comment {-*- mode: tcl ; fill-column: 90 -*-}]

Installing [vset critcl] contains an implicit test of its functionality.

[para] One of its operation modes uses the MD5 hash internally to generate unique ids for
sources, as a means of detecting changes. To make generation of such hashes fast a
[vset critcl]-based package for MD5 is installed as part of the main installation process.

[para] In other words, after installing the core packages of [vset critcl] this partial
installation is used to build the rest.

[para] This is possible because building a package from [vset critcl]-based sources is the
operation mode not using MD5, therefore there is no circular dependency.

[para] For our purposes this however is also a self-test of the system, verifying that the
core of [vset critcl] works, as well as the C compiler.

[para] For additional testing simply move on to section [sectref {The First Package}] of
the guide on [term {How To Use CriTcl}].

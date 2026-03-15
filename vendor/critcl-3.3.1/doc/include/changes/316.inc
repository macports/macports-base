[section {Changes for version 3.1.6}]
[list_begin enumerated]

[enum] Fixed issue #21. While the multi-definition of the stub-table
       pointer variables was ok with for all the C linkers seen so far
       C++ linkers did not like this at all. Reworked the code to
       ensure that this set of variables is generated only once, in
       the wrapper around all the pieces to assemble.

[enum] Fixed issue #22, the handling of the command identifier
       arguments of [cmd critcl::ccommand], [cmd critcl::cproc], and
       [cmd critcl::cdata]. We now properly allow any Tcl identifier
       and generate proper internal C identifiers from them.

[para] As part of this the signature of command [cmd critcl::name2c]
       changed. The command now delivers a list of four values instead
       of three. The new value was added at the end.

[para] Further adapted the implementation of package
       [package critcl::class], a user of [cmd critcl::name2c].
       This package is now at version 1.0.6 and requires critcl 3.1.6

[para] Lastly fixed the mis-handling of option [option -cname] in
       [cmd critcl::ccommand], and [cmd critcl::cproc].

[enum] Fixed issue #23.

[list_end]

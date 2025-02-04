
CriTcl can be used in three different modes of operation, called

[list_begin enumerated]
[enum] [term {Compile & Run}], and
[enum] [term {Generate Package}]
[enum] [term {Generate TEA Package}]
[list_end]

[term {Compile & Run}] was the original mode and is the default for
[manpage {critcl_pkg}].  Collects the C fragments from the
[vset critcl_script], builds them as needed, and caches the results to
improve load times later.

[para]

The second mode, [term {Generate Package}], was introduced to enable
the creation of (prebuilt) deliverable packages which do not depend on
the existence of a build system, i.e. C compiler, on the target
machine.

This was originally done through the experimental [cmd Critbind] tool,
and is now handled by the [manpage {CriTcl Application}], also named
[cmd critcl].

[para]

Newly introduced with CriTcl version 3 is
[term {Generate TEA Package}]. This mode constructs a directory
hierarchy from the package which can later be built like a regular TEA
package, i.e. using

[example {
	.../configure --prefix ...
	make all isntall
}]

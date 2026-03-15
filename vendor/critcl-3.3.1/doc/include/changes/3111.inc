[section {Changes for version 3.1.11}]
[list_begin enumerated]

[enum] Fixed issue #37, via pull request #38, with thanks to
       Jos DeCoster. Information was stored into the v::delproc
       and v::clientdata arrays using a different key than when
       retrieving the same information, thus failing the latter.

[enum] New convenience command [cmd critcl::include] for easy
       inclusion of headers and other C files.

[enum] New command [cmd critcl::make] to generate a local header of
       other C files for use by other parts of a package through
       inclusion.

[enum] New utility package [package critcl::literals] for quick and
       easy setup of and access to pools of fixed Tcl_Obj* strings.

       Built on top of [package critcl::iassoc].

[enum] New utility package [package critcl::bitmap] for quick and easy
       setup and use of mappings between C bitsets and Tcl lists whose
       string elements represent that set.

       Built on top of [package critcl::iassoc].

[list_end]

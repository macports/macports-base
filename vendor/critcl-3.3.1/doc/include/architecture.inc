
The system consists of two main layers, as seen in the figure below,
plus a support layer containing general packages the system uses during
operation.

[para][image architecture][para]

[list_begin enumerated]
[enum]

At the top we have an application built on top of the core packages,
providing command line access to the second and third usage modes,
i.e. [term {Generate Package}] and [term {Generate TEA Package}].

[list_begin definitions][comment {----- application ---}]
[def [syscmd critcl]]
[def [package critcl::app]]
[list_end][comment {------------------- application ---}]

[enum]

Below that is the core package providing the essential functionality
of the system, plus various utility packages which make common tasks
more convenient.

[list_begin definitions][comment {----- core ---}]
[def [package critcl]]
[def [package critcl::util]]
[list_end][comment {------------------- core ---}]

[enum]
Lastly a layer of supporting packages, mostly external to critcl.

[list_begin definitions][comment {----- support ---}]
[def [package md5]]
For this pure-Tcl package to be fast users should get one of several
possible accelerator packages:
[list_begin enumerated]
[enum] [package tcllibc]
[enum] [package Trf]
[enum] [package md5c]
[list_end]

[def [package cmdline]]
[def [package platform]]
[def [package stubs::container  ]]
[def [package stubs::reader     ]]
[def [package stubs::writer     ]]
[def [package stubs::gen        ]]
[def [package stubs::gen::init  ]]
[def [package stubs::gen::header]]
[def [package stubs::gen::decl  ]]
[def [package stubs::gen::macro ]]
[def [package stubs::gen::slot  ]]
[def [package stubs::gen::lib   ]]
[list_end][comment {------------------- support ---}]
[list_end]

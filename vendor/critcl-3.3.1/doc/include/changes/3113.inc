[section {Changes for version 3.1.13}]
[list_begin enumerated]

[enum]	Merged PR #43. Fixed bug loading adjunct Tcl sources.

[enum]	Fixes in documentation and generated code of package
	"critcl::enum". Bumped to version 1.0.1.

[enum]	Fixes in documentation of package "critcl::bitmap".

[enum]	New package "critcl::emap". In essence a variant or cross of
	"critcl::bitmap" with behaviour like "critcl::enum".

[enum]	Merged PR #49. Fixed documentation typo.

[enum]	Merged PR #46. Fixed documentation typo.

[enum]	Merged PR #47. Fixes to test results to match the accumulated
	code changes. Also made portable across Tcl versions (varying
	error syntax).

[enum]	New predefined argument- and result-type "wideint" mapping to
	Tcl_WideInt.

[enum]	New predefined argument-type "bytes" mapping to tuple of
	byte-array data and length. Note: The existing "bytearray"
	type (and its aliases) was left untouched, to keep backward
	compatibility.

[enum]	Modified the internal interface between the Tcl shim and C
	function underneath "critcl::cproc" with respect to the
	handling of optional arguments.

	An optional argument "X" now induces the use of two C
    	arguments, "X" and "has_X".  The new argument "has_X" is of
    	boolean (int) type. It is set to true when X is set, and set
    	to false when X has the default value. C code which cares
    	about knowing if the argument is default or not is now able to
    	check that quickly, without having to code the default value
    	inside.

	NOTE: This change is visible in the output of the advanced
    	      commands "argcnames", "argcsignature", "argvardecls",
    	      and "argconversion".

[enum]	Fixed issue #50 and documented the availability of variable
	"interp" (type Tcl_Interp*) within "critcl::cinit" C code
	fragments.

	Note that while the old, undocumented name of the variable,
	"ip", is still usable, it is deprecated. It will be fully
	removed in two releases, i.e. for release 3.1.15.

	The variable name was changed to be consistent with other code
	environments.

[enum]	Fixed issue #51. Disabled the generation of #line directives
	for "critcl::config lines 0" coming from template files, or
	code generated with them before the final value of this
	setting was known.

[enum]	Fixed issue with handling of namespaced package names in
	"critcl::iassoc". Equivalent to a bug in "critcl::class" fixed
	for critcl 3.1.1, critcl::class 1.0.1.

	Note: "literals", "enum", "emap", and "bitmap" do not require
	a fix as they are all built on top of "iassoc".

[list_end]

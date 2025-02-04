[section {Changes for version 3.0.4}]
[list_begin enumerated]

[enum]	Fixed generation of the package's initname when the incoming
	code is read from stdin and has no proper path.

[enum]	Fixed github issue 11. Now using /LIBPATH instead of -L
	on Windows (libinclude configuration setting).

[enum]	Extended critcl to handle -l:path format of -l options.
	GNU ld 2.22+ handles this by searching for the path as
	is. Good when specifying static libraries, as plain -l looks
	for shared libraries in preference over static. critcl handles
	it now, as older GNU ld's do not understand it, nor the
	various vendor-specific linkers.

[enum]	Fixed github issue #12. CriTcl now determines the version of
	MSVC in use and uses it to switch between various link debug
	options. Simplified the handling of bufferoverflowU.lib also,
	making use of the same mechanism and collapsing the two
	configurations sections we had back into one.

[enum]	Reworked the insertion of #line pragmas into the generated C
	code to avoid limitations on the line number argument imposed
	by various compilers, and be more accurate.

[enum]	Modified argument processing. Option -libdir now also
	implies -L for its argument.

[enum]	Extended handling of option -show ([cmd critcl::showconfig])
	to list the path of the configuration file the data is coming
	from. Good for debugging configuration processing.

[enum]	Extended the build script with targets to regenerate the
	embedded documentation, and diagrams, and to generate a
	release.

[list_end]

# -*- tcl -*-
# STUBS handling -- Code generation: Writing the initialization code for IMPORTers.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container

namespace eval ::stubs::gen::lib::g {
    namespace import ::stubs::gen::*
}

namespace eval ::stubs::gen::lib::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::lib::gen {table} {
    # Assuming that dependencies only go one level deep, we need to
    # emit all of the leaves first to avoid needing forward
    # declarations.

    variable template

    # Assuming that dependencies only go one level deep, we emit all
    # of the leaves first to avoid needing forward declarations.

    set leaves {}
    set roots  {}

    foreach name [lsort [c::interfaces $table]] {
	if {[c::hooks? $table $name]} {
	    lappend roots $name
	} else {
	    lappend leaves $name
	}
    }

    set headers   {}
    set variables {}
    set hooks     {}

    foreach name [concat $leaves $roots] {
	set capName [g::cap $name]

	# POLISH - format the variables code block aligned using
	# maxlength of interface names.
	lappend headers   "\#include \"${name}Decls.h\""
	lappend variables "const ${capName}Stubs* ${name}StubsPtr;"

	# Check if this is a hook. If yes it needs additional setup.
	set parent [Parent $table $name]
	if {$parent eq ""} continue
	lappend hooks "    ${name}StubsPtr = ${parent}StubsPtr->hooks->${name}Stubs;"
    }

    set pname   [c::library? $table] ; # FUTURE: May be separate from the library
    #                                    namespaces!
    set name    [string map {:: _} [c::library? $table]]
    set capName [g::cap $name]
    set upName  [string toupper $name]

    set headers   [Block $headers]
    set variables [Block $variables]
    set hooks     [Block $hooks]

    return [string map \
		[list \
		     @PKG@     $pname \
		     @@        $name  \
		     @UP@      $upName \
		     @CAP@     $capName \
		     @HEADERS@ $headers  \
		     @VARS@    $variables \
		     @HOOKS@   $hooks    \
		    ] $template]
    return $text
}

proc ::stubs::gen::lib::Block {list} {
    if {![llength $list]} { return "" }
    return \n[join $list \n]\n
}

proc ::stubs::gen::lib::make@ {basedir table} {
    make [path $basedir [c::library? $table]] $table
}

proc ::stubs::gen::lib::make {path table} {
    set c [open $path w]
    puts -nonewline $c [gen $table]
    close $c
    return
}

proc ::stubs::gen::lib::path {basedir name} {
    return [file join $basedir ${name}StubLib.c]
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::lib::Parent {table name} {
    # Check if this interface is a hook for some other interface.
    # TODO: Make this a container API command.
    foreach intf [c::interfaces $table] {
	if {[c::hooks? $table $intf] &&
	    ([lsearch -exact [c::hooksof $table $intf] $name] >= 0)} {
	    return $intf
	}
    }
    return ""
}

# # ## ### #####
namespace eval ::stubs::gen::lib {
    #checker exclude warnShadowVar
    variable template [string map {{
	} {
}} {
	/*
	 * @@StubLib.c --
	 *
	 * Stub object that will be statically linked into extensions that wish
	 * to access @@.
	 */

	/*
	 * We need to ensure that we use the stub macros so that this file contains
	 * no references to any of the stub functions.  This will make it possible
	 * to build an extension that references @CAP@_InitStubs but doesn't end up
	 * including the rest of the stub functions.
	 */

	#ifndef USE_TCL_STUBS
	#define USE_TCL_STUBS
	#endif
	#undef  USE_TCL_STUB_PROCS

	#include <tcl.h>

	#ifndef USE_@UP@_STUBS
	#define USE_@UP@_STUBS
	#endif
	#undef  USE_@UP@_STUB_PROCS
	@HEADERS@
	/*
	 * Ensure that @CAP@_InitStubs is built as an exported symbol.  The other stub
	 * functions should be built as non-exported symbols.
	 */

	#undef  TCL_STORAGE_CLASS
	#define TCL_STORAGE_CLASS DLLEXPORT
	@VARS@
	
	/*
	 *----------------------------------------------------------------------
	 *
	 * @CAP@_InitStubs --
	 *
	 * Checks that the correct version of @CAP@ is loaded and that it
	 * supports stubs. It then initialises the stub table pointers.
	 *
	 * Results:
	 *  The actual version of @CAP@ that satisfies the request, or
	 *  NULL to indicate that an error occurred.
	 *
	 * Side effects:
	 *  Sets the stub table pointers.
	 *
	 *----------------------------------------------------------------------
	 */

	#ifdef @CAP@_InitStubs
	#undef @CAP@_InitStubs
	#endif

	char *
	@CAP@_InitStubs(Tcl_Interp *interp, CONST char *version, int exact)
	{
	    CONST char *actualVersion;

	    actualVersion = Tcl_PkgRequireEx(interp, "@PKG@", version,
					     exact, (ClientData *) &@@StubsPtr);
	    if (!actualVersion) {
		return NULL;
	    }

	    if (!@@StubsPtr) {
		Tcl_SetResult(interp,
			      "This implementation of @CAP@ does not support stubs",
			      TCL_STATIC);
		return NULL;
	    }
	    @HOOKS@
	    return (char*) actualVersion;
	}
    }]

    namespace export gen make@ make rewrite@ rewrite path
}

# # ## ### ##### ######## #############
package provide stubs::gen::lib 1.1.1
return

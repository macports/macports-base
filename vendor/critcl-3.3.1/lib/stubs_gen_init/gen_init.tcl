# -*- tcl -*-
# STUBS handling -- Code generation: Writing the initialization code for EXPORTers.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A gen is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container

namespace eval ::stubs::gen::init::g {
    namespace import ::stubs::gen::*
}

namespace eval ::stubs::gen::init::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::gen::init::gen {table} {
    # Assuming that dependencies only go one level deep, we need to
    # emit all of the leaves first to avoid needing forward
    # declarations.

    set leaves {}
    set roots  {}

    foreach name [lsort [c::interfaces $table]] {
	if {[c::hooks? $table $name]} {
	    lappend roots $name
	} else {
	    lappend leaves $name
	}
    }

    set text {}
    foreach name $leaves {
	append text [Emit $table $name]
    }
    foreach name $roots {
	append text [Emit $table $name]
    }

    return $text
}

proc ::stubs::gen::init::make@ {basedir table} {
    make [path $basedir $table] $table
}

proc ::stubs::gen::init::make {path table} {
    variable template

    set c [open $path w]
    puts -nonewline $c \
	[string map \
	     [list @@ [string map {:: _} [c::library? $table]]] \
	     $template]
    close $c

    rewrite $path $table
    return
}

proc ::stubs::gen::init::rewrite@ {basedir table} {
    rewrite [path $basedir $table] $table
    return
}

proc ::stubs::gen::init::rewrite {path table} {
    g::rewrite $path [gen $table]
    return
}

proc ::stubs::gen::init::path {basedir table} {
    return [file join $basedir [c::library? $table]StubInit.c]
}

# # ## ### #####
## Internal helpers.

proc ::stubs::gen::init::Emit {table name} {
    # See tcllib/textutil as well.
    set capName [g::cap $name]

    if {[c::hooks? $table $name]} {
	append text "\nstatic const ${capName}StubHooks ${name}StubHooks = \{\n"
	set sep "    "
	foreach sub [c::hooksof $table $name] {
	    append text $sep "&${sub}Stubs"
	    set sep ",\n    "
	}
	append text "\n\};\n"
    }

    # Check if this interface is a hook for some other interface.
    # TODO: Make this a container API command.
    set root 1
    foreach intf [c::interfaces $table] {
	if {[c::hooks? $table $intf] &&
	    ([lsearch -exact [c::hooksof $table $intf] $name] >= 0)} {
	    set root 0
	    break
	}
    }

    # Hooks are local to the file.
    append text "\n"
    if {!$root} {
	append text "static "
    }
    append text "const ${capName}Stubs ${name}Stubs = \{\n"
    append text "    TCL_STUB_MAGIC,\n"

    if {[c::epoch? $table] ne ""} {
	set CAPName [string toupper $name]
	append text "    ${CAPName}_STUBS_EPOCH,\n"
	append text "    ${CAPName}_STUBS_REVISION,\n"
    }

    if {[c::hooks? $table $name]} {
	append text "    &${name}StubHooks,\n"
    } else {
	append text "    0,\n"
    }

    append text [g::forall $table $name [namespace current]::Make 1 \
		     "    0, /* @@ */\n"]

    append text "\};\n"
    return $text
}

# Make --
#
#	Generate the prototype for a function.
#
# Arguments:
#	name	The interface name.
#	decl	The function declaration.
#	index	The slot index for this function.
#
# Results:
#	Returns the formatted declaration string.

proc ::stubs::gen::init::Make {name decl index} {
    #puts "INIT($name $index) = |$decl|"

    lassign $decl rtype fname args

    if {![llength $args]} {
	append text "    &$fname, /* $index */\n"
    } else {
	append text "    $fname, /* $index */\n"
    }
    return $text
}

# # ## ### #####
namespace eval ::stubs::gen::init {
    #checker exclude warnShadowVar
    variable template [string map {{	} {}} {
	/* @@StubsInit.c
	 *
	 * The contents of this file are automatically generated
	 * from the @@.decls file.
	 *
	 */

	#include "@@.h"

	/* !BEGIN!: Do not edit below this line. */
	/* !END!: Do not edit above this line. */
    }]

    namespace export gen make@ make rewrite@ rewrite path
}

# # ## ### ##### ######## #############
package provide stubs::gen::init 1.1.1
return

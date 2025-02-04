# -*- tcl -*-
# STUBS handling -- Write stubs table as .decls file
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# A stubs table is represented by a dictionary value.
# A container is a variable holding a stubs table value.

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::gen
package require stubs::container

namespace eval ::stubs::writer::g {
    namespace import ::stubs::gen::*
}

namespace eval ::stubs::writer::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::writer::gen {table} {

    set defaults [c::new]
    set dscspec [c::scspec?   $defaults]
    set depoch  [c::epoch?    $defaults]

    set name   [c::library?  $table]
    set scspec [c::scspec?   $table]
    set epoch  [c::epoch?    $table]
    set rev    [c::revision? $table]

    lappend lines "\# ${name}.decls -- -*- tcl -*-"
    lappend lines "\#"
    lappend lines "\#\tThis file contains the declarations for all public functions"
    lappend lines "\#\tthat are exported by the \"${name}\" library via its stubs table."
    lappend lines "\#"

    lappend lines ""
    lappend lines "library   [list $name]"

    if {($scspec ne $dscspec) ||
	($epoch  ne $depoch )} {
	if {$scspec ne $dscspec} {
	    lappend lines "scspec    [list $scspec]"
	}
	if {$epoch  ne $depoch } {
	    lappend lines "epoch     [list $epoch]"
	    lappend lines "revision  [list $rev]"
	}
    }

    foreach if [c::interfaces $table] {
	lappend lines ""
	lappend lines "interface [list $if]"

	if {[c::hooks? $table $if]} {
	    lappend lines "hooks [list [c::hooksof $table $if]]"
	}
	lappend lines \
	    [g::forall $table $if \
		 [list [namespace current]::Make $table] \
		 0]
    }

    lappend lines "\# END $name"

    return [join $lines \n]
}

# # ## ### #####
## Internal helpers.

proc ::stubs::writer::Make {table if decl index} {
    #puts |---------------------------------------
    #puts |$if|$index|$decl|

    lassign $decl rtype fname arguments
    if {[llength $arguments]} {
	# what about the third piece of info, array flag?! ...

	set suffix {}
	foreach a $arguments {
	    if {$a eq "void"} {
		lappend ax $a
	    } elseif {$a eq "TCL_VARARGS"} {
		set suffix ", ..."
	    } else {
		lassign $a atype aname aflag
		# aflag either "", or "[]".
		lappend ax "$atype $aname$aflag"
		#puts \t|$atype|$aname|$aflag|
	    }
	}
	set ax [join $ax {, }]$suffix
    } else {
	set ax void
    }
    set cdecl     "\n    $rtype $fname ($ax)\n"
    set platforms [c::slotplatforms $table $if $index]

    lappend lines ""
    lappend lines "declare $index [list $platforms] \{$cdecl\}"

    return [join $lines \n]\n
}

# # ## ### #####
namespace eval ::stubs::writer {
    namespace export gen
}

# # ## ### #####
package provide stubs::writer 1.1.1
return

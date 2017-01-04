# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::randomseed 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Generate and combine seed lists for the
# Meta description random number generator inside of the
# Meta description tcl::chan::random channel. Sources of
# Meta description randomness are process id, time in two
# Meta description granularities, and Tcl's random number
# Meta description generator.
# Meta platform tcl
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.5

# # ## ### ##### ######## #############

namespace eval ::tcl {}

proc ::tcl::randomseed {} {
    set result {}
    foreach v [list \
		   [pid] \
		   [clock seconds] \
		   [expr {int(256*rand())}] \
		   [clock clicks -milliseconds]] \
	{
	    lappend result [expr {$v % 256}]
	}
    return $result
}

proc ::tcl::combine {a b} {
    while {[llength $a] < [llength $b]} {
	lappend a 0
    }
    while {[llength $b] < [llength $a]} {
	lappend b 0
    }

    set result {}
    foreach x $a y $b {
	lappend result [expr {($x ^ $y) % 256}]
    }
    return $result
}

# # ## ### ##### ######## #############
package provide tcl::randomseed 1
return

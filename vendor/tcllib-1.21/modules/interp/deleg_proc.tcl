# interp.tcl
# Some utility commands for creation of delegation procedures
# (Delegation of commands to a remote interpreter via a comm
# handle).
#
# Copyright (c) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: deleg_proc.tcl,v 1.2 2006/09/01 19:58:21 andreas_kupries Exp $

package require Tcl 8.3

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::interp::delegate {}

# ### ### ### ######### ######### #########
## Public API

proc ::interp::delegate::proc {args} {
    # syntax: ?-async? name arguments comm id

    set async 0
    while {[string match -* [set opt [lindex $args 0]]]} {
	switch -exact -- $opt {
	    -async {
		set async 1
		set args [lrange $args 1 end]
	    }
	    default {
		return -code error "unknown option \"$opt\", expected -async"
	    }
	}
    }
    if {[llength $args] != 4} {
	return -code error "wrong # args"
    }
    foreach {name arguments comm rid} $args break
    set base [namespace tail $name]

    if {![llength $arguments]} {
	set delegate "[list $base]"
    } elseif {[string equal args [lindex $arguments end]]} {
	if {[llength $arguments] == 1} {
	    set delegate "\[linsert \$args 0 [list $base]\]"
	} else {
	    set delegate "\[linsert \$args 0 [list $base] \$[join [lrange $arguments 0 end-1] " \$"]\]"
	}
    } else {
	set delegate "\[list [list $base] \$[join $arguments " \$"]\]"
    }

    set    body ""
    append body [list $comm] " " "send "
    if {$async} {append body "-async "}
    append body [list $rid] " " $delegate

    uplevel 1 [list ::proc $name $arguments $body]
    return $name
}

# ### ### ### ######### ######### #########
## Ready to go

package provide interp::delegate::proc 0.2

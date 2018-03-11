# interp.tcl
# Some utility commands for creation of delegation methods.
# (Delegation of methods to a remote interpreter via a comm
# handle).
#
# Copyright (c) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: deleg_method.tcl,v 1.2 2006/09/01 19:58:21 andreas_kupries Exp $

package require Tcl 8.3
package require snit

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::interp::delegate {}

# ### ### ### ######### ######### #########
## Public API

snit::macro ::interp::delegate::method {args} {
    # syntax: ?-async? name arguments comm id

    set async 0
    while {[string match -* [set opt [lindex $args 0]]]} {
	switch -exact -- $opt {
	    -async {set async 1 ; set args [lrange $args 1 end]}
	    default {
		return -code error "unknown option \"$opt\", expected -async"
	    }
	}
    }
    if {[llength $args] != 4} {
	return -code error "wrong # args"
    }
    foreach {name arguments comm rid} $args break

    if {![llength $arguments]} {
	set delegate "[list $name]"
    } elseif {[string equal args [lindex $arguments end]]} {
	if {[llength $arguments] == 1} {
	    set delegate "\[linsert \$args 0 [list $name]\]"
	} else {
	    set delegate "\[linsert \$args 0 [list $name] \$[join [lrange $arguments 0 end-1] " \$"]\]"
	}
    } else {
	set delegate "\[list [list $name] \$[join $arguments " \$"]\]"
    }

    set    body ""
    append body [list $comm] " " "send "
    if {$async} {append body "-async "}
    append body [list $rid] " " $delegate

    ::method $name $arguments $body
}

# ### ### ### ######### ######### #########
## Ready to go

package provide interp::delegate::method 0.2

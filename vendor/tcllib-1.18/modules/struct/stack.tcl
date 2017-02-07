# stack.tcl --
#
#	Implementation of a stack data structure for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2008 by Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: stack.tcl,v 1.20 2012/11/21 22:36:18 andreas_kupries Exp $

# @mdgen EXCLUDE: stack_c.tcl

package require Tcl 8.4
namespace eval ::struct::stack {}

# ### ### ### ######### ######### #########
## Management of stack implementations.

# ::struct::stack::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation
#	was successfully loaded; and False otherwise.

proc ::struct::stack::LoadAccelerator {key} {
    variable accel
    set r 0
    switch -exact -- $key {
	critcl {
	    # Critcl implementation of stack requires Tcl 8.4.
	    if {![package vsatisfies [package provide Tcl] 8.4]} {return 0}
	    if {[catch {package require tcllibc}]} {return 0}
	    set r [llength [info commands ::struct::stack_critcl]]
	}
	tcl {
	    variable selfdir
	    if {
		[package vsatisfies [package provide Tcl] 8.5] &&
		![catch {package require TclOO 0.6.1-} mx]
	    } {
		source [file join $selfdir stack_oo.tcl]
	    } else {
		source [file join $selfdir stack_tcl.tcl]
	    }
	    set r 1
	}
        default {
            return -code error "invalid accelerator/impl. package $key:\
                must be one of [join [KnownImplementations] {, }]"
        }
    }
    set accel($key) $r
    return $r
}

# ::struct::stack::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::struct::stack::SwitchTo {key} {
    variable accel
    variable loaded

    if {[string equal $key $loaded]} {
	# No change, nothing to do.
	return
    } elseif {![string equal $key ""]} {
	# Validate the target implementation of the switch.

	if {![info exists accel($key)]} {
	    return -code error "Unable to activate unknown implementation \"$key\""
	} elseif {![info exists accel($key)] || !$accel($key)} {
	    return -code error "Unable to activate missing implementation \"$key\""
	}
    }

    # Deactivate the previous implementation, if there was any.

    if {![string equal $loaded ""]} {
	rename ::struct::stack ::struct::stack_$loaded
    }

    # Activate the new implementation, if there is any.

    if {![string equal $key ""]} {
	rename ::struct::stack_$key ::struct::stack
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    return
}

# ::struct::stack::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::struct::stack::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::struct::stack::KnownImplementations --
#
#	Determines which implementations are known
#	as possible implementations.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys. In the order
#	of preference, most prefered first.

proc ::struct::stack::KnownImplementations {} {
    return {critcl tcl}
}

proc ::struct::stack::Names {} {
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# ### ### ### ######### ######### #########
## Initialization: Data structures.

namespace eval ::struct::stack {
    variable  selfdir [file dirname [info script]]
    variable  accel
    array set accel   {tcl 0 critcl 0}
    variable  loaded  {}
}

# ### ### ### ######### ######### #########
## Initialization: Choose an implementation,
## most prefered first. Loads only one of the
## possible implementations. And activates it.

namespace eval ::struct::stack {
    variable e
    foreach e [KnownImplementations] {
	if {[LoadAccelerator $e]} {
	    SwitchTo $e
	    break
	}
    }
    unset e
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Export the constructor command.
    namespace export stack
}

package provide struct::stack 1.5.3

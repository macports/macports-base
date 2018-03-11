# -*- tcl -*-
#
# Copyright (c) 2009-2015 by Andreas Kupries <andreas_kupries@users.sourceforge.net>

# # ## ### ##### ######## ############# #####################
## Package description

## Implementation of the PackRat Machine (PARAM), a virtual machine on
## top of which parsers for Parsing Expression Grammars (PEGs) can be
## realized. This implementation is tied to Tcl for control flow. We
## (will) have alternate implementations written in TclOO, and critcl,
## all exporting the same API.
#
## RD stands for Recursive Descent.

## This package has a pure Tcl implementation, and a C implementation,
## choosing the latter over the former, if possible.

# @mdgen EXCLUDE: pt_rdengine_c.tcl

package require Tcl 8.5

namespace eval ::pt::rde {}

# # ## ### ##### ######## ############# #####################
## Support narrative tracing.

package require debug
debug level  pt/rdengine
debug prefix pt/rdengine {}

# # ## ### ##### ######## ############# #####################
## Management of RDengine implementations.

# ::pt::rde::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation
#	was successfully loaded; and False otherwise.

proc ::pt::rde::LoadAccelerator {key} {
    debug.pt/rdengine {[info level 0]}
    variable accel
    set r 0
    switch -exact -- $key {
	critcl {
	    if {![package vsatisfies [package provide Tcl] 8.5]} {return 0}
	    if {[catch {package require tcllibc}]} {return 0}
	    set r [llength [info commands ::pt::rde_critcl]]
	}
	tcl {
	    variable selfdir
	    source [file join $selfdir pt_rdengine_tcl.tcl]
	    set r 1
	}
        default {
            return -code error "invalid accelerator/impl. package $key:\
                must be one of [join [KnownImplementations] {, }]"
        }
    }
    set accel($key) $r
    debug.pt/rdengine {[info level 0] ==> ($r)}
    return $r
}

# ::pt::rde::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::pt::rde::SwitchTo {key} {
    debug.pt/rdengine {[info level 0]}
    variable accel
    variable loaded

    if {$key eq $loaded} {
	# No change, nothing to do.
	debug.pt/rdengine {[info level 0] == $loaded /no change}
	return
    } elseif {$key ne {}} {
	# Validate the target implementation of the switch.
	debug.pt/rdengine {[info level 0] validate}

	if {![info exists accel($key)]} {
	    return -code error "Unable to activate unknown implementation \"$key\""
	} elseif {![info exists accel($key)] || !$accel($key)} {
	    return -code error "Unable to activate missing implementation \"$key\""
	}
    }

    # Deactivate the previous implementation, if there was any.

    if {$loaded ne {}} {
	debug.pt/rdengine {[info level 0] disable $loaded}
	rename ::pt::rde ::pt::rde_$loaded
    }

    # Activate the new implementation, if there is any.

    if {$key ne {}} {
	debug.pt/rdengine {[info level 0] enable $key}
	rename ::pt::rde_$key ::pt::rde
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    debug.pt/rdengine {[info level 0] /done}
    return
}

# ::pt::rde::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::pt::rde::Implementations {} {
    debug.pt/rdengine {[info level 0]}
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    debug.pt/rdengine {[info level 0] ==> ($res)}
    return $res
}

# ::pt::rde::KnownImplementations --
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

proc ::pt::rde::KnownImplementations {} {
    debug.pt/rdengine {[info level 0]}
    return {critcl tcl}
}

proc ::pt::rde::Names {} {
    debug.pt/rdengine {[info level 0]}
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# # ## ### ##### ######## ############# #####################
## Initialization: Data structures.

namespace eval ::pt::rde {
    variable  selfdir [file dirname [info script]]
    variable  accel
    array set accel   {tcl 0 critcl 0}
    variable  loaded  {}
}

# # ## ### ##### ######## ############# #####################

## Initialization: Choose an implementation, the most prefered is
## listed first. Loads only one of the possible implementations. And
## activates it.

namespace eval ::pt::rde {
    variable e
    foreach e [KnownImplementations] {
	if {[LoadAccelerator $e]} {
	    SwitchTo $e
	    break
	}
    }
    unset e
}

# # ## ### ##### ######## ############# #####################
## Ready

namespace eval ::pt {
    # Export the constructor command.
    namespace export rde
}

package provide pt::rde 1.1

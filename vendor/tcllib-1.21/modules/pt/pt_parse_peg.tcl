# -*- tcl -*-
#
# Copyright (c) 2009-2014 by Andreas Kupries <andreas_kupries@users.sourceforge.net>

# # ## ### ##### ######## ############# #####################
## Package description

## Implementation of a parser for PE grammars. We have multiple
## implementations in Tcl (Snit-based), and C (Critcl-based). The
## system will try to use the latter where possible.

# @mdgen EXCLUDE: pt_parse_peg_c.tcl

package require Tcl 8.5

namespace eval ::pt::parse::peg {}

# # ## ### ##### ######## ############# #####################
## Management of stack implementations.

# ::pt::parse::peg::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation
#	was successfully loaded; and False otherwise.

proc ::pt::parse::peg::LoadAccelerator {key} {
    variable accel
    set r 0
    switch -exact -- $key {
	critcl {
	    if {![package vsatisfies [package provide Tcl] 8.5]} {return 0}
	    if {[catch {package require tcllibc}]} {return 0}
	    set r [llength [info commands ::pt::parse::peg_critcl]]
	}
	tcl {
	    variable selfdir
	    source [file join $selfdir pt_parse_peg_tcl.tcl]
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

# ::pt::parse::peg::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::pt::parse::peg::SwitchTo {key} {
    variable accel
    variable loaded

    if {$key eq $loaded} {
	# No change, nothing to do.
	return
    } elseif {$key ne {}} {
	# Validate the target implementation of the switch.

	if {![info exists accel($key)]} {
	    return -code error "Unable to activate unknown implementation \"$key\""
	} elseif {![info exists accel($key)] || !$accel($key)} {
	    return -code error "Unable to activate missing implementation \"$key\""
	}
    }

    # Deactivate the previous implementation, if there was any.

    if {$loaded ne {}} {
	rename ::pt::parse::peg ::pt::parse::peg_$loaded
    }

    # Activate the new implementation, if there is any.

    if {$key ne {}} {
	rename ::pt::parse::peg_$key ::pt::parse::peg
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    return
}

# ::pt::parse::peg::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::pt::parse::peg::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::pt::parse::peg::KnownImplementations --
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

proc ::pt::parse::peg::KnownImplementations {} {
    return {critcl tcl}
}

proc ::pt::parse::peg::Names {} {
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# # ## ### ##### ######## ############# #####################
## Initialization: Data structures.

namespace eval ::pt::parse::peg {
    variable  selfdir [file dirname [info script]]
    variable  accel
    array set accel   {tcl 0 critcl 0}
    variable  loaded  {}
}

# # ## ### ##### ######## ############# #####################

## Initialization: Choose an implementation, the most prefered is
## listed first. Loads only one of the possible implementations. And
## activates it.

namespace eval ::pt::parse::peg {
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

package provide pt::parse::peg 1.0.1

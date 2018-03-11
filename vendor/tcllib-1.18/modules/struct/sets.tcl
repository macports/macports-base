#----------------------------------------------------------------------
#
# sets.tcl --
#
#	Definitions for the processing of sets.
#
# Copyright (c) 2004-2008 by Andreas Kupries.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: sets.tcl,v 1.17 2008/03/09 04:24:37 andreas_kupries Exp $
#
#----------------------------------------------------------------------

# @mdgen EXCLUDE: sets_c.tcl

package require Tcl 8.2

namespace eval ::struct::set {}

# ### ### ### ######### ######### #########
## Management of set implementations.

# ::struct::set::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation
#	was successfully loaded; and False otherwise.

proc ::struct::set::LoadAccelerator {key} {
    variable accel
    set r 0
    switch -exact -- $key {
	critcl {
	    # Critcl implementation of set requires Tcl 8.4.
	    if {![package vsatisfies [package provide Tcl] 8.4]} {return 0}
	    if {[catch {package require tcllibc}]} {return 0}
	    set r [llength [info commands ::struct::set_critcl]]
	}
	tcl {
	    variable selfdir
	    source [file join $selfdir sets_tcl.tcl]
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

# ::struct::set::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::struct::set::SwitchTo {key} {
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
	rename ::struct::set ::struct::set_$loaded
    }

    # Activate the new implementation, if there is any.

    if {![string equal $key ""]} {
	rename ::struct::set_$key ::struct::set
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    return
}

proc ::struct::set::Loaded {} {
    variable loaded
    return  $loaded
}

# ::struct::set::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::struct::set::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::struct::set::KnownImplementations --
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

proc ::struct::set::KnownImplementations {} {
    return {critcl tcl}
}

proc ::struct::set::Names {} {
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# ### ### ### ######### ######### #########
## Initialization: Data structures.

namespace eval ::struct::set {
    variable  selfdir [file dirname [info script]]
    variable  accel
    array set accel   {tcl 0 critcl 0}
    variable  loaded  {}
}

# ### ### ### ######### ######### #########
## Initialization: Choose an implementation,
## most prefered first. Loads only one of the
## possible implementations. And activates it.

namespace eval ::struct::set {
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
    namespace export set
}

package provide struct::set 2.2.3

## -*- mode: tcl; fill-column: 90 -*-
# ### ### ### ######### ######### #########
##
## Common information and commands for slippy based maps. I.e. tile size, relationship
## between zoom level and map size, etc.
##
## See
##	http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Pseudo-Code
##
## for the coordinate conversions and other information.

#
# Management code for switching between Tcl and C accelerated implementations.
#
# @mdgen EXCLUDE: map_slippy_c.tcl
#

package require Tcl 8.6 9
namespace eval ::map::slippy {}

# ### ### ### ######### ######### #########
## Management of map::slippy std implementations.

# ::map::slippy::LoadAccelerator --
#
#	Loads a named implementation, if possible.
#
# Arguments:
#	key	Name of the implementation to load.
#
# Results:
#	A boolean flag. True if the implementation was successfully loaded; and False otherwise.

proc ::map::slippy::LoadAccelerator {key} {
    variable accel
    set isok 0
    switch -exact -- $key {
	critcl {
	    # Critcl implementation of map::slippy requires Tcl 8.6.
	    if {![package vsatisfies [package provide Tcl] 8.6 9]} {return 0}
	    if {[catch {
		package require tcllibc
	    }]} {
		return 0
	    }
	    set isok [llength [info commands ::map::slippy::critcl_tiles]]
	}
	tcl {
	    variable selfdir
	    if {[catch {
		source [file join $selfdir map_slippy_tcl.tcl]
	    } msg]} {
		#puts /$msg
		return 0
	    }
	    set isok [llength [info commands ::map::slippy::tcl_tiles]]
	}
        default {
            return -code error "invalid accelerator $key:\
                must be one of [join [KnownImplementations] {, }]"
        }
    }
    set accel($key) $isok
    return $isok
}

# ::map::slippy::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::map::slippy::SwitchTo {key} {
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

    set cmdmap {
	geo::2point			point::2geo
	geo::2point*			point::2geo*
	geo::2point-list		point::2geo-list
	geo::bbox			point::bbox
	geo::bbox-list			point::bbox-list
	geo::box::2point		point::box::2geo
	geo::box::center		point::box::center
	geo::box::corners		point::box::corners
	geo::box::diameter		point::box::diameter
	geo::box::dimensions		point::box::dimensions
	geo::box::fit
	geo::box::inside		point::box::inside
	geo::box::limit
	geo::box::opposites		point::box::opposites
	geo::box::perimeter		point::box::perimeter
	geo::box::valid
	geo::box::valid-list
	geo::center			point::center
	geo::center-list		point::center-list
	geo::diameter			point::diameter
	geo::diameter-list		point::diameter-list
	geo::distance			point::distance
	geo::distance*			point::distance*
	geo::distance-list		point::distance-list
	geo::limit			point::simplify::rdp
	geo::valid
	geo::valid-list
	length				point::simplify::radial
	limit2
	limit3
	limit6
	tile::size
	tile::valid
	tiles
	valid::latitude
	valid::longitude
    }

    # Deactivate the previous implementation, if there was any.

    if {$loaded ne {}} {
	foreach cmd $cmdmap {
	    set origin [string map {:: _ - _ * _args} $cmd]
	    rename ::map::slippy::$cmd ::map::slippy::${loaded}_$origin
	}
    }

    # Activate the new implementation, if there is any.

    if {$key ne {}} {
	foreach cmd $cmdmap {
	    set origin [string map {:: _ - _ * _args} $cmd]
	    rename ::map::slippy::${key}_$origin ::map::slippy::$cmd
	}
    }

    # Remember the active implementation, for deactivation by future switches.

    set loaded $key
    return
}

# ::map::slippy::Implementations --
#
#	Determines which implementations are present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::map::slippy::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::map::slippy::KnownImplementations --
#
#	Determines which implementations are known as possible implementations.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys. In the order of preference, most prefered first.

proc ::map::slippy::KnownImplementations {} {
    return {critcl tcl}
}

proc ::map::slippy::Names {} {
    return {
	critcl {tcllibc based}
	tcl    {pure Tcl}
    }
}

# ### ### ### ######### ######### #########
## Initialization: Data structures.

namespace eval ::map::slippy {
    variable  selfdir [file dirname [info script]]
    variable  loaded  {}

    variable  accel
    array set accel {tcl 0 critcl 0}
}

# ### ### ### ######### ######### #########
## Initialization. Ensemble

namespace eval ::map {
    namespace export slippy
    namespace ensemble create
}
namespace eval ::map::slippy {
    namespace export length geo point tile tiles \
	limit6 limit3 limit2 pretty-distance valid
    namespace ensemble create
}
namespace eval ::map::slippy::valid {
    namespace export latitude longitude
    namespace ensemble create
}
namespace eval ::map::slippy::geo {
    namespace export \
	2point 2point* 2point-list bbox bbox-list \
	box center center-list diameter diameter-list \
	distance distance* distance-list limit \
	valid valid-list
    namespace ensemble create
}
namespace eval ::map::slippy::geo::box {
    namespace export fit 2point corners opposites center dimensions inside \
	diameter perimeter limit valid valid-list
    namespace ensemble create
}
namespace eval ::map::slippy::point {
    namespace export \
	2geo 2geo* 2geo-list bbox bbox-list \
	box center center-list diameter diameter-list \
	distance distance* distance-list simplify
    namespace ensemble create
}
namespace eval ::map::slippy::point::box {
    namespace export 2geo corners opposites center dimensions inside \
	diameter perimeter
    namespace ensemble create
}
namespace eval ::map::slippy::point::simplify {
    namespace export radial rdp
    namespace ensemble create
}
namespace eval ::map::slippy::tile {
    namespace export size valid
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## Unaccelerated commands

proc ::map::slippy::pretty-distance {x} {
    if {$x >= 1000} {
	return "[limit3 [expr {$x/1000.}]] km"
    }
    return "[limit2 $x] m"
}

# ### ### ### ######### ######### #########
## Initialization: Choose an implementation, most prefered first.
## Loads only one of the possible implementations and activates it.

apply {{} {
    foreach e [KnownImplementations] {
	if {[LoadAccelerator $e]} {
	    SwitchTo $e
	    break
	}
    }
} ::map::slippy}

# ### ### ### ######### ######### #########
## Ready

package provide map::slippy 0.10

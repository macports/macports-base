# map.tcl --
# Copyright (c) 2009-2019 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# Object wrapper around array/dict. Useful as key/value store in
# larger systems.
#
# Examples:
# - configuration mgmt in doctools v2 import/export managers
# - pt import/export managers
#
# Each object manages a key/value map.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require snit

# ### ### ### ######### ######### #########
## API

# ATTENTION:
##
# From an API point of view the code below is equivalent to the much
# shorter `snit::type struct::map { ... }`.
#
# Then why the more complex form ?
#
# When snit compiles the class to Tcl code, and later on when methods
# are executed it will happen in the `struct` namespace. The moment
# this package is used together with `struct::set` all unqualified
# `set` statements will go bonkers, eiter in snit, or, here, in method
# `set`, because they get resolved to the `struct::set` dispatcher
# instead of `::set`. Moving the implementation a level deeper makes
# the `struct::map` namespace the context, with no conflict.

# Future / TODO: Convert all the OO stuff here over to TclOO, as much
# as possible (snit configure/cget support is currently still better,
# ditto hierarchical methods).

namespace eval ::struct {}

proc ::struct::map {args} {
    uplevel 1 [linsert $args 0 struct::map::I]
}

snit::type ::struct::map::I {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creating, destruction

    # Default constructor.
    # Default destructor.

    # ### ### ### ######### ######### #########
    ## Public methods. Reading and writing the map.

    method names {} {
	return [array names mymap]
    }

    method get {} {
	return [array get mymap]
    }

    method set {name {value {}}} {
	# 7 instead of 3 in the condition below, because of the 4
	# implicit arguments snit is providing to each method.
	if {[llength [info level 0]] == 7} {
	    ::set mymap($name) $value
	} elseif {![info exists mymap($name)]} {
	    return -code error "can't read \"$name\": no such variable"
	}
	return $mymap($name)
    }

    method unset {args} {
	if {![llength $args]} { lappend args * }
	foreach pattern $args {
	    array unset mymap $pattern
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal methods :: None.

    # ### ### ### ######### ######### #########
    ## State :: Map data, Tcl array

    variable mymap -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide struct::map 1
return

# docidx.tcl --
#
#	Generic configuration management, for use by import and export
#	managers.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: config.tcl,v 1.2 2011/11/17 08:00:45 andreas_kupries Exp $

# Each object manages a set of configuration variables.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::config {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creating, destruction

    # Default constructor.
    # Default destructor.

    # ### ### ### ######### ######### #########
    ## Public methods. Reading and writing the configuration.

    method names {} {
	return [array names myconfiguration]
    }

    method get {} {
	return [array get myconfiguration]
    }

    method set {name {value {}}} {
	# 7 instead of 3 in the condition below, because of the 4
	# implicit arguments snit is providing to each method.
	if {[llength [info level 0]] == 7} {
	    set myconfiguration($name) $value
	} elseif {![info exists myconfiguration($name)]} {
	    return -code error "can't read \"$name\": no such variable"
	}
	return $myconfiguration($name)
    }

    method unset {args} {
	if {![llength $args]} { lappend args * }
	foreach pattern $args {
	    array unset myconfiguration $pattern
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal methods :: None.

    # ### ### ### ######### ######### #########
    ## State :: Configuration data, Tcl array

    variable myconfiguration -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::config 0.1
return

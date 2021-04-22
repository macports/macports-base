# math.tcl --
#
#	Main 'package provide' script for the package 'math'.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2002 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.2		;# uses [lindex $l end-$integer]

# @mdgen OWNER: tclIndex
# @mdgen OWNER: misc.tcl
# @mdgen OWNER: combinatorics.tcl

namespace eval ::math {
    # misc.tcl

    namespace export	cov		fibonacci	integrate
    namespace export	max		mean		min
    namespace export	product		random		sigma
    namespace export	stats		sum
    namespace export	expectDouble    expectInteger

    # combinatorics.tcl

    namespace export	ln_Gamma	factorial	choose
    namespace export	Beta

    # Set up for auto-loading

    if { ![interp issafe {}]} {
	variable home [file join [pwd] [file dirname [info script]]]
	if {[lsearch -exact $::auto_path $home] == -1} {
	    lappend ::auto_path $home
	}
    } else {
	source [file join [file dirname [info script]] misc.tcl]
	source [file join [file dirname [info script]] combinatorics.tcl]
    }

    package provide [namespace tail [namespace current]] 1.2.5
}

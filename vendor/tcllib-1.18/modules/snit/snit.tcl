#-----------------------------------------------------------------------
# TITLE:
#	snit.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Snit's Not Incr Tcl, a simple object system in Pure Tcl.
#
#       Snit 1.x Loader 
#
#       Copyright (C) 2003-2006 by William H. Duquette
#       This code is licensed as described in license.txt.
#
#-----------------------------------------------------------------------

package require Tcl 8.3

# Define the snit namespace and save the library directory

namespace eval ::snit:: {
    set library [file dirname [info script]]
}

# Select the implementation based on the version of the Tcl core
# executing this code. For 8.3 we use a backport emulating various
# 8.4 features

if {[package vsatisfies [package provide Tcl] 8.4]} {
    source [file join $::snit::library main1.tcl]
} else {
    source [file join $::snit::library main1_83.tcl]
    source [file join $::snit::library snit_tcl83_utils.tcl]
}

# Load the library of Snit validation types.

source [file join $::snit::library validate.tcl]

package provide snit 1.4.2

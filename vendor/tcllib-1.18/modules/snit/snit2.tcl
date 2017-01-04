#-----------------------------------------------------------------------
# TITLE:
#	snit2.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Snit's Not Incr Tcl, a simple object system in Pure Tcl.
#
#       Snit 2.x Loader
#
#       Copyright (C) 2003-2006 by William H. Duquette
#       This code is licensed as described in license.txt.
#
#-----------------------------------------------------------------------

package require Tcl 8.5

# Define the snit namespace and save the library directory

namespace eval ::snit:: {
    set library [file dirname [info script]]
}

# Load the kernel.
source [file join $::snit::library main2.tcl]

# Load the library of Snit validation types.
source [file join $::snit::library validate.tcl]

package provide snit 2.3.2

# -*- tcl -*-
# Implementation of 'localdoc'.

# Available variables
# * argv  - Cmdline arguments
# * base  - Location of sak.tcl = Top directory of Tcllib distribution
# * cbase - Location of all files relevant to this command.
# * sbase - Location of all files supporting the SAK.

# ###

package require sak::localdoc

if {[llength $argv]} {
    sak::localdoc::usage
}

sak::localdoc::run

##
# ###

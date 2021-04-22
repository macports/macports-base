#----------------------------------------------------------------------
#
# calendar.tcl --
#
#	This file is the main 'package provide' script for the
#   	'calendar' package.  The package provides various commands for
#	manipulating dates and times.

package require Tcl 8.2

namespace eval ::calendar {
    variable home [file join [pwd] [file dirname [info script]]]
    if { [lsearch -exact $::auto_path $home] == -1 } {
	lappend ::auto_path $home
    }

    package provide [namespace tail [namespace current]] 0.2
}

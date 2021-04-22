# -*- tcl -*-
# Implementation of 'readme'.

# Available variables
# * argv  - Cmdline arguments
# * base  - Location of sak.tcl = Top directory of Tcllib distribution
# * cbase - Location of all files relevant to this command.
# * sbase - Location of all files supporting the SAK.

package require sak::util
package require sak::readme

set raw  0
set log  0
set stem {}
set tclv {}
set format txt

while {[llength $argv]} {
    switch -exact -- [set o [lindex $argv 0]] {
	-md {
	    set argv [lrange $argv 1 end]
	    set format md
	}
	default {
	    sak::readme::usage
	}
    }
}

if {[llength $argv]} {
    sak::readme::usage
}

sak::readme::run $format

##
# ###

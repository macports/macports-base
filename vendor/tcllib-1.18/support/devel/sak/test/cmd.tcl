# -*- tcl -*-
# Implementation of 'doc'.

# Available variables
# * argv  - Cmdline arguments
# * base  - Location of sak.tcl = Top directory of Tcllib distribution
# * cbase - Location of all files relevant to this command.
# * sbase - Location of all files supporting the SAK.

package require sak::util
package require sak::test

if {![llength $argv]} {
    sak::test::usage Command missing
}

set cmd  [lindex $argv 0]
set argv [lrange $argv 1 end]

if {[catch {package require sak::test::$cmd} msg]} {
    sak::test::usage Unknown command \"$cmd\" : \
	    \n $::errorInfo
}

sak::test::$cmd $argv

##
# ###

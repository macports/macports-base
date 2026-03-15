# -*- tcl -*-
# Implementation of 'validate'.

# Available variables
# * argv  - Cmdline arguments
# * base  - Location of sak.tcl = Top directory of Tcllib distribution
# * cbase - Location of all files relevant to this command.
# * sbase - Location of all files supporting the SAK.

package require sak::util
package require sak::validate

set raw  0
set log  0
set stem {}
set tclv {}

if {[llength $argv]} {
    # First argument may be a command.
    set cmd [lindex $argv 0]
    if {![catch {
	package require sak::validate::$cmd
    } msg]} {
	set argv [lrange $argv 1 end]
    } else {
	set cmd all
    }

    # Now process any possible options (-v, -l, --log).

    while {[string match -* [set opt [lindex $argv 0]]]} {
	switch -exact -- $opt {
	    -v {
		set raw 1
		set argv [lrange $argv 1 end]
	    }
	    -l - --log {
		set log 1
		set stem [lindex $argv 1]
		set argv [lrange $argv 2 end]
	    }
	    -t - --tcl {
		set tclv [lindex $argv 1]
		set argv [lrange $argv 2 end]
	    }
	    default {
		sak::validate::usage Unknown option "\"$opt\""
	    }
	}
    }
} else {
    set cmd all
}

# At last now handle all remaining arguments as module specifications.
if {![sak::util::checkModules argv]} return

if {$log} { set raw 0 }

array set mode {
    00 short
    01 log
    10 verbose
    11 _impossible_
}

sak::validate::$cmd $argv $mode($raw$log) $stem $tclv

##
# ###

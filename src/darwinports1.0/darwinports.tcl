#!/usr/bin/tclsh
# /etc/ports.conf options
package provide darwinports 1.0

global ports_opts
global bootstrap_options
set bootstrap_options "sysportpath libpath auto_path"
set portinterp_options "sysportpath portpath auto_path portconf"
set uniqid 0

proc init {args} {
    global auto_path env bootstrap_options sysportpath portconf

    if [file isfile /etc/ports.conf] {
	set portconf /etc/ports.conf
	set fd [open /etc/ports.conf r]
	while {[gets $fd line] >= 0} {
	    foreach option $bootstrap_options {
		if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9/\]+$)" $line match val] == 1} {
		    set $option $val
		}
	    }
	}
    }

    # Prefer the PORTPATH environment variable
    if {[llength [array names env PORTPATH]] > 0} {
	set sysportpath [lindex [array get env PORTPATH] 1]
    }

    if ![info exists sysportpath] {
	return -code error "sysportpath must be set in /etc/ports.conf or in the PORTPATH env variable"
    }
	
    if ![info exists libpath] {
	set libpath /usr/local/share/darwinports/Tcl
    }

    if [file isdirectory $libpath] {
	lappend auto_path $libpath
    } else {
	return -code error "Library directory '$libpath' must exist"
    }
}

proc build {portdir chain target {options ""}} {
    global targets portpath portinterp_options uniqid

    if [file isdirectory $portdir] {
	cd $portdir
	set portpath [pwd]
	set workername workername[incr uniqid]
	interp create $workername
	$workername alias build build

	foreach opt $portinterp_options {
		upvar #0 $opt upopt
		if [info exists upopt] {
			$workername eval set system_options($opt) \"$upopt\"
			$workername eval set $opt \"$upopt\"
		}
	}

	foreach opt $options {
		if {[regexp {([A-Za-z0-9_\.]+)=(.+)} $opt match key val] == 1} {
			$workername eval set user_options($key) \"$val\"
			$workername eval set $key \"$val\"
		}
	}
	$workername eval source Portfile
	$workername eval {flock [open Portfile r] -exclusive}
	$workername eval eval_targets targets $chain $target
    } else {
	return -code error "Portdir $portpath does not exist"
    }
}

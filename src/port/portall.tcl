#!/bin/sh
#\
exec @TCLSH@ "$0" "$@"

# $Id: portall.tcl,v 1.28 2005/08/27 00:07:30 pguyot Exp $
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

catch {source \
	[file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports
dportinit
package require Pextlib

global target

# UI Instantiations
# ui_options(ports_debug) - If set, output debugging messages.
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"

# ui_options accessor
proc ui_isset {val} {
    global ui_options
    if {[info exists ui_options($val)]} {
	if {$ui_options($val) == "yes"} {
	    return 1
	}
    }
    return 0
}

# UI Callback

proc ui_prefix {priority} {
    switch $priority {
        debug {
        	return "DEBUG: "
        }
        error {
        	return "Error: "
        }
        warn {
        	return "Warning: "
        }
        default {
        	return ""
        }
    }
}

proc ui_channels {priority} {
    switch $priority {
        debug {
            if {[ui_isset ports_debug]} {
            	return {stderr}
            } else {
            	return {}
            }
        }
        info {
            if {[ui_isset ports_verbose]} {
                return {stdout}
            } else {
                return {}
			}
		}
        msg {
            if {[ui_isset ports_quiet]} {
                return {}
			} else {
				return {stdout}
			}
		}
        error {
        	return {stderr}
        }
        default {
        	return {stdout}
        }
    }
}

proc pindex {portdir} {
    global target options variations

    if {[catch {set interp [dportopen file://$portdir [array get options] [array get variations]]} err]} {
	puts "Error: Couldn't create interpreter for $portdir: $err"
	return -1
    }
    array set portinfo [dportinfo $interp]
    dportexec $interp $target
    dportclose $interp
}

# Main

# zero-out the options array
array set options [list]
array set variations [list]

if { $argc < 1 } {
    set target build
} else {
    for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]

	if {[regexp {([A-Za-z0-9_\.]+)=(.*)} $arg match key val] == 1} {
	    # option=value
	    set options($key) \"$val\"
	} elseif {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
	    # if +xyz -xyz or after the separator
	    set variations($opt) $sign
	} else {
	    set target $arg
	}
    }
}

if {[file isdirectory dports]} {
    dporttraverse pindex dports
} elseif {[file isdirectory ../dports]} {
    dporttraverse pindex .
} else {
    puts "Please run me from the darwinports directory (dports/..)"
    return 1
}

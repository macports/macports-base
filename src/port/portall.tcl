#!/usr/bin/env tclsh
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

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

proc ui_puts {messagelist} {
    set channel stdout
    array set message $messagelist
    switch $message(priority) {
        debug {
            if [ui_isset ports_debug] {
                set channel stderr
                set str "DEBUG: $message(data)"
            } else {
                return
            }
        }
        info {
            if ![ui_isset ports_verbose] {
                return
            }
	    set str $message(data)
        }
        msg {
            if [ui_isset ports_quiet] {
                return
            }
	    set str $message(data)
        }
        error {
            set str "Error: $message(data)"
            set channel stderr
        }
        warn {
            set str "Warning: $message(data)"
        }
    }
    puts $channel $str
}

proc port_traverse {func {dir .}} {
    set pwd [pwd]
    if [catch {cd $dir} err] {
	ui_error $err
	return
    }
    foreach name [readdir .] {
	if {[string match $name .] || [string match $name ..]} {
	    continue
	}
	if [file isdirectory $name] {
	    port_traverse $func $name
	} else {
	    if [string match $name Portfile] {
		catch {eval $func {[file join $pwd $dir]}}
	    }
	}
    }
    cd $pwd
}

proc pindex {portdir} {
    global target options variations

    if [catch {set interp [dportopen file://$portdir [array get options] [array get variations]]} err] {
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

if [file isdirectory dports] {
    port_traverse pindex dports
} elseif [file isdirectory ../dports] {
    port_traverse pindex .
} else {
    puts "Please run me from the darwinports directory (dports/..)"
    return 1
}

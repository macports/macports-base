#!@TCLSH@
# Traverse through all ports and try to build/install each one.
# should be run in a chroot tree unless you don't mind permuting the host
# system.

package require darwinports
dportinit
package require Pextlib

global target uniquestr

# UI Instantiations - These custom versions go to a debugging log.
#
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
    global uniquestr

    set channel [open "/tmp/portbuild.out" a+ 0644]
    array set message $messagelist
    switch $message(priority) {
        debug {
            if {[ui_isset ports_debug]} {
		close $channel
                set channel [open "/tmp/portdebug.out" a+ 0664]
                set str "${uniquestr}DEBUG: $message(data)"
            } else {
		close $channel
                return
            }
        }
        info {
	    set str "${uniquestr}OUT: $message(data)"
        }
        msg {
	    set str "${uniquestr}OUT: $message(data)"
        }
        error {
            set str "${uniquestr}ERR: $message(data)"
        }
        warn {
            set str "${uniquestr}WARN: $message(data)"
        }
    }
    puts $channel $str
    close $channel
}

proc port_traverse {func {dir .}} {
    set pwd [pwd]
    if {[catch {cd $dir} err]} {
	ui_error $err
	return
    }
    foreach name [readdir .] {
	if {[string match $name .] || [string match $name ..]} {
	    continue
	}
	if {[file isdirectory $name]} {
	    port_traverse $func $name
	} else {
	    if {[string match $name Portfile]} {
		catch {eval $func {[file join $pwd $dir]}}
	    }
	}
    }
    cd $pwd
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

set target install
# Set to something unique that can be grepped out of the output easily
set uniquestr "_BLDA_"
set env(UI_PREFIX) "${uniquestr}PHASE: "

if { $argc >= 1 } {
    for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]

	if {[regexp {([A-Za-z0-9_\.]+)=(.*)} $arg match key val] == 1} {
	    # option=value
	    set options($key) \"$val\"
	} elseif {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
	    # if +xyz -xyz or after the separator
	    set variations($opt) $sign
	} else {
	    puts "Invalid argument: $arg"
	    return 1
	}
    }
}

if {[file isdirectory dports]} {
    port_traverse pindex dports
} elseif {[file isdirectory ../dports]} {
    port_traverse pindex .
} else {
    puts "Please run me from the darwinports directory (dports/..)"
    return 1
}

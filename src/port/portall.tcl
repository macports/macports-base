#!/usr/bin/env tclsh8.3
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

package require darwinports
dportinit
package require Pextlib

global target

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

    if [catch {set interp [dportopen file://$portdir options variations]} err] {
	puts "Error: Couldn't create interpreter for $portdir: $err"
	return -1
    }
    array set portinfo [dportinfo $interp]
    puts "Doing $target for port: $portinfo(portname)"
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

if ![file isdirectory dports] {
    puts "Please run me from the darwinports directory (dports/..)"
    return 1
}

port_traverse pindex dports

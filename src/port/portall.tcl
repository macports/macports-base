#!/usr/bin/tclsh
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
    global target
    set interp [dportopen file://$portdir]
    array set portinfo [dportinfo $interp]
    puts "Doing $target for port: $portinfo(portname)"
    dportexec $interp $target
    dportclose $interp
}

if { $argc < 1 } {
    set target build
} else {
    set target [lindex $argv 0]
}

port_traverse pindex dports

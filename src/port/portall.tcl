#!/usr/bin/tclsh
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

package require darwinports
dportinit
package require port

global target

proc pindex {portdir} {
    global target

    set interp [dportopen $portdir]
    if {$target == "index"} {
	ui_puts [$interp eval {format "%-10s\t%-10s\t%s" $portname $portversion $description}]
    } else {
	dportbuild $interp $target
    }
    dportclose $interp
}

if { $argc < 1 } {
    set target build
} else {
    set target [lindex $argv 0]
}

if {[llength [array names env PORTPATH]] > 0} {
    cd [lindex [array get env PORTPATH] 1]
}

port_traverse pindex software


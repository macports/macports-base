#!/usr/bin/tclsh
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

package require darwinports
dportinit
package require Pextlib

proc port_traverse {func {dir .} {cwd ""}} {
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
	    port_traverse $func $name [file join $cwd $name]
	} else {
	    if [string match $name Portfile] {
		$func $cwd 
	    }
	}
    }
    cd $pwd
}

proc pindex {portdir} {
    global target fd directory
    set interp [dportopen [file join $directory $portdir]]
    array set portinfo [dportinfo $interp]
    dportclose $interp
    set portinfo(portdir) $portdir
    puts "Adding port $portinfo(portname)"
    set output [array get portinfo]
    set len [expr [string length $output] + 1]
    puts $fd "$portinfo(portname) $len"
    puts $fd $output
}

if { $argc < 1 } {
    set directory [pwd]
} else {
    set directory [lindex $argv 0]
}

cd $directory
set directory [pwd]
set fd [open PortIndex w]
port_traverse pindex $directory
close $fd

#!/usr/bin/tclsh
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

package require darwinports
dportinit
package require Pextlib

set archive 0

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-a\] \[directory\]"
    puts "-a:\tArchive port directories (for remote sites)"
}

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
    global target fd directory archive
    set interp [dportopen file://[file join $directory $portdir]]
    array set portinfo [dportinfo $interp]
    dportclose $interp
    set portinfo(portdir) $portdir
    puts "Adding port $portinfo(portname)"
    set output [array get portinfo]
    set len [expr [string length $output] + 1]
    puts $fd "$portinfo(portname) $len"
    puts $fd $output
    if {$archive == "1"} {
        set portinfo(portarchive) [file join [file dirname $portdir] [file tail $portdir]].tgz
        cd $directory
        puts "Archiving port $portinfo(portname) to $portinfo(portarchive)"
        if {[catch {exec tar -cf - [file join $portdir] | gzip -c >[file join $directory $portinfo(portarchive)]} result]} {
            puts "Failed to create port archive $portinfo(portarchive): $result"
        }
    }
}

set fd [open PortIndex w]
if {[expr $argc > 2]} {
    print_usage
    exit 1
}

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -regex -- $arg {
        {^-.+} {
            if {$arg == "-a"} {
                set archive 1
	    } else {
		puts "Unknown option: $arg"
		print_usage
		exit 1
	    }
	}
	default { set directory $arg }
    }
}
if {![info exists directory]} {
    set directory .
}

if {[catch {cd $directory} result]} {
   puts "$result"
   exit 1
}

set directory [pwd]
port_traverse pindex $directory
close $fd

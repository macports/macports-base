#!/usr/bin/tclsh
# portbuild
package require darwinports

# globals
set portdir .

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[target\] \[-d portdir\] \[options\]"
}

proc fatal args {
    global argv0
    puts stderr "$argv0: $args"
    exit
}

# Main
set target "build"
for {set i 0} {$i < $argc} {incr i} {
	switch -regexp -- [lindex $argv $i] {
		{^-d$} {
			incr i
			set portdir [lindex $argv $i]
		}
		{^[A-Za-z0-9_\.]+=.+$} {
			if {[regexp {([A-Za-z0-9_\.]+)=(.+)} [lindex $argv $i] match key val] == 1} {
				lappend options [lindex $argv $i]
			}
		}
		{^[A-Za-z0-9]+$} {
			set target [lindex $argv $i]
		}
		default { print_usage; exit }
	}
}
dportinit
if [info exists options] {
    set workername [dportopen $portdir $options]
} else {
    set workername [dportopen $portdir]
}
set result [dportbuild $workername $target]
dportclose $workername
return $result

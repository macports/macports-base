#!/bin/sh
#\
exec @TCLSH@ "$0" "$@"

# Traverse through all ports, creating an index and archiving port directories
# if requested
# $Id$

catch {source \
	[file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports
package require Pextlib

# Globals
set archive 0
set stats(total) 0
set stats(failed) 0
array set ui_options		[list]
array set global_options 	[list]
array set global_variations [list]

# Pass global options into dportinit
dportinit ui_options global_options global_variations



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

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-ad\] \[-o output directory\] \[directory\]"
    puts "-a:\tArchive port directories (for remote sites). Requires -o option"
    puts "-o:\tOutput all files to specified directory"
    puts "-d:\tOutput debugging information"
}

proc pindex {portdir} {	
    global target fd directory archive outdir stats 
    incr stats(total)
	global darwinports::prefix
	set save_prefix $prefix
	set prefix {\${prefix}}
    if {[catch {set interp [dportopen file://[file join $directory $portdir]]} result]} {
		puts "Failed to parse file $portdir/Portfile: $result"
		# revert the prefix.
		set prefix $save_prefix
		incr stats(failed)
    } else {
		# revert the prefix.
        set prefix $save_prefix
        array set portinfo [dportinfo $interp]
        dportclose $interp
        set portinfo(portdir) $portdir
        puts "Adding port $portdir"
        if {$archive == "1"} {
            if {![file isdirectory [file join $outdir [file dirname $portdir]]]} {
                if {[catch {file mkdir [file join $outdir [file dirname $portdir]]} result]} {
                    puts "$result"
                    exit 1
                }
            }
            set portinfo(portarchive) [file join [file dirname $portdir] [file tail $portdir]].tgz
            cd [file join $directory [file dirname $portinfo(portdir)]]
            puts "Archiving port $portinfo(name) to [file join $outdir $portinfo(portarchive)]"
            if {[catch {exec tar -cf - [file tail $portdir] | gzip -c >[file join $outdir $portinfo(portarchive)]} result]} {
                puts "Failed to create port archive $portinfo(portarchive): $result"
                exit 1
            }
        }
        
        set output [array get portinfo]
        set len [expr [string length $output] + 1]
        puts $fd [list $portinfo(name) $len]
        puts $fd $output
    }
}

if {[expr $argc > 4]} {
    print_usage
    exit 1
}

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -regex -- $arg {
        {^-.+} {
            if {$arg == "-a"} { # Turn on archiving
                set archive 1
	    } elseif {$arg == "-d"} { # Turn on debug output
		set ui_options(ports_debug) yes
	    } elseif {$arg == "-o"} { # Set output directory
		incr i
		set outdir [lindex $argv $i]
	    } else {
		puts "Unknown option: $arg"
		print_usage
		exit 1
	    }
	}
	default { set directory $arg }
    }
}

if {$archive == 1 && ![info exists outdir]} {
   puts "You must specify an output directory with -o when using the -a option"
   print_usage
   exit 1
}

if {![info exists directory]} {
    set directory .
}

# cd to input directory 
if {[catch {cd $directory} result]} {
    puts "$result"
    exit 1
} else {
    set directory [pwd]
}

# Set output directory to full path
if {[info exists outdir]} {
    if {[catch {file mkdir $outdir} result]} {
        puts "$result"
        exit 1
    }
    if {[catch {cd $outdir} result]} {
        puts "$result"
        exit 1
    } else {
        set outdir [pwd]
    }
} else {
    set outdir $directory
}

puts "Creating software index in $outdir"
set fd [open [file join $outdir PortIndex] w]
dporttraverse pindex $directory
close $fd
puts "\nTotal number of ports parsed:\t$stats(total)\
      \nPorts successfully parsed:\t[expr $stats(total) - $stats(failed)]\t\
      \nPorts failed:\t\t\t$stats(failed)\n"

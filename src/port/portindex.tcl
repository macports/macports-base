#!/usr/bin/env tclsh
# Traverse through all ports, creating an index and archiving port directories
# if requested

package require darwinports
dportinit
package require Pextlib

# Globals
set archive 0
set depth 0

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

# Output string "str"
# If you don't want newlines to be output, you must pass "-nonewline"
# as the second argument.

proc ui_puts {priority str nonl} {
    set channel stdout
    switch $priority {
        debug {
            if [ui_isset ports_debug] {
                set channel stderr
                set str "DEBUG: $str"
            } else {
                return
            }
        }
        info {
            if ![ui_isset ports_verbose] {
                return
            }
        }
        msg {
            if [ui_isset ports_quiet] {
                return
            }
        }
        error {
            set str "Error: $str"
            set channel stderr
        }
        warn {
            set str "Warning: $str"
        }
    }
    if {$nonl == "-nonewline"} {
	puts -nonewline $channel "$str"
	flush $channel 
    } else {
	puts "$str"
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

proc port_traverse {func {dir .} {cwd ""}} {
    global depth
    set pwd [pwd]
    if [catch {cd $dir} err] {
	    puts $err
	    return
    }
    foreach name [readdir .] {
        if {[string match $name "."] || [string match $name ".."]} {
            continue
        }
        if {[file isdirectory $name] && $depth != 2} {
            incr depth 1
            port_traverse $func $name [file join $cwd $name]			
            incr depth -1
        } else {
            if [string match $name Portfile] {
                $func $cwd 
            }
        }
    }
    cd $pwd
}

proc pindex {portdir} {
    global target fd directory archive outdir
    if {[catch {set interp [dportopen file://[file join $directory $portdir]]} result]} {
        puts "Failed to parse file $portdir/Portfile: $result"
    } else {        
        array set portinfo [dportinfo $interp]
        dportclose $interp
        set portinfo(portdir) $portdir
        puts "Adding port $portinfo(name)"
        if {$archive == "1"} {
            if ![file isdirectory [file join $outdir [file dirname $portdir]]] {
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
        puts $fd "$portinfo(name) $len"
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
if [info exists outdir] {
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
port_traverse pindex $directory
close $fd

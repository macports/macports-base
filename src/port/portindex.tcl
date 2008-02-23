#!/bin/sh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# Run the Tcl interpreter \
exec @TCLSH@ "$0" "$@"

# Traverse through all ports, creating an index and archiving port directories
# if requested
# $Id$

catch {source \
    [file join "@TCL_PACKAGE_DIR@" macports1.0 macports_fastload.tcl]}
package require macports
package require Pextlib

# Globals
set archive 0
set stats(total) 0
set stats(failed) 0
array set ui_options        [list]
array set global_options    [list]
array set global_variations [list]

# Pass global options into mportinit
mportinit ui_options global_options global_variations



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
    global macports::prefix
    set save_prefix $prefix
    set prefix {\${prefix}}
    if {[catch {set interp [mportopen file://[file join $directory $portdir]]} result]} {
        puts stderr "Failed to parse file $portdir/Portfile: $result"
        # revert the prefix.
        set prefix $save_prefix
        incr stats(failed)
    } else {
        # revert the prefix.
        set prefix $save_prefix
        array set portinfo [mportinfo $interp]
        mportclose $interp
        set portinfo(portdir) $portdir
        puts "Adding port $portdir"
        if {$archive == "1"} {
            if {![file isdirectory [file join $outdir [file dirname $portdir]]]} {
                if {[catch {file mkdir [file join $outdir [file dirname $portdir]]} result]} {
                    puts stderr "$result"
                    exit 1
                }
            }
            set portinfo(portarchive) [file join [file dirname $portdir] [file tail $portdir]].tgz
            cd [file join $directory [file dirname $portinfo(portdir)]]
            puts "Archiving port $portinfo(name) to [file join $outdir $portinfo(portarchive)]"
            if {[catch {exec tar -cf - [file tail $portdir] | gzip -c >[file join $outdir $portinfo(portarchive)]} result]} {
                puts stderr "Failed to create port archive $portinfo(portarchive): $result"
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
            puts stderr "Unknown option: $arg"
            print_usage
            exit 1
        }
    }
    default { set directory $arg }
    }
}

if {$archive == 1 && ![info exists outdir]} {
    puts stderr "You must specify an output directory with -o when using the -a option"
    print_usage
    exit 1
}

if {![info exists directory]} {
    set directory .
}

# cd to input directory 
if {[catch {cd $directory} result]} {
    puts stderr "$result"
    exit 1
} else {
    set directory [pwd]
}

# Set output directory to full path
if {[info exists outdir]} {
    if {[catch {file mkdir $outdir} result]} {
        puts stderr "$result"
        exit 1
    }
    if {[catch {cd $outdir} result]} {
        puts stderr "$result"
        exit 1
    } else {
        set outdir [pwd]
    }
} else {
    set outdir $directory
}

puts "Creating software index in $outdir"
set fd [open [file join $outdir PortIndex] w]
mporttraverse pindex $directory
close $fd
puts "\nTotal number of ports parsed:\t$stats(total)\
      \nPorts successfully parsed:\t[expr $stats(total) - $stats(failed)]\t\
      \nPorts failed:\t\t\t$stats(failed)\n"

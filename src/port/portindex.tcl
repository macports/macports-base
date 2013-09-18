#!/bin/sh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# Run the Tcl interpreter \
exec @TCLSH@ "$0" "$@"

# Traverse through all ports, creating an index and archiving port directories
# if requested
# $Id$

source [file join "@macports_tcl_dir@" macports1.0 macports_fastload.tcl]
package require macports
package require Pextlib

# Globals
set full_reindex 0
set stats(total) 0
set stats(failed) 0
set stats(skipped) 0
array set ui_options        [list]
array set global_options    [list]
array set global_variations [list]
set port_options            [list]

# Pass global options into mportinit
mportinit ui_options global_options global_variations

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-adf\] \[-p plat_ver_arch\] \[-o output directory\] \[directory\]"
    puts "-o:\tOutput all files to specified directory"
    puts "-d:\tOutput debugging information"
    puts "-f:\tDo a full re-index instead of updating"
    puts "-p:\tPretend to be on another platform"
}

proc pindex {portdir} {
    global target oldfd oldmtime newest qindex fd directory outdir stats full_reindex \
           ui_options port_options save_prefix keepkeys

    # try to reuse the existing entry if it's still valid
    if {$full_reindex != "1" && [info exists qindex([string tolower [file tail $portdir]])]} {
        try {
            set mtime [file mtime [file join $directory $portdir Portfile]]
            if {$oldmtime >= $mtime} {
                set offset $qindex([string tolower [file tail $portdir]])
                seek $oldfd $offset
                gets $oldfd line
                set name [lindex $line 0]
                set len [lindex $line 1]
                set line [read $oldfd $len]

                if {[info exists ui_options(ports_debug)]} {
                    puts "Reusing existing entry for $portdir"
                }

                puts $fd [list $name $len]
                puts -nonewline $fd $line

                incr stats(skipped)

                # also reuse the entries for its subports
                array set portinfo $line
                if {![info exists portinfo(subports)]} {
                    return
                }
                foreach sub $portinfo(subports) {
                    set offset $qindex([string tolower $sub])
                    seek $oldfd $offset
                    gets $oldfd line
                    set name [lindex $line 0]
                    set len [lindex $line 1]
                    set line [read $oldfd $len]
    
                    puts $fd [list $name $len]
                    puts -nonewline $fd $line
    
                    incr stats(skipped)
                }

                return
            }
        } catch {*} {
            ui_warn "failed to open old entry for ${portdir}, making a new one"
        }
    }

    incr stats(total)
    set prefix {\${prefix}}
    if {[catch {set interp [mportopen file://[file join $directory $portdir] $port_options]} result]} {
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

        foreach availkey [array names portinfo] {
            # store list of subports for top-level ports only
            if {![info exists keepkeys($availkey)] && $availkey != "subports"} {
                unset portinfo($availkey)
            }
        }
        set output [array get portinfo]
        set len [expr [string length $output] + 1]
        puts $fd [list $portinfo(name) $len]
        puts $fd $output
        set mtime [file mtime [file join $directory $portdir Portfile]]
        if {$mtime > $newest} {
            set newest $mtime
        }
        # now index this portfile's subports (if any)
        if {![info exists portinfo(subports)]} {
            return
        }
        foreach sub $portinfo(subports) {
            incr stats(total)
            set prefix {\${prefix}}
            if {[catch {set interp [mportopen file://[file join $directory $portdir] [concat $port_options subport $sub]]} result]} {
                puts stderr "Failed to parse file $portdir/Portfile with subport '${sub}': $result"
                set prefix $save_prefix
                incr stats(failed)
            } else {
                set prefix $save_prefix
                array unset portinfo
                array set portinfo [mportinfo $interp]
                mportclose $interp
                set portinfo(portdir) $portdir
                puts "Adding subport $sub"
                foreach availkey [array names portinfo] {
                    if {![info exists keepkeys($availkey)]} {
                        unset portinfo($availkey)
                    }
                }
                set output [array get portinfo]
                set len [expr [string length $output] + 1]
                puts $fd [list $portinfo(name) $len]
                puts $fd $output
            }
        }
    }
}

if {[expr $argc > 8]} {
    print_usage
    exit 1
}

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -regex -- $arg {
        {^-.+} {
            if {$arg == "-d"} { # Turn on debug output
                set ui_options(ports_debug) yes
            } elseif {$arg == "-o"} { # Set output directory
                incr i
                set outdir [file join [pwd] [lindex $argv $i]]
            } elseif {$arg == "-p"} { # Set platform
                incr i
                set platlist [split [lindex $argv $i] _]
                set os_platform [lindex $platlist 0]
                set os_major [lindex $platlist 1]
                set os_arch [lindex $platlist 2]
                if {$os_platform == "macosx"} {
                    lappend port_options os.subplatform $os_platform os.universal_supported yes
                    set os_platform darwin
                }
                lappend port_options os.platform $os_platform os.major $os_major os.arch $os_arch
            } elseif {$arg == "-f"} { # Completely rebuild index
                set full_reindex 1
            } else {
                puts stderr "Unknown option: $arg"
                print_usage
                exit 1
            }
        }
        default {
            set directory [file join [pwd] $arg]
        }
    }
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

puts "Creating port index in $outdir"
set outpath [file join $outdir PortIndex]
# open old index for comparison
if {[file isfile $outpath] && [file isfile ${outpath}.quick]} {
    set oldmtime [file mtime $outpath]
    set newest $oldmtime
    if {![catch {set oldfd [open $outpath r]}] && ![catch {set quickfd [open ${outpath}.quick r]}]} {
        if {![catch {set quicklist [read $quickfd]}]} {
            foreach entry [split $quicklist "\n"] {
                set qindex([lindex $entry 0]) [lindex $entry 1]
            }
        }
        close $quickfd
    }
} else {
    set newest 0
}

set tempportindex [mktemp "/tmp/mports.portindex.XXXXXXXX"]
set fd [open $tempportindex w]
set save_prefix ${macports::prefix}
foreach key {categories depends_fetch depends_extract depends_build \
             depends_lib depends_run description epoch homepage \
             long_description maintainers name platforms revision variants \
             version portdir replaced_by license installs_libs} {
    set keepkeys($key) 1
}
mporttraverse pindex $directory
if {[info exists oldfd]} {
    close $oldfd
}
close $fd
file rename -force $tempportindex $outpath
file mtime $outpath $newest
mports_generate_quickindex $outpath
puts "\nTotal number of ports parsed:\t$stats(total)\
      \nPorts successfully parsed:\t[expr $stats(total) - $stats(failed)]\
      \nPorts failed:\t\t\t$stats(failed)\
      \nUp-to-date ports skipped:\t$stats(skipped)\n"

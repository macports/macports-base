#!@TCLSH@
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# Traverse through all ports, creating an index and archiving port directories
# if requested

package require macports
package require Pextlib

# Globals
set full_reindex 0
set permit_error 0
set stats(total) 0
set stats(failed) 0
set stats(skipped) 0
set extended_mode 0
array set ui_options        [list ports_no_old_index_warning 1]
array set global_options    [list]
array set global_variations [list]
set port_options            [list]

# Pass global options into mportinit
mportinit ui_options global_options global_variations

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-dfe\] \[-o output directory\] \[-p plat_ver_\[cxxlib_\]arch\] \[directory\]"
    puts "-d:\tOutput debugging information"
    puts "-f:\tDo a full re-index instead of updating"
    puts "-e:\tExit code indicates if ports failed to parse"
    puts "-o:\tOutput all files to specified directory"
    puts "-p:\tPretend to be on another platform"
    puts "-x:\tInclude extra (optional) information in the PortIndex, like variant description and port notes."
}

proc _read_index {idx} {
    global qindex oldfd

    set offset $qindex($idx)
    seek $oldfd $offset
    gets $oldfd line

    set name [lindex $line 0]
    set len  [lindex $line 1]
    set line [read $oldfd [expr {$len - 1}]]

    return [list $name $len $line]
}

proc _write_index {name len line} {
    global fd

    puts $fd [list $name $len]
    puts $fd $line
}

proc _write_index_from_portinfo {portinfoname {is_subport no}} {
    global keepkeys

    upvar $portinfoname portinfo

    array set keep_portinfo {}
    foreach key [array names keepkeys] {
        # filter keys
        if {![info exists portinfo($key)]} {
            continue
        }

        # copy values we want to keep
        set keep_portinfo($key) $portinfo($key)
    }

    # if this is not a subport, add the "subports" key
    if {!$is_subport && [info exists portinfo(subports)]} {
        set keep_portinfo(subports) $portinfo(subports)
    }

    set output [array get keep_portinfo]
    set len [expr {[string length $output] + 1}]
    _write_index $portinfo(name) $len $output
}

proc _open_port {portinfo_name portdir absportdir port_options_name {subport {}}} {
    global save_prefix
    upvar $portinfo_name portinfo
    upvar $port_options_name port_options

    # Make sure $prefix expands to '${prefix}' so that the PortIndex is
    # portable across prefixes, see https://trac.macports.org/ticket/53169 and
    # https://trac.macports.org/ticket/17182.
    try -pass_signal {
        set macports::prefix {${prefix}}
        if {$subport eq {}} {
            set interp [mportopen file://$absportdir $port_options]
        } else {
            set interp [mportopen file://$absportdir [concat $port_options subport $subport]]
        }
    } finally {
        # Restore prefix to the previous value
        set macports::prefix $save_prefix
    }

    if {[array exists portinfo]} {
        array unset portinfo
    }
    array set portinfo [mportinfo $interp]
    mportclose $interp

    set portinfo(portdir) $portdir
}

proc pindex {portdir} {
    global oldmtime newest qindex directory stats full_reindex \
           ui_options port_options

    set qname [string tolower [file tail $portdir]]
    set absportdir [file join $directory $portdir]
    set portfile [file join $absportdir Portfile]
    # try to reuse the existing entry if it's still valid
    if {$full_reindex != 1 && [info exists qindex($qname)]} {
        try -pass_signal {
            set mtime [file mtime $portfile]
            if {$oldmtime >= $mtime} {
                lassign [_read_index $qname] name len line
                array set portinfo $line

                # reuse entry if it was made from the same portdir
                if {[info exists portinfo(portdir)] && $portinfo(portdir) eq $portdir} {
                    _write_index $name $len $line
                    incr stats(skipped)

                    if {[info exists ui_options(ports_debug)]} {
                        puts "Reusing existing entry for $portdir"
                    }

                    # also reuse the entries for its subports
                    if {![info exists portinfo(subports)]} {
                        return
                    }
                    foreach sub $portinfo(subports) {
                        _write_index {*}[_read_index [string tolower $sub]]
                        incr stats(skipped)
                    }

                    return
                }
            }
        } catch {{*} eCode eMessage} {
            ui_warn "Failed to open old entry for ${portdir}, making a new one"
            if {[info exists ui_options(ports_debug)]} {
                puts "$::errorInfo"
            }
        }
    }

    incr stats(total)
    try -pass_signal {
        _open_port portinfo $portdir $absportdir port_options
        puts "Adding port $portdir"

        _write_index_from_portinfo portinfo
        set mtime [file mtime $portfile]
        if {$mtime > $newest} {
            set newest $mtime
        }

        # now index this portfile's subports (if any)
        if {![info exists portinfo(subports)]} {
            return
        }
        foreach sub $portinfo(subports) {
            incr stats(total)
            try -pass_signal {
                _open_port portinfo $portdir $absportdir port_options $sub
                puts "Adding subport $sub"

                _write_index_from_portinfo portinfo yes
            } catch {{*} eCode eMessage} {
                puts stderr "Failed to parse file $portdir/Portfile with subport '${sub}': $eMessage"
                incr stats(failed)
            }
        }
    } catch {{*} eCode eMessage} {
        puts stderr "Failed to parse file $portdir/Portfile: $eMessage"
        incr stats(failed)
    }
}

if {$argc > 8} {
    print_usage
    exit 1
}

for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
    switch -regex -- $arg {
        {^-.+} {
            if {$arg eq "-d"} { # Turn on debug output
                set ui_options(ports_debug) yes
            } elseif {$arg eq "-o"} { # Set output directory
                incr i
                set outdir [file join [pwd] [lindex $argv $i]]
            } elseif {$arg eq "-p"} { # Set platform
                incr i
                set platlist [split [lindex $argv $i] _]
                set os_platform [lindex $platlist 0]
                set os_major [lindex $platlist 1]
                if {[llength $platlist] > 3} {
                    set cxx_stdlib [lindex $platlist 2]
                    switch -- $cxx_stdlib {
                        libcxx {
                            set cxx_stdlib libc++
                        }
                        libstdcxx {
                            set cxx_stdlib libstdc++
                        }
                        default {
                            puts stderr "Unknown C++ standard library: $cxx_stdlib (use libcxx or libstdcxx)"
                            print_usage
                            exit 1
                        }
                    }
                    set os_arch [lindex $platlist 3]
                } else {
                    if {$os_platform eq "macosx"} {
                        if {$os_major < 10} {
                            set cxx_stdlib libstdc++
                        } else {
                            set cxx_stdlib libc++
                        }
                    }
                    set os_arch [lindex $platlist 2]
                }
                if {$os_platform eq "macosx"} {
                    lappend port_options os.subplatform $os_platform os.universal_supported yes cxx_stdlib $cxx_stdlib
                    set os_platform darwin
                }
                lappend port_options os.platform $os_platform os.major $os_major os.arch $os_arch
            } elseif {$arg eq "-f"} { # Completely rebuild index
                set full_reindex 1
            } elseif {$arg eq "-x"} { # Build extended portindex (include extra information , eg.: notes, variant description, conflicts etc.)
                set extended_mode 1
            } elseif {$arg eq "-e"} { # Non-zero exit code on errors
                set permit_error 1
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

# keys for a normal portindex
foreach key {categories depends_fetch depends_extract depends_patch \
             depends_build depends_lib depends_run depends_test \
             description epoch homepage long_description maintainers \
             name platforms revision variants version portdir \
             replaced_by license installs_libs conflicts known_fail} {
    set keepkeys($key) 1
}

# additional keys for extended portindex (with extra information)
if {$extended_mode eq 1 } {
    foreach key {vinfo notes} {
        set keepkeys($key) 1
    }
}

set exit_fail 0
try {
    mporttraverse pindex $directory
} catch {{POSIX SIG SIGINT} eCode eMessage} {
    puts stderr "SIGINT received, terminating."
    set exit_fail 1
} catch {{POSIX SIG SIGTERM} eCode eMessage} {
    puts stderr "SIGTERM received, terminating."
    set exit_fail 1
} finally {
    if {[info exists oldfd]} {
        close $oldfd
    }
    close $fd
}
if {$exit_fail} {
    exit 1
}

file rename -force $tempportindex $outpath
file mtime $outpath $newest
mports_generate_quickindex $outpath
puts "\nTotal number of ports parsed:\t$stats(total)\
      \nPorts successfully parsed:\t[expr {$stats(total) - $stats(failed)}]\
      \nPorts failed:\t\t\t$stats(failed)\
      \nUp-to-date ports skipped:\t$stats(skipped)\n"

if {${permit_error} && $stats(failed) > 0} {
    exit 2
}

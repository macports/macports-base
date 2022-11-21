#!@TCLSH@
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# Traverse through all ports, creating an index and archiving port directories
# if requested

package require macports
package require Thread

# Globals
set full_reindex 0
set permit_error 0
set stats(total) 0
set stats(failed) 0
set stats(skipped) 0
set extended_mode 0
array set ui_options        [list ports_no_old_index_warning 1]
array set global_options    [list ports_no_load_quick_index 1]
array set global_variations [list]
set port_options            [list]

# Pass global options into mportinit
mportinit ui_options global_options global_variations

# Standard procedures
proc print_usage args {
    puts "Usage: $::argv0 \[-dfe\] \[-o output directory\] \[-p plat_ver_\[cxxlib_\]arch\] \[directory\]"
    puts "-d:\tOutput debugging information"
    puts "-f:\tDo a full re-index instead of updating"
    puts "-e:\tExit code indicates if ports failed to parse"
    puts "-o:\tOutput all files to specified directory"
    puts "-p:\tPretend to be on another platform"
    puts "-x:\tInclude extra (optional) information in the PortIndex, like variant description and port notes."
}

proc _write_index {name len line} {
    puts $::fd [list $name $len]
    puts $::fd $line
}

# Code that runs in worker threads
set worker_init_script {

package require macports
package require Thread

proc _read_index {idx} {
    set offset $::qindex($idx)
    thread::mutex lock [tsv::get mutexes PortIndex]
    try {
        seek $::oldfd $offset
        gets $::oldfd in_line

        set len  [lindex $in_line 1]
        set out_line [read $::oldfd [expr {$len - 1}]]
    } finally {
        thread::mutex unlock [tsv::get mutexes PortIndex]
    }
    set name [lindex $in_line 0]

    return [list $name $len $out_line]
}

proc _index_from_portinfo {portinfoname {is_subport no}} {
    upvar $portinfoname portinfo

    array set keep_portinfo {}
    foreach key [array names ::keepkeys] {
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
    return [list $portinfo(name) $len $output]
}

proc _open_port {portinfo_name portdir absportdir port_options_name {subport {}}} {
    upvar $portinfo_name portinfo
    upvar $port_options_name port_options

    # Make sure $prefix expands to '${prefix}' so that the PortIndex is
    # portable across prefixes, see https://trac.macports.org/ticket/53169 and
    # https://trac.macports.org/ticket/17182.
    macports_try -pass_signal {
        set macports::prefix {${prefix}}
        if {$subport eq {}} {
            set interp [mportopen file://$absportdir $port_options]
        } else {
            set interp [mportopen file://$absportdir [concat $port_options subport $subport]]
        }
    } finally {
        # Restore prefix to the previous value
        set macports::prefix $::save_prefix
    }

    array unset portinfo
    array set portinfo [mportinfo $interp]
    mportclose $interp

    set portinfo(portdir) $portdir
}

proc pindex {portdir jobnum {subport {}}} {
    try {
        tsv::set status $jobnum 1
        set absportdir [file join $::directory $portdir]
        set portfile [file join $absportdir Portfile]
        if {$subport ne ""} {
            set qname [string tolower $subport]
            set is_subport 1
        } else {
            set qname [string tolower [file tail $portdir]]
            set is_subport 0
        }
        # try to reuse the existing entry if it's still valid
        if {$::full_reindex != 1 && [info exists ::qindex($qname)]} {
            macports_try -pass_signal {
                set mtime [file mtime $portfile]
                if {$::oldmtime >= $mtime} {
                    lassign [_read_index $qname] name len line
                    array set portinfo $line

                    # reuse entry if it was made from the same portdir
                    if {[info exists portinfo(portdir)] && $portinfo(portdir) eq $portdir} {
                        tsv::set output $jobnum [list $name $len $line]

                        if {!$is_subport} {
                            if {[info exists ::ui_options(ports_debug)]} {
                                puts "Reusing existing entry for $portdir"
                            }

                            # report any subports
                            if {[info exists portinfo(subports)]} {
                                tsv::set subports $jobnum $portinfo(subports)
                            }
                        }

                        tsv::set status $jobnum -1
                        return
                    }
                }
            } on error {} {
                ui_warn "Failed to open old entry for ${portdir}, making a new one"
                if {[info exists ::ui_options(ports_debug)]} {
                    puts "$::errorInfo"
                }
            }
        }

        macports_try -pass_signal {
            _open_port portinfo $portdir $absportdir ::port_options $subport
            if {$is_subport} {
                puts "Adding subport $subport"
            } else {
                puts "Adding port $portdir"
            }

            tsv::set output $jobnum [_index_from_portinfo portinfo $is_subport]
            tsv::set mtime $jobnum [file mtime $portfile]

            # report this portfile's subports (if any)
            if {!$is_subport && [info exists portinfo(subports)]} {
                tsv::set subports $jobnum $portinfo(subports)
            }
        } on error {eMessage} {
            if {$is_subport} {
                puts stderr "Failed to parse file $portdir/Portfile with subport '${subport}': $eMessage"
            } else {
                puts stderr "Failed to parse file $portdir/Portfile: $eMessage"
            }
            return
        }

        tsv::set status $jobnum 0
        return
    } trap {POSIX SIG SIGINT} {} {
        puts stderr "SIGINT received, terminating."
        tsv::set status $jobnum 99
    } trap {POSIX SIG SIGTERM} {} {
        puts stderr "SIGTERM received, terminating."
        tsv::set status $jobnum 99
    }
}

}
# End worker_init_script

proc init_threads {} {
    append ::worker_init_script \
        [list array set qindex [array get ::qindex]] \n \
        [list array set keepkeys [array get ::keepkeys]] \n \
        [list array set ui_options [array get ::ui_options]] \n \
        [list array set global_options [array get ::global_options]] \n \
        [list set port_options $::port_options] \n \
        [list set save_prefix $::save_prefix] \n \
        [list set directory $::directory] \n \
        [list set full_reindex $::full_reindex] \n \
        [list mportinit ui_options global_options] \n \
        [list signal default {TERM INT}]
    if {[info exists ::oldfd]} {
        append ::worker_init_script \n \
            [list set outpath $::outpath] \n \
            {set oldfd [open $outpath r]} \n
    }
    if {[info exists ::oldmtime]} {
        append ::worker_init_script \
            [list set oldmtime $::oldmtime] \n
    }
    set ::maxjobs [macports:get_parallel_jobs no]
    set ::poolid [tpool::create -minworkers $::maxjobs -maxworkers $::maxjobs -initcmd $::worker_init_script]
    array set ::pending_jobs {}
    set ::nextjobnum 0
    tsv::set mutexes PortIndex [thread::mutex create]
}

proc handle_completed_jobs {} {
    set completed_jobs [tpool::wait $::poolid [array names ::pending_jobs]]
    foreach completed_job $completed_jobs {
        lassign $::pending_jobs($completed_job) jobnum portdir subport
        unset ::pending_jobs($completed_job)
        tsv::get status $jobnum status
        # -1 = skipped, 0 = success, 1 = fail, 99 = exit
        if {$status == 99} {
            set ::exit_fail 1
            array unset ::pending_jobs
            return -code break "Interrupt"
        } elseif {$status == 1} {
            incr ::stats(failed)
            incr ::stats(total)
            if {[tsv::exists output $jobnum]} {
                tsv::unset output $jobnum
            }
        } elseif {$status == 0 || $status == -1} {
            # queue jobs for subports
            if {$subport eq "" && [tsv::exists subports $jobnum]} {
                foreach nextsubport [tsv::get subports $jobnum] {
                    tsv::set status $::nextjobnum 99
                    set jobid [tpool::post -nowait $::poolid [list pindex $portdir $::nextjobnum $nextsubport]]
                    set ::pending_jobs($jobid) [list $::nextjobnum $portdir $nextsubport]
                    incr ::nextjobnum
                }
                tsv::unset subports $jobnum
            }
            if {$status == -1} {
                incr ::stats(skipped)
            } else {
                incr ::stats(total)
                tsv::get mtime $jobnum mtime
                if {$mtime > $::newest} {
                    set ::newest $mtime
                }
                tsv::unset mtime $jobnum
            }
            _write_index {*}[tsv::get output $jobnum]
            tsv::unset output $jobnum
        } else {
            error "Unknown status for job $jobnum (${portdir} $subport): $status"
        }
        tsv::unset status $jobnum
    }
}

# post new job to the pool
proc pindex_queue {portdir} {
    # Wait for a free thread
    while {[array size ::pending_jobs] >= $::maxjobs} {
        handle_completed_jobs
    }
    if {$::exit_fail} {
        error "Interrupt"
    }

    # Now queue the new job.
    # Start with worst status so we get it when the thread
    # returns due to ctrl-c etc.
    tsv::set status $::nextjobnum 99
    set jobid [tpool::post -nowait $::poolid [list pindex $portdir $::nextjobnum {}]]
    set ::pending_jobs($jobid) [list $::nextjobnum $portdir {}]
    incr ::nextjobnum
}

proc process_remaining {} {
    # let remaining jobs finish
    while {[array size ::pending_jobs] > 0} {
        handle_completed_jobs
    }
    tpool::release $::poolid
    thread::mutex destroy [tsv::get mutexes PortIndex]
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
                lappend port_options os.platform $os_platform os.major $os_major os.version ${os_major}.0.0 os.arch $os_arch
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
    init_threads
    # process list of portdirs
    mporttraverse pindex_queue $directory
    # handle completed jobs
    process_remaining
} trap {POSIX SIG SIGINT} {} {
    puts stderr "SIGINT received, terminating."
    set exit_fail 1
} trap {POSIX SIG SIGTERM} {} {
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

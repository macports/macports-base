# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package require struct::set

package require Pextlib 1.0
package require Thread

set cwd [file normalize [file dirname [info script]]]
set darwintrace_lib [file join $cwd .. darwintrace.dylib]

proc appendEntry {sandbox path action} {
    upvar 2 $sandbox sndbxlst

    set mapping {}
    # Escape backslashes with backslashes
    lappend mapping "\\" "\\\\"
    # Escape colons with \:
    lappend mapping ":" "\\:"
    # Escape equal signs with \=
    lappend mapping "=" "\\="

    # file normalize will leave symlinks as the very last
    # path component intact. This will, for instance, prevent /tmp from
    # being resolved to /private/tmp.
    # Use realpath to avoid this behavior.
    set normalizedPath [file normalize $path]
    # realpath only works on files that exist
    if {![catch {file type $normalizedPath}]} {
        set normalizedPath [realpath $normalizedPath]
    }
    lappend sndbxlst "[string map $mapping $path]=$action"
    if {$normalizedPath ne $path} {
        lappend sndbxlst "[string map $mapping $normalizedPath]=$action"
    }
}

##
# Append a trace sandbox entry suitable for allowing access to
# a directory to a given sandbox list.
#
# @param sandbox The name of the sandbox list variable
# @param path The path that should be permitted
proc allow {sandbox path} {
    appendEntry $sandbox $path "+"
}

##
# Append a trace sandbox entry suitable for denying access to a directory
# (and stopping processing of the sandbox) to a given sandbox list.
#
# @param sandbox The name of the sandbox list variable
# @param path The path that should be denied
proc deny {sandbox path} {
    appendEntry $sandbox $path "-"
}

##
# Append a trace sandbox entry suitable for deferring the access decision
# back to MacPorts to query for dependencies to a given sandbox list.
#
# @param sandbox The name of the sandbox list variable
# @param path The path that should be handed back to MacPorts for further
#             processing.
proc ask {sandbox path} {
    appendEntry $sandbox $path "?"
}

proc setup {rules} {
    global sandbox

    set sandbox [list]
    foreach {rule path} $rules {
        switch $rule {
            allow {
                allow sandbox $path
            }
            deny {
                deny sandbox $path
            }
            ask {
                ask sandbox $path
            }
        }
    }

    return tracelib_setup
}

proc tracelib_setup {} {
    global \
        darwintrace_lib \
        env \
        fifo \
        sandbox \
        thread \
        tracelib_result

    set fifo_mktemp_template "/tmp/macports-test-XXXXXX"
    set fifo [mktemp $fifo_mktemp_template]

    set thread [thread::create -joinable [list source threadsetup.tcl]]
    thread::send $thread [list setup $fifo]

    tracelib setsandbox [join $sandbox :]
    tracelib enablefence

    thread::send -async $thread [list run] tracelib_result

    set env(DYLD_INSERT_LIBRARIES) $darwintrace_lib
    set env(DARWINTRACE_LOG) $fifo
}

proc expect {{violations {}} {unknowns {}}} {
    global expectations
    array set expectations {}
    set expectations(violations) $violations
    set expectations(unknowns) $unknowns

    return tracelib_cleanup
}

proc tracelib_cleanup {} {
    global \
        env \
        expectations \
        fifo \
        sandbox \
        thread \
        tracelib_result

    tracelib closesocket
    tracelib clean
    file delete -force $fifo

    vwait tracelib_result

    thread::send $thread [list set warnings] warnings
    thread::send $thread [list set violations] violations
    thread::send $thread [list set unknowns] unknowns

    struct::set add violations_set $violations
    struct::set add unknowns_set $unknowns
    struct::set add expected_violations_set $expectations(violations)
    struct::set add expected_unknowns_set $expectations(unknowns)

    set failed no
    lassign [struct::set intersect3 $violations_set $expected_violations_set] _ additional_violations unexpected_violations
    foreach violation $additional_violations {
        puts "Unexpected violation '$violation'"
        set failed yes
    }
    foreach violation $unexpected_violations {
        puts "Expected violation '$violation' did not occur"
        set failed yes
    }

    lassign [struct::set intersect3 $unknowns_set $expected_unknowns_set] _ additional_unknowns unexpected_unknowns
    foreach unknown_ $additional_unknowns {
        puts "Unexpected unknown '$unknown_'"
        set failed yes
    }
    foreach unknown_ $unexpected_unknowns {
        puts "Expected unknown '$unknown_' did not occur"
        set failed yes
    }

    if {$failed} {
        foreach {name contents} [list "WARNINGS" $warnings "VIOLATIONS" $violations "UNKNOWNS" $unknowns] {
            if {[llength $contents] != 0} {
                puts "$name"
                foreach item $contents {
                    puts "  $item"
                }
            }
        }
        puts "SANDBOX"
        foreach sandbox_entry $sandbox {
            puts "  $sandbox_entry"
        }
    }

    thread::send -async $thread [list cleanup]
    thread::join $thread

    array unset env DYLD_INSERT_LIBRARIES
    array unset env DARWINTRACE_LOG
}


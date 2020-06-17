# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Test file for Pextlib's system command.
# Syntax:
# tclsh system.tcl <Pextlib name>

# globals
set output ""
set failures 0

# stubs
proc ui_debug {args} {
    # ignored
}
proc ui_info {args} {
    global output
    append output "$args\n"
}

# helper

proc check {a b} {
    if {$a ne $b} {
        return $b
    }
}

# run system command
# test_system {cmd...} {vars} {body...}
proc test_system {args} {
    global output failures

    set vars [lindex $args end-1]
    set body "proc body {$vars} { global output; "
    append body [lindex $args end] "}; body"
    foreach var $vars {
        append body " \$$var"
    }
    set args [lreplace $args end-1 end]

    set cmd "system "
    append cmd $args

    set output ""
    if {[catch {uplevel $cmd} res]} {
        puts "FAILED: $cmd"
        puts "catch: $res"
        incr failures
    } else {
        set output [string trim $output]
        set res [uplevel $body]
        if {$res ne ""} {
            puts "FAILED: $cmd"
            puts "Output: $output"
            puts "Expected: $res"
            incr failures
        }
    }
}

proc main {pextlibname} {
    global output failures

    load $pextlibname

    set str "MacPortsTest"
    test_system "echo \"$str\"" {str} {
        check [string trim $output] $str
    }

    test_system -W /usr "pwd" {} {
        check [string trim $output] "/usr"
    }

    if {$failures > 0} {
        exit 1
    }
    exit 0
}

main $argv

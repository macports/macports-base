package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc dep-c {} {
    global path output_file

    initial_setup

    set err "error*"
    set line [get_line $output_file $err]
    return $line
}

test dependencies-c {
    Regression test for dependencies-c.
} -body {
    dep-c
} -result -1


cleanup
cleanupTests

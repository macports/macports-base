package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc dep-b {} {
    global path output_file

    initial_setup

    set err "error*"
    set line [get_line $output_file $err]
    return $line
}

test dependencies-b {
    Regression test for dependencies-b.
} -body {
    dep-b
} -result -1


cleanup
cleanupTests

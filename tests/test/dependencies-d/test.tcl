package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc dep-d {} {
    global path output_file

    initial_setup

    set err "error*"
    set line [get_line $output_file $err]
    return $line
}

test dependencies-d {
    Regression test for dependencies-d.
} -body {
    dep-d
} -result -1


cleanup
cleanupTests

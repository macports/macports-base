package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc dep-a {} {
    global path output_file

    initial_setup

    set err "error*"
    set line [get_line $output_file $err]
    return $line
}

test dependencies-a {
    Regression test for dependencies-a.
} -body {
    dep-a
} -result -1

cleanup
cleanupTests

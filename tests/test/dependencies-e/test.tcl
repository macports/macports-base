package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc dep-e {} {
    global path output_file

    initial_setup

    set err "error: dependency 'docbook-xml-4.1.2' not found*"
    set line [get_line $output_file $err]
    return $line
}

test dependencies-e {
    Regression test for dependencies-e.
} -body {
    dep-e
} -result "error: dependency 'docbook-xml-4.1.2' not found."


cleanup
cleanupTests

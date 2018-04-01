package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

initial_setup


# Test cases
test case_insensitive_uninstall {
    Regression test for case-insensitive port name uninstall
} -body {
    port_install casesensitive
    return [port_uninstall CaseSensitivE]
} -result 0

cleanup
cleanupTests

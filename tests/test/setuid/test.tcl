package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl
set path [file dirname [file normalize $argv0]]

initial_setup

test setuid {
    Regression test for setuid permission bit.
} -body {
    global output_file path

    set str "perms: *"
    set line [get_line $path/$output_file $str]
    return $line
} -result "perms: 104755"

cleanup
cleanupTests

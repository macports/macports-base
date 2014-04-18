package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl
set path [file dirname [file normalize $argv0]]

initial_setup

proc var_check {} {
    global output_file path

    set var "utopia variant*"
    set line [get_line $path/$output_file $var]
    return $line
}


test variants {
    Regression test for variants.
} -body {
    var_check
} -result "utopia variant -- 2"


cleanup
cleanupTests

package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc sitetag {} {
    global output_file path

    initial_setup

    set err "error*"
    set line [get_line $output_file $err]
    if {$line == -1} {
        return "No errors found."
    } else {
        return "Errors found in the output file."
    }
}

test site-tags {
    Regression test for site-tags.
} -body {
    sitetag
} -result "No errors found."


cleanup
cleanupTests

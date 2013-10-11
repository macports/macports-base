package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl
set path [file dirname [file normalize $argv0]]

initial_setup

proc svn-patch {} {
    global output_file path

    set svn "error*"
    set line [get_line $path/$output_file $svn]
    if {$line == -1} {
        return "No error found."
    } else {
        return "Errors found in output file."
    }
}

test svn-patchsites {
    Regression test for svn-and-patchsites.
} -body {
    svn-patch
} -result "No error found."


cleanup
cleanupTests

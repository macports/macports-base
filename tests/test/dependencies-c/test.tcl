package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set file "output"
set dir "work"
set path [file dirname [file normalize $argv0]]

proc dep-c {} {
    global file
    global path

    load_variables $path
    set_dir
    port_index
    port_clean $path
    port_run $path

    set err "error*"
    set line [get_line $file $err]
    return $line
}

test dependencies-c {
    Regression test for dependencies-c.
} -constraints {
    root
} -body {
    dep-c
} -result -1

cleanup
removeFile $file
removeDirectory $dir

cleanupTests

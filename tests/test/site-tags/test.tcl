package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set file "output"
set dir "work"
set path [file dirname [file normalize $argv0]]

proc sitetag {} {
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

test site-tags {
    Regression test for site-tags.
} -constraints {
    root
} -body {
    sitetag
} -result -1

removeFile $file
removeDirectory $dir

cleanup
cleanupTests

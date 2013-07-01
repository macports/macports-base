package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set file "output"
set dir "work"
set path [file dirname [file normalize $argv0]]

proc dep-e {} {
    global file
    global path

    load_variables $path
    set_dir
    port_index
    port_clean $path
    port_run $path

    set err "error: dependency 'docbook-xml-4.1.2' not found*"
    set line [get_line $file $err]
    return $line
}

test dependencies-e {
    Regression test for dependencies-e.
} -constraints {
    root
} -body {
    dep-e
} -result "error: dependency 'docbook-xml-4.1.2' not found."

cleanup
removeFile $file
removeDirectory $dir

cleanupTests

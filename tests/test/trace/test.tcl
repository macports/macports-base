package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

#makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

proc test_trace {} {
    global path

    load_variables $path
    set_dir
    port_index
    port_clean $path

    exec mkdir ../tracetesttmp
    exec chown macports ../tracetesttmp
    exec sudo -u macports touch  ../tracetesttmp/delete-trace
    exec sudo -u macports touch ../tracetesttmp/rename-trace
    exec sudo -u macports mkdir ../tracetesttmp/rmdir-trace
    file delete -force /tmp/hello-trace
    file link -symbolic /tmp/link-trace2 /usr/include/unistd.h
    exec chown -h macports /tmp/link-trace2

    port_trace $path
    
    file delete -force /tmp/link-trace2
    file delete -force /tmp/hello-trace
}

test trace {
    Regression test for trace.
} -body {
    test_trace
} -result ""


cleanup
cleanupTests

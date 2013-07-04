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

    makeFile "" delete-trace
    makeFile "" rename-trace
    makeDirectory rmdir-trace
    file link -symbolic /tmp/link-trace2 /usr/include/unistd.h

    file delete -force create-trace
    file delete -force create-trace-modenv
    file delete -force mkdir-trace
    file delete -force /tmp/hello-trace
    file delete -force link-trace
    
    port_run $path
    
    file delete -force link-trace
    file delete -force rename-new-trace
    file delete -force create-trace
    file delete -force create-trace-modenv
    file delete -force mkdir-trace
    file delete -force /tmp/hello-trace
    file delete -force /tmp/link-trace
}

test trace {
    Regression test for trace.
} -body {
    test_trace
} -result ""


cleanup
cleanupTests

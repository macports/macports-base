package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

load_variables $path

proc test_trace {} {
    global path autoconf output_file

    set line [get_line $autoconf "runusr*"]
    set user [lrange [split $line " "] 1 1]

    set_dir
    port_index
    port_clean $path


    makeDirectory ../tracetesttmp
    file attributes ../tracetesttmp -owner $user
    exec sudo -u $user touch  ../tracetesttmp/delete-trace
    exec sudo -u $user touch ../tracetesttmp/rename-trace
    exec sudo -u $user mkdir ../tracetesttmp/rmdir-trace
    file delete -force /tmp/hello-trace
    file link -symbolic /tmp/link-trace2 /usr/include/unistd.h
    exec chown -h $user /tmp/link-trace2

    port_trace $path
    
    #file delete -force /tmp/link-trace2
    file delete -force /tmp/hello-trace

    set err "error*"
    set line [get_line $path/$output_file $err]
    if { $line == -1 } {
        return "No errors found."
    } else {
        return $line
    }
}

test trace {
    Regression test for trace.
} -body {
    test_trace
} -result "No errors found."


cleanup
cleanupTests

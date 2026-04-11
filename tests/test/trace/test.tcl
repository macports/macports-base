package require tcltest 2
namespace import tcltest::*

# need pextlib to drop privs
package require Pextlib 1.0

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

load_variables $path
set_dir
port_index

proc test_trace {} {
    global path output_file

    port_clean $path

    file delete -force /tmp/hello-trace
    file delete -force /tmp/link-trace2
    file link -symbolic /tmp/link-trace2 /usr/share/man/man1/awk.1

    makeDirectory ../tracetesttmp
    exec -ignorestderr touch  ../tracetesttmp/delete-trace
    exec -ignorestderr touch ../tracetesttmp/rename-trace
    exec -ignorestderr file mkdir ../tracetesttmp/rmdir-trace

    port_trace $path

    set err "error*"
    set line [get_line $path/$output_file $err]
    set unsupported [get_line $path/$output_file "*tracelib not supported on this platform*"]
    if {$unsupported != -1 || $line == -1} {
        return "No errors found."
    } else {
        return $line
    }
}

testConstraint notRoot [expr {[getuid] != 0}]

test trace {Regression test for trace.} \
    -constraints [list tracemode_support notRoot] \
    -body {
        test_trace
    } \
    -cleanup {
        file delete -force /tmp/link-trace2
        file delete -force /tmp/hello-trace
    } \
    -result "No errors found."


cleanup
cleanupTests

package require tcltest 2

# need pextlib to drop privs
package require Pextlib 1.0

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

    file delete -force /tmp/hello-trace
    file delete -force /tmp/link-trace2
    file link -symbolic /tmp/link-trace2 /usr/include/unistd.h

    makeDirectory ../tracetesttmp
    if {[getuid] == 0} {
        file attributes ../tracetesttmp -owner $user
        exec chown -h $user /tmp/link-trace2
    }

    if {[getuid] == 0} {
        seteuid [name_to_uid $user]
    }
    exec touch  ../tracetesttmp/delete-trace
    exec touch ../tracetesttmp/rename-trace
    exec mkdir ../tracetesttmp/rmdir-trace
    if {[getuid] == 0} {
        seteuid 0
    }

    port_trace $path

    file delete -force /tmp/link-trace2
    file delete -force /tmp/hello-trace

    set err "error*"
    set line [get_line $path/$output_file $err]
    set unsupported [get_line $path/$output_file "*tracelib not supported on this platform*"]
    if {$unsupported != -1 || $line == -1} {
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

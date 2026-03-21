package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]


# Initial setup
load_variables $path
set_dir
port_index
port_clean $path

proc envvar_test {} {
    global output_file path portsrc test_tclsh top_srcdir

    exec -ignorestderr env ENVA=A ENVB=B PORTSRC=${portsrc} ${test_tclsh} ${top_srcdir}/src/port/port.tcl test > output
    set line [get_line $path/$output_file "a"]
    set line2 [get_line $path/$output_file "b"]
    return $line$line2
}

test envvariables {
    Regression test for Environment Variables.
} -body {
    envvar_test
} -result "ab"


cleanup
cleanupTests

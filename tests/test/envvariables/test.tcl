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
    global output_file path portsrc bindir

    # Build helping string
    set string "export ENVA=A; export ENVB=B; "
    append string "export PORTSRC=${portsrc}; "
    append string "${bindir}/port test"

    exec -ignorestderr sh -c $string > output
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

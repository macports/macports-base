package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
set path [file dirname [file normalize $argv0]]

# Initial setup
load_variables $path
set_dir
port_index
port_config $path
port_destroot $path
port_clean $path

proc state_unknown {warn} {
    global path output_file

    if {$warn ne "no"} {
        set msg "warning*"
    } else {
        set msg "*staging*destroot*"
    }

    set line [get_line $path/$output_file $msg]
    return $line
}

test warning_check {
    Regression test for statefile-unknown warnings.
} -body {
    state_unknown yes
} -result "warning: unsupported statefile version '3'"

test output_check {
    Regression test for statefile-unknown output.
} -body {
    state_unknown no
} -result "--->  staging statefile-unknown-version into destroot"

removeFile $work_dir

cleanup
cleanupTests

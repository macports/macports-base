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
file copy -force $path/statefile $work_dir/.macports.statefile-version2-invalid.state
file attributes $work_dir/.macports.statefile-version2-invalid.state -permissions 0664
port_destroot $path
port_clean $path

proc state_v2_invalid {warn} {
    global path output_file

    if {$warn ne "no"} {
        set msg "*warning*checksum*"
    } else {
        set msg "*staging*destroot*"
    }

    set line [get_line $path/$output_file $msg]
    return $line
}

test warning_check {
    Regression test for statefile-v2-invalid discard prev version.
} -body {
    state_v2_invalid yes
} -result "warning: statefile has version 2 but didn't contain a checksum"

test output_check {
    Regression test for statefile-v2-invalid output.
} -body {
    state_v2_invalid no
} -result "--->  staging statefile-version2-invalid into destroot"

removeDirectory $work_dir

cleanup
cleanupTests

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
port_config $path
port_destroot $path
port_clean $path

proc statefile_v1 {warn} {
    global path output_file

    if {$warn ne "no"} {
        set msg "*discarding previous state*"
    } else {
        set msg "*staging*destroot*"
    }
    set line [get_line $path/$output_file $msg]
    return $line
}

test warning_check {
    Regression test for statefile-version1.
} -body {
    statefile_v1 yes
} -result "-1"

test output_check {
    Regression test for statefile-version1.
} -body {
    statefile_v1 no
} -result "--->  staging statefile-version1 into destroot"


cleanup
cleanupTests

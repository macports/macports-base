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
file copy -force $path/statefile $work_dir/.macports.statefile-version1-outdated.state
file attributes $work_dir/.macports.statefile-version1-outdated.state -permissions 0664
exec -ignorestderr touch -t 197001010000.09 $work_dir/.macports.statefile-version1-outdated.state
port_destroot $path
port_clean $path

proc state_v1 {warn} {
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
    Regression test for statefile-v1-outdated discard prev version.
} -body {
    state_v1 yes
} -result "portfile changed since last build; discarding previous state."

test output_check {
    Regression test for statefile-v1-outdated output.
} -body {
    state_v1 no
} -result "--->  staging statefile-version1-outdated into destroot"

removeDirectory $work_dir

cleanup
cleanupTests

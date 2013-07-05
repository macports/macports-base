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
port_desroot $path
port_clean $path

proc statefile_v2 {} {
    global path
    global output_file

    set msg "*staging*destroot*"
    set line [get_line $path/$output_file $msg]
    return $line
}

test envvariables {
    Regression test for statefile-version1.
} -body {
    statefile_v2
} -result "--->  staging statefile-version2 into destroot"


cleanup
cleanupTests

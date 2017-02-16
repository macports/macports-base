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
file copy -force $path/statefile $work_dir/.macports.statefile-version2.state
exec -ignorestderr sed -i'' -E "s/@CHECKSUM@/`openssl dgst -sha256 Portfile | \
    awk '{print \$\$2}'`/" $work_dir/.macports.statefile-version2.state
port_destroot $path
port_clean $path

proc statefile_v2 {arg} {
    global path output_file

    if {$arg ne "no"} {
        set msg "*discarding previous state*"
    } else {
        set msg "*staging*destroot*"
    }
    set line [get_line $path/$output_file $msg]
    return $line
}

test statefile-v2-discard {
    Regression test for statefile-version2 no discard.
} -body {
    statefile_v2 yes
} -result "-1"

test statefile-v2 {
    Regression test for statefile-version2.
} -body {
    statefile_v2 no
} -result "--->  staging statefile-version2 into destroot"


cleanup
cleanupTests

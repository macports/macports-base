source [file join [lindex $argv 0] macports1.0 macports_fastload.tcl]
package require macports
mportinit

source [file dirname [info script]]/../portdestroot.tcl
source [file dirname [info script]]/common.tcl

namespace eval tests {

proc "when destroot cmd is not gmake no -w argument is added" {} {
    global build.type build.cmd destroot.cmd destroot.target

    set build.type "gnu"
    set build.cmd "gmake"
    set destroot.cmd "_destroot_cmd_"
    set destroot.target "_target_"

    test_equal {[portdestroot::destroot_getargs]} "_target_"
}

proc "when destroot cmd is gmake a -w argument is added" {} {
    global build.type build.cmd destroot.cmd destroot.target

    set build.type "gnu"
    set build.cmd "_build_cmd_"
    set destroot.cmd "gmake"
    set destroot.target "_target_"

    test_equal {[portdestroot::destroot_getargs]} "-w _target_"
}


# run all tests
foreach proc [info procs *] {
    puts "* ${proc}"
    $proc
}

# namespace eval tests
}

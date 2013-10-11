package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

initial_setup

proc get_checksum {type} {
    global path output_file

    append string "debug: calculated (" $type ")*"
    set line [get_line $path/$output_file $string]
    set result [lrange [split $line " "] 4 4]

    return $result
}


# Test cases
test md5_checksum {
    Regression test for MD5 Checksum.
} -body {
    get_checksum md5
} -result "d41d8cd98f00b204e9800998ecf8427e"


test sha1_checksum {
    Regression test for SHA1 Checksum.
} -body {
    get_checksum sha1
} -result "da39a3ee5e6b4b0d3255bfef95601890afd80709"


test rmd160_checksum {
    Regression test for RMD160 Checksum.
} -body {
    get_checksum rmd160
} -result "9c1185a5c5e9fc54612808977ee8f548b2258d31"


cleanup
cleanupTests

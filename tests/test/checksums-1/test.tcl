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
port_run $path


# Useful procs
proc get_md5 {filename} {
    global path
    set md5 "debug: calculated (md5)*"

    set line [get_line $path/$filename $md5]
    set result [lrange [split $line " "] 4 4]

    return $result
}

proc get_sha {filename} {
    global path
    set sha "debug: calculated (sha1)*"

    set line [get_line $path/$filename $sha]
    set result [lrange [split $line " "] 4 4]

    return $result
}

proc get_rmd {filename} {
    global path
    set sha "debug: calculated (rmd160)*"

    set line [get_line $path/$filename $sha]
    set result [lrange [split $line " "] 4 4]

    return $result
}


# Test cases
test md5_checksum {
    Regression test for MD5 Checksum.
} -body {
    get_md5 $output_file
} -result "d41d8cd98f00b204e9800998ecf8427e"


test sha1_checksum {
    Regression test for SHA1 Checksum.
} -body {
    get_sha $output_file
} -result "da39a3ee5e6b4b0d3255bfef95601890afd80709"


test rmd160_checksum {
    Regression test for RMD160 Checksum.
} -body {
    get_rmd $output_file
} -result "9c1185a5c5e9fc54612808977ee8f548b2258d31"


cleanup
cleanupTests

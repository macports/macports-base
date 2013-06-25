package require tcltest 2
namespace import tcltest::*

source ./checksum.tcl

set file "output"
set dir "work"

# Initial setup
load_variables
port_clean
port_run


test md5_checksum {
    Regression test for MD5 Checksum.
} -constraints {
    root
} -body {
    get_md5 $file
} -result "d41d8cd98f00b204e9800998ecf8427e"


test sha1_checksum {
    Regression test for SHA1 Checksum.
} -constraints {
    root
} -body {
    get_sha $file
} -result "da39a3ee5e6b4b0d3255bfef95601890afd80709"


test rmd160_checksum {
    Regression test for RMD160 Checksum.
} -constraints {
    root
} -body {
    get_rmd $file
} -result "9c1185a5c5e9fc54612808977ee8f548b2258d31"


# remove output file and print results
removeFile $file
removeDirectory $dir

cleanupTests

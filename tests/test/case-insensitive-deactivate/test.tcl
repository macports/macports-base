package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set file "output"
set dir "work"
set path [file dirname [file normalize $argv0]]

set testfile "/tmp/macports-tests/opt/local/var/test/case"
set testport1 "casesensitive"
set testport2 "CaseSensitivE"

load_variables $path
set_dir
port_index

proc test_exists {} {
    global path
    global testfile
    global testport1

    exec sed "s/@name@/$testport1/" $path/Portfile.in > Portfile
    port_install

    if {[file exists $testfile]} {
        return "Port installed."
    } else {
        return "File missing."
    }
}

proc test_not_exists {} {
    global path
    global testfile
    global testport2

    exec sed "s/@name@/$testport2/" $path/Portfile.in > Portfile
    port_uninstall

    if {[file exists $testfile]} {
        return "File still exists."
    } else {
        return "Port uninstalled."
    }
}

# Test cases.
test file_installed {
    Regression test for file installed correctly.
} -constraints {
    root
} -body {
    test_exists
} -result "Port installed."

test file_uninstalled {
    Regression test for file uninstalled correctly.
} -constraints {
    root
} -body {
    test_not_exists
} -result "Port uninstalled."

# remove output file and print results
removeFile Portfile
removeFile $file
removeDirectory $dir

cleanup
cleanupTests

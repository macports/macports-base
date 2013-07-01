package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set file "output"
set dir "work"
set path [file dirname [file normalize $argv0]]

# Initial setup
load_variables $path
set_dir
port_index
port_clean $path

proc envvar_test {} {
    global file
    global path

    # Make helping script
    set fp [open script.sh w+]
    puts $fp "export ENVA=A; export ENVB=B; \
    export PORTSRC=/Volumes/Other/gsoc/macports-all/branches/gsoc13-tests/tests/test-macports.conf; \
    /opt/macports-test/bin/port test"
    close $fp

    exec sh script.sh > output
    set line [get_line $path/$file "a"]
    set line2 [get_line $path/$file "b"]
    return $line$line2
}

test envvariables {
    Regression test for Environment Variables.
} -constraints {
    root
} -body {
    envvar_test
} -result "ab"


# remove output file and print results
removeFile script.sh
removeFile $file
removeDirectory $dir

cleanupTests

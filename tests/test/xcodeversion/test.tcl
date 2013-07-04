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

proc xcode_ver {} {
    global output_file
    global path

    set xcode "xcodeversion*"
    set line [get_line $path/$output_file $xcode]
    return $line
}

proc xcode_binpath {} {
    global output_file
    global path

    set xcode "xcodebuildcmd*"
    set line [get_line $path/$output_file $xcode]
    return $line
}

test envvariables {
    Regression test for XCode version.
} -body {
    xcode_ver
} -result "xcodeversion >= 2.1"

test xcode_path {
    Regression test for XCode path.
} -body {
    xcode_binpath
} -result "xcodebuildcmd = /usr/bin/xcodebuild"


cleanup
cleanupTests

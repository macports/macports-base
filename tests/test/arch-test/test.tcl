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

proc noarch_good_test {} {
    global output_file path portsrc bindir

    port_clean $path

    set string "export PORTSRC=${portsrc}; "
    append string "${bindir}/port -q test +declare_noarch +be_noarch"

    exec -ignorestderr sh -c $string > /dev/null 2> $output_file
    set line [get_line $path/$output_file "*Mach-O files*"]
    return $line
}

proc noarch_bad_test {} {
    global output_file path portsrc bindir

    port_clean $path

    set string "export PORTSRC=${portsrc}; "
    append string "${bindir}/port -q test +declare_noarch"

    exec -ignorestderr sh -c $string  > /dev/null 2> $output_file
    set line [get_line $path/$output_file "*Mach-O files*"]
    return $line
}

proc arch_good_test {} {
    global output_file path portsrc bindir

    port_clean $path

    set string "export PORTSRC=${portsrc}; "
    append string "${bindir}/port -q test"

    exec -ignorestderr sh -c $string  > /dev/null 2> $output_file
    set line [get_line $path/$output_file "*Mach-O files*"]
    return $line
}

proc arch_bad_test {} {
    global output_file path portsrc bindir

    port_clean $path

    set string "export PORTSRC=${portsrc}; "
    append string "${bindir}/port -q test +be_noarch"

    exec -ignorestderr sh -c $string  > /dev/null 2> $output_file
    set line [get_line $path/$output_file "*Mach-O files*"]
    return $line
}

test envvariables {
    Regression test for architecture mismatch tests.
} -body {
    set output [noarch_good_test]
    if {$output != -1} {
        puts stderr "correct noarch port got warning:"
        puts $output
        return "fail"
    }
    set output [noarch_bad_test]
    if {$output == -1} {
        puts stderr "port mislabelled as noarch got no warning"
        return "fail"
    }
    set output [arch_good_test]
    if {$output != -1} {
        puts stderr "correct non-noarch port got warning:"
        puts $output
        return "fail"
    }
    set output [arch_bad_test]
    if {$output == -1} {
        puts stderr "port incorrectly not labelled as noarch got no warning"
        return "fail"
    }
    return "ok"
} -result "ok"


cleanup
cleanupTests

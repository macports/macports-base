package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

load_variables $path
set_dir
port_index

# Runs port with the given arguments, with its output replacing the
# output file. Returns 0 on success.
proc port_cmd {args} {
    global output_file portsrc test_tclsh top_srcdir

    close [open $output_file w]
    set result [catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl -N {*}$args >> $output_file 2>@1
            }
        }
    }]
    return $result
}

# Returns 1 if a line of the last port command's output matches the
# glob pattern.
proc output_has {pattern} {
    global output_file

    set fd [open $output_file r]
    set lines [split [read $fd] \n]
    close $fd
    return [expr {[lsearch -glob $lines $pattern] != -1}]
}

# Returns 1 if the port is installed and active.
proc port_active {} {
    global test_root

    return [file exists ${test_root}/opt/local/share/upgrade-binary-only-processall/installed]
}


# Test cases
test upgrade_binary_only_processall {
    Regression test for a forced upgrade with -b -p of a port that has
    no binary archive: it fails without building the port, and the
    installed version stays active.
} -body {
    set building "*Building upgrade-binary-only-processall*"
    set no_archive "*Failed to fetch binary archive*"
    if {[port_cmd install upgrade-binary-only-processall] != 0} {
        return "FAIL: install failed"
    }
    if {![output_has $building]} {
        return "FAIL: install did not build the port"
    }
    if {[port_cmd -b -p upgrade --force upgrade-binary-only-processall] != 1} {
        return "FAIL: binary-only upgrade did not fail"
    }
    if {![output_has $no_archive]} {
        return "FAIL: binary-only upgrade did not fail on the archive"
    }
    if {[output_has $building]} {
        return "FAIL: built from source despite -b"
    }
    if {![port_active]} {
        return "FAIL: no longer active after the upgrade"
    }
    # Without -b, the same upgrade builds the port.
    if {[port_cmd -p upgrade --force upgrade-binary-only-processall] != 0} {
        return "FAIL: upgrade without -b failed"
    }
    if {![output_has $building]} {
        return "FAIL: not built without -b"
    }
    if {![port_active]} {
        return "FAIL: not active after the upgrade without -b"
    }
    return "Not built, installed version kept."
} -result "Not built, installed version kept."

cleanup
cleanupTests

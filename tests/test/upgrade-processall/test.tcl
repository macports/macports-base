package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

makeFile "" $output_file
makeDirectory $work_dir
set path [file dirname [file normalize $argv0]]

load_variables $path
set_dir
port_index

# Runs port with the given arguments, returns 0 on success.
proc port_cmd {args} {
    global portsrc test_tclsh top_srcdir

    set result [catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl -N {*}$args >> output 2>@1
            }
        }
    }]
    return $result
}

# Returns the installed versions of a port.
proc port_versions {name} {
    global portsrc test_tclsh top_srcdir

    set versions [list]
    catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                set installed [exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl -q installed $name 2>@1]
            }
        }
        foreach {- version} [regexp -all -inline {@(\S+)} $installed] {
            lappend versions $version
        }
    }
    return $versions
}

# Returns the value written by the active build of a port, or
# "missing" if no version of the port is active.
proc port_build_value {name} {
    global test_root

    set file ${test_root}/opt/local/var/test/${name}
    if {![file exists $file]} {
        return missing
    }
    set fd [open $file r]
    set value [string trim [read $fd]]
    close $fd
    return $value
}

# Creates or deletes a flag file read by the Portfile.
proc set_flag {name} {
    global test_root
    close [open ${test_root}/opt/local/var/test/${name} w]
}
proc clear_flag {name} {
    global test_root
    file delete ${test_root}/opt/local/var/test/${name}
}


# Test cases
test upgrade_binary_only_processall {
    Regression test for a forced upgrade with -b -p of a port that has
    no binary archive: it keeps its installed version.
} -body {
    if {[port_cmd install upgrade-processall] != 0} {
        return "FAIL: install failed"
    }
    set before [port_build_value upgrade-processall]
    if {[port_cmd -b -p upgrade --force upgrade-processall] != 1} {
        return "FAIL: binary-only upgrade did not fail"
    }
    set after [port_build_value upgrade-processall]
    if {$after eq "missing"} {
        return "FAIL: uninstalled by the upgrade"
    }
    if {$after ne $before} {
        return "FAIL: rebuilt despite -b"
    }
    # Without -b, the same upgrade rebuilds the port.
    if {[port_cmd -p upgrade --force upgrade-processall] != 0} {
        return "FAIL: upgrade without -b failed"
    }
    if {[port_build_value upgrade-processall] in [list missing $before]} {
        return "FAIL: not rebuilt without -b"
    }
    return "Installed version kept."
} -result "Installed version kept."

test upgrade_failure_processall {
    Regression test for a forced upgrade with -p of two ports, one of
    which fails to build: it keeps its installed version, and the other
    is upgraded.
} -body {
    if {[port_cmd install upgrade-processall-broken upgrade-processall-ok] != 0} {
        return "FAIL: install failed"
    }
    set broken [port_build_value upgrade-processall-broken]
    set ok [port_build_value upgrade-processall-ok]
    set_flag upgrade-processall-broken.fail
    if {[port_cmd -p upgrade --force upgrade-processall-broken upgrade-processall-ok] != 1} {
        return "FAIL: upgrade did not fail"
    }
    set broken_after [port_build_value upgrade-processall-broken]
    set ok_after [port_build_value upgrade-processall-ok]
    if {$broken_after eq "missing"} {
        return "FAIL: failed port uninstalled by the upgrade"
    }
    if {$broken_after ne $broken} {
        return "FAIL: failed port changed"
    }
    if {$ok_after in [list missing $ok]} {
        return "FAIL: other port not upgraded"
    }
    return "Failed port kept, other port upgraded."
} -cleanup {
    clear_flag upgrade-processall-broken.fail
} -result "Failed port kept, other port upgraded."

test upgrade_uninstall_old_processall {
    Regression test for an upgrade with -p -u to a new version that
    fails to build: the installed version is not uninstalled.
} -body {
    if {[port_cmd install upgrade-processall-broken] != 0} {
        return "FAIL: install failed"
    }
    set before [port_build_value upgrade-processall-broken]
    set_flag upgrade-processall-broken.fail
    set_flag upgrade-processall-broken.version2
    if {[port_cmd -p -u upgrade upgrade-processall-broken] != 1} {
        return "FAIL: upgrade did not fail"
    }
    set after [port_build_value upgrade-processall-broken]
    if {$after eq "missing"} {
        return "FAIL: installed version uninstalled by the upgrade"
    }
    if {$after ne $before} {
        return "FAIL: installed version changed"
    }
    # Once the build works, the same upgrade installs version 2.
    clear_flag upgrade-processall-broken.fail
    if {[port_cmd -p -u upgrade upgrade-processall-broken] != 0} {
        return "FAIL: upgrade failed without the build failure"
    }
    if {[port_build_value upgrade-processall-broken] in [list missing $before]
            || [port_versions upgrade-processall-broken] ne [list 2_0]} {
        return "FAIL: version 2 not installed"
    }
    return "Installed version kept."
} -cleanup {
    clear_flag upgrade-processall-broken.fail
    clear_flag upgrade-processall-broken.version2
} -result "Installed version kept."

test upgrade_activate_failure_processall {
    Regression test for an upgrade with -p -u to a new version that
    fails to activate: the installed version is not uninstalled.
} -body {
    if {[port_cmd install upgrade-processall upgrade-processall-conflict] != 0} {
        return "FAIL: install failed"
    }
    set_flag upgrade-processall-conflict.version2
    set_flag upgrade-processall-conflict.conflict
    if {[port_cmd -p -u upgrade upgrade-processall-conflict] != 1} {
        return "FAIL: upgrade did not fail"
    }
    set versions [port_versions upgrade-processall-conflict]
    if {"1_0" ni $versions} {
        return "FAIL: installed version uninstalled by the upgrade ($versions)"
    }
    if {"2_0" ni $versions} {
        return "FAIL: version 2 not installed ($versions)"
    }
    return "Installed version kept."
} -cleanup {
    clear_flag upgrade-processall-conflict.version2
    clear_flag upgrade-processall-conflict.conflict
} -result "Installed version kept."

test upgrade_dry_run_processall {
    Regression test for a dry run of a failing upgrade with -b -p: the
    operations of every port are still shown.
} -body {
    if {[port_cmd install upgrade-processall upgrade-processall-ok] != 0} {
        return "FAIL: install failed"
    }
    close [open $output_file w]
    port_cmd -y -b -p upgrade --force upgrade-processall upgrade-processall-ok
    foreach name {upgrade-processall upgrade-processall-ok} {
        if {[get_line $output_file "Skipping activate $name @*"] == -1} {
            return "FAIL: activation of $name not shown"
        }
    }
    return "All operations shown."
} -result "All operations shown."

cleanup
cleanupTests

package require tcltest 2
namespace import tcltest::*

source [file dirname $argv0]/../library.tcl

set path [file dirname [file normalize $argv0]]
makeFile "" $output_file

load_variables $path
set_dir
set fd [open $portsrc a]
puts $fd "sandbox_enable no"
close $fd

proc port_local {args} {
    global output_file path portsrc test_tclsh top_srcdir

    set back [pwd]
    cd $path
    set result [catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl -D $path --local {*}$args >$output_file 2>@1
            }
        }
    }]
    cd $back
    return $result
}

proc port_normal_info {} {
    global output_file path portsrc test_tclsh top_srcdir

    set back [pwd]
    cd $path
    set result [catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl -D $path info >$output_file 2>@1
            }
        }
    }]
    cd $back
    return $result
}

proc port_normal_installed {} {
    global output_file path portsrc test_tclsh top_srcdir

    set back [pwd]
    cd $path
    set result [catch {
        without_darwintrace_env {
            with_portsrc $portsrc {
                exec -ignorestderr ${test_tclsh} ${top_srcdir}/src/port/port.tcl installed local-mode >$output_file 2>@1
            }
        }
    }]
    cd $back
    return $result
}

proc registry_db_path {} {
    global test_root
    return [file join $test_root opt/local/var/macports/registry/registry.db]
}

proc ensure_registry {} {
    if {![file exists [registry_db_path]] && [port_normal_info] != 0} {
        return 1
    }
    return 0
}

proc local_mode_destroot {} {
    global path test_root output_file

    file delete -force ${path}/work
    if {[ensure_registry]} {
        return "FAIL: could not initialize test registry"
    }
    if {[port_local destroot] != 0} {
        return "FAIL: destroot failed"
    }
    if {![file exists ${path}/work/build.marker]} {
        return "FAIL: build marker not in local workpath"
    }
    set destroot_result [file normalize "${path}/work/destroot[file normalize $test_root]/opt/local/share/local-mode/result"]
    if {![file exists $destroot_result]} {
        return "FAIL: destroot result not in local workpath"
    }
    if {![file exists ${path}/work/logs/local-mode/main.log]} {
        return "FAIL: log not in local workpath"
    }
    if {[llength [glob -nocomplain -directory ${test_root}/opt/local/var/macports/build *]] != 0} {
        return "FAIL: global build path was used"
    }
    if {[port_normal_installed] != 0} {
        return "FAIL: could not query installed ports"
    }
    set line [get_line $output_file "*none of the specified ports are installed*"]
    if {$line eq "-1"} {
        return "FAIL: local destroot wrote an installed registry entry"
    }

    return "Local destroot successful."
}

proc local_mode_clean {} {
    global path test_root

    if {[ensure_registry]} {
        return "FAIL: could not initialize test registry"
    }
    file mkdir ${path}/work
    close [open ${path}/work/clean.marker w]
    file mkdir ${test_root}/opt/local/var/macports/distfiles/local-mode
    close [open ${test_root}/opt/local/var/macports/distfiles/local-mode/keep w]

    if {[port_local clean --dist] != 0} {
        return "FAIL: clean failed"
    }
    if {[file exists ${path}/work]} {
        return "FAIL: local workpath not removed"
    }
    if {![file exists ${test_root}/opt/local/var/macports/distfiles/local-mode/keep]} {
        return "FAIL: global distfile was removed"
    }

    return "Local clean successful."
}

proc local_mode_reject_install {} {
    global output_file

    if {[port_local install] == 0} {
        return "FAIL: install was accepted"
    }
    set line [get_line $output_file "*--local does not support 'install'*"]
    if {$line eq "-1"} {
        return "FAIL: missing install rejection"
    }
    return "Local install rejection successful."
}

proc local_mode_missing_dependency {} {
    global output_file
    global path

    file delete -force ${path}/work
    if {[ensure_registry]} {
        return "FAIL: could not initialize test registry"
    }
    if {[port_local build +missingdep] == 0} {
        return "FAIL: missing dependency was accepted"
    }
    set line [get_line $output_file "*dependency local-mode-missingdep is not installed and active*"]
    if {$line eq "-1"} {
        return "FAIL: missing dependency was not reported"
    }
    return "Local dependency rejection successful."
}

proc local_mode_satisfied_file_dependency {} {
    global path

    file delete -force ${path}/work
    if {[ensure_registry]} {
        return "FAIL: could not initialize test registry"
    }

    set regdb [registry_db_path]
    set regdir [file dirname $regdb]
    set regdb_perms [file attributes $regdb -permissions]
    set regdir_perms [file attributes $regdir -permissions]
    try {
        file attributes $regdb -permissions 0444
        file attributes $regdir -permissions 0555
        if {[port_local build +bindep] != 0} {
            return "FAIL: satisfied bin dependency was rejected"
        }
        if {![file exists ${path}/work/build.marker]} {
            return "FAIL: build did not run"
        }
    } finally {
        file attributes $regdir -permissions $regdir_perms
        file attributes $regdb -permissions $regdb_perms
    }
    return "Local satisfied file dependency successful."
}

test local_mode_destroot {
    Local mode keeps build artifacts and logs under the Portfile directory.
} -constraints {
    nonRoot
} -body {
    local_mode_destroot
} -cleanup {
    file delete -force ${path}/work
} -result "Local destroot successful."

test local_mode_clean {
    Local mode clean removes only the local work directory.
} -constraints {
    nonRoot
} -body {
    local_mode_clean
} -cleanup {
    file delete -force ${path}/work
} -result "Local clean successful."

test local_mode_reject_install {
    Local mode rejects installation actions.
} -constraints {
    nonRoot
} -body {
    local_mode_reject_install
} -result "Local install rejection successful."

test local_mode_missing_dependency {
    Local mode reports missing dependencies without installing them.
} -constraints {
    nonRoot
} -body {
    local_mode_missing_dependency
} -cleanup {
    file delete -force ${path}/work
} -result "Local dependency rejection successful."

test local_mode_satisfied_file_dependency {
    Local mode accepts bin/path/lib dependencies satisfied outside the registry.
} -constraints {
    nonRoot
} -body {
    local_mode_satisfied_file_dependency
} -cleanup {
    file delete -force ${path}/work
} -result "Local satisfied file dependency successful."

cleanup
cleanupTests

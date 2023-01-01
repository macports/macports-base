# et:ts=4
# porttest.tcl

package provide porttest 1.0
package require portutil 1.0
package require portprogress 1.0
package require machista 1.0

set org.macports.test [target_new org.macports.test porttest::test_main]
target_provides ${org.macports.test} test
target_requires ${org.macports.test} main fetch checksum extract patch configure build destroot
target_prerun ${org.macports.test} porttest::test_start

namespace eval porttest {
}

# define options
options test.run test.target test.ignore_archs
commands test

# Set defaults
default test.dir {${build.dir}}
default test.cmd {${build.cmd}}
default test.pre_args {${test.target}}
default test.target test
default test.ignore_archs no

set_ui_prefix

proc porttest::get_file_archs {handle fpath} {
    set resultlist [machista::parse_file $handle $fpath]
    set returncode [lindex $resultlist 0]
    set result     [lindex $resultlist 1]
    if {$returncode != $machista::SUCCESS} {
        # fails on static libs, ignore
        if {$returncode != $machista::EMAGIC} {
            ui_warn "Error parsing file ${fpath}: [machista::strerror $returncode]"
        }
        return ""
    }
    set ret [list]
    set architecture [$result cget -mt_archs]
    while {$architecture ne "NULL"} {
        lappend ret [machista::get_arch_name [$architecture cget -mat_arch]]
        set architecture [$architecture cget -next]
    }
    return $ret
}

proc porttest::test_archs {} {
    if {[option os.platform] ne "darwin" || [option test.ignore_archs]} {
        return
    }
    set handle [machista::create_handle]
    if {$handle eq "NULL"} {
        error "Error creating libmachista handle"
    }
    array set file_archs {}
    set destrootlen [string length [option destroot]]
    fs-traverse -depth fullpath [list [option destpath]] {
        if {[file type $fullpath] ne "file"} {
            continue
        }
        if {[fileIsBinary $fullpath]} {
            set archs [get_file_archs $handle $fullpath]
            if {$archs ne ""} {
                # not guaranteed to be listed in canonical order
                lappend file_archs([lsort -ascii $archs]) [string range $fullpath $destrootlen end]
            }
        }
    }
    set wanted_archs [get_canonical_archs]
    set has_wanted_archs [info exists file_archs($wanted_archs)]
    unset -nocomplain file_archs($wanted_archs)
    if {[array names file_archs] ne ""} {
        set msg "[option name] is configured to build "
        if {$wanted_archs eq "noarch"} {
            append msg "no architecture-specific files,"
        } else {
            append msg "for the architecture(s) '$wanted_archs',"
        }
        append msg " but installed Mach-O files built for the following archs:\n"
        foreach a [array names file_archs] {
            append msg [join $a ,]:\n
            foreach f $file_archs($a) {
                append msg "  $f\n"
            }
        }
        ui_warn $msg
    } elseif {$wanted_archs ne "noarch" && !${has_wanted_archs}} {
        ui_warn "[option name] is configured to build for the architecture(s) '$wanted_archs',\
                    but did not install any Mach-O files."
    }
    machista::destroy_handle $handle
}

proc porttest::test_start {args} {
    global UI_PREFIX subport
    ui_notice "$UI_PREFIX [format [msgcat::mc "Testing %s"] ${subport}]"
}

proc porttest::test_main {args} {
    global subport test.run

    # built-in tests
    porttest::test_archs

    # tests defined by the Portfile
    if {[tbool test.run]} {
        command_exec -callback portprogress::target_progress_callback test
    }
    return 0
}

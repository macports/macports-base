# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide porttest_run 1.0
package require portprogress 1.0
package require machista 1.0

namespace eval porttest {

proc get_file_archs {handle fpath} {
    set resultlist [machista::parse_file $handle $fpath]
    set returncode [lindex $resultlist 0]
    set result     [lindex $resultlist 1]
    if {$returncode != $::machista::SUCCESS} {
        # EMAGIC means not Mach-O (nor an archive of Mach-O objects); ignore
        if {$returncode != $::machista::EMAGIC} {
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

proc test_archs {} {
    if {[option os.platform] ne "darwin" || [option test.ignore_archs]} {
        return
    }
    set handle [machista::create_handle]
    if {$handle eq "NULL"} {
        error "Error creating libmachista handle"
    }
    set file_archs [dict create]
    set destrootlen [string length [option destroot]]

    if {[getuid] == 0 && [geteuid] != 0} {
        # file readable doesn't take euid into account
        elevateToRoot test
        set elevated 1
    }

    fs-traverse -depth fullpath [list [option destpath]] {
        if {[file type $fullpath] ne "file"} {
            continue
        }
        if {![file readable $fullpath]} {
            ui_debug "Skipping unreadable file: $fullpath"
            continue
        }
        if {[fileIsBinary $fullpath]} {
            set archs [get_file_archs $handle $fullpath]
            if {$archs ne ""} {
                # not guaranteed to be listed in canonical order
                dict lappend file_archs [lsort -ascii $archs] [string range $fullpath $destrootlen end]
            }
        }
    }

    if {[info exists elevated]} {
        dropPrivileges
    }

    set wanted_archs [get_canonical_archs]
    set has_wanted_archs [dict exists $file_archs $wanted_archs]
    dict unset file_archs $wanted_archs
    if {[dict size $file_archs] > 0} {
        set msg "[option subport] is configured to build "
        if {$wanted_archs eq "noarch"} {
            append msg "no architecture-specific files,"
        } else {
            append msg "for the architecture(s) '$wanted_archs',"
        }
        append msg " but installed Mach-O files built for the following archs:\n"
        dict for {archs files} $file_archs {
            append msg [join $archs ,]:\n
            foreach f $files {
                append msg "  $f\n"
            }
        }
        ui_warn $msg
    } elseif {$wanted_archs ne "noarch" && !${has_wanted_archs}} {
        ui_warn "[option subport] is configured to build for the architecture(s) '$wanted_archs',\
                    but did not install any Mach-O files."
    }
    machista::destroy_handle $handle
}

proc test_start {args} {
    global UI_PREFIX subport
    ui_notice "$UI_PREFIX [format [msgcat::mc "Testing %s"] ${subport}]"
}

proc test_main {args} {
    global test.run

    # built-in tests
    test_archs

    # tests defined by the Portfile
    if {[tbool test.run]} {
        command_exec -callback portprogress::target_progress_callback test
    }
    return 0
}

}

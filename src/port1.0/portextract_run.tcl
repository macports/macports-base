# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portextract.tcl

package provide portextract_run 1.0

namespace eval portextract {

proc extract_start {args} {
    global UI_PREFIX extract.dir extract.mkdir

    ui_notice "$UI_PREFIX [format [msgcat::mc "Extracting %s"] [option subport]]"

    # create any users and groups needed by the port
    handle_add_users

    # should the distfiles be extracted to worksrcpath instead?
    if {[tbool extract.mkdir]} {
        global worksrcpath
        ui_debug "Extracting to subdirectory worksrcdir"
        file mkdir ${worksrcpath}
        set extract.dir ${worksrcpath}
    }

    variable methods_used
    if {[dict exists $methods_used dmg]} {
        variable dmg_mount [mkdtemp "/tmp/mports.XXXXXXXX"]
    }
}

proc extract_main {args} {
    global UI_PREFIX distpath filespath extract.dir extract.only extract.methods \
           extract.cmd extract.pre_args extract.post_args extract.suffix

    if {![exists distfiles] && ![exists extract.only]} {
        # nothing to do
        return 0
    }

    # extract.{cmd,pre_args,post_args} options are used for distfiles
    # using the method matching extract.suffix. This keeps the
    # behaviour the same as it used to be for the case where all
    # distfiles in extract.only use that method, which was formerly the
    # only supported case.
    # For files with different methods, the args are set up as per the
    # defaults for the method. If custom args are needed in this case,
    # a custom method should be used.
    set main_method [method_for_suffix ${extract.suffix}]
    foreach distfile ${extract.only} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] $distfile]"
        if {[file exists $filespath/$distfile]} {
            option extract.args "'$filespath/$distfile'"
        } else {
            option extract.args "'[file join $distpath $distfile]'"
        }

        if {[dict exists ${extract.methods} $distfile]} {
            set method [dict get ${extract.methods} $distfile]
        } else {
            set method [method_for_suffix $distfile]
        }
        ui_debug "Using extract method: $method"

        if {$method ne $main_method} {
            if {![info exists saved_options]} {
                set saved_options [list ${extract.cmd} ${extract.pre_args} ${extract.post_args}]
            }
            # set up the args for this method
            set extract.cmd [get_extract_cmd $method]
            set extract.pre_args [get_extract_pre_args $method]
            set extract.post_args [get_extract_post_args $method]
        }
        # If the MacPorts user does not have the privileges to mount a
        # DMG then hdiutil will fail with this error:
        #   hdiutil: attach failed - Device not configured
        # So elevate back to root.
        if {$method eq "dmg"} {
            elevateToRoot {extract dmg}
        }

        if {${extract.cmd} ne {}} {
            # built-in method
            set code [catch {command_exec extract} result]
        } else {
            # custom method, call it as a command
            set code [catch {$method [file join $distpath $distfile]} result]
        }

        if {$method eq "dmg"} {
            dropPrivileges
        }
        if {$method ne $main_method} {
            lassign $saved_options extract.cmd extract.pre_args extract.post_args
        }
        if {$code} {
            return -code error "$result"
        }

        chownAsRoot ${extract.dir}
    }

    if {[option extract.rename] && ![file exists [option worksrcpath]]} {
        global workpath distname
        # rename whatever directory exists in $workpath to $distname
        set worksubdirs [glob -nocomplain -types d -directory $workpath *]
        if {[llength $worksubdirs] == 1} {
            set origpath [lindex $worksubdirs 0]
            set newpath [file join $workpath $distname]
            if {$newpath ne $origpath} {
                ui_debug [format [msgcat::mc "extract.rename: Renaming %s -> %s"] [file tail $origpath] $distname]
                move $origpath $newpath
            }
        } elseif {[llength $worksubdirs] == 0} {
            return -code error "extract.rename: no directories exist in $workpath"
        } else {
            return -code error "extract.rename: multiple directories exist in ${workpath}: $worksubdirs"
        }
    }

    return 0
}

}

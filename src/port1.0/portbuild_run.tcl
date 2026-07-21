# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portbuild.tcl

package provide portbuild_run 1.0
package require portutil 1.0
package require portprogress 1.0

namespace eval portbuild {

proc build_start {args} {
    global UI_PREFIX subport

    ui_notice "$UI_PREFIX [format [msgcat::mc "Building %s"] ${subport}]"

    global portconfigure::no_default_compiler_allowed
    if {$no_default_compiler_allowed} {
        ui_warn_once no_default_compiler_allowed "All compilers are either blacklisted or unavailable; defaulting to first fallback option"
    }
}

proc build_main {args} {
    global build.cmd build.jobs_arg

    if {${build.cmd} eq ""} {
        error "No build command found"
    }

    set realcmd ${build.cmd}
    append build.cmd ${build.jobs_arg}
    command_exec -callback portprogress::target_progress_callback build
    set build.cmd ${realcmd}
    return 0
}

}

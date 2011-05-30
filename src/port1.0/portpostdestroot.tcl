# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portpostdestroot.tcl

package provide portpostdestroot 1.0
package require portutil 1.0

set org.macports.postdestroot [target_new org.macports.postdestroot portpostdestroot::postdestroot_main]
target_provides ${org.macports.postdestroot} postdestroot
target_requires ${org.macports.postdestroot} main destroot

namespace eval portpostdestroot {
}

set_ui_prefix

# list all links on a directory recursively
proc portpostdestroot::links_list {dir} {
    set ret {}
    foreach item [glob -nocomplain -type {d l} -directory $dir *] {
        if {[file isdirectory $item]} {
            set ret [concat $ret [links_list $item]]
        } else {
            #is link
            lappend ret $item
        }
    }
    return $ret
}

proc portpostdestroot::postdestroot_symlink_check {} {
    global UI_PREFIX destroot prefix
    ui_notice "$UI_PREFIX Checking for links"
    foreach link [links_list $destroot] {
        set points_to [file link $link]
        if { [string compare [file pathtype $points_to] {absolute}] == 0 } {
            if {[regexp $destroot $points_to]} {
                ui_debug "Absolute link path poiting to inside of destroot"
                return -code error "Absolute link path poiting to inside of destroot"
            } else {
                ui_debug "Absolute link path poiting to outside of destroot"
            }
        } elseif { [string compare [file pathtype $points_to] {relative}] == 0 } {
            regsub $destroot$prefix/ $link "" link_without_destroot
            set dir_depth [regexp -all / $link_without_destroot]
            set return_depth [regsub -all {\.\./} $points_to "" points_to_without_returns]
            set return_delta [expr $return_depth - [regexp -all / $points_to_without_returns]]
            if { $return_delta < $dir_depth } {
                ui_debug "Relative link path poiting to inside of destroot"
            } else {
                ui_debug "Relative link path poiting to outside of destroot"
                return -code error "Relative link path poiting to outside of destroot"
            }
        }
    }
}

proc portpostdestroot::postdestroot_main {args} {
    global UI_PREFIX
    ui_notice "$UI_PREFIX Executing post-destroot phase"
    postdestroot_symlink_check
    return 0
}


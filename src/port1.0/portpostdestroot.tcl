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

proc portpostdestroot::postdestroot_main {args} {
    global UI_PREFIX
    ui_notice "$UI_PREFIX Executing post-destroot phase"
    return 0
}


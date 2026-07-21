# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portpatch_run.tcl

package provide portpatch 1.0

set org.macports.patch [target_new org.macports.patch portpatch::patch_main]
target_provides ${org.macports.patch} patch
target_requires ${org.macports.patch} main fetch checksum extract
target_runpkg ${org.macports.patch} portpatch_run

namespace eval portpatch {
}

# Add command patch
commands patch

options patch.asroot
# Set up defaults
default patch.asroot no
default patch.dir {${worksrcpath}}
default patch.cmd {[portpatch::build_getpatchtype]}
default patch.pre_args {-t -N -p0}

proc portpatch::build_getpatchtype {args} {
    if {![exists patch.type]} {
        return [findBinary patch $::portutil::autoconf::patch_path]
    }
    switch -exact -- [option patch.type] {
        gnu {
            return [findBinary gpatch $::portutil::autoconf::gnupatch_path]
        }
        default {
            ui_warn "[format [msgcat::mc "Unknown patch.type %s, using 'patch'"] [option patch.type]]"
            return [findBinary patch $::portutil::autoconf::patch_path]
        }
    }
}

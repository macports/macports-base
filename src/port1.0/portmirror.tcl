# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portmirror_run.tcl

package provide portmirror 1.0

set org.macports.mirror [target_new org.macports.mirror portmirror::mirror_main]
target_runtype ${org.macports.mirror} always
target_state ${org.macports.mirror} no
target_provides ${org.macports.mirror} mirror
target_requires ${org.macports.mirror} main
target_runpkg ${org.macports.mirror} portmirror_run

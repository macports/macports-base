# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portdmg_run.tcl

package provide portdmg 1.0

set org.macports.dmg [target_new org.macports.dmg portdmg::dmg_main]
target_runtype ${org.macports.dmg} always
target_provides ${org.macports.dmg} dmg
target_requires ${org.macports.dmg} pkg
target_runpkg ${org.macports.dmg} portdmg_run

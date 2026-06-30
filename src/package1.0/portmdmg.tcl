# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portmdmg_run.tcl

package provide portmdmg 1.0

set org.macports.mdmg [target_new org.macports.mdmg portmdmg::mdmg_main]
target_runtype ${org.macports.mdmg} always
target_provides ${org.macports.mdmg} mdmg
target_requires ${org.macports.mdmg} mpkg
target_runpkg ${org.macports.mdmg} portmdmg_run

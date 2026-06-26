# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide portdistfiles 1.0

set org.macports.distfiles [target_new org.macports.distfiles portdistfiles::distfiles_main]
target_runtype ${org.macports.distfiles} always
target_state ${org.macports.distfiles} no
target_provides ${org.macports.distfiles} distfiles
target_requires ${org.macports.distfiles} main
target_prerun ${org.macports.distfiles} portdistfiles::distfiles_start
target_runpkg ${org.macports.distfiles} portdistfiles_run

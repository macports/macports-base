# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portreload_run.tcl

package provide portreload 1.0

set org.macports.reload [target_new org.macports.reload portreload::reload_main]
target_runtype ${org.macports.reload} always
target_state ${org.macports.reload} no
target_provides ${org.macports.reload} reload
target_requires ${org.macports.reload} main
target_runpkg ${org.macports.reload} portreload_run

options reload.asroot

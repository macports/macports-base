# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portdeactivate_run.tcl

# the 'deactivate' target is provided by this package

package provide portdeactivate 1.0

set org.macports.deactivate [target_new org.macports.deactivate portdeactivate::deactivate_main]
target_runtype ${org.macports.deactivate} always
target_state ${org.macports.deactivate} no
target_provides ${org.macports.deactivate} deactivate
target_requires ${org.macports.deactivate} main
target_prerun ${org.macports.deactivate} portdeactivate::deactivate_start
target_runpkg ${org.macports.deactivate} portdeactivate_run

options deactivate.asroot
default deactivate.asroot no

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portuninstall_run.tcl

# the 'uninstall' target is provided by this package

package provide portuninstall 1.0

set org.macports.uninstall [target_new org.macports.uninstall portuninstall::uninstall_main]
target_runtype ${org.macports.uninstall} always
target_state ${org.macports.uninstall} no
target_provides ${org.macports.uninstall} uninstall
target_requires ${org.macports.uninstall} main
target_prerun ${org.macports.uninstall} portuninstall::uninstall_start
target_runpkg ${org.macports.uninstall} portuninstall_run

options uninstall.asroot
default uninstall.asroot no

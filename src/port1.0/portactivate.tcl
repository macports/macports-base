# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# the 'activate' target is provided by this package

package provide portactivate 1.0

set org.macports.activate [target_new org.macports.activate portactivate::activate_main]
target_runtype ${org.macports.activate} always
target_state ${org.macports.activate} no
target_provides ${org.macports.activate} activate
target_requires ${org.macports.activate} main archivefetch fetch checksum extract patch configure build destroot install
target_prerun ${org.macports.activate} portactivate::activate_start
target_postrun ${org.macports.activate} portactivate::activate_finish
target_runpkg ${org.macports.activate} portactivate_run

options activate.asroot
default activate.asroot no

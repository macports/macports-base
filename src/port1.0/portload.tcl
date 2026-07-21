# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portload_run.tcl

package provide portload 1.0

set org.macports.load [target_new org.macports.load portload::load_main]
target_runtype ${org.macports.load} always
target_state ${org.macports.load} no
target_provides ${org.macports.load} load 
target_requires ${org.macports.load} main
target_runpkg ${org.macports.load} portload_run

options load.asroot

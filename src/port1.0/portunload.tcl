# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portunload_run.tcl

package provide portunload 1.0

set org.macports.unload [target_new org.macports.unload portunload::unload_main]
target_runtype ${org.macports.unload} always
target_state ${org.macports.unload} no
target_provides ${org.macports.unload} unload 
target_requires ${org.macports.unload} main
target_runpkg ${org.macports.unload} portunload_run

options unload.asroot

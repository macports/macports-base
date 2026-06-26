# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide portbump 1.0

set org.macports.bump [target_new org.macports.bump portbump::bump_main]
target_provides ${org.macports.bump} bump
target_runtype ${org.macports.bump} always
target_requires ${org.macports.bump} main fetch
target_prerun ${org.macports.bump} portbump::bump_start
target_runpkg ${org.macports.bump} portbump_run

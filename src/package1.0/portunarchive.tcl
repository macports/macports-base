# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portunarchive_run.tcl

package provide portunarchive 1.0

set org.macports.unarchive [target_new org.macports.unarchive portunarchive::unarchive_main]
target_runtype ${org.macports.unarchive} always
target_init ${org.macports.unarchive} portunarchive::unarchive_init
target_provides ${org.macports.unarchive} unarchive
target_requires ${org.macports.unarchive} main archivefetch
target_prerun ${org.macports.unarchive} portunarchive::unarchive_start
target_postrun ${org.macports.unarchive} portunarchive::unarchive_finish
target_runpkg ${org.macports.unarchive} portunarchive_run

# defaults
default unarchive.dir {${destpath}}
default unarchive.env {}
default unarchive.cmd {}
default unarchive.pre_args {}
default unarchive.args {}
default unarchive.post_args {}

default unarchive.type {}
default unarchive.file {}
default unarchive.path {}
default unarchive.skip 0

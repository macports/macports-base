# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# # License: see portarchive_run.tcl

package provide portarchive 1.0

set org.macports.archive [target_new org.macports.archive portarchive::archive_main]
target_provides ${org.macports.archive} archive
target_runtype ${org.macports.archive} always
target_state ${org.macports.archive} no
target_requires ${org.macports.archive} main archivefetch fetch checksum extract patch configure build destroot install
target_runpkg ${org.macports.archive} portarchive_run

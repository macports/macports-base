# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portmpkg_run.tcl

package provide portmpkg 1.0

set org.macports.mpkg [target_new org.macports.mpkg portmpkg::mpkg_main]
target_runtype ${org.macports.mpkg} always
target_provides ${org.macports.mpkg} mpkg
target_requires ${org.macports.mpkg} pkg
target_runpkg ${org.macports.mpkg} portmpkg_run

# define options
options package.destpath package.flat

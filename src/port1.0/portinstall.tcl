# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portinstall_run.tcl

package provide portinstall 1.0

set org.macports.install [target_new org.macports.install portinstall::install_main]
target_provides ${org.macports.install} install
target_runtype ${org.macports.install} always
target_requires ${org.macports.install} main archivefetch fetch checksum extract patch configure build destroot
target_prerun ${org.macports.install} portinstall::install_start
target_runpkg ${org.macports.install} portinstall_run

# define options
options install.asroot

# Set defaults
default install.asroot no

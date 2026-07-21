# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portpkg_run.tcl

package provide portpkg 1.0

set org.macports.pkg [target_new org.macports.pkg portpkg::pkg_main]
target_runtype ${org.macports.pkg} always
target_provides ${org.macports.pkg} pkg
target_requires ${org.macports.pkg} archivefetch unarchive destroot
target_prerun ${org.macports.pkg} portpkg::pkg_start
target_runpkg ${org.macports.pkg} portpkg_run

# define options
options package.type package.destpath package.flat package.resources \
        package.scripts pkg.asroot

# Set defaults
default package.destpath {${workpath}}
default package.resources {${workpath}/pkg_resources}
default package.scripts  {${workpath}/pkg_scripts}
# Need productbuild to make flat packages really work
default package.flat     {[expr {[vercmp $macosx_deployment_target 10.6] >= 0}]}
default pkg.asroot no

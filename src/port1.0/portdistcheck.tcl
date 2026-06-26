# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

package provide portdistcheck 1.0

set org.macports.distcheck [target_new org.macports.distcheck portdistcheck::distcheck_main]
target_runtype ${org.macports.distcheck} always
target_state ${org.macports.distcheck} no
target_provides ${org.macports.distcheck} distcheck
target_requires ${org.macports.distcheck} main
target_runpkg ${org.macports.distcheck} portdistcheck_run

# define options
options distcheck.type

# defaults
default distcheck.type moddate

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4

# License: see portdestroot_run.tcl

package provide portdestroot 1.0

set org.macports.destroot [target_new org.macports.destroot portdestroot::destroot_main]
target_provides ${org.macports.destroot} destroot
target_requires ${org.macports.destroot} main fetch checksum extract patch configure build
target_prerun ${org.macports.destroot} portdestroot::destroot_start
target_postrun ${org.macports.destroot} portdestroot::destroot_finish
target_runpkg ${org.macports.destroot} portdestroot_run

# define options
options destroot.target destroot.destdir destroot.clean destroot.keepdirs destroot.umask \
        destroot.violate_mtree destroot.asroot destroot.delete_la_files
commands destroot

# Set defaults
default destroot.asroot no
default destroot.dir {${build.dir}}
default destroot.cmd {${build.cmd}}
default destroot.pre_args {[portdestroot::destroot_getargs]}
default destroot.target install
default destroot.post_args {${destroot.destdir}}
default destroot.destdir {DESTDIR=${destroot}}
default destroot.nice {${buildnicevalue}}
default destroot.umask {$system_options(destroot_umask)}
default destroot.clean no
default destroot.keepdirs {}
default destroot.violate_mtree no
default destroot.delete_la_files {${delete_la_files}}

namespace eval portdestroot {
proc destroot_getargs {args} {
    global build.type os.platform destroot.cmd destroot.target
    if {((${build.type} eq "default" && ${os.platform} ne "freebsd") ||
         (${build.type} eq "gnu"))
        && [regexp "^(/\\S+/|)(g|gnu|)make(\\s+.*|)$" ${destroot.cmd}]} {
        # Print "Entering directory" lines for better log debugging
        return "-w ${destroot.target}"
    }

    return ${destroot.target}
}
}

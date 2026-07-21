# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# License: see portlivecheck_run.tcl

package provide portlivecheck 1.0

set org.macports.livecheck [target_new org.macports.livecheck portlivecheck::livecheck_main]
target_runtype ${org.macports.livecheck} always
target_state ${org.macports.livecheck} no
target_provides ${org.macports.livecheck} livecheck
target_requires ${org.macports.livecheck} main
target_runpkg ${org.macports.livecheck} portlivecheck_run

# define options
options livecheck.url livecheck.type livecheck.md5 livecheck.regex \
        livecheck.branch livecheck.name livecheck.distname livecheck.version \
        livecheck.ignore_sslcert livecheck.compression livecheck.curloptions \
        livecheck.user_agent

# defaults
default livecheck.url {$homepage}
default livecheck.type default
default livecheck.md5 {}
default livecheck.regex {}
default livecheck.branch {}
default livecheck.name default
default livecheck.distname default
default livecheck.version {$version}
default livecheck.ignore_sslcert no
default livecheck.compression yes
default livecheck.curloptions [list --append-http-header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]
default livecheck.user_agent {}

namespace eval portlivecheck {
    proc livecheck_async_start {} {
        global org.macports.livecheck
        portutil::target_load ${org.macports.livecheck}
        _livecheck_main yes
    }

    proc _async_cleanup {} {
        variable async_job
        if {[info exists async_job]} {
            curlwrap_async_cancel $async_job
            unset async_job
        }
        variable tempfilename
        if {[info exists tempfilename]} {
            file delete $tempfilename
            unset tempfilename
        }
    }
}

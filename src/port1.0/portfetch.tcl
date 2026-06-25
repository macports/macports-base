# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2004 - 2014, 2016-2018 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portfetch 1.0
package require portextract 1.0
package require portutil 1.0

set org.macports.fetch [target_new org.macports.fetch portfetch::fetch_main]
target_init ${org.macports.fetch} portfetch::fetch_init
target_provides ${org.macports.fetch} fetch
target_requires ${org.macports.fetch} main
target_prerun ${org.macports.fetch} portfetch::fetch_start
target_runpkg ${org.macports.fetch} portfetch_run

namespace eval portfetch {
    variable fetch_urls {}
}

# define options: distname master_sites
options master_sites patch_sites distfiles patchfiles \
    dist_subdir \
    fetch.type fetch.user fetch.password fetch.use_epsv fetch.ignore_sslcert \
    fetch.user_agent master_sites.mirror_subdir patch_sites.mirror_subdir \
    bzr.url bzr.revision \
    cvs.module cvs.root cvs.password cvs.date cvs.tag cvs.method \
    svn.url svn.revision svn.method \
    git.cmd git.url git.branch \
    hg.cmd hg.url hg.tag

# XXX we use the command framework to buy us some useful features,
# but this is not a user-modifiable command
commands bzr
commands cvs
commands svn

# Defaults
default fetch.type standard

default bzr.cmd {[findBinary bzr $::portutil::autoconf::bzr_path]}
default bzr.dir {${workpath}}
default bzr.revision -1
default bzr.pre_args {--builtin --no-aliases checkout --lightweight --verbose}
default bzr.args {}
default bzr.post_args {-r ${bzr.revision} ${bzr.url} ${worksrcdir}}

default cvs.cmd {[findBinary cvs $::portutil::autoconf::cvs_path]}
default cvs.password {}
default cvs.dir {${workpath}}
default cvs.method export
default cvs.module {$distname}
default cvs.tag {}
default cvs.date {}
default cvs.env {CVS_PASSFILE=${workpath}/.cvspass}
default cvs.pre_args {-z9 -f -d ${cvs.root}}
default cvs.args {}
default cvs.post_args {${cvs.module}}

default svn.cmd {${prefix_frozen}/bin/svn}
default svn.dir {${workpath}}
default svn.method export
default svn.revision {}
default svn.env {}
default svn.pre_args --non-interactive
default svn.args {}
default svn.post_args {}

default git.cmd {[portfetch::find_git_path]}
default git.dir {${workpath}}
default git.branch {}

default hg.cmd {[findBinary hg $::portutil::autoconf::hg_path]}
default hg.dir {${workpath}}
default hg.tag tip

# Set distfiles
default distfiles {[list [join $distname][join ${extract.suffix}]]}
default dist_subdir {${name}}

# user name & password
default fetch.user {}
default fetch.password {}
# Use EPSV for FTP transfers
default fetch.use_epsv yes
# Ignore SSL certificate
default fetch.ignore_sslcert no
# Use remote timestamps
default fetch.remote_time no
default fetch.user_agent {}

default global_mirror_site macports_distfiles
default mirror_sites.listfile mirror_sites.tcl
default mirror_sites.listpath port1.0/fetch

# Option-executed procedures

option_proc fetch.type portfetch::set_fetch_type

proc portfetch::set_fetch_type {option action args} {
    global os.platform os.major
    if {[string equal ${action} "set"]} {
        if {$args ne "standard"} {
            distfiles
        }
        switch $args {
            bzr {
                depends_fetch-append bin:bzr:bzr
            }
            cvs {
                depends_fetch-append bin:cvs:cvs
            }
            svn {
                depends_fetch-append path:bin/svn:subversion
            }
            git {
                # Oldest macOS version whose git can validate GitHub's SSL certificate.
                if {${os.major} >= 14 || ${os.platform} ne "darwin"} {
                    depends_fetch-append bin:git:git
                } else {
                    depends_fetch-append path:bin/git:git
                }
            }
            hg {
                depends_fetch-append bin:hg:mercurial
            }
        }
    }
}

proc portfetch::find_git_path {args} {
    global prefix_frozen os.platform os.major
    # Oldest macOS version whose git can validate GitHub's SSL certificate.
    if {${os.major} >= 14 || ${os.platform} ne "darwin"} {
        return [findBinary git $::portutil::autoconf::git_path]
    } else {
        return ${prefix_frozen}/bin/git
    }
}

proc portfetch::fetch_async_start {logid} {
    global org.macports.fetch
    portutil::target_load ${org.macports.fetch}
    _fetch_async_start $logid
}

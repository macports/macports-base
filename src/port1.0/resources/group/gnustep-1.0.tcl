# et:ts=4
# gnustep.tcl
#
# $Id$
#
# Copyright (c) 2006 Yves de Champlain <yves@macports.org>,
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Group code for GNUstep ports.

#
# Overview of gnustep 1.0 PortGroup
#
# default categories            gnustep
# default homepage              http://www.gnustep.org/
# default master_sites          gnustep:core
#
# array set gnustep.post_flags  Apple CC two-level namespaces requires all 
#                               symbols to be resolved at link time, 
#                               so most of the patches are just that.
#                               Setting the gnustep.post_flags array makes this
#                               simple beyond common understanding !
#                               ex: 
#                               platform darwin {
#                                   array set gnustep.post_flags {
#                                       BundleSubDir  "-lfoo -lbar"
#                                   }
#                               }
#                                
# default use_configure         no
# default configure.args        CC=gcc-mp-4.1
#
# default build.type            gnu
# default build.args            messages=yes
#
# default gnustep.domain        As provided by the current package or Local
# default destroot.args         messages=yes
# default destroot.destdir      GNUSTEP_INSTALLATION_DIR=${destroot}${prefix}/GNUstep/$gnustep.domain
# variant with_docs             GNUstep programs providing documentation should
#                               all follow the same pattern
#


# Options this group provides :

options gnustep.domain
default gnustep.domain      ""

# Default values for this group :

default categories			gnustep
default homepage            http://www.gnustep.org/

default master_sites        gnustep:core
default depends_build       port:gnustep-make
default depends_lib         port:gnustep-back

default use_configure		no
default configure.args      CC=gcc-mp-4.1

default build.type          gnu
default build.args          messages=yes

default destroot.args       messages=yes


# for Darwin's linker

array set gnustep.post_flags {}
post-patch {
    foreach {src_subdir post_libs} [array get gnustep.post_flags] {
        set fl [ open ${worksrcpath}/$src_subdir/GNUmakefile.preamble a ]
        puts $fl "\nSHARED_LD_POSTFLAGS += $post_libs"
        close $fl
    }
}

# try to guess installation directory if not specified in the Portfile
# defaults to Local

proc set_gnustep_domain {} {
    global gnustep.domain worksrcpath
    
    if {${gnustep.domain} == ""} {
        set gnustep.domain Local
        ui_debug "No gnustep.domain provided"
        if {[file exists $worksrcpath/GNUmakefile]} {
            set root_makefile "GNUmakefile"
        } elseif {[file exists $worksrcpath/GNUmakefile.in]} {
            set root_makefile "GNUmakefile.in"
        } else {
            ui_debug "no GNUmakefile ? ... hum !"
            return 1
        }
        ui_debug "Checking installation directory in $worksrcpath/$root_makefile"
        set fl [open "| grep \"^GNUSTEP_INSTALLATION_DIR = \" $worksrcpath/$root_makefile"]
        set data [read $fl]
        if {! [catch {close $fl} err] && [regexp SYSTEM $data]} {
            ui_debug "Data read : $data"
            set gnustep.domain System
        } else {
            ui_debug "$err"
        }
    }
    ui_debug "Using ${gnustep.domain}"
}


# GNUstep stages commands

configure {
    if { ${use_configure} == "yes" } {
        cd ${worksrcpath}
        ui_debug "./configure ${configure.pre_args} ${configure.args}"
        system "\
            . ${prefix}/GNUstep/System/Library/Makefiles/GNUstep.sh \
            && \
            ./configure ${configure.pre_args} ${configure.args}"
    }
}
    
build {
    cd ${worksrcpath}
    ui_debug "${build.cmd} ${build.target} ${build.args}"
    system "\
        . ${prefix}/GNUstep/System/Library/Makefiles/GNUstep.sh \
        && \
        ${build.cmd} ${build.target} ${build.args}"
}

destroot {
    set_gnustep_domain
    set destroot.destdir \
        GNUSTEP_INSTALLATION_DIR=${destroot}${prefix}/GNUstep/${gnustep.domain}
    cd ${worksrcpath}
    ui_debug "${destroot.cmd} ${destroot.target} \
            ${destroot.args} ${destroot.destdir}"
    system "\
        . ${prefix}/GNUstep/System/Library/Makefiles/GNUstep.sh \
        && \
        ${destroot.cmd} ${destroot.target} \
            ${destroot.args} ${destroot.destdir}"
}

# To build and install documentation provided by the port

variant with_docs {
    depends_build-append \
       bin:latex2html:latex2html \
        bin:texi2pdf:texinfo \
        bin:texi2html:texi2html \
        bin:pdftex:teTeX \
        port:gnustep-base
    post-destroot {
        if {[file exists ${worksrcpath}/Documentation/GNUmakefile]} {
            ui_msg "--->  Making Documentation for ${name}"
            cd ${worksrcpath}/Documentation
            system "\
                . ${prefix}/GNUstep/System/Library/Makefiles/GNUstep.sh \
                && \
                ${destroot.cmd} ${destroot.target} \
                    ${destroot.args} ${destroot.destdir}"
            set info_dir \
                ${destroot}${prefix}/GNUstep/System/Library/Documentation/info
            if {[file exists ${info_dir}/manual.info]} {
                set manual_name [regsub {gnustep-} ${name} ""]
                file rename ${info_dir}/manual.info \
                    ${info_dir}/${manual_name}-manual.info
            }
        } else {
            ui_msg "--->  No Documentation for ${name}"
        }
    }    
}

                    
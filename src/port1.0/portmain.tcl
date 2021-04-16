# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portmain.tcl
#
# Copyright (c) 2004-2005, 2007-2018 The MacPorts Project
# Copyright (c) 2002-2003 Apple Inc.
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

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portmain 1.0
package require portutil 1.0

set org.macports.main [target_new org.macports.main portmain::main]
target_provides ${org.macports.main} main
target_state ${org.macports.main} no

namespace eval portmain {
}

set_ui_prefix

# define options
options prefix name version revision epoch categories maintainers \
        long_description description homepage notes license \
        provides conflicts replaced_by known_fail \
        worksrcdir filesdir distname portdbpath libpath distpath sources_conf \
        os.platform os.subplatform os.version os.major os.minor os.arch os.endian \
        platforms default_variants install.user install.group \
        macosx_deployment_target universal_variant os.universal_supported \
        universal_possible \
        supported_archs depends_skip_archcheck installs_libs \
        license_noconflict copy_log_files \
        compiler.cpath compiler.library_path compiler.log_verbose_output \
        compiler.limit_flags \
        compiler.support_environment_paths \
        compiler.support_environment_sdkroot \
        add_users use_xcode

proc portmain::check_option_integer {option action args} {
    if {$action eq "set" && ![string is wideinteger -strict $args]} {
        return -code error "$option must be an integer"
    }
}

# Order of option_proc and option_export matters. Filter before exporting.

# Assign option procedure to default_variants
option_proc default_variants handle_default_variants
# Handle notes special for better formatting
option_proc notes handle_option_string
# Ensure that revision and epoch are integers
option_proc epoch portmain::check_option_integer
option_proc revision portmain::check_option_integer

# Export options via PortInfo
options_export name version revision epoch categories maintainers \
               platforms description long_description notes homepage \
               license provides conflicts replaced_by installs_libs \
               license_noconflict patchfiles known_fail

default subport {[portmain::get_default_subport]}
proc portmain::get_default_subport {} {
    global name portpath
    if {[info exists name]} {
        return $name
    }
    return [file tail $portpath]
}
default subbuildpath {[portmain::get_subbuildpath]}
proc portmain::get_subbuildpath {} {
    global portpath portbuildpath subport
    if {$subport ne ""} {
        set subdir $subport
    } else {
        set subdir [file tail $portpath]
    }
    return [file normalize [file join $portbuildpath $subdir]]
}
default workpath {[getportworkpath_from_buildpath $subbuildpath]}
default prefix /opt/local
default applications_dir /Applications/MacPorts
default frameworks_dir {${prefix}/Library/Frameworks}
default destdir destroot
default destpath {${workpath}/${destdir}}
# destroot is provided as a clearer name for the "destpath" variable
default destroot {${destpath}}
default filesdir files
default revision 0
default epoch 0
default license unknown
default distname {${name}-${version}}
default worksrcdir {$distname}
default filespath {[file join $portpath [join $filesdir]]}
default worksrcpath {[file join $workpath [join $worksrcdir]]}
# empty list means all archs are supported
default supported_archs {}
default depends_skip_archcheck {}
default add_users {}

# Configure settings
default install.user {${portutil::autoconf::install_user}}
default install.group {${portutil::autoconf::install_group}}

# Platform Settings
default platforms darwin
default os.platform {$os_platform}
default os.subplatform {$os_subplatform}
default os.version {$os_version}
default os.major {$os_major}
default os.minor {$os_minor}
default os.arch {$os_arch}
default os.endian {$os_endian}

set macos_version_text {}
if {[option os.platform] eq "darwin"} {
    set macos_version_text "(macOS ${macos_version}) "
}
ui_debug "OS [option os.platform]/[option os.version] ${macos_version_text}arch [option os.arch]"

default universal_variant {${use_configure}}

if {[option os.platform] eq "darwin" && [option os.subplatform] eq "macosx"} {
    # we're on macOS and can therefore build universal
    default os.universal_supported yes
} else {
    default os.universal_supported no
}

default universal_possible {[expr {${os.universal_supported} && [llength ${configure.universal_archs}] >= 2}]}

default compiler.cpath {${prefix}/include}
default compiler.library_path {${prefix}/lib}
default compiler.log_verbose_output yes
default compiler.limit_flags no
default compiler.support_environment_paths no
default compiler.support_environment_sdkroot no

# Record initial euid/egid
set euid [geteuid]
set egid [getegid]

default worksymlink {[file normalize [file join $portpath work]]}
default distpath {[file normalize [file join $portdbpath distfiles ${dist_subdir}]]}

default use_xcode {[expr {[option build.type] eq "xcode" || !([file exists /usr/lib/libxcselect.dylib] || [option os.major] >= 20) || ![file executable /Library/Developer/CommandLineTools/usr/bin/make]}]}

proc portmain::main {args} {
    return 0
}

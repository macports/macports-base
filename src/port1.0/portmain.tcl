# et:ts=4
# portmain.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

set com.apple.main [target_new com.apple.main main]
target_provides ${com.apple.main} main

# define options
options prefix name version revision epoch categories maintainers
options long_description description homepage
options workdir worksrcdir filesdir distname portdbpath libpath distpath sources_conf os.platform os.version os.arch os.endian platforms default_variants install.user install.group

# Export options via PortInfo
options_export name version revision epoch categories maintainers platforms description long_description homepage

# Assign option procedure to default_variants
option_proc default_variants handle_default_variants

# Hard coded version number for resource location
default portresourcepath {[file join $portsharepath resources/port1.0]}
default distpath {[file join $portdbpath distfiles]}
default workdir work
default workpath {[file join $portbuildpath $workdir]}
default worksymlink {[file join $portpath $workdir]}
default prefix /opt/local
default x11prefix /usr/X11R6
default destdir destroot
default destpath {${workpath}/${destdir}}
# destroot is provided as a clearer name for the "destpath" variable
default destroot {${destpath}}
default filesdir files
default revision 0
default epoch 0
default distname {${portname}-${portversion}}
default worksrcdir {$distname}
default filespath {[file join $portpath $filesdir]}
default worksrcpath {[file join $workpath $worksrcdir]}

# Configure settings
default install.user {${portutil::autoconf::install_user}}
default install.group {${portutil::autoconf::install_group}}

# Compatibility namespace
default portname {$name}
default portversion {$version}
default portrevision {$revision}
default portepoch {$epoch}

# Platform Settings
set os_arch $tcl_platform(machine)
if {$os_arch == "Power Macintosh"} { set os_arch "powerpc" }

default os.platform {[string tolower $tcl_platform(os)]}
default os.version {$tcl_platform(osVersion)}
default os.arch {$os_arch}
# Remove trailing "Endian"
default os.endian {[string range $tcl_platform(byteOrder) 0 end-6]}

# Select implicit variants
if {[info exists os.platform] && ![info exists variations(${os.platform})]} { variant_set ${os.platform}}
if {[info exists os.arch] && ![info exists variations(${os.arch})]} { variant_set ${os.arch} }
if {[info exists os.platform] && (${os.platform} == "darwin") && ![file isdirectory /System/Library/Frameworks/Carbon.framework] && ![info exists variations(puredarwin)]} { variant_set puredarwin }
if {[info exists os.platform] && (${os.platform} == "darwin") && [file isdirectory /System/Library/Frameworks/Carbon.framework] && ![info exists variations(macosx)]} {
	variant_set macosx
	# Declare default universal variant, on >10.3
	variant universal {
		if {[tbool use_xmkmf] || ![tbool use_configure]} {
			return -code error "Default universal variant only works with ports based on configure"
		}
		configure.args-append ${configure.universal_args}
		if {![file exists /Developer/SDKs/MacOSX10.4u.sdk/]} {
			return -code error "MacOS X 10.4 universal SDK is not installed (are we running on 10.3? did you forget to install it?) and building with +universal will very likely fail"
		}
		configure.cflags-append ${configure.universal_cflags}
		configure.cppflags-append ${configure.universal_cppflags}
		configure.cxxflags-append ${configure.universal_cxxflags}
		configure.ldflags-append ${configure.universal_ldflags}
	}

	# This is not a standard option, because we need to take an action when it's
	# set, in order to alter the PortInfo structure in time.
	proc universal_variant {state} {
		if {${state} == "no"} {
			variant_undef universal
		}
	}
}

proc main {args} {
    return 0
}

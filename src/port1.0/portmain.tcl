# ex:ts=4
# portmain.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

register com.apple.main target main
register com.apple.main provides main

# define options
options prefix portname portversion portrevision categories maintainers workdir worksrcdir filedir distname portdbpath libpath distpath sources_conf os.name os.version os.arch os.endian architectures
# Export options via PortInfo
options_export portname portversion portrevision categories maintainers architectures

global os_name os_arch os_endian

set os_name [string tolower $tcl_platform(os)]

set os_arch $tcl_platform(machine)
if {$os_arch == "Power Macintosh"} { set os_arch "powerpc" }

set os_endian $tcl_platform(byteOrder)
# Remove trailing "Endian"
set os_endian [string range $os_endian 0 [expr [string length $os_endian] - 7]]

default distpath {[file join $portdbpath distfiles]}
default workdir work
default workpath {[file join $portpath $workdir]}
default prefix /opt/local
default filedir files
default portrevision 0
default os.name {$os_name}
default os.version {$tcl_platform(osVersion)}
default os.arch {$os_arch}
default os.endian {$os_endian}
default distname {${portname}-${portversion}}
default worksrcdir {$distname}
default filesdir {files}
default filespath {[file join $portpath $filesdir]}
default worksrcpath {[file join $workpath $worksrcdir]}

# Select implicit variants
global variations
if {![info exists variations($os_name)]} { variant_set $os_name }
if {![info exists variations($os_arch)]} { variant_set $os_arch }

proc main {args} {
    return 0
}

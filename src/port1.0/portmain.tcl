# et:ts=4
# portmain.tcl
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

PortTarget 1.0

name		org.opendarwin.main
provides	main
runtype		always

# define options
options prefix name version revision categories maintainers
options long_description description homepage
options workdir worksrcdir filedir distname portdbpath libpath distpath sources_conf os.platform os.version os.arch os.endian platforms default_variants
options depends_lib depends_run depends_build

# Export options via PortInfo
options_export name version revision categories maintainers platforms description long_description homepage

# Assign option procedure to default_variants
option_proc default_variants handle_default_variants
options_export depends_build depends_lib depends_run

# Hard coded version number for resource location
default portresourcepath {[file join [option portsharepath] resources/port1.0]}
default distpath {[file join [option portdbpath] distfiles]}
default workdir work
default workpath {[file join [option portpath] [option workdir]]}
default prefix /opt/local
default x11prefix /usr/X11R6
default destdir destroot
default destpath {[option workpath]/[option destdir]}
# destroot is provided as a clearer name for the "destpath" variable
default destroot {[option destpath]}
default filedir files
default revision 0
default distname {[option portname]-[option portversion]}
default worksrcdir {[option distname]}
default filesdir {files}
default filespath {[file join [option portpath] [option filesdir]]}
default worksrcpath {[file join [option workpath] [option worksrcdir]]}

# Compatibility namespace
default portname {[option name]}
default portversion {[option version]}
default portrevision {[option revision]}

# Platform Settings
set os_arch $tcl_platform(machine)
if {$os_arch == "Power Macintosh"} { set os_arch "powerpc" }

default os.platform {[string tolower $tcl_platform(os)]}
default os.version {$tcl_platform(osVersion)}
default os.arch {$os_arch}
# Remove trailing "Endian"
default os.endian {[string range $tcl_platform(byteOrder) 0 [expr [string length $tcl_platform(byteOrder)] - 7]]}


# Select implicit variants
if {[info exists os.platform] && ![info exists variations([option os.platform])]} { variant_set [option os.platform]}
if {[info exists os.arch] && ![info exists variations([option os.arch])]} { variant_set [option os.arch] }

proc main {args} {
    return 0
}

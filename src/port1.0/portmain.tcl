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

register com.apple.main target main main_init
register com.apple.main provides main

# define options
options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir distname sysportpath libpath distpath

# XXX Special case sysportpath. This variable is set by the bootstrap
# and may not exist
if [info exists sysportpath] {
	default distpath "$sysportpath/distfiles"
}
default workdir work

if [info exists portpath] {
    default workpath "$portpath/$workdir"
}

default prefix /usr/local/
default filedir files
default portrevision 0
default os_arch $tcl_platform(machine)
default os_version $tcl_platform(osVersion)

proc main_init {args} {
    global worksrcdir dist_subdir distpath distname
    if {[tbool no_worksubdir]} {
	default worksrcdir ""
    } else {
	if {[info exists distname]} {
		default worksrcdir $distname
	}
    }
}

proc main {args} {

    return 0
}

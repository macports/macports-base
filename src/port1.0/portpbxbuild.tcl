# et:ts=4
# portpbxbuild.tcl
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

PortTarget 1.0

name			org.opendarwin.gnumake
version			1.0
maintainers		kevin@opendarwin.org
description		Builds sources using gnumake
requires		configure
provides		pbxbuild

# define options
options build.target.all build.target
commands build
# defaults
default build.dir {[option workpath]/[option worksrcdir]}
default build.pre_args {[option build.target]}
option_deprecate build.target.all build.target
default build.target "all"



proc set_defaults {args} {
	# If this gets called then somebody said "use bsdmake"
	global use_pbxbuild
	set use_pbxbuild yes

	default build.cmd {pbxbuild}
}

set UI_PREFIX "---> "

proc main {args} {
    global UI_PREFIX use_pbxbuild

	if {![info exists use_pbxbuild] || $use_pbxbuild != "yes"} {
		# We were not called upon.
		return 1
	}

    ui_msg "$UI_PREFIX [format [msgcat::mc "Building %s with pbxbuild"] [option portname]]"

	if {[catch {system "[command build]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] pbxbuild $result]"
	}
	
    return 0
}

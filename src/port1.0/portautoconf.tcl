# et:ts=4
# portautoconf.tcl
#
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
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

name			org.opendarwin.autoconf
#version		1.0
maintainers		kevin@opendarwin.org
description		Prepare sources for building using autoconf
requires		patch
provides		autoconf

commands autoconf

proc set_defaults {args} {
	# If this gets called then somebody said "use autoconf"
	global use_autoconf
	set use_autoconf yes
	
	default autoconf.dir {[option worksrcpath]}
}

set UI_PREFIX "---> "

proc main {args} {
    global UI_PREFIX use_autoconf

	if {![info exists use_autoconf] || $use_autoconf != "yes"} {
		# We were not called upon.
		return 1
	}

	#if {[glob -directory [option automake.dir] *.ac] == {}} {
	#	# Don't appear to be any autoconf files.
	#	return 1
	#}

    ui_msg "$UI_PREFIX [format [msgcat::mc "Configuring %s with autoconf"] [option portname]]"

	if {[catch {system "[command autoconf]"} result]} {
	    return -code error "[format [msgcat::mc "%s failure: %s"] autoconf $result]"
	}

    return 0
}

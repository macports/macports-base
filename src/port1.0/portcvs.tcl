# et:ts=4
# portcvs.tcl
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

name			org.opendarwin.download.cvs
#version		1.0
maintainers		kevin@opendarwin.org
description		Download files using cvs(1)
runtype			always
provides		download cvs
#uses			distcache

set UI_PREFIX "---> "

#default cvs.cmd cvs
#default cvs.password ""
#default cvs.dir {[option workpath]}
#default cvs.module {[option distname]}
#default cvs.tag HEAD
#default cvs.env {CVS_PASSFILE=[option workpath]/.cvspass}
#default cvs.pre_args {"-d [option cvs.root]"}


proc main {args} {
	global UI_PREFIX
	
	# The distpath should have already been set up by the distfiles target
	# We will be called with a valid list of master_sites, but only one
	# file in the distfile, as the distfiles target has set up.
	# It is our duty to attempt to use wget(1) to download this file from
	# one of the master sites into the distpath.

	set distpath [option distpath]
	set master_sites [option master_sites]
	set distfile [option distfile]
	
	# XXX: needs to be implemented
	return 1
	
	# We should probably operate on urls of cvs://CVSROOT ?
	# then we can check out various modules from various roots?
	
	foreach site $master_sites {
		ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to checkout %s from %s"] $distfile $site]"
		global workpath cvs.password cvs.args cvs.post_args cvs.tag cvs.module cvs.cmd cvs.env
		cd [option workpath]
		set cvs.args login
		set cvs.cmd "echo ${cvs.password} | /usr/bin/env ${cvs.env} cvs"
		if {[catch {system "[command cvs] 2>&1"} result]} {
			return -code error [msgcat::mc "CVS login failed"]
		}
		set cvs.args "co -r ${cvs.tag}"
		set cvs.cmd cvs
		set cvs.post_args "${cvs.module}"
		if {[catch {system "[command cvs] 2>&1"} result]} {
			return -code error [msgcat::mc "CVS check out failed"]
		}
	}
}

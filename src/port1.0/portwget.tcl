# et:ts=4
# portwget.tcl
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

name			org.opendarwin.download.wget
#version		1.0
maintainers		kevin@opendarwin.org
description		Download files using wget(1)
runtype			always
provides		download wget
uses			distcache

set UI_PREFIX "---> "

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
	
	foreach site $master_sites {
		ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to download %s from %s"] $distfile $site]"
		if {![catch {system "wget -O \"${distpath}/${distfile}.TMP\" \"${site}${distfile}\""} result] &&
			![catch {system "mv ${distpath}/${distfile}.TMP ${distpath}/${distfile}"}]} {
			# success
			# remove the temporary file
			exec rm -f "${distpath}/${distfile}.TMP"
			return 0
		} else {
			# an error occurred
			# some errors we fail silently, others we print a message, this is really up to
			# our discretion as to whether we think someone else will be able to recover.
			set url "${site}${distfile}"
			global errorCode
			switch -exact [lindex $errorCode 2] {
				1 { 
					# tcsh, zsh return 1 if wget(1) isn't found
					# unfortunately for us, no wget(1) and an error from wget(1)
					# mean different things, and we'll spin a little while...
					continue
				}
				127 {
					# bash returns 127 if curl(1) isn't found
					return 1
				}
				default { set err [format [msgcat::mc "An error occurred: %s"] "${url}"] }
			}
		}
	}

	if {[info exists err]} {
		return -code error $err
	} else {
		return 1
	}
}

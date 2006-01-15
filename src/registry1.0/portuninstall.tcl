# et:ts=4
# portuninstall.tcl
# $Id: portuninstall.tcl,v 1.13.6.3 2006/01/15 18:51:44 olegb Exp $
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

package provide portuninstall 1.0

package require registry 1.0

set UI_PREFIX "---> "

namespace eval portuninstall {

proc uninstall {portname {v ""} optionslist} {
	global uninstall.force uninstall.nochecksum UI_PREFIX
	array set options $optionslist

	set ilist [registry::installed $portname $v]

	set version [lindex [lindex $ilist 0] 1]
	set revision [lindex [lindex $ilist 0] 2]
	set variants [lindex [lindex $ilist 0] 3]

	# determine if it's the only installed port with that name or not.
	if {$v == ""} {
		set nb_versions_installed 1
	} else {
		set ilist [registry::installed $portname ""]
		set nb_versions_installed [llength $ilist]
	}

	# If global forcing is on, make it the same as a local force flag.
	if {[info exists options(ports_force)] && [string equal -nocase $options(ports_force) "yes"] } {
		set uninstall.force "yes"
	}

	# XXX Check if we have dependents XXX

	ui_msg "$UI_PREFIX [format [msgcat::mc "Removing package: %s-%s-%s"] ${portname} ${version} ${revision}]"
	if { $version eq "" } {
		if { [catch {set res [exec "rpm" "-ev" "$portname"]}] == 1 } {
			return 0
		} else {
			return 1
		}
	} else {
		if { [catch {set res [exec "rpm" "-ev" "$portname-$version-$revision"]}] == 1} {
			return 0
		} else {
			return 1
		}
	}

}

# End of portuninstall namespace
}

# et:ts=4
# portuninstall.tcl
# $Id: portuninstall.tcl,v 1.13.6.10 2006/02/21 19:47:28 olegb Exp $
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

	set time [clock format [clock seconds]]
	ui_msg "::${time}:: uninstall start."

	set portname [string map {- _} $portname]
	set ilist [registry::installed $portname]
	if { $ilist == {} } {
		ui_msg "No such port: $portname installed"
		return 1
	}

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
	} else {
		set uninstall.force "no"
	}

	# Check if we have dependents 
	set deps [registry::list_dependents $portname ]
	if { $deps != {} } {
		if {${uninstall.force} != "yes"} {
			ui_msg "${portname} has dependents, not uninstalling!"
			return 1
		}

		ui_debug "Forcing uninstall despite ${portname} has dependents."
	}
	
	set rpmcmd {}
	if { ${uninstall.force} == "yes"} {
		set rpmcmd "rpm -ev --nodeps $portname-$version-$revision"
	} else {
		set rpmcmd "rpm -ev $portname-$version-$revision"
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Removing package: %s-%s-%s"] ${portname} ${version} ${revision}]"
	if { [catch {system "${rpmcmd}"}] == 1} {
		set time [clock format [clock seconds]]
		ui_msg "::${time}:: uninstall end."
		return 1
	} else {
		set time [clock format [clock seconds]]
		ui_msg "::${time}:: uninstall end."
		return 0
	}


}

# End of portuninstall namespace
}

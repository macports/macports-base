# et:ts=4
# portstartupitem.tcl
#
# $Id: portstartupitem.tcl,v 1.7 2005/02/19 17:05:59 rshaw Exp $
#
# Copyright (c) 2004 Markus W. Weissman <mww@opendarwin.org>,
# Copyright (c) 2005 Robert Shaw <rshaw@opendarwin.org>,
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package provide portstartupitem 1.0
package require portutil 1.0

set_ui_prefix

proc startupitem_create_rcng {args} {
	global prefix destroot portname os.platform
	global startupitem.name startupitem.requires
	global startupitem.start startupitem.stop startupitem.restart
	global startupitem.type

	set scriptdir ${destroot}/${prefix}/etc/rc.d

	if { ![exists startupitem.requires] } {
		set startupitem.requires ""
	}

	# XXX We can't share defaults with startupitem_create_darwin
	foreach item {startupitem.start startupitem.stop startupitem.restart} {
		if {![info exists $item]} {
			return -code error "Missing required option $item"
		}
	}

	file mkdir ${destroot} ${scriptdir}
	set fd [open [file join ${scriptdir} ${startupitem.name}.sh] w 0755]

	puts ${fd} "#!/bin/sh"
	puts ${fd} "#"
	puts ${fd} "# DarwinPorts generated RCng Script"
	puts ${fd} "#"
	puts ${fd} ""
	puts ${fd} "# PROVIDE: ${startupitem.name}"
	puts ${fd} "# REQUIRE: ${startupitem.requires}"
	# TODO: Implement BEFORE support
	puts ${fd} "# BEFORE:"
	puts ${fd} "# KEYWORD: DarwinPorts"
	puts ${fd} ""
	puts ${fd} ". ${prefix}/etc/rc.subr"
	puts ${fd} ""
	puts ${fd} "name=\"${startupitem.name}\""
	puts ${fd} "start_cmd=\"${startupitem.start}\""
	puts ${fd} "stop_cmd=\"${startupitem.stop}\""
	puts ${fd} "restart_cmd=\"${startupitem.restart}\""
	puts ${fd} ""
	puts ${fd} "load_rc_config \"${startupitem.name}\""
	puts ${fd} ""
	puts ${fd} "run_rc_command \"\$1\""
	close ${fd}
}

proc startupitem_create_darwin {args} {
	global prefix destroot portname os.platform
	global startupitem.name startupitem.requires startupitem.init
	global startupitem.start startupitem.stop startupitem.restart

	set scriptdir ${prefix}/etc/startup
	if { ![exists startupitem.name] } {
		set startupitem.name ${portname}
	}
	if { ![exists startupitem.init] } {
		set startupitem.init [list]
	}
	if { ![exists startupitem.start] } {
		set startupitem.start [list "sh ${scriptdir}/${portname}.sh start"]
	}
	if { ![exists startupitem.stop] } {
		set startupitem.stop [list "sh ${scriptdir}/${portname}.sh stop"]
	}
	if { ![exists startupitem.restart] } {
		set startupitem.restart [list "sh ${scriptdir}/${portname}.sh restart"]
	}
	if { ![exists startupitem.requires] } {
		set startupitem.requires [list "Disks" "NFS"]
	}
	set itemname [string toupper ${startupitem.name}]
	set itemdir ${prefix}/etc/StartupItems/${startupitem.name}
	file mkdir ${destroot}${itemdir}
	set item [open "${destroot}${itemdir}/${startupitem.name}" w 0755]
	puts ${item} "#!/bin/sh"
	puts ${item} "#\n# DarwinPorts generated StartupItem\n#\n"
	puts ${item} ". /etc/rc.common\n"
	foreach line ${startupitem.init} { puts ${item} ${line} }
	puts ${item} "\nStartService ()\n\{"
	puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
	puts ${item} "\t\tConsoleMessage \"Starting ${startupitem.name}\""
	foreach line ${startupitem.start} { puts ${item} "\t\t${line}" }
	puts ${item} "\tfi\n\}\n"
	puts ${item} "StopService ()\n\{"
	puts ${item} "\t\tConsoleMessage \"Stopping ${startupitem.name}\""
	foreach line ${startupitem.stop} { puts ${item} "\t\t${line}" }
	puts ${item} "\}\n"
	puts ${item} "RestartService ()\n\{"
	puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
	puts ${item} "\t\tConsoleMessage \"Restarting ${startupitem.name}\""
	foreach line ${startupitem.restart} { puts ${item} "\t\t${line}" }
	puts ${item} "\tfi\n\}\n"
	puts ${item} "RunService \"\$1\""
	close ${item}
	set para [open "${destroot}${itemdir}/StartupParameters.plist" w 0644]
	puts ${para} "\{"
	puts ${para} "\tDescription\t= \"${startupitem.name}\";"
	puts ${para} "\tProvides\t= (\"${startupitem.name}\");"
	puts -nonewline ${para} "\tRequires\t= ("
	puts -nonewline ${para} [format {"%s"} [join ${startupitem.requires} {", "}]]
	puts ${para} ");"
	puts ${para} "\tOrderPreference\t= \"None\";"
	puts ${para} "\}"
	close ${para}
	file mkdir ${destroot}/Library/StartupItems
	system "cd ${destroot}/Library/StartupItems && ln -sf ${itemdir}"
}

proc startupitem_create {args} {
	global os.platform UI_PREFIX
	global startupitem.type
	ui_msg "$UI_PREFIX [msgcat::mc "Creating Startup Script"]"

	switch -exact ${os.platform} {
		"darwin" {
			if {${startupitem.type} == "RCng"} {
				startupitem_create_rcng
			} else {
				startupitem_create_darwin
			}
		}
		default {
			startupitem_create_rcng
		}
	}
}

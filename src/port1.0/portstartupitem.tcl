# et:ts=4
# portstartupitem.tcl
#
# $Id: portstartupitem.tcl,v 1.1 2005/01/18 18:58:15 mww Exp $
#
# Copyright (c) 2004 Markus W. Weissman <mww@opendarwin.org>,
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

proc startupitem_create {args} {
	global prefix destroot portname os.platform
	global startupitem.name startupitem.requires
	global startupitem.start startupitem.start startupitem.start
	ui_msg "creating startup item/script"

	if {${os.platform} == "darwin"} {
	    set scriptdir ${prefix}/etc/startup
		if { ![exists startupitem.name] } {
			set startupitem.name ${portname}
		}
		if { ![exists startupitem.start] } {
			set startupitem.start "sh ${scriptdir}/${portname}.sh start"
		}
		if { ![exists startupitem.stop] } {
			set startupitem.stop  "sh ${scriptdir}/${portname}.sh stop"
		}
		if { ![exists startupitem.restart] } {
			set startupitem.restart "sh ${scriptdir}/${portname}.sh restart"
		}
		if { ![exists startupitem.requires] } {
			set startupitem.requires "\"Disks\", \"NFS\""
		}
		set itemname [string toupper ${startupitem.name}]
		set itemdir ${prefix}/etc/StartupItems/${startupitem.name}
		file mkdir ${destroot}${itemdir}
		set item [open "${destroot}${itemdir}/${startupitem.name}" a]
		puts ${item} "#!/bin/sh"
		puts ${item} "#\n# DarwinPorts generated StartupItem\n#\n"
		puts ${item} ". ${prefix}/etc/rc.common\n"
		puts ${item} "StartService ()\n\{"
		puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
		puts ${item} "\t\tConsoleMessage \"Starting ${startupitem.name}\""
		puts ${item} "\t\t${startupitem.start}"
		puts ${item} "\tfi\n\}\n"
		puts ${item} "StopService ()\n\{"
		puts ${item} "\t\tConsoleMessage \"Stopping ${startupitem.name}\""
		puts ${item} "\t\t${startupitem.stop}"
		puts ${item} "\}\n"
		puts ${item} "RestartService ()\n\{"
		puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
		puts ${item} "\t\tConsoleMessage \"Restarting ${startupitem.name}\""
		puts ${item} "\t\t${startupitem.restart}"
		puts ${item} "\tfi\n\}\n"
		puts ${item} "RunService \"\$1\""
		close ${item}
		set para [open "${destroot}${itemdir}/StartupParameters.plist" a]
		puts ${para} "\{"
		puts ${para} "\tDescription\t= \"${startupitem.name}\";"
		puts ${para} "\tProvides\t= (\"${startupitem.name}\");"
		puts ${para} "\tRequires\t= (${startupitem.requires});"
		puts ${para} "\tOrderPreference\t= \"None\";"
		puts ${para} "\}"
		close ${para}
		file mkdir ${destroot}/Library/StartupItems
		system "cd ${destroot}/Library/StartupItems && ln -sf ${itemdir}"
	} else {
		ui_warn "WARNING: startupitem is not implemented on ${os.platform}."
	}

}

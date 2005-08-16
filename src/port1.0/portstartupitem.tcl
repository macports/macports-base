# et:ts=4
# portstartupitem.tcl
#
# $Id: portstartupitem.tcl,v 1.10 2005/08/16 23:04:17 jberry Exp $
#
# Copyright (c) 2004, 2005 Markus W. Weissman <mww@opendarwin.org>,
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

proc startupitem_create_darwin_systemstarter {args} {
	global prefix destroot portname os.platform
	global startupitem.name startupitem.requires startupitem.init
	global startupitem.start startupitem.stop startupitem.restart
	global startupitem.executable
	
	set scriptdir ${prefix}/etc/startup
	
	set itemname			[string toupper ${startupitem.name}]
	set itemdir				${prefix}/etc/StartupItems/${startupitem.name}
	set startupItemDir		${destroot}${itemdir}
	set startupItemScript	${startupItemDir}/${startupitem.name}
	set startupItemPlist	${startupItemDir}/StartupParameters.plist
	
	file mkdir ${startupItemDir}
	
	set plistName ${destroot}
	
	if { [llength ${startupitem.executable}] && 
			![llength ${startupitem.init}] &&
			![llength ${startupitem.start}] &&
			![llength ${startupitem.stop}] &&
			![llength ${startupitem.restart}] } {
			
		# An executable is specified, and there is no init, start, stop, or restart
		# code; so we need to gen-up those options
			
		set startupitem.init [list \
			"PIDFILE=${prefix}/var/run/${startupitem.name}.pid-dp" \
			]

		set startupitem.start [list \
			"rm -f \$PIDFILE" \
			"${startupitem.executable} &" \
			"echo \$! >\$PIDFILE" \
			]
			
		set startupitem.stop [list \
			"if test -r \$PIDFILE; then" \
			"\tkill \$(cat \$PIDFILE)" \
			"\trm -f \$PIDFILE" \
			"fi" \
			]
	}
	
	if { ![llength ${startupitem.start} ] } {
		set startupitem.start [list "sh ${scriptdir}/${portname}.sh start"]
	}
	if { ![llength ${startupitem.stop} ] } {
		set startupitem.stop [list "sh ${scriptdir}/${portname}.sh stop"]
	}
	if { ![llength ${startupitem.restart} ] } {
		set startupitem.restart [list StopService StartService]
	}
	if { ![llength ${startupitem.requires} ] } {
		set startupitem.requires [list Disks NFS]
	}

	# Generate the startup item script
	set item [open "${startupItemScript}" w 0755]
	file attributes "${startupItemScript}" -owner root -group wheel
	
	puts ${item} "#!/bin/sh"
	puts ${item} "#"
	puts ${item} "# DarwinPorts generated StartupItem"
	puts ${item} "#"
	puts ${item} ""
	puts ${item} ". /etc/rc.common"
	puts ${item} ""
	
	foreach line ${startupitem.init} { puts ${item} ${line} }
	
	puts ${item} "\nStartService ()\n\{"
	puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
	puts ${item} "\t\tConsoleMessage \"Starting ${startupitem.name}\""
	foreach line ${startupitem.start} { puts ${item} "\t\t${line}" }
	puts ${item} "\tfi\n\}\n"
	
	puts ${item} "StopService ()\n\{"
	puts ${item} "\tConsoleMessage \"Stopping ${startupitem.name}\""
	foreach line ${startupitem.stop} { puts ${item} "\t${line}" }
	puts ${item} "\}\n"
	
	puts ${item} "RestartService ()\n\{"
	puts ${item} "\tif \[ \"\$\{${itemname}:=-NO-\}\" = \"-YES-\" \]; then"
	puts ${item} "\t\tConsoleMessage \"Restarting ${startupitem.name}\""
	foreach line ${startupitem.restart} { puts ${item} "\t\t${line}" }
	puts ${item} "\tfi\n\}\n"
	
	puts ${item} "RunService \"\$1\""
	close ${item}
	
	# Generate the plist
	set para [open "${startupItemPlist}" w 0644]
	file attributes "${startupItemPlist}" -owner root -group wheel
	
	puts ${para} "\{"
	puts ${para} "\tDescription\t= \"${startupitem.name}\";"
	puts ${para} "\tProvides\t= (\"${startupitem.name}\");"
	puts -nonewline ${para} "\tRequires\t= ("
	puts -nonewline ${para} [format {"%s"} [join ${startupitem.requires} {", "}]]
	puts ${para} ");"
	puts ${para} "\tOrderPreference\t= \"None\";"
	puts ${para} "\}"
	close ${para}
	
	# Symlink from /Library/StartupItems to the our directory
	file mkdir ${destroot}/Library/StartupItems
	system "cd ${destroot}/Library/StartupItems && ln -sf ${itemdir}"
}

proc startupitem_create_darwin_launchd {args} {
	global prefix destroot portname os.platform
	global startupitem.name startupitem.requires startupitem.init
	global startupitem.start startupitem.stop startupitem.restart
	global startupitem.executable

	set scriptdir ${prefix}/etc/startup
	
	set itemname		${startupitem.name}
	set plistname		${itemname}.plist
	set daemondest		LaunchDaemons
	set itemdir			${prefix}/etc/${daemondest}/${itemname}
	set args			[list "${prefix}/bin/daemondo"]
	
	file mkdir ${destroot}${itemdir}
		
	if { [llength ${startupitem.executable}] && 
			![llength ${startupitem.init}] &&
			![llength ${startupitem.start}] &&
			![llength ${startupitem.stop}] &&
			![llength ${startupitem.restart}] } {
			
		# An executable is specified, and there is no init, start, stop, or restart
		# code; so we don't need a wrapper script
		
		set args [concat $args "--start-cmd" ${startupitem.executable} ";"]
		
	} else {
	
		# No executable was specified, or there was an init, start, stop, or restart
		# option, so we do need a wrapper script
		
		set wrappername		${itemname}.wrapper
		set wrapper			"${itemdir}/${wrappername}"

		if { ![llength ${startupitem.start}] } {
			set startupitem.start [list "sh ${scriptdir}/${portname}.sh start"]
		}
		if { ![llength ${startupitem.stop}] } {
			set startupitem.stop [list "sh ${scriptdir}/${portname}.sh stop"]
		}
		if { ![llength ${startupitem.restart}] } {
			set startupitem.restart [list Stop Start]
		}

		set args [concat $args \
			"--start-cmd"   ${wrapper} start   ";" \
			"--stop-cmd"    ${wrapper} stop    ";" \
			"--restart-cmd" ${wrapper} restart ";" \
			]

		# Create the wrapper script
		set item [open "${destroot}${wrapper}" w 0755]

		puts ${item} "#!/bin/sh"
		puts ${item} "#"
		puts ${item} "# DarwinPorts generated daemondo support script"
		puts ${item} "#"
		puts ${item} ""
		
		puts ${item} "#"
		puts ${item} "# Init"
		puts ${item} "#"
		foreach line ${startupitem.init}	{ puts ${item} ${line} }
		puts ${item} ""

		puts ${item} "#"
		puts ${item} "# Start"
		puts ${item} "#"
		puts ${item} "Start()"
		puts ${item} "\{"
		foreach line ${startupitem.start}	{ puts ${item} "\t${line}" }
		puts ${item} "\}"
		puts ${item} ""
		
		puts ${item} "#"
		puts ${item} "# Stop"
		puts ${item} "#"
		puts ${item} "Stop()"
		puts ${item} "\{"
		foreach line ${startupitem.stop}	{ puts ${item} "\t${line}" }
		puts ${item} "\}"
		puts ${item} ""
	
		puts ${item} "#"
		puts ${item} "# Restart"
		puts ${item} "#"
		puts ${item} "Restart()"
		puts ${item} "\{"
		foreach line ${startupitem.restart} { puts ${item} "\t${line}" }
		puts ${item} "\}"
		puts ${item} ""

		puts ${item} "#"
		puts ${item} "# Run"
		puts ${item} "#"
		puts ${item} "Run()"
		puts ${item} "\{"
		puts ${item} "case \$1 in"
		puts ${item} "  start  ) Start   ;;"
		puts ${item} "  stop   ) Stop    ;;"
		puts ${item} "  restart) Restart ;;"
		puts ${item} "  *      ) echo \"\$0: unknown argument: \$1\";;"
		puts ${item} "esac"
		puts ${item} "\}"
		puts ${item} ""

		puts ${item} "#"
		puts ${item} "# Run a phase based on the selector"
		puts ${item} "#"
		puts ${item} "Run \$1"
		puts ${item} ""

		close ${item}
	}
		
	# Create the plist file
	set plist [open "${destroot}${itemdir}/${plistname}" w 0644]
	
	puts ${plist} "<?xml version='1.0' encoding='UTF-8'?>"
	puts ${plist} "<!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN"
	puts ${plist} "http://www.apple.com/DTDs/PropertyList-1.0.dtd >"
	puts ${plist} "<plist version='1.0'>"
	puts ${plist} "<dict>"
	
	puts ${plist} "<key>Label</key><string>${itemname}</string>"
	
	puts ${plist} "<key>ProgramArguments</key>"
	puts ${plist} "<array>"
	foreach arg ${args} { puts ${plist} "\t<string>${arg}</string>" }
	puts ${plist} "</array>"
	
	puts ${plist} "<key>Disabled</key><false/>"
	puts ${plist} "<key>OnDemand</key><false/>"
	puts ${plist} "<key>RunAtLoad</key><false/>"
	
	puts ${plist} "</dict>"
	puts ${plist} "</plist>"

	close ${plist}

	# Make a symlink to the plist file
	file mkdir "${destroot}/Library/${daemondest}"
	system "cd ${destroot}/Library/${daemondest} && ln -sf ${itemdir}/${plistname}"
}

proc startupitem_create {args} {
	global UI_PREFIX
	global startupitem.type os.platform
	
	# Calculate a default value for startupitem.type
	# If the option has already been set, default will do nothing
	switch -exact ${os.platform} {
		darwin {
			set enableLaunchd ${portutil::autoconf::enable_launchd_support}
			set haveLaunchd	${portutil::autoconf::have_launchd}
			
			if { ${enableLaunchd} && ${haveLaunchd} } {
				default startupitem.type "launchd"
			} else {
				default startupitem.type "SystemStarter"
			}
		}
		default {
			default startupitem.type "RCng"
		}
	}
		
	ui_msg "$UI_PREFIX [msgcat::mc "Creating ${startupitem.type} control script"]"

	switch ${startupitem.type} {
		launchd			{ startupitem_create_darwin_launchd }
		SystemStarter	{ startupitem_create_darwin_systemstarter }
		RCng			{ startupitem_create_rcng }
		default			{ startupitem_create_rcng }
	}
}

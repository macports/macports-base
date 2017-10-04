# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portstartupitem.tcl
#
# Copyright (c) 2004-2012 The MacPorts Project
# Copyright (c) 2006-2007 James D. Berry
# Copyright (c) 2004,2005 Markus W. Weissman <mww@macports.org>
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
# 3. Neither the name of The MacPorts Project nor the names of its
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


#
#   Newly added keys:
#
#   startupitem.executable  the command to start the executable
#       This is exclusive of init, start, stop, restart
#       - This may be composed of exec arguments only--not shell code
#
#   startupitem.pidfile     none
#       There is no pidfile we can track
#
#   startupitem.pidfile     auto [filename.pid]
#       The daemon is responsible for creating/deleting the pidfile
#
#   startupitem.pidfile     clean [filename.pid]
#       The daemon creates the pidfile, but we must delete it
#
#   startupitem.pidfile     manual [filename.pid]
#       We create and destroy the pidfile to track the pid we receive from the executable
#
#   startupitem.logfile     logpath
#       Log to the specified file -- if not specified then output to /dev/null
#       - for launchd, just set this as the standard out key
#
#   startupitem.logevents   yes/no
#       Log events to the log
#       - for launchd, generate log messages inside daemondo
#
#   startupitem.autostart   yes/no
#       Automatically load the startupitem after activating. Defaults to no.
#

package provide portstartupitem 1.0
package require portutil 1.0

namespace eval portstartupitem {
}

set_ui_prefix

proc portstartupitem::startupitem_create_rcng {args} {
    global prefix destroot os.platform \
           startupitem.name startupitem.requires \
           startupitem.start startupitem.stop startupitem.restart \
           startupitem.type

    set scriptdir ${destroot}${prefix}/etc/rc.d

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
    puts ${fd} "# MacPorts generated RCng Script"
    puts ${fd} "#"
    puts ${fd} ""
    puts ${fd} "# PROVIDE: ${startupitem.name}"
    puts ${fd} "# REQUIRE: ${startupitem.requires}"
    # TODO: Implement BEFORE support
    puts ${fd} "# BEFORE:"
    puts ${fd} "# KEYWORD: MacPorts"
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

proc portstartupitem::startupitem_create_darwin_launchd {args} {
    global UI_PREFIX prefix destroot destroot.keepdirs subport macosx_deployment_target \
           startupitem.name startupitem.uniquename startupitem.plist startupitem.location \
           startupitem.init startupitem.start startupitem.stop startupitem.restart startupitem.executable \
           startupitem.pidfile startupitem.logfile startupitem.logevents startupitem.netchange \
           startupitem.install startupitem.autostart

    set scriptdir ${prefix}/etc/startup
    
    set itemname        ${startupitem.name}
    set uniquename      ${startupitem.uniquename}
    set plistname       ${startupitem.plist}
    set daemondest      ${startupitem.location}
    set itemdir         ${prefix}/etc/${daemondest}/${uniquename}
    set args            [list \
                          "${prefix}/bin/daemondo" \
                          "--label=${itemname}" \
                        ]
    
    file mkdir ${destroot}${itemdir}
    if {[getuid] == 0} {
        file attributes ${destroot}${itemdir} -owner root -group wheel
    }
        
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
        
        set wrappername     ${itemname}.wrapper
        set wrapper         "${itemdir}/${wrappername}"

        if { ![llength ${startupitem.start}] } {
            set startupitem.start [list "sh ${scriptdir}/${subport}.sh start"]
        }
        if { ![llength ${startupitem.stop}] } {
            set startupitem.stop [list "sh ${scriptdir}/${subport}.sh stop"]
        }
        if { ![llength ${startupitem.restart}] } {
            set startupitem.restart [list Stop Start]
        }

        lappend args \
          "--start-cmd"   ${wrapper} start   ";" \
          "--stop-cmd"    ${wrapper} stop    ";" \
          "--restart-cmd" ${wrapper} restart ";"

        # Create the wrapper script
        set item [open "${destroot}${wrapper}" w 0755]
        if {[getuid] == 0} {
            file attributes "${destroot}${wrapper}" -owner root -group wheel
        }

        puts ${item} "#!/bin/sh"
        puts ${item} "#"
        puts ${item} "# MacPorts generated daemondo support script"
        puts ${item} "#"
        puts ${item} ""
        
        puts ${item} "#"
        puts ${item} "# Init"
        puts ${item} "#"
        puts ${item} "prefix=$prefix"
        foreach line ${startupitem.init}    { puts ${item} ${line} }
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Start"
        puts ${item} "#"
        puts ${item} "Start()"
        puts ${item} "\{"
        foreach line ${startupitem.start}   { puts ${item} "\t${line}" }
        puts ${item} "\}"
        puts ${item} ""
        
        puts ${item} "#"
        puts ${item} "# Stop"
        puts ${item} "#"
        puts ${item} "Stop()"
        puts ${item} "\{"
        foreach line ${startupitem.stop}    { puts ${item} "\t${line}" }
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
    
    if {[tbool startupitem.netchange]} {
        lappend args "--restart-netchange"
    }
    
    # To log events then tell daemondo to log at verbosity=1
    if { [tbool startupitem.logevents] } {
        lappend args "--verbosity=1"
    }
    
    # If pidfile was specified, translate it for daemondo.
    #
    # There are four cases:
    #   (1) none
    #   (2) auto [pidfilename]
    #   (3) clean [pidfilename]
    #   (4) manual [pidfilename]
    #
    set pidfileArgCnt [llength ${startupitem.pidfile}]
    if { ${pidfileArgCnt} > 0 } {
        if { $pidfileArgCnt == 1 } {
            set pidFile "${prefix}/var/run/${itemname}.pid"
            lappend destroot.keepdirs "${destroot}${prefix}/var/run"
        } else {
            set pidFile [lindex ${startupitem.pidfile} 1]
        }

        if { ${pidfileArgCnt} > 2 } {
            ui_error "$UI_PREFIX [msgcat::mc "Invalid parameter count to startupitem.pidfile: 2 expected, %d found" ${pidfileArgCnt}]"
        }
        
        # Translate into appropriate arguments to daemondo
        set pidStyle [lindex ${startupitem.pidfile} 0]
        switch ${pidStyle} {
            none    { lappend args "--pid=none" }
            auto    { lappend args "--pid=fileauto" "--pidfile" ${pidFile} }
            clean   { lappend args "--pid=fileclean" "--pidfile" ${pidFile} }
            manual  { lappend args "--pid=exec" "--pidfile" ${pidFile} }
            default {
                ui_error "$UI_PREFIX [msgcat::mc "Unknown pidfile style %s presented to startupitem.pidfile" ${pidStyle}]"
            }
        }
    } else {
        if { [llength ${startupitem.executable}] } {
            lappend args "--pid=exec"
        } else {
            lappend args "--pid=none"
        }
    }
    
    # Create the plist file
    set plist [open "${destroot}${itemdir}/${plistname}" w 0644]
    
    puts ${plist} "<?xml version='1.0' encoding='UTF-8'?>"
    puts ${plist} "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\""
    puts ${plist} "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\" >"
    puts ${plist} "<plist version='1.0'>"
    puts ${plist} "<dict>"
    
    puts ${plist} "<key>Label</key><string>${uniquename}</string>"
    
    puts ${plist} "<key>ProgramArguments</key>"
    puts ${plist} "<array>"
    foreach arg ${args} { puts ${plist} "\t<string>${arg}</string>" }
    puts ${plist} "</array>"
    
    puts ${plist} "<key>Disabled</key><true/>"
    if {$macosx_deployment_target ne "10.4"} {
        puts ${plist} "<key>KeepAlive</key><true/>"
    } else {
        puts ${plist} "<key>OnDemand</key><false/>"
    }
    
    if { [llength ${startupitem.logfile}] } {
        puts ${plist} "<key>StandardOutPath</key><string>${startupitem.logfile}</string>"
    }
    
    puts ${plist} "</dict>"
    puts ${plist} "</plist>"

    close ${plist}

    if { [getuid] == 0 && 
      ${startupitem.install} ne "no" } {
        file mkdir "${destroot}/Library/${daemondest}"
        ln -sf "${itemdir}/${plistname}" "${destroot}/Library/${daemondest}"
    }

    # If launchd is not available, warn the user
    set haveLaunchd ${portutil::autoconf::have_launchd}
    if {![tbool haveLaunchd]} {
        ui_notice "###########################################################"
        ui_notice "# WARNING:"
        ui_notice "# We're building a launchd startup item, but launchd wasn't"
        ui_notice "# found by configure. Are you sure you didn't mess up your"
        ui_notice "# macports.conf settings?"
        ui_notice "###########################################################"
    }
    
    # Emit some information for the user
    if {[tbool startupitem.autostart]} {
        ui_notice "###########################################################"
        ui_notice "# A startup item has been generated that will aid in"
        ui_notice "# starting ${subport} with launchd. It will be enabled"
        ui_notice "# automatically on activation. Execute the following"
        ui_notice "# command to manually _disable_ it:"
        ui_notice "#"
        ui_notice "# sudo port unload ${subport}"
        ui_notice "###########################################################"
    } else {
        ui_notice "###########################################################"
        ui_notice "# A startup item has been generated that will aid in"
        ui_notice "# starting ${subport} with launchd. It is disabled"
        ui_notice "# by default. Execute the following command to start it,"
        ui_notice "# and to cause it to launch at startup:"
        ui_notice "#"
        ui_notice "# sudo port load ${subport}"
        ui_notice "###########################################################"
    }
}

proc portstartupitem::startupitem_create {args} {
    global UI_PREFIX startupitem.type os.platform
    
    set startupitem.type [string tolower ${startupitem.type}]
    
    # Calculate a default value for startupitem.type
    if {${startupitem.type} eq "default" || ${startupitem.type} eq ""} {
        switch -exact ${os.platform} {
            darwin {
                set startupitem.type "launchd"
            }
            default {
                set startupitem.type "rcng"
            }
        }
    }

    if { ${startupitem.type} eq "none" } {
        ui_notice "$UI_PREFIX [msgcat::mc "Skipping creation of control script"]"
    } else {
        ui_notice "$UI_PREFIX [msgcat::mc "Creating ${startupitem.type} control script"]"

        switch -- ${startupitem.type} {
            launchd         { startupitem_create_darwin_launchd }
            rcng            { startupitem_create_rcng }
            default         { ui_error "$UI_PREFIX [msgcat::mc "Unrecognized startupitem type %s" ${startupitem.type}]" }
        }
    }
}

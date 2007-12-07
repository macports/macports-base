# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portstartupitem.tcl
#
# $Id$
#
# Copyright (c) 2004-2007 MacPorts Project
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
#       - for systemstarter, redirect to this
#
#   startupitem.logevents   yes/no
#       Log events to the log
#       - for launchd, generate log messages inside daemondo
#       - for systemstarter, generate log messages in our generated script
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

proc startupitem_create_darwin_systemstarter {args} {
    global UI_PREFIX prefix destroot destroot.keepdirs  portname os.platform
    global startupitem.name startupitem.requires startupitem.init
    global startupitem.start startupitem.stop startupitem.restart startupitem.executable
    global startupitem.pidfile startupitem.logfile startupitem.logevents
    
    set scriptdir ${prefix}/etc/startup
    
    set itemname            ${startupitem.name}
    set uppername           [string toupper ${startupitem.name}]
    set itemdir             /Library/StartupItems/${itemname}
    set startupItemDir      ${destroot}${itemdir}
    set startupItemScript   ${startupItemDir}/${itemname}
    set startupItemPlist    ${startupItemDir}/StartupParameters.plist
    
    # Interpret the pidfile spec
    #
    # There are four cases:
    #   (1) none (or none specified)
    #   (2) auto [pidfilename]
    #   (3) clean [pidfilename]
    #   (4) manual [pidfilename]
    #
    set createPidFile false
    set deletePidFile false
    set pidFile ""
    set pidfileArgCnt [llength ${startupitem.pidfile}]
    if { ${pidfileArgCnt} > 0 } {
        if { $pidfileArgCnt == 1 } {
            set pidFile "${prefix}/var/run/${itemname}.pid"
            lappend destroot.keepdirs "${destroot}${prefix}/var/run"
        } else {
            set pidFile [lindex ${startupitem.pidfile} 1]
        }
        if { $pidfileArgCnt > 2 } {
            ui_error "$UI_PREFIX [msgcat::mc "Invalid parameter count to startupitem.pidfile: 2 expected, %d found" ${pidfileArgCnt}]"
        }
        
        set pidStyle [lindex ${startupitem.pidfile} 0]
        switch ${pidStyle} {
            none    { set createPidFile false; set deletePidFile false; set pidFile ""  }
            auto    { set createPidFile false; set deletePidFile false  }
            clean   { set createPidFile false; set deletePidFile true   }
            manual  { set createPidFile true;  set deletePidFile true   }
            default {
                ui_error "$UI_PREFIX [msgcat::mc "Unknown pidfile style %s presented to startupitem.pidfile" ${pidStyle}]"
            }
        }
    }

    if { [llength ${startupitem.executable}] && 
      ![llength ${startupitem.init}] &&
      ![llength ${startupitem.start}] &&
      ![llength ${startupitem.stop}] &&
      ![llength ${startupitem.restart}] } {
        # An executable is specified, and there is no init, start, stop, or restart
    } else {
        if { ![llength ${startupitem.start} ] } {
            set startupitem.start [list "sh ${scriptdir}/${portname}.sh start"]
        }
        if { ![llength ${startupitem.stop} ] } {
            set startupitem.stop [list "sh ${scriptdir}/${portname}.sh stop"]
        }
    }
    if { ![llength ${startupitem.requires} ] } {
        set startupitem.requires [list Disks NFS]
    }
    if { ![llength ${startupitem.logfile} ] } {
        set startupitem.logfile "/dev/null"
    }
    
    ########################
    # Create the startup item directory
    file mkdir ${startupItemDir}
    file attributes ${startupItemDir} -owner root -group wheel
    
    ########################
    # Generate the startup item script
    set item [open "${startupItemScript}" w 0755]
    file attributes "${startupItemScript}" -owner root -group wheel
    
    # Emit the header
    puts ${item} {#!/bin/sh
#
# MacPorts generated StartupItem
#

    }
    puts ${item} "prefix=$prefix"
    # Source the utilities package and the MacPorts config file
    puts ${item} {[ -r "/etc/rc.common" ] && . "/etc/rc.common"}
    puts ${item} {[ -r "${prefix}/etc/rc.conf" ] && . "${prefix}/etc/rc.conf"}

    # Emit the Configuration Section
    puts ${item} "NAME=${itemname}"
    puts ${item} "ENABLE_FLAG=\${${uppername}:=-NO-}"
    puts ${item} "PIDFILE=\"${pidFile}\""
    puts ${item} "LOGFILE=\"${startupitem.logfile}\""
    puts ${item} "EXECUTABLE=\"${startupitem.executable}\""
    puts ${item} ""
    puts ${item} "HAVE_STARTCMDS=[expr [llength ${startupitem.start}] ? "true" : "false"]"
    puts ${item} "HAVE_STOPCMDS=[expr [llength ${startupitem.stop}] ? "true" : "false"]"
    puts ${item} "HAVE_RESTARTCMDS=[expr [llength ${startupitem.restart}] ? "true" : "false"]"
    puts ${item} "DELETE_PIDFILE=${createPidFile}"
    puts ${item} "CREATE_PIDFILE=${deletePidFile}"
    puts ${item} "LOG_EVENTS=[expr [tbool ${startupitem.logevents}] ? "true" : "false"]"
    puts ${item} ""

    # Emit the init lines
    foreach line ${startupitem.init} { puts ${item} ${line} }
    puts ${item} ""
    
    # Emit the _Cmds
    foreach kind { start stop restart } {
        if {[llength [set "startupitem.$kind"]]} {
            puts ${item} "${kind}Cmds () \{"
            foreach line [set "startupitem.$kind"] {
                puts ${item} "\t${line}"
            }
            puts ${item} "\}\n"
        }
    }
    
    # vvvvv START BOILERPLATE vvvvvv
    # Emit the static boilerplate section
    puts ${item} {
IsEnabled () {
    [ "${ENABLE_FLAG}" = "-YES-" ]
    return $?
}

CreatePIDFile () {
    echo $1 > "$PIDFILE"
}

DeletePIDFile () {
    rm -f "$PIDFILE"
}

ReadPID () {
    if [ -r "$PIDFILE" ]; then
        read pid < "$PIDFILE"
    else
        pid=0
    fi
    echo $pid
}

CheckPID () {
    pid=$(ReadPID)
    if (($pid)); then
        kill -0 $pid >& /dev/null || pid=0
    fi
    echo $pid
}

NoteEvent () {
    ConsoleMessage "$1"
    $LOG_EVENTS && [ -n "$LOGFILE" ] && echo "$(date) $NAME: $1" >> $LOGFILE
}

StartService () {
    if IsEnabled; then
        NoteEvent "Starting $NAME"
        
        if $HAVE_STARTCMDS; then
            startCmds
        elif [ -n "$EXECUTABLE" ]; then
            $EXECUTABLE &
            pid=$!
            if $CREATE_PIDFILE; then
                CreatePIDFile $pid
            fi
        fi
        
    fi
}

StopService () {
    NoteEvent "Stopping $NAME"
    
    gaveup=false
    if $HAVE_STOPCMDS; then
        # If we have stop cmds, use them
        stopCmds
    else        
        # Otherwise, get the pid and try to stop the program
        echo -n "Stopping $NAME..."
        
        pid=$(CheckPID)
        if (($pid)); then
            # Try to kill the process with SIGTERM
            kill $pid
            
            # Wait for it to really stop
            for ((CNT=0; CNT < 15 && $(CheckPID); ++CNT)); do
                echo -n "."
                sleep 1
            done
            
            # Report status
            if (($(CheckPID))); then
                gaveup=true
                echo "giving up."
            else
                echo "stopped."
            fi
        else
            echo "it's not running."
        fi
    fi
    
    # Cleanup the pidfile if we've been asked to
    if ! $gaveup && $DELETE_PIDFILE; then
        DeletePIDFile
    fi
}

RestartService () {
    if IsEnabled; then
        NoteEvent "Restarting $NAME"
        
        if $HAVE_RESTARTCMDS; then
            # If we have restart cmds, use them
            restartCmds
        else
            # Otherwise just stop/start it
            StopService
            StartService
        fi
        
    fi
}

RunService "$1"
    }
    # ^^^^^^ END BOILERPLATE ^^^^^^
    
    close ${item}
    
    ########################
    # Generate the plist
    set para [open "${startupItemPlist}" w 0644]
    file attributes "${startupItemPlist}" -owner root -group wheel
    
    puts ${para} "\{"
    puts ${para} "\tDescription\t= \"${itemname}\";"
    puts ${para} "\tProvides\t= (\"${itemname}\");"
    puts -nonewline ${para} "\tRequires\t= ("
    puts -nonewline ${para} [format {"%s"} [join ${startupitem.requires} {", "}]]
    puts ${para} ");"
    puts ${para} "\tOrderPreference\t= \"None\";"
    puts ${para} "\}"
    close ${para}
    
    # Emit some information for the user
    ui_msg "###########################################################"
    ui_msg "# A startup item has been generated that will aid in"
    ui_msg "# starting ${portname} with SystemStarter. It is disabled"
    ui_msg "# by default. Add the following line to /etc/hostconfig"
    ui_msg "# or ${prefix}/etc/rc.conf to start it at startup:"
    ui_msg "#"
    ui_msg "# ${uppername}=-YES-"
    ui_msg "###########################################################"
}

proc startupitem_create_darwin_launchd {args} {
    global UI_PREFIX prefix destroot destroot.keepdirs portname os.platform
    global startupitem.name startupitem.uniquename startupitem.plist startupitem.location
    global startupitem.init startupitem.start startupitem.stop startupitem.restart startupitem.executable
    global startupitem.pidfile startupitem.logfile startupitem.logevents startupitem.netchange

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
    file attributes ${destroot}${itemdir} -owner root -group wheel
        
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
            set startupitem.start [list "sh ${scriptdir}/${portname}.sh start"]
        }
        if { ![llength ${startupitem.stop}] } {
            set startupitem.stop [list "sh ${scriptdir}/${portname}.sh stop"]
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
        file attributes "${destroot}${wrapper}" -owner root -group wheel

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
    puts ${plist} "<!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN"
    puts ${plist} "http://www.apple.com/DTDs/PropertyList-1.0.dtd >"
    puts ${plist} "<plist version='1.0'>"
    puts ${plist} "<dict>"
    
    puts ${plist} "<key>Label</key><string>${uniquename}</string>"
    
    puts ${plist} "<key>ProgramArguments</key>"
    puts ${plist} "<array>"
    foreach arg ${args} { puts ${plist} "\t<string>${arg}</string>" }
    puts ${plist} "</array>"
    
    puts ${plist} "<key>Debug</key><false/>"
    puts ${plist} "<key>Disabled</key><true/>"
    puts ${plist} "<key>OnDemand</key><false/>"
    puts ${plist} "<key>RunAtLoad</key><false/>"
    
    if { [llength ${startupitem.logfile}] } {
        puts ${plist} "<key>StandardOutPath</key><string>${startupitem.logfile}</string>"
    }
    
    puts ${plist} "</dict>"
    puts ${plist} "</plist>"

    close ${plist}

    # Make a symlink to the plist file
    file mkdir "${destroot}/Library/${daemondest}"
    system "cd ${destroot}/Library/${daemondest} && ln -sf ${itemdir}/${plistname}"
    
    # If launchd is not available, warn the user
    set haveLaunchd ${portutil::autoconf::have_launchd}
    if {![tbool haveLaunchd]} {
        ui_msg "###########################################################"
        ui_msg "# WARNING:"
        ui_msg "# We're building a launchd startup item, but launchd wasn't"
        ui_msg "# found by configure. Are you sure you didn't mess up your"
        ui_msg "# ports.conf settings?"
        ui_msg "###########################################################"
    }
    
    # Emit some information for the user
    ui_msg "###########################################################"
    ui_msg "# A startup item has been generated that will aid in"
    ui_msg "# starting ${portname} with launchd. It is disabled"
    ui_msg "# by default. Execute the following command to start it,"
    ui_msg "# and to cause it to launch at startup:"
    ui_msg "#"
    ui_msg "# sudo launchctl load -w /Library/${daemondest}/${plistname}"
    ui_msg "###########################################################"
}

proc startupitem_create {args} {
    global UI_PREFIX
    global startupitem.type os.platform
    
    set startupitem.type [string tolower ${startupitem.type}]
    
    # Calculate a default value for startupitem.type
    if {${startupitem.type} == "default" || ${startupitem.type} == ""} {
        switch -exact ${os.platform} {
            darwin {
                set haveLaunchd ${portutil::autoconf::have_launchd}
                if { [tbool haveLaunchd] } {
                    set startupitem.type "launchd"
                } else {
                    set startupitem.type "systemstarter"
                }
            }
            default {
                set startupitem.type "rcng"
            }
        }
    }

    if { ${startupitem.type} == "none" } {
        ui_msg "$UI_PREFIX [msgcat::mc "Skipping creation of control script"]"
    } else {
        ui_msg "$UI_PREFIX [msgcat::mc "Creating ${startupitem.type} control script"]"

        switch -- ${startupitem.type} {
            launchd         { startupitem_create_darwin_launchd }
            systemstarter   { startupitem_create_darwin_systemstarter }
            rcng            { startupitem_create_rcng }
            default         { ui_error "$UI_PREFIX [msgcat::mc "Unrecognized startupitem type %s" ${startupitem.type}]" }
        }
    }
}

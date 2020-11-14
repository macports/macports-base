# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portstartupitem.tcl
#
# Copyright (c) 2004-2014, 2016-2018, 2020 The MacPorts Project
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
#       - daemondo verbosity is controlled by startupitem.daemondo.verbosity
#
#   startupitem.autostart   yes/no
#       Automatically load the startupitem after activating. Defaults to no.
#
#   startupitem.user        <user>
#       User to run the service/daemon as.
#
#   startupitem.group       <group>
#       Group to run the service/daemon as.
#
#   startupitem.debug       yes/no
#       Enable additional debug logging
#       - for launchd, sets the Debug key to true

package provide portstartupitem 1.0
package require portutil 1.0

namespace eval portstartupitem {
}

options startupitems startupitem.autostart startupitem.debug \
        startupitem.create startupitem.executable \
        startupitem.user startupitem.group \
        startupitem.init startupitem.install startupitem.location \
        startupitem.logevents startupitem.logfile startupitem.name \
        startupitem.netchange startupitem.pidfile startupitem.plist \
        startupitem.requires startupitem.restart startupitem.start \
        startupitem.stop startupitem.type startupitem.uniquename \
        startupitem.daemondo.verbosity

default startupitem.autostart   no
default startupitem.debug       no
default startupitem.executable  ""
default startupitem.group       ""
default startupitem.init        ""
default startupitem.install     {$system_options(startupitem_install)}
default startupitem.location    LaunchDaemons
default startupitem.logevents   no
default startupitem.logfile     ""
default startupitem.name        {${subport}}
default startupitem.netchange   no
default startupitem.pidfile     ""
default startupitem.plist       {${startupitem.uniquename}.plist}
default startupitem.requires    ""
default startupitem.restart     ""
default startupitem.start       ""
default startupitem.stop        ""
default startupitem.type        {[portstartupitem::get_startupitem_type]}
default startupitem.uniquename  {org.macports.${startupitem.name}}
default startupitem.user        ""

default startupitem.daemondo.verbosity  1

set_ui_prefix

# Calculate a default value for startupitem.type
proc portstartupitem::get_startupitem_type {} {
    global system_options os.platform startupitem.create

    if {![tbool startupitem.create]} {
        return "none"
    }

    set type $system_options(startupitem_type)
    if {$type eq "default" || $type eq ""} {
        switch -- ${os.platform} {
            darwin {
                return "launchd"
            }
            default {
                return "none"
            }
        }
    }
    return $type
}

# run a loop body with variables set up representing the attributes of
# each startupitem that has been defined in the portfile
proc portstartupitem::foreach_startupitem {body} {
    global startupitems
    set vars [list autostart debug create executable group init install \
              location logevents logfile name netchange pidfile plist \
              requires restart start stop type uniquename user \
              daemondo.verbosity]

    array set startupitems_dict {}
    if {[info exists startupitems] && $startupitems ne ""} {
        foreach {key val} $startupitems {
            if {$key eq "name"} {
                set curname $val
                # these have defaults based on the name
                set uniquename org.macports.${val}
                lappend startupitems_dict($curname) uniquename $uniquename
                lappend startupitems_dict($curname) plist ${uniquename}.plist
            }
            lappend startupitems_dict($curname) $key $val
        }
    } else {
        global startupitem.name
        foreach var $vars {
            global startupitem.${var}
            if {[info exists startupitem.${var}]} {
                lappend startupitems_dict(${startupitem.name}) $var [set startupitem.${var}]
            }
        }
    }

    uplevel 1 "set si_vars [list $vars]"
    foreach item [array names startupitems_dict] {
        uplevel 1 "array unset si_dict; array set si_dict [list $startupitems_dict($item)]"
        uplevel 1 {
            foreach si_var $si_vars {
                if {[info exists si_dict($si_var)]} {
                    set si_${si_var} $si_dict($si_var)
                } else {
                    global startupitem.${si_var}
                    if {[info exists startupitem.${si_var}]} {
                        set si_${si_var} [set startupitem.${si_var}]
                        set si_dict($si_var) [set startupitem.${si_var}]
                    }
                }
            }
        }
        uplevel 1 $body
    }
}

# Add user notes regarding any installed startupitem
proc portstartupitem::add_notes {} {
    global subport startupitem_autostart
    set autostart_names {}
    set normal_names {}

    foreach_startupitem {
        if {$si_type eq "none"} {
            continue
        }
        # Add some information for the user to the port's notes
        if {$si_autostart && [tbool startupitem_autostart]} {
            lappend autostart_names $si_name
        } else {
            lappend normal_names $si_name
        }
    }

    if {$normal_names ne ""} {
        if {[exists notes]} {
            # leave a blank line after the existing notes
            notes-append ""
        }
        if {[llength $normal_names] == 1} {
        notes-append \
            "A startup item has been generated that will aid in\
            starting ${subport} with launchd. It is disabled\
            by default. Execute the following command to start it,\
            and to cause it to launch at startup:

    sudo port load ${subport}"
        } else {
            set namelist [join $normal_names ", "]
            notes-append \
            "Startup items (named '$namelist') have been generated that will aid in\
            starting ${subport} with launchd. They are disabled\
            by default. Execute the following command to start them,\
            and to cause them to launch at startup:

    sudo port load ${subport}"
        }
    }
    if {$autostart_names ne ""} {
        if {[exists notes]} {
            # leave a blank line after the existing notes
            notes-append ""
        }
        if {[llength $autostart_names] == 1} {
            notes-append \
            "A startup item has been generated that will\
            start ${subport} with launchd, and will be enabled\
            automatically on activation. Execute the following\
            command to manually _disable_ it:

    sudo port unload ${subport}"
        } else {
            set namelist [join $autostart_names ", "]
            notes-append \
            "Startup items (named '$namelist') have been generated that will\
            start ${subport} with launchd, and will be enabled\
            automatically on activation. Execute the following\
            command to manually _disable_ them:

    sudo port unload ${subport}"
        }
    }
}

# Register the above procedure as a callback after Portfile evaluation
port::register_callback portstartupitem::add_notes

proc portstartupitem::startupitem_create_darwin_launchd {attrs} {
    global UI_PREFIX prefix destroot destroot.keepdirs subport macosx_deployment_target

    array set si $attrs

    set scriptdir ${prefix}/etc/startup

    set itemname        $si(name)
    set uniquename      $si(uniquename)
    set plistname       $si(plist)
    set daemondest      $si(location)
    set itemdir         ${prefix}/etc/${daemondest}/${uniquename}
    set username        $si(user)
    set groupname       $si(group)
    set args            [list \
                          "${prefix}/bin/daemondo" \
                          "--label=${itemname}" \
                        ]

    file mkdir ${destroot}${itemdir}
    if {[getuid] == 0} {
        file attributes ${destroot}${itemdir} -owner root -group wheel
    }

    if {$si(executable) ne "" &&
        $si(init) eq "" &&
        $si(start) eq "" &&
        $si(stop) eq "" &&
        $si(restart) eq ""} {

        # An executable is specified, and there is no init, start, stop, or restart
        # code; so we don't need a wrapper script
        set args [concat $args "--start-cmd" $si(executable) ";"]

    } else {

        # No executable was specified, or there was an init, start, stop, or restart
        # option, so we do need a wrapper script

        set wrappername     ${itemname}.wrapper
        set wrapper         "${itemdir}/${wrappername}"

        if {$si(start) eq ""} {
            set si(start) [list "sh ${scriptdir}/${subport}.sh start"]
        }
        if {$si(stop) eq ""} {
            set si(stop) [list "sh ${scriptdir}/${subport}.sh stop"]
        }
        if {$si(restart) eq ""} {
            set si(restart) [list Stop Start]
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
        foreach line $si(init)    { puts ${item} ${line} }
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Start"
        puts ${item} "#"
        puts ${item} "Start()"
        puts ${item} "\{"
        foreach line $si(start)   { puts ${item} "\t${line}" }
        puts ${item} "\}"
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Stop"
        puts ${item} "#"
        puts ${item} "Stop()"
        puts ${item} "\{"
        foreach line $si(stop)    { puts ${item} "\t${line}" }
        puts ${item} "\}"
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Restart"
        puts ${item} "#"
        puts ${item} "Restart()"
        puts ${item} "\{"
        foreach line $si(restart) { puts ${item} "\t${line}" }
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

    if {$si(netchange)} {
        lappend args "--restart-netchange"
    }

    # To log events then tell daemondo to log at verbosity=n
    if {$si(logevents)} {
        lappend args "--verbosity=[option startupitem.daemondo.verbosity]"
    }

    # If pidfile was specified, translate it for daemondo.
    #
    # There are four cases:
    #   (1) none
    #   (2) auto [pidfilename]
    #   (3) clean [pidfilename]
    #   (4) manual [pidfilename]
    #
    set pidfileArgCnt [llength $si(pidfile)]
    if {${pidfileArgCnt} > 0} {
        if { $pidfileArgCnt == 1 } {
            set pidFile "${prefix}/var/run/${itemname}.pid"
            if {"${destroot}${prefix}/var/run" ni ${destroot.keepdirs}} {
                lappend destroot.keepdirs "${destroot}${prefix}/var/run"
            }
        } else {
            set pidFile [lindex $si(pidfile) 1]
        }

        if {${pidfileArgCnt} > 2} {
            ui_error "$UI_PREFIX [msgcat::mc "Invalid parameter count to startupitem.pidfile: 2 expected, %d found" ${pidfileArgCnt}]"
        }

        # Translate into appropriate arguments to daemondo
        set pidStyle [lindex $si(pidfile) 0]
        switch -- ${pidStyle} {
            none    { lappend args "--pid=none" }
            auto    { lappend args "--pid=fileauto" "--pidfile" ${pidFile} }
            clean   { lappend args "--pid=fileclean" "--pidfile" ${pidFile} }
            manual  { lappend args "--pid=exec" "--pidfile" ${pidFile} }
            default {
                ui_error "$UI_PREFIX [msgcat::mc "Unknown pidfile style %s presented to startupitem.pidfile" ${pidStyle}]"
            }
        }
    } else {
        if {$si(executable) ne ""} {
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

    if {$username ne ""} {
        puts ${plist} "<key>UserName</key><string>$username</string>"
    }

    if {$groupname ne ""} {
        puts ${plist} "<key>GroupName</key><string>$groupname</string>"
    }

    if {$si(logfile) ne ""} {
        puts ${plist} "<key>StandardOutPath</key><string>$si(logfile)</string>"
    }

    if {$si(debug)} {
        puts ${plist} "<key>Debug</key><true/>"
    }

    puts ${plist} "</dict>"
    puts ${plist} "</plist>"

    close ${plist}

    if {[getuid] == 0 && $si(install)} {
        file mkdir "${destroot}/Library/${daemondest}"
        ln -sf "${itemdir}/${plistname}" "${destroot}/Library/${daemondest}"
    } else {
        ln -sf ${itemdir}/${plistname} ${destroot}${prefix}/etc/${daemondest}
    }
}

proc portstartupitem::startupitem_create {} {
    global UI_PREFIX

    foreach_startupitem {
        if {${si_type} ne "none" && [tbool si_create]} {
            ui_notice "$UI_PREFIX [msgcat::mc "Creating ${si_type} control script '$si_name'"]"

            switch -- ${si_type} {
                launchd         { startupitem_create_darwin_launchd [array get si_dict] }
                default         { ui_error "$UI_PREFIX [msgcat::mc "Unrecognized startupitem type %s" ${si_type}]" }
            }
        }
    }
}

# Check if this port's startupitems are loaded
# Returns: list of loaded startupitems
proc portstartupitem::loaded {} {
    set launchctl_path ${portutil::autoconf::launchctl_path}
    if {$launchctl_path eq ""} {
        # assuming not loaded if there's no launchctl
        return {}
    }
    set ret {}
    global os.major sudo_user
    foreach_startupitem {
        if {$si_type ne "launchd"} {
            continue
        }
        if {$si_location eq "LaunchDaemons" && [getuid] == 0} {
            set uid 0
        } elseif {[info exists sudo_user]} {
            set uid [name_to_uid $sudo_user]
        } else {
            set uid [getuid]
        }
        if {${os.major} >= 14} {
            if {$si_location eq "LaunchDaemons"} {
                set domain system
            } else {
                set domain gui/${uid}
            }
            if {![catch {exec -ignorestderr $launchctl_path print ${domain}/${si_uniquename} >&/dev/null}]} {
                lappend ret $si_name
            }
        } elseif {${os.major} >= 9} {
            if {![catch {exec_as_uid $uid {system "$launchctl_path list ${si_uniquename} > /dev/null"}}]} {
                lappend ret $si_name
            }
        } else {
            if {![catch {exec_as_uid $uid {system "$launchctl_path list | grep -F ${si_uniquename} > /dev/null"}}]} {
                lappend ret $si_name
            }
        }
    }
    return $ret
}

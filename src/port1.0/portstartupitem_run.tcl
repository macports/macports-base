# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
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

package provide portstartupitem_run 1.0

namespace eval portstartupitem {

# Helper: link given .plist into the correct location
proc install_darwin_launchd {srcpath dstdir install} {
    global destroot prefix
    if {[getuid] == 0 && $install} {
        file mkdir ${destroot}/Library/${dstdir}
        ln -sf $srcpath ${destroot}/Library/${dstdir}
    } else {
        ln -sf $srcpath ${destroot}${prefix}/etc/${dstdir}
    }
}

proc startupitem_create_darwin_launchd {attrs} {
    global UI_PREFIX prefix destroot destroot.keepdirs subport macosx_deployment_target

    set uniquename      [dict get $attrs uniquename]
    set plistname       [dict get $attrs plist]
    set daemondest      [dict get $attrs location]
    set itemdir         ${prefix}/etc/${daemondest}/${uniquename}

    file mkdir ${destroot}${itemdir}
    if {[getuid] == 0} {
        file attributes ${destroot}${itemdir} -owner root -group wheel
    }

    if {[dict get $attrs custom_file] ne ""} {
        # The port is supplying its own plist
        file copy [dict get $attrs custom_file] ${destroot}${itemdir}/${plistname}
        install_darwin_launchd ${itemdir}/${plistname} $daemondest [dict get $attrs install]
        return
    }

    set scriptdir ${prefix}/etc/startup

    set itemname        [dict get $attrs name]
    set username        [dict get $attrs user]
    set groupname       [dict get $attrs group]
    set args            [list \
                          "${prefix}/bin/daemondo" \
                          "--label=${itemname}" \
                        ]

    if {[dict get $attrs executable] ne "" &&
        [dict get $attrs init] eq "" &&
        [dict get $attrs start] eq "" &&
        [dict get $attrs stop] eq "" &&
        [dict get $attrs restart] eq ""} {

        # An executable is specified, and there is no init, start, stop, or restart
        # code; so we don't need a wrapper script
        set args [concat $args "--start-cmd" [dict get $attrs executable] ";"]

    } else {

        # No executable was specified, or there was an init, start, stop, or restart
        # option, so we do need a wrapper script

        set wrappername     ${itemname}.wrapper
        set wrapper         "${itemdir}/${wrappername}"

        if {[dict get $attrs start] eq ""} {
            dict set attrs start [list "sh ${scriptdir}/${subport}.sh start"]
        }
        if {[dict get $attrs stop] eq ""} {
            dict set attrs stop [list "sh ${scriptdir}/${subport}.sh stop"]
        }
        if {[dict get $attrs restart] eq ""} {
            dict set attrs restart [list Stop Start]
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
        foreach line [dict get $attrs init]    { puts ${item} ${line} }
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Start"
        puts ${item} "#"
        puts ${item} "Start()"
        puts ${item} "\{"
        foreach line [dict get $attrs start]   { puts ${item} "\t${line}" }
        puts ${item} "\}"
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Stop"
        puts ${item} "#"
        puts ${item} "Stop()"
        puts ${item} "\{"
        foreach line [dict get $attrs stop]    { puts ${item} "\t${line}" }
        puts ${item} "\}"
        puts ${item} ""

        puts ${item} "#"
        puts ${item} "# Restart"
        puts ${item} "#"
        puts ${item} "Restart()"
        puts ${item} "\{"
        foreach line [dict get $attrs restart] { puts ${item} "\t${line}" }
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

    if {[dict get $attrs netchange]} {
        lappend args "--restart-netchange"
    }

    # To log events then tell daemondo to log at verbosity=n
    if {[dict get $attrs logevents]} {
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
    set pidfileArgCnt [llength [dict get $attrs pidfile]]
    if {${pidfileArgCnt} > 0} {
        if { $pidfileArgCnt == 1 } {
            set pidFile "${prefix}/var/run/${itemname}.pid"
            if {"${destroot}${prefix}/var/run" ni ${destroot.keepdirs}} {
                lappend destroot.keepdirs "${destroot}${prefix}/var/run"
            }
        } else {
            set pidFile [lindex [dict get $attrs pidfile] 1]
        }

        if {${pidfileArgCnt} > 2} {
            ui_error "$UI_PREFIX [msgcat::mc "Invalid parameter count to startupitem.pidfile: 2 expected, %d found" ${pidfileArgCnt}]"
        }

        # Translate into appropriate arguments to daemondo
        set pidStyle [lindex [dict get $attrs pidfile] 0]
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
        if {[dict get $attrs executable] ne ""} {
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
    puts ${plist} "<key>KeepAlive</key><true/>"

    if {$username ne ""} {
        puts ${plist} "<key>UserName</key><string>$username</string>"
    }

    if {$groupname ne ""} {
        puts ${plist} "<key>GroupName</key><string>$groupname</string>"
    }

    if {[dict get $attrs logfile] ne ""} {
        puts ${plist} "<key>StandardOutPath</key><string>[dict get $attrs logfile]</string>"
    }

    if {[dict get $attrs logfile.stderr] ne ""} {
        puts ${plist} "<key>StandardErrorPath</key><string>[dict get $attrs logfile.stderr]</string>"
    }

    if {[dict get $attrs debug]} {
        puts ${plist} "<key>Debug</key><true/>"
    }

    puts ${plist} "</dict>"
    puts ${plist} "</plist>"

    close ${plist}

    install_darwin_launchd ${itemdir}/${plistname} $daemondest [dict get $attrs install]
}

proc startupitem_create {} {
    global UI_PREFIX

    foreach_startupitem {
        if {${si_type} ne "none" && ([tbool si_create] || $si_custom_file ne "")} {
            if {[tbool si_create]} {
                ui_debug "Creating ${si_type} control script '$si_name'"
            } else {
                ui_debug "Installing ${si_type} control script '$si_name'"
            }

            switch -- ${si_type} {
                launchd         { startupitem_create_darwin_launchd $si_dict }
                default         { ui_error "$UI_PREFIX [msgcat::mc "Unrecognized startupitem type %s" ${si_type}]" }
            }
        }
    }
}

# Check if this port's startupitems are loaded
# Returns: list of loaded startupitems
proc loaded {} {
    set launchctl_path ${::portutil::autoconf::launchctl_path}
    if {$launchctl_path eq ""} {
        # assuming not loaded if there's no launchctl
        return [list]
    }
    set ret [list]
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
        } else {
            if {![catch {exec_as_uid $uid {system "$launchctl_path list ${si_uniquename} > /dev/null"}}]} {
                lappend ret $si_name
            }
        }
    }
    return $ret
}

}

# et:ts=4
# portunload.tcl
#
# Copyright (c) 2007, 2009, 2011 The MacPorts Project
# Copyright (c) 2007 James D. Berry
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
# 3. Neither the name of The MacPorts Project nor the names of its contributors
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

package provide portunload 1.0
package require portutil 1.0

set org.macports.unload [target_new org.macports.unload portunload::unload_main]
target_runtype ${org.macports.unload} always
target_state ${org.macports.unload} no
target_provides ${org.macports.unload} unload 
target_requires ${org.macports.unload} main

namespace eval portunload {
}

options unload.asroot

set_ui_prefix

proc portunload::unload_main {args} {
    global UI_PREFIX prefix subport sudo_user
    set launchctl_path ${portutil::autoconf::launchctl_path}

    portstartupitem::foreach_startupitem {
        if {$si_install} {
            set path /Library/${si_location}/${si_plist}
        } else {
            set path ${prefix}/etc/${si_location}/${si_plist}
        }
        if {$launchctl_path eq ""} {
            return -code error [format [msgcat::mc "launchctl command was not found by configure"]]
        } elseif {![file exists $path]} {
            return -code error [format [msgcat::mc "Launchd plist %s was not found"] $path]
        } else {
            set skip 0
            if {$si_location eq "LaunchDaemons"} {
                if {[getuid] == 0} {
                    set uid 0
                } else {
                    ui_warn [format [msgcat::mc "Skipping unload of startupitem '%s' for %s, root privileges required"] $si_name $subport]
                    set skip 1
                }
            } elseif {[getuid] == 0} {
                if {[info exists sudo_user]} {
                    set uid [name_to_uid $sudo_user]
                } else {
                    ui_warn [format [msgcat::mc "Unloading per-user startupitem '%s' for %s as root"] $si_name $subport]
                    set uid 0
                }
            } else {
                set uid [getuid]
            }
            if {!$skip} {
                ui_notice "$UI_PREFIX [format [msgcat::mc "Unloading startupitem '%s' for %s"] $si_name $subport]"
                exec_as_uid $uid {system "$launchctl_path unload -w $path"}
            }
        }
    }

    return
}

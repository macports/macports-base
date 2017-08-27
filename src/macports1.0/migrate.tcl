#!@TCLSH@
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2017 The MacPorts Project
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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

package provide migrate 1.0

package require macports 1.0
package require registry 1.0
package require Pextlib 1.0
package require snapshot 1.0
package require restore 1.0
package require registry_uninstall 2.0

namespace eval migrate {

    proc main {opts} {
        # The main function. Calls each individual function that needs to be run.
        #
        # Args:
        #           opts - options array.
        # Returns:
        #           None

        array set options $opts

        # create a snapshot
        ui_msg "$macports::ui_prefix Taking a snapshot of the current state.."
        set snapshot [snapshot::main $opts]
        set id [$snapshot id]
        set note [$snapshot note]
        set datetime [$snapshot created_at]
        ui_msg "$macports::ui_prefix Done: snapshot '$id':'$note' created at $datetime"

        if {[info exists macports::ui_options(questions_yesno)]} {
            set msg "Migration will first uninstall all the installed ports and then reinstall."
            set retvalue [$macports::ui_options(questions_yesno) $msg "MigrationPrompt" "" {y} 0 "Would you like to continue?"]
            if {$retvalue == 0} {
                ui_msg "$macports::ui_prefix Uninstalling all ports.."
                uninstall_installed [registry::entry imaged]
            } else {
                ui_msg "Not uninstalling ports."
                return 0
            }
        }

        ui_msg "$macports::ui_prefix Fetching ports to install.."
        set snapshot_portlist [$snapshot ports]

        ui_msg "$macports::ui_prefix Restoring the original state.."
        restore::restore_state $snapshot_portlist

        # TODO: CLEAN PARTIAL BUILDS STEP HERE
        return 1
    }

    proc uninstall_installed {portlist} {
        set portlist [portlist_sort_dependencies_later [registry::entry imaged]]
        foreach port $portlist {
            ui_msg "Uninstalling: [$port name]"
            if {[registry::run_target $port uninstall]} {
                continue
            } else {
                ui_error "Error uninstalling [$port name]"
            }
        }
    }
}

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# migrate.tcl
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
package require snapshot 1.0
package require restore 1.0
package require selfupdate 1.0

namespace eval migrate {
    proc main {opts} {
        # The main function. Calls each individual step in order.
        #
        # Args:
        #           opts - options array.
        # Returns:
        #           0 if success

        array set options $opts

        # create a snapshot
        ui_msg "Taking a snapshot of the current state..."
        set snapshot [snapshot::main $opts]
        set id [$snapshot id]
        set note [$snapshot note]
        set datetime [$snapshot created_at]
        ui_msg "Done: Snapshot '$id' : '$note' created at $datetime"

        if {[info exists macports::ui_options(questions_yesno)]} {
            set msg "Migration will first uninstall all the installed ports, upgrade MacPorts and then reinstall them again."
            set retvalue [$macports::ui_options(questions_yesno) $msg "MigrationPrompt" "" {y} 0 "Would you like to continue?"]
            if {$retvalue == 1} {
                # quit as user answered 'no'
                ui_msg "Not uninstalling ports."
                return 0
            }
        }

        ui_msg "Uninstalling all ports..."
        uninstall_installed

        ui_msg "Upgrading MacPorts..."
        if {[catch {upgrade_port_command} result]} {
            ui_debug $::errorInfo
            ui_msg "Upgrading port command failed. Try running 'sudo port -v selfupdate' and then, 'sudo port restore --last'"
            return 1
        }

        ui_msg "You need to run 'port restore --last' to complete the migration."
        return 0
    }

    proc uninstall_installed {} {
        set options {}
        set portlist [restore::portlist_sort_dependencies_later [registry::entry imaged]]
        foreach port $portlist {
            ui_msg "Uninstalling: [$port name]"
            if {[registry::run_target $port uninstall $options]} {
                continue
            } else {
                ui_error "Error uninstalling [$port name]"
            }
        }
    }

    proc upgrade_port_command {} {
        array set optionslist {}
        # forced selfupdate
        set optionslist(ports_force) 1
        # shouldn't sync ports tree
        set optionslist(ports_selfupdate_nosync) 1
        set updatestatusvar {}
        return [uplevel [list selfupdate::main [array get optionslist] $updatestatusvar]]
    }
}

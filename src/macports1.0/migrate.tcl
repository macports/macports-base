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
    ##
    # The main function. Calls each individual step in order.
    #
    # @returns 0 on success, -999 when MacPorts base has been upgraded and the
    #          caller should re-run itself and invoke migration with the --continue
    #          flag set.
    proc main {opts} {
        array set options $opts

        if {[needs_migration]} {
            if {[info exists macports::ui_options(questions_yesno)]} {
                set msg "Migration will first upgrade MacPorts and then reinstall all installed ports."
                set retvalue [$macports::ui_options(questions_yesno) $msg "MigrationPrompt" "" {y} 0 "Would you like to continue?"]
                if {$retvalue == 1} {
                    # quit as user answered 'no'
                    ui_msg "Aborting migration. You can re-run 'sudo port migrate' later or follow the migration instructions: https://trac.macports.org/wiki/Migration"
                    return 0
                }
            }

            ui_msg "Upgrading MacPorts..."
            set success no
            if {[catch {set success [upgrade_port_command]} result]} {
                ui_debug $::errorInfo
                ui_error "Upgrading port command failed. Try running 'sudo port -v selfupdate' and then 'sudo port migrate'."
                return 1
            }
            if {!$success} {
                ui_error "Upgrading port command failed or was not attempted. Please re-install MacPorts manually and then run 'sudo port migrate' again."
                return 1
            }

            # MacPorts successfully upgraded, automatically re-run migration
            # from the new MacPorts installation
            return -999
        }

        # If port migrate was not called with --continue, the user probably did
        # that manually and we do not have confirmation to run migration yet;
        # do that now.
        set continuation [expr {[info exists options(ports_migrate_continue)] && $options(ports_migrate_continue)}]
        if {!$continuation && [info exists macports::ui_options(questions_yesno)]} {
            set msg "Migration will reinstall all installed ports."
            set retvalue [$macports::ui_options(questions_yesno) $msg "MigrationContinuationPrompt" "" {y} 0 "Would you like to continue?"]
            if {$retvalue == 1} {
                # quit as user answered 'no'
                ui_msg "Aborting migration. You can re-run 'sudo port migrate' later or follow the migration instructions: https://trac.macports.org/wiki/Migration"
                return 0
            }
        }

        # create a snapshot
        ui_msg "Taking a snapshot of the current state..."
        set snapshot [snapshot::main $opts]
        if {$snapshot == 0} {
            return -1
        }

        ui_msg "Uninstalling all ports..."
        uninstall_installed

        ui_msg "Restoring ports..."
        return [restore_snapshot [$snapshot id]]
    }

    ##
    # Check whether the current platform is the one this installation was
    # configured for. Returns true, if migration is needed, false otherwise.
    #
    # @return true iff the migration procedure is needed
    proc needs_migration {} {
        if {$macports::os_platform ne $macports::autoconf::os_platform} {
            return 1
        }
        if {$macports::os_major != $macports::autoconf::os_major} {
            return 1
        }
        return 0
    }

    ##
    # Uninstall all installed ports for migration
    #
    # @return void on success, raises an error on failure
    proc uninstall_installed {} {
        set options {}
        set portlist [restore::sort_portlist_dependencies_later [registry::entry imaged]]
        foreach port $portlist {
            ui_msg "Uninstalling: [$port name]"
            if {![registry::run_target $port uninstall $options]} {
                ui_error "Error uninstalling [$port name]"
            }
        }
    }

    ##
    # Restore the list of ports from the snapshot created above by migrate.
    #
    # @return 0 on success, an error on failure
    proc restore_snapshot {id} {
        array set options {}
        set options(ports_restore_snapshot-id) $id
        return [restore::main [array get options]]
    }

    ##
    # Run MacPorts selfupdate, but avoid downgrading pre-release installations
    #
    # Will return true on success, false if no error occured but MacPorts was
    # not re-installed (e.g. because the currently installed version is newer
    # than the downloaded release). If reinstallation fails, an error is
    # raised.
    #
    # @return true on success, false if no update was performed, an error on
    #         failure.
    proc upgrade_port_command {} {
        array set optionslist {}
        # Force rebuild, but do not allow downgrade
        set optionslist(ports_selfupdate_migrate) 1
        # Avoid portindex, which would trigger 'portindex', which does not work
        set optionslist(ports_selfupdate_nosync) 1

        selfupdate::main [array get optionslist] base_updated
        return $base_updated
    }
}

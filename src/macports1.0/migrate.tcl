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

        if {[check_toolchain]} {
            return 1
        }

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
            if {[catch {set status [upgrade_port_command]} result]} {
                ui_debug $::errorInfo
                ui_error "Upgrading port command failed. Try running 'sudo port -v selfupdate' and then 'sudo port migrate'."
                return 1
            }
            if {![dict get $status base_updated]} {
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
        set continuation [expr {[dict exists $opts ports_migrate_continue] && [dict get $opts ports_migrate_continue]}]
        if {!$continuation && [info exists macports::ui_options(questions_yesno)]} {
            set msg "Migration will reinstall all installed ports."
            set retvalue [$macports::ui_options(questions_yesno) $msg "MigrationContinuationPrompt" "" {y} 0 "Would you like to continue?"]
            if {$retvalue == 1} {
                # quit as user answered 'no'
                ui_msg "Aborting migration. You can re-run 'sudo port migrate' later or follow the migration instructions: https://trac.macports.org/wiki/Migration"
                return 0
            }
        }

        # Sync ports tree
        try {
            mportsync
        } on error {eMessage} {
            ui_error "Couldn't sync the ports tree: $eMessage"
            return 1
        }

        # create a snapshot
        ui_msg "Taking a snapshot of the current state..."
        if {[catch {snapshot::create $opts} snapshot] || $snapshot == 0} {
            return -1
        }
        set id [$snapshot id]
        set note [$snapshot note]
        set datetime [$snapshot created_at]
        ui_msg "Done: Snapshot '$id' : '$note' created at $datetime"

        ui_msg "Deactivating all ports..."
        restore::deactivate_all

        lassign [get_intree_archs] ports_in_tree_archs mport_list
        # get_intree_archs opens Portfiles. Leaving them open for now because
        # restore_snapshot will want to use the same ones.

        ui_msg "Uninstalling ports that need to be reinstalled..."
        uninstall_incompatible $ports_in_tree_archs

        ui_msg "Restoring ports..."
        set ret [restore_snapshot $opts]

        # Close mports that get_intree_archs opened
        foreach mport $mport_list {
            mportclose $mport
        }

        return $ret
    }

    # Check that Xcode and/or CLTs are usable
    proc check_toolchain {} {
        global macports::macos_version_major macports::xcodeversion \
               macports::xcodecltversion macports::os_platform

        if {$os_platform ne "darwin"} {
            return 0
        }
        
        lassign [macports::get_compatible_xcode_versions] min ok rec
        if {[vercmp $macos_version_major >= "10.9"]} {
            if {$xcodecltversion ne "none"} {
                if {[vercmp $xcodecltversion < $min]} {
                    ui_error "The installed Xcode Command Line Tools are too old."
                    ui_error "Version $xcodecltversion installed; at least $min required."
                    ui_error "Run Software Update or follow <https://trac.macports.org/wiki/ProblemHotlist#reinstall-clt>"
                    return 1
                }
                return 0
            } elseif {[file exists "/Library/Developer/CommandLineTools/"]} {
                ui_error "The Xcode Command Line Tools package appears to be installed, but its receipt appears to be missing."
                ui_error "The Command Line Tools may be outdated, which can cause problems."
                ui_error "Please see: <https://trac.macports.org/wiki/ProblemHotlist#reinstall-clt>"
                return 1
            }
        }
        if {$xcodeversion ne "none"} {
            if {[vercmp $xcodeversion < $min]} {
                ui_error "The installed version of Xcode is too old."
                ui_error "Version $xcodeversion installed; at least $min required."
                ui_error "(If you have multiple versions installed, you may need to select a newer one using xcode-select.)"
                return 1
            }
            return 0
        }
        ui_error "Neither Xcode nor the Command Line Tools appear to be installed."
        ui_error "See <https://guide.macports.org/#installing.xcode>"
        return 1
    }

    ##
    # Open the current in-tree Portfile for each installed port,
    # using the recorded requested variants, and figure out its archs.
    #
    # @return a list of two elements:
    #   1. A dict mapping portname -> requested_variants -> archs
    #   2. A list of the mport handles for the opened Portfiles.
    proc get_intree_archs {} {
        set fancy_output [expr {![macports::ui_isset ports_debug] && [info exists macports::ui_options(progress_generic)]}]
        if {$fancy_output} {
            set progress $macports::ui_options(progress_generic)
        } else {
            proc noop {args} {}
            set progress noop
        }

        set intree_archs [dict create]
        set mports [list]

        ui_msg "$macports::ui_prefix Loading Portfiles"
        $progress start
        set portfile_counter 0
        set installed_ports [registry::entry imaged]
        set portfile_total [llength $installed_ports]
        $progress update $portfile_counter $portfile_total

        foreach port $installed_ports {
            set portname [$port name]
            set requested_variants [$port requested_variants]
            if {[dict exists $intree_archs $portname $requested_variants]} {
                incr portfile_counter
                $progress update $portfile_counter $portfile_total
                continue
            }
            set variations [restore::variants_to_variations_arr $requested_variants]
            # Set same options as restore code so it's more likely the open mports
            # can be reused rather than having to be opened again.
            set options [dict create ports_requested [$port requested] subport $portname]
            lassign [mportlookup $portname] portname portinfo
            if {$portname eq "" ||
                [catch {mportopen [dict get $portinfo porturl] $options $variations} mport]
            } then {
                incr portfile_counter
                $progress update $portfile_counter $portfile_total
                continue
            }
            set workername [ditem_key $mport workername]
            set mport_archs [$workername eval [list get_canonical_archs]]
            dict set intree_archs $portname $requested_variants $mport_archs
            lappend mports $mport

            incr portfile_counter
            $progress update $portfile_counter $portfile_total
        }
        $progress finish

        return [list $intree_archs $mports]
    }

    ##
    # Check whether the current platform is the one this installation was
    # configured for. Returns true, if migration is needed, false otherwise.
    #
    # @return true iff the migration procedure is needed
    proc needs_migration {{reasonvar {}}} {
        global macports::os_platform macports::os_major macports::build_arch
        if {$reasonvar ne {}} {
            upvar $reasonvar reason
            set reason {}
        }
        if {$os_platform ne $macports::autoconf::os_platform
            || ($os_platform eq "darwin" && $os_major != $macports::autoconf::os_major)
        } then {
            set reason "Current platform \"$os_platform $os_major\" does not match expected platform \"$macports::autoconf::os_platform $macports::autoconf::os_major\""
            return 1
        }
        if {$os_platform eq "darwin" && $os_major >= 20 && $build_arch ne "x86_64"
                && ![catch {sysctl sysctl.proc_translated} translated] && $translated
        } then {
            # Check if our tclsh has an arm64 slice - rebuilding not needed if it's universal
            set h [machista::create_handle]
            set rlist [machista::parse_file $h $macports::autoconf::tclsh_path]
            if {[lindex $rlist 0] == $machista::SUCCESS} {
                set r [lindex $rlist 1]
                set a [$r cget -mt_archs]
                set has_arm64 0
                while {$a ne "NULL"} {
                    set arch [machista::get_arch_name [$a cget -mat_arch]]
                    if {$arch eq "arm64"} {
                        set has_arm64 1
                        break
                    }
                    set a [$a cget -next]
                }
            }
            machista::destroy_handle $h
            if {[info exists has_arm64] && !$has_arm64} {
                set reason "MacPorts is running through Rosetta 2, and should be rebuilt for Apple Silicon"
                return 1
            }
        }
        return 0
    }

    ##
    # Uninstall installed ports that are not compatible with the
    # current platform, or that would build for a different arch with
    # the current configuration.
    #
    # @return void on success, raises an error on failure
    proc uninstall_incompatible {ports_in_tree_archs} {
        set options [dict create ports_nodepcheck 1 ports_force 1]
        set portlist [restore::deactivation_order [registry::entry imaged]]
        foreach port $portlist {
            set portname [$port name]
            if {![snapshot::_os_mismatch [$port os_platform] [$port os_major]]} {
                # Compatible with current platform, check that archs match
                set installed_reqvar [$port requested_variants]
                if {[dict exists $ports_in_tree_archs $portname $installed_reqvar]
                    && [dict get $ports_in_tree_archs $portname $installed_reqvar]
                        eq [$port archs]} {
                    continue
                }
            }
            ui_msg "Uninstalling: $portname"
            if {![registry::run_target $port uninstall $options]
                    && [catch {registry_uninstall::uninstall $portname [$port version] [$port revision] [$port variants] $options} result]} {
                ui_error "Error uninstalling ${portname}: $result"
            }
        }
    }

    ##
    # Restore the list of ports from the latest snapshot using the equivalent
    # of 'port restore --last'
    #
    # @return 0 on success, an error on failure
    proc restore_snapshot {opts} {
        dict set opts ports_restore_last yes
        if {[dict exists $opts ports_migrate_all]} {
            dict set opts ports_restore_all [dict get $opts ports_migrate_all]
        }

        return [restore::main $opts]
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
        set options [dict create]
        # Force rebuild, but do not allow downgrade
        dict set options ports_selfupdate_migrate 1
        # Avoid portindex, which would trigger 'portindex', which does not work
        dict set options ports_selfupdate_nosync 1

        selfupdate::main $options selfupdate_status
        return $selfupdate_status
    }
}

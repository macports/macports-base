# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# restore.tcl
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

package provide restore 1.0

package require macports 1.0
package require migrate 1.0
package require registry 1.0
package require snapshot 1.0

namespace eval restore {
    proc main {opts} {
        # The main function. If the action is provided a snapshot id, then it deactivates
        # all the current ports and restores the specified snapshot.
        #
        # If '--last', then it assumes that this is a continution step of migration and
        # no need of deactivating, since no ports exist. It simply sorts and installs the
        # last snapshot ports
        #
        # If none, then it lists the last k (or all) snapshots with id for the user to
        # choose from. Deactivates and installs the selected snapshot.
        #
        # Args:
        #           opts - options array.
        # Returns:
        #           0 if success

        array set options $opts

        if {[migrate::needs_migration]} {
            ui_error "You need to run 'sudo port migrate' before running restore"
            return 1
        }

        if {[info exists options(ports_restore_snapshot-id)]} {
            # use the specified snapshot
            set snapshot [fetch_snapshot $options(ports_restore_snapshot-id)]
            ui_msg "Deactivating all ports installed.."
            deactivate_all
        } elseif {[info exists options(ports_restore_last)]} {
            set snapshot [fetch_snapshot_last]
        } else {
            set snapshots [list_snapshots]
            set human_readable_snapshots {}
            foreach snapshot $snapshots {
                lappend human_readable_snapshots "[$snapshot note], created at [$snapshot created_at] (ID: [$snapshot id])"
            }

            if {[llength $snapshots] == 0} {
                ui_error "There are no snapshots to restore. You must run 'sudo port snapshot' first."
                return 1
            }

            set retstring [$macports::ui_options(questions_singlechoice) "Select any one snapshot to restore:" "" $human_readable_snapshots]
            set snapshot [lindex $snapshots $retstring]

            ui_msg "Deactivating all ports installed.."
            deactivate_all
        }

        ui_msg "Restoring snapshot '[$snapshot note]' created at [$snapshot created_at]"

        ui_msg "Fetching ports to install..."
        set snapshot_portlist [$snapshot ports]

        ui_msg "Restoring the selected snapshot.."
        restore_state [$snapshot ports]

        return 0
    }

    proc fetch_snapshot {snapshot_id} {
        return [registry::snapshot get_by_id $snapshot_id]
    }

    proc fetch_snapshot_last {} {
        return [registry::snapshot get_last]
    }

    proc list_snapshots {} {
        return [registry::snapshot get_all]
    }

    proc portlist_sort_dependencies_later {portlist} {

        # Sorts a list of port references such that ports come before
        # their dependencies. Ideal for uninstalling a port.
        #
        # Args:
        #       portlist - the list of port references
        #
        # Returns:
        #       the list in dependency-sorted order

        foreach port $portlist {
            set portname [$port name]
            lappend entries($portname) $port
            # Avoid adding ports in loop
            if {![info exists dependents($portname)]} {
                set dependents($portname) {}
                foreach result [$port dependents] {
                    lappend dependents($portname) [$result name]
                }
            }
        }
        set ret {}
        foreach port $portlist {
            portlist_sort_dependencies_later_helper $port entries dependents seen ret
        }
        return $ret
    }

    proc portlist_sort_dependencies_later_helper {port up_entries up_dependents up_seen up_retlist} {
        upvar 1 $up_seen seen
        if {![info exists seen($port)]} {
            set seen($port) 1
            upvar 1 $up_entries entries $up_dependents dependents $up_retlist retlist
            set name [$port name]
            foreach dependent $dependents($name) {
                if {[info exists entries($dependent)]} {
                    foreach entry $entries($dependent) {
                        portlist_sort_dependencies_later_helper $entry entries dependents seen retlist
                    }
                }
            }
            lappend retlist $port
        }
    }

    proc deactivate_all {} {
        set portlist [portlist_sort_dependencies_later [registry::entry imaged]]
        foreach port $portlist {
            ui_msg "Deactivating: [$port name]"
            if {[$port state] eq "installed"} {
                if {[registry::run_target $port deactivate {}]} {
                    continue
                }
            }
        }
    }

    proc portlist_sort_dependencies_first {portlist} {

        # Sorts a list of port references such that ports appear after
        # their dependencies. Ideal for installing a port.
        #
        # Args:
        #       portlist - the list of port references
        #
        # Returns:
        #       the list in dependency-sorted order

        array set port_installed {}
        array set port_deps {}
        array set port_in_list {}

        set new_list [list]

        foreach port $portlist {

            set name [lindex $port 0]
            set requested [lindex $port 1]
            if {$requested eq 0} {
                continue
            }
            set active 0
            if {[lindex $port 2] eq "installed"} {
                set active 1
            }
            set variantstr [lindex $port 3]
            if {$variantstr eq "(null)"} {
                set variantstr ""
            }
            set variants ""
            if {[info exists variantstr]} {
                while 1 {
                    set nextplus [string last + $variantstr]
                    set nextminus [string last - $variantstr]
                    if {$nextplus > $nextminus} {
                        set next $nextplus
                        set sign +
                    } else {
                        set next $nextminus
                        set sign -
                    }
                    if {$next == -1} {
                        break
                    }
                    set v [string range $variantstr [expr $next + 1] end]
                    lappend variants $v $sign
                    set variantstr [string range $variantstr 0 [expr $next - 1]]
                }
            }
            if {![info exists port_in_list($name)]} {
                set port_in_list($name) 1
                set port_installed($name) 0
            } else {
                incr port_in_list($name)
            }

            if {![info exists port_deps(${name},${variants})]} {
                set port_deps(${name},${variants}) [portlist_sort_dependencies_first_helper $name $variants]
            }
            lappend new_list [list $name $variants $active]
        }

        set operation_list [list]
        while {[llength $new_list] > 0} {

            set oldLen [llength $new_list]
            foreach port $new_list {
                foreach {name variants active} $port break

                # Ensure active versions are installed after inactive versions.
                # Skip this port if it is active and all the inactive versions have
                # not been added to the operation_list.
                if {$active && $port_installed($name) < ($port_in_list($name) - 1)} {
                    continue
                }
                set installable 1
                foreach dep $port_deps(${name},${variants}) {
                    if {[info exists port_installed($dep)] && $port_installed($dep) == 0} {
                        set installable 0
                        break
                    }
                }
                if {$installable} {
                    lappend operation_list [list $name $variants $active]
                    incr port_installed($name)
                    set index [lsearch $new_list [list $name $variants $active]]
                    set new_list [lreplace $new_list $index $index]
                }
            }
            if {[llength $new_list] == $oldLen} {
                return -code error "Stuck in loop"
            }
        }
        return $operation_list
    }

    proc portlist_sort_dependencies_first_helper {portname variant_info} {
        set dependency_list [list]
        set port_search_result [mportlookup $portname]
        if {[llength $port_search_result] < 2} {
            ui_warn "Skipping $portname (not in the ports tree)"
            return $dependency_list
        }
        array set portinfo [lindex $port_search_result 1]
        if {[catch {set mport [mportopen $portinfo(porturl) [list subport $portinfo(name)] $variant_info]} result]} {
            global errorInfo
            puts stderr "$errorInfo"
            return -code error "Unable to open port '$portname': $result"
        }
        array unset portinfo
        array set portinfo [mportinfo $mport]
        mportclose $mport
        set dependency_types { depends_fetch depends_extract depends_build depends_lib depends_run }
        foreach dependency_type $dependency_types {
            if {[info exists portinfo($dependency_type)] && [string length $portinfo($dependency_type)] > 0} {
                foreach dependency $portinfo($dependency_type) {
                    lappend dependency_list [lindex [split $dependency:] end]
                }
            }
        }
        return $dependency_list
    }

    proc restore_state {snapshot_portlist} {
        ui_msg "Installing ports:"
        set snapshot_portlist [lsort -index 0 -nocase $snapshot_portlist]

        foreach port $snapshot_portlist {
            # 0: port name
            # 1: requested (0/1)
            # 2: state (imaged/installed, i.e. inactive/active)
            # 3: variants
            if {[lindex $port 1] == 1} {
                # Hide unrequested ports
                if {[lindex $port 2] eq "installed"} {
                    ui_msg "   [lindex $port 0] [lindex $port 3]"
                } else {
                    ui_msg "   [lindex $port 0] [lindex $port 3] (inactive)"
                }
            }
        }

        set sorted_snapshot_portlist [portlist_sort_dependencies_first $snapshot_portlist]
        foreach port $sorted_snapshot_portlist {

            set name [string trim [lindex $port 0]]
            set variations [lindex $port 1]
            set active [lindex $port 2]

            if {!$active} {
                set target install
                ui_msg "Installing (not activating): $name $variations"
            } else {
                set target activate
                ui_msg "Installing (and activating): $name $variations"
            }

            if {[catch {set res [mportlookup $name]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                return -code error "lookup of port $name failed: $result"
            }
            if {[llength $res] < 2} {
                # not in the index, but we already warned about that earlier
                continue
            }
            array unset portinfo
            array set portinfo [lindex $res 1]
            set porturl $portinfo(porturl)

            set options(ports_requested) 1
            set options(subport) $portinfo(name)

            if {[catch {set workername [mportopen $porturl [array get options] $variations]} result]} {
                global errorInfo
                puts stderr "$errorInfo"
                return -code error "Unable to open port '$name': $result"
            }

            if {[catch {set result [mportexec $workername $target]} result]} {
                global errorInfo
                mportclose $workername
                ui_msg "$errorInfo"
                return -code error "Unable to execute target 'install' for port '$name': $result"
            } else {
                mportclose $workername
            }
            # TODO: some ports may get re-activated to fulfil dependencies - recheck?
        }
    }
}

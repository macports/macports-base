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
package require macports_dlist 1.0
package require migrate 1.0
package require registry 1.0
package require snapshot 1.0

package require struct::graph 2.4
package require struct::graph::op 0.11
package require lambda 1

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
        } elseif {[info exists options(ports_restore_last)]} {
            # use the last snapshot
            set snapshot [fetch_snapshot_last]
        } else {
            # ask the user to select a snapshot
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
        }

        ui_msg "$macports::ui_prefix Deactivating all installed ports"
        deactivate_all

        ui_msg "$macports::ui_prefix Restoring snapshot '[$snapshot note]' created at [$snapshot created_at]"
        set snapshot_portlist [$snapshot ports]
        array set failed [restore_state [$snapshot ports]]

        if {[array size failed] > 0} {
            set note "Migration finished with errors.\n"
        } else {
            set note "Migration finished.\n"
        }

        if {[info exists macports::ui_options(notifications_system)]} {
            $macports::ui_options(notifications_system) $note
        } else {
            ui_msg $note
        }

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

    ##
    # Sorts a list of port references such that ports come before their
    # dependencies. Ideal for uninstalling all ports.
    #
    # Args:
    #       portlist - the list of port references
    #
    # Returns:
    #       the list in order such that leaves are first
    proc deactivation_order {portlist} {
        # Create a graph where each edge means "is dependent of". A topological
        # sort of this graph should return leaves (i.e., ports which have no
        # dependents) first.
        #
        # We're going to use Tarjan's algorithm for this, which also deals
        # which potential cycles.

        set dependents [::struct::graph]

        array set entries {}

        foreach port $portlist {
            set portname [$port name]
            set entries($portname) $port

            if {![$dependents node exists $portname]} {
                $dependents node insert $portname
            }

            foreach dependent [$port dependents] {
                set dependent_name [$dependent name]
                if {![$dependents node exists $dependent_name]} {
                    $dependents node insert $dependent_name
                }

                $dependents arc insert $portname $dependent_name
            }
        }

        # Compute a list of strongly connected components using Tarjan's
        # algorithm. This list should contain one-element lists (unless there
        # are dependency cycles).
        set portlist_sccs [::struct::graph::op::tarjan $dependents]
        set operations {}

        foreach scc $portlist_sccs {
            foreach portname $scc {
                lappend operations $entries($portname)
            }
        }

        $dependents destroy

        return $operations
    }

    ##
    # Deactivate all installed ports in reverse dependency order so that as few
    # warnings as possible will be printed.
    proc deactivate_all {} {
        set portlist [deactivation_order [registry::entry imaged]]

        foreach port $portlist {
            if {[$port state] eq "installed"} {
                if {![registry::run_target $port deactivate {ports_force 1}]} {
                    if {[catch {portimage::deactivate [$port name] [$port version] [$port revision] [$port variants] {ports_force 1}} result]} {
                        ui_debug $::errorInfo
                        ui_warn "Failed to deactivate [$port name]: $result"
                    }
                }
            }
        }
    }

    ##
    # Convert a variant string into a serialized array of variations suitable for passing to mportopen
    proc variants_to_variations_arr {variantstr} {
        set split_variants_re {([-+])([[:alpha:]_]+[\w\.]*)}
        set result {}

        foreach {match sign variant} [regexp -all -inline -- $split_variants_re $variantstr] {
            lappend result $variant $sign
        }

        return $result
    }

    ##
    # Sorts a list of port references such that ports appear after their
    # dependencies. Ideal for installing a port.
    #
    # Args:
    #       portlist - the list of port references
    #
    # Returns:
    #       The list in dependency-sorted order
    #       The dependency graph, to be destroyed by calling $dependencies destroy
    proc resolve_dependencies {portlist} {
        array set ports {}
        array set dep_ports {}
        set dependencies [::struct::graph]

        set requested_counter 0
        set requested_total 0

        set fancy_output [expr {![macports::ui_isset ports_debug] && [info exists macports::ui_options(progress_generic)]}]
        if {$fancy_output} {
            set progress $macports::ui_options(progress_generic)
        } else {
            proc noop {args} {}
            set progress noop
        }

        if {$fancy_output} {
            ui_msg "$macports::ui_prefix Computing dependency order"
        } else {
            ui_msg "$macports::ui_prefix Computing dependency order. This will take a while, please be patient"
            flush stdout
        }
        $progress start

        # Populate $ports so that we can look up requested variants given the
        # port name.
        foreach port $portlist {
            lassign $port name requested active _ variants

            # bool-ify active
            set active [expr {$active eq "installed"}]
            set ports($name) [list $requested $active $variants]

            if {$requested} {
                incr requested_total
            }
        }

        $progress update $requested_counter $requested_total

        # Iterate over the requested ports to calculate the dependency tree.
        # Use a worklist so that we can push items to the front to do
        # depth-first dependency resolution.
        set worklist [list]
        set seen [list]
        array set seen_conflicts {}
        foreach port $portlist {
            lassign $port name requested _ _ _

            if {!$requested} {
                continue
            }

            lappend worklist $name
        }
        while {[llength $worklist] > 0} {
            set worklist [lassign $worklist portname]

            # If we've already seen this port, continue
            if {[lsearch -sorted -exact $seen $portname] != -1} {
                continue
            }
            lappend seen $portname
            set seen [lsort -ascii $seen]

            ui_debug "Dependency calculation for port $portname"

            # Find the port
            set port [mportlookup $portname]
            if {[llength $port] < 2} {
                $progress intermission
                ui_warn "Port $portname not found, skipping"
                $progress update $requested_counter $requested_total
                continue
            }

            if {[info exists ports($portname)]} {
                lassign $ports($portname) requested _ variants
            } elseif {[info exists dep_ports($portname)]} {
                set variants $dep_ports($portname)
                set requested 0
            } else {
                set variants ""
                set requested 0
            }

            # Open the port with the requested variants from the snapshot
            set variations [variants_to_variations_arr $variants]
            array set portinfo [lindex $port 1]
            if {[catch {set mport [mportopen $portinfo(porturl) [list subport $portinfo(name)] $variations]} result]} {
                $progress intermission
                error "Unable to open port '$portname': $result"
            }
            array unset portinfo

            # Compute the dependencies for the 'install' target. Do not recurse into the dependencies: we'll do that
            # here manually in order to
            #  (1) keep our dependency graph updated
            #  (2) use the requested variants when opening the dependencies
            #  (3) identify if an alternative provider was used based on the snapshot and the conflicts information
            #  (such as for example when a port depends on curl-ca-bundle, but the snapshot contains certsync, which
            #  conflicts with curl-ca-bundle).
            if {[mportdepends $mport install 0] != 0} {
                $progress intermission
                error "Unable to determine dependencies for port '$portname'"
            }

            set provides [ditem_key $mport provides]
            if {![$dependencies node exists $provides]} {
                $dependencies node insert $provides
            }
            foreach dependency [ditem_key $mport requires] {
                lassign [dlist_search $macports::open_mports provides $dependency] dep_ditem

                set conflict_found 0
                array set portinfo [mportinfo $dep_ditem]
                if {[info exists portinfo(conflicts)] && [llength $portinfo(conflicts)] > 0} {
                    foreach conflict $portinfo(conflicts) {
                        if {[info exists ports($conflict)]} {
                            # The conflicting port was installed in the snapshot. Assume that this happened because the
                            # conflicting port is an alternative provider for this dependency (e.g., curl-ca-bundle and
                            # certsync, or a -devel port replacing its non-devel variant).
                            #
                            # Do not add the dependency that mportdepends computed, but instead replace this dependency
                            # with the conflicting port.
                            #
                            # Warn only once for every combination, otherwise users might see the same message multiple
                            # times.
                            if {![info exists seen_conflicts($portinfo(name),$conflict)]} {
                                set seen_conflicts($portinfo(name),$conflict) 1

                                $progress intermission
                                ui_warn "Snapshot contains $conflict, which conflicts with dependency $portinfo(name); assuming $conflict provides the functionality of $portinfo(name)"
                                $progress update $requested_counter $requested_total
                            }

                            if {![$dependencies node exists $conflict]} {
                                $dependencies node insert $conflict
                            }

                            $dependencies arc insert $provides $conflict

                            set worklist [linsert $worklist 0 $conflict]
                            set conflict_found 1
                            break
                        }
                    }
                }
                array unset portinfo
                if {$conflict_found} {
                    continue
                }

                if {![$dependencies node exists $dependency]} {
                    $dependencies node insert $dependency
                }
                set dependency_requested_variants [[ditem_key $dep_ditem workername] eval {set requested_variants}]
                set dep_ports($dependency) $dependency_requested_variants

                $dependencies arc insert $provides $dependency
                set worklist [linsert $worklist 0 $dependency]
            }
            mportclose $mport

            if {$requested} {
                # Print a progress indicator if this is a requested port (or for every port if in verbose mode).
                incr requested_counter
            }
            $progress update $requested_counter $requested_total
        }

        $progress finish

        ui_msg "$macports::ui_prefix Sorting dependency tree"

        # Compute a list of stronly connected components using Tarjan's
        # algorithm. The result should be a list of one-element sets (unless
        # there are cylic dependencies, which there shouldn't be). Because of
        # how Tarjan's algorithm works, this list should be in topological
        # order, though. This is what we need for installation.
        set portlist_sccs [::struct::graph::op::tarjan $dependencies]
        set operations {}

        foreach scc $portlist_sccs {
            foreach name $scc {
                if {[info exists ports($name)]} {
                    lappend operations [list $name {*}$ports($name)]
                } elseif {[info exists dep_ports($name)]} {
                    lappend operations [list $name 0 1 $dep_ports($name)]
                } else {
                    lappend operations [list $name 0 1 {}]
                }
            }
        }

        return [list $operations $dependencies]
    }

    proc _handle_failure {failedName dependencies portname reason} {
        upvar $failedName failed

        set failed($portname) [list "failed" $reason]

        set level "#[info level]"

        $dependencies walk $portname \
            -type dfs \
            -order pre \
            -dir backward \
            -command [lambda {level mode dependencies node} {
                if {$mode eq "enter"} {
                    uplevel $level [subst -nocommands {
                        set failed($node) [list "skipped" "dependency \$portname failed"]
                    }]
                }
            } $level]
    }

    proc restore_state {snapshot_portlist} {
        lassign [resolve_dependencies $snapshot_portlist] sorted_snapshot_portlist dependencies

        # map from port name to an entry describing why the port failed or was
        # skipped
        array set failed {}

        set index 0
        set length [llength $sorted_snapshot_portlist]
        foreach port $sorted_snapshot_portlist {
            incr index
            lassign $port name requested active variants

            if {$variants ne ""} {
                ui_msg "$macports::ui_prefix $index/$length Restoring $name $variants from snapshot"
            } else {
                ui_msg "$macports::ui_prefix $index/$length Restoring $name from snapshot"
            }

            if {[info exists failed($name)]} {
                lassign $failed($name) type reason
                switch $type {
                    skipped {
                        ui_msg "$macports::ui_prefix Skipping $name because its $reason"
                    }
                    failed {
                        ui_msg "$macports::ui_prefix Skipping $name because it failed previously: $reason"
                    }
                    default {
                        ui_msg "$macports::ui_prefix Skipping $name: $reason"
                    }
                }

                continue
            }

            if {!$active} {
                set target install
            } else {
                set target activate
            }

            if {[catch {set res [mportlookup $name]} result]} {
                ui_debug "$::errorInfo"
                _handle_failure failed $dependencies $name "lookup of port $name failed: $result"
                continue
            }
            if {[llength $res] < 2} {
                # not in the index, but we already warned about that earlier
                _handle_failure failed $dependencies $name "port $name not found in the port index"
                continue
            }
            array unset portinfo
            array set portinfo [lindex $res 1]
            set porturl $portinfo(porturl)

            set options(ports_requested) $requested
            set options(subport) $portinfo(name)
            set variations [variants_to_variations_arr $variants]

            if {[catch {set workername [mportopen $porturl [array get options] $variations]} result]} {
                ui_msg $::errorInfo
                _handle_failure failed $dependencies $name "unable to open port $name: $result"
                continue
            }

            if {[catch {set result [mportexec $workername $target]} result]} {
                ui_msg "$::errorInfo"
                _handle_failure failed $dependencies $name "Unable to execute target $target for port $name: $result"
            } elseif {$result != 0} {
                _handle_failure failed $dependencies $name "Failed to $target $name"
            }
            mportclose $workername
        }

        $dependencies destroy

        return [array get failed]
    }
}

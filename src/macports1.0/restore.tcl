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
    variable ui_prefix
    variable mports

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

        set restore::ui_prefix [string map {--- ===} $macports::ui_prefix]

        if {[migrate::needs_migration]} {
            ui_error "You need to run 'sudo port migrate' before running restore"
            return 1
        }

        if {[dict exists $opts ports_restore_snapshot-id]} {
            # use the specified snapshot
            set snapshot [fetch_snapshot [dict get $opts ports_restore_snapshot-id]]
        } elseif {[dict exists $opts ports_restore_last]} {
            # use the last snapshot
            set snapshot [fetch_snapshot_last]
            if {$snapshot eq ""} {
                ui_error "There are no snapshots to restore. You must run 'sudo port snapshot' first."
                return 1
            }
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

            if {[info exists macports::ui_options(questions_singlechoice)]} {
                set retstring [$macports::ui_options(questions_singlechoice) "Select any one snapshot to restore:" "" $human_readable_snapshots]
                set snapshot [lindex $snapshots $retstring]
            } elseif {[llength $snapshots] == 1} {
                set snapshot [lindex $snapshots 0]
            } else {
                ui_error "Multiple snapshots exist, specify which one to restore using --snapshot-id or use\
                        --last to restore the most recent one."
                foreach s $human_readable_snapshots {
                    ui_msg $s
                }
                return 1
            }
        }
        set include_unrequested [expr {[dict exists $opts ports_restore_all]}]

        ui_msg "$restore::ui_prefix Deactivating all installed ports"
        deactivate_all

        ui_msg "$restore::ui_prefix Restoring snapshot '[$snapshot note]' created at [$snapshot created_at]"
        set failed [restore_state $snapshot $include_unrequested]

        if {[dict size $failed] > 0} {
            set note "Migration finished with errors.\n"
        } else {
            set note "Migration finished.\n"
        }

        array set diff [snapshot::diff $snapshot]

        if {!$include_unrequested} {
            foreach field {added removed changed} {
                set result {}
                foreach port $diff($field) {
                    lassign $port _ requested
                    if {$requested} {
                        lappend result $port
                    }
                }
                set diff($field) $result
            }
        }

        if {[llength $diff(added)] > 0} {
            append note "The following requested ports were additionally installed:\n"
            foreach added_port [lsort -ascii -index 0 $diff(added)] {
                lassign $added_port name _ _ _ requested_variants
                if {$requested_variants ne ""} {
                    append note " - $name\n"
                } else {
                    append note " - $name $requested_variants\n"
                }
            }
        }

        if {[llength $diff(removed)] > 0} {
            append note "The following ports could not be restored:\n"
            foreach removed_port [lsort -ascii -index 0 $diff(removed)] {
                lassign $removed_port name _ _ _ requested_variants
                if {$requested_variants ne ""} {
                    append note " - $name\n"
                } else {
                    append note " - $name $requested_variants\n"
                }
                if {[dict exists $failed $name]} {
                    lassign [dict get $failed $name] type reason
                    switch $type {
                        skipped {
                            append note "   Skipped because its $reason\n"
                        }
                        failed {
                            append note "   Failed: $reason\n"
                        }
                    }
                }
            }
        }

        # It's possible that a port's state changed because it failed
        # to activate, or it's a platform-independent port that stayed
        # installed but a dependency failed. Report that separately.
        set changed_and_failed {}
        set just_changed {}
        foreach changed_port $diff(changed) {
            set name [lindex $changed_port 0]
            if {[dict exists $failed $name]} {
                lappend changed_and_failed $changed_port
            } else {
                lappend just_changed $changed_port
            }
        }

        if {[llength $changed_and_failed] > 0} {
            append note "The following ports could not be fully restored:\n"
            foreach changed_port [lsort -ascii -index 0 $changed_and_failed] {
                lassign $changed_port name _ _ _ requested_variants changes
                if {$requested_variants ne ""} {
                    append note " - $name\n"
                } else {
                    append note " - $name $requested_variants\n"
                }
                lassign [dict get $failed $name] type reason
                switch $type {
                    skipped {
                        append note "   Skipped because its $reason\n"
                    }
                    failed {
                        append note "   Failed: $reason\n"
                    }
                }
                foreach change $changes {
                    lassign $change field old new
                    append note "   $field changed from '$old' to '$new'\n"
                }
            }
        }

        if {[llength $just_changed] > 0} {
            append note "The following ports were restored with changes:\n"
            foreach changed_port [lsort -ascii -index 0 $just_changed] {
                lassign $changed_port name _ _ _ requested_variants changes
                if {$requested_variants ne ""} {
                    append note " - $name\n"
                } else {
                    append note " - $name $requested_variants\n"
                }
                foreach change $changes {
                    lassign $change field old new
                    append note "   $field changed from '$old' to '$new'\n"
                }
            }
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

        set entries [dict create]

        foreach port $portlist {
            set portname [$port name]
            dict lappend entries $portname $port

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
                if {[dict exists $entries $portname]} {
                    lappend operations {*}[dict get $entries $portname]
                }
            }
        }

        $dependents destroy

        return $operations
    }

    ##
    # Deactivate all installed ports in reverse dependency order so that as few
    # warnings as possible will be printed.
    proc deactivate_all {} {
        set options [dict create ports_nodepcheck 1 ports_force 1]
        foreach port [deactivation_order [registry::entry installed]] {
            if {![registry::run_target $port deactivate $options]
                && [catch {portimage::deactivate [$port name] [$port version] [$port revision] [$port variants] $options} result]} {
                ui_debug $::errorInfo
                ui_warn "Failed to deactivate [$port name]: $result"
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

    # Get the port that satisfies a depspec, with respect to the files
    # in the snapshot for path-pased deps.
    proc resolve_depspec {depspec ports snapshot_id} {
        set remaining [lassign [split $depspec :] type next]
        if {$type eq "port"} {
            return $next
        }
        set portname [lindex $remaining end]
        if {[dict exists $ports $portname] && [lindex [dict get $ports $portname] 1]} {
            # Port is active in the snapshot.
            return $portname
        }
        switch $type {
            bin {
                variable binpaths
                if {![info exists binpaths]} {
                    set binpaths [list]
                    foreach p [split $::env(PATH) :] {
                        lappend binpaths $p
                    }
                }
                foreach path $binpaths {
                    set owners [snapshot::file_owner [file join $path $next] $snapshot_id]
                    if {$owners ne ""} {
                        break
                    }
                }
            }
            lib {
                global macports::prefix macports::frameworks_dir macports::os_platform
                set i [string first . $next]
                if {$i < 0} {set i [string length $next]}
                set depname [string range $next 0 $i-1]
                set depversion [string range $next $i end]
                if {${os_platform} eq "darwin"} {
                    set depfile ${depname}${depversion}.dylib
                } else {
                    set depfile ${depname}.so${depversion}
                }
                foreach path [list ${frameworks_dir} ${prefix}/lib] {
                    set owners [snapshot::file_owner [file join $path $depfile] $snapshot_id]
                    if {$owners ne ""} {
                        break
                    }
                }
            }
            path {
                global macports::prefix
                set owners [snapshot::file_owner [file join $prefix $next] $snapshot_id]
            }
        }
        if {[info exists owners]} {
            if {[llength $owners] > 1} {
                ui_warn "File for $depspec owned by multiple ports in snapshot, using first match"
            }
            return [lindex $owners 0]
        }
        return {}
    }

    ##
    # Sorts a list of port references such that ports appear after their
    # dependencies. Ideal for installing a port.
    #
    # Args:
    #       snapshot - the snapshot from which to get the list of port references
    #
    # Returns:
    #       The list in dependency-sorted order
    #       The dependency graph, to be destroyed by calling $dependencies destroy
    proc resolve_dependencies {snapshot {include_unrequested 0}} {
        variable mports
        set portlist [$snapshot ports]
        set ports [dict create]
        set dep_ports [dict create]
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
            ui_msg "$restore::ui_prefix Computing dependency order"
        } else {
            ui_msg "$restore::ui_prefix Computing dependency order. This will take a while, please be patient"
            flush stdout
        }
        $progress start

        # Populate $ports so that we can look up requested variants given the
        # port name.
        foreach port $portlist {
            lassign $port name requested active _ requested_variants

            # bool-ify active
            set active [expr {$active eq "installed"}]
            dict set ports $name [list $requested $active $requested_variants]

            if {$requested} {
                incr requested_total
            }
        }

        $progress update $requested_counter $requested_total

        # Iterate over the requested ports to calculate the dependency tree.
        # Use a worklist so that we can push items to the front to do
        # depth-first dependency resolution.
        set worklist [list]
        set required_archs [dict create]
        set snapshot_id [$snapshot id]
        foreach port $portlist {
            lassign $port name requested _ _ _

            if {!$requested && !$include_unrequested} {
                continue
            }

            lappend worklist $name
        }
        while {[llength $worklist] > 0} {
            set worklist [lassign $worklist portname]

            # If we've already seen this port, continue
            if {[dict exists $mports $portname] &&
                [macports::_mport_supports_archs [dict get $mports $portname] [dict get $required_archs $portname]]} {
                continue
            }

            ui_debug "Dependency calculation for port $portname"

            # Find the port
            set port [mportlookup $portname]
            if {[llength $port] < 2} {
                $progress intermission
                ui_warn "Port $portname not found, skipping"
                $progress update $requested_counter $requested_total
                continue
            }
            lassign $port portname portinfo

            if {[dict exists $ports $portname]} {
                lassign [dict get $ports $portname] requested _ requested_variants
            } elseif {[dict exists $dep_ports $portname]} {
                set requested_variants [dict get $dep_ports $portname]
                set requested 0
            } else {
                set requested_variants ""
                set requested 0
            }
            set porturl [dict get $portinfo porturl]

            # Open the port with the requested variants from the snapshot
            if {![dict exists $mports $portname]} {
                set options [dict create ports_requested $requested subport $portname]
                set variations [variants_to_variations_arr $requested_variants]
                if {[catch {set mport [mportopen $porturl $options $variations]} result]} {
                    $progress intermission
                    ui_error "Unable to open port '$portname' with variants '$requested_variants': $result"
                    continue
                }
                dict set mports $portname $mport
                if {![dict exists $required_archs $portname]} {
                    dict set required_archs $portname [list]
                }
            } else {
                set mport [dict get $mports $portname]
            }
            set portinfo [mportinfo $mport]

            # Check archs and re-open with +universal if needed (and possible)
            if {[dict exists $portinfo installs_libs] && ![dict get $portinfo installs_libs]} {
                dict set required_archs $portname [list]
            }
            if {![macports::_mport_supports_archs $mport [dict get $required_archs $portname]]
                && [dict exists $portinfo variants] && "universal" in [dict get $portinfo variants]} {
                set variations [ditem_key $mport variations]
                if {!([dict exists $variations universal] && [dict get $variations universal] eq "+")} {
                    dict set variations universal +
                    set options [dict create ports_requested $requested subport $portname]
                    if {![catch {set universal_mport [mportopen $porturl $options $variations]}]} {
                        if {[macports::_mport_supports_archs $universal_mport [dict get $required_archs $portname]]} {
                            mportclose $mport
                            set mport $universal_mport
                            dict set mports $portname $mport
                            set requested_variants [_mportkey $mport requested_variants]
                            if {[dict exists $ports $portname]} {
                                set ports_entry [dict get $ports $portname]
                                lset ports_entry 2 $requested_variants
                                dict set ports $portname $ports_entry
                            } elseif {[dict exists $dep_ports $portname]} {
                                dict set dep_ports $portname $requested_variants
                            }
                        } else {
                            mportclose $universal_mport
                            # Requirement can't be satisfied, so don't bother checking again
                            # (an error will occur regardless when we actually try to install)
                            dict set required_archs $portname [list]
                        }
                    }
                }
            }

            # Compute the dependencies for the 'install' target. Do not recurse into the dependencies: we'll do that
            # here manually in order to
            #  (1) keep our dependency graph updated
            #  (2) use the requested variants when opening the dependencies
            #  (3) identify if an alternative provider was used based on the snapshot and the conflicts information
            #  (such as for example when a port depends on curl-ca-bundle, but the snapshot contains certsync, which
            #  conflicts with curl-ca-bundle).
            set workername [ditem_key $mport workername]
            set deptypes [macports::_deptypes_for_target install $workername]
            set port_archs [$workername eval [list get_canonical_archs]]
            set depends_skip_archcheck [_mportkey $mport depends_skip_archcheck]

            set provides [ditem_key $mport provides]
            if {![$dependencies node exists $provides]} {
                $dependencies node insert $provides
            }
            foreach deptype $deptypes {
                if {![dict exists $portinfo $deptype]} {
                    continue
                }
                set check_archs [expr {$port_archs ne "noarch" && [macports::_deptype_needs_archcheck $deptype]}]
                foreach depspec [dict get $portinfo $deptype] {
                    set dependency [resolve_depspec $depspec $ports $snapshot_id]
                    if {$dependency eq ""} {
                        # Not fulfilled by a port in the snapshot. Check if
                        # it needs to be fulfilled by any port. (This is safe
                        # because all ports are inactive at this point.)
                        set dependency [$workername eval [list _get_dep_port $depspec]]
                        if {$dependency eq ""} {
                            continue
                        }
                    }
                    if {$check_archs && [lsearch -exact -nocase $depends_skip_archcheck $dependency] == -1} {
                        if {![dict exists $required_archs $dependency]} {
                            dict set required_archs $dependency $port_archs
                        } else {
                            set dep_required_archs [dict get $required_archs $dependency]
                            foreach arch $port_archs {
                                if {$arch ni $dep_required_archs} {
                                    lappend dep_required_archs $arch
                                }
                            }
                            dict set required_archs $dependency $dep_required_archs
                        }
                    }
                    if {![$dependencies node exists $dependency]} {
                        $dependencies node insert $dependency
                    }
                    if {[dict exists $ports $dependency]} {
                        set dependency_requested_variants [lindex [dict get $ports $dependency] 2]
                    } else {
                        set dependency_requested_variants {}
                    }
                    dict set dep_ports $dependency $dependency_requested_variants

                    $dependencies arc insert $provides $dependency
                    set worklist [linsert $worklist 0 $dependency]
                }
            }

            if {$requested} {
                # Print a progress indicator if this is a requested port (or for every port if in verbose mode).
                incr requested_counter
            }
            $progress update $requested_counter $requested_total
        }

        $progress finish

        ui_msg "$restore::ui_prefix Sorting dependency tree"

        # Compute a list of stronly connected components using Tarjan's
        # algorithm. The result should be a list of one-element sets (unless
        # there are cylic dependencies, which there shouldn't be). Because of
        # how Tarjan's algorithm works, this list should be in topological
        # order, though. This is what we need for installation.
        set portlist_sccs [::struct::graph::op::tarjan $dependencies]
        set operations {}

        foreach scc $portlist_sccs {
            foreach name $scc {
                if {[dict exists $ports $name]} {
                    lappend operations [list $name {*}[dict get $ports $name]]
                } elseif {[dict exists $dep_ports $name]} {
                    lappend operations [list $name 0 1 [dict get $dep_ports $name]]
                } else {
                    lappend operations [list $name 0 1 {}]
                }
            }
        }

        return [list $operations $dependencies]
    }

    proc _handle_failure {failedName dependencies portname reason} {
        upvar $failedName failed

        dict set failed $portname [list "failed" $reason]

        set level "#[info level]"

        $dependencies walk $portname \
            -type dfs \
            -order pre \
            -dir backward \
            -command [lambda {level mode dependencies node} {
                if {$mode eq "enter"} {
                    uplevel $level [subst -nocommands {
                        if {![dict exists \$failed $node]} {
                            dict set failed $node [list "skipped" "dependency \$portname failed"]
                        }
                    }]
                }
            } $level]
    }

    proc restore_state {snapshot {include_unrequested 0}} {
        variable mports [dict create]
        lassign [resolve_dependencies $snapshot $include_unrequested] sorted_snapshot_portlist dependencies

        # map from port name to an entry describing why the port failed or was
        # skipped
        set failed [dict create]

        set index 0
        set length [llength $sorted_snapshot_portlist]
        foreach port $sorted_snapshot_portlist {
            incr index
            lassign $port name requested active requested_variants

            if {$requested_variants ne ""} {
                ui_msg "$restore::ui_prefix Restoring port $index of $length: $name $requested_variants"
            } else {
                ui_msg "$restore::ui_prefix Restoring port $index of $length: $name"
            }

            if {[dict exists $failed $name]} {
                lassign [dict get $failed $name] type reason
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
                set install_target install
            } else {
                set install_target activate
            }

            if {[catch {set res [mportlookup $name]} result]} {
                ui_debug $::errorInfo
                _handle_failure failed $dependencies $name "lookup of port $name failed: $result"
                continue
            }
            if {[llength $res] < 2} {
                # not in the index, but we already warned about that earlier
                _handle_failure failed $dependencies $name "port $name not found in the port index"
                continue
            }
            lassign $res portname portinfo
            if {![dict exists $mports $portname]} {
                set porturl [dict get $portinfo porturl]
                set options [dict create ports_requested $requested subport $portname]
                set variations [variants_to_variations_arr $requested_variants]

                if {[catch {set mport [mportopen $porturl $options $variations]} result]} {
                    ui_debug $::errorInfo
                    _handle_failure failed $dependencies $name "unable to open port $name: $result"
                    continue
                }
                dict set mports $portname $mport
            } else {
                set mport [dict get $mports $portname]
            }

            foreach target [list clean $install_target] {
                if {[catch {set result [mportexec $mport $target]} result]} {
                    ui_msg $::errorInfo
                    _handle_failure failed $dependencies $name "Unable to execute target '$target' for port $name: $result"
                } elseif {$result != 0} {
                    _handle_failure failed $dependencies $name "Unable to execute target '$target' for port $name - see its log for details"
                }
            }
            mportclose $mport
            dict unset mports $portname
        }

        $dependencies destroy
        foreach mport [dict values $mports] {
            mportclose $mport
        }

        return $failed
    }
}

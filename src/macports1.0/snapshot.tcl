# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# snapshot.tcl
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

package provide snapshot 1.0

package require macports 1.0
package require registry 1.0

namespace eval snapshot {
	proc main {opts} {
		# Function to create a snapshot of the current state of ports.
        #
        # Args:
        #           opts - The options passed in.
        # Returns:
        #           registry::snapshot

        if {![dict exists $opts options_snapshot_order]} {
            set operation "create"
        } else {
            set operation ""
            foreach op {list create diff delete} {
                set opname "ports_snapshot_$op"
                if {[dict exists $opts $opname]} {
                    if {$operation ne ""} {
                        ui_error "Only one of the --list, --create, --diff, and --delete options can be specified."
                        error "Incorrect usage, see port snapshot --help."
                    }

                    set operation $op
                }
            }
        }

        if {[dict exists $opts ports_snapshot_help]} {
            ui_msg "Usage: One of:"
            ui_msg "  port snapshot \[--create\] \[--note '<message>'\]"
            ui_msg "  port snapshot --list"
            ui_msg "  port snapshot --diff <snapshot-id> \[--requested-only\]"
            ui_msg "  port snapshot --delete <snapshot-id>"
            return 0
        }

        switch $operation {
            "create" {
                return [create $opts]
            }
            "list" {
                ui_error "list operation not implemented"
            }
            "diff" {
                set snapshot [registry::snapshot get_by_id [dict get $opts ports_snapshot_diff]]
                array set diff [diff $snapshot]
                set show_all [dict exists $opts ports_snapshot_all]
                set note ""

                if {!$show_all} {
                    append note "Showing differences in requested ports only. Re-run with --all to see all differences.\n"

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
                    append note "The following ports are installed but not in the snapshot:\n"
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
                    append note "The following ports are in the snapshot but not installed:\n"
                    foreach removed_port [lsort -ascii -index 0 $diff(removed)] {
                        lassign $removed_port name _ _ _ requested_variants
                        if {$requested_variants ne ""} {
                            append note " - $name\n"
                        } else {
                            append note " - $name $requested_variants\n"
                        }
                    }
                }

                if {[llength $diff(changed)] > 0} {
                    append note "The following ports are in the snapshot and installed, but with changes:\n"
                    foreach changed_port [lsort -ascii -index 0 $diff(changed)] {
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

                ui_msg [string trimright $note "\n"]
            }
            "delete" {
                ui_error "delete operation not implemented"
            }
        }
    }

    proc create {opts} {

        registry::write {
            # An option used by user while creating snapshot manually
            # to identify a snapshot, usually followed by `port restore`
            if {[dict exists $opts ports_snapshot_note]} {
                set note [dict get $opts ports_snapshot_note]
            } else {
                set note "snapshot created for migration"
            }
            set inactive_ports [list]
            foreach port [registry::entry imaged] {
                if {[$port state] eq "imaged"} {
                    lappend inactive_ports "[$port name] @[$port version]_[$port revision] [$port variants]"
                }
            }
            if {[llength $inactive_ports] != 0} {
                set msg "Following inactive ports will not be a part of this snapshot and won't be installed while restoring:"
                set inactive_ports [lsort -index 0 -nocase $inactive_ports]
                if {[info exists macports::ui_options(questions_yesno)]} {
                    set retvalue [$macports::ui_options(questions_yesno) $msg "Continue?" $inactive_ports {y} 0]
                    if {$retvalue != 0} {
                        ui_msg "Not creating a snapshot!"
                        return 0
                    }
                } else {
                    puts $msg
                    foreach port $inactive_ports {
                        puts $port
                    }
                }
            }
            set snapshot [registry::snapshot create $note]
        }
        return $snapshot
    }

    proc _os_mismatch {iplatform iosmajor} {
        if {($iplatform ne "" && $iosmajor != 0) && ($iplatform != $macports::os_platform || $iosmajor != $macports::os_major)} {
            return 1
        }
        return 0
    }

    proc _find_best_match {port installed} {
        lassign $port name requested active variants requested_variants
        set active [expr {$active eq "installed"}]
        set requested [expr {$requested == 1}]

        set best_match {}
        set best_match_score -1
        foreach iport $installed {
            lassign $iport iname iversion irevision ivariants iactive iepoch
            set regref [registry::open_entry $iname $iversion $irevision $ivariants $iepoch]
            set iplatform [registry::property_retrieve $regref os_platform]
            set iosmajor [registry::property_retrieve $regref os_major]
            set irequested [expr {[registry::property_retrieve $regref requested] == 1}]
            set irequested_variants [registry::property_retrieve $regref requested_variants]

            if {[_os_mismatch $iplatform $iosmajor]} {
                # ignore ports that were not built on the current macOS version
                continue
            }

            set score 0

            if {$irequested_variants eq $requested_variants} {
                incr score
            }
            if {$irequested == $requested} {
                incr score
            }
            if {$ivariants eq $variants} {
                incr score
            }
            if {$active == $iactive} {
                incr score
            }

            if {$score > $best_match_score} {
                set best_match_score $score
                set best_match [list {*}$iport $irequested $irequested_variants]
            }
        }

        return $best_match
    }

    ##
    # Compute the difference between the given snapshot registry object, and
    # the currently installed ports.
    #
    # Callers that do not care about differences in unrequested ports are
    # expected to filter the results themselves.
    #
    # Args:
    #       snapshot - The snapshot object
    # Returns:
    #       A array in list form with the three entries removed, added, and
    #       changed. Each array value is a list with entries that were removed,
    #       added, or changed. The format is as follows:
    #       - Added entries: a 5-tuple of (name, requested, active, variants, requested variants)
    #       - Removed entries: a 5-tuple of (name, requested, active, variants, requested variants)
    #       - Changed entries: a 6-typle of (name, requested, active, variants, requested variants, changes)
    #       where changes is a list of 3-tuples of (changed field, old value, new value)
    proc diff {snapshot} {
        set portlist [$snapshot ports]

        set removed {}
        set added {}
        set changed {}

        set snapshot_ports [dict create]

        foreach port $portlist {
            lassign $port name requested active variants requested_variants
            set active [expr {$active eq "installed"}]
            set requested [expr {$requested == 1}]

            dict set snapshot_ports $name 1

            if {[catch {set installed [registry::installed $name]}]} {
                # registry::installed failed, the port probably isn't installed
                lappend removed $port
                continue
            }

            if {$active} {
                # for ports that were active in the snapshot, always compare
                # with the installed active port, if any
                set found 0
                foreach installed_port $installed {
                    lassign $installed_port iname iversion irevision ivariants iactive iepoch
                    set regref [registry::open_entry $iname $iversion $irevision $ivariants $iepoch]
                    set iplatform [registry::property_retrieve $regref os_platform]
                    set iosmajor [registry::property_retrieve $regref os_major]
                    set irequested [expr {[registry::property_retrieve $regref requested] == 1}]
                    set irequested_variants [registry::property_retrieve $regref requested_variants]

                    if {[_os_mismatch $iplatform $iosmajor]} {
                        # ignore ports that were not built on the current macOS version
                        continue
                    }

                    if {$iactive} {
                        set found 1
                        break
                    }
                }

                if {$found} {
                    set changes {}
                    if {$requested_variants ne $irequested_variants} {
                        lappend changes [list "requested variants" $requested_variants $irequested_variants]
                    }
                    if {$variants ne $ivariants} {
                        lappend changes [list "variants" $variants $ivariants]
                    }
                    if {$requested != $irequested} {
                        lappend changes [list "requested" \
                            [expr {$requested == 1 ? "requested" : "unrequested"}] \
                            [expr {$irequested == 1 ? "requested" : "unrequested"}]]
                    }
                    if {[llength $changes] > 0} {
                        lappend changed [list {*}$port $changes]
                    }
                    continue
                }
            }

            # Either the port wasn't active in the snapshot, or the port is now no longer active.
            # This may still mean that it is missing completely, e.g., because only the version for an older OS is installed
            set best_match [_find_best_match $port $installed]
            if {[llength $best_match] <= 0} {
                # There is no matching port, so it seems this one is actually missing
                lappend removed $port
                continue
            } else {
                lassign $best_match iname iversion irevision ivariants iactive iepoch irequested irequested_variants

                set changes {}
                if {$requested_variants ne $irequested_variants} {
                    lappend changes [list "requested variants" $requested_variants $irequested_variants]
                }
                if {$variants ne $ivariants} {
                    lappend changes [list "variants" $variants $ivariants]
                }
                if {$requested != $irequested} {
                    lappend changes [list "requested" \
                        [expr {$requested == 1 ? "requested" : "unrequested $requested"}] \
                        [expr {$irequested == 1 ? "requested" : "unrequested $irequested"}]]
                }
                if {$active != $iactive} {
                    lappend changes [list "state" \
                        [expr {$active == 1 ? "installed" : "inactive"}] \
                        [expr {$iactive == 1 ? "installed" : "inactive"}]]
                }
                if {[llength $changes] > 0} {
                    lappend changed [list {*}$port $changes]
                }
            }
        }

        foreach port [registry::entry imaged] {
            lassign $installed_port iname iversion irevision ivariants iactive iepoch
            set regref [registry::open_entry $iname $iversion $irevision $ivariants $iepoch]
            set iplatform [registry::property_retrieve $regref os_platform]
            set iosmajor [registry::property_retrieve $regref os_major]
            set irequested [registry::property_retrieve $regref requested]
            set irequested_variants [registry::property_retrieve $regref requested_variants]

            if {[_os_mismatch $iplatform $iosmajor]} {
                # port was installed on old OS, ignore
                continue
            }
            if {[dict exists $snapshot_ports $iname]} {
                # port was in the snapshot
                continue
            }

            # port was not in the snapshot, it is new
            lappend added [list $iname $irequested $iactive $ivariants $irequested_variants]
        }

        return [list removed $removed added $added changed $changed]
    }
}

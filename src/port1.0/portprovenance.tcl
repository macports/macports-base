# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portprovenance.tcl
#
# Copyright (c) 2026 The MacPorts Project
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

package provide portprovenance 1.0

namespace eval portprovenance {
    variable tracked_options [list]
    variable option_provenance [list]
    variable scope_stack [list [dict create scope global]]
}

# portprovenance overview
#
# This module records executed Portfile option mutations so consumers can map
# evaluated option state back to the source command text that produced it.
# It is intended for tools that need both the semantic meaning of an option
# and the exact Portfile commands that were active when the Portfile was
# evaluated.
#
# How it works:
#
# Consumers first register the options they care about with track_option.
# The generic handle_option* helpers in portutil then call
# record_option_provenance after a tracked mutation succeeds. The recorder
# walks the Tcl frame stack to find the actual Portfile mutation command
# frame, such as "checksums", "checksums-append", or "revision", and stores
# a record describing that executed command.
#
# Each record contains the option name, mutation action, source file,
# command text, optional line number, optional evaluated arguments, the
# current PortInfo(name), and an explicit scope record. Scope defaults to the
# top-level "global" Portfile scope. Callers such as subport or variant_run
# can push and pop explicit scope records so later mutations are tagged as
# belonging to a specific subport instead of the top-level port definition.
#
# The recorder is inert unless an option has been registered with
# track_option, which keeps provenance collection additive and opt-in for
# consumers that need it.
#
# Usage example:
#
#     portprovenance::track_option checksums
#     portprovenance::track_option revision
#
#     # During Portfile evaluation, handle_option and friends call
#     # record_option_provenance automatically for tracked options.
#
#     set checksum_records [portprovenance::get_option_provenance checksums]
#     set revision_records [portprovenance::get_option_provenance revision]
#
#     # One record looks like:
#     # {
#     #     option checksums
#     #     action append
#     #     file /path/to/Portfile
#     #     line 42
#     #     cmd {checksums-append docs.tar.xz ...}
#     #     args {docs.tar.xz rmd160 ...}
#     #     portname git
#     #     scope subport
#     #     scope_name git-devel
#     # }

# mutation_command_name
#
# Return the Portfile command name associated with an option mutation action.
#
proc portprovenance::mutation_command_name {option action} {
    switch -- $action {
        set {
            return $option
        }
        append -
        prepend -
        delete -
        strsed -
        replace {
            return "${option}-${action}"
        }
    }

    return {}
}

# record_scope
#
# Return the recorded provenance scope for one command, defaulting to global.
#
proc portprovenance::record_scope {command_record} {
    if {[dict exists $command_record scope]} {
        return [dict get $command_record scope]
    }

    return global
}

# record_applies_to_subport
#
# Return whether one recorded mutation applies to the selected subport.
#
proc portprovenance::record_applies_to_subport {command_record selected_subport} {
    switch -- [record_scope $command_record] {
        subport {
            if {$selected_subport eq {} || ![dict exists $command_record scope_name]} {
                return no
            }

            return [string equal -nocase [dict get $command_record scope_name] $selected_subport]
        }
        default {
            return yes
        }
    }
}

# track_option
#
# Record provenance for the specified option when it is mutated.
#
proc portprovenance::track_option {option} {
    variable tracked_options

    if {$option ni $tracked_options} {
        lappend tracked_options $option
    }
}

# reset_option_provenance
#
# Clear the recorded option provenance entries.
#
proc portprovenance::reset_option_provenance {} {
    variable option_provenance

    set option_provenance [list]
}

# default_scope_record
#
# Return the default provenance scope record for top-level Portfile code.
#
proc portprovenance::default_scope_record {} {
    return [dict create scope global]
}

# reset_scope
#
# Reset the active provenance scope to the top-level Portfile scope.
#
proc portprovenance::reset_scope {} {
    variable scope_stack

    set scope_stack [list [default_scope_record]]
}

# current_scope
#
# Return the currently active provenance scope record.
#
proc portprovenance::current_scope {} {
    variable scope_stack

    if {![llength $scope_stack]} {
        return [default_scope_record]
    }

    return [lindex $scope_stack end]
}

# push_scope_record
#
# Push one explicit provenance scope record onto the active scope stack.
#
proc portprovenance::push_scope_record {scope_record} {
    variable scope_stack

    if {![dict exists $scope_record scope]} {
        return -code error "invalid provenance scope record"
    }

    lappend scope_stack $scope_record
}

# push_scope
#
# Push one provenance scope with an optional scope name onto the active stack.
#
proc portprovenance::push_scope {scope {scope_name {}}} {
    set scope_record [dict create scope $scope]

    if {$scope_name ne {}} {
        dict set scope_record scope_name $scope_name
    }

    push_scope_record $scope_record
}

# pop_scope
#
# Pop the innermost provenance scope from the active scope stack.
#
proc portprovenance::pop_scope {} {
    variable scope_stack

    if {[llength $scope_stack] > 1} {
        set scope_stack [lrange $scope_stack 0 end-1]
    }
}

# matches_mutation_command
#
# Return whether a frame executes the requested Portfile mutation command.
#
proc portprovenance::matches_mutation_command {frame command_name} {
    if {$command_name eq {} || ![dict exists $frame cmd]} {
        return no
    }

    if {[catch {set frame_command [lindex [dict get $frame cmd] 0]}]} {
        return no
    }

    return [expr {$frame_command eq $command_name}]
}

# find_source_frame
#
# Return the frame for the executed Portfile mutation command itself.
#
proc portprovenance::find_source_frame {option action} {
    global portpath

    set command_name [mutation_command_name $option $action]

    # Walk outward until we find the Portfile command itself rather than one of
    # the generic wrappers that eventually called record_option_provenance.
    for {set level 1} {![catch {set frame [info frame $level]}]} {incr level} {
        if {![matches_mutation_command $frame $command_name]} {
            continue
        }

        # Variant bodies and other uplevel paths can lose file metadata, so use
        # the current Portfile path when the frame does not provide one.
        if {![dict exists $frame file] && [info exists portpath]} {
            dict set frame file [file join $portpath Portfile]
        }

        return $frame
    }

    return {}
}

# record_option_provenance
#
# Record one executed mutation for a tracked option.
#
proc portprovenance::record_option_provenance {option action args} {
    variable tracked_options
    variable option_provenance
    global PortInfo subport

    if {$option ni $tracked_options} {
        return
    }

    # Provenance is best-effort metadata and must never change option-mutation
    # behavior if source discovery fails.
    if {[catch {
        set frame [find_source_frame $option $action]
        if {$frame ne {}} {
            set record [dict create \
                option $option \
                action $action \
                file [file normalize [dict get $frame file]] \
                cmd [dict get $frame cmd]]

            # Snapshot the active scope onto the record so later consumers do not have
            # to reconstruct subport/variant context from the current interpreter state.
            dict for {key value} [current_scope] {
                dict set record $key $value
            }

            if {[dict exists $frame line]} {
                dict set record line [dict get $frame line]
            }
            if {[llength $args]} {
                dict set record args $args
            }
            if {[info exists subport]} {
                dict set record subport $subport
            }
            if {[info exists PortInfo(name)]} {
                dict set record portname $PortInfo(name)
            }

            lappend option_provenance $record
        }
    }]} {
        return
    }
}

# get_option_provenance
#
# Return the recorded provenance entries for the requested option.
#
proc portprovenance::get_option_provenance {option {filters {}}} {
    variable option_provenance

    set records [list]

    foreach record $option_provenance {
        if {[dict get $record option] ne $option} {
            continue
        }

        set include yes
        # Keep filtering simple and additive: each supplied key/value pair must
        # match exactly on the recorded dict entry.
        foreach {key value} $filters {
            if {![dict exists $record $key] || [dict get $record $key] ne $value} {
                set include no
                break
            }
        }

        if {$include} {
            lappend records $record
        }
    }

    return $records
}

# has_option_provenance
#
# Return whether provenance was recorded for the given option in this Portfile.
#
proc portprovenance::has_option_provenance {option portfile} {
    set normalized_portfile [file normalize $portfile]

    foreach command_record [get_option_provenance $option] {
        if {[dict get $command_record file] eq $normalized_portfile} {
            return yes
        }
    }

    return no
}

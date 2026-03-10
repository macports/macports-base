# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portsource.tcl
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

package provide portsource 1.0
package require portutil 1.0
package require portprovenance 1.0

namespace eval portsource {
}

# portsource overview
#
# This module provides helpers for locating Portfile commands in source text
# and matching executed provenance records back to those source spans.
#
# normalize_command_text
#
# Collapse command whitespace so source text can be matched against recorded
# commands.
#
proc portsource::normalize_command_text {command_text} {
    set words [list]

    foreach word [regexp -all -inline {\S+} [string trim $command_text]] {
        # Drop standalone continuation tokens so info frame command text and
        # literal Portfile source normalize to the same word sequence.
        if {$word eq "\\"} {
            continue
        }

        lappend words $word
    }

    return [join $words " "]
}

# find_portfile_commands
#
# Locate complete Portfile commands by name and return their source spans.
#
proc portsource::find_portfile_commands {portfile_contents command_names} {
    set commands [list]
    set offset 0
    set line_number 1
    set escaped_names [list]

    foreach command_name $command_names {
        lappend escaped_names [quotemeta $command_name]
    }

    set command_pattern [format {^[[:space:]]*(%s)\y} [join $escaped_names |]]

    while {$offset < [string length $portfile_contents]} {
        set current_line $line_number
        set newline_index [string first "\n" $portfile_contents $offset]
        if {$newline_index < 0} {
            set next_offset [string length $portfile_contents]
        } else {
            set next_offset [expr {$newline_index + 1}]
        }

        set line [string range $portfile_contents $offset [expr {$next_offset - 1}]]
        if {[regexp -- $command_pattern $line -> command_name]} {
            set start $offset
            set command_text $line
            set end [expr {$next_offset - 1}]
            set offset $next_offset
            incr line_number

            # Source matching works at the Tcl-command level, so keep consuming
            # physical lines until the full command is syntactically complete.
            while {![info complete $command_text] && $offset < [string length $portfile_contents]} {
                set newline_index [string first "\n" $portfile_contents $offset]
                if {$newline_index < 0} {
                    set next_offset [string length $portfile_contents]
                } else {
                    set next_offset [expr {$newline_index + 1}]
                }

                append command_text [string range $portfile_contents $offset [expr {$next_offset - 1}]]
                set end [expr {$next_offset - 1}]
                set offset $next_offset
                incr line_number
            }

            lappend commands [dict create \
                start $start \
                end $end \
                line $current_line \
                text $command_text \
                normalized [normalize_command_text $command_text] \
                command_name $command_name]
            continue
        }

        set offset $next_offset
        incr line_number
    }

    return $commands
}

# find_matching_command_index
#
# Return the index of the source command that matches one recorded mutation.
#
proc portsource::find_matching_command_index {commands command_record} {
    set command_name [portprovenance::mutation_command_name \
        [dict get $command_record option] \
        [dict get $command_record action]]
    set normalized_cmd {}
    set line_number {}

    if {[dict exists $command_record cmd]} {
        set normalized_cmd [normalize_command_text [dict get $command_record cmd]]
    }
    if {[dict exists $command_record line]} {
        set line_number [dict get $command_record line]
    }

    # Prefer the exact line-number match when provenance captured it; fall back
    # to normalized command text alone for frames that did not preserve lines.
    if {$normalized_cmd ne {} && $line_number ne {}} {
        for {set i 0} {$i < [llength $commands]} {incr i} {
            set command [lindex $commands $i]
            if {[dict get $command command_name] ne $command_name} {
                continue
            }
            if {[dict get $command line] != $line_number} {
                continue
            }
            if {[dict get $command normalized] ne $normalized_cmd} {
                continue
            }

            return $i
        }
    }

    if {$normalized_cmd ne {}} {
        for {set i 0} {$i < [llength $commands]} {incr i} {
            set command [lindex $commands $i]
            if {[dict get $command command_name] ne $command_name} {
                continue
            }
            if {[dict get $command normalized] ne $normalized_cmd} {
                continue
            }

            return $i
        }
    }

    return -1
}

# match_recorded_commands
#
# Match recorded mutations to source commands in the Portfile.
#
proc portsource::match_recorded_commands {portfile_contents command_records} {
    set command_names [list]

    # Limit the source scan to command names that the recorded mutations could
    # actually resolve to.
    foreach command_record $command_records {
        set command_name [portprovenance::mutation_command_name \
            [dict get $command_record option] \
            [dict get $command_record action]]
        if {$command_name eq {} || $command_name in $command_names} {
            continue
        }

        lappend command_names $command_name
    }

    set source_commands [find_portfile_commands $portfile_contents $command_names]
    set matched_commands [list]

    foreach command_record $command_records {
        set match_index [find_matching_command_index $source_commands $command_record]
        if {$match_index < 0} {
            return -code error [format "failed to locate active %s command in Portfile" \
                [dict get $command_record option]]
        }

        lappend matched_commands [dict merge [lindex $source_commands $match_index] $command_record]
        set source_commands [lreplace $source_commands $match_index $match_index]
    }

    return $matched_commands
}

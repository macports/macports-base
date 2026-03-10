# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portbump.tcl
#
# Copyright (c) 2019 The MacPorts Project
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

package provide portbump 1.0
package require portutil 1.0
package require portchecksum 1.0
package require portprovenance 1.0
package require portsource 1.0

set org.macports.bump [target_new org.macports.bump portbump::bump_main]
target_provides ${org.macports.bump} bump
target_runtype ${org.macports.bump} always
target_requires ${org.macports.bump} main fetch
target_prerun ${org.macports.bump} portbump::bump_start

namespace eval portbump {
}

portprovenance::track_option checksums
portprovenance::track_option revision

# build_checksum_replacements
#
# Build regex replacements for one checksum command while preserving distfile context.
#
proc portbump::build_checksum_replacements {command_name checksums_str all_dist_files calculated_checksums_array_name} {
    upvar 1 $calculated_checksums_array_name calculated_checksums_array

    set replacements [list]
    # Grow the regex context as we walk the command so repeated values such as
    # identical sizes only match within the intended distfile/type block.
    set prefix_patterns [list [quotemeta $command_name]]
    set whitespace {[[:space:]\\]+}
    set distfile_pattern {[^[:space:]\\]+}

    set single_file_format [portchecksum::uses_single_file_checksum_format $checksums_str $all_dist_files]

    foreach checksum_entry [portchecksum::parse_checksum_entries $checksums_str $all_dist_files] {
        lassign $checksum_entry distfile checksum_values

        if {!$single_file_format} {
            lappend prefix_patterns $distfile_pattern
        }

        if {[info exists calculated_checksums_array($distfile)]} {
            set new_checksums $calculated_checksums_array($distfile)
        } else {
            set new_checksums [list]
        }

        foreach {type old_sum} $checksum_values {
            lappend prefix_patterns [quotemeta $type]

            set new_sum_index [lsearch -exact $new_checksums $type]
            if {$new_sum_index >= 0} {
                set new_sum [lindex $new_checksums [expr {$new_sum_index + 1}]]

                lappend replacements [list \
                    [format {(%s%s)%s} [join $prefix_patterns $whitespace] $whitespace [quotemeta $old_sum]] \
                    "\\1${new_sum}"]
            }

            lappend prefix_patterns [quotemeta $old_sum]
        }
    }

    # Apply the most specific replacements first so earlier edits do not
    # invalidate broader patterns that still need to match the original text.
    return [lreverse $replacements]
}

# parse_recorded_checksum_entries
#
# Parse one recorded checksum mutation into ordered distfile entries.
#
proc portbump::parse_recorded_checksum_entries {command_record all_dist_files} {
    if {![dict exists $command_record args]} {
        return -code error "missing checksum provenance arguments"
    }

    return [portchecksum::parse_checksum_entries [dict get $command_record args] $all_dist_files]
}

# checksum_record_applies
#
# Return whether one recorded checksum mutation applies to the selected distfiles.
#
proc portbump::checksum_record_applies {command_record all_dist_files selected_subport} {
    if {![portprovenance::record_applies_to_subport $command_record $selected_subport]} {
        return no
    }

    # A checksum command is relevant if it belongs to the selected scope and
    # contributes at least one of the distfiles being bumped.
    foreach checksum_entry [parse_recorded_checksum_entries $command_record $all_dist_files] {
        if {[lindex $checksum_entry 0] in $all_dist_files} {
            return yes
        }
    }

    return no
}

# get_active_checksum_records
#
# Return the recorded checksum mutations that apply to this Portfile.
#
proc portbump::get_active_checksum_records {portfile all_dist_files} {
    global subport

    if {[info exists subport]} {
        set selected_subport $subport
    } else {
        set selected_subport {}
    }

    set records [list]
    set normalized_portfile [file normalize $portfile]

    foreach command_record [portprovenance::get_option_provenance checksums] {
        if {[dict get $command_record file] ne $normalized_portfile} {
            continue
        }
        if {![checksum_record_applies $command_record $all_dist_files $selected_subport]} {
            continue
        }

        lappend records $command_record
    }

    return $records
}

# get_active_revision_records
#
# Return the recorded revision mutations that apply to the selected subport.
#
proc portbump::get_active_revision_records {portfile} {
    global subport

    set global_records [list]
    set matching_records [list]
    set normalized_portfile [file normalize $portfile]

    if {[info exists subport]} {
        set selected_subport $subport
    } else {
        set selected_subport {}
    }

    foreach command_record [portprovenance::get_option_provenance revision] {
        if {[dict get $command_record file] ne $normalized_portfile} {
            continue
        }

        # Top-level revisions are inherited by subports unless a matching
        # subport-local revision executed and overrides them.
        if {[portprovenance::record_scope $command_record] eq "subport"} {
            if {[portprovenance::record_applies_to_subport $command_record $selected_subport]} {
                lappend matching_records $command_record
            }
        } else {
            lappend global_records $command_record
        }
    }

    if {[llength $matching_records]} {
        set selected_records $matching_records
    } else {
        set selected_records $global_records
    }

    set active_records [list]
    foreach command_record $selected_records {
        if {[dict exists $command_record args]} {
            set revision_args [dict get $command_record args]
            if {[llength $revision_args] == 1
                && [string is wideinteger -strict [lindex $revision_args 0]]
                && [lindex $revision_args 0] <= 0} {
                continue
            }
        }

        lappend active_records $command_record
    }

    return $active_records
}

# evaluate_checksum_command
#
# Evaluate one checksum command with wrappers so we can recover its argument words.
#
proc portbump::evaluate_checksum_command {command_text} {
    variable captured_checksum_command

    unset -nocomplain captured_checksum_command

    # Replace the public checksum commands temporarily so Tcl expansion runs as
    # usual and we can still recover the fully evaluated argument words.
    foreach command_name {checksums checksums-append} {
        set saved_command ::portbump::saved-${command_name}
        if {[llength [info commands ::${command_name}]]} {
            rename ::${command_name} ${saved_command}
        }
    }

    proc ::checksums {args} {
        set ::portbump::captured_checksum_command [list checksums $args]
    }
    proc ::checksums-append {args} {
        set ::portbump::captured_checksum_command [list checksums-append $args]
    }

    try {
        namespace eval :: $command_text
    } finally {
        rename ::checksums {}
        rename ::checksums-append {}

        foreach command_name {checksums checksums-append} {
            set saved_command ::portbump::saved-${command_name}
            if {[llength [info commands ${saved_command}]]} {
                rename ${saved_command} ::${command_name}
            }
        }
    }

    if {![info exists captured_checksum_command]} {
        return -code error "failed to evaluate checksum command"
    }

    return $captured_checksum_command
}

# build_checksum_edits
#
# Plan the checksum edits for the active Portfile checksum commands.
#
proc portbump::build_checksum_edits {portfile portfile_contents all_dist_files calculated_checksums_array_name} {
    upvar 1 $calculated_checksums_array_name calculated_checksums_array

    set edits [list]
    set command_records [get_active_checksum_records $portfile $all_dist_files]

    if {![llength $command_records]} {
        return $edits
    }

    # Match only the checksum commands that actually executed for this port,
    # then rewrite those source spans in place.
    foreach command_record [portsource::match_recorded_commands $portfile_contents $command_records] {
        set replacements [build_checksum_replacements \
            [dict get $command_record command_name] \
            [dict get $command_record args] \
            $all_dist_files \
            calculated_checksums_array]
        set command_text [dict get $command_record text]

        if {![llength $replacements]} {
            continue
        }

        foreach replacement $replacements {
            lassign $replacement pattern replacement_string

            if {![regsub -- $pattern $command_text $replacement_string command_text]} {
                return -code error "failed to locate checksum in Portfile"
            }
        }

        lappend edits [list \
            [dict get $command_record start] \
            [dict get $command_record end] \
            $command_text]
    }

    return $edits
}

# build_checksum_fallback_edits
#
# Plan checksum edits by rescanning the source when no checksum provenance exists.
#
proc portbump::build_checksum_fallback_edits {portfile_contents all_dist_files calculated_checksums_array_name} {
    upvar 1 $calculated_checksums_array_name calculated_checksums_array

    set edits [list]

    # Tests can inject raw Portfile text without provenance, so keep a narrow
    # source-scan fallback for that case.
    foreach command [portsource::find_portfile_commands $portfile_contents {checksums checksums-append}] {
        if {[catch {lassign [evaluate_checksum_command [dict get $command text]] command_name command_args}]} {
            continue
        }

        set replacements [build_checksum_replacements \
            $command_name \
            $command_args \
            $all_dist_files \
            calculated_checksums_array]
        set command_text [dict get $command text]

        if {![llength $replacements]} {
            continue
        }

        foreach replacement $replacements {
            lassign $replacement pattern replacement_string

            if {![regsub -- $pattern $command_text $replacement_string command_text]} {
                return -code error "failed to locate checksum in Portfile"
            }
        }

        lappend edits [list \
            [dict get $command start] \
            [dict get $command end] \
            $command_text]
    }

    return $edits
}

# build_revision_edits
#
# Plan the revision edits for the active Portfile revision commands.
#
proc portbump::build_revision_edits {portfile portfile_contents} {
    set edits [list]
    set command_records [get_active_revision_records $portfile]

    if {![llength $command_records]} {
        return $edits
    }

    foreach command_record [portsource::match_recorded_commands $portfile_contents $command_records] {
        set command_text [dict get $command_record text]

        if {![regexp -- {revision[[:space:]\\]+([0-9]+)} $command_text -> old_revision]} {
            return -code error "failed to locate revision in Portfile"
        }

        set pattern [format {(revision[[:space:]\\]+)%s} [quotemeta $old_revision]]
        if {![regsub -- $pattern $command_text {\10} command_text]} {
            return -code error "failed to locate revision in Portfile"
        }

        lappend edits [list \
            [dict get $command_record start] \
            [dict get $command_record end] \
            $command_text]
    }

    return $edits
}

# apply_source_edits
#
# Apply source replacements from the end of the Portfile toward the beginning.
#
proc portbump::apply_source_edits {portfile_contents edits} {
    foreach edit [lreverse $edits] {
        lassign $edit start end replacement_text
        set portfile_contents [string replace $portfile_contents $start $end $replacement_text]
    }

    return $portfile_contents
}

# rewrite_portfile
#
# Rewrite the Portfile checksums and reset the revision in a temporary file.
#
proc portbump::rewrite_portfile {portfile tmpfd all_dist_files calculated_checksums_array_name} {
    upvar 1 $calculated_checksums_array_name calculated_checksums_array

    set portfd [open $portfile r]
    set portfile_contents [read $portfd]
    close $portfd

    set checksum_edits [build_checksum_edits $portfile $portfile_contents $all_dist_files calculated_checksums_array]
    if {![llength $checksum_edits] && ![portprovenance::has_option_provenance checksums $portfile]} {
        set checksum_edits [build_checksum_fallback_edits $portfile_contents $all_dist_files calculated_checksums_array]
    }

    set revision_edits [build_revision_edits $portfile $portfile_contents]
    set use_revision_fallback [expr {![llength $revision_edits] && ![portprovenance::has_option_provenance revision $portfile]}]

    set edits [concat $checksum_edits $revision_edits]

    if {![llength $edits] && !$use_revision_fallback} {
        return -code error "failed to locate checksum or revision in Portfile"
    }

    set portfile_contents [apply_source_edits $portfile_contents $edits]

    # Older simple Portfiles may still have no revision provenance at all, so
    # keep the legacy one-shot reset as a compatibility fallback.
    if {$use_revision_fallback
        && [regsub -- {(revision[[:space:]\\]+)[0-9]+} $portfile_contents {\10} portfile_contents]} {
    }

    puts -nonewline $tmpfd $portfile_contents
    close $tmpfd
}

# bump_start
#
# Target prerun procedure; simply prints a message about what we're doing.
#
proc portbump::bump_start {args} {
    global UI_PREFIX subport

    ui_notice "$UI_PREFIX [format [msgcat::mc "Bumping checksums for %s"] ${subport}]"
}

# bump_main
#
# Target main procedure. Bumps the checksums for distfiles.
#
proc portbump::bump_main {args} {
    global UI_PREFIX all_dist_files checksums_array portpath ports_bump_patch

    set portfile "${portpath}/Portfile"

    # If no files have been downloaded, there is nothing to bump.
    if {![info exists all_dist_files]} {
        return 0
    }

    # So far, no mismatches yet.
    set mismatch no

    # Set the list of checksums as the option checksums.
    set checksums_str [option checksums]

    # Store the calculated checksums to avoid repeated calculations
    array set calculated_checksums_array {}

    # If everything is fine with the syntax, keep on and check the checksum of
    # the distfiles.
    if {[portchecksum::parse_checksums $checksums_str] eq "yes"} {
        global distpath

        foreach distfile $all_dist_files {
            ui_info "$UI_PREFIX [format [msgcat::mc "Checksumming %s"] $distfile]"

            # Get the full path of the distfile.
            set fullpath [file join $distpath $distfile]
            if {![file isfile $fullpath]} {
                return -code error "$distfile does not exist in $distpath"
            }

            # Check that there is at least one checksum for the distfile.
            if {![info exists checksums_array($distfile)] || [llength $checksums_array($distfile)] < 1} {
                ui_error "[format [msgcat::mc "No checksum set for %s"] $distfile]"
                set mismatch yes
            } else {
                # Retrieve the list of types/values from the array.
                set portfile_checksums $checksums_array($distfile)
                set calculated_checksums [list]

                # Iterate on this list to check the actual values.
                foreach {type sum} $portfile_checksums {
                    set calculated_sum [portchecksum::calc_$type $fullpath]
                    lappend calculated_checksums $type
                    lappend calculated_checksums $calculated_sum

                    if {$sum eq $calculated_sum} {
                        ui_debug "[format [msgcat::mc "Correct (%s) bump for %s"] $type $distfile]"
                    } else {
                        ui_info "[format [msgcat::mc "Portfile bump: %s %s %s"] $distfile $type $sum]"
                        ui_info "[format [msgcat::mc "Distfile bump: %s %s %s"] $distfile $type $calculated_sum]"

                        # Raise the failure flag
                        set mismatch yes
                    }
                }

                # Save our calculated checksums in case we need them later
                set calculated_checksums_array($distfile) $calculated_checksums

                if {![regexp {\.html?$} ${distfile}] &&
                    ![catch {strsed [exec [findBinary file $portutil::autoconf::file_path] $fullpath --brief --mime] {s/;.*$//}} mimetype]
                    && "text/html" eq $mimetype} {
                    # file --mime-type would be preferable to file --mime and strsed, but is only available as of Snow Leopard
                    set wrong_mimetype yes
                    set htmlfile_path ${fullpath}.html
                    file rename -force $fullpath $htmlfile_path
                }
            }
        }
    } else {
        # Something went wrong with the syntax.
        return -code error "[msgcat::mc "Unable to verify file checksums"]"
    }

    if {![tbool mismatch]} {
        ui_msg "No changes needed."
        return 0
    }

    if {[tbool wrong_mimetype]} {
        # We got an HTML file, though the distfile name does not suggest that one was
        # expected. Probably a helpful DNS server sent us to its search results page
        # instead of admitting that the server we asked for doesn't exist, or a mirror that
        # no longer has the file served its error page with a 200 response.
        ui_notice "***"
        ui_notice "The non-matching file appears to be HTML. See this page for possible reasons"
        ui_notice "for the bump mismatch:"
        ui_notice "<https://trac.macports.org/wiki/MisbehavingServers>"
        ui_notice "***"
        ui_notice "The file has been moved to: $htmlfile_path"
        
        return -code error "[msgcat::mc "Unable to verify file checksums"]"
    } else {
        # Show the desired checksum line for easy cut-paste
        # based on the previously calculated values, plus our default types

        global version subport

        ui_msg "We will bump these:"
        foreach distfile $all_dist_files {
            if {![info exists checksums_array($distfile)] || ![info exists calculated_checksums_array($distfile)]} {
                continue
            }

            if {[llength $all_dist_files] > 1} {
                ui_msg $distfile
            }

            set portfile_checksums $checksums_array($distfile)
            set calculated_checksums $calculated_checksums_array($distfile)

            for {set checksum_index 0} {$checksum_index < [llength $portfile_checksums]} {incr checksum_index 2} {
                set type [lindex $portfile_checksums $checksum_index]
                set sum [lindex $portfile_checksums [expr {$checksum_index + 1}]]
                set calculated_sum [lindex $calculated_checksums [expr {$checksum_index + 1}]]

                ui_msg [format "Old %-8s %s" ${type}: $sum]
                ui_msg [format "New %-8s %s" ${type}: $calculated_sum]
            }
        }

        # Get the uid of Portfile owner
        set owneruid [name_to_uid [file attributes ${portfile} -owner]]

        # root -> owner id
        exec_as_uid $owneruid {
            # Create temporary Portfile_XXXXXX.bump
            if {[catch {set tmpfd [file tempfile tmpfile ${portpath}/Portfile.bump]} error]} {
                ui_debug $::errorInfo
                ui_error "file tempfile: $error"
                return -code error "file tempfile failed"
            }

            # Get Portfile attributes
            set attributes [file attributes $portfile]

            # Rewrite Portfile checksums and write to Portfile.bump
            if {[catch {rewrite_portfile $portfile $tmpfd $all_dist_files calculated_checksums_array} error]} {
                ui_debug $::errorInfo
                ui_error "bump: $error"
                file delete "$tmpfile"
                catch {close $tmpfd}
                return -code error "bump rewrite failed"
            }

            ui_info "$UI_PREFIX [format [msgcat::mc "Patching %s"] $portfile]"

            if {[tbool ports_bump_patch]} {
                # Patch mode
                # Set Potfile.patch path
                set patchfile "${portpath}/Portfile.patch"
                set patchfd [open $patchfile w]

                # Construct diff command
                set diffcmd [list]
                lappend diffcmd $portutil::autoconf::diff_path -u --label old/Portfile --label new/Portfile
                lappend diffcmd $portfile $tmpfile >@$patchfd

                # Create and write diff to Portfile.patch
                if {[catch {exec -ignorestderr -- {*}$diffcmd} error]} {
                    # Copy Portfile attributes to Portfile.patch
                    file attributes $portfile {*}$attributes
                    ui_msg "Portfile.patch successfully created at $patchfile"    
                } else {
                    ui_msg "No changes needed."
                    file delete "$patchfile"
                    close $patchfd
                }
            } else {
                # Overwrite mode
                # Replace Portfile with Portfile.bump
                if {[catch {move -force $tmpfile $portfile} error]} {
                    ui_debug $::errorInfo
                    ui_error "bump: $error"
                    file delete "$tmpfile"
                    return -code error "bump overwrite failed"
                }

                # Restore Portfile attributes
                file attributes $portfile {*}$attributes

                ui_msg "Checksums successfully bumped. Suggested commit message:"
                ui_msg [format "%-8s%s: update to %s" "" ${subport} $version]
            }

            # Delete Portfile.bump
            file delete "$tmpfile"
        }

        return 0
    }
}

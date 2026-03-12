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

set org.macports.bump [target_new org.macports.bump portbump::bump_main]
target_provides ${org.macports.bump} bump
target_runtype ${org.macports.bump} always
target_requires ${org.macports.bump} main fetch
target_prerun ${org.macports.bump} portbump::bump_start

namespace eval portbump {
}

# replace_checksums
#
# Replace old checksum hash values with new ones in a list of lines.
# Returns a list of two elements: the modified lines and a list of
# line indices where replacements were made.
#
# Checksum values (hex hashes and integer sizes) are matched as whole
# words using \y word-boundary anchors (Tcl ARE syntax), so a size
# like 123 cannot accidentally match inside a larger value such as
# 12345. All checksum values are alphanumeric ([0-9a-f]+ or [0-9]+)
# and contain no regex metacharacters, so they are safe to interpolate
# directly into the pattern.
#
#   lines          - list of Portfile lines
#   both_checksums - list of {type old_sum new_sum} triples
proc portbump::replace_checksums {lines both_checksums} {
    set checksum_lines [list]
    foreach {type sum calculated_sum} $both_checksums {
        if {$sum eq $calculated_sum} {
            continue
        }
        for {set i 0} {$i < [llength $lines]} {incr i} {
            set line [lindex $lines $i]
            if {[regsub -all "\\y${sum}\\y" $line $calculated_sum new_line]} {
                lset lines $i $new_line
                lappend checksum_lines $i
            }
        }
    }
    return [list $lines $checksum_lines]
}

# find_revision_line
#
# Find the line index of the revision that should be reset for the
# given subport. Handles Portfiles with multiple revision lines across
# subport blocks, conditional branches, or inline subport declarations
# (e.g. "subport foo { revision 3 }").
#
# Strategy:
# 1. If the current subport has an inline revision on its subport
#    declaration line, use that.
# 2. Otherwise, use the standalone revision line nearest to the
#    anchor (typically the first checksum line that was modified).
#    When bumping the parent port, revision lines inside subport { }
#    blocks are excluded.
#
#   lines       - list of Portfile lines
#   subport     - current subport name
#   portname    - parent port name
#   anchor      - line index to measure proximity from
#
# Returns: line index, or -1 if no revision line found
proc portbump::find_revision_line {lines subport portname anchor} {
    # For a subport, prefer an inline revision on its subport declaration line
    # (e.g. "subport clang-16 { revision 9 }").
    if {$subport ne $portname} {
        set escaped_subport [string map {\\ \\\\ . \\. * \\* + \\+ ? \\? ( \\( ) \\) \{ \\\{ \} \\\} \[ \\\[ \] \\\]} $subport]
        for {set i 0} {$i < [llength $lines]} {incr i} {
            if {[regexp "^\\s*subport\\s+\\S*${escaped_subport}\\S*\\s+.*revision\\s+\\d+" [lindex $lines $i]]} {
                return $i
            }
        }
    }

    # When bumping the parent port, build an exclusion set of lines inside
    # subport { } blocks so their revision lines are not mistakenly targeted.
    set in_subport_block [dict create]
    if {$subport eq $portname} {
        set brace_depth 0
        set in_subport 0
        for {set i 0} {$i < [llength $lines]} {incr i} {
            set line [lindex $lines $i]
            if {!$in_subport && [regexp {^\s*subport\s+} $line]} {
                set in_subport 1
                set opens [regexp -all {\{} $line]
                set closes [regexp -all {\}} $line]
                set brace_depth [expr {$opens - $closes}]
                dict set in_subport_block $i 1
                if {$brace_depth <= 0} {
                    set in_subport 0
                    set brace_depth 0
                }
            } elseif {$in_subport} {
                dict set in_subport_block $i 1
                set opens [regexp -all {\{} $line]
                set closes [regexp -all {\}} $line]
                incr brace_depth [expr {$opens - $closes}]
                if {$brace_depth <= 0} {
                    set in_subport 0
                    set brace_depth 0
                }
            }
        }
    }

    # Find the nearest standalone revision line, skipping any inside subport blocks.
    set best_line -1
    set best_dist 2147483647
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {[regexp {^\s*revision\s+\d+} [lindex $lines $i]]} {
            if {[dict exists $in_subport_block $i]} {
                continue
            }
            set dist [expr {abs($i - $anchor)}]
            if {$dist < $best_dist} {
                set best_dist $dist
                set best_line $i
            }
        }
    }

    return $best_line
}

# reset_revision
#
# Reset the revision value to 0 on the specified line.
# Returns the modified list of lines.
#
#   lines    - list of Portfile lines
#   line_idx - index of the line to modify
proc portbump::reset_revision {lines line_idx} {
    set old_line [lindex $lines $line_idx]
    set new_line [regsub {(revision\s+)\d+} $old_line {\10}]
    if {$old_line ne $new_line} {
        lset lines $line_idx $new_line
    }
    return $lines
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
    set wrong_mimetype no

    # Read the declared checksums from the port options.
    set checksums_str [option checksums]

    # If everything is fine with the syntax, keep on and check the checksum of
    # the distfiles.
    if {[portchecksum::parse_checksums $checksums_str] eq "yes"} {
        global distpath

        set both_checksums [list]
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

                # Iterate on this list to check the actual values.
                foreach {type sum} $portfile_checksums {
                    set calculated_sum [portchecksum::calc_$type $fullpath]
                    lappend both_checksums $type $sum $calculated_sum

                    if {$sum eq $calculated_sum} {
                        ui_debug "[format [msgcat::mc "Correct (%s) bump for %s"] $type $distfile]"
                    } else {
                        ui_info "[format [msgcat::mc "Portfile bump: %s %s %s"] $distfile $type $sum]"
                        ui_info "[format [msgcat::mc "Distfile bump: %s %s %s"] $distfile $type $calculated_sum]"

                        # Raise the failure flag
                        set mismatch yes
                    }
                }

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
        global version subport

        ui_msg "We will bump these:"
        foreach {type sum calculated_sum} $both_checksums {
            if {$sum eq $calculated_sum} {
                continue
            }
            ui_msg [format "Old %-8s %s" ${type}: $sum]
            ui_msg [format "New %-8s %s" ${type}: $calculated_sum]
        }

        # Get the uid of Portfile owner
        set owneruid [name_to_uid [file attributes ${portfile} -owner]]

        # root -> owner id
        exec_as_uid $owneruid {
            # Read the Portfile
            set fd [open $portfile r]
            set lines [split [read $fd] \n]
            close $fd

            # Get Portfile attributes
            set attributes [file attributes $portfile]

            lassign [portbump::replace_checksums $lines $both_checksums] lines checksum_lines
            foreach cl $checksum_lines {
                ui_debug "Replaced checksum on line [expr {$cl + 1}]"
            }

            if {[llength $checksum_lines] > 0} {
                set rev_line [portbump::find_revision_line $lines $subport [option name] [lindex $checksum_lines 0]]
                if {$rev_line >= 0} {
                    set old_rev [lindex $lines $rev_line]
                    set lines [portbump::reset_revision $lines $rev_line]
                    if {[lindex $lines $rev_line] ne $old_rev} {
                        ui_debug "Reset revision to 0 on line [expr {$rev_line + 1}]"
                    }
                }
            }

            set new_content [join $lines \n]

            if {[tbool ports_bump_patch]} {
                # Patch mode
                if {[catch {set tmpfd [file tempfile tmpfile ${portpath}/Portfile.bump]} error]} {
                    ui_debug $::errorInfo
                    ui_error "file tempfile: $error"
                    return -code error "file tempfile failed"
                }
                puts -nonewline $tmpfd $new_content
                close $tmpfd

                set patchfile "${portpath}/Portfile.patch"
                set patchfd [open $patchfile w]

                # Construct diff command
                set diffcmd [list]
                lappend diffcmd $portutil::autoconf::diff_path -u --label old/Portfile --label new/Portfile
                lappend diffcmd $portfile $tmpfile >@$patchfd

                # Create and write diff to Portfile.patch
                if {[catch {exec -ignorestderr -- {*}$diffcmd} error]} {
                    file attributes $patchfile {*}$attributes
                    ui_msg "Portfile.patch successfully created at $patchfile"
                } else {
                    ui_msg "No changes needed."
                    file delete "$patchfile"
                    close $patchfd
                }

                file delete "$tmpfile"
            } else {
                # Overwrite mode
                if {[catch {set tmpfd [file tempfile tmpfile ${portpath}/Portfile.bump]} error]} {
                    ui_debug $::errorInfo
                    ui_error "file tempfile: $error"
                    return -code error "file tempfile failed"
                }
                puts -nonewline $tmpfd $new_content
                close $tmpfd

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
        }

        return 0
    }
}

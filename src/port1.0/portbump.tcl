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

# bump_start
#
# Target prerun procedure; simply prints a message about what we're doing.
#
proc portbump::bump_start {args} {
    global UI_PREFIX

    ui_notice "$UI_PREFIX [format [msgcat::mc "Bumping checksums for %s"] [option subport]]"
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
        set distpath [option distpath]

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
                set calculated_checksums {}
                set both_checksums {}

                # Iterate on this list to check the actual values.
                foreach {type sum} $portfile_checksums {
                    set calculated_sum [portchecksum::calc_$type $fullpath]
                    lappend calculated_checksums $type
                    lappend calculated_checksums $calculated_sum
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
    } elseif {![info exists both_checksums]} {
        return -code error "[msgcat::mc "No checksums found in Portfile"]"
    } else {
        # Show the desired checksum line for easy cut-paste
        # based on the previously calculated values, plus our default types
        set sums {}

        global version revision

        ui_msg "We will bump these:"
        foreach {type sum calculated_sum} $both_checksums {
            ui_msg [format "Old %-8s %s" ${type}: $sum]
            ui_msg [format "New %-8s %s" ${type}: $calculated_sum]
        }

        set patterns {}

        set whitespace {[[:space:]\\]+}
        # Create substitution pattern(s) for checksum
        foreach {type sum calculated_sum} $both_checksums {
            lappend patterns "s/(${type}${whitespace})${sum}/\\1${calculated_sum}/g"
        }
        # Create substitution pattern for revision (reset to 0)
        lappend patterns {s/(revision[[:space:]\\]+)[0-9]+/\10/g}

        # Construct sed command
        set cmdline {}
        lappend cmdline $portutil::autoconf::sed_command -E
        foreach pattern $patterns {
            lappend cmdline -e $pattern
        }

        # Get the uid of Portfile owner
        set owneruid [name_to_uid [file attributes ${portfile} -owner]]

        # root -> owner id
        exec_as_uid $owneruid {
            # Create temporary Portfile.bump.XXXXXX
            if {[catch {set tmpfile [mkstemp "${portpath}/Portfile.bump.XXXXXX"]} error]} {
                ui_debug $::errorInfo
                ui_error "mkstemp: $error"
                return -code error "mkstemp failed"
            }

            # Extract the Tcl Channel number
            set tmpfd [lindex $tmpfile 0]

            # Set tmpfile to only the file name
            set tmpfile [join [lrange $tmpfile 1 end]]

            # Get Portfile attributes
            set attributes [file attributes $portfile]

            # Direct sed command output to tempfile
            lappend cmdline "<${portfile}" ">@$tmpfd"

            # Run sed command and write to Portfile.bump
            ui_info "$UI_PREFIX [format [msgcat::mc "Patching %s: %s"] $portfile $patterns]"
            if {[catch {exec -ignorestderr -- {*}$cmdline} error]} {
                ui_debug $::errorInfo
                ui_error "sed: $error"
                file delete "$tmpfile"
                close $tmpfd
                return -code error "sed sed(1) failed"
            }

            if {[tbool ports_bump_patch]} {
                # Patch mode
                # Set Potfile.patch path
                set patchfile "${portpath}/Portfile.patch"
                set patchfd [open $patchfile w]

                # Construct diff command
                set diffcmd {}
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
                ui_msg [format "%-8s%s: update to %s" "" [option subport] $version]
            }

            # Delete Portfile.bump
            file delete "$tmpfile"
        }

        return 0
    }
}

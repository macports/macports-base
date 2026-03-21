# et:ts=4
# portchecksum.tcl
#
# Copyright (c) 2002 - 2004 Apple Inc.
# Copyright (c) 2004 - 2005 Paul Guyot <pguyot@kallisys.net>
# Copyright (c) 2006 - 2012, 2014 - 2016, 2018 The MacPorts Project
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
#

package provide portchecksum 1.0
package require portutil 1.0

set org.macports.checksum [target_new org.macports.checksum portchecksum::checksum_main]
target_provides ${org.macports.checksum} checksum
target_requires ${org.macports.checksum} main fetch
target_prerun ${org.macports.checksum} portchecksum::checksum_start

namespace eval portchecksum {

    # The list of the types of checksums we know.
    variable checksum_types [list md5 sha1 rmd160 sha256 size]

    # types to recommend if none are specified in the portfile
    variable default_checksum_types [list rmd160 sha256 size]

    # types that are considered secure
    variable secure_checksum_types [list rmd160 sha256]
}

# Options
options checksums checksum.skip

# Defaults
default checksums {}
default checksum.skip false

set_ui_prefix

# parse_checksum_block_formats
#
# Scan Portfile lines for checksums/checksums-append/checksums-prepend block headers and
# extract their formatting properties. Returns a list of block dicts,
# each containing: keyword, indent, keyword_width, type_width,
# start_line, end_line.
#
#   lines - list of Portfile lines
#
proc portchecksum::parse_checksum_block_formats {lines} {
    variable checksum_types
    set blocks [list]

    # Build regex alternation from checksum_types
    set types_re [join $checksum_types |]

    for {set i 0} {$i < [llength $lines]} {incr i} {
        set line [lindex $lines $i]
        # Match checksums-append/checksums-prepend before checksums to avoid partial match
        if {[regexp {^(\s*)(checksums-(?:append|prepend)|checksums)(\s+)} $line -> leading keyword spacing]} {
            set indent $leading
            set keyword_width [expr {[string length $leading] + [string length $keyword] + [string length $spacing]}]

            # Determine type_width by scanning this block for a known
            # checksum type followed by spaces and a value
            set type_width 8
            set end_line $i
            for {set j $i} {$j < [llength $lines]} {incr j} {
                set bline [lindex $lines $j]
                if {[regexp "(?:^|\\s)(${types_re})(\\s+)\\S" $bline -> _type tw_spacing]} {
                    set type_width [expr {[string length $_type] + [string length $tw_spacing]}]
                }
                if {[string match {*\\} [string trimright $bline]]} {
                    set end_line $j
                } else {
                    set end_line $j
                    break
                }
            }

            lappend blocks [dict create \
                keyword $keyword \
                indent $indent \
                keyword_width $keyword_width \
                type_width $type_width \
                start_line $i \
                end_line $end_line]

            # Skip past this block
            set i $end_line
        }
    }

    return $blocks
}

# find_block_for_value
#
# Find which checksum block contains a given value string by searching
# the Portfile lines and matching against block line ranges.
# Returns the block index, or -1 if not found.
#
#   lines  - list of Portfile lines
#   blocks - list of block dicts from parse_checksum_block_formats
#   value  - checksum value to search for
#
proc portchecksum::find_block_for_value {lines blocks value} {
    for {set i 0} {$i < [llength $lines]} {incr i} {
        if {[string first $value [lindex $lines $i]] >= 0} {
            for {set b 0} {$b < [llength $blocks]} {incr b} {
                set block [lindex $blocks $b]
                if {$i >= [dict get $block start_line] && $i <= [dict get $block end_line]} {
                    return $b
                }
            }
            return -1
        }
    }
    return -1
}

# extract_block_distfile_names
#
# Extract distfile name tokens from a checksum block as they appear
# in the Portfile text (preserving variable expressions like
# ${go_src_dist}). Returns a list of distfile name strings.
#
# Tokens that are known checksum types (and the value following them)
# are skipped; everything else is a distfile name.
#
#   lines - list of Portfile lines
#   block - block dict from parse_checksum_block_formats
#
proc portchecksum::extract_block_distfile_names {lines block} {
    variable checksum_types
    set start [dict get $block start_line]
    set end [dict get $block end_line]
    set kw_width [dict get $block keyword_width]

    # Collect all tokens from the block
    set tokens [list]
    for {set i $start} {$i <= $end} {incr i} {
        set line [lindex $lines $i]
        if {$i == $start} {
            # Strip keyword prefix
            set line [string range $line $kw_width end]
        }
        # Strip trailing backslash and whitespace
        set line [string trimright $line]
        set line [string trimright $line \\]
        set line [string trim $line]
        if {$line ne ""} {
            foreach token [regexp -all -inline {\S+} $line] {
                lappend tokens $token
            }
        }
    }

    # Walk tokens: checksum types are followed by values,
    # everything else is a distfile name
    set distfile_names [list]
    set i 0
    while {$i < [llength $tokens]} {
        set token [lindex $tokens $i]
        if {$token in $checksum_types && ($i + 1) < [llength $tokens]} {
            # Skip type and value
            incr i 2
        } else {
            lappend distfile_names $token
            incr i
        }
    }

    return $distfile_names
}

# format_checksum_suggestion
#
# Format a checksum suggestion string with the given indentation
# parameters. Returns the formatted multi-line string.
#
#   keyword       - "checksums" or "checksums-append"
#   indent        - leading whitespace before keyword
#   keyword_width - total prefix width (indent + keyword + spacing)
#   type_width    - padding width for checksum type names
#   sums          - list of formatted entry strings
#
proc portchecksum::format_checksum_suggestion {keyword indent keyword_width sums} {
    set kw_pad [expr {$keyword_width - [string length $indent]}]
    set header "${indent}[format "%-${kw_pad}s" $keyword]"
    set continuation " \\\n[string repeat " " $keyword_width]"
    return "${header}[join $sums $continuation]"
}

# verify_checksum_format
#
# Given a checksum type as string and the actual checksum:
#
# - return 1  if the value has the expected format
# - return 0  if the value does not look as expected
# - return -1 if the checksum type is unrecognized
proc portchecksum::verify_checksum_format {type value} {
    set result 0

    switch [string tolower $type] {
        sha256 {
          set result [regexp {^\w{64}$} $value]
        }
        rmd160 {
          set result [regexp {^\w{40}$} $value]
        }
        sha1 {
          set result [regexp {^\w{40}$} $value]
        }
        md5 {
          set result [regexp {^\w{32}$} $value]
        }
        size {
          set result [regexp {^\d+$} $value]
        }
        default {
          # unrecognized checksum type
          set result -1
        }
    }

    return $result
}

# Using global all_dist_files, parse the checksums and store them into the
# global array checksums_array.
#
# There are two formats:
# type value [type value [type value]]                      for a single file
# file1 type value [type value [type value]] [file2 ...]    for multiple files.
#
# Portfile is in format #1 if:
# (1) There is only one distfile.
# (2) There are an even number of words in checksums (i.e. "md5 cksum sha1 cksum" = 4 words).
# (3) There are no more checksums specified than $portchecksum::checksum_types contains.
# (4) first word is one of the checksums types.
#
# return yes if the syntax was correct, no if there was a problem.
proc portchecksum::parse_checksums {checksums_str} {
    global checksums_array all_dist_files
    variable checksum_types

    # Parse the string of checksums.
    set nb_checksum [llength $checksums_str]

    if {[llength $all_dist_files] == 1
        && [expr {$nb_checksum % 2}] == 0
        && [expr {$nb_checksum / 2}] <= [llength $checksum_types]
        && [lindex $checksums_str 0] in $checksum_types} {
        # Convert to format #2
        set checksums_str [linsert $checksums_str 0 [lindex $all_dist_files 0]]
        # We increased the size.
        incr nb_checksum
    }

    # Create the array with the checksums.
    array set checksums_array {}

    set result yes

    # Catch out of bounds errors (they're syntax errors).
    if {[catch {
        # Parse the string as if it was in format #2.
        for {set ix_checksum 0} {$ix_checksum < $nb_checksum} {incr ix_checksum} {
            # first word is the file.
            set checksum_filename [lindex $checksums_str $ix_checksum]

            # retrieve the list of values we already know for this file.
            set checksum_values {}
            if {[info exists checksums_array($checksum_filename)]} {
                set checksum_values $checksums_array($checksum_filename)
            }

            # append the new value
            incr ix_checksum
            while {1} {
                set checksum_type [lindex $checksums_str $ix_checksum]
                if {$checksum_type in $checksum_types} {
                    # append the type and the value.
                    incr ix_checksum
                    set checksum_value [lindex $checksums_str $ix_checksum]
                    incr ix_checksum

                    lappend checksum_values $checksum_type
                    lappend checksum_values $checksum_value
                } else {
                    # this wasn't a type but the next dist file.
                    incr ix_checksum -1
                    break
                }

                # stop if we exhausted all the items in the list.
                if {$ix_checksum == $nb_checksum} {
                    break
                }
            }

            # set the values in the array.
            set checksums_array($checksum_filename) $checksum_values
        }
    } error]} {
        # An error occurred.
        ui_debug $::errorInfo
        ui_error "Couldn't parse checksum line ($checksums_str) [$error]"

        # Something wrong happened.
        set result no
    }

    return $result
}

# calc_md5
#
# Calculate the md5 checksum for the given file.
# Return the checksum.
#
proc portchecksum::calc_md5 {file} {
    return [md5 file $file]
}

# calc_sha1
#
# Calculate the sha1 checksum for the given file.
# Return the checksum.
#
proc portchecksum::calc_sha1 {file} {
    return [sha1 file $file]
}

# calc_rmd160
#
# Calculate the rmd160 checksum for the given file.
# Return the checksum.
#
proc portchecksum::calc_rmd160 {file} {
    return [rmd160 file $file]
}

# calc_sha256
#
# Calculate the sha256 checksum for the given file.
# Return the checksum.
#
proc portchecksum::calc_sha256 {file} {
    return [sha256 file $file]
}

# calc_size
#
# Get the size of the given file.
# Return the size.
#
proc portchecksum::calc_size {file} {
    return [file size $file]
}

# checksum_start
#
# Target prerun procedure; simply prints a message about what we're doing.
#
proc portchecksum::checksum_start {args} {
    global UI_PREFIX

    ui_notice "$UI_PREFIX [format [msgcat::mc "Verifying checksums for %s"] [option subport]]"
}

# checksum_main
#
# Target main procedure. Verifies the checksums of all distfiles.
#
proc portchecksum::checksum_main {args} {
    global UI_PREFIX all_dist_files checksums_array checksum.skip distpath portpath

    # If no files have been downloaded, there is nothing to checksum.
    if {![info exists all_dist_files]} {
        return 0
    }

    # Completely bypass checksumming if checksum.skip=yes
    # This should be considered an extreme measure
    if {[tbool checksum.skip]} {
        ui_info "$UI_PREFIX Skipping checksum phase"
        return 0
    }

    # so far, everything went fine.
    set fail no

    # Set the list of checksums as the option checksums.
    set checksums_str [option checksums]

    # store the calculated checksums to avoid repeated calculations
    array set calculated_checksums_array {}

    # if everything is fine with the syntax, keep on and check the checksum of
    # the distfiles.
    if {[parse_checksums $checksums_str] eq "yes"} {

        foreach distfile $all_dist_files {
            ui_info "$UI_PREFIX [format [msgcat::mc "Checksumming %s"] $distfile]"

            # get the full path of the distfile.
            set fullpath [file join $distpath $distfile]
            if {![file isfile $fullpath]} {
                return -code error "$distfile does not exist in $distpath"
            }

            # check that there is at least one checksum for the distfile.
            if {![info exists checksums_array($distfile)] || [llength $checksums_array($distfile)] < 1} {
                ui_error "[format [msgcat::mc "No checksum set for %s"] $distfile]"
                set fail yes
            } else {
                # retrieve the list of types/values from the array.
                set portfile_checksums $checksums_array($distfile)
                set calculated_checksums [list]

                # iterate on this list to check the actual values.
                foreach {type sum} $portfile_checksums {
                    set calculated_sum [calc_$type $fullpath]
                    lappend calculated_checksums $type
                    lappend calculated_checksums $calculated_sum

		    # Used for regression testing
                    ui_debug "[format [msgcat::mc "Calculated (%s) is %s"] $type $calculated_sum]"

                    if {$sum eq $calculated_sum} {
                        ui_debug "[format [msgcat::mc "Correct (%s) checksum for %s"] $type $distfile]"
                    } else {
                        ui_error "[format [msgcat::mc "Checksum (%s) mismatch for %s"] $type $distfile]"
                        ui_info "[format [msgcat::mc "Portfile checksum: %s %s %s"] $distfile $type $sum]"
                        ui_info "[format [msgcat::mc "Distfile checksum: %s %s %s"] $distfile $type $calculated_sum]"

                        # Raise the failure flag
                        set fail yes
                    }
                }

                # Save our calculated checksums in case we need them later
                set calculated_checksums_array($distfile) $calculated_checksums

                if {[tbool fail] && ![regexp {\.html?$} ${distfile}] &&
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
        set fail yes
    }

    if {[tbool fail]} {

        if {[tbool wrong_mimetype]} {
            # We got an HTML file, though the distfile name does not suggest that one was
            # expected. Probably a helpful DNS server sent us to its search results page
            # instead of admitting that the server we asked for doesn't exist, or a mirror that
            # no longer has the file served its error page with a 200 response.
            ui_notice "***"
            ui_notice "The non-matching file appears to be HTML. See this page for possible reasons"
            ui_notice "for the checksum mismatch:"
            ui_notice "<https://trac.macports.org/wiki/MisbehavingServers>"
            ui_notice "***"
            ui_notice "The file has been moved to: $htmlfile_path"
        } else {
            # Show the desired checksum line for easy cut-paste
            # based on the previously calculated values, plus our default types
            variable default_checksum_types

            # Read Portfile to detect existing indentation
            set portfile_lines {}
            set blocks {}
            if {[info exists portpath]} {
                set portfile "${portpath}/Portfile"
                if {[file isfile $portfile]} {
                    if {![catch {
                        set fd [open $portfile r]
                        set portfile_lines [split [read $fd] \n]
                        close $fd
                    }]} {
                        set blocks [parse_checksum_block_formats $portfile_lines]
                    }
                }
            }

            # Default formatting when no Portfile block can be matched
            set default_block [dict create keyword checksums indent "" \
                keyword_width 20 type_width 8]

            # Pass 1: Determine which block each distfile belongs to
            set distfile_blocks [dict create]
            set block_info [dict create]
            foreach distfile $all_dist_files {
                set distfile_block -1
                if {[info exists checksums_array($distfile)] && [llength $blocks] > 0} {
                    foreach {type old_val} $checksums_array($distfile) {
                        set b [find_block_for_value $portfile_lines $blocks $old_val]
                        if {$b >= 0} {
                            set distfile_block $b
                            break
                        }
                    }
                }
                dict set distfile_blocks $distfile $distfile_block

                if {$distfile_block >= 0} {
                    dict set block_info $distfile_block [lindex $blocks $distfile_block]
                } elseif {![dict exists $block_info $distfile_block]} {
                    dict set block_info $distfile_block $default_block
                }
            }

            # Build mapping of resolved distfile names to original
            # Portfile expressions (e.g. "${go_src_dist}" instead of
            # "go1.26.0.src.tar.gz")
            set original_names [dict create]
            if {[llength $blocks] > 0} {
                foreach block_idx [lsort -integer -unique [dict values $distfile_blocks]] {
                    if {$block_idx < 0} continue
                    set block [lindex $blocks $block_idx]
                    set orig_names [extract_block_distfile_names $portfile_lines $block]
                    # Collect resolved names for this block in order
                    set resolved_in_block [list]
                    foreach df $all_dist_files {
                        if {[dict get $distfile_blocks $df] == $block_idx} {
                            lappend resolved_in_block $df
                        }
                    }
                    # Map by position
                    for {set n 0} {$n < [llength $resolved_in_block] && $n < [llength $orig_names]} {incr n} {
                        dict set original_names [lindex $resolved_in_block $n] [lindex $orig_names $n]
                    }
                }
            }

            # Pass 2: Build per-block sums using original distfile names
            set block_sums [dict create]
            foreach distfile $all_dist_files {
                set distfile_block [dict get $distfile_blocks $distfile]
                set blk [dict get $block_info $distfile_block]
                set tw [dict get $blk type_width]
                set missing_types $default_checksum_types

                # Add distfile name for multi-distfile ports, using
                # the original Portfile expression when available
                if {[llength $all_dist_files] > 1} {
                    if {[dict exists $original_names $distfile]} {
                        dict lappend block_sums $distfile_block \
                            [dict get $original_names $distfile]
                    } else {
                        dict lappend block_sums $distfile_block $distfile
                    }
                }

                # Append calculated checksums
                if {[info exists calculated_checksums_array($distfile)] && [llength $calculated_checksums_array($distfile)]} {
                    set calculated_checksums $calculated_checksums_array($distfile)
                    foreach {type sum} $calculated_checksums {
                        dict lappend block_sums $distfile_block [format "%-${tw}s%s" $type $sum]

                        set found [lsearch -exact ${missing_types} ${type}];
                        if { ${found} != -1} {
                            set missing_types [lreplace ${missing_types} ${found} ${found}]
                        }
                    }
                }

                # Append any default types not previously calculated
                if {[llength $missing_types]} {
                    set fullpath [file join $distpath $distfile]
                    if {![file isfile $fullpath]} {
                        return -code error "$distfile does not exist in $distpath"
                    }

                    foreach type $missing_types {
                        dict lappend block_sums $distfile_block \
                            [format "%-${tw}s%s" $type [calc_$type $fullpath]]
                    }
                }
            }

            # Output one suggestion per block
            dict for {block_idx sums} $block_sums {
                set blk [dict get $block_info $block_idx]
                if {[dict exists $blk start_line]} {
                    set lineno [expr {[dict get $blk start_line] + 1}]
                    ui_info "The correct checksum line may be (on line ${lineno}):"
                } else {
                    ui_info "The correct checksum line may be:"
                }
                ui_info [format_checksum_suggestion \
                    [dict get $blk keyword] \
                    [dict get $blk indent] \
                    [dict get $blk keyword_width] \
                    $sums]
            }
        }

        return -code error "[msgcat::mc "Unable to verify file checksums"]"
    }

    return 0
}

# et:ts=4
# portchecksum.tcl
#
# Copyright (c) 2002 - 2004 Apple Computer, Inc.
# Copyright (c) 2004 Paul Guyot, Darwinports Team.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

set com.apple.checksum [target_new com.apple.checksum checksum_main]
target_provides ${com.apple.checksum} checksum
target_requires ${com.apple.checksum} main fetch
target_prerun ${com.apple.checksum} checksum_start

# Options
options checksums

# Defaults
default checksums ""

set_ui_prefix

# The list of the types of checksums we know.
set checksum_types "md5 sha1"

# The number of types we know.
set checksum_types_count [llength $checksum_types]

# fchecksums
#
# Considering the list of checksums, returns only the checksums for the given
# file. This function returns -1 if no checksum can be found for the file.
# The checksum types are checked.
#
# Remark #1: the format of the list prevents us from having a file name equal to
# one of the types.
# Remark #2: the current implementation prevents us from having a file name
# equal to one of sums.
#
# checksums -> the list of checksums in the format:
#	file type sum [type sum] [type sum] ...
# file -> the file to find.
# return a list in the format type sum [type sum] ...
#
proc fchecksums {checksums file} {
	global checksum_types

	set i [lsearch $checksums $file]

	if {$i == -1} {
		return -1
	}

	# Start at the first item after the filename.
	set start [expr $i + 1]

	# Check every other item, making sure they're valid checksum types.
	while {1} {
		if {[lsearch $checksum_types [lindex $checksums [expr $i + 1]]] == -1} {
			break
		}

		incr i 2
	}

	# If no checksums were found, the checksums option is probably invalid.
	if {$start >= $i} {
		return -1
	}

	return [lrange $checksums $start $i]
}

# check_md5
#
# Check the md5 checksum for the given file.
# Return 0 if the checksum is incorrect, 1 otherwise.
#
proc check_md5 {file sum} {
	return [string equal $sum [md5 file $file]]
}

# check_sha1
#
# Check the sha1 checksum for the given file.
# Return 0 if the checksum is incorrect, 1 otherwise.
#
proc check_sha1 {file sum} {
	return [string equal $sum [sha1 file $file]]
}

# checksum_start
#
# Target prerun procedure; simply prints a message about what we're doing.
#
proc checksum_start {args} {
	global UI_PREFIX

	ui_msg "$UI_PREFIX [format [msgcat::mc "Verifying checksum(s) for %s"] [option portname]]"
}

# checksum_main
#
# Target main procedure. Verifies the checksums of all distfiles.
#
proc checksum_main {args} {
	global UI_PREFIX all_dist_files checksum_types_count

	# If no files have been downloaded, there is nothing to checksum.
	if {![info exists all_dist_files]} {
		return 0
	}

	# Set the list of checksums as the option checksums.
	set checksums [option checksums]

	# However, this list might not be in our format.
	
	# Indeed, we are using a short checksum form if:
	# (1) There is only one distfile.
	# (2) There are an even number of words in checksums (i.e. "md5 cksum sha1 cksum" = 4 words).
	# (3) There are no more than $checksum_types_count checksums specified.
	if {[llength $all_dist_files] == 1
		&& [expr [llength $checksums] % 2] == 0
		&& [expr [llength $checksums] / 2] <= $checksum_types_count} {
		set checksums [linsert $checksums 0 $all_dist_files]
	}

	set fail no
	
	set distpath [option distpath]

	foreach distfile $all_dist_files {
		ui_info "$UI_PREFIX [format [msgcat::mc "Checksumming %s"] $distfile]"

		# get the full path of the distfile.
		set fullpath [file join $distpath $distfile]

		# obtain the checksums for this file from the portfile (i.e. from $checksums)
		set portfile_checksums [fchecksums $checksums $distfile]

		# check that there is at least one checksum for the distfile.
		if {$portfile_checksums == -1} {
			ui_error "[format [msgcat::mc "No checksum set for %s"] $distfile]"
			ui_info "[format [msgcat::mc "Correct checksum: %s sha1 %s"] $distfile [sha1 file $fullpath]]"
			set fail yes
		} else {
			# iterate on this list to check the actual values.
			foreach {type sum} $portfile_checksums {
				if {[check_$type $fullpath $sum]} {
					ui_debug "[format [msgcat::mc "Correct (%s) checksum for %s"] $type $distfile]"
				} else {
					ui_error "[format [msgcat::mc "Checksum (%s) mismatch for %s"] $type $distfile]"
					ui_info "[format [msgcat::mc "Correct checksum: %s %s %s"] $distfile $type [sha1 file $fullpath]]"
					
					# Raise the failure flag
					set fail yes
					
					# Exit.
					break
				}
			}
		}
	}

	if {[tbool fail]} {
		return -code error "[msgcat::mc "Unable to verify file checksums"]"
	}

	return 0
}

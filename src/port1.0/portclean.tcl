# et:ts=4
# portclean.tcl
# $Id$
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

# the 'clean' target is provided by this package

package provide portclean 1.0
package require portutil 1.0
package require Pextlib 1.0

set com.apple.clean [target_new com.apple.clean clean_main]
target_runtype ${com.apple.clean} always
target_provides ${com.apple.clean} clean
target_requires ${com.apple.clean} main
target_prerun ${com.apple.clean} clean_start

set_ui_prefix

proc clean_start {args} {
    global UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Cleaning %s"] [option portname]]"
}

proc clean_main {args} {
    global UI_PREFIX
	global ports_clean_dist ports_clean_work ports_clean_archive
	global ports_clean_all

	if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
		[info exists ports_clean_dist] && $ports_clean_dist == "yes"} {
		ui_info "$UI_PREFIX [format [msgcat::mc "Removing distfiles for %s"] [option portname]]"
		clean_dist
	}
	if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
		[info exists ports_clean_archive] && $ports_clean_archive == "yes"} {
		ui_info "$UI_PREFIX [format [msgcat::mc "Removing archives for %s"] [option portname]]"
		clean_archive
	}
	if {[info exists ports_clean_all] && $ports_clean_all == "yes" || \
		[info exists ports_clean_work] && $ports_clean_work == "yes" || \
		(!([info exists ports_clean_dist] && $ports_clean_dist == "yes") && \
		 !([info exists ports_clean_archive] && $ports_clean_archive == "yes"))} {
		 ui_info "$UI_PREFIX [format [msgcat::mc "Removing workpath for %s"] [option portname]]"
		 clean_work
	}

    return 0
}

#
# Remove the directory where the distfiles reside.
# This is crude, but works.
#
proc clean_dist {args} {
	global ports_force portname distpath dist_subdir distfiles

	# remove known distfiles for sure (if they exist)
	set count 0
	foreach file $distfiles {
		if {[info exist distpath] && [info exists dist_subdir]} {
			set distfile [file join $distpath $dist_subdir $file]
		} else {
			set distfile [file join $distpath $file]
		}
		if {[file isfile $distfile]} {
			ui_debug "Removing file: $distfile"
			if {[catch {delete $distfile} result]} {
				ui_debug "$::errorInfo"
				ui_error "$result"
			}
			set count [expr $count + 1]
		}
	}
	if {$count > 0} {
		ui_debug "$count distfile(s) removed."
	} else {
		ui_debug "No distfiles found to remove."
	}

	# next remove dist_subdir if only needed for this port,
	# or if user forces us to
	set dirlist [list]
	if {($dist_subdir != $portname)} {
		if {[info exists dist_subdir]} {
			set distfullpath [file join $distpath $dist_subdir]
			if {!([info exists ports_force] && $ports_force == "yes")
				&& [file isdirectory $distfullpath]
				&& [llength [readdir $distfullpath]] > 0} {
				ui_warn [format [msgcat::mc "Distfiles directory '%s' may contain distfiles needed for other ports, use the -f flag to force removal" ] [file join $distpath $dist_subdir]]
			} else {
				lappend dirlist $dist_subdir
				lappend dirlist $portname
			}
		} else {
			lappend dirlist $portname
		}
	} else {
		lappend dirlist $portname
	}
	# loop through directories
	set count 0
	foreach dir $dirlist {
		set distdir [file join $distpath $dir]
		if {[file isdirectory $distdir]} {
			ui_debug "Removing directory: ${distdir}"
			if {[catch {delete $distdir} result]} {
				ui_debug "$::errorInfo"
				ui_error "$result"
			}
			set count [expr $count + 1]
		}
	}
	if {$count > 0} {
		ui_debug "$count distfile directory(s) removed."
	} else {
		ui_debug "No distfile directory found to remove."
	}
	return 0
}

proc clean_work {args} {
	global workpath worksymlink

	if {[file isdirectory $workpath]} {
		ui_debug "Removing directory: ${workpath}"
		if {[catch {delete $workpath} result]} {
			ui_debug "$::errorInfo"
			ui_error "$result"
		}
	} else {
		ui_debug "No work directory found to remove."
	}

	# Clean symlink, if necessary
	if {![catch {file type $worksymlink} result] && $result eq "link"} {
		ui_debug "Removing symlink: $worksymlink"
		delete $worksymlink
	}

	return 0
}

proc clean_archive {args} {
	global workpath portarchivepath portname portversion ports_version_glob

	# Define archive destination directory and target filename
	if {$portarchivepath ne $workpath && $portarchivepath ne ""} {
		set archivepath [file join $portarchivepath [option os.platform] [option os.arch]]
	}

	if {[info exists ports_version_glob]} {
		# Match all possible archive variatns that match the version
		# glob specified by the user for this OS.
		set fileglob "$portname-[option ports_version_glob]*.[option os.arch].*"
	} else {
		# Match all possible archive variants for the current version on
		# this OS. If you want to delete previous versions, use the
		# version glob argument to clean.
		#
		# We do this because if we don't, then ports that match the
		# first part of the name (e.g. trying to remove foo-*, it will
		# pick up anything foo-bar-* as well, which is undesirable).
		set fileglob "$portname-$portversion*.[option os.arch].*"
	}

	# Remove the archive files
	set count 0
	if {![catch {set archivelist [glob [file join $archivepath $fileglob]]} result]} {
		foreach path $archivelist {
			set file [file tail $path]
			# Make sure file is truly a port archive file, and not
			# and accidental match with some other file that might exist.
			if {[regexp "^$portname-\[-_a-zA-Z0-9\.\]+_\[0-9\]*\[+-_a-zA-Z0-9\]*\[\.\][option os.arch]\[\.\]\[a-z\]+\$" $file]} {
				if {[file isfile $path]} {
					ui_debug "Removing archive: $path"
					if {[catch {delete $path} result]} {
						ui_debug "$::errorInfo"
						ui_error "$result"
					}
					set count [expr $count + 1]
				}
			}
		}
	}
	if {$count > 0} {
		ui_debug "$count archive(s) removed."
	} else {
		ui_debug "No archives found to remove."
	}

	return 0
}


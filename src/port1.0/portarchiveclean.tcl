# vim:ts=4 sw=4 fo=croq
# portarchiveclean.tcl
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

# the 'archiveclean' target is provided by this package

package provide portarchiveclean 1.0
package require portutil 1.0

set com.apple.archiveclean [target_new com.apple.archiveclean archiveclean_main]
target_runtype ${com.apple.archiveclean} always
target_provides ${com.apple.archiveclean} archiveclean
target_requires ${com.apple.archiveclean} main
target_prerun ${com.apple.archiveclean} archiveclean_start

# defaults
default archiveclean.path {${portarchivepath}}

set_ui_prefix

proc archiveclean_start {args} {
	global UI_PREFIX ports_force
	global portname portversion portrevision portvariants
	global archiveclean.path workpath

	# Define port variants if not already defined
	if { ![info exists portvariants] } {
		set portvariants ""
		set vlist [lsort -ascii [array names variations]]
		# Put together variants in the form +foo+bar for the archive name
		foreach v $vlist {
			if { ![string equal $v [option os.platform]] && ![string equal $v [option os.arch]] } {
				set portvariants "${portvariants}+${v}"
			}
		}
	}

	# Define archive destination directory and target filename
	if {![string equal ${archiveclean.path} ${workpath}] && ![string equal ${archiveclean.path} ""]} {
		set archiveclean.path [file join ${archiveclean.path} [option os.platform] [option os.arch]]
	}

	if {[info exists ports_force] && $ports_force == "yes"} {
		ui_msg "$UI_PREFIX [format [msgcat::mc "Removing ALL archives for %s"] $portname]"
	} else {
		ui_msg "$UI_PREFIX [format [msgcat::mc "Removing archives for %s %s_%s%s"] $portname $portversion $portrevision $portvariants]"
	}
}


# Remove archives for current OS arch that match the port name, version,
# revision, and variants if force is NOT set. If force IS set, remove
# all archives for current OS arch that match just the port name.

proc archiveclean_main {args} {
	global ports_force
	global portname portversion portrevision portvariants
	global archiveclean.path

	if {[info exists ports_force] && $ports_force == "yes"} {
		set archive.glob "${portname}-*_*.[option os.arch].*"
	} else {
		set archive.glob "${portname}-${portversion}_${portrevision}${portvariants}.[option os.arch].*"
	}

	if {![catch {set filelist [glob [file join ${archiveclean.path} ${archive.glob}]]} result]} {
		foreach archive.file $filelist {
			set archive.path "[file join ${archiveclean.path} ${archive.file}]"
			if {[file isfile ${archive.path}]} {
				ui_debug "Removing archive: ${archive.path}"
				file delete ${archive.path}
			}
		}
	} else {
		ui_msg "No archive(s) found to remove."
	}

	return 0
}


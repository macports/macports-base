# et:ts=4
# portdistclean.tcl
#
# Copyright (c) 2004 Ole Guldberg Jensen, The DarwinPorts Team.
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

# the 'distclean' target is provided by this package

package provide portdistclean 1.0
package require portutil 1.0

set com.apple.distclean [target_new com.apple.distclean distclean_main]
target_runtype ${com.apple.distclean} always
target_provides ${com.apple.distclean} distclean
target_requires ${com.apple.distclean} main
target_prerun ${com.apple.distclean} distclean_start

set_ui_prefix

proc distclean_start {args} {
    global UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Removing distfiles for %s"] [option portname]]"
}

#
# Remove the directory where the distfiles reside.
# This is crude, but works.
#
proc distclean_main {args} {
	global ports_force portname distpath dist_subdir distfiles

	# remove known distfiles for sure (if they exist)
	foreach file $distfiles {
		if {[info exist distpath] && [info exists dist_subdir]} {
			set distfile [file join ${distpath} ${dist_subdir} ${file}]
		} else {
			set distfile [file join ${distpath} ${file}]
		}
		if {[file isfile $distfile]} {
			ui_debug "Removing file: $distfile"
			file delete $distfile
		}
	}

	# next remove dist_subdir if only needed for this port,
	# or if user forces us to
	set dirlist [list]
	if {[info exists dist_subdir]} {
		if {($dist_subdir != $portname) && !([info exists ports_force] && $ports_force == "yes")} {
			ui_warn [format [msgcat::mc "Distfiles directory '%s' may contain distfiles needed for other ports, use the -f flag to force removal" ] [file join ${distpath} ${dist_subdir}]]
			return 1 
		}
		lappend dirlist $dist_subdir
	}
	lappend dirlist $portname
	foreach dir $dirlist {
		set distdir [file join ${distpath} ${dir}]
		if {[file isdirectory ${distdir}]} {
			ui_debug "Removing directory: ${distdir}"
			file delete -force $distdir
		}
	}
	return 0
}


# et:ts=4
# portchecksum.tcl
#
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

PortTarget 1.0

name		org.opendarwin.checksum
requires	fetch
provides	checksum

# define options
options checksums

set UI_PREFIX "---> "

proc md5 {file} {
    global UI_PREFIX

    set md5regex "^(MD5)\[ \]\\((.+)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
    if {[catch {set pipe [open "|md5 \"${file}\"" r]} result]} {
        return -code error "[format [msgcat::mc "Unable to parse checksum: %s"] $result]"
    }
    set line [read $pipe]
    if {[regexp $md5regex $line match type filename sum] == 1} {
	close $pipe
	if {$filename == $file} {
	    return $sum
	} else {
	    return -1
	}
    } else {
	close $pipe
	return -code error "[format [msgcat::mc "Unable to parse checksum: %s"] $line]"
    }
}

proc dmd5 {file} {
    foreach {name type sum} [option checksums] {
	if {$name == $file} {
	    return $sum
	}
    }
    return -1
}

proc start {args} {
    global UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Verifying checksum for %s"] [option portname]]"
}

proc main {args} {
    global UI_PREFIX

	set all_dist_files [option all_dist_files]

    # If no files have been downloaded there is nothing to checksum
    if {![exists all_dist_files]} {
		return 0
    }

    if {![exists checksums]} {
	ui_error "[msgcat::mc "No checksums statement in Portfile.  File checksums are:"]"
	foreach distfile $all_dist_files {
	    ui_msg "$distfile md5 [md5 [option distpath]/$distfile]"
	}
	return -code error "[msgcat::mc "No checksums statement in Portfile."]"
    }

    # Optimization for the 2 argument case for checksums
    if {[llength [option checksums]] == 2 && [llength $all_dist_files] == 1} {
	option checksums [linsert [option checksums] 0 $all_dist_files]
    }

    foreach distfile $all_dist_files {
	set checksum [md5 [option distpath]/$distfile]
	set dchecksum [dmd5 $distfile]
	if {$dchecksum == -1} {
	    ui_warn "[format [msgcat::mc "No checksum recorded for %s"] $distfile]"
	} elseif {$checksum != $dchecksum} {
	    return -code error "[format [msgcat::mc "Checksum mismatch for %s"] $distfile]"
	}
    }
	
	option all_dist_files $all_dist_files
	
    return 0
}

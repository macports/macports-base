# et:ts=4
# portchecksum.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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
${com.apple.checksum} provides checksum
${com.apple.checksum} requires main fetch
${com.apple.checksum} set prerun checksum_start

# define options
options checksums

set UI_PREFIX "---> "

proc md5 {file} {
    global distpath UI_PREFIX

    set md5regex "^(MD5)\[ \]\\((.+)\\)\[ \]=\[ \](\[A-Za-z0-9\]+)\n$"
    set pipe [open "|md5 \"${file}\"" r]
    set line [read $pipe]
    if {[regexp $md5regex $line match type filename sum] == 1} {
	close $pipe
	if {$filename == $file} {
	    return $sum
	} else {
	    return -1
	}
    } else {
	# XXX Handle this error beter
	close $pipe
	ui_error "$line - md5sum failed!"
	return -1
    }
}

proc dmd5 {file} {
    global checksums

    foreach {name type sum} $checksums {
	if {$name == $file} {
	    return $sum
	}
    }
    return -1
}

proc checksum_start {args} {
    global UI_PREFIX portname

    ui_msg "$UI_PREFIX Verifying checksum for $portname"
}

proc checksum_main {args} {
    global checksums distpath all_dist_files UI_PREFIX

    # If no files have been downloaded there is nothing to checksum
    if ![info exists all_dist_files] {
	return 0
    }

    if ![info exists checksums] {
	ui_error "No checksums statement in Portfile.  File checksums are:"
	foreach distfile $all_dist_files {
	    ui_msg "$distfile md5 [md5 $distpath/$distfile]"
	}
	return -code error "No checksums statement in Portfile."
    }

    # Optimization for the 2 argument case for checksums
    if {[llength $checksums] == 2 && [llength $all_dist_files] == 1} {
	set checksums [linsert $checksums 0 $all_dist_files]
    }

    foreach distfile $all_dist_files {
	set checksum [md5 $distpath/$distfile]
	set dchecksum [dmd5 $distfile]
	if {$dchecksum == -1} {
	    ui_warn "No checksum recorded for $distfile"
	} elseif {$checksum != $dchecksum} {
	    ui_error "Checksum mismatch for $distfile"
	    return -code error "Checksum mismatch for $distfile"
	}
    }
    return 0
}

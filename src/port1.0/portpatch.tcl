# et:ts=4
# portpatch.tcl
# $Id$
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

package provide portpatch 1.0
package require portutil 1.0

set com.apple.patch [target_new com.apple.patch patch_main]
target_provides ${com.apple.patch} patch
target_requires ${com.apple.patch} main fetch checksum extract 

set_ui_prefix

# Add command patch
commands patch
# Set up defaults
default patch.dir {${worksrcpath}}
default patch.cmd patch
default patch.pre_args -p0

proc patch_main {args} {
    global UI_PREFIX
    
    # First make sure that patchfiles exists and isn't stubbed out.
    if {![exists patchfiles]} {
	return 0
    }
    
	ui_msg "$UI_PREFIX [format [msgcat::mc "Applying patches to %s"] [option portname]]"

    foreach patch [option patchfiles] {
    set patch_file [getdistname $patch]
	if {[file exists [option filespath]/$patch_file]} {
	    lappend patchlist [option filespath]/$patch_file
	} elseif {[file exists [option distpath]/$patch_file]} {
	    lappend patchlist [option distpath]/$patch_file
	} else {
		return -code error [format [msgcat::mc "Patch file %s is missing"] $patch]
	}
    }
    if {![info exists patchlist]} {
	return -code error [msgcat::mc "Patch files missing"]
    }
    cd [option worksrcpath]
    foreach patch $patchlist {
	ui_info "$UI_PREFIX [format [msgcat::mc "Applying %s"] $patch]"
	if {[option os.platform] == "linux"} {
	    set gzcat "zcat"
	} else {
	    set gzcat "gzcat"
	}
	switch -glob -- [file tail $patch] {
	    *.Z -
	    *.gz {system "$gzcat \"$patch\" | ([command patch])"}
	    *.bz2 {system "bzcat \"$patch\" | ([command patch])"}
	    default {system "[command patch] < \"$patch\""}
	}
    }
    return 0
}

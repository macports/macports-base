# ex:ts=4
# portpatch.tcl
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

package provide portpatch 1.0
package require portutil 1.0

register com.apple.patch target patch_main patch_init
register com.apple.patch provides patch
register com.apple.patch requires main fetch checksum extract depends_build depends_lib

set UI_PREFIX "---> "

proc patch_init {args} {
    return 0
}

proc patch_main {args} {
    global portname patchfiles distpath filedir workdir portpath UI_PREFIX

    if ![info exists patchfiles] {
	return 0
    }
    foreach patch $patchfiles {
	if [file exists $portpath/$filedir/$patch] {
	    lappend patchlist $portpath/$filedir/$patch
	} elseif [file exists $distpath/$patch] {
	    lappend patchlist $distpath/$patch
	}
    }
    if ![info exists patchlist] {
	return -code error "Patch files missing"
    }
    cd $portpath/$workdir
    foreach patch $patchlist {
	ui_info "$UI_PREFIX Applying $patch"
	switch -glob -- [file tail $patch] {
	    *.Z -
	    *.gz {system "gzcat \"$patch\" | patch -p0"}
	    *.bz2 {system "bzcat \"$patch\" | patch -p0"}
	    default {system "patch -p0 < \"$patch\""}
	}
    }
    return 0
}

# ex:ts=4
# portuninstall.tcl
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

package provide portcontents 1.0
package require portutil 1.0

set com.apple.contents [target_new com.apple.contents contents_main]
${com.apple.contents} set runtype always
${com.apple.contents} provides contents
${com.apple.contents} requires main

set UI_PREFIX "---> "

proc contents_main {args} {
    global portname portversion UI_PREFIX

    set rfile [registry_exists $portname $portversion]
    if [string length $rfile] {
	if [regexp .bz2$ $rfile] {
	    set fd [open "|bunzip2 -c $rfile" r]
	} else {
	    set fd [open $rfile r]
	}
	set entry [read $fd]
	close $fd

	# look for a contents list
	set ix [lsearch $entry contents]
	if {$ix >= 0} {
	    set contents [lindex $entry [incr ix]]
	    set uninst_err 0
	    ui_msg "Contents of ${portname}-${portversion}:"
	    foreach f $contents {
		ui_msg [lindex $f 0]
	    }
	} else {
	    return -code error "No contents list for ${portname}-${portversion}"
	}
    } else {
	return -code error "Contents listing failed - no registry entry"
    }
}

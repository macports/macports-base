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

package provide portuninstall 1.0
package require portutil 1.0

register com.apple.uninstall target uninstall_main
register com.apple.uninstall provides uninstall
register com.apple.uninstall requires main

# define options
options uninstall.force uninstall.nochecksum

set UI_PREFIX "---> "

proc uninstall_main {args} {
    global portname portversion uninstall.force uninstall.nochecksum UI_PREFIX

    set rfile [registry_exists $portname $portversion]
    if [string length $rfile] {
	ui_msg "$UI_PREFIX Uninstalling $portname-$portversion"
	if [regexp .bz2$ $rfile] {
	    set fd [open "|bunzip2 -c $rfile" r]
	} else {
	    set fd [open $rfile r]
	}
	set entry [read $fd]
	close $fd
	set ix [lsearch $entry contents]
	if {$ix >= 0} {
	    set contents [lindex $entry [incr ix]]
	    set uninst_err 0
	    foreach f $contents {
		set fname [lindex $f 0]
		set sum1 [lindex [lindex $f 5] 3]
		if {![string match $sum1 NONE] && ![tbool uninstall.nochecksum]} {
		    if ![catch {set sum2 [md5 $fname]}] {
			if ![string match $sum1 $sum2] {
			    ui_info "$UI_PREFIX  Original checksum does not match for $fname, not removing"
			    set uninst_err 1
			    continue
			}
		    }
		}
		ui_info "$UI_PREFIX   Uninstall is removing $fname"
		if [file isdirectory $fname] {
		    if [catch {exec rmdir $fname}] {
			ui_msg "$UI_PREFIX  Uninstall unable to remove directory $fname (not empty?)"
			set uninst_err 1
		    }
		} else {
		    if [catch {exec rm $fname}] {
			ui_msg "$UI_PREFIX  Uninstall unable to remove file $fname"
			set uninst_err 1
		    }
		}
	    }
	    if {!$uninst_err} {
		registry_delete $portname $portversion
		return 0
	    }
	} else {
	    return -1
	}
    }
    return -1
}

# et:ts=4
# portuninstall.tcl
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

package provide portuninstall 1.0
package require portutil 1.0

set com.apple.uninstall [target_new com.apple.uninstall uninstall_main]
target_runtype ${com.apple.uninstall} always
target_provides ${com.apple.uninstall} uninstall
target_requires ${com.apple.uninstall} main
target_prerun ${com.apple.uninstall} uninstall_start

# define options
options uninstall.force uninstall.nochecksum

set UI_PREFIX "---> "

proc uninstall_start {args} {
    global portname portversion UI_PREFIX

    if {[string length [registry_exists $portname $portversion]]} {
	ui_msg "$UI_PREFIX [format [msgcat::mc "Uninstalling %s-%s"] $portname $portversion]"
    }
}

proc uninstall_main {args} {
    global portname portversion uninstall.force uninstall.nochecksum ports_force UI_PREFIX

    # If global forcing is on, make it the same as a local force flag.
    if {[tbool ports_force]} {
	set uninstall.force "yes"
    }

    set rfile [registry_exists $portname $portversion]
    if {[string length $rfile]} {
	if {[regexp .bz2$ $rfile]} {
	    set fd [open "|bunzip2 -c $rfile" r]
	} else {
	    set fd [open $rfile r]
	}
	set entry [read $fd]
	close $fd

	# First look to see if the port has registered an uninstall procedure
	set ix [lsearch $entry pkg_uninstall]
	if {$ix >= 0} {
	    set uninstall [lindex $entry [incr ix]]
	    if {![catch {eval $uninstall} err]} {
		pkg_uninstall $portname $portversion
	    } else {
		ui_error [format [msgcat::mc "Could not evaluate pkg_uninstall procedure: %s"] $err]
	    }
	}

	# Now look for a contents list
	set ix [lsearch $entry contents]
	if {$ix >= 0} {
	    set contents [lsort -decreasing [lindex $entry [incr ix]]]
	    set uninst_err 0
	    foreach f $contents {
		set fname [lindex $f 0]
		set md5index [lsearch -regex [lrange $f 1 end] MD5]
		if {$md5index != -1} {
			set sumx [lindex $f [expr $md5index + 1]]
		} else {
			# XXX There is no MD5 listed, set sumx to an empty
			# list, causing the next conditional to return a
			# checksum error
			set sumx {}
		}
		set sum1 [lindex $sumx [expr [llength $sumx] - 1]]
		if {![string match $sum1 NONE] && ![tbool uninstall.nochecksum]} {
		    if {![catch {set sum2 [md5 $fname]}]} {
			if {![string match $sum1 $sum2]} {
			    if {![tbool uninstall.force]} {
				ui_info "$UI_PREFIX  [format [msgcat::mc "Original checksum does not match for %s, not removing"] $fname]"
				set uninst_err 1
				continue
			    } else {
				ui_info "$UI_PREFIX  [format [msgcat::mc "Original checksum does not match for %s, removing anyway [force in effect]"] $fname]"
			    }
			}
		    }
		}
		ui_info "$UI_PREFIX [format [msgcat::mc "Uninstall is removing %s"] $fname]"
		if {[file isdirectory $fname]} {
		    if {[catch {file delete -- $fname} result]} {
			# A non-empty directory is not a fatal error
			if {$result != "error deleting \"$fname\": directory not empty"} {
			    ui_info "$UI_PREFIX  [format [msgcat::mc "Uninstall unable to remove directory %s (not empty?)"] $fname]"
			}
		    }
		} else {
		    if {[catch {file delete -- $fname}]} {
			ui_info "$UI_PREFIX  [format [msgcat::mc "Uninstall unable to remove file %s"] $fname]"
			set uninst_err 1
		    }
		}
	    }
	    if {!$uninst_err || [tbool uninstall.force]} {
		registry_delete $portname $portversion
		return 0
	    }
	} else {
	    return -code error [msgcat::mc "Uninstall failed: Port has no contents entry"]
	}
    }
    return -code error [msgcat::mc "Uninstall failed: Port not registered as installed"]
}

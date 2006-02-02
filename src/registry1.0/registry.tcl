# registry.tcl
#
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
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

package provide registry 1.0

package require darwinports 1.0
package require portuninstall 1.0
package require msgcat

namespace eval registry {

# Check to see if an entry exists in the registry.  This is passed straight 
# through to the receipts system
proc entry_exists {name version {revision 0} {variants ""}} {
	if { [catch {set res [system "rpm -q $name-$version-$revision"]} ] == 1 } {
		return 0
	} else {
		return 1
	}
}

# If only one version of the port is installed, this process returns that
# version's parts.  Otherwise, it lists the versions installed and exists.
proc installed {{name ""} {version ""}} {
	# more mapping
	set name [string map {- _} $name]

	set ilist [split [exec rpm "-qa" "$name"]]
	set rlist [list]

	if {$ilist == {} } {
		return {}
	}

	if { [llength $ilist] > 1 } {
		foreach installed $ilist {
			set inslst [split $installed -]
			set iname [lindex $inslst 0]
			set iname [string map {_ -} $iname]
			set iversion [lindex $inslst 1]
			set irevision [lindex $inslst 2]
			set ivariants ""
			set iref ""
			set iactive	""
			set iepoch ""
			lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
		}
	} else {
		set installed [split $ilist -]
		set iname [lindex $installed 0]
		set iversion [lindex $installed 1]
		set irevision [lindex $installed 2]
		set ivariants ""
		set iref ""
		set iactive	""
		set iepoch ""
		lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
	}
	return $rlist
}

proc location {portname portversion} {
	set ilist [registry::installed $portname $portversion]

	if { [llength $ilist] > 1 } {
		puts "The following versions of $portname are currently installed:"
		foreach i $ilist { 
			set iname [lindex $i 0]
			set iversion [lindex $i 1]
			set irevision [lindex $i 2]
			set ivariants [lindex $i 3]
			ui_msg "	$iname ${iversion}_${irevision}${ivariants}"
		}
		return -1
	} else {
		return [lindex $ilist 0]
	}
}	

proc file_registered {file} {
	if { [catch {set res [exec "rpm" "-qf" "$file"]}] } {
		return 0
	} else {
		return $res
	}
}

proc port_registered {name} {
	if {[catch {set res [exec "rpm" "-q" "--filesbypkg" "$name"]}] } {
		return {}
	} else {
		set rlist [list]
		foreach l $res {
			if {$l != $name} {
				lappend rlist $l
			}
		}
		return $rlist
	}
}

# List all dependencies for this port
proc list_depends {name} {

	set name [string map {- _} $name]

	if { [catch {set res [exec "rpm" "-q" "--requires" "$name"]}] } {
		return {}
	} else {
		return $res
	}
}

# List all the ports that depend on this port
proc list_dependents {name} {

	set name [string map {- _} $name]

	if { [catch {set res [exec "rpm" "-q" "--whatrequires" "$name"]}] } {
		return {}
	} else {
		return $res
	}
}

# End of registry namespace
}


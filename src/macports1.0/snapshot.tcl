# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# snapshot.tcl
#
# Copyright (c) 2017 The MacPorts Project
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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

package provide snapshot 1.0

package require macports 1.0
package require registry 1.0

namespace eval snapshot {
	proc main {opts} {
		# Function to create a snapshot of the current state of ports.
        #
        # Args:
        #           opts - The options passed in.
        # Returns:
        #           registry::snapshot

        array set options $opts

        registry::write {
            # An option used by user while creating snapshot manually
            # to identify a snapshot, usually followed by `port restore`
            if {[info exists options(ports_snapshot_note)]} {
                set note $options(ports_snapshot_note)
            } else {
                set note "snapshot created for migration"
            }
            set inactive_ports  [list]
            foreach port [registry::entry imaged] {
                if {[$port state] eq "imaged"} {
                    lappend inactive_ports "[$port name] @[$port version]_[$port revision] [$port variants][$port negated_variants]"
                }
            }
            if {[llength $inactive_ports] != 0} {
                set msg "Following inactive ports will not be a part of this snapshot and won't be installed while restoring:"
                set inactive_ports [lsort -index 0 -nocase $inactive_ports]
                if {[info exists macports::ui_options(questions_yesno)]} {
                    set retvalue [$macports::ui_options(questions_yesno) $msg "Continue?" $inactive_ports {y} 0]
                    if {$retvalue != 0} {
                        ui_msg "Not creating a snapshot!"
                        return 0
                    }
                } else {
                    puts $msg
                    foreach port $inactive_ports {
                        puts $port
                    }
                }
            }
            set snapshot [registry::snapshot create $note]
            # TODO: catch
        }
        return $snapshot
    }
}

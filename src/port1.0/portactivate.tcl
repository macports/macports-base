# et:ts=4
# portactivate.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
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

# the 'activate' target is provided by this package

package provide portactivate 1.0
package require portutil 1.0

set org.macports.activate [target_new org.macports.activate portactivate::activate_main]
target_runtype ${org.macports.activate} always
target_state ${org.macports.activate} no
target_provides ${org.macports.activate} activate
if {[option portarchivemode] == "yes"} {
    target_requires ${org.macports.activate} main unarchive fetch extract checksum patch configure build destroot archive install
} else {
    target_requires ${org.macports.activate} main fetch extract checksum patch configure build destroot install
}

namespace eval portactivate {
}

set_ui_prefix

proc portactivate::activate_main {args} {
    global env name version revision portvariants user_options portnotes
    registry_activate $name ${version}_${revision}${portvariants} [array get user_options]

    # Display notes at the end of the activation phase.
    if {[info exists portnotes] && $portnotes ne {}} {
        # If env(COLUMNS) exists, limit each line's width to this width.
        if {[info exists env(COLUMNS)]} {
            set maxlen $env(COLUMNS)

            ui_msg ""
            foreach line [split $portnotes "\n"] {
                set joiner ""
                set lines ""
                set newline ""

                foreach word [split $line " "] {
                    if {[string length $newline] + [string length $word] >= $maxlen} {
                        lappend lines $newline
                        set newline ""
                        set joiner ""
                    }
                    append newline $joiner $word
                    set joiner " "
                }
                if {$newline ne {}} {
                    lappend lines $newline
                }
                ui_msg [join $lines "\n"]
            }
            ui_msg ""
        } else {
            ui_msg \n$portnotes\n
        }
    }

    return 0
}

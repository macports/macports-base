# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2019-2020 The MacPorts Project
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

package provide portprogress 1.0
package require portutil 1.0
package require Pextlib 1.0

namespace eval portprogress {
    # The time in milliseconds to wait before we switch our progress bar from
    # determinate to indeterminate
    variable indeterminate_threshold    10000

    # The time (in milliseconds since epoch) since our progress callback last
    # produced a determinate progress update.
    variable indeterminate_timer        0

    # If our progress callback should issue indeterminate progress updates
    variable indeterminate              yes

    # ninja ([<completed tasks>/<pending tasks>])
    variable ninja_line_re              {^\[([1-9][0-9]*)/([1-9][0-9]*)\].*}

    # cmake makefiles ([<percentage>%])
    variable cmake_line_re              {^\[\s*([1-9][0-9]*)%\].*}
}

# A SystemCmd callback that parses common target progress formats to display
# a progress bar
proc portprogress::target_progress_callback {event} {
    global portverbose
    variable indeterminate
    variable indeterminate_timer
    variable indeterminate_threshold
    variable ninja_line_re
    variable cmake_line_re

    if {${portverbose}} {
        return
    }

    switch -- [dict get $event type] {
        exec {
            set indeterminate yes
            set indeterminate_timer 0
            ui_progress_generic start
        }
        stdin {
            set line [dict get $event line]

            # Try to parse the build line
            set determinate_match no
            set cur 1
            set total 0

            # ninja ([<completed tasks>/<pending tasks>])
            if {[regexp $ninja_line_re ${line} -> cur total]} {
                set determinate_match yes

            # cmake makefiles ([<percentage>%])
            } elseif {[regexp $cmake_line_re ${line} -> cur]} {
                set total 100
                set determinate_match yes

            # No match
            } else {
                set cur 1
                set total 0
            }

            if {${determinate_match}} {
                set indeterminate no
                set indeterminate_timer [clock milliseconds]
            } elseif {!${indeterminate}} {
                set time_last $indeterminate_timer
                set time_now [clock milliseconds]
                set time_diff [expr { $time_now - $time_last }]

                if {${time_diff} >= ${indeterminate_threshold}} {
                    set indeterminate yes
                }
            }

            if {${determinate_match} || ${indeterminate}} {
                ui_progress_generic update ${cur} ${total}
            }
        }
        exit {
            ui_progress_generic finish
        }
    }
}

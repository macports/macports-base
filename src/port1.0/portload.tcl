# et:ts=4
# portsubmit.tcl
# $Id$
#
# Copyright (c) 2007 MacPorts Project
# Copyright (c) 2007 James D. Berry
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

package provide portload 1.0
package require portutil 1.0

set org.macports.load [target_new org.macports.load portload::load_main]
target_runtype ${org.macports.load} always
target_provides ${org.macports.load} load 
target_requires ${org.macports.load} main

namespace eval portload {
}

set_ui_prefix

proc portload::load_main {args} {
    global startupitem.type startupitem.name startupitem.location startupitem.plist
    set launchctl_path ${portutil::autoconf::launchctl_path}

    foreach { path } "/Library/${startupitem.location}/${startupitem.plist}" {
        if {[string length $launchctl_path] == 0} {
            return -code error [format [msgcat::mc "launchctl command was not found by configure"]]
        } elseif {![file exists $path]} {
            return -code error [format [msgcat::mc "Launchd plist %s was not found"] $path]
        } else {
            exec $launchctl_path load -w $path
        }
    }
    
    return
}

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portdeactivate.tcl
#
# Copyright (c) 2010-2011 The MacPorts Project
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
# 3. Neither the name of The MacPorts Project nor the names of its contributors
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

# the 'deactivate' target is provided by this package

package provide portdeactivate 1.0
package require portutil 1.0

set org.macports.deactivate [target_new org.macports.deactivate portdeactivate::deactivate_main]
target_runtype ${org.macports.deactivate} always
target_state ${org.macports.deactivate} no
target_provides ${org.macports.deactivate} deactivate
target_requires ${org.macports.deactivate} main
target_prerun ${org.macports.deactivate} portdeactivate::deactivate_start

namespace eval portdeactivate {
}

options deactivate.asroot
default deactivate.asroot no

proc portdeactivate::deactivate_start {args} {
    global prefix
    if {![file writable $prefix] || ([getuid] == 0 && [geteuid] != 0)} {
        # if install location is not writable, need root privileges
        elevateToRoot "deactivate"
    }
}

proc portdeactivate::deactivate_main {args} {
    global subport _inregistry_version _inregistry_revision _inregistry_variants user_options
    foreach {var backup} {_inregistry_version version _inregistry_revision revision _inregistry_variants portvariants} {
        if {![info exists $var]} {
            set $var [option $backup]
        }
    }

    if {[portstartupitem::loaded] ne ""} {
        if {[eval_targets "unload"]} {
            ui_warn [format [msgcat::mc "Failed to unload startupitem(s) for %s (continuing anyway)"] $subport]
        }
    }

    registry_deactivate $subport $_inregistry_version $_inregistry_revision $_inregistry_variants [array get user_options]
    return 0
}

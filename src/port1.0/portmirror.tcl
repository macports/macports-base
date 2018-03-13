# et:ts=4
# portmirror.tcl
#
# Copyright (c) 2007-2011 The MacPorts Project
# Copyright (c) 2006 Paul Guyot <pguyot@kallisys.net>,
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package provide portmirror 1.0
package require portutil 1.0
package require Pextlib 1.0
package require portfetch 1.0
package require portchecksum 1.0

set org.macports.mirror [target_new org.macports.mirror portmirror::mirror_main]
target_runtype ${org.macports.mirror} always
target_state ${org.macports.mirror} no
target_provides ${org.macports.mirror} mirror
target_requires ${org.macports.mirror} main

namespace eval portmirror {
}

# Mirror is a target that fetches & checksums files and delete them
# if the checksum isn't correct.
# It also records the path in a database.

proc portmirror::mirror_main {args} {
    global fetch.type mirror_filemap portdbpath subport license

    if {[lsearch -exact -nocase $license "nomirror"] >= 0} {
        ui_info "Not mirroring $subport due to license NoMirror"
        return
    }

    set mirror_filemap_path [file join $portdbpath distfiles_mirror.db]
    filemap open mirror_filemap $mirror_filemap_path

    # Check the distfiles if it's a regular fetch phase.
    if {${fetch.type} eq "standard"} {
        # fetch the files.
        portfetch::fetch_init $args
        portfetch::fetch_start $args
        portfetch::fetch_main $args

        # checksum the files.
        if {[catch {portchecksum::checksum_main $args}]} {
            # delete the files.
            portfetch::fetch_deletefiles $args
        } else {
            # add the list of files.
            portfetch::fetch_addfilestomap mirror_filemap
        }
    }

    # close the filemap.
    filemap close mirror_filemap
}

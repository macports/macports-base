# et:ts=4
# portpatch.tcl
#
# Copyright (c) 2004, 2006-2007, 2009-2011 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
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
#

package provide portpatch 1.0
package require portutil 1.0

set org.macports.patch [target_new org.macports.patch portpatch::patch_main]
target_provides ${org.macports.patch} patch
target_requires ${org.macports.patch} main fetch checksum extract

namespace eval portpatch {
}

set_ui_prefix

# Add command patch
commands patch

options patch.asroot
# Set up defaults
default patch.asroot no
default patch.dir {${worksrcpath}}
default patch.cmd {[portpatch::build_getpatchtype]}
default patch.pre_args -p0

proc portpatch::build_getpatchtype {args} {
    if {![exists patch.type]} {
        return [findBinary patch $portutil::autoconf::patch_path]
    }
    switch -exact -- [option patch.type] {
        gnu {
            return [findBinary gpatch $portutil::autoconf::gnupatch_path]
        }
        default {
            ui_warn "[format [msgcat::mc "Unknown patch.type %s, using 'patch'"] [option patch.type]]"
            return [findBinary patch $portutil::autoconf::patch_path]
        }
    }
}

proc portpatch::patch_main {args} {
    global UI_PREFIX

    # First make sure that patchfiles exists and isn't stubbed out.
    if {![exists patchfiles] || [option patchfiles] eq ""} {
        return 0
    }

    ui_notice "$UI_PREFIX [format [msgcat::mc "Applying patches to %s"] [option subport]]"

    foreach patch [option patchfiles] {
        set patch_file [getdistname $patch]
        if {[file exists [option filespath]/$patch_file]} {
            lappend patchlist [option filespath]/$patch_file
        } elseif {[file exists [option distpath]/$patch_file]} {
            lappend patchlist [option distpath]/$patch_file
        } else {
            return -code error [format [msgcat::mc "Patch file %s is missing"] $patch]
        }
    }
    if {![info exists patchlist]} {
        return -code error [msgcat::mc "Patch files missing"]
    }

    set gzcat "[findBinary gzip $portutil::autoconf::gzip_path] -dc"
    set bzcat "[findBinary bzip2 $portutil::autoconf::bzip2_path] -dc"
    catch {set xzcat "[findBinary xz $portutil::autoconf::xz_path] -dc"}

    foreach patch $patchlist {
        ui_info "$UI_PREFIX [format [msgcat::mc "Applying %s"] [file tail $patch]]"
        switch -- [file extension $patch] {
            .Z -
            .gz {command_exec patch "$gzcat \"$patch\" | (" ")"}
            .bz2 {command_exec patch "$bzcat \"$patch\" | (" ")"}
            .xz {
                if {[info exists xzcat]} {
                    command_exec patch "$xzcat \"$patch\" | (" ")"
                } else {
                    return -code error [msgcat::mc "xz binary not found; port needs to add 'depends_patch bin:xz:xz'"]
                }}
            default {command_exec patch "" "< '$patch'"}
        }
    }
    return 0
}

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portdistfiles.tcl
#
# Copyright (c) 2008-2011 The MacPorts Project
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

package provide portdistfiles 1.0
package require portutil 1.0
package require portfetch 1.0
package require portchecksum 1.0

set org.macports.distfiles [target_new org.macports.distfiles portdistfiles::distfiles_main]
target_runtype ${org.macports.distfiles} always
target_state ${org.macports.distfiles} no
target_provides ${org.macports.distfiles} distfiles
target_requires ${org.macports.distfiles} main
target_prerun ${org.macports.distfiles} portdistfiles::distfiles_start

namespace eval portdistfiles {
}

set_ui_prefix

proc portdistfiles::distfiles_start {args} {
    global UI_PREFIX subport
    ui_notice "$UI_PREFIX [format [msgcat::mc "Distfiles for %s"] ${subport}]"
}

proc portdistfiles::distfiles_main {args} {
    global master_sites patch_sites patchfiles checksums_array \
           portdbpath dist_subdir all_dist_files
    
    # give up on ports that do not provide URLs
    if {(![info exists master_sites] || $master_sites eq "{}")
        && (![info exists patchfiles] || ![info exists patch_sites] || $patch_sites eq "{}")} {
        return 0
    }

    # from portfetch... process the sites, files and patches
    set fetch_urls {}
    portfetch::checkfiles fetch_urls

    # also give up on ports that don't have any distfiles
    if {![info exists all_dist_files]} {
        return 0
    }

    # get checksum data from the portfile and parse it
    set checksums_str [option checksums]
    set result [portchecksum::parse_checksums $checksums_str]

    foreach {url_var distfile} $fetch_urls {
        global portfetch::urlmap

        ui_msg "\[$distfile\] [file join $portdbpath distfiles $dist_subdir $distfile]"

        # print checksums if available
        if {$result eq "yes" && [array get checksums_array $distfile] ne ""} {
            foreach {type sum} $checksums_array($distfile) {
                ui_msg " $type: $sum"
            }
        }

        # determine sites to download from
        if {![info exists urlmap($url_var)]} {
            set urlmap($url_var) $urlmap(master_sites)
        }
        
        # determine URLs to download
        foreach site $urlmap($url_var) {
            set file_url [portfetch::assemble_url $site $distfile]
            ui_msg "  $file_url"
        }

        ui_msg " "

    }
}

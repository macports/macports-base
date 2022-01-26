# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portdmg.tcl
#
# Copyright (c) 2007, 2009-2011  The MacPorts Project
# Copyright (c) 2003, 2005 Apple Inc.
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

package provide portdmg 1.0
package require portutil 1.0

set org.macports.dmg [target_new org.macports.dmg portdmg::dmg_main]
target_runtype ${org.macports.dmg} always
target_provides ${org.macports.dmg} dmg
target_requires ${org.macports.dmg} pkg

namespace eval portdmg {
}

set_ui_prefix

proc portdmg::dmg_main {args} {
    global subport version revision package.destpath UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating disk image for %s-%s"] ${subport} ${version}_${revision}]"

    if {[getuid] == 0 && [geteuid] != 0} {
		seteuid 0; setegid 0
	}

    return [package_dmg $subport $version $revision]
}

proc portdmg::package_dmg {portname portversion portrevision} {
    global UI_PREFIX package.destpath portpath \
           os.platform os.arch os.version os.major

    set imagename [portpkg::image_name ${portname} ${portversion} ${portrevision}]

    set tmp_image ${package.destpath}/${imagename}.tmp.dmg
    set final_image ${package.destpath}/${imagename}.dmg
    set pkgpath ${package.destpath}/${imagename}.pkg

    if {[file readable $final_image] && ([file mtime ${final_image}] >= [file mtime ${portpath}/Portfile])} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Disk Image for %s version %s is up-to-date"] ${portname} ${portversion}_${portrevision}]"
        return 0
    }

    # partition for .dmg
    if {${os.major} >= 9 && ${os.arch} eq "i386"} {
        # GUID_partition_scheme
        set subdev 1
    } else {
        # Apple_partition_scheme (Apple_partition_map is at s1)
        set subdev 2
    }

    if {![file isdirectory $pkgpath]} {
        file mkdir ${package.destpath}/${imagename}
        file copy $pkgpath ${package.destpath}/${imagename}
        set pkgpath ${package.destpath}/${imagename}
    }

    set hdiutil [findBinary hdiutil $portutil::autoconf::hdiutil_path]
    if {[system "$hdiutil create -quiet -fs HFS+ -volname [shellescape ${imagename}] -srcfolder [shellescape ${pkgpath}] [shellescape ${tmp_image}]"] ne ""} {
        return -code error [format [msgcat::mc "Failed to create temporary image: %s"] ${imagename}]
    }
    if {[system "$hdiutil convert [shellescape ${tmp_image}] -format UDCO -o [shellescape ${final_image}] -quiet"] ne ""} {
        return -code error [format [msgcat::mc "Failed to convert to final image: %s"] ${final_image}]
    }
    # internet-enable verb removed from hdiutil in Catalina
    if {${os.major} < 19 && [system "$hdiutil internet-enable -quiet -yes [shellescape ${final_image}]"] ne ""} {
        return -code error [format [msgcat::mc "Failed to internet-enable: %s"] ${final_image}]
    }
    file delete -force "${tmp_image}"

    return 0
}

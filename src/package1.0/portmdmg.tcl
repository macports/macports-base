# et:ts=4
# portmdmg.tcl
# $Id$
#
# Copyright (c) 2003 Apple Computer, Inc.
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

package provide portmdmg 1.0
package require portutil 1.0

set org.macports.mdmg [target_new org.macports.mdmg mdmg_main]
target_runtype ${org.macports.mdmg} always
target_provides ${org.macports.mdmg} mdmg 
target_requires ${org.macports.mdmg} mpkg

set_ui_prefix

proc mdmg_main {args} {
    global portname portversion portrevision package.destpath UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating disk image for %s-%s"] ${portname} ${portversion}]"
    
    return [package_mdmg $portname $portversion $portrevision]
}

proc package_mdmg {portname portversion portrevision} {
    global UI_PREFIX package.destpath portpath
    global os.platform os.arch os.version os.major
    
    if {[expr (${portrevision} > 0)]} {
        set imagename "${portname}-${portversion}-${portrevision}"
    } else {
	set imagename "${portname}-${portversion}"
    }
    
    set tmp_image ${package.destpath}/${imagename}.tmp.dmg
    set final_image ${package.destpath}/${imagename}.dmg
    set mpkgpath ${package.destpath}/${portname}-${portversion}.mpkg
    
    if {[file readable $final_image] && ([file mtime ${final_image}] >= [file mtime ${portpath}/Portfile])} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Disk Image for %s-%s is up-to-date"] ${portname} ${portversion}]"
	return 0
    }
    
    # size for .dmg
    set size [dirSize ${mpkgpath}]
    if {[expr ($size < 4194304)]} {
	# there is a minimum of 8292 512 blocks in a dmg
        set blocks 8292
    } else {
	# this is now replaced with hdiutil create -srcfolder
        set blocks [expr ($size/512) + ((($size/512)*3)/100)]
    }
    
    # partition for .dmg
    if {${os.major} >= 9 && ${os.arch} == "i386"} {
	# GUID_partition_scheme
        set subdev 1
    } else {
	# Apple_partition_scheme (Apple_partition_map is at s1)
        set subdev 2
    }
    
  if {false} {
    if {[system "hdiutil create -quiet -fs HFS+ -volname ${imagename} -size ${blocks}b ${tmp_image}"] != ""} {
        return -code error [format [msgcat::mc "Failed to create temporary image: %s"] ${imagename}]
    }
    if {[catch {set devicename [exec hdid ${tmp_image} | grep s${subdev} | awk "{ print \$1 }"]} error]} {
        return -code error [format [msgcat::mc "Failed to attach temporary image: %s"] ${error}]
    }
    set mount_point [exec mount | grep "${devicename}"]
    regexp {(\/Volumes/[A-Za-z0-9\-\_\s].+)\s\(} $mount_point code mount_point
    system "ditto -rsrcFork ${mpkgpath} '${mount_point}/${portname}-${portversion}.mpkg'"
    system "hdiutil detach ${devicename} -quiet"
  } else {
    if {[system "hdiutil create -quiet -fs HFS+ -volname ${imagename} -srcfolder ${mpkgpath} ${tmp_image}"] != ""} {
        return -code error [format [msgcat::mc "Failed to create temporary image: %s"] ${imagename}]
    }
  }
    if {[system "hdiutil convert ${tmp_image} -format UDCO -o ${final_image} -quiet"] != ""} {
        return -code error [format [msgcat::mc "Failed to convert to final image: %s"] ${final_image}]
    }
    if {[system "hdiutil internet-enable -quiet -yes ${final_image}"] != ""} {
        return -code error [format [msgcat::mc "Failed to internet-enable: %s"] ${final_image}]
    }
    system "rm -f ${tmp_image}"
    
    return 0
}

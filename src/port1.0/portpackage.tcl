# et:ts=4
# portpackage.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

package provide portpackage 1.0
package require portutil 1.0

set com.apple.package [target_new com.apple.package package_main]
${com.apple.package} set runtype always
${com.apple.package} provides package
${com.apple.package} requires registry

# define options
options package.type package.destpath

# Set defaults
default package.type pkg
default package.destpath {${workpath}}

set UI_PREFIX "---> "

proc package_main {args} {
    global portname portversion package.type package.destpath UI_PREFIX

    set rfile [registry_exists $portname $portversion]
    if ![string length $rfile] {
	ui_error "Package ${portname}-${portversion} not installed on this system"
	return -code error "Package ${portname}-${portversion} not installed on this system"
    }
    ui_msg "$UI_PREFIX Creating ${package.type} format package for ${portname}-${portversion}"
    if [regexp .bz2$ $rfile] {
	set fd [open "|bunzip2 -c $rfile" r]
    } else {
	set fd [open $rfile r]
    }
    set entry [read $fd]
    close $fd

    # Make sure the destination path exists.
    system "mkdir -p ${package.destpath}"

    # For now we only support pkg and tarball package types.
    switch -exact -- ${package.type} {
	pkg {
	    return [package_pkg $portname $portversion $entry]
	}
	tarball {
	    return [package_tarball $portname $portversion $entry]
	}
	default {
	    ui_error "Do not know how to generate package of type ${package.type}"
	    return -code error "Unknown package type: ${package.type}"
	}
    }
}

# Make a tarball version of a package.  This is our "built-in" packaging
# method.
proc package_tarball {portname portversion entry} {
    global portdbpath package.destpath

    set rfile [registry_exists $portname $portversion]
    set ix [lsearch $entry contents]
    if {$ix >= 0} {
	set contents [lindex $entry [incr ix]]
	set plist [mkstemp /tmp/XXXXXXXX]
	set pfile [lindex $plist 0]
	foreach f $contents {
	    set fname [lindex $f 0]
	    puts $pfile $fname
	}
	puts $pfile $rfile
	close $pfile

	set ptarget ${package.destpath}/${portname}-${portversion}.tar.gz
	if [catch {system "gnutar -T [lindex $plist 1] -czPpf ${ptarget}"} err] {
	    ui_error "Package creation failed - gnutar returned error status: $err"
	    ui_info "Failed packing list left in [lindex $plist 1]"
	    return -code error "Package creation failed - gnutar returned error status: $err"
	}
	exec rm [lindex $plist 1]
    } else {
	ui_error "Bad registry entry for ${portname}-${portversion}, no contents"
	return -code error "Bad registry entry for ${portname}-${portversion}, no contents"
    }
    return 0
}

proc package_pkg {portname portversion entry} {
    global portdbpath destpath workpath contents prefix portresourcepath description package.destpath long_description

    set resourcepath ${workpath}/pkg_resources
    set rfile [registry_exists $portname $portversion]
    set ix [lsearch $entry contents]
    if {$ix >= 0} {
		set plist [mkstemp ${workpath}/.${portname}.plist.XXXXXXXXX]
		set pfile [lindex $plist 0]
		# XXX hack that allows contents list to be grouped by braces
		# XXX split contents list up if it contains one argument
		# XXX this breaks contents lists that contain one filename, with spaces.
		if {[llength $contents] == 1} {
			set clist [eval concat $contents]
		} else {
			set clist $contents
		}
	
		foreach f $clist {
			set fname [lindex $f 0]
			puts $pfile $fname
		}
		close $pfile
	
		if {![file isdirectory $destpath]} {
			if {[catch {file mkdir $destpath} result]} {
			ui_error "Unable to create destination root path: $result"
			return -code error "Unable to create destination root path: $result"
			}
		}
	
		if [catch {system "(cd ${prefix} && gnutar -T [lindex $plist 1] -cPpf -) | (cd ${destpath} && tar xvf -)"} return] {
			ui_error "Package creation failed - gnutar returned error status: $return"
			file delete [lindex $plist 1]
			return -code error "Package creation failed - gnutar returned error status: $return"
		}
		file delete [lindex $plist 1]
	}
	if {![file isdirectory $resourcepath]} {
	    if {[catch {file mkdir $resourcepath} result]} {
		ui_error "Unable to create package resource directory: $result"
		return -code error "Unable to create package resource directory: $result"
	    }
	}

# XXX: we need to support .lproj in resources.
	set pkgpath ${package.destpath}/${portname}.pkg
	system "mkdir -p -m 0755 ${pkgpath}/Contents/Resources"
	write_PkgInfo ${pkgpath}/Contents/PkgInfo
	write_info_file ${pkgpath}/Contents/Resources/${portname}.info $portname $portversion $description $prefix
	write_info_plist ${pkgpath}/Contents/Info.plist $portname $portversion $prefix
	write_description_plist ${pkgpath}/Contents/Resources/Description.plist $portname $portversion $description
	system "cp ${portresourcepath}/package/background.tiff ${pkgpath}/Contents/Resources/background.tiff"
	system "mkbom ${destpath} ${pkgpath}/Contents/Archive.bom"
	system "cd ${pkgpath}/Contents/Resources/ && ln -fs ../Archive.bom ${portname}.bom"
	system "cd ${destpath} && pax -w -z . > ${pkgpath}/Contents/Archive.pax.gz"
	system "cd ${pkgpath}/Contents/Resources/ && ln -fs ../Archive.pax.gz ${portname}.pax.gz"

	write_sizes_file ${pkgpath}/Contents/Resources/${portname}.sizes ${pkgpath} ${destpath}

    return 0
}

proc write_PkgInfo {infofile} {
	set infofd [open ${infofile} w+]
	puts $infofd "pmkrpkg1"
	close $infofd
}

proc write_info_file {infofile portname portversion description destination} {
	if {[string index $destination end] != "/"} {
		append destination /
	}

	set infofd [open ${infofile} w+]
	puts $infofd "Title ${portname}
Version ${portversion}
Description ${description}
DefaultLocation ${destination}
DeleteWarning

### Package Flags

NeedsAuthorization YES
Required NO
Relocatable NO
RequiresReboot NO
UseUserMask YES
OverwritePermissions NO
InstallFat NO
RootVolumeOnly NO"
	close $infofd
}

proc write_info_plist {infofile portname portversion destination} {
	set vers [split $portversion "."]
	set major [lindex $vers 0]
	set minor [lindex $vers 1]
	
	if {[string index $destination end] != "/"} {
		append destination /
	}

	set infofd [open ${infofile} w+]
	puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
}
	puts $infofd "<dict>
	<key>CFBundleGetInfoString</key>
	<string>${portname} ${portversion}</string>
	<key>CFBundleIdentifier</key>
	<string>org.opendarwin.darwinports.${portname}</string>
	<key>CFBundleName</key>
	<string>${portname}</string>
	<key>CFBundleShortVersionString</key>
	<string>${portversion}</string>
	<key>IFMajorVersion</key>
	<integer>${major}</integer>
	<key>IFMinorVersion</key>
	<integer>${minor}</integer>
	<key>IFPkgFlagAllowBackRev</key>
	<false/>
	<key>IFPkgFlagAuthorizationAction</key>
	<string>RootAuthorization</string>
	<key>IFPkgFlagDefaultLocation</key>
	<string>${destination}</string>
	<key>IFPkgFlagInstallFat</key>
	<false/>
	<key>IFPkgFlagIsRequired</key>
	<false/>
	<key>IFPkgFlagRelocatable</key>
	<false/>
	<key>IFPkgFlagRestartAction</key>
	<string>NoRestart</string>
	<key>IFPkgFlagRootVolumeOnly</key>
	<false/>
	<key>IFPkgFlagUpdateInstalledLanguages</key>
	<false/>
	<key>IFPkgFormatVersion</key>
	<real>0.10000000149011612</real>
</dict>
</plist>"
	close $infofd
}

proc write_description_plist {infofile portname portversion description} {
	set infofd [open ${infofile} w+]
	puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
}
	puts $infofd "<dict>
	<key>IFPkgDescriptionDeleteWarning</key>
	<string></string>
	<key>IFPkgDescriptionDescription</key>
	<string>${description}</string>
	<key>IFPkgDescriptionTitle</key>
	<string>${portname}</string>
	<key>IFPkgDescriptionVersion</key>
	<string>${portversion}</string>
</dict>
</plist>"
	close $infofd
}

proc write_sizes_file {sizesfile pkgpath destpath} {
set numFiles 0
set compressedSize 0
set installedSize 0
#	set numFiles `lsbom -s "${pkgpath}/Contents/Archive.bom" | wc -l`
#	set compresedSize `du -k -s "$pkgpath" | awk '{print $1}'`
#	incr compressedSize 3
#	set infoSize `ls -s "${pkgpath}/Contents/Resources/${portname}.info" | awk '{print $1}'`
#	set bomSize `ls -s "${pkgpath}/Contents/Archive.bom" | awk '{print $1}'`
#	set installedSize `du -k -s "$destpath" | awk '{print $1}'`
#	incr installedSize $infoSize
#	incr installedSize $bomSize
#	incr installedSize 3
	
	set fd [open ${sizesfile} w+]
	puts $fd "NumFiles $numFiles
InstalledSize $installedSize
CompressedSize $compressedSize"
	close $fd
}

# et:ts=4
# portpackage.tcl
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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
	return -code error [format [msgcat::mc "Package %s-%s not installed on this system"] ${portname} ${portversion}]
    }
    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating %s format package for %s-%s"] ${package.type} ${portname} ${portversion}]"
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
	    return -code error [format [msgcat::mc "Unknown package type: %s"] ${package.type}]
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
	if [catch {system "gnutar -T [lindex $plist 1] -czPpf ${ptarget}"} result] {
	    ui_info [format [msgcat::mc "Package creation failed - Failed packing list left in %s"] [lindex $plist 1]]
	    return -code error [format [msgcat::mc "Package creation failed - gnutar returned error status: %s"] $result]
	}
	exec rm [lindex $plist 1]
    } else {
	return -code error [format [msgcat::mc "Bad registry entry for %s-%s, no contents"] ${portname} ${portversion}]
    }
    return 0
}

proc package_pkg {portname portversion entry} {
    global portdbpath destpath workpath prefix portresourcepath description package.destpath long_description homepage

    set resourcepath ${workpath}/pkg_resources
    set rfile [registry_exists $portname $portversion]
    set ix [lsearch $entry contents]
    # If contents entry exists, transplant installed files into ${destpath}
    # Otherwise, presume that they are already installed in ${destpath} path
    if {$ix >= 0} {
	set plist [mkstemp ${workpath}/.${portname}.plist.XXXXXXXXX]
	set pfile [lindex $plist 0]

	set receipt_contents [lindex $entry [incr ix]]
	foreach f $receipt_contents {
	    set fname [lindex $f 0]
	    puts $pfile $fname
	}
	close $pfile

	if {![file isdirectory $destpath]} {
	    if {[catch {file mkdir $destpath} result]} {
		return -code error [format [msgcat::mc "Unable to create destination root path: %s"] $result]
	    }
	}

	if [catch {system "gnutar -T [lindex $plist 1] -cPpf - | (cd ${destpath} && tar xvf -)"} return] {
	    file delete [lindex $plist 1]
	    return -code error [format [msgcat::mc "Package creation failed - gnutar returned error status: %s"] $result]
	}
	file delete [lindex $plist 1]
    }
    if {![file isdirectory $resourcepath]} {
	if {[catch {file mkdir $resourcepath} result]} {
	    return -code error [format [msgcat::mc "Unable to create package resource directory: %s"] $result]
	}
    }

    # XXX: we need to support .lproj in resources.
    set pkgpath ${package.destpath}/${portname}.pkg
    system "mkdir -p -m 0755 ${pkgpath}/Contents/Resources"
    write_PkgInfo ${pkgpath}/Contents/PkgInfo
    write_info_file ${pkgpath}/Contents/Resources/${portname}.info $portname $portversion $description
    write_info_plist ${pkgpath}/Contents/Info.plist $portname $portversion
    write_description_plist ${pkgpath}/Contents/Resources/Description.plist $portname $portversion $description
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
	if {![info exists $variable]} {
	    set pkg_$variable ""
	} else {
	    set pkg_$variable [set $variable]
	}
    }
    write_welcome_rtf ${pkgpath}/Contents/Resources/Welcome.rtf $portname $portversion $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- ${portresourcepath}/package/background.tiff ${pkgpath}/Contents/Resources/background.tiff
    system "mkbom ${destpath} ${pkgpath}/Contents/Archive.bom"
    system "cd ${pkgpath}/Contents/Resources/ && ln -fs ../Archive.bom ${portname}.bom"
    system "cd ${destpath} && pax -w -z . > ${pkgpath}/Contents/Archive.pax.gz"
    system "cd ${pkgpath}/Contents/Resources/ && ln -fs ../Archive.pax.gz ${portname}.pax.gz"

    write_sizes_file ${pkgpath}/Contents/Resources/${portname}.sizes ${portname} ${pkgpath} ${destpath}

    return 0
}

proc dirSize {dir} {
    set size    0;
    foreach file [readdir $dir] {
	if {$file == "." || $file == ".."} {
	    continue
	}
	if {[file isdirectory [file join $dir $file]]} {
	    incr size [dirSize [file join $dir $file]]
	} else {
	    incr size [file size [file join $dir $file]];
	}
    }
    return $size;
}

proc write_PkgInfo {infofile} {
	set infofd [open ${infofile} w+]
	puts $infofd "pmkrpkg1"
	close $infofd
}

proc write_info_file {infofile portname portversion description} {
	set infofd [open ${infofile} w+]
	puts $infofd "Title ${portname}
Version ${portversion}
Description ${description}
DefaultLocation /
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

proc write_info_plist {infofile portname portversion} {
	set vers [split $portversion "."]
	set major [lindex $vers 0]
	set minor [lindex $vers 1]
	if {$major == ""} {set major "0"}
	if {$minor == ""} {set minor "0"}
		
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
	<true/>
	<key>IFPkgFlagAuthorizationAction</key>
	<string>RootAuthorization</string>
	<key>IFPkgFlagDefaultLocation</key>
	<string>/</string>
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

proc write_welcome_rtf {filename portname portversion long_description description homepage} {
    set fd [open ${filename} w+]
    if {$long_description == ""} {
	set long_description $description
    }
    puts $fd \
"{\\rtf1\\mac\\ansicpg10000\\cocoartf102
{\\fonttbl\\f0\\fswiss\\fcharset77 Helvetica-Bold;\\f1\\fswiss\\fcharset77 Helvetica;}
{\\colortbl;\\red255\\green255\\blue255;\\red1\\green1\\blue1;}
\\vieww9000\\viewh9000\\viewkind0
\\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720\\ql\\qnatural

\\f0\\b\\fs24 \\cf2 Welcome to the ${portname} for Mac OS X Installer\\
\\
\\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720\\ql\\qnatural
"
    puts $fd "\\f1\\b0 \\cf2 ${long_description} \\\n\\"
    if {$homepage != ""} {
	puts $fd "${homepage} \\\n\\"
    }
    puts $fd "This installer guides you through the steps necessary to install ${portname} ${portversion} for Mac OS X. To get started, click Continue.\\\n}"

    close $fd
}

proc write_sizes_file {sizesfile portname pkgpath destpath} {
    
    if {[catch {set numFiles [exec lsbom -s ${pkgpath}/Contents/Archive.bom | wc -l]} result]} {
	return -code error [format [msgcat::mc "Reading package bom failed: %s"] $result]
    }
    if {[catch {set compressedSize [expr [dirSize ${pkgpath}] / 1024]} result]} {
	return -code error [format [msgcat::mc "Error determining compressed size: %s"] $result]
    }
    if {[catch {set installedSize [expr [dirSize ${destpath}] / 1024]} result]} {
	return -code error [format [msgcat::mc "Error determining installed size: %s"] $result]
    }
    if {[catch {set infoSize [file size ${pkgpath}/Contents/Resources/${portname}.info]} result]} {
	return -code error [format [msgcat::mc "Error determining info file size: %s"] $result]
    }
    if {[catch {set bomSize [file size ${pkgpath}/Contents/Archive.bom]} result]} {
	return -code error [format [msgcat::mc "Error determining bom file size: %s"] $result]
    }
    incr installedSize $infoSize
    incr installedSize $bomSize
	
    set fd [open ${sizesfile} w+]
    puts $fd "NumFiles $numFiles
InstalledSize $installedSize
CompressedSize $compressedSize"
    close $fd
}

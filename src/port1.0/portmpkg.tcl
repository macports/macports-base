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

package provide portmpkg 1.0
package require portutil 1.0

set com.apple.mpkg [target_new com.apple.mpkg mpkg_main]
${com.apple.mpkg} set runtype always
${com.apple.mpkg} provides mpkg
${com.apple.mpkg} requires package

# define options
options package.type package.destpath

set UI_PREFIX "---> "

proc mpkg_main {args} {
    global portname portversion package.type package.destpath UI_PREFIX

    # Make sure the destination path exists.
    system "mkdir -p ${package.destpath}"

    # For now we only support pkg and tarball package types.
    switch -exact -- ${package.type} {
	pkg {
	    return [package_mpkg $portname $portversion]
	}
	default {
	    ui_error "Do not know how to generate package of type ${package.type}"
	    return -code error "Unknown package type: ${package.type}"
	}
    }
}

proc package_mpkg {portname portversion} {
    global portdbpath destpath workpath contents prefix portresourcepath description package.destpath long_description homepage depends_run depends_lib

	# get the union of depends_run and depends_lib, ignore everything but the portfile.
	set depends {}
	if {[info exists depends_run]} {eval "lappend depends $depends_run"}
	if {[info exists depends_lib]} {eval "lappend depends $depends_lib"}
	set ports {}
	foreach depspec $depends {
		set depname [lindex [split $depspec :] 2]

		# nasty hack
		if {$depname != "XFree86"} {
			lappend ports $depname
		}
	}
	set ports [lsort -unique $ports]

	set pkgpath ${package.destpath}/${portname}.pkg
	set mpkgpath ${package.destpath}/${portname}.mpkg
	system "mkdir -p -m 0755 ${mpkgpath}/Contents/Resources"

	if {[llength $ports] > 0} {
		set dependencies {}
		
		# Create mpkgs for each of our dependencies inside our resources directory.
		foreach port $ports {
			if {[catch {set res [dportsearch "^$port\$"]} result]} {
				ui_error "port search failed: $result"
				return 1
			}
			foreach {name array} $res {
				array set portinfo $array
				
				if [info exists portinfo(porturl)] {
					# only the prefix gets passed to the worker.
					set worker [dportopen $portinfo(porturl) [list prefix $prefix package.destpath ${mpkgpath}/Contents/Resources]]
					if {[info exists portinfo(depends_run)] || [info exists portinfo(depends_lib)]} {
						dportexec $worker mpkg
						lappend dependencies ${portinfo(name)}.mpkg
						# Remove intermediate .pkg, since the .pkg will have been copied into the .mpkg resources directory.
						system "rm -R ${mpkgpath}/Contents/Resources/${portinfo(name)}.pkg"
					} else {
						dportexec $worker package
						lappend dependencies ${portinfo(name)}.pkg
					}
				}
				
				unset portinfo
			}
		}
	}
	
	# copy our own pkg into the mpkg
	system "cp -RPp ${pkgpath} ${mpkgpath}/Contents/Resources/"
	lappend dependencies ${portname}.pkg
	
    write_PkgInfo ${mpkgpath}/Contents/PkgInfo
    write_info_file ${mpkgpath}/Contents/Resources/${portname}.info $portname $portversion $description
    mpkg_write_info_plist ${mpkgpath}/Contents/Info.plist $portname $portversion $prefix $dependencies
    write_description_plist ${mpkgpath}/Contents/Resources/Description.plist $portname $portversion $description
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
	if {![info exists $variable]} {
	    set pkg_$variable ""
	} else {
	    set pkg_$variable [set $variable]
	}
    }
    write_welcome_rtf ${mpkgpath}/Contents/Resources/Welcome.rtf $portname $portversion $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- ${portresourcepath}/package/background.tiff ${mpkgpath}/Contents/Resources/background.tiff

	return 0
}

proc mpkg_write_info_plist {infofile portname portversion destination dependencies} {
	set vers [split $portversion "."]
	set major [lindex $vers 0]
	set minor [lindex $vers 1]
	if {$major == ""} {set major "0"}
	if {$minor == ""} {set minor "0"}
	
	if {[string index $destination end] != "/"} {
		append destination /
	}
	
	set depxml ""
	foreach dep $dependencies {
		append depxml "<dict>
			<key>IFPkgFlagPackageLocation</key>
			<string>${dep}</string>
			<key>IFPkgFlagPackageSelection</key>
			<string>selected</string>
		</dict>
		"
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
	<string>org.opendarwin.darwinports.mpkg.${portname}</string>
	<key>CFBundleName</key>
	<string>${portname}</string>
	<key>CFBundleShortVersionString</key>
	<string>${portversion}</string>
	<key>IFMajorVersion</key>
	<integer>${major}</integer>
	<key>IFMinorVersion</key>
	<integer>${minor}</integer>
	<key>IFPkgFlagComponentDirectory</key>
	<string>./Contents/Resources</string>
	<key>IFPkgFlagPackageList</key>
	<array>
		${depxml}</array>
	<key>IFPkgFormatVersion</key>
	<real>0.10000000149011612</real>
</dict>
</plist>"
	close $infofd
}

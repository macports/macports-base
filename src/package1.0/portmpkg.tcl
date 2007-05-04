# et:ts=4
# portmpkg.tcl
# $Id$
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

package provide portmpkg 1.0
package require portutil 1.0

set org.macports.mpkg [target_new org.macports.mpkg mpkg_main]
target_runtype ${org.macports.mpkg} always
target_provides ${org.macports.mpkg} mpkg
target_requires ${org.macports.mpkg} pkg

# define options
options package.destpath

set_ui_prefix

proc mpkg_main {args} {
    global portname portversion portrevision package.destpath UI_PREFIX

    # Make sure the destination path exists.
    system "mkdir -p ${package.destpath}"

    return [package_mpkg $portname $portversion $portrevision]
}

proc make_dependency_list {portname} {
	set result {}
	if {[catch {set res [mport_search "^$portname\$"]} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_error "port search failed: $error"
		return 1
	}
	foreach {name array} $res {
		array set portinfo $array

		if {[info exists portinfo(depends_run)] || [info exists portinfo(depends_lib)]} {
			# get the union of depends_run and depends_lib
			# xxx: only examines the portfile component of the depspec
			set depends {}
			if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
			if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }

			foreach depspec $depends {
				set dep [lindex [split $depspec :] end]
	
				# xxx: nasty hack
				if {$dep != "XFree86"} {
					eval "lappend result [make_dependency_list $dep]"
				}
			}
		}
		lappend result $portinfo(name)/$portinfo(version)
		unset portinfo
	}
	ui_debug "dependencies for ${portname}: $result"
	return $result
}

proc make_one_package {portname portversion mpkgpath} {
	global prefix package.destpath 
	if {[catch {set res [mport_search "^$portname\$"]} result]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_error "port search failed: $result"
		return 1
	}
	foreach {name array} $res {
		array set portinfo $array
		
		if {[info exists portinfo(porturl)] && [info exists portinfo(version)] && $portinfo(version) == $portversion} {
			# only the prefix gets passed to the worker.
			ui_debug "building dependency package: $portname"
			set worker [mport_open $portinfo(porturl) [list prefix $prefix package.destpath ${mpkgpath}/Contents/Resources] {} yes]
			mport_exec $worker pkg
			mport_close $worker
		}
		unset portinfo
	}
}

proc package_mpkg {portname portversion portrevision} {
    global portdbpath destpath workpath prefix portresourcepath description package.destpath long_description homepage depends_run depends_lib

	set pkgpath ${package.destpath}/${portname}-${portversion}.pkg
	set mpkgpath ${package.destpath}/${portname}-${portversion}.mpkg
	system "mkdir -p -m 0755 ${mpkgpath}/Contents/Resources"

	set dependencies {}
	# get deplist
	set deps [make_dependency_list $portname]
	set deps [lsort -unique $deps]
	foreach dep $deps {
		set name [lindex [split $dep /] 0]
		set vers [lindex [split $dep /] 1]
		# don't re-package ourself
		if {$name != $portname} {
			make_one_package $name $vers $mpkgpath
			lappend dependencies ${name}-${vers}.pkg
		}
	}
	
	# copy our own pkg into the mpkg
	system "cp -PR ${pkgpath} ${mpkgpath}/Contents/Resources/"
	lappend dependencies ${portname}-${portversion}.pkg
	
    write_PkgInfo ${mpkgpath}/Contents/PkgInfo
    mpkg_write_info_plist ${mpkgpath}/Contents/Info.plist $portname $portversion $portrevision $prefix $dependencies
    write_description_plist ${mpkgpath}/Contents/Resources/Description.plist $portname $portversion $description
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
	if {![info exists $variable]} {
	    set pkg_$variable ""
	} else {
	    set pkg_$variable [set $variable]
	}
    }
    write_welcome_html ${mpkgpath}/Contents/Resources/Welcome.rtf $portname $portversion $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- ${portresourcepath}/package/background.tiff ${mpkgpath}/Contents/Resources/background.tiff

	return 0
}

proc xml_escape {s} {
	regsub -all {&} $s {\&amp;} s
	regsub -all {<} $s {\&lt;} s
	regsub -all {>} $s {\&gt;} s
	return $s
}

proc mpkg_write_info_plist {infofile portname portversion portrevision destination dependencies} {
	set vers [split $portversion "."]
	
	if {[string index $destination end] != "/"} {
		append destination /
	}
	
	set depxml ""
	foreach dep $dependencies {
		set dep [xml_escape $dep]
		append depxml "<dict>
			<key>IFPkgFlagPackageLocation</key>
			<string>${dep}</string>
			<key>IFPkgFlagPackageSelection</key>
			<string>selected</string>
		</dict>
		"
	}

	set portname [xml_escape $portname]
	set portversion [xml_escape $portversion]
	set portrevision [xml_escape $portrevision]
	set infofd [open ${infofile} w+]
	puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
}
	puts $infofd "<dict>
	<key>CFBundleGetInfoString</key>
	<string>${portname} ${portversion}</string>
	<key>CFBundleIdentifier</key>
	<string>org.macports.mpkg.${portname}</string>
	<key>CFBundleName</key>
	<string>${portname}</string>
	<key>CFBundleShortVersionString</key>
	<string>${portversion}</string>
	<key>IFMajorVersion</key>
	<integer>${portrevision}</integer>
	<key>IFMinorVersion</key>
	<integer>0</integer>
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

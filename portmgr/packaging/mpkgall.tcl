#!/usr/bin/env tclsh
# mpkgall.tcl
#
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
# Copyright (c) 2002 Apple Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#	 notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#	 notice, this list of conditions and the following disclaimer in the
#	 documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#	 may be used to endorse or promote products derived from this software
#	 without specific prior written permission.
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

package require darwinports

# globals
set portdir .
array set ui_options {}

proc ui_prefix {priority} {
	return ""
}

proc ui_channels {priority} {
	return {}
}

# copy binary packages if they've already been built.

proc copy_package_if_available {portname basepath destpath} {

	set dependencies {}

	# XXX: don't overwrite Apple X11
	# XXX: probably should exclude KDE here too
	if {$portname == "XFree86"} { return {} }

	if {[catch {set res [mportsearch "^$portname\$"]} error]} {
		puts stderr "Internal error: port search failed: $error"
		return
	}
	foreach {name array} $res {
		array set portinfo $array
		if {![info exists portinfo(name)]} { return -1 }
		if {![info exists portinfo(version)]} { return -1 }
		if {![info exists portinfo(categories)]} { return -1 }

		set portname $portinfo(name)
		set portversion $portinfo(version)
		set category [lindex $portinfo(categories) 0]

		set depends {}
		if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
		if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
		#if {[info exists portinfo(depends_build)]} { eval "lappend depends $portinfo(depends_build)" }
		foreach depspec $depends {
			set dep [lindex [split $depspec :] end]
			set result [copy_package_if_available $dep $basepath $destpath]
			if {$result == -1} {
				return -1
			} else {
				eval "lappend dependencies $result"
			}
		}

		set pkgname "${portname}-${portversion}.pkg"
		lappend dependencies $pkgname
		set pkgpath "${basepath}/${category}/${pkgname}"
		if {[file readable "${pkgpath}/Contents/Info.plist"]} {
			puts stderr "copying package: ${pkgpath} to ${destpath}"
			if {[catch {system "cp -R ${pkgpath} ${destpath}/"} error]} {
				puts stderr "Internal error: $error"
			}
		} else {
			puts stderr "package ${pkgname} not found"
			return -1
		}
	}

	return $dependencies
}

proc write_description_plist {infofile portname portversion description} {
	set infofd [open ${infofile} w+]
	puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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

proc write_welcome_html {filename portname portversion long_description description homepage} {
	set fd [open ${filename} w+]
	if {$long_description eq ""} {
		set long_description $description
	}

puts $fd "
<html lang=\"en\">
<head>
	<meta http-equiv=\"content-type\" content=\"text/html; charset=iso-8859-1\">
	<title>Install ${portname}</title>
</head>
<body>
<font face=\"Helvetica\"><b>Welcome to the ${portname} for Mac OS X Installer</b></font>
<p>
<font face=\"Helvetica\">${long_description}</font>
<p>"

	if {$homepage ne ""} {
		puts $fd "<font face=\"Helvetica\">${homepage}</font><p>"
	}

	puts $fd "<font face=\"Helvetica\">This installer guides you through the steps necessary to install ${portname} ${portversion} for Mac OS X. To get started, click Continue.</font>
</body>
</html>"

	close $fd
}

proc write_PkgInfo {infofile} {
	set infofd [open ${infofile} w+]
	puts $infofd "pmkrpkg1"
	close $infofd
}

proc mpkg_write_info_plist {infofile portname portversion portrevision destination dependencies} {
	set vers [split $portversion "."]

	if {[string index $destination end] ne "/"} {
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
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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


# Standard procedures

proc fatal args {
	global argv0
	puts stderr "$argv0: $args"
	exit
}

# Main
array set options [list]
array set variations [list]
#	set ui_options(ports_verbose) yes

if {[catch {mportinit ui_options options variations} result]} {
	puts "Failed to initialize ports system, $result"
	exit 1
}

package require Pextlib

# If no arguments were given, default to all ports.
if {[llength $argv] == 0} {
	lappend argv ".*"
}

foreach pname $argv {
	if {[catch {set res [mportsearch "^${pname}\$"]} result]} {
		puts "port search failed: $result"
		exit 1
	}

	foreach {name array} $res {
		global prefix
		array unset portinfo
		array set portinfo $array

		if {![info exists portinfo(porturl)]} {
			puts stderr "Internal error: no porturl for $name"
			continue
		}

		set pkgbase "/darwinports/pkgs/"
		set mpkgbase "/darwinports/mpkgs/"
		set porturl $portinfo(porturl)
		set prefix "/opt/local"

		# Skip up-to-date packages
		if {[regsub {^file://} $portinfo(porturl) "" portpath]} {
			if {[info exists portinfo(name)] &&
				[info exists portinfo(version)] &&
				[info exists portinfo(categories)]} {
				set portname $portinfo(name)
				set portversion $portinfo(version)
				set category [lindex $portinfo(categories) 0]
				set mpkgfile ${mpkgbase}/${category}/${portname}-${portversion}.mpkg/Contents/Info.plist
				if {[file readable $mpkgfile] && ([file mtime ${mpkgfile}] > [file mtime ${portpath}/Portfile])} {
					puts stderr "Skipping ${portname}-${portversion}; meta-package is up to date."
					continue
				}
			}
		}

		# Skipt packages which previously failed

		# Building the mpkg:
		# - create an mpkg skeleton
		# - copy dependent pkgs into Contents/Resources directory

		set portname ""
		set portversion ""
		set description ""
		set long_description ""
		set homepage ""
		set category ""

		if {[info exists portinfo(name)]} {	set portname $portinfo(name) }
		if {[info exists portinfo(version)]} { set portversion $portinfo(version) }
		if {[info exists portinfo(description)]} { set description $portinfo(description) }
		if {[info exists portinfo(long_description)]} { set long_description $portinfo(long_description) }
		if {[info exists portinfo(homepage)]} { set homepage $portinfo(homepage) }
		if {[info exists portinfo(categories)]} { set category [lindex $portinfo(categories) 0] }
		if {[info exists portinfo(maintainers)]} { set maintainers $portinfo(maintainers) }

		puts "meta-packaging ${category}/${portname}-${portversion}"

		set mpkgpath "${mpkgbase}/${category}/${portname}-${portversion}.mpkg"

		if {[catch {system "mkdir -p -m 0755 ${mpkgpath}/Contents/Resources"} error]} {
			puts stderr "Internal error: $error"
		}

		# list of .pkg names for dependencies,
		# built up by copy_package_if_available, and used in the Info.plist
		set dependencies {}
		set result [copy_package_if_available ${portname} $pkgbase "${mpkgpath}/Contents/Resources/"]
		if {$result == -1} {
			puts stderr "aborting; one or more dependencies was missing."
			if {[catch {system "rm -R ${mpkgpath}"} error]} {
				puts stderr "Internal error: $error"
			}
			continue
		} else {
			set result [lsort -uniq $result]
			eval "lappend dependencies $result"
		}

		#
		# Begin quote from portmpkg.tcl
		#
		write_PkgInfo ${mpkgpath}/Contents/PkgInfo
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
		write_welcome_html ${mpkgpath}/Contents/Resources/Welcome.html $portname $portversion $pkg_long_description $pkg_description $pkg_homepage
		file copy -force -- /opt/local/share/darwinports/resources/port1.0/package/background.tiff \
			${mpkgpath}/Contents/Resources/background.tiff
		#
		# End quote from portmpkg.tcl
		#
	}
}
# end foreach pname

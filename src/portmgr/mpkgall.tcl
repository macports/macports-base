#!/usr/bin/env tclsh
# mpkgall.tcl
#
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
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

package require darwinports

# globals
set portdir .

proc ui_puts {args} {}

# copy binary packages if they've already been built.

proc copy_package_if_available {portname basepath destpath} {

	set dependencies {}

	if {[catch {set res [dportsearch "^$portname\$"]} error]} {
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
			set dep [lindex [split $depspec :] 2]
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

if {[catch {dportinit} result]} {
    puts "Failed to initialize ports system, $result"
    exit 1
}

package require Pextlib
package require portmpkg 1.0
package require portpackage 1.0

# If no arguments were given, default to all ports.
if {[llength $argv] == 0} {
        lappend argv ".*"
}

foreach pname $argv {

if {[catch {set res [dportsearch "^${pname}\$"]} result]} {
	puts "port search failed: $result"
	exit 1
}

foreach {name array} $res {
	global prefix
	array unset portinfo
	array set portinfo $array

	if ![info exists portinfo(porturl)] {
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
    write_info_file ${mpkgpath}/Contents/Resources/${portname}-${portversion}.info $portname $portversion $description
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
    write_welcome_html ${mpkgpath}/Contents/Resources/Welcome.rtf $portname $portversion $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- /opt/local/share/darwinports/resources/port1.0/package/background.tiff \
			${mpkgpath}/Contents/Resources/background.tiff
	#
	# End quote from portmpkg.tcl
	#
}

}
# end foreach pname

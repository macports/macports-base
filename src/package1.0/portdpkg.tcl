# et:ts=4
# portdpkg.tcl
# $Id$
#
# Copyright (c) 2005, 2007, 2009, 2011 The MacPorts Project
# Copyright (c) 2004 Landon Fuller <landonf@macports.org>
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

package provide portdpkg 1.0
package require portutil 1.0

set org.macports.dpkg [target_new org.macports.dpkg portdpkg::main]
target_runtype ${org.macports.dpkg} always
target_provides ${org.macports.dpkg} dpkg
target_requires ${org.macports.dpkg} archivefetch unarchive destroot

namespace eval portdpkg {
}

# Options
options dpkg.asroot \
        package.destpath

# Set up defaults
default dpkg.asroot yes

set_ui_prefix

proc portdpkg::main {args} {
	global UI_PREFIX destpath os.arch os.platform supported_archs configure.build_arch

	ui_msg "$UI_PREFIX [format [msgcat::mc "Creating dpkg for %s-%s"] [option subport] [option version]]"

	# get deplist
	set deps [make_dependency_list [option subport]]
	set deps [lsort -unique $deps]
	foreach dep $deps {
		set name [lindex [split $dep /] 0]
		set vers [lindex [split $dep /] 1]
		# don't re-package ourself
		if {$name != [option subport]} {
			lappend dependencies "${name} (>= ${vers})"
		}
	}

	if {[info exists dependencies]} {
		ui_debug $dependencies
	}

	set controlpath [file join ${destpath} DEBIAN]
	if {[file exists ${controlpath}]} {
		if {![file isdirectory ${controlpath}]} {
			return -code error [format [msgcat::mc "Can not create dpkg control directory. %s not a directory."] ${controlpath}]
		} else {
			ui_info [msgcat::mc "Removing stale dpkg control directory."]
			delete "${controlpath}"
		}
	}
	file mkdir ${controlpath}

	set controlfd [open [file join ${controlpath} control] w+]

	# Size, in kilobytes, of ${destpath}
   	set pkg_installed-size [expr [dirSize ${destpath}] / 1024]

	# Create debian dependency list
	if {[info exists dependencies]} {
		if {[llength ${dependencies}] != 0} {
			set pkg_depends [join ${dependencies} ", "]
		}
	}

	# Create dpkg version number
	if {[expr [option epoch] != 0]} {
		set pkg_version "[option epoch]:[option version]"
	} else {
		set pkg_version "[option version]"
	}
	if {[expr [option revision] != 0]} {
		append pkg_version "-[option revision]"
	}

	# Set dpkg category to first (main) category
	set pkg_category [lindex [option categories] 0]

	# Format the long description. Add a homepage if possible.
	if {[exists long_description]} {
		set pkg_long_description " [option long_description]\n"
	} elseif {[exists description]} {
		set pkg_long_description " [option description]\n"
	} else {
		set pkg_long_description " [option subport]\n"
	}

	if {[exists homepage]} {
		append pkg_long_description " .\n"
		append pkg_long_description " [option homepage]\n"
	}

	# Discern correct architecture
	# From http://www.debian.org/doc/debian-policy/ch-customized-programs.html#fr55:
	# The following architectures and operating systems are currently recognised
	# by dpkg-archictecture. The architecture, arch, is one of the following:
	# alpha, arm, hppa, i386, ia64, m68k, mips, mipsel, powerpc, s390, sh, sheb,
	# sparc and sparc64. The operating system, os, is one of: linux, gnu,
	# freebsd and openbsd. Use of gnu in this string is reserved for the
	# GNU/Hurd operating system.
	switch -regex ${configure.build_arch} {
		i[3-9]86 { set pkg_arch "i386" }
		x86_64 { set pkg_arch "x86_64" }
		default { set pkg_arch ${os.arch} }
	}

	# On systems other than Linux, the Architecture must contain
	# the operating system name
	if {${os.platform} != "linux"} {
		set pkg_arch "${os.platform}-${pkg_arch}"
	} elseif {${pkg_arch} == "x86_64"} {
		set pkg_arch "amd64"
	}

	# An architecture-independent package
	if {$supported_archs == "noarch"} {
		set pkg_arch "all"
	}

	puts $controlfd "Package: [option subport]"
	puts $controlfd "Architecture: ${pkg_arch}"
	puts $controlfd "Version: ${pkg_version}"
	puts $controlfd "Section: ${pkg_category}"
	puts $controlfd "Maintainer: [option maintainers]"
	if {[info exists pkg_depends]} {
		puts $controlfd "Depends: ${pkg_depends}"
	}
	puts $controlfd "Installed-Size: ${pkg_installed-size}"

	puts $controlfd "Description: [option description]"
	# pkg_long_description is pre-formatted. Do not add a newline
	puts -nonewline $controlfd "$pkg_long_description"
	close $controlfd

	# Build debian package in package.destpath
	system "dpkg-deb -b \"${destpath}\" \"[option package.destpath]\""

	ui_info [msgcat::mc "Removing dpkg control directory."]
	delete "${controlpath}"
}

proc portdpkg::make_dependency_list {portname} {
	set result {}
	if {[catch {set res [mport_lookup $portname]} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_error "port lookup failed: $error"
		return 1
	}
	foreach {name array} $res {
		array set portinfo $array

		if {[info exists portinfo(depends_run)] || [info exists portinfo(depends_lib)]} {
			# get the union of depends_run and depends_lib
			# xxx: only examines the portfile component of the depspec
			set depends {}
			if {[info exists portinfo(depends_run)]} {
				eval "lappend depends $portinfo(depends_run)"
			}
			if {[info exists portinfo(depends_lib)]} {
				eval "lappend depends $portinfo(depends_lib)"
			}

			foreach depspec $depends {
				set dep [lindex [split $depspec :] end]
				eval "lappend result [make_dependency_list $dep]"
			}
		}
				lappend result $portinfo(name)/$portinfo(version)
				unset portinfo
	}
	return $result
}

#!/usr/bin/env tclsh
# packageall.tcl
#
# Copyright (c) 2009-2011 The MacPorts Project
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

# UI Instantiations
array set ui_options {}
# ui_options(ports_debug) - If set, output debugging messages.
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"

# ui_options accessor
proc ui_isset {val} {
	global ui_options
	if {[info exists ui_options($val)]} {
		if {$ui_options($val) eq "yes"} {
			return 1
		}
	}
	return 0
}

# UI Callback

proc ui_prefix {priority} {
	switch $priority {
		debug {
			return "DEBUG: "
		}
		error {
			return "Error: "
		}
		warn {
			return "Warning: "
		}
		default {
			return ""
		}
	}
}

proc ui_channels {priority} {
	global logfd
	switch $priority {
		debug {
			if {[ui_isset ports_debug]} {
				return {stdout}
			} else {
				return {}
			}
		}
		info {
			# put verbose stuff only to the log file
			if {[ui_isset ports_verbose]} {
				return {$logfd}
			} else {
				return {}
			}
		}
		msg {
			if {[ui_isset ports_quiet]} {
				return {}
			} else {
				return {stdout}
			}
		}
		default {
			return {stdout}
		}
	}
}

proc pkg_ui_log {message} {
	global logfd
	if {$logfd ne ""} {
		log_message $logfd $message
	}
}

proc log_message {channel message} {
	seek $channel 0 end
	puts $channel $message
	flush $channel
}

# Recursive bottom-up approach of building a list of dependencies.
proc get_dependencies {portname includeBuildDeps} {
	set result {}

	if {[catch {set res [mportsearch "^$portname\$"]} error]} {
		ui_debug $::errorInfo
		ui_error "Internal error: port search failed: $error"
		return {}
	}
	foreach {name array} $res {
		array set portinfo $array
		if {![info exists portinfo(name)] ||
			![info exists portinfo(version)] ||
			![info exists portinfo(categories)]} {
			ui_error "Internal error: $name missing some portinfo keys"
			continue
		}

		set portname $portinfo(name)
		set portversion $portinfo(version)
		set category [lindex $portinfo(categories) 0]

		# Append the package itself to the result list
		#set pkgpath ${category}/${portname}-${portversion}.pkg
		lappend result [list $portname $portversion $category]

		# Append the package's dependents to the result list
		set depends {}
		if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
		if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
		if {$includeBuildDeps ne "" && [info exists portinfo(depends_build)]} {
			eval "lappend depends $portinfo(depends_build)"
		}
		if {$includeBuildDeps ne "" && [info exists portinfo(depends_fetch)]} {
			eval "lappend depends $portinfo(depends_fetch)"
		}
		if {$includeBuildDeps ne "" && [info exists portinfo(depends_extract)]} {
			eval "lappend depends $portinfo(depends_extract)"
		}

		foreach depspec $depends {
			set dep [lindex [split $depspec :] end]
			set x [get_dependencies $dep $includeBuildDeps]
			eval "lappend result $x"
			set result [lsort -unique $result]
		}
	}
	return $result
}

# Install binary packages if they've already been built.  This will
# speed up the testing, since we won't have to recompile dependencies
# which have already been compiled.

proc install_binary_if_available {dep basepath} {
	set portname [lindex $dep 0]
	set portversion [lindex $dep 1]
	set category [lindex $dep 2]

	set pkgpath ${basepath}/${category}/${portname}-${portversion}.pkg
	if {[file readable $pkgpath]} {
		ui_msg "installing binary: $pkgpath"
		if {[catch {system "cd / && gunzip -c ${pkgpath}/Contents/Archive.pax.gz | pax -r"} error]} {
			ui_debug $::errorInfo
			ui_error "Internal error: $error"
		}
		# Touch the receipt
		# xxx: use some variable to describe this path
		if {[catch {system "touch /opt/local/var/db/dports/receipts/${portname}-${portversion}.bz2"} error]} {
			ui_debug $::errorInfo
			ui_error "Internal error: $error"
		}
	}
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

	set logpath "/darwinports/logs"
	set logfd ""

	foreach {name array} $res {
		array unset portinfo
		array set portinfo $array

		# Start with verbose output off;
		# this will prevent the repopulation of /opt/local from getting logged.
		set ui_options(ports_verbose) no

		if {![info exists portinfo(porturl)]} {
			puts stderr "Internal error: no porturl for $name"
			continue
		}

		set pkgbase /darwinports/pkgs/
		set porturl $portinfo(porturl)

		# Skip up-to-date packages
		if {[regsub {^file://} $portinfo(porturl) "" portpath]} {
			if {[info exists portinfo(name)] &&
				[info exists portinfo(version)] &&
				[info exists portinfo(categories)]} {
				set portname $portinfo(name)
				set portversion $portinfo(version)
				set category [lindex $portinfo(categories) 0]
				set pkgfile ${pkgbase}/${category}/${portname}-${portversion}.pkg/Contents/Archive.pax.gz
				if {[file readable $pkgfile] && ([file mtime ${pkgfile}] > [file mtime ${portpath}/Portfile])} {
					puts stderr "Skipping ${portname}-${portversion}; package is up to date."
					continue
				}
			}
		}

		# Skipt packages which previously failed

		# Building the port:
		# - remove /opt/local so it won't pollute the port.
		# - re-install MacPorts.
		# - keep distfiles outside /opt/local so we don't have to keep fetching them.
		# - send out an email to the maintainer if any errors occurred.

		ui_msg "removing /opt/local"
		#unset ui_options(ports_verbose)
		if {[catch {system "rm -Rf /opt/local"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "rm -Rf /usr/X11R6"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "rm -Rf /etc/X11"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "rm -Rf /etc/fonts"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "cd $env(HOME)/darwinports && make && make install"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "rmdir /opt/local/var/db/dports/distfiles"} error]} {
			puts stderr "Internal error: $error"
		}
		if {[catch {system "ln -s /darwinports/distfiles /opt/local/var/db/dports/distfiles"} error]} {
			puts stderr "Internal error: $error"
		}
		#set ui_options(ports_verbose) yes

		# If there was a log file left over from the previous pass,
		# then the port failed with an error.  Send the log in an
		# email to the maintainers.
		if {$logfd ne ""} {
			close $logfd
			set logfd ""
		}
		#if {[file readable $logfilename]} {
		#	if {[catch {system "<$logfilename /usr/sbin/sendmail -t"} error]} {
		#		puts stderr "Internal error: $error"
		#	}
		#}

		# Open the log file for writing
		set logfd [open ${logpath}/${name}.log w]

		set valid 1

		set lint_errors {}
		set portname ""
		set portversion ""
		set description ""
		set category ""

		if {![info exists portinfo(name)]} {
			lappend lint_errors "missing name key"
			set valid 0
		} else {
			set portname $portinfo(name)
		}

		if {![info exists portinfo(description)]} {
			lappend lint_errors "missing description key"
			set valid 0
		} else {
			set description $portinfo(description)
		}

		if {![info exists portinfo(version)]} {
			lappend lint_errors "missing version key"
			set valid 0
		} else {
			set portversion $portinfo(version)
		}

		if {![info exists portinfo(categories)]} {
			lappend lint_errors "missing categories key"
			set valid 0
		} else {
			set category [lindex $portinfo(categories) 0]
		}

		if {![info exists portinfo(maintainers)]} {
			append lint_errors "missing maintainers key"
			set valid 0
			set maintainers kevin@opendarwin.org
		} else {
			set maintainers $portinfo(maintainers)
		}

		pkg_ui_log "To: [join $maintainers {, }]"
		pkg_ui_log "From: donotreply@opendarwin.org"
		pkg_ui_log "Subject: MacPorts $portinfo(name)-$portinfo(version) build failure"
		pkg_ui_log ""
		pkg_ui_log "The following is a transcript produced by the MacPorts automated build		 "
		pkg_ui_log "system.  You are receiving this email because you are listed as a maintainer	"
		pkg_ui_log "of this port, which has failed the automated packaging process.  Please update	"
		pkg_ui_log "the port as soon as possible."
		pkg_ui_log ""
		pkg_ui_log ""
		pkg_ui_log "Thank you,"
		pkg_ui_log "The MacPorts Team"
		pkg_ui_log ""
		pkg_ui_log "================================================================================"
		pkg_ui_log ""

		if {!$valid} {
			foreach error $lint_errors {
				ui_error $error
			}
		}

		ui_msg "packaging ${category}/${portname}-${portversion}"

		# Install binary dependencies if we can, to speed things up.
		#set depends {}
		#if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
		#if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
		#if {[info exists portinfo(depends_build)]} { eval "lappend depends $portinfo(depends_build)" }
		#foreach depspec $depends {
		#	set dep [lindex [split $depspec :] end]
			#install_binary_if_available $dep $pkgbase
		#}
		set dependencies [get_dependencies $portname 1]
		set dependencies [lsort -unique $dependencies]
		foreach dep $dependencies {
			install_binary_if_available $dep $pkgbase
		}

		set options(package.type) pkg
		set options(package.destpath) ${pkgbase}/${category}/

		# Turn on verbose output for the build
		set ui_options(ports_verbose) yes
		set options(subport) $name
		if {[catch {set workername [mportopen $porturl [array get options] [array get variations] yes]} result] ||
			$result == 1} {
			ui_debug $::errorInfo
			ui_error "Internal error: unable to open port: $result"
			continue
		}
		if {[catch {set result [mportexec $workername pkg]} result] ||
			$result == 1} {
			ui_debug $::errorInfo
			ui_error "port package failed: $result"
			mportclose $workername
			continue
		}
		set ui_options(ports_verbose) no
		# Turn verbose output off after the build

		mportclose $workername

		# We made it to the end.  We can delete the log file.
		close $logfd
		set logfd ""
		file delete ${logpath}/${name}.log
	}
}
# end foreach pname

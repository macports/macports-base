#!/usr/bin/env tclsh
# dpkgbuild.tcl
#
# Copyright (c) 2004 Landon Fuller <landonf@opendarwin.org>
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

#######################################
#
# Must be installed outside of dports tree:
#	tcl 8.4
#	curl
#	tar
#	gzip
#	dports tree
#
# A tar file containing full /${portprefix} directory tree, stored in:
#	$pkgrepo/$architecture/root.tar.gz
# The /${portprefix} directory tree must contain:
#	DarwinPorts installation
#	dpkg
#
# Configuration:
#	/etc/ports/dpkg.conf
#	/etc/ports/dpkg
#
#######################################

package require darwinports

namespace eval dpkg {
	variable configopts "pkgrepo architecture portlist portprefix dportsrc silentmode"

	variable silentmode false
	variable configfile "/usr/dports/etc/ports/dpkg.conf"
	variable portlist ""
	variable portprefix "/usr/dports"
	variable dportsrc "/usr/darwinports"
	variable pkgrepo "/export/dpkg/"
	variable architecture "[exec dpkg --print-installation-architecture]"

	# portlistfile defaults to ${pkgrepo}/${architecture}/etc/buildlist.txt (set in main)
	variable portlistfile

	variable logfd
}

proc ui_puts {messageArray} {
	global dpkg::logfd
	array set message $messageArray
	switch -- $message(priority) {
		debug {
			return
		}
		info {
			set str "INFO: $message(data)"
		}
		msg {
			set str $message(data)
		}
		error {
			set str "Error: $message(data)"
		}
		warn {
			set str "Warning: $message(data)"
		}
	}
	if {[string length $logfd] > 0 } {
		log_message $logfd $str
	}
}

proc ui_silent {message} {
	global dpkg::silentmode
	if {"${silentmode}" != true} {
		puts $message
	}
}

proc log_message {channel message} {
	seek $channel 0 end
	puts $channel $message
	flush $channel
}

proc readConfig {file} {
	global dpkg::configopts

	set fd [open $file r]
	while {[gets $fd line] >= 0} {
		foreach option $configopts {
			if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9_:,\./-\]+$)" $line match val] == 1} {
				set dpkg::$option $val
			}
		}
	}
}

proc readPortList {file} {
	global dpkg::portlist
	set fd [open $file r]
	while {[gets $fd line] >= 0} {
		lappend portlist $line
	}
}

proc escape_portname {portname} {
	regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" escaped_string
	return $escaped_string
}

proc print_usage {args} {
	global argv0
	puts "Usage: [file tail $argv0] \[-qa\] \[-f configfile\] \[-p portlist\]"
	puts "	-q	Quiet mode (no warnings!)"
	puts "	-a	Build all ports"
}

proc reset_tree {args} {
	global dpkg::portprefix dpkg::pkgrepo dpkg::architecture

	ui_silent "Deleting ${portprefix} ..."

	if {[catch {system "rm -Rf ${portprefix}"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}

	ui_silent "Deleting /usr/X11R6 ..."
	if {[catch {system "rm -Rf /usr/X11R6"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}

	ui_silent "Deleting /etc/X11 ..."
	if {[catch {system "rm -Rf /etc/X11"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}

	ui_silent "Deletion complete."

	ui_silent "Restoring pristine ${portprefix} from ${pkgrepo}/${architecture}/root.tar.gz"
	if {[catch {system "cd / && tar xvf ${pkgrepo}/${architecture}/root.tar.gz"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}

	ui_silent "Linking static distfiles directory to ${portprefix}/var/db/dports/distfiles."
	if {[catch {system "rmdir ${portprefix}/var/db/dports/distfiles"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}

	if {[catch {system "ln -s ${pkgrepo}/distfiles ${portprefix}/var/db/dports/distfiles"} error]} {
		puts stderr "Internal error: $error"
		exit 1
	}
}

proc main {argc argv} {
	global dpkg::configfile dpkg::pkgrepo dpkg::architecture dpkg::portlistfile dpkg::portlist
	global dpkg::portsArray dpkg::portprefix dpkg::silentmode dpkg::logfd

	# Check if portlistfile was set in the configuration file
	if {![info exists portlistfile]} {
		# The default portlist file
		set portlistfile [file join $pkgrepo $architecture etc buildlist.txt]
	}

	# Read command line options
	set buildall_flag false
	for {set i 0} {$i < $argc} {incr i} {
		set arg [lindex $argv $i]
		switch -- $arg {
			-f {
				incr i
				set configfile [lindex $argv $i]

				if {![file readable $file]} {
					return -code error "Configuration file \"$configfile\" is unreadable."
				}
			}
			-p {
				incr i
				set portlistfile [lindex $argv $i]
				if {![file readable $portlistfile]} {
					return -code error "Port list file \"$portlistfile\" is unreadable."
				}
			}
			-q {
				set silentmode true
			}
			-a {
				set buildall_flag true
			}
			default {
				print_usage
				exit 1
			}
		}
	}

	# If the configuration files are absent, choose reasonable defaults
	if {[file readable $configfile]} {
		readConfig $configfile
	}

	if {[file readable $portlistfile]} {
		readPortList $portlistfile
	}

	# Initialize System
	dportinit

	# If no portlist file was specified, create a portlist that includes all ports
	if {[llength $portlist] == 0 || "$buildall_flag" == "true"} {
		set res [dportsearch {.*}]
		foreach {name array} $res {
			lappend portlist $name
		}
	} else {
		# Port list was specified. Ensure that all the specified ports are available
		foreach port $portlist {
			set searchstring [escape_portname $port]
			set res [dportsearch "^${searchstring}\$"]
			set fail false

			if {[llength $res] < 2} {
				puts "Port \"$port\" not found in index"
				set fail true
			}
		}
		if {"$fail" == "true"} {
			exit 1
		}
	}

	# Ensure that the log directory exists, and open up
	# the default debug log
	file mkdir ${pkgrepo}/log/
	set logfd [open ${pkgrepo}/log/debug.log w 0644]

	# Set the dport options
	# Package build path
	set options(package.destpath) ${pkgrepo}/${architecture}/Packages/
	# Force mode
	set options(ports_force) yes
	# Noisy output
	set options(ports_verbose) yes
	set options(ports_debug) yes

	# Set variations (empty)
	set variations [list]


	if {"$silentmode" != "true"} {
		puts "WARNING: The full contents of ${portprefix}, /usr/X11R6, and /etc/X11 will be deleted by this script. If you do not want this, control-C NOW."
		exec sleep 10
	}

	close $logfd

	foreach port $portlist {
		# Open the default debug log write/append
		set logfd [open ${pkgrepo}/log/debug.log w+ 0644]
		reset_tree


		set searchstring [escape_portname $port]
		if {[catch {set res [dportsearch "^${searchstring}\$"]} error]} {
			puts "Internal error: port search failed: $error"
			exit 1
		}
		array set portinfo [lindex $res 1]

		if {![info exists portinfo(name)] ||
			![info exists portinfo(version)] || 
			![info exists portinfo(revision)] || 
			![info exists portinfo(categories)]} {
			puts "Internal error: $name missing some portinfo keys"
			close $logfd
			continue
		}

		close $logfd

		# Skip up-to-date software
		set pkgfile [get_pkgpath $portinfo(name) $portinfo(version) $portinfo(revision)]
		if {[file exists ${pkgfile}]} {
			if {[regsub {^file://} $portinfo(porturl) "" portpath]} {
				if {[file readable $pkgfile] && ([file mtime ${pkgfile}] > [file mtime ${portpath}/Portfile])} {
					ui_silent "Skipping ${portinfo(name)}-${portinfo(version)}-${portinfo(revision)}; package is up to date."
					continue
				}
			}
		}


		ui_silent "Building $portinfo(name) ..."

		# Create log directory and open the build log
		file mkdir [file join ${pkgrepo} log ${port}]
		set logfd [open ${pkgrepo}/log/${port}/build.log w 0644]

		# Install binary dependencies if possible
		set dependencies [get_dependencies $portinfo(name)]
		foreach dep $dependencies {
			install_binary_if_available $dep
		}

		if {[catch {set workername [dportopen $portinfo(porturl) [array get options] [array get variations] yes]} result] || $result == 1} {
			puts "Internal error: unable to open port: $result"
			exit 1
		}

		if {[catch {set result [dportexec $workername dpkg]} result] || $result == 1} {
			puts "port package failed: $result"
			dportclose $workername

			# Close the log
			close $logfd

			# Move the log to the failure log directory
			file mkdir ${pkgrepo}/failure-logs/${portinfo(name)}
			file copy -force ${pkgrepo}/log/${port}/build.log ${pkgrepo}/failure-logs/${portinfo(name)}/
		} else {
			ui_silent "Package build for $portinfo(name) succeeded"

			# Close the log
			close $logfd

			# Delete any previous failure logs
			if {[catch {system "rm -Rf ${pkgrepo}/failure-logs/${portinfo(name)}"} error]} {
				puts "Internal error: $error"
				exit 1
			}
		}

		# Close the port
		dportclose $workername
	}

	ui_silent "Resetting /usr/dports ..."
	ui_silent "Done."

	ui_silent "Package run finished."
	exit 0
}

proc get_pkgpath {name version revision} {
	global dpkg::pkgrepo dpkg::architecture
	return ${pkgrepo}/${architecture}/Packages/${name}_${version}-${revision}.deb
}

# Recursive bottom-up approach of building a list of dependencies.
proc get_dependencies {portname {includeBuildDeps "true"}} {
	set result [get_dependencies_recurse $portname $includeBuildDeps]
	return [lsort -unique $result]
}

proc get_dependencies_recurse {portname includeBuildDeps} {
	set result {}
	
	set searchstring [escape_portname $portname]
	if {[catch {set res [dportsearch "^$searchstring\$"]} error]} {
		ui_error "Internal error: port search failed: $error"
		return {}
	}

	foreach {name array} $res {
		array set portinfo $array
		if {![info exists portinfo(name)] ||
			![info exists portinfo(version)] || 
			![info exists portinfo(revision)] || 
			![info exists portinfo(categories)]} {
			ui_error "Internal error: $name missing some portinfo keys"
			continue
		}

		lappend result [list $portinfo(name) $portinfo(version) $portinfo(revision) [lindex $portinfo(categories) 0]]

		# Append the package's dependents to the result list
		set depends {}
		if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
		if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
		if {$includeBuildDeps == "true" && [info exists portinfo(depends_build)]} { 
			eval "lappend depends $portinfo(depends_build)"
		}
		foreach depspec $depends {
			set dep [lindex [split $depspec :] 2]
			set x [get_dependencies_recurse $dep $includeBuildDeps]
			eval "lappend result $x"
			set result [lsort -unique $result]
		}
	}
	return $result
}

# Install binary packages if they've already been built.  This will
# speed up the testing, since we won't have to recompile dependencies
# which have already been compiled.

proc install_binary_if_available {dep} {
	global dpkg::architecture dpkg::pkgrepo dpkg::portprefix

	set portname [lindex $dep 0]
	set portversion [lindex $dep 1]
	set portrevision [lindex $dep 2]
	set category [lindex $dep 3]
	
	set receiptdir [file join $portprefix var db receipts ${portname} ${portversion}]
	set pkgpath [get_pkgpath ${portname} ${portversion} ${portrevision}]

	# Check if the package is available, and ensure that it has not already been
	# installed through darwinports (bootstrap packages such as dpkg and its
	# dependencies are always installed)
	if {[file readable $pkgpath] && ![file exists $receiptdir/receipt.bz2]} {
		ui_silent "Installing binary: $pkgpath"
		if {[catch {system "dpkg --force-depends -i ${pkgpath}"} error]} {
			puts "Internal error: $error"
			exit 1
		}
		# Touch the receipt
		file mkdir $receiptdir
		if {[catch {system "touch [file join $receiptdir receipt.bz2]"} error]} {
			puts "Internal error: $error"
			exit 1
		}
	}
}

### main() entry point ####
main $argc $argv

#!/usr/bin/env tclsh8.4
# dpkgbuild.tcl
# $Id$
#
# Copyright (c) 2009-2011 The MacPorts Project
# Copyright (c) 2004 Landon Fuller <landonf@macports.org>
# Copyright (c) 2003 Kevin Van Vechten <kevin@opendarwin.org>
# Copyright (c) 2002 Apple Inc.
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

#######################################
#
# Must be installed outside of dports tree:
#	tcl 8.4
#	curl
#	tar
#	gzip
#	unzip
#	dports tree
#
# A tar file containing full /${portprefix} directory tree, stored in:
#	$pkgrepo/$architecture/root.tar.gz
# The /${portprefix} directory tree must contain:
#	MacPorts installation
#	dpkg
#
# Configuration:
#	/etc/ports/dpkg.conf
#	/etc/ports/dpkg
#
#######################################

package require darwinports

# Configuration Namespace
namespace eval dpkg {
	variable configopts "pkgrepo architecture portlistfile portprefix dportsrc silentmode initialports"

	# Preferences
	variable silentmode false
	variable configfile "/etc/ports/dpkg.conf"
	variable portlist ""
	variable portprefix "/usr/dports"
	variable dportsrc "/usr/darwinports"
	variable pkgrepo "/export/dpkg/"
	# architecture is set in main
	variable architecture
	variable initialports "dpkg apt"
	variable aptpackagedir
	variable packagedir
	# portlistfile defaults to ${pkgrepo}/${architecture}/etc/buildlist.txt (set in main)
	variable portlistfile
	# baselistfile defaults to ${pkgrepo}/${architecture}/etc/baselist.txt (set in main)
	variable baselistfile

	# Non-user modifiable.
	# Ports required for building. Format:
	# <binary> <portname> <binary> <portname> ...
	variable requiredports "dpkg dpkg apt-get apt"

	# Current log file descriptor
	variable logfd
}

# MacPorts UI Event Callbacks
proc ui_prefix {priority} {
    switch $priority {
        debug {
        	return "Debug: "
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
	global dpkg::logfd
	if {[info exists logfd] && [string length $logfd] > 0 } {
		return {$logfd}
	} elseif {$message(priority) != "debug"} {
		# If there's no log file, echo to stdout
		return {stdout}
	}
}

proc ui_silent {message} {
	global dpkg::silentmode
	if {"${silentmode}" != true} {
		puts $message
		ui_msg $message
	} else {
		ui_msg $message
	}
}

# Outputs message to console and to log
# Should only be used with errors
proc ui_noisy_error {message} {
	puts $message
	ui_error $message
}

proc log_message {channel message} {
	seek $channel 0 end
	puts $channel $message
	flush $channel
}

# Read in configuration file
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

# Read a list of newline seperated port names from $file
proc readPortList {file} {
	set fd [open $file r]
	set portlist ""

	while {[gets $fd line] >= 0} {
		lappend portlist $line
	}

	return $portlist
}

# Escape all regex characters in a portname
proc regex_escape_portname {portname} {
	regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" escaped_string
	return $escaped_string
}

# Print usage string
proc print_usage {args} {
	global argv0
	puts "Usage: [file tail $argv0] \[-qa\] \[-f configfile\] \[-p portlist\]"
	puts "	-q	Quiet mode (only errors reported)"
	puts "	-w	No warnings (progress still reported)"
	puts "	-a	Build all ports"
	puts "	-b	Re-generate base install archive"
	puts "	-p	Attempt to build ports that do not advertise support for the build platform"
	puts "	-i	Initialize Build System (Should only be run on a new build system)"
}

# Delete and restore the build system
proc reset_tree {args} {
	global dpkg::portprefix dpkg::pkgrepo dpkg::architecture

	ui_silent "Restoring pristine ${portprefix} from ${pkgrepo}/${architecture}/root.tar.gz"
	if {[catch {system "rm -Rf ${portprefix}"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	if {[catch {system "rm -Rf /usr/X11R6"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	if {[catch {system "rm -Rf /etc/X11"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	if {[catch {system "cd / && tar xvf ${pkgrepo}/${architecture}/root.tar.gz"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	ui_silent "Linking static distfiles directory to ${portprefix}/var/db/dports/distfiles."
	if {[file isdirectory ${portprefix}/var/db/dports/distfiles"]} {
		if {[catch {system "rm -rf ${portprefix}/var/db/dports/distfiles"} error]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: $error"
			exit 1
		}

		if {[catch {system "ln -s ${pkgrepo}/distfiles ${portprefix}/var/db/dports/distfiles"} error]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: $error"
			exit 1
		}
	}
}

proc main {argc argv} {
	global dpkg::configfile dpkg::pkgrepo dpkg::architecture dpkg::portlistfile
	global dpkg::portsArray dpkg::portprefix dpkg::silentmode dpkg::logfd dpkg::packagedir dpkg::aptpackagedir
	global dpkg::requiredports dpkg::baselistfile tcl_platform

	# First time through, we reset the tree
	set firstrun_flag true

	# Read command line options
	set buildall_flag false
	set anyplatform_flag false
	set nowarn_flag false
	set basegen_flag false
	set initialize_flag false

	for {set i 0} {$i < $argc} {incr i} {
		set arg [lindex $argv $i]
		switch -- $arg {
			-a {
				set buildall_flag true
			}
			-b {
				set basegen_flag true
			}
			-f {
				incr i
				set configfile [lindex $argv $i]

				if {![file readable $configfile]} {
					return -code error "Configuration file \"$configfile\" is unreadable."
				}
			}
			-i {
				set initialize_flag true
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
			-w {
				set nowarn_flag true
			}
			-p {
				set anyplatform_flag true
			}
			default {
				print_usage
				exit 1
			}
		}
	}

	# Initialize System
	array set ui_options {}
	array set options {}
	array set variations {}
	mportinit ui_options options variations

	# If -i was specified, install base system and exit
	if {$initialize_flag == "true"} {
		initialize_system
		exit 0
	}

	# We must have dpkg by now 
	if {[catch {set_architecture} result]} {
		puts "$result."
		puts "Have you initialized the build system? Use the -i flag:"
		print_usage
		exit 1
	}

	# Set the platform
	set platformString [string tolower $tcl_platform(os)]

	set packagedir ${pkgrepo}/${architecture}/packages/
	set aptpackagedir ${pkgrepo}/apt/dists/stable/main/binary-${architecture}/

	# Read configuration files
	if {[file readable $configfile]} {
		readConfig $configfile
	}

	# If portlistfile has not been set, supply a reasonable default
	if {![info exists portlistfile]} {
		# The default portlist file
		set portlistfile [file join $pkgrepo $architecture etc buildlist.txt]
	}

	# If baselistfile has not been set, supply a reasonable default
	if {![info exists baselistfile]} {
		# The default baselist file
		set baselistfile [file join $pkgrepo $architecture etc baselist.txt]
	}

	# Read the port list
	if {[file readable $portlistfile]} {
		set portlist [readPortList $portlistfile]
	} else {
		set portlist ""
	}

	if {[file readable $baselistfile]} {
		set baselist [readPortList $baselistfile]
	} else {
		set baselist ""
	}

	# If no portlist file was specified, create a portlist that includes all ports
	if {[llength $portlist] == 0 || "$buildall_flag" == "true"} {
		set res [mportlistall]
		foreach {name array} $res {
			lappend portlist $name
		}
	} else {
		# Port list was specified. Ensure that all the specified ports are available.
		# Add ${baselist} and get_required_ports to the list
		set portlist [lsort -unique [concat $portlist $baselist [get_required_ports]]]
		foreach port $portlist {
			set fail false

			if {[catch {set res [get_portinfo $port]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				ui_noisy_error "Error: $result"
				set fail true
			}

			# Add all of the specified ports' dependencies to the portlist
			set dependencies [get_dependencies $port false]
			foreach dep $dependencies {
				lappend portlist [lindex $dep 0]
			}
		}
		if {"$fail" == "true"} {
			exit 1
		}
	}

	# Clean out duplicates
	set portlist [lsort -unique $portlist]

	# Ensure that the log directory exists, and open up
	# the default debug log
	open_default_log w

	# Set the dport options
	# Package build path
	set options(package.destpath) ${packagedir}

	# Ensure that it exists
	file mkdir $options(package.destpath)

	# Force mode
	set options(ports_force) yes

	# Set variations (empty)
	set variations [list]


	if {"$silentmode" != "true" && "$nowarn_flag" != "true"} {
		puts "WARNING: The full contents of ${portprefix}, /usr/X11R6, and /etc/X11 will be deleted by this script. If you do not want this, control-C NOW."
		exec sleep 10
	}

	# Destroy the existing apt repository
	if {[catch {system "rm -Rf ${aptpackagedir}"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	# Recreate
	file mkdir ${aptpackagedir}

	close_default_log

	foreach port $portlist {
		# Open the default debug log write/append
		open_default_log

		if {[catch {set res [get_portinfo $port]} error]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: port search failed: $error"
			exit 1
		}

		# Reset array from previous runs
		unset -nocomplain portinfo
		array set portinfo [lindex $res 1]

		if {![info exists portinfo(name)] ||
			![info exists portinfo(version)] || 
			![info exists portinfo(revision)] || 
			![info exists portinfo(categories)]} {
			ui_noisy_error "Internal error: $name missing some portinfo keys"
			close $logfd
			continue
		}

        # open correct subport
        set options(subport) $portinfo(name)

		# Skip un-supported ports
		if {[info exists portinfo(platforms)] && ${anyplatform_flag} != "true"} {
			if {[lsearch $portinfo(platforms) $platformString] == -1} {
				ui_silent "Skipping unsupported port $portinfo(name) (platform: $platformString supported: $portinfo(platforms))"
				continue
			}
		}


		# Add apt override line. dpkg is special cased and marked 'required'
		# TODO: add the ability to specify the "required" priority for specific
		# ports in a config file.
		if {"$portinfo(name)" == "dpkg"} {
			set pkg_priority required
		} else {
			set pkg_priority optional
		}
		add_override $portinfo(name) $pkg_priority [lindex $portinfo(categories) 0]

		# Skip up-to-date software
		set pkgfile [get_pkgpath $portinfo(name) $portinfo(version) $portinfo(revision)]
		if {[file exists ${pkgfile}]} {
			if {[regsub {^file://} $portinfo(porturl) "" portpath]} {
				if {[file readable $pkgfile] && ([file mtime ${pkgfile}] > [file mtime ${portpath}/Portfile])} {
					ui_silent "Skipping ${portinfo(name)}-${portinfo(version)}-${portinfo(revision)}; package is up to date."
					# Shove the package into the apt repository
					copy_pkg_to_apt $portinfo(name) $portinfo(version) $portinfo(revision) [lindex $portinfo(categories) 0]
					continue
				}
			}
		}

		# We're going to actually build the package, reset the tree
		# if this is our first time through. The tree is always reset
		# at the end of a packaging run, too.
		if {$firstrun_flag == true} {
			reset_tree
			set firstrun_flag false
		}

		ui_silent "Building $portinfo(name) ..."

		# Close the main debug log
		close_default_log

		# Create log directory and open the build log
		file mkdir [file join ${pkgrepo} ${architecture} log build ${port}]
		set logfd [open ${pkgrepo}/${architecture}/log/build/${port}/build.log w 0644]

		# Install binary dependencies if possible
		set dependencies [get_dependencies $portinfo(name)]
		foreach dep $dependencies {
			install_binary_if_available $dep
		}

		if {[catch {set workername [mportopen $portinfo(porturl) [array get options] [array get variations] yes]} result] || $result == 1} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: unable to open port: $result"
			exit 1
		}

		if {[catch {set result [mportexec $workername clean]} result] || $result == 1} {
			ui_noisy_error "Cleaning $portinfo(name) failed, consult build log"

			# Close the log
			close $logfd

			# Copy the log to the failure directory
			copy_failure_log $portinfo(name)

			# Close the port
			mportclose $workername

			continue
		}

		# Re-open the port. MacPorts doesn't play well with multiple targets, apparently
		mportclose $workername
		if {[catch {set workername [mportopen $portinfo(porturl) [array get options] [array get variations] yes]} result] || $result == 1} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: unable to open port: $result"
			exit 1
		}

		if {[catch {set result [mportexec $workername dpkg]} result] || $result == 1} {
			ui_noisy_error "Packaging $portinfo(name) failed, consult build log"

			# Copy the log to the failure directory
			copy_failure_log $portinfo(name)

			# Close the port
			mportclose $workername

			# Close the log
			close $logfd

			# Open default log
			open_default_log

			ui_silent "Resetting /usr/dports ..."
			reset_tree
			ui_silent "Done."

			# Close the log
			close $logfd

			continue
		}

		ui_silent "Package build for $portinfo(name) succeeded"
		
		# Into the apt repository you go!
		copy_pkg_to_apt $portinfo(name) $portinfo(version) $portinfo(revision) [lindex $portinfo(categories) 0]

		ui_silent "Resetting /usr/dports ..."
		reset_tree
		ui_silent "Done."

		# Close the log
		close $logfd

		# Delete any previous failure logs
		delete_failure_log $portinfo(name)

		# Close the port
		mportclose $workername
	}

	open_default_log

	# If required, rebuild the clientinstall.tgz
	if {$basegen_flag == true} {
		# dpkg is always required
		set pkglist [lsort -unique [concat dpkg $baselist [get_required_ports]]]
		set workdir [file join ${pkgrepo} ${architecture}]
		set rootdir [file join $workdir clientroot]
		set rootfile [file join $workdir client-root.tar.gz]
		file mkdir ${rootdir}

		# dpkg is required
		array set portinfo [lindex [get_portinfo dpkg] 1]
		set pkgfile [get_pkgpath $portinfo(name) $portinfo(version) $portinfo(revision)]
		system "cd \"${rootdir}\" && ar x \"${pkgfile}\" data.tar.gz"
		system "cd \"${rootdir}\" && tar xvf data.tar.gz; rm data.tar.gz"

		foreach port $pkglist {
			set dependencies [get_dependencies $port false]
			foreach dep $dependencies {
				lappend newpkglist [lindex $dep 0]
			}
		}

		if {[info exists newpkglist]} {		
			set pkglist [lsort -unique [concat $newpkglist $pkglist]]
		}

		foreach port $pkglist {
			array set portinfo [lindex [get_portinfo $port] 1]
			system "dpkg --root \"${rootdir}\" --force-depends -i \"[get_pkgpath $portinfo(name) $portinfo(version) $portinfo(revision)]\""
		}

		system "cd \"${rootdir}\" && tar cf \"[file join ${workdir} clientinstall.tar.gz]\" ."
		file delete -force ${rootdir}
	}

	ui_silent "Building apt-get index ..."
	if {[catch {system "cd ${pkgrepo}/apt && dpkg-scanpackages dists override >${aptpackagedir}/Packages"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}

	if {[catch {system "cd ${aptpackagedir} && gzip Packages"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}
	remove_override_file
	ui_silent "Done."

	ui_silent "Package run finished."
	close_default_log

	exit 0
}

# Return ports listed in $dpkg::requiredports that are not
# installed
proc get_required_ports {args} {
	global dpkg::requiredports
	set reqlist ""

	foreach {binary port} $requiredports {
		if {[find_binary $binary] == ""} {
			lappend reqlist $port
		}
	}
	return $reqlist
}

# Given a binary name, searches PATH
proc find_binary {binary} {
	global env
	set path [split $env(PATH) :]
	foreach dir $path {
		set file [file join $dir $binary]
		if {[file exists $file]} {
			return $file
		}
	}
	return ""
}

# Set the architecture global
proc set_architecture {args} {
	set dpkg::architecture "[exec dpkg --print-installation-architecture]"
}

# Initialize a new build system
proc initialize_system {args} {
	global dpkg::initialports dpkg::pkgrepo
	global dpkg::architecture dpkg::portprefix

	# Create standard directories
	ui_msg "Creating ${pkgrepo} directory"
	file mkdir ${pkgrepo}

	set builddeps ""
	set rundeps ""

	foreach port [get_required_ports] {
		set builddeps [concat $builddeps [get_dependencies $port true]]
		set rundeps [concat $rundeps [get_dependencies $port false]]
	}

	set buildlist [lsort -unique $builddeps]

	foreach port $builddeps {
		if {[lsearch -exact $port $rundeps] >= 0 } {
			lappend removelist $port
		}
	}

	set options ""
	set variations ""

	foreach port [get_required_ports] {
	    set options(subport) $port
		if {[catch {do_portexec $port [array get options] [array get variants] activate} result]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Fatal error: $result"
			exit 1
		}
	}

	if {[info exists removelist]} {
		ui_msg "Removing build dependencies ..."
		foreach portlist $removelist {
			set port [lindex $portlist 0]

			ui_msg "Uninstalling $port."
			if { [catch {registry_uninstall::uninstall $portname $portversion "" 0 [array get options]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				ui_noisy_errorr "Fatal error: Uninstalling $port failed: $result"
				exit 1
			}
		}
		ui_msg "Done."
	}
			

	if {[catch {set_architecture} result]} {
		puts "Fatal error: $result."
		exit 1
	}

	ui_msg "Creating [file join ${pkgrepo} ${architecture}] directory"
	file mkdir [file join ${pkgrepo} ${architecture}]
	file mkdir [file join ${pkgrepo} ${architecture} etc]

	ui_msg "Generating pristine archive: [file join ${pkgrepo} ${architecture} root.tar.gz]"
	if {[catch {system "tar -zcf \"[file join ${pkgrepo} ${architecture} root.tar.gz]\" \"${portprefix}\""} result]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Fatal error: Archive creation failed: $result"
		exit 1
	}

	ui_msg "Build system successfully initialized!"
}

# Execute a target on a port (by port name)
proc do_portexec {port options variants target} {

	array set portinfo [lindex [get_portinfo $port] 1]

	if {[catch {set workername [mportopen $portinfo(porturl) $options $variants yes]} result] || $result == 1} {
		return -code error "Internal error: unable to open port: $result"
		exit 1
	}

	if {[catch {set result [mportexec $workername $target]} result] || $result == 1} {

		# Close the port
		mportclose $workername

		# Return error
		return -code error "Executing target $target on $portinfo(name) failed."
	}
}

proc get_portinfo {port} {
	set searchstring [regex_escape_portname $port]
	set res [mportlookup ${searchstring}]

	if {[llength $res] < 2} {
		return -code error "Port \"$port\" not found in index."
	}

	return $res
}

# Given name, version, and revision, returns the path to a package file
proc get_pkgpath {name version revision} {
	global dpkg::pkgrepo dpkg::architecture
	global dpkg::packagedir
	if {${revision} == 0} {
		set revision ""
	} else {
		set revision "-${revision}"
	}

	return [string tolower ${packagedir}/${name}_${version}${revision}_${architecture}.deb]
}

# Opens the default log file and sets dpkg::logfd
proc open_default_log {{mode a}} {
	global dpkg::pkgrepo dpkg::architecture dpkg::logfd
	# Ensure that the log directory exists, and open up
	# the default debug log
	file mkdir ${pkgrepo}/${architecture}/log/
	set logfd [open ${pkgrepo}/${architecture}/log/debug.log ${mode} 0644]
}

# Closes the current logfile
proc close_default_log {args} {
	global dpkg::logfd
	close $logfd
}

# Copies a port log file to the failure directory
proc copy_failure_log {name} {
	global dpkg::pkgrepo dpkg::architecture
	# Copy the log to the failure log directory
	file mkdir ${pkgrepo}/${architecture}/log/failure/${name}
	file copy -force ${pkgrepo}/${architecture}/log/build/${name}/build.log ${pkgrepo}/${architecture}/log/failure/${name}/
}

# Deletes a port's failure log
proc delete_failure_log {name} {
	global dpkg::pkgrepo dpkg::architecture
	if {[catch {system "rm -Rf ${pkgrepo}/${architecture}/log/failure/${name}"} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}
}

# Add an override entry to the apt override file
proc add_override {name priority section {maintainer ""}} {
	global dpkg::aptpackagedir dpkg::pkgrepo
	set output "${name}	${priority}	${section}"
	if {${maintainer} != ""} {
		append output " ${maintainer}"
	}
	set fd [open "${pkgrepo}/apt/override" a 0644]
	puts $fd $output
	close $fd
}

# Deletes the apt override file
proc remove_override_file {args} {
	global dpkg::aptpackagedir dpkg::pkgrepo
	if {[catch {file delete -force ${pkgrepo}/apt/override} error]} {
		global errorInfo
		ui_debug "$errorInfo"
		ui_noisy_error "Internal error: $error"
		exit 1
	}
}

# Copies a given package to the apt repository
proc copy_pkg_to_apt {name version revision category} {
	global dpkg::aptpackagedir

	set pkgfile [get_pkgpath $name $version $revision]
	file mkdir $aptpackagedir/main/$category
	file link -hard $aptpackagedir/main/$category/[file tail $pkgfile] $pkgfile
}

# Recursive bottom-up approach of building a list of dependencies.
proc get_dependencies {portname {includeBuildDeps "true"}} {
	set result [get_dependencies_recurse $portname $includeBuildDeps]
	return [lsort -unique $result]
}

proc get_dependencies_recurse {portname includeBuildDeps} {
	set result {}
	
	set res [get_portinfo $portname]

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
		if {$includeBuildDeps == "true" && [info exists portinfo(depends_fetch)]} { 
			eval "lappend depends $portinfo(depends_fetch)"
		}
		if {$includeBuildDeps == "true" && [info exists portinfo(depends_extract)]} { 
			eval "lappend depends $portinfo(depends_extract)"
		}
		foreach depspec $depends {
			set dep [lindex [split $depspec :] end]
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

	if {${portrevision} != ""} {
		set verstring ${portversion}_${portrevision}
	} else {
		set verstring ${portversion}
	}
	
	set receiptdir [file join $portprefix var db receipts ${portname} ${verstring}]
	set pkgpath [get_pkgpath ${portname} ${portversion} ${portrevision}]

	# Check if the package is available, and ensure that it has not already been
	# installed through MacPorts (bootstrap packages such as dpkg and its
	# dependencies are always installed)
	if {[file readable $pkgpath] && ![file exists $receiptdir/receipt.bz2]} {
		ui_silent "Installing binary: $pkgpath"
		if {[catch {system "dpkg --force-depends -i ${pkgpath}"} error]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: $error"
			exit 1
		}
		# Touch the receipt
		file mkdir $receiptdir
		if {[catch {system "touch [file join $receiptdir receipt.bz2]"} error]} {
			global errorInfo
			ui_debug "$errorInfo"
			ui_noisy_error "Internal error: $error"
			exit 1
		}
	}
}

### main() entry point ####
main $argc $argv

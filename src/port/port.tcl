#!/bin/sh
#\
exec @TCLSH@ "$0" "$@"
# port.tcl
# $Id: port.tcl,v 1.86 2005/09/13 18:09:38 jberry Exp $
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
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
#	TODO:
#		- Support globing of portnames?
#

catch {source \
	[file join "/Library/Tcl" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports

# globals
set portdir .
set action ""
set portlist [list]
array set global_options [list]

# UI Instantiations
# ui_options(ports_debug) - If set, output debugging messages.
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"

# ui_options accessor
proc ui_isset {val} {
	global ui_options
	if {[info exists ui_options($val)]} {
		if {$ui_options($val) == "yes"} {
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
            	return {stderr}
            } else {
            	return {}
            }
        }
        info {
            if {[ui_isset ports_verbose]} {
                return {stdout}
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
        error {
        	return {stderr}
        }
        default {
        	return {stdout}
        }
    }
}

# Standard procedures
proc print_usage args {
	global argv0
	puts "Usage: [file tail $argv0] \[-vdqfonausbckt\] \[-D portdir\] target \[flags\] \[portname\] \[options\] \[variants\]"
}

proc fatal s {
	global argv0
	puts stderr "$argv0: $s"
	exit
}


# Form a composite version as is sometimes used for registry functions
proc composite_version {version variations} {
	# Form a composite version out of the version and variations
	set pos [list]
	set neg [list]
	
	# Select the variations into positive and negative
	foreach { key val } $variations {
		if {$val == "+"} {
			lappend pos $key
		} elseif {$val == "-"} {
			lappend neg $key
		}
	}
	
	# If there is no version, we have nothing to do
	set composite_version ""
	if {$version != ""} {
		set pos_str ""
		set neg_str ""
		
		if {[llength $pos]} {
			set pos_str "+[join [lsort -ascii $pos] "+"]"
		}
		if {[llength $neg]} {
			set neg_str "-[join [lsort -ascii $neg] "-"]"
		}
		
		set composite_version "$version$pos_str$neg_str"
	}
	
	return $composite_version
}


proc split_variants {variants} {
	set result [list]
	set l [regexp -all -inline -- {([-+])([[:alpha:]_]+[\w\.]*)} $variants]
	foreach { match sign variant } $l {
		lappend result $variant $sign
	}
	return $result
}


proc registry_installed {portname {portversion ""}} {
	set ilist [registry::installed $portname $portversion]
	if { [llength $ilist] > 1 } {
		puts "The following versions of $portname are currently installed:"
		foreach i $ilist { 
			set iname [lindex $i 0]
			set iversion [lindex $i 1]
			set irevision [lindex $i 2]
			set ivariants [lindex $i 3]
			set iactive [lindex $i 4]
			if { $iactive == 0 } {
				puts "	$iname ${iversion}_${irevision}${ivariants}"
			} elseif { $iactive == 1 } {
				puts "	$iname ${iversion}_${irevision}${ivariants} (active)"
			}
		}
		return -code error "Registry error: Please specify the full version as recorded in the port registry."
	} else {
		return [lindex $ilist 0]
	}
}


proc add_to_portlist {portentry {options ""}} {
	upvar portlist portlist
	global global_options
	if {![llength $options]} {
		set options [array get global_options]
	}
	lappend portlist [lappend portentry $options]
}


proc add_ports_to_portlist {ports {options ""}} {
	upvar portlist portlist
	global global_options
	if {![llength $options]} {
		set options [array get global_options]
	}
	foreach portentry $ports {
		lappend portlist [lappend portentry $options]
	}
}


proc url_to_portname { url } {
	if {[catch {set ctx [dportopen $url]} result]} {
		return ""
	} else {
		array set portinfo [dportinfo $ctx]
		set portname $portinfo(name)
		dportclose $ctx
		return $portname
	}
}


# Supply a default porturl/portname if the portlist is empty
proc require_portlist {} {
	global global_porturl
	
	upvar portlist portlist
	if {[llength $portlist] == 0} {
		if {[info exists global_porturl]} {
			set url $global_porturl
		} else {
			set url file://./
		}
		set portname [url_to_portname $url]
	
		if {$portname != ""} {
			add_to_portlist [list $url $portname "" ""]
		} else {
			puts "You must specify a port or be in a port directory"
			exit 1
		}
	}
}


# Execute the enclosed block once for every element in the portlist
# When the block is entered, the variables portname, portversion, options, and variations
# will have been set
proc foreachport {portlist block} {
	foreach portspec $portlist {
		uplevel 1 "
			set porturl \"[lindex $portspec 0]\"
			set portname \"[lindex $portspec 1]\"
			set portversion \"[lindex $portspec 2]\"
			array unset variations
			array set variations { [lindex $portspec 3] }
			array unset options
			array set options { [lindex $portspec 4] }
			$block
			"
	}
}


proc get_all_ports {} {
	set pat ".+"
	if {[catch {set res [dportsearch ^$pat\$]} result]} {
		global errorInfo
		ui_debug "$errorInfo"
		fatal "port search failed: $result"
	}

	set results [list]
	foreach {name info} $res {
		array set portinfo $info
		foreach variant $portinfo(variants) {
			lappend variants $variant "+"
		}
		# For now, don't include version or variants with all ports list
		#"$portinfo(version)_$portinfo(revision)"
		#$variants
		lappend results [list $portinfo(porturl) $name {} {}]
	}
	
	# Return the list of all ports, sorted
	return [lsort -ascii -index 1 $results]
}


proc get_current_port {} {
	global global_porturl

	if {[info exists global_porturl]} {
		set url $global_porturl
	} else {
		set url file://./
	}
	set portname [url_to_portname $url]

	if {$portname == ""} {
		fatal "The pseudo-port current must be issued in a port's directory"
	}
	
	return [list [list $url $portname "" ""]]
}


proc get_installed_ports {} {
	if { [catch {set ilist [registry::installed]} result] } {
		if {$result == "Registry error: No ports registered as installed."} {
			fatal "No ports installed!"
		} else {
			global errorInfo
			ui_debug "$errorInfo"
			fatal "port installed failed: $result"
		}
	}
	
	set results [list]
	foreach i $ilist {
		set iname [lindex $i 0]
		set iversion [lindex $i 1]
		set irevision [lindex $i 2]
		set ivariants [split_variants [lindex $i 3]]
		set iactive [lindex $i 4]
		
		lappend results [list "" $iname "${iversion}_${irevision}" $ivariants]
	}
	
	# Return the list of ports, sorted
	return [lsort -ascii -index 1 $results]
}


proc get_uninstalled_ports {} {
	# Get list of all ports and installed ports
	set all [get_all_ports]
	set installed [get_installed_ports]
	
	# Create an array of the installed ports so that we can quickly search it
	array unset installed_array 
	foreach port $installed {
		set installed_array([lindex $port 1]) yes
	}
	
	# Create a new list, omitting all those ports that are in installed_array
	set results [list]
	foreach port $all {
		if {![info exists installed_array([lindex $port 1])]} {
			lappend results $port
		}
	}
	
	return $results
}


proc get_active_ports {} {
	if { [catch {set ilist [registry::installed]} result] } {
		if {$result == "Registry error: No ports registered as installed."} {
			fatal "No ports installed!"
		} else {
			global errorInfo
			ui_debug "$errorInfo"
			fatal "port installed failed: $result"
		}
	}
	
	set results [list]
	foreach i $ilist {
		set iname [lindex $i 0]
		set iversion [lindex $i 1]
		set irevision [lindex $i 2]
		set ivariants [split_variants [lindex $i 3]]
		set iactive [lindex $i 4]
		if {!$iactive} continue
		lappend results [list "" $iname "${iversion}_${irevision}" $ivariants]
	}

	# Return the list of ports, sorted
	return [lsort -ascii -index 1 $results]
}


proc get_inactive_ports {} {
	if { [catch {set ilist [registry::installed]} result] } {
		if {$result == "Registry error: No ports registered as installed."} {
			fatal "No ports installed!"
		} else {
			global errorInfo
			ui_debug "$errorInfo"
			fatal "port installed failed: $result"
		}
	}
	
	set results [list]
	foreach i $ilist {
		set iname [lindex $i 0]
		set iversion [lindex $i 1]
		set irevision [lindex $i 2]
		set ivariants [split_variants [lindex $i 3]]
		set iactive [lindex $i 4]
		if {$iactive} continue
		lappend results [list "" $iname "${iversion}_${irevision}" $ivariants]
	}

	# Return the list of ports, sorted
	return [lsort -ascii -index 1 $results]
}


proc get_outdated_ports {} {
	# If port names were supplied, limit ourselves to those port, else check all installed ports
	if { [catch {set ilist [registry::installed]} result] } {
		global errorInfo
		ui_debug "$errorInfo"
		fatal "can't get installed ports: $result"
	}

	set results [list]
	if { [llength $ilist] > 0 } {
		foreach i $ilist { 

			# Get information about the installed port
			set portname			[lindex $i 0]
			set installed_version	[lindex $i 1]
			set installed_revision	[lindex $i 2]
			set installed_compound	"${installed_version}_${installed_revision}"
			set installed_variants	[lindex $i 3]

			set is_active			[lindex $i 4]
			if { $is_active == 0 } continue
			set installed_epoch		[lindex $i 5]

			# Get info about the port from the index
			# Escape regex special characters
			regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
			if {[catch {set res [dportsearch ^$search_string\$]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}
			if {[llength $res] < 2} {
				if {[ui_isset ports_debug]} {
					puts "$portname ($installed_compound is installed; the port was not found in the port index)"
				}
				continue
			}
			array set portinfo [lindex $res 1]
			
			# Get information about latest available version and revision
			set latest_version $portinfo(version)
			set latest_revision		0
			if {[info exists portinfo(revision)] && $portinfo(revision) > 0} { 
				set latest_revision	$portinfo(revision)
			}
			set latest_compound		"${latest_version}_${latest_revision}"
			set latest_epoch		0
			if {[info exists portinfo(epoch)]} { 
				set latest_epoch	$portinfo(epoch)
			}
			
			# Compare versions, first checking epoch, then the compound version string
			set comp_result [expr $installed_epoch - $latest_epoch]
			if { $comp_result == 0 } {
				set comp_result [rpm-vercomp $installed_compound $latest_compound]
			}
			
			# Add outdated ports to our results list
			if { $comp_result < 0 } {
				lappend results [list "" $portname $installed_compound [split_variants $installed_variants]]
			}
		}
	}

	return $results
}



# Main
set argn 0

# Initialize dport
if {[catch {dportinit} result]} {
	global errorInfo
	puts "$errorInfo"
	fatal "Failed to initialize ports system, $result"
}

# Parse global options
while {$argn < $argc} {
	set arg [lindex $argv $argn]
	
	if {[string index $arg 0] != "-"} {
		break
	} elseif {[string index $arg 1] == "-"} {
		# Process long args -- we don't support any for now
		print_usage; exit 1
	} else {
		# Process short arg(s)
		set opts [string range $arg 1 end]
		foreach c [split $opts] {
			switch -- $c {
				v {	set ui_options(ports_verbose) yes		}
				d { set ui_options(ports_debug) yes
					# debug implies verbose
					set ui_options(ports_verbose) yes
				  }
				q { set ui_options(ports_quiet) yes
					set ui_options(ports_verbose) no
					set ui_options(ports_debug) no
				  }
				f { set global_options(ports_force) yes			}
				o { set global_options(ports_ignore_older) yes	}
				n { set global_options(ports_nodeps) yes		}
				a { set global_options(port_upgrade_all) yes	}
				u { set global_options(port_uninstall_old) yes	}
				s { set global_options(ports_source_only) yes	}
				b { set global_options(ports_binary_only) yes	}
				c { set global_options(ports_autoclean) yes		}
				k { set global_options(ports_autoclean) no		}
				t { set global_options(ports_trace) yes			}
				D { incr argn
					set global_porturl "file://[lindex $argv $argn]"
				  }
				u { incr argn
					set global_porturl [lindex $argv $argn]
				  }
				default {
					print_usage; exit 1
				  }
			}
		}
	}
	
	incr argn
}

# Process an action if there is one
if {$argn < $argc} {
	set action [lindex $argv $argn]
	incr argn
	
	# Parse action options
	while {$argn < $argc} {
		set arg [lindex $argv $argn]
		
		if {[string index $arg 0] != "-"} {
			break
		} elseif {[string index $arg 1] == "-"} {
			# Process long options
			set key [string range $arg 2 end]
			set global_options(ports_${action}_${key}) yes
		} else {
			# Process short options
			# There are none for now
			print_usage; exit 1
		}
		
		incr argn
	}
	
	# Parse port specs associated with the action
	while {$argn < $argc} {
		set portname [lindex $argv $argn]
		incr argn

		set portversion	""
		array set portoptions [array get global_options]
		array unset portvariants
		
		# Parse port version/variants/options
		set portversion ""
		set opt ""
		for {set firstTime 1} {$opt != "" || $argn < $argc} {set firstTime 0} {
			# Refresh opt as needed
			if {[string length $opt] == 0} {
				set opt [lindex $argv $argn]
				incr argn
			}
			
			# Version must be first, if it's there at all
			if {$firstTime && [string match {[0-9]*} $opt]} {
				# Parse the version
				
				set sepPos [string first "/" $opt]
				if {$sepPos >= 0} {
					# Version terminated by "/" to disambiguate -variant from part of version
					set portversion [string range $opt 0 [expr $sepPos-1]]
					set opt [string range $opt [expr $sepPos+1] end]
				} else {
					set sepPos [string first "+" $opt]
					if {$sepPos >= 0} {
						# Version terminated by "+"
						set portversion [string range $opt 0 [expr $sepPos-1]]
						set opt [string range $opt $sepPos end]
					} else {
						# Unterminated version
						set portversion $opt
						set opt ""
					}
				}
			} else {
				# Parse all other options
				
				# Look first for a variable setting: VARNAME=VALUE
				if {[regexp {^([[:alpha:]_]+[\w\.]*)=(.*)} $opt match key val] == 1} {
					# It's a variable setting
					set portoptions($key) \"$val\"
					set opt ""
				} elseif {[regexp {^([-+])([[:alpha:]_]+[\w\.]*)} $opt match sign variant] == 1} {
					# It's a variant
					set portvariants($variant) $sign
					set opt [string range $opt [expr [string length $variant]+1] end]
				} else {
					# Not an option we recognize, so break from port option processing
					incr argn -1
					break
				}
			}
		}
		
		# Resolve the pseudo-portnames
		# all, current, installed, uninstalled, active, inactive, outdated
		switch -- $portname {
			all 			{ add_ports_to_portlist [get_all_ports] [array get portoptions] }
			current			{ add_ports_to_portlist [get_current_port] [array get portoptions] }
			installed		{ add_ports_to_portlist [get_installed_ports] [array get portoptions] }
			uninstalled		{ add_ports_to_portlist [get_uninstalled_ports] [array get portoptions] }
			active			{ add_ports_to_portlist [get_active_ports] [array get portoptions] }
			inactive		{ add_ports_to_portlist [get_inactive_ports] [array get portoptions] }
			outdated		{ add_ports_to_portlist [get_outdated_ports] [array get portoptions] }
			default 		{ add_to_portlist [list "" $portname $portversion [array get portvariants]] [array get portoptions] }
		}
	}
}


# If there's no action, just print the usage and be done
if {![info exists action]} {
	print_usage
	exit 1
}


# Perform the action
switch -- $action {

	info {
		require_portlist
		foreachport $portlist {	
			# search for port
			if {[catch {dportsearch ^$portname$} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}
		
			if {$result == ""} {
				puts "No port $portname found."
			} else {
				set found [expr [llength $result] / 2]
				if {$found > 1} {
					ui_warn "Found $found port $portname definitions, displaying first one."
				}
				array set portinfo [lindex $result 1]
	
				puts -nonewline "$portinfo(name) $portinfo(version)"
				if {[info exists portinfo(revision)] && $portinfo(revision) > 0} { 
					puts -nonewline ", Revision $portinfo(revision)" 
				}
				puts -nonewline ", $portinfo(portdir)" 
				if {[info exists portinfo(variants)]} {
					puts -nonewline " (Variants: "
					for {set i 0} {$i < [llength $portinfo(variants)]} {incr i} {
						if {$i > 0} { puts -nonewline ", " }
						puts -nonewline "[lindex $portinfo(variants) $i]"
					}
					puts -nonewline ")"
				}
				puts ""
				if {[info exists portinfo(homepage)]} { 
					puts "$portinfo(homepage)"
				}
		
				if {[info exists portinfo(long_description)]} {
					puts "\n$portinfo(long_description)\n"
				}
	
				# find build dependencies
				if {[info exists portinfo(depends_build)]} {
					puts -nonewline "Build Dependencies: "
					for {set i 0} {$i < [llength $portinfo(depends_build)]} {incr i} {
						if {$i > 0} { puts -nonewline ", " }
						puts -nonewline "[lindex [split [lindex $portinfo(depends_build) $i] :] end]"
					}
					set nodeps false
					puts ""
				}
		
				# find library dependencies
				if {[info exists portinfo(depends_lib)]} {
					puts -nonewline "Library Dependencies: "
					for {set i 0} {$i < [llength $portinfo(depends_lib)]} {incr i} {
						if {$i > 0} { puts -nonewline ", " }
						puts -nonewline "[lindex [split [lindex $portinfo(depends_lib) $i] :] end]"
					}
					set nodeps false
					puts ""
				}
		
				# find runtime dependencies
				if {[info exists portinfo(depends_run)]} {
					puts -nonewline "Runtime Dependencies: "
					for {set i 0} {$i < [llength $portinfo(depends_run)]} {incr i} {
						if {$i > 0} { puts -nonewline ", " }
						puts -nonewline "[lindex [split [lindex $portinfo(depends_run) $i] :] end]"
					}
					set nodeps false
					puts ""
				}
				if {[info exists portinfo(platforms)]} { puts "Platforms: $portinfo(platforms)"}
				if {[info exists portinfo(maintainers)]} { puts "Maintainers: $portinfo(maintainers)"}
			}
		}
	}
	
	location {
		require_portlist
		foreachport $portlist {
			if { [catch {set ilist [registry_installed $portname [composite_version $portversion [array get variations]]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port location failed: $result"
				exit 1
			} else {
				set version [lindex $ilist 1]
				set revision [lindex $ilist 2]
				set	variants [lindex $ilist 3]
			}
	
			set ref [registry::open_entry $portname $version $revision $variants]
			if { [string equal [registry::property_retrieve $ref installtype] "image"] } {
				set imagedir [registry::property_retrieve $ref imagedir]
				puts "Port $portname ${version}_${revision}${variants} is installed as an image in:"
				puts $imagedir
			} else {
				puts "Port $portname is not installed as an image."
				exit 1
			}
		}
	}
	
	provides {
		# In this case, portname is going to be used for the filename... since
		# that is the first argument we expect... perhaps there is a better way
		# to do this?
		if { ![llength $portlist] } {
			puts "Please specify a filename to check which port provides that file."
			exit 1
		}
		foreachport $portlist {
			set file [compat filenormalize $portname]
			if {[file exists $file]} {
				if {![file isdirectory $file]} {
					set port [registry::file_registered $file] 
					if { $port != 0 } {
						puts "$file is provided by: $port"
					} else {
						puts "$file is not provided by a DarwinPorts port."
					}
				} else {
					puts "$file is a directory."
				}
			} else {
				puts "$file does not exist."
			}
		}
	}
	
	activate {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::activate $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port activate failed: $result"
				exit 1
			}
		}
	}
	
	deactivate {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::deactivate $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port deactivate failed: $result"
				exit 1
			}
		}
	}
	
	selfupdate {
		if { [catch {darwinports::selfupdate} result ] } {
			global errorInfo
			ui_debug "$errorInfo"
			puts "Selfupdate failed: $result"
			exit 1
		}
	}
	
	upgrade {
        if {[info exists options(port_upgrade_all)] } {
            # upgrade all installed ports!!!
            if { [catch {set ilist [registry::installed]} result] } {
                if {$result == "Registry error: No ports registered as installed."} {
                    puts "no ports installed!"
                    exit 1
                } else {
					global errorInfo
					ui_debug "$errorInfo"
                    puts "port installed failed: $result"
                    exit 1
                }
            }
            if { [llength $ilist] > 0 } {
                foreach i $ilist {
                    set iname [lindex $i 0]
                    darwinports::upgrade $iname "port:$iname"
                }
            }
        } else {
        	require_portlist
        	foreachport $portlist {
            	darwinports::upgrade $portname "port:$portname"
            }
        }
    }

	version {
		puts "Version: [darwinports::version]"
	}

	compact {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::compact $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port compact failed: $result"
				exit 1
			}
		}
	}
	
	uncompact {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::uncompact $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port uncompact failed: $result"
				exit 1
			}
		}
	}
	
	uninstall {
		# if -u then uninstall all non-active ports
		if {[info exists options(port_uninstall_old)]} {
			if { [catch {set ilist [registry::installed]} result] } {
                if {$result == "Registry error: No ports registered as installed."} {
                    puts "no ports installed!"
                    exit 1
                } else {
					global errorInfo
					ui_debug "$errorInfo"
                    puts "port installed failed: $result"
					exit 1
                }
            }
			if { [llength ilist] > 0} {
				foreach i $ilist {
					# uninstall inactive port
					if {[lindex $i 4] == 0} {
						set portname "[lindex $i 0]"
						set portversion "[lindex $i 1]_[lindex $i 2][lindex $i 3]"
						ui_debug " uninstalling $portname $portversion"
						if { [catch {portuninstall::uninstall $portname $portversion} result] } {
							global errorInfo
							ui_debug "$errorInfo"
                        	puts "port uninstall failed: $result"
							exit 1
                        }
					}
				}
			}
		} else {
			require_portlist
			foreachport $portlist {
				if { [catch {portuninstall::uninstall $portname [composite_version $portversion [array get variations]]} result] } {
					global errorInfo
					ui_debug "$errorInfo"
					puts "port uninstall failed: $result"
					exit 1
				}
			}
		}
	}
	
	installed {
        if { [llength $portlist] } {
			set ilist [list]
        	foreach portspec $portlist {
        		set portname [lindex $portspec 1]
        		set composite_version [composite_version [lindex $portspec 2] [lindex $portspec 3]]
				if { [catch {set ilist [concat $ilist [registry::installed $portname $composite_version]]} result] } {
					if {![string match "* not registered as installed." $result]} {
						global errorInfo
						ui_debug "$errorInfo"
						fatal "port installed failed: $result"
					}
				}
			}
        } else {
            if { [catch {set ilist [registry::installed]} result] } {
                if {$result == "Registry error: No ports registered as installed."} {
                    fatal "No ports installed!"
                } else {
					global errorInfo
					ui_debug "$errorInfo"
                    fatal "port installed failed: $result"
                }
            }
        }
        if { [llength $ilist] > 0 } {
            puts "The following ports are currently installed:"
            foreach i $ilist {
                set iname [lindex $i 0]
                set iversion [lindex $i 1]
                set irevision [lindex $i 2]
                set ivariants [lindex $i 3]
                set iactive [lindex $i 4]
                if { $iactive == 0 } {
                    puts "  $iname ${iversion}_${irevision}${ivariants}"
                } elseif { $iactive == 1 } {
                    puts "  $iname ${iversion}_${irevision}${ivariants} (active)"
                }
            }
        } else {
            exit 1
        }
    }

	outdated {
		# If port names were supplied, limit ourselves to those port, else check all installed ports
       if { [llength $portlist] } {
			set ilist [list]
        	foreach portspec $portlist {
        		set portname [lindex $portspec 1]
        		set composite_version [composite_version [lindex $portspec 2] [lindex $portspec 3]]
				if { [catch {set ilist [concat $ilist [registry::installed $portname $composite_version]]} result] } {
					if {![string match "* not registered as installed." $result]} {
						global errorInfo
						ui_debug "$errorInfo"
						fatal "port outdated failed: $result"
					}
				}
			}
		} else {
			if { [catch {set ilist [registry::installed]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port outdated failed: $result"
				exit 1
			}
		}
	
		if { [llength $ilist] > 0 } {
			puts "The following installed ports are outdated:"
		
			foreach i $ilist { 

				# Get information about the installed port
				set portname			[lindex $i 0]
				set installed_version	[lindex $i 1]
				set installed_revision	[lindex $i 2]
				set installed_compound	"${installed_version}_${installed_revision}"

				set is_active			[lindex $i 4]
				if { $is_active == 0 } {
					continue
				}
				set installed_epoch		[lindex $i 5]

				# Get info about the port from the index
				# Escape regex special characters
				regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
				if {[catch {set res [dportsearch ^$search_string\$]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					puts "port search failed: $result"
					exit 1
				}
				if {[llength $res] < 2} {
					if {[ui_isset ports_debug]} {
						puts "$portname ($installed_compound is installed; the port was not found in the port index)"
					}
					continue
				}
				array set portinfo [lindex $res 1]
				
				# Get information about latest available version and revision
				set latest_version $portinfo(version)
				set latest_revision		0
				if {[info exists portinfo(revision)] && $portinfo(revision) > 0} { 
					set latest_revision	$portinfo(revision)
				}
				set latest_compound		"${latest_version}_${latest_revision}"
				set latest_epoch		0
				if {[info exists portinfo(epoch)]} { 
					set latest_epoch	$portinfo(epoch)
				}
				
				# Compare versions, first checking epoch, then the compound version string
				set comp_result [expr $installed_epoch - $latest_epoch]
				if { $comp_result == 0 } {
					set comp_result [rpm-vercomp $installed_compound $latest_compound]
				}
				
				# Report outdated (or, for verbose, predated) versions
				if { $comp_result != 0 } {
								
					# Form a relation between the versions
					set flag ""
					if { $comp_result > 0 } {
						set relation ">"
						set flag "!"
					} else {
						set relation "<"
					}
					
					# Emit information
					if {$comp_result < 0 || [ui_isset ports_verbose]} {
						puts [format "%-30s %-24s %1s" $portname "$installed_compound $relation $latest_compound" $flag]
					}
					
				}
			}
		} else {
			exit 1
		}
	}

	contents {
		require_portlist
		foreachport $portlist {
			set files [registry::port_registered $portname]
			if { $files != 0 } {
				if { [llength $files] > 0 } {
					puts "Port $portname contains:"
					foreach file $files {
						puts "  $file"
					}
				} else {
					puts "Port $portname does not contain any file or is not active."
				}
			} else {
				puts "Port $portname is not installed."
			}
		}
	}
	
	deps {
		set nodeps true
		
		require_portlist
		foreachport $portlist {
			# search for port
			if {[catch {dportsearch ^$portname$} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}
	
			if {$result == ""} {
				puts "No port $portname found."
				exit 1
			}
	
			array set portinfo [lindex $result 1]
	
			set depstypes {depends_build depends_lib depends_run}
			set depstypes_descr {"build" "library" "runtime"}
	
			foreach depstype $depstypes depsdecr $depstypes_descr {
				if {[info exists portinfo($depstype)] &&
					$portinfo($depstype) != ""} {
					puts "$portname has $depsdecr dependencies on:"
					foreach i $portinfo($depstype) {
						puts "\t[lindex [split [lindex $i 0] :] end]"
					}
					set nodeps false
				}
			}
			
			# no dependencies found
			if {$nodeps == "true"} {
				puts "$portname has no dependencies"
			}
		}
	}
	
	variants {
		require_portlist
		foreachport $portlist {
			# search for port
			if {[catch {dportsearch ^$portname$} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}
		
			if {$result == ""} {
				puts "No port $portname found."
			}
		
			array set portinfo [lindex $result 1]
		
			# if this fails the port doesn't have any variants
			if {![info exists portinfo(variants)]} {
				puts "$portname has no variants"
			} else {
				# print out all the variants
				puts "$portname has the variants:"
				for {set i 0} {$i < [llength $portinfo(variants)]} {incr i} {
					puts "\t[lindex $portinfo(variants) $i]"
				}
			}
		}
	}
	
	search {
		if {![llength portlist]} {
			puts "You must specify a search pattern"
			exit 1
		}
		
		foreachport $portlist {
			if {[catch {set res [dportsearch $portname "no"]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}
			foreach {name array} $res {
				array set portinfo $array
	
				# XXX is this the right place to verify an entry?
				if {![info exists portinfo(name)]} {
					puts "Invalid port entry, missing portname"
					continue
				}
				if {![info exists portinfo(description)]} {
					puts "Invalid port entry for $portinfo(name), missing description"
					continue
				}
				if {![info exists portinfo(version)]} {
					puts "Invalid port entry for $portinfo(name), missing version"
					continue
				}
				if {![info exists portinfo(portdir)]} {
					set output [format "%-30s %-12s %s" $portinfo(name) $portinfo(version) $portinfo(description)]
				} else {
					set output [format "%-30s %-14s %-12s %s" $portinfo(name) $portinfo(portdir) $portinfo(version) $portinfo(description)]
				}
				set portfound 1
				puts $output
				unset portinfo
			}
			if {![info exists portfound] || $portfound == 0} {
				puts "No match for $portname found"
				exit 1
			}
		}
	}
	
	list {
		# Default to list all ports if no portnames are supplied
		if {![llength portlist]} {
			add_to_portlist [list "" "-all-" "" {}] {}
			exit 1
		}
		
		foreachport $portlist {
			if {$portname == "-all-"} {
				set pat ".+"
			} else {
				regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
			}

			if {[catch {set res [dportsearch ^$search_string\$]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "port search failed: $result"
				exit 1
			}

			foreach {name array} $res {
				array set portinfo $array
				puts [format "%-30s %-12s" $portinfo(name) $portinfo(version)]
			}
		}
	}
	
	echo {
		# Simply echo back the port specs given to this command
		foreachport $portlist {
			set opts [list]
			foreach { key value } [array get options] {
				lappend opts "$key=\"$value\""
			}
			
			puts [format "%-30s %s %s" $portname [composite_version $portversion [array get variations]] [join $opts " "]]
		}
	}
	
	sync {
		if {[catch {dportsync} result]} {
			global errorInfo
			ui_debug "$errorInfo"
			puts "port sync failed: $result"
			exit 1
		}
	}
	
	default {
		require_portlist
		foreachport $portlist {
			set target $action

			# If we have a url, use that, since it's most specific
			# otherwise try to map the portname to a url
			if {$porturl == ""} {
				# Verify the portname, getting portinfo to map to a porturl
				# Escape regex special characters
				regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
				if {[catch {set res [dportsearch ^$search_string\$]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					puts "port search failed: $result"
					exit 1
				}
				if {[llength $res] < 2} {
					puts "Port $portname not found"
					exit 1
				}
				array set portinfo [lindex $res 1]
				set porturl $portinfo(porturl)
			}

			# If version was specified, save it as a version glob for use
			# in port actions (e.g. clean).
			if {[string length $portversion]} {
				set options(ports_version_glob) $portversion
			}
			if {[catch {set workername [dportopen $porturl [array get options] [array get variations]]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "Unable to open port: $result"
				exit 1
			}
			if {[catch {set result [dportexec $workername $target]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				puts "Unable to execute port: $result"
				exit 1
			}
		
			dportclose $workername
			exit $result
		}
	}
}

#!@TCLSH@
# port.tcl
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

catch {source
	[file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports

# globals
set portdir .

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

proc ui_puts {messagelist} {
	set channel stdout
	array set message $messagelist
	switch $message(priority) {
		debug {
			if {[ui_isset ports_debug]} {
				set channel stderr
				set str "DEBUG: $message(data)"
			} else {
				return
			}
		}
		info {
			if {![ui_isset ports_verbose]} {
				return
			}
			set str $message(data)
		}
		msg {
			if {[ui_isset ports_quiet]} {
				return
			}
			set str $message(data)
		}
		error {
			set str "Error: $message(data)"
			set channel stderr
		}
		warn {
			set str "Warning: $message(data)"
		}
	}
	puts $channel $str
}

# Standard procedures
proc print_usage args {
	global argv0
	puts "Usage: [file tail $argv0] \[-vdqfonausbck\] \[-D portdir\] target \[flags\] \[portname\] \[options\] \[variants\]"
}

proc fatal args {
	global argv0
	puts stderr "$argv0: $args"
	exit
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


# Main
set separator 0
array set options [list]
array set variations [list]
for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]

	# if --xyz after the action, but before any portname
	if {[info exists action] && ![info exists portname] \
			&& [regexp {^--([A-Za-z0-9]+)$} $arg match key] == 1} {
		set options(ports_${action}_${key}) yes

	# if -xyz before the separator
	} elseif {$separator == 0 && [regexp {^-([-A-Za-z0-9]+)$} $arg match opt] == 1} {
	if {$opt == "-"} {
		set separator 1
	} else {
		foreach c [split $opt {}] {
			if {$c == "v"} {
				set ui_options(ports_verbose) yes
			} elseif {$c == "f"} {
				set options(ports_force) yes
			} elseif {$c == "d"} {
				set ui_options(ports_debug) yes
				# debug infers verbose
				set ui_options(ports_verbose) yes
			} elseif {$c == "q"} {
				set ui_options(ports_quiet) yes
				set ui_options(ports_verbose) no
				set ui_options(ports_debug) no
			} elseif {$c == "o"} {
				set options(ports_ignore_older) yes
			} elseif {$c == "n"} {
				set options(ports_nodeps) yes
			} elseif {$c == "a"} {
				set options(port_upgrade_all) yes
			} elseif {$c == "u"} {
				set options(port_uninstall_old) yes
			} elseif {$c == "s"} {
				set options(ports_source_only) yes
			} elseif {$c == "b"} {
				set options(ports_binary_only) yes
			} elseif {$c == "c"} {
				set options(ports_autoclean) yes
			} elseif {$c == "k"} {
				set options(ports_autoclean) no
			} elseif {$opt == "D"} {
				incr i
				set porturl "file://[lindex $argv $i]"
			} elseif {$opt == "u"} {
				incr i
				set porturl [lindex $argv $i]
			} else {
				print_usage; exit
			}
		}
	}
	
	# if +xyz -xyz or after the separator
	} elseif {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
		set variations($opt) $sign
	
	# option=value
	} elseif {[regexp {([A-Za-z0-9_\.]+)=(.*)} $arg match key val] == 1} {
		set options($key) \"$val\"
	
	# action
	} elseif {[regexp {^([A-Za-z0-9/._\-^$ \[\[?\(\)\\|\+\*%]+)$} $arg match opt] == 1} {
		if {[info exists action] && ![info exists portname]} {
			set portname $opt
		} elseif { [info exists action] && [info exists portname] } {
			set portversion $opt
		} else {
			set action $opt
		}
	} else {
		print_usage; exit
	}
}

if {![info exists action]} {
	print_usage
	exit
}

if {$action == "list"} {
	set action search
	set portname .+
}

if {[catch {dportinit} result]} {
	puts "Failed to initialize ports system, $result"
	exit 1
}

switch -- $action {
	info {
		if {![info exists portname]} {
			puts "You must specify a port"
			exit 1
		}
	
		# search for port
		if {[catch {dportsearch ^$portname$} result]} {
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

			puts -nonewline "$portname $portinfo(version)"
			if {[info exists portinfo(revision)] && $portinfo(revision) > 0} { 
				puts -nonewline ", Revision $portinfo(revision)" 
			}
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
					puts -nonewline "[lindex [split [lindex $portinfo(depends_build) $i] :] 2]"
				}
				set nodeps false
				puts ""
			}
	
			# find library dependencies
			if {[info exists portinfo(depends_lib)]} {
				puts -nonewline "Library Dependencies: "
				for {set i 0} {$i < [llength $portinfo(depends_lib)]} {incr i} {
					if {$i > 0} { puts -nonewline ", " }
					puts -nonewline "[lindex [split [lindex $portinfo(depends_lib) $i] :] 2]"
				}
				set nodeps false
				puts ""
			}
	
			# find runtime dependencies
			if {[info exists portinfo(depends_run)]} {
				puts -nonewline "Runtime Dependencies: "
				for {set i 0} {$i < [llength $portinfo(depends_run)]} {incr i} {
					if {$i > 0} { puts -nonewline ", " }
					puts -nonewline "[lindex [split [lindex $portinfo(depends_run) $i] :] 2]"
				}
				set nodeps false
				puts ""
			}
			if {[info exists portinfo(platforms)]} { puts "Platforms: $portinfo(platforms)"}
			if {[info exists portinfo(maintainers)]} { puts "Maintainers: $portinfo(maintainers)"}

		}
	}
	location {
		if { ![info exists portname] } {
			puts "To list the image location of an installed port please provide a portname."
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion "" 
		}
	
		if { [catch {set ilist [registry_installed $portname $portversion]} result] } {
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
	provides {
		# In this case, portname is going to be used for the filename... since
		# that is the first argument we expect... perhaps ther eis a better way
		# to do this?
		if { ![info exists portname] } {
			puts "Please specify a filename to check which port provides that file."
			exit 1
		}
		set file $portname
		if { [file exists $file] && ![file isdirectory $file] } {
			set port [registry::file_registered $file] 
			if { $port != 0 } {
				puts "$file is provided by: $port"
			} else {
				puts "$file is not provided by a DarwinPorts port."
			}
		} else {
			puts "$file does not exist or is a directory."
		}
	}
	activate {
		if { ![info exists portname] } {
			puts "Please specify a port to activate."
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion ""
		} 
		if { [catch {portimage::activate $portname $portversion} result] } {
			puts "port activate failed: $result"
			exit 1
		}
	}
	deactivate {
		if { ![info exists portname] } {
			puts "Please specify a port to deactivate."
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion ""
		} 
		if { [catch {portimage::deactivate $portname $portversion} result] } {
			puts "port deactivate failed: $result"
			exit 1
		}
	}
	upgrade {
        if {[info exists options(port_upgrade_all)] } {
            # upgrade all installed ports!!!
            if { [catch {set ilist [registry::installed]} result] } {
                if {$result eq "Registry error: No ports registered as installed."} {
                    puts "no ports installed!"
                    exit 1
                } else {
                    puts "port installed failed: $result"
                    exit 1
                }
            }
            if { [llength $ilist] > 0 } {
                foreach i $ilist {
                    set iname [lindex $i 0]
                    upgrade $iname "lib:XXX:$iname"
                }
            }
        } else {
            # upgrade a specific port
            if { ![info exists portname] } {
                puts "Please specify a port to upgrade."
                exit 1
            }

            upgrade $portname "lib:XXX:$portname"
        }
    }

	compact {
		if { ![info exists portname] } {
			puts "Please specify a port to compact."
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion ""
		} 
		if { [catch {portimage::compact $portname $portversion} result] } {
			puts "port compact failed: $result"
			exit 1
		}
	}
	uncompact {
		if { ![info exists portname] } {
			puts "Please specify a port to compact."
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion ""
		} 
		if { [catch {portimage::uncompact $portname $portversion} result] } {
			puts "port uncompact failed: $result"
			exit 1
		}
	}
	uninstall {
		# if -u then uninstall all non-active ports
		if {[info exists options(port_uninstall_old)]} {
			if { [catch {set ilist [registry::installed]} result] } {
                if {$result eq "Registry error: No ports registered as installed."} {
                    puts "no ports installed!"
                    exit 1
                } else {
                    puts "port installed failed: $result"
					exit 1
                }
            }
			if { [llength ilist] > 0} {
				foreach i $ilist {
					# uninstall inactive port
					if {[lindex $i 4] eq 0} {
						set portname "[lindex $i 0]"
						set portversion "[lindex $i 1]_[lindex $i 2][lindex $i 3]"
						ui_debug " uninstalling $portname $portversion"
						if { [catch {portuninstall::uninstall $portname $portversion} result] } {
                        	puts "port uninstall failed: $result"
							exit 1
                        }
					}
				}
			}
		} else {
			if { ![info exists portname] } {
				puts "Please specify a port to uninstall"
				exit 1
			} elseif { ![info exists portversion] } {
				set portversion ""
			} 
			if { [catch {portuninstall::uninstall $portname $portversion} result] } {
				puts "port uninstall failed: $result"
				exit 1
			}
		}
	}
	installed {
        if { [info exists portname] } {
            if { [catch {set ilist [registry::installed $portname]} result] } {
                if {$result eq "Registry error: $portname not registered as installed."} {
                    puts "Port $portname not installed!"
                    exit 1
                } else {
                    puts "port installed failed: $result"
                    exit 1
                }
            }
        } else {
            if { [catch {set ilist [registry::installed]} result] } {
                if {$result eq "Registry error: No ports registered as installed."} {
                    puts "No ports installed!"
                    exit 1
                } else {
                    puts "port installed failed: $result"
                    exit 1
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
		# If a port name was supplied, limit ourselves to that port, else check all installed ports
		if { [info exists portname] } {
			if { [catch {set ilist [registry::installed $portname]} result] } {
				puts "port outdated failed: $result"
				exit 1
			}
		} else {
			if { [catch {set ilist [registry::installed]} result] } {
				puts "port outdated failed: $result"
				exit 1
			}
		}
	
		if { [llength $ilist] > 0 } {
			puts "The following installed ports seem to be outdated:"
		
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

				# Get info about the port from the index
				# Escape regex special characters
				regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
				if {[catch {set res [dportsearch ^$search_string\$]} result]} {
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
				
				# Compare versions for equality
				set comp_result [rpm-vercomp $installed_compound $latest_compound]
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
					
					# Even more verbose explanation (disabled at present)
					if {false && [ui_isset ports_verbose]} {
						puts "  installed: $installed_compound"
						puts "  latest:    $latest_compound"
						# Warning for ports that are predated
						if { $result > 0 } {
							puts "  (installed version is newer than port index version)"
						}
					}
					
				}
			}
		} else {
			exit 1
		}
	}

	contents {
		# make sure a port was given on the command line
		if {![info exists portname]} {
			puts "Please specify a port"
			exit 1
		} elseif { ![info exists portversion] } {
			set portversion "" 
		}

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
	deps {
		set nodeps true

		# make sure a port was given on the command line
		if {![info exists portname]} {
			puts "You must specify a port"
			exit 1
		}

		# search for port
		if {[catch {dportsearch ^$portname$} result]} {
			puts "port search failed: $result"
			exit 1
		}

		if {$result == ""} {
			puts "No port $portname found."
			exit 1
		}

		array set portinfo [lindex $result 1]

		# find build dependencies
		if {[info exists portinfo(depends_build)]} {
			puts "$portname has build dependencies on:"
			foreach i $portinfo(depends_build) {
				puts "\t[lindex [split [lindex $i 0] :] 2]"
			}
			set nodeps false
		}

		# find library dependencies
		if {[info exists portinfo(depends_lib)]} {
			puts "$portname has library dependencies on:"
			foreach i $portinfo(depends_lib) {
				puts "\t[lindex [split [lindex $i 0] :] 2]"
			}
			set nodeps false
		}

		# find runtime dependencies
		if {[info exists portinfo(depends_run)]} {
			puts "$portname has runtime dependencies on:"
			foreach i $portinfo(depends_run) {
				puts "\t[lindex [split [lindex $i 0] :] 2]"
			}
			set nodeps false
		}

		# no dependencies found
		if {$nodeps == "true"} {
			puts "$portname has no dependencies"
		}
	}
	variants {
		# make sure a port was given on the command line
		if {![info exists portname]} {
			puts "You must specify a port"
			exit 1
		}
	
		# search for port
		if {[catch {dportsearch ^$portname$} result]} {
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
			for {set i 0} {$i < [llength $portinfo(variants)]} {incr i} {
				puts "[lindex $portinfo(variants) $i]"
			}
		}
	}
	search {
		if {![info exists portname]} {
			puts "You must specify a search pattern"
			exit 1
		}
		if {[catch {set res [dportsearch $portname "no"]} result]} {
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
			set output [format "%-20s\t%-8s\t%s" $portinfo(name) $portinfo(version) $portinfo(description)]
		} else {
			set output [format "%-8s\t%-14s\t%-8s\t%s" $portinfo(name) $portinfo(portdir) $portinfo(version) $portinfo(description)]
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
	sync {
		if {[catch {dportsync} result]} {
			puts "port sync failed: $result"
			exit 1
		}
	}
	default {
		set target $action
		if {[info exists portname]} {
			# Escape regex special characters
			regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
			if {[catch {set res [dportsearch ^$search_string\$]} result]} {
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
		if {![info exists porturl]} {
			set porturl file://./
		}
		# If version was specified, save it as a version glob for use
		# in port actions (e.g. clean).
		if {[info exists portversion]} {
			set options(ports_version_glob) $portversion
		}
		if {[catch {set workername [dportopen $porturl [array get options] [array get variations]]} result]} {
			puts "Unable to open port: $result"
			exit 1
		}
		if {[catch {set result [dportexec $workername $target]} result]} {
			puts "Unable to execute port: $result"
			exit 1
		}
	
		dportclose $workername
		exit $result
	}
}

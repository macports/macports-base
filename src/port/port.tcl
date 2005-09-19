#!/bin/sh
#\
exec @TCLSH@ "$0" "$@"
# port.tcl
# $Id: port.tcl,v 1.100 2005/09/19 18:49:36 jberry Exp $
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
#

catch {source \
	[file join "@TCL_PACKAGE_DIR@" darwinports1.0 darwinports_fastload.tcl]}
package require darwinports

# globals
set portdir .
set argn 0
set action ""
set portlist [list]
array set global_options [list]
array set global_variations [list]

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
	set usage { [-vdqfonasbckt] [-D portdir] [-u porturl] action [actionflags]
	[[portname|pseudo-portname|port-url] [version] [+-variant]... [option=value]...]...
	
Valid actions are:
	help, info, location, provides, activate, deactivate, selfupdate,
	upgrade, version, compact, uncompact, uninstall, installed, outdated,
	contents, deps, variants, search, list, echo, sync,
	fetch, patch, extract, build, destroot, install, test
	
Pseudo-portnames:
	Pseudo-portnames are words which may be used in place of a portname, and
	which expand to some set of ports. The common pseudo-ports are:
	all, current, active, inactive, installed, uninstalled, and outdated.
	These pseudo-portnames expand to the set of ports named.
	
	Additional psuedo-portnames are:
	variants:, variant:, description:, portdir:, homepage:, epoch:,
	platforms:, platform:, name:, long_description:, maintainers:,
	maintainer:, categories:, category:, and revision:.
	These each select a set or ports based on a regex search of metadata
	about the ports. In all such cases, a standard regex pattern following
	the colon will be used to select the set of ports to which the
	pseudo-portname expands.
	
	portnames that contain standard glob characters will be expanded to the
	set of ports matching the glob pattern.
	
Port expressions:
	Portnames, port glob patterns, and psuedo-portnames may be logically combined
	using expressions consisting of and, or, not, !, (, and ).
	
	}
	
	puts "Usage: [file tail $argv0]$usage"
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


proc add_to_portlist {listname portentry} {
	upvar $listname portlist
	global global_options global_variations
	
	# The portlist currently has the following elements in it:
	#	url				if any
	#	name
	#	version			(version_revision)
	#	variants array	(variant=>+-)
	#	options array	(key=>value)
	#	fullname		(name/version_revision+-variants)
	
	array set port $portentry
	if {![info exists port(url)]}		{ set port(url) "" }
	if {![info exists port(name)]}		{ set port(name) "" }
	if {![info exists port(version)]}	{ set port(version) "" }
	if {![info exists port(variants)]}	{ set port(variants) "" }
	if {![info exists port(options)]}	{ set port(options) [array get global_options] }
		
	# Form the fully descriminated portname: portname/version_revison+-variants
	set port(fullname) "$port(name)/[composite_version $port(version) $port(variants)]"
	
	# Add it to our portlist
	lappend portlist [array get port]
}


proc add_ports_to_portlist {listname ports {overridelist ""}} {
	upvar $listname portlist
	
	array set overrides $overridelist
	
	# Add each entry to the named portlist, overriding any values
	# specified as overrides
	foreach portentry $ports {
		array set port $portentry
		if ([info exists overrides(version)])	{ set port(version) $overrides(version)	}
		if ([info exists overrides(variants)])	{ set port(variants) $overrides(variants)	}
		if ([info exists overrides(options)])	{ set port(options) $overrides(options)	}
		add_to_portlist portlist [array get port]
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
	upvar portlist portlist
	global global_porturl
	
	if {[llength $portlist] == 0} {
		if {[info exists global_porturl]} {
			set url $global_porturl
		} else {
			set url file://./
		}
		set portname [url_to_portname $url]
	
		if {$portname != ""} {
			add_to_portlist portlist [list url $url name $portname]
		} else {
			fatal "You must specify a port or be in a port directory"
		}
	}
}


# Execute the enclosed block once for every element in the portlist
# When the block is entered, the variables portname, portversion, options, and variations
# will have been set
proc foreachport {portlist block} {
	foreach portspec $portlist {
		array set port $portspec
		uplevel 1 "
			set porturl \"$port(url)\"
			set portname \"$port(name)\"
			set portversion \"$port(version)\"
			array unset variations
			array set variations { $port(variants) }
			array unset options
			array set options { $port(options) }
			$block
			"
	}
}


proc portlist_compare { a b } {
	array set a_ $a
	array set b_ $b
	return [string compare $a_(name) $b_(name)]
}


proc portlist_sort list {
	return [lsort -command portlist_compare $list]
}


proc regex_pat_sanitize s {
	set sanitized [regsub -all {[\\(){}+$.^]} $s {\\&}]
	return $sanitized
}


##########################################
# Port selection
##########################################
proc get_matching_ports {pattern {casesensitive no} {matchstyle glob} {field name}} {
	if {[catch {set res [dportsearch $pattern $casesensitive $matchstyle $field]} result]} {
		global errorInfo
		ui_debug "$errorInfo"
		fatal "search for portname $pattern failed: $result"
	}

	set results [list]
	foreach {name info} $res {
		array set portinfo $info
		
		#set variants {}
		#if {[info exists portinfo(variants)]} {
		#	foreach variant $portinfo(variants) {
		#		lappend variants $variant "+"
		#	}
		#}
		# For now, don't include version or variants with all ports list
		#"$portinfo(version)_$portinfo(revision)"
		#$variants
		add_to_portlist results [list url $portinfo(porturl) name $name]
	}
	
	# Return the list of all ports, sorted
	return [portlist_sort $results]
}


proc get_all_ports {} {
	global all_ports_cache
	
	if {![info exists all_ports_cache]} {
		set all_ports_cache [get_matching_ports "*"]
	}
	return $all_ports_cache
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
	
	set results [list]
	add_to_portlist results [list url $url name $portname]
	return $results
}


proc get_installed_ports { {ignore_active yes} {active yes} } {
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
		
		if { ${ignore_active} == "yes" || (${active} == "yes") == (${iactive} != 0) } {
			add_to_portlist results [list name $iname version "${iversion}_${irevision}" variants $ivariants]
		}
	}
	
	# Return the list of ports, sorted
	return [portlist_sort $results]
}


proc get_uninstalled_ports {} {
	# Return all - installed
	set all [get_all_ports]
	set installed [get_installed_ports]
	return [opComplement $all $installed]
}


proc get_active_ports {} {
	return [get_installed_ports no yes]
}


proc get_inactive_ports {} {
	return [get_installed_ports no no]
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
			if {[catch {set res [dportsearch $portname no exact]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $portname failed: $result"
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
				add_to_portlist results [list name $portname version $installed_compound variants [split_variants $installed_variants]]
			}
		}
	}

	return $results
}



##########################################
# Port expressions
##########################################
proc moreargs {} {
	global argn argc
	return [expr {$argn < $argc}]
}

proc lookahead {} {
	global argn argc argv
	if {$argn < $argc} {
		return [lindex $argv $argn]
	} else {
		return _EOF_
	}
}


proc advance {} {
	global argn
	incr argn
}


proc match s {
	if {[lookahead] == $s} {
		advance
		return 1
	}
	return 0
}


proc portExpr resname {
	upvar $resname reslist
	set result [seqExpr reslist]
	return $result
}


proc seqExpr resname {
	upvar $resname reslist
	
	# Evaluate a sequence of expressions a b c...
	# These act the same as a or b or c

	set result 1
	while {$result} {
		switch -- [lookahead] {
			)		-
			_EOF_	{ break }
		}
		
		set blist [list]
		set result [orExpr blist]
		if {$result} {
			# Calculate the union of result and b
			set reslist [opUnion $reslist $blist]
		}
	}
	
	return $result
}


proc orExpr resname {
	upvar $resname reslist
	
	set a [andExpr reslist]
	while ($a) {
		switch -- [lookahead] {
			or {
					advance
					set blist [list]
					if {![andExpr blist]} {
						return 0
					}
						
					# Calculate a union b
					set reslist [opUnion $reslist $blist]
				}
			default {
					return $a
				}
		}
	}
	
	return $a
}


proc andExpr resname {
	upvar $resname reslist
	
	set a [unaryExpr reslist]
	while {$a} {
		switch -- [lookahead] {
			and {
					advance
					
					set blist [list]
					set b [unaryExpr blist]
					if {!$b} {
						return 0
					}
					
					# Calculate a intersect b
					set reslist [opIntersection $reslist $blist]
				}
			default {
					return $a
				}
		}
	}
	
	return $a
}


proc unaryExpr resname {
	upvar $resname reslist
	set result 0

	switch -- [lookahead] {
		!	-
		not	{
				advance
				set blist [list]
				set result [unaryExpr blist]
				if {$result} {
					set all [get_all_ports]
					set reslist [opComplement $all $blist]
				}
			}
		default {
				set result [element reslist]
			}
	}
	
	return $result
}


proc element resname {
	upvar $resname reslist
	set el 0
	
	set version ""
	array unset variants
	array unset options
	
	set token [lookahead]
	switch -regex -- $token {
		^\\)$			-
		^_EOF_$			{}
		
		^\\($			{
							advance
							set el [portExpr reslist]
							if {!$el || ![match ")"]} {
								set el 0
							}
						}
			
		^all$ 			-
		^installed$		-
		^uninstalled$	-
		^active$		-
		^inactive$		-
		^outdated$		{	advance; add_multiple_ports reslist [get_${token}_ports];	set el 1 }
		^current$		{	advance; add_multiple_ports reslist [get_current_port];		set el 1 }
		
		^variants:		-
		^variant:		-
		^description:	-
		^portdir:		-
		^homepage:		-
		^epoch:			-
		^platforms:		-
		^platform:		-
		^name:			-
		^long_description:	-
		^maintainers:	-
		^maintainer:	-
		^categories:	-
		^category:		-
		^revision:		{	# Handle special port selectors
							advance
							
							# Break up the token, because older Tcl switch doesn't support -matchvar
							regexp {^(\w+):(.*)} $token matchvar field pat
							
							# Remap friendly names to actual names
							switch -- $field {
								variant		-
								platform	-
								maintainer	{ set field "${field}s" }
								category	{ set field "categories" }
							}							
							add_multiple_ports reslist [get_matching_ports $pat no regexp $field]
							set el 1
						}
						
		[][?*]			{	# Handle portname glob patterns
							advance; add_multiple_ports reslist [get_matching_ports $token no glob]
							set el 1
						}
						
		^\\w+:.+		{	# Handle a url by trying to open it as a port and mapping the name
							advance
							set actualname [url_to_portname $token]
							if {$actualname != ""} {
								parsePortSpec version variants options
								add_to_portlist reslist [list url $token \
															actualname $token\
															version $version \
															variants [array get variants] \
															options [array get options]]
							} else {
								fatal "Can't open url '$token' as a port"
							}
							set el 1
						}
		
		default			{
							advance
							parsePortSpec version variants options
							add_to_portlist reslist [list name $token \
														version $version \
														variants [array get variants] \
														options [array get options]]
							set el 1
						}
	}
	
	return $el
}


proc add_multiple_ports { resname ports } {
	upvar $resname reslist
	
	set version ""
	array unset variants
	array unset options
	parsePortSpec version variants options
	
	array unset overrides
	if {$version != ""}			{ set overrides(version) $version }
	if {[array size variants]}	{ set overrides(variants) [array get variants] }
	if {[array size options]}	{ set overrides(options) [array get options] }

	add_ports_to_portlist reslist $ports [array get overrides]
}


proc opUnion { a b } {
	set result [list]
	
	array unset onetime
	
	# Walk through each array, adding to result only those items that haven't
	# been added before
	foreach item $a {
		array set port $item
		if {[info exists onetime($port(fullname))]} continue
		lappend result $item
	}

	foreach item $b {
		array set port $item
		if {[info exists onetime($port(fullname))]} continue
		lappend result $item
	}
	
	return $result
}


proc opIntersection { a b } {
	set result [list]
	
	# Rules we follow in performing the intersection of two port lists:
	#
	#	a/, a/			==> a/
	#	a/, b/			==>
	#	a/, a/1.0		==> a/1.0
	#	a/1.0, a/		==> a/1.0
	#	a/1.0, a/2.0	==>
	#
	#	If there's an exact match, we take it.
	#	If there's a match between simple and descriminated, we take the later.
	
	# First create a list of the fully descriminated names in b
	array unset bfull
	set i 0
	foreach bitem $b {
		array set port $bitem
		set bfull($port(fullname)) $i
		incr i
	}
	
	# Walk through each item in a, matching against b
	#
	# Note: -regexp may not be present in all versions of Tcl we need to work
	# 		against, in which case we may have to fall back to a slower alternative
	#		for those cases. I'm not worrying about that for now, however. -jdb
	foreach aitem $a {
		array set port $aitem
		
		# Quote the fullname and portname to avoid special characters messing up the regexp
		set safefullname [regex_pat_sanitize $port(fullname)]
		
		set simpleform [expr { "$port(name)/" == $port(fullname) }]
		if {$simpleform} {
			set pat "^${safefullname}"
		} else {
			set safename [regex_pat_sanitize $port(name)]
			set pat "^${safefullname}$|^${safename}/$"
		}
		
		set matches [array names bfull -regexp $pat]
		foreach match $matches {
			if {$simpleform} {
				set i $bfull($match)
				lappend result [lindex $b $i]
			} else {
				lappend result $aitem
			}
		}
	}
	
	return $result
}


proc opComplement { a b } {
	set result [list]
	
	# Return all elements of a not matching elements in b
	
	# First create a list of the fully descriminated names in b
	array unset bfull
	set i 0
	foreach bitem $b {
		array set port $bitem
		set bfull($port(fullname)) $i
		incr i
	}
	
	# Walk through each item in a, taking all those items that don't match b
	#
	# Note: -regexp may not be present in all versions of Tcl we need to work
	# 		against, in which case we may have to fall back to a slower alternative
	#		for those cases. I'm not worrying about that for now, however. -jdb
	foreach aitem $a {
		array set port $aitem
		
		# Quote the fullname and portname to avoid special characters messing up the regexp
		set safefullname [regex_pat_sanitize $port(fullname)]
		
		set simpleform [expr { "$port(name)/" == $port(fullname) }]
		if {$simpleform} {
			set pat "^${safefullname}"
		} else {
			set safename [regex_pat_sanitize $port(name)]
			set pat "^${safefullname}$|^${safename}/$"
		}
		
		set matches [array names bfull -regexp $pat]

		# We copy this element to result only if it didn't match against b
		if {![llength $matches]} {
			lappend result $aitem
		}
	}
	
	return $result
}


proc parsePortSpec { vername varname optname } {
	upvar $vername portversion
	upvar $varname portvariants
	upvar $optname portoptions
	
	global global_options
	
	set portversion	""
	array unset portoptions
	array set portoptions [array get global_options]
	array unset portvariants
	
	# Parse port version/variants/options
	set opt [lookahead]
	for {set firstTime 1} {$opt != "" || [moreargs]} {set firstTime 0} {
		# Refresh opt as needed
		if {[string length $opt] == 0} {
			advance
			set opt [lookahead]
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
				break
			}
		}
	}
}



##########################################
# Main
##########################################

# Parse global options
while {[moreargs]} {
	set arg [lookahead]
	
	if {[string index $arg 0] != "-"} {
		break
	} elseif {[string index $arg 1] == "-"} {
		# Process long args -- we don't support any for now
		print_usage; exit 1
	} else {
		# Process short arg(s)
		set opts [string range $arg 1 end]
		foreach c [split $opts {}] {
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
				D { advance
					set global_porturl "file://[lookahead]"
				  }
				u { advance
					set global_porturl [lookahead]
				  }
				default {
					print_usage; exit 1
				  }
			}
		}
	}
	
	advance
}

# Initialize dport
# This must be done following parse of global options, as these are
# evaluated by dportinit.
if {[catch {dportinit ui_options global_options global_variations} result]} {
	global errorInfo
	puts "$errorInfo"
	fatal "Failed to initialize ports system, $result"
}

# Process an action if there is one
if {[moreargs]} {
	set action [lookahead]
	advance
	
	# Parse action options
	while {[moreargs]} {
		set arg [lookahead]
		
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
		
		advance
	}
	
	if {![portExpr portlist]} {
		fatal "Improper expression syntax while processing parameters"
	}
}

# If there's no action, just print the usage and be done
if {$action == ""} {
	print_usage
	exit 1
}

# Perform the action
switch -- $action {

	help {
		print_usage
	}

	info {
		require_portlist
		foreachport $portlist {	
			# Get information about the named port
			if {[catch {dportsearch $portname no exact} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $portname failed: $result"
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
				fatal "port location failed: $result"
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
				fatal "Port $portname is not installed as an image."
			}
		}
	}
	
	provides {
		# In this case, portname is going to be used for the filename... since
		# that is the first argument we expect... perhaps there is a better way
		# to do this?
		if { ![llength $portlist] } {
			fatal "Please specify a filename to check which port provides that file."
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
				fatal "port activate failed: $result"
			}
		}
	}
	
	deactivate {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::deactivate $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "port deactivate failed: $result"
			}
		}
	}
	
	selfupdate {
		if { [catch {darwinports::selfupdate $global_options} result ] } {
			global errorInfo
			ui_debug "$errorInfo"
			fatal "selfupdate failed: $result"
		}
	}
	
	upgrade {
        if {[info exists global_options(port_upgrade_all)] } {
			# if -a then upgrade all installed ports
			# (union these to any other ports user has in the port list)
			set portlist [opUnion $portlist [get_installed_ports]]
        } else {
        	# Otherwise if the user has supplied no ports we'll use the current port
			require_portlist
        }
                
		foreachport $portlist {
			# Merge global variations into the variations specified for this port
			foreach { variation value } [array get global_variations] {
				if { ![info exists variations($variation)] } {
					set variations($variation) $value
				}
			}
			
			darwinports::upgrade $portname "port:$portname" [array get variations] [array get options]
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
				fatal "port compact failed: $result"
			}
		}
	}
	
	uncompact {
		require_portlist
		foreachport $portlist {
			if { [catch {portimage::uncompact $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "port uncompact failed: $result"
			}
		}
	}
	
	uninstall {
		if {[info exists global_options(port_uninstall_old)]} {
			# if -u then uninstall all inactive ports
			# (union these to any other ports user has in the port list)
			set portlist [opUnion $portlist [get_inactive_ports]]
		} else {
			# Otherwise the user had better have supplied a portlist, or we'll default to the existing directory
			require_portlist
		}

		foreachport $portlist {
			if { [catch {portuninstall::uninstall $portname [composite_version $portversion [array get variations]]} result] } {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "port uninstall failed: $result"
			}
		}
	}
	
	installed {
        if { [llength $portlist] } {
			set ilist [list]
        	foreach portspec $portlist {
        		array set port $portspec
        		set portname $port(name)
        		set composite_version [composite_version $port(version) $port(variants)]
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
        		array set port $portspec
        		set portname $port(name)
        		set composite_version [composite_version $port(version) $port(variants)]
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
				fatal "port outdated failed: $result"
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
				if {[catch {set res [dportsearch $portname no exact]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					fatal "search for portname $portname failed: $result"
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
		require_portlist
		foreachport $portlist {
			# Get info about the port
			if {[catch {dportsearch $portname no exact} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $portname failed: $result"
			}
	
			if {$result == ""} {
				fatal "No port $portname found."
			}
	
			array set portinfo [lindex $result 1]
	
			set depstypes {depends_build depends_lib depends_run}
			set depstypes_descr {"build" "library" "runtime"}
	
			set nodeps true
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
			if {[catch {dportsearch $portname no exact} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $portname failed: $result"
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
			fatal "You must specify a search pattern"
		}
		
		foreachport $portlist {
			if {[catch {set res [dportsearch $portname no]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $portname failed: $result"
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
				fatal "No match for $portname found"
			}
		}
	}
	
	list {
		# Default to list all ports if no portnames are supplied
		if {![llength $portlist]} {
			add_to_portlist portlist [list name "-all-"]
		}
		
		foreachport $portlist {
			if {$portname == "-all-"} {
				set search_string ".+"
			} else {
				set search_string [regex_pat_sanitize $portname]
			}
			
			if {[catch {set res [dportsearch ^$search_string\$ no]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "search for portname $search_string failed: $result"
			}

			foreach {name array} $res {
				array set portinfo $array
				set outdir ""
				if {[info exists portinfo(portdir)]} {
					set outdir $portinfo(portdir)
				}
				puts [format "%-30s %-14s %s" $portinfo(name) $portinfo(version) $outdir]
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
			fatal "port sync failed: $result"
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
				if {[catch {set res [dportsearch $portname no exact]} result]} {
					global errorInfo
					ui_debug "$errorInfo"
					fatal "search for portname $portname failed: $result"
				}
				if {[llength $res] < 2} {
					fatal "Port $portname not found"
				}
				array set portinfo [lindex $res 1]
				set porturl $portinfo(porturl)
			}
			
			# If this is the install target, add any global_variations to the variations
			# specified for the port
			if { $target == "install" } {
				foreach { variation value } [array get global_variations] {
					if { ![info exists variations($variation)] } {
						set variations($variation) $value
					}
				}
			}

			# If version was specified, save it as a version glob for use
			# in port actions (e.g. clean).
			if {[string length $portversion]} {
				set options(ports_version_glob) $portversion
			}
			if {[catch {set workername [dportopen $porturl [array get options] [array get variations]]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "Unable to open port: $result"
			}
			if {[catch {set result [dportexec $workername $target]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				fatal "Unable to execute port: $result"
			}
		
			dportclose $workername
			exit $result
		}
	}
}



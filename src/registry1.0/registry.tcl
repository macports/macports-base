# registry.tcl
#
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
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

package provide registry 1.0

package require darwinports 1.0
package require receipt_flat 1.0
package require receipt_sqlite 1.0
package require portimage 1.0
package require portuninstall 1.0
package require msgcat

namespace eval registry {

# Check to see if an entry exists in the registry.  This is passed straight 
# through to the receipts system
proc entry_exists {name version {revision 0} {variants ""}} {
	if { [catch {set res [system "rpm -q $name-$version-$revision"]} ] == 1 } {
		return 0
	} else {
		return 1
	}
}

# Open a registry entry.
proc open_entry {name {version 0} {revision 0} {variants ""}} {
	global darwinports::registry.format

	return [${darwinports::registry.format}::open_entry $name $version $revision $variants]

}

# Store a property with the open registry entry.
proc property_store {ref property value} {
	global darwinports::registry.format
	${darwinports::registry.format}::property_store $ref $property $value
}

# Retrieve a property from the open registry entry.
proc property_retrieve {ref property} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::property_retrieve $ref $property]
}

# If only one version of the port is installed, this process returns that
# version's parts.  Otherwise, it lists the versions installed and exists.
proc installed {{name ""} {version ""}} {

	set ilist [split [exec rpm "-qa" "$name"]]
	set rlist [list]

	if {$ilist == {} } {
		return -code error "Registry error: No such installation"
	}

	if { [llength $ilist] > 1 } {
		foreach installed $ilist {
			set inslst [split $installed -]
			set iname [lindex $inslst 0]
			set iversion [lindex $inslst 1]
			set irevision [lindex $inslst 2]
			set ivariants ""
			set iref ""
			set iactive	""
			set iepoch ""
			lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
		}
	} else {
		set installed [split $ilist -]
		set iname [lindex $installed 0]
		set iversion [lindex $installed 1]
		set irevision [lindex $installed 2]
		set ivariants ""
		set iref ""
		set iactive	""
		set iepoch ""
		lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
	}
	return $rlist
}

# Return a list with the active version of a port (or the active versions of
# all ports if name is "").
proc active {{name ""}} {
	global darwinports::registry.format

	set ilist [${darwinports::registry.format}::installed $name]
	set rlist [list]

	if { [llength $ilist] > 0 } {
		foreach installed $ilist {
			set iname [lindex $installed 0]
			set iversion [lindex $installed 1]
			set irevision [lindex $installed 2]
			set ivariants [lindex $installed 3]
			set iref [open_entry $iname $iversion $irevision $ivariants]
			set iactive	[property_retrieve $iref active]
			set iepoch [property_retrieve $iref epoch]
			if {$iactive} {
				lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
			}
		}
	}
	
	if { [llength $rlist] < 1 } {
		if { $name == "" } {
			return -code error "Registry error: No ports registered as active."
		} else {
			return -code error "Registry error: $name not registered as installed & active."
		}
	}
	return $rlist
}

proc location {portname portversion} {
	set ilist [registry::installed $portname $portversion]

	if { [llength $ilist] > 1 } {
		puts "The following versions of $portname are currently installed:"
		foreach i $ilist { 
			set iname [lindex $i 0]
			set iversion [lindex $i 1]
			set irevision [lindex $i 2]
			set ivariants [lindex $i 3]
			ui_msg "	$iname ${iversion}_${irevision}${ivariants}"
		}
		return -1
	} else {
		return [lindex $ilist 0]
	}
}	

proc file_registered {file} {
	if { [catch {set res [exec "rpm" "-qf" "$file"]}] } {
		return 0
	} else {
		return $res
	}
}

proc port_registered {name} {
	set res [exec "rpm" "-q" "--filesbypkg" "$name"]
	set rlist [list]
	foreach l $res {
		if {$l != $name} {
			lappend rlist $l
		}
	}
	return $rlist
}

# Dependency Map Code
proc register_dependencies {deps name} {

	open_dep_map
	foreach dep $deps {
		# We expect the form type:regexp:port to come in, but we don't need to 
		# store it that way in the dep map.
		set type [lindex [split $dep :] 0]
		set depport [lindex [split $dep :] end]
		register_dep $depport $type $name
	}
	write_dep_map
}

proc unregister_dependencies {name} {

	open_dep_map
	foreach dep [list_depends $name] {
		unregister_dep [lindex $dep 0] [lindex $dep 1] [lindex $dep 2]
	}
	write_dep_map
}

proc open_dep_map {args} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::open_dep_map $args]
}

##
#
# From a file name, return a list representing data currently known about the file.
# This list is a 6-tuple of the form:
# 0: file path
# 1: uid
# 2: gid
# 3: mode
# 4: size
# 5: md5 checksum information
#
# fname		a path to a given file.
# return a 6-tuple about this file.
proc fileinfo_for_file {fname} {
    # Add the link to the registry, not the actual file.
    # (we won't store the md5 of the target of links since it's meaningless
    # and $statvar(mode) tells us that links are links).
    if {![catch {file lstat $fname statvar}]} {
	if {[file isfile $fname] && [file type $fname] != "link"} {
	    if {[catch {md5 file $fname} md5sum] == 0} {
		# Create a line that matches md5(1)'s output
		# for backwards compatibility
		set line "MD5 ($fname) = $md5sum"
		return [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) $line]
	    }
	} else {
	    return  [list $fname $statvar(uid) $statvar(gid) $statvar(mode) $statvar(size) "MD5 ($fname) NONE"]
	}
    }
    return {}
}

##
#
# From a list of files, return a list of information concerning these files.
# The information is obtained through fileinfo_for_file.
#
# flist		the list of file to get information about.
# return a list of 6-tuples described in fileinfo_for_file.
proc fileinfo_for_index {flist} {
	global prefix

	set rval [list]
	foreach file $flist {
		if {[string index $file 0] != "/"} {
			set file [file join $prefix $file]
		}
		lappend rval [fileinfo_for_file $file]
	}
	return $rval
}

# List all ports this one depends on
proc list_depends {name} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::list_depends $name]
}

# List all the ports that depend on this port
proc list_dependents {name} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::list_dependents $name]
}

proc register_dep {dep type port} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::register_dep $dep $type $port]
}

proc unregister_dep {dep type port} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::unregister_dep $dep $type $port]
}

proc write_dep_map {args} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::write_dep_map $args]
}


# End of registry namespace
}


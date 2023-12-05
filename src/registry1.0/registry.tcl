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

package require macports 1.0
package require receipt_flat 1.0
package require receipt_sqlite 1.0
package require portimage 1.0
package require portuninstall 1.0
package require msgcat

namespace eval registry {

# Begin creating a new registry entry for the port version_revision+variant
# This process assembles the directory name and creates a receipt dlist
proc new_entry {name version {revision 0} {variants ""} {epoch 0} } {
	global macports::registry.path macports::registry.format macports::registry.installtype macports::prefix

	
	# Make sure we don't already have an entry in the Registry for this
	# port version_revision+variants
	if {![entry_exists $name $version $revision $variants] } {

		set ref [${macports::registry.format}::new_entry]

		property_store $ref name $name
		property_store $ref version $version
		property_store $ref revision $revision
		property_store $ref variants $variants
		property_store $ref epoch $epoch
		# Trick to have a portable GMT-POSIX epoch-based time.
		# (because we'll compare this with a file mtime).
		property_store $ref date [expr [clock scan now -gmt true] - [clock scan "1970-1-1 00:00:00" -gmt true]]
		property_store $ref installtype ${macports::registry.installtype}
		property_store $ref receipt_f ${macports::registry.format}
		if { ${macports::registry.installtype} == "image" } {
			set imagedir [file join ${macports::registry.path} software ${name} ${version}_${revision}${variants}]
			property_store $ref imagedir $imagedir
			property_store $ref active 0
		}

		return $ref
	} else {
		return -code error "Registry error: ${name} @${version}_${revision}${variants} already registered as installed.  Please uninstall it first."
	}
}

# Check to see if an entry exists in the registry.  This is passed straight 
# through to the receipts system
proc entry_exists {name version {revision 0} {variants ""}} {
	global macports::registry.format
	return [${macports::registry.format}::entry_exists $name $version $revision $variants] 
}

# Check to see if any entry exists in the registry for the given port name.
proc entry_exists_for_name {name} {
	global macports::registry.format
	return [${macports::registry.format}::entry_exists_for_name $name]
}

# Close the registry... basically wrap the receipts systems's write process
proc write_entry {ref} {
	global macports::registry.format
	
	set name [property_retrieve $ref name]
	set version [property_retrieve $ref version]
	set revision [property_retrieve $ref revision]
	set variants [property_retrieve $ref variants]
	set epoch [property_retrieve $ref epoch]
	set contents [property_retrieve $ref contents]

	${macports::registry.format}::write_entry $ref $name $version $revision $variants

}

# Delete an entry from the registry.
proc delete_entry {ref} {
	global macports::registry.format
	
	set name [property_retrieve $ref name]
	set version [property_retrieve $ref version]
	set revision [property_retrieve $ref revision]
	set variants [property_retrieve $ref variants]
	
	${macports::registry.format}::delete_entry $name $version $revision $variants
	
}

# Open a registry entry.
proc open_entry {name {version ""} {revision 0} {variants ""}} {
	global macports::registry.format

	return [${macports::registry.format}::open_entry $name $version $revision $variants]

}

# Store a property with the open registry entry.
proc property_store {ref property value} {
	global macports::registry.format
	${macports::registry.format}::property_store $ref $property $value
}

# Retrieve a property from the open registry entry.
proc property_retrieve {ref property} {
	global macports::registry.format
	return [${macports::registry.format}::property_retrieve $ref $property]
}

# If only one version of the port is installed, this process returns that
# version's parts.  Otherwise, it lists the versions installed and exists.
proc installed {{name ""} {version ""}} {
	global macports::registry.format

	set ilist [${macports::registry.format}::installed $name $version]
	set rlist [list]

	if { [llength $ilist] > 1 } {
		foreach installed $ilist {
			set iname [lindex $installed 0]
			set iversion [lindex $installed 1]
			set irevision [lindex $installed 2]
			set ivariants [lindex $installed 3]
			set iref [open_entry $iname $iversion $irevision $ivariants]
			set iactive	[property_retrieve $iref active]
			set iepoch [property_retrieve $iref epoch]
			lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
		}
	} elseif { [llength $ilist] < 1 } {
		if { $name == "" } {
			return -code error "Registry error: No ports registered as installed."
		} else {
			if { $version == "" } {
				return -code error "Registry error: $name not registered as installed."
			} else {
				return -code error "Registry error: $name $version not registered as installed."
			}
		}
	} else {
		set iname [lindex [lindex $ilist 0] 0]
		set iversion [lindex [lindex $ilist 0] 1]
		set irevision [lindex [lindex $ilist 0] 2]
		set ivariants [lindex [lindex $ilist 0] 3]
		set iref [open_entry $iname $iversion $irevision $ivariants]
		set iactive	[property_retrieve $iref active]
		set iepoch [property_retrieve $iref epoch]
		lappend rlist [list $iname $iversion $irevision $ivariants $iactive $iepoch]
	}
	return $rlist
}

# Return a list with the active version of a port (or the active versions of
# all ports if name is "").
proc active {{name ""}} {
	global macports::registry.format

	set ilist [${macports::registry.format}::installed $name]
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
			set iactive [lindex $i 4]
			if { $iactive == 0 } {
				puts "	$iname @${iversion}_${irevision}${ivariants}"
			} elseif { $iactive == 1 } {
				puts "	$iname @${iversion}_${irevision}${ivariants} (active)"
			}
		}
		return -1
	} else {
		return [lindex $ilist 0]
	}
}	


# File Map Code
proc open_file_map {args} {
	global macports::registry.format
	return [${macports::registry.format}::open_file_map $args]
}

proc file_registered {file} {
	global macports::registry.format
	return [${macports::registry.format}::file_registered $file]
}

proc port_registered {name} {
	global macports::registry.format
	return [${macports::registry.format}::port_registered $name]
}

proc register_file {file port} {
	global macports::registry.format
	return [${macports::registry.format}::register_file $file $port]
}

proc register_bulk_files {files port} {
	global macports::registry.format
	open_file_map
        set r [${macports::registry.format}::register_bulk_files $files $port]
	write_file_map
	close_file_map
	return $r
}

proc unregister_file {file} {
	global macports::registry.format
	return [${macports::registry.format}::unregister_file $file]
}

proc write_file_map {args} {
	global macports::registry.format
	return [${macports::registry.format}::write_file_map $args]
}

proc close_file_map {args} {
	global macports::registry.format
	return [${macports::registry.format}::close_file_map $args]
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
	global macports::registry.format
	return [${macports::registry.format}::open_dep_map $args]
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
	global macports::registry.format
	return [${macports::registry.format}::list_depends $name]
}

# List all the ports that depend on this port
proc list_dependents {name} {
	global macports::registry.format
	return [${macports::registry.format}::list_dependents $name]
}

proc register_dep {dep type port} {
	global macports::registry.format
	return [${macports::registry.format}::register_dep $dep $type $port]
}

proc unregister_dep {dep type port} {
	global macports::registry.format
	return [${macports::registry.format}::unregister_dep $dep $type $port]
}

proc clean_dep_map {args} {
    global macports::registry.format
    return [${macports::registry.format}::clean_dep_map $args]
}

proc write_dep_map {args} {
	global macports::registry.format
	return [${macports::registry.format}::write_dep_map $args]
}


# End of registry namespace
}


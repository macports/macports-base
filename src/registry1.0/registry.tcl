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

# Begin creating a new registry entry for the port version_revision+variant
# This process assembles the directory name and creates a receipt dlist
proc new_entry {name version {revision 0} {variants ""}} {
	global darwinports::registry.path darwinports::registry.format darwinports::registry.installtype darwinports::prefix

	
	# Make sure we don't already have an entry in the Registry for this
	# port version_revision+variants
	if {![entry_exists $name $version $revision $variants] } {

		set ref [${darwinports::registry.format}::new_entry]

		property_store $ref name $name
		property_store $ref version $version
		property_store $ref revision $revision
		property_store $ref variants $variants
		property_store $ref installtype ${darwinports::registry.installtype}
		property_store $ref receipt_f ${darwinports::registry.format}
		if { ${darwinports::registry.installtype} == "image" } {
			set imagedir [file join ${darwinports::registry.path} software ${name} ${version}_${revision}${variants}]
			property_store $ref imagedir $imagedir
			property_store $ref active 0
			property_store $ref compact 0
		}

		return $ref
	} else {
		return -code error "Registry error: ${name} ${version}_${revision}${variants} already registered as installed.  Please uninstall it first."
	}
}

# Check to see if an entry exists in the registry.  This is passed straight 
# through to the receipts system
proc entry_exists {name version {revision 0} {variants ""}} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::entry_exists $name $version $revision $variants] 
}

# Close the registry... basically wrap the receipts systems's write process
proc write_entry {ref} {
	global darwinports::registry.format
	
	set name [property_retrieve $ref name]
	set version [property_retrieve $ref version]
	set revision [property_retrieve $ref revision]
	set variants [property_retrieve $ref variants]
	set contents [property_retrieve $ref contents]

	${darwinports::registry.format}::write_entry $ref $name $version $revision $variants

}

# Delete an entry from the registry.
proc delete_entry {ref} {
	global darwinports::registry.format
	
	set name [property_retrieve $ref name]
	set version [property_retrieve $ref version]
	set revision [property_retrieve $ref revision]
	set variants [property_retrieve $ref variants]
	
	${darwinports::registry.format}::delete_entry $name $version $revision $variants
	
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

# Return all properties of the open registry entry
proc entry_properties {ref} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::entry_properties $ref]
}

# If only one version of the port is installed, this process returns that
# vERSION'S parts.  Otherwise, it lists the versions installed and exists.
proc installed {{name ""} {version ""}} {
	global darwinports::registry.format

	set ilist [${darwinports::registry.format}::installed $name $version]
	set rlist [list]

	if { [llength $ilist] > 1 } {
		foreach installed $ilist {
			set iname [lindex $installed 0]
			set iversion [lindex $installed 1]
			set irevision [lindex $installed 2]
			set ivariants [lindex $installed 3]
			set iref [open_entry $iname $iversion $irevision $ivariants]
			set iactive	[property_retrieve $iref active]
			lappend rlist [list $iname $iversion $irevision $ivariants $iactive]
		}
	} elseif { [llength $ilist] < 1 } {
		if { $name == "" } {
			return -code error "Registry error: No ports registered as installed."
		} else {
			return -code error "Registry error: $name not registered as installed."
		}
	} else {
		set name [lindex [lindex $ilist 0] 0]
		set iversion [lindex [lindex $ilist 0] 1]
		set irevision [lindex [lindex $ilist 0] 2]
		set ivariants [lindex [lindex $ilist 0] 3]
		set iref [open_entry $name $iversion $irevision $ivariants]
		set iactive	[property_retrieve $iref active]
		lappend rlist [list $name $iversion $irevision $ivariants $iactive]
	}
	return $rlist
}

# File Map Code
proc open_file_map {args} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::open_file_map $args]
}

proc file_registered {file} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::file_registered $file]
}

proc port_registered {name} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::port_registered $name]
}

proc register_file {file port} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::register_file $file $port]
}

proc unregister_file {file} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::unregister_file $file]
}

proc write_file_map {args} {
	global darwinports::registry.format
	return [${darwinports::registry.format}::write_file_map $args]
}

# Dependency Map Code
proc register_dependencies {deps name} {

	open_dep_map
	foreach dep $deps {
		# We expect the form type:regexp:port to come in, but we don't need to 
		# store it that way in the dep map.
		set type [lindex [split $dep :] 0]
		set depport [lindex [split $dep :] 2]
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


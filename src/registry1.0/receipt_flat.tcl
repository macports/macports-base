# receipt_flat.tcl
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

package provide receipt_flat 1.0

package require darwinports 1.0

##
# Receipts Code supporting flat-files
##
namespace eval receipt_flat {

# receipt_list will hold a reference to each "receipt" that is currently open
variable receipt_list [list]
variable file_map [list]
namespace export receipt_list file_map

# Create a new entry and place it in the receipt_list
proc new_entry {} {
	variable receipt_list

	if { ![info exists receipt_list] } {
		set receipt_list [list]
	}

	lappend receipt_list ""
	
	if { [llength $receipt_list] <= 1 } {
		return 0
	} else {
		return [expr [llength $receipt_list] - 1]
	}

}

# Open an existing entry and place it in the receipt_list
proc open_entry {name {version 0} {revision 0} {variants ""}} {
	global darwinports::registry.installtype
	variable receipt_list
	
	if { ![info exists receipt_list] } {
		set receipt_list [list]
	}

	set receipt_path [file join ${darwinports::registry.path} receipts ${name}]

	# If the receipt path ${name} doesn't exist, then a receipt doesn't.
	if { ![file isdirectory $receipt_path] } {
		return 0
	}

	# If version wasn't specified, find out the version number.  This will
	# depend on which installtype mode we're in, "direct" or "image"	
	if { $version == 0 } {
		# xxx: If we're in image mode, we really should have had the 
		# version given to us.  How should we handle this?
		set x [glob -nocomplain [file join ${receipt_path} *]]
		if { [string length $x] } {
			set v [lindex [file split [lindex $x 0]] end]
			regexp {([-_a-zA-Z0-9\.]+)_([0-9]*)([+-_a-zA-Z0-9]*)$} $v match version revision variants
		} else {
			return -code error "Registry error: ${name} not registered as installed."
		}
	}

	if { ![entry_exists $name $version $revision $variants] } {
		return -code error "Registry error: ${name} ${version}_${revision}${variants} not registered as installed."
	}

	set receipt_path [file join ${darwinports::registry.path} receipts ${name} ${version}_${revision}${variants}]

	set receipt_file [file join ${receipt_path} receipt]

	if { [file exists ${receipt_file}.bz2] && [file exists /usr/bin/bzip2] } {
		# xxx: Again, we shouldn't use absolute paths
		set receipt_contents [exec /usr/bin/bzip2 -d -c ${receipt_file}.bz2]
	} else {
		set receipt_handle [open ${receipt_file} r]
		set receipt_contents [read $receipt_handle]
		close $receipt_handle
	}

	lappend receipt_list $receipt_contents	

	if { [llength $receipt_list] <= 1 } {
		return 0
	} else {
		return [expr [llength $receipt_list] - 1]
	}

}

# Write an entry from the receipt_list
proc write_entry {ref name version {revision 0} {variants ""}} {
	global darwinports::registry.installtype
	variable receipt_list

	set receipt_contents [lindex $receipt_list $ref]

	set receipt_path [file join ${darwinports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	set receipt_file [file join ${receipt_path} receipt]

	if { ![file isdirectory ${receipt_path}] } {
		file mkdir ${receipt_path}
	}

	# Create the contents list entry
	set contents [property_retrieve $ref contents]
	set file_map [list]
	foreach file $contents {
		lappend file_map [list [lindex $file 0] $name ${version}_${revision}${variants}]
	}

	set receipt_handle [open ${receipt_file}.tmp w 0644]
	puts $receipt_handle $receipt_contents
	close $receipt_handle

	if { [file exists ${receipt_file}] } {
		system "rm -rf ${receipt_file}"
	} elseif { [file exists ${receipt_file}.bz2] } {
		system "rm -rf ${receipt_file}.bz2"
	}

	system "mv ${receipt_file}.tmp ${receipt_file}"

	# We should really not use absolute path for bzip2
	if { [file exists ${receipt_file}] && [file exists /usr/bin/bzip2] && ![info exists registry.nobzip] } {
		system "/usr/bin/bzip2 -f ${receipt_file}"
	}

	return 1
}

# Check to see if an entry exists
proc entry_exists {name version {revision 0} {variants ""}} {
	global darwinports::registry.path
variable receipt_handle 
	variable receipt_file 
	variable receipt_path

	set receipt_path [file join ${darwinports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	set receipt_file [file join ${receipt_path} receipt]

	if { [file exists $receipt_file] } {
		return 1
	} elseif { [file exists ${receipt_file}.bz2] } {
		return 1
	}

	return 0
}

# Store a property to a receipt current in the receipt_list
proc property_store {ref property value} {
	variable receipt_list

	if { [info exists receipt_list] } {
		set receipt_contents [lindex $receipt_list $ref]
	} else {
		set receipt_contents [list]
	}
	
	_reclist_set receipt_contents $property $value
	lset receipt_list $ref $receipt_contents

	return 1
}

# Retrieve a property from a receipt currently in the receipt_list
proc property_retrieve {ref property} {
	variable receipt_list

	set receipt_contents [lindex $receipt_list $ref]

	return [_reclist_get receipt_contents $property]
}

# Delete an entry
proc delete_entry {name version {revision 0} {variants ""}} {
	global darwinports::registry.path
	variable receipt_list

	set receipt_path [file join ${darwinports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	if { [file exists ${receipt_path}] } {
		system "rm -rf ${receipt_path}"
		return 1
	} else {
		return 0
	}
}

# Return all properties of an entry currently in the receipt_list
proc entry_properties {ref} {
	variable receipt_list
	set receipt_contents [lindex $receipt_list $ref]
	return $receipt_contents
}

# Return all installed ports
proc installed {{name ""} {version ""}} {
	global darwinports::registry.path
	variable receipt_path

	set query_path [file join ${darwinports::registry.path} receipts]
	
	if { $name == "" } {
		set query_path [file join ${query_path} *]
		if { $version == "" } {
			set query_path [file join ${query_path} *]
		}
	} else {
		set query_path [file join ${query_path} ${name}]
		if { $version != "" } {
			set query_path [file join ${query_path} ${version}*]
		} else {
			set query_path [file join ${query_path} *]
		}
	}

	set x [glob -nocomplain -type d ${query_path}]
	set rlist [list]
	foreach p $x {
		set plist [list]
		regexp {([-_a-zA-Z0-9\.]+)_([0-9]*)([+-_a-zA-Z0-9]*)$} [lindex [file split $p] end] match version revision variants
		lappend plist [lindex [file split $p] end-1]
		lappend plist $version
		lappend plist $revision
		lappend plist $variants
		lappend rlist $plist
	}
	return $rlist
}

proc open_file_map {args} {
	global darwinports::registry.path
	variable file_map

	set receipt_path [file join ${darwinports::registry.path} receipts]

	set map_file [file join ${receipt_path} map]

	if { ![file exists $map_file] } {
		system "touch $map_file"
	}
	
	if { [file exists ${map_file}.bz2] && [file exists /usr/bin/bzip2] } {
		# xxx: Again, we shouldn't use absolute paths
		set file_map [exec /usr/bin/bzip2 -d -c ${map_file}.bz2]
	} else {
		set map_handle [open ${map_file} r]
		set file_map [read $map_handle]
		close $map_handle
	}
	if { ![llength $file_map] > 0 } {
		set file_map [list]
	}
}

proc file_registered {file} {
	variable file_map
	if { [llength $file_map] < 1 && [info exists file_map] } {
		open_file_map
	}
	foreach f $file_map {
		if { $file == [lindex $f 0] } {
			return [lindex $f 1]
		}
	}
	return 0
}

proc port_registered {name} {
	variable file_map
	if { [llength $file_map] < 1 && [info exists file_map] } {
		open_file_map
	}
	set files [list]
	foreach f $file_map {
		if { $name == [lindex $f 1] } {
			lappend files [lindex $f 0]
		}
	}
	if { [llength $files] > 0 } {
		return $files
	} else {
		return 0
	}
}

proc register_file {file port} {
	variable file_map
	lappend file_map [list $file $port]
}

proc unregister_file {file} {
	variable file_map
	set new_map [list]
	foreach fe $file_map {
		if { ![string equal [lindex $fe 0] $file] } {
			lappend new_map $fe
		}
	}
	set file_map $new_map
}

proc write_file_map {args} {
	variable file_map

	set receipt_path [file join ${darwinports::registry.path} receipts]

	set map_file [file join ${receipt_path} map]

	set map_handle [open ${map_file}.tmp w 0644]
	puts $map_handle $file_map
	close $map_handle

	if { [file exists ${map_file}] } {
		system "rm -rf ${map_file}"
	} elseif { [file exists ${map_file}.bz2] } {
		system "rm -rf ${map_file}.bz2"
	}

	system "mv ${map_file}.tmp ${map_file}"

	# We should really not use absolute path for bzip2
	if { [file exists ${map_file}] && [file exists /usr/bin/bzip2] && ![info exists registry.nobzip] } {
		system "/usr/bin/bzip2 -f ${map_file}"
	}

	return 1
}

##
# A simple keyed list effort... 
# This should be considered private
# xxx:There should be a better way to do this
##

# Add a key/value to the reglist
proc _reclist_set {rlist key value} {
	upvar $rlist r
	for { set i 0 } { $i <= [llength $r] } { incr i } {
		if { [lindex [lindex $r $i] 0] == $key } {
			lset r $i [list $key $value]
			return r
		}
	}
	lappend r [list $key $value]
	return r
}

# Get the value for key from a reglist
proc _reclist_get {rlist key} {
	upvar $rlist r
	foreach k $r {	
		if { [lindex $k 0] == $key } {
			return [lindex $k 1]
		}
	}
	return 0
}

# Delete a key/value from a reglist
proc _reclist_del {rlist key} {
	upvar $rlist r
	set t [list]
	foreach k $r {
		if { [lindex $k 0] == $key] } {
			lappend $t $k
		}
	}
	set r $t
}


# End of receipt_flat namespace
}


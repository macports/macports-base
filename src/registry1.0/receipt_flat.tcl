# receipt_flat.tcl
# $Id$
#
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
# Copyright (c) 2004 Paul Guyot, The MacPorts Project.
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

package require macports 1.0
package require Pextlib 1.0

##
# Receipts Code supporting flat-files
##
namespace eval receipt_flat {

# receipt_lastref is the last attributed index of receipts.
variable receipt_lastref -1

##
#
# Create a new entry and return its reference number.
# The reference number allows us to retrieve the receipt array.
proc new_entry {} {
	variable receipt_lastref
	incr receipt_lastref

	variable receipt_$receipt_lastref
	array set receipt_$receipt_lastref {}

	return $receipt_lastref
}

##
#
# Get the path to the receipt in HEAD format.
# Remark: this code doesn't work for some ports.
# That's why we moved to the new path format in the first place.
#
# portname			the name of the port.
# portversion		the version for this port, 0 if unknown.
# return the path to the file or "" if the file couldn't be found.
proc get_head_entry_receipt_path {portname portversion} {
    global macports::registry.path

    # regex match case
    if {$portversion == 0} {
	set x [glob -nocomplain [file join ${macports::registry.path} receipts ${portname}-*]]
	if {[string length $x]} {
	    set matchfile [lindex $x 0]
		# Remove trailing .bz2, if any.
		regexp {(.*)\.bz2$} $matchfile match matchfile
	} else {
	    set matchfile ""
	}
    } else {
	set matchfile [file join ${macports::registry.path} receipts ${portname}-${portversion}]
    }

    # Might as well bail out early if no file to match
    if {![string length $matchfile]} {
		return ""
    }

    if {[file exists $matchfile] || [file exists ${matchfile}.bz2]} {
		return $matchfile
    }
    return ""
}

##
#
# Open an existing entry and return its reference number.
proc open_entry {name {version 0} {revision 0} {variants ""}} {
	global macports::registry.installtype
	global macports::registry.path

	set receipt_path [file join ${macports::registry.path} receipts ${name}]

	# If the receipt path ${name} doesn't exist, then the receipt probably is
	# in the old HEAD format.
	if { ![file isdirectory $receipt_path] } {
		set receipt_file [get_head_entry_receipt_path $name $version]
		
		if {![string length $receipt_file]} {
			if { $version != 0 } {
				return -code error "Registry error: ${name} @${version}_${revision}${variants} not registered as installed."
			} else {
				return -code error "Registry error: ${name} not registered as installed."
			}
		}
		
		# Extract the version from the path.
		if { $version == 0 } {
			set theFileName [file tail $receipt_file]
			regexp "^$name-(.*)\$" $theFileName match version
		}
	} else {
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
			return -code error "Registry error: ${name} @${version}_${revision}${variants} not registered as installed."
		}
	
		set receipt_path [file join ${macports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	
		set receipt_file [file join ${receipt_path} receipt]
	}

	if { [file exists ${receipt_file}.bz2] && [file exists ${registry::autoconf::bzip2_path}] } {
		set receipt_file ${receipt_file}.bz2
		set receipt_contents [exec ${registry::autoconf::bzip2_path} -d -c ${receipt_file}]
	} elseif { [file exists ${receipt_file}] } {
		set receipt_handle [open ${receipt_file} r]
		set receipt_contents [read $receipt_handle]
		close $receipt_handle
	} else {
		return -code error "Registry error: receipt for ${name} @${version}_${revision}${variants} seems to be compressed, but bzip2 couln't be found."
	}

	set ref [new_entry]
	variable receipt_$ref

	# Determine the format of the receipt.
	if {[string match "# Format: var value ...*" $receipt_contents]} {
		# This is old HEAD format.
		# We convert it and we save it.
		# tell the user
		ui_msg "Converting receipt for $name-$version to new format"

		convert_entry_from_HEAD $name $version $revision $variants $receipt_contents $ref
		
		# move the old receipt
		set convertedDirPath [file join ${macports::registry.path} receipts_converted]
		file mkdir $convertedDirPath
		file rename $receipt_file $convertedDirPath
	} elseif {[string match "# Version: *" $receipt_contents]} {
		# This is new format
		if {![string match "# Version: 1.0*" $receipt_contents]} {
			return -code error "Registry error: receipt ${name} @${version}_${revision}${variants} is in an unknown format (version too new?)."
		}

		# Remove any line starting with #
		while {[regexp "(^|\n)#.*\n(.*)\$" $receipt_contents match foo receipt_contents]} {}
		array set receipt_$ref $receipt_contents
	} else {
		# This is old Images format

		# Iterate on the elements of $receipt_contents and add them to the list.
		foreach pair $receipt_contents {
			array set receipt_[set ref] $pair
		}
	}
	
	return $ref
}

##
#
# Convert an entry from HEAD old format.
# HEAD old format is a file in the key,value format with key and values being on the
# same line separated with a space.
# This typically is read with an options-like approach.
# This conversion routine also appends the contents to the file map.
#
# name				the name of the port to convert.
# version			the version of the port to convert.
# revision			the revision of the port to convert (probably inaccurate).
# variants			the variants of the port to convert (idem).
# receipt_contents	the content of the old receipt file.
# ref				reference of the target receipt array where the content must be put.
proc convert_entry_from_HEAD {name version revision variants receipt_contents ref} {
	variable receipt_$ref
	
	# First set default value for stuff that aren't in the receipt.
	array set receipt_[set ref] [list name $name]
	array set receipt_[set ref] [list version $version]
	array set receipt_[set ref] [list revision $revision]
	array set receipt_[set ref] [list variants $variants]
	array set receipt_[set ref] [list installtype direct]
	array set receipt_[set ref] [list receipt_f receipt_flat]
	array set receipt_[set ref] [list active 1]
	
	# Then start a new interpreter to read the content of the portfile.
	interp create theConverterInterpreter
	# Just ignore prefix.
	interp eval theConverterInterpreter "proc prefix {args} {\n\
	}"
	# Also ignore run_depends.
	interp eval theConverterInterpreter "proc run_depends {args} {\n\
	}"
	interp eval theConverterInterpreter "proc categories {args} {\n\
		global theConvertedReceipt\n\
		array set theConvertedReceipt \[list categories \$args\]\n\
	}"
	interp eval theConverterInterpreter "proc description {args} {\n\
		global theConvertedReceipt\n\
		array set theConvertedReceipt \[list description \$args\]\n\
	}"
	interp eval theConverterInterpreter "proc long_description {args} {\
		global theConvertedReceipt\n\
		array set theConvertedReceipt \[list long_description \$args\]\n\
	}"
	interp eval theConverterInterpreter "proc homepage {args} {\n\
		global theConvertedReceipt\n\
		array set theConvertedReceipt \[list homepage \$args\]\n\
	}"
	# contents already is a list.
	interp eval theConverterInterpreter "proc contents {args} {\n\
		variable contents\n\
		set contents \[lindex \$args 0\]\n\
	}"
	interp eval theConverterInterpreter "array set theConvertedReceipt {}"
	interp eval theConverterInterpreter "variable contents"
	interp eval theConverterInterpreter $receipt_contents
	array set receipt_$ref [interp eval theConverterInterpreter "array get theConvertedReceipt"]
	set contents [interp eval theConverterInterpreter "set contents"]
	interp delete theConverterInterpreter

	# Append the contents list to the file map (only the files).
	set theActualContents [list]
	foreach file $contents {
		if {[llength $file]} {
			set theFilePath [lindex $file 0]
			if {[file isfile $theFilePath]} {
				set previousPort [file_registered $theFilePath]
				if {$previousPort != 0} {
					ui_warn "Conflict detected for file $theFilePath between $previousPort and $name."
				}
				if {[catch {register_file $theFilePath $name}]} {
					ui_warn "An error occurred while adding $theFilePath to the file_map database."
				}
			} elseif {![file exists $theFilePath]} {
				ui_warn "Port $name refers to $theFilePath which doesn't exist."
			}
			lappend theActualContents $file
		} else {
			ui_warn "Port $name contents list includes an empty element."
		}
	}
	
	property_store $ref contents $theActualContents

	# Save the file_map afterwards
	write_file_map
	
	# Save the entry to new format.
	write_entry $ref $name $version $revision $variants
}

##
#
# Write the entry that was previously created.
#
# ref				the reference number of the entry.
# name				the name of the port.
# version			the version of the port.
# variants			the variants of the port.
proc write_entry {ref name version {revision 0} {variants ""}} {
	global macports::registry.installtype
	variable receipt_$ref

	set receipt_contents [array get receipt_$ref]

	set receipt_path [file join ${macports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	set receipt_file [file join ${receipt_path} receipt]

	if { ![file isdirectory ${receipt_path}] } {
		file mkdir ${receipt_path}
	}

	set receipt_handle [open ${receipt_file}.tmp w 0644]
	puts $receipt_handle "# Version: 1.0"
	puts $receipt_handle $receipt_contents
	close $receipt_handle

	if { [file exists ${receipt_file}] } {
		system "rm -rf ${receipt_file}"
	} elseif { [file exists ${receipt_file}.bz2] } {
		system "rm -rf ${receipt_file}.bz2"
	}

	system "mv ${receipt_file}.tmp ${receipt_file}"

	if { [file exists ${receipt_file}] && [file exists ${registry::autoconf::bzip2_path}] && ![info exists registry.nobzip] } {
		system "${registry::autoconf::bzip2_path} -f ${receipt_file}"
	}

	return 1
}

# Check to see if an entry exists
proc entry_exists {name version {revision 0} {variants ""}} {
	global macports::registry.path
	variable receipt_handle 
	variable receipt_file 
	variable receipt_path

	set receipt_path [file join ${macports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	set receipt_file [file join ${receipt_path} receipt]

	if { [file exists $receipt_file] } {
		return 1
	} elseif { [file exists ${receipt_file}.bz2] } {
		return 1
	}

	return 0
}

##
#
# Store a property to a receipt that was loaded in memory.
# This replaces any property that had the same key previously in the receipt.
#
# ref			reference number for the receipt.
# property		key for the property to store.
# value			value for the property to store.
proc property_store {ref property value} {
	variable receipt_$ref
	
	array set receipt_[set ref] [list $property $value]

	return 1
}

##
#
# Retrieve a property from a receipt that was loaded in memory.
#
# ref			reference number for the receipt.
# property		key for the property to retrieve.
#
proc property_retrieve {ref property} {
	variable receipt_$ref

	set theCouple [array get receipt_[set ref] $property]
	if {[llength $theCouple] != 2} {
		return 0
	} else {
		return [lindex $theCouple 1]
	}
}

# Delete an entry
proc delete_entry {name version {revision 0} {variants ""}} {
	global macports::registry.path

	set receipt_path [file join ${macports::registry.path} receipts ${name} ${version}_${revision}${variants}]
	if { [file exists ${receipt_path}] } {
		# remove port receipt directory
		ui_debug "deleting directory: ${receipt_path}"
		file delete -force ${receipt_path}
		# remove port receipt parent directory (if empty)
		set receipt_dir [file join ${macports::registry.path} receipts ${name}]
		if { [file isdirectory ${receipt_dir}] } {
			# 0 item means empty.
			if { [llength [readdir ${receipt_dir}]] == 0 } {
				ui_debug "deleting directory: ${receipt_dir}"
				file delete -force ${receipt_dir}
			} else {
				ui_debug "${receipt_dir} is not empty"
			}
		}
		return 1
	} else {
		return 0
	}
}

# Return all installed ports
#
# If version is "", return all ports of that version.
# Otherwise, return only ports that exactly match this version.
# What we call version here is version_revision+variants.
# Note: at some point we need to change these APIs and support something
# like selecting on the version or selecting variants in any order.
proc installed {{name ""} {version ""}} {
	global macports::registry.path

	set query_path [file join ${macports::registry.path} receipts]
	
	if { $name == "" } {
		set query_path [file join ${query_path} *]
		if { $version == "" } {
			set query_path [file join ${query_path} *]
		}
		# [PG] Huh?
	} else {
		set query_path [file join ${query_path} ${name}]
		if { $version != "" } {
			set query_path [file join ${query_path} ${version}]
		} else {
			set query_path [file join ${query_path} *]
		}
	}

	set x [glob -nocomplain -types d ${query_path}]
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

	# append the ports in old HEAD format.
	if { $name == "" } {
		set query_path [file join ${macports::registry.path} receipts *]
	} else {
		set query_path [file join ${macports::registry.path} receipts ${name}-*]
	}
    set receiptglob [glob -nocomplain -types f ${query_path}]
    foreach receipt_file $receiptglob {
		set theFileName [file tail $receipt_file]

    	# Remark: these regexes do not always work.
   		set theName ""
    	if { $name == "" } {
			regexp {^(.*)-(.*)$} $theFileName match theName version
    	} else {
			regexp "^($name)-(.*)\$" $theFileName match theName version
		}
		
		# Skip if the name is empty, i.e. if it didn't match.
		if {[string length $theName]} {
			set plist [list]
			lappend plist $theName
			
			# Remove .bz2 suffix, if present.
			regexp {^(.*)\.bz2$} $version match version
			lappend plist $version
			lappend plist 0
			lappend plist ""
			lappend rlist $plist
		}
	}

	return $rlist
}

# File Map stuff

##
# open the file map and store a reference to it into variable file_map.
# convert from the old format if required.
#
proc open_file_map {{readonly 0}} {
	global macports::registry.path
	variable file_map

	set receipt_path [file join ${macports::registry.path} receipts]
	set map_file [file join ${receipt_path} file_map]

	# Don't reopen it (it actually would deadlock us), unless it was open r/o.
	# and we want it r/w.
	if { [info exists file_map] } {
		if { $readonly == 0 } {
			if {[filemap isreadonly file_map]} {
				filemap close file_map
				filemap open file_map ${map_file}.db
			}
		}
		return 0
	}

	set old_filemap [list]

	if { ![file exists ${map_file}.db] } {
		# Convert to new format
		if { [file exists ${map_file}.bz2] && [file exists ${registry::autoconf::bzip2_path}] } {
			set old_filemap [exec ${registry::autoconf::bzip2_path} -d -c ${map_file}.bz2]
		} elseif { [file exists $map_file] } {		
			set map_handle [open ${map_file} r]
			set old_filemap [read $map_handle]
			close $map_handle
		}
	}

	if { [llength $old_filemap] > 0 } {
		# Translate from old format.
		# Open the map (new format)
		filemap open file_map ${map_file}.db
		
		# Tell the user.
		ui_msg "Converting file map to new format (this may take a while)"

		foreach f $old_filemap {
			filemap set file_map [lindex $f 0] [lindex $f 1]
		}
		
		# Save it afterwards.
		filemap save file_map

		# reopen it r/o if we wanted it r/o.
	} else {
		# open it directly
		if { $readonly == 1 } {
			filemap open file_map ${map_file}.db readonly
		} else {
			filemap open file_map ${map_file}.db
		}
	}
	
	return 0
}

##
# determine if a file is registered in the file map, and if it is,
# get its port.
# open the file map if required.
#
# - file	the file to test
# return the 0 if the file is not registered, the name of the port otherwise.
#
proc file_registered {file} {
	variable file_map

	open_file_map 1

	if {[filemap exists file_map $file]} {
		return [filemap get file_map $file]
	} else {
		return 0
	}
}

##
# determine if a port is registered in the file map, and if it is,
# get its installed (activated) files.
# convert the port if required.
# open the file map if required.
#
# - port	the port to test
# return the 0 if the port is not registered, the list of its files otherwise.
#
proc port_registered {name} {
	# Trust the file map first.
	variable file_map

	open_file_map 1

	set files [filemap list file_map $name]

	if { [llength $files] > 0 } {
		return $files
	} else {
		# Is port installed?
		set matchingPorts [installed $name]
		if { [llength $matchingPorts] } {
			# Convert the port and retry.
			open_entry $name
			
			set files [filemap list file_map $name]
			
			return $files
		} else {
			return 0
		}
	}
}

##
# register a file in the file map.
# open the file map if required.
#
# - file	the file to register
# - port	the port to associate with the file
#
proc register_file {file port} {
	variable file_map

	open_file_map

	if { [file type $file] == "link" } {
		ui_debug "Adding link to file_map: $file for: $port"
	} else {
		ui_debug "Adding file to file_map: $file for: $port"
	}
	filemap set file_map $file $port
}

##
# register all the files in the list 'files' in the filemap.
# open the file map if required.
#
# - files	the list of files to register
# - port	the port to associate the files with
#
proc register_bulk_files {files port} {
	variable file_map

	open_file_map

	foreach f $files {
		set file [lindex $f 0]
		if { [file type $file] == "link" } {
			ui_debug "Adding link to file_map: $file for: $port"
		} else {
			ui_debug "Adding file to file_map: $file for: $port"
		}
		filemap set file_map $file $port
	}
}

##
# unregister a file from the file map.
# open the file map if required.
#
# - file	the file to unregister
#
proc unregister_file {file} {
	variable file_map

	open_file_map

	ui_debug "Removing entry from file_map: $file"
	filemap unset file_map $file
}

##
# save the file map to disk.
# do not do anything if the file map wasn't open.
#
# always return 1
#
proc write_file_map {args} {
	variable file_map

	if { [info exists file_map] } {
		open_file_map
		filemap save file_map
	}

	return 1
}

# Dependency Map Code
proc open_dep_map {args} {
	global macports::registry.path
	variable dep_map

	set receipt_path [file join ${macports::registry.path} receipts]

	set map_file [file join ${receipt_path} dep_map]

	if { [file exists ${map_file}.bz2] && [file exists ${registry::autoconf::bzip2_path}] } {
		set dep_map [exec ${registry::autoconf::bzip2_path} -d -c ${map_file}.bz2]
	} elseif { [file exists ${map_file}] } {
		set map_handle [open ${map_file} r]
		set dep_map [read $map_handle]
		close $map_handle
	} else {
	    set dep_map [list]
	}
	if { ![llength $dep_map] > 0 } {
		set dep_map [list]
	}
}

# List all ports this one depends on
proc list_depends {name} {
	variable dep_map
	if { [llength $dep_map] < 1 && [info exists dep_map] } {
		open_dep_map
	}
	set rlist [list]
	foreach de $dep_map {
		if { $name == [lindex $de 2] } {
			lappend rlist $de
		}
	}
	return $rlist
}

# List all the ports that depend on this port
proc list_dependents {name} {
	variable dep_map
	if { [llength $dep_map] < 1 && [info exists dep_map] } {
		open_dep_map
	}
	set rlist [list]
	foreach de $dep_map {
		if { $name == [lindex $de 0] } {
			lappend rlist $de
		}
	}
	return $rlist
}

proc register_dep {dep type port} {
	variable dep_map
	set newdep [list $dep $type $port]
	# slow, but avoids duplicate entries building up
	if {[lsearch -exact $dep_map $newdep] == -1} {
	    lappend dep_map $newdep
	}
}

proc unregister_dep {dep type port} {
	variable dep_map
	set new_map [list]
	foreach de $dep_map {
		if { $de != [list $dep $type $port] } {
			lappend new_map $de
		}
	}
	set dep_map $new_map
}

proc write_dep_map {args} {
	global macports::registry.path
	variable dep_map

	set receipt_path [file join ${macports::registry.path} receipts]

	set map_file [file join ${receipt_path} dep_map]

	set map_handle [open ${map_file}.tmp w 0644]
	puts $map_handle $dep_map
	close $map_handle

    # don't both checking for presence, file delete doesn't error if file doesn't exist
    file delete ${map_file} ${map_file}.bz2

    file rename ${map_file}.tmp ${map_file}

	if { [file exists ${map_file}] && [file exists ${registry::autoconf::bzip2_path}] && ![info exists registry.nobzip] } {
		system "${registry::autoconf::bzip2_path} -f ${map_file}"
	}

	return 1
}

# End of receipt_flat namespace
}


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
package require portuninstall 1.0
package require msgcat
package require Pextlib 1.0

set UI_PREFIX "---> "

namespace eval registry {

variable force
namespace export force


# Begin creating a new registry entry for the port version_revision+variant
# This process assembles the directory name and creates a receipt dlist
proc new_entry {name version {revision 0} {variants ""} {epoch 0} } {
	global macports::registry.path macports::registry.format macports::prefix

	
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
		property_store $ref receipt_f ${macports::registry.format}
		property_store $ref active 0

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


#
# Port Images are installations of the destroot of a port archived into a
# tbz file.
# They allow the user to install multiple versions of the same port, treating
# each revision and each different combination of variants as a "version".
#  
# From there, the user can "activate" a port image.  This extracts the port's
# files from the tbz into ${prefix}.  Directories are created.  
# Activation checks the registry's file_map for any files which conflict with
# other "active" ports, and will not overwrite the links to the those files.
# The conflicting port must be deactivated first.
#
# The user can also "deactivate" an active port.  This will remove all the
# port's files from ${prefix}, and if any directories are empty, remove them
# as well.  It will also remove all of the references of the files from the
# registry's file_map.
#

# Activate a "Port Image"	
proc activate {name v optionslist} {
	global macports::prefix macports::registry.path UI_PREFIX env
	global macports::portimagefilepath
	array set options $optionslist
	variable force

	if {[info exists options(ports_force)] && [string equal -nocase $options(ports_force) "yes"] } {
		set force 1
	} else {
		set force 0
	}

	set ilist [_check_registry $name $v]
	# set name again since the one we were passed may not have had the correct case
	set name [lindex $ilist 0]
	set version [lindex $ilist 1]
	set revision [lindex $ilist 2]
	set	variants [lindex $ilist 3]
	set	epoch [lindex $ilist 5]
    set macport_filename [macports::getportimagename_from_port_info $name $epoch $version $revision $variants]
	set macport_file [file join ${macports::portimagefilepath} $name $macport_filename]
	if {![file exists $macport_file]} {
		return -code error "Image error: Can't find image file $macport_file"
	}
	
    if {$v != ""} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $v]"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s"] $name]"
    }

	set ilist [registry::installed $name]
	if { [llength $ilist] > 1 } {
		foreach i $ilist {
			set iname [lindex $i 0]
			set iversion [lindex $i 1]
			set irevision [lindex $i 2]
			set	ivariants [lindex $i 3]
			set iactive [lindex $i 4]
			if { ![string equal ${iversion}_${irevision}${ivariants} ${version}_${revision}${variants}] && $iactive == 1 } {
				return -code error "Image error: Another version of this port ($iname @${iversion}_${irevision}${ivariants}) is already active."
			}
		}
	}

	set ref [registry::open_entry $name $version $revision $variants]
	
	if { [registry::property_retrieve $ref active] != 0 } {
		return -code error "Image error: ${name} @${version}_${revision}${variants} is already active."
	} 

	set contents [registry::property_retrieve $ref contents]

	set imagefiles {}
	foreach content_element $contents {
		lappend imagefiles [lindex $content_element 0]
	}

	if {[info exists env(TMPDIR)]} {
		set extractdir [mkdtemp [file join $env(TMPDIR) mpextractXXXXXXXX]]
	} else {
		set extractdir [mkdtemp [file join /tmp mpextractXXXXXXXX]]
	}
	set startpwd [pwd]
	try {
		if {[catch {cd $extractdir} err]} {
			throw MACPORTS $err
		}
		if {[catch {set tarcmd [macports::findBinary tar]} err]} {
			throw MACPORTS $err
		}
		if {[catch {set bzipcmd [macports::findBinary bzip2]} err]} {
			throw MACPORTS $err
		}
		if {[catch {system "$tarcmd -xf $macport_file files.tar.bz2"} err]} {
			throw MACPORTS $err
		}
		if {[catch {system "$bzipcmd -dc files.tar.bz2 | $tarcmd -xpvf -"} err]} {
			throw MACPORTS $err
		}
		_activate_contents $name $imagefiles $extractdir
		registry::property_store $ref active 1
		registry::write_entry $ref

		registry::register_bulk_files $contents $name
	} catch {* errorCode errorMessage} {
		ui_error $errorMessage
	} finally {
		cd $startpwd
		file delete -force $extractdir
	}
}

proc deactivate {name v optionslist} {
	global UI_PREFIX
	array set options $optionslist
	variable force

	if {[info exists options(ports_force)] && [string equal -nocase $options(ports_force) "yes"] } {
		set force 1
	} else {
		set force 0
	}

	set ilist [registry::active $name]
	if { [llength $ilist] > 1 } {
		return -code error "Registry error: Please specify the name of the port."
	} else {
		set ilist [lindex $ilist 0]
	}
	# set name again since the one we were passed may not have had the correct case
	set name [lindex $ilist 0]
	set version [lindex $ilist 1]
	set revision [lindex $ilist 2]
	set	variants [lindex $ilist 3]
	set fqversion ${version}_${revision}${variants}
	
    if {$v != ""} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $v]"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s"] $name]"
    }
	
	if { $v != "" && ![string equal ${fqversion} $v] } {
		return -code error "Active version of $name is not $v but ${fqversion}."
	}
	
	set ref [registry::open_entry $name $version $revision $variants]

	if { [registry::property_retrieve $ref active] != 1 } {
		return -code error "Image error: ${name} @${fqversion} is not active."
	} 

	set imagefiles [registry::port_registered $name]

	_deactivate_contents $name $imagefiles

	registry::open_file_map
	foreach file $imagefiles {
		registry::unregister_file $file
	}
	registry::write_file_map
	registry::close_file_map
	
	registry::property_store $ref active 0

	registry::write_entry $ref

}

proc _check_registry {name v} {
	global UI_PREFIX

	set ilist [registry::installed $name $v]
	if { [string equal $v ""] } {
		if { [llength $ilist] > 1 } {
		    # set name again since the one we were passed may not have had the correct case
		    set name [lindex [lindex $ilist 0] 0]
			ui_msg "$UI_PREFIX [msgcat::mc "The following versions of $name are currently installed:"]"
			foreach i $ilist { 
				set iname [lindex $i 0]
				set iversion [lindex $i 1]
				set irevision [lindex $i 2]
				set	ivariants [lindex $i 3]
				set iactive [lindex $i 4]
				if { $iactive == 0 } {
					ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s_%s%s"] $iname $iversion $irevision $ivariants]"
				} elseif { $iactive == 1 } {
					ui_msg "$UI_PREFIX [format [msgcat::mc "	%s @%s_%s%s (active)"] $iname $iversion $irevision $ivariants]"
				}
			}
			return -code error "Registry error: Please specify the full version as recorded in the port registry."
		} else {
			return [lindex $ilist 0]
		}
	} else {
			return [lindex $ilist 0]
	}
	return -code error "Registry error: No port of $name installed."
}

proc _activate_file {srcfile dstfile} {
	# Don't recursively copy directories
	if { [file isdirectory $srcfile] && [file type $srcfile] != "link" } {
		# Don't do anything if the directory already exists.
		if { ![file isdirectory $dstfile] } {
			file mkdir $dstfile
			# fix attributes on the directory.
			eval file attributes {$dstfile} [file attributes $srcfile]
			# set mtime on installed element
			file mtime $dstfile [file mtime $srcfile]
		}
	} else {
		file rename $srcfile $dstfile
	}
}

proc _activate_list {flist extractdir} {
	foreach file $flist {
		ui_debug "activating [file type ${extractdir}${file}]: $file"
		_activate_file ${extractdir}${file} $file
	}
}

proc _activate_contents {name imagefiles extractdir} {
	variable force
	global macports::prefix

	set files [list]
	
	# This is big and hairy and probably could be done better.
	# First, we need to check the source file, make sure it exists
	# Then we remove the $extractdir from the path of the file in the contents
	#  list  and check to see if that file exists
	# Last, if the file exists, and belongs to another port, and force is set
	#  we remove the file from the file_map, take ownership of it, and 
	#  clobber it
	foreach file $imagefiles {
		set srcfile ${extractdir}${file}

		# To be able to install links, we test if we can lstat the file to figure
		# out if the source file exists (file exists will return false for symlinks on
		# files that do not exist)
		if { [catch {file lstat $srcfile dummystatvar}] } {
			return -code error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port $name."
		}

		set port [registry::file_registered $file] 

		set timestamp [clock seconds]

		if { $port != 0  && $force != 1 && $port != $name } {
			return -code error "Image error: $file is being used by the active $port port.  Please deactivate this port first, or use 'port -f activate $name' to force the activation."
		} elseif { [file exists $file] && $force != 1 } {
			return -code error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port $name."
		} elseif { $force == 1 && [file exists $file] || $port != 0 } {
			set bakfile ${file}.mp_${timestamp}

			if {[file exists $file]} {
				ui_warn "File $file already exists.  Moving to: $bakfile."
				file rename -force $file $bakfile
			}
			
			if { $port != 0 } {
				set bakport [registry::file_registered $file]
				registry::unregister_file $file
				if {[file exists $file]} {
					registry::register_file $bakfile $bakport
				}
			}
		}
		
		# Split out the filename's subpaths and add them to the imagefile list.
		# We need directories first to make sure they will be there before
		# links. However, because file mkdir creates all parent directories,
		# we don't need to have them sorted from root to subpaths. We do need,
		# nevertheless, all sub paths to make sure we'll set the directory
		# attributes properly for all directories.
		set directory [file dirname $file]
		while { [lsearch -exact $files $directory] == -1 } { 
			lappend files $directory
			set directory [file dirname $directory]
		}

		# Also add the filename to the imagefile list.
		lappend files $file
	}
	registry::write_file_map

	# Sort the list in forward order, removing duplicates.
	# Since the list is sorted in forward order, we're sure that directories
	# are before their elements.
	# We don't have to do this as mentioned above, but it makes the
	# debug output of activate make more sense.
	set theList [lsort -increasing -unique $files]

	# Activate it, and catch errors so we can roll-back
	if { [catch {set files [_activate_list $theList $extractdir] } result] } {
		ui_debug "Activation failed, rolling back."
		_deactivate_contents $name $imagefiles
		return -code error $result
	}
}

proc _deactivate_file {dstfile} {
	if { [file type $dstfile] == "link" } {
		ui_debug "deactivating link: $dstfile"
		file delete -- $dstfile
	} elseif { [file isdirectory $dstfile] } {
		# 0 item means empty.
		if { [llength [readdir $dstfile]] == 0 } {
			ui_debug "deactivating directory: $dstfile"
			file delete -- $dstfile
		} else {
			ui_debug "$dstfile is not empty"
		}
	} else {
		ui_debug "deactivating file: $dstfile"
		file delete -- $dstfile
	}
}

proc _deactivate_list {filelist} {
	foreach file $filelist {
		_deactivate_file $file
	}
}

proc _deactivate_contents {name imagefiles} {
	variable force

	set files [list]
	
	foreach file $imagefiles {
		set port [registry::file_registered $file]
		if { [file exists $file] || (![catch {file type $file}] && [file type $file] == "link") } {
			# Normalize the file path to avoid removing the intermediate
			# symlinks (remove the empty directories instead)
			# Remark: paths in the registry may be not normalized.
			# This is not really a problem and it is in fact preferable.
			# Indeed, if I change the activate code to include normalized paths
			# instead of the paths we currently have, users' registry won't
			# match and activate will say that some file exists but doesn't
			# belong to any port.
			set theFile [file normalize $file]
			lappend files $theFile
			
			# Split out the filename's subpaths and add them to the image list as
			# well.
			set directory [file dirname $theFile]
			while { [lsearch -exact $files $directory] == -1 } { 
				lappend files $directory
				set directory [file dirname $directory]
			}
		} else {
			ui_debug "$file does not exist."
		}
	}

	# Sort the list in reverse order, removing duplicates.
	# Since the list is sorted in reverse order, we're sure that directories
	# are after their elements.
	set theList [lsort -decreasing -unique $files]

	# Remove all elements.
	if { [catch {_deactivate_list $theList} result] } {
		return -code error $result
	}
}

# End of registry namespace
}


# portimage.tcl
# $Id$
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

package provide portimage 1.0

package require registry 1.0
package require macports 1.0
package require Pextlib 1.0

set UI_PREFIX "--> "

#
# Port Images are basically just installations of the destroot of a port into
# ${macports::registry.path}/software/${name}/${version}_${revision}${variants}
# They allow the user to instal multiple versions of the same port, treating
# each revision and each different combination of variants as a "version".
#  
# From there, the user can "activate" a port image.  This creates {sym,hard}links for
# all files in the image into the ${prefix}.  Directories are created.  
# Activation checks the registry's file_map for any files which conflict with
# other "active" ports, and will not overwrite the links to the those files.
# The conflicting port must be deactivated first.
#
# The user can also "deactivate" an active port.  This will remove all {sym,hard}links
# from ${prefix}, and if any directories are empty, remove them as well.  It 
# will also remove all of the references of the files from the registry's 
# file_map
#
# Compacting and Uncompacting of port images to save space will be implemented
# at some point.
#
# For the creating and removing of links during activation and deactivation,
# code very similar to what is used in portinstall is used.
#

namespace eval portimage {

variable force
namespace export force
	
# Activate a "Port Image"	
proc activate {name v optionslist} {
	global macports::prefix macports::registry.path UI_PREFIX
	array set options $optionslist
	variable force

	if {[info exists options(ports_force)] && [string equal -nocase $options(ports_force) "yes"] } {
		set force 1
	} else {
		set force 0
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $v]"
	
	set ilist [_check_registry $name $v]
	set version [lindex $ilist 1]
	set revision [lindex $ilist 2]
	set	variants [lindex $ilist 3]

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
	
	if { ![string equal [registry::property_retrieve $ref installtype] "image"] } {
		return -code error "Image error: ${name} @${version}_${revision}${variants} not installed as an image."
	}
	if { [registry::property_retrieve $ref active] != 0 } {
		return -code error "Image error: ${name} @${version}_${revision}${variants} is already active."
	} 
	if { [registry::property_retrieve $ref compact] != 0 } {
		return -code error "Image error: ${name} @${version}_${revision}${variants} is compactd."
	} 

	set imagedir [registry::property_retrieve $ref imagedir]

	set contents [registry::property_retrieve $ref contents]
	
	set imagefiles [_check_contents $name $contents $imagedir]
	
	_activate_contents $name $imagefiles $imagedir

	registry::property_store $ref active 1

	registry::write_entry $ref

	registry::open_file_map
	foreach file $imagefiles {
		registry::register_file $file $name
	}
	registry::write_file_map
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

	ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $v]"
	
	set ilist [registry::active $name]
	if { [llength $ilist] > 1 } {
		return -code error "Registry error: Please specify the name of the port."
	} else {
		set ilist [lindex $ilist 0]
	}
	set version [lindex $ilist 1]
	set revision [lindex $ilist 2]
	set	variants [lindex $ilist 3]
	set fqversion ${version}_${revision}${variants}
	
	if { $v != "" && ![string equal ${fqversion} $v] } {
		return -code error "Active version of $name is not $v but ${fqversion}."
	}
	
	set ref [registry::open_entry $name $version $revision $variants]

	if { ![string equal [registry::property_retrieve $ref installtype] "image"] } {
		return -code error "Image error: ${name} @${fqversion} not installed as an image."
	}
	if { [registry::property_retrieve $ref active] != 1 } {
		return -code error "Image error: ${name} @${fqversion} is not active."
	} 
	if { [registry::property_retrieve $ref compact] != 0 } {
		return -code error "Image error: ${name} @${fqversion} is compactd."
	} 

	set imagedir [registry::property_retrieve $ref imagedir]

	set imagefiles [registry::port_registered $name]

	_deactivate_contents $name $imagefiles

	registry::open_file_map
	foreach file $imagefiles {
		registry::unregister_file $file
	}
	registry::write_file_map
	
	registry::property_store $ref active 0

	registry::write_entry $ref

}

proc compact {name v} {
	global UI_PREFIX

	return -code error "Image error: compact/uncompact not yet implemented."

}

proc uncompact {name v} {
	global UI_PREFIX

	return -code error "Image error: compact/uncompact not yet implemented."

}

proc _check_registry {name v} {
	global UI_PREFIX

	set ilist [registry::installed $name $v]
	if { [string equal $v ""] } {
		if { [llength $ilist] > 1 } {
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

proc _check_contents {name contents imagedir} {
	variable force

	set imagefiles [list]

	# This is big and hairy and probably could be done better.
	# First, we need to check the source file, make sure it exists
	# Then we remove the $imagedir from the path of the file in the contents
	#  list  and check to see if that file exists
	# Last, if the file exists, and belongs to another port, and force is set
	#  we remove the file from the file_map, take ownership of it, and 
	#  clobber it
	foreach fe $contents {
		if { ![file isdirectory [lindex $fe 0]] || [file type [lindex $fe 0]] == "link" } {
			set srcfile [lindex $fe 0]
			set file [string range [lindex $fe 0] [string length $imagedir] [string length [lindex $fe 0]]]

			if { ![string equal $srcfile ""] } {
				lappend imagefiles $file
			}
		}
	}

	return $imagefiles
}

proc _activate_file {srcfile dstfile} {
	# Don't recursively copy directories
	if { [file isdirectory $srcfile] && [file type $srcfile] != "link" } {
		# Don't do anything if the directory already exists.
		if { ![file isdirectory $dstfile] } {
			file mkdir $dstfile
	
			# fix attributes on the directory.
			set attributes [file attributes $srcfile]
			for {set i 0} {$i < [llength $attributes]} {incr i} {
				set opt [lindex $attributes $i]
				incr i
				set arg [lindex $attributes $i]
				file attributes $dstfile $opt $arg
			}
	
			# set mtime on installed element
			exec touch -r $srcfile $dstfile
		}
	} elseif { [file type $srcfile] == "link" } {
		file copy -force $srcfile $dstfile
	} else {
		# Try a hard link first and if that fails, a symlink
		if {[catch {compat filelinkhard $dstfile $srcfile}]} {
			ui_debug "hardlinking $srcfile to $dstfile failed, symlinking instead"
			compat filelinksymbolic $dstfile $srcfile
		}
	}
}

proc _activate_list {flist imagedir} {
	foreach file $flist {
		if { [file type ${imagedir}${file}] == "link" } {
			ui_debug "activating link: $file"
		} elseif { [file isdirectory ${imagedir}${file}] } {
			ui_debug "activating directory: $file"
		} else {
			ui_debug "activating file: $file"
		}
		_activate_file ${imagedir}${file} $file
	}
}

proc _activate_contents {name imagefiles imagedir} {
	variable force
	global macports::prefix

	set files [list]
	
	# This is big and hairy and probably could be done better.
	# First, we need to check the source file, make sure it exists
	# Then we remove the $imagedir from the path of the file in the contents
	#  list  and check to see if that file exists
	# Last, if the file exists, and belongs to another port, and force is set
	#  we remove the file from the file_map, take ownership of it, and 
	#  clobber it
	registry::open_file_map
	foreach file $imagefiles {
		set srcfile ${imagedir}${file}

		# To be able to install links, we test if we can lstat the file to figure
		# out if the source file exists (file exists will return false for symlinks on
		# files that do not exist)
		if { [catch {file lstat $srcfile dummystatvar}] } {
			return -code error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port $name."
		}

		set port [registry::file_registered $file] 

		if { $port != 0  && $force != 1 && $port != $name } {
			return -code error "Image error: $file is being used by the active $port port.  Please deactivate this port first, or use the -f flag to force the activation."
		} elseif { [file exists $file] && $force != 1 } {
			return -code error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port $name."
		} elseif { $force == 1 && [file exists $file] || $port != 0 } {
			set bakfile ${file}.mp_[clock seconds]

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
	if { [catch {set files [_activate_list $theList $imagedir] } result] } {
		ui_debug "Activation failed, rolling back."
		_deactivate_contents $name $imagefiles
		return -code error $result
	}

	#_activate_list $files $imagedir

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
			set theFile [compat filenormalize $file]
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

# End of portimage namespace
}

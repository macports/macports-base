# et:ts=4
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

package provide portimage 2.0

package require macports 1.0
package require registry2 2.0
package require registry_util 2.0
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

# Activate a "Port Image"
proc activate {name specifier optionslist} {
    global macports::prefix macports::registry.path UI_PREFIX
    array set options $optionslist

    if {[info exists options(ports_force)] && [string is true $options(ports_force)] } {
        set force 1
    } else {
        set force 0
    }

    if {$specifier != ""} {
            ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $specifier]"
    } else {
            ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s"] $name]"
    }

    registry::read {

        set requested [_check_registry $name $specifier]
        set version [$requested version]
        set revision [$requested revision]
        set variants [$requested variants]
        set specifier "${version}_$revision$variants"

        set current [registry::entry installed $name]
        if { [llength $current] > 1 } {
            foreach i $current {
                set iname [$i name]
                set iversion [$i version]
                set irevision [$i revision]
                set ivariants [$i variants]
                set ispecifier "${iversion}_$irevision$ivariants"
                if { ![string equal $specifier $ispecifier]
                        && [string equal [$i state] "installed"] } {
                    return -code error "Image error: Another version of this port ($iname @${iversion}_${irevision}${ivariants}) is already active."
                }
            }
        }

        # this shouldn't be possible
        if { ![string equal [$requested installtype] "image"] } {
            return -code error "Image error: ${name} @${version}_${revision}${variants} not installed as an image."
        }

        if { [string equal [$requested state] "active"] } {
            return -code error "Image error: ${name} @${version}_${revision}${variants} is already active."
        }

        # compaction is not yet supported
        #if { [$requested compact] != 0 } {
        #    return -code error "Image error: ${name} @${version}_${revision}${variants} is compacted."
        #}
    }

    _activate_contents $port $force
    $requested state active
}

proc deactivate {name spec optionslist} {
    global UI_PREFIX
    array set options $optionslist

    if {[info exists options(ports_force)] && [string is true $options(ports_force)] } {
        set force 1
    } else {
        set force 0
    }

    if {$spec != ""} {
            ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $spec]"
    } else {
            ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s"] $name]"
    }

    if { [string equal $name {}] } {
        throw registry::image-error "Registry error: Please specify the name of the port."
    }
    set ilist [registry::entry installed $name]
    if { [llength $ilist] == 1 } {
        set requested [lindex $ilist 0]
    } else {
        throw registry::image-error "Image error: port ${name} is not active."
    }
    set version [$requested version]
    set revision [$requested revision]
    set variants [$requested variants]
    set specifier ${version}_$revision$variants

    if { ![string equal $spec {}] && ![string equal $spec $specifier] } {
        return -code error "Active version of $name is not $spec but $specifier."
    }
    if { ![string equal [$requested installtype] "image"] } {
        return -code error "Image error: ${name} @${specifier} not installed as an image."
    }
    # this shouldn't be possible
    if { [$requested state] != "installed" } {
        return -code error "Image error: ${name} @${specifier} is not active."
    }

    # compaction not yet supported
    #if { [registry::property_retrieve $ref compact] != 0 } {
    #    return -code error "Image error: ${name} @${specifier} is compacted."
    #}

    registry::check_dependents $port $force

    set imagedir [$requested imagedir]
    set imagefiles [$requested files]

    _deactivate_contents $requested $force
    $requested state imaged
}

proc compact {name v} {
    global UI_PREFIX

    throw registry::image-error "Image error: compact/uncompact not yet implemented."
}

proc uncompact {name v} {
    global UI_PREFIX

    throw registry::image-error "Image error: compact/uncompact not yet implemented."
}

proc _check_registry {name specifier} {
    global UI_PREFIX

    if { [registry::decode_spec $specifier version revision variants] } {
        set ilist [registry::entry imaged $name $version $revision $variants]
        set valid 1
    } else {
        set valid [string equal $specifier {}]
        set ilist [registry::entry imaged $name]
    }

    if { [llength $ilist] > 1 || (!$valid && [llength $ilist] == 1) } {
        ui_msg "$UI_PREFIX [msgcat::mc "The following versions of $name are currently installed:"]"
        foreach i $ilist {
            set iname [$i name]
            set iversion [$i version]
            set irevision [$i revision]
            set ivariants [$i variants]
            if { [$i state] == "installed" } {
                ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s_%s%s (active)"] $iname $iversion $irevision $ivariants]"
            } else {
                ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s_%s%s"] $iname $iversion $irevision $ivariants]"
            }
        }
        if { $valid } {
            throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
        } else {
            throw registry::invalid "Registry error: Invalid version specified. Please specify a version as recorded in the port registry."
        }
    } else if { [llength $ilist] == 1 } {
        return [lindex $ilist 0]
    }
    throw registry::invalid "Registry error: No port of $name installed."
}

## Activates a file from an image into the filesystem. Deals with symlinks,
## directories and files.
##
## @param [in] srcfile path to file in image
## @param [in] dstfile path to activate file to
proc _activate_file {srcfile dstfile} {
    switch { [file type $srcfile] } {
        case link {
            ui_debug "activating link: $dstfile"
            file copy -force $srcfile $dstfile
        }
        case directory {
            # Don't recursively copy directories
            ui_debug "activating directory: $dstfile"
            # Don't do anything if the directory already exists.
            if { ![file isdirectory $dstfile] } {
                file mkdir $dstfile
                # copy attributes, set mtime and atime
                eval file attributes [list $dstfile] [file attributes $srcfile]
                file mtime $dstfile [file mtime $srcfile]
                file atime $dstfile [file atime $srcfile]
            }
        }
        case file {
            ui_debug "activating file: $dstfile"
            # Try a hard link first and if that fails, a symlink
            try {
                compat filelinkhard $dstfile $srcfile
            } catch {*} {
                ui_debug "hardlinking $srcfile to $dstfile failed; symlinking instead"
                compat filelinksymbolic $dstfile $srcfile
            }
        }
        default {
            # don't activate e.g. a unix socket
            ui_warning "skipped file $srcfile of unknown type [file type $srcfile]"
        }
    }
}

## Activates the contents of a port
proc _activate_contents {port force} {
    global macports::prefix

    set files [list]
    set imagedir [$port imagedir]
    set imagefiles [$port imagefiles]

    # first, ensure all files exist in the image dir
    foreach file $imagefiles {
        set srcfile $imagedir$file
        # To be able to install links, we test if we can lstat the file to
        # figure out if the source file exists (file exists will return
        # false for symlinks on files that do not exist)
        try {
            file lstat $srcfile dummystatvar
        } catch {*} {
            throw registry::image-error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port [$port name]."
        }
    }

    set baksuffix .mp_[clock seconds]
    set backups [list]

    # This is big and hairy and probably could be done better.

    # Then we remove the $imagedir from the path of the file in the contents
    #  list  and check to see if that file exists
    # Last, if the file exists, and belongs to another port, and force is set
    #  we remove the file from the file_map, take ownership of it, and
    #  clobber it
    try {
        registry::write {
            foreach file $imagefiles {
                set srcfile ${imagedir}${file}

                set owner [registry::entry owner $file]

                if { [string is true $force] } {
                    # if we're forcing the activation, then we move any existing
                    # files to a backup file, both in the filesystem and in the
                    # registry
                    if { [file exists $file] } {
                        ui_warn "File $file already exists.  Moving to: $bakfile."
                        file rename -force $file $file$baksuffix
                        lappend backups $file
                    }
                    if { $owner != {} } {
                        $owner deactivate [list $file]
                        $owner activate [list $file] [list $file$baksuffix]
                    }
                } else {
                    # if we're not forcing the activation, then we bail out if
                    # we find any files that already exist, or have entries in
                    # the registry
                    if { $owner != {} && $owner != $port } {
                        throw registry::image-error "Image error: $file is being used by the active [$owner name] port.  Please deactivate this port first, or use the -f flag to force the activation."
                    } elseif { $owner == {} && [file exists $file] } {
                        throw registry::image-error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port [$owner name]."
                    }
                }

                # Split out the filename's subpaths and add them to the
                # imagefile list.
                # We need directories first to make sure they will be there
                # before links. However, because file mkdir creates all parent
                # directories, we don't need to have them sorted from root to
                # subpaths. We do need, nevertheless, all sub paths to make sure
                # we'll set the directory attributes properly for all
                # directories.
                set directory [file dirname $file]
                while { [lsearch -exact $files $directory] == -1 } {
                    lappend files $directory
                    set directory [file dirname $directory]
                }

                # Also add the filename to the imagefile list.
                lappend files $file
            }

            # Sort the list in forward order, removing duplicates.
            # Since the list is sorted in forward order, we're sure that
            # directories are before their elements.
            # We don't have to do this as mentioned above, but it makes the
            # debug output of activate make more sense.
            set theList [lsort -increasing -unique $files]

            # Activate it, and catch errors so we can roll-back
            try {
                [$port activate $imagefiles]
                foreach file $theList {
                    _activate_file $imagedir$file $file
                }
            } catch {*} {
                ui_debug "Activation failed, rolling back."
                _deactivate_contents $port yes
                throw
            }
        }
    } catch {*} {
        # if any errors occurred, move backed-up files back to their original
        # locations, then rethrow the error. Transaction rollback will take care
        # of this in the registry.
        foreach file $backups {
            file rename -force $file$baksuffix $file
        }
        throw
    }
}

proc _deactivate_file {dstfile} {
    switch { [file type $dstfile] } {
        case link {
            ui_debug "deactivating link: $dstfile"
            file delete -- $dstfile
        }
        case directory {
            # 0 item means empty.
            if { [llength [readdir $dstfile]] == 0 } {
                ui_debug "deactivating directory: $dstfile"
                file delete -- $dstfile
            } else {
                ui_debug "$dstfile is not empty"
            }
        }
        case file {
            ui_debug "deactivating file: $dstfile"
            file delete -- $dstfile
        }
        default {
            # don't deactivate e.g. a unix socket
            ui_warning "skipped file $dstfile of unknown type [file type $dstfile]"
        }
    }
}

proc _deactivate_contents {port force} {

    set files [list]

    set realfiles [$port files]

    foreach file $realfiles {
        set owner [registry::entry owner $file]
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

            # Split out the filename's subpaths and add them to the image list
            # as well.
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

    registry::write {
        # Remove all elements.
        $port deactivate $realfiles
        foreach file $theList {
            _deactivate_file $file
        }
    }
}

# End of portimage namespace
}

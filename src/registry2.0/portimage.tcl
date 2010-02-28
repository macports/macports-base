# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portimage.tcl
# $Id$
#
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
# Copyright (c) 2002 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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

package require registry 1.0
package require registry2 2.0
package require registry_util 2.0
package require macports 1.0
package require Pextlib 1.0

set UI_PREFIX "--> "

#
# Port Images are basically just installations of the destroot of a port into
# ${macports::registry.path}/software/${name}/${version}_${revision}${variants}
# They allow the user to install multiple versions of the same port, treating
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
# For the creating and removing of links during activation and deactivation,
# code very similar to what is used in portinstall is used.
#

namespace eval portimage {

variable force 0
variable use_reg2 0

# Activate a "Port Image"
proc activate {name v optionslist} {
    global macports::prefix macports::registry.format macports::registry.path registry_open UI_PREFIX
    array set options $optionslist
    variable force
    variable use_reg2

    if {[info exists options(ports_force)] && [string is true -strict $options(ports_force)] } {
        set force 1
    }
    if {[string equal ${macports::registry.format} "receipt_sqlite"]} {
        set use_reg2 1
        if {![info exists registry_open]} {
            registry::open [file join ${macports::registry.path} registry registry.db]
            set registry_open yes
        }
    }
    set todeactivate [list]

    if {$use_reg2} {
        registry::read {

            set requested [_check_registry $name $v]
            # set name again since the one we were passed may not have had the correct case
            set name [$requested name]
            set version [$requested version]
            set revision [$requested revision]
            set variants [$requested variants]
            set specifier "${version}_${revision}${variants}"

            # if another version of this port is active, deactivate it first
            set current [registry::entry installed $name]
            if { [llength $current] > 1 } {
                foreach i $current {
                    set iversion [$i version]
                    set irevision [$i revision]
                    set ivariants [$i variants]
                    set ispecifier "${iversion}_${irevision}${ivariants}"
                    if { ![string equal $specifier $ispecifier]
                            && [string equal [$i state] "installed"] } {
                        lappend todeactivate $ispecifier
                    }
                }
            }

            # this shouldn't be possible
            if { ![string equal [$requested installtype] "image"] } {
                return -code error "Image error: ${name} @${version}_${revision}${variants} not installed as an image."
            }

            if { [string equal [$requested state] "installed"] } {
                return -code error "Image error: ${name} @${version}_${revision}${variants} is already active."
            }
        }
    } else {
        # registry1.0
        set ilist [_check_registry $name $v]
        # set name again since the one we were passed may not have had the correct case
        set name [lindex $ilist 0]
        set version [lindex $ilist 1]
        set revision [lindex $ilist 2]
        set variants [lindex $ilist 3]

        # if another version of this port is active, deactivate it first
        set ilist [registry::installed $name]
        if { [llength $ilist] > 1 } {
            foreach i $ilist {
                set iversion [lindex $i 1]
                set irevision [lindex $i 2]
                set ivariants [lindex $i 3]
                set iactive [lindex $i 4]
                if { ![string equal "${iversion}_${irevision}${ivariants}" "${version}_${revision}${variants}"] && $iactive == 1 } {
                    lappend todeactivate "${iversion}_${irevision}${ivariants}"
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
    }

    foreach a $todeactivate {
        deactivate $name $a [list ports_force 1]
    }

    if {$v != ""} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $v]"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s"] $name]"
    }

    if {$use_reg2} {
        _activate_contents $requested
        $requested state installed
    } else {
        set imagedir [registry::property_retrieve $ref imagedir]

        set contents [registry::property_retrieve $ref contents]

        set imagefiles [_check_contents $name $contents $imagedir]

        registry::open_file_map
        _activate_contents $name $imagefiles $imagedir

        registry::property_store $ref active 1

        registry::write_entry $ref

        foreach file $imagefiles {
            registry::register_file $file $name
        }
        registry::write_file_map
        registry::close_file_map
    }
}

proc deactivate {name v optionslist} {
    global UI_PREFIX macports::registry.format macports::registry.path registry_open
    array set options $optionslist
    variable use_reg2

    if {[info exists options(ports_force)] && [string is true -strict $options(ports_force)] } {
        # this not using the namespace variable is correct, since activate
        # needs to be able to force deactivate independently of whether
        # the activation is being forced
        set force 1
    } else {
        set force 0
    }
    if {[string equal ${macports::registry.format} "receipt_sqlite"]} {
        set use_reg2 1
        if {![info exists registry_open]} {
            registry::open [file join ${macports::registry.path} registry registry.db]
            set registry_open yes
        }
    }

    if {$use_reg2} {
        if { [string equal $name ""] } {
            throw registry::image-error "Registry error: Please specify the name of the port."
        }
        set ilist [registry::entry installed $name]
        if { [llength $ilist] == 1 } {
            set requested [lindex $ilist 0]
        } else {
            throw registry::image-error "Image error: port ${name} is not active."
        }
        # set name again since the one we were passed may not have had the correct case
        set name [$requested name]
        set version [$requested version]
        set revision [$requested revision]
        set variants [$requested variants]
        set specifier "${version}_${revision}${variants}"
    } else {
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
        set variants [lindex $ilist 3]
        set specifier "${version}_${revision}${variants}"
    }

    if { $v != "" && ![string equal $specifier $v] } {
        return -code error "Active version of $name is not $v but ${specifier}."
    }

    if {$v != ""} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $v]"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s"] $name]"
    }

    if {$use_reg2} {
        if { ![string equal [$requested installtype] "image"] } {
            return -code error "Image error: ${name} @${specifier} not installed as an image."
        }
        # this shouldn't be possible
        if { [$requested state] != "installed" } {
            return -code error "Image error: ${name} @${specifier} is not active."
        }

        registry::check_dependents $requested $force

        _deactivate_contents $requested {} $force
        $requested state imaged
    } else {
        set ref [registry::open_entry $name $version $revision $variants]

        if { ![string equal [registry::property_retrieve $ref installtype] "image"] } {
            return -code error "Image error: ${name} @${specifier} not installed as an image."
        }
        if { [registry::property_retrieve $ref active] != 1 } {
            return -code error "Image error: ${name} @${specifier} is not active."
        }

        registry::open_file_map
        set imagefiles [registry::port_registered $name]

        _deactivate_contents $name $imagefiles

        foreach file $imagefiles {
            registry::unregister_file $file
        }
        registry::write_file_map
        registry::close_file_map

        registry::property_store $ref active 0

        registry::write_entry $ref
    }
}

proc _check_registry {name v} {
    global UI_PREFIX macports::registry.installtype
    variable use_reg2

    if {$use_reg2} {
        if { [registry::decode_spec $v version revision variants] } {
            set ilist [registry::entry imaged $name $version $revision $variants]
            set valid 1
        } else {
            set valid [string equal $v {}]
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
        } elseif { [llength $ilist] == 1 } {
            return [lindex $ilist 0]
        }
        throw registry::invalid "Registry error: No port of $name installed."
    } else {
        # registry1.0
        set ilist [registry::installed $name $v]
        if { [string equal $v ""] && [llength $ilist] > 1 } {
            # set name again since the one we were passed may not have had the correct case
            set name [lindex [lindex $ilist 0] 0]
            ui_msg "$UI_PREFIX [msgcat::mc "The following versions of $name are currently installed:"]"
            foreach i $ilist { 
                set iname [lindex $i 0]
                set iversion [lindex $i 1]
                set irevision [lindex $i 2]
                set ivariants [lindex $i 3]
                set iactive [lindex $i 4]
                if { $iactive == 0 } {
                    ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s_%s%s"] $iname $iversion $irevision $ivariants]"
                } elseif { $iactive == 1 } {
                    ui_msg "$UI_PREFIX [format [msgcat::mc "    %s @%s_%s%s (active)"] $iname $iversion $irevision $ivariants]"
                }
            }
            return -code error "Registry error: Please specify the full version as recorded in the port registry."
        } elseif {[llength $ilist] == 1} {
            return [lindex $ilist 0]
        }
        return -code error "Registry error: No port of $name installed."
    }
}

proc _check_contents {name contents imagedir} {

    set imagefiles [list]
    set idlen [string length $imagedir]

    # generate list of activated file paths from list of paths in the image dir
    foreach fe $contents {
        set srcfile [lindex $fe 0]
        if { ![string equal $srcfile ""] && [file type $srcfile] != "directory" } {
            set file [string range $srcfile $idlen [string length $srcfile]]

            lappend imagefiles $file
        }
    }

    return $imagefiles
}

## Activates a file from an image into the filesystem. Deals with symlinks,
## directories and files.
##
## @param [in] srcfile path to file in image
## @param [in] dstfile path to activate file to
proc _activate_file {srcfile dstfile} {
    switch [file type $srcfile] {
        link {
            ui_debug "activating link: $dstfile"
            file copy -force -- $srcfile $dstfile
        }
        directory {
            # Don't recursively copy directories
            ui_debug "activating directory: $dstfile"
            # Don't do anything if the directory already exists.
            if { ![file isdirectory $dstfile] } {
                file mkdir $dstfile
                # fix attributes on the directory.
                eval file attributes {$dstfile} [file attributes $srcfile]
                # set mtime on installed element
                file mtime $dstfile [file mtime $srcfile]
            }
        }
        default {
            ui_debug "activating file: $dstfile"
            # Try a hard link first and if that fails, a symlink
            if {[catch {file link -hard $dstfile $srcfile}]} {
                ui_debug "hardlinking $srcfile to $dstfile failed, symlinking instead"
                file link -symbolic $dstfile $srcfile
            }
        }
    }
}

## Activates the contents of a port
proc _activate_contents {port {imagefiles {}} {imagedir {}}} {
    variable force
    variable use_reg2
    global macports::prefix

    set files [list]
    set baksuffix .mp_[clock seconds]
    if {$use_reg2} {
        set imagedir [$port location]
        set imagefiles [$port imagefiles]
    } else {
        set name $port
    }

    set deactivated [list]
    set backups [list]
    # This is big and hairy and probably could be done better.
    # First, we need to check the source file, make sure it exists
    # Then we remove the $imagedir from the path of the file in the contents
    #  list  and check to see if that file exists
    # Last, if the file exists, and belongs to another port, and force is set
    #  we remove the file from the file_map, take ownership of it, and
    #  clobber it
    if {$use_reg2} {
        try {
            registry::write {
                foreach file $imagefiles {
                    set srcfile "${imagedir}${file}"

                    # To be able to install links, we test if we can lstat the file to
                    # figure out if the source file exists (file exists will return
                    # false for symlinks on files that do not exist)
                    if { [catch {file lstat $srcfile dummystatvar}] } {
                        throw registry::image-error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port [$port name]."
                    }

                    set owner [registry::entry owner $file]

                    if {$owner != {} && $owner != $port} {
                        # deactivate conflicting port if it is replaced_by this one
                        set result [mportlookup [$owner name]]
                        array unset portinfo
                        array set portinfo [lindex $result 1]
                        if {[info exists portinfo(replaced_by)] && [lsearch -exact -nocase $portinfo(replaced_by) [$port name]] != -1} {
                            lappend deactivated $owner
                            # XXX this is bad, deactivate does another write transaction (probably deadlocks)
                            deactivate [$owner name] "" ""
                            set owner {}
                        }
                    }

                    if { [string is true -strict $force] } {
                        # if we're forcing the activation, then we move any existing
                        # files to a backup file, both in the filesystem and in the
                        # registry
                        if { [file exists $file] } {
                            set bakfile "${file}${baksuffix}"
                            ui_warn "File $file already exists.  Moving to: $bakfile."
                            file rename -force -- $file $bakfile
                            lappend backups $file
                        }
                        if { $owner != {} } {
                            $owner deactivate [list $file]
                            $owner activate [list $file] [list "${file}${baksuffix}"]
                        }
                    } else {
                        # if we're not forcing the activation, then we bail out if
                        # we find any files that already exist, or have entries in
                        # the registry
                        if { $owner != {} && $owner != $port } {
                            throw registry::image-error "Image error: $file is being used by the active [$owner name] port.  Please deactivate this port first, or use 'port -f activate [$port name]' to force the activation."
                        } elseif { $owner == {} && [file exists $file] } {
                            throw registry::image-error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port [$port name]. Use 'port -f activate [$port name]' to force the activation."
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
                    $port activate $imagefiles
                    foreach file $theList {
                        _activate_file "${imagedir}${file}" $file
                    }
                } catch {*} {
                    ui_debug "Activation failed, rolling back."
                    # can't do it here since we're already inside a transaction
                    set deactivate_this yes
                    throw
                }
            }
        } catch {*} {
            # roll back activation of this port
            if {[info exists deactivate_this]} {
                _deactivate_contents $port {} yes
            }
            # if any errors occurred, move backed-up files back to their original
            # locations, then rethrow the error. Transaction rollback will take care
            # of this in the registry.
            foreach file $backups {
                file rename -force -- "${file}${baksuffix}" $file
            }
            # reactivate deactivated ports
            foreach entry $deactivated {
                set pvers "[$entry version]_[$entry revision][$entry variants]"
                activate [$entry name] $pvers ""
            }
            throw
        }
    } else {
        # registry1.0
        foreach file $imagefiles {
            set srcfile "${imagedir}${file}"

            # To be able to install links, we test if we can lstat the file to
            # figure out if the source file exists (file exists will return
            # false for symlinks on files that do not exist)
            if { [catch {file lstat $srcfile dummystatvar}] } {
                return -code error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port $name."
            }

            set port [registry::file_registered $file]
            
            if {$port != 0  && $port != $name} {
                # deactivate conflicting port if it is replaced_by this one
                if {[catch {mportlookup $port} result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    return -code error "port lookup failed: $result"
                }
                array unset portinfo
                array set portinfo [lindex $result 1]
                if {[info exists portinfo(replaced_by)] && [lsearch -exact -nocase $portinfo(replaced_by) $name] != -1} {
                    lappend deactivated [lindex [registry::active $port] 0]
                    deactivate $port "" ""
                    set port 0
                }
            }
    
            if { $port != 0  && $force != 1 && $port != $name } {
                return -code error "Image error: $file is being used by the active $port port.  Please deactivate this port first, or use 'port -f activate $name' to force the activation."
            } elseif { [file exists $file] && $force != 1 } {
                return -code error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port $name. Use 'port -f activate $name' to force the activation."
            } elseif { $force == 1 && [file exists $file] || $port != 0 } {
                set bakfile "${file}${baksuffix}"

                if {[file exists $file]} {
                    ui_warn "File $file already exists.  Moving to: $bakfile."
                    file rename -force -- $file $bakfile
                    lappend backups $file
                }

                if { $port != 0 } {
                    set bakport [registry::file_registered $file]
                    registry::unregister_file $file
                    if {[file exists $bakfile]} {
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
        if { [catch { foreach file $theList {
                        _activate_file "${imagedir}${file}" $file
                    }} result]} {
            ui_debug "Activation failed, rolling back."
            _deactivate_contents $name $imagefiles
            # return backed up files to their old locations
            foreach f $backups {
                set bakfile "${f}${baksuffix}"
                set bakport [registry::file_registered $bakfile]
                if {$bakport != 0} {
                    registry::unregister_file $bakfile
                    registry::register_file $f $bakport
                }
                file rename -force -- $bakfile $file
            }
            # reactivate deactivated ports
            foreach entry $deactivated {
                set pname [lindex $entry 0]
                set pvers "[lindex $entry 1]_[lindex $entry 2][lindex $entry 3]"
                activate $pname $pvers ""
            }
            registry::write_file_map

            return -code error $result
        }
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

proc _deactivate_contents {port imagefiles {force 0}} {
    variable use_reg2
    set files [list]
    if {$use_reg2} {
        set imagefiles [$port files]
    }

    foreach file $imagefiles {
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
            # well. The realpath call is necessary because file normalize
            # does not resolve symlinks on OS X < 10.6
            set directory [realpath [file dirname $theFile]]
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
    if {$use_reg2} {
        registry::write {
            $port deactivate $imagefiles
            foreach file $theList {
                _deactivate_file $file
            }
        }
    } else {
        foreach file $theList {
            _deactivate_file $file
        }
    }
}

# End of portimage namespace
}

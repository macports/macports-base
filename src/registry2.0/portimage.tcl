# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portimage.tcl
#
# Copyright (c) 2004-2005, 2007-2018 The MacPorts Project
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

package require Tclx

# Port Images are installations of the destroot of a port into a compressed
# tarball in ${macports::registry.path}/software/${name}.
# They allow the user to install multiple versions of the same port, treating
# each revision and each different combination of variants as a "version".
#
# From there, the user can "activate" a port image.  This extracts the port's
# files from the image into the ${prefix}.  Directories are created.
# Activation checks the registry's file_map for any files which conflict with
# other "active" ports, and will not overwrite the links to the those files.
# The conflicting port must be deactivated first.
#
# The user can also "deactivate" an active port.  This will remove all the
# port's files from ${prefix}, and if any directories are empty, remove them
# as well. It will also remove all of the references of the files from the 
# registry's file_map.


namespace eval portimage {

variable force 0
variable noexec 0
variable UI_PREFIX {---> }

# takes a composite version spec rather than separate version,revision,variants
proc activate_composite {name {v ""} {optionslist ""}} {
    if {$v eq ""} {
        return [activate $name "" "" 0 $optionslist]
    } elseif {[registry::decode_spec $v version revision variants]} {
        return [activate $name $version $revision $variants $optionslist]
    }
    throw registry::invalid "Registry error: Invalid version '$v' specified for ${name}. Please specify a version as recorded in the port registry."
}

# Activate a "Port Image"
proc activate {name {version ""} {revision ""} {variants 0} {options ""}} {
    variable force
    variable noexec
    variable UI_PREFIX

    if {[dict exists $options ports_force] && [string is true -strict [dict get $options ports_force]] } {
        set force 1
    }
    if {[dict exists $options ports_activate_no-exec]} {
        set noexec [dict get $options ports_activate_no-exec]
    }
    set rename_list [list]
    if {[dict exists $options portactivate_rename_files]} {
        set rename_list [dict get $options portactivate_rename_files]
    }
    set todeactivate [list]

    registry::read {

        set requested [_check_registry $name $version $revision $variants]
        # set name again since the one we were passed may not have had the correct case
        set name [$requested name]
        set version [$requested version]
        set revision [$requested revision]
        set variants [$requested variants]
        set specifier "${version}_${revision}${variants}"
        set location [$requested location]

        if {[$requested state] eq "installed"} {
            ui_info "${name} @${specifier} is already active."
            #registry::entry close $requested
            return
        }

        # this shouldn't be possible
        if { [$requested installtype] ne "image" } {
            #registry::entry close $requested
            return -code error "Image error: ${name} @${specifier} not installed as an image."
        }
        if {![::file exists $location]} {
            #registry::entry close $requested
            return -code error "Image error: Can't find image file $location"
        }

        # if another version of this port is active, deactivate it first
        set current [registry::entry installed $name]
        foreach i $current {
            if { $specifier ne "[$i version]_[$i revision][$i variants]" } {
                lappend todeactivate $i
            } else {
                #registry::entry close $i
            }
        }
    }

    try {
        foreach a $todeactivate {
            if {$noexec || ![registry::run_target $a deactivate [list ports_nodepcheck 1]]} {
                deactivate $name [$a version] [$a revision] [$a variants] [list ports_nodepcheck 1]
            }
        }

        ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $specifier]"

        _activate_contents $requested $rename_list
    } finally {
        #registry::entry close $requested
        foreach a $todeactivate {
            # may have been closed by deactivate
            #catch {registry::entry close $a}
        }
    }
}

# takes a composite version spec rather than separate version,revision,variants
proc deactivate_composite {name {v ""} {optionslist ""}} {
    if {$v eq ""} {
        return [deactivate $name "" "" 0 $optionslist]
    } elseif {[registry::decode_spec $v version revision variants]} {
        return [deactivate $name $version $revision $variants $optionslist]
    }
    throw registry::invalid "Registry error: Invalid version '$v' specified for ${name}. Please specify a version as recorded in the port registry."
}

proc deactivate {name {version ""} {revision ""} {variants 0} {options ""}} {
    variable UI_PREFIX

    if {[dict exists $options ports_force] && [string is true -strict [dict get $options ports_force]] } {
        # this not using the namespace variable is correct, since activate
        # needs to be able to force deactivate independently of whether
        # the activation is being forced
        set force 1
    } else {
        set force 0
    }

    if {$name eq ""} {
        throw registry::image-error "Registry error: Please specify the name of the port."
    }
    set ilist [registry::entry installed $name]
    if { [llength $ilist] == 1 } {
        set requested [lindex $ilist 0]
    } else {
        set ilist [_check_registry $name $version $revision $variants 1]
        if {[llength $ilist] > 0} {
            ui_info "port ${name} is already inactive"
            #foreach i $ilist {
            #    registry::entry close $i
            #}
            return
        } else {
            set v ""
            if {$version ne ""} {
                set v " @${version}"
                if {$revision ne ""} {
                    append v _${revision}${variants}
                }
            }
            throw registry::image-error "Image error: port ${name}${v} is not active."
        }
    }
    # set name again since the one we were passed may not have had the correct case
    set name [$requested name]
    set specifier "[$requested version]_[$requested revision][$requested variants]"

    if {$version ne "" && ($version ne [$requested version] ||
        ($revision ne "" && ($revision != [$requested revision] || $variants ne [$requested variants])))} {
        set v $version
        if {$revision ne ""} {
            append v _${revision}${variants}
        }
        set ilist [_check_registry $name $version $revision $variants 1]
        foreach inact $ilist {
            if {$revision ne ""} {
                set thisv [$inact version]_[$inact revision][$inact variants]
            } else {
                set thisv [$inact version]
            }
            if {$v eq $thisv} {
                ui_info "port ${name} @${thisv} is already inactive"
                #registry::entry close $requested
                #foreach inact $ilist {
                #    registry::entry close $inact
                #}
                return
            }
        }
        #registry::entry close $requested
        #foreach inact $ilist {
        #    registry::entry close $inact
        #}
        return -code error "Active version of $name is not $v but ${specifier}."
    }

    if { [$requested installtype] ne "image" } {
        #registry::entry close $requested
        return -code error "Image error: ${name} @${specifier} not installed as an image."
    }
    # this shouldn't be possible
    if { [$requested state] ne "installed" } {
        #registry::entry close $requested
        return -code error "Image error: ${name} @${specifier} is not active."
    }

    if {![dict exists $options ports_nodepcheck] || ![string is true -strict [dict get $options ports_nodepcheck]]} {
        set retvalue [registry::check_dependents $requested $force "deactivate"]
        if {$retvalue eq "quit"} {
            #registry::entry close $requested
            return
        }
    }

    ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $specifier]"

    try {
        _deactivate_contents $requested [$requested files] $force
    } finally {
        #registry::entry close $requested
    }
}

proc _check_registry {name version revision variants {return_all 0}} {
    set searchkeys [list $name]
    set composite_spec ""
    if {$version ne ""} {
        lappend searchkeys $version
        set composite_spec $version
        # restriction imposed by underlying registry API (see entry.c):
        # if a revision is specified, so must variants be
        if {$revision ne ""} {
            lappend searchkeys $revision $variants
            append composite_spec _${revision}${variants}
        }
    }
    set ilist [registry::entry imaged {*}$searchkeys]
    if {$return_all} {
        return $ilist
    }

    if { [llength $ilist] > 1 } {
        variable UI_PREFIX
        set portilist [list]
        set msg "The following versions of $name are currently installed:"
        if {[macports::ui_isset ports_noninteractive]} {
            ui_msg "$UI_PREFIX [msgcat::mc $msg]"
        }
        foreach i $ilist {
            set portstr [format "%s @%s_%s%s" [$i name] [$i version] [$i revision] [$i variants]]
            if {[$i state] eq "installed"} {
                append portstr [msgcat::mc " (active)"]
            }

            if {[info exists macports::ui_options(questions_singlechoice)]} {
                lappend portilist "$portstr"
            } else {
                ui_msg "$UI_PREFIX     $portstr"
            }
        }
        if {[info exists macports::ui_options(questions_singlechoice)]} {
            set retindex [$macports::ui_options(questions_singlechoice) $msg "Choice_Q1" $portilist]
            set retvalue [lindex $ilist $retindex]
            #foreach i $ilist {
            #    if {$i ne $retvalue} {
            #        registry::entry close $i
            #    }
            #}
            return $retvalue
        }
        #foreach i $ilist {
        #    registry::entry close $i
        #}
        throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
    } elseif { [llength $ilist] == 1 } {
        return [lindex $ilist 0]
    }
    if {$composite_spec ne ""} {
        set composite_spec " @${composite_spec}"
    }
    throw registry::invalid "Registry error: ${name}${composite_spec} is not installed."
}

# Mapping of directory paths to device numbers. Used to check if files
# can be hardlinked or cloned, or must be copied.
variable dir_devices [dict create]

## Activates a list of files from an image into the filesystem. Deals
## with symlinks and regular files.
##
## @param [in] files list of target file paths
## @param [in] imageroot path to root of image directory
## @param [in] imageroot path to root of image directory
## @param [in] rollback_var list name to append activated files to
## @return list of files that need to be explicitly deleted if we have to roll back
proc _activate_files {srcfiles dstfiles imageroot rollback_var} {
    variable progress_step; variable progress_total_steps
    variable dir_devices; variable keep_imagedir
    upvar $rollback_var rollback_list
    set use_clone [expr {$keep_imagedir && [fs_clone_capable $imageroot]}]
    ::file stat $imageroot statinfo
    set imagedev $statinfo(dev)
    set all_attrs [expr {[getuid] == 0}]
    set hardlinks [dict create]

    foreach srcfile $srcfiles dstfile $dstfiles {
        # this can happen if the archive was built on case-sensitive and we're case-insensitive
        # we know any existing dstfile is ours because we checked for conflicts earlier
        if {![catch {::file type $dstfile}]} {
            ui_debug "skipping case-conflicting file: $srcfile"
            continue
        }
        ui_debug "activating file: $dstfile"
        set hardlinked 0
        ::file lstat $srcfile statinfo
        if {$statinfo(nlink) > 1} {
            # Hard linked file
            if {[dict exists $hardlinks $statinfo(ino)]} {
                # Link to the primary link
                if {![catch {::file link -hard $dstfile [dict get $hardlinks $statinfo(ino)]}]} {
                    set hardlinked 1
                }
                # Fall back to normal method if hardlinking failed. The destinations
                # for the links could be on different devices, or a destination
                # filesystem might not even support hard links.
            } else {
                # Set this as the primary link and activate as normal.
                dict set hardlinks $statinfo(ino) $dstfile
            }
        }
        if {!$hardlinked} {
            if {$use_clone && [dict get $dir_devices [::file dirname $dstfile]] == $imagedev} {
                clonefile $srcfile $dstfile
                # not all permissions are preserved by clonefile
                if {$statinfo(type) ne "link"} {
                    ::file attributes $dstfile -permissions {*}[::file attributes $srcfile -permissions]
                }
            } elseif {$keep_imagedir} {
                ::file copy $srcfile $dstfile
                if {$statinfo(type) ne "link"} {
                    if {$all_attrs} {
                        ::file attributes $dstfile {*}[::file attributes ${srcfile}]
                    } else {
                        # not root, so can't set owner/group
                        ::file attributes $dstfile -permissions {*}[::file attributes ${srcfile} -permissions]
                    }
                    ::file mtime $dstfile [::file mtime $srcfile]
                }
            } else {
                ::file rename $srcfile $dstfile
            }
        }
        lappend rollback_list $dstfile

        _progress update $progress_step $progress_total_steps
        incr progress_step
    }
}

## Activates a directory from an image into the filesystem.
##
## @param [in] dirs list of destination directory paths
## @param [in] imageroot path to root of image directory
proc _activate_directories {dirs imageroot} {
    variable progress_step; variable progress_total_steps
    variable dir_devices
    set all_attrs [expr {[getuid] == 0}]
    foreach dir $dirs {
        ui_debug "activating directory: $dir"
        # Don't do anything if the directory already exists.
        if {![::file isdirectory $dir]} {
            ::file mkdir $dir
            set srcdir ${imageroot}${dir}
            # fix attributes on the directory.
            if {$all_attrs} {
                ::file attributes $dir {*}[::file attributes ${srcdir}]
            } else {
                # not root, so can't set owner/group
                ::file attributes $dir -permissions {*}[::file attributes ${srcdir} -permissions]
            }
            # set mtime on installed element
            ::file mtime $dir [::file mtime ${srcdir}]
        }
        if {![dict exists $dir_devices $dir]} {
            ::file stat $dir statinfo
            dict set dir_devices $dir $statinfo(dev)
        }
        _progress update $progress_step $progress_total_steps
        incr progress_step
    }
}

# extract an archive to a directory
# returns: path to the extracted directory
proc extract_archive_to_imagedir {location} {
    set extractdir [file rootname $location]
    if {[file exists $extractdir]} {
        set extractdir [mkdtemp ${extractdir}XXXXXXXX]
    } else {
        file mkdir $extractdir
    }
    set startpwd [pwd]

    try {
        if {[catch {cd $extractdir} err]} {
            throw MACPORTS $err
        }

        # clagged straight from unarchive... this really needs to be factored
        # out, but it's a little tricky as the places where it's used run in
        # different interpreter contexts with access to different packages.
        set unarchive.cmd {}
        set unarchive.pre_args {}
        set unarchive.args {}
        set unarchive.pipe_cmd ""
        set unarchive.type [::file extension $location]
        switch -regex ${unarchive.type} {
            aar {
                set aa "aa"
                if {[catch {set aa [macports::findBinary $aa ${macports::autoconf::aa_path}]} errmsg] == 0} {
                    ui_debug "Using $aa"
                    set unarchive.cmd "$aa"
                    set unarchive.pre_args {extract -afsc-all -enable-dedup -enable-holes -v}
                    set unarchive.args "-i [macports::shellescape ${location}]"
                } else {
                    ui_debug $errmsg
                    return -code error "No '$aa' was found on this system!"
                }
            }
            cp(io|gz) {
                set pax "pax"
                if {[catch {set pax [macports::findBinary $pax ${macports::autoconf::pax_path}]} errmsg] == 0} {
                    ui_debug "Using $pax"
                    set unarchive.cmd "$pax"
                    if {[geteuid] == 0} {
                        set unarchive.pre_args {-r -v -p e}
                    } else {
                        set unarchive.pre_args {-r -v -p p}
                    }
                    if {[regexp {z$} ${unarchive.type}]} {
                        set unarchive.args {.}
                        set gzip "gzip"
                        if {[catch {set gzip [macports::findBinary $gzip ${macports::autoconf::gzip_path}]} errmsg] == 0} {
                            ui_debug "Using $gzip"
                            set unarchive.pipe_cmd "$gzip -d -c [macports::shellescape ${location}] |"
                        } else {
                            ui_debug $errmsg
                            throw MACPORTS "No '$gzip' was found on this system!"
                        }
                    } else {
                        set unarchive.args "-f [macports::shellescape ${location}] ."
                    }
                } else {
                    ui_debug $errmsg
                    throw MACPORTS "No '$pax' was found on this system!"
                }
            }
            t(ar|bz|lz|xz|gz) {
                # Opportunistic HFS compression. bsdtar will automatically
                # disable this if filesystem does not support compression.
                # Don't use if not running as root, due to bugs:
                # The system bsdtar on 10.15 suffers from https://github.com/libarchive/libarchive/issues/497
                # Later versions fixed that problem but another remains: https://github.com/libarchive/libarchive/issues/1415 
                global macports::hfscompression
                if {${hfscompression} && [getuid] == 0 &&
                        ![catch {macports::binaryInPath bsdtar}] &&
                        ![catch {exec bsdtar -x --hfsCompression < /dev/null >& /dev/null}]} {
                    ui_debug "Using bsdtar with HFS+ compression (if valid)"
                    set unarchive.cmd "bsdtar"
                    set unarchive.pre_args {-xvp --hfsCompression -f}
                } else {
                    set tar "tar"
                    if {[catch {set tar [macports::findBinary $tar ${macports::autoconf::tar_path}]} errmsg]} {
                        ui_debug $errmsg
                        throw MACPORTS "No '$tar' was found on this system!"
                    }
                    ui_debug "Using $tar"
                    set unarchive.cmd "$tar"
                    set unarchive.pre_args {-xvpf}
                }

                if {[regexp {z2?$} ${unarchive.type}]} {
                    set unarchive.args {-}
                    if {[regexp {bz2?$} ${unarchive.type}]} {
                        if {![catch {macports::binaryInPath lbzip2}]} {
                            set gzip "lbzip2"
                        } elseif {![catch {macports::binaryInPath pbzip2}]} {
                            set gzip "pbzip2"
                        } else {
                            set gzip "bzip2"
                        }
                    } elseif {[regexp {lz$} ${unarchive.type}]} {
                        set gzip "lzma"
                    } elseif {[regexp {xz$} ${unarchive.type}]} {
                        set gzip "xz"
                    } else {
                        set gzip "gzip"
                    }
                    if {[info exists macports::autoconf::${gzip}_path]} {
                        set hint [set macports::autoconf::${gzip}_path]
                    } else {
                        set hint ""
                    }
                    if {[catch {set gzip [macports::findBinary $gzip $hint]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set unarchive.pipe_cmd "$gzip -d -c [macports::shellescape ${location}] |"
                    } else {
                        ui_debug $errmsg
                        throw MACPORTS "No '$gzip' was found on this system!"
                    }
                } else {
                    set unarchive.args [macports::shellescape ${location}]
                }
            }
            xar {
                set xar "xar"
                if {[catch {set xar [macports::findBinary $xar ${macports::autoconf::xar_path}]} errmsg] == 0} {
                    ui_debug "Using $xar"
                    set unarchive.cmd "$xar"
                    set unarchive.pre_args {-xvpf}
                    set unarchive.args [macports::shellescape ${location}]
                } else {
                    ui_debug $errmsg
                    throw MACPORTS "No '$xar' was found on this system!"
                }
            }
            zip {
                set unzip "unzip"
                if {[catch {set unzip [macports::findBinary $unzip ${macports::autoconf::unzip_path}]} errmsg] == 0} {
                    ui_debug "Using $unzip"
                    set unarchive.cmd "$unzip"
                    if {[geteuid] == 0} {
                        set unarchive.pre_args {-oX}
                    } else {
                        set unarchive.pre_args {-o}
                    }
                    set unarchive.args "[macports::shellescape ${location}] -d ."
                } else {
                    ui_debug $errmsg
                    throw MACPORTS "No '$unzip' was found on this system!"
                }
            }
            default {
                throw MACPORTS "Unsupported port archive type '${unarchive.type}'!"
            }
        }

        # and finally, reinvent command_exec
        if {${unarchive.pipe_cmd} eq ""} {
            set cmdstring "${unarchive.cmd} ${unarchive.pre_args} ${unarchive.args}"
        } else {
            set cmdstring "${unarchive.pipe_cmd} ( ${unarchive.cmd} ${unarchive.pre_args} ${unarchive.args} )"
        }
        system -callback portimage::_extract_progress $cmdstring
    } on error {_ eOptions} {
        ::file delete -force $extractdir
        throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
    } finally {
        cd $startpwd
    }

    return $extractdir
}

proc _extract_progress {event} {
    variable progress_step
    variable progress_total_steps

    switch -- [dict get $event type] {
        exec {
            set progress_step 0
            _progress start
        }
        stdin {
            set line [string trimright [dict get $event line]]

            # We only want to count files, not directories. Additionally,
            # filter MacPorts metadata files that start with "+".

            #   directories                        bsdtar output for metadata             gnutar output for metadata
            if {[string index $line end] == "/" || [string range $line 0 4] eq "x ./+" || [string range $line 0 2] eq "./+"} {
                return
            }

            incr progress_step
            _progress update $progress_step $progress_total_steps
        }
        exit {
            # no cleanup, we pick up the progress where this one ended
        }
    }
}

proc _progress {args} {
    if {[macports::ui_isset ports_verbose]} {
        return
    }

    ui_progress_generic {*}${args}
}

proc _get_port_conflicts {port} {
    global registry::tdbc_connection
    if {![info exists tdbc_connection]} {
        registry::tdbc_connect
    }
    variable conflicts_stmt
    if {![info exists conflicts_stmt]} {
        set query {SELECT files.id, files.path, files.actual_path FROM
                (SELECT path FROM files where id = :thisport_id)
                AS thisport_files
                INNER JOIN files ON thisport_files.path = files.actual_path
                WHERE files.active = 1}
        set conflicts_stmt [$tdbc_connection prepare $query]
    }

    set thisport_id [$port id]
    $tdbc_connection transaction {
        set results [$conflicts_stmt execute]
    }
    set id_to_port [dict create]
    set path_to_port [dict create]
    set port_to_paths [dict create]
    set is_replaced [dict create]
    set todeactivate [dict create]
    set thisport_name [$port name]
    foreach result [$results allrows] {
        set id [dict get $result id]
        if {![dict exists $id_to_port $id]} {
            dict set id_to_port $id [lindex [registry::entry search id $id] 0]
        }
        set conflicting_port [dict get $id_to_port $id]
        if {![dict exists $is_replaced $conflicting_port]} {
            lassign [mportlookup [$conflicting_port name]] _ portinfo
            if {[dict exists $portinfo replaced_by] && [lsearch -exact -nocase [dict get $portinfo replaced_by] $thisport_name] != -1} {
                dict set is_replaced $conflicting_port 1
                dict set todeactivate $conflicting_port 1
            } else {
                dict set is_replaced $conflicting_port 0
            }
        }
        set actual_path [dict get $result actual_path]
        dict set path_to_port $actual_path $conflicting_port
        if {![dict get $is_replaced $conflicting_port]} {
            set imagepath [dict get $result path]
            dict lappend port_to_paths $conflicting_port [list $imagepath $actual_path]
        }
    }
    $results close
    return [list $path_to_port $port_to_paths $todeactivate]
}

## Activates the contents of a port
proc _activate_contents {port {rename_list {}}} {
    variable force
    variable noexec
    variable keep_archive
    variable keep_imagedir
    variable progress_step
    variable progress_total_steps

    set files [list]
    set baksuffix .mp_[clock seconds]
    set portname [$port name]
    set location [$port location]
    set imagefiles [$port imagefiles]
    set num_imagefiles [llength $imagefiles]

    set progress_step 0
    if {[::file isfile $location]} {
        set progress_total_steps [expr {$num_imagefiles * 3}]
        set extracted_dir [extract_archive_to_imagedir $location]
        # extract phase complete, assume 1/3 is done
        set progress_step $num_imagefiles
        if {!$keep_archive} {
            registry::write {
                $port location $extracted_dir
            }
            file delete $location
            set location $extracted_dir
        }
    } else {
        set extracted_dir $location
        set progress_total_steps [expr {$num_imagefiles * 2}]
        _progress start
    }

    set backups [list]
    set seendirs [dict create]
    set confirmed_rename_list [list]
    # This is big and hairy and probably could be done better.
    # First, we need to check the source file, make sure it exists
    # Then we remove the $location from the path of the file in the contents
    #  list  and check to see if that file exists
    # Last, if the file exists, and belongs to another port, and force is set
    #  we remove the file from the file_map, take ownership of it, and
    #  clobber it
    set todeactivate [dict create]
    try {
        registry::write {
            foreach file $imagefiles {
                incr progress_step
                _progress update $progress_step $progress_total_steps
                set srcfile "${extracted_dir}${file}"

                # To be able to install links, we test if 'file type' errors to
                # figure out if the source file exists (file exists will return
                # false for symlinks on files that do not exist)
                if {[catch {::file type $srcfile}]} {
                    throw registry::image-error "Image error: Source file $srcfile does not appear to exist.  Unable to activate port ${portname}."
                }

                if {![catch {::file type $file}]} {
                    if {![info exists conflicts_path_to_port]} {
                        # Check for conflicting ports. 'todeactivate' contains ports replaced by this one,
                        # which we'll deactivate later, but before activating our files.
                        lassign [_get_port_conflicts $port] conflicts_path_to_port conflicts_port_to_paths todeactivate
                        if {!$force && [dict size $conflicts_port_to_paths] > 0} {
                            set msg "The following ports have active files that conflict with ${portname}'s:\n"
                            foreach conflicting_port [dict keys $conflicts_port_to_paths] {
                                append msg "[$conflicting_port name] @[$conflicting_port version]_[$conflicting_port revision][$conflicting_port variants]\n"
                                set conflicting_paths [dict get $conflicts_port_to_paths $conflicting_port]
                                set pathcounter 0
                                set pathtotal [llength $conflicting_paths]
                                foreach p $conflicting_paths {
                                    if {$pathcounter >= 3 && $pathtotal > 4} {
                                        append msg "  (... [expr {$pathtotal - $pathcounter}] more not shown)\n"
                                        break
                                    }
                                    append msg "  [lindex $p 1]\n"
                                    incr pathcounter
                                }
                            }
                            append msg "Image error: Conflicting file(s) present. Please deactivate the conflicting port(s) first, or use 'port -f activate $portname' to force the activation."
                            throw registry::image-error $msg
                        }
                    }
                    if {[dict exists $conflicts_path_to_port $file]} {
                        set owner [dict get $conflicts_path_to_port $file]
                    } else {
                        set owner {}
                    }
                    if {$owner eq {} || ![dict exists $todeactivate $owner]} {
                        if {$force} {
                            # if we're forcing the activation, then we move any existing
                            # files to a backup file, both in the filesystem and in the
                            # registry
                            if {$owner ne {}} {
                                # Rename all conflicting files for this owner.
                                set owner_deactivate_paths [list]
                                set owner_activate_paths [list]
                                set owner_backup_paths [list]
                                foreach pathpair [dict get $conflicts_port_to_paths $owner] {
                                    lassign $pathpair path actual_path
                                    lappend owner_deactivate_paths $path
                                    if {![catch {::file type $actual_path}]} {
                                        lappend owner_activate_paths $path
                                        set bakfile ${actual_path}${baksuffix}
                                        lappend owner_backup_paths $bakfile
                                        ui_warn "File $actual_path already exists.  Moving to: $bakfile."
                                        ::file rename -force -- $actual_path $bakfile
                                        lappend backups $actual_path
                                    }
                                }
                                $owner deactivate $owner_deactivate_paths
                                $owner activate $owner_activate_paths $owner_backup_paths
                            } else {
                                # Just rename this file.
                                set bakfile ${file}${baksuffix}
                                _progress intermission
                                ui_warn "File $file already exists.  Moving to: $bakfile."
                                ::file rename -force -- $file $bakfile
                                lappend backups $file
                            }
                        } else {
                            # if we're not forcing the activation, then we bail out if
                            # we find any files that already exist
                            set msg "Image error: $file already exists and does not belong to a registered port.  Unable to activate port ${portname}. Use 'port -f activate $portname' to force the activation."
                            throw registry::image-error $msg
                        }
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
                set directory [::file dirname $file]
                while {![dict exists $seendirs $directory]} {
                    dict set seendirs $directory 1
                    # Any add here will mean an additional step in the second
                    # phase of activation. We could just update this once after
                    # this foreach loop is complete, but that could make the
                    # progress bar jump from 66 % down to 65. Doing it
                    # incrementally here will hopefully hide the increase in
                    # noise.
                    incr progress_total_steps
                    set directory [::file dirname $directory]
                }

                # Also add the filename to the normal or renamed list.
                if {[dict exists $rename_list $file]} {
                    lappend confirmed_rename_list $file [dict get $rename_list $file]
                } else {
                    lappend files $file
                }
            }
        }
        set directories [dict keys $seendirs]
        unset seendirs

        # deactivate ports replaced_by this one
        set deactivate_options [dict create ports_nodepcheck 1]
        foreach owner [dict keys $todeactivate] {
            _progress intermission
            if {$noexec || ![registry::run_target $owner deactivate $deactivate_options]} {
                deactivate [$owner name] "" "" 0 $deactivate_options
            }
        }

        # Sort the list in forward order, removing duplicates.
        # Since the list is sorted in forward order, we're sure that
        # parent directories are before their elements.
        # We don't have to do this as mentioned above, but it makes the
        # debug output of activate make more sense.
        set directories [lsort -increasing -unique $directories]

        set rollback_filelist [list]

        registry::write {
            # Activate it, and catch errors so we can roll-back

            try {
                $port activate $imagefiles
                _activate_directories $directories $extracted_dir
                _activate_files [lmap f $files {string cat ${extracted_dir}${f}}] \
                                $files $extracted_dir rollback_filelist
                foreach {src dest} $confirmed_rename_list {
                    $port deactivate [list $src]
                    $port activate [list $src] [list $dest]
                }
                _activate_files [lmap {src _} $confirmed_rename_list {string cat ${extracted_dir}${src}}] \
                                [lmap {_ dst} $confirmed_rename_list {set dst}] \
                                $extracted_dir rollback_filelist

                # Recording that the port has been activated should be done
                # here so that this information cannot be inconsistent with the
                # state of the files on disk.
                $port state installed

                _progress finish
            } trap {POSIX SIG SIGINT} {_ eOptions} {
                # Pressing ^C will (often?) print "^C" to the terminal; send
                # a linebreak so our message appears after that.
                _progress intermission
                ui_msg ""
                ui_msg "Control-C pressed, rolling back, please wait."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } trap {POSIX SIG SIGTERM} {_ eOptions} {
                _progress intermission
                ui_msg "SIGTERM received, rolling back, please wait."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } on error {_ eOptions} {
                ui_debug "Activation failed, rolling back."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            }
        }
    } on error {_ eOptions} {
        # This code must run to completion, or the installation might be left
        # in an inconsistent state. We store the old signal handling state,
        # block the critical signals and restore to the previous state instead
        # of unblocking.
        # Note that this still contains a race condition: A user could press ^C
        # fast enough so that the second error arrives before the error is
        # caught, re-thrown and re-caught here. As far as I can see, there's no
        # easy way around this problem.
        set osignals [signal get {TERM INT}]
        try {
            # Block signals to avoid inconsistiencies.
            signal block {TERM INT}

            # roll back activation of this port
            if {[info exists deactivate_this]} {
                _deactivate_contents $port $rollback_filelist yes yes
            }
            # if any errors occurred, move backed-up files back to their original
            # locations, then rethrow the error. Transaction rollback will take care
            # of this in the registry.
            foreach file $backups {
                ::file rename -force -- "${file}${baksuffix}" $file
            }
            # reactivate deactivated ports
            foreach entry [dict keys $todeactivate] {
                if {[$entry state] eq "imaged" && ($noexec || ![registry::run_target $entry activate ""])} {
                    activate [$entry name] [$entry version] [$entry revision] [$entry variants] [dict create ports_activate_no-exec $noexec]
                }
            }
        } finally {
            # We've completed all critical operations, re-enable the TERM and
            # INT signals.
            signal set $osignals
        }

        throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
    } finally {
        #foreach entry [dict keys $todeactivate] {
        #    registry::entry close $entry
        #}
        # Only delete extracted dir if there is an archive to re-extract from
        if {!$keep_imagedir && [file isfile $location]} {
            # remove temp image dir
            ::file delete -force $extracted_dir
        }
    }
}

# These directories should not be removed during deactivation even if they are empty.
# TODO: look into what other dirs should go here
variable precious_dirs [dict create /Library/LaunchDaemons 1 /Library/LaunchAgents 1]

# Delete the given lists of files and directories, calling _progress
# update for each one. Nonempty directories are skipped.
proc _deactivate_files {files directories progress_count progress_total} {
    foreach dstfile $files {
        ui_debug "deactivating file: $dstfile"
        ::file delete -- $dstfile
        incr progress_count
        _progress update $progress_count $progress_total
    }
    foreach dstdir $directories {
        if {[dirempty $dstdir]} {
            ui_debug "deactivating directory: $dstdir"
            ::file delete -- $dstdir
        } else {
            ui_debug "$dstdir is not empty"
        }
        incr progress_count
        _progress update $progress_count $progress_total
    }
}

proc _deactivate_contents {port imagefiles {force 0} {rollback 0}} {
    set files [list]

    # these are only used locally, so it is *not* a mistake that there is no
    # 'variable' declaration here
    set progress_step 0
    set progress_total_steps [expr {[llength $imagefiles] * 2}]

    _progress start

    set seendirs [dict create]
    variable precious_dirs
    foreach file $imagefiles {
        incr progress_step
        _progress update $progress_step $progress_total_steps
        if { [::file exists $file] || (![catch {::file type $file} ft] && $ft eq "link") } {
            # Normalize the file path to avoid removing the intermediate
            # symlinks (remove the empty directories instead)
            # Remark: paths in the registry may be not normalized.
            # This is not really a problem and it is in fact preferable.
            # Indeed, if I change the activate code to include normalized paths
            # instead of the paths we currently have, users' registry won't
            # match and activate will say that some file exists but doesn't
            # belong to any port.
            # The custom realpath proc is necessary because file normalize
            # does not resolve symlinks on Mac OS X < 10.6
            set directory [realpath [::file dirname $file]]
            lappend files [::file join $directory [::file tail $file]]

            # Split out the filename's subpaths and add them to the image list
            # as well.
            while {![dict exists $seendirs $directory]} {
                if {[dict exists $precious_dirs $directory]} {
                    dict set seendirs $directory 0
                    ui_debug "directory $directory does not belong to us"
                    break
                }
                dict set seendirs $directory 1
                incr progress_total_steps
                set directory [::file dirname $directory]
            }
        } else {
            ui_debug "$file does not exist."
        }
    }
    set directories [dict keys [dict filter $seendirs value 1]]
    unset seendirs

    # Sort the list in reverse order, removing duplicates.
    # Since the list is sorted in reverse order, we're sure that
    # parent directories are after their elements.
    set directories [lsort -decreasing -unique $directories]

    set progress_total_steps [expr {[llength $imagefiles] + [llength $files] + [llength $directories]}]

    # Avoid interruptions while removing the files and updating the database to
    # prevent inconsistencies from forming between filesystem and database.
    set osignals [signal get {TERM INT}]

    try {
        # Block the TERM and INT signals to avoid being interrupted. Note that
        # they might already be block at this point because
        # _deactivate_contents might be called during rollback of
        # _activate_contents, but because we're storing the old signal state
        # and returning to that instead of unblocking it doesn't matter.
        signal block {TERM INT}

        # Remove all elements.
        if {!$rollback} {
            registry::write {
                $port deactivate $imagefiles

                _deactivate_files $files $directories $progress_step $progress_total_steps

                # Update the port's state in the same transaction as the file
                # delete operations.
                $port state imaged
            }
        } else {
           _deactivate_files $files $directories $progress_step $progress_total_steps
        }
    } finally {
        # restore the signal block state
        signal set $osignals
        _progress finish
    }
}

# Create a new registry entry using the given metadata dictionary
proc install {metadata} {
    global macports::registry.path
    registry::write {
        # store portfile
        set portfile_path [dict get $metadata portfile_path]
        set portfile_sha256 [sha256 file $portfile_path]
        set portfile_size [file size $portfile_path]
        set portfile_reg_dir [file join ${registry.path} registry portfiles [dict get $metadata name]-[dict get $metadata version]_[dict get $metadata revision] ${portfile_sha256}-${portfile_size}]
        set portfile_reg_path ${portfile_reg_dir}/Portfile
        file mkdir $portfile_reg_dir
        if {![file isfile $portfile_reg_path] || [file size $portfile_reg_path] != $portfile_size
                || [sha256 file $portfile_reg_path] ne $portfile_sha256} {
            file copy -force $portfile_path $portfile_reg_dir
            file attributes $portfile_reg_path -permissions 0644
        }

        # store portgroups
        if {[dict exists $metadata portgroups]} {
            foreach {pgname pgversion groupFile} [dict get $metadata portgroups] {
                set pgsha256 [sha256 file $groupFile]
                set pgsize [file size $groupFile]
                set pg_reg_dir [file join ${registry.path} registry portgroups ${pgsha256}-${pgsize}]
                set pg_reg_path ${pg_reg_dir}/${pgname}-${pgversion}.tcl
                lappend portgroups [list $pgname $pgversion $pgsha256 $pgsize]
                if {![file isfile $pg_reg_path] || [file size $pg_reg_path] != $pgsize || [sha256 file $pg_reg_path] ne $pgsha256} {
                    file mkdir $pg_reg_dir
                    file copy -force $groupFile $pg_reg_dir
                }
                file attributes $pg_reg_path -permissions 0644
            }
            dict unset metadata portgroups
        }

        set regref [registry::entry create [dict get $metadata name] [dict get $metadata version] [dict get $metadata revision] [dict get $metadata variants] [dict get $metadata epoch]]
        $regref installtype image
        $regref state imaged
        $regref portfile ${portfile_sha256}-${portfile_size}
        if {[info exists portgroups]} {
            foreach p $portgroups {
                $regref addgroup {*}$p
            }
        }
        foreach dep_portname [dict get $metadata depends] {
            $regref depends $dep_portname
        }
        if {[dict exists $metadata files]} {
            # register files
            $regref map [dict get $metadata files]
            dict unset metadata files
        }
        if {[dict exists $metadata binary]} {
            dict for {f isbinary} [dict get $metadata binary] {
                set fileref [registry::file open [$regref id] $f]
                $fileref binary $isbinary
                registry::file close $fileref
            }
            dict unset metadata binary
        }
        foreach key {name version revision variants epoch depends portfile_path} {
            dict unset metadata $key
        }

        # remaining metadata maps directly to reg entry fields
        dict for {key val} $metadata {
            $regref $key $val
        }
    }
}

# End of portimage namespace
}

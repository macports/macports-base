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

set UI_PREFIX "--> "

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
proc activate {name {version ""} {revision ""} {variants 0} {optionslist ""}} {
    global macports::registry.path registry_open UI_PREFIX
    array set options $optionslist
    variable force
    variable noexec

    if {[info exists options(ports_force)] && [string is true -strict $options(ports_force)] } {
        set force 1
    }
    if {[info exists options(ports_activate_no-exec)]} {
        set noexec $options(ports_activate_no-exec)
    }
    set rename_list [list]
    if {[info exists options(portactivate_rename_files)]} {
        set rename_list $options(portactivate_rename_files)
    }
    if {![info exists registry_open]} {
        registry::open [::file join ${macports::registry.path} registry registry.db]
        set registry_open yes
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
            return
        }

        # if another version of this port is active, deactivate it first
        set current [registry::entry installed $name]
        foreach i $current {
            if { $specifier ne "[$i version]_[$i revision][$i variants]" } {
                lappend todeactivate $i
            }
        }

        # this shouldn't be possible
        if { [$requested installtype] ne "image" } {
            return -code error "Image error: ${name} @${specifier} not installed as an image."
        }
        if {![::file isfile $location]} {
            return -code error "Image error: Can't find image file $location"
        }
    }
    foreach a $todeactivate {
        if {$noexec || ![registry::run_target $a deactivate [list ports_nodepcheck 1]]} {
            deactivate $name [$a version] [$a revision] [$a variants] [list ports_nodepcheck 1]
        }
    }

    ui_msg "$UI_PREFIX [format [msgcat::mc "Activating %s @%s"] $name $specifier]"

    _activate_contents $requested $rename_list
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

proc deactivate {name {version ""} {revision ""} {variants 0} {optionslist ""}} {
    global UI_PREFIX macports::registry.path registry_open
    array set options $optionslist

    if {[info exists options(ports_force)] && [string is true -strict $options(ports_force)] } {
        # this not using the namespace variable is correct, since activate
        # needs to be able to force deactivate independently of whether
        # the activation is being forced
        set force 1
    } else {
        set force 0
    }
    if {![info exists registry_open]} {
        registry::open [::file join ${macports::registry.path} registry registry.db]
        set registry_open yes
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
                return
            }
        }
        return -code error "Active version of $name is not $v but ${specifier}."
    }

    if { [$requested installtype] ne "image" } {
        return -code error "Image error: ${name} @${specifier} not installed as an image."
    }
    # this shouldn't be possible
    if { [$requested state] ne "installed" } {
        return -code error "Image error: ${name} @${specifier} is not active."
    }
	
    if {![info exists options(ports_nodepcheck)] || ![string is true -strict $options(ports_nodepcheck)]} {
        set retvalue [registry::check_dependents $requested $force "deactivate"]
        if {$retvalue eq "quit"} {
            return
        }
    }

    ui_msg "$UI_PREFIX [format [msgcat::mc "Deactivating %s @%s"] $name $specifier]"
	
    _deactivate_contents $requested [$requested files] $force
}

proc _check_registry {name version revision variants {return_all 0}} {
    global UI_PREFIX

    set searchkeys $name
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
            set retvalue [$macports::ui_options(questions_singlechoice) $msg "Choice_Q1" $portilist]
            return [lindex $ilist $retvalue]
        }
        throw registry::invalid "Registry error: Please specify the full version as recorded in the port registry."
    } elseif { [llength $ilist] == 1 } {
        return [lindex $ilist 0]
    }
    if {$composite_spec ne ""} {
        set composite_spec " @${composite_spec}"
    }
    throw registry::invalid "Registry error: ${name}${composite_spec} is not installed."
}

## Activates a file from an image into the filesystem. Deals with symlinks,
## directories and files.
##
## @param [in] srcfile path to file in image
## @param [in] dstfile path to activate file to
## @return 1 if file needs to be explicitly deleted if we have to roll back, 0 otherwise
proc _activate_file {srcfile dstfile} {
    if {[catch {set filetype [::file type $srcfile]} result]} {
        # this can happen if the archive was built on case-sensitive and we're case-insensitive
        # we know any existing dstfile is ours because we checked for conflicts earlier
        if {![catch {file type $dstfile}]} {
            ui_debug "skipping case-conflicting file: $srcfile"
            return 0
        } else {
            error $result
        }
    }
    switch $filetype {
        directory {
            # Don't recursively copy directories
            ui_debug "activating directory: $dstfile"
            # Don't do anything if the directory already exists.
            if { ![::file isdirectory $dstfile] } {
                ::file mkdir $dstfile
                # fix attributes on the directory.
                if {[getuid] == 0} {
                    ::file attributes $dstfile {*}[::file attributes $srcfile]
                } else {
                    # not root, so can't set owner/group
                    ::file attributes $dstfile -permissions {*}[::file attributes $srcfile -permissions]
                }
                # set mtime on installed element
                ::file mtime $dstfile [::file mtime $srcfile]
            }
            return 0
        }
        default {
            ui_debug "activating file: $dstfile"
            ::file rename $srcfile $dstfile
            return 1
        }
    }
}

# extract an archive to a temporary location
# returns: path to the extracted directory
proc extract_archive_to_tmpdir {location} {
    set extractdir [mkdtemp [::file dirname $location]/mpextractXXXXXXXX]
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
                global macports::hfscompression
                # Opportunistic HFS compression. bsdtar will automatically
                # disable this if filesystem does not support compression.
                # Don't use if not running as root, due to bugs:
                # The system bsdtar on 10.15 suffers from https://github.com/libarchive/libarchive/issues/497
                # Later versions fixed that problem but another remains: https://github.com/libarchive/libarchive/issues/1415 
                if {${macports::hfscompression} && [getuid] == 0 &&
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
        system $cmdstring
    } catch {*} {
        ::file delete -force $extractdir
        throw
    } finally {
        cd $startpwd
    }

    return $extractdir
}

## Activates the contents of a port
proc _activate_contents {port {rename_list {}}} {
    variable force
    variable noexec

    set files [list]
    set baksuffix .mp_[clock seconds]
    set location [$port location]
    set imagefiles [$port imagefiles]
    set extracted_dir [extract_archive_to_tmpdir $location]
    set replaced_by_re "(?i)^[$port name]\$"

    set backups [list]
    # This is big and hairy and probably could be done better.
    # First, we need to check the source file, make sure it exists
    # Then we remove the $location from the path of the file in the contents
    #  list  and check to see if that file exists
    # Last, if the file exists, and belongs to another port, and force is set
    #  we remove the file from the file_map, take ownership of it, and
    #  clobber it
    array set todeactivate {}
    try {
        registry::write {
            foreach file $imagefiles {
                set srcfile "${extracted_dir}${file}"

                # To be able to install links, we test if we can lstat the file to
                # figure out if the source file exists (file exists will return
                # false for symlinks on files that do not exist)
                if { [catch {::file lstat $srcfile dummystatvar}] } {
                    throw registry::image-error "Image error: Source file $srcfile does not appear to exist (cannot lstat it).  Unable to activate port [$port name]."
                }

                set owner [registry::entry owner $file]

                if {$owner ne {} && $owner ne $port} {
                    # deactivate conflicting port if it is replaced_by this one
                    set result [mportlookup [$owner name]]
                    array unset portinfo
                    array set portinfo [lindex $result 1]
                    if {[info exists portinfo(replaced_by)] && [lsearch -regexp $portinfo(replaced_by) $replaced_by_re] != -1} {
                        # we'll deactivate the owner later, but before activating our files
                        set todeactivate($owner) yes
                        set owner "replaced"
                    }
                }

                if {$owner ne "replaced"} {
                    if { [string is true -strict $force] } {
                        # if we're forcing the activation, then we move any existing
                        # files to a backup file, both in the filesystem and in the
                        # registry
                        if { ![catch {::file type $file}] } {
                            set bakfile "${file}${baksuffix}"
                            ui_warn "File $file already exists.  Moving to: $bakfile."
                            ::file rename -force -- $file $bakfile
                            lappend backups $file
                        }
                        if { $owner ne {} } {
                            $owner deactivate [list $file]
                            $owner activate [list $file] [list "${file}${baksuffix}"]
                        }
                    } else {
                        # if we're not forcing the activation, then we bail out if
                        # we find any files that already exist, or have entries in
                        # the registry
                        if { $owner ne {} && $owner ne $port } {
                            throw registry::image-error "Image error: $file is being used by the active [$owner name] port.  Please deactivate this port first, or use 'port -f activate [$port name]' to force the activation."
                        } elseif { $owner eq {} && ![catch {::file type $file}] } {
                            throw registry::image-error "Image error: $file already exists and does not belong to a registered port.  Unable to activate port [$port name]. Use 'port -f activate [$port name]' to force the activation."
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
                while {$directory ni $files} {
                    lappend files $directory
                    set directory [::file dirname $directory]
                }

                # Also add the filename to the imagefile list.
                lappend files $file
            }
        }

        # deactivate ports replaced_by this one
        foreach owner [array names todeactivate] {
            if {$noexec || ![registry::run_target $owner deactivate [list ports_nodepcheck 1]]} {
                deactivate [$owner name] "" "" 0 [list ports_nodepcheck 1]
            }
        }

        # Sort the list in forward order, removing duplicates.
        # Since the list is sorted in forward order, we're sure that
        # directories are before their elements.
        # We don't have to do this as mentioned above, but it makes the
        # debug output of activate make more sense.
        set files [lsort -increasing -unique $files]
        # handle files that are to be renamed
        set confirmed_rename_list [list]
        foreach {src dest} $rename_list {
            set index [lsearch -exact -sorted $files $src]
            if {$index != -1} {
                set files [lreplace $files $index $index]
                lappend confirmed_rename_list $src $dest
            }
        }
        set rollback_filelist [list]

        registry::write {
            # Activate it, and catch errors so we can roll-back
            try {
                $port activate $imagefiles
                foreach file $files {
                    if {[_activate_file "${extracted_dir}${file}" $file] == 1} {
                        lappend rollback_filelist $file
                    }
                }
                foreach {src dest} $confirmed_rename_list {
                    $port deactivate [list $src]
                    $port activate [list $src] [list $dest]
                    if {[_activate_file ${extracted_dir}${src} $dest] == 1} {
                        lappend rollback_filelist $dest
                    }
                }

                # Recording that the port has been activated should be done
                # here so that this information cannot be inconsistent with the
                # state of the files on disk.
                $port state installed
            } catch {{POSIX SIG SIGINT} eCode eMessage} {
                # Pressing ^C will (often?) print "^C" to the terminal; send
                # a linebreak so our message appears after that.
                ui_msg ""
                ui_msg "Control-C pressed, rolling back, please wait."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw
            } catch {{POSIX SIG SIGTERM} eCode eMessage} {
                ui_msg "SIGTERM received, rolling back, please wait."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw
            } catch {*} {
                ui_debug "Activation failed, rolling back."
                # can't do it here since we're already inside a transaction
                set deactivate_this yes
                throw
            }
        }
    } catch {*} {
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
            foreach entry [array names todeactivate] {
                if {[$entry state] eq "imaged" && ($noexec || ![registry::run_target $entry activate ""])} {
                    activate [$entry name] [$entry version] [$entry revision] [$entry variants] [list ports_activate_no-exec $noexec]
                }
            }
        } finally {
            # We've completed all critical operations, re-enable the TERM and
            # INT signals.
            signal set $osignals
        }

        # remove temp image dir
        ::file delete -force $extracted_dir
        throw
    }
    ::file delete -force $extracted_dir
}

# These directories should not be removed during deactivation even if they are empty.
# TODO: look into what other dirs should go here
variable precious_dirs
array set precious_dirs { /Library/LaunchDaemons 1 /Library/LaunchAgents 1 }

proc _deactivate_file {dstfile} {
    if {[catch {::file type $dstfile} filetype]} {
        ui_debug "$dstfile does not exist"
        return
    }
    if { $filetype eq "link" } {
        ui_debug "deactivating link: $dstfile"
        file delete -- $dstfile
    } elseif { $filetype eq "directory" } {
        # 0 item means empty.
        if { [llength [readdir $dstfile]] == 0 } {
            variable precious_dirs
            if {![info exists precious_dirs($dstfile)]} {
                ui_debug "deactivating directory: $dstfile"
                ::file delete -- $dstfile
            } else {
                ui_debug "directory $dstfile does not belong to us"
            }
        } else {
            ui_debug "$dstfile is not empty"
        }
    } else {
        ui_debug "deactivating file: $dstfile"
        ::file delete -- $dstfile
    }
}

proc _deactivate_contents {port imagefiles {force 0} {rollback 0}} {
    set files [list]

    foreach file $imagefiles {
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
            while {$directory ni $files} {
                lappend files $directory
                set directory [::file dirname $directory]
            }
        } else {
            ui_debug "$file does not exist."
        }
    }

    # Sort the list in reverse order, removing duplicates.
    # Since the list is sorted in reverse order, we're sure that directories
    # are after their elements.
    set files [lsort -decreasing -unique $files]

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
                foreach file $files {
                    _deactivate_file $file
                }

                # Update the port's state in the same transaction as the file
                # delete operations.
                $port state imaged
            }
        } else {
            foreach file $files {
                _deactivate_file $file
            }
        }
    } finally {
        # restore the signal block state
        signal set $osignals
    }
}

# End of portimage namespace
}

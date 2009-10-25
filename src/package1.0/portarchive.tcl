# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portarchive.tcl
# $Id$
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

package provide portarchive 1.0
package require portutil 1.0

set org.macports.archive [target_new org.macports.archive portarchive::archive_main]
target_init ${org.macports.archive} portarchive::archive_init
target_provides ${org.macports.archive} archive
target_requires ${org.macports.archive} main unarchive fetch extract checksum patch configure build destroot
target_prerun ${org.macports.archive} portarchive::archive_start
target_postrun ${org.macports.archive} portarchive::archive_finish

namespace eval portarchive {
}

# defaults
default archive.dir {${destpath}}
default archive.env {}
default archive.cmd {}
default archive.pre_args {}
default archive.args {}
default archive.post_args {}

default archive.destpath {${portarchivepath}}
default archive.type {}
default archive.file {}
default archive.path {}

default archive.meta false
default archive.metaname {}
default archive.metapath {}

set_ui_prefix

proc portarchive::archive_init {args} {
    global UI_PREFIX target_state_fd
    global variations package.destpath workpath
    global ports_force ports_source_only ports_binary_only
    global name version revision portvariants
    global archive.destpath archive.type archive.meta
    global archive.file archive.path archive.fulldestpath
    global configure.build_arch

    # Check mode in case archive called directly by user
    if {[option portarchivemode] != "yes"} {
        return -code error "Archive mode is not enabled!"
    }

    # Define port variants if not already defined
    if { ![info exists portvariants] } {
        set portvariants ""
        set vlist [lsort -ascii [array names variations]]
        # Put together variants in the form +foo+bar for the archive name
        foreach v $vlist {
            if {$variations($v) == "+"} {
                append portvariants "+${v}"
            }
        }
    }

    # Define archive destination directory and target filename
    if {![string equal ${archive.destpath} ${workpath}] && ![string equal ${archive.destpath} ""]} {
        set archive.fulldestpath [file join ${archive.destpath} [option os.platform] ${configure.build_arch}]
    } else {
        set archive.fulldestpath ${archive.destpath}
    }

    # Determine if archive should be skipped
    set skipped 0
    if {[check_statefile target org.macports.archive $target_state_fd]} {
        return 0
    } elseif {[check_statefile target org.macports.unarchive $target_state_fd] && ([info exists ports_binary_only] && $ports_binary_only == "yes")} {
        ui_debug "Skipping archive ($name) since binary-only is set"
        set skipped 1
    } elseif {[info exists ports_source_only] && $ports_source_only == "yes"} {
        ui_debug "Skipping archive ($name) since source-only is set"
        set skipped 1
    } else {
        set unsupported 0
        set any_missing no
        foreach archive.type [option portarchivetype] {
            if {[catch {archiveTypeIsSupported ${archive.type}} errmsg] == 0} {
                set archive.file "${name}-${version}_${revision}${portvariants}.${configure.build_arch}.${archive.type}"
                set archive.path "[file join ${archive.fulldestpath} ${archive.file}]"
                if {![file exists ${archive.path}]} {
                    set any_missing yes
                }
            } else {
                ui_debug "Skipping [string toupper ${archive.type}] archive: $errmsg"
                set unsupported [expr $unsupported + 1]
            }
        }
        if {!$any_missing} {
            # might be nice to allow forcing, but let's fix #16061 first
            ui_debug "Skipping archive ($name) since archive(s) already exist"
            set skipped 1
        }
        if {${archive.type} == "xpkg"} {
            set archive.meta true
        }
        if {[llength [option portarchivetype]] == $unsupported} {
            ui_debug "Skipping archive ($name) since specified archive types not supported"
            set skipped 1
        }
    }
    # Skip archive target by setting state
    if {$skipped == 1} {
        write_statefile target "org.macports.archive" $target_state_fd
    }

    return 0
}

proc portarchive::archive_start {args} {
    global UI_PREFIX
    global name version revision portvariants

    if {[llength [option portarchivetype]] > 1} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Packaging [join [option portarchivetype] {, }] archives for %s %s_%s%s"] $name $version $revision $portvariants]"
    } else {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Packaging [option portarchivetype] archive for %s %s_%s%s"] $name $version $revision $portvariants]"
    }

    return 0
}

proc portarchive::archive_command_setup {args} {
    global archive.env archive.cmd
    global archive.pre_args archive.args archive.post_args
    global archive.type archive.path
    global archive.metaname archive.metapath
    global os.platform os.version

    # Define appropriate archive command and options
    set archive.env {}
    set archive.cmd {}
    set archive.pre_args {}
    set archive.args {}
    set archive.post_args {}
    switch -regex ${archive.type} {
        cp(io|gz) {
            set pax "pax"
            if {[catch {set pax [findBinary $pax ${portutil::autoconf::pax_path}]} errmsg] == 0} {
                ui_debug "Using $pax"
                set archive.cmd "$pax"
                set archive.pre_args {-w -v -x cpio}
                if {[regexp {z$} ${archive.type}]} {
                    set gzip "gzip"
                    if {[catch {set gzip [findBinary $gzip ${portutil::autoconf::gzip_path}]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set archive.args {.}
                        set archive.post_args "| $gzip -c9 > ${archive.path}"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set archive.args "-f ${archive.path} ."
                }
            } else {
                ui_debug $errmsg
                return -code error "No '$pax' was found on this system!"
            }
        }
        t(ar|bz|lz|xz|gz) {
            set tar "tar"
            if {[catch {set tar [findBinary $tar ${portutil::autoconf::tar_path}]} errmsg] == 0} {
                ui_debug "Using $tar"
                set archive.cmd "$tar"
                set archive.pre_args {-cvf}
                if {[regexp {z2?$} ${archive.type}]} {
                    if {[regexp {bz2?$} ${archive.type}]} {
                        set gzip "bzip2"
                        set level 9
                    } elseif {[regexp {lz$} ${archive.type}]} {
                        set gzip "lzma"
                        set level 7
                    } elseif {[regexp {xz$} ${archive.type}]} {
                        set gzip "xz"
                        set level 6
                    } else {
                        set gzip "gzip"
                        set level 9
                    }
                    if {[info exists portutil::autoconf::${gzip}_path]} {
                        set hint [set portutil::autoconf::${gzip}_path]
                    } else {
                        set hint ""
                    }
                    if {[catch {set gzip [findBinary $gzip $hint]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set archive.args {- .}
                        set archive.post_args "| $gzip -c$level > ${archive.path}"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set archive.args "${archive.path} ."
                }
            } else {
                ui_debug $errmsg
                return -code error "No '$tar' was found on this system!"
            }
        }
        xar {
            set xar "xar"
            if {[catch {set xar [findBinary $xar ${portutil::autoconf::xar_path}]} errmsg] == 0} {
                ui_debug "Using $xar"
                set archive.cmd "$xar"
                set archive.pre_args {-cvf}
                set archive.args "${archive.path} ."
            } else {
                ui_debug $errmsg
                return -code error "No '$xar' was found on this system!"
            }
        }
        xpkg {
            set xar "xar"
            set compression "bzip2"
            if {[catch {set xar [findBinary $xar ${portutil::autoconf::xar_path}]} errmsg] == 0} {
                ui_debug "Using $xar"
                set archive.cmd "$xar"
                set archive.pre_args "-cv --exclude='\./\+.*' --compression=${compression} -n ${archive.metaname} -s ${archive.metapath} -f"
                set archive.args "${archive.path} ."
            } else {
                ui_debug $errmsg
                return -code error "No '$xar' was found on this system!"
            }
        }
        zip {
            set zip "zip"
            if {[catch {set zip [findBinary $zip ${portutil::autoconf::zip_path}]} errmsg] == 0} {
                ui_debug "Using $zip"
                set archive.cmd "$zip"
                set archive.pre_args {-ry9}
                set archive.args "${archive.path} ."
            } else {
                ui_debug $errmsg
                return -code error "No '$zip' was found on this system!"
            }
        }
        default {
            return -code error "Invalid port archive type '${archive.type}' specified!"
        }
    }

    return 0
}

proc portarchive::putel { fd el data } {
    # Quote xml data
    set quoted [string map  { & &amp; < &lt; > &gt; } $data]
    # Write the element
    puts $fd "<${el}>${quoted}</${el}>"
}

proc portarchive::putlist { fd listel itemel list } {
    puts $fd "<$listel>"
    foreach item $list {
        putel $fd $itemel $item
    }
    puts $fd "</$listel>"
}

proc portarchive::archive_main {args} {
    global UI_PREFIX variations
    global workpath destpath portpath ports_force
    global name epoch version revision portvariants
    global archive.fulldestpath archive.type archive.file archive.path
    global archive.meta archive.metaname archive.metapath
    global os.platform os.arch configure.build_arch

    # Create archive destination path (if needed)
    if {![file isdirectory ${archive.fulldestpath}]} {
        system "mkdir -p ${archive.fulldestpath}"
    }

    # Create (if no files) destroot for archiving
    if {![file isdirectory ${destpath}]} {
        system "mkdir -p ${destpath}"
    }

    # Copy state file into destroot for archiving
    # +STATE contains a copy of the MacPorts state information
    set statefile [file join $workpath .macports.${name}.state]
    file copy -force $statefile [file join $destpath "+STATE"]

    # Copy Portfile into destroot for archiving
    # +PORTFILE contains a copy of the MacPorts Portfile
    set portfile [file join $portpath Portfile]
    file copy -force $portfile [file join $destpath "+PORTFILE"]

    # Create some informational files that we don't really use just yet,
    # but we may in the future in order to allow port installation from
    # archives without a full "ports" tree of Portfiles.
    #
    # Note: These have been modeled after FreeBSD type package files to
    # start. We can change them however we want for actual future use if
    # needed.
    #
    # +COMMENT contains the port description
    set fd [open [file join $destpath "+COMMENT"] w]
    if {[exists description]} {
        puts $fd "[option description]"
    }
    close $fd
    # +DESC contains the port long_description and homepage
    set fd [open [file join $destpath "+DESC"] w]
    if {[exists long_description]} {
        puts $fd "[option long_description]"
    }
    if {[exists homepage]} {
        puts $fd "\nWWW: [option homepage]"
    }
    close $fd
    # +CONTENTS contains the port version/name info and all installed
    # files and checksums
    set control [list]
    set fd [open [file join $destpath "+CONTENTS"] w]
    puts $fd "@name ${name}-${version}_${revision}${portvariants}"
    puts $fd "@portname ${name}"
    puts $fd "@portepoch ${epoch}"
    puts $fd "@portversion ${version}"
    puts $fd "@portrevision ${revision}"
    set vlist [lsort -ascii [array names variations]]
    foreach v $vlist {
        if {![string equal $v [option os.platform]] && ![string equal $v [option os.arch]]} {
            puts $fd "@portvariant +${v}"
        }
    }
    fs-traverse fullpath $destpath {
        if {[file isdirectory $fullpath]} {
            continue
        }
        set relpath [strsed $fullpath "s|^$destpath/||"]
        if {![regexp {^[+]} $relpath]} {
            puts $fd "$relpath"
            if {[file isfile $fullpath]} {
                ui_debug "checksum file: $fullpath"
                set checksum [md5 file $fullpath]
                puts $fd "@comment MD5:$checksum"
            }
        } else {
            lappend control $relpath
        }
    }
    foreach relpath $control {
        puts $fd "@ignore"
        puts $fd "$relpath"
    }
    close $fd

    # the XML package metadata, for XAR package
    # (doesn't contain any file list/checksums)
    if {${archive.meta}} {
        set archive.metaname "xpkg"
        set archive.metapath [file join $workpath "${archive.metaname}.xml"]
        set sd [open ${archive.metapath} w]
        puts $sd "<xpkg version='0.2'>"
        # TODO: split contents into <buildinfo> (new) and <package> (current)
        #       see existing <portpkg> for the matching source package layout

        putel $sd name ${name}
        putel $sd epoch ${epoch}
        putel $sd version ${version}
        putel $sd revision ${revision}
        putel $sd major 0
        putel $sd minor 0

        putel $sd platform ${os.platform}
        putel $sd arch ${os.arch}
        set vlist [lsort -ascii [array names variations]]
        putlist $sd variants variant $vlist

        if {[exists categories]} {
            set primary [lindex [split [option categories] " "] 0]
            putel $sd category $primary
        }
        if {[exists description]} {
            putel $sd comment "[option description]"
        }
        if {[exists long_description]} {
            putel $sd desc "[option long_description]"
        }
        if {[exists homepage]} {
            putel $sd homepage "[option homepage]"
        }

            # Emit dependencies provided by this package
            puts $sd "<provides>"
                set name ${name}
                puts $sd "<item>"
                putel $sd name $name
                putel $sd major 0
                putel $sd minor 0
                puts $sd "</item>"
            puts $sd "</provides>"
            
    set res [mport_lookup $name]
    if {[llength $res] < 2} {
        ui_error "Dependency $name not found"
    } else {
    array set portinfo [lindex $res 1]

            # Emit build, library, and runtime dependencies
            puts $sd "<requires>"
            foreach {key type} {
                depends_fetch "fetch"
                depends_extract "extract"
                depends_build "build"
                depends_lib "library"
                depends_run "runtime"
            } {
                if {[info exists portinfo($key)]} {
                    set name [lindex [split $portinfo($key) :] end]
                    puts $sd "<item type=\"$type\">"
                    putel $sd name $name
                    putel $sd major 0
                    putel $sd minor 0
                    puts $sd "</item>"
                }
            }
            puts $sd "</requires>"
    }

        puts $sd "</xpkg>"
        close $sd
    }

    # Now create the archive(s)
    # Loop through archive types
    foreach archive.type [option portarchivetype] {
        if {[catch {archiveTypeIsSupported ${archive.type}} errmsg] == 0} {
            # Define archive file/path
            set archive.file "${name}-${version}_${revision}${portvariants}.${configure.build_arch}.${archive.type}"
            set archive.path "[file join ${archive.fulldestpath} ${archive.file}]"

            # Setup archive command
            archive_command_setup

            # Remove existing archive
            if {[file exists ${archive.path}]} {
                ui_info "$UI_PREFIX [format [msgcat::mc "Deleting previous %s"] ${archive.file}]"
                file delete -force ${archive.path}
            }

            ui_info "$UI_PREFIX [format [msgcat::mc "Creating %s"] ${archive.file}]"
            command_exec archive
            ui_info "$UI_PREFIX [format [msgcat::mc "Archive %s packaged"] ${archive.file}]"
        }
    }

    return 0
}

proc portarchive::archive_finish {args} {
    global UI_PREFIX
    global name version revision portvariants
    global destpath

    # Cleanup all control files when finished
    set control_files [glob -nocomplain -types f [file join $destpath +*]]
    foreach file $control_files {
        ui_debug "removing file: $file"
        file delete -force $file
    }

    if {[llength [option portarchivetype]] > 1} {
        ui_info "$UI_PREFIX [format [msgcat::mc "Archives for %s %s_%s%s packaged"] $name $version $revision $portvariants]"
    } else {
        ui_info "$UI_PREFIX [format [msgcat::mc "Archive for %s %s_%s%s packaged"] $name $version $revision $portvariants]"
    }
    return 0
}

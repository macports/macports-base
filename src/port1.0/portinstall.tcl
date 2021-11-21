# et:ts=4
# portinstall.tcl
#
# Copyright (c) 2002 - 2004 Apple Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2005, 2007 - 2012 The MacPorts Project
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

package provide portinstall 1.0
package require portutil 1.0
package require registry2 2.0
package require machista 1.0

set org.macports.install [target_new org.macports.install portinstall::install_main]
target_provides ${org.macports.install} install
target_runtype ${org.macports.install} always
target_requires ${org.macports.install} main archivefetch fetch checksum extract patch configure build destroot
target_prerun ${org.macports.install} portinstall::install_start

namespace eval portinstall {
}

# define options
options install.asroot

# Set defaults
default install.asroot no

set_ui_prefix

proc portinstall::install_start {args} {
    global UI_PREFIX subport version revision portvariants \
           prefix registry_open registry.path
    ui_notice "$UI_PREFIX [format [msgcat::mc "Installing %s @%s_%s%s"] $subport $version $revision $portvariants]"
    
    # start gsoc08-privileges
    if {![file writable $prefix] || ([getuid] == 0 && [geteuid] != 0)} {
        # if install location is not writable, need root privileges to install
        # Also elevate if started as root, since 'file writable' doesn't seem
        # to take euid into account.
        elevateToRoot "install"
    }
    # end gsoc08-privileges
    
    if {![info exists registry_open]} {
        registry::open [file join ${registry.path} registry registry.db]
        set registry_open yes
    }

    # create any users and groups needed by the port
    handle_add_users
}

proc portinstall::create_archive {location archive.type} {
    global workpath destpath portpath subport version revision portvariants \
           epoch configure.cxx_stdlib portinstall::actual_cxx_stdlib \
           portinstall::file_is_binary portinstall::cxx_stdlib_overridden \
           cxx_stdlib PortInfo installPlist \
           archive.env archive.cmd archive.pre_args archive.args \
           archive.post_args archive.dir depends_lib depends_run
    set archive.env {}
    set archive.cmd {}
    set archive.pre_args {}
    set archive.args {}
    set archive.post_args {}
    set archive.dir ${destpath}

    switch -regex -- ${archive.type} {
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
                        set archive.post_args "| $gzip -c9 > ${location}"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set archive.args "-f ${location} ."
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
                        if {![catch {binaryInPath lbzip2}]} {
                            set gzip "lbzip2"
                        } elseif {![catch {binaryInPath pbzip2}]} {
                            set gzip "pbzip2"
                        } else {
                            set gzip "bzip2"
                        }
                        set level 9
                    } elseif {[regexp {lz$} ${archive.type}]} {
                        set gzip "lzma"
                        set level ""
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
                        set archive.post_args "| $gzip -c$level > ${location}"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set archive.args "${location} ."
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
                set archive.args "${location} ."
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
                set archive.args "${location} ."
            } else {
                ui_debug $errmsg
                return -code error "No '$zip' was found on this system!"
            }
        }
    }

    set archive.fulldestpath [file dirname $location]
    # Create archive destination path (if needed)
    if {![file isdirectory ${archive.fulldestpath}]} {
        file mkdir ${archive.fulldestpath}
    }

    # Create (if no files) destroot for archiving
    if {![file isdirectory ${destpath}]} {
        return -code error "no destroot found at: ${destpath}"
    }

    # Copy state file into destroot for archiving
    # +STATE contains a copy of the MacPorts state information
    set statefile [file join $workpath .macports.${subport}.state]
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
    puts $fd "@name ${subport}-${version}_${revision}${portvariants}"
    puts $fd "@portname ${subport}"
    puts $fd "@portepoch ${epoch}"
    puts $fd "@portversion ${version}"
    puts $fd "@portrevision ${revision}"
    puts $fd "@archs [get_canonical_archs]"
    array set ourvariations $PortInfo(active_variants)
    set vlist [lsort -ascii [array names ourvariations]]
    foreach v $vlist {
        if {$ourvariations($v) eq "+"} {
            puts $fd "@portvariant +${v}"
        }
    }

    foreach key "depends_lib depends_run" {
         if {[info exists $key]} {
             foreach depspec [set $key] {
                 set depname [lindex [split $depspec :] end]
                 set dep [mport_lookup $depname]
                 if {[llength $dep] < 2} {
                     ui_debug "Dependency $depname not found"
                 } else {
                     array set portinfo [lindex $dep 1]
                     set depver $portinfo(version)
                     set deprev $portinfo(revision)
                     puts $fd "@pkgdep $portinfo(name)-${depver}_${deprev}"
                 }
             }
         }
    }

    set have_fileIsBinary [expr {[option os.platform] eq "darwin"}]
    set binary_files {}
    # also save the contents for our own use later
    set installPlist {}
    set destpathLen [string length $destpath]
    fs-traverse -depth fullpath [list $destpath] {
        if {[file type $fullpath] eq "directory"} {
            continue
        }

        set relpath [string range $fullpath $destpathLen+1 end]
        if {[string index $relpath 0] ne "+"} {
            puts $fd "$relpath"
            set abspath [file join [file separator] $relpath]
            lappend installPlist $abspath
            if {[file isfile $fullpath]} {
                ui_debug "checksum file: $fullpath"
                set checksum [md5 file $fullpath]
                puts $fd "@comment MD5:$checksum"
                if {$have_fileIsBinary} {
                    # test if (mach-o) binary
                    set is_binary [fileIsBinary $fullpath]
                    if {$is_binary} {
                        lappend binary_files $fullpath
                    }
                    puts $fd "@comment binary:$is_binary"
                    set portinstall::file_is_binary($abspath) $is_binary
                }
            }
        } else {
            lappend control $relpath
        }
    }
    foreach relpath $control {
        puts $fd "@ignore"
        puts $fd "$relpath"
    }
    set portinstall::actual_cxx_stdlib [get_actual_cxx_stdlib $binary_files]
    puts $fd "@cxx_stdlib ${portinstall::actual_cxx_stdlib}"
    if {${portinstall::actual_cxx_stdlib} ne "none"} {
        set portinstall::cxx_stdlib_overridden [expr {${configure.cxx_stdlib} ne $cxx_stdlib}]
    } else {
        set portinstall::cxx_stdlib_overridden 0
    }
    puts $fd "@cxx_stdlib_overridden ${portinstall::cxx_stdlib_overridden}"
    close $fd

    # Now create the archive
    ui_debug "Creating [file tail $location]"
    command_exec archive
    ui_debug "Archive [file tail $location] packaged"

    # Cleanup all control files when finished
    set control_files [glob -nocomplain -types f [file join $destpath +*]]
    foreach file $control_files {
        ui_debug "removing file: $file"
        file delete -force $file
    }
}

proc portinstall::extract_contents {location type} {
    return [extract_archive_metadata $location $type contents]
}

proc portinstall::install_main {args} {
    global subport version portpath depends_run revision user_options \
    portvariants requested_variants depends_lib PortInfo epoch \
    os.platform os.major portarchivetype installPlist registry.path porturl \
    portinstall::file_is_binary portinstall::actual_cxx_stdlib portinstall::cxx_stdlib_overridden

    set oldpwd [pwd]
    if {$oldpwd eq ""} {
        set oldpwd $portpath
    }

    set location [get_portimage_path]
    set archive_path [find_portarchive_path]
    if {$archive_path ne ""} {
        set install_dir [file dirname $location]
        file mkdir $install_dir
        file rename -force $archive_path $install_dir
        set location [file join $install_dir [file tail $archive_path]]
        set current_archive_type [string range [file extension $location] 1 end]
        set contents [extract_contents $location $current_archive_type]
        set installPlist [lindex $contents 0]
        array set portinstall::file_is_binary [lindex $contents 1]
        set cxxinfo [extract_archive_metadata $location $current_archive_type cxx_info]
        set portinstall::actual_cxx_stdlib [lindex $cxxinfo 0]
        set portinstall::cxx_stdlib_overridden [lindex $cxxinfo 1]
    } else {
        # throws an error if an unsupported value has been configured
        archiveTypeIsSupported $portarchivetype
        # create archive from the destroot
        create_archive $location $portarchivetype
    }

    # can't do this inside the write transaction due to deadlock issues with _get_dep_port
    set dep_portnames [list]
    foreach deplist {depends_lib depends_run} {
        if {[info exists $deplist]} {
            foreach dep [set $deplist] {
                set dep_portname [_get_dep_port $dep]
                if {$dep_portname ne ""} {
                    lappend dep_portnames $dep_portname
                }
            }
        }
    }

    registry::write {

        set regref [registry::entry create $subport $version $revision $portvariants $epoch]

        if {[info exists user_options(ports_requested)]} {
            $regref requested $user_options(ports_requested)
        } else {
            $regref requested 0
        }
        $regref os_platform ${os.platform}
        $regref os_major ${os.major}
        $regref archs [get_canonical_archs]
        if {${portinstall::actual_cxx_stdlib} ne ""} {
            $regref cxx_stdlib ${portinstall::actual_cxx_stdlib}
            $regref cxx_stdlib_overridden ${portinstall::cxx_stdlib_overridden}
        } else {
            # no info in the archive
            global configure.cxx_stdlib cxx_stdlib
            $regref cxx_stdlib_overridden [expr {${configure.cxx_stdlib} ne $cxx_stdlib}]
        }
        # Trick to have a portable GMT-POSIX epoch-based time.
        $regref date [expr {[clock scan now -gmt true] - [clock scan "1970-1-1 00:00:00" -gmt true]}]
        if {[info exists requested_variants]} {
            $regref requested_variants $requested_variants
        }

        foreach dep_portname $dep_portnames {
            $regref depends $dep_portname
        }

        $regref installtype image
        $regref state imaged
        $regref location $location

        if {[info exists installPlist]} {
            # register files
            $regref map $installPlist
            foreach f [array names portinstall::file_is_binary] {
                set fileref [registry::file open [$regref id] $f]
                $fileref binary $portinstall::file_is_binary($f)
                registry::file close $fileref
            }
        }

        # store portfile
        set portfile_path [file join $portpath Portfile]
        set portfile_sha256 [sha256 file $portfile_path]
        set portfile_size [file size $portfile_path]
        set portfile_reg_dir [file join ${registry.path} registry portfiles ${subport}-${version}_${revision} ${portfile_sha256}-${portfile_size}]
        file mkdir $portfile_reg_dir
        set portfile_reg_path ${portfile_reg_dir}/Portfile
        if {![file isfile $portfile_reg_path] || [file size $portfile_reg_path] != $portfile_size || [sha256 file $portfile_reg_path] ne $portfile_sha256} {
            file copy -force $portfile_path $portfile_reg_dir
            file attributes $portfile_reg_path -permissions 0644
        }
        $regref portfile ${portfile_sha256}-${portfile_size}

        # store portgroups
        if {[info exists PortInfo(portgroups)]} {
            foreach pg $PortInfo(portgroups) {
                set pgname [lindex $pg 0]
                set pgversion [lindex $pg 1]
                set groupFile [lindex $pg 2]
                if {[file isfile $groupFile]} {
                    set pgsha256 [sha256 file $groupFile]
                    set pgsize [file size $groupFile]
                    set pg_reg_dir [file join ${registry.path} registry portgroups ${pgsha256}-${pgsize}]
                    set pg_reg_path ${pg_reg_dir}/${pgname}-${pgversion}.tcl
                    if {![file isfile $pg_reg_path] || [file size $pg_reg_path] != $pgsize || [sha256 file $pg_reg_path] ne $pgsha256} {
                        file mkdir $pg_reg_dir
                        file copy -force $groupFile $pg_reg_dir
                    }
                    file attributes $pg_reg_path -permissions 0644
                    $regref addgroup $pgname $pgversion $pgsha256 $pgsize
                } else {
                    ui_debug "install_main: no portgroup ${pgname}-${pgversion}.tcl found"
                }
            }
        }
    }

    #registry::entry close $regref

    _cd $oldpwd
    return 0
}

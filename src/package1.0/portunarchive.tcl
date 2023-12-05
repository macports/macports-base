# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# portunarchive.tcl
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

package provide portunarchive 1.0
package require portutil 1.0

set org.macports.unarchive [target_new org.macports.unarchive portunarchive::unarchive_main]
target_runtype ${org.macports.unarchive} always
target_init ${org.macports.unarchive} portunarchive::unarchive_init
target_provides ${org.macports.unarchive} unarchive
target_requires ${org.macports.unarchive} main
target_prerun ${org.macports.unarchive} portunarchive::unarchive_start
target_postrun ${org.macports.unarchive} portunarchive::unarchive_finish

namespace eval portunarchive {
}

# defaults
default unarchive.dir {${destpath}}
default unarchive.env {}
default unarchive.cmd {}
default unarchive.pre_args {}
default unarchive.args {}
default unarchive.post_args {}

default unarchive.srcpath {${portarchivepath}}
default unarchive.type {}
default unarchive.file {}
default unarchive.path {}

set_ui_prefix

proc portunarchive::unarchive_init {args} {
    global UI_PREFIX target_state_fd variations workpath
    global ports_force ports_source_only ports_binary_only
    global name version revision portvariants portpath
    global unarchive.srcpath unarchive.type unarchive.file unarchive.path unarchive.fullsrcpath
    global configure.build_arch configure.universal_archs

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

    # Define archive directory, file, and path
    if {![string equal ${unarchive.srcpath} ${workpath}] && ![string equal ${unarchive.srcpath} ""]} {
        if {[variant_exists universal] && [variant_isset universal]} {
            set unarchive.fullsrcpath [file join ${unarchive.srcpath} [option os.platform] "universal"]
        } else {
            set unarchive.fullsrcpath [file join ${unarchive.srcpath} [option os.platform] ${configure.build_arch}]
        }
    } else {
        set unarchive.fullsrcpath ${unarchive.srcpath}
    }

    # Determine if unarchive should be skipped
    set skipped 0
    if {[check_statefile target org.macports.unarchive $target_state_fd]} {
        return 0
    } elseif {[info exists ports_source_only] && $ports_source_only == "yes"} {
        ui_debug "Skipping unarchive ($name) since source-only is set"
        set skipped 1
    } elseif {[check_statefile target org.macports.destroot $target_state_fd]} {
        ui_debug "Skipping unarchive ($name) since destroot completed"
        set skipped 1
    } elseif {[info exists ports_force] && $ports_force == "yes"} {
        ui_debug "Skipping unarchive ($name) since force is set"
        set skipped 1
    } else {
        set found 0
        set unsupported 0
        foreach unarchive.type [option portarchivetype] {
            if {[catch {archiveTypeIsSupported ${unarchive.type}} errmsg] == 0} {
                if {[variant_exists universal] && [variant_isset universal]} {
                    set archstring [join [lsort -ascii ${configure.universal_archs}] -]
                } else {
                    set archstring ${configure.build_arch}
                }
                set unarchive.file "${name}-${version}_${revision}${portvariants}.${archstring}.${unarchive.type}"
                set unarchive.path "[file join ${unarchive.fullsrcpath} ${unarchive.file}]"
                if {[file exist ${unarchive.path}]} {
                    set found 1
                    break
                } else {
                    ui_debug "No [string toupper ${unarchive.type}] archive: ${unarchive.path}"
                }
            } else {
                ui_debug "Skipping [string toupper ${unarchive.type}] archive: $errmsg"
                set unsupported [expr $unsupported + 1]
            }
        }
        if {$found == 1} {
            ui_debug "Found [string toupper ${unarchive.type}] archive: ${unarchive.path}"
        } else {
            if {[info exists ports_binary_only] && $ports_binary_only == "yes"} {
                return -code error "Archive for ${name} ${version}_${revision}${portvariants} not found, required when binary-only is set!"
            } else {
                if {[llength [option portarchivetype]] == $unsupported} {
                    ui_debug "Skipping unarchive ($name) since specified archive types not supported"
                } else {
                    ui_debug "Skipping unarchive ($name) since no archive found"
                }
                set skipped 1
            }
        }
    }
    # Skip unarchive target by setting state
    if {$skipped == 1} {
        write_statefile target "org.macports.unarchive" $target_state_fd
    }

    return 0
}

proc portunarchive::unarchive_start {args} {
    global UI_PREFIX name version revision portvariants
    global unarchive.type

    ui_msg "$UI_PREFIX [format [msgcat::mc "Unpacking ${unarchive.type} archive for %s %s_%s%s"] $name $version $revision $portvariants]"

    return 0
}

proc portunarchive::unarchive_command_setup {args} {
    global unarchive.env unarchive.cmd
    global unarchive.pre_args unarchive.args unarchive.post_args
    global unarchive.type unarchive.path
    global unarchive.pipe_cmd
    global os.platform os.version env

    # Define appropriate unarchive command and options
    set unarchive.env {}
    set unarchive.cmd {}
    set unarchive.pre_args {}
    set unarchive.args {}
    set unarchive.post_args {}
    set unarchive.pipe_cmd ""
    switch -regex ${unarchive.type} {
        cp(io|gz) {
            set pax "pax"
            if {[catch {set pax [findBinary $pax ${portutil::autoconf::pax_path}]} errmsg] == 0} {
                ui_debug "Using $pax"
                set unarchive.cmd "$pax"
                if {[info exists env(USER)] && $env(USER) == "root"} {
                    set unarchive.pre_args {-r -v -p e}
                } else {
                    set unarchive.pre_args {-r -v -p p}
                }
                if {[regexp {z$} ${unarchive.type}]} {
                    set unarchive.args {.}
                    set gzip "gzip"
                    if {[catch {set gzip [findBinary $gzip ${portutil::autoconf::gzip_path}]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set unarchive.pipe_cmd "$gzip -d -c ${unarchive.path} |"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set unarchive.args "-f ${unarchive.path} ."
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
                set unarchive.cmd "$tar"
                set unarchive.pre_args {-xvpf}
                if {[regexp {z2?$} ${unarchive.type}]} {
                    set unarchive.args {-}
                    if {[regexp {bz2?$} ${unarchive.type}]} {
                        set gzip "bzip2"
                    } elseif {[regexp {lz$} ${unarchive.type}]} {
                        set gzip "lzma"
                    } elseif {[regexp {xz$} ${unarchive.type}]} {
                        set gzip "xz"
                    } else {
                        set gzip "gzip"
                    }
                    if {[info exists portutil::autoconf::${gzip}_path]} {
                        set hint [set portutil::autoconf::${gzip}_path]
                    } else {
                        set hint ""
                    }
                    if {[catch {set gzip [findBinary $gzip $hint]} errmsg] == 0} {
                        ui_debug "Using $gzip"
                        set unarchive.pipe_cmd "$gzip -d -c ${unarchive.path} |"
                    } else {
                        ui_debug $errmsg
                        return -code error "No '$gzip' was found on this system!"
                    }
                } else {
                    set unarchive.args "${unarchive.path}"
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
                set unarchive.cmd "$xar"
                set unarchive.pre_args {-xvpf}
                set unarchive.args "${unarchive.path}"
            } else {
                ui_debug $errmsg
                return -code error "No '$xar' was found on this system!"
            }
        }
        zip {
            set unzip "unzip"
            if {[catch {set unzip [findBinary $unzip ${portutil::autoconf::unzip_path}]} errmsg] == 0} {
                ui_debug "Using $unzip"
                set unarchive.cmd "$unzip"
                if {[info exists env(USER)] && $env(USER) == "root"} {
                    set unarchive.pre_args {-oX}
                } else {
                    set unarchive.pre_args {-o}
                }
                set unarchive.args "${unarchive.path} -d ."
            } else {
                ui_debug $errmsg
                return -code error "No '$unzip' was found on this system!"
            }
        }
        default {
            return -code error "Invalid port archive type '${unarchive.type}' specified!"
        }
    }

    return 0
}

proc portunarchive::unarchive_main {args} {
    global UI_PREFIX
    global name version revision portvariants
    global unarchive.dir unarchive.file unarchive.pipe_cmd

    # Setup unarchive command
    unarchive_command_setup

    # Create destination directory for unpacking
    if {![file isdirectory ${unarchive.dir}]} {
        file mkdir ${unarchive.dir}
    }

    # Unpack the archive
    ui_info "$UI_PREFIX [format [msgcat::mc "Extracting %s"] ${unarchive.file}]"
    if {${unarchive.pipe_cmd} == ""} {
        command_exec unarchive
    } else {
        command_exec unarchive "${unarchive.pipe_cmd} (" ")"
    }

    return 0
}

proc portunarchive::unarchive_finish {args} {
    global UI_PREFIX target_state_fd unarchive.file name workpath destpath

    # Reset state file with archive version
    set statefile [file join $workpath .macports.${name}.state]
    file copy -force [file join $destpath "+STATE"] $statefile
    file mtime $statefile [clock seconds]

# Hack to temporarily move com.apple.* strings in statefiles extracted from old archives
# to the org.macports.* namespace. "temporarily" because old archives will still have a
# +STATE file with the old strings in it, as we only update them on the unpacked statefile.
    set fd_new_sf [open $statefile r]
    set fd_tmp [open ${statefile}.tmp w+]
    while {[gets $fd_new_sf line] >= 0} {
    puts $fd_tmp "[regsub com.apple $line org.macports]"
    }
    close $fd_new_sf
    close $fd_tmp
    file rename -force ${statefile}.tmp $statefile

    # Update the state from unpacked archive version
    set target_state_fd [open_statefile]
    
    # Cleanup all control files when finished
    set control_files [glob -nocomplain -types f [file join $destpath +*]]
    foreach file $control_files {
        ui_debug "Removing $file"
        file delete -force $file
    }

    ui_info "$UI_PREFIX [format [msgcat::mc "Archive %s unpacked"] ${unarchive.file}]"
    return 0
}

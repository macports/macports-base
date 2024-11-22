# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# macports.tcl
#
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2004 - 2005 Paul Guyot, <pguyot@kallisys.net>.
# Copyright (c) 2004 - 2006 Ole Guldberg Jensen <olegb@opendarwin.org>.
# Copyright (c) 2004 - 2005 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2004 - 2020 The MacPorts Project
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
package provide macports 1.0
package require macports_dlist 1.0
package require macports_util 1.0
package require diagnose 1.0
package require reclaim 1.0
package require selfupdate 1.0
package require snapshot 1.0
package require restore 1.0
package require migrate 1.0
package require Tclx

# catch wrapper shared with port1.0
package require mpcommon 1.0

namespace eval macports {
    variable bootstrap_options [dict create]
    # Config file options with no special handling
    foreach opt [list binpath auto_path extra_env portdbformat \
        portarchivetype portimage_mode hfscompression portautoclean \
        porttrace portverbose keeplogs destroot_umask release_urls release_version_urls \
        rsync_server rsync_options rsync_dir \
        startupitem_autostart startupitem_type startupitem_install \
        place_worksymlink xcodeversion xcodebuildcmd xcodecltversion xcode_license_unaccepted \
        configureccache ccache_size configuredistcc configurepipe buildnicevalue buildmakejobs \
        universal_archs build_arch macosx_sdk_version macosx_deployment_target \
        macportsuser proxy_override_env proxy_http proxy_https proxy_ftp proxy_rsync proxy_skip \
        master_site_local patch_site_local archive_site_local buildfromsource \
        revupgrade_autorun revupgrade_mode revupgrade_check_id_loadcmds \
        host_blacklist preferred_hosts sandbox_enable sandbox_network delete_la_files cxx_stdlib \
        default_compilers pkg_post_unarchive_deletions ui_interactive] {
            dict set bootstrap_options $opt {}
    }
    # Config file options that are a filesystem path and should be fully resolved
    foreach opt [list applications_dir archive_sites_conf ccache_dir developer_dir \
                      frameworks_dir packagemaker_path portdbpath prefix pubkeys_conf \
                      sources_conf variants_conf] {
        dict set bootstrap_options $opt is_path 1
    }
    unset opt

    variable user_options {}
    variable portinterp_options [list \
        portdbpath porturl portpath portbuildpath auto_path prefix prefix_frozen portsharepath \
        registry.path registry.format user_home user_path user_ssh_auth_sock \
        portarchivetype portarchive_hfscompression archivefetch_pubkeys \
        portautoclean portimage_mode porttrace keeplogs portverbose destroot_umask \
        rsync_server rsync_options rsync_dir startupitem_autostart startupitem_type startupitem_install \
        place_worksymlink macportsuser sudo_user \
        configureccache ccache_dir ccache_size configuredistcc configurepipe buildnicevalue buildmakejobs \
        applications_dir applications_dir_frozen current_phase frameworks_dir frameworks_dir_frozen \
        developer_dir universal_archs build_arch os_arch os_endian os_version os_major os_minor \
        os_platform os_subplatform macos_version macos_version_major macosx_version macosx_sdk_version \
        macosx_deployment_target packagemaker_path default_compilers sandbox_enable sandbox_network \
        delete_la_files cxx_stdlib pkg_post_unarchive_deletions {*}$user_options]

    # deferred options are only computed when needed.
    # they are not exported to the trace thread.
    # they are not exported to the interpreter in system_options array.
    variable portinterp_deferred_options [list developer_dir xcodeversion xcodebuildcmd \
                                               xcodecltversion xcode_license_unaccepted]

    variable open_mports {}

    variable ui_priorities [list error warn msg notice info debug any]
    variable current_phase main

    variable ui_prefix {---> }

    variable cache_dirty [dict create]
    variable tool_path_cache [dict create]
    variable variant_descriptions [dict create]

    variable getprotocol_re {(?x)([^:]+)://.+}
    variable file_porturl_re {^file://(.*)}
    variable source_is_snapshot_re {^((?:https?|ftp|rsync)://.+/)(.+\.(tar\.gz|tar\.bz2|tar))$}

    # All valid depends_* options
    variable all_dep_types [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test]
    # Which depends_* types need to have matching archs when installing
    variable archcheck_install_dep_types [list depends_build depends_lib depends_run]
    # Which depends_* types need to have matching archs if used
    variable archcheck_dep_types [list {*}${archcheck_install_dep_types} depends_test]
}

##
# Return the version of MacPorts you are running
#
# This proc never fails and always returns the current version in the format
# major.minor.patch. Note that the value of patch will not be meaningful for
# Git master, but we guarantee that it will compare to be greater than any
# released versions from the same major.minor.x series. You should use the
# MacPorts-provided Tcl extension "vercmp" to do version number comparisons on
# the return value of this function.
proc macports::version {} {
    return ${macports::autoconf::macports_version}
}

# Provided UI instantiations
# For standard messages, the following priorities are defined
#     debug, info, msg, warn, error
# Clients of the library are expected to provide ui_prefix and ui_channels with
# the following prototypes.
#     proc ui_prefix {priority}
#     proc ui_channels {priority}
# ui_prefix returns the prefix for the messages, if any.
# ui_channels returns a list of channels to output the message to, empty for
#     no message.
# if these functions are not provided, defaults are used.
# Clients of the library may optionally provide ui_init with the following
# prototype.
#     proc ui_init {priority prefix channels message}
# ui_init needs to correctly define the proc ::ui_$priority {message} or throw
# an error.
# if this function is not provided or throws an error, default procedures for
# ui_$priority are defined.

# ui_options accessor
proc macports::ui_isset {val} {
    variable ui_options
    if {[info exists ui_options($val)]} {
        return [string is true -strict $ui_options($val)]
    }
    return 0
}

# Return all current ui options
proc macports::get_ui_options {} {
    variable ui_options
    return [array get ui_options]
}
# Set all ui options
# Takes a value previously returned by get_ui_options
proc macports::set_ui_options {opts} {
    variable ui_options; variable portverbose
    array unset ui_options
    array set ui_options $opts
    # This is also a config file option, so needs special handling
    if {[info exists ui_options(ports_verbose)]} {
        set portverbose $ui_options(ports_verbose)
    } else {
        variable portverbose_frozen
        set portverbose $portverbose_frozen
    }
}


# global_options accessor
proc macports::global_option_isset {val} {
    variable global_options
    if {[info exists global_options($val)]} {
        return [string is true -strict $global_options($val)]
    }
    return 0
}

# Return all current global options
proc macports::get_global_options {} {
    variable global_options
    return [array get global_options]
}
# Set all global options
# Takes a value previously returned by get_global_options
proc macports::set_global_options {opts} {
    variable global_options
    array unset global_options
    array set global_options $opts
    # Options that can also be set in the config file need special handling
    foreach {opt var} {ports_autoclean portautoclean ports_trace porttrace} {
        variable $var
        if {[info exists global_options($opt)]} {
            set $var $global_options($opt)
        } else {
            variable ${var}_frozen
            set $var [set ${var}_frozen]
        }
    }
}


proc macports::init_logging {mport} {
    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0; setegid 0
    }
    if {[catch {macports::ch_logging $mport} err]} {
        ui_debug "Logging disabled, error opening log file: $err"
        return 1
    }
    macports::_log_sysinfo
    return 0
}

proc macports::ch_logging {mport} {
    variable debuglogname; variable debuglog
    set portinfo [mportinfo $mport]
    set portname [dict get $portinfo name]
    set portpath [ditem_key $mport portpath]

    set logdir [macports::getportlogpath $portpath $portname]
    file mkdir $logdir
    set debuglogname [file join $logdir main.log]

    # Append to the file if it already exists
    set debuglog [open $debuglogname a]
    puts $debuglog version:1

    ui_debug "Starting logging for $portname @[dict get $portinfo version]_[dict get $portinfo revision][dict get $portinfo canonical_active_variants]"
}

# log platform information
proc macports::_log_sysinfo {} {
    foreach v [list current_phase os_platform os_subplatform os_version \
                    os_arch macos_version macosx_sdk_version \
                    macosx_deployment_target xcodeversion xcodecltversion] {
        variable $v
    }

    set previous_phase ${current_phase}
    set current_phase "sysinfo"

    if {$os_platform eq "darwin"} {
        if {$os_subplatform eq "macosx"} {
            if {[vercmp $macos_version >= 10.12] } {
                set os_version_string "macOS ${macos_version}"
            } elseif {[vercmp $macos_version >= 10.8]} {
                set os_version_string "OS X ${macos_version}"
            } else {
                set os_version_string "Mac OS X ${macos_version}"
            }
        } else {
            set os_version_string "PureDarwin ${os_version}"
        }
    } else {
        global tcl_platform
        # use capitalized platform name
        set os_version_string "$tcl_platform(os) ${os_version}"
    }

    ui_debug "$os_version_string ($os_platform/$os_version) arch $os_arch"
    ui_debug "MacPorts [macports::version]"
    if {$os_platform eq "darwin" && $os_subplatform eq "macosx"} {
        ui_debug "Xcode ${xcodeversion}, CLT ${xcodecltversion}"
        ui_debug "SDK ${macosx_sdk_version}"
        ui_debug "MACOSX_DEPLOYMENT_TARGET: ${macosx_deployment_target}"
    }

    set current_phase $previous_phase
}

proc macports::push_log {mport} {
    variable logenabled; variable logstack
    variable debuglog; variable debuglogname
    if {![info exists logenabled]} {
        if {[macports::init_logging $mport] == 0} {
            set logenabled yes
            set logstack [list [list $debuglog $debuglogname]]
            return
        } else {
            set logenabled no
        }
    }
    if {$logenabled} {
        if {[macports::init_logging $mport] == 0} {
            lappend logstack [list $debuglog $debuglogname]
        }
    }
}

proc macports::pop_log {} {
    variable logenabled
    if {![info exists logenabled]} {
        return -code error "pop_log called before push_log"
    }
    variable logstack
    if {$logenabled && [llength $logstack] > 0} {
        variable debuglog; variable debuglogname
        close $debuglog
        set logstack [lreplace ${logstack}[set logstack {}] end end]
        if {[llength $logstack] > 0} {
            lassign [lindex $logstack end] debuglog debuglogname
        } else {
            unset debuglog
            unset debuglogname
        }
    }
}

proc set_phase {phase} {
    global macports::current_phase
    set current_phase $phase
    if {$phase ne "main"} {
        set cur_time [clock format [clock seconds] -format  {%+}]
        ui_debug "$phase phase started at $cur_time"
    }
}

proc ui_message {priority prefix args} {
    global macports::channels macports::current_phase macports::debuglog

    # 
    # validate $args
    #
    switch [llength $args] {
       0 - 1 {}
       2 {
           if {[lindex $args 0] ne "-nonewline"} {
               set hint "error: when 4 arguments are given, 3rd must be \"-nonewline\""
               error "$hint\nusage: ui_message priority prefix ?-nonewline? string"
           }
       }
       default {
           set hint "error: too many arguments specified"
           error "$hint\nusage: ui_message priority prefix ?-nonewline? string"
       }
    } 

    foreach chan $channels($priority) {
        if {[lindex $args 0] eq "-nonewline"} {
            puts -nonewline $chan $prefix[lindex $args 1]
        } else {
            puts $chan $prefix[lindex $args 0]
        }
    }

    if {[info exists debuglog]} {
        if {[info exists current_phase]} {
            set phase $current_phase
        }
        set strprefix ":${priority}:$phase "
        if {[lindex $args 0] eq "-nonewline"} {
            puts -nonewline $debuglog $strprefix[lindex $args 1]
        } else {
            foreach str [split [lindex $args 0] "\n"] {
                puts $debuglog $strprefix$str
            }
        }
    }
}

# Init (or re-init) all ui channels
proc macports::ui_init_all {} {
    variable ui_priorities
    variable ui_options

    foreach priority $ui_priorities {
        ui_init $priority
    }

    foreach pname {progress_download progress_generic} {
        if {![macports::ui_isset ports_debug] && [info exists ui_options($pname)]} {
            interp alias {} ui_$pname {} $ui_options($pname)
        } else {
            interp alias {} ui_$pname {} return -level 0
        }
    }
}

proc macports::ui_init {priority args} {
    variable channels
    # Get the list of channels.
    if {[llength [info commands ui_channels]] > 0} {
        set channels($priority) [ui_channels $priority]
    } else {
        set channels($priority) [macports::ui_channels_default $priority]
    }

    # Simplify ui_$priority.
    try {
        set prefix [ui_prefix $priority]
    } on error {} {
        set prefix [ui_prefix_default $priority]
    }
    try {
        ::ui_init $priority $prefix $channels($priority) {*}$args
    } on error {} {
        interp alias {} ui_$priority {} ui_message $priority $prefix
    }
}

# Default implementation of ui_prefix
proc macports::ui_prefix_default {priority} {
    switch -- $priority {
        debug {
            return "DEBUG: "
        }
        error {
            return "Error: "
        }
        warn {
            return "Warning: "
        }
        default {
            return {}
        }
    }
}

# Default implementation of ui_channels:
# ui_options(ports_debug) - If set, output debugging messages
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"
proc macports::ui_channels_default {priority} {
    switch -- $priority {
        debug {
            if {[ui_isset ports_debug]} {
                return stderr
            } else {
                return {}
            }
        }
        info {
            if {[ui_isset ports_verbose]} {
                return stdout
            } else {
                return {}
            }
        }
        notice {
            if {[ui_isset ports_quiet]} {
                return {}
            } else {
                return stdout
            }
        }
        msg {
            return stdout
        }
        warn -
        error {
            return stderr
        }
        default {
            return stdout
        }
    }
}

proc ui_warn_once {id msg} {
    global macports::warning_done
    if {![info exists warning_done($id)]} {
        ui_warn $msg
        set warning_done($id) 1
    }
}

# Replace puts to catch errors (typically broken pipes when being piped to head)
rename puts tcl::puts
proc puts {args} {
    catch {tcl::puts {*}$args}
}

# find a binary either in a path defined at MacPorts' configuration time
# or in the PATH environment variable through macports::binaryInPath (fallback)
proc macports::findBinary {prog {autoconf_hint {}}} {
    if {$autoconf_hint ne "" && [file executable $autoconf_hint]} {
        return $autoconf_hint
    } else {
        macports_try -pass_signal {
            return [macports::binaryInPath $prog]
        } on error {eMessage} {
            error "$eMessage or at its MacPorts configuration time location, did you move it?"
        }
    }
}

# check for a binary in the path
# returns an error code if it cannot be found
proc macports::binaryInPath {prog} {
    global env
    foreach dir [split $env(PATH) :] {
        if {[file executable [file join $dir $prog]]} {
            return [file join $dir $prog]
        }
    }
    return -code error [format [msgcat::mc "Failed to locate '%s' in path: '%s'"] $prog $env(PATH)];
}

# deferred option processing
proc macports::getoption {name} {
    variable $name
    return [set $name]
}

# Load a cache file
# filename: Name relative to ${portdbpath}/cache to load from
# Returns a dict created from the file contents if successful, or an
# empty dict otherwise.
proc macports::load_cache {filename} {
    variable portdbpath
    set cachefd -1
    macports_try -pass_signal {
        set cachefd [open ${portdbpath}/cache/${filename} r]
        set cache [dict create {*}[gets $cachefd]]
    } on error {errorInfo} {
        set cache [dict create]
        ui_debug "Error reading ${portdbpath}/cache/${filename}: $errorInfo"
    } finally {
        if {$cachefd != -1} {
            close $cachefd
        }
    }
    return $cache
}

# Save a cache file
# filename: Name relative to ${portdbpath}/cache to save to
# cache: A dict containing the cache data
proc macports::save_cache {filename cache} {
    variable portdbpath
    set cachefd -1
    macports_try -pass_signal {
        file mkdir ${portdbpath}/cache
        set cachefd [open ${portdbpath}/cache/${filename} w]
        puts $cachefd $cache
    } on error {errorInfo} {
        ui_debug "Error writing ${portdbpath}/cache/${filename}: $errorInfo"
    } finally {
        if {$cachefd != -1} {
            close $cachefd
        }
    }
}

# deferred and on-need extraction of xcodeversion and xcodebuildcmd.
proc macports::setxcodeinfo {name1 name2 op} {
    variable xcodeversion; variable xcodebuildcmd
    variable developer_dir; variable portdbpath
    variable os_major

    trace remove variable xcodeversion read macports::setxcodeinfo
    trace remove variable xcodebuildcmd read macports::setxcodeinfo

    set xcodeversion_overridden [info exists xcodeversion]
    set xcodebuildcmd_overridden [info exists xcodebuildcmd]

    # Potentially read by developer_dir trace proc
    if {!${xcodeversion_overridden}} {
        set xcodeversion {}
    }
    # First try the cache
    set xcodeinfo_cache [load_cache xcodeinfo]

    # Refresh everything if the OS major version changed
    if {[dict exists $xcodeinfo_cache os_major]
         && [dict get $xcodeinfo_cache os_major] != $os_major
    } {
        set xcodeinfo_cache [dict create]
    }

    # The same cache file is used for xcodecltversion
    set clt_refreshed [set_xcodecltversion xcodeinfo_cache]

    # Figure out which file to check to see if Xcode was updated
    if {[file extension [file dirname [file dirname $developer_dir]]] eq ".app"} {
        # New style, Developer dir inside Xcode.app
        set checkfile [file dirname $developer_dir]/Info.plist
    } else {
        # Old style, Xcode.app inside Developer dir
        set checkfile ${developer_dir}/Applications/Xcode.app/Contents/Info.plist
    }
    set checkfile_found [file isfile $checkfile]
    set xcode_refresh 1
    if {$checkfile_found && [dict exists $xcodeinfo_cache $checkfile mtime]
            && [dict exists $xcodeinfo_cache $checkfile xcodeversion]
            && [dict exists $xcodeinfo_cache $checkfile xcodebuildcmd]} {
        if {[file mtime $checkfile] == [dict get $xcodeinfo_cache $checkfile mtime]} {
            if {!${xcodeversion_overridden}} {
                set xcodeversion [dict get $xcodeinfo_cache $checkfile xcodeversion]
            }
            if {!${xcodebuildcmd_overridden}} {
                set xcodebuildcmd [dict get $xcodeinfo_cache $checkfile xcodebuildcmd]
            }
            if {!$clt_refreshed} {
                return
            }
            set xcode_refresh 0
        } else {
            ui_debug "Xcode mtime has changed, refreshing version info"
        }
    }

    if {$xcode_refresh} {
    macports_try -pass_signal {
        set xcodebuild [findBinary xcodebuild $macports::autoconf::xcodebuild_path]
        if {!${xcodeversion_overridden}} {
            # Determine xcode version
            set xcodeversion 2.0orlower
            macports_try -pass_signal {
                set xcodebuildversion [exec -ignorestderr -- $xcodebuild -version 2> /dev/null]
                if {[regexp {Xcode ([0-9.]+)} $xcodebuildversion - xcode_v] == 1} {
                    set xcodeversion $xcode_v
                } elseif {[regexp {DevToolsCore-(.*);} $xcodebuildversion - devtoolscore_v] == 1} {
                    if {$devtoolscore_v >= 1809.0} {
                        set xcodeversion 3.2.6
                    } elseif {$devtoolscore_v >= 1763.0} {
                        set xcodeversion 3.2.5
                    } elseif {$devtoolscore_v >= 1705.0} {
                        set xcodeversion 3.2.4
                    } elseif {$devtoolscore_v >= 1691.0} {
                        set xcodeversion 3.2.3
                    } elseif {$devtoolscore_v >= 1648.0} {
                        set xcodeversion 3.2.2
                    } elseif {$devtoolscore_v >= 1614.0} {
                        set xcodeversion 3.2.1
                    } elseif {$devtoolscore_v >= 1608.0} {
                        set xcodeversion 3.2
                    } elseif {$devtoolscore_v >= 1204.0} {
                        set xcodeversion 3.1.4
                    } elseif {$devtoolscore_v >= 1192.0} {
                        set xcodeversion 3.1.3
                    } elseif {$devtoolscore_v >= 1148.0} {
                        set xcodeversion 3.1.2
                    } elseif {$devtoolscore_v >= 1114.0} {
                        set xcodeversion 3.1.1
                    } elseif {$devtoolscore_v >= 1100.0} {
                        set xcodeversion 3.1
                    } elseif {$devtoolscore_v >= 921.0} {
                        set xcodeversion 3.0
                    } elseif {$devtoolscore_v >= 798.0} {
                        set xcodeversion 2.5
                    } elseif {$devtoolscore_v >= 762.0} {
                        set xcodeversion 2.4.1
                    } elseif {$devtoolscore_v >= 757.0} {
                        set xcodeversion 2.4
                    } elseif {$devtoolscore_v >= 747.0} {
                        set xcodeversion 2.3
                    } elseif {$devtoolscore_v >= 650.0} {
                        set xcodeversion 2.2.1
                    } elseif {$devtoolscore_v > 620.0} {
                        # XXX find actual version corresponding to 2.2
                        set xcodeversion 2.2
                    } elseif {$devtoolscore_v >= 620.0} {
                        set xcodeversion 2.1
                    }
                }
            } on error {} {
                set xcodeversion none
            }
        }
        if {!${xcodebuildcmd_overridden}} {
            set xcodebuildcmd $xcodebuild
        }
    } on error {} {
        if {!${xcodeversion_overridden}} {
            set xcodeversion none
        }
        if {!${xcodebuildcmd_overridden}} {
            set xcodebuildcmd none
        }
    }
    }

    if {[file writable $portdbpath]} {
        if {$checkfile_found} {
            dict unset xcodeinfo_cache $checkfile
            # Don't cache overridden values
            if {!${xcodeversion_overridden} && !${xcodebuildcmd_overridden}} {
                dict set xcodeinfo_cache $checkfile xcodeversion $xcodeversion
                dict set xcodeinfo_cache $checkfile xcodebuildcmd $xcodebuildcmd
                dict set xcodeinfo_cache $checkfile mtime [file mtime $checkfile]
            }
        }
        # Remove any entries for Xcode installations that no longer exist
        set xcodeinfo_cache [dict filter $xcodeinfo_cache script {key info} {
            expr {[string index $key 0] ne "/" || [file isfile $key]}
        }]
        dict set xcodeinfo_cache os_major $os_major
        save_cache xcodeinfo $xcodeinfo_cache
    }
}

# deferred calculation of developer_dir
proc macports::set_developer_dir {name1 name2 op} {
    variable developer_dir

    trace remove variable developer_dir read macports::set_developer_dir

    if {[info exists developer_dir]} {
        return
    }

    # Look for xcodeselect, and make sure it has a valid value
    macports_try -pass_signal {
        set xcodeselect [findBinary xcode-select $macports::autoconf::xcode_select_path]

        # We have xcode-select: ask it where xcode is and check if it's valid.
        # If no xcode is selected, xcode-select will fail, so catch that
        macports_try -pass_signal {
            set devdir [exec -ignorestderr $xcodeselect -print-path 2> /dev/null]
            if {[_is_valid_developer_dir $devdir]} {
                set developer_dir $devdir
                return
            }
        } on error {} {}

        # The directory from xcode-select isn't correct.

        # Ask mdfind where Xcode is and make some suggestions for the user,
        # searching by bundle identifier for various Xcode versions (3.x and 4.x)
        set installed_xcodes [list]

        macports_try -pass_signal {
            set mdfind [findBinary mdfind $macports::autoconf::mdfind_path]
            set installed_xcodes [exec -ignorestderr $mdfind "kMDItemCFBundleIdentifier == 'com.apple.Xcode' || kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2> /dev/null]
        } on error {} {}

        # In case mdfind metadata wasn't complete, also look in two well-known locations for Xcode.app
        foreach app {/Applications/Xcode.app /Developer/Applications/Xcode.app} {
            if {[file isdirectory $app]} {
                lappend installed_xcodes $app
            }
        }

        # Form a list of unique xcode installations
        set installed_xcodes [lsort -unique $installed_xcodes]

        # Present instructions to the user
        ui_error
        macports_try -pass_signal {
            if {[llength $installed_xcodes] == 0} {
                error "No Xcode installation was found."
            }

            set mdls [findBinary mdls $macports::autoconf::mdls_path]

            # One, or more than one, Xcode installations found
            ui_error "No valid Xcode installation is properly selected."
            ui_error "Please use xcode-select to select an Xcode installation:"
            foreach xcode $installed_xcodes {
                set vers [exec -ignorestderr $mdls -raw -name kMDItemVersion $xcode 2> /dev/null]
                if {$vers eq {(null)}} {set vers unknown}
                if {[_is_valid_developer_dir ${xcode}/Contents/Developer]} {
                    # Though xcode-select shipped with xcode 4.3 supports and encourages
                    # direct use of the app path, older xcode-select does not.
                    # Specify the Contents/Developer directory if it exists
                    ui_error "    sudo xcode-select -switch ${xcode}/Contents/Developer # version $vers"
                } elseif {[vercmp $vers 4.3] >= 0} {
                    # Future proofing: fall back to the app-path only for xcode >= 4.3, since Contents/Developer doesn't exist
                    ui_error "    sudo xcode-select -switch $xcode # version $vers"
                } elseif {[_is_valid_developer_dir ${xcode}/../..]} {
                    # Older xcode (< 4.3) is below the developer directory
                    ui_error "    sudo xcode-select -switch [file normalize ${xcode}/../..] # version $vers"
                } else {
                    ui_error "    # malformed Xcode at ${xcode}, version $vers"
                }
            }
        } on error {} {
            ui_error "No Xcode installation was found."
            ui_error "Please install Xcode and/or run xcode-select to specify its location."
        }
        ui_error
    } on error {} {}

    # Try the default
    variable os_major
    variable xcodeversion
    if {$os_major >= 11 && ([vercmp $xcodeversion 4.3] >= 0 ||
        ($xcodeversion eq {} && [file exists /Applications/Xcode.app/Contents/Developer]))
    } {
        set developer_dir /Applications/Xcode.app/Contents/Developer
    } else {
        set developer_dir /Developer
    }
}

proc macports::_is_valid_developer_dir {dir} {
    # Check whether specified directory looks valid for an Xcode installation

    # Verify that the directory exists
    if {![file isdirectory $dir]} {
        return 0
    }

    # Verify that the directory has some key subdirectories
    foreach subdir {Library usr} {
        if {![file isdirectory ${dir}/$subdir]} {
            return 0
        }
    }

    # The specified directory seems valid for Xcode
    return 1
}

# deferred calculation of xcodecltversion
# @return 1 if cachevar has been updated, 0 otherwise
proc macports::set_xcodecltversion {cachevar} {
    variable xcodecltversion

    trace remove variable xcodecltversion read macports::setxcodeinfo

    if {[info exists xcodecltversion]} {
        return 0
    }
    # Same test as used to set the default for use_xcode
    if {![file executable /Library/Developer/CommandLineTools/usr/bin/make]} {
        set xcodecltversion none
        return 0
    }

    upvar $cachevar cache
    if {[dict exists $cache clt version] && [dict exists $cache clt mtime]
            && [dict exists $cache clt checkfile]} {
        set checkfile [dict get $cache clt checkfile]
        if {[file exists $checkfile]
             && [file mtime $checkfile] == [dict get $cache clt mtime]} {
            set xcodecltversion [dict get $cache clt version]
            return 0
        }
    }

    # Potential names for the CLTs pkg on different OS versions.
    set pkgnames [list CLTools_Executables CLTools_Base DeveloperToolsCLI DeveloperToolsCLILeo]

    if {[catch {exec -ignorestderr /usr/sbin/pkgutil --pkgs=com\\.apple\\.pkg\\.([join $pkgnames |]) 2> /dev/null} result]} {
        set xcodecltversion none
        return 0
    }
    set pkgs [split $result \n]
    set found_pkgname {}
    # Check in order from newest to oldest, just in case something
    # stuck around from an older OS version.
    foreach pkgname $pkgnames {
        set fullpkgname com.apple.pkg.${pkgname}
        if {$fullpkgname in $pkgs} {
            if {![catch {exec -ignorestderr /usr/sbin/pkgutil --pkg-info $fullpkgname 2> /dev/null} result]} {
                foreach line [split $result \n] {
                    lassign [split $line] name val
                    if {$name eq "version:"} {
                        set xcodecltversion $val
                        set found_pkgname $fullpkgname
                        break
                    }
                }
                if {$found_pkgname ne {}} {
                    break
                }
            } else {
                ui_debug "set_xcodecltversion: Failed to get info for installed pkg ${fullpkgname}: $result"
            }
        }
    }

    if {$found_pkgname ne {}} {
        # TODO: See if there are more possible locations.
        foreach dir {/Library/Apple/System/Library/Receipts /System/Library/Receipts /private/var/db/receipts} {
            set checkfile ${dir}/${found_pkgname}.plist
            if {[file exists $checkfile]} {
                dict set cache clt checkfile $checkfile
                dict set cache clt mtime [file mtime $checkfile]
                dict set cache clt version $xcodecltversion
                return 1
            }
        }
    } else {
        set xcodecltversion none
    }
    return 0
}

proc macports::set_xcode_license_unaccepted {name1 name2 op} {
    variable xcode_license_unaccepted

    trace remove variable xcode_license_unaccepted read macports::set_xcode_license_unaccepted

    if {[info exists xcode_license_unaccepted]} {
        return
    }

    catch {exec [findBinary xcrun $macports::autoconf::xcrun_path] clang 2>@1} output
    set output [join [lrange [split $output "\n"] 0 end-1] "\n"]
    if {[string match -nocase "*license*" $output]} {
        set xcode_license_unaccepted yes
        return
    }

    set xcode_license_unaccepted no
}


proc mportinit {{up_ui_options {}} {up_options {}} {up_variations {}}} {
    global auto_noexec env tcl_platform \
        macports::autoconf::macports_conf_path \
        macports::macports_user_dir \
        macports::user_home \
        macports::user_path \
        macports::sudo_user \
        macports::user_ssh_auth_sock \
        macports::bootstrap_options \
        macports::user_options \
        macports::portsharepath \
        macports::registry.format \
        macports::registry.path \
        macports::rsync_dir \
        macports::rsync_options \
        macports::rsync_server \
        macports::sources \
        macports::sources_default \
        macports::destroot_umask \
        macports::macportsuser \
        macports::prefix_frozen \
        macports::applications_dir \
        macports::applications_dir_frozen \
        macports::frameworks_dir_frozen \
        macports::developer_dir \
        macports::xcodebuildcmd \
        macports::xcodeversion \
        macports::xcodecltversion \
        macports::xcode_license_unaccepted \
        macports::configureccache \
        macports::ccache_dir \
        macports::ccache_size \
        macports::configuredistcc \
        macports::configurepipe \
        macports::buildnicevalue \
        macports::buildmakejobs \
        macports::host_blacklist \
        macports::preferred_hosts \
        macports::keeplogs \
        macports::place_worksymlink \
        macports::revupgrade_autorun \
        macports::revupgrade_mode \
        macports::sandbox_enable \
        macports::sandbox_network \
        macports::startupitem_autostart \
        macports::startupitem_install \
        macports::startupitem_type \
        macports::buildfromsource \
        macports::portarchivetype \
        macports::portautoclean \
        macports::portautoclean_frozen \
        macports::portimage_mode \
        macports::porttrace \
        macports::porttrace_frozen \
        macports::portverbose \
        macports::portverbose_frozen \
        macports::universal_archs \
        macports::build_arch \
        macports::os_arch \
        macports::os_endian \
        macports::os_version \
        macports::os_major \
        macports::os_minor \
        macports::os_platform \
        macports::os_subplatform \
        macports::macos_version \
        macports::macos_version_major \
        macports::macosx_version \
        macports::macosx_sdk_version \
        macports::macosx_deployment_target \
        macports::archivefetch_pubkeys \
        macports::delete_la_files \
        macports::cxx_stdlib \
        macports::hfscompression \
        macports::portarchive_hfscompression \
        macports::host_cache \
        macports::porturl_prefix_map \
        macports::ui_options \
        macports::global_options \
        macports::global_variations

    # Disable unknown(n)'s behavior of running unknown commands in the system
    # shell
    set auto_noexec yes

    if {$up_ui_options eq {}} {
        array set ui_options {}
    } else {
        upvar $up_ui_options temp_ui_options
        array set ui_options [array get temp_ui_options]
    }
    if {$up_options eq {}} {
        array set global_options {}
    } else {
        upvar $up_options temp_options
        array set global_options [array get temp_options]
    }
    if {$up_variations eq {}} {
        array set variations {}
    } else {
        upvar $up_variations variations
    }

    # Initialize ui_* channels
    macports::ui_init_all

    package require Pextlib 1.0
    package require registry 1.0
    package require registry2 2.0
    package require machista 1.0

    # Set the system encoding to utf-8
    encoding system utf-8

    # Set up signal handling for SIGTERM and SIGINT
    # Specifying error here will case the program to abort where it is with
    # a Tcl error, which can be caught, if necessary.
    signal -restart error {TERM INT}

    # Set RLIMIT_NOFILE to the maximum possible
    set_max_open_files

    # set up platform info variables
    set os_arch $tcl_platform(machine)
    # Set os_arch to match `uname -p`
    switch -glob $os_arch {
       "Power Macintosh" -
       ppc* {
           set os_arch powerpc
       }
       i[3-7]86 -
       x86_64 {
           set os_arch i386
       }
       arm* -
       aarch* {
           set os_arch arm
       }
    }
    set os_version $tcl_platform(osVersion)
    set os_major [lindex [split $os_version .] 0]
    set os_minor [lindex [split $os_version .] 1]
    set os_platform [string tolower $tcl_platform(os)]
    # Remove trailing "Endian"
    set os_endian [string range $tcl_platform(byteOrder) 0 end-6]
    set os_subplatform {}
    set macos_version {}
    if {$os_platform eq "darwin"} {
        if {[file isdirectory /System/Library/Frameworks/Carbon.framework]} {
            # macOS
            set os_subplatform macosx
        } else {
            # PureDarwin
            set os_subplatform puredarwin
        }
    }

    # Ensure that the macports user directory (i.e. ~/.macports) exists if HOME is defined.
    # Also save $HOME for later use before replacing it with our own.
    if {[info exists env(HOME)]} {
        set user_home $env(HOME)
        # XXX Relying on file normalize to do tilde expansion for
        # macports::autoconf::macports_user_dir will not work in Tcl 9.
        set macports_user_dir [file normalize $macports::autoconf::macports_user_dir]
    } elseif {[info exists env(SUDO_USER)] && $os_platform eq "darwin"} {
        set user_home [exec -ignorestderr dscl -q . -read /Users/$env(SUDO_USER) NFSHomeDirectory | cut -d ' ' -f 2]
        set macports_user_dir [file join $user_home [string range $macports::autoconf::macports_user_dir 2 end]]
    } elseif {[exec id -u] != 0 && $os_platform eq "darwin"} {
        set user_home [exec -ignorestderr dscl -q . -read /Users/[exec -ignorestderr id -un 2> /dev/null] NFSHomeDirectory | cut -d ' ' -f 2]
        set macports_user_dir [file join $user_home [string range $macports::autoconf::macports_user_dir 2 end]]
    } else {
        # Otherwise define the user directory as a directory that will never exist
        set macports_user_dir /dev/null/NO_HOME_DIR
        set user_home /dev/null/NO_HOME_DIR
    }

    # Save the path for future processing
    set user_path $env(PATH)
    # Likewise any SUDO_USER
    if {[info exists env(SUDO_USER)]} {
        set sudo_user $env(SUDO_USER)
    }

    # Save SSH_AUTH_SOCK for ports tree sync
    if {[info exists env(SSH_AUTH_SOCK)]} {
        set user_ssh_auth_sock $env(SSH_AUTH_SOCK)
    }

    # Configure the search path for configuration files
    set conf_files [list]
    lappend conf_files ${macports_conf_path}/macports.conf
    if {[file isdirectory $macports_user_dir]} {
        lappend conf_files ${macports_user_dir}/macports.conf
    }
    if {[info exists env(PORTSRC)]} {
        set PORTSRC $env(PORTSRC)
        lappend conf_files $PORTSRC
    }

    # Process all configuration files we find on conf_files list
    set conf_option_re {^(\w+)([ \t]+(.*))?$}
    foreach file $conf_files {
        if {[file exists $file]} {
            set fd [open $file r]
            set continuation 0
            while {[gets $fd line] >= 0} {
                set next_continuation [expr {[string index $line end] eq "\\"}]
                if {$next_continuation} {
                    set line [string range $line 0 end-1]
                }
                if {$continuation} {
                    set val $line
                } elseif {[regexp $conf_option_re $line match option ignore val] != 1} {
                    continue
                }
                if {[dict exists $bootstrap_options $option]} {
                    global macports::$option
                    set val [string trim $val]
                    if {[dict exists $bootstrap_options $option is_path]} {
                        if {[catch {set $option [realpath $val]}]} {
                            set $option [file normalize $val]
                        }
                    } elseif {$continuation} {
                        lappend $option {*}$val
                    } else {
                        set $option $val
                    }
                }
                set continuation $next_continuation
            }
            close $fd
        }
    }

    # Process per-user only settings
    set per_user ${macports_user_dir}/user.conf
    if {[file exists $per_user]} {
        set fd [open $per_user r]
        while {[gets $fd line] >= 0} {
            if {[regexp $conf_option_re $line match option ignore val] == 1} {
                if {$option in $user_options} {
                    global macports::$option
                    set $option $val
                }
            }
        }
        close $fd
    }

    if {![info exists sources_conf]} {
        return -code error "sources_conf must be set in ${macports_conf_path}/macports.conf or in your ${macports_user_dir}/macports.conf file"
    }
    # Precompute mapping of source URLs to prefix to use for porturls (used in mportlookup etc)
    set porturl_prefix_map [dict create]
    set sources_conf_comment_re {^\s*#|^$}
    set sources_conf_source_re {^([\w-]+://\S+)(?:\s+\[(\w+(?:,\w+)*)\])?$}
    set fd [open $sources_conf r]
    while {[gets $fd line] >= 0} {
        set line [string trimright $line]
        if {![regexp $sources_conf_comment_re $line]} {
            if {[regexp $sources_conf_source_re $line _ url flags]} {
                set flags [split $flags ,]
                foreach flag $flags {
                    if {$flag ni [list nosync default]} {
                        ui_warn "$sources_conf source '$line' specifies invalid flag '$flag'"
                    }
                    if {$flag eq "default"} {
                        if {[info exists sources_default]} {
                            ui_warn "More than one default port source is defined."
                        }
                        set sources_default [concat [list $url] $flags]
                    }
                }
                if {[string match rsync://*rsync.macports.org/release/ports/ $url]} {
                    ui_warn "MacPorts is configured to use an unsigned source for the ports tree.\
Please edit sources.conf and change '$url' to '[string range $url 0 end-14]macports/release/tarballs/ports.tar'."
                } elseif {[string match rsync://rsync.macports.org/release/* $url]} {
                    ui_warn "MacPorts is configured to use an older rsync URL for the ports tree.\
Please edit sources.conf and change '$url' to '[string range $url 0 26]macports/release/tarballs/ports.tar'."
                }
                switch -- [macports::getprotocol $url] {
                    rsync -
                    https -
                    http -
                    ftp {
                        # Rsync and snapshot tarballs create Portfiles in the local filesystem
                        dict set porturl_prefix_map $url file://[macports::getsourcepath $url]
                    }
                    default {
                        dict set porturl_prefix_map $url $url
                    }
                }
                lappend sources [concat [list $url] $flags]
            } else {
                ui_warn "$sources_conf specifies invalid source '$line', ignored."
            }
        }
    }
    close $fd

    if {![info exists sources]} {
        if {[file isdirectory ports]} {
            set sources file://[pwd]/ports
        } else {
            return -code error "No sources defined in $sources_conf"
        }
    }
    # Make sure the default port source is defined. Otherwise
    # [macports::getportresourcepath] fails when the first source doesn't
    # contain _resources.
    if {![info exists sources_default]} {
        ui_warn "No default port source specified in ${sources_conf}, using last source as default"
        set sources_default [lindex $sources end]
    }

    # regex also used by pubkeys.conf
    set variants_conf_comment_re {^[\ \t]*#.*$|^$}
    if {[info exists variants_conf]} {
        if {[file exists $variants_conf]} {
            set variants_conf_setting_re {^([-+])([-A-Za-z0-9_+\.]+)$}
            set fd [open $variants_conf r]
            while {[gets $fd line] >= 0} {
                set line [string trimright $line]
                if {![regexp $variants_conf_comment_re $line]} {
                    foreach arg [split $line " \t"] {
                        if {[regexp $variants_conf_setting_re $arg match sign opt] == 1} {
                            if {![info exists variations($opt)]} {
                                set variations($opt) $sign
                            }
                        } else {
                            ui_warn "$variants_conf specifies invalid variant syntax '$arg', ignored."
                        }
                    }
                }
            }
            close $fd
        } else {
            ui_debug "$variants_conf does not exist, variants_conf setting ignored."
        }
    }
    array set global_variations [array get variations]

    # archive_sites.conf
    if {![info exists archive_sites_conf]} {
        global macports::archive_sites_conf
        set archive_sites_conf [file join $macports_conf_path archive_sites.conf]
    }

    # pubkeys.conf
    if {![info exists pubkeys_conf]} {
        global macports::pubkeys_conf
        set pubkeys_conf [file join $macports_conf_path pubkeys.conf]
    }
    set archivefetch_pubkeys [list]
    if {[file isfile $pubkeys_conf]} {
        set fd [open $pubkeys_conf r]
        while {[gets $fd line] >= 0} {
            set line [string trim $line]
            if {![regexp $variants_conf_comment_re $line]} {
                lappend archivefetch_pubkeys $line
            }
        }
        close $fd
    } else {
        ui_debug "pubkeys.conf does not exist."
    }

    if {![info exists prefix]} {
        return -code error "prefix must be set in ${macports_conf_path}/macports.conf or in your ${macports_user_dir}/macports.conf"
    }
    if {![info exists portdbpath]} {
        return -code error "portdbpath must be set in ${macports_conf_path}/macports.conf or in your ${macports_user_dir}/macports.conf"
    }
    if {![file isdirectory $portdbpath]} {
        if {![file exists $portdbpath]} {
            if {[catch {file mkdir $portdbpath} result]} {
                return -code error "portdbpath $portdbpath does not exist and could not be created: $result"
            }
        } else {
            return -code error "$portdbpath is not a directory. Please create the directory $portdbpath and try again"
        }
    }

    # Get macOS version (done here because caches can't be used before portdbpath is known)
    if {$os_subplatform eq "macosx"} {
        # load cached macOS version
        set macos_version_cache [macports::load_cache macos_version]
        set checkfile /System/Library/CoreServices/SystemVersion.plist
        set checkfile_mtime [expr {[file isfile $checkfile] ? [file mtime $checkfile] : {}}]
        if {[dict exists $macos_version_cache macos_version]
                && [dict exists $macos_version_cache mtime]
                && $checkfile_mtime == [dict get $macos_version_cache mtime]} {
            set macos_version [dict get $macos_version_cache macos_version]
        } elseif {[file executable /usr/bin/sw_vers]} {
            ui_debug "Refreshing cached macOS version"
            set macos_version_cache [dict create]
            macports_try -pass_signal {
                set macos_version [exec -ignorestderr /usr/bin/sw_vers -productVersion 2> /dev/null]
                # Only update cache if it can be written out
                if {$checkfile_mtime ne {} && [file writable $portdbpath]} {
                    dict set macos_version_cache mtime $checkfile_mtime
                    dict set macos_version_cache macos_version $macos_version
                }
            } on error {eMessage} {
                ui_debug "sw_vers exists but running it failed: $eMessage"
            }
            if {[dict exists $macos_version_cache macos_version]
                 && [dict exists $macos_version_cache mtime]} {
                macports::save_cache macos_version $macos_version_cache
            }
        } else {
            ui_debug "sw_vers executable not found; can't get macOS version"
        }
    }
    if {[vercmp $macos_version 11] >= 0} {
        # Big Sur is apparently any 11.x version
        set macos_version_major [lindex [split $macos_version .] 0]
    } else {
        set macos_version_major [join [lrange [split $macos_version .] 0 1] .]
    }
    # backward compatibility synonym
    set macosx_version $macos_version_major

    set env(HOME) [file join $portdbpath home]
    set registry.path $portdbpath

    # Format for receipts; currently only "sqlite" is allowed
    # could previously be "flat", so we switch that to sqlite
    if {![info exists portdbformat] || $portdbformat eq "flat" || $portdbformat eq "sqlite"} {
        set registry.format receipt_sqlite
    } else {
        return -code error "unknown registry format '$portdbformat' set in macports.conf"
    }

    # Autoclean mode, whether to automatically call clean after "install"
    if {![info exists portautoclean]} {
        set portautoclean yes
    }
    set portautoclean_frozen $portautoclean
    # whether to keep logs after successful builds
    if {![info exists keeplogs]} {
        set keeplogs no
    }

    # Check command line override for autoclean
    if {[info exists global_options(ports_autoclean)]} {
        if {$global_options(ports_autoclean) ne $portautoclean} {
            set portautoclean $global_options(ports_autoclean)
        }
    }
    # Trace mode, whether to use darwintrace to debug ports.
    if {![info exists porttrace]} {
        set porttrace no
    }
    set porttrace_frozen $porttrace
    # Check command line override for trace
    if {[info exists global_options(ports_trace)]} {
        if {$global_options(ports_trace) ne $porttrace} {
            set porttrace $global_options(ports_trace)
        }
    }
    # Check command line override for source/binary only mode
    if {![info exists global_options(ports_binary_only)]
        && ![info exists global_options(ports_source_only)]
        && [info exists buildfromsource]} {
        if {$buildfromsource eq "never"} {
            set global_options(ports_binary_only) yes
            set temp_options(ports_binary_only) yes
        } elseif {$buildfromsource eq "always"} {
            set global_options(ports_source_only) yes
            set temp_options(ports_source_only) yes
        } elseif {$buildfromsource ne "ifneeded"} {
            ui_warn "'buildfromsource' set to unknown value '$buildfromsource', using 'ifneeded' instead"
        }
    }

    # Duplicate prefix into prefix_frozen, so that port actions
    # can always get to the original prefix, even if a portfile overrides prefix
    set prefix_frozen $prefix

    if {![info exists applications_dir]} {
        set applications_dir /Applications/MacPorts
    }
    set applications_dir_frozen ${applications_dir}

    if {[info exists frameworks_dir]} {
        set frameworks_dir_frozen ${frameworks_dir}
    } else {
        set frameworks_dir_frozen ${prefix_frozen}/Library/Frameworks
    }

    # Export verbosity.
    if {![info exists portverbose]} {
        set portverbose no
    }
    set portverbose_frozen $portverbose
    if {[info exists ui_options(ports_verbose)]} {
        if {$ui_options(ports_verbose) ne $portverbose} {
            set portverbose $ui_options(ports_verbose)
        }
    }

    # Set noninteractive mode if specified in config
    if {[info exists ui_interactive] && !$ui_interactive} {
        set ui_options(ports_noninteractive) yes
        unset -nocomplain ui_options(questions_yesno) \
                          ui_options(questions_singlechoice) \
                          ui_options(questions_multichoice) \
                          ui_options(questions_alternative)

    }

    # Archive type, what type of binary archive to use (CPIO, gzipped
    # CPIO, XAR, etc.)
    if {![info exists portarchivetype]} {
        set portarchivetype tbz2
    } else {
        set portarchivetype [lindex $portarchivetype 0]
    }

    # How to store port images
    if {[info exists portimage_mode] &&
        $portimage_mode ni {archive directory directory_and_archive}} {
        ui_warn "Unknown portimage_mode value '$portimage_mode', using default"
        unset portimage_mode
    }
    if {![info exists portimage_mode]} {
        # Using an extracted directory is usually only a good idea if
        # the filesystem supports COW clones.
        if {![catch {fs_clone_capable [file join $portdbpath software]} result] && $result} {
            set portimage_mode directory
        } else {
            set portimage_mode archive
        }
    }
    set portimage::keep_imagedir [expr {$portimage_mode ne "archive"}]
    set portimage::keep_archive [expr {$portimage_mode ne "directory"}]

    # Enable HFS+ compression by default
    if {![info exists hfscompression]} {
        set hfscompression yes
    }
    set portarchive_hfscompression $hfscompression

    # Set rync options
    if {![info exists rsync_server]} {
        set rsync_server rsync.macports.org
    }
    if {![info exists rsync_dir]} {
        set rsync_dir macports/release/tarballs/base.tar
    } elseif {[string range $rsync_dir end-3 end] ne ".tar" && [string match *.macports.org ${rsync_server}]} {
        ui_warn "MacPorts is configured to use an unsigned source for selfupdate.\
Please edit macports.conf and change the rsync_dir setting to\
match macports.conf.default."
    }
    if {![info exists rsync_options]} {
        set rsync_options {-rtzvl --delete-after}
    }

    set portsharepath ${prefix}/share/macports
    if {![file isdirectory $portsharepath]} {
        return -code error "Data files directory '$portsharepath' must exist"
    }

    if {![info exists binpath]} {
        set env(PATH) ${prefix}/bin:${prefix}/sbin:/bin:/sbin:/usr/bin:/usr/sbin
    } else {
        set env(PATH) $binpath
    }

    # Set startupitem default type (can be overridden by portfile)
    if {![info exists startupitem_type]} {
        set startupitem_type default
    }

    # Set whether startupitems are symlinked into system directories
    if {![info exists startupitem_install]} {
        set startupitem_install yes
    }

    # Set whether ports are allowed to auto-load their startupitems
    if {![info exists startupitem_autostart]} {
        set startupitem_autostart yes
    }

    # Default place_worksymlink
    if {![info exists place_worksymlink]} {
        set place_worksymlink yes
    }

    # Default mp configure options
    if {![info exists configureccache]} {
        set configureccache no
    }
    if {![info exists ccache_dir]} {
        set ccache_dir [file join $portdbpath build .ccache]
    }
    if {![info exists ccache_size]} {
        set ccache_size 2G
    }
    if {![info exists configuredistcc]} {
        set configuredistcc no
    }
    if {![info exists configurepipe]} {
        set configurepipe yes
    }

    # Default mp build options
    if {![info exists buildnicevalue]} {
        set buildnicevalue 0
    }
    if {![info exists buildmakejobs]} {
        set buildmakejobs 0
    }

    # default user to run as when privileges can be dropped
    if {![info exists macportsuser]} {
        set macportsuser $macports::autoconf::macportsuser
    }

    # Default mp universal options
    if {![info exists universal_archs]} {
        if {$os_major >= 20} {
            set universal_archs [list arm64 x86_64]
        } elseif {$os_major >= 19} {
            set universal_archs [list x86_64]
        } elseif {$os_major >= 10} {
            set universal_archs [list x86_64 i386]
        } else {
            set universal_archs [list i386 ppc]
        }
    } elseif {[llength $universal_archs] == 1} {
        # allow empty value to disable universal
        if {$os_major < 18 || $os_major > 19} {
            ui_warn "invalid universal_archs configured (should contain at least 2 archs)"
        }
    }

    # Default arch to build for
    if {![info exists build_arch]} {
        if {$os_platform eq "darwin"} {
            if {$os_major >= 20} {
                if {$os_arch eq "arm" || (![catch {sysctl sysctl.proc_translated} translated] && $translated)} {
                    set build_arch arm64
                } else {
                    set build_arch x86_64
                }
            } elseif {$os_major >= 10} {
                if {[sysctl hw.cpu64bit_capable] == 1} {
                    set build_arch x86_64
                } else {
                    set build_arch i386
                }
            } else {
                if {$os_arch eq "powerpc"} {
                    set build_arch ppc
                } else {
                    set build_arch i386
                }
            }
        } else {
            switch -glob $tcl_platform(machine) {
               "Power Macintosh" -
               ppc* {
                   set build_arch ppc
               }
               i[3-7]86 {
                   set build_arch i386
               }
               x86_64 {
                   set build_arch x86_64
               }
               arm* -
               aarch* {
                   set build_arch arm64
               }
               default {
                   set build_arch {}
               }
            }
        }
    } else {
        set build_arch [lindex $build_arch 0]
    }

    # Check that the current platform is the one we were configured for, otherwise need to do migration
    set skip_migration_check [expr {[info exists macports::global_options(ports_no_migration_check)] && $macports::global_options(ports_no_migration_check)}]
    if {!$skip_migration_check && [migrate::needs_migration migrate_reason]} {
        ui_error $migrate_reason
        ui_error "Please run 'sudo port migrate' or follow the migration instructions: https://trac.macports.org/wiki/Migration"
        return -code error "OS platform mismatch"
    }

    if {![info exists macosx_deployment_target]} {
        if {[vercmp $macos_version 11] >= 0} {
            set macosx_deployment_target ${macos_version_major}.0
        } else {
            set macosx_deployment_target $macos_version_major
        }
    }
    if {![info exists macosx_sdk_version]} {
        set macosx_sdk_version $macos_version_major
    }

    if {![info exists revupgrade_autorun]} {
        if {$os_platform eq "darwin"} {
            set revupgrade_autorun yes
        } else {
            set revupgrade_autorun no
        }
    }
    if {![info exists revupgrade_mode]} {
        set revupgrade_mode rebuild
    }
    if {![info exists delete_la_files]} {
        if {$os_platform eq "darwin" && $os_major >= 13} {
            set delete_la_files yes
        } else {
            set delete_la_files no
        }
    }
    if {![info exists cxx_stdlib]} {
        if {$os_platform eq "darwin" && $os_major >= 10} {
            set cxx_stdlib libc++
        } elseif {$os_platform eq "darwin"} {
            set cxx_stdlib libstdc++
        } else {
            set cxx_stdlib {}
        }
    }
    if {![info exists global_options(ports_rev-upgrade_id-loadcmd-check)]
         && [info exists revupgrade_check_id_loadcmds]} {
        set global_options(ports_rev-upgrade_id-loadcmd-check) $revupgrade_check_id_loadcmds
        set temp_options(ports_rev-upgrade_id-loadcmd-check) $revupgrade_check_id_loadcmds
    }

    if {![info exists sandbox_enable]} {
        set sandbox_enable yes
    }

    if {![info exists sandbox_network]} {
        set sandbox_network no
    }

    # make tools we run operate in UTF-8 mode
    set env(LANG) en_US.UTF-8

    # ENV cleanup.
    set keepenvkeys {
        DISPLAY DYLD_FALLBACK_FRAMEWORK_PATH
        DYLD_FALLBACK_LIBRARY_PATH DYLD_FRAMEWORK_PATH
        DYLD_LIBRARY_PATH DYLD_INSERT_LIBRARIES
        HOME JAVA_HOME MASTER_SITE_LOCAL ARCHIVE_SITE_LOCAL
        PATCH_SITE_LOCAL PATH PORTSRC RSYNC_PROXY
        USER GROUP LANG
        http_proxy HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
        COLUMNS LINES
    }
    if {[info exists extra_env]} {
        set keepenvkeys [concat $keepenvkeys $extra_env]
    }

    # set the hidden flag on $portdbpath to avoid spotlight indexing, which
    # might slow builds down considerably. You can avoid this by touching
    # $portdbpath/.nohide.
    if {$os_platform eq "darwin" && ![file exists [file join $portdbpath .nohide]] && [file writable $portdbpath] && [file attributes $portdbpath -hidden] == 0} {
        macports_try -pass_signal {
            file attributes $portdbpath -hidden yes
        } on error {eMessage} {
            ui_debug "error setting hidden flag for $portdbpath: $eMessage"
        }
    }

    # don't keep unusable TMPDIR/TMP values
    foreach var {TMP TMPDIR} {
        if {[info exists env($var)] && [file writable $env($var)] &&
            ([getuid] != 0 || $macportsuser eq "root" ||
             [file attributes $env($var) -owner] eq $macportsuser)} {
            lappend keepenvkeys $var
        }
    }

    foreach envkey [array names env] {
        if {$envkey ni $keepenvkeys} {
            unset env($envkey)
        }
    }

    if {$os_platform eq "darwin"} {
        if {![info exists xcodeversion] || ![info exists xcodebuildcmd] || ![info exists xcodecltversion]} {
            # We'll resolve these later (if needed)
            trace add variable xcodeversion read macports::setxcodeinfo
            trace add variable xcodebuildcmd read macports::setxcodeinfo
            trace add variable xcodecltversion read macports::setxcodeinfo
        }
    } else {
        set xcodeversion none
        set xcodebuildcmd none
        set xcodecltversion none
    }

    if {![info exists xcode_license_unaccepted]} {
        if {$os_platform eq "darwin"} {
            trace add variable xcode_license_unaccepted read macports::set_xcode_license_unaccepted
        } else {
            set xcode_license_unaccepted no
        }
    }

    if {![info exists developer_dir]} {
        if {$os_platform eq "darwin"} {
            trace add variable developer_dir read macports::set_developer_dir
        } else {
            set developer_dir {}
        }
    } else {
        if {$os_platform eq "darwin" && ![file isdirectory $developer_dir]} {
            ui_warn "Your developer_dir setting in macports.conf points to a non-existing directory.\
                Since this is known to cause problems, please correct the setting or comment it and let\
                macports auto-discover the correct path."
        }
    }

    if {[getuid] == 0 && $os_major >= 11 && $os_platform eq "darwin"} {
        macports::copy_xcode_plist $env(HOME)
    }

    # Set the default umask
    if {![info exists destroot_umask]} {
        set destroot_umask 022
    }

    if {[info exists master_site_local] && ![info exists env(MASTER_SITE_LOCAL)]} {
        set env(MASTER_SITE_LOCAL) $master_site_local
    }
    if {[info exists patch_site_local] && ![info exists env(PATCH_SITE_LOCAL)]} {
        set env(PATCH_SITE_LOCAL) $patch_site_local
    }
    if {[info exists archive_site_local] && ![info exists env(ARCHIVE_SITE_LOCAL)]} {
        set env(ARCHIVE_SITE_LOCAL) $archive_site_local
    }

    # Proxy handling (done this late since Pextlib is needed)
    if {![info exists proxy_override_env] || ![string is true -strict $proxy_override_env]} {
        set proxy_override_env no
    }
    if {[catch {array set sysConfProxies [get_systemconfiguration_proxies]} result]} {
        return -code error "Unable to get proxy configuration from system: $result"
    }
    if {![info exists env(http_proxy)] || $proxy_override_env} {
        if {[info exists proxy_http]} {
            set env(http_proxy) $proxy_http
        } elseif {[info exists sysConfProxies(proxy_http)]} {
            set env(http_proxy) $sysConfProxies(proxy_http)
        }
    }
    if {![info exists env(HTTPS_PROXY)] || $proxy_override_env} {
        if {[info exists proxy_https]} {
            set env(HTTPS_PROXY) $proxy_https
        } elseif {[info exists sysConfProxies(proxy_https)]} {
            set env(HTTPS_PROXY) $sysConfProxies(proxy_https)
        }
    }
    if {![info exists env(FTP_PROXY)] || $proxy_override_env} {
        if {[info exists proxy_ftp]} {
            set env(FTP_PROXY) $proxy_ftp
        } elseif {[info exists sysConfProxies(proxy_ftp)]} {
            set env(FTP_PROXY) $sysConfProxies(proxy_ftp)
        }
    }
    if {![info exists env(RSYNC_PROXY)] || $proxy_override_env} {
        if {[info exists proxy_rsync]} {
            set env(RSYNC_PROXY) $proxy_rsync
        }
    }
    if {![info exists env(NO_PROXY)] || $proxy_override_env} {
        if {[info exists proxy_skip]} {
            set env(NO_PROXY) $proxy_skip
        } elseif {[info exists sysConfProxies(proxy_skip)]} {
            set env(NO_PROXY) $sysConfProxies(proxy_skip)
        }
    }

    # add ccache to environment
    set env(CCACHE_DIR) $ccache_dir

    # load caches on demand
    trace add variable macports::compiler_version_cache read macports::load_compiler_version_cache
    trace add variable macports::ping_cache {read write} macports::load_ping_cache
    if {![info exists host_blacklist]} {
        set host_blacklist {}
    }
    if {![info exists preferred_hosts]} {
        set preferred_hosts {}
    }
    set host_cache [dict create]

    # load the quick index unless told not to
    if {![macports::global_option_isset ports_no_load_quick_index]} {
        trace add variable macports::quick_index {read write} macports::load_quickindex
    }

    # load variant descriptions file on demand
    trace add variable macports::default_variant_descriptions read macports::load_default_variant_descriptions

    if {![info exists ui_options(ports_no_old_index_warning)]} {
        set default_source_url [lindex $sources_default 0]
        if {[macports::getprotocol $default_source_url] eq "file" || [macports::getprotocol $default_source_url] eq "rsync"} {
            set default_portindex [macports::getindex $default_source_url]
            if {[file exists $default_portindex] && [clock seconds] - [file mtime $default_portindex] > 1209600} {
                ui_warn "port definitions are more than two weeks old, consider updating them by running 'port selfupdate'."
            }
        }
    }

    # init registry
    set db_path [file join ${registry.path} registry registry.db]
    set db_exists [file exists $db_path]
    registry::open $db_path

    # convert any flat receipts if we just created a new db
    if {$db_exists == 0 && [file exists ${registry.path}/receipts] && [file writable $db_path]} {
        ui_warn "Converting your registry to sqlite format, this might take a while..."
        if {[catch {registry::convert_to_sqlite}]} {
            ui_debug $::errorInfo
            file delete -force $db_path
            error "Failed to convert your registry to sqlite!"
        } else {
            ui_warn "Successfully converted your registry to sqlite!"
        }
    }
}

# call this just before you exit
proc mportshutdown {} {
    global macports::portdbpath
    # save cached values
    if {[file writable $portdbpath]} {
        global macports::ping_cache macports::compiler_version_cache \
               macports::cache_dirty
        # Only save the cache if it was updated
        if {[dict exists $cache_dirty pingtimes]} {
            # don't save expired entries
            set now [clock seconds]
            set pinglist_fresh [dict filter $ping_cache script {host entry} {
                expr {$now - [lindex $entry 1] < 86400}
            }]
            macports::save_cache pingtimes $pinglist_fresh
        }
        if {[dict exists $cache_dirty compiler_versions]} {
            macports::save_cache compiler_versions $compiler_version_cache
        }
    }

    # close it down so the cleanup stuff is called, e.g. vacuuming the db
    registry::close
}

# link plist for xcode 4.3's benefit
proc macports::copy_xcode_plist {target_homedir} {
    variable user_home; variable macportsuser
    set user_plist "${user_home}/Library/Preferences/com.apple.dt.Xcode.plist"
    set target_dir "${target_homedir}/Library/Preferences"
    file delete -force "${target_dir}/com.apple.dt.Xcode.plist"
    if {[file isfile $user_plist]} {
        if {![file isdirectory $target_dir]} {
            macports_try -pass_signal {
                file mkdir $target_dir
            } on error {eMessage} {
                ui_warn "Failed to create Library/Preferences in ${target_homedir}: $eMessage"
                return
            }
        }
        macports_try -pass_signal {
            if {![file writable $target_dir]} {
                error "${target_dir} is not writable"
            }
            ui_debug "Copying $user_plist to $target_dir"
            file copy -force $user_plist $target_dir
            file attributes ${target_dir}/com.apple.dt.Xcode.plist -owner $macportsuser -permissions 0644
        } on error {eMessage} {
            ui_warn "Failed to copy com.apple.dt.Xcode.plist to ${target_dir}: $eMessage"
        }
    }
}

proc macports::worker_init {workername portpath porturl portbuildpath options variations} {
    variable portinterp_options; variable portinterp_deferred_options
    variable ui_priorities; variable ui_options

    # Hide any Tcl commands that should be inaccessible to port1.0 and Portfiles
    # exit: It should not be possible to exit the interpreter
    interp hide $workername exit

    # cd: This is necessary for some code in port1.0, but should be hidden
    interp eval $workername [list rename cd _cd]

    # Tell the sub interpreter about commonly needed Tcl packages we
    # already know about so it won't glob for packages.
    foreach pkgName {port portactivate portarchivefetch portbuild portbump
                     portchecksum portclean portconfigure portdeactivate
                     portdepends portdestroot portdistcheck portdistfiles
                     portdmg portextract portfetch portimage portinstall
                     portlint portlivecheck portload portmain portmdmg
                     portmirror portmpkg portpatch portpkg portprogress
                     portreload portsandbox portstartupitem porttest
                     porttrace portunarchive portuninstall portunload
                     portutil cmdline fetch_common fileutil machista msgcat
                     Pextlib macports_dlist macports_util mpcommon
                     mp_package signalcatch Thread} {
        foreach pkgVers [package versions $pkgName] {
            set pkgLoadScript [package ifneeded $pkgName $pkgVers]
            $workername eval [list package ifneeded $pkgName $pkgVers $pkgLoadScript]
        }
    }

    # Create package require abstraction procedure
    $workername eval [list proc PortSystem {version} {
            package require port $version
            portmain::report_platform_info
        }]

    # Clearly separate slave interpreters and the master interpreter.
    $workername alias mport_exec mportexec
    $workername alias mport_open mportopen
    $workername alias mport_close mportclose
    $workername alias mport_lookup mportlookup
    $workername alias mport_info mportinfo
    $workername alias set_phase set_phase

    # instantiate the UI call-backs
    foreach priority $ui_priorities {
        $workername alias ui_$priority ui_$priority
    }
    # add the UI progress call-backs (or a no-op alias, if unavailable)
    foreach pname {progress_download progress_generic} {
        $workername alias ui_$pname ui_$pname
    }

    # notifications callback
    if {[info exists ui_options(notifications_append)]} {
        $workername alias ui_notifications_append $ui_options(notifications_append)
    } else {
        # provide a no-op if notifications_append wasn't set. See http://wiki.tcl.tk/3044
        $workername alias ui_notifications_append return -level 0
    }

    $workername alias ui_prefix ui_prefix
    $workername alias ui_channels ui_channels

    $workername alias ui_warn_once ui_warn_once

    # Export some utility functions defined here.
    $workername alias macports_version macports::version
    $workername alias macports_create_thread macports::create_thread
    $workername alias getportworkpath_from_buildpath macports::getportworkpath_from_buildpath
    $workername alias getportresourcepath macports::getportresourcepath
    $workername alias getportlogpath macports::getportlogpath
    $workername alias getdefaultportresourcepath macports::getdefaultportresourcepath
    $workername alias getprotocol macports::getprotocol
    $workername alias getportdir macports::getportdir
    $workername alias findBinary macports::findBinary
    $workername alias binaryInPath macports::binaryInPath
    $workername alias sysctl sysctl
    $workername alias realpath realpath
    $workername alias _mportsearchpath _mportsearchpath
    $workername alias _portnameactive _portnameactive
    $workername alias get_actual_cxx_stdlib macports::get_actual_cxx_stdlib
    $workername alias shellescape macports::shellescape

    # New Registry/Receipts stuff
    $workername alias registry_new registry::new_entry
    $workername alias registry_open registry::open_entry
    $workername alias registry_write registry::write_entry
    $workername alias registry_prop_store registry::property_store
    $workername alias registry_prop_retr registry::property_retrieve
    $workername alias registry_exists registry::entry_exists
    $workername alias registry_exists_for_name registry::entry_exists_for_name
    $workername alias registry_activate portimage::activate
    $workername alias registry_deactivate portimage::deactivate
    $workername alias registry_deactivate_composite portimage::deactivate_composite
    $workername alias registry_install portimage::install
    $workername alias registry_uninstall registry_uninstall::uninstall
    $workername alias registry_register_deps registry::register_dependencies
    $workername alias registry_fileinfo_for_index registry::fileinfo_for_index
    $workername alias registry_fileinfo_for_file registry::fileinfo_for_file
    $workername alias registry_bulk_register_files registry::register_bulk_files
    $workername alias registry_active registry::active
    $workername alias registry_file_registered registry::file_registered
    $workername alias registry_port_registered registry::port_registered
    $workername alias registry_list_depends registry::list_depends

    # deferred options processing.
    $workername alias getoption macports::getoption

    # ping cache
    $workername alias get_pingtime macports::get_pingtime
    $workername alias set_pingtime macports::set_pingtime

    # archive_sites.conf handling
    $workername alias get_archive_sites_conf_values macports::get_archive_sites_conf_values
    # variant_descriptions.conf
    $workername alias get_variant_description macports::get_variant_description

    # compiler version cache
    $workername alias get_compiler_version macports::get_compiler_version
    # tool path cache
    $workername alias get_tool_path macports::get_tool_path

    $workername alias get_compatible_xcode_versions macports::get_compatible_xcode_versions

    foreach opt $portinterp_options {
        if {![info exists $opt]} {
            variable $opt
        }
        if {[info exists $opt]} {
            $workername eval [list set system_options($opt) [set $opt]]
            $workername eval [list set $opt [set $opt]]
        }
    }

    foreach opt $portinterp_deferred_options {
        variable $opt
        # define the trace hook.
        $workername eval [list \
            proc trace_$opt {name1 name2 op} "
                global $opt
                trace remove variable $opt read trace_$opt
                set $opt \[getoption $opt\]
            "]
        # next access will actually define the variable.
        $workername eval [list trace add variable $opt read trace_$opt]
        # define some value now
        $workername eval [list set $opt ?]
    }

    foreach {opt val} $options {
        $workername eval [list set user_options($opt) $val]
        $workername eval [list set $opt $val]
    }

    foreach {var val} $variations {
        $workername eval [list set variations($var) $val]
        $workername eval [list set requested_variations($var) $val]
    }
}

# Create a thread with most configuration options set.
# The newly created thread is sent portinterp_options vars and knows where to
# find all packages we know.
proc macports::create_thread {} {
    package require Thread

    variable portinterp_options

    # Create the thread.
    set result [thread::create -preserved [list thread::wait]]

    # Tell the thread about all the Tcl packages we already
    # know about so it won't glob for packages.
    foreach pkgName [package names] {
        foreach pkgVers [package versions $pkgName] {
            set pkgLoadScript [package ifneeded $pkgName $pkgVers]
            thread::send -async $result [list package ifneeded $pkgName $pkgVers $pkgLoadScript]
        }
    }

    # inherit configuration variables.
    thread::send -async $result [list namespace eval macports {}]
    foreach opt $portinterp_options {
        if {![info exists $opt]} {
            variable $opt
        }
        if {[info exists $opt]} {
            thread::send -async $result [list set macports::$opt [set $opt]]
        }
    }

    return $result
}

proc macports::get_tar_flags {suffix} {
    switch -- $suffix {
        .tbz -
        .tbz2 {
            return -j
        }
        .tgz {
            return -z
        }
        .txz {
            return "--use-compress-program [findBinary xz {}] -"
        }
        .tlz {
            return "--use-compress-program [findBinary lzma {}] -"
        }
        default {
            return -
        }
    }
}

##
# Extracts a Portfile from a tarball pointed to by the given \a url to a path
# in \c $portdbpath and returns its path.
#
# @param url URL pointing to a tarball containing either a file named \c
#            Portfile at the root level -- in which case the tarball is
#            extracted completely, --  or a file named \c +CONTENTS at the root
#            level (i.e., the archive is a valid MacPorts binary archive), in
#            which case the Portfile is extracted from the file \c +PORTFILE
#            and put in a separate directory.
# @param local one, if the URL is local, zero otherwise
# @return a path to a directory containing the Portfile, or an error code
proc macports::fetch_port {url {local 0}} {
    variable portdbpath

    set fetchdir [file join $portdbpath portdirs]
    file mkdir $fetchdir
    if {![file writable $fetchdir]} {
        return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }

    if {$local} {
        set filepath $url
    } else {
        variable ui_prefix; variable ui_options
        variable portverbose
        ui_msg "$ui_prefix Fetching port $url"
        set fetchfile [file tail $url]
        set progressflag {}
        if {$portverbose} {
            set progressflag [list --progress builtin]
        } elseif {[info exists ui_options(progress_download)]} {
            set progressflag [list --progress $ui_options(progress_download)]
        }
        set filepath [file join $fetchdir $fetchfile]
        if {[catch {curl fetch {*}$progressflag $url $filepath} result]} {
            return -code error "Port remote fetch failed: $result"
        }
    }

    set oldpwd [pwd]
    cd $fetchdir

    # check if this is a binary archive or just the port dir by checking
    # whether the file "+CONTENTS" exists.
    set tarcmd [findBinary tar $macports::autoconf::tar_path]
    set tarflags [get_tar_flags [file extension $filepath]]
    set qflag $macports::autoconf::tar_q
    set cmdline [list $tarcmd ${tarflags}${qflag}xOf $filepath ./+CONTENTS]
    ui_debug $cmdline
    if {![catch {set contents [exec {*}$cmdline]}]} {
        # the file is probably a valid binary archive
        set binary 1
        ui_debug "getting port name from binary archive"
        # get the portname from the contents file
        foreach line [split $contents \n] {
            if {[lindex $line 0] eq {@name}} {
                # actually ${name}-${version}_$revision
                set portname [lindex $line 1]
            }
        }
        ui_debug "port name is '$portname'"

        # create a correctly-named directory and put the Portfile there
        file mkdir $portname
        cd $portname
    } else {
        # the file is not a valid binary archive, assume it's an archive just
        # containing Portfile and the files directory
        set binary 0
        set portname [file rootname [file tail $filepath]]
    }

    # extract the portfile (and possibly files dir if not a binary archive)
    ui_debug "extracting port archive to [pwd]"
    if {$binary} {
        set cmdline [list $tarcmd ${tarflags}${qflag}xOf $filepath ./+PORTFILE > Portfile]
    } else {
        set cmdline [list $tarcmd ${tarflags}xf $filepath]
    }
    ui_debug $cmdline
    if {[catch {exec {*}$cmdline} result]} {
        if {!$local} {
            # clean up the archive, we don't need it anymore
            file delete [file join $fetchdir $fetchfile]
        }

        cd $oldpwd
        return -code error "Port extract failed: $result"
    }

    if {!$local} {
        # clean up the archive, we don't need it anymore
        file delete [file join $fetchdir $fetchfile]
    }

    cd $oldpwd
    return [file join $fetchdir $portname]
}

proc macports::getprotocol {url} {
    variable getprotocol_re
    if {[regexp $getprotocol_re $url match protocol] == 1} {
        return $protocol
    } else {
        return -code error "Can't parse url $url"
    }
}

##
# Return the directory where the port identified by the given \a url is
# located. Can be called with either local paths (starting with \c file://), or
# local or remote URLs pointing to a tarball that will be extracted.
#
# @param url URL identifying the port to be installed
# @return normalized path to the port's directory, or error when called with an
#         unsupported protocol, or if the tarball pointed to by \a url didn't
#         contain a Portfile.
proc macports::getportdir {url} {
    variable extracted_portdirs

    set protocol [macports::getprotocol $url]
    switch -- $protocol {
        file {
            set path [file normalize [string range $url [expr {[string length $protocol] + 3}] end]]
            if {![file isfile $path]} {
                # the URL points to a local directory
                return $path
            } else {
                # the URL points to a local tarball that (hopefully) contains a Portfile
                # create a local dir for the extracted port, but only once
                if {![info exists extracted_portdirs($url)]} {
                    set extracted_portdirs($url) [macports::fetch_port $path 1]
                }
                return $extracted_portdirs($url)
            }
        }
        https -
        http -
        ftp {
            # the URL points to a remote tarball that (hopefully) contains a Portfile
            # create a local dir for the extracted port, but only once
            if {![info exists extracted_portdirs($url)]} {
                set extracted_portdirs($url) [macports::fetch_port $url 0]
            }
            return $extracted_portdirs($url)
        }
        default {
            return -code error "Unsupported protocol $protocol"
        }
    }
}

##
# Get the path to the _resources directory of the source
#
# If the file is not available in the current source, it will fall back to the
# default source. This behavior is controlled by the fallback parameter.
#
# @param url port url
# @param path path in _resources we are interested in
# @param fallback fall back to the default source tree
# @return path to the _resources directory or the path to the fallback
proc macports::getportresourcepath {url {path {}} {fallback yes}} {
    set protocol [getprotocol $url]

    switch -- $protocol {
        file {
            set proposedpath [file normalize [file join [getportdir $url] .. ..]]
        }
        default {
            set proposedpath [getsourcepath $url]
        }
    }

    # append requested path
    set proposedpath [file join $proposedpath _resources $path]

    if {$fallback && ![file exists $proposedpath]} {
        return [getdefaultportresourcepath $path]
    }

    return $proposedpath
}

##
# Get the path to the _resources directory of the default source
#
# @param path path in _resources we are interested in
# @return path to the _resources directory of the default source
proc macports::getdefaultportresourcepath {{path {}}} {
    variable sources_default

    set default_source_url [lindex $sources_default 0]
    if {[getprotocol $default_source_url] eq "file"} {
        set proposedpath [getportdir $default_source_url]
    } else {
        set proposedpath [getsourcepath $default_source_url]
    }

    # append requested path
    set proposedpath [file join $proposedpath _resources $path]

    return $proposedpath
}


##
# Opens a MacPorts portfile specified by a URL. The URL can be local (starting
# with file://), or remote (http, https, or ftp). In the local case, the URL
# can point to a directory containing a Portfile, or to a tarball in the format
# detailed below. In the remote case, the URL must point to a tarball. The
# Portfile is opened with the given list of options and variations. The result
# of this function should be treated as an opaque handle to a MacPorts
# Portfile.
#
# @param porturl URL to the directory of the port to be opened. Can the path to
#                a local directory, or an URL (both remote and local) pointing
#                to a tarball that
#                \li either contains a \c Portfile and possible a \c files
#                    directory, or
#                \li is a MacPorts binary archive, where the Portfile is in
#                    a file called \c +PORTFILE.
# @param options an optional array (in list format) of options
# @param variations an optional array (in list format) of variations, passed
#                   to \c eval_variants after running the Portfile
# @param nocache a non-empty string, if port information caching should be
#                avoided.
proc mportopen {porturl {options {}} {variations {}} {nocache {}}} {
    global macports::open_mports macports::file_porturl_re

    # normalize porturl for local files
    if {[regexp $file_porturl_re $porturl -> path]} {
        set realporturl "file://[file normalize $path]"
        if {$porturl ne $realporturl} {
            set porturl $realporturl
            ui_debug "Using normalized porturl $porturl"
        }
    }

    # Look for an already-open MPort with the same URL.
    # If found, return the existing reference and bump the refcount.
    if {$nocache ne ""} {
        set mport ""
    } else {
        set comparators [dict create variations dictequal options dictequal]
        set mport [dlist_match_multi $open_mports [list porturl $porturl variations $variations options $options] $comparators]
    }
    if {$mport ne ""} {
        # just in case more than one somehow matches
        set mport [lindex $mport 0]
        set refcnt [ditem_key $mport refcnt]
        incr refcnt
        ditem_key $mport refcnt $refcnt
        return $mport
    }

    # Will download if remote and extract if tarball.
    set portpath [macports::getportdir $porturl]
    ui_debug "Opening port in directory: $portpath"
    set portfilepath [file join $portpath Portfile]
    if {![file isfile $portfilepath]} {
        return -code error "Could not find Portfile in $portpath"
    }

    set workername [interp create]

    set mport [ditem_create]
    lappend open_mports $mport
    ditem_key $mport porturl $porturl
    ditem_key $mport portpath $portpath
    ditem_key $mport workername $workername
    ditem_key $mport options $options
    ditem_key $mport variations $variations
    ditem_key $mport refcnt 1

    macports::worker_init $workername $portpath $porturl [macports::getportbuildpath $portpath] $options $variations

    if {[catch {$workername eval [list source $portfilepath]} result]} {
        mportclose $mport
        ui_debug $::errorInfo
        error $result
    }

    # add the default universal variant if appropriate, and set up flags that
    # are conditional on whether universal is set
    $workername eval [list universal_setup]

    # evaluate the variants
    if {[$workername eval [list eval_variants variations]] != 0} {
        mportclose $mport
        error "Error evaluating variants"
    }

    $workername eval [list port::run_callbacks]

    set actual_subport [$workername eval [list set PortInfo(name)]]
    if {[$workername eval [list info exists user_options(subport)]]} {
        # The supplied subport may have been set on the command line by the
        # user, or simply obtained from the PortIndex or registry. Check that
        # it's valid in case the user made a mistake.
        set supplied_subport [$workername eval [list set user_options(subport)]]
        if {$supplied_subport ne $actual_subport} {
            set portname [$workername eval [list set name]]
            mportclose $mport
            error "$portname does not have a subport '$supplied_subport'"
        }
    }
    ditem_key $mport provides $actual_subport

    return $mport
}

# mportopen_installed
# opens a portfile stored in the registry
proc mportopen_installed {name version revision variants options} {
    global macports::registry.path
    set regref [lindex [registry::entry imaged $name $version $revision $variants] 0]
    set portfile_dir [file join ${registry.path} registry portfiles ${name}-${version}_${revision} [$regref portfile]]

    set variations [dict create]
    # Relies on all negated variants being at the end of requested_variants
    set minusvariant [lrange [split [$regref requested_variants] -] 1 end]
    set plusvariant [lrange [split [$regref variants] +] 1 end]
    foreach v $plusvariant {
        dict set variations $v +
    }
    foreach v $minusvariant {
        if {[string first "+" $v] == -1} {
            dict set variations $v -
        } else {
            ui_warn "Invalid negated variant for $name @${version}_${revision}${variants}: $v"
        }
    }

    dict set options subport $name

    # find portgroups in registry
    set pgdirlist [list]
    foreach pg [$regref groups_used] {
        lappend pgdirlist [file join ${registry.path} registry portgroups [$pg sha256]-[$pg size]]
        registry::portgroup close $pg
    }
    if {$pgdirlist ne ""} {
        dict set options _portgroup_search_dirs $pgdirlist
    }

    # Don't close as the reference is usually in use by the caller.
    # (Maybe this proc should take a regref as input?)
    #registry::entry close $regref

    set retmport [mportopen file://${portfile_dir}/ $options $variations]
    set workername [ditem_key $retmport workername]
    foreach var {version revision variants} {
        $workername eval [list set _inregistry_${var} [set $var]]
    }
    return $retmport
}

# Traverse a directory with ports, calling a function on the path of ports
# (at the second depth).
# I.e. the structure of dir shall be:
# category/port/
# with a Portfile file in category/port/
#
# func:     function to call on every port directory (it is passed
#           category/port/ as its parameter)
# root:     the directory with all the categories directories.
proc mporttraverse {func {root .}} {
    # Save the current directory
    set pwd [pwd]

    # Join the root.
    set pathToRoot [file join $pwd $root]

    # Go to root because some callers expects us to be there.
    cd $pathToRoot

    foreach category [lsort -increasing -unique [readdir $root]] {
        set pathToCategory [file join $root $category]
        # process the category dirs but not _resources
        if {[file isdirectory $pathToCategory] && [string index [file tail $pathToCategory] 0] ne "_"} {
            # Iterate on port directories.
            foreach port [lsort -increasing -unique [readdir $pathToCategory]] {
                set pathToPort [file join $pathToCategory $port]
                if {[file isdirectory $pathToPort] &&
                  [file exists [file join $pathToPort Portfile]]} {
                    # Call the function.
                    $func [file join $category $port]

                    # Restore the current directory because some
                    # functions change it.
                    cd $pathToRoot
                }
            }
        }
    }

    # Restore the current directory.
    cd $pwd
}

### _mportsearchpath is private; subject to change without notice

# depfilename -> the filename to find.
# search_path -> directories to search
# executable -> whether we want to check that the file is executable by current
#               user or not.
proc _mportsearchpath {depfilename search_path {executable 0} {return_match 0}} {
    set found 0
    foreach path $search_path {
        if {![file isdirectory $path]} {
            continue
        }

        set fullpath [file join $path $depfilename]
        if {![catch {file type $fullpath}] &&
          (($executable == 0) || [file executable $fullpath])} {
            ui_debug "Found Dependency: path: $path filename: $depfilename"
            set found 1
            break
        }
    }
    if {$return_match} {
        if {$found} {
            return $fullpath
        } else {
            return {}
        }
    } else {
        return $found
    }
}


### _mportinstalled is private; may change without notice

# Determine if a port is already *installed*, as in "in the registry".
proc _mportinstalled {mport} {
    # Check for the presence of the port in the registry
    set subport [ditem_key $mport provides]
    return [expr {[registry::entry imaged $subport] ne ""}]
}

# Determine if a port is active
proc _mportactive {mport} {
    set portname [ditem_key $mport provides]
    set ret 0
    set reslist [registry::entry installed $portname]
    if {$reslist ne {}} {
        set i [lindex $reslist 0]
        set portinfo [mportinfo $mport]
        if {[$i version] eq [dict get $portinfo version] && [$i revision] == [dict get $portinfo revision]
             && [$i variants] eq [dict get $portinfo canonical_active_variants]} {
            set ret 1
        }
        #registry::entry close $i
    }
    return $ret
}

# Determine if the named port is active
proc _portnameactive {portname} {
    set ilist [registry::entry installed $portname]
    #foreach i $ilist {
    #    registry::entry close $i
    #}
    return [expr {$ilist ne {}}]
}

### _mportispresent is private; may change without notice

# Determine if some depspec is satisfied or if the given port is installed
# and active.
# We actually start with the registry (faster?)
#
# mport     the port declaring the dep (context in which to evaluate $prefix etc.)
# depspec   the dependency test specification (path, bin, lib, etc.)
proc _mportispresent {mport depspec} {
    set portname [lindex [split $depspec :] end]
    ui_debug "Searching for dependency: $portname"
    set res [_portnameactive $portname]
    if {$res != 0} {
        ui_debug "Found Dependency: receipt exists for $portname"
        return 1
    } else {
        # The receipt test failed, use one of the depspec file mechanisms
        ui_debug "Didn't find receipt, going to depspec file for: $portname"
        set workername [ditem_key $mport workername]
        set type [lindex [split $depspec :] 0]
        switch -- $type {
            lib {return [$workername eval [list _libtest $depspec]]}
            bin {return [$workername eval [list _bintest $depspec]]}
            path {return [$workername eval [list _pathtest $depspec]]}
            port {return 0}
            default {return -code error "unknown depspec type: $type"}
        }
        return 0
    }
}

### _mporterrorifconflictsinstalled is private; may change without notice

# Determine if the port, per the conflicts option, has any conflicts
# with what is installed. If it does, raises an error unless force
# option is set.
#
# mport   the port to check for conflicts
proc _mporterrorifconflictsinstalled {mport} {
    set conflictlist [list]
    set portinfo [mportinfo $mport]

    if {[dict exists $portinfo conflicts] &&
        [llength [dict get $portinfo conflicts]] > 0} {
        ui_debug "Checking for conflicts against [_mportkey $mport subport]"
        foreach conflictport [dict get $portinfo conflicts] {
            if {[_portnameactive $conflictport]} {
                lappend conflictlist $conflictport
            }
        }
    } else {
        ui_debug "[_mportkey $mport subport] has no conflicts"
    }

    if {[llength $conflictlist] != 0} {
        if {[macports::global_option_isset ports_force]} {
            ui_warn "Force option set; installing [dict get $portinfo name] despite conflicts with: $conflictlist"
        } else {
            if {![macports::ui_isset ports_debug]} {
                ui_msg {}
            }
            ui_error "Can't install [dict get $portinfo name] because conflicting ports are active: $conflictlist"
            return -code error "conflicting ports"
        }
    }
}

# check if an error should be raised due to known_fail being set in a port
proc _mportcheck_known_fail {options portinfo} {
    if {([dict exists $portinfo known_fail] && [string is true -strict [dict get $portinfo known_fail]])
            && !([dict exists $options ignore_known_fail] && [string is true -strict [dict get $options ignore_known_fail]])} {
        # "Computing dependencies for" won't be followed by a newline yet
        if {![macports::ui_isset ports_debug]} {
            ui_msg {}
        }
        global macports::ui_options
        if {[info exists ui_options(questions_yesno)]} {
            set retvalue [$ui_options(questions_yesno) "[dict get $portinfo name] is known to fail." "_mportcheck_known_fail" {} {n} 0 "Try to install anyway?"]
            if {$retvalue != 0} {
                ui_error "[dict get $portinfo name] is known to fail"
                return 1
            }
        } else {
            ui_error "[dict get $portinfo name] is known to fail"
            return 1
        }
    }
    return 0
}

### _mportexec is private; may change without notice

proc _mportexec {target mport} {
    set portname [_mportkey $mport subport]
    macports::push_log $mport
    # xxx: set the work path?
    set workername [ditem_key $mport workername]
    $workername eval [list validate_macportsuser]

    # If the target doesn't need a toolchain (e.g. because an archive is
    # available and we're not going to build it), don't check for the Xcode
    # version (and presence for use_xcode yes ports).
    if {![catch {$workername eval [list check_variants $target]} result] && $result == 0 &&
        (![macports::_target_needs_toolchain $workername $target] || (![catch {$workername eval [list _check_xcode_version]} result] && $result == 0)) &&
        ![catch {$workername eval [list check_supported_archs]} result] && $result == 0 &&
        ![catch {$workername eval [list eval_targets $target]} result] && $result == 0} {
        # If auto-clean mode, clean-up after dependency install
        global macports::portautoclean
        if {$portautoclean} {
            # Make sure we are back in the port path before clean.
            # Otherwise, if the current directory had been changed to
            # inside the port, the next port may fail when trying to
            # install because [pwd] will return a "no file or directory"
            # error since the directory it was in is now gone.
            set portpath [ditem_key $mport portpath]
            catch {cd $portpath}
            $workername eval [list eval_targets clean]
        }
        macports::pop_log
        return 0
    } else {
        global macports::logenabled macports::debuglogname
        if {[info exists logenabled] && $logenabled && [info exists debuglogname]} {
            ui_error "See $debuglogname for details."
        }
        macports::pop_log
        return 1
    }
}

# mportexec
# Execute the specified target of the given mport.
proc mportexec {mport target} {
    global macports::ui_prefix macports::portautoclean
    set workername [ditem_key $mport workername]

    # check for existence of macportsuser and use fallback if necessary
    $workername eval [list validate_macportsuser]
    # check variants
    if {[$workername eval [list check_variants $target]] != 0} {
        return 1
    }
    set portname [_mportkey $mport subport]
    set log_needs_pop no
    if {$target ne "clean"} {
        macports::push_log $mport
        set log_needs_pop yes
    }

    # Use _target_needs_toolchain as a proxy for whether we're going to build
    # and will therefore need to check Xcode version and supported_archs.
    if {[macports::_target_needs_toolchain $workername $target]} {
        # possibly warn or error out depending on how old Xcode is
        if {[$workername eval [list _check_xcode_version]] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
        # error out if selected arch(s) not supported by this port
        if {[$workername eval [list check_supported_archs]] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
    }

    # Before we build the port, we must build its dependencies.
    set dlist [list]
    if {[macports::_target_needs_deps $target] && [macports::_mport_has_deptypes $mport [macports::_deptypes_for_target $target $workername]]} {
        registry::exclusive_lock
        # see if we actually need to build this port
        if {$target ni {activate install} ||
            ![$workername eval {registry_exists $subport $version $revision $portvariants}]} {

            # upgrade dependencies that are already installed
            if {![macports::global_option_isset ports_nodeps]} {
                macports::_upgrade_mport_deps $mport $target
            }
        }

        ui_msg -nonewline "$ui_prefix Computing dependencies for [_mportkey $mport subport]"
        if {[macports::ui_isset ports_debug]} {
            # play nice with debug messages
            ui_msg {}
        }
        if {[mportdepends $mport $target 1 1 0 dlist] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
        if {![macports::ui_isset ports_debug]} {
            ui_msg {}
        }

        # print the dep list
        if {[llength $dlist] > 0} {
            ##
            # User Interaction Question
            # Asking before installing dependencies
            global macports::ui_options
            if {[info exists ui_options(questions_yesno)]} {
                set deplist [list]
                foreach ditem $dlist {
                    lappend deplist [ditem_key $ditem provides]
                }
                set retvalue [$ui_options(questions_yesno) "The following dependencies will be installed: " "TestCase#2" [lsort $deplist] {y} 0]
                if {$retvalue == 1} {
                    if {$log_needs_pop} {
                        macports::pop_log
                    }
                    foreach ditem $dlist {
                        mportclose $ditem
                    }
                    return 0
                } 
            } else {
                set depstring "$ui_prefix Dependencies to be installed:"
                foreach ditem $dlist {
                    append depstring " [ditem_key $ditem provides]"
                }
                ui_msg $depstring
            }
        }

        # install them
        set result [dlist_eval $dlist _mportactive [list _mportexec activate]]

        if {[getuid] == 0 && [geteuid] != 0} {
            seteuid 0; setegid 0
        }

        registry::exclusive_unlock

        if {$result ne ""} {
            ##
            # When this happens, the failing port usually already printed an
            # error message. Don't print another here to avoid cluttering the
            # output and hiding the *real* problem, unless the problem
            # appears to be a circular dependency, which won't have produced
            # an error message yet.

            if {$dlist_eval_reason eq "unmet_deps"} {
                set errstring "The following dependencies were not installed\
                    because all of them have unmet dependencies (likely due\
                    to a dependency cycle):"
                foreach ditem $result {
                    append errstring " [ditem_key $ditem provides]"
                }
                ui_error $errstring
                foreach ditem $result {
                    ui_debug "[ditem_key $ditem provides] requires: [ditem_key $ditem requires]"
                }
            }
            foreach ditem $dlist {
                catch {mportclose $ditem}
            }
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }

        # Close the dependencies; we're done installing them.
        foreach ditem $dlist {
            mportclose $ditem
        }
    } else {
        # No dependencies, but we still need to check for conflicts.
        if {$target eq "" || $target eq "install" || $target eq "activate"} {
            if {[catch {_mporterrorifconflictsinstalled $mport}]} {
                if {$log_needs_pop} {
                    macports::pop_log
                }
                return 1
            }
        }
    }

    # Build this port with the specified target
    set result [$workername eval [list eval_targets $target]]

    # If auto-clean mode and successful install, clean-up after install
    if {$result == 0 && $portautoclean && $target in {install activate}} {
        # Make sure we are back in the port path, just in case
        set portpath [ditem_key $mport portpath]
        catch {cd $portpath}
        $workername eval [list eval_targets clean]
    }

    if {$result != 0} {
        global macports::logenabled macports::debuglogname
        if {[info exists logenabled] && $logenabled && [info exists debuglogname]} {
            ui_error "See $debuglogname for details."
        }
    }

    if {$log_needs_pop} {
        macports::pop_log
    }

    # Regain privileges that may have been dropped while running the target.
    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0; setegid 0
    }

    return $result
}

# upgrade any dependencies of mport that are installed and needed for target
proc macports::_upgrade_mport_deps {mport target} {
    variable universal_archs
    set options [ditem_key $mport options]
    set workername [ditem_key $mport workername]
    set deptypes [macports::_deptypes_for_target $target $workername]
    set portinfo [mportinfo $mport]
    array set depscache {}

    set required_archs [$workername eval [list get_canonical_archs]]
    set depends_skip_archcheck [_mportkey $mport depends_skip_archcheck]

    # Pluralize "arch" appropriately.
    set s [expr {[llength $required_archs] == 1 ? "" : "s"}]

    set test _portnameactive

    foreach deptype $deptypes {
        if {![dict exists $portinfo $deptype]} {
            continue
        }
        foreach depspec [dict get $portinfo $deptype] {
            set dep_portname [$workername eval [list _get_dep_port $depspec]]
            if {$dep_portname ne "" && ![info exists depscache(port:$dep_portname)] && [$test $dep_portname]} {
                set variants [dict create]

                # check that the dep has the required archs
                set active_archs [_active_archs $dep_portname]
                if {[_deptype_needs_archcheck $deptype] && $active_archs ni {{} noarch}
                    && $required_archs ne "noarch" && [lsearch -exact -nocase $depends_skip_archcheck $dep_portname] == -1} {
                    set missing [list]
                    foreach arch $required_archs {
                        if {$arch ni $active_archs} {
                            lappend missing $arch
                        }
                    }
                    if {[llength $missing] > 0} {
                        lassign [mportlookup $dep_portname] dep_portname dep_portinfo
                        if {[dict exists $dep_portinfo installs_libs] && ![dict get $dep_portinfo installs_libs]} {
                            set missing [list]
                        }
                    }
                    if {[llength $missing] > 0} {
                        if {[dict exists $dep_portinfo variants] && "universal" in [dict get $dep_portinfo variants]} {
                            # dep offers a universal variant
                            if {[llength $active_archs] == 1} {
                                # not installed universal
                                set missing [list]
                                foreach arch $required_archs {
                                    if {$arch ni $universal_archs} {
                                        lappend missing $arch
                                    }
                                }
                                if {[llength $missing] > 0} {
                                    ui_error "Cannot install [_mportkey $mport subport] for the arch${s} '$required_archs' because"
                                    ui_error "its dependency $dep_portname is only installed for the arch '$active_archs'"
                                    ui_error "and the configured universal_archs '$universal_archs' are not sufficient."
                                    return -code error "architecture mismatch"
                                } else {
                                    # upgrade the dep with +universal
                                    dict set variants universal +
                                    dict set options ports_upgrade_enforce-variants yes
                                    ui_debug "enforcing +universal upgrade for $dep_portname"
                                }
                            } else {
                                # already universal
                                ui_error "Cannot install [_mportkey $mport subport] for the arch${s} '$required_archs' because"
                                ui_error "its dependency $dep_portname is only installed for the archs '$active_archs'."
                                return -code error "architecture mismatch"
                            }
                        } else {
                            ui_error "Cannot install [_mportkey $mport subport] for the arch${s} '$required_archs' because"
                            ui_error "its dependency $dep_portname is only installed for the arch '$active_archs'"
                            ui_error "and does not have a universal variant."
                            return -code error "architecture mismatch"
                        }
                    }
                }

                set status [macports::upgrade $dep_portname port:$dep_portname $variants $options depscache]
                # status 2 means the port was not found in the index
                if {$status != 0 && $status != 2 && ![macports::ui_isset ports_processall]} {
                    return -code error "upgrade $dep_portname failed"
                }
            }
        }
    }
}

proc macports::getsourcepath {url} {
    variable portdbpath

    set source_path [split $url ://]

    if {[_source_is_snapshot $url]} {
        # snapshot tarball
        return [file join $portdbpath sources [join [lrange $source_path 3 end-1] /] ports]
    }

    return [file join $portdbpath sources [lindex $source_path 3] [lindex $source_path 4] [lindex $source_path 5]]
}

##
# Checks whether a supplied source URL is for a snapshot tarball
# (private)
#
# @param url source URL to check
# @param filename upvar variable name for filename
# @param extension upvar variable name for extension
# @param extension upvar variable name for URL excluding the filename
proc _source_is_snapshot {url {filename {}} {extension {}} {rooturl {}}} {
    global macports::source_is_snapshot_re
    upvar $rooturl myrooturl
    upvar $filename myfilename
    upvar $extension myextension

    if {[regexp $source_is_snapshot_re $url -> u f e]} {
        set myrooturl $u
        set myfilename $f
        set myextension $e

        return 1
    }

    return 0
}

##
# Checks whether a local source directory is a checkout of the obsolete Subversion repository
#
# @param source_dir local directory check
proc _source_is_obsolete_svn_repo {source_dir} {
    if {![catch {macports::findBinary svn} svn] &&
        ([file exists ${source_dir}/.svn] ||
         ![catch {exec $svn info ${source_dir} >/dev/null 2>@1}])
    } then {
        if {![catch {exec $svn info ${source_dir}} svninfo]} {
            if {[regexp -line {^Repository Root: https?://svn\.macports\.org/repository/macports} $svninfo] ||
                    [regexp -line {^Repository UUID: d073be05-634f-4543-b044-5fe20cf6d1d6$} $svninfo]} {
                return 1
            }
        }
    }
    return 0
}

proc macports::getportbuildpath {id {portname {}}} {
    variable portdbpath
    regsub {://} $id {.} port_path
    regsub -all {/} $port_path {_} port_path
    return [file join $portdbpath build $port_path $portname]
}

proc macports::getportlogpath {id {portname {}}} {
    variable portdbpath
    regsub {://} $id {.} port_path
    regsub -all {/} $port_path {_} port_path
    return [file join $portdbpath logs $port_path $portname]
}

proc macports::getportworkpath_from_buildpath {portbuildpath} {
    return [file normalize [file join $portbuildpath work]]
}

proc macports::getportworkpath_from_portdir {portpath {portname {}}} {
    return [macports::getportworkpath_from_buildpath [macports::getportbuildpath $portpath $portname]]
}

proc macports::getindex {source} {
    # Special case file:// sources
    if {[macports::getprotocol $source] eq "file"} {
        return [file join [macports::getportdir $source] PortIndex]
    }

    return [file join [macports::getsourcepath $source] PortIndex]
}

# macports::VCSPrepare
#
# Prepare to run a VCS command in the given directory, including
# dropping privileges by taking on the euid of the owner of the
# directory, if running as root.
#
# @param portDir Path to directory to prepare to operate on.
# @param state Variable name to save relevant state in. Pass this to
#              VCSCleanup after running the VCS commands.
proc macports::VCSPrepare {dir statevar} {
    if {[getuid] == 0} {
        global env
        variable user_ssh_auth_sock
        upvar $statevar state
        # Must change egid before dropping root euid.
        set state(oldEGID) [getegid]
        set newEGID [name_to_gid [file attributes $dir -group]]
        setegid $newEGID
        set state(oldEUID) [geteuid]
        set newEUID [name_to_uid [file attributes $dir -owner]]
        seteuid $newEUID
        set state(oldEnv) [array get env]
        set env(HOME) [getpwuid $newEUID dir]
        set envdebug "HOME=$env(HOME)"
        if {[info exists user_ssh_auth_sock]} {
            set env(SSH_AUTH_SOCK) $user_ssh_auth_sock
            append envdebug " SSH_AUTH_SOCK=$env(SSH_AUTH_SOCK)"
        }
        ui_debug "euid/egid changed to: $newEUID/$newEGID, env: $envdebug"
    }
}

# macports::VCSCleanup
#
# Clean up after running VCS commands. Undoes the effects of VCSPrepare
# including restoring privileges.
#
# @param state Variable name that was passed to VCSPrepare previously.
proc macports::VCSCleanup {statevar} {
    if {[getuid] == 0} {
        global env
        upvar $statevar state
        seteuid $state(oldEUID)
        setegid $state(oldEGID)
        array unset env *
        array set env $state(oldEnv)
        ui_debug "euid/egid restored to: $state(oldEUID)/$state(oldEGID), env restored"
    }
}

# macports::GetVCSUpdateCmd --
#
# Determine whether the given directory is associated with a repository
# for a supported version control system. If so, return a list
# containing two strings:
#
#   1) The human-readable name of the version control system.
#   2) A command that will update the repository's working tree to the
#      latest commit/changeset/revision/whatever. This command should
#      work properly from any working directory, although it doesn't
#      have to worry about cleaning up after itself (restoring the
#      environment, changing back to the initial directory, etc.).
#
# If the directory is not associated with any supported system, return
# an empty list.
#
# @param portDir The directory to check.
#
proc macports::GetVCSUpdateCmd {portDir} {

    set oldPWD [pwd]
    cd $portDir

    # Subversion
    if {![catch {macports::findBinary svn} svn] &&
        ([file exists .svn] ||
         ![catch {exec $svn info >/dev/null 2>@1}])
    } then {
        return [list Subversion "$svn update --non-interactive" $portDir]
    }

    # Git
    if {![catch {macports::findBinary git} git] &&
        ![catch {exec $git rev-parse --is-inside-work-tree}]
    } then {
        if {![catch {exec $git config --local --get svn-remote.svn.url}]} {
            # git-svn repository
            return [list git-svn "$git svn rebase" $portDir]
        }
        # regular git repository
        set autostash ""
        if {![catch {exec $git --version} git_version_string] && \
            [regexp -nocase "git version (\[^ ]+)" $git_version_string -> gitversion] && \
            [vercmp $gitversion 2.9.0] >= 0} {
            # https://github.com/git/git/blob/v2.9.0/Documentation/RelNotes/2.9.0.txt#L84-L86
            set autostash " --autostash"
        }
        return [list Git "$git pull --rebase${autostash}" $portDir]
    }

    # Add new VCSes here!

    cd $oldPWD
    return [list]
}

# macports::UpdateVCS --
#
# Execute the given command in a shell. Should be run as the
# user/group that owns the given directory by calling VCSPrepare
# beforehand.
#
# This proc could probably be generalized and used elsewhere.
#
# @param cmd The command to run.
# @param dir The directory to run the command in.
#
proc macports::UpdateVCS {cmd dir} {
    ui_debug $cmd
    catch {system -W $dir $cmd} result options
    return -options $options $result
}

proc mportsync {{options {}}} {
    global macports::sources macports::ui_prefix \
           macports::os_platform macports::os_major \
           macports::os_arch macports::autoconf::tar_path

    if {[dict exists $options no_reindex]} {
        upvar [dict get $options needed_portindex_var] any_needed_portindex
    }

    set numfailed 0
    set obsoletesvn 0

    ui_msg "$ui_prefix Updating the ports tree"
    foreach source $sources {
        set flags [lrange $source 1 end]
        set source [lindex $source 0]
        if {"nosync" in $flags} {
            ui_debug "Skipping $source"
            continue
        }
        set needs_portindex false
        ui_info "Synchronizing local ports tree from $source"
        switch -regexp -- [macports::getprotocol $source] {
            {^file$} {
                set portdir [macports::getportdir $source]
                macports::VCSPrepare $portdir statevar
                if {[_source_is_obsolete_svn_repo $portdir]} {
                    set obsoletesvn 1
                }
                macports_try -pass_signal {
                    set repoInfo [macports::GetVCSUpdateCmd $portdir] 
                } on error {} {
                    ui_debug $::errorInfo
                    ui_info "Could not access contents of $portdir"
                    incr numfailed
                    macports::VCSCleanup statevar
                    continue
                }
                if {[llength $repoInfo]} {
                    lassign $repoInfo vcs cmd dir
                    macports_try -pass_signal {
                        macports::UpdateVCS $cmd $dir
                    } on error {} {
                        ui_debug $::errorInfo
                        ui_info "Syncing local $vcs ports tree failed"
                        incr numfailed
                        macports::VCSCleanup statevar
                        continue
                    }
                }
                macports::VCSCleanup statevar
                set needs_portindex true
            }
            {^rsync$} {
                global macports::rsync_options macports::autoconf::rsync_path
                # Where to, boss?
                set indexfile [macports::getindex $source]
                set destdir [file dirname $indexfile]
                set is_tarball [_source_is_snapshot $source filename extension rooturl]
                file mkdir $destdir

                if {$is_tarball} {
                    set exclude_option "--exclude=*"
                    if {$extension eq "tar"} {
                        set filename ${filename}.gz
                    }
                    set include_option "--include=/${filename} --include=/${filename}.rmd160"
                    # need to do a few things before replacing the ports tree in this case
                    set extractdir [file dirname $destdir]
                    set destdir [file join $extractdir remote]
                    file mkdir $destdir
                    set srcstr $rooturl
                    set old_tarball_path [file join $extractdir $filename]
                    if {[file isfile $old_tarball_path]} {
                        file rename -force $old_tarball_path $destdir
                    }
                    set old_PortIndex_path [file join $extractdir PortIndex]
                    file delete -force {*}[glob -nocomplain -directory $extractdir [file rootname $filename]*] \
                        ${old_PortIndex_path} ${old_PortIndex_path}.rmd160
                } else {
                    # Keep rsync happy with a trailing slash
                    if {[string index $source end] ne "/"} {
                        append source /
                    }
                    # don't sync PortIndex yet; we grab the platform-specific one afterwards
                    set exclude_option '--exclude=/PortIndex*'
                    set include_option {}
                    set srcstr $source
                }
                # Do rsync fetch
                set rsync_commandline "$rsync_path $rsync_options $include_option $exclude_option $srcstr $destdir"
                macports_try -pass_signal {
                    system $rsync_commandline
                } on error {} {
                    ui_error "Synchronization of the local ports tree failed doing rsync"
                    incr numfailed
                    continue
                }

                if {$is_tarball} {
                    global macports::archivefetch_pubkeys macports::hfscompression macports::autoconf::openssl_path
                    set tarball [file join $destdir $filename]
                    # Fetch plain .tar if .tar.gz is missing
                    if {![file isfile $tarball]} {
                        set filename [file rootname $filename]
                        set include_option "--include=/${filename} --include=/${filename}.rmd160"
                        set rsync_commandline "$rsync_path $rsync_options $include_option $exclude_option $srcstr $destdir"
                        macports_try -pass_signal {
                            system $rsync_commandline
                        } on error {} {
                            ui_error "Synchronization of the local ports tree failed doing rsync"
                            incr numfailed
                            continue
                        }
                        set tarball [file join $destdir $filename]
                        if {![file isfile $tarball]} {
                            ui_error "Synchronization with rsync did not create $filename"
                            incr numfailed
                            continue
                        }
                    }
                    # verify signature for tarball
                    set signature ${tarball}.rmd160
                    set openssl [macports::findBinary openssl $openssl_path]
                    set verified 0
                    foreach pubkey $archivefetch_pubkeys {
                        macports_try -pass_signal {
                            exec $openssl dgst -ripemd160 -verify $pubkey -signature $signature $tarball
                            set verified 1
                            ui_debug "successful verification with key $pubkey"
                            break
                        } on error {eMessage} {
                            ui_debug "failed verification with key $pubkey"
                            ui_debug "openssl output: $eMessage"
                        }
                    }
                    if {!$verified} {
                        ui_error "Failed to verify signature for ports tree!"
                        incr numfailed
                        continue
                    }

                    if {${hfscompression} && [getuid] == 0 &&
                            ![catch {macports::binaryInPath bsdtar}] &&
                            ![catch {exec bsdtar -x --hfsCompression < /dev/null >& /dev/null}]} {
                        ui_debug "Using bsdtar with HFS+ compression (if valid)"
                        set tar "bsdtar --hfsCompression"
                    } else {
                        set tar [macports::findBinary tar $tar_path]
                    }
                    # extract tarball and move into place
                    file mkdir ${extractdir}/tmp
                    set zflag [expr {[file extension $tarball] eq ".gz" ? "z" : ""}]
                    set tar_cmd "$tar -C ${extractdir}/tmp -x${zflag}f $tarball"
                    macports_try -pass_signal {
                        system $tar_cmd
                    } on error {eMessage} {
                        ui_error "Failed to extract ports tree from tarball: $eMessage"
                        incr numfailed
                        continue
                    }
                    # save the local PortIndex data
                    if {[file isfile $indexfile]} {
                        file copy -force $indexfile ${destdir}/
                        file rename -force $indexfile ${extractdir}/tmp/ports/
                        if {[file isfile ${indexfile}.quick]} {
                            file rename -force ${indexfile}.quick ${extractdir}/tmp/ports/
                        }
                    }
                    file delete -force ${extractdir}/ports
                    file rename ${extractdir}/tmp/ports ${extractdir}/ports
                    file delete -force ${extractdir}/tmp
                    # delete any old uncompressed tarball
                    if {[file extension $tarball] eq ".gz"} {
                        file delete -force [file rootname $tarball] [file rootname $tarball].rmd160
                    }
                }

                set needs_portindex true
                # now sync the index if the local file is missing or older than a day
                if {![file isfile $indexfile] || [clock seconds] - [file mtime $indexfile] > 86400
                      || [dict exists $options no_reindex]} {
                    set include_option "--include=/PortIndex --exclude=*"
                    if {$is_tarball} {
                        # chop ports.tar off the end
                        set index_source [string range $source 0 end-[string length [file tail $source]]]
                        set include_option "--include=/PortIndex.rmd160 ${include_option}"
                    } else {
                        set index_source $source
                    }
                    set remote_indexdir "${index_source}PortIndex_${os_platform}_${os_major}_${os_arch}/"
                    set rsync_commandline "$rsync_path $rsync_options $include_option $remote_indexdir $destdir"
                    macports_try -pass_signal {
                        system $rsync_commandline
                        
                        set ok 1
                        set needs_portindex false
                        if {$is_tarball} {
                            set ok 0
                            set needs_portindex true
                            # verify signature for PortIndex
                            foreach pubkey $archivefetch_pubkeys {
                                macports_try -pass_signal {
                                    exec $openssl dgst -ripemd160 -verify $pubkey -signature ${destdir}/PortIndex.rmd160 ${destdir}/PortIndex
                                    set ok 1
                                    set needs_portindex false
                                    ui_debug "successful verification with key $pubkey"
                                    break
                                } on error {eMessage} {
                                    ui_debug "failed verification with key $pubkey"
                                    ui_debug "openssl output: $eMessage"
                                }
                            }
                            if {$ok} {
                                # move PortIndex into place
                                file rename -force ${destdir}/PortIndex ${extractdir}/ports/
                            }
                        }
                        if {$ok} {
                            mports_generate_quickindex $indexfile
                        }
                    } on error {} {
                        ui_debug "Synchronization of the PortIndex failed doing rsync"
                    }
                }
                macports_try -pass_signal {
                    system [list chmod -R a+r $destdir]
                } on error {} {
                    ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                }
            }
            {^https?$|^ftp$} {
                if {![_source_is_snapshot $source filename extension]} {
                    ui_error "Synchronization using http, https and ftp only supported with tarballs."
                    ui_error "The source ${source} doesn't seem to point to a tarball."
                    ui_error "Please switch to a different sync protocol (e.g. rsync) in your sources.conf"
                    ui_error "Remove the line mentioned above from your sources.conf to silence this error."
                    incr numfailed
                    continue
                }
                # sync a port snapshot tarball
                set indexfile [macports::getindex $source]
                set destdir [file dirname $indexfile]
                set tarpath [file join [file normalize [file join $destdir ..]] $filename]

                set updated 1
                if {[file isdirectory $destdir]} {
                    set moddate [file mtime $destdir]
                    if {[catch {set updated [curl isnewer $source $moddate]} error]} {
                        ui_warn "Cannot check if $source was updated, ($error)"
                    }
                }

                if {(![dict exists $options ports_force] || ![dict get $options ports_force]) && $updated <= 0} {
                    ui_info "No updates for $source"
                    continue
                }

                file mkdir $destdir

                global macports::portverbose macports::ui_options
                set progressflag {}
                if {$portverbose} {
                    set progressflag [list --progress builtin]
                    set verboseflag "-v"
                } elseif {[info exists ui_options(progress_download)]} {
                    set progressflag [list --progress $ui_options(progress_download)]
                    set verboseflag ""
                }
                macports_try -pass_signal {
                    curl fetch {*}$progressflag $source $tarpath
                } on error {eMessage} {
                    ui_error [msgcat::mc "Fetching %s failed: %s" $source $eMessage]
                    incr numfailed
                    continue
                }

                set extflag {}
                switch -- $extension {
                    {tar.gz} {
                        set extflag -z
                    }
                    {tar.bz2} {
                        set extflag -j
                    }
                }

                # Ignore the top-level directory, which allows to use tarballs
                # generated by GitHub, as they use "repository-branch/"
                # as top-level directory name.
                set striparg "--strip-components=1"

                set tar [macports::findBinary tar $tar_path]
                if {[catch {system -W ${destdir} "$tar $verboseflag $striparg $extflag -xf [macports::shellescape $tarpath]"} error]} {
                    ui_error "Extracting $source failed ($error)"
                    incr numfailed
                    continue
                }

                if {[catch {system "chmod -R a+r [macports::shellescape $destdir]"}]} {
                    ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                }

                set platindex "PortIndex_${os_platform}_${os_major}_${os_arch}/PortIndex"
                if {[file isfile ${destdir}/$platindex] && [file isfile ${destdir}/${platindex}.quick]} {
                    file rename -force ${destdir}/$platindex ${destdir}/${platindex}.quick $destdir
                } else {
                    set needs_portindex true
                }

                file delete $tarpath
            }
            {^mports$} {
                ui_error "Synchronization using the mports protocol no longer supported."
                ui_error "Please switch to a different sync protocol (e.g. rsync) in your sources.conf"
                ui_error "Remove the line starting with mports:// from your sources.conf to silence this error."
                incr numfailed
                continue
            }
            default {
                ui_warn "Unknown synchronization protocol for $source"
            }
        }

        if {$needs_portindex} {
            set any_needed_portindex true
            if {![dict exists $options no_reindex]} {
                global macports::prefix
                set indexdir [file dirname [macports::getindex $source]]
                if {[catch {system "${prefix}/bin/portindex [macports::shellescape $indexdir]"}]} {
                    ui_error "updating PortIndex for $source failed"
                }
            }
        }
    }

    # Aways refresh the quick index - in addition to batch or shell
    # mode, it's possible to run multiple actions like:
    # port sync \; upgrade outdated
    _mports_load_quickindex

    if {$numfailed == 1} {
        return -code error "Synchronization of 1 source failed"
    }
    if {$numfailed >= 2} {
        return -code error "Synchronization of $numfailed sources failed"
    }

    if {$obsoletesvn != 0} {
        ui_warn "The Subversion repository at svn.macports.org is no longer updated."
        ui_warn "Please switch to Git: https://trac.macports.org/wiki/howto/SyncingWithGit"
    }
}

##
# Searches all configured port sources for a given pattern in a given field
# using a given matching style and optional case-sensitivity.
#
# @param pattern pattern to search for; will be interpreted according to the \a
#                matchstyle parameter
# @param case_sensitive "yes", if a case-sensitive search should be performed,
#                       "no" otherwise. Defaults to "yes".
# @param matchstyle One of the values \c exact, \c glob and \c regexp, where \c
#                   exact performs a standard string comparison, \c glob
#                   performs Tcl string matching using <tt>[string match]</tt>
#                   and \c regexp interprets \a pattern as a regular
#                   expression.
# @param field name of the field to apply \a pattern to. Must be one of the
#              fields available in the used portindex. The portindex currently
#              contains
#                \li \c name (the default)
#                \li \c homepage
#                \li \c description
#                \li \c long_description
#                \li \c license
#                \li \c categories
#                \li \c platforms
#                \li \c maintainers
#                \li \c variants
#                \li \c portdir
#                \li all \c depends_* values
#                \li \c epoch
#                \li \c version
#                \li \c revision
#                \li \c replaced_by
#                \li \c installs_libs
# @return a list where each even index (starting with 0) contains the name of
#         a matching port. Each entry at an odd index is followed by its
#         corresponding line from the portindex, which can be passed to
#         <tt>array set</tt>. The whole return value can also be passed to
#         <tt>array set</tt> to create an associate array where the port names
#         are the keys and the lines from portindex are the values.
proc mportsearch {pattern {case_sensitive yes} {matchstyle regexp} {field name}} {
    global macports::sources macports::porturl_prefix_map
    set matches [list]
    set easy [expr {$field eq "name"}]

    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set porturl_prefix [dict get $porturl_prefix_map $source]
        macports_try -pass_signal {
            set fd [open [macports::getindex $source] r]

            macports_try -pass_signal {
                incr found 1
                while {[gets $fd line] >= 0} {
                    set name [lindex $line 0]
                    set len  [lindex $line 1]
                    set portinfo [read $fd $len]

                    if {$easy} {
                        set target $name
                    } else {
                        if {![dict exists $portinfo $field]} {
                            continue
                        }
                        set target [dict get $portinfo $field]
                    }

                    switch -- $matchstyle {
                        exact {
                            if {$case_sensitive} {
                                set compres [string compare $pattern $target]
                            } else {
                                set compres [string compare -nocase $pattern $target]
                            }
                            set matchres [expr {0 == $compres}]
                        }
                        glob {
                            if {$case_sensitive} {
                                set matchres [string match $pattern $target]
                            } else {
                                set matchres [string match -nocase $pattern $target]
                            }
                        }
                        regexp {
                            if {$case_sensitive} {
                                set matchres [regexp -- $pattern $target]
                            } else {
                                set matchres [regexp -nocase -- $pattern $target]
                            }
                        }
                        default {
                            return -code error "mportsearch: Unsupported matching style: ${matchstyle}."
                        }
                    }

                    if {$matchres == 1} {
                        if {[dict exists $portinfo portdir]} {
                            set porturl ${porturl_prefix}/[dict get $portinfo portdir]
                            dict set portinfo porturl $porturl
                            ui_debug "Found port in $porturl"
                        } else {
                            ui_debug "Found port info: $portinfo"
                        }
                        lappend matches $name $portinfo
                    }
                }
            } on error {_ eOptions} {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } finally {
                close $fd
            }
        } on error {} {
            ui_warn "Can't open index file for source: $source"
        }
    }
    if {!$found} {
        return -code error "No index(es) found! Have you synced your port definitions? Try running 'port selfupdate'."
    }

    return $matches
}

##
# Returns the PortInfo for a single named port. The info comes from the
# PortIndex, and name matching is case-insensitive. Unlike mportsearch, only
# the first match is returned, but the return format is otherwise identical.
# The advantage is that mportlookup is usually much faster than mportsearch,
# due to the use of the quick index, which is a name-based index into the
# PortIndex.
#
# @param name name of the port to look up. Returns the first match while
#             traversing the sources in-order.
# @return associative array in list form where the first field is the port name
#         and the second field is the line from PortIndex containing the port
#         info. See the return value of mportsearch().
# @see mportsearch()
proc mportlookup {name} {
    global macports::quick_index macports::sources \
           macports::porturl_prefix_map

    set sourceno 0
    set matches [list]
    set normname [string tolower $name]
    foreach source $sources {
        if {![dict exists $quick_index $sourceno $normname]} {
            # no entry in this source, advance to next source
            incr sourceno 1
            continue
        }
        set source [lindex $source 0]
        # The quick index is keyed on the port name, and provides the offset in
        # the main PortIndex where the given port's PortInfo line can be found.
        set offset [dict get $quick_index $sourceno $normname]
        incr sourceno 1
        if {[catch {set fd [open [macports::getindex $source] r]} result]} {
            ui_warn "Can't open index file for source: $source"
        } else {
            macports_try -pass_signal {
                seek $fd $offset
                gets $fd line
                set name [lindex $line 0]
                set len  [lindex $line 1]
                set portinfo [read $fd $len]

                if {[dict exists $portinfo portdir]} {
                    dict set portinfo porturl [dict get $porturl_prefix_map $source]/[dict get $portinfo portdir]
                }
                lappend matches $name $portinfo
            } on error {_ eOptions} {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } finally {
                close $fd
            }
            if {[llength $matches] > 0} {
                # if we have a match, exit. If we don't, continue with the next
                # source.
                break
            }
        }
    }

    return $matches
}

##
# Returns all ports in the indices. Faster than 'mportsearch .*' because of the
# lack of matching.
#
# @return associative array in list form where the first field is the port name
#         and the second field is the line from PortIndex containing the port
#         info. See the return value of mportsearch().
# @see mportsearch()
proc mportlistall {} {
    global macports::sources macports::porturl_prefix_map
    set matches [list]
    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set porturl_prefix [dict get $porturl_prefix_map $source]
        macports_try -pass_signal {
            set fd [open [macports::getindex $source] r]

            macports_try -pass_signal {
                incr found 1
                while {[gets $fd line] >= 0} {
                    set name [lindex $line 0]
                    set len  [lindex $line 1]
                    set portinfo [read $fd $len]

                    if {[dict exists $portinfo portdir]} {
                        dict set portinfo porturl ${porturl_prefix}/[dict get $portinfo portdir]
                    }
                    lappend matches $name $portinfo
                }
            } on error {_ eOptions} {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } finally {
                close $fd
            }
        } on error {} {
            ui_warn "Can't open index file for source: $source"
        }
    }
    if {!$found} {
        return -code error "No index(es) found! Have you synced your port definitions? Try running 'port selfupdate'."
    }

    return $matches
}

# Deferred loading of quick index
proc macports::load_quickindex {name1 name2 op} {
    variable quick_index
    trace remove variable quick_index {read write} macports::load_quickindex
    if {$op eq "read"} {
        _mports_load_quickindex
    }
}

##
# Loads PortIndex.quick from each source into the quick_index, generating it
# first if necessary. Private API of macports1.0, do not use this from outside
# macports1.0.
proc _mports_load_quickindex {} {
    global macports::quick_index macports::sources

    set quick_index [dict create]

    set sourceno 0
    foreach source $sources {
        unset -nocomplain quicklist
        # chop off any tags
        set source [lindex $source 0]
        set index [macports::getindex $source]
        if {![file exists $index]} {
            incr sourceno
            continue
        }
        if {![file exists ${index}.quick]} {
            ui_warn "No quick index file found, attempting to generate one for source: $source"
            macports_try -pass_signal {
                set quicklist [mports_generate_quickindex $index]
            } on error {} {
                incr sourceno
                continue
            }
        }
        # only need to read the quick index file if we didn't just update it
        if {![info exists quicklist]} {
            macports_try -pass_signal {
                set fd [open ${index}.quick r]
            } on error {} {
                ui_warn "Can't open quick index file for source: $source"
                incr sourceno
                continue
            }
            set quicklist [read -nonewline $fd]
            close $fd
        }
        dict set quick_index ${sourceno} [dict create {*}$quicklist]
        incr sourceno
    }
    if {!$sourceno} {
        ui_warn "No index(es) found! Have you synced your port definitions? Try running 'port selfupdate'."
    }
}

##
# Generates a PortIndex.quick file from a PortIndex by using the name field as
# key. This allows fast indexing into the PortIndex when using the port name as
# key.
#
# @param index the PortIndex file to create the index for. The resulting quick
#              index will be in a file named like \a index, but with ".quick"
#              appended.
# @return a list of entries written to the quick index file in the same format
#         if the file would just have been written.
# @throws if the given \a index cannot be opened, the output file cannot be
#         opened, an error occurs while using the PortIndex (e.g., because it
#         is corrupt), or the quick index generation failed for some other
#         reason.
proc mports_generate_quickindex {index} {
    macports_try -pass_signal {
        set indexfd -1
        set quickfd -1
        set indexfd [open $index r]
        set quickfd [open ${index}.quick w]
    } on error {} {
        ui_warn "Can't open index file: $index"
        return -code error
    }
    macports_try -pass_signal {
        set offset [tell $indexfd]
        set quicklist {}
        while {[gets $indexfd line] >= 0} {
            if {[llength $line] != 2} {
                continue
            }
            set name [lindex $line 0]
            append quicklist "[string tolower $name] $offset\n"

            set len [lindex $line 1]
            read $indexfd $len
            set offset [tell $indexfd]
        }
        puts -nonewline $quickfd $quicklist
    } on error {_ eOptions} {
        ui_warn "It looks like your PortIndex file $index may be corrupt."
        throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
    } finally {
        if {$indexfd != -1} {
            close $indexfd
        }
        if {$quickfd != -1} {
            close $quickfd
        }
    }
    if {[info exists quicklist]} {
        return $quicklist
    } else {
        ui_warn "Failed to generate quick index for: $index"
        return -code error
    }
}

proc mportinfo {mport} {
    set workername [ditem_key $mport workername]
    return [dict create {*}[$workername eval [list array get PortInfo]]]
}

proc mportclose {mport} {
    global macports::open_mports
    #macports::extracted_portdirs
    set refcnt [ditem_key $mport refcnt]
    incr refcnt -1
    ditem_key $mport refcnt $refcnt
    if {$refcnt == 0} {
        dlist_delete open_mports $mport
        set workername [ditem_key $mport workername]
        interp delete $workername
        #set porturl [ditem_key $mport porturl]
        #if {[info exists macports::extracted_portdirs($porturl)]} {
            # TODO port.tcl calls mportopen multiple times on the same port to
            # determine a number of attributes and will close the port after
            # each call. $macports::extracted_portdirs($porturl) will however
            # stay set, which means it will not be extracted twice. We could
            # (1) unset $macports::extracted_portdirs($porturl), which would
            # lead to downloading the port multiple times, or (2) fix the
            # port.tcl code to delay mportclose until the end.
            #ui_debug "Removing temporary port directory $macports::extracted_portdirs($porturl)"
            #file delete -force $macports::extracted_portdirs($porturl)
        #}
        ditem_delete $mport
    }
}

##### Private Depspec API #####
# This API should be considered work in progress and subject to change without notice.
##### "

# _mportkey
# - returns a variable from the port's interpreter

proc _mportkey {mport key} {
    set workername [ditem_key $mport workername]
    return [$workername eval [list set $key]]
}

# mportdepends builds the list of mports which the given port depends on.
# This list is added to $mport.
# This list actually depends on the target.
# This method can optionally recurse through the dependencies, looking for
#   dependencies of dependencies.
# This method can optionally cut the search when ports are already installed or
#   the dependencies are satisfied.
#
# mport -> mport item
# target -> target to consider the dependency for
# recurseDeps -> if the search should be recursive
# skipSatisfied -> cut the search tree when encountering installed/satisfied
#                  dependencies ports.
# accDeps -> accumulator for recursive calls
# depListName -> Variable name to return the list of dependencies in. If not set,
#                they are only added to the global open_mports.
# return 0 if everything was ok, an non zero integer otherwise.
proc mportdepends {mport {target {}} {recurseDeps 1} {skipSatisfied 1} {accDeps 0} {depListName {}}} {

    set portinfo [mportinfo $mport]
    if {$accDeps} {
        upvar port_seen port_seen
    } else {
        set port_seen [dict create]
    }
    if {$depListName ne {}} {
        upvar $depListName depList
        set depListName depList
    }

    # progress indicator
    if {![macports::ui_isset ports_debug]} {
        ui_info -nonewline .
        flush stdout
    }

    set options [ditem_key $mport options]

    if {$target in {{} install activate}} {
        if {$target eq {} && [_mportcheck_known_fail $options $portinfo]} {
            return 1
        }
        if {[catch {_mporterrorifconflictsinstalled $mport}]} {
            return 1
        }
    }

    set workername [ditem_key $mport workername]
    set deptypes [macports::_deptypes_for_target $target $workername]

    set depPorts [list]
    if {[llength $deptypes] > 0} {
        # avoid propagating requested flag from parent
        dict unset options ports_requested
        # subport will be different for deps
        dict unset options subport
        set variations [ditem_key $mport variations]
        set required_archs [$workername eval [list get_canonical_archs]]
        set required_archs_len [llength $required_archs]
        set depends_skip_archcheck [_mportkey $mport depends_skip_archcheck]
    }

    # Process the dependencies for each of the deptypes
    foreach deptype $deptypes {
        if {![dict exists $portinfo $deptype]} {
            continue
        }
        foreach depspec [dict get $portinfo $deptype] {
            # get the portname that satisfies the depspec
            set dep_portname [$workername eval [list _get_dep_port $depspec]]
            # normalise to lower case for equality checks
            set dep_portname_norm [string tolower $dep_portname]
            # skip port/archs combos we've already seen, and ones with the same port but less archs than ones we've seen (or noarch)
            set seenkeys [list $dep_portname_norm $required_archs]
            set seen 0
            if {[dict exists $port_seen {*}$seenkeys]} {
                set seen 1
            } elseif {[dict exists $port_seen $dep_portname_norm]} {
                set prev_seen_archs [dict keys [dict get $port_seen $dep_portname_norm]]
                foreach prev_archs $prev_seen_archs {
                    if {$prev_archs eq "noarch" || $required_archs eq "noarch" || [llength $prev_archs] > $required_archs_len} {
                        set seen 1
                        set seenkeys [list $dep_portname_norm $prev_archs]
                        break
                    }
                }
            }
            if {$seen} {
                if {[dict get $port_seen {*}$seenkeys] != 0} {
                    # nonzero means the dep is not satisfied, so we have to record it
                    ditem_append_unique $mport requires [dict get $port_seen {*}$seenkeys]
                }
                continue
            }

            # Is that dependency satisfied or this port installed?
            # If we don't skip or if it is not, add it to the list.
            set present [_mportispresent $mport $depspec]

            if {!$skipSatisfied && $dep_portname eq ""} {
                set dep_portname [lindex [split $depspec :] end]
                set dep_portname_norm [string tolower $dep_portname]
            }

            set check_archs 0
            if {$dep_portname ne "" && [macports::_deptype_needs_archcheck $deptype]
                && [lsearch -exact -nocase $depends_skip_archcheck $dep_portname] == -1} {
                set check_archs 1
            }

            # need to open the portfile even if the dep is installed if it doesn't have the right archs
            set parse 0
            if {!$skipSatisfied || !$present || ($check_archs && ![macports::_active_supports_archs $dep_portname $required_archs])} {
                set parse 1
            }
            if {$parse} {
                # Find the porturl
                macports_try -pass_signal {
                    set res [mportlookup $dep_portname]
                } on error {eMessage} {
                    ui_msg {}
                    ui_debug $::errorInfo
                    ui_error "Internal error: port lookup failed: $eMessage"
                    return 1
                }

                set dep_portinfo [lindex $res 1]
                if {![dict exists $dep_portinfo porturl]} {
                    if {![macports::ui_isset ports_debug]} {
                        ui_msg {}
                    }
                    ui_error "Dependency '$dep_portname' not found."
                    return 1
                } elseif {[dict exists $dep_portinfo installs_libs] && ![dict get $dep_portinfo installs_libs]} {
                    set check_archs 0
                    if {$skipSatisfied && $present} {
                        set parse 0
                    }
                }

                if {$parse} {
                    set dep_options $options
                    dict set dep_options subport [dict get $dep_portinfo name]
                    # Figure out the depport. Check the depList (or open_mports) first, since
                    # we potentially leak mport references if we mportopen each time,
                    # because mportexec only closes each open mport once.
                    set matchlistname [expr {$depListName ne {} ? "depList" : "macports::open_mports"}]
                    set comparators [dict create options dictequal]
                    set depport_matches [dlist_match_multi [set $matchlistname] [list porturl [dict get $dep_portinfo porturl] options $dep_options] $comparators]
                    # if multiple matches, the most recently opened one is more likely what we want
                    set depport [lindex $depport_matches end]

                    if {$depport eq ""} {
                        # We haven't opened this one yet.
                        set depport [mportopen [dict get $dep_portinfo porturl] $dep_options $variations]
                        if {$depListName ne {}} {
                            lappend depList $depport
                        }
                    }
                }
            }

            # check archs
            if {$parse && $check_archs
                && ![macports::_mport_supports_archs $depport $required_archs]} {

                set supported_archs [_mportkey $depport supported_archs]
                set dep_variations [[ditem_key $depport workername] eval [list array get requested_variations]]
                mportclose $depport
                if {$depListName ne {}} {
                    dlist_delete depList $depport
                }
                set arch_mismatch 1
                set has_universal 0
                if {[dict exists $dep_portinfo variants] && {universal} in [dict get $dep_portinfo variants]} {
                    # a universal variant is offered
                    set has_universal 1
                    if {![dict exists $dep_variations universal] || [dict get $dep_variations universal] ne "+"} {
                        dict set dep_variations universal +
                        # try again with +universal
                        set depport [mportopen [dict get $dep_portinfo porturl] $dep_options $dep_variations]
                        if {[macports::_mport_supports_archs $depport $required_archs]} {
                            set arch_mismatch 0
                            if {$depListName ne {}} {
                                lappend depList $depport
                            }
                        }
                    }
                }
                if {$arch_mismatch} {
                    macports::_explain_arch_mismatch [_mportkey $mport subport] $dep_portname $required_archs $supported_archs $has_universal
                    return 1
                }
            }

            if {$parse} {
                if {$recurseDeps} {
                    # Add to the list we need to recurse on.
                    lappend depPorts $depport
                }

                # Append the sub-port's provides to the port's requirements list.
                set depport_provides [ditem_key $depport provides]
                ditem_append_unique $mport requires $depport_provides
                # record actual archs we ended up getting
                dict set port_seen $dep_portname_norm [macports::_mport_archs $depport] $depport_provides
            } elseif {$present && $dep_portname ne ""} {
                # record actual installed archs
                dict set port_seen $dep_portname_norm [macports::_active_archs $dep_portname] 0
            }
        }
    }

    # Loop on the depports.
    if {$recurseDeps} {
        # Dep ports should be installed (all dependencies must be satisfied).
        foreach depport $depPorts {
            # Any of these may have been closed by a previous recursive call
            # and replaced by a universal version. This is fine, just skip.
            if {[ditem_key $depport] ne ""} {
                set res [mportdepends $depport {} $recurseDeps $skipSatisfied 1 $depListName]
                if {$res != 0} {
                    return $res
                }
            }
        }
    }

    return 0
}

# check if the given mport can support dependents with the given archs
proc macports::_mport_supports_archs {mport required_archs} {
    if {$required_archs eq "noarch"} {
        return 1
    }
    set provided_archs [_mport_archs $mport]
    if {$provided_archs eq "noarch"} {
        return 1
    }
    foreach arch $required_archs {
        if {$arch ni $provided_archs} {
            return 0
        }
    }
    return 1
}

# return the archs of the given mport
proc macports::_mport_archs {mport} {
    set workername [ditem_key $mport workername]
    return [$workername eval [list get_canonical_archs]]
}

# check if the active version of a port supports the given archs
proc macports::_active_supports_archs {portname required_archs} {
    if {$required_archs eq "noarch"} {
        return 1
    }
    set ilist [registry::entry installed $portname]
    if {$ilist eq ""} {
        return 0
    } else {
        #foreach i $ilist {
        #    registry::entry close $i
        #}
    }
    set provided_archs [_active_archs $portname]
    if {$provided_archs eq "noarch" || $provided_archs eq ""} {
        return 1
    }
    foreach arch $required_archs {
        if {$arch ni $provided_archs} {
            return 0
        }
    }
    return 1
}

# get the archs for a given active port
proc macports::_active_archs {portname} {
    set ilist [registry::entry installed $portname]
    set i [lindex $ilist 0]
    if {[catch {$i archs} archs]} {
        set archs [list]
    }
    #catch {registry::entry close $i}
    return $archs
}

# print an error message explaining why a port's archs are not provided by a dependency
proc macports::_explain_arch_mismatch {port dep required_archs supported_archs has_universal} {
    variable universal_archs
    if {![macports::ui_isset ports_debug]} {
        ui_msg {}
    }

    set s [expr {[llength $required_archs] == 1 ? "" : "s"}]

    ui_error "Cannot install $port for the arch${s} '$required_archs' because"
    if {$supported_archs ne ""} {
        set ss [expr {[llength $supported_archs] == 1 ? "" : "s"}]
        foreach arch $required_archs {
            if {$arch ni $supported_archs} {
                ui_error "its dependency $dep only supports the arch${ss} '$supported_archs'."
                return
            }
        }
    }
    if {$has_universal} {
        foreach arch $required_archs {
            if {$arch ni $universal_archs} {
                ui_error "its dependency $dep does not build for the required arch${s} by default"
                ui_error "and the configured universal_archs '$universal_archs' are not sufficient."
                return
            }
        }
        ui_error "its dependency $dep cannot build for the required arch${s}."
        return
    }
    ui_error "its dependency $dep does not build for the required arch${s} by default"
    ui_error "and does not have a universal variant."
}

# check if the given mport has any dependencies of the given types
proc macports::_mport_has_deptypes {mport deptypes} {
    set portinfo [mportinfo $mport]
    foreach type $deptypes {
        if {[dict exists $portinfo $type] && [dict get $portinfo $type] ne ""} {
            return 1
        }
    }
    return 0
}

# check if the given target needs dependencies installed first
proc macports::_target_needs_deps {target} {
    # XXX: need a better way than checking this hardcoded list
    switch -- $target {
        fetch -
        checksum -
        extract -
        patch -
        configure -
        build -
        test -
        destroot -
        install -
        activate -
        dmg -
        mdmg -
        pkg -
        mpkg {return 1}
        default {return 0}
    }
}

##
# Determine if the given target of the given port needs a toolchain. Returns
# true iff the target will require a compiler (or a different part of
# a standard toolchain) to successfully execute.
#
# Returns false otherwise, in which case it can be assumed that no toolchain is
# required for the successful execution of this task.
#
# @param workername A reference to the port interpreter of the port for which
#                   this function should check whether a toolchain is needed.
# @param target The target that will be run for this port
# @return true iff a toolchain is needed for this port, false otherwise
proc macports::_target_needs_toolchain {workername target} {
    switch -- $target {
        configure -
        build -
        test -
        destroot {
            return yes
        }

        install -
        activate -
        dmg -
        mdmg -
        pkg -
        mpkg {
            # check if an archive is available; if there isn't we'll need
            # a toolchain for these
            return [expr {![$workername eval [list _archive_available]]}]
        }

        default {
            return no
        }
    }
}

# Determine dependency types required for target
proc macports::_deptypes_for_target {target workername} {
    switch -- $target {
        fetch       -
        checksum    {return [list depends_fetch]}
        extract     {return [list depends_fetch depends_extract]}
        patch       {return [list depends_fetch depends_extract depends_patch]}
        configure   -
        build       {return [list depends_fetch depends_extract depends_patch depends_build depends_lib]}
        test        {return [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test]}
        destroot    {return [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run]}
        dmg         -
        pkg         -
        mdmg        -
        mpkg        {
            if {[global_option_isset ports_binary_only] ||
                (![global_option_isset ports_source_only] && [$workername eval [list _archive_available]])} {
                return [list depends_lib depends_run]
            } else {
                return [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run]
            }
        }
        install     -
        activate    -
        {}          {
            if {[global_option_isset ports_binary_only] ||
                [$workername eval {registry_exists $subport $version $revision $portvariants}]
                || (![global_option_isset ports_source_only] && [$workername eval [list _archive_available]])} {
                return [list depends_lib depends_run]
            } else {
                return [list depends_fetch depends_extract depends_patch depends_build depends_lib depends_run]
            }
        }
    }
    return [list]
}

# Return true if the given dependency type needs to have matching archs
proc macports::_deptype_needs_archcheck {deptype} {
    variable archcheck_dep_types
    return [expr {$deptype in ${archcheck_dep_types}}]
}

# selfupdate procedure
proc macports::selfupdate {{options {}} {updatestatusvar {}}} {
    return [uplevel [list selfupdate::main $options $updatestatusvar]]
}

# upgrade API wrapper procedure
# return codes:
#   0 = success
#   1 = general failure
#   2 = port name not found in index
#   3 = port not installed
proc macports::upgrade {portname dspec variations options {depscachename {}}} {
    variable global_options
    # only installed ports can be upgraded
    set ilist [registry::entry imaged $portname]
    if {$ilist eq {}} {
        ui_error "$portname is not installed"
        return 3
    }
    #foreach i $ilist {
    #    registry::entry close $i
    #}
    if {$depscachename ne ""} {
        upvar $depscachename depscache
    } else {
        array set depscache {}
    }
    # stop upgrade from being called via mportexec as well
    set orig_nodeps yes
    if {![info exists global_options(ports_nodeps)]} {
        set global_options(ports_nodeps) yes
        set orig_nodeps no
    }

    # run the actual upgrade
    set status [macports::_upgrade $portname $dspec $variations $options depscache]

    if {!$orig_nodeps} {
        unset -nocomplain global_options(ports_nodeps)
    }

    return $status
}

# main internal upgrade procedure
proc macports::_upgrade {portname dspec variations options {depscachename {}}} {
    variable global_variations

    if {$depscachename ne ""} {
        upvar $depscachename depscache
    }

    # Is this a dry run?
    set is_dryrun no
    if {[dict exists $options ports_dryrun] && [dict get $options ports_dryrun]} {
        set is_dryrun yes
    }

    # Is this a rev-upgrade-called run?
    set is_revupgrade no
    if {[dict exists $options ports_revupgrade] && [dict get $options ports_revupgrade]} {
        set is_revupgrade yes
        # unset revupgrade options so we can upgrade dependencies with the same
        # $options without also triggering a rebuild there, see #40150
        dict unset options ports_revupgrade
    }
    set is_revupgrade_second_run no
    if {[dict exists $options ports_revupgrade_second_run] && [dict get $options ports_revupgrade_second_run]} {
        set is_revupgrade_second_run yes
        # unset revupgrade options so we can upgrade dependencies with the same
        # $options without also triggering a rebuild there, see #40150
        dict unset options ports_revupgrade_second_run
    }

    # check if the port is in tree
    set result ""
    macports_try {
        set result [mportlookup $portname]
    } on error {eMessage} {
        ui_debug $::errorInfo
        ui_error "port lookup failed: $eMessage"
        return 1
    }
    # argh! port doesn't exist!
    if {$result eq ""} {
        ui_warn "No port $portname found in the index."
        return 2
    }
    # fill array with information
    lassign $result portname portinfo
    # set portname again since the one we were passed may not have had the correct case
    dict set options subport $portname

    # Note $called_variations retains the original
    # requested variations, which should be passed to recursive calls to
    # upgrade; while variations gets existing variants and global variations
    # merged in later on, so it applies only to this port's upgrade
    set called_variations $variations

    if {[catch {registry::entry imaged $portname} result]} {
        ui_error "Checking installed version failed: $result"
        return 1
    } elseif {$result eq {}} {
        ui_debug "$portname is *not* installed by MacPorts"

        # We need to pass _mportispresent a reference to the mport that is
        # actually declaring the dependency on the one we're checking for.
        # We got here via _upgrade_dependencies, so we grab it from 2 levels up.
        upvar 2 mport parentmport
        if {![_mportispresent $parentmport $dspec]} {
            # open porthandle
            set porturl [dict get $portinfo porturl]
            # Merge in global variants
            set variations [dict merge [array get global_variations] $variations]
            ui_debug "fully merged portvariants: $variations"
            # Don't inherit requested status from the depending port
            dict unset options ports_requested

            if {[catch {_mport_open_with_archcheck $porturl $dspec $parentmport $options $variations} mport]} {
                return 1
            }
            # While we're at it, update the portinfo
            set portinfo [mportinfo $mport]

            # mark it in the cache now to guard against circular dependencies
            set depscache(port:$portname) 1
            # upgrade its dependencies first
            set status [_upgrade_dependencies $portinfo depscache $called_variations $options]
            if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
                catch {mportclose $mport}
                return $status
            }
            # now install it
            if {[catch {mportexec $mport activate} result]} {
                ui_debug $::errorInfo
                ui_error "Unable to exec port: $result"
                catch {mportclose $mport}
                return 1
            } elseif {$result != 0} {
                ui_error "Problem while installing $portname"
                catch {mportclose $mport}
                return $result
            }
            mportclose $mport
        } else {
            # dependency is satisfied by something other than the named port
            ui_debug "$portname not installed, soft dependency satisfied"
            # mark this depspec as satisfied in the cache
            set depscache($dspec) 1
        }
        # the rest of the proc doesn't matter for a port that is freshly
        # installed or not installed
        return 0
    } else {
        # we'll now take care of upgrading it, so we can add it to the cache
        set depscache(port:$portname) 1
        set ilist $result
    }

    # set version_in_tree and revision_in_tree
    if {![dict exists $portinfo version]} {
        ui_error "Invalid port entry for ${portname}, missing version"
        _upgrade_cleanup
        return 1
    }
    set version_in_tree [dict get $portinfo version]
    set revision_in_tree [dict get $portinfo revision]
    set epoch_in_tree [dict get $portinfo epoch]

    # find latest version installed and active version (if any)
    set anyactive no
    set version_installed {}
    foreach i $ilist {
        set variant [$i variants]
        set version [$i version]
        set revision [$i revision]
        set epoch [$i epoch]
        if {$version_installed eq "" || ($epoch > $epoch_installed && $version ne $version_installed) ||
                ($epoch >= $epoch_installed && [vercmp $version $version_installed] > 0)
                || ($epoch >= $epoch_installed
                    && [vercmp $version $version_installed] == 0
                    && $revision > $revision_installed)} {
            set version_installed $version
            set revision_installed $revision
            set variant_installed $variant
            set epoch_installed $epoch
            if {!$anyactive} {
                set regref $i
            }
        }

        if {[$i state] eq "installed"} {
            set anyactive yes
            set regref $i
            set version_active $version
            set revision_active $revision
            set variant_active $variant
            set epoch_active $epoch
        }
    }

    # output version numbers
    ui_debug "epoch: in tree: $epoch_in_tree installed: $epoch_installed"
    ui_debug "$portname ${version_in_tree}_$revision_in_tree exists in the ports tree"
    ui_debug "$portname ${version_installed}_$revision_installed $variant_installed is the latest installed"
    if {$anyactive} {
        ui_debug "$portname ${version_active}_$revision_active $variant_active is active"
        # save existing variant for later use
        set oldvariant $variant_active
    } else {
        ui_debug "no version of $portname is active"
        set oldvariant $variant_installed
    }
    set oldrequestedvariant [$regref requested_variants]
    if {$oldrequestedvariant == 0} {
        set oldrequestedvariant {}
    }
    set requestedflag [$regref requested]
    set os_platform_installed [$regref os_platform]
    set os_major_installed [$regref os_major]
    # These might error if the info is not present in the registry.
    if {[catch {$regref cxx_stdlib} cxx_stdlib_installed]} {
        set cxx_stdlib_installed ""
    }
    if {[catch {$regref cxx_stdlib_overridden} cxx_stdlib_overridden]} {
        set cxx_stdlib_overridden 0
    }
    if {[dict exists $options ports_do_dependents]} {
        set dependents_list [$regref dependents]
    }

    # Before we do
    # dependencies, we need to figure out the final variants,
    # open the port, and update the portinfo.
    set porturl [dict get $portinfo porturl]

    # Relies on all negated variants being at the end of requested_variants
    set splitvariant [split $oldrequestedvariant -]
    set minusvariant [lrange $splitvariant 1 end]
    set splitvariant [split [lindex $splitvariant 0] +]
    set plusvariant [lrange $splitvariant 1 end]
    ui_debug "Merging existing requested variants '${oldrequestedvariant}' into variants"
    set oldrequestedvariations [dict create]
    # also save the current variants for dependency calculation
    # purposes in case we don't end up upgrading this port
    set installedvariations [dict create]
    foreach v $plusvariant {
        dict set oldrequestedvariations $v +
    }
    foreach v $minusvariant {
        if {[string first "+" $v] == -1} {
            dict set oldrequestedvariations $v -
            dict set installedvariations $v -
        } else {
            ui_warn "Invalid negated variant for ${portname}: $v"
        }
    }
    set plusvariant [lrange [split $oldvariant +] 1 end]
    foreach v $plusvariant {
        dict set installedvariations $v +
    }

    # Now merge all the variations. Global (i.e. variants.conf) ones are
    # overridden by the previous requested variants, which are overridden
    # by the currently requested variants.
    set variations [dict merge [array get global_variations] $oldrequestedvariations $variations]

    ui_debug "new fully merged portvariants: $variations"

    # at this point we need to check if a different port will be replacing this one
    if {[dict exists $portinfo replaced_by] && ![dict exists $options ports_upgrade_no-replace]} {
        variable ui_prefix
        ui_msg "$ui_prefix $portname is replaced by [dict get $portinfo replaced_by]"
        if {[catch {mportlookup [dict get $portinfo replaced_by]} result]} {
            ui_debug $::errorInfo
            ui_error "port lookup failed: $result"
            _upgrade_cleanup
            return 1
        }
        if {$result eq ""} {
            ui_error "No port [dict get $portinfo replaced_by] found."
            _upgrade_cleanup
            return 1
        }
        lassign $result newname portinfo

        set porturl [dict get $portinfo porturl]
        set depscache(port:$newname) 1
    } else {
        set newname $portname
    }

    set interp_options $options
    dict set interp_options ports_requested $requestedflag
    dict set interp_options subport $newname
    # Mark this port to be rebuilt from source if this isn't the first time it
    # was flagged as broken by rev-upgrade
    if {$is_revupgrade_second_run} {
        dict set interp_options ports_source_only yes
    }

    if {[catch {set mport [mportopen $porturl $interp_options $variations]} result]} {
        ui_debug $::errorInfo
        ui_error "Unable to open port: $result"
        _upgrade_cleanup
        return 1
    }

    set portinfo [mportinfo $mport]
    set version_in_tree [dict get $portinfo version]
    set revision_in_tree [dict get $portinfo revision]
    set epoch_in_tree [dict get $portinfo epoch]

    set build_override 0
    set will_install yes
    # check installed version against version in ports
    if {([vercmp $version_installed $version_in_tree] > 0
            || ([vercmp $version_installed $version_in_tree] == 0
                && [vercmp $revision_installed $revision_in_tree] >= 0))
        && ![dict exists $options ports_upgrade_force]} {
        if {$portname ne $newname} {
            ui_debug "ignoring versions, installing replacement port"
        } elseif {$epoch_installed < $epoch_in_tree && $version_installed ne $version_in_tree} {
            set build_override 1
            ui_debug "epoch override ... upgrading!"
        } elseif {[dict exists $options ports_upgrade_enforce-variants] && [dict get $options ports_upgrade_enforce-variants]
                  && [dict exists $portinfo canonical_active_variants] && [dict get $portinfo canonical_active_variants] ne $oldvariant} {
            ui_debug "variant override ... upgrading!"
        } elseif {$os_platform_installed ni [list any "" 0] && $os_major_installed ne ""
                  && ([_mportkey $mport os.platform] ne $os_platform_installed
                  || ($os_major_installed ne "any" && [_mportkey $mport os.major] != $os_major_installed))} {
            ui_debug "platform mismatch ... upgrading!"
            set build_override 1
        } elseif {$cxx_stdlib_overridden == 0 && ($cxx_stdlib_installed eq "libstdc++" || $cxx_stdlib_installed eq "libc++")
                  && [_mportkey $mport configure.cxx_stdlib] ne $cxx_stdlib_installed} {
            ui_debug "cxx_stdlib mismatch ... upgrading!"
            set build_override 1
        } elseif {$is_revupgrade_second_run} {
            ui_debug "rev-upgrade override ... upgrading (from source)!"
            set build_override 1
        } elseif {$is_revupgrade} {
            ui_debug "rev-upgrade override ... upgrading!"
            # in the first run of rev-upgrade, only activate possibly already existing files and check for missing dependencies
            # do nothing, just prevent will_install being set to no below
        } else {
            if {[dict exists $portinfo canonical_active_variants] && [dict get $portinfo canonical_active_variants] ne $oldvariant} {
                if {[dict size $called_variations] > 0} {
                    ui_warn "Skipping upgrade since $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_${revision_in_tree}, even though installed variants \"$oldvariant\" do not match \"[dict get $portinfo canonical_active_variants]\". Use 'upgrade --enforce-variants' to switch to the requested variants."
                } else {
                    ui_debug "Skipping upgrade since $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_${revision_in_tree}, even though installed variants \"$oldvariant\" do not match \"[dict get $portinfo canonical_active_variants]\"."
                }
                # reopen with the installed variants so deps are calculated correctly
                catch {mportclose $mport}
                if {[catch {set mport [mportopen $porturl $interp_options $installedvariations]} result]} {
                    ui_debug $::errorInfo
                    ui_error "Unable to open port: $result"
                    _upgrade_cleanup
                    return 1
                }
            } else {
                ui_debug "No need to upgrade! $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_$revision_in_tree"
            }
            set will_install no
        }
    }

    set will_build no
    set already_installed [registry::entry_exists $newname $version_in_tree $revision_in_tree [dict get $portinfo canonical_active_variants]]
    # avoid building again unnecessarily
    if {$will_install &&
        ([dict exists $options ports_upgrade_force]
            || $build_override == 1
            || !$already_installed)} {
        set will_build yes
    }

    # first upgrade dependencies
    if {![dict exists $options ports_nodeps]} {
        # the last arg is because we might have to build from source if a rebuild is being forced
        set status [_upgrade_dependencies $portinfo depscache $called_variations $options [expr {$will_build && $already_installed}]]
        if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
            _upgrade_cleanup
            return $status
        }
    } else {
        ui_debug "Not following dependencies"
    }

    if {!$will_install} {
        # not upgrading this port, so just update its metadata
        _upgrade_metadata $mport $regref $is_dryrun
        # check if we have to do dependents
        if {[dict exists $options ports_do_dependents]} {
            # We do dependents ..
            dict set options ports_nodeps 1

            # Get names from all registry entries in advance, since the
            # recursive upgrade calls could invalidate them.
            set dependents_names [list]
            foreach dep $dependents_list {
                lappend dependents_names [$dep name]
            }
            foreach mpname $dependents_names {
                if {![info exists depscache(port:$mpname)]} {
                    set status [macports::_upgrade $mpname port:$mpname $called_variations $options depscache]
                    if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
                        _upgrade_cleanup
                        return $status
                    }
                }
            }
        }
        _upgrade_cleanup
        return 0
    }

    set workername [ditem_key $mport workername]
    if {$will_build} {
        if {$already_installed
            && ([dict exists $options ports_upgrade_force] || $build_override == 1)} {
            # Tell archivefetch/unarchive not to use the installed archive, i.e. a
            # fresh one will be either fetched or built locally.
            # Ideally this would be done in the interp_options when we mportopen,
            # but we don't know if we want to do this at that point.
            $workername eval [list set force_archive_refresh yes]

            # run archivefetch and (if needed) destroot for version_in_tree
            # doing this instead of just running install ensures that we have the
            # new copy ready but not yet installed, so we can safely uninstall the
            # existing one.
            set archivefetch_failed 1
            if {![dict exists $interp_options ports_source_only]} {
                if {[catch {mportexec $mport archivefetch} result]} {
                    ui_debug $::errorInfo
                } elseif {$result == 0 && [$workername eval [list find_portarchive_path]] ne ""} {
                    set archivefetch_failed 0
                }
            }
            if {$archivefetch_failed} {
                if {[dict exists $interp_options ports_binary_only]} {
                    _upgrade_cleanup
                    return 1
                }
                if {[catch {mportexec $mport destroot} result]} {
                    ui_debug $::errorInfo
                    _upgrade_cleanup
                    return 1
                } elseif {$result != 0} {
                    _upgrade_cleanup
                    return 1
                }
            }
        } else {
            # Normal non-forced case
            # install version_in_tree (but don't activate yet)
            if {[catch {mportexec $mport install} result]} {
                ui_debug $::errorInfo
                _upgrade_cleanup
                return 1
            } elseif {$result != 0} {
                _upgrade_cleanup
                return 1
            }
        }
    }

    unset interp_options

    # check if the startupitem is loaded, so we can load again it after upgrading
    # (deactivating the old version will unload the startupitem)
    set loaded_startupitems [list]
    if {$portname eq $newname} {
        set loaded_startupitems [$workername eval [list portstartupitem::loaded]]
    }

    # are we installing an existing version due to force or epoch override?
    if {$already_installed
        && ([dict exists $options ports_upgrade_force] || $build_override == 1)} {
         ui_debug "Uninstalling $newname ${version_in_tree}_${revision_in_tree}[dict get $portinfo canonical_active_variants]"
        # we have to force the uninstall in case of dependents
        set force_cur [dict exists $options ports_force]
        dict set options ports_force yes
        set newregref [registry::entry open $newname $version_in_tree $revision_in_tree [dict get $portinfo canonical_active_variants] ""]
        if {$is_dryrun} {
            ui_msg "Skipping uninstall $newname @${version_in_tree}_${revision_in_tree}[dict get $portinfo canonical_active_variants] (dry run)"
        } elseif {![registry::run_target $newregref uninstall $options]
                  && [catch {registry_uninstall::uninstall $newname $version_in_tree $revision_in_tree [dict get $portinfo canonical_active_variants] $options} result]} {
            ui_debug $::errorInfo
            ui_error "Uninstall $newname ${version_in_tree}_${revision_in_tree}[dict get $portinfo canonical_active_variants] failed: $result"
            _upgrade_cleanup
            return 1
        }
        # newregref is rendered invalid if the port was uninstalled
        if {!$is_dryrun} {
            unset newregref
        }
        if {!$force_cur} {
            dict unset options ports_force
        }
        if {$anyactive && $version_in_tree eq $version_active && $revision_in_tree == $revision_active
            && [dict get $portinfo canonical_active_variants] eq $variant_active && $portname eq $newname} {
            set anyactive no
        }
    }
    if {$anyactive && $portname ne $newname} {
        # replaced_by in effect, deactivate the old port
        # we have to force the deactivate in case of dependents
        set force_cur [dict exists $options ports_force]
        dict set options ports_force yes
        if {$is_dryrun} {
            ui_msg "Skipping deactivate $portname @${version_active}_${revision_active}$variant_active (dry run)"
        } elseif {![registry::run_target $regref deactivate $options]
                  && [catch {portimage::deactivate $portname $version_active $revision_active $variant_active $options} result]} {
            ui_debug $::errorInfo
            ui_error "Deactivating $portname @${version_active}_${revision_active}$variant_active failed: $result"
            _upgrade_cleanup
            return 1
        }
        if {!$force_cur} {
            dict unset options ports_force
        }
        set anyactive no
    }
    if {[dict exists $options port_uninstall_old] && $portname eq $newname} {
        # uninstalling now could fail due to dependents when not forced,
        # because the new version is not installed
        set uninstall_later yes
    }

    if {$is_dryrun} {
        if {$anyactive} {
            ui_msg "Skipping deactivate $portname @${version_active}_${revision_active}$variant_active (dry run)"
        }
        ui_msg "Skipping activate $newname @${version_in_tree}_${revision_in_tree}[dict get $portinfo canonical_active_variants] (dry run)"
    } else {
        set failed 0
        if {[catch {mportexec $mport activate} result]} {
            ui_debug $::errorInfo
            set failed 1
        } elseif {$result != 0} {
            set failed 1
        }
        if {$failed} {
            ui_error "Couldn't activate $newname ${version_in_tree}_${revision_in_tree}[dict get $portinfo canonical_active_variants]: $result"
            _upgrade_cleanup
            return 1
        }
        if {$loaded_startupitems ne ""} {
            $workername eval [list set ::portstartupitem::load_only $loaded_startupitems]
            if {[catch {mportexec $mport load} result]} {
                ui_debug $::errorInfo
                ui_warn "Error loading startupitem(s) for ${newname}: $result"
            } elseif {$result != 0} {
                ui_warn "Error loading startupitem(s) for ${newname}: $result"
            }
            $workername eval [list unset ::portstartupitem::load_only]
        }
    }

    # Check if we have to do dependents
    if {[dict exists $options ports_do_dependents]} {
        # We do dependents ..
        dict set options ports_nodeps 1

        if {$portname ne $newname} {
            if {![info exists newregref]} {
                set newregref [registry::entry open $newname $version_in_tree $revision_in_tree [dict get $portinfo canonical_active_variants] ""]
            }
            lappend dependents_list {*}[$newregref dependents]
        }

        # Get names from all registry entries in advance, since the
        # recursive upgrade calls could invalidate them.
        set dependents_names [list]
        foreach dep $dependents_list {
            lappend dependents_names [$dep name]
        }
        foreach mpname $dependents_names {
            if {![info exists depscache(port:$mpname)]} {
                set status [macports::_upgrade $mpname port:$mpname $called_variations $options depscache]
                if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
                    _upgrade_cleanup
                    return $status
                }
            }
        }
    }

    if {[info exists uninstall_later] && $uninstall_later} {
        if {[catch {registry::entry imaged $portname} ilist]} {
            ui_error "Checking installed version failed: $ilist"
            return 1
        }
        foreach i $ilist {
            set version [$i version]
            set revision [$i revision]
            set variant [$i variants]
            if {$version eq $version_in_tree && $revision == $revision_in_tree && $variant eq [dict get $portinfo canonical_active_variants] && $portname eq $newname} {
                continue
            }
            ui_debug "Uninstalling $portname ${version}_${revision}$variant"
            if {$is_dryrun} {
                ui_msg "Skipping uninstall $portname @${version}_${revision}$variant (dry run)"
            } elseif {![registry::run_target $i uninstall $options]
                      && [catch {registry_uninstall::uninstall $portname $version $revision $variant $options} result]} {
                ui_debug $::errorInfo
                # replaced_by can mean that we try to uninstall all versions of the old port, so handle errors due to dependents
                if {$result ne "Please uninstall the ports that depend on $portname first." && ![ui_isset ports_processall]} {
                    ui_error "Uninstall $portname @${version}_${revision}$variant failed: $result"
                    _upgrade_cleanup
                    return 1
                }
            }
        }
    }

    _upgrade_cleanup
    return 0
}

# Open the given port, adding +universal if needed to satisfy the arch
# requirements of the dependent mport.
proc macports::_mport_open_with_archcheck {porturl depspec dependent_mport options variations} {
    variable archcheck_install_dep_types
    if {[catch {set mport [mportopen $porturl $options $variations]} result]} {
        ui_debug $::errorInfo
        ui_error "Unable to open port ($depspec): $result"
        error "mportopen failed"
    }
    set portinfo [mportinfo $mport]

    if {[dict exists $portinfo installs_libs] && ![dict get $portinfo installs_libs]} {
        return $mport
    }
    set skip_archcheck [_mportkey $dependent_mport depends_skip_archcheck]
    set required_archs [_mport_archs $dependent_mport]
    if {[lsearch -exact -nocase $skip_archcheck [dict get $portinfo name]] >= 0
            || [_mport_supports_archs $mport $required_archs]} {
        return $mport
    }
    # Check if the dependent used a dep type that needs matching archs
    set dependent_portinfo [mportinfo $dependent_mport]
    set archcheck_needed 0
    foreach dtype ${archcheck_install_dep_types} {
        if {[dict exists $dependent_portinfo $dtype]
             && [lsearch -exact -nocase [dict get $dependent_portinfo $dtype] $depspec] >= 0} {
            set archcheck_needed 1
            break
        }
    }
    if {!$archcheck_needed} {
        return $mport
    }

    # Reopen with +universal if possible
    set has_universal [expr {[dict exists $portinfo variants] && "universal" in [dict get $portinfo variants]}]
    if {![dict exists $variations universal] && $has_universal
            && [llength [_mport_archs $mport]] < 2} {
        mportclose $mport
        dict set variations universal +
        if {[catch {set mport [mportopen $porturl $options $variations]} result]} {
            ui_debug $::errorInfo
            ui_error "Unable to open port [dict get $portinfo name]: $result"
            error "mportopen failed"
        }
        if {[_mport_supports_archs $mport $required_archs]} {
            return $mport
        }
    }
    _explain_arch_mismatch [dict get $dependent_portinfo name] [dict get $portinfo name] $required_archs [_mportkey $mport supported_archs] $has_universal
    error "architecture mismatch"
}

# _upgrade calls this to clean up before returning
proc macports::_upgrade_cleanup {} {
    #upvar ilist ilist regref regref newregref newregref \
    #      deplist deplist
    upvar mport mport
    if {[info exists mport]} {
        catch {mportclose $mport}
    }
    #if {[info exists ilist]} {
    #    foreach i $ilist {
    #        catch {registry::entry close $i}
    #    }
    #}
    #if {[info exists regref]} {
    #    catch {registry::entry close $regref}
    #}
    #if {[info exists newregref]} {
    #    catch {registry::entry close $newregref}
    #}
    #if {[info exists deplist]} {
    #    foreach i $deplist {
    #        catch {registry::entry close $i}
    #    }
    #}
}

# upgrade_dependencies: helper proc for upgrade
# Calls upgrade on each dependency listed in the PortInfo.
# Uses upvar to access the variables.
proc macports::_upgrade_dependencies {portinfo depscachename variations options {build_needed no}} {
    upvar $depscachename depscache \
          mport parentmport

    # If we're following dependents, we only want to follow this port's
    # dependents, not those of all its dependencies. Otherwise, we would
    # end up processing this port's dependents n+1 times (recursively!),
    # where n is the number of dependencies this port has, since this port
    # is of course a dependent of each of its dependencies. Plus the
    # dependencies could have any number of unrelated dependents.
    # So we unset the option while doing the dependencies.
    dict unset options ports_do_dependents

    set parentworker [ditem_key $parentmport workername]
    # each required dep type is upgraded
    if {$build_needed && ![global_option_isset ports_binary_only]} {
        set dtypes [_deptypes_for_target destroot $parentworker]
    } else {
        set dtypes [_deptypes_for_target install $parentworker]
    }

    set status 0
    foreach dtype $dtypes {
        if {[dict exists $portinfo $dtype]} {
            foreach i [dict get $portinfo $dtype] {
                set d [$parentworker eval [list _get_dep_port $i]]
                if {$d eq ""} {
                    set d [lindex [split $i :] end]
                }
                if {![info exists depscache(port:$d)] && ![info exists depscache($i)]} {
                    set status [macports::_upgrade $d $i $variations $options depscache]
                    if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} break
                }
            }
        }
        if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} break
    }
    return $status
}

# update certain metadata if changed in the portfile since installation
proc macports::_upgrade_metadata {mport regref is_dryrun} {
    set workername [ditem_key $mport workername]
    set portinfo [mportinfo $mport]
    set portname [dict get $portinfo name]
    set tree_verstring "[dict get $portinfo version]_[dict get $portinfo revision][dict get $portinfo canonical_active_variants]"

    # Check that the version in the ports tree isn't too different
    if {[dict get $portinfo version] ne [$regref version]
        || [dict get $portinfo revision] != [$regref revision]
        || [dict get $portinfo canonical_active_variants] ne [$regref variants]} {
        ui_debug "${portname}: Registry '[$regref version]_[$regref revision][$regref variants]' doesn't match '$tree_verstring'"
        ui_debug "Not attempting to update metadata for $portname"
        return
    }

    # Update runtime dependencies if needed.
    # First get the deps from the Portfile and from the registry.
    set deps_in_tree [dict create]
    foreach dtype [list depends_lib depends_run] {
        if {[dict exists $portinfo $dtype]} {
            foreach dep [dict get $portinfo $dtype] {
                set dname [$workername eval [list _get_dep_port $dep]]
                if {$dname ne ""} {
                    dict set deps_in_tree $dname 1
                }
            }
        }
    }
    set deps_in_reg [dict create]
    foreach dep_regref [$regref dependencies] {
        dict set deps_in_reg [$dep_regref name] 1
    }

    # Find the differences.
    set removed [list]
    foreach d [dict keys $deps_in_reg] {
        if {![dict exists $deps_in_tree $d]} {
            lappend removed $d
        }
    }
    set added [list]
    foreach d [dict keys $deps_in_tree] {
        if {![dict exists $deps_in_reg $d]} {
            lappend added $d
        }
    }

    # Update the registry.
    if {[llength $removed] > 0 || [llength $added] > 0} {
        if {$is_dryrun} {
            ui_info "Not updating dependencies for $portname @$tree_verstring (dry run)"
        } else {
            ui_info "Updating dependencies for $portname @$tree_verstring"
            if {[llength $removed] > 0} {
                registry::delete_dependencies $regref $removed
            }
            if {[llength $added] > 0} {
                registry::write {
                    foreach d $added {
                        $regref depends $d
                    }
                }
            }
        }
    }

    # Update platform if it been corrected to 'any' (indicating
    # compatibility with multiple platforms or versions).
    # The opposite case requires a rev bump so is not handled here.
    lassign [$workername eval [list _get_compatible_platform]] os_platform os_major
    if {$os_major eq "any" && $os_major ne [$regref os_major]} {
        if {$is_dryrun} {
            ui_info "Not updating platform for $portname @$tree_verstring (dry run)"
        } else {
            ui_info "Updating platform for $portname @$tree_verstring"
            registry::write {
                $regref os_major $os_major
                # No need to check for a completely different platform, since
                # the port would be considered actually outdated in that case.
                if {$os_platform ne [$regref os_platform]} {
                    $regref os_platform $os_platform
                }
            }
        }
    }

    # Update archs if it has been corrected to 'noarch'.
    # Like platforms above, the opposite case requires a rev bump.
    set archs [$workername eval [list get_canonical_archs]]
    if {$archs eq "noarch" && $archs ne [$regref archs]} {
        if {$is_dryrun} {
            ui_info "Not updating archs for $portname @$tree_verstring (dry run)"
        } else {
            ui_info "Updating archs for $portname @$tree_verstring"
            registry::write {
                $regref archs $archs
            }
        }
    }
}

# mportselect
#   * command: The only valid commands are list, set, show and summary
#   * group: This argument should correspond to a directory under
#            ${macports::prefix}/etc/select.
#   * version: This argument is only used by the 'set' command.
# On error mportselect returns with the code 'error'.
proc mportselect {command {group ""} {version {}}} {
    ui_debug "mportselect \[$command] \[$group] \[$version]"

    global macports::prefix
    set conf_path ${prefix}/etc/select/$group
    if {![file isdirectory $conf_path]} {
        return -code error "The specified group '$group' does not exist."
    }

    switch -- $command {
        list {
            if {[catch {set versions [glob -directory $conf_path *]} result]} {
                ui_debug "${result}: $::errorInfo"
                return -code error [concat "No configurations associated" \
                                           "with '$group' were found."]
            }

            # Return the sorted list of versions (excluding base and current).
            set lversions [list]
            foreach v $versions {
                # Only the file name corresponds to the version name.
                set v [file tail $v]
                if {$v eq "base" || $v eq "current"} {
                    continue
                }
                lappend lversions [file tail $v]
            }
            return [lsort $lversions]
        }
        summary {
            # Return the list of portgroups in ${macports::prefix}/etc/select
            if {[catch {set lportgroups [glob -directory $conf_path -tails *]} result]} {
                ui_debug "${result}: $::errorInfo"
                return -code error [concat "No ports with the select" \
                                           "option were found."]
            }
            return [lsort $lportgroups]
        }
        set {
            # Use ${conf_path}/$version to read in sources.
            if {$version eq "" || $version eq "base" || $version eq "current"
                    || [catch {set src_file [open "${conf_path}/$version"]} result]} {
                ui_debug "${result}: $::errorInfo"
                return -code error "The specified version '$version' is not valid."
            }
            set srcs [split [read -nonewline $src_file] \n]
            close $src_file

            # Use ${conf_path}/base to read in targets.
            if {[catch {set tgt_file [open ${conf_path}/base]} result]} {
                ui_debug "${result}: $::errorInfo"
                return -code error [concat "The configuration file" \
                                           "'${conf_path}/base' could not be" \
                                           "opened."]
            }
            set tgts [split [read -nonewline $tgt_file] \n]
            close $tgt_file

            # Iterate through the configuration files executing the specified
            # actions.
            set i 0
            foreach tgt $tgts {
                set src [lindex $srcs $i]

                switch -glob -- $src {
                    - {
                        # The source is unavailable for this file.
                        set tgt [file join $prefix $tgt]
                        file delete $tgt
                        ui_debug "rm -f $tgt"
                    }
                    /* {
                        # The source is an absolute path.
                        set tgt [file join $prefix $tgt]
                        file delete $tgt
                        file link -symbolic $tgt $src
                        ui_debug "ln -sf $src $tgt"
                    }
                    default {
                        # The source is a relative path.
                        set src [file join $prefix $src]
                        set tgt [file join $prefix $tgt]
                        file delete $tgt
                        file link -symbolic $tgt $src
                        ui_debug "ln -sf $src $tgt"
                    }
                }
                incr i
            }

            # Update the selected version.
            set selected_version ${conf_path}/current
            file delete $selected_version
            symlink $version $selected_version
            return
        }
        show {
            set selected_version ${conf_path}/current

            if {[catch {file type $selected_version} err]} {
                # this might be okay if nothing was selected yet,
                # just log the error for debugging purposes
                ui_debug "cannot determine selected version for $group: $err"
                return none
            } else {
                return [file readlink $selected_version]
            }
        }
    }
    return
}

# Return a good temporary directory to use; /tmp if TMPDIR is not set
# in the environment
proc macports::gettmpdir {args} {
    global env

    if {[info exists env(TMPDIR)]} {
        return $env(TMPDIR)
    } else {
        return /tmp
    }
}

# check if the system we're on can run code of the given architecture
proc macports::arch_runnable {arch} {
    variable os_major; variable os_arch; variable os_platform
    if {$os_platform eq "darwin"} {
        if {$os_major >= 11 && [string first ppc $arch] == 0} {
            return no
        } elseif {$os_arch eq "i386" && $arch in [list arm64 ppc64]} {
            return no
        } elseif {$os_major <= 8 && $arch eq "x86_64"} {
            return no
        }
    }
    return yes
}

proc macports::diagnose_main {opts} {
    # Calls the main function for the 'port diagnose' command.
    #
    # Args: 
    #           None
    # Returns:
    #           0 on successful execution.

    diagnose::main $opts
    return 0
}

##
# Run reclaim if necessary
#
# @return 0 on success, 1 if an exception occurred during the execution
#         of reclaim, 2 if the execution was aborted on user request.
proc macports::reclaim_check_and_run {} {
    if {[macports::ui_isset ports_quiet]} {
        return 0
    }

    try {
        return [reclaim::check_last_run]
    } trap {POSIX SIG SIGINT} {} {
        ui_error [msgcat::mc "reclaim aborted: SIGINT received."]
        return 2
    } trap {POSIX SIG SIGTERM} {} {
        ui_error [msgcat::mc "reclaim aborted: SIGTERM received."]
        return 2
    } on error {eMessage} {
        ui_debug "reclaim failed: $::errorInfo"
        ui_error [msgcat::mc "reclaim failed: %s" $eMessage]
        return 1
    }
}

# create a snapshot. A snapshot is basically an inventory of what is installed
# along with meta data like requested and variants, and stored in the sqlite
# database.
proc macports::snapshot_main {opts} {

    # Calls the main function for the 'port snapshot' command.
    #
    # Args:
    #           $opts having a 'note'
    # Returns:
    #           0 on successful execution.

    return [snapshot::main $opts]
}

# restores a snapshot.
proc macports::restore_main {opts} {

    # Calls the main function for the 'port restore' command.
    #
    # Args:
    #           $opts having a 'snapshot-id' but not compulsorily
    # Returns:
    #           0 on successful execution.

    return [restore::main $opts]
}

##
# Calls the main function for the 'port migrate' command.
#
# @returns 0 on success, -999 when MacPorts base has been upgraded and the
#          caller should re-run itself and invoke migration with the --continue
#          flag set.
proc macports::migrate_main {opts} {
    return [migrate::main $opts]
}

proc macports::reclaim_main {opts} {
    # Calls the main function for the 'port reclaim' command.
    #
    # Args:
    #           None
    # Returns:
    #           None

    try {
        reclaim::main $opts
    } trap {POSIX SIG SIGINT} {} {
        ui_error [msgcat::mc "reclaim aborted: SIGINT received."]
        return 2
    } trap {POSIX SIG SIGTERM} {} {
        ui_error [msgcat::mc "reclaim aborted: SIGTERM received."]
        return 2
    } on error {eMessage} {
        ui_debug "reclaim failed: $::errorInfo"
        ui_error [msgcat::mc "reclaim failed: %s" $eMessage]
        return 1
    }
    return 0
}

# given a list of binaries, determine which C++ stdlib is used (if any)
proc macports::get_actual_cxx_stdlib {binaries} {
    if {$binaries eq ""} {
        return "none"
    }
    set handle [machista::create_handle]
    if {$handle eq "NULL"} {
        error "Error creating libmachista handle"
    }
    array set stdlibs {}
    foreach b $binaries {
        set resultlist [machista::parse_file $handle $b]
        set returncode [lindex $resultlist 0]
        set result     [lindex $resultlist 1]
        if {$returncode != $machista::SUCCESS} {
            if {$returncode == $machista::EMAGIC} {
                # not a Mach-O file
                # ignore silently, these are only static libs anyway
            } else {
                ui_debug "Error parsing file ${b}: [machista::strerror $returncode]"
            }
            continue;
        }
        set architecture [$result cget -mt_archs]
        while {$architecture ne "NULL"} {
            set loadcommand [$architecture cget -mat_loadcmds]
            while {$loadcommand ne "NULL"} {
                set libname [file tail [$loadcommand cget -mlt_install_name]]
                if {[string match libc++*.dylib $libname]} {
                    set stdlibs(libc++) 1
                } elseif {[string match libstdc++*.dylib $libname]} {
                    set stdlibs(libstdc++) 1
                }
                set loadcommand [$loadcommand cget -next]
            }
            set architecture [$architecture cget -next]
        }
    }

    machista::destroy_handle $handle

    if {[info exists stdlibs(libc++)]} {
        if {[info exists stdlibs(libstdc++)]} {
            return "mixed"
        } else {
            return "libc++"
        }
    } elseif {[info exists stdlibs(libstdc++)]} {
        return "libstdc++"
    } else {
        return "none"
    }
}

##
# Execute the rev-upgrade scan and attempt to rebuild all ports found to be
# broken. Depends on the revupgrade_mode setting from macports.conf.
#
# @param opts
#        A Tcl array serialized into a list using array get containing options
#        for MacPorts. Options used exclusively by rev-upgrade are
#        ports_rev-upgrade_id-loadcmd-check, a boolean indicating whether the
#        ID load command of binaries should be check for sanity. This is mostly
#        useful for maintainers.
# @return 0 if report-only mode is enabled, no ports are broken, or the
#         rebuilds finished successfully. 1 if an exception occurred during the
#         execution of rev-upgrade, 2 if the execution was aborted on user
#         request.
proc macports::revupgrade {opts} {
    set run_loop 1
    array set broken_port_counts {}
    try {
        while {$run_loop == 1} {
            set run_loop [revupgrade_scanandrebuild broken_port_counts $opts]
        }
        return 0
    } trap {POSIX SIG SIGINT} {} {
        ui_debug "rev-upgrade failed: $::errorInfo"
        ui_error [msgcat::mc "rev-upgrade aborted: SIGINT received."]
        return 2
    } trap {POSIX SIG SIGTERM} {} {
        ui_error [msgcat::mc "rev-upgrade aborted: SIGTERM received."]
        return 2
    } on error {eMessage} {
        ui_debug "rev-upgrade failed: $::errorInfo"
        ui_error [msgcat::mc "rev-upgrade failed: %s" $eMessage]
        return 1
    }
}

##
# Helper function for rev-upgrade. Sets the 'binary' flag to the appropriate
# value for files in the registry that don't have it set.
#
# @param fancy_output
#        Boolean, whether to use a progress display callback
# @param revupgrade_progress
#        Progress display callback name
proc macports::revupgrade_update_binary {fancy_output {revupgrade_progress ""}} {
    set files [registry::file search active 1 binary -null]
    set files_count [llength $files]

    if {$files_count > 0} {
        variable ui_prefix
        registry::write {
            try {
                ui_msg "$ui_prefix Updating database of binaries"
                set i 1
                if {$fancy_output} {
                    $revupgrade_progress start
                }
                foreach f $files {
                    if {$fancy_output} {
                        if {$files_count < 10000 || $i % 100 == 1} {
                            $revupgrade_progress update $i $files_count
                        }
                    }
                    set fpath [$f actual_path]
                    ui_debug "Updating binary flag for file $i of ${files_count}: $fpath"
                    incr i

                    try {
                        $f binary [fileIsBinary $fpath]
                    } trap {POSIX SIG SIGINT} {_ eOptions} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                        throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                    } trap {POSIX SIG SIGTERM} {_ eOptions} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                        throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                    } on error {eMessage} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        # handle errors (e.g. file not found, permission denied) gracefully
                        ui_warn "Error determining file type of `$fpath': $eMessage"
                        ui_warn "A file belonging to the `[[registry::entry owner $fpath] name]' port is missing or unreadable. Consider reinstalling it."
                    }
                }
            } on error {_ eOptions} {
                if {${fancy_output}} {
                    $revupgrade_progress intermission
                }
                ui_error "Updating database of binaries failed"
                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
            } finally {
                foreach f $files {
                    registry::file close $f
                }
            }
        }
        if {$fancy_output} {
            $revupgrade_progress finish
        }
    }
}

##
# Helper function for rev-upgrade. Sets the 'cxx_stdlib' flag to the
# appropriate value for ports in the registry that don't have it set.
#
# @param fancy_output
#        Boolean, whether to use a progress display callback
# @param revupgrade_progress
#        Progress display callback name
proc macports::revupgrade_update_cxx_stdlib {fancy_output {revupgrade_progress ""}} {
    set maybe_cxx_ports [registry::entry search state installed cxx_stdlib -null]
    set maybe_cxx_len [llength $maybe_cxx_ports]
    if {$maybe_cxx_len > 0} {
        variable ui_prefix
        ui_msg "$ui_prefix Updating database of C++ stdlib usage"
        set i 1
        if {$fancy_output} {
            $revupgrade_progress start
        }
        foreach maybe_port $maybe_cxx_ports {
            registry::write {
                if {$fancy_output} {
                    $revupgrade_progress update $i $maybe_cxx_len
                }
                incr i
                set binary_files [list]
                foreach filehandle [registry::file search id [$maybe_port id] binary 1] {
                    lappend binary_files [$filehandle actual_path]
                }
                $maybe_port cxx_stdlib [get_actual_cxx_stdlib $binary_files]
                if {[catch {$maybe_port cxx_stdlib_overridden}]} {
                    # can't tell after the fact, assume not overridden
                    $maybe_port cxx_stdlib_overridden 0
                }
            }
            #registry::entry close $maybe_port
        }
        if {$fancy_output} {
            $revupgrade_progress finish
        }
    }
}

##
# Helper function for rev-upgrade. Do not consider this to be part of public
# API. Use macports::revupgrade instead.
#
# @param broken_port_counts_name
#        The name of a Tcl array that's being used to store the number of times
#        a port has been rebuilt so far.
# @param opts
#        A serialized version of a Tcl array that contains options for
#        MacPorts. Options used by this method are
#        ports_rev-upgrade_id-loadcmd-check, a boolean indicating whether the
#        ID loadcommand of binaries should also be checked during rev-upgrade
#        and ports_dryrun, a boolean indicating whether no action should be
#        taken.
# @return 1 if ports were rebuilt and this function should be called again,
#         0 otherwise.
proc macports::revupgrade_scanandrebuild {broken_port_counts_name options} {
    upvar $broken_port_counts_name broken_port_counts
    variable ui_options; variable ui_prefix
    variable cxx_stdlib; variable revupgrade_mode

    set fancy_output [expr {![macports::ui_isset ports_debug] && [info exists ui_options(progress_generic)]}]
    if {$fancy_output} {
        set revupgrade_progress $ui_options(progress_generic)
    } else {
        set revupgrade_progress ""
    }

    revupgrade_update_binary $fancy_output $revupgrade_progress

    revupgrade_update_cxx_stdlib $fancy_output $revupgrade_progress

    set broken_files [list]
    set binaries [registry::file search active 1 binary 1]
    set binary_count [llength $binaries]
    if {$binary_count > 0} {
        ui_msg "$ui_prefix Scanning binaries for linking errors"
        set handle [machista::create_handle]
        if {$handle eq "NULL"} {
            error "Error creating libmachista handle"
        }
        array unset files_warned_about
        array set files_warned_about [list]

        if {$fancy_output} {
            $revupgrade_progress start
        }

        try {
            set i 1
            foreach b $binaries {
                if {$fancy_output} {
                    if {$binary_count < 10000 || $i % 10 == 1} {
                        $revupgrade_progress update $i $binary_count
                    }
                }
                set bpath [$b actual_path]
                #ui_debug "${i}/${binary_count}: $bpath"
                incr i

                set resultlist [machista::parse_file $handle $bpath]
                set returncode [lindex $resultlist 0]
                set result     [lindex $resultlist 1]

                if {$returncode != $machista::SUCCESS} {
                    if {$returncode == $machista::EMAGIC} {
                        # not a Mach-O file
                        # ignore silently, these are only static libs anyway
                        #ui_debug "Error parsing file ${bpath}: [machista::strerror $returncode]"
                    } else {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        ui_warn "Error parsing file ${bpath}: [machista::strerror $returncode]"
                    }
                    continue;
                }

                set architecture [$result cget -mt_archs]
                while {$architecture ne "NULL"} {
                    if {[dict exists $options ports_rev-upgrade_id-loadcmd-check] && [dict get $options ports_rev-upgrade_id-loadcmd-check]} {
                        if {[$architecture cget -mat_install_name] ne "NULL" && [$architecture cget -mat_install_name] ne ""} {
                            # check if this lib's install name actually refers to this file itself
                            # if this is not the case software linking against this library might have erroneous load commands

                            try {
                                set idloadcmdpath [revupgrade_handle_special_paths $bpath [$architecture cget -mat_install_name]]
                                if {[string index $idloadcmdpath 0] ne "/"} {
                                    set port [registry::entry owner $bpath]
                                    if {$port ne ""} {
                                        set portname [$port name]
                                    } else {
                                        set portname <unknown-port>
                                    }
                                    if {$fancy_output} {
                                        $revupgrade_progress intermission
                                    }
                                    ui_warn "ID load command in ${bpath}, arch [machista::get_arch_name [$architecture cget -mat_arch]] (belonging to port $portname) contains relative path"
                                } elseif {![file exists $idloadcmdpath]} {
                                    set port [registry::entry owner $bpath]
                                    if {$port ne ""} {
                                        set portname [$port name]
                                    } else {
                                        set portname <unknown-port>
                                    }
                                    if {$fancy_output} {
                                        $revupgrade_progress intermission
                                    }
                                    ui_warn "ID load command in ${bpath}, arch [machista::get_arch_name [$architecture cget -mat_arch]] refers to non-existent file $idloadcmdpath"
                                    ui_warn "This is probably a bug in the $portname port and might cause problems in libraries linking against this file"
                                } else {
                                    set hash_this [sha256 file $bpath]
                                    set hash_idloadcmd [sha256 file $idloadcmdpath]

                                    if {$hash_this ne $hash_idloadcmd} {
                                        set port [registry::entry owner $bpath]
                                        if {$port ne ""} {
                                            set portname [$port name]
                                        } else {
                                            set portname <unknown-port>
                                        }
                                        if {$fancy_output} {
                                            $revupgrade_progress intermission
                                        }
                                        ui_warn "ID load command in ${bpath}, arch [machista::get_arch_name [$architecture cget -mat_arch]] refers to file ${idloadcmdpath}, which is a different file"
                                        ui_warn "This is probably a bug in the $portname port and might cause problems in libraries linking against this file"
                                    }
                                }
                            } trap {POSIX SIG SIGINT} {_ eOptions} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                            } trap {POSIX SIG SIGTERM} {_ eOptions} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                                throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                            }
                        }
                    }

                    set archname [machista::get_arch_name [$architecture cget -mat_arch]]
                    if {![arch_runnable $archname]} {
                        ui_debug "skipping $archname in $bpath since this system can't run it anyway"
                        set architecture [$architecture cget -next]
                        continue
                    }

                    set loadcommand [$architecture cget -mat_loadcmds]

                    while {$loadcommand ne "NULL"} {
                        # see https://trac.macports.org/ticket/52700
                        set LC_LOAD_WEAK_DYLIB 0x80000018
                        if {[$loadcommand cget -mlt_type] == $LC_LOAD_WEAK_DYLIB} {
                            ui_debug "[msgcat::mc "Skipping weakly-linked"] [$loadcommand cget -mlt_install_name]"
                            set loadcommand [$loadcommand cget -next]
                            continue
                        }

                        try {
                            set filepath [revupgrade_handle_special_paths $bpath [$loadcommand cget -mlt_install_name]]
                        } trap {POSIX SIG SIGINT} {_ eOptions} {
                            if {$fancy_output} {
                                $revupgrade_progress intermission
                            }
                            ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                            throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                        } trap {POSIX SIG SIGTERM} {_ eOptions} {
                            if {$fancy_output} {
                                $revupgrade_progress intermission
                            }
                            ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                            throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
                        } on error {} {
                            set loadcommand [$loadcommand cget -next]
                            continue
                        }

                        set libresultlist [machista::parse_file $handle $filepath]
                        set libreturncode [lindex $libresultlist 0]
                        set libresult     [lindex $libresultlist 1]

                        if {$libreturncode != $machista::SUCCESS} {
                            if {![info exists files_warned_about($filepath)] && $libreturncode != $machista::ECACHE} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_info "Could not open ${filepath}: [machista::strerror $libreturncode] (referenced from $bpath)"
                                if {[string first [file separator] $filepath] == -1} {
                                    ui_info "${filepath} seems to be referenced using a relative path. This may be a problem with its canonical library name and require the use of install_name_tool(1) to fix."
                                }
                                set files_warned_about($filepath) yes
                            }
                            if {$libreturncode == $machista::EFILE} {
                                ui_debug "Marking $bpath as broken"
                                lappend broken_files $bpath
                            }
                            set loadcommand [$loadcommand cget -next]
                            continue;
                        }

                        set libarchitecture [$libresult cget -mt_archs]
                        set libarch_found false;
                        while {$libarchitecture ne "NULL"} {
                            if {[$architecture cget -mat_arch] ne [$libarchitecture cget -mat_arch]} {
                                set libarchitecture [$libarchitecture cget -next]
                                continue;
                            }

                            if {[$loadcommand cget -mlt_version] ne [$libarchitecture cget -mat_version] && [$loadcommand cget -mlt_comp_version] > [$libarchitecture cget -mat_comp_version]} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_info "Incompatible library version: $bpath requires version [machista::format_dylib_version [$loadcommand cget -mlt_comp_version]] or later, but $filepath provides version [machista::format_dylib_version [$libarchitecture cget -mat_comp_version]]"
                                ui_debug "Marking $bpath as broken"
                                lappend broken_files $bpath
                            }

                            set libarch_found true;
                            break;
                        }

                        if {!$libarch_found} {
                            ui_debug "Missing architecture [machista::get_arch_name [$architecture cget -mat_arch]] in file $filepath"
                            if {[path_is_in_prefix $filepath]} {
                                ui_debug "Marking $bpath as broken"
                                lappend broken_files $bpath
                            } else {
                                ui_debug "Missing architecture [machista::get_arch_name [$architecture cget -mat_arch]] in file outside prefix referenced from $bpath"
                                # ui_debug "   How did you get that compiled anyway?"
                            }
                        }
                        set loadcommand [$loadcommand cget -next]
                    }

                    set architecture [$architecture cget -next]
                }
            }
        } on error {_ eOptions} {
            if {$fancy_output} {
                $revupgrade_progress intermission
            }
            throw [dict get $eOptions -errorcode] [dict get $eOptions -errorinfo]
        } finally {
            foreach b $binaries {
                registry::file close $b
            }
        }
        if {$fancy_output} {
            $revupgrade_progress finish
        }

        machista::destroy_handle $handle

        set num_broken_files [llength $broken_files]
        set s [expr {$num_broken_files == 1 ? "" : "s"}]

        set broken_ports [list]
        if {$num_broken_files == 0} {
            ui_msg "$ui_prefix No broken files found."
        } else {
            ui_msg "$ui_prefix Found $num_broken_files broken file${s}, matching files to ports"
            set broken_files [lsort -unique $broken_files]
            foreach file $broken_files {
                set port [registry::entry owner $file]
                if {$port ne ""} {
                    lappend broken_ports $port
                    lappend broken_files_by_port($port) $file
                } else {
                    ui_error "Broken file $file doesn't belong to any port."
                }
            }
        }

        # check for mismatched cxx_stdlib
        if {${cxx_stdlib} eq "libc++"} {
            set wrong_stdlib libstdc++
        } else {
            set wrong_stdlib libc++
        }
        set broken_cxx_ports [registry::entry search state installed cxx_stdlib_overridden 0 cxx_stdlib $wrong_stdlib]
        foreach cxx_port $broken_cxx_ports {
            ui_info "[$cxx_port name] is using $wrong_stdlib (this installation is configured to use ${cxx_stdlib})"
        }
        set broken_ports [lsort -unique [concat $broken_ports $broken_cxx_ports]]

        if {[llength $broken_ports] == 0} {
            ui_msg "$ui_prefix No broken ports found."
            return 0
        }

        if {$revupgrade_mode eq "rebuild"} {
            # don't try to rebuild ports that don't exist in the tree
            set temp_broken_ports [list]
            foreach port $broken_ports {
                set portname [$port name]
                if {[catch {mportlookup $portname} result]} {
                    ui_debug $::errorInfo
                    error "lookup of portname $portname failed: $result"
                }
                if {[llength $result] >= 2} {
                    lappend temp_broken_ports $port
                } else {
                    #registry::entry close $port
                    ui_warn "No port $portname found in the index; can't rebuild"
                }
            }

            if {[llength $temp_broken_ports] == 0} {
                ui_msg "$ui_prefix Broken files found, but all associated ports are not in the index and so cannot be rebuilt."
                return 0
            }
        } else {
            set temp_broken_ports $broken_ports
        }

        set broken_ports [list]

        foreach port $temp_broken_ports {
            set portname [$port name]

            set broken_reason ""
            if {![info exists broken_files_by_port($port)]} {
                set broken_reason "(cxx_stdlib mismatch) "
            }
            if {![info exists broken_port_counts($portname)]} {
                set broken_port_counts($portname) 0
            }
            incr broken_port_counts($portname)
            if {$broken_port_counts($portname) > 3} {
                ui_error "Port $portname is still broken ${broken_reason}after rebuilding it more than 3 times."
                if {$fancy_output} {
                    ui_error "Please run port -d -y rev-upgrade and use the output to report a bug."
                }
                set rebuild_tries [expr {$broken_port_counts($portname) - 1}]
                set s [expr {$rebuild_tries == 1 ? "" : "s"}]
                error "Port $portname still broken after rebuilding $rebuild_tries time${s}"
            } elseif {$broken_port_counts($portname) > 1 && [global_option_isset ports_binary_only]} {
                error "Port $portname still broken ${broken_reason}after reinstalling -- can't rebuild due to binary-only mode"
            }
            lappend broken_ports $port
        }
        unset temp_broken_ports

        set num_broken_ports [llength $broken_ports]
        set s [expr {$num_broken_ports == 1 ? "" : "s"}]

        if {$revupgrade_mode ne "rebuild"} {
            ui_msg "$ui_prefix Found $num_broken_ports broken port${s}:"
            foreach port $broken_ports {
                ui_msg "     [$port name] @[$port version]_[$port revision][$port variants]"
                if {[info exists broken_files_by_port($port)]} {
                    foreach f $broken_files_by_port($port) {
                        ui_msg "         $f"
                    }
                } else {
                    ui_msg "         (cxx_stdlib mismatch)"
                }
                #registry::entry close $port
            }
            return 0
        }

        ui_msg "$ui_prefix Found $num_broken_ports broken port${s}, determining rebuild order"
        # broken_ports are the nodes in our graph
        # now we need adjacents
        foreach port $broken_ports {
            # initialize with empty list
            set adjlist($port) [list]
            set revadjlist($port) [list]
            ui_debug "Broken: [$port name]"
        }

        array set visited {}
        foreach port $broken_ports {
            # stack of broken nodes we've come across
            set stack [list]
            lappend stack $port

            # build graph
            if {![info exists visited($port)]} {
                revupgrade_buildgraph $port stack adjlist revadjlist visited
            }
        }

        set unsorted_ports $broken_ports
        set topsort_ports [list]
        while {[llength $unsorted_ports] > 0} {
            set lowest_adj_number [llength $adjlist([lindex $unsorted_ports 0])]
            set lowest_adj_port [lindex $unsorted_ports 0]

            foreach port $unsorted_ports {
                set len [llength $adjlist($port)]
                if {$len < $lowest_adj_number} {
                    set lowest_adj_port $port
                    set lowest_adj_number $len
                }
                if {$len == 0} {
                    # this node has no further dependencies
                    # add it to topsorted list
                    lappend topsort_ports $port
                    # remove from unsorted list
                    set index [lsearch -exact $unsorted_ports $port]
                    set unsorted_ports [lreplace ${unsorted_ports}[set unsorted_ports {}] $index $index]

                    # remove edges
                    foreach target $revadjlist($port) {
                        set index [lsearch -exact $adjlist($target) $port]
                        set adjlist($target) [lreplace $adjlist($target)[set adjlist($target) {}] $index $index]
                    }

                    break;
                }
            }

            # if we arrive here and lowest_adj_number is larger than 0, then we
            # have a loop in the graph and need to break it somehow
            if {$lowest_adj_number > 0} {
                ui_debug "Breaking loop in dependency graph by starting with [$lowest_adj_port name], which has $lowest_adj_number dependencies"
                lappend topsort_ports $lowest_adj_port

                set index [lsearch -exact $unsorted_ports $lowest_adj_port]
                set unsorted_ports [lreplace ${unsorted_ports}[set unsorted_ports {}] $index $index]

                foreach target $revadjlist($port) {
                    set index [lsearch -exact $adjlist($target) $lowest_adj_port]
                    set adjlist($target) [lreplace $adjlist($target)[set adjlist($target) {}] $index $index]
                }
            }
        }

        set broken_portnames [list]
        if {![info exists ui_options(questions_yesno)]} {
            ui_msg "$ui_prefix Rebuilding in order"
        }
        foreach port $topsort_ports {
            lappend broken_portnames [$port name]@[$port version][$port variants]
            if {![info exists ui_options(questions_yesno)]} {
                ui_msg "     [$port name] @[$port version]_[$port revision][$port variants]"
            }
        }

        ##
        # User Interaction Question
        # Asking before rebuilding in rev-upgrade
        if {[info exists ui_options(questions_yesno)]} {
            ui_msg "You can always run 'port rev-upgrade' again to fix errors."
            set retvalue [$ui_options(questions_yesno) "The following ports will be rebuilt:" "TestCase#1" $broken_portnames {y} 0]
            if {$retvalue == 1} {
                # quit as user answered 'no'
                #foreach p $topsort_ports {
                #    registry::entry close $p
                #}
                return 0
            }
            unset ui_options(questions_yesno)
        }

        # shared depscache for all ports that are going to be rebuilt
        array set depscache {}
        set status 0
        variable global_options
        set my_options [array get global_options]
        dict set my_options ports_revupgrade yes

        # Depending on the options, calling macports::upgrade could
        # uninstall later entries in this list. So get the info we need
        # from all the entries first.
        set topsort_portnames [list]
        foreach port $topsort_ports {
            lappend topsort_portnames [$port name]
            #registry::entry close $port
        }
        foreach portname $topsort_portnames {
            if {![info exists depscache(port:$portname)]} {
                dict unset my_options ports_revupgrade_second_run
                dict unset my_options ports_nodeps
                if {$broken_port_counts($portname) > 1} {
                    dict set my_options ports_revupgrade_second_run yes

                    if {$broken_port_counts($portname) > 2} {
                        # runtime deps are upgraded the first time, build deps 
                        # the second, so none left to do the third time
                        dict set my_options ports_nodeps yes
                    }
                }

                # call macports::upgrade with ports_revupgrade option to rebuild the port
                set status [macports::upgrade $portname port:$portname \
                    {} $my_options depscache]
                ui_debug "Rebuilding port $portname finished with status $status"
                if {$status != 0} {
                    error "Error rebuilding $portname"
                }
            }
        }

        if {[dict exists $options ports_dryrun] && [dict get $options ports_dryrun]} {
            ui_warn "If this was not a dry run, rev-upgrade would now run the checks again to find unresolved and newly created problems"
            return 0
        }
        return 1
    }

    return 0
}

# Return whether a path is in the macports prefix
# Usage: path_is_in_prefix path_to_test
# Returns true if the path is in the prefix, false otherwise
proc macports::path_is_in_prefix {path} {
    variable prefix; variable applications_dir
    if {[string first $prefix $path] == 0} {
        return yes
    }
    if {[string first $applications_dir $path] == 0} {
        return yes
    }
    return no
}

# Function to replace macros in loadcommand paths with their proper values (which are usually determined at load time)
# Usage: revupgrade_handle_special_paths name_of_file path_from_loadcommand
# Returns the corrected path on success or an error in case of failure.
# Note that we can't reliably replace @executable_path, because it's only clear when executing a file where it was executed from.
# Replacing @rpath does not work yet, but it might be possible to get it working using the rpath attribute in the file containing the
# loadcommand
proc macports::revupgrade_handle_special_paths {fname path} {
    set corrected_path $path

    set loaderpath_idx [string first @loader_path $corrected_path]
    if {$loaderpath_idx != -1} {
        set corrected_path [string replace $corrected_path $loaderpath_idx ${loaderpath_idx}+11 [file dirname $fname]]
    }

    set executablepath_idx [string first @executable_path $corrected_path]
    if {$executablepath_idx != -1} {
        ui_debug "Ignoring loadcommand containing @executable_path in $fname"
        error "@executable_path in loadcommand"
    }

    set rpath_idx [string first @rpath $corrected_path]
    if {$rpath_idx != -1} {
        ui_debug "Ignoring loadcommand containing @rpath in $fname"
        error "@rpath in loadcommand"
    }

    return $corrected_path
}

# Recursively build the dependency graph between broken ports
# Usage: revupgrade_buildgraph start_port name_of_stack name_of_adjacency_list name_of_reverse_adjacency_list name_of_visited_map
proc macports::revupgrade_buildgraph {port stackname adjlistname revadjlistname visitedname} {
    upvar $stackname stack
    upvar $adjlistname adjlist
    upvar $revadjlistname revadjlist
    upvar $visitedname visited

    set visited($port) true

    ui_debug "Processing port [$port name] @[$port epoch]:[$port version]_[$port revision][$port variants]"
    set dependent_ports [$port dependents]
    foreach dep $dependent_ports {
        set is_broken_port false

        if {[info exists adjlist($dep)]} {
            ui_debug "Dependent [$dep name] is broken, adding edge from [$dep name] to [[lindex $stack 0] name]"
            ui_debug "Making [$dep name] new head of stack"
            # $dep is one of the broken ports
            # add an edge to the last broken port in the DFS
            lappend revadjlist([lindex $stack 0]) $dep
            lappend adjlist($dep) [lindex $stack 0]
            # make this port the new last broken port by prepending it to the stack
            set stack [linsert $stack 0 $dep]

            set is_broken_port true
        }
        if {![info exists visited($dep)]} {
            revupgrade_buildgraph $dep stack adjlist revadjlist visited
        }
        if {$is_broken_port} {
            ui_debug "Removing [$dep name] from stack"
            # remove $dep from the stack
            set stack [lrange $stack 1 end]
        }
    }
}

# Deferred loading of ping times cache
proc macports::load_ping_cache {name1 name2 op} {
    variable ping_cache
    trace remove variable ping_cache {read write} macports::load_ping_cache
    if {$op eq "write"} {
        set ping_cache [dict merge [load_cache pingtimes] $ping_cache]
    } else {
        set ping_cache [load_cache pingtimes]
    }
}

# get cached ping time for host, modified by blacklist and preferred list
proc macports::get_pingtime {host} {
    variable host_cache

    if {![dict exists $host_cache $host]} {
        variable host_blacklist
        foreach pattern $host_blacklist {
            if {[string match -nocase $pattern $host]} {
                dict set host_cache $host -1
                return -1
            }
        }
        variable preferred_hosts
        foreach pattern $preferred_hosts {
            if {[string match -nocase $pattern $host]} {
                dict set host_cache $host 0
                return 0
            }
        }
        dict set host_cache $host {}
    }
    if {[dict get $host_cache $host] ne {}} {
        return [dict get $host_cache $host]
    }

    variable ping_cache
    if {[dict exists $ping_cache $host]} {
        # expire entries after 1 day
        if {[clock seconds] - [lindex [dict get $ping_cache $host] 1] <= 86400} {
            return [lindex [dict get $ping_cache $host] 0]
        }
    }
    return {}
}

# cache a ping time of ms for host
proc macports::set_pingtime {host ms} {
    variable ping_cache
    dict set ping_cache $host [list $ms [clock seconds]]
    variable cache_dirty
    dict set cache_dirty pingtimes 1
}

# Deferred loading of compiler version cache
proc macports::load_compiler_version_cache {name1 name2 op} {
    variable compiler_version_cache; variable xcodeversion; variable xcodecltversion

    trace remove variable compiler_version_cache read macports::load_compiler_version_cache

    set compiler_version_cache [load_cache compiler_versions]
    # Invalidate if Xcode or CLT version changed
    if {([dict exists $compiler_version_cache xcodeversion]
            && $xcodeversion ne [dict get $compiler_version_cache xcodeversion])
            || ([dict exists $compiler_version_cache xcodecltversion]
            && $xcodecltversion ne [dict get $compiler_version_cache xcodecltversion])} {
        set compiler_version_cache [dict create]
    }
    if {[dict size $compiler_version_cache] == 0} {
        dict set compiler_version_cache xcodeversion $xcodeversion
        dict set compiler_version_cache xcodecltversion $xcodecltversion
    }
}

# get the version of a compiler (cached)
proc macports::get_compiler_version {compiler developer_dir} {
    variable compiler_version_cache

    if {[dict exists $compiler_version_cache versions $developer_dir $compiler]} {
        return [dict get $compiler_version_cache versions $developer_dir $compiler]
    }

    if {![file executable ${compiler}]} {
        dict set compiler_version_cache versions $developer_dir $compiler ""
        return ""
    }

    switch -- [file tail ${compiler}] {
        clang {
            set re {clang(?:_.*)?-([0-9.]+)}
        }
        llvm-gcc-4.2 {
            set re {LLVM build ([0-9.]+)}
        }
        gcc-4.2 -
        gcc-4.0 {
            set re {build ([0-9.]+)}
        }
        default {
            return -code error "don't know how to determine build number of compiler \"${compiler}\""
        }
    }

    if {[catch {regexp ${re} [exec /usr/bin/env DEVELOPER_DIR=${developer_dir} ${compiler} -v 2>@1] -> compiler_version}]} {
        dict set compiler_version_cache versions $developer_dir $compiler ""
        return ""
    }
    if {![info exists compiler_version]} {
        return -code error "couldn't determine build number of compiler \"${compiler}\""
    }
    dict set compiler_version_cache versions $developer_dir $compiler $compiler_version
    variable cache_dirty
    dict set cache_dirty compiler_versions 1
    return $compiler_version
}

# check availability and location of tool
proc macports::get_tool_path {tool} {
    variable tool_path_cache

    if {[dict exists $tool_path_cache $tool]} {
        return [dict get $tool_path_cache $tool]
    }

    # first try /usr/bin since this doesn't move around
    set toolpath "/usr/bin/${tool}"
    if {![file executable $toolpath]} {
        # Use xcode's xcrun to find the named tool.
        if {[catch {exec -ignorestderr [findBinary xcrun $macports::autoconf::xcrun_path] -find ${tool} 2> /dev/null} toolpath]} {
            set toolpath ""
        }
    }

    dict set tool_path_cache $tool $toolpath
    return $toolpath
}

# Load the global description file for a port tree
#
# @param descfile path to the descriptions file
# @return A dict mapping variant names to descriptions
proc macports::load_variant_desc_file {descfile} {
    set variant_descs [dict create]
    if {[file exists $descfile]} {
        ui_debug "Reading variant descriptions from $descfile"

        if {[catch {set fd [open $descfile r]} err]} {
            ui_warn "Could not open global variant description file: $err"
            return $variant_descs
        }
        set lineno 0
        while {[gets $fd line] >= 0} {
            incr lineno
            lassign $line name desc
            if {$name ne "" && $desc ne ""} {
                dict set variant_descs $name $desc
            } else {
                ui_warn "Invalid variant description in $descfile at line $lineno"
            }
        }
        close $fd
    }
    return $variant_descs
}

# deferred loading of variant_descriptions.conf from default source
proc macports::load_default_variant_descriptions {name1 name2 op} {
    variable default_variant_descriptions

    trace remove variable default_variant_descriptions read macports::load_default_variant_descriptions

    set descfile [getdefaultportresourcepath port1.0/variant_descriptions.conf]
    set default_variant_descriptions [load_variant_desc_file $descfile]
}

# get global description for a variant (called from portfile interpreters)
# @param variant name of the variant
# @param resourcepath dir to search for conf file
# @return description from descriptions file or an empty string
proc macports::get_variant_description {variant resourcepath} {
    variable variant_descriptions

    if {![dict exists $variant_descriptions $resourcepath]} {
        variable default_variant_descriptions
        if {$resourcepath eq [getdefaultportresourcepath]} {
            dict set variant_descriptions $resourcepath $default_variant_descriptions
        } else {
            set descfile [file join $resourcepath port1.0/variant_descriptions.conf]
            dict set variant_descriptions $resourcepath [dict merge $default_variant_descriptions [load_variant_desc_file $descfile]]
        }
    }

    if {[dict exists $variant_descriptions $resourcepath $variant]} {
        return [dict get $variant_descriptions $resourcepath $variant]
    }
    return {}
}

# read and cache archive_sites.conf (called from port1.0 code)
proc macports::get_archive_sites_conf_values {} {
    variable archive_sites_conf_values
    if {![info exists archive_sites_conf_values]} {
        variable archive_sites_conf
        variable os_platform; variable os_major
        set archive_sites_conf_values [list]
        set all_names [list]
        set defaults_list [list applications_dir /Applications/MacPorts prefix /opt/local type tbz2]
        if {$os_platform eq "darwin" && $os_major <= 12} {
            lappend defaults_list cxx_stdlib libstdc++ delete_la_files no
        } else {
            lappend defaults_list cxx_stdlib libc++ delete_la_files yes
        }
        array set defaults $defaults_list
        set conf_options [list applications_dir cxx_stdlib delete_la_files frameworks_dir name prefix type urls]
        set line_re {^(\w+)([ \t]+(.*))?$}
        if {[file isfile $archive_sites_conf]} {
            set fd [open $archive_sites_conf r]
            while {[gets $fd line] >= 0} {
                if {[regexp $line_re $line match option ignore val] == 1} {
                    if {$option in $conf_options} {
                        if {$option eq "name"} {
                            set cur_name $val
                            lappend all_names $val
                        } elseif {[info exists cur_name]} {
                            set trimmedval [string trim $val]
                            if {$option eq "urls"} {
                                set processed_urls [list]
                                foreach url $trimmedval {
                                    lappend processed_urls ${url}:nosubdir
                                }
                                lappend archive_sites_conf_values portfetch::mirror_sites::sites($cur_name) $processed_urls
                                set sites($cur_name) $processed_urls
                            } else {
                                lappend archive_sites_conf_values portfetch::mirror_sites::archive_${option}($cur_name) $trimmedval
                                set archive_${option}($cur_name) $trimmedval
                            }
                        } else {
                            ui_warn "archive_sites.conf: ignoring '$option' occurring before name"
                        }
                    } else {
                        ui_warn "archive_sites.conf: ignoring unknown key '$option'"
                    }
                }
            }
            close $fd

            # check for unspecified values and set to defaults
            foreach cur_name $all_names {
                foreach key [array names defaults] {
                    if {![info exists archive_${key}($cur_name)]} {
                        set archive_${key}($cur_name) $defaults($key)
                        lappend archive_sites_conf_values portfetch::mirror_sites::archive_${key}($cur_name) $defaults($key)
                    }
                }
                if {![info exists archive_frameworks_dir($cur_name)]} {
                    set archive_frameworks_dir($cur_name) $archive_prefix($cur_name)/Library/Frameworks
                    lappend archive_sites_conf_values portfetch::mirror_sites::archive_frameworks_dir($cur_name) $archive_frameworks_dir($cur_name)
                }
                if {![info exists sites($cur_name)]} {
                    ui_warn "archive_sites.conf: no urls set for $cur_name"
                    set sites($cur_name) {}
                    lappend archive_sites_conf_values portfetch::mirror_sites::sites($cur_name) {}
                }
            }
        }
    }
    return $archive_sites_conf_values
}

##
# Escape a string for use in a POSIX shell, e.g., when passing it to the \c system Pextlib extension. This is necessary
# to handle cases such as group names with backslashes correctly. See #43875 for an example of a problem caused by
# missing quotes.
#
# @param arg The argument that should be escaped for use in a POSIX shell
# @return A quoted version of the argument
proc macports::shellescape {arg} {
    # Put a bashslash in front of every character that is not safe. This
    # may not be an exhaustive list of safe characters but it is allowed
    # to put a backslash in front of safe characters too.
    return [regsub -all -- {[^A-Za-z0-9.:@%/+=_-]} $arg {\\&}]
}

##
# Given a list of maintainers as recorded in a Portfile, return a list of lists
# in [key value ...] format describing all maintainers. Valid keys are 'email'
# which denotes a maintainer's email address, 'github', which precedes the
# GitHub username of the maintainer and 'keyword', which contains a special
# maintainer keyword such as 'openmaintainer' or 'nomaintainer'.
#
# @param list A list of obscured maintainers
# @return A list of associative arrays in serialized list format
proc macports::unobscure_maintainers {list} {
    return [macports_util::unobscure_maintainers $list]
}

# Get actual number of parallel jobs based on buildmakejobs, which may
# be 0 for automatic selection.
proc macports::get_parallel_jobs {{mem_restrict yes}} {
    variable buildmakejobs; variable os_platform
    if {[string is integer -strict $buildmakejobs] && $buildmakejobs > 0} {
        set jobs $buildmakejobs
    } elseif {$os_platform eq "darwin" && $buildmakejobs == 0
              && ![catch {sysctl hw.activecpu} cpus]} {
        set jobs $cpus
        if {$mem_restrict && ![catch {sysctl hw.memsize} memsize]
                && $jobs > $memsize / (1024 * 1024 * 1024) + 1} {
            set jobs [expr {$memsize / (1024 * 1024 * 1024) + 1}]
        }
    } else {
        set jobs 2
    }
    return $jobs
}

# Returns list of Xcode versions for the current macOS version:
# [min, ok, rec]
# min = lowest version that will work at all
# ok = lowest version without any serious known issues
# rec = recommended version, usually the latest known
proc macports::get_compatible_xcode_versions {} {
    variable macos_version_major
    switch $macos_version_major {
        10.4 {
            set min 2.0
            set ok 2.4.1
            set rec 2.5
        }
        10.5 {
            set min 3.0
            set ok 3.1
            set rec 3.1.4
        }
        10.6 {
            set min 3.2
            set ok 3.2
            set rec 3.2.6
        }
        10.7 {
            set min 4.1
            set ok 4.1
            set rec 4.6.3
        }
        10.8 {
            set min 4.4
            set ok 4.4
            set rec 5.1.1
        }
        10.9 {
            set min 5.0.1
            set ok 5.0.1
            set rec 6.2
        }
        10.10 {
            set min 6.1
            set ok 6.1
            set rec 7.2.1
        }
        10.11 {
            set min 7.0
            set ok 7.0
            set rec 8.2.1
        }
        10.12 {
            set min 8.0
            set ok 8.0
            set rec 9.2
        }
        10.13 {
            set min 9.0
            set ok 9.0
            set rec 9.4.1
        }
        10.14 {
            set min 10.0
            set ok 10.0
            set rec 10.3
        }
        10.15 {
            set min 11.0
            set ok 11.3
            set rec 11.7
        }
        11 {
            set min 12.2
            set ok 12.2
            set rec 12.5
        }
        12 {
            set min 13.1
            set ok 13.1
            set rec 13.4.1
        }
        13 {
            set min 14.1
            set ok 14.1
            set rec 14.3.1
        }
        14 {
            set min 15.0
            set ok 15.1
            set rec 15.4
        }
        15 {
            set min 16
            set ok 16
            set rec 16
        }
        default {
            set min 16
            set ok 16
            set rec 16
        }
    }
    return [list $min $ok $rec]
}

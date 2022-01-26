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
package require Tclx

# catch wrapper shared with port1.0
package require mpcommon 1.0

namespace eval macports {
    namespace export bootstrap_options user_options portinterp_options open_mports ui_priorities
    variable bootstrap_options "\
        portdbpath binpath auto_path extra_env sources_conf prefix portdbformat \
        portarchivetype hfscompression portautoclean \
        porttrace portverbose keeplogs destroot_umask variants_conf rsync_server rsync_options \
        rsync_dir startupitem_autostart startupitem_type startupitem_install \
        place_worksymlink xcodeversion xcodebuildcmd \
        configureccache ccache_dir ccache_size configuredistcc configurepipe buildnicevalue buildmakejobs \
        applications_dir frameworks_dir developer_dir universal_archs build_arch macosx_sdk_version macosx_deployment_target \
        macportsuser proxy_override_env proxy_http proxy_https proxy_ftp proxy_rsync proxy_skip \
        master_site_local patch_site_local archive_site_local buildfromsource \
        revupgrade_autorun revupgrade_mode revupgrade_check_id_loadcmds \
        host_blacklist preferred_hosts sandbox_enable sandbox_network delete_la_files cxx_stdlib \
        packagemaker_path default_compilers pkg_post_unarchive_deletions ui_interactive"
    variable user_options {}
    variable portinterp_options "\
        portdbpath porturl portpath portbuildpath auto_path prefix prefix_frozen portsharepath \
        registry.path registry.format user_home user_path user_ssh_auth_sock \
        portarchivetype archivefetch_pubkeys portautoclean porttrace keeplogs portverbose destroot_umask \
        rsync_server rsync_options rsync_dir startupitem_autostart startupitem_type startupitem_install \
        place_worksymlink macportsuser sudo_user \
        configureccache ccache_dir ccache_size configuredistcc configurepipe buildnicevalue buildmakejobs \
        applications_dir applications_dir_frozen current_phase frameworks_dir frameworks_dir_frozen \
        developer_dir universal_archs build_arch os_arch os_endian os_version os_major os_minor \
        os_platform os_subplatform macos_version macos_version_major macosx_version macosx_sdk_version \
        macosx_deployment_target packagemaker_path default_compilers sandbox_enable sandbox_network \
        delete_la_files cxx_stdlib pkg_post_unarchive_deletions $user_options"

    # deferred options are only computed when needed.
    # they are not exported to the trace thread.
    # they are not exported to the interpreter in system_options array.
    variable portinterp_deferred_options "xcodeversion xcodebuildcmd developer_dir"

    variable open_mports {}

    variable ui_priorities "error warn msg notice info debug any"
    variable current_phase main

    variable ui_prefix "---> "
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
    if {[info exists macports::ui_options($val)]} {
        return [string is true -strict $macports::ui_options($val)]
    }
    return 0
}


# global_options accessor
proc macports::global_option_isset {val} {
    if {[info exists macports::global_options($val)]} {
        return [string is true -strict $macports::global_options($val)]
    }
    return 0
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
    array set portinfo [mportinfo $mport]
    set portname $portinfo(name)
    set portpath [ditem_key $mport portpath]

    set logname [macports::getportlogpath $portpath $portname]
    file mkdir $logname
    set logname [file join $logname main.log]

    set ::debuglogname $logname

    # Append to the file if it already exists
    set ::debuglog [open $::debuglogname a]
    puts $::debuglog version:1

    ui_debug "Starting logging for $portname @$portinfo(version)_$portinfo(revision)$portinfo(canonical_active_variants)"
}

# log platform information
proc macports::_log_sysinfo {} {
    global macports::current_phase
    global macports::os_platform macports::os_subplatform \
           macports::os_version macports::os_major macports::os_minor \
           macports::os_endian macports::os_arch \
           macports::macos_version macports::macosx_sdk_version macports::macosx_deployment_target \
           macports::xcodeversion
    global tcl_platform

    set previous_phase ${macports::current_phase}
    set macports::current_phase "sysinfo"

    if {$os_platform eq "darwin"} {
        if {$os_subplatform eq "macosx"} {
            if {[vercmp $macos_version 10.12] >= 0} {
                set os_version_string "macOS ${macos_version}"
            } elseif {[vercmp $macos_version 10.8] >= 0} {
                set os_version_string "OS X ${macos_version}"
            } else {
                set os_version_string "Mac OS X ${macos_version}"
            }
        } else {
            set os_version_string "PureDarwin ${os_version}"
        }
    } else {
        # use capitalized platform name
        set os_version_string "$tcl_platform(os) ${os_version}"
    }

    ui_debug "$os_version_string ($os_platform/$os_version) arch $os_arch"
    ui_debug "MacPorts [macports::version]"
    if {$os_platform eq "darwin" && $os_subplatform eq "macosx"} {
        ui_debug "Xcode ${xcodeversion}"
        ui_debug "SDK ${macosx_sdk_version}"
        ui_debug "MACOSX_DEPLOYMENT_TARGET: ${macosx_deployment_target}"
    }

    set macports::current_phase $previous_phase
}

proc macports::push_log {mport} {
    if {![info exists ::logenabled]} {
        if {[macports::init_logging $mport] == 0} {
            set ::logenabled yes
            set ::logstack [list [list $::debuglog $::debuglogname]]
            return
        } else {
            set ::logenabled no
        }
    }
    if {$::logenabled} {
        if {[macports::init_logging $mport] == 0} {
            lappend ::logstack [list $::debuglog $::debuglogname]
        }
    }
}

proc macports::pop_log {} {
    if {![info exists ::logenabled]} {
        return -code error "pop_log called before push_log"
    }
    if {$::logenabled && [llength $::logstack] > 0} {
        close $::debuglog
        set ::logstack [lreplace $::logstack end end]
        if {[llength $::logstack] > 0} {
            set top [lindex $::logstack end]
            set ::debuglog [lindex $top 0]
            set ::debuglogname [lindex $top 1]
        } else {
            unset ::debuglog
            unset ::debuglogname
        }
    }
}

proc set_phase {phase} {
    global macports::current_phase
    set macports::current_phase $phase
    if {$phase ne "main"} {
        set cur_time [clock format [clock seconds] -format  {%+}]
        ui_debug "$phase phase started at $cur_time"
    }
}

proc ui_message {priority prefix args} {
    global macports::channels macports::current_phase

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

    foreach chan $macports::channels($priority) {
        if {[lindex $args 0] eq "-nonewline"} {
            puts -nonewline $chan $prefix[lindex $args 1]
        } else {
            puts $chan $prefix[lindex $args 0]
        }
    }

    if {[info exists ::debuglog]} {
        set chan $::debuglog
        if {[info exists macports::current_phase]} {
            set phase $macports::current_phase
        }
        set strprefix ":${priority}:$phase "
        if {[lindex $args 0] eq "-nonewline"} {
            puts -nonewline $chan $strprefix[lindex $args 1]
        } else {
            foreach str [split [lindex $args 0] "\n"] {
                puts $chan $strprefix$str
            }
        }
    }
}

proc macports::ui_init {priority args} {
    global macports::channels
    set default_channel [macports::ui_channels_default $priority]
    # Get the list of channels.
    if {[llength [info commands ui_channels]] > 0} {
        set channels($priority) [ui_channels $priority]
    } else {
        set channels($priority) $default_channel
    }

    # Simplify ui_$priority.
    try {
        set prefix [ui_prefix $priority]
    } catch * {
        set prefix [ui_prefix_default $priority]
    }
    try {
        ::ui_init $priority $prefix $channels($priority) {*}$args
    } catch * {
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
    variable macports::warning_done
    if {![info exists macports::warning_done($id)]} {
        ui_warn $msg
        set macports::warning_done($id) 1
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
        try -pass_signal {
            return [macports::binaryInPath $prog]
        } catch {{*} eCode eMessage} {
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
    global macports::$name
    return [set $name]
}

# deferred and on-need extraction of xcodeversion and xcodebuildcmd.
proc macports::setxcodeinfo {name1 name2 op} {
    global macports::xcodeversion macports::xcodebuildcmd

    trace remove variable macports::xcodeversion read macports::setxcodeinfo
    trace remove variable macports::xcodebuildcmd read macports::setxcodeinfo

    try -pass_signal {
        set xcodebuild [findBinary xcodebuild $macports::autoconf::xcodebuild_path]
        if {![info exists xcodeversion]} {
            # Determine xcode version
            set macports::xcodeversion 2.0orlower
            try -pass_signal {
                set xcodebuildversion [exec -- $xcodebuild -version 2> /dev/null]
                if {[regexp {Xcode ([0-9.]+)} $xcodebuildversion - xcode_v] == 1} {
                    set macports::xcodeversion $xcode_v
                } elseif {[regexp {DevToolsCore-(.*);} $xcodebuildversion - devtoolscore_v] == 1} {
                    if {$devtoolscore_v >= 1809.0} {
                        set macports::xcodeversion 3.2.6
                    } elseif {$devtoolscore_v >= 1763.0} {
                        set macports::xcodeversion 3.2.5
                    } elseif {$devtoolscore_v >= 1705.0} {
                        set macports::xcodeversion 3.2.4
                    } elseif {$devtoolscore_v >= 1691.0} {
                        set macports::xcodeversion 3.2.3
                    } elseif {$devtoolscore_v >= 1648.0} {
                        set macports::xcodeversion 3.2.2
                    } elseif {$devtoolscore_v >= 1614.0} {
                        set macports::xcodeversion 3.2.1
                    } elseif {$devtoolscore_v >= 1608.0} {
                        set macports::xcodeversion 3.2
                    } elseif {$devtoolscore_v >= 1204.0} {
                        set macports::xcodeversion 3.1.4
                    } elseif {$devtoolscore_v >= 1192.0} {
                        set macports::xcodeversion 3.1.3
                    } elseif {$devtoolscore_v >= 1148.0} {
                        set macports::xcodeversion 3.1.2
                    } elseif {$devtoolscore_v >= 1114.0} {
                        set macports::xcodeversion 3.1.1
                    } elseif {$devtoolscore_v >= 1100.0} {
                        set macports::xcodeversion 3.1
                    } elseif {$devtoolscore_v >= 921.0} {
                        set macports::xcodeversion 3.0
                    } elseif {$devtoolscore_v >= 798.0} {
                        set macports::xcodeversion 2.5
                    } elseif {$devtoolscore_v >= 762.0} {
                        set macports::xcodeversion 2.4.1
                    } elseif {$devtoolscore_v >= 757.0} {
                        set macports::xcodeversion 2.4
                    } elseif {$devtoolscore_v >= 747.0} {
                        set macports::xcodeversion 2.3
                    } elseif {$devtoolscore_v >= 650.0} {
                        set macports::xcodeversion 2.2.1
                    } elseif {$devtoolscore_v > 620.0} {
                        # XXX find actual version corresponding to 2.2
                        set macports::xcodeversion 2.2
                    } elseif {$devtoolscore_v >= 620.0} {
                        set macports::xcodeversion 2.1
                    }
                }
            } catch {*} {
                set macports::xcodeversion none
            }
        }
        if {![info exists xcodebuildcmd]} {
            set macports::xcodebuildcmd $xcodebuild
        }
    } catch {*} {
        if {![info exists xcodeversion]} {
            set macports::xcodeversion none
        }
        if {![info exists xcodebuildcmd]} {
            set macports::xcodebuildcmd none
        }
    }
}

# deferred calculation of developer_dir
proc macports::set_developer_dir {name1 name2 op} {
    global macports::developer_dir macports::os_major macports::xcodeversion

    trace remove variable macports::developer_dir read macports::set_developer_dir

    # Look for xcodeselect, and make sure it has a valid value
    try -pass_signal {
        set xcodeselect [findBinary xcode-select $macports::autoconf::xcode_select_path]

        # We have xcode-select: ask it where xcode is and check if it's valid.
        # If no xcode is selected, xcode-select will fail, so catch that
        try -pass_signal {
            set devdir [exec $xcodeselect -print-path 2> /dev/null]
            if {[_is_valid_developer_dir $devdir]} {
                set macports::developer_dir $devdir
                return
            }
        } catch {*} {}

        # The directory from xcode-select isn't correct.

        # Ask mdfind where Xcode is and make some suggestions for the user,
        # searching by bundle identifier for various Xcode versions (3.x and 4.x)
        set installed_xcodes {}

        try -pass_signal {
            set mdfind [findBinary mdfind $macports::autoconf::mdfind_path]
            set installed_xcodes [exec $mdfind "kMDItemCFBundleIdentifier == 'com.apple.Xcode' || kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"]
        } catch {*} {}

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
        try -pass_signal {
            if {[llength $installed_xcodes] == 0} {
                error "No Xcode installation was found."
            }

            set mdls [findBinary mdls $macports::autoconf::mdls_path]

            # One, or more than one, Xcode installations found
            ui_error "No valid Xcode installation is properly selected."
            ui_error "Please use xcode-select to select an Xcode installation:"
            foreach xcode $installed_xcodes {
                set vers [exec $mdls -raw -name kMDItemVersion $xcode]
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
        } catch {*} {
            ui_error "No Xcode installation was found."
            ui_error "Please install Xcode and/or run xcode-select to specify its location."
        }
        ui_error
    } catch {*} {}

    # Try the default
    if {$os_major >= 11 && [vercmp $xcodeversion 4.3] >= 0} {
        set devdir /Applications/Xcode.app/Contents/Developer
    } else {
        set devdir /Developer
    }

    set macports::developer_dir $devdir
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


proc mportinit {{up_ui_options {}} {up_options {}} {up_variations {}}} {
    # Disable unknown(n)'s behavior of running unknown commands in the system
    # shell
    set ::auto_noexec yes

    if {$up_ui_options eq {}} {
        array set macports::ui_options {}
    } else {
        upvar $up_ui_options temp_ui_options
        array set macports::ui_options [array get temp_ui_options]
    }
    if {$up_options eq {}} {
        array set macports::global_options {}
    } else {
        upvar $up_options temp_options
        array set macports::global_options [array get temp_options]
    }
    if {$up_variations eq {}} {
        array set variations {}
    } else {
        upvar $up_variations variations
    }

    # Initialize ui_*
    foreach priority $macports::ui_priorities {
        macports::ui_init $priority
    }

    package require Pextlib 1.0
    package require registry 1.0
    package require registry2 2.0
    package require machista 1.0

    global auto_path env tcl_platform \
        macports::autoconf::macports_conf_path \
        macports::macports_user_dir \
        macports::bootstrap_options \
        macports::user_options \
        macports::portconf \
        macports::portsharepath \
        macports::registry.format \
        macports::registry.path \
        macports::sources \
        macports::sources_default \
        macports::destroot_umask \
        macports::prefix \
        macports::macportsuser \
        macports::prefix_frozen \
        macports::applications_dir_frozen \
        macports::frameworks_dir_frozen \
        macports::xcodebuildcmd \
        macports::xcodeversion \
        macports::configureccache \
        macports::ccache_dir \
        macports::ccache_size \
        macports::configuredistcc \
        macports::configurepipe \
        macports::buildnicevalue \
        macports::buildmakejobs \
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
        macports::ping_cache \
        macports::host_cache \
        macports::delete_la_files \
        macports::cxx_stdlib \
        macports::hfscompression

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
    if {$os_arch eq "Power Macintosh"} {
        set os_arch "powerpc"
    } elseif {$os_arch eq "i586" || $os_arch eq "i686" || $os_arch eq "x86_64"} {
        set os_arch "i386"
    } elseif {$os_arch eq "arm64"} {
        set os_arch "arm"
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
            if {[file executable /usr/bin/sw_vers]} {
                try -pass_signal {
                    set macos_version [exec /usr/bin/sw_vers -productVersion]
                } catch {* ec result} {
                    ui_debug "sw_vers exists but running it failed: $result"
                }
            }
        } else {
            # PureDarwin
            set os_subplatform puredarwin
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

    # Check that the current platform is the one we were configured for, otherwise need to do migration
    if {($os_platform ne $macports::autoconf::os_platform) || ($os_platform eq "darwin" && $os_major != $macports::autoconf::os_major)} {
        ui_error "Current platform \"$os_platform $os_major\" does not match expected platform \"$macports::autoconf::os_platform $macports::autoconf::os_major\""
        ui_error "If you upgraded your OS, please follow the migration instructions: https://trac.macports.org/wiki/Migration"
        return -code error "OS platform mismatch"
    }

    # Ensure that the macports user directory (i.e. ~/.macports) exists if HOME is defined.
    # Also save $HOME for later use before replacing it with our own.
    if {[info exists env(HOME)]} {
        set macports::user_home $env(HOME)
        set macports::macports_user_dir [file normalize $macports::autoconf::macports_user_dir]
    } elseif {[info exists env(SUDO_USER)] && $os_platform eq "darwin"} {
        set macports::user_home [exec dscl -q . -read /Users/$env(SUDO_USER) NFSHomeDirectory | cut -d ' ' -f 2]
        set macports::macports_user_dir [file join $macports::user_home [string range $macports::autoconf::macports_user_dir 2 end]]
    } elseif {[exec id -u] != 0 && $os_platform eq "darwin"} {
        set macports::user_home [exec dscl -q . -read /Users/[exec id -un] NFSHomeDirectory | cut -d ' ' -f 2]
        set macports::macports_user_dir [file join $macports::user_home [string range $macports::autoconf::macports_user_dir 2 end]]
    } else {
        # Otherwise define the user directory as a directory that will never exist
        set macports::macports_user_dir /dev/null/NO_HOME_DIR
        set macports::user_home /dev/null/NO_HOME_DIR
    }

    # Save the path for future processing
    set macports::user_path $env(PATH)
    # Likewise any SUDO_USER
    if {[info exists env(SUDO_USER)]} {
        set macports::sudo_user $env(SUDO_USER)
    }

    # Save SSH_AUTH_SOCK for ports tree sync
    if {[info exists env(SSH_AUTH_SOCK)]} {
        set macports::user_ssh_auth_sock $env(SSH_AUTH_SOCK)
    }

    # Configure the search path for configuration files
    set conf_files {}
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
            set portconf $file
            set fd [open $file r]
            while {[gets $fd line] >= 0} {
                if {[regexp $conf_option_re $line match option ignore val] == 1} {
                    if {$option in $bootstrap_options} {
                        set macports::$option [string trim $val]
                        global macports::$option
                    }
                }
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
                    set macports::$option $val
                    global macports::$option
                }
            }
        }
        close $fd
    }

    if {![info exists sources_conf]} {
        return -code error "sources_conf must be set in ${macports_conf_path}/macports.conf or in your ${macports_user_dir}/macports.conf file"
    }
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
Please edit sources.conf and change '$url' to '[string range $url 0 end-6]tarballs/ports.tar'."
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
    global macports::global_variations
    array set macports::global_variations [array get variations]

    # pubkeys.conf
    set macports::archivefetch_pubkeys {}
    if {[file isfile [file join $macports_conf_path pubkeys.conf]]} {
        set fd [open [file join $macports_conf_path pubkeys.conf] r]
        while {[gets $fd line] >= 0} {
            set line [string trim $line]
            if {![regexp $variants_conf_comment_re $line]} {
                lappend macports::archivefetch_pubkeys $line
            }
        }
        close $fd
    } else {
        ui_debug "pubkeys.conf does not exist."
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
        set macports::portautoclean yes
        global macports::portautoclean
    }
    # whether to keep logs after successful builds
    if {![info exists keeplogs]} {
        set macports::keeplogs no
        global macports::keeplogs
    }

    # Check command line override for autoclean
    if {[info exists macports::global_options(ports_autoclean)]} {
        if {$macports::global_options(ports_autoclean) ne $portautoclean} {
            set macports::portautoclean $macports::global_options(ports_autoclean)
        }
    }
    # Trace mode, whether to use darwintrace to debug ports.
    if {![info exists porttrace]} {
        set macports::porttrace no
        global macports::porttrace
    }
    # Check command line override for trace
    if {[info exists macports::global_options(ports_trace)]} {
        if {$macports::global_options(ports_trace) ne $porttrace} {
            set macports::porttrace $macports::global_options(ports_trace)
        }
    }
    # Check command line override for source/binary only mode
    if {![info exists macports::global_options(ports_binary_only)]
        && ![info exists macports::global_options(ports_source_only)]
        && [info exists macports::buildfromsource]} {
        if {$macports::buildfromsource eq "never"} {
            set macports::global_options(ports_binary_only) yes
            set temp_options(ports_binary_only) yes
        } elseif {$macports::buildfromsource eq "always"} {
            set macports::global_options(ports_source_only) yes
            set temp_options(ports_source_only) yes
        } elseif {$macports::buildfromsource ne "ifneeded"} {
            ui_warn "'buildfromsource' set to unknown value '$macports::buildfromsource', using 'ifneeded' instead"
        }
    }

    # Duplicate prefix into prefix_frozen, so that port actions
    # can always get to the original prefix, even if a portfile overrides prefix
    set macports::prefix_frozen $prefix

    if {![info exists macports::applications_dir]} {
        set macports::applications_dir /Applications/MacPorts
    }
    set macports::applications_dir_frozen ${macports::applications_dir}

    if {[info exists macports::frameworks_dir]} {
        set macports::frameworks_dir_frozen ${macports::frameworks_dir}
    } else {
        set macports::frameworks_dir_frozen ${macports::prefix_frozen}/Library/Frameworks
    }

    # Export verbosity.
    if {![info exists portverbose]} {
        set macports::portverbose no
        global macports::portverbose
    }
    if {[info exists macports::ui_options(ports_verbose)]} {
        if {$macports::ui_options(ports_verbose) ne $portverbose} {
            set macports::portverbose $macports::ui_options(ports_verbose)
        }
    }

    # Set noninteractive mode if specified in config
    if {[info exists ui_interactive] && !$ui_interactive} {
        set macports::ui_options(ports_noninteractive) yes
        unset -nocomplain macports::ui_options(questions_yesno) \
                            macports::ui_options(questions_singlechoice) \
                            macports::ui_options(questions_multichoice) \
                            macports::ui_options(questions_alternative)

    }

    # Archive type, what type of binary archive to use (CPIO, gzipped
    # CPIO, XAR, etc.)
    global macports::portarchivetype
    if {![info exists portarchivetype]} {
        set macports::portarchivetype tbz2
    } else {
        set macports::portarchivetype [lindex $portarchivetype 0]
    }

    # Enable HFS+ compression by default
    if {![info exists macports::hfscompression]} {
        set macports::hfscompression yes
    }

    # Set rync options
    if {![info exists rsync_server]} {
        global macports::rsync_server
        set macports::rsync_server rsync.macports.org
    }
    if {![info exists rsync_dir]} {
        global macports::rsync_dir
        set macports::rsync_dir macports/release/tarballs/base.tar
    } elseif {[string range $rsync_dir end-3 end] ne ".tar" && [string match *.macports.org ${macports::rsync_server}]} {
        ui_warn "MacPorts is configured to use an unsigned source for selfupdate.\
Please edit macports.conf and change the rsync_dir setting to\
match macports.conf.default."
    }
    if {![info exists rsync_options]} {
        global macports::rsync_options
        set rsync_options "-rtzvl --delete-after"
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
    if {![info exists macports::startupitem_type]} {
        set macports::startupitem_type default
    }

    # Set whether startupitems are symlinked into system directories
    if {![info exists macports::startupitem_install]} {
        set macports::startupitem_install yes
    }

    # Set whether ports are allowed to auto-load their startupitems
    if {![info exists macports::startupitem_autostart]} {
        set macports::startupitem_autostart yes
    }

    # Default place_worksymlink
    if {![info exists macports::place_worksymlink]} {
        set macports::place_worksymlink yes
    }

    # Default mp configure options
    if {![info exists macports::configureccache]} {
        set macports::configureccache no
    }
    if {![info exists macports::ccache_dir]} {
        set macports::ccache_dir [file join $portdbpath build .ccache]
    }
    if {![info exists macports::ccache_size]} {
        set macports::ccache_size 2G
    }
    if {![info exists macports::configuredistcc]} {
        set macports::configuredistcc no
    }
    if {![info exists macports::configurepipe]} {
        set macports::configurepipe yes
    }

    # Default mp build options
    if {![info exists macports::buildnicevalue]} {
        set macports::buildnicevalue 0
    }
    if {![info exists macports::buildmakejobs]} {
        set macports::buildmakejobs 0
    }

    # default user to run as when privileges can be dropped
    if {![info exists macports::macportsuser]} {
        set macports::macportsuser $macports::autoconf::macportsuser
    }

    # Default mp universal options
    if {![info exists macports::universal_archs]} {
        if {$os_major >= 20} {
            set macports::universal_archs {arm64 x86_64}
        } elseif {$os_major >= 19} {
            set macports::universal_archs {x86_64}
        } elseif {$os_major >= 10} {
            set macports::universal_archs {x86_64 i386}
        } else {
            set macports::universal_archs {i386 ppc}
        }
    } elseif {[llength $macports::universal_archs] == 1} {
        # allow empty value to disable universal
        if {$os_major < 18 || $os_major > 19} {
            ui_warn "invalid universal_archs configured (should contain at least 2 archs)"
        }
    }

    # Default arch to build for
    if {![info exists macports::build_arch]} {
        if {$os_platform eq "darwin"} {
            if {$os_major >= 20} {
                if {$os_arch eq "arm"} {
                    set macports::build_arch arm64
                } else {
                    set macports::build_arch x86_64
                }
            } elseif {$os_major >= 10} {
                if {[sysctl hw.cpu64bit_capable] == 1} {
                    set macports::build_arch x86_64
                } else {
                    set macports::build_arch i386
                }
            } else {
                if {$os_arch eq "powerpc"} {
                    set macports::build_arch ppc
                } else {
                    set macports::build_arch i386
                }
            }
        } else {
            set macports::build_arch {}
        }
    } else {
        set macports::build_arch [lindex $macports::build_arch 0]
    }

    if {![info exists macports::macosx_deployment_target]} {
        if {[vercmp $macos_version 11] >= 0} {
            set macports::macosx_deployment_target ${macos_version_major}.0
        } else {
            set macports::macosx_deployment_target $macos_version_major
        }
    }
    if {![info exists macports::macosx_sdk_version]} {
        set macports::macosx_sdk_version $macos_version_major
    }

    if {![info exists macports::revupgrade_autorun]} {
        if {$os_platform eq "darwin"} {
            set macports::revupgrade_autorun yes
        } else {
            set macports::revupgrade_autorun no
        }
    }
    if {![info exists macports::revupgrade_mode]} {
        set macports::revupgrade_mode rebuild
    }
    if {![info exists macports::delete_la_files]} {
        if {$os_platform eq "darwin" && $os_major >= 13} {
            set macports::delete_la_files yes
        } else {
            set macports::delete_la_files no
        }
    }
    if {![info exists macports::cxx_stdlib]} {
        if {$os_platform eq "darwin" && $os_major >= 10} {
            set macports::cxx_stdlib libc++
        } elseif {$os_platform eq "darwin"} {
            set macports::cxx_stdlib libstdc++
        } else {
            set macports::cxx_stdlib {}
        }
    }
    if {![info exists macports::global_options(ports_rev-upgrade_id-loadcmd-check)]
         && [info exists macports::revupgrade_check_id_loadcmds]} {
        set macports::global_options(ports_rev-upgrade_id-loadcmd-check) $macports::revupgrade_check_id_loadcmds
        set temp_options(ports_rev-upgrade_id-loadcmd-check) $macports::revupgrade_check_id_loadcmds
    }

    if {![info exists macports::sandbox_enable]} {
        set macports::sandbox_enable yes
    }

    if {![info exists macports::sandbox_network]} {
        set macports::sandbox_network no
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
        try -pass_signal {
            file attributes $portdbpath -hidden yes
        } catch {{*} eCode eMessage} {
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

    set env_names [array names env]
    foreach envkey $env_names {
        if {$envkey ni $keepenvkeys} {
            unset env($envkey)
        }
    }

    if {![info exists xcodeversion] || ![info exists xcodebuildcmd]} {
        # We'll resolve these later (if needed)
        trace add variable macports::xcodeversion read macports::setxcodeinfo
        trace add variable macports::xcodebuildcmd read macports::setxcodeinfo
    }

    if {![info exists developer_dir]} {
        if {$os_platform eq "darwin"} {
            trace add variable macports::developer_dir read macports::set_developer_dir
        } else {
            set macports::developer_dir {}
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
    set env(CCACHE_DIR) $macports::ccache_dir

    # load cached ping times
    try -pass_signal {
        set pingfile -1
        set pingfile [open ${macports::portdbpath}/pingtimes r]
        array set macports::ping_cache [gets $pingfile]
    } catch {*} {
        array set macports::ping_cache {}
    } finally {
        if {$pingfile != -1} {
            close $pingfile
        }
    }
    if {![info exists macports::host_blacklist]} {
        set macports::host_blacklist {}
    }
    if {![info exists macports::preferred_hosts]} {
        set macports::preferred_hosts {}
    }
    array set macports::host_cache {}

    # load the quick index
    _mports_load_quickindex

    if {![info exists macports::ui_options(ports_no_old_index_warning)]} {
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
    # for the benefit of the portimage code that is called from multiple interpreters
    global registry_open
    set registry_open yes
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
    # save ping times
    global macports::ping_cache macports::portdbpath
    if {[file writable $macports::portdbpath]} {
        catch {
            foreach host [array names ping_cache] {
                # don't save expired entries
                if {[clock seconds] - [lindex $ping_cache($host) 1] < 86400} {
                    lappend pinglist_fresh $host $ping_cache($host)
                }
            }
            set pingfile [open ${macports::portdbpath}/pingtimes w]
            puts $pingfile $pinglist_fresh
            close $pingfile
        }
    }

    # close it down so the cleanup stuff is called, e.g. vacuuming the db
    registry::close
}

# link plist for xcode 4.3's benefit
proc macports::copy_xcode_plist {target_homedir} {
    global macports::user_home macports::macportsuser
    set user_plist "${user_home}/Library/Preferences/com.apple.dt.Xcode.plist"
    set target_dir "${target_homedir}/Library/Preferences"
    file delete -force "${target_dir}/com.apple.dt.Xcode.plist"
    if {[file isfile $user_plist]} {
        if {![file isdirectory $target_dir]} {
            try -pass_signal {
                file mkdir $target_dir
            } catch {{*} eCode eMessage} {
                ui_warn "Failed to create Library/Preferences in ${target_homedir}: $eMessage"
                return
            }
        }
        try -pass_signal {
            if {![file writable $target_dir]} {
                error "${target_dir} is not writable"
            }
            ui_debug "Copying $user_plist to $target_dir"
            file copy -force $user_plist $target_dir
            file attributes ${target_dir}/com.apple.dt.Xcode.plist -owner $macportsuser -permissions 0644
        } catch {{*} eCode eMessage} {
            ui_warn "Failed to copy com.apple.dt.Xcode.plist to ${target_dir}: $eMessage"
        }
    }
}

proc macports::worker_init {workername portpath porturl portbuildpath options variations} {
    global macports::portinterp_options macports::portinterp_deferred_options

    # Hide any Tcl commands that should be inaccessible to port1.0 and Portfiles
    # exit: It should not be possible to exit the interpreter
    interp hide $workername exit

    # cd: This is necessary for some code in port1.0, but should be hidden
    interp eval $workername {rename cd _cd}

    # Tell the sub interpreter about all the Tcl packages we already
    # know about so it won't glob for packages.
    foreach pkgName [package names] {
        foreach pkgVers [package versions $pkgName] {
            set pkgLoadScript [package ifneeded $pkgName $pkgVers]
            $workername eval "package ifneeded $pkgName $pkgVers {$pkgLoadScript}"
        }
    }

    # Create package require abstraction procedure
    $workername eval {proc PortSystem {version} {
            package require port $version
        }}

    # Clearly separate slave interpreters and the master interpreter.
    $workername alias mport_exec mportexec
    $workername alias mport_open mportopen
    $workername alias mport_close mportclose
    $workername alias mport_lookup mportlookup
    $workername alias mport_info mportinfo
    $workername alias set_phase set_phase

    # instantiate the UI call-backs
    foreach priority $macports::ui_priorities {
        $workername alias ui_$priority ui_$priority
    }
    # add the UI progress call-backs (or a no-op alias, if unavailable)
    foreach pname {progress_download progress_generic} {
        if {[info exists macports::ui_options($pname)]} {
            $workername alias ui_$pname $macports::ui_options($pname)
        } else {
            $workername alias ui_$pname return -level 0
        }
    }

    # notifications callback
    if {[info exists macports::ui_options(notifications_append)]} {
        $workername alias ui_notifications_append $macports::ui_options(notifications_append)
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

    # compiler version cache
    $workername alias get_compiler_version macports::get_compiler_version
    # tool path cache
    $workername alias get_tool_path macports::get_tool_path

    foreach opt $portinterp_options {
        if {![info exists $opt]} {
            global macports::$opt
        }
        if {[info exists $opt]} {
            $workername eval [list set system_options($opt) [set $opt]]
            $workername eval [list set $opt [set $opt]]
        }
    }

    foreach opt $portinterp_deferred_options {
        global macports::$opt
        # define the trace hook.
        $workername eval \
            "proc trace_$opt {name1 name2 op} { \n\
                trace remove variable ::$opt read ::trace_$opt \n\
                global $opt \n\
                set $opt \[getoption $opt\] \n\
            }"
        # next access will actually define the variable.
        $workername eval "trace add variable ::$opt read ::trace_$opt"
        # define some value now
        $workername eval "set $opt ?"
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

    global macports::portinterp_options

    # Create the thread.
    set result [thread::create -preserved {thread::wait}]

    # Tell the thread about all the Tcl packages we already
    # know about so it won't glob for packages.
    foreach pkgName [package names] {
        foreach pkgVers [package versions $pkgName] {
            set pkgLoadScript [package ifneeded $pkgName $pkgVers]
            thread::send -async $result "package ifneeded $pkgName $pkgVers {$pkgLoadScript}"
        }
    }

    # inherit configuration variables.
    thread::send -async $result "namespace eval macports {}"
    foreach opt $portinterp_options {
        if {![info exists $opt]} {
            global macports::$opt
        }
        if {[info exists $opt]} {
            thread::send -async $result "global macports::$opt"
            set val [set macports::$opt]
            thread::send -async $result "set macports::$opt \"$val\""
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
    global macports::portdbpath macports::ui_prefix macports::portverbose macports::ui_options

    set fetchdir [file join $portdbpath portdirs]
    file mkdir $fetchdir
    if {![file writable $fetchdir]} {
        return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }

    if {$local} {
        set filepath $url
    } else {
        ui_msg "$macports::ui_prefix Fetching port $url"
        set fetchfile [file tail $url]
        set progressflag {}
        if {$macports::portverbose} {
            set progressflag "--progress builtin"
        } elseif {[info exists macports::ui_options(progress_download)]} {
            set progressflag "--progress ${macports::ui_options(progress_download)}"
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

set macports::getprotocol_re {(?x)([^:]+)://.+}
proc macports::getprotocol {url} {
    if {[regexp $::macports::getprotocol_re $url match protocol] == 1} {
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
    global macports::extracted_portdirs

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
                if {![info exists macports::extracted_portdirs($url)]} {
                    set macports::extracted_portdirs($url) [macports::fetch_port $path 1]
                }
                return $macports::extracted_portdirs($url)
            }
        }
        https -
        http -
        ftp {
            # the URL points to a remote tarball that (hopefully) contains a Portfile
            # create a local dir for the extracted port, but only once
            if {![info exists macports::extracted_portdirs($url)]} {
                set macports::extracted_portdirs($url) [macports::fetch_port $url 0]
            }
            return $macports::extracted_portdirs($url)
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
    global macports::sources_default

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


set macports::file_porturl_re {^file://(.*)}

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
    global macports::portdbpath macports::portconf macports::open_mports auto_path

    # normalize porturl for local files
    if {[regexp $::macports::file_porturl_re $porturl -> path]} {
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
        set mport [dlist_match_multi $macports::open_mports [list porturl $porturl variations $variations options $options]]
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
    ui_debug "Changing to port directory: $portpath"
    cd $portpath
    if {![file isfile Portfile]} {
        return -code error "Could not find Portfile in $portpath"
    }

    set workername [interp create]

    set mport [ditem_create]
    lappend macports::open_mports $mport
    ditem_key $mport porturl $porturl
    ditem_key $mport portpath $portpath
    ditem_key $mport workername $workername
    ditem_key $mport options $options
    ditem_key $mport variations $variations
    ditem_key $mport refcnt 1

    macports::worker_init $workername $portpath $porturl [macports::getportbuildpath $portpath] $options $variations

    if {[catch {$workername eval {source Portfile}} result]} {
        mportclose $mport
        ui_debug $::errorInfo
        error $result
    }

    # add the default universal variant if appropriate, and set up flags that
    # are conditional on whether universal is set
    $workername eval {universal_setup}

    # evaluate the variants
    if {[$workername eval {eval_variants variations}] != 0} {
        mportclose $mport
        error "Error evaluating variants"
    }

    $workername eval {port::run_callbacks}

    set actual_subport [$workername eval {set PortInfo(name)}]
    if {[$workername eval {info exists user_options(subport)}]} {
        # The supplied subport may have been set on the command line by the
        # user, or simply obtained from the PortIndex or registry. Check that
        # it's valid in case the user made a mistake.
        set supplied_subport [$workername eval {set user_options(subport)}]
        if {$supplied_subport ne $actual_subport} {
            set portname [$workername eval {set name}]
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

    set variations {}
    # Relies on all negated variants being at the end of requested_variants
    set minusvariant [lrange [split [$regref requested_variants] -] 1 end]
    set plusvariant [lrange [split [$regref variants] +] 1 end]
    foreach v $plusvariant {
        lappend variations $v +
    }
    foreach v $minusvariant {
        if {[string first "+" $v] == -1} {
            lappend variations $v -
        } else {
            ui_warn "Invalid negated variant for $name @${version}_${revision}${variants}: $v"
        }
    }

    array set options_array $options
    set options_array(subport) $name

    # find portgroups in registry
    set pgdirlist [list]
    foreach pg [$regref groups_used] {
        lappend pgdirlist [file join ${registry.path} registry portgroups [$pg sha256]-[$pg size]]
    }
    if {$pgdirlist ne ""} {
        set options_array(_portgroup_search_dirs) $pgdirlist
    }

    set retmport [mportopen file://${portfile_dir}/ [array get options_array] $variations]
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

# depregex -> regex on the filename to find.
# search_path -> directories to search
# executable -> whether we want to check that the file is executable by current
#               user or not.
proc _mportsearchpath {depregex search_path {executable 0} {return_match 0}} {
    set found 0
    foreach path $search_path {
        if {![file isdirectory $path]} {
            continue
        }

        if {[catch {set filelist [readdir $path]} result]} {
            return -code error "$result ($path)"
        }

        foreach filename $filelist {
            if {[regexp $depregex $filename] &&
              (($executable == 0) || [file executable [file join $path $filename]])} {
                ui_debug "Found Dependency: path: $path filename: $filename regex: $depregex"
                set found 1
                break
            }
        }

        if {$found} {
            break
        }
    }
    if {$return_match} {
        if {$found} {
            return [file join $path $filename]
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
    set workername [ditem_key $mport workername]
    return [$workername eval {registry_exists_for_name $subport}]
}

# Determine if a port is active
proc _mportactive {mport} {
    set portname [ditem_key $mport provides]
    set reslist [registry::entry installed $portname]
    if {$reslist ne {}} {
        set i [lindex $reslist 0]
        array set portinfo [mportinfo $mport]
        if {[$i version] eq $portinfo(version) && [$i revision] == $portinfo(revision)
             && [$i variants] eq $portinfo(canonical_active_variants)} {
            return 1
        }
    }
    return 0
}

# Determine if the named port is active
proc _portnameactive {portname} {
    return [expr {[registry::entry installed $portname] ne {}}]
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
        # The receipt test failed, use one of the depspec regex mechanisms
        ui_debug "Didn't find receipt, going to depspec regex for: $portname"
        set workername [ditem_key $mport workername]
        set type [lindex [split $depspec :] 0]
        switch -- $type {
            lib {return [$workername eval "_libtest $depspec"]}
            bin {return [$workername eval "_bintest $depspec"]}
            path {return [$workername eval "_pathtest $depspec"]}
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
    set conflictlist {}
    array set portinfo [mportinfo $mport]

    if {[info exists portinfo(conflicts)] &&
        [llength $portinfo(conflicts)] > 0} {
        ui_debug "Checking for conflicts against [_mportkey $mport subport]"
        foreach conflictport $portinfo(conflicts) {
            if {[_mportispresent $mport port:$conflictport]} {
                lappend conflictlist $conflictport
            }
        }
    } else {
        ui_debug "[_mportkey $mport subport] has no conflicts"
    }

    if {[llength $conflictlist] != 0} {
        if {[macports::global_option_isset ports_force]} {
            ui_warn "Force option set; installing $portinfo(name) despite conflicts with: $conflictlist"
        } else {
            if {![macports::ui_isset ports_debug]} {
                ui_msg {}
            }
            ui_error "Can't install $portinfo(name) because conflicting ports are active: $conflictlist"
            return -code error "conflicting ports"
        }
    }
}

### _mportexec is private; may change without notice

proc _mportexec {target mport} {
    set portname [_mportkey $mport subport]
    macports::push_log $mport
    # xxx: set the work path?
    set workername [ditem_key $mport workername]
    $workername eval {validate_macportsuser}

    # If the target doesn't need a toolchain (e.g. because an archive is
    # available and we're not going to build it), don't check for the Xcode
    # version (and presence for use_xcode yes ports).
    if {![catch {$workername eval "check_variants $target"} result] && $result == 0 &&
        (![macports::_target_needs_toolchain $workername $target] || (![catch {$workername eval {_check_xcode_version}} result] && $result == 0)) &&
        ![catch {$workername eval {check_supported_archs}} result] && $result == 0 &&
        ![catch {$workername eval "eval_targets $target"} result] && $result == 0} {
        # If auto-clean mode, clean-up after dependency install
        if {$macports::portautoclean} {
            # Make sure we are back in the port path before clean.
            # Otherwise, if the current directory had been changed to
            # inside the port, the next port may fail when trying to
            # install because [pwd] will return a "no file or directory"
            # error since the directory it was in is now gone.
            set portpath [ditem_key $mport portpath]
            catch {cd $portpath}
            $workername eval {eval_targets clean}
        }
        # XXX hack to avoid running out of fds due to sqlite temp files, ticket #24857
        interp delete $workername
        macports::pop_log
        return 0
    } else {
        if {[info exists ::logenabled] && $::logenabled && [info exists ::debuglogname]} {
            ui_error "See $::debuglogname for details."
        }
        macports::pop_log
        return 1
    }
}

# mportexec
# Execute the specified target of the given mport.
proc mportexec {mport target} {
    set workername [ditem_key $mport workername]

    # check for existence of macportsuser and use fallback if necessary
    $workername eval {validate_macportsuser}
    # check variants
    if {[$workername eval "check_variants $target"] != 0} {
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
        if {[$workername eval {_check_xcode_version}] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
        # error out if selected arch(s) not supported by this port
        if {[$workername eval {check_supported_archs}] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
    }

    # Before we build the port, we must build its dependencies.
    set dlist {}
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

        ui_msg -nonewline "$macports::ui_prefix Computing dependencies for [_mportkey $mport subport]"
        if {[macports::ui_isset ports_debug]} {
            # play nice with debug messages
            ui_msg {}
        }
        if {[mportdepends $mport $target] != 0} {
            if {$log_needs_pop} {
                macports::pop_log
            }
            return 1
        }
        if {![macports::ui_isset ports_debug]} {
            ui_msg {}
        }

        # Select out the dependents along the critical path,
        # but exclude this mport; we might not be installing it.
        set dlist [dlist_append_dependents $macports::open_mports $mport {}]

        dlist_delete dlist $mport

        # print the dep list
        if {[llength $dlist] > 0} {
            ##
            # User Interaction Question
            # Asking before installing dependencies
            if {[info exists macports::ui_options(questions_yesno)]} {
                set deplist {}
                foreach ditem $dlist {
                    lappend deplist [ditem_key $ditem provides]
                }
                set retvalue [$macports::ui_options(questions_yesno) "The following dependencies will be installed: " "TestCase#2" [lsort $deplist] {y} 0]
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
                set depstring "$macports::ui_prefix Dependencies to be installed:"
                foreach ditem $dlist {
                    append depstring " [ditem_key $ditem provides]"
                }
                ui_msg $depstring
            }
        }

        # install them
        set result [dlist_eval $dlist _mportactive [list _mportexec activate]]

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

    set clean 0
    if {$macports::portautoclean && ($target eq "install" || $target eq "activate")} {
        # If we're doing an install, check if we should clean after
        set clean 1
    }

    # Build this port with the specified target
    set result [$workername eval "eval_targets $target"]

    # If auto-clean mode and successful install, clean-up after install
    if {$result == 0 && $clean == 1} {
        # Make sure we are back in the port path, just in case
        set portpath [ditem_key $mport portpath]
        catch {cd $portpath}
        $workername eval {eval_targets clean}
    }

    if {$result != 0 && [info exists ::logenabled] && $::logenabled && [info exists ::debuglogname]} {
        ui_error "See $::debuglogname for details."
    }

    if {$log_needs_pop} {
        macports::pop_log
    }

    return $result
}

# upgrade any dependencies of mport that are installed and needed for target
proc macports::_upgrade_mport_deps {mport target} {
    set options [ditem_key $mport options]
    set workername [ditem_key $mport workername]
    set deptypes [macports::_deptypes_for_target $target $workername]
    array set portinfo [mportinfo $mport]
    array set depscache {}

    set required_archs [$workername eval {get_canonical_archs}]
    set depends_skip_archcheck [_mportkey $mport depends_skip_archcheck]

    # Pluralize "arch" appropriately.
    set s [expr {[llength $required_archs] == 1 ? "" : "s"}]

    set test _portnameactive

    foreach deptype $deptypes {
        if {![info exists portinfo($deptype)]} {
            continue
        }
        foreach depspec $portinfo($deptype) {
            set dep_portname [$workername eval "_get_dep_port $depspec"]
            if {$dep_portname ne "" && ![info exists depscache(port:$dep_portname)] && [$test $dep_portname]} {
                set variants {}

                # check that the dep has the required archs
                set active_archs [_active_archs $dep_portname]
                if {$deptype ni {depends_fetch depends_extract} && $active_archs ni {{} noarch}
                    && $required_archs ne "noarch" && $dep_portname ni $depends_skip_archcheck} {
                    set missing {}
                    foreach arch $required_archs {
                        if {$arch ni $active_archs} {
                            lappend missing $arch
                        }
                    }
                    if {[llength $missing] > 0} {
                        set res [mportlookup $dep_portname]
                        array unset dep_portinfo
                        array set dep_portinfo [lindex $res 1]
                        if {[info exists dep_portinfo(installs_libs)] && !$dep_portinfo(installs_libs)} {
                            set missing {}
                        }
                    }
                    if {[llength $missing] > 0} {
                        if {[info exists dep_portinfo(variants)] && "universal" in $dep_portinfo(variants)} {
                            # dep offers a universal variant
                            if {[llength $active_archs] == 1} {
                                # not installed universal
                                set missing {}
                                foreach arch $required_archs {
                                    if {$arch ni $macports::universal_archs} {
                                        lappend missing $arch
                                    }
                                }
                                if {[llength $missing] > 0} {
                                    ui_error "Cannot install [_mportkey $mport subport] for the arch${s} '$required_archs' because"
                                    ui_error "its dependency $dep_portname is only installed for the arch '$active_archs'"
                                    ui_error "and the configured universal_archs '$macports::universal_archs' are not sufficient."
                                    return -code error "architecture mismatch"
                                } else {
                                    # upgrade the dep with +universal
                                    lappend variants universal +
                                    lappend options ports_upgrade_enforce-variants yes
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
    global macports::portdbpath

    set source_path [split $url ://]

    if {[_source_is_snapshot $url]} {
        # snapshot tarball
        return [file join $portdbpath sources [join [lrange $source_path 3 end-1] /] ports]
    }

    return [file join $portdbpath sources [lindex $source_path 3] [lindex $source_path 4] [lindex $source_path 5]]
}

set macports::source_is_snapshot_re {^((?:https?|ftp|rsync)://.+/)(.+\.(tar\.gz|tar\.bz2|tar))$}
##
# Checks whether a supplied source URL is for a snapshot tarball
# (private)
#
# @param url source URL to check
# @param filename upvar variable name for filename
# @param extension upvar variable name for extension
# @param extension upvar variable name for URL excluding the filename
proc _source_is_snapshot {url {filename {}} {extension {}} {rooturl {}}} {
    upvar $rooturl myrooturl
    upvar $filename myfilename
    upvar $extension myextension

    if {[regexp $::macports::source_is_snapshot_re $url -> u f e]} {
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
    global macports::portdbpath
    regsub {://} $id {.} port_path
    regsub -all {/} $port_path {_} port_path
    return [file join $portdbpath build $port_path $portname]
}

proc macports::getportlogpath {id {portname {}}} {
    global macports::portdbpath
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
proc macports::GetVCSUpdateCmd portDir {

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
# Execute the given command in a shell. If called with superuser
# privileges, execute the command as the user/group that owns the given
# directory, restoring privileges before returning.
#
# This proc could probably be generalized and used elsewhere.
#
proc macports::UpdateVCS {cmd dir} {
    global env macports::user_ssh_auth_sock
    if {[getuid] == 0} {
        # Must change egid before dropping root euid.
        set oldEGID [getegid]
        set newEGID [name_to_gid [file attributes $dir -group]]
        setegid $newEGID
        set oldEUID [geteuid]
        set newEUID [name_to_uid [file attributes $dir -owner]]
        seteuid $newEUID
        array set oldEnv [array get env]
        set env(HOME) [getpwuid $newEUID dir]
        set envdebug "HOME=$env(HOME)"
        if {[info exists macports::user_ssh_auth_sock]} {
            set env(SSH_AUTH_SOCK) $macports::user_ssh_auth_sock
            append envdebug " SSH_AUTH_SOCK=$env(SSH_AUTH_SOCK)"
        }
        ui_debug "euid/egid changed to: $newEUID/$newEGID, env: $envdebug"
    }
    ui_debug $cmd
    catch {system -W $dir $cmd} result options
    if {[getuid] == 0} {
        seteuid $oldEUID
        setegid $oldEGID
        array unset env *
        array set env [array get oldEnv]
        ui_debug "euid/egid restored to: $oldEUID/$oldEGID, env restored"
    }
    return -options $options $result
}

proc mportsync {{optionslist {}}} {
    global macports::sources macports::rsync_options \
           macports::portverbose macports::autoconf::rsync_path \
           macports::autoconf::tar_path macports::autoconf::openssl_path \
           macports::ui_options
    array set options $optionslist
    if {[info exists options(no_reindex)]} {
        upvar $options(needed_portindex_var) any_needed_portindex
    }

    set numfailed 0
    set obsoletesvn 0

    ui_msg "$macports::ui_prefix Updating the ports tree"
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
                if {[_source_is_obsolete_svn_repo $portdir]} {
                    set obsoletesvn 1
                }
                try -pass_signal {
                    set repoInfo [macports::GetVCSUpdateCmd $portdir] 
                } catch {*} {
                    ui_debug $::errorInfo
                    ui_info "Could not access contents of $portdir"
                    incr numfailed
                    continue
                }
                if {[llength $repoInfo]} {
                    lassign $repoInfo vcs cmd dir
                    try -pass_signal {
                        macports::UpdateVCS $cmd $dir
                    } catch {*} {
                        ui_debug $::errorInfo
                        ui_info "Syncing local $vcs ports tree failed"
                        incr numfailed
                        continue
                    }
                }
                set needs_portindex true
            }
            {^rsync$} {
                # Where to, boss?
                set indexfile [macports::getindex $source]
                set destdir [file dirname $indexfile]
                set is_tarball [_source_is_snapshot $source filename extension rooturl]
                file mkdir $destdir

                if {$is_tarball} {
                    set exclude_option "--exclude=*"
                    set include_option "--include=/${filename} --include=/${filename}.rmd160"
                    # need to do a few things before replacing the ports tree in this case
                    set destdir [file dirname $destdir]
                    set srcstr $rooturl
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
                set rsync_commandline "$macports::autoconf::rsync_path $rsync_options $include_option $exclude_option $srcstr $destdir"
                try -pass_signal {
                    system $rsync_commandline
                } catch {*} {
                    ui_error "Synchronization of the local ports tree failed doing rsync"
                    incr numfailed
                    continue
                }

                if {$is_tarball} {
                    # verify signature for tarball
                    global macports::archivefetch_pubkeys
                    set tarball ${destdir}/[file tail $source]
                    set signature ${tarball}.rmd160
                    set openssl [macports::findBinary openssl $macports::autoconf::openssl_path]
                    set verified 0
                    foreach pubkey $macports::archivefetch_pubkeys {
                        try -pass_signal {
                            exec $openssl dgst -ripemd160 -verify $pubkey -signature $signature $tarball
                            set verified 1
                            ui_debug "successful verification with key $pubkey"
                            break
                        } catch {{*} eCode eMessage} {
                            ui_debug "failed verification with key $pubkey"
                            ui_debug "openssl output: $eMessage"
                        }
                    }
                    if {!$verified} {
                        ui_error "Failed to verify signature for ports tree!"
                        incr numfailed
                        continue
                    }

                    # extract tarball and move into place
                    set tar [macports::findBinary tar $macports::autoconf::tar_path]
                    file mkdir ${destdir}/tmp
                    set tar_cmd "$tar -C ${destdir}/tmp -xf $tarball"
                    try -pass_signal {
                        system $tar_cmd
                    } catch {{*} eCode eMessage} {
                        ui_error "Failed to extract ports tree from tarball: $eMessage"
                        incr numfailed
                        continue
                    }
                    # save the local PortIndex data
                    if {[file isfile $indexfile]} {
                        file copy -force $indexfile ${destdir}/
                        file rename -force $indexfile ${destdir}/tmp/ports/
                        if {[file isfile ${indexfile}.quick]} {
                            file rename -force ${indexfile}.quick ${destdir}/tmp/ports/
                        }
                    }
                    file delete -force ${destdir}/ports
                    file rename ${destdir}/tmp/ports ${destdir}/ports
                    file delete -force ${destdir}/tmp
                }

                set needs_portindex true
                # now sync the index if the local file is missing or older than a day
                if {![file isfile $indexfile] || [clock seconds] - [file mtime $indexfile] > 86400
                      || [info exists options(no_reindex)]} {
                    if {$is_tarball} {
                        # chop ports.tar off the end
                        set index_source [string range $source 0 end-[string length [file tail $source]]]
                    } else {
                        set index_source $source
                    }
                    set remote_indexfile "${index_source}PortIndex_${macports::os_platform}_${macports::os_major}_${macports::os_arch}/PortIndex"
                    set rsync_commandline "$macports::autoconf::rsync_path $rsync_options $remote_indexfile $destdir"
                    try -pass_signal {
                        system $rsync_commandline
                        
                        set ok 1
                        set needs_portindex false
                        if {$is_tarball} {
                            set ok 0
                            set needs_portindex true
                            # verify signature for PortIndex
                            set rsync_commandline "$macports::autoconf::rsync_path $rsync_options ${remote_indexfile}.rmd160 $destdir"
                            system $rsync_commandline
                            foreach pubkey $macports::archivefetch_pubkeys {
                                try -pass_signal {
                                    exec $openssl dgst -ripemd160 -verify $pubkey -signature ${destdir}/PortIndex.rmd160 ${destdir}/PortIndex
                                    set ok 1
                                    set needs_portindex false
                                    ui_debug "successful verification with key $pubkey"
                                    break
                                } catch {{*} eCode eMessage} {
                                    ui_debug "failed verification with key $pubkey"
                                    ui_debug "openssl output: $eMessage"
                                }
                            }
                            if {$ok} {
                                # move PortIndex into place
                                file rename -force ${destdir}/PortIndex ${destdir}/ports/
                            }
                        }
                        if {$ok} {
                            mports_generate_quickindex $indexfile
                        }
                    } catch {*} {
                        ui_debug "Synchronization of the PortIndex failed doing rsync"
                    }
                }
                try -pass_signal {
                    system [list chmod -R a+r $destdir]
                } catch {*} {
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

                if {(![info exists options(ports_force)] || !$options(ports_force)) && $updated <= 0} {
                    ui_info "No updates for $source"
                    continue
                }

                file mkdir $destdir

                set progressflag {}
                if {$macports::portverbose} {
                    set progressflag "--progress builtin"
                    set verboseflag "-v"
                } elseif {[info exists macports::ui_options(progress_download)]} {
                    set progressflag "--progress ${macports::ui_options(progress_download)}"
                    set verboseflag ""
                }
                try -pass_signal {
                    curl fetch {*}$progressflag $source $tarpath
                } catch {{*} eCode eMessage} {
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

                set tar [macports::findBinary tar $macports::autoconf::tar_path]
                if {[catch {system -W ${destdir} "$tar $verboseflag $striparg $extflag -xf [macports::shellescape $tarpath]"} error]} {
                    ui_error "Extracting $source failed ($error)"
                    incr numfailed
                    continue
                }

                if {[catch {system "chmod -R a+r [macports::shellescape $destdir]"}]} {
                    ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                }

                set platindex "PortIndex_${macports::os_platform}_${macports::os_major}_${macports::os_arch}/PortIndex"
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
            if {![info exists options(no_reindex)]} {
                global macports::prefix
                set indexdir [file dirname [macports::getindex $source]]
                if {[catch {system "${macports::prefix}/bin/portindex [macports::shellescape $indexdir]"}]} {
                    ui_error "updating PortIndex for $source failed"
                }
            }
        }
    }

    # refresh the quick index if necessary (batch or shell mode run)
    if {[info exists macports::ui_options(ports_commandfiles)]} {
        _mports_load_quickindex
    }

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
    global macports::sources
    set matches [list]
    set easy [expr {$field eq "name"}]

    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        try -pass_signal {
            set fd [open [macports::getindex $source] r]

            try -pass_signal {
                incr found 1
                while {[gets $fd line] >= 0} {
                    array unset portinfo
                    set name [lindex $line 0]
                    set len  [lindex $line 1]
                    set line [read $fd $len]

                    if {$easy} {
                        set target $name
                    } else {
                        array set portinfo $line
                        if {![info exists portinfo($field)]} {
                            continue
                        }
                        set target $portinfo($field)
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
                        if {$easy} {
                            array set portinfo $line
                        }
                        switch -- $protocol {
                            rsync {
                                # Rsync files are local
                                set source_url file://[macports::getsourcepath $source]
                            }
                            https -
                            http -
                            ftp {
                                # snapshot tarball
                                set source_url file://[macports::getsourcepath $source]
                            }
                            default {
                                set source_url $source
                            }
                        }
                        if {[info exists portinfo(portdir)]} {
                            set porturl ${source_url}/$portinfo(portdir)
                            lappend line porturl $porturl
                            ui_debug "Found port in $porturl"
                        } else {
                            ui_debug "Found port info: $line"
                        }
                        lappend matches $name
                        lappend matches $line
                    }
                }
            } catch * {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
                throw
            } finally {
                close $fd
            }
        } catch {*} {
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
    global macports::sources macports::quick_index

    set sourceno 0
    set matches [list]
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        if {![info exists quick_index(${sourceno},[string tolower $name])]} {
            # no entry in this source, advance to next source
            incr sourceno 1
            continue
        }
        # The quick index is keyed on the port name, and provides the offset in
        # the main PortIndex where the given port's PortInfo line can be found.
        set offset $quick_index(${sourceno},[string tolower $name])
        incr sourceno 1
        if {[catch {set fd [open [macports::getindex $source] r]} result]} {
            ui_warn "Can't open index file for source: $source"
        } else {
            try -pass_signal {
                seek $fd $offset
                gets $fd line
                set name [lindex $line 0]
                set len  [lindex $line 1]
                set line [read $fd $len]

                array set portinfo $line

                switch -- $protocol {
                    rsync {
                        set source_url file://[macports::getsourcepath $source]
                    }
                    https -
                    http -
                    ftp {
                        set source_url file://[macports::getsourcepath $source]
                    }
                    default {
                        set source_url $source
                    }
                }
                if {[info exists portinfo(portdir)]} {
                    lappend line porturl ${source_url}/$portinfo(portdir)
                }
                lappend matches $name
                lappend matches $line
            } catch * {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
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
    global macports::sources
    set matches [list]

    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        try -pass_signal {
            set fd [open [macports::getindex $source] r]

            try -pass_signal {
                incr found 1
                while {[gets $fd line] >= 0} {
                    array unset portinfo
                    set name [lindex $line 0]
                    set len  [lindex $line 1]
                    set line [read $fd $len]

                    array set portinfo $line

                    switch -- $protocol {
                        rsync {
                            set source_url file://[macports::getsourcepath $source]
                        }
                        https -
                        http -
                        ftp {
                            set source_url file://[macports::getsourcepath $source]
                        }
                        default {
                            set source_url $source
                        }
                    }
                    if {[info exists portinfo(portdir)]} {
                        lappend line porturl ${source_url}/$portinfo(portdir)
                    }
                    lappend matches $name $line
                }
            } catch * {
                ui_warn "It looks like your PortIndex file for $source may be corrupt."
                throw
            } finally {
                close $fd
            }
        } catch {*} {
            ui_warn "Can't open index file for source: $source"
        }
    }
    if {!$found} {
        return -code error "No index(es) found! Have you synced your port definitions? Try running 'port selfupdate'."
    }

    return $matches
}

##
# Loads PortIndex.quick from each source into the quick_index, generating it
# first if necessary. Private API of macports1.0, do not use this from outside
# macports1.0.
proc _mports_load_quickindex {} {
    global macports::sources macports::quick_index

    unset -nocomplain macports::quick_index

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
            try -pass_signal {
                set quicklist [mports_generate_quickindex $index]
            } catch {*} {
                incr sourceno
                continue
            }
        }
        # only need to read the quick index file if we didn't just update it
        if {![info exists quicklist]} {
            try -pass_signal {
                set fd [open ${index}.quick r]
            } catch {*} {
                ui_warn "Can't open quick index file for source: $source"
                incr sourceno
                continue
            }
            set quicklist [read $fd]
            close $fd
        }
        foreach entry [split $quicklist \n] {
            set quick_index(${sourceno},[lindex $entry 0]) [lindex $entry 1]
        }
        incr sourceno 1
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
    try -pass_signal {
        set indexfd -1
        set quickfd -1
        set indexfd [open $index r]
        set quickfd [open ${index}.quick w]
    } catch {*} {
        ui_warn "Can't open index file: $index"
        return -code error
    }
    try -pass_signal {
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
    } catch {{*} eCode eMessage} {
        ui_warn "It looks like your PortIndex file $index may be corrupt."
        throw
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
    return [$workername eval {array get ::PortInfo}]
}

proc mportclose {mport} {
    global macports::open_mports
    #macports::extracted_portdirs
    set refcnt [ditem_key $mport refcnt]
    incr refcnt -1
    ditem_key $mport refcnt $refcnt
    if {$refcnt == 0} {
        dlist_delete macports::open_mports $mport
        set workername [ditem_key $mport workername]
        # the hack in _mportexec might have already deleted the worker
        if {[interp exists $workername]} {
            interp delete $workername
        }
        set porturl [ditem_key $mport porturl]
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
# return 0 if everything was ok, an non zero integer otherwise.
proc mportdepends {mport {target {}} {recurseDeps 1} {skipSatisfied 1} {accDeps 0}} {

    array set portinfo [mportinfo $mport]
    if {$accDeps} {
        upvar port_seen port_seen
    } else {
        array set port_seen {}
    }

    # progress indicator
    if {![macports::ui_isset ports_debug]} {
        ui_info -nonewline .
        flush stdout
    }

    if {$target in {{} install activate}} {
        if {[catch {_mporterrorifconflictsinstalled $mport}]} {
            return 1
        }
    }

    set workername [ditem_key $mport workername]
    set deptypes [macports::_deptypes_for_target $target $workername]

    set depPorts {}
    if {[llength $deptypes] > 0} {
        array set optionsarray [ditem_key $mport options]
        # avoid propagating requested flag from parent
        unset -nocomplain optionsarray(ports_requested)
        # subport will be different for deps
        unset -nocomplain optionsarray(subport)
        set options [array get optionsarray]
        set variations [ditem_key $mport variations]
        set required_archs [$workername eval {get_canonical_archs}]
        set depends_skip_archcheck [_mportkey $mport depends_skip_archcheck]
    }

    # Process the dependencies for each of the deptypes
    foreach deptype $deptypes {
        if {![info exists portinfo($deptype)]} {
            continue
        }
        foreach depspec $portinfo($deptype) {
            # get the portname that satisfies the depspec
            set dep_portname [$workername eval "_get_dep_port $depspec"]
            # skip port/archs combos we've already seen, and ones with the same port but less archs than ones we've seen (or noarch)
            set seenkey ${dep_portname},[join $required_archs ,]
            set seen 0
            if {[info exists port_seen($seenkey)]} {
                set seen 1
            } else {
                set prev_seenkeys [array names port_seen ${dep_portname},*]
                set nrequired [llength $required_archs]
                foreach key $prev_seenkeys {
                    set key_archs [lrange [split $key ,] 1 end]
                    if {$key_archs eq "noarch" || $required_archs eq "noarch" || [llength $key_archs] > $nrequired} {
                        set seen 1
                        set seenkey $key
                        break
                    }
                }
            }
            if {$seen} {
                if {$port_seen($seenkey) != 0} {
                    # nonzero means the dep is not satisfied, so we have to record it
                    ditem_append_unique $mport requires $port_seen($seenkey)
                }
                continue
            }

            # Is that dependency satisfied or this port installed?
            # If we don't skip or if it is not, add it to the list.
            set present [_mportispresent $mport $depspec]

            if {!$skipSatisfied && $dep_portname eq ""} {
                set dep_portname [lindex [split $depspec :] end]
            }

            set check_archs 0
            if {$dep_portname ne "" && $deptype ni {depends_fetch depends_extract}
                && $dep_portname ni $depends_skip_archcheck} {
                set check_archs 1
            }

            # need to open the portfile even if the dep is installed if it doesn't have the right archs
            set parse 0
            if {!$skipSatisfied || !$present || ($check_archs && ![macports::_active_supports_archs $dep_portname $required_archs])} {
                set parse 1
            }
            if {$parse} {
                # Find the porturl
                try -pass_signal {
                    set res [mportlookup $dep_portname]
                } catch {{*} eCode eMessage} {
                    ui_msg {}
                    ui_debug $::errorInfo
                    ui_error "Internal error: port lookup failed: $eMessage"
                    return 1
                }

                array unset dep_portinfo
                array set dep_portinfo [lindex $res 1]
                if {![info exists dep_portinfo(porturl)]} {
                    if {![macports::ui_isset ports_debug]} {
                        ui_msg {}
                    }
                    ui_error "Dependency '$dep_portname' not found."
                    return 1
                } elseif {[info exists dep_portinfo(installs_libs)] && !$dep_portinfo(installs_libs)} {
                    set check_archs 0
                    if {$skipSatisfied && $present} {
                        set parse 0
                    }
                }

                if {$parse} {
                    set dep_options $options
                    lappend dep_options subport $dep_portinfo(name)
                    # Figure out the depport. Check the open_mports list first, since
                    # we potentially leak mport references if we mportopen each time,
                    # because mportexec only closes each open mport once.
                    set depport [dlist_match_multi $macports::open_mports [list porturl $dep_portinfo(porturl) options $dep_options]]

                    if {$depport eq ""} {
                        # We haven't opened this one yet.
                        set depport [mportopen $dep_portinfo(porturl) $dep_options $variations]
                    }
                }
            }

            # check archs
            if {$parse && $check_archs
                && ![macports::_mport_supports_archs $depport $required_archs]} {

                set supported_archs [_mportkey $depport supported_archs]
                array unset variation_array
                array set variation_array [[ditem_key $depport workername] eval {array get requested_variations}]
                mportclose $depport
                set arch_mismatch 1
                set has_universal 0
                if {[info exists dep_portinfo(variants)] && {universal} in $dep_portinfo(variants)} {
                    # a universal variant is offered
                    set has_universal 1
                    if {![info exists variation_array(universal)] || $variation_array(universal) ne "+"} {
                        set variation_array(universal) +
                        # try again with +universal
                        set depport [mportopen $dep_portinfo(porturl) $dep_options [array get variation_array]]
                        if {[macports::_mport_supports_archs $depport $required_archs]} {
                            set arch_mismatch 0
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
                set port_seen(${dep_portname},[join [macports::_mport_archs $depport] ,]) $depport_provides
            } elseif {$present && $dep_portname ne ""} {
                # record actual installed archs
                set port_seen(${dep_portname},[join [macports::_active_archs $dep_portname] ,]) 0
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
                set res [mportdepends $depport {} $recurseDeps $skipSatisfied 1]
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
    return [$workername eval {get_canonical_archs}]
}

# check if the active version of a port supports the given archs
proc macports::_active_supports_archs {portname required_archs} {
    if {$required_archs eq "noarch"} {
        return 1
    }
    if {[registry::entry installed $portname] eq ""} {
        return 0
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
        set archs {}
    }
    return $archs
}

# print an error message explaining why a port's archs are not provided by a dependency
proc macports::_explain_arch_mismatch {port dep required_archs supported_archs has_universal} {
    global macports::universal_archs
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
    array set portinfo [mportinfo $mport]
    foreach type $deptypes {
        if {[info exists portinfo($type)] && $portinfo($type) ne ""} {
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
            return [expr {![$workername eval _archive_available]}]
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
        checksum    {return depends_fetch}
        extract     {return "depends_fetch depends_extract"}
        patch       {return "depends_fetch depends_extract depends_patch"}
        configure   -
        build       {return "depends_fetch depends_extract depends_patch depends_build depends_lib"}
        test        {return "depends_fetch depends_extract depends_patch depends_build depends_lib depends_run depends_test"}
        destroot    {return "depends_fetch depends_extract depends_patch depends_build depends_lib depends_run"}
        dmg         -
        pkg         -
        mdmg        -
        mpkg        {
            if {[global_option_isset ports_binary_only] ||
                (![global_option_isset ports_source_only] && [$workername eval {_archive_available}])} {
                return "depends_lib depends_run"
            } else {
                return "depends_fetch depends_extract depends_patch depends_build depends_lib depends_run"
            }
        }
        install     -
        activate    -
        {}          {
            if {[global_option_isset ports_binary_only] ||
                [$workername eval {registry_exists $subport $version $revision $portvariants}]
                || (![global_option_isset ports_source_only] && [$workername eval {_archive_available}])} {
                return "depends_lib depends_run"
            } else {
                return "depends_fetch depends_extract depends_patch depends_build depends_lib depends_run"
            }
        }
    }
    return {}
}

# selfupdate procedure
proc macports::selfupdate {{optionslist {}} {updatestatusvar {}}} {
    return [uplevel [list selfupdate::main $optionslist $updatestatusvar]]
}

# upgrade API wrapper procedure
# return codes:
#   0 = success
#   1 = general failure
#   2 = port name not found in index
#   3 = port not installed
proc macports::upgrade {portname dspec variationslist optionslist {depscachename {}}} {
    # only installed ports can be upgraded
    if {[registry::entry imaged $portname] eq {}} {
        ui_error "$portname is not installed"
        return 3
    }
    if {$depscachename ne ""} {
        upvar $depscachename depscache
    } else {
        array set depscache {}
    }
    # stop upgrade from being called via mportexec as well
    set orig_nodeps yes
    if {![info exists macports::global_options(ports_nodeps)]} {
        set macports::global_options(ports_nodeps) yes
        set orig_nodeps no
    }

    # run the actual upgrade
    set status [macports::_upgrade $portname $dspec $variationslist $optionslist depscache]

    if {!$orig_nodeps} {
        unset -nocomplain macports::global_options(ports_nodeps)
    }

    return $status
}

# main internal upgrade procedure
proc macports::_upgrade {portname dspec variationslist optionslist {depscachename {}}} {
    global macports::global_variations
    array set options $optionslist

    if {$depscachename ne ""} {
        upvar $depscachename depscache
    }

    # Is this a dry run?
    set is_dryrun no
    if {[info exists options(ports_dryrun)] && $options(ports_dryrun)} {
        set is_dryrun yes
    }

    # Is this a rev-upgrade-called run?
    set is_revupgrade no
    if {[info exists options(ports_revupgrade)] && $options(ports_revupgrade)} {
        set is_revupgrade yes
        # unset revupgrade options so we can upgrade dependencies with the same
        # $options without also triggering a rebuild there, see #40150
        unset options(ports_revupgrade)
    }
    set is_revupgrade_second_run no
    if {[info exists options(ports_revupgrade_second_run)] && $options(ports_revupgrade_second_run)} {
        set is_revupgrade_second_run yes
        # unset revupgrade options so we can upgrade dependencies with the same
        # $options without also triggering a rebuild there, see #40150
        unset options(ports_revupgrade_second_run)
    }

    # check if the port is in tree
    set result ""
    try {
        set result [mportlookup $portname]
    } catch {{*} eCode eMessage} {
        ui_debug $::errorInfo
        ui_error "port lookup failed: $eMessage"
        return 1
    }
    # argh! port doesnt exist!
    if {$result eq ""} {
        ui_warn "No port $portname found in the index."
        return 2
    }
    # fill array with information
    array set portinfo [lindex $result 1]
    # set portname again since the one we were passed may not have had the correct case
    set portname $portinfo(name)
    set options(subport) $portname

    set ilist {}
    if {[catch {set ilist [registry::installed $portname {}]} result]} {
        if {$result eq "Registry error: $portname not registered as installed."} {
            ui_debug "$portname is *not* installed by MacPorts"

            # We need to pass _mportispresent a reference to the mport that is
            # actually declaring the dependency on the one we're checking for.
            # We got here via _upgrade_dependencies, so we grab it from 2 levels up.
            upvar 2 mport parentmport
            if {![_mportispresent $parentmport $dspec]} {
                # open porthandle
                set porturl $portinfo(porturl)
                if {![info exists porturl]} {
                    set porturl file://./
                }
                # Grab the variations from the parent
                upvar 2 variations variations

                if {[catch {set mport [mportopen $porturl [array get options] [array get variations]]} result]} {
                    ui_debug $::errorInfo
                    ui_error "Unable to open port: $result"
                    return 1
                }
                # While we're at it, update the portinfo
                array unset portinfo
                array set portinfo [mportinfo $mport]

                # mark it in the cache now to guard against circular dependencies
                set depscache(port:$portname) 1
                # upgrade its dependencies first
                set status [_upgrade_dependencies portinfo depscache variationslist options]
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
            ui_error "Checking installed version failed: $result"
            return 1
        }
    } else {
        # we'll now take care of upgrading it, so we can add it to the cache
        set depscache(port:$portname) 1
    }

    # set version_in_tree and revision_in_tree
    if {![info exists portinfo(version)]} {
        ui_error "Invalid port entry for ${portname}, missing version"
        return 1
    }
    set version_in_tree $portinfo(version)
    set revision_in_tree $portinfo(revision)
    set epoch_in_tree $portinfo(epoch)

    # find latest version installed and active version (if any)
    set anyactive no
    set version_installed {}
    foreach i $ilist {
        set variant [lindex $i 3]
        set version [lindex $i 1]
        set revision [lindex $i 2]
        set epoch [lindex $i 5]
        if {$version_installed eq "" || ($epoch > $epoch_installed && $version ne $version_installed) ||
                ($epoch >= $epoch_installed && [vercmp $version $version_installed] > 0)
                || ($epoch >= $epoch_installed
                    && [vercmp $version $version_installed] == 0
                    && $revision > $revision_installed)} {
            set version_installed $version
            set revision_installed $revision
            set variant_installed $variant
            set epoch_installed $epoch
        }

        set isactive [lindex $i 4]
        if {$isactive == 1} {
            set anyactive yes
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
        set regref [registry::open_entry $portname $version_active $revision_active $variant_active $epoch_active]
    } else {
        ui_debug "no version of $portname is active"
        set oldvariant $variant_installed
        set regref [registry::open_entry $portname $version_installed $revision_installed $variant_installed $epoch_installed]
    }
    set oldrequestedvariant [registry::property_retrieve $regref requested_variants]
    if {$oldrequestedvariant == 0} {
        set oldrequestedvariant {}
    }
    set requestedflag [registry::property_retrieve $regref requested]
    set os_platform_installed [registry::property_retrieve $regref os_platform]
    set os_major_installed [registry::property_retrieve $regref os_major]
    set cxx_stdlib_installed [registry::property_retrieve $regref cxx_stdlib]
    set cxx_stdlib_overridden [registry::property_retrieve $regref cxx_stdlib_overridden]

    # Before we do
    # dependencies, we need to figure out the final variants,
    # open the port, and update the portinfo.
    set porturl $portinfo(porturl)
    if {![info exists porturl]} {
        set porturl file://./
    }

    # Note $variationslist is left alone and so retains the original
    # requested variations, which should be passed to recursive calls to
    # upgrade; while variations gets existing variants and global variations
    # merged in later on, so it applies only to this port's upgrade
    array set variations $variationslist

    set globalvarlist [array get macports::global_variations]

    # Relies on all negated variants being at the end of requested_variants
    set splitvariant [split $oldrequestedvariant -]
    set minusvariant [lrange $splitvariant 1 end]
    set splitvariant [split [lindex $splitvariant 0] +]
    set plusvariant [lrange $splitvariant 1 end]
    ui_debug "Merging existing requested variants '${oldrequestedvariant}' into variants"
    set oldvariantlist [list]
    foreach v $plusvariant {
        lappend oldvariantlist $v +
    }
    foreach v $minusvariant {
        if {[string first "+" $v] == -1} {
            lappend oldvariantlist $v -
            set installedvariations($v) -
        } else {
            ui_warn "Invalid negated variant for ${portname}: $v"
        }
    }
    # save the current variants for dependency calculation purposes
    # in case we don't end up upgrading this port
    set plusvariant [lrange [split $oldvariant +] 1 end]
    foreach v $plusvariant {
        set installedvariations($v) +
    }

    # merge in the old requested variants
    foreach {variation value} $oldvariantlist {
        if {![info exists variations($variation)]} {
            set variations($variation) $value
        }
    }

    # Now merge in the global (i.e. variants.conf) variations.
    # We wait until now so that existing requested variants for this port
    # override global variations
    foreach {variation value} $globalvarlist {
        if {![info exists variations($variation)]} {
            set variations($variation) $value
        }
    }

    ui_debug "new fully merged portvariants: [array get variations]"

    # at this point we need to check if a different port will be replacing this one
    if {[info exists portinfo(replaced_by)] && ![info exists options(ports_upgrade_no-replace)]} {
        ui_msg "$macports::ui_prefix $portname is replaced by $portinfo(replaced_by)"
        if {[catch {mportlookup $portinfo(replaced_by)} result]} {
            ui_debug $::errorInfo
            ui_error "port lookup failed: $result"
            return 1
        }
        if {$result eq ""} {
            ui_error "No port $portinfo(replaced_by) found."
            return 1
        }
        array unset portinfo
        array set portinfo [lindex $result 1]
        set newname $portinfo(name)

        set porturl $portinfo(porturl)
        if {![info exists porturl]} {
            set porturl file://./
        }
        set depscache(port:$newname) 1
    } else {
        set newname $portname
    }

    array set interp_options [array get options]
    set interp_options(ports_requested) $requestedflag
    set interp_options(subport) $newname
    # Mark this port to be rebuilt from source if this isn't the first time it
    # was flagged as broken by rev-upgrade
    if {$is_revupgrade_second_run} {
        set interp_options(ports_source_only) yes
    }

    if {[catch {set mport [mportopen $porturl [array get interp_options] [array get variations]]} result]} {
        ui_debug $::errorInfo
        ui_error "Unable to open port: $result"
        return 1
    }

    array unset portinfo
    array set portinfo [mportinfo $mport]
    set version_in_tree $portinfo(version)
    set revision_in_tree $portinfo(revision)
    set epoch_in_tree $portinfo(epoch)

    set build_override 0
    set will_install yes
    # check installed version against version in ports
    if {([vercmp $version_installed $version_in_tree] > 0
            || ([vercmp $version_installed $version_in_tree] == 0
                && [vercmp $revision_installed $revision_in_tree] >= 0))
        && ![info exists options(ports_upgrade_force)]} {
        if {$portname ne $newname} {
            ui_debug "ignoring versions, installing replacement port"
        } elseif {$epoch_installed < $epoch_in_tree && $version_installed ne $version_in_tree} {
            set build_override 1
            ui_debug "epoch override ... upgrading!"
        } elseif {[info exists options(ports_upgrade_enforce-variants)] && $options(ports_upgrade_enforce-variants)
                  && [info exists portinfo(canonical_active_variants)] && $portinfo(canonical_active_variants) ne $oldvariant} {
            ui_debug "variant override ... upgrading!"
        } elseif {$os_platform_installed ne "" && $os_major_installed ne "" && $os_platform_installed != 0
                  && ([_mportkey $mport os.platform] ne $os_platform_installed
                  || [_mportkey $mport os.major] != $os_major_installed)} {
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
            if {[info exists portinfo(canonical_active_variants)] && $portinfo(canonical_active_variants) ne $oldvariant} {
                if {[llength $variationslist] > 0} {
                    ui_warn "Skipping upgrade since $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_${revision_in_tree}, even though installed variants \"$oldvariant\" do not match \"$portinfo(canonical_active_variants)\". Use 'upgrade --enforce-variants' to switch to the requested variants."
                } else {
                    ui_debug "Skipping upgrade since $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_${revision_in_tree}, even though installed variants \"$oldvariant\" do not match \"$portinfo(canonical_active_variants)\"."
                }
                # reopen with the installed variants so deps are calculated correctly
                catch {mportclose $mport}
                if {[catch {set mport [mportopen $porturl [array get interp_options] [array get installedvariations]]} result]} {
                    ui_debug $::errorInfo
                    ui_error "Unable to open port: $result"
                    return 1
                }
            } else {
                ui_debug "No need to upgrade! $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_$revision_in_tree"
            }
            set will_install no
        }
    }

    array unset interp_options

    set will_build no
    set already_installed [registry::entry_exists $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants)]
    # avoid building again unnecessarily
    if {$will_install &&
        ([info exists options(ports_upgrade_force)]
            || $build_override == 1
            || !$already_installed)} {
        set will_build yes
    }

    # first upgrade dependencies
    if {![info exists options(ports_nodeps)]} {
        # the last arg is because we might have to build from source if a rebuild is being forced
        set status [_upgrade_dependencies portinfo depscache variationslist options [expr {$will_build && $already_installed}]]
        if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
            catch {mportclose $mport}
            return $status
        }
    } else {
        ui_debug "Not following dependencies"
    }

    if {!$will_install} {
        # nothing to do for this port, so just check if we have to do dependents
        if {[info exists options(ports_do_dependents)]} {
            # We do dependents ..
            set options(ports_nodeps) 1

            registry::open_dep_map
            if {$anyactive} {
                set deplist [registry::list_dependents $portname $version_active $revision_active $variant_active]
            } else {
                set deplist [registry::list_dependents $portname $version_installed $revision_installed $variant_installed]
            }

            if {[llength deplist] > 0} {
                foreach dep $deplist {
                    set mpname [lindex $dep 2]
                    if {![info exists depscache(port:$mpname)]} {
                        set status [macports::_upgrade $mpname port:$mpname $variationslist [array get options] depscache]
                        if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
                            catch {mportclose $mport}
                            return $status
                        }
                    }
                }
            }
        }
        mportclose $mport
        return 0
    }

    set workername [ditem_key $mport workername]
    if {$will_build} {
        if {$already_installed
            && ([info exists options(ports_upgrade_force)] || $build_override == 1)} {
            # Tell archivefetch/unarchive not to use the installed archive, i.e. a
            # fresh one will be either fetched or built locally.
            # Ideally this would be done in the interp_options when we mportopen,
            # but we don't know if we want to do this at that point.
            $workername eval {set force_archive_refresh yes}

            # run archivefetch and destroot for version_in_tree
            # doing this instead of just running install ensures that we have the
            # new copy ready but not yet installed, so we can safely uninstall the
            # existing one.
            if {[catch {mportexec $mport archivefetch} result]} {
                ui_debug $::errorInfo
                catch {mportclose $mport}
                return 1
            } elseif {$result != 0} {
                catch {mportclose $mport}
                return 1
            }
            # the following is a noop if archivefetch found an archive
            if {[catch {mportexec $mport destroot} result]} {
                ui_debug $::errorInfo
                catch {mportclose $mport}
                return 1
            } elseif {$result != 0} {
                catch {mportclose $mport}
                return 1
            }
        } else {
            # Normal non-forced case
            # install version_in_tree (but don't activate yet)
            if {[catch {mportexec $mport install} result]} {
                ui_debug $::errorInfo
                catch {mportclose $mport}
                return 1
            } elseif {$result != 0} {
                catch {mportclose $mport}
                return 1
            }
        }
    }

    # check if the startupitem is loaded, so we can load again it after upgrading
    # (deactivating the old version will unload the startupitem)
    set loaded_startupitems {}
    if {$portname eq $newname} {
        set loaded_startupitems [$workername eval {portstartupitem::loaded}]
    }

    # are we installing an existing version due to force or epoch override?
    if {$already_installed
        && ([info exists options(ports_upgrade_force)] || $build_override == 1)} {
         ui_debug "Uninstalling $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants)"
        # we have to force the uninstall in case of dependents
        set force_cur [info exists options(ports_force)]
        set options(ports_force) yes
        set existing_epoch [lindex [registry::installed $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants)] 0 5]
        set newregref [registry::open_entry $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants) $existing_epoch]
        if {$is_dryrun} {
            ui_msg "Skipping uninstall $newname @${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) (dry run)"
        } elseif {![registry::run_target $newregref uninstall [array get options]]
                  && [catch {registry_uninstall::uninstall $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants) [array get options]} result]} {
            ui_debug $::errorInfo
            ui_error "Uninstall $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) failed: $result"
            catch {mportclose $mport}
            return 1
        }
        if {!$force_cur} {
            unset options(ports_force)
        }
        if {$anyactive && $version_in_tree eq $version_active && $revision_in_tree == $revision_active
            && $portinfo(canonical_active_variants) eq $variant_active && $portname eq $newname} {
            set anyactive no
        }
    }
    if {$anyactive && $portname ne $newname} {
        # replaced_by in effect, deactivate the old port
        # we have to force the deactivate in case of dependents
        set force_cur [info exists options(ports_force)]
        set options(ports_force) yes
        if {$is_dryrun} {
            ui_msg "Skipping deactivate $portname @${version_active}_${revision_active}$variant_active (dry run)"
        } elseif {![catch {registry::active $portname}] &&
                  ![registry::run_target $regref deactivate [array get options]]
                  && [catch {portimage::deactivate $portname $version_active $revision_active $variant_active [array get options]} result]} {
            ui_debug $::errorInfo
            ui_error "Deactivating $portname @${version_active}_${revision_active}$variant_active failed: $result"
            catch {mportclose $mport}
            return 1
        }
        if {!$force_cur} {
            unset options(ports_force)
        }
        set anyactive no
    }
    if {[info exists options(port_uninstall_old)] && $portname eq $newname} {
        # uninstalling now could fail due to dependents when not forced,
        # because the new version is not installed
        set uninstall_later yes
    }

    if {$is_dryrun} {
        if {$anyactive} {
            ui_msg "Skipping deactivate $portname @${version_active}_${revision_active}$variant_active (dry run)"
        }
        ui_msg "Skipping activate $newname @${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) (dry run)"
    } else {
        set failed 0
        if {[catch {mportexec $mport activate} result]} {
            ui_debug $::errorInfo
            set failed 1
        } elseif {$result != 0} {
            set failed 1
        }
        if {$failed} {
            ui_error "Couldn't activate $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants): $result"
            catch {mportclose $mport}
            return 1
        }
        if {$loaded_startupitems ne ""} {
            $workername eval "set ::portstartupitem::load_only [list $loaded_startupitems]"
            if {[catch {mportexec $mport load} result]} {
                ui_debug $::errorInfo
                ui_warn "Error loading startupitem(s) for ${newname}: $result"
            } elseif {$result != 0} {
                ui_warn "Error loading startupitem(s) for ${newname}: $result"
            }
            $workername eval "unset ::portstartupitem::load_only"
        }
    }

    # Check if we have to do dependents
    if {[info exists options(ports_do_dependents)]} {
        # We do dependents ..
        set options(ports_nodeps) 1

        registry::open_dep_map
        if {$portname ne $newname} {
            set deplist [registry::list_dependents $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants)]
        } else {
            set deplist [list]
        }
        if {$anyactive} {
            set deplist [concat $deplist [registry::list_dependents $portname $version_active $revision_active $variant_active]]
        } else {
            set deplist [concat $deplist [registry::list_dependents $portname $version_installed $revision_installed $variant_installed]]
        }

        if {[llength deplist] > 0} {
            foreach dep $deplist {
                set mpname [lindex $dep 2]
                if {![info exists depscache(port:$mpname)]} {
                    set status [macports::_upgrade $mpname port:$mpname $variationslist [array get options] depscache]
                    if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} {
                        catch {mportclose $mport}
                        return $status
                    }
                }
            }
        }
    }

    if {[info exists uninstall_later] && $uninstall_later} {
        foreach i $ilist {
            set version [lindex $i 1]
            set revision [lindex $i 2]
            set variant [lindex $i 3]
            if {$version eq $version_in_tree && $revision == $revision_in_tree && $variant eq $portinfo(canonical_active_variants) && $portname eq $newname} {
                continue
            }
            set epoch [lindex $i 5]
            ui_debug "Uninstalling $portname ${version}_${revision}$variant"
            set regref [registry::open_entry $portname $version $revision $variant $epoch]
            if {$is_dryrun} {
                ui_msg "Skipping uninstall $portname @${version}_${revision}$variant (dry run)"
            } elseif {![registry::run_target $regref uninstall $optionslist]
                      && [catch {registry_uninstall::uninstall $portname $version $revision $variant $optionslist} result]} {
                ui_debug $::errorInfo
                # replaced_by can mean that we try to uninstall all versions of the old port, so handle errors due to dependents
                if {$result ne "Please uninstall the ports that depend on $portname first." && ![ui_isset ports_processall]} {
                    ui_error "Uninstall $portname @${version}_${revision}$variant failed: $result"
                    catch {mportclose $mport}
                    return 1
                }
            }
        }
    }

    # close the port handle
    mportclose $mport
    return 0
}

# upgrade_dependencies: helper proc for upgrade
# Calls upgrade on each dependency listed in the PortInfo.
# Uses upvar to access the variables.
proc macports::_upgrade_dependencies {portinfoname depscachename variationslistname optionsname {build_needed no}} {
    upvar $portinfoname portinfo $depscachename depscache \
          $variationslistname variationslist \
          $optionsname options
    upvar mport parentmport

    # If we're following dependents, we only want to follow this port's
    # dependents, not those of all its dependencies. Otherwise, we would
    # end up processing this port's dependents n+1 times (recursively!),
    # where n is the number of dependencies this port has, since this port
    # is of course a dependent of each of its dependencies. Plus the
    # dependencies could have any number of unrelated dependents.

    # So we save whether we're following dependents, unset the option
    # while doing the dependencies, and restore it afterwards.
    set saved_do_dependents [info exists options(ports_do_dependents)]
    unset -nocomplain options(ports_do_dependents)

    set parentworker [ditem_key $parentmport workername]
    # each required dep type is upgraded
    if {$build_needed && ![global_option_isset ports_binary_only]} {
        set dtypes [_deptypes_for_target destroot $parentworker]
    } else {
        set dtypes [_deptypes_for_target install $parentworker]
    }

    set status 0
    foreach dtype $dtypes {
        if {[info exists portinfo($dtype)]} {
            foreach i $portinfo($dtype) {
                set d [$parentworker eval "_get_dep_port $i"]
                if {![info exists depscache(port:$d)] && ![info exists depscache($i)]} {
                    if {$d ne ""} {
                        set dspec port:$d
                    } else {
                        set dspec $i
                        set d [lindex [split $i :] end]
                    }
                    set status [macports::_upgrade $d $dspec $variationslist [array get options] depscache]
                    if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} break
                }
            }
        }
        if {$status != 0 && $status != 2 && ![ui_isset ports_processall]} break
    }
    # restore dependent-following to its former value
    if {$saved_do_dependents} {
        set options(ports_do_dependents) yes
    }
    return $status
}

# mportselect
#   * command: The only valid commands are list, set, show and summary
#   * group: This argument should correspond to a directory under
#            ${macports::prefix}/etc/select.
#   * version: This argument is only used by the 'set' command.
# On error mportselect returns with the code 'error'.
proc mportselect {command {group ""} {version {}}} {
    ui_debug "mportselect \[$command] \[$group] \[$version]"

    set conf_path ${macports::prefix}/etc/select/$group
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
            set lversions {}
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
                        set tgt [file join $macports::prefix $tgt]
                        file delete $tgt
                        ui_debug "rm -f $tgt"
                    }
                    /* {
                        # The source is an absolute path.
                        set tgt [file join $macports::prefix $tgt]
                        file delete $tgt
                        file link -symbolic $tgt $src
                        ui_debug "ln -sf $src $tgt"
                    }
                    default {
                        # The source is a relative path.
                        set src [file join $macports::prefix $src]
                        set tgt [file join $macports::prefix $tgt]
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
    global macports::os_major macports::os_arch macports::os_platform
    if {$macports::os_platform eq "darwin"} {
        if {$macports::os_major >= 11 && [string first ppc $arch] == 0} {
            return no
        } elseif {$macports::os_arch eq "i386" && $arch in [list arm64 ppc64]} {
            return no
        } elseif {$macports::os_major <= 8 && $arch eq "x86_64"} {
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
# @return 0 on success, 1 if an exception occured during the execution
#         of reclaim, 2 if the execution was aborted on user request.
proc macports::reclaim_check_and_run {} {
    if {[macports::ui_isset ports_quiet]} {
        return 0
    }

    try {
        return [reclaim::check_last_run]
    } catch {{POSIX SIG SIGINT} eCode eMessage} {
        ui_error [msgcat::mc "reclaim aborted: SIGINT received."]
        return 2
    } catch {{POSIX SIG SIGTERM} eCode eMessage} {
        ui_error [msgcat::mc "reclaim aborted: SIGTERM received."]
        return 2
    } catch {{*} eCode eMessage} {
        ui_debug "reclaim failed: $::errorInfo"
        ui_error [msgcat::mc "reclaim failed: %s" $eMessage]
        return 1
    }
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
    } catch {{POSIX SIG SIGINT} eCode eMessage} {
        ui_error [msgcat::mc "reclaim aborted: SIGINT received."]
        return 2
    } catch {{POSIX SIG SIGTERM} eCode eMessage} {
        ui_error [msgcat::mc "reclaim aborted: SIGTERM received."]
        return 2
    } catch {{*} eCode eMessage} {
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
#         rebuilds finished successfully. 1 if an exception occured during the
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
    } catch {{POSIX SIG SIGINT} eCode eMessage} {
        ui_debug "rev-upgrade failed: $::errorInfo"
        ui_error [msgcat::mc "rev-upgrade aborted: SIGINT received."]
        return 2
    } catch {{POSIX SIG SIGTERM} eCode eMessage} {
        ui_error [msgcat::mc "rev-upgrade aborted: SIGTERM received."]
        return 2
    } catch {{*} eCode eMessage} {
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
        registry::write {
            try {
                ui_msg "$macports::ui_prefix Updating database of binaries"
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
                    } catch {{POSIX SIG SIGINT} eCode eMessage} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                        throw
                    } catch {{POSIX SIG SIGTERM} eCode eMessage} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                        throw
                    } catch {{*} eCode eMessage} {
                        if {$fancy_output} {
                            $revupgrade_progress intermission
                        }
                        # handle errors (e.g. file not found, permission denied) gracefully
                        ui_warn "Error determining file type of `$fpath': $eMessage"
                        ui_warn "A file belonging to the `[[registry::entry owner $fpath] name]' port is missing or unreadable. Consider reinstalling it."
                    }
                }
            } catch {*} {
                if {${fancy_output}} {
                    $revupgrade_progress intermission
                }
                ui_error "Updating database of binaries failed"
                throw
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
        ui_msg "$macports::ui_prefix Updating database of C++ stdlib usage"
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
                set binary_files {}
                foreach filehandle [registry::file search id [$maybe_port id] binary 1] {
                    lappend binary_files [$filehandle actual_path]
                }
                $maybe_port cxx_stdlib [get_actual_cxx_stdlib $binary_files]
                if {[catch {$maybe_port cxx_stdlib_overridden}]} {
                    # can't tell after the fact, assume not overridden
                    $maybe_port cxx_stdlib_overridden 0
                }
            }
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
proc macports::revupgrade_scanandrebuild {broken_port_counts_name opts} {
    upvar $broken_port_counts_name broken_port_counts
    array set options $opts

    set fancy_output [expr {![macports::ui_isset ports_debug] && [info exists macports::ui_options(progress_generic)]}]
    if {$fancy_output} {
        set revupgrade_progress $macports::ui_options(progress_generic)
    } else {
        set revupgrade_progress ""
    }

    revupgrade_update_binary $fancy_output $revupgrade_progress

    revupgrade_update_cxx_stdlib $fancy_output $revupgrade_progress

    set broken_files {}
    set binaries [registry::file search active 1 binary 1]
    set binary_count [llength $binaries]
    if {$binary_count > 0} {
        ui_msg "$macports::ui_prefix Scanning binaries for linking errors"
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
                    if {[info exists options(ports_rev-upgrade_id-loadcmd-check)] && $options(ports_rev-upgrade_id-loadcmd-check)} {
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
                            } catch {{POSIX SIG SIGINT} eCode eMessage} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                                throw
                            } catch {{POSIX SIG SIGTERM} eCode eMessage} {
                                if {$fancy_output} {
                                    $revupgrade_progress intermission
                                }
                                ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                                throw
                            } catch {*} {}
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
                        try {
                            set filepath [revupgrade_handle_special_paths $bpath [$loadcommand cget -mlt_install_name]]
                        } catch {{POSIX SIG SIGINT} eCode eMessage} {
                            if {$fancy_output} {
                                $revupgrade_progress intermission
                            }
                            ui_debug [msgcat::mc "Aborted: SIGINT signal received"]
                            throw
                        } catch {{POSIX SIG SIGTERM} eCode eMessage} {
                            if {$fancy_output} {
                                $revupgrade_progress intermission
                            }
                            ui_debug [msgcat::mc "Aborted: SIGTERM signal received"]
                            throw
                        } catch {*} {
                            set loadcommand [$loadcommand cget -next]
                            continue;
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
        } catch {*} {
            if {$fancy_output} {
                $revupgrade_progress intermission
            }
            throw
        }
        if {$fancy_output} {
            $revupgrade_progress finish
        }

        machista::destroy_handle $handle

        set num_broken_files [llength $broken_files]
        set s [expr {$num_broken_files == 1 ? "" : "s"}]

        set broken_ports {}
        if {$num_broken_files == 0} {
            ui_msg "$macports::ui_prefix No broken files found."
        } else {
            ui_msg "$macports::ui_prefix Found $num_broken_files broken file${s}, matching files to ports"
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
        if {${macports::cxx_stdlib} eq "libc++"} {
            set wrong_stdlib libstdc++
        } else {
            set wrong_stdlib libc++
        }
        set broken_cxx_ports [registry::entry search state installed cxx_stdlib_overridden 0 cxx_stdlib $wrong_stdlib]
        foreach cxx_port $broken_cxx_ports {
            ui_info "[$cxx_port name] is using $wrong_stdlib (this installation is configured to use ${macports::cxx_stdlib})"
        }
        set broken_ports [lsort -unique [concat $broken_ports $broken_cxx_ports]]

        if {[llength $broken_ports] == 0} {
            ui_msg "$macports::ui_prefix No broken ports found."
            return 0
        }

        if {$macports::revupgrade_mode eq "rebuild"} {
            # don't try to rebuild ports that don't exist in the tree
            set temp_broken_ports {}
            foreach port $broken_ports {
                set portname [$port name]
                if {[catch {mportlookup $portname} result]} {
                    ui_debug $::errorInfo
                    error "lookup of portname $portname failed: $result"
                }
                if {[llength $result] >= 2} {
                    lappend temp_broken_ports $port
                } else {
                    ui_warn "No port $portname found in the index; can't rebuild"
                }
            }

            if {[llength $temp_broken_ports] == 0} {
                ui_msg "$macports::ui_prefix Broken files found, but all associated ports are not in the index and so cannot be rebuilt."
                return 0
            }
        } else {
            set temp_broken_ports $broken_ports
        }

        set broken_ports {}

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

        if {$macports::revupgrade_mode ne "rebuild"} {
            ui_msg "$macports::ui_prefix Found $num_broken_ports broken port${s}:"
            foreach port $broken_ports {
                ui_msg "     [$port name] @[$port version]_[$port revision][$port variants]"
                if {[info exists broken_files_by_port($port)]} {
                    foreach f $broken_files_by_port($port) {
                        ui_msg "         $f"
                    }
                } else {
                    ui_msg "         (cxx_stdlib mismatch)"
                }
            }
            return 0
        }

        ui_msg "$macports::ui_prefix Found $num_broken_ports broken port${s}, determining rebuild order"
        # broken_ports are the nodes in our graph
        # now we need adjacents
        foreach port $broken_ports {
            # initialize with empty list
            set adjlist($port) {}
            set revadjlist($port) {}
            ui_debug "Broken: [$port name]"
        }

        array set visited {}
        foreach port $broken_ports {
            # stack of broken nodes we've come across
            set stack {}
            lappend stack $port

            # build graph
            if {![info exists visited($port)]} {
                revupgrade_buildgraph $port stack adjlist revadjlist visited
            }
        }

        set unsorted_ports $broken_ports
        set topsort_ports {}
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
                    set unsorted_ports [lreplace $unsorted_ports $index $index]

                    # remove edges
                    foreach target $revadjlist($port) {
                        set index [lsearch -exact $adjlist($target) $port]
                        set adjlist($target) [lreplace $adjlist($target) $index $index]
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
                set unsorted_ports [lreplace $unsorted_ports $index $index]

                foreach target $revadjlist($port) {
                    set index [lsearch -exact $adjlist($target) $lowest_adj_port]
                    set adjlist($target) [lreplace $adjlist($target) $index $index]
                }
            }
        }

        set broken_portnames {}
        if {![info exists macports::ui_options(questions_yesno)]} {
            ui_msg "$macports::ui_prefix Rebuilding in order"
        }
        foreach port $topsort_ports {
            lappend broken_portnames [$port name]@[$port version][$port variants]
            if {![info exists macports::ui_options(questions_yesno)]} {
                ui_msg "     [$port name] @[$port version]_[$port revision][$port variants]"
            }
        }

        ##
        # User Interaction Question
        # Asking before rebuilding in rev-upgrade
        if {[info exists macports::ui_options(questions_yesno)]} {
            ui_msg "You can always run 'port rev-upgrade' again to fix errors."
            set retvalue [$macports::ui_options(questions_yesno) "The following ports will be rebuilt:" "TestCase#1" $broken_portnames {y} 0]
            if {$retvalue == 1} {
                # quit as user answered 'no'
                return 0
            }
            unset macports::ui_options(questions_yesno)
        }

        # shared depscache for all ports that are going to be rebuilt
        array set depscache {}
        set status 0
        array set my_options [array get macports::global_options]
        set my_options(ports_revupgrade) yes
        foreach port $topsort_ports {
            set portname [$port name]
            if {![info exists depscache(port:$portname)]} {
                unset -nocomplain my_options(ports_revupgrade_second_run) \
                                  my_options(ports_nodeps)
                if {$broken_port_counts($portname) > 1} {
                    set my_options(ports_revupgrade_second_run) yes

                    if {$broken_port_counts($portname) > 2} {
                        # runtime deps are upgraded the first time, build deps 
                        # the second, so none left to do the third time
                        set my_options(ports_nodeps) yes
                    }
                }

                # call macports::upgrade with ports_revupgrade option to rebuild the port
                set status [macports::upgrade $portname port:$portname \
                    {} [array get my_options] depscache]
                ui_debug "Rebuilding port $portname finished with status $status"
                if {$status != 0} {
                    error "Error rebuilding $portname"
                }
            }
        }

        if {[info exists options(ports_dryrun)] && $options(ports_dryrun)} {
            ui_warn "If this was no dry run, rev-upgrade would now run the checks again to find unresolved and newly created problems"
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
    global macports::prefix macports::applications_dir
    if {[string first $macports::prefix $path] == 0} {
        return yes
    }
    if {[string first $macports::applications_dir $path] == 0} {
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

# get cached ping time for host, modified by blacklist and preferred list
proc macports::get_pingtime {host} {
    global macports::ping_cache macports::host_cache \
           macports::host_blacklist macports::preferred_hosts

    if {[info exists host_cache($host)]} {
        return $host_cache($host)
    }
    foreach pattern $macports::host_blacklist {
        if {[string match -nocase $pattern $host]} {
            set host_cache($host) -1
            return -1
        }
    }
    foreach pattern $macports::preferred_hosts {
        if {[string match -nocase $pattern $host]} {
            set host_cache($host) 1
            return 1
        }
    }
    if {[info exists ping_cache($host)]} {
        # expire entries after 1 day
        if {[clock seconds] - [lindex $ping_cache($host) 1] <= 86400} {
            return [lindex $ping_cache($host) 0]
        }
    }
    return {}
}

# cache a ping time of ms for host
proc macports::set_pingtime {host ms} {
    global macports::ping_cache
    set ping_cache($host) [list $ms [clock seconds]]
}

# get the version of a compiler (memoized)
proc macports::get_compiler_version {compiler} {
    global macports::compiler_version_cache

    if {[info exists compiler_version_cache($compiler)]} {
        return $compiler_version_cache($compiler)
    }

    if {![file executable ${compiler}]} {
        set compiler_version_cache($compiler) ""
        return ""
    }

    switch [file tail ${compiler}] {
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

    if {[catch {regexp ${re} [exec ${compiler} -v 2>@1] -> compiler_version}]} {
        set compiler_version_cache($compiler) ""
        return ""
    }
    if {![info exists compiler_version]} {
        return -code error "couldn't determine build number of compiler \"${compiler}\""
    }
    set compiler_version_cache($compiler) $compiler_version
    return $compiler_version
}

# check availability and location of tool
proc macports::get_tool_path {tool} {
    global macports::tool_path_cache

    if {[info exists tool_path_cache($tool)]} {
        return $tool_path_cache($tool)
    }

    # first try /usr/bin since this doesn't move around
    set toolpath "/usr/bin/${tool}"
    if {![file executable $toolpath]} {
        # Use xcode's xcrun to find the named tool.
        if {[catch {exec [findBinary xcrun $portutil::autoconf::xcrun_path] -find ${tool}} toolpath]} {
            set toolpath ""
        }
    }

    set tool_path_cache($tool) $toolpath
    return $toolpath
}

# read and cache archive_sites.conf (called from port1.0 code)
proc macports::get_archive_sites_conf_values {} {
    global macports::archive_sites_conf_values macports::autoconf::macports_conf_path
    if {![info exists archive_sites_conf_values]} {
        set archive_sites_conf_values {}
        set all_names {}
        set defaults_list {applications_dir /Applications/MacPorts prefix /opt/local type tbz2}
        if {$macports::os_platform eq "darwin" && $macports::os_major <= 12} {
            lappend defaults_list cxx_stdlib libstdc++ delete_la_files no
        } else {
            lappend defaults_list cxx_stdlib libc++ delete_la_files yes
        }
        array set defaults $defaults_list
        set conf_file ${macports_conf_path}/archive_sites.conf
        set conf_options {applications_dir cxx_stdlib delete_la_files frameworks_dir name prefix type urls}
        set line_re {^(\w+)([ \t]+(.*))?$}
        if {[file isfile $conf_file]} {
            set fd [open $conf_file r]
            while {[gets $fd line] >= 0} {
                if {[regexp $line_re $line match option ignore val] == 1} {
                    if {$option in $conf_options} {
                        if {$option eq "name"} {
                            set cur_name $val
                            lappend all_names $val
                        } elseif {[info exists cur_name]} {
                            set trimmedval [string trim $val]
                            if {$option eq "urls"} {
                                set processed_urls {}
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
# which denotes a maintainer's email address, 'github', which preceeds the
# GitHub username of the maintainer and 'keyword', which contains a special
# maintainer keyword such as 'openmaintainer' or 'nomaintainer'.
#
# @param list A list of obscured maintainers
# @return A list of associative arrays in serialized list format
proc macports::unobscure_maintainers {list} {
    return [macports_util::unobscure_maintainers $list]
}

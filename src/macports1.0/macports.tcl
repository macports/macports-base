# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# macports.tcl
# $Id$
#
# Copyright (c) 2002 Apple Computer, Inc.
# Copyright (c) 2004 - 2005 Paul Guyot, <pguyot@kallisys.net>.
# Copyright (c) 2004 - 2006 Ole Guldberg Jensen <olegb@opendarwin.org>.
# Copyright (c) 2004 - 2005 Robert Shaw <rshaw@opendarwin.org>
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
package provide macports 1.0
package require macports_dlist 1.0
package require macports_index 1.0
package require macports_util 1.0

namespace eval macports {
    namespace export bootstrap_options user_options portinterp_options open_mports ui_priorities port_stages 
    variable bootstrap_options "\
        portdbpath libpath binpath auto_path extra_env sources_conf prefix portdbformat \
        portinstalltype portarchivemode portarchivepath portarchivetype portautoclean \
        porttrace portverbose keeplogs destroot_umask variants_conf rsync_server rsync_options \
        rsync_dir startupitem_type place_worksymlink xcodeversion xcodebuildcmd \
        mp_remote_url mp_remote_submit_url configureccache configuredistcc configurepipe buildnicevalue buildmakejobs \
        applications_dir frameworks_dir developer_dir universal_archs build_arch \
        macportsuser proxy_override_env proxy_http proxy_https proxy_ftp proxy_rsync proxy_skip"
    variable user_options "submitter_name submitter_email submitter_key"
    variable portinterp_options "\
        portdbpath porturl portpath portbuildpath auto_path prefix prefix_frozen portsharepath \
        registry.path registry.format registry.installtype portarchivemode portarchivepath \
        portarchivetype portautoclean porttrace keeplogs portverbose destroot_umask rsync_server \
        rsync_options rsync_dir startupitem_type place_worksymlink macportsuser \
        mp_remote_url mp_remote_submit_url configureccache configuredistcc configurepipe buildnicevalue buildmakejobs \
        applications_dir current_stage frameworks_dir developer_dir universal_archs build_arch $user_options"

    # deferred options are only computed when needed.
    # they are not exported to the trace thread.
    # they are not exported to the interpreter in system_options array.
    variable portinterp_deferred_options "xcodeversion xcodebuildcmd"

    variable open_mports {}

    variable ui_priorities "debug info msg error warn any"
    variable port_stages "any fetch checksum"
    variable current_stage "main"
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
        if {$macports::ui_options($val) == "yes"} {
            return 1
        }
    }
    return 0
}


# global_options accessor
proc macports::global_option_isset {val} {
    if {[info exists macports::global_options($val)]} {
        if {$macports::global_options($val) == "yes"} {
            return 1
        }
    }
    return 0
}

proc macports::init_logging {portname} {
    global ::debuglog ::debuglogname macports::channels macports::portdbpath

    if {[getuid] == 0 && [geteuid] != 0} {
        seteuid 0
    }
    set logspath [file join $macports::portdbpath logs]
    if {([file exists $logspath] && ![file writable $logspath]) || (![file exists $logspath] && ![file writable $macports::portdbpath])} {
        ui_debug "logging disabled, can't write to $logspath"
        return
    }
    set logname [file join $logspath $portname]
    file mkdir $logname
    set logname [file join $logname "main.log"]
    ui_debug "logging to $logname"
    set ::debuglogname $logname

    # Recreate the file if already exists
    if {[file exists $::debuglogname]} {
        file delete -force $::debuglogname
    }
    set ::debuglog [open $::debuglogname w]
    puts $::debuglog "version:1"
    # Add our log-channel to all already initialized channels
    foreach key [array names channels] {
        set macports::channels($key) [concat $macports::channels($key) "debuglog"]
    }
}
proc macports::ch_logging {portname} {
    global ::debuglog ::debuglogname macports::channels macports::portdbpath

    set logname [file join $macports::portdbpath "logs/$portname"]
    file mkdir $logname
    set logname [file join $logname "main.log"]

    set ::debuglogname $logname
 
    # Recreate the file if already exists
    if {[file exists $::debuglogname]} {
        file delete -force $::debuglogname
    }
    set ::debuglog [open $::debuglogname w]
    puts $::debuglog "version:1"
} 

proc ui_phase {phase} {
    global macports::current_stage
    set macports::current_stage $phase
    if {$phase != "main"} {
        set cur_time [clock format [clock seconds] -format  {%+}]
        ui_debug "$phase phase started at $cur_time"
    }
}
proc ui_message {priority prefix stage args} {
    global macports::channels ::debuglog macports::current_stage
    foreach chan $macports::channels($priority) {
        if {[info exists ::debuglog] && ($chan == "debuglog")} {
            set chan $::debuglog
            if {[info exists macports::current_stage]} {
                set stage $macports::current_stage
            }
            set strprefix ":$priority:$stage "
            if {[lindex $args 0] == "-nonewline"} {
                puts -nonewline $chan "$strprefix[lindex $args 1]"
            } else {
                puts $chan "$strprefix[lindex $args 0]"
            }
 
        } else {
            if {[lindex $args 0] == "-nonewline"} {
                puts -nonewline $chan "$prefix[lindex $args 1]"
            } else {
                puts $chan "$prefix[lindex $args 0]"
            }
        }
    }
}
proc macports::ui_init {priority args} {
    global macports::channels ::debuglog
    set default_channel [macports::ui_channels_default $priority]
    # Get the list of channels.
    if {[llength [info commands ui_channels]] > 0} {
        set channels($priority) [ui_channels $priority]
    } else {
        set channels($priority) $default_channel
    }
    
    # if some priority initialized after log file is being created
    if [info exist ::debuglog] {
        set channels($priority) [concat $channels($priority) "debuglog"]
    }
    # Simplify ui_$priority.
    try {
        set prefix [ui_prefix $priority]
    } catch * {
        set prefix [ui_prefix_default $priority]
    }
    set stages {fetch checksum}
    try {
        eval ::ui_init $priority $prefix $channels($priority) $args
    } catch * {
        interp alias {} ui_$priority {} ui_message $priority $prefix ""
        foreach stage $stages {
            interp alias {} ui_${priority}_${stage} {} ui_message $priority $prefix $stage
        }
    }
    # Call ui_$priority
    eval ::ui_$priority $args
    
}

# Default implementation of ui_prefix
proc macports::ui_prefix_default {priority} {
    switch $priority {
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
            return ""
        }
    }
}

# Default implementation of ui_channels:
# ui_options(ports_debug) - If set, output debugging messages
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"
proc macports::ui_channels_default {priority} {
    switch $priority {
        debug {
            if {[ui_isset ports_debug]} {
                return {stderr}
            } else {
                return {}
            }
        }
        info {
            if {[ui_isset ports_verbose]} {
                return {stdout}
            } else {
                return {}
            }
        }
        msg {
            if {[ui_isset ports_quiet]} {
                return {}
            } else {
                return {stdout}
            }
        }
        warn -
        error {
            return {stderr}
        }
        default {
            return {stdout}
        }
    }
}

foreach priority ${macports::ui_priorities} {
    proc ui_$priority {args} [subst { eval macports::ui_init $priority \$args }]
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
    catch "tcl::puts $args"
}

# find a binary either in a path defined at MacPorts' configuration time
# or in the PATH environment variable through macports::binaryInPath (fallback)
proc macports::findBinary {prog {autoconf_hint ""}} {
    if {${autoconf_hint} != "" && [file executable ${autoconf_hint}]} {
        return ${autoconf_hint}
    } else {
        if {[catch {set cmd_path [macports::binaryInPath ${prog}]} result] == 0} {
            return ${cmd_path}
        } else {
            return -code error "${result} or at its MacPorts configuration time location, did you move it?"
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
    return [expr $$name]
}

# deferred and on-need extraction of xcodeversion and xcodebuildcmd.
proc macports::setxcodeinfo {name1 name2 op} {
    global macports::xcodeversion
    global macports::xcodebuildcmd

    trace remove variable macports::xcodeversion read macports::setxcodeinfo
    trace remove variable macports::xcodebuildcmd read macports::setxcodeinfo

    if {[catch {set xcodebuild [binaryInPath "xcodebuild"]}] == 0} {
        if {![info exists xcodeversion]} {
            # Determine xcode version (<= 2.0 or 2.1)
            if {[catch {set xcodebuildversion [exec xcodebuild -version]}] == 0} {
                if {[regexp "DevToolsCore-(.*); DevToolsSupport-(.*)" $xcodebuildversion devtoolscore_v devtoolssupport_v] == 1} {
                    if {$devtoolscore_v >= 620.0 && $devtoolssupport_v >= 610.0} {
                        # for now, we don't need to distinguish 2.1 from 2.1 or higher.
                        set macports::xcodeversion "2.1"
                    } else {
                        set macports::xcodeversion "2.0orlower"
                    }
                } else {
                    set macports::xcodeversion "2.0orlower"
                }
            } else {
                set macports::xcodeversion "2.0orlower"
            }
        }

        if {![info exists xcodebuildcmd]} {
            set macports::xcodebuildcmd "xcodebuild"
        }
    } elseif {[catch {set pbxbuild [binaryInPath "pbxbuild"]}] == 0} {
        if {![info exists xcodeversion]} {
            set macports::xcodeversion "pb"
        }
        if {![info exists xcodebuildcmd]} {
            set macports::xcodebuildcmd "pbxbuild"
        }
    } else {
        if {![info exists xcodeversion]} {
            set macports::xcodeversion "none"
        }
        if {![info exists xcodebuildcmd]} {
            set macports::xcodebuildcmd "none"
        }
    }
}

proc mportinit {{up_ui_options {}} {up_options {}} {up_variations {}}} {
    if {$up_ui_options eq ""} {
        array set macports::ui_options {}
    } else {
        upvar $up_ui_options temp_ui_options
        array set macports::ui_options [array get temp_ui_options]
    }
    if {$up_options eq ""} {
        array set macports::global_options {}
    } else {
        upvar $up_options temp_options
        array set macports::global_options [array get temp_options]
    }
    if {$up_variations eq ""} {
        array set variations {}
    } else {
        upvar $up_variations variations
    }

    global auto_path env tcl_platform
    global macports::autoconf::macports_conf_path
    global macports::macports_user_dir
    global macports::bootstrap_options
    global macports::user_options
    global macports::extra_env
    global macports::portconf
    global macports::portdbpath
    global macports::portsharepath
    global macports::registry.format
    global macports::registry.path
    global macports::sources
    global macports::sources_default
    global macports::sources_conf
    global macports::destroot_umask
    global macports::libpath
    global macports::prefix
    global macports::macportsuser
    global macports::prefix_frozen
    global macports::registry.installtype
    global macports::rsync_dir
    global macports::rsync_options
    global macports::rsync_server
    global macports::variants_conf
    global macports::xcodebuildcmd
    global macports::xcodeversion
    global macports::configureccache
    global macports::configuredistcc
    global macports::configurepipe
    global macports::buildnicevalue
    global macports::buildmakejobs
    global macports::universal_archs
    global macports::build_arch

    # Set the system encoding to utf-8
    encoding system utf-8

    # Ensure that the macports user directory exists if HOME is defined
    if {[info exists env(HOME)]} {
        set macports::macports_user_dir [file normalize $macports::autoconf::macports_user_dir]
    } else {
        # Otherwise define the user directory as a direcotory that will never exist
        set macports::macports_user_dir "/dev/null/NO_HOME_DIR"
    }

    # Configure the search path for configuration files
    set conf_files ""
    lappend conf_files "${macports_conf_path}/macports.conf"
    if { [file isdirectory $macports_user_dir] } {
        lappend conf_files "${macports_user_dir}/macports.conf"
    }
    if {[info exists env(PORTSRC)]} {
        set PORTSRC $env(PORTSRC)
        lappend conf_files ${PORTSRC}
    }

    # Process the first configuration file we find on conf_files list
    foreach file $conf_files {
        if [file exists $file] {
            set portconf $file
            set fd [open $file r]
            while {[gets $fd line] >= 0} {
                if {[regexp {^(\w+)([ \t]+(.*))?$} $line match option ignore val] == 1} {
                    if {[lsearch $bootstrap_options $option] >= 0} {
                        set macports::$option [string trim $val]
                        global macports::$option
                    }
                }
            }
            close $fd
        }
    }

    # Process per-user only settings
    set per_user "${macports_user_dir}/user.conf"
    if [file exists $per_user] {
        set fd [open $per_user r]
        while {[gets $fd line] >= 0} {
            if {[regexp {^(\w+)([ \t]+(.*))?$} $line match option ignore val] == 1} {
                if {[lsearch $user_options $option] >= 0} {
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
    set fd [open $sources_conf r]
    while {[gets $fd line] >= 0} {
        set line [string trimright $line]
        if {![regexp {^\s*#|^$} $line]} {
            if {[regexp {^([\w-]+://\S+)(?:\s+\[(\w+(?:,\w+)*)\])?$} $line _ url flags]} {
                set flags [split $flags ,]
                foreach flag $flags {
                    if {[lsearch -exact [list nosync default] $flag] == -1} {
                        ui_warn "$sources_conf source '$line' specifies invalid flag '$flag'"
                    }
                    if {$flag == "default"} {
                        if {[info exists sources_default]} {
                            ui_warn "More than one default port source is defined."
                        }
                        set sources_default [concat [list $url] $flags]
                    }
                }
                lappend sources [concat [list $url] $flags]
            } else {
                ui_warn "$sources_conf specifies invalid source '$line', ignored."
            }
        }
    }
    close $fd
    # Make sure the default port source is defined. Otherwise
    # [macports::getportresourcepath] fails when the first source doesn't
    # contain _resources.
    if {![info exists sources_default]} {
        ui_warn "No default port source specified in $sources_conf, using last source as default"
        set sources_default [lindex $sources end]
    }

    if {![info exists sources]} {
        if {[file isdirectory ports]} {
            set sources "file://[pwd]/ports"
        } else {
            return -code error "No sources defined in $sources_conf"
        }
    }

    if {[info exists variants_conf]} {
        if {[file exist $variants_conf]} {
            set fd [open $variants_conf r]
            while {[gets $fd line] >= 0} {
                set line [string trimright $line]
                if {![regexp {^[\ \t]*#.*$|^$} $line]} {
                    foreach arg [split $line " \t"] {
                        if {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
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
    array set macports::global_variations [mport_filtervariants [array get variations] yes]

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

    set registry.path $portdbpath

    # Format for receipts, can currently be either "flat" or "sqlite"
    if {[info exists portdbformat]} {
        if { $portdbformat == "sqlite" } {
            return -code error "SQLite is not yet supported for registry storage."
        }
        set registry.format receipt_${portdbformat}
    } else {
        set registry.format receipt_flat
    }

    # Installation type, whether to use port "images" or install "direct"
    if {[info exists portinstalltype]} {
        set registry.installtype $portinstalltype
    } else {
        set registry.installtype image
    }

    # Autoclean mode, whether to automatically call clean after "install"
    if {![info exists portautoclean]} {
        set macports::portautoclean "yes"
        global macports::portautoclean
    }
	# keeplogs option
   	if {![info exists keeplogs]} {
        set macports::keeplogs "yes"
        global macports::keeplogs
    }
   
    # Check command line override for autoclean
    if {[info exists macports::global_options(ports_autoclean)]} {
        if {![string equal $macports::global_options(ports_autoclean) $portautoclean]} {
            set macports::portautoclean $macports::global_options(ports_autoclean)
        }
    }
    # Trace mode, whether to use darwintrace to debug ports.
    if {![info exists porttrace]} {
        set macports::porttrace "no"
        global macports::porttrace
    }
    # Check command line override for trace
    if {[info exists macports::global_options(ports_trace)]} {
        if {![string equal $macports::global_options(ports_trace) $porttrace]} {
            set macports::porttrace $macports::global_options(ports_trace)
        }
    }

    # Duplicate prefix into prefix_frozen, so that port actions
    # can always get to the original prefix, even if a portfile overrides prefix
    set macports::prefix_frozen $prefix

    # Export verbosity.
    if {![info exists portverbose]} {
        set macports::portverbose "no"
        global macports::portverbose
    }
    if {[info exists macports::ui_options(ports_verbose)]} {
        if {![string equal $macports::ui_options(ports_verbose) $portverbose]} {
            set macports::portverbose $macports::ui_options(ports_verbose)
        }
    }

    # Archive mode, whether to create/use binary archive packages
    if {![info exists portarchivemode]} {
        set macports::portarchivemode "no"
        global macports::portarchivemode
    }

    # Archive path, where to store/retrieve binary archive packages
    if {![info exists portarchivepath]} {
        set macports::portarchivepath [file join $portdbpath packages]
        global macports::portarchivepath
    }
    if {$portarchivemode == "yes"} {
        if {![file isdirectory $portarchivepath]} {
            if {![file exists $portarchivepath]} {
                if {![file owned $portdbpath]} {
                    file lstat $portdbpath stat
                    return -code error "insufficient privileges for portdbpath $portdbpath (uid $stat(uid)); cannot create portarchivepath"
                } elseif {[catch {file mkdir $portarchivepath} result]} {
                    return -code error "portarchivepath $portarchivepath does not exist and could not be created: $result"
                }
            }
        }
        if {![file isdirectory $portarchivepath]} {
            return -code error "$portarchivepath is not a directory. Please create the directory $portarchivepath and try again"
        }
    }

    # Archive type, what type of binary archive to use (CPIO, gzipped
    # CPIO, XAR, etc.)
    if {![info exists portarchivetype]} {
        set macports::portarchivetype "tgz"
        global macports::portarchivetype
    }
    # Convert archive type to a list for multi-archive support, colon or
    # comma separators indicates to use multiple archive formats
    # (reading and writing)
    set macports::portarchivetype [split $portarchivetype {:,}]

    # Set rync options
    if {![info exists rsync_server]} {
        set macports::rsync_server rsync.macports.org
        global macports::rsync_server
    }
    if {![info exists rsync_dir]} {
        set macports::rsync_dir release/base/
        global macports::rsync_dir
    }
    if {![info exists rsync_options]} {
        set rsync_options "-rtzv --delete-after"
        global macports::rsync_options
    }

    set portsharepath ${prefix}/share/macports
    if {![file isdirectory $portsharepath]} {
        return -code error "Data files directory '$portsharepath' must exist"
    }

    if {![info exists libpath]} {
        set libpath "${prefix}/share/macports/Tcl"
    }

    if {![info exists binpath]} {
        set env(PATH) "${prefix}/bin:${prefix}/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
    } else {
        set env(PATH) "$binpath"
    }

    # Set startupitem default type (can be overridden by portfile)
    if {![info exists macports::startupitem_type]} {
        set macports::startupitem_type "default"
    }

    # Default place_worksymlink
    if {![info exists macports::place_worksymlink]} {
        set macports::place_worksymlink yes
    }

    # Default mp remote options
    if {![info exists macports::mp_remote_url]} {
        set macports::mp_remote_url "http://db.macports.org"
    }
    if {![info exists macports::mp_remote_submit_url]} {
        set macports::mp_remote_submit_url "${macports::mp_remote_url}/submit"
    }

    # Default mp configure options
    if {![info exists macports::configureccache]} {
        set macports::configureccache no
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

    # Default Xcode Tools path
    if {![info exists macports::developer_dir]} {
        set macports::developer_dir "/Developer"
    }

    # Default mp universal options
    if {![info exists macports::universal_archs]} {
        if {[lindex [split $tcl_platform(osVersion) .] 0] >= 10} {
            set macports::universal_archs {x86_64 i386}
        } else {
            set macports::universal_archs {i386 ppc}
        }
    }
    
    # Default arch to build for
    if {![info exists macports::build_arch]} {
        if {$tcl_platform(os) == "Darwin"} {
            if {[lindex [split $tcl_platform(osVersion) .] 0] >= 10} {
                if {[sysctl hw.cpu64bit_capable] == 1} {
                    set macports::build_arch x86_64
                } else {
                    set macports::build_arch i386
                }
            } else {
                if {$tcl_platform(machine) == "Power Macintosh"} {
                    set macports::build_arch ppc
                } else {
                    set macports::build_arch i386
                }
            }
        } else {
            set macports::build_arch ""
        }
    }

    # ENV cleanup.
    set keepenvkeys {
        DISPLAY DYLD_FALLBACK_FRAMEWORK_PATH
        DYLD_FALLBACK_LIBRARY_PATH DYLD_FRAMEWORK_PATH
        DYLD_LIBRARY_PATH DYLD_INSERT_LIBRARIES
        HOME JAVA_HOME MASTER_SITE_LOCAL
        PATCH_SITE_LOCAL PATH PORTSRC RSYNC_PROXY TMP TMPDIR
        USER GROUP
        http_proxy HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
        COLUMNS LINES
    }
    if {[info exists extra_env]} {
        set keepenvkeys [concat ${keepenvkeys} ${extra_env}]
    }

    foreach envkey [array names env] {
        if {[lsearch $keepenvkeys $envkey] == -1} {
            array unset env $envkey
        }
    }

    if {![info exists xcodeversion] || ![info exists xcodebuildcmd]} {
        # We'll resolve these later (if needed)
        trace add variable macports::xcodeversion read macports::setxcodeinfo
        trace add variable macports::xcodebuildcmd read macports::setxcodeinfo
    }

    # Set the default umask
    if {![info exists destroot_umask]} {
        set destroot_umask 022
    }

    if {[info exists master_site_local] && ![info exists env(MASTER_SITE_LOCAL)]} {
        set env(MASTER_SITE_LOCAL) "$master_site_local"
    }

    if {[file isdirectory $libpath]} {
        lappend auto_path $libpath
        set macports::auto_path $auto_path

        # XXX: not sure if this the best place, but it needs to happen
        # early, and after auto_path has been set.  Or maybe Pextlib
        # should ship with macports1.0 API?
        package require Pextlib 1.0
        package require registry 1.0
    } else {
        return -code error "Library directory '$libpath' must exist"
    }

    # unset environment an extra time, to work around bugs in Leopard Tcl
    foreach envkey [array names env] {
        if {[lsearch $keepenvkeys $envkey] == -1} {
            unsetenv $envkey
        }
    }

    # Proxy handling (done this late since Pextlib is needed)
    if {![info exists proxy_override_env] } {
        set proxy_override_env "no"
    }
    array set sysConfProxies [get_systemconfiguration_proxies]
    if {![info exists env(http_proxy)] || $proxy_override_env == "yes" } {
        if {[info exists proxy_http]} {
            set env(http_proxy) $proxy_http
        } elseif {[info exists sysConfProxies(proxy_http)]} {
            set env(http_proxy) $sysConfProxies(proxy_http)
        }
    }
    if {![info exists env(HTTPS_PROXY)] || $proxy_override_env == "yes" } {
        if {[info exists proxy_https]} {
            set env(HTTPS_PROXY) $proxy_https
        } elseif {[info exists sysConfProxies(proxy_https)]} {
            set env(HTTPS_PROXY) $sysConfProxies(proxy_https)
        }
    }
    if {![info exists env(FTP_PROXY)] || $proxy_override_env == "yes" } {
        if {[info exists proxy_ftp]} {
            set env(FTP_PROXY) $proxy_ftp
        } elseif {[info exists sysConfProxies(proxy_ftp)]} {
            set env(FTP_PROXY) $sysConfProxies(proxy_ftp)
        }
    }
    if {![info exists env(RSYNC_PROXY)] || $proxy_override_env == "yes" } {
        if {[info exists proxy_rsync]} {
            set env(RSYNC_PROXY) $proxy_rsync
        }
    }
    if {![info exists env(NO_PROXY)] || $proxy_override_env == "yes" } {
        if {[info exists proxy_skip]} {
            set env(NO_PROXY) $proxy_skip
        } elseif {[info exists sysConfProxies(proxy_skip)]} {
            set env(NO_PROXY) $sysConfProxies(proxy_skip)
        }
    }

    # load the quick index
    _mports_load_quickindex

    set default_source_url [lindex ${sources_default} 0]
    if {[macports::getprotocol $default_source_url] == "file" || [macports::getprotocol $default_source_url] == "rsync"} {
        set default_portindex [macports::getindex $default_source_url]
        if {[file exists $default_portindex] && [expr [clock seconds] - [file mtime $default_portindex]] > 1209600} {
            ui_warn "port definitions are more than two weeks old, consider using selfupdate"
        }
    }
}

proc macports::worker_init {workername portpath porturl portbuildpath options variations} {
    global macports::portinterp_options macports::portinterp_deferred_options registry.installtype

    # Hide any Tcl commands that should be inaccessible to port1.0 and Portfiles
    # exit: It should not be possible to exit the interpreter
    interp hide $workername exit

    # cd: This is necessary for some code in port1.0, but should be hidden
    interp eval $workername "rename cd _cd"

    # Tell the sub interpreter about all the Tcl packages we already
    # know about so it won't glob for packages.
    foreach pkgName [package names] {
        foreach pkgVers [package versions $pkgName] {
            set pkgLoadScript [package ifneeded $pkgName $pkgVers]
            $workername eval "package ifneeded $pkgName $pkgVers {$pkgLoadScript}"
        }
    }

    # Create package require abstraction procedure
    $workername eval "proc PortSystem \{version\} \{ \n\
            package require port \$version \}"

    # Clearly separate slave interpreters and the master interpreter.
    $workername alias mport_exec mportexec
    $workername alias mport_open mportopen
    $workername alias mport_close mportclose
    $workername alias mport_lookup mportlookup
    $workername alias ui_phase ui_phase

    # instantiate the UI call-backs
    foreach priority ${macports::ui_priorities} {
        $workername alias ui_$priority ui_$priority
        foreach stage ${macports::port_stages} {
            $workername alias ui_${priority}_${stage} ui_${priority}_${stage}
        }
 
    }

    $workername alias ui_prefix ui_prefix
    $workername alias ui_channels ui_channels
    
    $workername alias ui_warn_once ui_warn_once

    # Export some utility functions defined here.
    $workername alias macports_create_thread macports::create_thread
    $workername alias getportworkpath_from_buildpath macports::getportworkpath_from_buildpath
    $workername alias getportresourcepath macports::getportresourcepath
    $workername alias getdefaultportresourcepath macports::getdefaultportresourcepath
    $workername alias getprotocol macports::getprotocol
    $workername alias getportdir macports::getportdir
    $workername alias findBinary macports::findBinary
    $workername alias binaryInPath macports::binaryInPath
    $workername alias sysctl sysctl
    $workername alias realpath realpath

    # New Registry/Receipts stuff
    $workername alias registry_new registry::new_entry
    $workername alias registry_open registry::open_entry
    $workername alias registry_write registry::write_entry
    $workername alias registry_prop_store registry::property_store
    $workername alias registry_prop_retr registry::property_retrieve
    $workername alias registry_delete registry::delete_entry
    $workername alias registry_exists registry::entry_exists
    $workername alias registry_exists_for_name registry::entry_exists_for_name
    $workername alias registry_activate portimage::activate
    $workername alias registry_deactivate portimage::deactivate
    $workername alias registry_register_deps registry::register_dependencies
    $workername alias registry_fileinfo_for_index registry::fileinfo_for_index
    $workername alias registry_bulk_register_files registry::register_bulk_files
    $workername alias registry_installed registry::installed
    $workername alias registry_active registry::active

    # deferred options processing.
    $workername alias getoption macports::getoption

    foreach opt $portinterp_options {
        if {![info exists $opt]} {
            global macports::$opt
        }
        if {[info exists $opt]} {
            $workername eval set system_options($opt) \{[set $opt]\}
            $workername eval set $opt \{[set $opt]\}
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
        $workername eval set $opt "?"
    }

    foreach {opt val} $options {
        $workername eval set user_options($opt) $val
        $workername eval set $opt $val
    }

    foreach {var val} $variations {
        $workername eval set variations($var) $val
    }

    if { [info exists registry.installtype] } {
        $workername eval set installtype ${registry.installtype}
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

proc macports::fetch_port {url} {
    global macports::portdbpath tcl_platform
    set fetchdir [file join $portdbpath portdirs]
    set fetchfile [file tail $url]
    file mkdir $fetchdir
    if {![file writable $fetchdir]} {
        return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }
    if {[catch {curl fetch $url [file join $fetchdir $fetchfile]} result]} {
        return -code error "Port remote fetch failed: $result"
    }
    cd $fetchdir
    if {[catch {exec [findBinary tar $macports::autoconf::tar_path] -zxf $fetchfile} result]} {
        return -code error "Port extract failed: $result"
    }
    if {[regexp {(.+).tgz} $fetchfile match portdir] != 1} {
        return -code error "Can't decipher portdir from $fetchfile"
    }
    return [file join $fetchdir $portdir]
}

proc macports::getprotocol {url} {
    if {[regexp {(?x)([^:]+)://.+} $url match protocol] == 1} {
        return ${protocol}
    } else {
        return -code error "Can't parse url $url"
    }
}

# XXX: this really needs to be rethought in light of the remote index
# I've added the destdir parameter.  This is the location a remotely
# fetched port will be downloaded to (currently only applies to
# mports:// sources).
proc macports::getportdir {url {destdir "."}} {
    set protocol [macports::getprotocol $url]
    switch ${protocol} {
        file {
            return [file normalize [string range $url [expr [string length $protocol] + 3] end]]
        }
        mports {
            return [macports::index::fetch_port $url $destdir]
        }
        https -
        http -
        ftp {
            return [macports::fetch_port $url]
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
proc macports::getportresourcepath {url {path ""} {fallback yes}} {
    global macports::sources_default

    set protocol [getprotocol $url]

    switch -- ${protocol} {
        file {
            set proposedpath [file normalize [file join [getportdir $url] .. ..]]
        }
        default {
            set proposedpath [getsourcepath $url]
        }
    }

    # append requested path
    set proposedpath [file join $proposedpath _resources $path]

    if {$fallback == "yes" && ![file exists $proposedpath]} {
        return [getdefaultportresourcepath $path]
    }

    return $proposedpath
}

##
# Get the path to the _resources directory of the default source
#
# @param path path in _resources we are interested in
# @return path to the _resources directory of the default source
proc macports::getdefaultportresourcepath {{path ""}} {
    global macports::sources_default

    set default_source_url [lindex ${sources_default} 0]
    if {[getprotocol $default_source_url] == "file"} {
        set proposedpath [getportdir $default_source_url]
    } else {
        set proposedpath [getsourcepath $default_source_url]
    }

    # append requested path
    set proposedpath [file join $proposedpath _resources $path]

    return $proposedpath
}


# mport_filtervariants
# returns the given list of variants with implicitly-set ones removed
proc mport_filtervariants {variations {warn yes}} {
    # Iterate through the variants, filtering out
    # implicit ones. At the moment, the only implicit variants are
    # platform variants.
    set filteredvariations {}

    foreach {variation value} $variations {
        switch -regexp $variation {
            ^(pure)?darwin         -
            ^(free|net|open){1}bsd -
            ^i386                  -
            ^linux                 -
            ^macosx                -
            ^powerpc               -
            ^solaris               -
            ^sunos {
                if {$warn} {
                    ui_warn "Implicit variants should not be explicitly set or unset. $variation will be ignored."
                }
            }
            default {
                lappend filteredvariations $variation $value
            }
        }
    }
    return $filteredvariations
}


# mportopen
# Opens a MacPorts portfile specified by a URL.  The Portfile is
# opened with the given list of options and variations.  The result
# of this function should be treated as an opaque handle to a
# MacPorts Portfile.

proc mportopen {porturl {options ""} {variations ""} {nocache ""}} {
    global macports::portdbpath macports::portconf macports::open_mports auto_path

    # Look for an already-open MPort with the same URL.
    # XXX: should compare options and variations here too.
    # if found, return the existing reference and bump the refcount.
    if {$nocache != ""} {
        set mport {}
    } else {
        set mport [dlist_search $macports::open_mports porturl $porturl]
    }
    if {$mport != {}} {
        set refcnt [ditem_key $mport refcnt]
        incr refcnt
        ditem_key $mport refcnt $refcnt
        return $mport
    }

    array set options_array $options
    if {[info exists options_array(portdir)]} {
        set portdir $options_array(portdir)
    } else {
        set portdir ""
    }

    set portpath [macports::getportdir $porturl $portdir]
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

    $workername eval source Portfile

    # add the default universal variant if appropriate, and set up flags that
    # are conditional on whether universal is set
    $workername eval universal_setup

    # evaluate the variants
    if {[$workername eval eval_variants variations] != 0} {
        mportclose $mport
        error "Error evaluating variants"
    }

    ditem_key $mport provides [$workername eval return \$name]

    return $mport
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
        if {[file isdirectory $pathToCategory] && [string index [file tail $pathToCategory] 0] != "_"} {
            # Iterate on port directories.
            foreach port [lsort -increasing -unique [readdir $pathToCategory]] {
                set pathToPort [file join $pathToCategory $port]
                if {[file isdirectory $pathToPort] &&
                  [file exists [file join $pathToPort "Portfile"]]} {
                    # Call the function.
                    $func [file join $category $port]

                    # Restore the current directory because some
                    # functions changes it.
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
    }
    if {$return_match} {
        if {$found} {
            return [file join $path $filename]
        } else {
            return ""
        }
    } else {
        return $found
    }
}

### _libtest is private; subject to change without notice
# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
#   -- Since /usr/local is bad, using /lib:/usr/lib only.
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc _libtest {mport depspec {return_match 0}} {
    global env tcl_platform
    set depline [lindex [split $depspec :] 1]
    set prefix [_mportkey $mport prefix]
    set frameworks_dir [_mportkey $mport frameworks_dir]

    if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FRAMEWORK_PATH)
    } else {
        lappend search_path ${frameworks_dir} /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
    }
    if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
    }
    if {[info exists env(DYLD_LIBRARY_PATH)]} {
        lappend search_path $env(DYLD_LIBRARY_PATH)
    }
    lappend search_path /lib /usr/lib ${prefix}/lib
    if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
        lappend search_path $env(DYLD_FALLBACK_LIBRARY_PATH)
    }

    set i [string first . $depline]
    if {$i < 0} {set i [string length $depline]}
    set depname [string range $depline 0 [expr $i - 1]]
    set depversion [string range $depline $i end]
    regsub {\.} $depversion {\.} depversion
    if {$tcl_platform(os) == "Darwin"} {
        set depregex \^${depname}${depversion}\\.dylib\$
    } else {
        set depregex \^${depname}\\.so${depversion}\$
    }

    return [_mportsearchpath $depregex $search_path 0 $return_match]
}

### _bintest is private; subject to change without notice

proc _bintest {mport depspec {return_match 0}} {
    global env
    set depregex [lindex [split $depspec :] 1]
    set prefix [_mportkey $mport prefix]

    set search_path [split $env(PATH) :]

    set depregex \^$depregex\$

    return [_mportsearchpath $depregex $search_path 1 $return_match]
}

### _pathtest is private; subject to change without notice

proc _pathtest {mport depspec {return_match 0}} {
    global env
    set depregex [lindex [split $depspec :] 1]
    set prefix [_mportkey $mport prefix]

    # separate directory from regex
    set fullname $depregex

    regexp {^(.*)/(.*?)$} "$fullname" match search_path depregex

    if {[string index $search_path 0] != "/"} {
        # Prepend prefix if not an absolute path
        set search_path "${prefix}/${search_path}"
    }

    set depregex \^$depregex\$

    return [_mportsearchpath $depregex $search_path 0 $return_match]
}

### _porttest is private; subject to change without notice

proc _porttest {mport depspec} {
    # We don't actually look for the port, but just return false
    # in order to let the mportdepends handle the dependency
    return 0
}

### _mportinstalled is private; may change without notice

# Determine if a port is already *installed*, as in "in the registry".
proc _mportinstalled {mport} {
    # Check for the presence of the port in the registry
    set workername [ditem_key $mport workername]
    return [$workername eval registry_exists_for_name \${name}]
}

# Determine if a port is active (only for image mode)
proc _mportactive {mport} {
    set workername [ditem_key $mport workername]
    if {[catch {set reslist [$workername eval registry_active \${name}]}]} {
        return 0
    } else {
        return [expr [llength $reslist] > 0]
    }
}

# Determine if the named port is active (only for image mode)
proc _portnameactive {portname} {
    if {[catch {set reslist [registry::active $portname]}]} {
        return 0
    } else {
        return [expr [llength $reslist] > 0]
    }
}

### _mportispresent is private; may change without notice

# Determine if some depspec is satisfied or if the given port is installed
# (and active, if we're in image mode).
# We actually start with the registry (faster?)
#
# mport     the port declaring the dep (context in which to evaluate $prefix etc)
# depspec   the dependency test specification (path, bin, lib, etc.)
proc _mportispresent {mport depspec} {
    set portname [lindex [split $depspec :] end]
    ui_debug "Searching for dependency: $portname"
    if {[string equal ${macports::registry.installtype} "image"]} {
        set res [_portnameactive $portname]
    } else {
        set res [registry::entry_exists_for_name $portname]
    }
    if {$res != 0} {
        ui_debug "Found Dependency: receipt exists for $portname"
        return 1
    } else {
        # The receipt test failed, use one of the depspec regex mechanisms
        ui_debug "Didn't find receipt, going to depspec regex for: $portname"
        set type [lindex [split $depspec :] 0]
        switch $type {
            lib { return [_libtest $mport $depspec] }
            bin { return [_bintest $mport $depspec] }
            path { return [_pathtest $mport $depspec] }
            port { return [_porttest $mport $depspec] }
            default {return -code error "unknown depspec type: $type"}
        }
        return 0
    }
}

### _mportconflictsinstalled is private; may change without notice

# Determine if the port, per the conflicts option, has any conflicts with
# what is installed.
#
# mport   the port to check for conflicts
# Returns a list of which installed ports conflict, or an empty list if none
proc _mportconflictsinstalled {mport conflictinfo} {
    set conflictlist {}
    if {[llength $conflictinfo] > 0} {
        ui_debug "Checking for conflicts against [_mportkey $mport name]"
        foreach conflictport ${conflictinfo} {
            if {[_mportispresent $mport port:${conflictport}]} {
                lappend conflictlist $conflictport
            }
        }
    } else {
        ui_debug "[_mportkey $mport name] has no conflicts"
    }

    return $conflictlist
}


### _mportexec is private; may change without notice

proc _mportexec {target mport} {
    global ::debuglog
    if {[info exists ::debuglog]} {
        set previouslog $::debuglog
    }
    set portname [_mportkey $mport name]
    ui_debug "Starting logging for $portname"
    macports::ch_logging $portname
    # xxx: set the work path?
    set workername [ditem_key $mport workername]
    if {![catch {$workername eval check_variants variations $target} result] && $result == 0 &&
        ![catch {$workername eval eval_targets $target} result] && $result == 0} {
        # If auto-clean mode, clean-up after dependency install
        if {[string equal ${macports::portautoclean} "yes"]} {
            # Make sure we are back in the port path before clean
            # otherwise if the current directory had been changed to
            # inside the port,  the next port may fail when trying to
            # install because [pwd] will return a "no file or directory"
            # error since the directory it was in is now gone.
            set portpath [ditem_key $mport portpath]
            catch {cd $portpath}
            $workername eval eval_targets clean
        }
        if {[info exists previouslog]} {
            set ::debuglog $previouslog
        }
        return 0
    } else {
        # An error occurred.
        if {[info exists previouslog]} {
            set ::debuglog $previouslog
        }
        return 1
    }
}

# mportexec
# Execute the specified target of the given mport.
proc mportexec {mport target} {
    global macports::registry.installtype

    set workername [ditem_key $mport workername]

    # check variants
    if {[$workername eval check_variants variations $target] != 0} {
        return 1
    }
    set portname [_mportkey $mport name]
    macports::init_logging $portname

    # Before we build the port, we must build its dependencies.
    # XXX: need a more general way of comparing against targets
    set dlist {}
    if {   $target == "fetch" || $target == "checksum"
        || $target == "extract" || $target == "patch"
        || $target == "configure" || $target == "build"
        || $target == "test"
        || $target == "destroot" || $target == "install"
        || $target == "archive"
        || $target == "dmg" || $target == "mdmg"
        || $target == "pkg" || $target == "mpkg"
        || $target == "rpm" || $target == "dpkg"
        || $target == "srpm"|| $target == "portpkg" } {

        # upgrade dependencies that are already installed
        if {![macports::global_option_isset ports_nodeps]} {
            macports::_upgrade_mport_deps $mport $target
        }

        ui_msg -nonewline "--->  Computing dependencies for [_mportkey $mport name]"
        if {[macports::ui_isset ports_debug]} {
            # play nice with debug messages
            ui_msg ""
        }
        if {[mportdepends $mport $target] != 0} {
            return 1
        }
        if {![macports::ui_isset ports_debug]} {
            ui_msg ""
        }

        # Select out the dependents along the critical path,
        # but exclude this mport, we might not be installing it.
        set dlist [dlist_append_dependents $macports::open_mports $mport {}]

        dlist_delete dlist $mport

        # install them
        # xxx: as with below, this is ugly.  and deps need to be fixed to
        # understand Port Images before this can get prettier
        if { [string equal ${macports::registry.installtype} "image"] } {
            set result [dlist_eval $dlist _mportactive [list _mportexec "activate"]]
        } else {
            set result [dlist_eval $dlist _mportinstalled [list _mportexec "install"]]
        }

        if {$result != {}} {
            set errstring "The following dependencies failed to build:"
            foreach ditem $result {
                append errstring " [ditem_key $ditem provides]"
            }
            ui_error $errstring
            return 1
        }

        # Close the dependencies, we're done installing them.
        foreach ditem $dlist {
            mportclose $ditem
        }
    }

    # If we're doing an install, check if we should clean after
    set clean 0
    if {[string equal ${macports::portautoclean} "yes"] && [string equal $target "install"] } {
        set clean 1
    }

    # If we're doing image installs, then we should activate after install
    # xxx: This isn't pretty
    if { [string equal ${macports::registry.installtype} "image"] && [string equal $target "install"] } {
        set target activate
    }

    # Build this port with the specified target
    set result [$workername eval eval_targets $target]

    # If auto-clean mode and successful install, clean-up after install
    if {$result == 0 && $clean == 1} {
        # Make sure we are back in the port path, just in case
        set portpath [ditem_key $mport portpath]
        catch {cd $portpath}
        $workername eval eval_targets clean
    }
    
    global ::debuglogname
    if {$result != 0 && ![macports::ui_isset ports_quiet] && [info exists ::debuglogname]} {
        ui_msg "Log for $portname is at: $::debuglogname"
    }

    return $result
}

# upgrade any dependencies of mport that are installed and needed for target
proc macports::_upgrade_mport_deps {mport target} {
    set options [ditem_key $mport options]
    set deptypes [macports::_deptypes_for_target $target]
    array set portinfo [mportinfo $mport]
    set depends {}
    array set depscache {}

    foreach deptype $deptypes {
        # Add to the list of dependencies if the option exists and isn't empty.
        if {[info exists portinfo($deptype)] && $portinfo($deptype) != ""} {
            set depends [concat $depends $portinfo($deptype)]
        }
    }
    
    foreach depspec $depends {
        set dep_portname [_get_dep_port $mport $depspec]
        if {$dep_portname != "" && ![info exists depscache(port:$dep_portname)] && [registry::entry_exists_for_name $dep_portname]} {
            set status [macports::upgrade $dep_portname "port:$dep_portname" {} $options depscache]
            # status 2 means the port was not found in the index
            if {$status != 0 && $status != 2 && ![macports::ui_isset ports_processall]} {
                return -code error "upgrade $dep_portname failed"
            }
        }
    }
}

# returns the name of the port that will actually be satisfying $depspec
proc macports::_get_dep_port {mport depspec} {
    set speclist [split $depspec :]
    set portname [lindex $speclist end]
    if {[string equal ${macports::registry.installtype} "image"]} {
        set res [_portnameactive $portname]
    } else {
        set res [registry::entry_exists_for_name $portname]
    }
    if {$res != 0} {
        return $portname
    }
    
    set depfile ""
    switch [lindex $speclist 0] {
        bin {
            set depfile [_bintest $mport $depspec 1]
        }
        lib {
            set depfile [_libtest $mport $depspec 1]
        }
        path {
            set depfile [_pathtest $mport $depspec 1]
        }
    }
    if {$depfile == ""} {
        return $portname
    } else {
        set theport [registry::file_registered $depfile]
        if {$theport != 0} {
            return $theport
        } else {
            return ""
        }
    }
}

proc macports::getsourcepath {url} {
    global macports::portdbpath

    set source_path [split $url ://]

    if {[_source_is_snapshot $url]} {
        # daily snapshot tarball
        return [file join $portdbpath sources [join [lrange $source_path 3 end-1] /] ports]
    }

    return [file join $portdbpath sources [lindex $source_path 3] [lindex $source_path 4] [lindex $source_path 5]]
}

##
# Checks whether a supplied source URL is for a daily snapshot tarball
# (private)
#
# @param url source URL to check
# @return a list containing filename and extension or an empty list
proc _source_is_snapshot {url {filename ""} {extension ""}} {
    upvar $filename myfilename
    upvar $extension myextension

    if {[regexp {^(?:https?|ftp)://.+/(.+\.(tar\.gz|tar\.bz2))$} $url -> f e]} {
        set myfilename $f
        set myextension $e

        return 1
    }

    return 0
}

proc macports::getportbuildpath {id} {
    global macports::portdbpath
    regsub {://} $id {.} port_path
    regsub -all {/} $port_path {_} port_path
    return [file join $portdbpath build $port_path]
}

proc macports::getportworkpath_from_buildpath {portbuildpath} {
    return [file join $portbuildpath work]
}

proc macports::getportworkpath_from_portdir {portpath} {
    return [macports::getportworkpath_from_buildpath [macports::getportbuildpath $portpath]]
}

proc macports::getindex {source} {
    # Special case file:// sources
    if {[macports::getprotocol $source] == "file"} {
        return [file join [macports::getportdir $source] PortIndex]
    }

    return [file join [macports::getsourcepath $source] PortIndex]
}

proc mportsync {{optionslist {}}} {
    global macports::sources macports::portdbpath macports::rsync_options tcl_platform
    global macports::portverbose
    global macports::autoconf::rsync_path
    array set options $optionslist

    set numfailed 0

    ui_debug "Synchronizing ports tree(s)"
    foreach source $sources {
        set flags [lrange $source 1 end]
        set source [lindex $source 0]
        if {[lsearch -exact $flags nosync] != -1} {
            ui_debug "Skipping $source"
            continue
        }
        ui_info "Synchronizing local ports tree from $source"
        switch -regexp -- [macports::getprotocol $source] {
            {^file$} {
                set portdir [macports::getportdir $source]
                if {[file exists $portdir/.svn]} {
                    set svn_commandline "[macports::findBinary svn] update --non-interactive ${portdir}"
                    ui_debug $svn_commandline
                    if {
                        [catch {
                            set euid [geteuid]
                            set egid [getegid]
                            ui_debug "changing euid/egid - current euid: $euid - current egid: $egid"
                            setegid [name_to_gid [file attributes $portdir -group]]
                            seteuid [name_to_uid [file attributes $portdir -owner]]
                            system $svn_commandline
                            seteuid $euid
                            setegid $egid
                        }]
                    } {
                        ui_debug "$::errorInfo"
                        ui_error "Synchronization of the local ports tree failed doing an svn update"
                        incr numfailed
                        continue
                    }
                }
            }
            {^mports$} {
                macports::index::sync $macports::portdbpath $source
            }
            {^rsync$} {
                # Where to, boss?
                set destdir [file dirname [macports::getindex $source]]
                file mkdir $destdir
                # Keep rsync happy with a trailing slash
                if {[string index $source end] != "/"} {
                    set source "${source}/"
                }
                # Do rsync fetch
                set rsync_commandline "${macports::autoconf::rsync_path} ${rsync_options} ${source} ${destdir}"
                ui_debug $rsync_commandline
                if {[catch {system $rsync_commandline}]} {
                    ui_error "Synchronization of the local ports tree failed doing rsync"
                    incr numfailed
                    continue
                }
                if {[catch {system "chmod -R a+r \"$destdir\""}]} {
                    ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                }
            }
            {^https?$|^ftp$} {
                if {[_source_is_snapshot $source filename extension]} {
                    # sync a daily port snapshot tarball
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

                    if {(![info exists options(ports_force)] || $options(ports_force) != "yes") && $updated <= 0} {
                        ui_info "No updates for $source"
                        continue
                    }

                    file mkdir [file dirname $indexfile]

                    set verboseflag {}
                    if {$macports::portverbose == "yes"} {
                        set verboseflag "-v"
                    }

                    if {[catch {eval curl fetch $verboseflag {$source} {$tarpath}} error]} {
                        ui_error "Fetching $source failed ($error)"
                        incr numfailed
                        continue
                    }

                    set extflag {}
                    switch $extension {
                        {tar.gz} {
                            set extflag "-z"
                        }
                        {tar.bz2} {
                            set extflag "-j"
                        }
                    }

                    set tar [macports::findBinary tar $macports::autoconf::tar_path]
                    if { [catch { system "cd $destdir/.. && $tar ${verboseflag} ${extflag} -xf $filename" } error] } {
                        ui_error "Extracting $source failed ($error)"
                        incr numfailed
                        continue
                    }

                    if {[catch {system "chmod -R a+r \"$destdir\""}]} {
                        ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                    }

                    file delete $tarpath
                } else {
                    # sync just a PortIndex file
                    set indexfile [macports::getindex $source]
                    file mkdir [file dirname $indexfile]
                    curl fetch ${source}/PortIndex $indexfile
                    curl fetch ${source}/PortIndex.quick ${indexfile}.quick
                }
            }
            default {
                ui_warn "Unknown synchronization protocol for $source"
            }
        }
    }

    if {$numfailed > 0} {
        return -code error "Synchronization of $numfailed source(s) failed"
    }
}

proc mportsearch {pattern {case_sensitive yes} {matchstyle regexp} {field name}} {
    global macports::portdbpath macports::sources
    set matches [list]
    set easy [expr { $field == "name" }]

    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        if {$protocol == "mports"} {
            set res [macports::index::search $macports::portdbpath $source [list name $pattern]]
            eval lappend matches $res
        } else {
            if {[catch {set fd [open [macports::getindex $source] r]} result]} {
                ui_warn "Can't open index file for source: $source"
            } else {
                try {
                    incr found 1
                    while {[gets $fd line] >= 0} {
                        array unset portinfo
                        set name [lindex $line 0]
                        set len [lindex $line 1]
                        set line [read $fd $len]

                        if {$easy} {
                            set target $name
                        } else {
                            array set portinfo $line
                            if {![info exists portinfo($field)]} continue
                            set target $portinfo($field)
                        }

                        switch $matchstyle {
                            exact {
                                set matchres [expr 0 == ( {$case_sensitive == "yes"} ? [string compare $pattern $target] : [string compare -nocase $pattern $target] )]
                            }
                            glob {
                                set matchres [expr {$case_sensitive == "yes"} ? [string match $pattern $target] : [string match -nocase $pattern $target]]
                            }
                            regexp -
                            default {
                                set matchres [expr {$case_sensitive == "yes"} ? [regexp -- $pattern $target] : [regexp -nocase -- $pattern $target]]
                            }
                        }

                        if {$matchres == 1} {
                            if {$easy} {
                                array set portinfo $line
                            }
                            switch $protocol {
                                rsync {
                                    # Rsync files are local
                                    set source_url "file://[macports::getsourcepath $source]"
                                }
                                https -
                                http -
                                ftp {
                                    if {[_source_is_snapshot $source filename extension]} {
                                        # daily snapshot tarball
                                        set source_url "file://[macports::getsourcepath $source]"
                                    } else {
                                        # default action
                                        set source_url $source
                                    }
                                }
                                default {
                                    set source_url $source
                                }
                            }
                            if {[info exists portinfo(portarchive)]} {
                                set porturl ${source_url}/$portinfo(portarchive)
                            } elseif {[info exists portinfo(portdir)]} {
                                set porturl ${source_url}/$portinfo(portdir)
                            }
                            if {[info exists porturl]} {
                                lappend line porturl $porturl
                                ui_debug "Found port in $porturl"
                            } else {
                                ui_debug "Found port info: $line"
                            }
                            lappend matches $name
                            lappend matches $line
                        }
                    }
                } catch {*} {
                    ui_warn "It looks like your PortIndex file for $source may be corrupt."
                    throw
                } finally {
                    close $fd
                }
            }
        }
    }
    if {!$found} {
        return -code error "No index(es) found! Have you synced your source indexes?"
    }

    return $matches
}

# Returns the PortInfo for a single named port. The info comes from the
# PortIndex, and name matching is case-insensitive. Unlike mportsearch, only
# the first match is returned, but the return format is otherwise identical.
# The advantage is that mportlookup is much faster than mportsearch, due to
# the use of the quick index.
proc mportlookup {name} {
    global macports::portdbpath macports::sources

    set sourceno 0
    set matches [list]
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        if {$protocol != "mports"} {
            global macports::quick_index
            if {![info exists quick_index($sourceno,[string tolower $name])]} {
                incr sourceno 1
                continue
            }
            # The quick index is keyed on the port name, and provides the
            # offset in the main PortIndex where the given port's PortInfo
            # line can be found.
            set offset $quick_index($sourceno,[string tolower $name])
            incr sourceno 1
            if {[catch {set fd [open [macports::getindex $source] r]} result]} {
                ui_warn "Can't open index file for source: $source"
            } else {
                try {
                    seek $fd $offset
                    gets $fd line
                    set name [lindex $line 0]
                    set len [lindex $line 1]
                    set line [read $fd $len]

                    array set portinfo $line

                    switch $protocol {
                        rsync {
                            set source_url "file://[macports::getsourcepath $source]"
                        }
                        https -
                        http -
                        ftp {
                            if {[_source_is_snapshot $source filename extension]} {
                                set source_url "file://[macports::getsourcepath $source]"
                             } else {
                                set source_url $source
                             }
                        }
                        default {
                            set source_url $source
                        }
                    }
                    if {[info exists portinfo(portarchive)]} {
                        set porturl ${source_url}/$portinfo(portarchive)
                    } elseif {[info exists portinfo(portdir)]} {
                        set porturl ${source_url}/$portinfo(portdir)
                    }
                    if {[info exists porturl]} {
                        lappend line porturl $porturl
                    }
                    lappend matches $name
                    lappend matches $line
                    close $fd
                    set fd -1
                } catch {*} {
                    ui_warn "It looks like your PortIndex file for $source may be corrupt."
                } finally {
                    if {$fd != -1} {
                        close $fd
                    }
                }
                if {[llength $matches] > 0} {
                    break
                }
            }
        } else {
            set res [macports::index::search $macports::portdbpath $source [list name $name]]
            if {[llength $res] > 0} {
                eval lappend matches $res
                break
            }
        }
    }

    return $matches
}

# Returns all ports in the indices. Faster than 'mportsearch .*'
proc mportlistall {args} {
    global macports::portdbpath macports::sources
    set matches [list]

    set found 0
    foreach source $sources {
        set source [lindex $source 0]
        set protocol [macports::getprotocol $source]
        if {$protocol != "mports"} {
            if {![catch {set fd [open [macports::getindex $source] r]} result]} {
                try {
                    incr found 1
                    while {[gets $fd line] >= 0} {
                        array unset portinfo
                        set name [lindex $line 0]
                        set len [lindex $line 1]
                        set line [read $fd $len]

                        array set portinfo $line

                        switch $protocol {
                            rsync {
                                set source_url "file://[macports::getsourcepath $source]"
                            }
                            https -
                            http -
                            ftp {
                                if {[_source_is_snapshot $source filename extension]} {
                                    set source_url "file://[macports::getsourcepath $source]"
                                } else {
                                    set source_url $source
                                }
                            }
                            default {
                                set source_url $source
                            }
                        }
                        if {[info exists portinfo(portdir)]} {
                            set porturl ${source_url}/$portinfo(portdir)
                        } elseif {[info exists portinfo(portarchive)]} {
                            set porturl ${source_url}/$portinfo(portarchive)
                        }
                        if {[info exists porturl]} {
                            lappend line porturl $porturl
                        }
                        lappend matches $name $line
                    }
                } catch {*} {
                    ui_warn "It looks like your PortIndex file for $source may be corrupt."
                    throw
                } finally {
                    close $fd
                }
            } else {
                ui_warn "Can't open index file for source: $source"
            }
        } else {
            set res [macports::index::search $macports::portdbpath $source [list name .*]]
            eval lappend matches $res
        }
    }
    if {!$found} {
        return -code error "No index(es) found! Have you synced your source indexes?"
    }

    return $matches
}


# Loads PortIndex.quick from each source into the quick_index, generating
# it first if necessary.
proc _mports_load_quickindex {args} {
    global macports::sources macports::quick_index

    set sourceno 0
    foreach source $sources {
        unset -nocomplain quicklist
        # chop off any tags
        set source [lindex $source 0]
        set index [macports::getindex $source]
        if {![file exists ${index}]} {
            continue
        }
        if {![file exists ${index}.quick]} {
            ui_warn "No quick index file found, attempting to generate one for source: $source"
            if {[catch {set quicklist [mports_generate_quickindex ${index}]}]} {
                continue
            }
        }
        # only need to read the quick index file if we didn't just update it
        if {![info exists quicklist]} {
            if {[catch {set fd [open ${index}.quick r]} result]} {
                ui_warn "Can't open quick index file for source: $source"
                continue
            } else {
                set quicklist [read $fd]
                close $fd
            }
        }
        foreach entry [split $quicklist "\n"] {
            set quick_index($sourceno,[lindex $entry 0]) [lindex $entry 1]
        }
        incr sourceno 1
    }
    if {!$sourceno} {
        ui_warn "No index(es) found! Have you synced your source indexes?"
    }
}

proc mports_generate_quickindex {index} {
    if {[catch {set indexfd [open ${index} r]} result] || [catch {set quickfd [open ${index}.quick w]} result]} {
        ui_warn "Can't open index file: $index"
        return -code error
    } else {
        try {
            set offset [tell $indexfd]
            set quicklist ""
            while {[gets $indexfd line] >= 0} {
                if {[llength $line] != 2} {
                    continue
                }
                set name [lindex $line 0]
                append quicklist "[string tolower $name] ${offset}\n"

                set len [lindex $line 1]
                read $indexfd $len
                set offset [tell $indexfd]
            }
            puts -nonewline $quickfd $quicklist
        } catch {*} {
            ui_warn "It looks like your PortIndex file $index may be corrupt."
            throw
        } finally {
            close $indexfd
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
    return [$workername eval array get PortInfo]
}

proc mportclose {mport} {
    global macports::open_mports
    set refcnt [ditem_key $mport refcnt]
    incr refcnt -1
    ditem_key $mport refcnt $refcnt
    if {$refcnt == 0} {
        dlist_delete macports::open_mports $mport
        set workername [ditem_key $mport workername]
        interp delete $workername
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
    return [$workername eval "return \$${key}"]
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
proc mportdepends {mport {target ""} {recurseDeps 1} {skipSatisfied 1}} {

    array set portinfo [mportinfo $mport]
    set depends {}
    set deptypes {}

    # progress indicator
    if {![macports::ui_isset ports_debug]} {
        ui_info -nonewline "."
        flush stdout
    }
    
    if {[info exists portinfo(conflicts)] && ($target == "" || $target == "install")} {
        set conflictports [_mportconflictsinstalled $mport $portinfo(conflicts)]
        if {[llength ${conflictports}] != 0} {
            if {[macports::global_option_isset ports_force]} {
                ui_warn "Force option set; installing $portinfo(name) despite conflicts with: ${conflictports}"
            } else {
                return -code error "Can't install $portinfo(name) because conflicting ports are installed: ${conflictports}"
            }
        }
    }

    set deptypes [macports::_deptypes_for_target $target]

    # Gather the dependencies for deptypes
    foreach deptype $deptypes {
        # Add to the list of dependencies if the option exists and isn't empty.
        if {[info exists portinfo($deptype)] && $portinfo($deptype) != ""} {
            set depends [concat $depends $portinfo($deptype)]
        }
    }

    set subPorts {}
    set options [ditem_key $mport options]
    set variations [ditem_key $mport variations]

    foreach depspec $depends {
        # Is that dependency satisfied or this port installed?
        # If we don't skip or if it is not, add it to the list.
        if {!$skipSatisfied || ![_mportispresent $mport $depspec]} {
            # grab the portname portion of the depspec
            set dep_portname [lindex [split $depspec :] end]

            # Find the porturl
            if {[catch {set res [mportlookup $dep_portname]} error]} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "Internal error: port lookup failed: $error"
                return 1
            }

            array unset portinfo
            array set portinfo [lindex $res 1]
            if {![info exists portinfo(porturl)]} {
                if {![macports::ui_isset ports_debug]} {
                    ui_msg ""
                }
                ui_error "Dependency '$dep_portname' not found."
                return 1
            }

            # Figure out the subport. Check the open_mports list first, since
            # we potentially leak mport references if we mportopen each time,
            # because mportexec only closes each open mport once.
            set subport [dlist_search $macports::open_mports porturl $portinfo(porturl)]
            if {$subport == {}} {
                # We haven't opened this one yet.
                set subport [mportopen $portinfo(porturl) $options $variations]
                if {$recurseDeps} {
                    # Add to the list we need to recurse on.
                    lappend subPorts $subport
                }
            }

            # Append the sub-port's provides to the port's requirements list.
            ditem_append_unique $mport requires "[ditem_key $subport provides]"
        }
    }

    # Loop on the subports.
    if {$recurseDeps} {
        foreach subport $subPorts {
            # Sub ports should be installed (all dependencies must be satisfied).
            set res [mportdepends $subport "" $recurseDeps $skipSatisfied]
            if {$res != 0} {
                return $res
            }
        }
    }

    return 0
}

# Determine dependency types required for target
proc macports::_deptypes_for_target {target} {
    switch $target {
        fetch       -
        checksum    { set deptypes "depends_fetch" }
        extract     -
        patch       { set deptypes "depends_fetch depends_extract" }
        configure   -
        build       { set deptypes "depends_fetch depends_extract depends_lib depends_build" }

        test        -
        destroot    -
        install     -
        archive     -
        dmg         -
        pkg         -
        portpkg     -
        mdmg        -
        mpkg        -
        rpm         -
        srpm        -
        dpkg        -
        ""          { set deptypes "depends_fetch depends_extract depends_lib depends_build depends_run" }
    }
    return $deptypes
}

# selfupdate procedure
proc macports::selfupdate {{optionslist {}}} {
    global macports::prefix macports::portdbpath macports::libpath macports::rsync_server macports::rsync_dir macports::rsync_options
    global macports::autoconf::macports_version macports::autoconf::rsync_path tcl_platform
    array set options $optionslist

    # syncing ports tree.
    if {![info exists options(ports_selfupdate_nosync)] || $options(ports_selfupdate_nosync) != "yes"} {
        ui_msg "--->  Updating the ports tree"
        if {[catch {mportsync $optionslist} result]} {
            return -code error "Couldn't sync the ports tree: $result"
        }
    }

    # create the path to the to be downloaded sources if it doesn't exist
    set mp_source_path [file join $portdbpath sources ${rsync_server} ${rsync_dir}/]
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources location: $mp_source_path"

    # sync the MacPorts sources
    ui_msg "--->  Updating MacPorts base sources using rsync"
    if { [catch { system "$rsync_path $rsync_options rsync://${rsync_server}/${rsync_dir} $mp_source_path" } result ] } {
       return -code error "Error synchronizing MacPorts sources: $result"
    }

    # echo current MacPorts version
    ui_msg "MacPorts base version $macports::autoconf::macports_version installed,"

    if { [info exists options(ports_force)] && $options(ports_force) == "yes" } {
        set use_the_force_luke yes
        ui_debug "Forcing a rebuild and reinstallation of MacPorts"
    } else {
        set use_the_force_luke no
        ui_debug "Rebuilding and reinstalling MacPorts if needed"
    }

    # Choose what version file to use: old, floating point format or new, real version number format
    set version_file [file join $mp_source_path config macports_version]
    if {[file exists $version_file]} {
        set fd [open $version_file r]
        gets $fd macports_version_new
        close $fd
        # echo downloaded MacPorts version
        ui_msg "MacPorts base version $macports_version_new downloaded."
    } else {
        ui_warn "No version file found, please rerun selfupdate."
        set macports_version_new 0
    }

    # check if we we need to rebuild base
    set comp [rpm-vercomp $macports_version_new $macports::autoconf::macports_version]
    if {$use_the_force_luke == "yes" || $comp > 0} {
        if {[info exists options(ports_dryrun)] && $options(ports_dryrun) == "yes"} {
            ui_msg "--->  MacPorts base is outdated, selfupdate would install $macports_version_new (dry run)"
        } else {
            ui_msg "--->  MacPorts base is outdated, installing new version $macports_version_new"

            # get installation user/group and permissions
            set owner [file attributes ${prefix} -owner]
            set group [file attributes ${prefix} -group]
            set perms [string range [file attributes ${prefix} -permissions] end-3 end]
            if {$tcl_platform(user) != "root" && ![string equal $tcl_platform(user) $owner]} {
                return -code error "User $tcl_platform(user) does not own ${prefix} - try using sudo"
            }
            ui_debug "Permissions OK"

            # where to install our macports1.0 tcl package
            set mp_tclpackage_path [file join $portdbpath .tclpackage]
            if { [file exists $mp_tclpackage_path]} {
                set fd [open $mp_tclpackage_path r]
                gets $fd tclpackage
                close $fd
            } else {
                set tclpackage $libpath
            }

            set configure_args "--prefix=$prefix --with-tclpackage=$tclpackage --with-install-user=$owner --with-install-group=$group --with-directory-mode=$perms"
            # too many users have an incompatible readline in /usr/local, see ticket #10651
            if {$tcl_platform(os) != "Darwin" || $prefix == "/usr/local"
                || ([glob -nocomplain "/usr/local/lib/lib{readline,history}*"] == "" && [glob -nocomplain "/usr/local/include/readline/*.h"] == "")} {
                append configure_args " --enable-readline"
            } else {
                ui_warn "Disabling readline support due to readline in /usr/local"
            }

            # do the actual configure, build and installation of new base
            ui_msg "Installing new MacPorts release in $prefix as $owner:$group; permissions $perms; Tcl-Package in $tclpackage\n"
            if { [catch { system "cd $mp_source_path && ./configure $configure_args && make && make install" } result] } {
                return -code error "Error installing new MacPorts base: $result"
            }
        }
    } elseif {$comp < 0} {
        ui_msg "--->  MacPorts base is probably trunk or a release candidate"
    } else {
        ui_msg "--->  MacPorts base is already the latest version"
    }

    # set the MacPorts sources to the right owner
    set sources_owner [file attributes [file join $portdbpath sources/] -owner]
    ui_debug "Setting MacPorts sources ownership to $sources_owner"
    if { [catch { exec [findBinary chown $macports::autoconf::chown_path] -R $sources_owner [file join $portdbpath sources/] } result] } {
        return -code error "Couldn't change permissions of the MacPorts sources at $mp_source_path to $sources_owner: $result"
    }

    if {![info exists options(ports_selfupdate_nosync)] || $options(ports_selfupdate_nosync) != "yes"} {
        ui_msg "\nThe ports tree has been updated. To upgrade your installed ports, you should run"
        ui_msg "  port upgrade outdated"
    }

    return 0
}

# upgrade API wrapper procedure
# return codes: 0 = success, 1 = general failure, 2 = port name not found in index
proc macports::upgrade {portname dspec variationslist optionslist {depscachename ""}} {
    # only installed ports can be upgraded
    if {![registry::entry_exists_for_name $portname]} {
        ui_error "$portname is not installed"
        return 1
    }
    if {![string match "" $depscachename]} {
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
    # filter out implicit variants from the explicitly set/unset variants.
    set variationslist [mport_filtervariants $variationslist yes]
    
    # run the actual upgrade
    set status [macports::_upgrade $portname $dspec $variationslist $optionslist depscache]
    
    if {!$orig_nodeps} {
        unset -nocomplain macports::global_options(ports_nodeps)
    }
    return $status
}

# main internal upgrade procedure
proc macports::_upgrade {portname dspec variationslist optionslist {depscachename ""}} {
    global macports::registry.installtype
    global macports::portarchivemode
    global macports::global_variations
    array set options $optionslist

    # Note $variationslist is left alone and so retains the original
    # requested variations, which should be passed to recursive calls to
    # upgrade; while variations gets existing variants and global variations
    # merged in later on, so it applies only to this port's upgrade
    array set variations $variationslist
    
    set globalvarlist [array get macports::global_variations]

    if {![string match "" $depscachename]} {
        upvar $depscachename depscache
    }

    # Is this a dry run?
    set is_dryrun no
    if {[info exists options(ports_dryrun)] && $options(ports_dryrun) eq "yes"} {
        set is_dryrun yes
    }

    # check if the port is in tree
    if {[catch {mportlookup $portname} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "port lookup failed: $result"
        return 1
    }
    # argh! port doesnt exist!
    if {$result == ""} {
        ui_warn "No port $portname found in the index."
        return 2
    }
    # fill array with information
    array set portinfo [lindex $result 1]
    # set portname again since the one we were passed may not have had the correct case
    set portname $portinfo(name)

    # set version_in_tree and revision_in_tree
    if {![info exists portinfo(version)]} {
        ui_error "Invalid port entry for $portname, missing version"
        return 1
    }
    set version_in_tree "$portinfo(version)"
    set revision_in_tree "$portinfo(revision)"
    set epoch_in_tree "$portinfo(epoch)"

    set ilist {}
    if { [catch {set ilist [registry::installed $portname ""]} result] } {
        if {$result == "Registry error: $portname not registered as installed." } {
            ui_debug "$portname is *not* installed by MacPorts"

            # We need to pass _mportispresent a reference to the mport that is
            # actually declaring the dependency on the one we're checking for.
            # We got here via _upgrade_dependencies, so we grab it from 2 levels up.
            upvar 2 workername parentworker
            if {![_mportispresent $parentworker $dspec ] } {
                # open porthandle
                set porturl $portinfo(porturl)
                if {![info exists porturl]} {
                    set porturl file://./
                }
                # Merge the global variations into the specified
                foreach { variation value } $globalvarlist {
                    if { ![info exists variations($variation)] } {
                        set variations($variation) $value
                    }
                }

                if {[catch {set workername [mportopen $porturl [array get options] [array get variations]]} result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    ui_error "Unable to open port: $result"
                    return 1
                }
                # While we're at it, update the portinfo
                array unset portinfo
                array set portinfo [mportinfo $workername]
                
                # upgrade its dependencies first
                set status [_upgrade_dependencies portinfo depscache variationslist options]
                if {$status != 0 && ![ui_isset ports_processall]} {
                    catch {mportclose $workername}
                    return $status
                }
                # now install it
                if {[catch {set result [mportexec $workername install]} result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    ui_error "Unable to exec port: $result"
                    catch {mportclose $workername}
                    return 1
                }
                if {$result > 0} {
                    ui_error "Problem while installing $portname"
                    catch {mportclose $workername}
                    return $result
                }
                # we just installed it, so mark it done in the cache
                set depscache(port:${portname}) 1
                mportclose $workername
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
        set depscache(port:${portname}) 1
    }
    set anyactive no
    set version_installed {}
    set revision_installed {}
    set epoch_installed 0
    set variant_installed ""

    # find latest version installed and active version (if any)
    foreach i $ilist {
        set variant [lindex $i 3]
        set version [lindex $i 1]
        set revision [lindex $i 2]
        set epoch [lindex $i 5]
        if { $version_installed == {} || $epoch > $epoch_installed ||
                ($epoch == $epoch_installed && [rpm-vercomp $version $version_installed] > 0)
                || ($epoch == $epoch_installed
                    && [rpm-vercomp $version $version_installed] == 0
                    && [rpm-vercomp $revision $revision_installed] > 0)} {
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
        }
    }

    # output version numbers
    ui_debug "epoch: in tree: $epoch_in_tree installed: $epoch_installed"
    ui_debug "$portname ${version_in_tree}_${revision_in_tree} exists in the ports tree"
    ui_debug "$portname ${version_installed}_${revision_installed} $variant_installed is the latest installed"
    if {$anyactive} {
        ui_debug "$portname ${version_active}_${revision_active} $variant_active is active"
    } else {
        ui_debug "no version of $portname is active"
    }

    # save existing variant for later use
    if {$anyactive} {
        set oldvariant $variant_active
    } else {
        set oldvariant $variant_installed
    }

    # Before we do
    # dependencies, we need to figure out the final variants,
    # open the port, and update the portinfo.

    set porturl $portinfo(porturl)
    if {![info exists porturl]} {
        set porturl file://./
    }

    # will break if we start recording negative variants (#2377)
    set variant [lrange [split $oldvariant +] 1 end]
    ui_debug "Merging existing variants $variant into variants"
    set oldvariantlist [list]
    foreach v $variant {
        lappend oldvariantlist $v "+"
    }
    # remove implicit variants, without printing warnings
    set oldvariantlist [mport_filtervariants $oldvariantlist no]

    # merge in the old variants
    foreach {variation value} $oldvariantlist {
        if { ![info exists variations($variation)]} {
            set variations($variation) $value
        }
    }

    # Now merge in the global (i.e. variants.conf) variations.
    # We wait until now so that existing variants for this port
    # override global variations
    foreach { variation value } $globalvarlist {
        if { ![info exists variations($variation)] } {
            set variations($variation) $value
        }
    }

    ui_debug "new fully merged portvariants: [array get variations]"
    
    # at this point we need to check if a different port will be replacing this one
    if {[info exists portinfo(replaced_by)] && ![info exists options(ports_upgrade_no-replace)]} {
        ui_debug "$portname is replaced by $portinfo(replaced_by)"
        if {[catch {mportlookup $portinfo(replaced_by)} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "port lookup failed: $result"
            return 1
        }
        if {$result == ""} {
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
        set depscache(port:${newname}) 1
    } else {
        set newname $portname
    }

    if {[catch {set workername [mportopen $porturl [array get options] [array get variations]]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Unable to open port: $result"
        return 1
    }

    array unset portinfo
    array set portinfo [mportinfo $workername]
    set version_in_tree "$portinfo(version)"
    set revision_in_tree "$portinfo(revision)"
    set epoch_in_tree "$portinfo(epoch)"


    # first upgrade dependencies
    if {![info exists options(ports_nodeps)]} {
        set status [_upgrade_dependencies portinfo depscache variationslist options]
        if {$status != 0 && ![ui_isset ports_processall]} {
            catch {mportclose $workername}
            return $status
        }
    } else {
        ui_debug "Not following dependencies"
    }

    set epoch_override 0
    # check installed version against version in ports
    if { ( [rpm-vercomp $version_installed $version_in_tree] > 0
            || ([rpm-vercomp $version_installed $version_in_tree] == 0
                && [rpm-vercomp $revision_installed $revision_in_tree] >= 0 ))
        && ![info exists options(ports_upgrade_force)] } {
        if {$portname != $newname} { 
            ui_debug "ignoring versions, installing replacement port"
        } elseif { $epoch_installed < $epoch_in_tree } {
            set epoch_override 1
            ui_debug "epoch override ... upgrading!"
        } elseif {[info exists options(ports_upgrade_enforce-variants)] && $options(ports_upgrade_enforce-variants) eq "yes"
                  && [info exists portinfo(canonical_active_variants)] && $portinfo(canonical_active_variants) != $oldvariant} {
            ui_debug "variant override ... upgrading!"
        } else {
            if {[info exists portinfo(canonical_active_variants)] && $portinfo(canonical_active_variants) != $oldvariant} {
                ui_warn "Skipping upgrade since $portname ${version_installed}_${revision_installed} >= $portname ${version_in_tree}_${revision_in_tree}, even though installed variants \"$oldvariant\" do not match \"$portinfo(canonical_active_variants)\". Use 'upgrade --enforce-variants' to switch to the requested variants."
            } else {
                ui_debug "No need to upgrade! $portname ${version_installed}_${revision_installed} >= $portname ${version_in_tree}_${revision_in_tree}"
            }
            # Check if we have to do dependents
            if {[info exists options(ports_do_dependents)]} {
                # We do dependents ..
                set options(ports_nodeps) 1

                registry::open_dep_map
                set deplist [registry::list_dependents $portname]

                if { [llength deplist] > 0 } {
                    foreach dep $deplist {
                        set mpname [lindex $dep 2]
                        if {![llength [array get depscache port:${mpname}]]} {
                            set status [macports::_upgrade $mpname port:${mpname} $variationslist [array get options] depscache]
                            if {$status != 0 && ![ui_isset ports_processall]} {
                                catch {mportclose $workername}
                                return $status
                            }
                        }
                    }
                }
            }
            mportclose $workername
            return 0
        }
    }


    # build or unarchive version_in_tree
    if {0 == [string compare "yes" ${macports::portarchivemode}]} {
        set upgrade_action "archive"
    } else {
        set upgrade_action "destroot"
    }

    # avoid building again unnecessarily
    if {[info exists options(ports_upgrade_force)] || $epoch_override == 1
        || ![registry::entry_exists $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants)]} {
        if {[catch {set result [mportexec $workername $upgrade_action]} result] || $result != 0} {
            if {[info exists ::errorInfo]} {
                ui_debug "$::errorInfo"
            }
            ui_error "Unable to upgrade port: $result"
            catch {mportclose $workername}
            return 1
        }
    }

    # always uninstall old port in direct mode
    if { 0 != [string compare "image" ${macports::registry.installtype}] } {
        # uninstall old
        ui_debug "Uninstalling $portname ${version_installed}_${revision_installed}${variant_installed}"
        # we have to force the uninstall in case of dependents
        set force_cur [info exists options(ports_force)]
        set options(ports_force) yes
        if {$is_dryrun eq "yes"} {
            ui_msg "Skipping uninstall $portname @${version_installed}_${revision_installed}${variant_installed} (dry run)"
        } elseif {[catch {portuninstall::uninstall $portname ${version_installed}_${revision_installed}${variant_installed} [array get options]} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "Uninstall $portname ${version_installed}_${revision_installed}${variant_installed} failed: $result"
            catch {mportclose $workername}
            return 1
        }
        if {!$force_cur} {
            unset options(ports_force)
        }
    } else {
        # are we installing an existing version due to force or epoch override?
        if {[registry::entry_exists $newname $version_in_tree $revision_in_tree $portinfo(canonical_active_variants)]
            && ([info exists options(ports_upgrade_force)] || $epoch_override == 1)} {
             ui_debug "Uninstalling $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants)"
            # we have to force the uninstall in case of dependents
            set force_cur [info exists options(ports_force)]
            set options(ports_force) yes
            if {$is_dryrun eq "yes"} {
                ui_msg "Skipping uninstall $newname @${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) (dry run)"
            } elseif {[catch {portuninstall::uninstall $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) [array get options]} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "Uninstall $newname ${version_in_tree}_${revision_in_tree}$portinfo(canonical_active_variants) failed: $result"
                catch {mportclose $workername}
                return 1
            }
            if {!$force_cur} {
                unset options(ports_force)
            }
            if {$anyactive && $version_in_tree == $version_active && $revision_in_tree == $revision_active
                && $portinfo(canonical_active_variants) == $variant_active && $portname == $newname} {
                set anyactive no
            }
        }
        if {$anyactive} {
            # deactivate version_active
            if {$is_dryrun eq "yes"} {
                ui_msg "Skipping deactivate $portname @${version_active}_${revision_active} (dry run)"
            } elseif {[catch {portimage::deactivate $portname ${version_active}_${revision_active}${variant_active} $optionslist} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "Deactivating $portname ${version_active}_${revision_active} failed: $result"
                catch {mportclose $workername}
                return 1
            }
        }
        if {[info exists options(port_uninstall_old)]} {
            # uninstalling now could fail due to dependents when not forced,
            # because the new version is not installed
            set uninstall_later yes
        }
    }

    if {$is_dryrun eq "yes"} {
        ui_msg "Skipping activate $newname @${version_in_tree}_${revision_in_tree} (dry run)"
    } elseif {[catch {set result [mportexec $workername install]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Couldn't activate $newname ${version_in_tree}_${revision_in_tree}: $result"
        catch {mportclose $workername}
        return 1
    }

    if {[info exists uninstall_later] && $uninstall_later == yes} {
        foreach i $ilist {
            set version [lindex $i 1]
            set revision [lindex $i 2]
            set variant [lindex $i 3]
            if {$version == $version_in_tree && $revision == $revision_in_tree && $variant == $portinfo(canonical_active_variants) && $portname == $newname} {
                continue
            }
            ui_debug "Uninstalling $portname ${version}_${revision}${variant}"
            if {$is_dryrun eq "yes"} {
                ui_msg "Skipping uninstall $portname @${version}_${revision}${variant} (dry run)"
            } elseif {[catch {portuninstall::uninstall $portname ${version}_${revision}${variant} $optionslist} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                # replaced_by can mean that we try to uninstall all versions of the old port, so handle errors due to dependents
                if {$result != "Please uninstall the ports that depend on $portname first." && ![ui_isset ports_processall]} {
                    ui_error "Uninstall $portname @${version}_${revision}${variant} failed: $result"
                    catch {mportclose $workername}
                    return 1
                }
            }
        }
    }

    # Check if we have to do dependents
    if {[info exists options(ports_do_dependents)]} {
        # We do dependents ..
        set options(ports_nodeps) 1

        registry::open_dep_map
        set deplist [registry::list_dependents $newname]
        if {$portname != $newname} {
            set deplist [concat $deplist [registry::list_dependents $portname]]
        }

        if { [llength deplist] > 0 } {
            foreach dep $deplist {
                set mpname [lindex $dep 2]
                if {![llength [array get depscache port:${mpname}]]} {
                    set status [macports::_upgrade $mpname port:${mpname} $variationslist [array get options] depscache]
                    if {$status != 0 && ![ui_isset ports_processall]} {
                        catch {mportclose $workername}
                        return $status
                    }
                }
            }
        }
    }


    # close the port handle
    mportclose $workername
    return 0
}

# upgrade_dependencies: helper proc for upgrade
# Calls upgrade on each dependency listed in the PortInfo.
# Uses upvar to access the variables.
proc macports::_upgrade_dependencies {portinfoname depscachename variationslistname optionsname} {
    upvar $portinfoname portinfo $depscachename depscache \
          $variationslistname variationslist \
          $optionsname options
    upvar workername parentworker

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

    set status 0
    # each dep type is upgraded
    foreach dtype {depends_fetch depends_extract depends_build depends_lib depends_run} {
        if {[info exists portinfo($dtype)]} {
            foreach i $portinfo($dtype) {
                set d [_get_dep_port $parentworker $i]
                if {![llength [array get depscache port:${d}]] && ![llength [array get depscache $i]]} {
                    if {$d != ""} {
                        set dspec port:$d
                    } else {
                        set dspec $i
                        set d [lindex [split $i :] end]
                    }
                    set status [macports::_upgrade $d $dspec $variationslist [array get options] depscache]
                    if {$status != 0 && ![ui_isset ports_processall]} break
                }
            }
        }
        if {$status != 0 && ![ui_isset ports_processall]} break
    }
    # restore dependent-following to its former value
    if {$saved_do_dependents} {
        set options(ports_do_dependents) yes
    }
    return $status
}

# mportselect
#   * command: The only valid commands are list, set and show
#   * group: This argument should correspond to a directory under
#            $macports::prefix/etc/select.
#   * version: This argument is only used by the 'set' command.
# On error mportselect returns with the code 'error'.
proc mportselect {command group {version ""}} {
    ui_debug "mportselect \[$command] \[$group] \[$version]"

    set conf_path "$macports::prefix/etc/select/$group"
    if {![file isdirectory $conf_path]} {
        return -code error "The specified group '$group' does not exist."
    }

    switch -- $command {
        list {
            if {[catch {set versions [glob -directory $conf_path *]}]} {
                return -code error [concat "No configurations associated " \
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
        set {
            # Use $conf_path/$version to read in sources.
            if {[catch {set src_file [open "$conf_path/$version"]}]} {
                return -code error [concat "Verify that the specified " \
                                           "version '$version' is valid " \
                                           "(i.e., Is it listed when you " \
                                           "specify the --list command?)."]
            }
            set srcs [split [read -nonewline $src_file] "\n"]
            close $src_file

            # Use $conf_path/base to read in targets.
            if {[catch {set tgt_file [open "$conf_path/base"]}]} {
                return -code error [concat "The configuration file " \
                                           "'$conf_path/base' could not be " \
                                           "opened."]
            }
            set tgts [split [read -nonewline $tgt_file] "\n"]
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
                set i [expr $i+1]
            }

            # Update the selected version.
            set selected_version "$conf_path/current"
            if {[file exists $selected_version]} {
                file delete $selected_version
            }
            symlink $version $selected_version
            return
        }
        show {
            set selected_version "$conf_path/current"

            if {![file exists $selected_version]} {
                return "none"
            } else {
                return [file readlink $selected_version]
            }
        }
    }
    return
}

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
    namespace export bootstrap_options user_options portinterp_options open_mports ui_priorities
    variable bootstrap_options "\
        portdbpath libpath binpath auto_path extra_env sources_conf prefix portdbformat \
        portinstalltype portarchivemode portarchivepath portarchivetype portautoclean \
        porttrace portverbose destroot_umask variants_conf rsync_server rsync_options \
        rsync_dir startupitem_type place_worksymlink xcodeversion xcodebuildcmd \
        mp_remote_url mp_remote_submit_url configureccache configuredistcc configurepipe buildnicevalue buildmakejobs"
    variable user_options "submitter_name submitter_email submitter_key"
    variable portinterp_options "\
        portdbpath portpath portbuildpath auto_path prefix prefix_frozen portsharepath \
        registry.path registry.format registry.installtype portarchivemode portarchivepath \
        portarchivetype portautoclean porttrace portverbose destroot_umask rsync_server \
        rsync_options rsync_dir startupitem_type place_worksymlink \
        mp_remote_url mp_remote_submit_url configureccache configuredistcc configurepipe buildnicevalue buildmakejobs \
        $user_options"
    
    # deferred options are only computed when needed.
    # they are not exported to the trace thread.
    # they are not exported to the interpreter in system_options array.
    variable portinterp_deferred_options "xcodeversion xcodebuildcmd"
    
    variable open_mports {}
    
    variable ui_priorities "debug info msg error warn"
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


proc macports::ui_init {priority message} {
    # Get the list of channels.
    if {[llength [info commands ui_channels]] > 0} {
        set channels [ui_channels $priority]
    } else {
        set channels [ui_channels_default $priority]
    }

    # Simplify ui_$priority.
    set nbchans [llength $channels]
    if {$nbchans == 0} {
        proc ::ui_$priority {str} {}
    } else {
        if {[llength [info commands ui_prefix]] > 0} {
            set prefix [ui_prefix $priority]
        } else {
            set prefix [ui_prefix_default $priority]
        }

        if {$nbchans == 1} {
            set chan [lindex $channels 0]
            proc ::ui_$priority {str} [subst { puts $chan "$prefix\$str" }]
        } else {
            proc ::ui_$priority {str} [subst {
                foreach chan \$channels {
                    puts $chan "$prefix\$str"
                }
            }]
        }

        # Call ui_$priority
        ::ui_$priority $message
    }
}

# Defult implementation of ui_prefix
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
        error {
            return {stderr}
        }
        default {
            return {stdout}
        }
    }
}

foreach priority ${macports::ui_priorities} {
    proc ui_$priority {str} [subst { macports::ui_init $priority \$str }]
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
# returns an error code if it can not be found
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

# dportinit
# Deprecated version of the new mportinit proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportinit {{up_ui_options {}} {up_options {}} {up_variations {}}} {
    ui_warn "The dportinit proc is deprecated and will be going away soon, please use mportinit in the future!"
    mportinit $up_ui_options $up_options $up_variations
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
    
    global auto_path env
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
    global macports::sources_conf
    global macports::destroot_umask
    global macports::libpath
    global macports::prefix
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

    # Set the system encoding to utf-8
    encoding system utf-8

    # Ensure that the macports user directory exists if HOME is defined
    if {[info exists env(HOME)]} {
        set macports::macports_user_dir [file normalize $macports::autoconf::macports_user_dir]
        if { ![file exists $macports_user_dir] } {
        # If not, create it with ownership of the enclosing directory, rwx by the user only
        file mkdir $macports_user_dir
        file attributes $macports_user_dir -permissions u=rwx,go= \
            -owner [file attributes $macports_user_dir/.. -owner] \
            -group [file attributes $macports_user_dir/.. -group]
        }
    } else {
        # Otherwise define the user directory as a direcotory that will never exist
        set macports::macports_user_dir "/dev/null/NO_HOME_DIR"
    }
    
    # Configure the search path for configuration files
    set conf_files ""
    if {[info exists env(PORTSRC)]} {
        set PORTSRC $env(PORTSRC)
        lappend conf_files ${PORTSRC}
    }
    if { [file isdirectory $macports_user_dir] } {
        lappend conf_files "${macports_user_dir}/macports.conf"
    }
    lappend conf_files "${macports_conf_path}/macports.conf"
    
    # Process the first configuration file we find on conf_files list
    foreach file $conf_files {
        if [file exists $file] {
            set portconf $file
            set fd [open $file r]
            while {[gets $fd line] >= 0} {
                if {[regexp {^(\w+)([ \t]+(.*))?$} $line match option ignore val] == 1} {
                    if {[lsearch $bootstrap_options $option] >= 0} {
                        set macports::$option $val
                        global macports::$option
                    }
                }
            }            
            break
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
                    if {[lsearch -exact [list nosync] $flag] == -1} {
                        ui_warn "$sources_conf source '$line' specifies invalid flag '$flag'"
                    }
                }
                lappend sources [concat [list $url] $flags]
            } else {
                ui_warn "$sources_conf specifies invalid source '$line', ignored."
            }
        }
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
        } else {
            ui_debug "$variants_conf does not exist, variants_conf setting ignored."
        }
    }

    if {![info exists portdbpath]} {
        return -code error "portdbpath must be set in ${macports_conf_path}/macports.conf or in your ${macports_user_dir}/macports.conf"
    }
    if {![file isdirectory $portdbpath]} {
        if {![file exists $portdbpath]} {
            if {[catch {file mkdir $portdbpath} result]} {
                return -code error "portdbpath $portdbpath does not exist and could not be created: $result"
            }
        }
    }
    if {![file isdirectory $portdbpath]} {
        return -code error "$portdbpath is not a directory. Please create the directory $portdbpath and try again"
    }

    set registry.path $portdbpath
    if {![file isdirectory ${registry.path}]} {
        if {![file exists ${registry.path}]} {
            if {[catch {file mkdir ${registry.path}} result]} {
                return -code error "portdbpath ${registry.path} does not exist and could not be created: $result"
            }
        }
    }
    if {![file isdirectory ${macports::registry.path}]} {
        return -code error "${macports::registry.path} is not a directory. Please create the directory $portdbpath and try again"
    }

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
        set macports::portarchivemode "yes"
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
                if {[catch {file mkdir $portarchivepath} result]} {
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
        set macports::portarchivetype "cpgz"
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
        set env(PATH) "${prefix}/bin:${prefix}/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"
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
        set macports::configurepipe no
    }

    # Default mp build options
    if {![info exists macports::buildnicevalue]} {
        set macports::buildnicevalue 0
    }
    if {![info exists macports::buildmakejobs]} {
        set macports::buildmakejobs 1
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
}

proc macports::worker_init {workername portpath portbuildpath options variations} {
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
    $workername alias mport_search mportsearch

    # instantiate the UI call-backs
    foreach priority ${macports::ui_priorities} {
        $workername alias ui_$priority ui_$priority
    }
    $workername alias ui_prefix ui_prefix
    $workername alias ui_channels ui_channels
    
    # Export some utility functions defined here.
    $workername alias macports_create_thread macports::create_thread
    $workername alias getportworkpath_from_buildpath macports::getportworkpath_from_buildpath

    # New Registry/Receipts stuff
    $workername alias registry_new registry::new_entry
    $workername alias registry_open registry::open_entry
    $workername alias registry_write registry::write_entry
    $workername alias registry_prop_store registry::property_store
    $workername alias registry_prop_retr registry::property_retrieve
    $workername alias registry_delete registry::delete_entry
    $workername alias registry_exists registry::entry_exists
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
    if {[catch {exec curl -L -s -S -o [file join $fetchdir $fetchfile] $url} result]} {
        return -code error "Port remote fetch failed: $result"
    }
    cd $fetchdir
    if {[catch {exec tar -zxf $fetchfile} result]} {
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
    if {[regexp {(?x)([^:]+)://(.+)} $url match protocol string] == 1} {
        switch -regexp -- ${protocol} {
            {^file$} {
                return [file normalize $string]
            }
            {^mports$} {
                return [macports::index::fetch_port $url $destdir]
            }
            {^https?$|^ftp$} {
                return [macports::fetch_port $url]
            }
            default {
                return -code error "Unsupported protocol $protocol"
            }
        }
    } else {
        return -code error "Can't parse url $url"
    }
}

# dportopen
# Deprecated version of the new mportopen proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportopen {porturl {options ""} {variations ""} {nocache ""}} {
    ui_warn "The dportopen proc is deprecated and will be going away soon, please use mportopen in the future!"
    mportopen $porturl $options $variations $nocache
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
    
    macports::worker_init $workername $portpath [macports::getportbuildpath $portpath] $options $variations

    $workername eval source Portfile

    # evaluate the variants
    if {[$workername eval eval_variants variations] != 0} {
    mportclose $mport
    error "Error evaluating variants"
    }

    ditem_key $mport provides [$workername eval return \$portname]

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
        if {[file isdirectory $pathToCategory]} {
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
proc _mportsearchpath {depregex search_path {executable 0}} {
    set found 0
    foreach path $search_path {
        if {![file isdirectory $path]} {
            continue
        }

        if {[catch {set filelist [readdir $path]} result]} {
            return -code error "$result ($path)"
            set filelist ""
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
    return $found
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

proc _libtest {mport depspec} {
    global env tcl_platform
    set depline [lindex [split $depspec :] 1]
    set prefix [_mportkey $mport prefix]
    
    if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FRAMEWORK_PATH)
    } else {
        lappend search_path /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
    }
    if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
        lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
    }
    if {[info exists env(DYLD_LIBRARY_PATH)]} {
        lappend search_path $env(DYLD_LIBRARY_PATH)
    }
    lappend search_path /lib /usr/lib /usr/X11R6/lib ${prefix}/lib
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

    return [_mportsearchpath $depregex $search_path]
}

### _bintest is private; subject to change without notice

proc _bintest {mport depspec} {
    global env
    set depregex [lindex [split $depspec :] 1]
    set prefix [_mportkey $mport prefix] 
    
    set search_path [split $env(PATH) :]
    
    set depregex \^$depregex\$
    
    return [_mportsearchpath $depregex $search_path 1]
}

### _pathtest is private; subject to change without notice

proc _pathtest {mport depspec} {
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

    return [_mportsearchpath $depregex $search_path]
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
    # Check for the presense of the port in the registry
    set workername [ditem_key $mport workername]
    set res [$workername eval registry_exists \${portname} \${portversion}]
    if {$res != 0} {
        ui_debug "[ditem_key $mport provides] is installed"
        return 1
    } else {
        return 0
    }
}

### _mportispresent is private; may change without notice

# Determine if some depspec is satisfied or if the given port is installed.
# We actually start with the registry (faster?)
#
# mport     the port to test (to figure out if it's present)
# depspec   the dependency test specification (path, bin, lib, etc.)
proc _mportispresent {mport depspec} {
    # Check for the presense of the port in the registry
    set workername [ditem_key $mport workername]
    ui_debug "Searching for dependency: [ditem_key $mport provides]"
    if {[catch {set reslist [$workername eval registry_installed \${portname}]} res]} {
        set res 0
    } else {
        set res [llength $reslist]
    }
    if {$res != 0} {
        ui_debug "Found Dependency: receipt exists for [ditem_key $mport provides]"
        return 1
    } else {
        # The receipt test failed, use one of the depspec regex mechanisms
        ui_debug "Didn't find receipt, going to depspec regex for: [ditem_key $mport provides]"
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

### _mportexec is private; may change without notice

proc _mportexec {target mport} {
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
        return 0
    } else {
        # An error occurred.
        return 1
    }
}

# dportexec
# Deprecated version of the new mportexec proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportexec {mport target} {
    ui_warn "The dportexec proc is deprecated and will be going away soon, please use mportexec in the future!"
    mportexec $mport $target
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
    
    # Before we build the port, we must build its dependencies.
    # XXX: need a more general way of comparing against targets
    set dlist {}
    if {$target == "configure" || $target == "build"
        || $target == "test"
        || $target == "destroot" || $target == "install"
        || $target == "archive"
        || $target == "pkg" || $target == "mpkg"
        || $target == "rpm" || $target == "dpkg" } {

        if {[mportdepends $mport $target] != 0} {
            return 1
        }
        
        # Select out the dependents along the critical path,
        # but exclude this mport, we might not be installing it.
        set dlist [dlist_append_dependents $macports::open_mports $mport {}]
        
        dlist_delete dlist $mport

        # install them
        # xxx: as with below, this is ugly.  and deps need to be fixed to
        # understand Port Images before this can get prettier
        if { [string equal ${macports::registry.installtype} "image"] } {
            set result [dlist_eval $dlist _mportinstalled [list _mportexec "activate"]]
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

    return $result
}

proc macports::getsourcepath {url} {
    global macports::portdbpath
    set source_path [split $url ://]
    return [file join $portdbpath sources [lindex $source_path 3] [lindex $source_path 4] [lindex $source_path 5]]
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

# dportsync
# Deprecated version of the new mportsync proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportsync {} {
    ui_warn "The dportsync proc is deprecated and will be going away soon, please use mportsync in the future!"
    mportsync
}

proc mportsync {} {
    global macports::sources macports::portdbpath macports::rsync_options tcl_platform
    global macports::autoconf::rsync_path 
    
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
                    set svn_commandline "[macports::findBinary svn ${macports::autoconf::svn_path}] update --non-interactive ${portdir}"
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
                        return -code error "Synchronization of the local ports tree failed doing an svn update"
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
                    return -code error "Synchronization the local ports tree failed doing rsync"
                }
                if {[catch {system "chmod -R a+r \"$destdir\""}]} {
                    ui_warn "Setting world read permissions on parts of the ports tree failed, need root?"
                }
            }
            {^https?$|^ftp$} {
                set indexfile [macports::getindex $source]
                file mkdir [file dirname $indexfile]
                exec curl -L -s -S -o $indexfile $source/PortIndex
            }
            default {
                ui_warn "Unknown synchronization protocol for $source"
            }
        }
    }
}

# dportsearch
# Deprecated version of the new mportsearch proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportsearch {pattern {case_sensitive yes} {matchstyle regexp} {field name}} {
    ui_warn "The dportsearch proc is deprecated and will be going away soon, please use mportsearch in the future!"
    mportsearch $pattern $case_sensitive $matchstyle $field
}

proc mportsearch {pattern {case_sensitive yes} {matchstyle regexp} {field name}} {
    global macports::portdbpath macports::sources
    set matches [list]
    set easy [expr { $field == "name" }]
    
    set found 0
    foreach source $sources {
        set flags [lrange $source 1 end]
        set source [lindex $source 0]
        if {[macports::getprotocol $source] == "mports"} {
            array set attrs [list name $pattern]
            set res [macports::index::search $macports::portdbpath $source [array get attrs]]
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
                            switch -regexp -- [macports::getprotocol ${source}] {
                                {^rsync$} {
                                    # Rsync files are local
                                    set source_url "file://[macports::getsourcepath $source]"
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
                    ui_warn "It looks like your PortIndex file may be corrupt."
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

# dportinfo
# Deprecated version of the new mportinfo proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportinfo {mport} {
    ui_warn "The dportinfo proc is deprecated and will be going away soon, please use mportinfo in the future!"
    mport info $mport
}

proc mportinfo {mport} {
    set workername [ditem_key $mport workername]
    return [$workername eval array get PortInfo]
}

# dportclose
# Deprecated version of the new mportclose proc, listed here as backwards
# compatibility glue for API clients that haven't updated to the new naming
proc dportclose {mport} {
    ui_warn "The dportclose proc is deprecated and will be going away soon, please use mportclose in the future!"
    mportclose $mport
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
proc mportdepends {mport {target ""} {recurseDeps 1} {skipSatisfied 1} {accDeps {}}} {

    array set portinfo [mportinfo $mport]
    set depends {}
    set deptypes {}
        
    # Determine deptypes to look for based on target
    switch $target {
        configure   { set deptypes "depends_lib" }
        
        build       { set deptypes "depends_lib depends_build" }
        
        test        -
        destroot    -
        install     -
        archive     -
        pkg         -
        mpkg        -
        rpm         -
        dpkg        -
        ""          { set deptypes "depends_lib depends_build depends_run" }
    }
    
    # Gather the dependencies for deptypes
    foreach deptype $deptypes {
        # Add to the list of dependencies if the option exists and isn't empty.
        if {[info exists portinfo($deptype)] && $portinfo($deptype) != ""} {
            set depends [concat $depends $portinfo($deptype)]
        }
    }

    set subPorts {}
    
    foreach depspec $depends {
        # grab the portname portion of the depspec
        set dep_portname [lindex [split $depspec :] end]
        
        # Find the porturl
        if {[catch {set res [mportsearch $dep_portname false exact]} error]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "Internal error: port search failed: $error"
            return 1
        }
        foreach {name array} $res {
            array set portinfo $array
            if {[info exists portinfo(porturl)]} {
                set porturl $portinfo(porturl)
                break
            }
        }

        if {![info exists porturl]} {
            ui_error "Dependency '$dep_portname' not found."
            return 1
        }

        set options [ditem_key $mport options]
        set variations [ditem_key $mport variations]

        # Figure out the subport.   
        set subport [mportopen $porturl $options $variations]

        # Is that dependency satisfied or this port installed?
        # If we don't skip or if it is not, add it to the list.
        if {!$skipSatisfied || ![_mportispresent $subport $depspec]} {
            # Append the sub-port's provides to the port's requirements list.
            ditem_append_unique $mport requires "[ditem_key $subport provides]"
    
            if {$recurseDeps} {
                # Skip the port if it's already in the accumulated list.
                if {[lsearch $accDeps $dep_portname] == -1} {
                    # Add it to the list
                    lappend accDeps $dep_portname
                
                    # We'll recursively iterate on it.
                    lappend subPorts $subport
                }
            }
        }
    }

    # Loop on the subports.
    if {$recurseDeps} {
        foreach subport $subPorts {
            # Sub ports should be installed (all dependencies must be satisfied).
            set res [mportdepends $subport "" $recurseDeps $skipSatisfied $accDeps]
            if {$res != 0} {
                return $res
            }
        }
    }
    
    return 0
}

# selfupdate procedure
proc macports::selfupdate {{optionslist {}}} {
    global macports::prefix macports::portdbpath macports::rsync_server macports::rsync_dir macports::rsync_options
    global macports::autoconf::macports_version macports::autoconf::rsync_path
    array set options $optionslist
    
    if { [info exists options(ports_force)] && $options(ports_force) == "yes" } {
        set use_the_force_luke yes
        ui_debug "Forcing a rebuild of the MacPorts base system."
    } else {
        set use_the_force_luke no
        ui_debug "Rebuilding the MacPorts base system if needed."
    }
    # syncing ports tree. We expect the user have rsync:// in the sources.conf
    if {[catch {mportsync} result]} {
        return -code error "Couldn't sync the ports tree: $result"
    }

    set mp_source_path [file join $portdbpath sources ${rsync_server} ${rsync_dir}/]
    if {![file exists $mp_source_path]} {
        file mkdir $mp_source_path
    }
    ui_debug "MacPorts sources dir: $mp_source_path"

    # get user of the MacPorts system
    set user [file attributes [file join $portdbpath sources/] -owner]
    ui_debug "Setting user: $user"

    # echo MacPorts version
    ui_msg "\nMacPorts base version $macports::autoconf::macports_version installed"

    ui_debug "Updating using rsync"
    if { [catch { system "$rsync_path $rsync_options rsync://${rsync_server}/${rsync_dir} $mp_source_path" } ] } {
        return -code error "Error: rsync failed in selfupdate"
    }

    # get downloaded MacPorts version
    set fd [open [file join $mp_source_path config mp_version] r]
    gets $fd macports_version_new
    close $fd
    ui_msg "\nDownloaded MacPorts base version $macports_version_new"

    # check if we we need to rebuild base
    if {[rpm-vercomp $macports_version_new $macports::autoconf::macports_version] > 0 || $use_the_force_luke == "yes"} {
        ui_msg "Configuring, Building and Installing new MacPorts base"
        # check if $prefix/bin/port is writable, if so we go !
        # get installation user / group 
        set owner root
        set group admin
        set portprog [file join $prefix bin port]
        if {[file exists $portprog ]} {
            # set owner
            set owner [file attributes $portprog -owner]
            # set group
            set group [file attributes $portprog -group]
        }
        set p_user [exec /usr/bin/whoami]
        if {[file writable $portprog] || [string equal $p_user $owner] } {
            ui_debug "permissions OK"
        } else {
            return -code error "Error: $p_user cannot write to ${prefix}/bin - try using sudo"
        }
        ui_debug "Setting owner: $owner group: $group"

        set mp_tclpackage_path [file join $portdbpath .tclpackage]
        if { [file exists $mp_tclpackage_path]} {
            set fd [open $mp_tclpackage_path r]
            gets $fd tclpackage
            close $fd
        } else {
            set tclpackage [file join ${prefix} share macports Tcl]
        }
        # do the actual installation of new base
        ui_debug "Install in: $prefix as $owner : $group - TCL-PACKAGE in $tclpackage"
        if { [catch { system "cd $mp_source_path && ./configure --prefix=$prefix --with-install-user=$owner --with-install-group=$group --with-tclpackage=$tclpackage && make && make install" } result] } {
            return -code error "Error installing new MacPorts base: $result"
        }
    } else {
        ui_msg "\nThe MacPorts installation is not outdated and so was not updated"
    }

    # set the macports system to the right owner 
    ui_debug "Setting ownership to $user"
    if { [catch { exec chown -R $user [file join $portdbpath sources/] } result] } {
        return -code error "Couldn't change permissions: $result"
    }

    # set the right version
    ui_msg "selfupdate done!"

    return 0
}

proc macports::version {} {
    global macports::autoconf::macports_version
    
    return $macports::autoconf::macports_version

}

# upgrade procedure
proc macports::upgrade {portname dspec variationslist optionslist {depscachename ""}} {
    global macports::registry.installtype
    global macports::portarchivemode
    array set options $optionslist
    array set variations $variationslist
    if {![string match "" $depscachename]} {
        upvar $depscachename depscache
    } 

    # set to no-zero is epoch overrides version
    set epoch_override 0

    # check if the port is in tree
    if {[catch {mportsearch $portname false exact} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "port search failed: $result"
        return 1
    }
    # argh! port doesnt exist!
    if {$result == ""} {
        ui_error "No port $portname found."
        return 1
    }
    # fill array with information
    array set portinfo [lindex $result 1]

    # set version_in_tree and revision_in_tree
    if {![info exists portinfo(version)]} {
        ui_error "Invalid port entry for $portname, missing version"
        return 1
    }
    set version_in_tree "$portinfo(version)"
    set revision_in_tree "$portinfo(revision)"
    set epoch_in_tree "$portinfo(epoch)"

    # the depflag tells us if we should follow deps (this is for stuff installed outside MacPorts)
    # if this is set (not 0) we dont follow the deps
    set depflag 0

    # set version_installed and revision_installed
    set ilist {}
    if { [catch {set ilist [registry::installed $portname ""]} result] } {
        if {$result == "Registry error: $portname not registered as installed." } {
            ui_debug "$portname is *not* installed by MacPorts"
            # open porthandle    
            set porturl $portinfo(porturl)
            if {![info exists porturl]} {
                set porturl file://./    
            }    
            if {[catch {set workername [mportopen $porturl [array get options] ]} result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    ui_error "Unable to open port: $result"        
                    return 1
            }

            if {![_mportispresent $workername $dspec ] } {
                # port in not installed - install it!
                if {[catch {set result [mportexec $workername install]} result]} {
                    global errorInfo
                    ui_debug "$errorInfo"
                    ui_error "Unable to exec port: $result"
                    return 1
                }
            } else {
                # port installed outside MacPorts
                ui_debug "$portname installed outside the MacPorts system"
                set depflag 1
            }

        } else {
            ui_error "Checking installed version failed: $result"
            exit 1
        }
    }
    set anyactive 0
    set version_installed {}
    set revision_installed {}
    set epoch_installed 0
    if {$ilist == ""} {
        # XXX  this sets $version_installed to $version_in_tree even if not installed!!
        set version_installed $version_in_tree
        set revision_installed $revision_in_tree
        # That was a very dirty hack showing how ugly our depencendy and upgrade code is.
        # To get it working when user provides -f, we also need to set the variant to
        # avoid a future failure.
        set variant ""
    } else {
        # a port could be installed but not activated
        # so, deactivate all and save newest for activation later
        set num 0
        set variant ""
        foreach i $ilist {
            set variant [lindex $i 3]
            set version [lindex $i 1]
            set revision [lindex $i 2]
            if { $version_installed == {} ||
                    [rpm-vercomp $version $version_installed] > 0
                    || ([rpm-vercomp $version $version_installed] == 0
                        && [rpm-vercomp $revision $revision_installed] > 0)} {
                set version_installed $version
                set revision_installed $revision
                set epoch_installed [registry::property_retrieve [registry::open_entry $portname [lindex $i 1] [lindex $i 2] $variant] epoch]
                set num $i
            }

            set isactive [lindex $i 4]
            if {$isactive == 1} {
                if { [rpm-vercomp $version_installed $version] < 0
                        || ([rpm-vercomp $version_installed $version] == 0
                            && [rpm-vercomp $revision_installed $revision] < 0)} {
                    # deactivate version
                    if {[catch {portimage::deactivate $portname $version $optionslist} result]} {
                        global errorInfo
                        ui_debug "$errorInfo"
                        ui_error "Deactivating $portname $version_installed_$revision_installed failed: $result"
                        return 1
                    }
                }
            }
        }
        if { [lindex $num 4] == 0 && 0 == [string compare "image" ${macports::registry.installtype}] } {
            # activate the latest installed version
            if {[catch {portimage::activate $portname ${version_installed}_$revision_installed$variant $optionslist} result]} {
                global errorInfo
                ui_debug "$errorInfo"
                ui_error "Activating $portname ${version_installed}_$revision_installed failed: $result"
                return 1
            }
        }
    }

    # output version numbers
    ui_debug "epoch: in tree: $epoch_in_tree installed: $epoch_installed"
    ui_debug "$portname ${version_in_tree}_$revision_in_tree exists in the ports tree"
    ui_debug "$portname ${version_installed}_$revision_installed is installed"

    # set the nodeps option  
    if {![info exists options(ports_nodeps)]} {
        set nodeps no
    } else {
        set nodeps yes
    }

    if {$nodeps == "yes" || $depflag == 1} {
        ui_debug "Not following dependencies"
        set depflag 0
    } else {
        # build depends is upgraded
        if {[info exists portinfo(depends_build)]} {
            foreach i $portinfo(depends_build) {
                if {![llength [array get depscache $i]]} {
                set d [lindex [split $i :] end]
                    set depscache($i) 1
                    upgrade $d $i $variationslist $optionslist depscache
                } 
            }
        }
        # library depends is upgraded
        if {[info exists portinfo(depends_lib)]} {
            foreach i $portinfo(depends_lib) {
                if {![llength [array get depscache $i]]} {
                set d [lindex [split $i :] end]
                    set depscache($i) 1
                    upgrade $d $i $variationslist $optionslist depscache
                } 
            }
        }
        # runtime depends is upgraded
        if {[info exists portinfo(depends_run)]} {
            foreach i $portinfo(depends_run) {
                if {![llength [array get depscache $i]]} {
                set d [lindex [split $i :] end]
                    set depscache($i) 1
                    upgrade $d $i $variationslist $optionslist depscache
                } 
            }
        }
    }

    # check installed version against version in ports
    if { ( [rpm-vercomp $version_installed $version_in_tree] > 0
            || ([rpm-vercomp $version_installed $version_in_tree] == 0
                && [rpm-vercomp $revision_installed $revision_in_tree] >= 0 ))
        && ![info exists options(ports_force)] } {
        ui_debug "No need to upgrade! $portname ${version_installed}_$revision_installed >= $portname ${version_in_tree}_$revision_in_tree"
        if { $epoch_installed >= $epoch_in_tree } {
            # Check if we have to do dependents
            if {[info exists options(ports_do_dependents)]} {
                # We do dependents ..
                set options(ports_nodeps) 1

                registry::open_dep_map
                set deplist [registry::list_dependents $portname]

                if { [llength deplist] > 0 } {
                    foreach dep $deplist {
                        set mpname [lindex $dep 2] 
                        macports::upgrade $mpname "port:$mpname" [array get variations] [array get options]
                    }
                }
            }

            return 0
        } else {
            ui_debug "epoch override ... upgrading!"
            set epoch_override 1
        }
    }

    # open porthandle
    set porturl $portinfo(porturl)
    if {![info exists porturl]} {
        set porturl file://./
    }

    # check if the variants is present in $version_in_tree
    set oldvariant $variant
    set variant [split $variant +]
    ui_debug "variants to install $variant"
    if {[info exists portinfo(variants)]} {
        set avariants $portinfo(variants)
    } else {
        set avariants {}
    }
    ui_debug "available variants are : $avariants"
    foreach v $variant {
        if {[lsearch $avariants $v] == -1} {
        } else {
            ui_debug "variant $v is present in $portname ${version_in_tree}_$revision_in_tree"
            set variations($v) "+"
        }
    }
    ui_debug "new portvariants: [array get variations]"
    
    if {[catch {set workername [mportopen $porturl [array get options] [array get variations]]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Unable to open port: $result"
        return 1
    }

    # install version_in_tree
    if {0 == [string compare "yes" ${macports::portarchivemode}]} {
        set upgrade_action "archive"
    } else {
        set upgrade_action "destroot"
    }

    if {[catch {set result [mportexec $workername $upgrade_action]} result] || $result != 0} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Unable to upgrade port: $result"
        return 1
    }

    # uninstall old ports
    if {[info exists options(port_uninstall_old)] || $epoch_override == 1 || [info exists options(ports_force)] || 0 != [string compare "image" ${macports::registry.installtype}] } {
        # uninstall old
        ui_debug "Uninstalling $portname ${version_installed}_$revision_installed$oldvariant"
        if {[catch {portuninstall::uninstall $portname ${version_installed}_$revision_installed$oldvariant $optionslist} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "Uninstall $portname ${version_installed}_$revision_installed$oldvariant failed: $result"
            return 1
        }
    } else {
        # XXX deactivate version_installed
        if {[catch {portimage::deactivate $portname ${version_installed}_$revision_installed$oldvariant $optionslist} result]} {
            global errorInfo
            ui_debug "$errorInfo"
            ui_error "Deactivating $portname ${version_installed}_$revision_installed failed: $result"
            return 1
        }
    }

    if {[catch {set result [mportexec $workername install]} result]} {
        global errorInfo
        ui_debug "$errorInfo"
        ui_error "Couldn't activate $portname ${version_in_tree}_$revision_in_tree$oldvariant: $result"
        return 1
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
                macports::upgrade $mpname "port:$mpname" [array get variations] [array get options]
            }
        }
    }

    
    # close the port handle
    mportclose $workername
}

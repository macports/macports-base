# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# reclaim.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Inc.
# Copyright (c) 2004 - 2005 Paul Guyot, <pguyot@kallisys.net>.
# Copyright (c) 2004 - 2006 Ole Guldberg Jensen <olegb@opendarwin.org>.
# Copyright (c) 2004 - 2005 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2004 - 2014 The MacPorts Project
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

# TODO:

# Finished:
# Add ui_debug statments
# Catch some error-prone areas.
# Remove the useless/structure comments and add actual docstrings.
# Add copyright notice
# Check if inactive ports are dependents of other ports.
# Add test cases
# Add distfile version checking.
# Pretty sure we should be using ui_msg, instead of puts and what not. Should probably add that.
# Register the "port cleanup" command with port.tcl and all that involves.
# Implement a hash-map, or multidimensional array for ease of port info keeping. Write it yourself if you have to.
# Figure out what the hell is going on with "port clean all" vs "port clean installed" the 'clean' target is provided by this package

# XXX: all prompts for the user need to use the ui_ask_* API
#      (definitely required for GUI support)

package provide reclaim 1.0

package require registry_uninstall 2.0
package require macports

namespace eval reclaim {

    proc main {args} {
        # The main function. Calls each individual function that needs to be run.
        # Args: 
        #           None
        # Returns:
        #           None

        uninstall_inactive
        remove_distfiles
        update_last_run
    }

    proc walk_files {dir files_in_use unused_name} {
        # Recursively walk the given directory $dir and build a list of all files that are present on-disk but not listed in $files_in_use.
        # The list of unused files will be stored in the variable given by $unused_name
        #
        # Args:
        #           dir             - A string path of the given directory to walk through
        #           files_in_use    - A sorted list of the full paths for all distfiles from installed ports
        #           unused_name     - The name of a list in the caller to which unused files will be appended

        upvar $unused_name unused

        foreach item [readdir $dir] {
            set currentPath [file join $dir $item]
            switch -exact -- [file type $currentPath] {
                directory {
                    walk_files $currentPath $files_in_use unused
                }
                file {
                    if {[lsearch -exact -sorted $files_in_use $currentPath] == -1} {
                        ui_info "Found unused distfile $currentPath"
                        lappend unused $currentPath
                    }
                }
            }
        }
    }

    proc remove_distfiles {} {
        # Check for distfiles in both the root, and home directories. If found, delete them.
        # Args:
        #               None
        # Returns:
        #               0 on successful execution

        global macports::portdbpath
        global macports::user_home

        # The root and home distfile folder locations, respectively. 
        set root_dist       [file join ${macports::portdbpath} distfiles]
        set home_dist       ${macports::user_home}/.macports$root_dist

        set port_info    [get_info]
        set files_in_use [list]

        set fancyOutput [expr {   ![macports::ui_isset ports_debug] \
                               && ![macports::ui_isset ports_verbose] \
                               && [info exists macports::ui_options(progress_generic)]}]
        if {$fancyOutput} {
            set progress $macports::ui_options(progress_generic)
        } else {
            # provide a no-op if there is no progress function
            proc noop {args} {}
            set progress noop
        }

        ui_msg "$macports::ui_prefix Building list of files still in use"
        set port_count [llength $port_info]
        set i 1
        $progress start

        foreach port $port_info {
            set name     [lindex $port 0]
            set version  [lindex $port 1]
            set revision [lindex $port 2]
            set variants [lindex $port 3]

            # Get mport reference
            try -pass_signal {
                set mport [mportopen_installed $name $version $revision $variants {}]
            } catch {{*} eCode eMessage} {
                $progress intermission
                ui_warn [msgcat::mc "Failed to open port %s from registry: %s" $name $eMessage]
                continue
            }

            # Setup sub-Tcl-interpreter that executed the installed port
            set workername [ditem_key $mport workername]

            # Append that port's distfiles to the list
            set dist_subdir [$workername eval return {$dist_subdir}]
            set distfiles   [$workername eval return {$distfiles}]
            set patchfiles  [$workername eval [list if {[exists patchfiles]} { return $patchfiles } else { return [list] }]]

            foreach distfile [concat $distfiles $patchfiles] {
                set root_path [file join $root_dist $dist_subdir $distfile]
                set home_path [file join $home_dist $dist_subdir $distfile]

                # Add the full file path to the list, depending where it's located.
                if {[file isfile $root_path]} {
                    ui_info "Keeping $root_path"
                    lappend files_in_use $root_path
                }
                if {[file isfile $home_path]} {
                    ui_info "Keeping $home_path"
                    lappend files_in_use $home_path
                }
            }

            $progress update $i $port_count
            incr i
        }

        $progress finish

        ui_msg "$macports::ui_prefix Searching for unused files"

        # sort so we can use binary search in walk_files
        set files_in_use [lsort -unique $files_in_use]

        ui_debug "Calling walk_files on root directory."

        set superfluous_files [list]
        walk_files $root_dist $files_in_use superfluous_files

        if {[file exists $home_dist]} {
            ui_debug "Calling walk_files on home directory."
            walk_files $home_dist $files_in_use superfluous_files
        }

        set num_superfluous_files [llength $superfluous_files]
        set size_superfluous_files 0
        foreach f $superfluous_files {
            incr size_superfluous_files [file size $f]
        }
        if {[llength $superfluous_files] > 0} {
            if {[info exists macports::ui_options(questions_alternative)]} {
                array set alternatives {d delete k keep l list}
                while 1 {
                    set retstring [$macports::ui_options(questions_alternative) [msgcat::mc \
                        "Found %d files (total %s) that are no longer needed and can be deleted." \
                        $num_superfluous_files [bytesize $size_superfluous_files]] "deleteFilesQ" "alternatives" {k}]
                
                    switch $retstring {
                        d {
                            ui_msg "Deleting..."
                            foreach f $superfluous_files {
                                set root_length [string length "${root_dist}/"]
                                set home_length [string length "${home_dist}/"]

                                try -pass_signal {
                                    ui_info [msgcat::mc "Deleting unused file %s" $f]
                                    file delete -- $f

                                    set directory [file dirname $f]
                                    while {1} {
                                        set is_below_root [string equal -length $root_length $directory "${root_dist}/"]
                                        set is_below_home [string equal -length $home_length $directory "${home_dist}/"]

                                        if {!$is_below_root && !$is_below_home} {
                                            break
                                        }

                                        if {[llength [readdir $directory]] > 0} {
                                            break
                                        }

                                        ui_info [msgcat::mc "Deleting empty directory %s" $directory]
                                        try -pass_signal {
                                            file delete -- $directory
                                        } catch {{*} eCode eMessage} {
                                            ui_warn [msgcat::mc "Could not delete empty directory %s: %s" $directory $eMesage]
                                        }
                                        set directory [file dirname $directory]
                                    }
                                } catch {{*} eCode eMessage} {
                                    ui_warn [msgcat::mc "Could not delete %s: %s" $f $eMessage]
                                }
                            }
                            break
                        }
                        k {
                            ui_msg "OK, keeping the files."
                            break
                        }
                        l {
                            foreach f $superfluous_files {
                                ui_msg "  $f"
                            }
                        }
                    }
                }
            }
        } else {
            ui_msg "No unused files found."
        }

        return 0
    }

    proc is_inactive {port} {

        # Determines whether a port is inactive or not.
        # Args: 
        #           port - An array where the fourth item in it is the activity of the port.
        # Returns:
        #           1 if inactive, 0 if active.

        if {[lindex $port 4] == 0} {
            ui_debug "Port [lindex $port 0] is inactive."
            return 1
        }
        ui_debug "Port [lindex $port 0] is not inactive."
        return 0
    }

    proc get_info {} {

        # Gets the information of all installed ports (those returned by registry::installed), and returns it in a
        # multidimensional list.
        #
        # Args:
        #           None
        # Returns:
        #           A multidimensional list where each port is a sublist, i.e., [{first port info} {second port info} {...}]
        #           Indexes of each sublist are: 0 = name, 1 = version, 2 = revision, 3 = variants, 4 = activity, and 5 = epoch.
        
        try -pass_signal {
            return [registry::installed]
        } catch {*} {
            ui_error "no installed ports found."
            return {}
        }
    }

    proc update_last_run {} {
        
        # Updates the last_reclaim textfile with the newest time the code has been ran. 
        #
        # Args:
        #           None
        # Returns:
        #           None

        ui_debug "Updating last run information."

        set path [file join ${macports::portdbpath} last_reclaim]
        set fd -1
        try -pass_signal {
            set fd [open $path w]
            puts $fd [clock seconds]
        } catch {*} {
            # Ignore error silently
        } finally {
            if {$fd != -1} {
                close $fd
            }
        }
    }

    proc check_last_run {} {

        # Periodically warns the user that they haven't run 'port reclaim' in two weeks, and that they should consider doing so.
        # 
        # Args:
        #           None
        # Returns: 
        #           None

        ui_debug "Checking time since last reclaim run"

        set path [file join ${macports::portdbpath} last_reclaim]

        set fd -1
        set time ""
        try -pass_signal {
            set fd [open $path r]
            set time [gets $fd]
        } catch {*} {
            # Ignore error silently; the file might not have been created yet
        } finally {
            if {$fd != -1} {
                close $fd
            }
        }
        if {$time ne ""} {
            if {[clock seconds] - $time > 1209600} {
                set msg "You haven't run 'sudo port reclaim' in two weeks. It's recommended you run this regularly to reclaim disk space."

                if {[file writable $macports::portdbpath] && [info exists macports::ui_options(questions_yesno)]} {
                    set retval [$macports::ui_options(questions_yesno) $msg "ReclaimPrompt" "" {y} 0 "Would you like to run it now?"]
                    if {$retval == 0} {
                        # User said yes, run port reclaim
                        macports::reclaim_main
                    } else {
                        # User said no, ask again in two weeks
                        # Change this time frame if a consensus is agreed upon
                        update_last_run
                    }
                } else {
                    ui_warn $msg
                }
            }
        }
    }

    proc uninstall_inactive {} {

        # Attempts to uninstall all inactive ports. (Performance is now O(N)!)
        #
        # Args: 
        #           None
        # Returns: 
        #           0 if execution was successful. Errors (for now) if execution wasn't. 

        set ports           [get_info]
        set inactive_ports  [list]
        set inactive_names  [list]
        set inactive_count  0

        ui_debug "Iterating through all inactive ports."

        foreach port $ports {

            if { [is_inactive $port] } {
                lappend inactive_ports $port
                lappend inactive_names [lindex $port 0]
                incr inactive_count
            }
        }

        if { $inactive_count == 0 } {
            ui_msg "Found no inactive ports."

        } else {

            ui_msg "Found inactive ports: $inactive_names."
            if {[info exists macports::ui_options(questions_multichoice)]} {
                set retstring [$macports::ui_options(questions_multichoice) "Would you like to uninstall these ports?" "" $inactive_names]

                if {[llength $retstring] > 0} {
                    foreach i $retstring {
                        set port [lindex $inactive_ports $i]
                        set name [lindex $port 0]

                        ui_msg "Uninstalling: $name"

                        # Note: 'uninstall' takes a name, version, revision, variants and an options list. 
                        try -pass_signal {
                            registry_uninstall::uninstall $name [lindex $port 1] [lindex $port 2] [lindex $port 3] {}
                        } catch {{*} eCode eMessage} {
                            ui_error "Error uninstalling $name: $eMessage"
                        }
                    }
                } else {
                    ui_msg "Not uninstalling ports."
                }
            }
        }
        return 0
    }
}

# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# reclaim.tcl
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

package provide reclaim 1.0

package require registry_uninstall 2.0
package require macports

namespace eval reclaim {

    proc main {opts} {
        # The main function. Calls each individual function that needs to be run.
        # Args: 
        #           opts - options array
        # Returns:
        #           None

        array set options $opts
        if {[info exists options(ports_reclaim_enable-reminders)]} {
            ui_info "Enabling port reclaim reminders."
            update_last_run
            return
        }
        if {[info exists options(ports_reclaim_disable-reminders)]} {
            ui_info "Disabling port reclaim reminders."
            write_last_run_file disabled
            return
        }

        uninstall_unrequested
        uninstall_inactive
        remove_distfiles

        if {![macports::global_option_isset ports_dryrun]} {
            set last_run_contents [read_last_run_file]
            if {$last_run_contents eq ""} {
                set msg "This appears to be the first time you have run 'port reclaim'."

                if {[info exists macports::ui_options(questions_yesno)]} {
                    set retval [$macports::ui_options(questions_yesno) $msg "ReclaimPrompt" "" {y} 0 "Would you like to be reminded to run it every two weeks?"]
                    if {$retval != 0} {
                        # User said no, store disabled flag
                        set last_run_contents disabled
                        write_last_run_file $last_run_contents
                        ui_msg "Reminders disabled. Run 'port reclaim --enable-reminders' to enable."
                    } else {
                        # the last run file will be updated below
                        ui_msg "Reminders enabled. Run 'port reclaim --disable-reminders' to disable."
                    }
                } else {
                    # couldn't ask the question, leave disabled for now
                    set last_run_contents disabled
                }
            }
            if {$last_run_contents ne "disabled"} {
                update_last_run
            }
        }
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
                    if {$item eq ".turd_MacPorts"} {
                        # .turd_MacPorts files are created by MacPorts when creating the MacPorts
                        # installer packages from the MacPorts port so that empty directories are
                        # not deleted after destroot. Treat those files as if they were not there.
                        continue
                    }
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

        ui_msg "$macports::ui_prefix Building list of distfiles still in use"
        set installed_ports [registry::entry imaged]
        set port_count [llength $installed_ports]
        set i 1
        $progress start

        foreach port $installed_ports {
            # Get mport reference
            try -pass_signal {
                set mport [mportopen_installed [$port name] [$port version] [$port revision] [$port variants] {}]
            } catch {{*} eCode eMessage} {
                $progress intermission
                ui_warn [msgcat::mc "Failed to open port %s from registry: %s" [$port name] $eMessage]
                continue
            }

            # Setup sub-Tcl-interpreter that executed the installed port
            set workername [ditem_key $mport workername]

            # Append that port's distfiles to the list
            set dist_subdir [$workername eval {set dist_subdir}]
            set distfiles   [$workername eval {set distfiles}]
            if {[catch {$workername eval {set patchfiles}} patchfiles]} {
                set patchfiles {}
            }

            foreach file [concat $distfiles $patchfiles] {
                # split distfile into filename and disttag
                set distfile [$workername eval "getdistname $file"]
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

            mportclose $mport

            $progress update $i $port_count
            incr i
        }

        $progress finish

        ui_msg "$macports::ui_prefix Searching for unused distfiles"

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
            array set alternatives {d delete k keep l list}
            while 1 {
                set retstring "d"
                if {[info exists macports::ui_options(questions_alternative)]} {
                    set retstring [$macports::ui_options(questions_alternative) [msgcat::mc \
                        "Found %d files (total %s) that are no longer needed and can be deleted." \
                        $num_superfluous_files [bytesize $size_superfluous_files]] "deleteFilesQ" "alternatives" {k}]
                }

                switch $retstring {
                    d {
                        if {[macports::global_option_isset ports_dryrun]} {
                            ui_msg "Deleting... (dry run)"
                        } else {
                            ui_msg "Deleting..."
                        }
                        foreach f $superfluous_files {
                            set root_length [string length "${root_dist}/"]
                            set home_length [string length "${home_dist}/"]

                            try -pass_signal {
                                if {[macports::global_option_isset ports_dryrun]} {
                                    ui_info [msgcat::mc "Skipping deletion of unused file %s (dry run)" $f]
                                } else {
                                    ui_info [msgcat::mc "Deleting unused file %s" $f]
                                    file delete -- $f
                                }

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

                                    if {[macports::global_option_isset ports_dryrun]} {
                                        ui_info [msgcat::mc "Skipping deletion of empty directory %s (dry run)" $directory]
                                    } else {
                                        ui_info [msgcat::mc "Deleting empty directory %s" $directory]
                                        try -pass_signal {
                                            file delete -- $directory
                                        } catch {{*} eCode eMessage} {
                                            ui_warn [msgcat::mc "Could not delete empty directory %s: %s" $directory $eMesage]
                                        }
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
        } else {
            ui_msg "No unused files found."
        }

        return 0
    }

    proc read_last_run_file {} {
        set path [file join ${macports::portdbpath} last_reclaim]

        set fd -1
        set contents ""
        try -pass_signal {
            set fd [open $path r]
            set contents [gets $fd]
        } catch {*} {
            # Ignore error silently; the file might not have been created yet
        } finally {
            if {$fd != -1} {
                close $fd
            }
        }
        return $contents
    }

    proc write_last_run_file {contents} {
        set path [file join ${macports::portdbpath} last_reclaim]
        set fd -1
        try -pass_signal {
            set fd [open $path w]
            puts $fd $contents
        } catch {*} {
            # Ignore error silently
        } finally {
            if {$fd != -1} {
                close $fd
            }
        }
    }

    proc update_last_run {} {

        # Updates the last_reclaim textfile with the newest time the code has been run.
        #
        # Args:
        #           None
        # Returns:
        #           None

        ui_debug "Updating last run information."

        write_last_run_file [clock seconds]
    }

    proc check_last_run {} {

        # Periodically warns the user that they haven't run 'port reclaim' in two weeks, and that they should consider doing so.
        # 
        # Args:
        #           None
        # Returns: 
        #           None

        set time [read_last_run_file]

        if {![string is wideinteger -strict $time]} {
            return 0
        }

        ui_debug "Checking time since last reclaim run"
        if {[clock seconds] - $time > 1209600} {
            set msg "You haven't run 'sudo port reclaim' in two weeks. It's recommended you run this regularly to reclaim disk space."

            if {[file writable $macports::portdbpath] && [info exists macports::ui_options(questions_yesno)]} {
                set retval [$macports::ui_options(questions_yesno) $msg "ReclaimPrompt" "" {y} 0 "Would you like to run it now?"]
                if {$retval == 0} {
                    # User said yes, run port reclaim
                    return [macports::reclaim_main {}]
                } else {
                    # User said no, ask again in two weeks
                    # Change this time frame if a consensus is agreed upon
                    update_last_run
                }
            } else {
                ui_warn $msg
            }
        }
        return 0
    }

    proc sort_portlist_by_dependendents {portlist} {
        # Sorts a list of port references such that dependents appear before
        # the ports they depend on.
        #
        # Args:
        #       portlist - the list of port references
        #
        # Returns:
        #       the list in dependency-sorted order

        foreach port $portlist {
            set portname [$port name]
            lappend ports_for_name($portname) $port
            if {![info exists dependents($portname)]} {
                set dependents($portname) {}
                foreach result [$port dependents] {
                    lappend dependents($portname) [$result name]
                }
            }
        }
        set ret {}
        foreach port $portlist {
            sortdependents_helper $port ports_for_name dependents seen ret
        }
        return $ret
    }

    proc sortdependents_helper {port up_ports_for_name up_dependents up_seen up_retlist} {
        upvar 1 $up_seen seen
        if {![info exists seen($port)]} {
            set seen($port) 1
            upvar 1 $up_ports_for_name ports_for_name $up_dependents dependents $up_retlist retlist
            foreach dependent $dependents([$port name]) {
                if {[info exists ports_for_name($dependent)]} {
                    foreach entry $ports_for_name($dependent) {
                        sortdependents_helper $entry ports_for_name dependents seen retlist
                    }
                }
            }
            lappend retlist $port
        }
    }

    proc uninstall_inactive {} {

        # Attempts to uninstall all inactive ports. (Performance is now O(N)!)
        #
        # Args:
        #           None
        # Returns:
        #           0 if execution was successful. Errors (for now) if execution wasn't.

        set inactive_ports  [list]
        set inactive_names  [list]
        set inactive_count  0

        ui_msg "$macports::ui_prefix Checking for inactive ports"

        foreach port [registry::entry imaged] {
            if {[$port state] eq "imaged"} {
                lappend inactive_ports $port
                incr inactive_count
            }
        }

        set inactive_ports [sort_portlist_by_dependendents $inactive_ports]
        foreach port $inactive_ports {
            lappend inactive_names "[$port name] @[$port version]_[$port revision][$port variants]"
        }

        if { $inactive_count == 0 } {
            ui_msg "Found no inactive ports."

        } else {
            set retval 0
            if {[info exists macports::ui_options(questions_yesno)]} {
                set retval [$macports::ui_options(questions_yesno) "Inactive ports found:" "" $inactive_names "y" 0 "Would you like to uninstall them?"]
            }

            if {${retval} == 0 && [macports::global_option_isset ports_dryrun]} {
                ui_msg "Skipping uninstall of inactive ports (dry run)"
            } elseif {${retval} == 0} {
                foreach port $inactive_ports {
                    # Note: 'uninstall' takes a name, version, revision, variants and an options list.
                    try -pass_signal {
                        registry_uninstall::uninstall [$port name] [$port version] [$port revision] [$port variants] {ports_force true}
                    } catch {{*} eCode eMessage} {
                        ui_error "Error uninstalling $name: $eMessage"
                    }
                }
            } else {
                ui_msg "Not uninstalling ports."
            }
        }
        return 0
    }


    proc uninstall_unrequested {} {

        # Attempts to uninstall unrequested ports no requested ports depend on
        #
        # Args:
        #           None
        # Returns:
        #           0 if execution was successful. Errors (for now) if execution wasn't.

        set unnecessary_ports  [list]
        set unnecessary_names  [list]
        set unnecessary_count  0

        array set isrequested {}

        ui_msg "$macports::ui_prefix Checking for unnecessary unrequested ports"

        array set ports {}

        foreach port [sort_portlist_by_dependendents [registry::entry imaged]] {
            set isrequested([$port name]) [registry::property_retrieve $port requested]
            set ports([$port name]) $port
            if {$isrequested([$port name]) == 0} {
                foreach dependent [$port dependents] {
                    if {$isrequested([$dependent name]) != 0} {
                        ui_debug "[$port name] is requested by [$dependent name]"
                        set isrequested([$port name]) 1
                        break
                    }
                }

                if {$isrequested([$port name]) == 0} {
                    lappend unnecessary_ports $port
                    lappend unnecessary_names [$port name]
                    incr unnecessary_count
                }
            }
        }

        if { $unnecessary_count == 0 } {
            ui_msg "Found no unrequested ports without requested dependents."

        } else {
            set retval 0
            if {[info exists macports::ui_options(questions_yesno)]} {
                set retval [$macports::ui_options(questions_yesno) "Unrequested ports without requested dependents found:" "" $unnecessary_names "y" 0 "Would you like to uninstall them?"]
            }

            if {${retval} == 0 && [macports::global_option_isset ports_dryrun]} {
                ui_msg "Skipping uninstall of unrequested ports (dry run)"
            } elseif {${retval} == 0} {
                foreach port $unnecessary_ports {
                    # Note: 'uninstall' takes a name, version, revision, variants and an options list.
                    try -pass_signal {
                        registry_uninstall::uninstall [$port name] [$port version] [$port revision] [$port variants] {ports_force true}
                    } catch {{*} eCode eMessage} {
                        ui_error "Error uninstalling $name: $eMessage"
                    }
                }
            } else {
                ui_msg "Not uninstalling ports; use 'port setrequested' mark a port as explicitly requested."
            }
        }
        return 0
    }
}

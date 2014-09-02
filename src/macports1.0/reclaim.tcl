# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# reclaim.tcl
# $Id: macports.tcl 119177 2014-04-18 22:35:29Z cal@macports.org $
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
# Check if inactive files are dependents for other files. 
# Add test cases
# Add distfile version checking.
# Pretty sure we should be using ui_msg, instead of puts and what not. Should probably add that.
# Register the "port cleanup" command with port.tcl and all that involves.
# Implement a hash-map, or multidimensional array for ease of app info keeping. Write it yourself if you have to.
# Figure out what the hell is going on with "port clean all" vs "port clean installed" the 'clean' target is provided by this package

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

    proc is_empty_dir {dir} {
        
        # Test if the given directory is empty.
        # Args:
        #           dir         - A string path of the given directory to test
        # Returns:
        #           0 if the directory is not empty, 1 if it is.

        # Get _all_ files
        set filenames [glob -nocomplain -tails -directory $dir * .*]

        # Yay complex statements! Use RE, lsearch, and llength to determine if the directory is empty.  
        expr {![llength [lsearch -all -not -regexp $filenames {^\.\.?$}]]}
    }

    proc walk_files {dir delete dist_paths} {

        # Recursively walk through each directory that isn't an installed port and if delete each file that isn't a directory if requested.
        # Args:
        #           dir             - A string path of the given directory to walk through
        #           delete          - Whether to delete each file found that isn't a directory or not. Set to 'yes' or 'no'. 
        #           dist_paths      - A list of the full paths for all distfiles from installed ports  
        # Returns: 
        #           'no' if no distfiles were found, and 'yes' if distfiles were found. 

        set found_distfile  no 
        set root_dist       [file join ${macports::portdbpath} distfiles]
        set home_dist       ${macports::user_home}/.macports/$root_dist

        foreach item [readdir $dir] {
            set currentPath [file join $dir $item]

            if {[file isdirectory $currentPath]} {
                walk_files $currentPath $delete $dist_paths
            } else {
                # If the current file isn't in the known-installed-distfiles
                if {[lsearch $dist_paths $currentPath] == -1} {
                    set found_distfile yes

                    ui_msg "Found unused distfile: $item"

                    if {$delete eq "yes"} {
                        ui_debug "Deleting file: $item"
                        ui_msg "Removing distfile: $item"

                        if {[catch {file delete $currentPath} error]} {
                            ui_error "something went wrong when trying to delete $currentPath: $error"
                        }
                    }
                }
            }
        }

        if {$dir ne $root_dist && $dir ne $home_dist && [llength [readdir $dir]] == 0} {
            # If the directory is empty, and this isn't the root folder, delete
            # it.
            ui_msg "Found empty directory: $dir. Attempting to delete."

            if {[catch {file delete -force $dir} error] } {
                ui_error "something went wrong when trying to delete $dir: $error"
            }
        }

        return $found_distfile
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
        set dist_path    [list]

        foreach port $port_info {

            set name        [lindex $port 0]
            set version     [lindex $port 1]
            set revision    [lindex $port 2]
            set variants    [lindex $port 3]

            # Get mport reference
            if {[catch {set mport [mportopen_installed $name $version $revision $variants {}]} error]} {
                ui_error "something went wrong when trying to get an mport reference."
            }

            # Setup sub-Tcl-interpreter that executed the installed port
            set workername [ditem_key $mport workername]

            # Append that port's distfiles to the list
            set subdir [$workername eval return \$dist_subdir]
            set name   [$workername eval return \$distfiles]

            set root_path [file join $root_dist $subdir $name]
            set home_path [file join $home_dist $subdir $name]

            # Add the full file path to the list, depending where it's located.
            if {[file isfile $root_path]} {
                ui_debug "Appending $root_path."
                lappend dist_path $root_path

            } else {
                if {[file isfile $home_path]} {
                    ui_debug "Appending $home_path"
                    lappend dist_path $home_path
                }
            }
        }

        ui_debug "Calling walk_files on root directory."

        # Walk through each directory, and delete any files found. Alert the user if no files were found.
        if {[walk_files $root_dist yes $dist_path] eq "no"} {
            ui_msg "No distfiles found in root directory."
        }

        if {[file exists $home_dist]} {

            ui_debug "Calling walk_files on home directory."

            if {[walk_files $home_dist yes $dist_path] eq "no"} {
                ui_msg "No distfiles found in home directory."
            }
        }

        return 0
    } 

    proc close_file {file} {

        # Closes the file, handling error catching if needed.
        #
        # Args: 
        #           file - The file handler
        # Returns:
        #           None
        if {[catch {close $file} error]} {
            ui_error "something went wrong when closing file, $file."
        }
    }

    proc is_inactive {app} {

        # Determine's whether an application is inactive or not.
        # Args: 
        #           app - An array where the fourth item in it is the activity of the application.
        # Returns:
        #           1 if inactive, 0 if active.

        if {[lindex $app 4] == 0} {
            ui_debug "App, [lindex $app 0], is inactive."
            return 1
        }
        ui_debug "App, [lindex $app 0], is not inactive."
        return 0
    }

    proc get_info {} {

        # Get's the information of all installed appliations (those returned by registry::installed), and returns it in a
        # multidimensional list.
        #
        # Args:
        #           None
        # Returns:
        #           A multidimensional list where each app is a sublist, i.e., [{First Application Info} {Second Application Info} {...}]
        #           Indexes of each sublist are: 0 = name, 1 = version, 2 = revision, 3 = variants, 4 = activity, and 5 = epoch.
        
        if {[catch {set installed [registry::installed]} result]} {
            ui_error "no installed applications found."
            return {}
        }

        return $installed
    }

    proc update_last_run {} {
        
        # Updates the last_reclaim textfile with the newest time the code has been ran. 
        #
        # Args:
        #           None
        # Returns:
        #           None

        ui_debug "Updating last run information."

        set path    [file join ${macports::portdbpath} last_reclaim.txt]
        set fd      [open $path w]
        puts $fd    [clock seconds]
        close_file $fd
    }

    proc check_last_run {} {

        # Periodically warn's the user that they haven't run 'port reclaim' in two weeks, and that they should consider doing so.
        # 
        # Args:
        #           None
        # Returns: 
        #           None

        ui_debug "Checking last run information."

        set path [file join ${macports::portdbpath} last_reclaim.txt]

        if {[file exists $path]} {

            set fd      [open $path r]
            set time    [gets $fd]
            close_file $fd

            if {$time ne ""} {
                if {[clock seconds] - $time > 1209600} {
                    ui_warn "you haven't run 'port reclaim' in two weeks. It's recommended you run this once every two weeks to help save space on your computer."
                }
            }
        }
    }

    proc uninstall_inactive {} {

        # Attempts to uninstall all inactive applications. (Performance is now O(N)!)
        #
        # Args: 
        #           None
        # Returns: 
        #           0 if execution was successful. Errors (for now) if execution wasn't. 

        set apps            [get_info]
        set inactive_apps   [list]
        set inactive_names  [list]
        set inactive_count  0

        ui_debug "Iterating through all inactive apps."

        foreach app $apps {

            if { [is_inactive $app] } {
                lappend inactive_apps $app
                lappend inactive_names [lindex $app 0]
                incr inactive_count
            }
        }

        if { $inactive_count == 0 } {
            ui_msg "Found no inactive ports."

        } else {

            ui_msg "Found inactive ports: $inactive_names."
            ui_msg "Would you like to uninstall these apps? \[Y/N\]: "

            set input [gets stdin]
            if {$input eq "Y" || $input eq "y" } {

                ui_debug "Iterating through all inactive apps... again."

                foreach app $inactive_apps {
                    set name [lindex $app 0]

                    # Get all dependents for the current application
                    if {[catch {set dependents [registry::list_dependents $name [lindex 1] [lindex 2] [lindex 3]]} error]} {
                        ui_error "something went wrong when trying to enumerate all dependents for $name"
                    }
                    if {dependents ne ""} {
                        ui_warn "the following application ($name) is a dependent for $dependents. Are you positive you'd like to uninstall this 
                                 (this could break other applications)? \[Y/N\]"

                        set input [gets stdin]
                        if { $input eq "N" || "n" } {
                            ui_msg "Skipping application."
                            continue
                        }
                    }
                    ui_msg "Uninstalling: $name"

                    # Note: 'uninstall' takes a name, version, revision, variants and an options list. 
                    if {[catch {registry_uninstall::uninstall $name [lindex $app 1] [lindex $app 2] [lindex $app 3] {}} error]} {
                        ui_error "something went wrong when uninstalling $name"
                    }
                }
            } else {
                ui_msg "Not uninstalling applications."
            }
        }
        return 0
    }
}

#!/bin/sh
# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4 
exec @TCLSH@ "$0" "$@"

# Updates the distfiles to current distfiles by deleting old stuff.
# Uses the database.
# $Id$

catch {source \
    [file join "@TCL_PACKAGE_DIR@" macports1.0 macports_fastload.tcl]}
package require macports
package require Pextlib

# Globals
global distfiles_filemap
array set ui_options        [list]
array set global_options    [list]
array set global_variations [list]

# Pass global options into mportinit
mportinit ui_options global_options global_variations

# UI Instantiations
# ui_options(ports_debug) - If set, output debugging messages.
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"


# UI Callback
proc ui_prefix {priority} {
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

proc ui_channels {priority} {
    switch $priority {
        debug {
            if {[macports::ui_isset ui_options ports_debug]} {
                return {stderr}
            } else {
                return {}
            }
        }
        info {
            if {[macports::ui_isset ui_options ports_verbose]} {
                return {stdout}
            } else {
                return {}
            }
        }
        msg {
            if {[macports::ui_isset ui_options ports_quiet]} {
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

# Iterate on dist files.
#
# func:     function to call on every dist file (it is passed
#           the path as its parameter)
# root:     the directory with all the dist files (full path).
proc iterate_distfiles_r {func root} {
    foreach item [readdir $root] {
        set pathToItem [file join $root $item]
        if {[file isdirectory $pathToItem]} {
            iterate_distfiles_r $func $pathToItem
        } else {
            $func $pathToItem
        }
    }
}

# Iterate on dist files.
#
# func:     function to call on every dist file (it is passed
#           the path as its parameter)
proc iterate_distfiles {func} {
    global macports::portdbpath
    iterate_distfiles_r $func [file join ${macports::portdbpath} distfiles]
}

# Check if the file is in the map and delete it otherwise.
proc iterate_walker {path} {
    global distfiles_filemap
    if {![filemap exists distfiles_filemap $path]} {
        puts "deleting $path"
        file delete -force $path
    }
}

# Open the database
proc open_database args {
    global macports::portdbpath distfiles_filemap
    set path [file join ${macports::portdbpath} distfiles_mirror.db]
    if {[file exists $path]} {
        filemap open distfiles_filemap $path readonly
    } else {
        return -code error "The database doesn't exist at <$path>"
    }
}

# Close the database
proc close_database args {
    global distfiles_filemap
    filemap close distfiles_filemap
}

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0"
}

if {[expr $argc > 0]} {
    print_usage
    exit 1
}

# Open the database.
open_database

# Iterate on the files, deleting them.
iterate_distfiles iterate_walker

# Close the database
close_database

#
# instcopy.tcl -- 
#
# Tcl program to copy files during the installation of Tcl.  This is used
# because "copy -r" is not ubiquitous.  It also adds some minor additional
# functionality.
#
#------------------------------------------------------------------------------
# Copyright 1992-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: instcopy.tcl,v 8.7 2002/11/12 21:35:31 karll Exp $
#------------------------------------------------------------------------------
#
# It is run in the following manner:
#
#  instcopy file1 file2 ... targetdir
#  instcopy -filename file1 targetfile
#
#  o -filename - If specified, then the last file is the name of a file rather
#    than a directory. 
#  o -bin - Force file to be copied without translation. (not implemented).
#  o files - List of files to copy. If one of directories are specified, they
#    are copied.
#  o targetdir - Target directory to copy the files to.  If the directory does
#    not exist, it is created (including parent directories).
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

package require Tclx
source [file join [file dirname [info script]] buildutil.tcl]

#------------------------------------------------------------------------------
# Usage --
#
#   Issue a usage message and exit.
#------------------------------------------------------------------------------
proc Usage {{msg {}}} {
    if {"$msg" != ""} {
        puts stderr "Error: $msg"
    }
    puts stderr {usage: instcopy ?-filename? file1 file2 ... targetdir}
    exit 1
}

#------------------------------------------------------------------------------
# DoACopy --
#------------------------------------------------------------------------------

proc DoACopy {file target mode} {

    if [cequal [file tail $file] "CVS"] {
        return
    }
    if {$mode == "FILENAME"} {
        set targetDir [file dirname $target]
        if [file exists $target] {
            file delete -force $target
        }
    } else {
        set targetDir $target
    }
    file mkdir $targetDir

    if [file isdirectory $file] {
        CopyDir $file $target
    } else {
        CopyFile $file $target
    }
}


#------------------------------------------------------------------------------
# Main program code.
#------------------------------------------------------------------------------

#
# Parse the arguments
#
if {$argc < 2} {
    Usage "Not enough arguments"
}

set mode {}
set binary 0
while {[string match -* [lindex $argv 0]]} {
    set flag [lvarpop argv]
    incr argc -1
    switch -exact -- $flag {
        -filename {
            set mode FILENAME
        }
        -bin {
            set binary 1
        }
        default {
            puts stderr "unknown flag"
        }
    }
}

set files {}
foreach file [lrange $argv 0 [expr $argc-2]] {
    lappend files [eval file join [file split $file]]
}
set targetDir [eval file join [file split [lindex $argv [expr $argc-1]]]]

if {[file exists $targetDir] && ![file isdirectory $targetDir] &&
    ($mode != "FILENAME")} {
   Usage "Target is not a directory: $targetDir"
}

umask 022

if [catch {
    foreach file $files {
        DoACopy $file $targetDir $mode
    }
} msg] {
    puts stderr "Error: $msg"
    exit 1
}



#
# edprocs.tcl --
#
# Tools for Tcl developers. Procedures to save procs to a file and to edit
# a proc in memory.
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
# $Id: edprocs.tcl,v 1.2 2004/11/23 00:35:20 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-developer_utils saveprocs edprocs

proc saveprocs {fileName args} {
    set fp [open $fileName w]
    try_eval {
        puts $fp "# tcl procs saved on [fmtclock [getclock]]\n"
        puts $fp [eval "showproc $args"]
    } {} {
        close $fp
    }
}

proc edprocs {args} {
    global env

    set tmpFilename /tmp/tcldev.[pid].[clock seconds]
    set access [list RDWR CREAT EXCL TRUNC]
    set perm 0600
    if {[catch {open $tmpFilename $access $perm} fp]} {
	# something went wrong
	return -code error "Could not open temporary file:\n$fp"
    }

    try_eval {
        puts $fp "\n# TEMP EDIT BUFFER -- YOUR CHANGES ARE FOR THIS SESSION ONLY\n"
        puts $fp [eval [linsert $args 0 showproc]]
    } {} {
        close $fp
    }

    if {[info exists env(EDITOR)]} {
        set editor $env(EDITOR)
    } else {
	set editor vi
    }

    set startMtime [file mtime $tmpFilename]
    system "$editor $tmpFilename"

    if {[file mtime $tmpFilename] != $startMtime} {
	source $tmpFilename
	echo "Procedures were reloaded."
    } else {
	echo "No changes were made."
    }
    unlink $tmpFilename
    return
}



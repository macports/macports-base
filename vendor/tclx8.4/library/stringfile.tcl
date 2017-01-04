#
# string_file --
#
# Functions to read and write strings from a file that has not been opened.
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
# $Id: stringfile.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-stringfile_functions read_file write_file

proc read_file {fileName args} {
    if {$fileName == "-nonewline"} {
        set flag $fileName
        set fileName [lvarpop args]
    } else {
        set flag {}
    }
    set fp [open $fileName]
    try_eval {
        set result [eval read $flag $fp $args]
    } {} {
        close $fp
    }
    return $result
} 

proc write_file {fileName args} {
    set fp [open $fileName w]
    try_eval {
        foreach string $args {
            puts $fp $string
        }
    } {} {
        close $fp
    }
}




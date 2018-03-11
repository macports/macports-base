#
# globrecur.tcl --
#
#  Build or process a directory list recursively.
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
# $Id: globrecur.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-globrecur recursive_glob

proc recursive_glob {dirlist globlist} {
    set result {}
    set recurse {}
    foreach dir $dirlist {
        if ![file isdirectory $dir] {
            error "\"$dir\" is not a directory"
        }
        foreach pattern $globlist {
            set result [concat $result \
                    [glob -nocomplain -- [file join $dir $pattern]]]
        }
        foreach file [readdir $dir] {
            set file [file join $dir $file]
            if [file isdirectory $file] {
                set fileTail [file tail $file]
                if {!([cequal $fileTail .] || [cequal $fileTail ..])} {
                    lappend recurse $file
                }
            }
        }
    }
    if ![lempty $recurse] {
        set result [concat $result [recursive_glob $recurse $globlist]]
    }
    return $result
}

#@package: TclX-forrecur for_recursive_glob

proc for_recursive_glob {var dirlist globlist cmd {depth 1}} {
    upvar $depth $var myVar
    set recurse {}
    foreach dir $dirlist {
        if ![file isdirectory $dir] {
            error "\"$dir\" is not a directory"
        }
        set code 0
        set result {}
        foreach pattern $globlist {
            foreach file [glob -nocomplain -- [file join $dir $pattern]] {
                set myVar $file
                set code [catch {uplevel $depth $cmd} result]
                if {$code != 0 && $code != 4} break
            }
            if {$code != 0 && $code != 4} break
        }
        if {$code != 0 && $code != 4} {
            if {$code == 3} {
                return $result
            }
            if {$code == 1} {
                global errorCode errorInfo
                return -code $code -errorcode $errorCode \
                        -errorinfo $errorInfo $result
            }
            return -code $code $result
        }

        foreach file [readdir $dir] {
            set file [file join $dir $file]
            if [file isdirectory $file] {
                set fileTail [file tail $file]
                if {!([cequal $fileTail .] || [cequal $fileTail ..])} {
                    lappend recurse $file
                }
            }
        }
    }
    if ![lempty $recurse] {
        return [for_recursive_glob $var $recurse $globlist $cmd \
                    [expr $depth + 1]]
    }
    return {}
}



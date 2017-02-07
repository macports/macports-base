#
# pushd.tcl --
#
# C-shell style directory stack procs.
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
# $Id: pushd.tcl,v 1.2 2005/11/25 18:18:55 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-directory_stack pushd popd dirs

global TCLXENV(dirPushList)

set TCLXENV(dirPushList) ""

proc pushd {{new ""}} {
    global TCLXENV

    set current [pwd]
    if {[string length $new]} {
        set dirs [glob -nocomplain $new]
        set count [llength $dirs]
        if {$count == 0} {
            error "no such directory: $new"
        } elseif {$count != 1} {
            error "ambiguous directory: $new: [join $dirs {, }]"
        }
        cd [lindex $dirs 0]
        lvarpush TCLXENV(dirPushList) $current
    } else {
        if [lempty $TCLXENV(dirPushList)] {
            error "directory stack empty"
        }
        cd [lindex $TCLXENV(dirPushList) 0]
        lvarpop TCLXENV(dirPushList)
        lvarpush TCLXENV(dirPushList) $current
    }
    return [pwd]
}

proc popd {} {
    global TCLXENV

    if {[lempty $TCLXENV(dirPushList)]} {
        error "directory stack empty"
    }
    cd [lvarpop TCLXENV(dirPushList)]
    return [pwd]
}

proc dirs {} { 
    global TCLXENV
    return [linsert $TCLXENV(dirPushList) 0 [pwd]]
}



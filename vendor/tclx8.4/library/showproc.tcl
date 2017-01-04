#
# showproc.tcl --
#
# Display procedure headers and bodies.
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
# $Id: showproc.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-showproc showproc

proc showproc args {
    if [lempty $args] {
        set args [info procs]
    }
    set out {}

    foreach procname $args {
        if [lempty [info procs $procname]] {
            auto_load $procname
        }
        set arglist [info args $procname]
        set nargs {}
        while {[llength $arglist] > 0} {
            set varg [lvarpop arglist 0]
            if [info default $procname $varg defarg] {
                lappend nargs [list $varg $defarg]
            } else {
                lappend nargs $varg
            }
        }
        append out "proc $procname [list $nargs] \{[info body $procname]\}\n"
    }
    return $out
}



#
# runbuildhelp.tcl -- 
#
# Wrapper to invoke buildhelp proc since standard tclsh doesn't have -c
#------------------------------------------------------------------------------
# Copyright 2002 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: runbuildhelp.tcl,v 8.1 2002/11/12 21:35:31 karll Exp $
#------------------------------------------------------------------------------
#

package require Tclx

source $env(TCLX_LIBRARY)/buildhelp.tcl

#-----------------------------------------------------------------------------
# Main program for building help from manual files.  Constructs tmp input
# file for the buildhelp command.

if {[llength $argv] != 3} {
    puts stderr "wrong # args: $argv0 helpdir brief File.n"
    exit 1
}

set helpDir [lindex $argv 0]
set brief [lindex $argv 1]
set dotN [lindex $argv 2]

buildhelp $helpDir $brief $dotN

exit 0



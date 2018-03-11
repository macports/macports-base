#
# arrayprocs.tcl --
#
# Extended Tcl array procedures.
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
# $Id: arrayprocs.tcl,v 1.2 2002/04/02 03:00:14 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-ArrayProcedures for_array_keys

proc for_array_keys {varName arrayName codeFragment} {
    upvar $varName enumVar $arrayName enumArray

    if {![array exists enumArray]} {
	return -code error "\"$arrayName\" isn't an array"
    }

    set code 0
    set result {}
    set searchId [array startsearch enumArray]
    while {[array anymore enumArray $searchId]} {
	set enumVar [array nextelement enumArray $searchId]
        set code [catch {uplevel 1 $codeFragment} result]
        if {$code != 0 && $code != 4} break
    }
    array donesearch enumArray $searchId

    if {$code == 0 || $code == 3 || $code == 4} {
        return $result
    }
    if {$code == 1} {
        global errorCode errorInfo
        return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    return -code $code $result
}

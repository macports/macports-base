# pt_peg_import_peg.tcl --
#
#	The PEG to PEG (text representation) import plugin. Generation
#	of plain text.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_import_peg.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package is a plugin for the pt::peg import manager.  It takes
# the human readable text representation of a parsing expression
# grammar and produces the corresponding canonical serialization.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: pt::peg::import::plugin

package require Tcl 8.5
package require pt::peg::import::plugin ; # The presence of this
					  # pseudo package indicates
					  # execution inside of a
					  # properly initialized
					  # plugin interpreter.
package require pt::peg::from::peg

# ### ### ### ######### ######### #########
## API.

proc import {text} {
    return [pt::peg::from::peg convert $text]
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::import::peg 1
return

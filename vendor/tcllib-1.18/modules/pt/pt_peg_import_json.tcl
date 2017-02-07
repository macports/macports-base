# pt_peg_import_json.tcl --
#
#	The PEG from JSON import plugin.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_import_json.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package is a plugin for the pt::peg import manager. It takes
# text in JSON format for a parsing expression grammar and produces
# the canonical serialization of that grammar.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: pt::peg::import::plugin

package require Tcl 8.5
package require pt::peg::import::plugin ; # The presence of this
					  # pseudo package indicates
					  # execution inside of a
					  # properly initialized
					  # plugin interpreter.
package require pt::peg::from::json

# ### ### ### ######### ######### #########
## API.

proc import {text} {
    return [pt::peg::from::json convert $text]
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::import::json 1
return

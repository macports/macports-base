# peg_export_container.tcl --
#
#	The PEG to CONTAINER export plugin. Generation of Tcl code, a
#	snit::type.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_export_container.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package is a plugin for the pt::peg export manager.  It
# takes the canonical serialization of a parsing expression grammar
# and produces text in CONTAINER format.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: pt::peg::export::plugin

package  require Tcl 8.5
package  require pt::peg::export::plugin ; # The presence of this
						# pseudo package
						# indicates execution
						# inside of a properly
						# initialized plugin
						# interpreter.
package require pt::peg::to::container

# ### ### ### ######### ######### #########
## API.

proc export {serial configuration} {

    pt::peg::to::container reset
    foreach {option value} $configuration {
	pt::peg::to::container configure $option $value
    }

    set text [pt::peg::to::container convert $serial]

    pt::peg::to::container reset
    return $text
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::export::container 1
return

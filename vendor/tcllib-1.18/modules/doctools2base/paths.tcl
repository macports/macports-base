# docidx.tcl --
#
#	Generic path list management, for use by import management.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: paths.tcl,v 1.2 2009/04/29 02:09:46 andreas_kupries Exp $

# Each object manages a list of paths.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::doctools::paths {

    # ### ### ### ######### ######### #########
    ## Options :: None

    # ### ### ### ######### ######### #########
    ## Creation, destruction

    # Default constructor.
    # Default destructor.

    # ### ### ### ######### ######### #########
    ## Methods :: Querying and manipulating the list of paths.

    method paths {} {
	return $mypaths
    }

    method add {path} {
	set pos [lsearch $mypaths $path]
	if {$pos >= 0 } return
	lappend mypaths $path
	return
    }

    method remove {path} {
	set pos [lsearch $mypaths $path]
	if {$pos < 0} return
	set  mypaths [lreplace $mypaths $pos $pos]
	return
    }

    method clear {} {
	set mypaths {}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal methods :: None

    # ### ### ### ######### ######### #########
    ## State :: List of paths.

    variable mypaths {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::paths 0.1
return

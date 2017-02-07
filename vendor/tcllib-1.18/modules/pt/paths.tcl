# paths.tcl --
#
#	Generic path list management, for use by import management.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: paths.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# Each object manages a list of paths.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require snit

# ### ### ### ######### ######### #########
## API

snit::type ::paths {

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
	if {$path in $mypaths} return
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

package provide paths 1
return

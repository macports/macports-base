# tie_dsource.tcl --
#
#	Data source: Data source object. I.e. here we implement a proxy.
#
# Copyright (c) 2004 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tie_dsource.tcl,v 1.3 2005/09/28 04:51:24 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require tie

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tie::std::dsource {

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {args} {
	set delegate $args
	return
    }

    # ### ### ### ######### ######### #########
    ## API : Data source methods

    delegate method * to delegate

    # ### ### ### ######### ######### #########
    ## Internal : Instance data

    variable delegate ; # The object to delegate to.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::dsource as dsource
package provide   tie::std::dsource 1.0

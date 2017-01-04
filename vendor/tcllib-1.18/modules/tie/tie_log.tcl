# tie_log.tcl --
#
#	Data source: /dev/null. Just log changes.
#
# Copyright (c) 2004 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: tie_log.tcl,v 1.3 2005/09/28 04:51:24 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require log
package require tie

# ### ### ### ######### ######### #########
## Implementation

package require snit
snit::type ::tie::std::log {

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no
    pragma -simpledispatch yes

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {} {
	::log::log debug "$self construction"
	return
    }

    destructor {
	::log::log debug "$self destruction"
	return
    }

    # ### ### ### ######### ######### #########
    ## API : Data source methods

    method get {} {
	::log::log debug "$self get (nothing)"
	return {}
    }

    method set {dict} {
	::log::log debug "$self set [list $dict]"
	return
    }

    method unset {{pattern *}} {
	::log::log debug "$self unset $pattern"
	return
    }

    method names {} {
	::log::log debug "$self names (nothing)"
	return {}
    }

    method size {} {
	::log::log debug "$self size (0)"
	return 0
    }

    method getv {index} {
	::log::log debug "$self get ($index)"
	return {}
    }

    method setv {index value} {
	::log::log debug "$self set ($index) = \[$value\]"
	return
    }

    method unsetv {index} {
	::log::log debug "$self unset ($index)"
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::log as log
package provide   tie::std::log 1.0

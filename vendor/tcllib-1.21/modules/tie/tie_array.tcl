# tie_array.tcl --
#
#	Data source: Tcl array.
#
# Copyright (c) 2004-2021 Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require snit
package require tie

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tie::std::array {

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no
    pragma -simpledispatch yes

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {rvar} {
	# Bring reference to the array into the object scope,
	# i.e. namespace of the object. This will fail for proc local
	# variables. This latter is enforced by the core, to prevent
	# the existence of dangling references to the variable when
	# the procedure goes away.

	# upvar 3, because we have to skip 3 snit internal levels to
	# access the callers level.

	if {[catch {
	    upvar 3 $rvar ${selfns}::thesource
	}]} {
	    return -code error "Illegal use of proc local array variable \"$rvar\""
	}

	# Now bring the variable into method scope as well, to check
	# for its existence.

	variable ${selfns}::thesource

	if {![array exists thesource]} {
	    return -code error "Undefined source array variable \"$rvar\""
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## API : Data source methods

    method get {} {
	variable ${selfns}::thesource
	return [array get thesource]
    }

    method set {dict} {
	variable ${selfns}::thesource
	return [array set thesource $dict]
    }

    method unset {{pattern *}} {
	variable ${selfns}::thesource
	array unset thesource $pattern
	return
    }

    method names {} {
	variable ${selfns}::thesource
	return [array names thesource]
    }

    method size {} {
	variable ${selfns}::thesource
	return [array size thesource]
    }

    method getv {index} {
	variable ${selfns}::thesource
	return $thesource($index)
    }

    method setv {index value} {
	variable ${selfns}::thesource
	set thesource($index) $value
	return
    }

    method unsetv {index} {
	variable ${selfns}::thesource
	unset thesource($index)
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal : Instance data

    ## During construction the source array variable is imported into
    ## the namespace of the object, for direct access through a
    ## constant name. This also allows a direct reference without
    ## having to deal with changing stack scopes. This is possible if
    ## and only if the imported array is a namespaced variable. Proc
    ## local variables cannot be imported into a namespace in this
    ## manner. Trying to do so results in an error.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::array as array
package provide   tie::std::array 1.1

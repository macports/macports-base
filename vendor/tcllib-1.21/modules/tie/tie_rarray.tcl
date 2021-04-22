# tie_rarray.tcl --
#
#	Data source: Remote Tcl array.
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

snit::type ::tie::std::rarray {

    # ### ### ### ######### ######### #########
    ## Specials

    pragma -hastypemethods no
    pragma -hasinfo        no
    pragma -simpledispatch yes

    # ### ### ### ######### ######### #########
    ## API : Construction & Destruction

    constructor {rvar cmdpfx id} {
	set remotevar $rvar
	set cmd       $cmdpfx
	set rid       $id

	if {![$self Call array exists $rvar]} {
	    return -code error "Undefined source array variable \"$rvar\""
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## API : Data source methods

    method get {} {
	return [$self Call array get $remotevar]
    }

    method set {dict} {
	$self Call array set $remotevar $dict
	return
    }

    method unset {{pattern *}} {
	$self Call array unset $remotevar $pattern
	return
    }

    method names {} {
	return [$self Call array names $remotevar]
    }

    method size {} {
	return [$self Call array size $remotevar]
    }

    method getv {index} {
	return [$self Call set ${remotevar}($index)]
    }

    method setv {index value} {
	$self Call set ${remotevar}($index) $value
	return
    }

    method unsetv {index} {
	$self Call unset -nocomplain ${remotevar}($index)
	return
    }

    # ### ### ### ######### ######### #########
    ## Internal : Instance data

    variable remotevar {} ; # Name of rmeote array
    variable cmd       {} ; # Send command prefix
    variable rid       {} ; # Id of entity hosting the array.

    # ### ### ### ######### ######### #########
    ## Internal: Calling to the remote entity.

    ## All calls are synchronous. Asynchronous operations would
    ## created problems with circular ties. Because the operation may
    ## came back so much later that the origin is already in a
    ## completely new state. This is avoied in synchronous mode as the
    ## origin waits for the change to be acknowledged, and the
    ## operation came back in this time. The change made by it is no
    ## problem. The trace is still running, thus any write does _not_
    ## re-invoke our trace. The only possible problem is an unset for
    ## an element already gone. This was solved by using -nocomplain
    ## when propagating this type of change.

    method Call {args} {
	set     c $cmd
	lappend c $rid
	lappend c $args
	return [uplevel #0 $c]
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready to go

::tie::register ::tie::std::rarray as remotearray
package provide   tie::std::rarray 1.1

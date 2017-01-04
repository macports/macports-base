## -*- tcl -*-
# ### ### ### ######### ######### #########

# Copyright (c) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>

# Aynchronous in-memory cache. Queries of the cache generate
# asynchronous requests for data for unknown parts, with asynchronous
# result return. Data found in the cache may return fully asynchronous
# as well, or semi-synchronous. The latter meaning that the regular
# callbacks are used, but invoked directly, and not decoupled through
# events. The cache can be pre-filled synchronously.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.4 ; #
package require snit    ; # 

# ### ### ### ######### ######### #########
##

snit::type cache::async {

    # ### ### ### ######### ######### #########
    ## Unknown methods and options are forwared to the object actually
    ## providing the cached data, making the cache a proper facade for
    ## it.

    delegate method * to myprovider
    delegate option * to myprovider

    # ### ### ### ######### ######### #########
    ## API 

    option -full-async-results -default 1 -type snit::boolean

    constructor {provider args} {
	set myprovider $provider
	$self configurelist $args
	return
    }

    method get {key donecmd} {
	# Register request
	lappend mywaiting($key) $donecmd

	# Check if the request can be satisfied from the cache. If yes
	# then that is done.

	if {[info exists mymiss($key)]} {
	    $self NotifyUnset 1 $key
	    return
	} elseif {[info exists myhit($key)]} {
	    $self NotifySet 1 $key
	    return
	}

	# We have to ask our provider if there is data or
	# not. however, if a request for this key is already in flight
	# then we have to do nothing more. Our registration at the
	# beginning ensures that we will get notified when the
	# requested information comes back.

	if {[llength $mywaiting($key)] > 1} return

	# This is the first query for this key, ask the provider.

	after idle [linsert $myprovider end get $key $self]
	return
    }

    method clear {args} {
	# Note: This method cannot interfere with async queries caused
	# by 'get' invokations.  If the data is present, and now
	# removed, all 'get' invokations before this call were
	# satisfied from the cache and only invokations coming after
	# it can trigger async queries of the provider. If the data is
	# not present the state will not change, and queries in flight
	# simply refill the cache as they would do anyway without the
	# 'clear'.

	if {![llength $args]} {
	    array unset myhit  *
	    array unset mymiss *
	} elseif {[llength $arg] == 1} {
	    set key [lindex $args 0]
	    unset -nocomplain  myhit($key)
	    unset -nocomplain mymiss($key)
	} else {
	    WrongArgs ?key?
	}
	return
    }

    method exists {key} {
	return [expr {[info exists myhit($key)] || [info exists mymiss($key)]}]
    }

    method set {key value} {
	# Add data to the cache, and notify all outstanding queries.
	# Nothing is done if the key is already known and has the same
	# value.

	# This is the method invoked by the provider in response to
	# queries, and also the method to use to prefill the cache
	# with data.

	if {
	    [info exists myhit($key)] &&
	    ($value eq $myhit($key))
	} return

	set                myhit($key) $value
	unset -nocomplain mymiss($key)
	$self NotifySet 0 $key
	return
    }

    method unset {key} {
	# Add hole to the cache, and notify all outstanding queries.
	# This is the method invoked by the provider in response to
	# queries, and also the method to use to prefill the cache
	# with holes.
	unset -nocomplain myhit($key)
	set              mymiss($key) .
	$self NotifyUnset 0 $key
	return
    }

    method NotifySet {found key} {
	if {![info exists mywaiting($key)] || ![llength $mywaiting($key)]} return

	set pending $mywaiting($key)
	unset mywaiting($key)

	set value $myhit($key)
	if {$found && !$options(-full-async-results)} {
	    foreach donecmd $pending {
		uplevel \#0 [linsert $donecmd end set $key $value]
	    }
	} else {
	    foreach donecmd $pending {
		after idle [linsert $donecmd end set $key $value]
	    }
	}
	return
    }

    method NotifyUnset {found key} {
	if {![info exists mywaiting($key)] || ![llength $mywaiting($key)]} return

	set pending $mywaiting($key)
	unset mywaiting($key)

	if {$found && !$options(-full-async-results)} {
	    foreach donecmd $pending {
		uplevel \#0 [linsert $donecmd end unset $key]
	    }
	} else {
	    foreach donecmd $pending {
		after idle [linsert $donecmd end unset $key]
	    }
	}
	return
    }

    proc WrongArgs {expected} {
	return -code error "wrong#args: Expected $expected"
    }

    # ### ### ### ######### ######### #########
    ## State

    variable myprovider          ; # Command prefix providing the data to cache.
    variable myhit     -array {} ; # Cache array mapping keys to values.
    variable mymiss    -array {} ; # Cache array mapping keys to holes.
    variable mywaiting -array {} ; # Map of keys pending to notifier commands.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide cache::async 0.3

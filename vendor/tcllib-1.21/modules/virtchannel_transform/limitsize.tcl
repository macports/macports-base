# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::limitsize 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   Possibilities for extension: Trigger the
# Meta as::notes   EOF when finding specific patterns in
# Meta as::notes   the input. Trigger the EOF based on some
# Meta as::notes   external signal routed into the limiter.
# Meta as::notes   Make the limit reconfigurable.
# Meta description Implementation of a transformation
# Meta description limiting the number of bytes read
# Meta description from its channel. An observer instead of
# Meta description a transformation, forcing an artificial
# Meta description EOF marker. Based on Tcl 8.6's
# Meta description transformation reflection support.
# Meta description Exports a single command adding a new
# Meta description transform of this type to a channel. One
# Meta description argument, the channel to extend, and the
# Meta description number of bytes to allowed to be read.
# Meta description No result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# This may help with things like zlib compression of messages. Have
# the message format a length at the front, followed by a payload of
# that size. Now we may compress messages. On the read side we can use
# the limiter to EOF on a message, then reset the limit for the
# next. This is a half-baked idea.

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::limitsize {chan max} {
    ::chan push $chan [limitsize::implementation new $max]
}

oo::class create ::tcl::transform::limitsize::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    method write {c data} {
	return $data
    }

    method read {c data} {
	# Reduce the limit of bytes allowed in the future according to
	# the number of bytes we have seen already.

	if {$max > 0} {
	    incr max -[string length $data]
	    if {$max < 0} {
		set max 0
	    }
	}
	return $data
    }

    method limit? {c} {
	return $max
    }

    # # ## ### ##### ######## #############

    constructor {themax} {
	set max $themax
	return
    }

    variable max

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::limitsize 1
return

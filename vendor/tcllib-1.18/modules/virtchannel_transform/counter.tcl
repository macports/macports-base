# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::counter 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   For other observers see adler32, crc32,
# Meta as::notes   identity, and observer (stream copy).
# Meta as::notes   Possibilities for extension: Separate
# Meta as::notes   counters per byte value. Count over
# Meta as::notes   fixed time-intervals = channel speed.
# Meta as::notes   Use callbacks or traces to save changes
# Meta as::notes   in the counters, etc. as time-series.
# Meta as::notes   Compute statistics over the time-series.
# Meta description Implementation of a counter
# Meta description transformation. Based on Tcl 8.6's
# Meta description transformation reflection support (TIP
# Meta description 230). An observer instead of a
# Meta description transformation, it counts the number of
# Meta description bytes read and written. The observer
# Meta description saves the counts into two external
# Meta description namespaced variables specified at
# Meta description construction time. Exports a single
# Meta description command adding a new transformation of
# Meta description this type to a channel. One argument,
# Meta description the channel to extend, plus options to
# Meta description specify the variables for the counters.
# Meta description No result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::counter {chan args} {
    ::chan push $chan [counter::implementation new {*}$args]
}

oo::class create ::tcl::transform::counter::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    method write {c data} {
	my Count -write-variable $data
	return $data
    }

    method read {c data} {
	my Count -read-variable $data
	return $data
    }

    # No partial data, nor state => no flush, drain, nor clear needed.

    # # ## ### ##### ######## #############

    constructor {args} {
	array set options {
	    -read-variable  {}
	    -write-variable {}
	}
	# todo: validity checking of options (legal names, legal
	# values, etc.)
	array set options $args
	return
    }

    # # ## ### ##### ######## #############

    variable options

    # # ## ### ##### ######## #############

    method Count {o data} {
	if {$options($o) eq ""} return
	upvar #0 $options($o) counter
	incr counter [string length $data]
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::transform::counter 1
return

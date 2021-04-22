# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::fifo 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Re-implementation of Memchan's fifo
# Meta description channel. Based on Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new
# Meta description channels. No arguments. Result is the
# Meta description handle of the new channel.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::events
# Meta require {Tcl 8.5}
# @@ Meta End
# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::events

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::fifo {} {
    return [::chan create {read write} [fifo::implementation new]]
}

oo::class create ::tcl::chan::fifo::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    method initialize {args} {
	my allow write
	next {*}$args
    }

    method read {c n} {
	set max  [string length $read]
	set last [expr {$at + $n - 1}]
	set result {}

	#    last+1 <= max
	# <=> at+n <= max
	# <=> n <= max-at

	if {$n <= ($max - $at)} {
	    # The request is less than what we have left in the read
	    # buffer, we take it, and move the read pointer forward.

	    append result [string range $read $at $last]
	    incr at $n
	    incr $size -$n
	} else {
	    # We need the whole remaining read buffer, and more. For
	    # the latter we shift the write buffer contents over into
	    # the read buffer, and then read from the latter again.

	    append result  [string range $read $at end]
	    incr n -[string length $result]

	    set at    0
	    set read  $write
	    set write {}
	    set size  [string length $read]
	    set max   $size

	    # at == 0
	    if {$n <= $max} {
		# The request is less than what we have in the updated
		# read buffer, we take it, and move the read pointer
		# forward.

		append result [string range $read 0 $last]
		set at $n
		incr $size -$n
	    } else {
		# We need the whole remaining read buffer, and
		# more. As we took the data from write already we have
		# nothing left, and update accordingly.

		append result $read

		set at   0
		set read {}
		set size 0
	    }
	}

	my Readable

	if {$result eq {}} {
	    return -code error EAGAIN
	}

	return $result
    }

    method write {c bytes} {
	append write $bytes
	set n [string length $bytes]
	incr size $n
	my Readable
	return $n
    }

    # # ## ### ##### ######## #############

    variable at read write size

    # # ## ### ##### ######## #############

    constructor {} {
	set at    0
	set read  {}
	set write {}
	set size  0
	next
    }

    method Readable {} {
	if {$size} {
	    my allow read
	} else {
	    my disallow read
	}
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::fifo 1
return

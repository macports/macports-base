# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009, 2019 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::halfpipe 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009,2019
# Meta as::license BSD
# Meta description Implementation of one half of a pipe
# Meta description channel. Based on Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new
# Meta description channels. Option arguments. Result is the
# Meta description handle of the new channel, and the object
# Meta description command of the handler object.
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

proc ::tcl::chan::halfpipe {args} {
    set handler [halfpipe::implementation new {*}$args]
    return [list [::chan create {read write} $handler] $handler]
}

oo::class create ::tcl::chan::halfpipe::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    method initialize {args} {
	my allow write
	set eof 0
	next {*}$args
    }

    method finalize {c} {
	my Call -close-command $c
	next $c
    }

    method read {c n} {
	set max  [string length $read]
	set last [expr {$at + $n - 1}]
	set result {}
	
	#    last+1 <= max
	# <=> at+n <= max
	# <=> n <= max-at

	if {$n <= ($max - $at)} {
	    # There is enough data in the buffer to fill the request, so take
	    # it from there and move the read pointer forward.

	    append result [string range $read $at $last]
	    incr at $n
	    incr $size -$n
	} else {
	    # We need the whole remaining read buffer, and more. For
	    # the latter we make the write buffer the new read buffer,
	    # and then read from it again.

	    append result [string range $read $at end]
	    incr n -[string length $result]

	    set at    0
            set last  [expr {$n - 1}]
	    set read  $write
	    set write {}
	    set size  [string length $read]
	    set max   $size

	    # at == 0 simplifies expressions
	    if {$n <= $max} {
		# The request is less than what we have in the new
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
	if {$result eq {} && !$eof} {
	    return -code error EAGAIN
	}
	return $result
    }

    method write {c bytes} {
	my Call -write-command $c $bytes
	return [string length $bytes]
    }

    # # ## ### ##### ######## #############

    method put bytes {
	append write $bytes
	set n [string length $bytes]
	if {$n == 0} {
	    my variable eof
	    set eof 1
	} else {
	    incr size $n
	}
	my Readable
	return $n
    }

    # # ## ### ##### ######## #############

    variable at eof read write size options
    # at      : first location in read buffer not yet read
    # eof     : indicates whether the end of the data has been reached 
    # read    : read buffer
    # write   : buffer for received data, i.e.
    #           written into the halfpipe from
    #           the other side.
    # size    : combined length of receive and read buffers
    #           == amount of stored data
    # options : configuration array

    # The halpipe uses a pointer (`at`) into the data buffer to
    # extract the characters read by the user, while not shifting the
    # data down in memory. Doing such a shift would cause a large
    # performance hit (O(n**2) operation vs O(n)). This however comes
    # with the danger of the buffer growing out of bounds as ever more
    # data is appended by the receiver while the reader is not
    # catching up, preventing a release. The solution to this in turn
    # is to split the buffer into two. An append-only receive buffer
    # (`write`) for incoming data, and a `read` buffer with the
    # pointer. When the current read buffer is entirely consumed the
    # current receive buffer becomes the new read buffer and a new
    # empty receive buffer is started.
    
    # # ## ### ##### ######## #############

    constructor {args} {
	array set options {
	    -write-command {}
	    -empty-command {}
	    -close-command {}
	}
	# todo: validity checking of options (legal names, legal
	# values, etc.)
	array set options $args
	set at    0
	set read  {}
	set write {}
	set size  0
	next
    }

    method Readable {} {
	if {$size || $eof} {
	    my allow read
	} else {
	    my variable channel
	    my disallow read
	    my Call -empty-command $channel
	}
	return
    }

    method Call {o args} {
	if {![llength $options($o)]} return
	uplevel \#0 [list {*}$options($o) {*}$args]
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::halfpipe 1.0.2
return

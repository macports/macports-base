# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::spacer 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a spacer
# Meta description transformation, using Tcl 8.6's
# Meta description transformation reflection support. Uses
# Meta description counters to implement the transformation,
# Meta description i.e. decide where to insert the spacing.
# Meta description Exports a single command adding a new
# Meta description transform of this type to a channel. One
# Meta description argument, the channel to extend. No
# Meta description result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::spacer {chan n {space { }}} {
    ::chan push $chan [spacer::implementation new $n $space]
    return
}

oo::class create ::tcl::transform::spacer::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    # This transformation is intended for streaming operation. Seeking
    # the channel while it is active may cause undesirable
    # output. Proper behaviour may require the destruction of the
    # transform before seeking.

    method write {c data} {
	# add spacing, data is split into groups of delta chars.
	set result {}
	set len [string length $data]

	if {$woffset} {
	    # The beginning of the buffer is the remainder of the
	    # partial group found at the end of the buffer in the last
	    # call.  It may still be partial, if the current buffer is
	    # short enough.

	    if {($woffset + $len) < $delta} {
		# Yes, the group is still not fully covered.
		# Move the offset forward, and return the whole
		# buffer. spacing is not needed yet.
		incr woffset $len
		return $data
	    }

	    # The buffer completes the group. Add it and the following
	    # spacing, then fix the offset to start the processing of
	    # the groups coming after at the proper location.

	    set stop [expr {$delta - $woffset - 1}]

	    append result [string range $data 0 $stop]
	    append result $spacing

	    set  woffset $stop
	    incr woffset
	}

	# Process full groups in the middle of the incoming buffer.

	set at   $woffset
	set stop [expr {$at + $delta - 1}]
	while {$stop < $len} {
	    append result [string range $data $at $stop]
	    append result $spacing
	    incr at   $delta
	    incr stop $delta
	}

	# Process partial group at the end of the buffer and remember
	# the offset, for the processing of the group remainder in the
	# next call.

	if {($at < $len) && ($stop >= $len)} {
	    append result [string range $data $at end]
	}
	set woffset [expr {$len - $at}]
	return $result
    }

    method read {c data} {
	# remove spacing from groups of delta+sdelta chars, keeping
	# the first delta in each group.
	set result {}
	set iter [expr {$delta + $sdelta}]
	set at 0
	if {$roffset} {
	    if {$roffset < $delta} {
		append result [string range $data 0 ${roffset}-1]
	    }
	    incr at [expr {$iter - $roffset}]
	}
	set len  [string length $data]
	set end  [expr {$at + $delta - 1}]
	set stop [expr {$at + $iter - 1}]
	while {$stop < $len} {
	    append result [string range $data $at $end]
	    incr at   $iter
	    incr end  $iter
	    incr stop $iter
	}
	if {$end < $len} {
	    append result [string range $data $at $end]
	    set roffset [expr {$len - $end + 1}]
	} elseif {$at < $len} {
	    append result [string range $data $at end]
	    set roffset [expr {$len - $at}]
	}
	return [list $result $roffset]
    }

    # # ## ### ##### ######## #############

    constructor {n space} {
	set roffset 0
	set woffset 0
	set delta   $n
	set spacing $space
	set sdelta [string length $spacing]
	return
    }

    # # ## ### ##### ######## #############

    variable roffset woffset delta spacing sdelta

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::spacer 1
return

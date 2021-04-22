# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# Variable string channel (in-memory r/w file, internal variable).
# Seekable beyond the end of the data, implies appending of 0x00
# bytes.

# @@ Meta Begin
# Package tcl::chan::memchan 1.0.4
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Re-implementation of Memchan's memchan
# Meta description channel. Based on Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new
# Meta description channels. No arguments. Result is the
# Meta description handle of the new channel. Essentially
# Meta description an in-memory read/write random-access
# Meta description file. Similar to -> tcl::chan::variable,
# Meta description except the content variable is internal,
# Meta description part of the channel. Further similar to
# Meta description -> tcl::chan::string, except that the
# Meta description content is here writable, and
# Meta description extendable.
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

proc ::tcl::chan::memchan {} {
    return [::chan create {read write} [memchan::implementation new]]
}

oo::class create ::tcl::chan::memchan::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    constructor {} {
	set content {}
	set at 0
	next
    }

    method initialize {args} {
	my allow write
	my Events
	next {*}$args
    }

    variable content at 

    method read {c n} {
	# First determine the location of the last byte to read,
	# relative to the current location, and limited by the maximum
	# location we are allowed to access per the size of the
	# content.

	set last [expr {min($at + $n,[string length $content])-1}]

	# Then extract the relevant range from the content, move the
	# seek location behind it, and return the extracted range. Not
	# to forget, switch readable events based on the seek
	# location.

	set res [string range $content $at $last]
	set at $last
	incr at

	my Events
	return $res
    }

    method write {c newbytes} {
	# Return immediately if there is nothing is to write.
	set n [string length $newbytes]
	if {$n == 0} {
	    return $n
	}

	# Determine where and how to write. There are three possible cases.
	# (1) Append at/after the end.
	# (2) Starting in the middle, but extending beyond the end.
	# (3) Replace in the middle.

	set max [string length $content]
	if {$at >= $max} {
	    # Ad 1.
	    append content $newbytes
	    set at [string length $content]
	} else {
	    set last [expr {$at + $n - 1}]
	    if {$last >= $max} {
		# Ad 2.
		set content [string replace $content $at end $newbytes]
		set at [string length $content]
	    } else {
		# Ad 3.
		set content [string replace $content $at $last $newbytes]
		set at $last
		incr at
	    }
	}

	my Events
	return $n
    }

    method seek {c offset base} {
	# offset == 0 && base == current
	# <=> Seek nothing relative to current
	# <=> Report current location.

	if {!$offset && ($base eq "current")} {
	    return $at
	}

	# Compute the new location per the arguments.

	set max [string length $content]
	switch -exact -- $base {
	    start   { set newloc $offset}
	    current { set newloc [expr {$at  + $offset }] }
	    end     { set newloc [expr {$max + $offset }] }
	}

	# Check if the new location is beyond the range given by the
	# content.

	if {$newloc < 0} {
	    return -code error "Cannot seek before the start of the channel"
	} elseif {$newloc > $max} {
	    # We can seek beyond the end of the current contents, add
	    # a block of zeros.
	    #puts XXX.PAD.[expr {$newloc - $max}]
	    append content [binary format @[expr {$newloc - $max}]]
	}

	# Commit to new location, switch readable events, and report.
	set at $newloc

	my Events
	return $at
    }

    method Events {} {
	# Always readable -- Even if the seek location is at the end
	# (or beyond).  In that case the readable events are fired
	# endlessly until the eof indicated by the seek location is
	# properly processed by the event handler. Like for regular
	# files -- Ticket [864a0c83e3].
	my allow read
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::memchan 1.0.4
return

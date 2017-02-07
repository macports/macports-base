# queue.tcl --
#
#	Queue implementation for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2008-2010 Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: queue_oo.tcl,v 1.2 2010/09/10 17:31:04 andreas_kupries Exp $

package require Tcl   8.5
package require TclOO 0.6.1- ; # This includes 1 and higher.

# Cleanup first
catch {namespace delete ::struct::queue::queue_oo}
catch {rename           ::struct::queue::queue_oo {}}
oo::class create ::struct::queue::queue_oo {

    variable qat qret qadd

    # variable qat  - Index in qret of next element to return
    # variable qret - List of elements waiting for return
    # variable qadd - List of elements added and not yet reached for return.

    constructor {} {
	set qat  0
	set qret [list]
	set qadd [list]
	return
    }

    # clear --
    #
    #	Clear a queue.
    #
    # Results:
    #	None.

    method clear {} {
	set qat  0
	set qret [list]
	set qadd [list]
	return
    }

    # get --
    #
    #	Get an item from a queue.
    #
    # Arguments:
    #	count	number of items to get; defaults to 1
    #
    # Results:
    #	item	first count items from the queue; if there are not enough 
    #		items in the queue, throws an error.

    method get {{count 1}} {
	if { $count < 1 } {
	    return -code error "invalid item count $count"
	} elseif { $count > [my size] } {
	    return -code error "insufficient items in queue to fill request"
	}

	my Shift?

	if { $count == 1 } {
	    # Handle this as a special case, so single item gets aren't
	    # listified

	    set item [lindex $qret $qat]
	    incr qat
	    my Shift?
	    return $item
	}

	# Otherwise, return a list of items

	if {$count > ([llength $qret] - $qat)} {
	    # Need all of qret (from qat on) and parts of qadd, maybe all.
	    set max    [expr {$qat + $count - 1 - [llength $qret]}]
	    set result [concat [lrange $qret $qat end] [lrange $qadd 0 $max]]
	    my Shift
	    set qat $max
	} else {
	    # Request can be satisified from qret alone.
	    set max    [expr {$qat + $count - 1}]
	    set result [lrange $qret $qat $max]
	    set qat $max
	}

	incr qat
	my Shift?
	return $result
    }

    # peek --
    #
    #	Retrieve the value of an item on the queue without removing it.
    #
    # Arguments:
    #	count	number of items to peek; defaults to 1
    #
    # Results:
    #	items	top count items from the queue; if there are not enough items
    #		to fulfill the request, throws an error.

    method peek {{count 1}} {
	variable queues
	if { $count < 1 } {
	    return -code error "invalid item count $count"
	} elseif { $count > [my size] } {
	    return -code error "insufficient items in queue to fill request"
	}

	my Shift?

	if { $count == 1 } {
	    # Handle this as a special case, so single item pops aren't
	    # listified
	    return [lindex $qret $qat]
	}

	# Otherwise, return a list of items

	if {$count > [llength $qret] - $qat} {
	    # Need all of qret (from qat on) and parts of qadd, maybe all.
	    set over [expr {$qat + $count - 1 - [llength $qret]}]
	    return [concat [lrange $qret $qat end] [lrange $qadd 0 $over]]
	} else {
	    # Request can be satisified from qret alone.
	    return [lrange $qret $qat [expr {$qat + $count - 1}]]
	}
    }

    # put --
    #
    #	Put an item into a queue.
    #
    # Arguments:
    #	args	items to put.
    #
    # Results:
    #	None.

    method put {args} {
	if {![llength $args]} {
	    return -code error "wrong # args: should be \"[self] put item ?item ...?\""
	}
	foreach item $args {
	    lappend qadd $item
	}
	return
    }

    # unget --
    #
    #	Put an item into a queue. At the _front_!
    #
    # Arguments:
    #	item	item to put at the front of the queue
    #
    # Results:
    #	None.

    method unget {item} {
	if {![llength $qret]} {
	    set qret [list $item]
	} elseif {$qat == 0} {
	    set qret [linsert [my K $qret [unset qret]] 0 $item]
	} else {
	    # step back and modify return buffer
	    incr qat -1
	    set qret [lreplace [my K $qret [unset qret]] $qat $qat $item]
	}
	return
    }

    # size --
    #
    #	Return the number of objects on a queue.
    #
    # Results:
    #	count	number of items on the queue.

    method size {} {
	return [expr {
		      [llength $qret] + [llength $qadd] - $qat
		  }]
    }

    # ### ### ### ######### ######### #########

    method Shift? {} {
	if {$qat < [llength $qret]} return
	# inlined Shift
	set qat 0
	set qret $qadd
	set qadd [list]
	return
    }

    method Shift {} {
	set qat 0
	set qret $qadd
	set qadd [list]
	return
    }

    method K {x y} { set x }
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'queue::queue' into the general structure namespace for
    # pickup by the main management.

    proc queue_tcl {args} {
	if {[llength $args]} {
	    uplevel 1 [::list ::struct::queue::queue_oo create {*}$args]
	} else {
	    uplevel 1 [::list ::struct::queue::queue_oo new]
	}
    }
}

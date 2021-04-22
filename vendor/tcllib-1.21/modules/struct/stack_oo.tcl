# stack.tcl --
#
#	Stack implementation for Tcl 8.6+, or 8.5 + TclOO
#
# Copyright (c) 2010 Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: stack_oo.tcl,v 1.4 2010/09/10 17:31:04 andreas_kupries Exp $

package require Tcl   8.5
package require TclOO 0.6.1- ; # This includes 1 and higher.

# Cleanup first
catch {namespace delete ::struct::stack::stack_oo}
catch {rename           ::struct::stack::stack_oo {}}

oo::class create ::struct::stack::stack_oo {

    variable mystack

    constructor {} {
	set mystack {}
	return
    }

    # clear --
    #
    #	Clear a stack.
    #
    # Results:
    #	None.

    method clear {} {
	set mystack {}
	return
    }

    # get --
    #
    #	Retrieve the whole contents of the stack.
    #
    # Results:
    #	items	list of all items in the stack.

    method get {} {
	return [lreverse $mystack]
    }

    method getr {} {
	return $mystack
    }

    # peek --
    #
    #	Retrieve the value of an item on the stack without popping it.
    #
    # Arguments:
    #	count	number of items to pop; defaults to 1
    #
    # Results:
    #	items	top count items from the stack; if there are not enough items
    #		to fulfill the request, throws an error.

    method peek {{count 1}} {
	if { $count < 1 } {
	    return -code error "invalid item count $count"
	} elseif { $count > [llength $mystack] } {
	    return -code error "insufficient items on stack to fill request"
	}

	if { $count == 1 } {
	    # Handle this as a special case, so single item peeks are not
	    # listified
	    return [lindex $mystack end]
	}

	# Otherwise, return a list of items
	incr count -1
	return [lreverse [lrange $mystack end-$count end]]
    }

    method peekr {{count 1}} {
	if { $count < 1 } {
	    return -code error "invalid item count $count"
	} elseif { $count > [llength $mystack] } {
	    return -code error "insufficient items on stack to fill request"
	}

	if { $count == 1 } {
	    # Handle this as a special case, so single item peeks are not
	    # listified
	    return [lindex $mystack end]
	}

	# Otherwise, return a list of items, in reversed order.
	incr count -1
	return [lrange $mystack end-$count end]
    }

    # trim --
    #
    #	Pop items off a stack until a maximum size is reached.
    #
    # Arguments:
    #	count	requested size of the stack.
    #
    # Results:
    #	item	List of items trimmed, may be empty.

    method trim {newsize} {
	if { ![string is integer -strict $newsize]} {
	    return -code error "expected integer but got \"$newsize\""
	} elseif { $newsize < 0 } {
	    return -code error "invalid size $newsize"
	} elseif { $newsize >= [llength $mystack] } {
	    # Stack is smaller than requested, do nothing.
	    return {}
	}

	# newsize < [llength $mystack]
	# pop '[llength $mystack]' - newsize elements.

	if {!$newsize} {
	    set result [lreverse [my K $mystack [unset mystack]]]
	    set mystack {}
	} else {
	    set result  [lreverse [lrange $mystack $newsize end]]
	    set mystack [lreplace [my K $mystack [unset mystack]] $newsize end]
	}

	return $result
    }

    method trim* {newsize} {
	if { ![string is integer -strict $newsize]} {
	    return -code error "expected integer but got \"$newsize\""
	} elseif { $newsize < 0 } {
	    return -code error "invalid size $newsize"
	}

	if { $newsize >= [llength $mystack] } {
	    # Stack is smaller than requested, do nothing.
	    return
	}

	# newsize < [llength $mystack]
	# pop '[llength $mystack]' - newsize elements.

	# No results, compared to trim. 

	if {!$newsize} {
	    set mystack {}
	} else {
	    set mystack [lreplace [my K $mystack [unset mystack]] $newsize end]
	}

	return
    }

    # pop --
    #
    #	Pop an item off a stack.
    #
    # Arguments:
    #	count	number of items to pop; defaults to 1
    #
    # Results:
    #	item	top count items from the stack; if the stack is empty, 
    #		returns a list of count nulls.

    method pop {{count 1}} {
	if { $count < 1 } {
	    return -code error "invalid item count $count"
	}

	set ssize [llength $mystack]

	if { $count > $ssize } {
	    return -code error "insufficient items on stack to fill request"
	}

	if { $count == 1 } {
	    # Handle this as a special case, so single item pops are not
	    # listified
	    set item [lindex $mystack end]
	    if {$count == $ssize} {
		set mystack [list]
	    } else {
		set mystack [lreplace [my K $mystack [unset mystack]] end end]
	    }
	    return $item
	}

	# Otherwise, return a list of items, and remove the items from the
	# stack.
	if {$count == $ssize} {
	    set result  [lreverse [my K $mystack [unset mystack]]]
	    set mystack [list]
	} else {
	    incr count -1
	    set result  [lreverse [lrange $mystack end-$count end]]
	    set mystack [lreplace [my K $mystack [unset mystack]] end-$count end]
	}
	return $result
    }

    # push --
    #
    #	Push an item onto a stack.
    #
    # Arguments:
    #	args	items to push.
    #
    # Results:
    #	None.

    method push {args} {
	if {![llength $args]} {
	    return -code error "wrong # args: should be \"[self] push item ?item ...?\""
	}

	lappend mystack {*}$args
	return
    }

    # rotate --
    #
    #	Rotate the top count number of items by step number of steps.
    #
    # Arguments:
    #	count	number of items to rotate.
    #	steps	number of steps to rotate.
    #
    # Results:
    #	None.

    method rotate {count steps} {
	set len [llength $mystack]
	if { $count > $len } {
	    return -code error "insufficient items on stack to fill request"
	}

	# Rotation algorithm:
	# do
	#   Find the insertion point in the stack
	#   Move the end item to the insertion point
	# repeat $steps times

	set start [expr {$len - $count}]
	set steps [expr {$steps % $count}]

	if {$steps == 0} return

	for {set i 0} {$i < $steps} {incr i} {
	    set item [lindex $mystack end]
	    set mystack [linsert \
			     [lreplace \
				  [my K $mystack [unset mystack]] \
				  end end] $start $item]
	}
	return
    }

    # size --
    #
    #	Return the number of objects on a stack.
    #
    # Results:
    #	count	number of items on the stack.

    method size {} {
	return [llength $mystack]
    }

    # ### ### ### ######### ######### #########

    method K {x y} { set x }
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'stack::stack' into the general structure namespace for
    # pickup by the main management.

    proc stack_tcl {args} {
	if {[llength $args]} {
	    uplevel 1 [::list ::struct::stack::stack_oo create {*}$args]
	} else {
	    uplevel 1 [::list ::struct::stack::stack_oo new]
	}
    }
}

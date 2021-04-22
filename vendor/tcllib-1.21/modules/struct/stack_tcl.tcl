# stack.tcl --
#
#	Stack implementation for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: stack_tcl.tcl,v 1.3 2010/03/15 17:17:38 andreas_kupries Exp $

namespace eval ::struct::stack {
    # counter is used to give a unique name for unnamed stacks
    variable counter 0

    # Only export one command, the one used to instantiate a new stack
    namespace export stack_tcl
}

# ::struct::stack::stack_tcl --
#
#	Create a new stack with a given name; if no name is given, use
#	stackX, where X is a number.
#
# Arguments:
#	name	name of the stack; if null, generate one.
#
# Results:
#	name	name of the stack created

proc ::struct::stack::stack_tcl {args} {
    variable I::stacks
    variable counter
    
    switch -exact -- [llength [info level 0]] {
	1 {
	    # Missing name, generate one.
	    incr counter
	    set name "stack${counter}"
	}
	2 {
	    # Standard call. New empty stack.
	    set name [lindex $args 0]
	}
	default {
	    # Error.
	    return -code error \
		    "wrong # args: should be \"stack ?name?\""
	}
    }

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 [list namespace current]]
        if {"::" != $ns} {
            append ns "::"
        }

        set name "$ns$name"
    }
    if {[llength [info commands $name]]} {
	return -code error \
		"command \"$name\" already exists, unable to create stack"
    }

    set stacks($name) [list ]

    # Create the command to manipulate the stack
    interp alias {} $name {} ::struct::stack::StackProc $name

    return $name
}

##########################
# Private functions follow

# ::struct::stack::StackProc --
#
#	Command that processes all stack object commands.
#
# Arguments:
#	name	name of the stack object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

if {[package vsatisfies [package provide Tcl] 8.5]} {
    # In 8.5+ we can do an ensemble for fast dispatch.

    proc ::struct::stack::StackProc {name cmd args} {
	# Shuffle method to front and then simply run the ensemble.
	# Dispatch, argument checking, and error message generation
	# are all done in the C-level.

	I $cmd $name {*}$args
    }

    namespace eval ::struct::stack::I {
	namespace export clear destroy get getr peek peekr \
	    trim trim* pop push rotate size
	namespace ensemble create
    }

} else {
    # Before 8.5 we have to code our own dispatch, including error
    # checking.

    proc ::struct::stack::StackProc {name cmd args} {
	# Do minimal args checks here
	if { [llength [info level 0]] == 2 } {
	    return -code error "wrong # args: should be \"$name option ?arg arg ...?\""
	}

	# Split the args into command and args components
	if {![llength [info commands ::struct::stack::I::$cmd]]} {
	    set optlist [lsort [info commands ::struct::stack::I::*]]
	    set xlist {}
	    foreach p $optlist {
		set p [namespace tail $p]
		if {($p eq "K") || ($p eq "lreverse")} continue
		lappend xlist $p
	    }
	    set optlist [linsert [join $xlist ", "] "end-1" "or"]
	    return -code error \
		"bad option \"$cmd\": must be $optlist"
	}

	uplevel 1 [linsert $args 0 ::struct::stack::I::$cmd $name]
    }
}

# ### ### ### ######### ######### #########

namespace eval ::struct::stack::I {
    # The stacks array holds all of the stacks you've made
    variable stacks
}

# ### ### ### ######### ######### #########

# ::struct::stack::I::clear --
#
#	Clear a stack.
#
# Arguments:
#	name	name of the stack object.
#
# Results:
#	None.

proc ::struct::stack::I::clear {name} {
    variable stacks
    set stacks($name) {}
    return
}

# ::struct::stack::I::destroy --
#
#	Destroy a stack object by removing it's storage space and 
#	eliminating it's proc.
#
# Arguments:
#	name	name of the stack object.
#
# Results:
#	None.

proc ::struct::stack::I::destroy {name} {
    variable stacks
    unset stacks($name)
    interp alias {} $name {}
    return
}

# ::struct::stack::I::get --
#
#	Retrieve the whole contents of the stack.
#
# Arguments:
#	name	name of the stack object.
#
# Results:
#	items	list of all items in the stack.

proc ::struct::stack::I::get {name} {
    variable stacks
    return [lreverse $stacks($name)]
}

proc ::struct::stack::I::getr {name} {
    variable stacks
    return $stacks($name)
}

# ::struct::stack::I::peek --
#
#	Retrieve the value of an item on the stack without popping it.
#
# Arguments:
#	name	name of the stack object.
#	count	number of items to pop; defaults to 1
#
# Results:
#	items	top count items from the stack; if there are not enough items
#		to fulfill the request, throws an error.

proc ::struct::stack::I::peek {name {count 1}} {
    variable stacks
    upvar 0  stacks($name) mystack

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

proc ::struct::stack::I::peekr {name {count 1}} {
    variable stacks
    upvar 0  stacks($name) mystack

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

# ::struct::stack::I::trim --
#
#	Pop items off a stack until a maximum size is reached.
#
# Arguments:
#	name	name of the stack object.
#	count	requested size of the stack.
#
# Results:
#	item	List of items trimmed, may be empty.

proc ::struct::stack::I::trim {name newsize} {
    variable stacks
    upvar 0  stacks($name) mystack

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
	set result [lreverse [K $mystack [unset mystack]]]
	set mystack {}
    } else {
	set result  [lreverse [lrange $mystack $newsize end]]
	set mystack [lreplace [K $mystack [unset mystack]] $newsize end]
    }

    return $result
}

proc ::struct::stack::I::trim* {name newsize} {
    if { ![string is integer -strict $newsize]} {
	return -code error "expected integer but got \"$newsize\""
    } elseif { $newsize < 0 } {
	return -code error "invalid size $newsize"
    }

    variable stacks
    upvar 0  stacks($name) mystack

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
	set mystack [lreplace [K $mystack [unset mystack]] $newsize end]
    }

    return
}

# ::struct::stack::I::pop --
#
#	Pop an item off a stack.
#
# Arguments:
#	name	name of the stack object.
#	count	number of items to pop; defaults to 1
#
# Results:
#	item	top count items from the stack; if the stack is empty, 
#		returns a list of count nulls.

proc ::struct::stack::I::pop {name {count 1}} {
    variable stacks
    upvar 0  stacks($name) mystack

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
	    set mystack [lreplace [K $mystack [unset mystack]] end end]
	}
	return $item
    }

    # Otherwise, return a list of items, and remove the items from the
    # stack.
    if {$count == $ssize} {
	set result  [lreverse [K $mystack [unset mystack]]]
	set mystack [list]
    } else {
	incr count -1
	set result  [lreverse [lrange $mystack end-$count end]]
	set mystack [lreplace [K $mystack [unset mystack]] end-$count end]
    }
    return $result

    # -------------------------------------------------------

    set newsize [expr {[llength $mystack] - $count}]

    if {!$newsize} {
	set result [lreverse [K $mystack [unset mystack]]]
	set mystack {}
    } else {
	set result  [lreverse [lrange $mystack $newsize end]]
	set mystack [lreplace [K $mystack [unset mystack]] $newsize end]
    }

    if {$count == 1} {
	set result [lindex $result 0]
    }

    return $result
}

# ::struct::stack::I::push --
#
#	Push an item onto a stack.
#
# Arguments:
#	name	name of the stack object
#	args	items to push.
#
# Results:
#	None.

if {[package vsatisfies [package provide Tcl] 8.5]} {

    proc ::struct::stack::I::push {name args} {
	if {![llength $args]} {
	    return -code error "wrong # args: should be \"$name push item ?item ...?\""
	}

	variable stacks
	upvar 0  stacks($name) mystack

	lappend mystack {*}$args
	return
    }
} else {
    proc ::struct::stack::I::push {name args} {
	if {![llength $args]} {
	    return -code error "wrong # args: should be \"$name push item ?item ...?\""
	}

	variable stacks
	upvar 0  stacks($name) mystack

	if {[llength $args] == 1} {
	    lappend mystack [lindex $args 0]
	} else {
	    eval [linsert $args 0 lappend mystack]
	}
	return
    }
}

# ::struct::stack::I::rotate --
#
#	Rotate the top count number of items by step number of steps.
#
# Arguments:
#	name	name of the stack object.
#	count	number of items to rotate.
#	steps	number of steps to rotate.
#
# Results:
#	None.

proc ::struct::stack::I::rotate {name count steps} {
    variable stacks
    upvar 0  stacks($name) mystack
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
			      [K $mystack [unset mystack]] \
			      end end] $start $item]
    }
    return
}

# ::struct::stack::I::size --
#
#	Return the number of objects on a stack.
#
# Arguments:
#	name	name of the stack object.
#
# Results:
#	count	number of items on the stack.

proc ::struct::stack::I::size {name} {
    variable stacks
    return [llength $stacks($name)]
}

# ### ### ### ######### ######### #########

proc ::struct::stack::I::K {x y} { set x }

if {![llength [info commands lreverse]]} {
    proc ::struct::stack::I::lreverse {x} {
	# assert (llength(x) > 1)
	set l [llength $x]
	if {$l <= 1} { return $x }
	set r [list]
	while {$l} { lappend r [lindex $x [incr l -1]] }
	return $r
    }
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'stack::stack' into the general structure namespace for
    # pickup by the main management.
    namespace import -force stack::stack_tcl
}

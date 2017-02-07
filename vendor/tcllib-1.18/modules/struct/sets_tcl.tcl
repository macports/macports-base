#----------------------------------------------------------------------
#
# sets_tcl.tcl --
#
#	Definitions for the processing of sets.
#
# Copyright (c) 2004-2008 by Andreas Kupries.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: sets_tcl.tcl,v 1.4 2008/03/09 04:38:47 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package require Tcl 8.0

namespace eval ::struct::set {
    # Only export one command, the one used to instantiate a new tree
    namespace export set_tcl
}

##########################
# Public functions

# ::struct::set::set --
#
#	Command that access all set commands.
#
# Arguments:
#	cmd	Name of the subcommand to dispatch to.
#	args	Arguments for the subcommand.
#
# Results:
#	Whatever the result of the subcommand is.

proc ::struct::set::set_tcl {cmd args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 1 } {
	return -code error "wrong # args: should be \"$cmd ?arg arg ...?\""
    }
    ::set sub S_$cmd
    if { [llength [info commands ::struct::set::$sub]] == 0 } {
	::set optlist [info commands ::struct::set::S_*]
	::set xlist {}
	foreach p $optlist {
	    lappend xlist [string range $p 17 end]
	}
	return -code error \
		"bad option \"$cmd\": must be [linsert [join [lsort $xlist] ", "] "end-1" "or"]"
    }
    return [uplevel 1 [linsert $args 0 ::struct::set::$sub]]
}

##########################
# Implementations of the functionality.
#

# ::struct::set::S_empty --
#
#       Determines emptiness of the set
#
# Parameters:
#       set	-- The set to check for emptiness.
#
# Results:
#       A boolean value. True indicates that the set is empty.
#
# Side effects:
#       None.
#
# Notes:

proc ::struct::set::S_empty {set} {
    return [expr {[llength $set] == 0}]
}

# ::struct::set::S_size --
#
#	Computes the cardinality of the set.
#
# Parameters:
#	set	-- The set to inspect.
#
# Results:
#       An integer greater than or equal to zero.
#
# Side effects:
#       None.

proc ::struct::set::S_size {set} {
    return [llength [Cleanup $set]]
}

# ::struct::set::S_contains --
#
#	Determines if the item is in the set.
#
# Parameters:
#	set	-- The set to inspect.
#	item	-- The element to look for.
#
# Results:
#	A boolean value. True indicates that the element is present.
#
# Side effects:
#       None.

proc ::struct::set::S_contains {set item} {
    return [expr {[lsearch -exact $set $item] >= 0}]
}

# ::struct::set::S_union --
#
#	Computes the union of the arguments.
#
# Parameters:
#	args	-- List of sets to unify.
#
# Results:
#	The union of the arguments.
#
# Side effects:
#       None.

proc ::struct::set::S_union {args} {
    switch -exact -- [llength $args] {
	0 {return {}}
	1 {return [lindex $args 0]}
    }
    foreach setX $args {
	foreach x $setX {::set ($x) {}}
    }
    return [array names {}]
}


# ::struct::set::S_intersect --
#
#	Computes the intersection of the arguments.
#
# Parameters:
#	args	-- List of sets to intersect.
#
# Results:
#	The intersection of the arguments
#
# Side effects:
#       None.

proc ::struct::set::S_intersect {args} {
    switch -exact -- [llength $args] {
	0 {return {}}
	1 {return [lindex $args 0]}
    }
    ::set res [lindex $args 0]
    foreach set [lrange $args 1 end] {
	if {[llength $res] && [llength $set]} {
	    ::set res [Intersect $res $set]
	} else {
	    # Squash 'res'. Otherwise we get the wrong result if res
	    # is not empty, but 'set' is.
	    ::set res {}
	    break
	}
    }
    return $res
}

proc ::struct::set::Intersect {A B} {
    if {[llength $A] == 0} {return {}}
    if {[llength $B] == 0} {return {}}

    # This is slower than local vars, but more robust
    if {[llength $B] > [llength $A]} {
	::set res $A
	::set A $B
	::set B $res
    }
    ::set res {}
    foreach x $A {::set ($x) {}}
    foreach x $B {
	if {[info exists ($x)]} {
	    lappend res $x
	}
    }
    return $res
}

# ::struct::set::S_difference --
#
#	Compute difference of two sets.
#
# Parameters:
#	A, B	-- Sets to compute the difference for.
#
# Results:
#	A - B
#
# Side effects:
#       None.

proc ::struct::set::S_difference {A B} {
    if {[llength $A] == 0} {return {}}
    if {[llength $B] == 0} {return $A}

    array set tmp {}
    foreach x $A {::set tmp($x) .}
    foreach x $B {catch {unset tmp($x)}}
    return [array names tmp]
}

if {0} {
    # Tcllib SF Bug 1002143. We cannot use the implementation below.
    # It will treat set elements containing '(' and ')' as array
    # elements, and this screws up the storage of elements as the name
    # of local vars something fierce. No way around this. Disabling
    # this code and always using the other implementation (s.a.) is
    # the only possible fix.

    if {[package vcompare [package provide Tcl] 8.4] < 0} {
	# Tcl 8.[23]. Use explicit array to perform the operation.
    } else {
	# Tcl 8.4+, has 'unset -nocomplain'

	proc ::struct::set::S_difference {A B} {
	    if {[llength $A] == 0} {return {}}
	    if {[llength $B] == 0} {return $A}

	    # Get the variable B out of the way, avoid collisions
	    # prepare for "pure list optimization"
	    ::set ::struct::set::tmp [lreplace $B -1 -1 unset -nocomplain]
	    unset B

	    # unset A early: no local variables left
	    foreach [lindex [list $A [unset A]] 0] {.} {break}

	    eval $::struct::set::tmp
	    return [info locals]
	}
    }
}

# ::struct::set::S_symdiff --
#
#	Compute symmetric difference of two sets.
#
# Parameters:
#	A, B	-- The sets to compute the s.difference for.
#
# Results:
#	The symmetric difference of the two input sets.
#
# Side effects:
#       None.

proc ::struct::set::S_symdiff {A B} {
    # symdiff == (A-B) + (B-A) == (A+B)-(A*B)
    if {[llength $A] == 0} {return $B}
    if {[llength $B] == 0} {return $A}
    return [S_union \
	    [S_difference $A $B] \
	    [S_difference $B $A]]
}

# ::struct::set::S_intersect3 --
#
#	Return intersection and differences for two sets.
#
# Parameters:
#	A, B	-- The sets to inspect.
#
# Results:
#	List containing A*B, A-B, and B-A
#
# Side effects:
#       None.

proc ::struct::set::S_intersect3 {A B} {
    return [list \
	    [S_intersect $A $B] \
	    [S_difference $A $B] \
	    [S_difference $B $A]]
}

# ::struct::set::S_equal --
#
#	Compares two sets for equality.
#
# Parameters:
#	a	First set to compare.
#	b	Second set to compare.
#
# Results:
#	A boolean. True if the lists are equal.
#
# Side effects:
#       None.

proc ::struct::set::S_equal {A B} {
    ::set A [Cleanup $A]
    ::set B [Cleanup $B]

    # Equal if of same cardinality and difference is empty.

    if {[::llength $A] != [::llength $B]} {return 0}
    return [expr {[llength [S_difference $A $B]] == 0}]
}


proc ::struct::set::Cleanup {A} {
    # unset A to avoid collisions
    if {[llength $A] < 2} {return $A}
    # We cannot use variables to avoid an explicit array. The set
    # elements may look like namespace vars (i.e. contain ::), and
    # such elements break that, cannot be proc-local variables.
    array set S {}
    foreach item $A {set S($item) .}
    return [array names S]
}

# ::struct::set::S_include --
#
#	Add an element to a set.
#
# Parameters:
#	Avar	-- Reference to the set variable to extend.
#	element	-- The item to add to the set.
#
# Results:
#	None.
#
# Side effects:
#       The set in the variable referenced by Avar is extended
#	by the element (if the element was not already present).

proc ::struct::set::S_include {Avar element} {
    # Avar = Avar + {element}
    upvar 1 $Avar A
    if {![info exists A] || ![S_contains $A $element]} {
	lappend A $element
    }
    return
}

# ::struct::set::S_exclude --
#
#	Remove an element from a set.
#
# Parameters:
#	Avar	-- Reference to the set variable to shrink.
#	element	-- The item to remove from the set.
#
# Results:
#	None.
#
# Side effects:
#       The set in the variable referenced by Avar is shrunk,
#	the element remove (if the element was actually present).

proc ::struct::set::S_exclude {Avar element} {
    # Avar = Avar - {element}
    upvar 1 $Avar A
    if {![info exists A]} {return -code error "can't read \"$Avar\": no such variable"}
    while {[::set pos [lsearch -exact $A $element]] >= 0} {
	::set A [lreplace [K $A [::set A {}]] $pos $pos]
    }
    return
}

# ::struct::set::S_add --
#
#	Add a set to a set. Similar to 'union', but the first argument
#	is a variable.
#
# Parameters:
#	Avar	-- Reference to the set variable to extend.
#	B	-- The set to add to the set in Avar.
#
# Results:
#	None.
#
# Side effects:
#       The set in the variable referenced by Avar is extended
#	by all the elements in B.

proc ::struct::set::S_add {Avar B} {
    # Avar = Avar + B
    upvar 1 $Avar A
    if {![info exists A]} {set A {}}
    ::set A [S_union [K $A [::set A {}]] $B]
    return
}

# ::struct::set::S_subtract --
#
#	Remove a set from a set. Similar to 'difference', but the first argument
#	is a variable.
#
# Parameters:
#	Avar	-- Reference to the set variable to shrink.
#	B	-- The set to remove from the set in Avar.
#
# Results:
#	None.
#
# Side effects:
#       The set in the variable referenced by Avar is shrunk,
#	all elements of B are removed.

proc ::struct::set::S_subtract {Avar B} {
    # Avar = Avar - B
    upvar 1 $Avar A
    if {![info exists A]} {return -code error "can't read \"$Avar\": no such variable"}
    ::set A [S_difference [K $A [::set A {}]] $B]
    return
}

# ::struct::set::S_subsetof --
#
#	A predicate checking if the first set is a subset
#	or equal to the second set.
#
# Parameters:
#	A	-- The possible subset.
#	B	-- The set to compare to.
#
# Results:
#	A boolean value, true if A is subset of or equal to B
#
# Side effects:
#       None.

proc ::struct::set::S_subsetof {A B} {
    # A subset|== B <=> (A == A*B)
    return [S_equal $A [S_intersect $A $B]]
}

# ::struct::set::K --
# Performance helper command.

proc ::struct::set::K {x y} {::set x}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Put 'set::set' into the general structure namespace
    # for pickup by the main management.

    namespace import -force set::set_tcl
}

# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Utility commands operating on parsing expressions.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5        ; # Required runtime.
package require pt::pe         ; # PE basics
package require struct::set    ; # Set operations (symbol sets)

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::pe::op {
    namespace export \
	drop rename called flatten fusechars

    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

proc ::pt::pe::op::rename {nt ntnew serial} {
    if {$nt eq $ntnew} {
	return $serial
    }
    return [pt::pe bottomup \
		[list [namespace current]::Rename $nt $ntnew] \
		$serial]
}

proc ::pt::pe::op::drop {dropset serial} {
   set res [pt::pe bottomup \
		[list [namespace current]::Drop $dropset] \
		$serial]
   if {$res eq "@@"} { set res [pt::pe epsilon] }
   return $res
}

proc ::pt::pe::op::called {serial} {
    return [pt::pe bottomup \
		[list [namespace current]::Called] \
		$serial]
}

proc ::pt::pe::op::flatten {serial} {
    return [pt::pe bottomup \
		[list [namespace current]::Flatten] \
		$serial]
}

proc ::pt::pe::op::fusechars {serial} {
    return [pt::pe bottomup \
		[list [namespace current]::FuseChars] \
		$serial]
}

# # ## ### ##### ######## #############
## Internals

proc ::pt::pe::op::Drop {dropset pe op arguments} {
    if {$op eq "n"} {
	lassign $arguments symbol
	if {[struct::set contains $dropset $symbol]} {
	    return @@
	} else {
	    return $pe
	}
    }

    switch -exact -- $op {
	/ - x - * - + - ? - & - ! {
	    set newarg {}
	    foreach a $arguments {
		if {$a eq "@@"} continue
		lappend newarg $a
	    }

	    if {![llength $newarg]} {
		# Nothing remained, drop the whole expression
		return [pt::pe epsilon]
	    } elseif {[llength $newarg] < [llength $argument]} {
		# Some removed, construct a new expression
		set pe [list $op {*}$newarg]
	    } ; # None removed, no change.
	}
    }

    return $pe
}

proc ::pt::pe::op::Rename {nt ntnew pe op arguments} {
    #puts R($op)/$arguments/
    if {($op eq "n") && ([lindex $arguments 0] eq $nt)} {
	return [pt::pe nonterminal $ntnew]
    } else {
	return $pe
    }
}

proc ::pt::pe::op::Called {pe op arguments} {
    # arguments = list(set-of-symbols) for operators, and n.
    #             ignored for terminal expressions.
    # result    = set-of-symbols

    #puts -nonewline C|$op|$arguments|=
    switch -exact -- $op {
	n - & - ! - * - + - ? {
	    #puts |[lindex $arguments 0]|
	    return [lindex $arguments 0]
	}
	x - / {
	    #puts |[struct::set union {*}$arguments]|
	    return [struct::set union {*}$arguments]
	}
    }
    #puts ||
    return {}
}

proc ::pt::pe::op::Flatten {pe op arguments} {
    switch -exact -- $op {
	x - / {
	    if {[llength $arguments] == 1} {
		# Cut single-child x/ out of the tree
		return [lindex $arguments 0]
	    } else {
		set res {}
		foreach c $arguments {
		    if {[lindex $c 0] eq $op} {
			# Cut x in x (/ in /) operator out of the
			# tree.
			lappend res {*}[lrange $c 1 end]
		    } else {
			# Leave anything else unchanged.
			lappend res $c
		    }
		}
		return [list $op {*}$res]
	    }
	}
	default {
	    # Leave anything not x/ unchanged
	    return $pe
	}
    }
}

proc ::pt::pe::op::FuseChars {pe op arguments} {
    switch -exact -- $op {
	x {
	    set changed 0  ; # boolean flag showing if fuse ops were done.
	    set buf     {} ; # accumulator of chars in a string.
	    set res     {} ; # accumulator of new children for operator.

	    foreach c $arguments {
		CollectTerminal $c
		FuseTerminal
		lappend res $c
	    }

	    # Capture a run of characters at the end of the sequence.
	    FuseTerminal

	    if {$changed} {
		return [list x {*}$res]
	    } else {
		return $pe
	    }
	}
	/ {
	    set changed 0  ; # boolean flag showing if fuse ops were done.
	    set buf     {} ; # accumulator of chars and ranges in a class.
	    set res     {} ; # accumulator of new children for operator.

	    foreach c $arguments {
		CollectClass $c
		FuseClass
		lappend res $c
	    }

	    # Capture a run of characters and ranges at the end of the
	    # sequence.
	    FuseClass

	    if {$changed} {
		return [list / {*}$res]
	    } else {
		return $pe
	    }
	}
	default {
	    # Leave anything not x/ unchanged
	    return $pe
	}
    }
}

# # ## ### ##### ######## #############
## Fuser Support

proc ::pt::pe::op::CollectTerminal {c} {
    if {[lindex $c 0] ne "t"} return

    # A terminal. Just extend the accumulator. The main processing
    # happens after each run of t-operators, see FuseTerminal.

    upvar 1 buf buf
    lappend buf [lindex $c 1]
    return -code continue
}

proc ::pt::pe::op::FuseTerminal {} {
    upvar 1 changed changed res res buf buf

    # Nothing has accumulated, nothing to fuse.
    if {$buf eq {}} return

    # The current non-t operator is after one or more t-operators. We
    # have to flush its accumulated data to keep the expression
    # correct.

    if {[llength $buf] > 1} {
	# We are behind an actual series of t-operators, i.e. a
	# string. We flush it and signal the change to the processing
	# after the loop,

	lappend res [list str {*}$buf]
	set changed 1
    } else {
	# We are behind a single t-operator. We keep it as is, there
	# is no actual need to make it a string.

	lappend res [pt::pe terminal [lindex $buf 0]]
    }

    # Reset the accumulator for the next series.
    set buf {}
    return
}

# # ## ### ##### ######## #############

proc ::pt::pe::op::CollectClass {c} {
    if {[lindex $c 0] ni {t ..}} return

    # A terminal or range. Just extend the accumulator. The main processing
    # happens after each run of t-operators, see FuseClass.

    upvar 1 buf buf
    set new [lrange $c 1 end]
    if {([llength $new] == 1) || ([lindex $new 0] eq [lindex $new 1])} {
	set new [list [lindex $new 0]]
	#set new [lindex $new 0]
	# Note how new is rewrapped as a list, because that is what
	# FuseClass below expects, always. See <*>
    }
    lappend buf $new
    return -code continue
}

proc ::pt::pe::op::FuseClass {} {
    upvar 1 changed changed res res buf buf

    # buf :: list (elems), elems :: list (char ?char?)

    # Nothing has accumulated, nothing to fuse.
    if {$buf eq {}} return

    # The current non-t operator is after one or more
    # t/..-operators. We have to flush the accumulated data to keep
    # the expression correct.

    if {[llength $buf] > 1} {
	# We are behind an actual series of t/..-operators, i.e. a
	# class. We flush it, signal the change to the processing
	# after the loop, and reset the accumulator for the next
	# series.

	# TODO :: Sort class elements, aggregate adjacents into larger
	#         ranges if possible and worthwhile (>= 3), look for
	#         overlapping ranges and merge.

	# buf :: list (elems), elems :: list (char ?char?)
	# The single-element elems have to change, become simple chars.
	# A simple {*}-operation is not enough, as that leaves these as lists.

	lappend tmp cl
	foreach elem $buf {
	    if {[llength $elem] == 1} {
		lappend tmp [lindex $elem 0]
	    } else {
		lappend tmp $elem
	    }
	}
	lappend res $tmp
	set changed 1
    } else {
	# We are behind a single t- or ..-operator. A terminal can be
	# kept as is, but a range has to be encapsulated into a class,
	# except of the range is something like a-a, then this is just
	# a different coding of a single character ... 

	set args [lindex $buf 0] ; # <*> args expected to be a list.
	if {[llength $args] == 1} {
	    lappend res [pt::pe terminal [lindex $args 0]]
	} else {
	    lassign $args a b
	    set changed 1
	    if {$a ne $b} {
		lappend res [list cl {*}$buf]
	    } else {
		lappend res [pt::pe terminal $a]
	    }
	}
    }

    # Reset the accumulator for the next series.
    set buf {}
    return
}

# # ## ### ##### ######## #############
## State / Configuration :: n/a

namespace eval ::pt::pe::op {}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::pe::op 1.0.1
return

# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Verification of serialized parsing expressions, conversion
# between such and other data structures, and their construction.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require char                 ; # Character quoting utilities.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::ast {
    namespace export \
	verify verify-as-canonical canonicalize \
	equal bottomup topdown \
	print new new0

    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of an abstract syntax tree is
# indeed such.

proc ::pt::ast::verify {serial {canonvar {}}} {
    variable ourprefix
    #puts "V <$serial> /[llength [info level 0]] / [info level 0]"

    if {$canonvar ne {}} {
	upvar 1 $canonvar iscanonical
	set iscanonical [string equal $serial [list {*}$serial]]
    }

    topdown [list [namespace current]::Verify] $serial
    return
}

proc ::pt::ast::verify-as-canonical {serial} {
    verify $serial iscanonical
    if {!$iscanonical} {
	variable ourprefix
	variable ourimpure
	return -code error $ourprefix$ourimpure
    }
    return
}

proc ::pt::ast::Verify {ast} {
    variable ourprefix
    variable ourbadrange
    variable ourbadend
    variable ourbadstart
    variable ourshort

    if {[llength $ast] < 3} {
	return -code error $ourprefix$ourshort
    }

    # Open Questions
    # - Should we constrain the locations of the children to be
    #   inside of the parent ?
    # - Should we constrain the locations of the children to not
    #   overlap ?
    # Note: Gaps we have to allow, comments and whitespace and such.

    lassign $ast type start end

    if {![string is integer -strict $start]} {
	return -code error $ourprefix[format $ourbadstart $start]
    } elseif {$start < 0} {
	return -code error $ourprefix[format $ourbadstart $start]
    }

    if {![string is integer -strict $end] || ($end < 0)} {
	return -code error $ourprefix[format $ourbadend $end]
    }

    if {$end < $start} {
	return -code error $ourprefix$ourbadrange
    }

    upvar 1 iscanonical iscanonical
    if {
	[info exists iscanonical] && ($ast ne [list {*}$ast])
    } {
	# Reject coding with superfluous whitespace as non-canonical.
	set iscanonical 0
    }
    return
}

# # ## ### ##### ######## #############

proc ::pt::ast::canonicalize {serial} {
    verify $serial iscanonical
    if {$iscanonical} { return $serial }
    return [bottomup [list [namespace current]::Canonicalize] $serial]
}

proc ::pt::ast::Canonicalize {ast} {
    # We construct a pure list out of the node data.
    return [list {*}$ast]
}

# # ## ### ##### ######## #############

# Converts a parsing expression serialization into a human readable
# string for test results. It assumes that the serialization is at
# least structurally sound.

proc ::pt::ast::print {serial} {
    return [join [bottomup [list [namespace current]::Print] $serial] \n]
}

proc ::pt::ast::Print {ast} {
    set children [lassign $ast type start end]
    set result   [list [list <$type> :: $start $end]]

    # The arguments are already processed for printing
    foreach c $children {
	foreach line $c {
	    lappend result "    $line"
	}
    }
    return $result
}

# # ## ### ##### ######## #############

proc ::pt::ast::equal {seriala serialb} {
    return [string equal \
		[canonicalize $seriala] \
		[canonicalize $serialb]]
}

# # ## ### ##### ######## #############

proc ::pt::ast::bottomup {cmdprefix ast} {
    Bottomup 2 $cmdprefix $ast
}

proc ::pt::ast::Bottomup {level cmdprefix ast} {
    set children [lassign $ast type start end]
    set new      [list $type $start $end]

    set clevel $level
    incr clevel

    foreach c $children {
	lappend new [Bottomup $clevel $cmdprefix $c]
    }

    return [uplevel $level [list {*}$cmdprefix $new]]
}

proc ::pt::ast::topdown {cmdprefix ast} {
    Topdown 2 $cmdprefix $ast
    return
}

proc ::pt::ast::Topdown {level cmdprefix ast} {
    uplevel $level [list {*}$cmdprefix $ast]

    incr level
    foreach c [lrange $ast 3 end] {
	Topdown $level $cmdprefix $c
    }
    return
}

# # ## ### ##### ######## #############

proc ::pt::ast::new {sym start end args} {
    variable ourbadstart
    variable ourbadend
    variable ourbadrange

    if {![string is integer -strict $start] || ($start < 0)} {
	return -code error [format $ourbadstart $start]
    }
    if {![string is integer -strict $end] || ($end < 0)} {
	return -code error [format $ourbadend $end]
    }
    if {$end < $start} {
	return -code error $ourbadrange
    }

    return [list $sym $start $end {*}$args]
}

proc ::pt::ast::new0 {sym start args} {
    variable ourbadstart

    if {![string is integer -strict $start] || ($start < 0)} {
	return -code error [format $ourbadstart $start]
    }

    # The end of the range is placed one position before the start,
    # making it zero-length (length = end-start+1), i.e. empty. Such
    # nodes are possible for symbols whose RHS uses * or ? as their
    # top-level operator.

    set  end $start
    incr end -1

    return [list $sym $start $end {*}$args]
}

namespace eval ::pt::ast {
    # # ## ### ##### ######## #############
    ## Strings for error messages.

    variable ourprefix    "error in serialization:"
    variable ourbadstart  " expected integer >= 0 as start of range, got \"%s\""
    variable ourbadend    " expected integer >= 0 as end of range, got \"%s\""
    variable ourbadrange  " expected start <= end for range"
    variable ourshort     " expected at least 3 elements for node"
    variable ourimpure    " has irrelevant whitespace"

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::ast 1.1
return

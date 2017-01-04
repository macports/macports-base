# repeat.tcl --
#
#	Emulation of string repeat for older
#	revisions of Tcl.
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2001-2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: repeat.tcl,v 1.1 2006/04/21 04:42:28 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2

namespace eval ::textutil::repeat {}

# ### ### ### ######### ######### #########

namespace eval ::textutil::repeat {
    variable HaveBuiltin [expr {![catch {string repeat a 1}]}]
}

if {0} {
    # Problems with the deactivated code:
    # - Linear in 'num'.
    # - Tests for 'string repeat' in every call!
    #   (Ok, just the variable, still a test every call)
    # - Fails for 'num == 0' because of undefined 'str'.

    proc textutil::repeat::StrRepeat { char num } {
	variable HaveBuiltin
	if { $HaveBuiltin == 0 } then {
	    for { set i 0 } { $i < $num } { incr i } {
		append str $char
	    }
	} else {
	    set str [ string repeat $char $num ]
	}
	return $str
    }
}

if {$::textutil::repeat::HaveBuiltin} {
    proc ::textutil::repeat::strRepeat {char num} {
	return [string repeat $char $num]
    }

    proc ::textutil::repeat::blank {n} {
	return [string repeat " " $n]
    }
} else {
    proc ::textutil::repeat::strRepeat {char num} {
	if {$num <= 0} {
	    # No replication required
	    return ""
	} elseif {$num == 1} {
	    # Quick exit for recursion
	    return $char
	} elseif {$num == 2} {
	    # Another quick exit for recursion
	    return $char$char
	} elseif {0 == ($num % 2)} {
	    # Halving the problem results in O (log n) complexity.
	    set result [strRepeat $char [expr {$num / 2}]]
	    return "$result$result"
	} else {
	    # Uneven length, reduce problem by one
	    return "$char[strRepeat $char [incr num -1]]"
	}
    }

    proc ::textutil::repeat::blank {n} {
	return [strRepeat " " $n]
    }
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::repeat {
    namespace export strRepeat blank
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::repeat 0.7

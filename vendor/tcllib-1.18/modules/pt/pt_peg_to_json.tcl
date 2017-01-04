# peg_to_json.tcl --
#
#	Conversion from PEG to JSON (Java Script Object Notation).
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_json.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes the canonical serialization of a parsing
# expression grammar and produces text in JSON format, Java Script
# data transfer format.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require pt::peg      ; # Verification that the
					       # input is proper.
package require json::write

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::to::json {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::json::reset {} {
    variable indented 0
    variable aligned  0
    variable name     a_pe_grammar
    variable file     unknown
    variable user     unknown
    return
}

proc ::pt::peg::to::json::configure {args} {
    variable indented
    variable aligned
    variable name
    variable file
    variable user

    if {[llength $args] == 0} {
	return [list \
		    -file     $file \
		    -name     $name \
		    -user     $user \
		    -indented $indented \
		    -aligned  $aligned]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists $variable]} {
	    return [set $variable]
	} else {
	    return -code error "Expected one of -aligned, or -indented, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists $variable]} {
		return -code error "Expected one of -aligned, or -indented, got \"$option\""
	    }
	}
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    switch -exact -- $variable {
		indented - aligned {
		    if {![::string is boolean -strict $value]} {
			return -code error "Expected boolean, got \"$value\""
		    }
		}
		name -
		file -
		user { }
	    }
	    set $variable $value
	}
    } else {
	return -code error {wrong#args, expected option value ...}
    }
}

proc ::pt::peg::to::json::convert {serial} {
    variable indented
    variable aligned

    ::pt::peg verify-as-canonical $serial

    json::write indented $indented
    json::write aligned  $aligned

    # Unpack the serialization, known as canonical
    array set peg $serial
    array set peg $peg(pt::grammar::peg)
    unset     peg(pt::grammar::peg)

    # Assemble the rules object
    set rules {}
    foreach {symbol def} $peg(rules) {
	lassign $def _ is _ mode
	lappend rules $symbol \
	    [json::write object \
		 is   [json::write string $is] \
		 mode [json::write string $mode]]
    }

    # Assemble the final result
    return [json::write object pt::grammar::peg \
		[json::write object \
		     rules [json::write object {*}$rules] \
		     start [json::write string $peg(start)]]]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::json {

    # Combinations of the format specific entries
    # I A |
    # - - + ---------------------
    # 0 0 | Ultracompact (no whitespace, single line)
    # 1 0 | Indented
    # 0 1 | Not possible, per the implications above.
    # 1 1 | Indented + Tabular aligned keys
    # - - + ---------------------

    variable indented 0
    variable aligned  0
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::to::json 1
return

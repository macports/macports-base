#----------------------------------------------------------------------
#
# aycock-debug.tcl --
#
#	Procedures needed to debug an Aycock-Horspool-Earley parser.
#
# Copyright (c) 2006 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: aycock-debug.tcl,v 1.2 2011/01/13 02:47:47 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package provide grammar::aycock::debug 1.0
package require Tcl 8.4

# Bring in the runtime library

package require grammar::aycock::runtime 1.0

# grammar::aycock::Terminals --
#
#	List the terminal symbols used in a parser's grammar
#
# Usage:
#	$parser terminals
#
# Results:
#	Returns a list of the terminal symbols

proc ::grammar::aycock::Terminals {parser} {
    namespace upvar $parser RuleSet RuleSet
    set t [dict create]
    dict for {lhs rules} $RuleSet {
	dict for {rhs action} $rules {
	    foreach sym $rhs {
		if {$sym ne "\u22a2"} {
		    if {![dict exists $RuleSet $sym]} {
			dict set t $sym {}
		    }
		}
	    }
	}
    }
    return [lsort -dictionary [dict keys $t]]
}

# grammar::aycock::Nonterminals --
#
#	List the nonterminal symbols used in a parser's grammar
#
# Usage:
#	$parser nonterminals
#
# Results:
#	Returns a list of the nonterminal symbols

proc ::grammar::aycock::Nonterminals {parser} {
    namespace upvar $parser RuleSet RuleSet
    set t [dict create]
    dict for {lhs rules} $RuleSet {
	dict for {rhs action} $rules {
	    foreach sym $rhs {
		if {$sym ne "\u22a2"} {
		    if {[dict exists $RuleSet $sym]} {
			dict set t $sym {}
		    }
		}
	    }
	}
    }
    return [lsort -dictionary [dict keys $t]]
}

# grammar::aycock::NeverReduced --
#
#	Checks a parser's grammar for rules that cannot be reduced.
#
# Parameters:
#	parser -- Name of the parser
#
# Results:
#	Return a list of the left-hand sides of rules never reduced.

proc ::grammar::aycock::NeverReduced {parser} {
    namespace upvar $parser RuleSet RuleSet
    set t [dict create]
    foreach {lhs rules} $RuleSet {
	dict set t $lhs {}
    }
    foreach s [Nonterminals $parser] {
	dict unset t $s
    }
    dict unset t {}
    return [lsort [dict keys $t]]
}

# grammar::aycock::Save --
#
#	Produces a script that will load an Aycock-Earley parser without
#	needing to do all the state analysis.
#
# Usage:
#	$parser save
#
# Results:
#	Returns a script that when evaluated will reload the parser.

proc ::grammar::aycock::Save {parser} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Completions Completions \
	Edges Edges
    set actions [dict create]
    set rex1 {}
    dict for {lhs rules} $RuleSet {
	set rex2 {}
	foreach {rhs action} $rules {
	    dict set actions $action {}
	    append rex2 \n \t [list $rhs $action]
	}
	append rex2 \n "    "
	append rex1 \n "    " [list $lhs $rex2]
    }
    append rex1 \n
    set i 0
    set sex1 {}
    foreach {completions} $Completions {
	set nc 0
	append sex1 \n "    " [list $completions [dict get $Edges $i]]
	incr i
    }
    append sex1 \n
    set retval [list [namespace current]::Restore $rex1 $sex1]
    foreach action [lsort -dictionary [dict keys $actions]] {
	lappend retval $action \
	    [string trimright [info body ${parser}::$action]]\n
    }
    return $retval
}

# grammar::aycock::DumpItemSet --
#
#	Displays a representation of an LRE(0) item set on a channel
#
# Parameters:
#	parser - Name of the parser
#	s - Item set to display
#	chan - Channel to use
#
# Results:
#	None
#
# Side effects:
#	Writes the LRE(0) item set on the given channel

proc ::grammar::aycock::DumpItemSet {parser s {chan stdout}} {
    foreach {lhs prodIndex pos} $s {
	DumpItem $parser $lhs $prodIndex $pos $chan
    }
    return
}

# grammar::aycock::DumpItem --
#
#	Displays a representation of an LRE(0) item on a channel
#
# Parameters:
#	parser - Name of the parser
#	lhs - Left-hand side of the reduction
#	prodIndex - Ordinal position of the right-hand side among
#		    all right-hand sides for that LHS
#	pos - Position of the dot on the right-hand side
#	chan - Channel to use
#
# Results:
#	None
#
# Side effects:
#	Writes the LRE(0) item on the given channel

proc ::grammar::aycock::DumpItem {parser lhs prodIndex pos {chan stdout}} {
    namespace upvar $parser RuleSet RuleSet
    set rhs [lindex [dict get $RuleSet $lhs] $prodIndex]
    puts $chan "        $lhs ::= [linsert $rhs $pos \u00b7]"
    return
}

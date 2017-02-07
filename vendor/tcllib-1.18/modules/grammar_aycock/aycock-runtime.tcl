#----------------------------------------------------------------------
#
# aycock-runtime.tcl --
#
#	Procedures needed to execute an Aycock-Horspool-Earley parser.
#
# Copyright (c) 2006 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: aycock-runtime.tcl,v 1.2 2011/01/13 02:47:47 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package provide grammar::aycock::runtime 1.0
package require Tcl 8.5

# Define the directory containing this package's scripts

namespace eval grammar {}
namespace eval grammar::aycock {
    variable parserCount 0
}

# grammar::aycock::Restore --
#
#	Restores a parser from saved state.
#
# Parameters;
#	rules - Saved rule set
#	automaton - Saved automaton
#	args - Saved action procedures
#
# Results:
#	Returns the constructed parser's name
#
# Side effects:
#	Reconstructs the parser

proc ::grammar::aycock::Restore {rules automaton args} {
    set name [MakeParser]
    variable ${name}::RuleSet
    variable ${name}::Completions
    variable ${name}::Edges
    set RuleSet $rules
    set Edges [dict create]
    set Completions {}
    set i 0
    foreach {completions edges} $automaton {
	lappend Completions $completions
	dict set Edges $i $edges
	incr i
    }
    foreach {actionName actionBody} $args {
	namespace eval ${name} \
	    [list proc $actionName {_ clientData} $actionBody]
    }
    return ${name}
}

# grammar::aycock::MakeParser --
#
#	Constructs the ensemble that will contain an Aycock parser.
#
# Results:
#	Returns the name of the parser, which is an ensemble within
#	the "aycock" namespace.
#
# The following commands are members of the ensemble:
#	parse -- Parses a sequence of symbols and returns its lexical
#		 value.
#	destroy -- Destroys the parser.
#	terminals -- Lists the terminal symbols accepted by the parser
#	nonterminals -- Lists the nonterminal symbols reduced by the parser
#	save -- Returns a command to recreate the parser without needing
#		to analyze the rule set.

proc ::grammar::aycock::MakeParser {} {
    variable parserCount
    set name [namespace current]::parser[incr parserCount]
    namespace eval $name {
	namespace export parse destroy
	namespace export terminals nonterminals save
    }
    proc ${name}::parse {symList vallist {clientData {}}} \
	[string map [list \
			 PROC [namespace current]::Parse \
			 PARSER $name] {
			     PROC PARSER $symList $vallist $clientData
			 }]
    proc ${name}::terminals {} \
	[list [namespace current]::Terminals $name]
    proc ${name}::nonterminals {} \
	[list [namespace current]::Nonterminals $name]
    proc ${name}::save {} \
	[list [namespace current]::Save $name]
    proc ${name}::destroy {} \
	[list namespace delete $name]
    namespace eval $name {
	namespace ensemble create
    }
    return $name
}

# grammar::aycock::MakeSet --
#
#	Run one step of an Earley parse.
#
# Parameters:
#	parser -- Name of the parser
#	setsVar -- Sets of parser states already constructed
#	sym -- Input symbol
#
# Results:
#	Returns the sets of parser states updated with the transition on the
#	given input
#
# Each parser state is an ordered pair (automaton state, parent)
# where parent is the position in the input string where the substring
# matching the given state begins.  A state set is a dictionary whose
# keys are parser states and whose values are "links" - a link consists of
# the automaton state, parent, and state set of the predecessor,
# the automaton state, parent and state set of the cause, and
# the LRE(0) parser state of the symbol being reduced - see Aycock's
# paper for the details on how these are interpreted.

proc ::grammar::aycock::MakeSet {parser setsVar sym} {
    upvar 1 $setsVar sets
    namespace upvar $parser \
	Completions Completions \
	Edges Edges

    # Find the state index and set up "current" and "next" state sets.

    set ip1 [llength $sets]
    set i [expr {$ip1 - 1}]
    set curSet [lindex $sets end]
    set newSet {}

    # Work through the "current" set to determine "next state" transitions.

    set j 0
    set worklist $curSet
    while {$j < [llength $worklist]} {
	set item [lindex $worklist $j]
	incr j 2
	foreach {state parent} $item break

	# Advance using the 'goto' on the current input symbol

	if {$sym ne {} && [dict exists $Edges $state $sym]} {
	    set k [dict get $Edges $state $sym]
	    set createdItem [list $k $parent]
	    set links [list $state $parent $i]
	    dict set newSet $createdItem $links {}

	    # Also add the epsilon-transition from that state

	    if {[dict exists $Edges $k {}]} {
		set nk [dict get $Edges $k {}]
		set createdItem [list $nk [expr {$i+1}]]
		dict set newSet $createdItem {} {}
	    }
	}

	if {$parent != $i} {

	    # Reduce any completions in the current state, adding
	    # them to the worklist because their 'goto' items may
	    # also be shifted.

	    foreach {lhs rhs pos} [lindex $Completions $state] {
		if {$lhs eq {}} continue
		foreach pitem [lindex $sets $parent] {
		    foreach {pstate pparent} $pitem break
		    if {[dict exists $Edges $pstate $lhs]} {

			# goto on the newly-reduced nonterminal

			set k [dict get $Edges $pstate $lhs]
			set createdItem [list $k $pparent]
			set links [list $pstate $pparent $parent \
				       $state $parent $i \
				       $lhs $rhs $pos]
			if {![dict exists $curSet $createdItem]} {
			    lappend worklist $createdItem $links
			}
			dict set curSet $createdItem $links {}
			if {[dict exists $Edges $k {}]} {

			    # epsilon-transition from the nonterminal's goto

			    set nk [dict get $Edges $k {}]
			    set createdItem [list $nk $i]
			    if {![dict exists $curSet $createdItem]} {
				lappend worklist $createdItem {}
			    }
			    dict set curSet $createdItem {} {}
			}
		    }
		}
	    }
	}
    }
    set sets [lreplace $sets[set sets {}] end end $curSet $newSet]
}

# grammar::aycock::Parse --
#
#	Runs an Aycock-Earley parser
#
# Usage:
#	$parser parse symlist vallist
#
# Parameters:
#	symlist - List of token names created by scanning an input
#	vallist - List of semantic values corresponding to the
#		  tokens in $symlist
#	clientData - Client data to be passed to semantic action procedures
#
# Results:
#	Returns whatever the semantic action in the top-level reduction
#	of the parse returns.

proc ::grammar::aycock::Parse {parser symlist vallist {clientData {}}} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Edges Edges
    set sets [list [dict create [list 1 0] {} [list 2 0] {}]]
    set i 0
    foreach sym $symlist {
	MakeSet $parser sets $sym
	if {[llength [lindex $sets end]] == 0} {
	    return -code error "syntax error before symbol $i ($sym: [lindex $vallist $i])"
	}
	incr i
    }
    MakeSet $parser sets {}

    set startSym [lindex [dict get $RuleSet {}] 0 1]
    #set finalState [dict get $Edges 2 $startSym]
    set finalState [dict get $Edges 1 $startSym]
    # TODO - check that the final state *is* final... it has to contain an
    #	     acceptor somewhere.
    return [Reconstruct $parser {} $finalState 0 $vallist $sets \
		[expr {[llength $sets] - 2}] $clientData]

}

# grammar::aycock::Reconstruct --
#
#	Reconstructs the parse that leads to reducing a given nonterminal
#	symbol, and determines the nonterminal's semantic value.
#
# Parameters:
#	parser -- Aycock parser
#	nt - Name of the nonterminal being reduced
#	state - Parser state that contains the reduction
#	parent - Position in the input list of the start of the reduction
#	vallist - List of semantic values corresponding the the symbols
#		  on the right hand side of the reduction
#	sets - List of sets generated by grammar::aycock::MakeSet
#	k - Position in the input list at the start of the reduction
#	clientData - Client data for semantic actions
#
# Results:
#	Returns the semantic value of the left-hand side of the reduction

proc ::grammar::aycock::Reconstruct {parser nt state parent vallist sets k clientData} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Completions Completions \
	Edges Edges
    set choices {}
    # Here it's possible that Completions contains completions for the
    # wrong nonterminal?
    set complete [lindex $Completions $state]
    if {[llength $complete] != 3} {
	set complete {}
	foreach {lhs rhs pos} [lindex $Completions $state] {
	    if {$lhs eq $nt} {
		lappend complete $lhs $rhs $pos
	    }
	}
    }
    set compIdx [ChooseReduction $parser $complete]
    foreach {lhs rhsIndex pos} \
	[lrange $complete [expr {3*$compIdx}] [expr {3*$compIdx+2}]] break
    foreach {rhs action} [lrange [dict get $RuleSet $lhs] $rhsIndex [expr {$rhsIndex+1}]] break
    set cmd [list ${parser}::$action]
    set args {}
    foreach sym $rhs {
	lappend args {}
    }
    for {set i [expr {[llength $rhs]-1}]} {$i >= 0} {incr i -1} {
	set sym [lindex $rhs $i]
	if {![dict exists $RuleSet $sym]} {
	    # terminal symbol
	    if {$sym != "\u22a2"} {
		lset args $i [lindex $vallist [expr {$k-1}]]
		set predecessors {}
		dict for {key v} \
		    [dict get [lindex $sets $k] [list $state $parent]] {
		    foreach {pstate pparent pk cstate cparent ck
			lhs rhsIndex pos} $key break
		    # should be only one transition on a terminal
		    break
		}
		set state $pstate
		set parent $pparent
		set k $pk
	    }
	} elseif {[string range $sym end-2 end] == "\{\u00d8\}"} {
	    lset args $i [DeriveEpsilon $parser $sym $clientData]
	} elseif {[dict exists [lindex $sets $k] [list $state $parent]]} {
	    set causes {}
	    set links [dict get [lindex $sets $k] [list $state $parent]]
	    set keys {}
	    set reductions {}
	    dict for {key v} $links {
		foreach {pstate pparent pk cstate cparent ck \
			 lhs rhsIndex pos} $key break
		lappend reductions $lhs $rhsIndex $pos
		lappend keys $key
	    }
	    set keyIdx [ChooseReduction $parser $reductions]
	    set key [lindex $keys $keyIdx]
		foreach {pstate pparent pk cstate cparent ck \
			 lhs rhsIndex pos} $key break
	    lset args $i \
		[Reconstruct $parser $sym $cstate $cparent $vallist \
		     $sets $ck $clientData]
	    set state $pstate
	    set parent $pparent
	    set k $pk
	} else {
	    return -code error "syntax error: incomplete parse"
	}

    }
    set v [eval [list $cmd $args $clientData]]
    return $v
}

# grammar::aycock::ChooseReduction --
#
#	Resolves an ambiguity in an Aycock-Earley parse
#
# Parameters:
#	parser - Parser structure
#	lritems - List of LR items that could be reduced.
#
# Results:
#	Returns the ordinal number of the reduction to choose
#
# Always resolves in favour of the shortest right-hand side. This choice
# is equivalent to choosing "resolve shift/reduce conflicts in favour
# of shifting" in an LR parser, and is adequate to handling situations
# like "dangling ELSE." It is not adequate for handling things like a
# YACC-style ambiguous expression grammar with precedence and associativity;
# that sort of processing would need additional investigation.

proc ::grammar::aycock::ChooseReduction {parser lritems} {
#     if {[llength $lritems] != 3} {
# 	puts "Need to choose which item to reduce:"
# 	DumpItemSet $parser $lritems
#     }
    # choose the shortest reduction - this is equivalent to
    # "resolve in favour of shift"
    set ind -1
    set shortest 99999
    set i 0
    foreach {lhs rhsIndex pos} $lritems {
	if {$pos < $shortest} {
	    set shortest $pos
	    set ind $i
	}
	incr i
    }
    return $ind
}

# grammar::aycock::DeriveEpsilon --
#
#	Performs a set of semantic actions needed to derive the
#	empty string within a set of reductions in an Aycock-Earley parser.
#
# Parameters:
#	parser -- Parser data structure
#	sym -- Non-terminal symbol that reduces to the empty string.
#	clientData - Client data for semantic actions
#
# Results:
#	Returns the semantic value of the given symbol

proc ::grammar::aycock::DeriveEpsilon {parser sym clientData} {
    # need to find the rule that derives the null string, and
    # expand it out.
    namespace upvar $parser RuleSet RuleSet
    set rules [dict get $RuleSet $sym]
    set idx 0
    if { [llength $rules] != 2 } {
	set items {}
	set i 0
	foreach {rhs action} $rules {
	    lappend items $sym $i [llength $rhs]
	    incr i 2
	}
	set idx [expr {2 * [ChooseReduction $parser $items]}]
    }
    set rhs [lindex $rules $idx]
    set action [lindex $rules [expr {$idx + 1}]]
    set cmd [list ${parser}::$action]
    set args {}
    foreach sym $rhs {
	lappend args {}
    }
    for {set i [expr {[llength $rhs] - 1}]} {$i >= 0} {incr i -1} {
	lset args $i [DeriveEpsilon $parser [lindex $rhs $i] $clientData]
    }
    set r [eval [list $cmd $args $clientData]]
    return $r
    
}

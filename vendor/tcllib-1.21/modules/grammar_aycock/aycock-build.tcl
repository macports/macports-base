#----------------------------------------------------------------------
#
# aycock-build.tcl --
#
#	Procedures needed to compile an Aycock-Horspool-Earley parser.
#
# Copyright (c) 2006 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: aycock-build.tcl,v 1.2 2011/01/13 02:47:47 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package provide grammar::aycock 1.0
package require Tcl 8.4

# Bring in procedures that aid in debugging a parser; they will in turn
# bring in procedures that implement the runtime system.

package require grammar::aycock::debug 1.0

namespace eval grammar::aycock {

    # The 'aycock' namespace exports only the 'parser' command, which
    # constructs a parser.

    namespace export parser

}

# grammar::aycock::parser --
#
#	Creates an Aycock-Earley parser.
#
# Parameters:
#	rules - A list that can be broken down into productions.  
#	dump - The optional flag, '-verbose'. If supplied, the rules
#	       and resulting LRE(0) automaton are dumped to the standard
#	       output.
#
# Results:
#	Returns the name of a parser, which is an ensemble
#	supporting a number of subcommands for processing the
#	language defined by $rules.
#
# Each production takes the form
# 	symbol ::= rhs { action }
# where symbol is a single word defining a nonterminal
# symbol; rhs is the right-hand side (a sequence of nonterminal
# or terminal symbols) and action is a single word giving
# a script to execute when the production is reduced.  Within the
# action, a variable $_ is defined, which is a list of the same
# length as rhs giving the semantic values of each symbol on the
# right-hand side.

proc ::grammar::aycock::parser {rules {dump {}}} {
    set name [MakeParser]
    ProcessRules $name $rules
    ComputeNullable $name
    RewriteGrammar $name
    MakeState0 $name
    MakeState $name 0 \u22a2
    CompleteAutomaton $name
    unset ${name}::Cores
    if {$dump eq {-verbose}} {
	puts "parser: $name"
	puts "Rules:"
	DumpRuleSet $name stdout
	puts "------------------------------------------------------------"
	DumpAutomaton $name stdout
    }
    set l [NeverReduced $name]
    if {[llength $l] != 0} {
	return -code error "Rules never reduced: $l"
    }
    unset ${name}::Items
    return $name
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
	namespace export parse terminals nonterminals save destroy
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

# grammar::aycock::ProcessRules --
#
#	Processes the rule set presented to grammar::aycock::parser
#
# Parameters:
#	parser -- Name of the parser
#	rules -- Rule set
#
# Results:
#	None.
#
# Side effects:
#	RuleSet is set to be a dictionary indexed by nonterminal symbol
#	name, whose values are alternating right-hand sides and names
#	of action procedures.  A set of Action procedures is constructed
#	for the reduction actions.

proc ::grammar::aycock::ProcessRules {parser rules} {
    namespace upvar $parser \
	RuleSet RuleSet \
	ActionProcs ActionProcs \
	APCount APCount

    # Locate the "::=" symbols within the rules.

    set RuleSet [dict create]
    set ActionProcs [dict create]
    set APCount 0
    set positions {}
    set i 0
    foreach sym $rules {
	if {$sym eq {::=}} {
	    lappend positions [expr {$i-1}]
	}
	incr i
    }
    lappend positions [llength $rules]

    # For each rule, place the right-hand side and action into
    # the appropriate RuleSet entry.

    set lastp [lindex $positions 0]
    set top [lindex $rules $lastp]
    foreach p [lrange $positions 1 end] {
	set lhs [lindex $rules $lastp]
	set rhs [lrange $rules [expr {$lastp + 2}] [expr {$p - 2}]]
	set action [MakeAction $parser [lindex $rules [expr {$p - 1}]]]
	set lastp $p
	dict lappend RuleSet $lhs $rhs
	dict lappend RuleSet $lhs $action
    }

    # Make a special "start" rule (whose name is the empty string)
    # whose right-hand side is "right tack" followed by the name of
    # the initial rule.

    dict lappend RuleSet {} [list \u22a2 $top]
    dict lappend RuleSet {} [MakeAction $parser {lindex $_ 1}]

    # Clean up memory.

    unset ${parser}::ActionProcs
    unset ${parser}::APCount
    return
}

# grammar::aycock::MakeAction --
#
#	Defines an action procedure for the parser to use at run time.
#
# Parameters:
#	parser -- Name of the parser
#	body -- Body of the action procedure, which is expected to
#		return the semantic value of some nonterminal after reduction.
#
# Results:
#	Returns the name of the action procedure.
#
# Side effects:
#	Creates the action procedure, which will accept a single parameter,
#	"_", containing the semantic values of the symbols on the right-hand
#	side.

proc ::grammar::aycock::MakeAction {parser {body {lindex $_ 0}}} {
    namespace upvar $parser \
	ActionProcs ActionProcs \
	APCount APCount
    if {$body eq {}} {
	set body {lindex $_ 0}
    }
    if {![dict exists $ActionProcs $body]} {
	set pname Action\#[incr APCount]
	dict set ActionProcs $body $pname
	namespace eval $parser [list proc $pname {_ clientData} $body]
    }
    return [dict get $ActionProcs $body]
}

# grammar::aycock::ComputeNullable --
#
#	Determines which rules in the parser's rule set are nullable, that
#	is, can match the empty sequence of input symbols.
#
# Parameters:
#	parser -- Name of the parser.
#
# Results:
#	None.
#
# Side effects:
#	Sets 'Nullable' to a dictionary whose keys are nonterminal symbol
#	names and whose values are 1 if the symbol is nullable and 0 otherwise.

proc ::grammar::aycock::ComputeNullable {parser} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Nullable Nullable
    set Nullable [dict create]
    set tbd {}
    dict for {lhs rules} $RuleSet {
	dict set Nullable $lhs 0
	foreach {rhs action} $rules {
	    if {[llength $rhs] == 0} {
		dict set Nullable $lhs 1
	    } else {
		set ntonly 1
		foreach sym $rhs {
		    if {![dict exists $RuleSet $sym]} {
			set ntonly 0
			break
		    }
		}
		if {$ntonly} {
		    lappend tbd $lhs $rhs
		}
	    }
	}
    }
    set changed 1
    while {$changed} {
	set changed 0
	foreach {lhs rhs} $tbd {
	    if {![dict get $Nullable $lhs]} {
		set nullable 1
		foreach sym $rhs {
		    if {![dict get $Nullable $sym]} {
			set nullable 0
			break
		    }
		}
		if {$nullable} {
		    dict set Nullable $lhs 1
		    set changed 1
		}
	    }
	}
    }
    return
}

# grammar::aycock::RewriteGrammar --
#
#	Rewrite $parser's grammar into Nihilistic Normal Form {NNF}
#
# Parameters:
#	parser -- Parser to rewrite.
#
# Results:
#	None.
#
# Side effects:
#	Rewrites the rule set to separate nullable rules from other
#	rules.  The nullable rules are distinguished by having
#	"{\u00d8}" appended to their names.

proc ::grammar::aycock::RewriteGrammar {parser} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Nullable Nullable
    set newRuleSet [dict create]

    # Create a work list wth all rules not yet examined

    set worklist {}
    dict for {lhs rules} $RuleSet {
	foreach {rhs action} $rules {
	    lappend worklist $lhs $rhs 0 1 $action
	}
    }

    # Process the rules in sequence from the worklist. For each rule,
    # determine whether it contains a sequence of nullable symbols
    # on the right-hand side.  If it does, split it on the last nullable
    # symbol. Continue until all possible splits have been done.

    for {set k 0} {$k < [llength $worklist]} {incr k 5} {
	foreach {lhs rhs position candidateFlag action} \
	    [lrange $worklist $k [expr {$k+4}]] break
	set n [llength $rhs]
	while {$position < $n} {
	    set sym [lindex $rhs $position]
	    if {![dict exists $Nullable $sym]
		|| ![dict get $Nullable $sym]} {
		set candidateFlag 0
	    } else {
		set newrhs $rhs
		lset newrhs $position ${sym}\{\u00d8\}
		lappend worklist $lhs $newrhs [expr {$position+1}] \
		    $candidateFlag $action
		set candidateFlag 0
	    }
	    incr position
	}
	if {$position >= $n} {
	    if {$candidateFlag} {
		set lhs ${lhs}\{\u00d8\}
	    }
	    dict lappend newRuleSet $lhs $rhs
	    dict lappend newRuleSet $lhs $action
	}
    }
    set RuleSet $newRuleSet
    unset Nullable
    return
}

# grammar::aycock::DumpRuleSet --
#
#	Displays the set of rules in a parser.
#
# Parameters:
#	parser - Name of the parser
#	chan - Channel on which to display the rules
#
# Results:
#	None.
#
# Side effects:
#	Displays the rule set on the given channel.

proc ::grammar::aycock::DumpRuleSet {parser chan} {
    namespace upvar $parser RuleSet RuleSet
    dict for {lhs rules} $RuleSet {
	dict for {rhs action} $rules {
	    puts $chan "$lhs ::= $rhs [list [info body ${parser}::${action}]]"
	}
    }
    return
}

# grammar::aycock::MakeState0 --
#
#	Makes the first state of a parser's automaton.
#
# Parameters:
#	parser -- Parser under construction.
#
# Results:
#	None.
#
# Side effects:
#	Builds a state corresponding to the reduction of the start
#	symbol.  Creates "Completions", "Items", "Cores", and "Edges";
#	Completions will be a list of lists of right-hand-sides
#	completed in each state.
#	Items will be a list of LRE(0) items belonging to
#	the states. Each item is represented as three elements:
#	the nonterminal symbol, the rule number in that nonterminal's
#	rule list, and the position of the dot within the right-hand side.
#	Edges will be a two-level dictionary - the outer key is state
#	number and the inner key is a symbol - giving the 'goto' symbol
#	for a given state and symbol.
#	Cores is a work dictionary used to avoid state duplication.

proc ::grammar::aycock::MakeState0 {parser} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Completions Completions \
	Items Items \
	Cores Cores \
	Edges Edges
    set items {}
    set i 0
    foreach {rhs action} [dict get $RuleSet {}] {
	lappend items {} $i 0
	incr i 2
    }
    set Completions [list {}]
    set Items [list $items]
    set Cores [dict create]
    set Edges [dict create]
    return
}

# grammar::aycock::MakeState --
#
#	Constructs a state of the parsing automaton.
#
# Parameters:
#	parser -- Parser under construction
#	stateIdx - Ordinal number of a state being examined.
#	sym - Symbol whose goto is being computed
#
# Results:
#	Returns goto(state,sym)
#
# Side effects:
#	Constructs a new state if necessary, updating Completions, Items
#	Cores and Edges to reflect it.

proc ::grammar::aycock::MakeState {parser stateIdx sym} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Completions Completions \
	Items Items \
	Cores Cores \
	Edges Edges

    if {$sym == {}} {
	error "Null symbol in MakeState"
    }

    set complete [lindex $Completions $stateIdx]

    # Compute the epsilon-kernel items for the given transition.

    set Kitems {}
    set items [lindex $Items $stateIdx]
    foreach {lhs prodIndex pos} $items {
	set rhs [lindex [dict get $RuleSet $lhs] $prodIndex]
	if {[lindex $rhs $pos] == $sym} {
	    set nextPos [SkipOver $rhs [expr {$pos+1}]]
	    lappend Kitems [list $lhs $prodIndex $nextPos]
	}
    }

    # Determine whether we've already built the state.

    set core {}
    foreach tuple \
	[lsort -index 0 \
	     [lsort -integer -index 1 \
		  [lsort -integer -index 2 $Kitems]]] {
		      foreach {lhs prodIndex pos} $tuple break
		      lappend core $lhs $prodIndex $pos
		  }

    if {[dict exists $Cores $core]} {
	return [dict get $Cores $core]
    }

    # We haven't built it yet - so we need to build it now.  Let k and
    # nk be the state numbers for the epsilon-kernel and epsilon-non-kernel
    # states.

    set k [llength $Items]
    set nk [expr {$k + 1}]

    set Kitems $core
    set NKitems {}

    set Kedges [dict create]
    set predicted [dict create]
    set Kcomplete {}

    # enumerate all the LRE(0) items in the epsilon-kernel set

    foreach {lhs rhsIndex pos} $Kitems {
	set rhs [lindex [dict get $RuleSet $lhs] $rhsIndex]
	if {$pos == [llength $rhs]} {
	    # reduction
	    lappend Kcomplete $lhs $rhsIndex $pos
	    continue
	} elseif {![dict exists $RuleSet [set nextSym [lindex $rhs $pos]]]} {
	    # transition on a terminal symbol
	    if {![dict exists $Kedges $nextSym] } {
		dict set Kedges $nextSym {}
	    }
	} else {
	    # GOTO on a nonterminal
	    dict set Kedges $nextSym {}
	    if {![dict exists $predicted $nextSym]} {
		dict set predicted $nextSym 1
		set prhsIndex 0
		foreach {prhs paction} [dict get $RuleSet $nextSym] {
		    set ppos [SkipOver $prhs]
		    lappend NKitems $nextSym $prhsIndex $ppos
		    incr prhsIndex 2
		}
	    }
	}
    }

    # build the state for the epsilon-kernel

    lappend Completions $Kcomplete
    lappend Items $Kitems
    dict set Edges $stateIdx $sym $k
    dict set Edges $k $Kedges

    if {[llength $NKitems] == 0} {
	return $k
    }

    # now start with the non-kernel set.  We need to build it before
    # we can figure out whether we've built it already

    set NKcomplete {}

    # enumerate all the LRE(0) items in the non-kernel set

    set NKedges [dict create]
    set w 0
    while {$w < [llength $NKitems] } {
	foreach {lhs rhsIndex pos} [lrange $NKitems $w [expr {$w+2}]] break
	incr w 3
	set rhs [lindex [dict get $RuleSet $lhs] $rhsIndex]
	if {$pos == [llength $rhs]} {
	    # reduction
	    lappend NKComplete [list $lhs $rhsIndex $pos]
	    continue
	}
	set nextSym [lindex $rhs $pos]
	if {![dict exists $RuleSet $nextSym]} {
	    # transition on a terminal symbol
	    if {![dict exists $NKedges $nextSym]} {
		dict set NKedges $nextSym {}
	    }
	} else {
	    # GOTO on a nonterminal
	    dict set NKedges $nextSym {}
	    if {![dict exists $predicted $nextSym]} {
		dict set predicted $nextSym 1
		set prhsIndex 0
		dict for {prhs paction} [dict get $RuleSet $nextSym] {
		    set ppos [SkipOver $prhs]
		    lappend NKitems $nextSym $prhsIndex $ppos
		    incr prhsIndex 2
		}
	    }
	}
    }

    # Now we might be able to add NKedges, and NK, or maybe we don't need to.

    set core [lsort [dict keys $predicted]]
    if {[dict exists $Cores $core]} {
	dict set Edges $k {} [dict get $Cores $core]
    } else {
	dict set Cores $core $nk
	dict set Edges $k {} $nk
	lappend Completions $NKcomplete
	lappend Items $NKitems
	dict set Edges $nk $NKedges
    }

    # Return the new kernel state's number.

    return $k
    
}

# grammar::aycock::SkipOver --
#
#	Service procedure that skips over nullable symbols beginning at
#	a given position on a right-hand side.
#
# Parameters:
#	rhs - Right-hand side being analyzed
#	pos - Starting position within the rhs
#
# Results:
#	Returns the index of the first non-nullable symbol after $pos,
#	which will be the fictitious symbol beyond the end of the right-hand
#	side if no non-nullable symbols remain.

proc ::grammar::aycock::SkipOver {rhs {pos 0}} {
    set n [llength $rhs]
    while {$pos < $n} {
	if {[string range [lindex $rhs $pos] end-2 end] ne "\{\u00d8\}"} {
	    break
	}
	incr pos
    }
    return $pos
}

# grammar::aycock::CopmpleteAutomaton --
#
#	Completes building the parser automaton once the first state
#	has been constructed.
#
# Parameters:
#	parser -- Name of the parser.
#
# Results:
#	None.
#
# Works by a brute-force approach: for each state, for each symbol
# that the state can transition on, add goto(state,symbol) to the
# state set; iterate until convergence.

proc ::grammar::aycock::CompleteAutomaton {parser} {
    namespace upvar $parser \
	RuleSet RuleSet \
	Items Items \
	Edges Edges
    
    set changes 1
    while {$changes} {
	set changes 0
	set worklist {}
	dict for {state d} [dict get $Edges] {
	    dict for {sym v} $d {
		if {$v eq {}} {
 		    if {$state < [llength $Items]} {
 			lappend worklist \
 			    [list $state [dict exists $RuleSet $sym] $sym]
 			set changes 1
 		    }
		}
	    }
	}
	foreach tuple \
	    [lsort -integer -index 0 \
		 [lsort -integer -index 1 \
		      [lsort -dictionary -index 2 $worklist]]] {
		foreach {state - sym} $tuple break
		::grammar::aycock::GoTo $parser $state $sym
	    }
    }
}

# grammar::aycock::GoTo --
#
#	Computes goto(state,symbol) in a parser.
#
# Parameters:
#	parser -- Name of the parser
#	state -- Index of the state
#	sym -- Symbol whose goto is being computed.
#
# Results:
#	Returns the goto entry.
#
# Side effects:
#	Constructs a new state if needed.

proc ::grammar::aycock::GoTo {parser state sym} {
    namespace upvar $parser Edges Edges
    if {![dict exists $Edges $state] || ![dict exists $Edges $state $sym]} {
	return {}
    } else {
	set rv [dict get $Edges $state $sym]
	if {$rv eq {}} {
	    set rv [MakeState $parser $state $sym]
	    dict set Edges $state $sym $rv
	}
    }
    return $rv
}

# grammar::aycock::DumpAutomaton --
#
#	Displays the parsing automaton of an Aycock-Earley parser on a
#	channel.
#
# Parameters:
#	parser - Parser to display
#	chan - Channel to use
#
# Results:
#	None.
#
# Side effects:
#	Dumps the grammar (in NNF) and the states of the parsing
#	automaton.  For each state, indicates the LRE(0) items in that
#	state, the completion list for the state, and the GOTO function
#	for the state.
    
proc ::grammar::aycock::DumpAutomaton {parser chan} {
    namespace upvar $parser \
	Completions Completions \
	Items Items \
	Edges Edges
    for {set ns 0} {$ns < [llength $Completions]} {incr ns} {
	set completions [lindex $Completions $ns]
	puts $chan "state $ns:"
	if {[info exists Items]} {
	    set items [lindex $Items $ns]
	    DumpItemSet $parser $items $chan
	    puts $chan "  ------------------------------"
	}
	puts $chan "  completions:"
	DumpItemSet $parser $completions $chan
	puts $chan "  ------------------------------"
	puts $chan "  goto:"
	set worklist {}
	dict for {sym nexts} [dict get $Edges $ns] {
	    if {$sym eq {}} {
		set sym \u03b5
	    }
	    lappend worklist [list $sym $nexts]
	}
	foreach pair [lsort -integer -index 1 $worklist] {
	    foreach {sym nexts} $pair break
	    puts $chan [format "    %-22s%4d" $sym $nexts]
	}
	puts $chan "------------------------------------"
    }
}

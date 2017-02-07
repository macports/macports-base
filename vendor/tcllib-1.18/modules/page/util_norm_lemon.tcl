# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Transformation - Normalize PEG AST for later.

# This package assumes to be used from within a PAGE plugin. It uses
# the API commands listed below. These are identical across the major
# types of PAGE plugins, allowing this package to be used in reader,
# transform, and writer plugins. It cannot be used in a configuration
# plugin, and this makes no sense either.
#
# To ensure that our assumption is ok we require the relevant pseudo
# package setup by the PAGE plugin management code.
#
# -----------------+--
# page_info        | Reporting to the user.
# page_warning     |
# page_error       |
# -----------------+--
# page_log_error   | Reporting of internals.
# page_log_warning |
# page_log_info    |
# -----------------+--

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: page::plugin

package require page::plugin ; # S.a. pseudo-package.
package require treeql
package require page::util::quote
package require page::util::peg

namespace eval ::page::util::norm::lemon {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl)

    namespace import ::page::util::quote::*
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::util::norm::lemon {t} {
    set q [treeql q -tree $t]

    page_info {[Lemon Normalization]}

    # Retrieve grammar name out of one directive.
    # Or from LHS of first rule.

    page_log_info ..Startsymbol

    set start {}

    $q query tree \
	    withatt type nonterminal \
	    withatt detail StartSymbol \
	    descendants \
	    withatt type terminal \
	    over n {

	lemon::TokReduce $t $n detail
	set start [$t get $n detail]

	page_info "  StartSymbol: $start"
    }

    $q query tree \
	    withatt type   nonterminal \
	    withatt detail Name \
	    descendants \
	    withatt type terminal \
	    over n {

	lemon::TokReduce $t $n detail
	set name [$t get $n detail]

	page_info "  Name:        $name"

	$t set root name $name
    }

    page_log_info ..Drop        ; lemon::Drop        $q $t
    page_log_info ..Terminals   ; lemon::Terminals   $q $t
    page_log_info ..Definitions ; lemon::Definitions $q $t
    page_log_info ..Rules       ; lemon::Rules       $q $t start
    page_log_info ..Epsilon     ; lemon::ElimEpsilon $q $t
    page_log_info ..Autoclass   ; lemon::AutoClassId $q $t
    page_log_info ..Chains

    # Find and cut operator chains, very restricted. Cut only chains
    # of x- and /-operators. The other operators have only one child
    # by definition and are thus not chains.

    #set q [treeql q -tree $t]
    # q query tree over n
    foreach n [$t children -all root] {
	if {[$t keyexists $n symbol]}        continue
	if {[llength [$t children $n]] != 1} continue

	set op [$t get $n op]
	if {($op ne "/") && ($op ne "x")} continue
	$t cut $n
    }

    page_log_info ..Flatten

    lemon::flatten $q $t

    # Analysis: Left recursion, and where.
    # Manual: Definitions for terminals.
    #         Definitions for space, comments.
    #         Integration of this into the grammar.

    # Sentinel for PE algorithms.
    $t set root symbol <StartExpression>

    if {$start eq ""} {
	page_error "  Startsymbol missing"
    } else {
	set s [$t insert root end]
	$t set $s op  n
	$t set $s sym $start
	$t set root start $s

	array set def [$t get root definitions]

	if {![info exists def($start)]} {
	    page_error "  Startsymbol is undefined"
	    $t set $s def ""
	} else {
	    $t set $s def $def($start)
	}
	unset def
    }

    $q destroy

    page_log_info Ok
    return
}

# ### ### ### ######### ######### #########
## Documentation
#
## See doc_normalize.txt for the specification of the publicly visible
## attributes.
##
## Internal attributes
## - DATA - Transient storage for terminal data.

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::util::norm::lemon::Drop {q t} {
    # Simple normalization.
    # All lemon specific data is dropped completely.

    foreach drop {
	Directive Codeblock Label Precedence
    } {
	$q query tree withatt type nonterminal \
	    withatt detail $drop over n {
		$t delete $n
	    }
    }

    # Some nodes can be dropped, but not their children.

    $q query tree withatt type nonterminal \
	withatt detail Statement over n {
	    $t cut $n
	}

    # Cut the ALL and LemonGrammar nodes, direct access, no search
    # needed.

    $t cut [lindex [$t children root] 0]
    $t cut [lindex [$t children root] 0]

    return
}

proc ::page::util::norm::lemon::Terminals {q t} {
    # The data for all terminals is stored in their grandparental
    # nodes. We get rid of both terminals and their parents.

    $q query tree withatt type terminal over n {
	set p  [$t parent $n]
	set gp [$t parent $p]

	CopyLocation $t $n $gp
	AttrCopy     $t $n detail $gp DATA
	TokReduce    $t           $gp DATA
	$t delete $p
    }

    # We can now drop the type attribute, as all the remaining nodes
    # (which have it) will contain the value 'nonterminal'.

    $q query tree hasatt type over n {
	$t unset $n type
    }
    return
}

proc ::page::util::norm::lemon::Definitions {q t} {
    # Convert 'Definition' into the sequences they are.
    # Sequences of length one will be flattened later.
    # Empty sequences (Length zero) are epsilon.
    # Epsilon will be later converted to ? of the
    # whole choice they are part of.

    $q query tree withatt detail Definition over n {
	$t unset $n detail

	if {[$t children $n] < 1} {
	    $t set $n op epsilon
	} else {
	    $t set $n op x
	}
    }
    return
}

proc ::page::util::norm::lemon::Rules {q t sv} {
    upvar $sv start
    # We move nonterminal hint information from nodes into attributes,
    # and delete the now irrelevant nodes.

    # Like with the global metadata we move definition specific
    # information out of nodes into attributes, get rid of the
    # superfluous nodes, and tag the definition roots with marker
    # attributes.

    array set defs {}
    $q query tree withatt detail Rule over n {
	set first [Child $t $n 0]

	set sym   [$t get $first DATA]
	$t set $n symbol $sym
	$t set $n label  $sym
	$t set $n users  {}
	$t set $n mode value

	if {$start eq ""} {
	    page_info "  StartSymbol: $sym"
	    set start $sym
	}

	# We get the left extend of the definition from the terminal
	# for the symbol it defines.

	MergeLocations $t $first [Rightmost $t $n] $n
	$t unset $n detail

	lappend defs($sym) $n
	$t cut $first
    }

    set d {}
    foreach sym [array names defs] {
	set nodes $defs($sym)
	if {[llength $nodes] == 1} {
	    lappend d $sym [lindex $nodes 0]
	} else {
	    # Merge multi-node definition together, under a choice.

	    set r [$t insert root end]
	    set c [$t insert $r end]

	    $t set $r symbol $sym
	    $t set $r label  $sym
	    $t set $r users  {}
	    $t set $r mode value
	    $t set $c op     /

	    foreach n $nodes {
		set seq [lindex [$t children $n] 0]
		$t move $c end $seq
		$t delete $n
	    }

	    lappend d $sym $r
	}
    }

    # We remember a mapping from nonterminal names to their defining
    # nodes in the root as well, for quick reference later, when we
    # build nonterminal usage references

    $t set root definitions $d
    return
}

proc ::page::util::norm::lemon::Rightmost {t n} {
    # Determine the rightmost leaf under the specified node.

    if {[$t isleaf $n]} {return $n}
    return [Rightmost $t [lindex [$t children $n] end]]
}

proc ::page::util::norm::lemon::ElimEpsilon {q t} {
    # We convert choices with an epsilon in them into
    # optional choices without an epsilon branch.

    $q query tree withatt op epsilon over n {
	set choice [$t parent $n]

	# Move branches into the epsilon, which becomes the new
	# choice. And the choice becomes an option.
	foreach c [$t children $choice] {
	    if {$c eq $n} continue
	    $t move $n end $c
	}
	$t set $n      op /
	$t set $choice op ?
    }
    return
}

proc ::page::util::norm::lemon::AutoClassId {q t} {

    array set defs [$t get root definitions]
    array set use {}

    $q query tree \
	    withatt op x \
	    children \
	    hasatt DATA \
	    over n {
	# All identifiers are nonterminals, and for the
	# undefined ones we create rules which define
	# them as terminal sequences.

	set sym  [$t get $n DATA]
	$t unset $n DATA

	$t set $n op  n
	$t set $n sym $sym

	if {![info exists defs($sym)]} {
	    set defs($sym) [NewTerminal $t $sym]
	}
	$t set $n def $defs($sym)

	lappend use($sym) $n
	$t unset $n detail
    }

    $t set root definitions [array get defs]

    foreach sym [array names use] {
	$t set $defs($sym) users $use($sym)
    }

    $t set root undefined {}
    return
}

proc ::page::util::norm::lemon::NewTerminal {t sym} {
    page_log_info "  Terminal: $sym"

    set     r [$t insert root end]
    $t set $r symbol $sym
    $t set $r label  $sym
    $t set $r users  {}
    $t set $r mode   leaf

    set     s [$t insert $r end]
    $t set $s op x

    foreach ch [split $sym {}] {
	set c [$t insert $s end]
	$t set $c op   t
	$t set $c char $ch
    }
    return $r
}

# ### ### ### ######### ######### #########
## Internal. Low-level helpers.

proc ::page::util::norm::lemon::CopyLocation {t src dst} {
    $t set $dst range    [$t get $src range]
    $t set $dst range_lc [$t get $src range_lc]
    return
}

proc ::page::util::norm::lemon::MergeLocations {t srca srcb dst} {
    set ar   [$t get $srca range]
    set arlc [$t get $srca range_lc]

    set br   [$t get $srcb range]
    set brlc [$t get $srcb range_lc]

    $t set $dst range    [list [lindex $ar   0] [lindex $br   1]]
    $t set $dst range_lc [list [lindex $arlc 0] [lindex $brlc 1]]
    return
}

proc ::page::util::norm::lemon::AttrCopy {t src asrc dst adst} {
    $t set $dst $adst [$t get $src $asrc]
    return
}

proc ::page::util::norm::lemon::Child {t n index} {
    return [lindex [$t children $n] $index]
}

proc ::page::util::norm::lemon::TokReduce {t src attr} {
    set tokens [$t get $src $attr]
    set ch     {}
    foreach tok $tokens {
	lappend ch [lindex $tok 0]
    }
    $t set $src $attr [join $ch {}]
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide page::util::norm::lemon 0.1

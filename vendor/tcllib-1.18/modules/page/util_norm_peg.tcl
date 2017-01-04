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

namespace eval ::page::util::norm::peg {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl)

    namespace import ::page::util::quote::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::util::norm::peg {t} {
    set q [treeql q -tree $t]

    page_info {[PEG Normalization]}
    page_log_info ..Terminals   ; peg::Terminals   $q $t
    page_log_info ..Chains      ; peg::CutChains   $q $t
    page_log_info ..Metadata    ; peg::Metadata    $q $t
    page_log_info ..Definitions ; peg::Definitions $q $t
    page_log_info ..Expressions ; peg::Expressions $q $t

    # Sentinel for PE algorithms.
    $t set root symbol <StartExpression>
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

proc ::page::util::norm::peg::Terminals {q t} {
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

proc ::page::util::norm::peg::CutChains {q t} {
    # All nodes which have exactly one child are irrelevant. We get
    # rid of them. The root node is the sole exception. The immediate
    # child of the root however is superfluous as well.

    $q query tree notq {root} over n {
	if {[llength [$t children $n]] != 1} continue
	$t cut $n
    }

    foreach n [$t children root] {$t cut $n}
    return
}

proc ::page::util::norm::peg::Metadata {q t} {
    # Having the name of the grammar in a tree node is overkill. We
    # move this information into an attribute of the root node.
    # The node keeping the start expression separate is irrelevant as
    # well. We get rid of it, and tag the root of the start expression
    # with a marker attribute.

    $q query tree withatt detail Header over n {
	set tmp    [Child $t $n 0]
	set sexpr  [Child $t $n 1]

	AttrCopy $t $tmp DATA root name
	$t cut $tmp
	$t cut $n
	break
    }

    # Remember the node for the start expression in the root for quick
    # access by later stages.

    $t set root start $sexpr
    return
}

proc ::page::util::norm::peg::Definitions {q t} {
    # We move nonterminal hint information from nodes into attributes,
    # and delete the now irrelevant nodes.

    # NOTE: This transformation is dependent on the removal of all
    # nodes with exactly one child, as it removes the all 'Attribute'
    # nodes already. Otherwise this transformation would have to put
    # the information into the grandparental node.

    # The default mode for nonterminals is 'value'.

    $q query tree withatt detail Definition over n {
	$t set $n mode value
    }

    foreach {a mode} {
	VOID  discard
	MATCH match
	LEAF  leaf
    } {
	$q query tree withatt detail $a over n {
	    set p [$t parent $n]
	    $t set $p mode $mode
	    $t delete $n
	}
    }

    # Like with the global metadata we move definition specific
    # information out of nodes into attributes, get rid of the
    # superfluous nodes, and tag the definition roots with marker
    # attributes.

    set defs {}
    $q query tree withatt detail Definition over n {
	# Define mode information for all nonterminals without an
	# explicit specification. We also save the mode information
	# from deletion when we redo the definition node.

	set first [Child $t $n 0]

	set sym [$t get $first DATA]
	$t set $n symbol $sym
	$t set $n label  $sym
	$t set $n users  {}

	# Now determine the range in the input covered by the
	# definition. The left extent comes from the terminal for the
	# nonterminal symbol it defines. The right extent comes from
	# the rightmost child under the definition. While this not an
	# expression tree yet the location data is sound already.

	MergeLocations $t $first [Rightmost $t $n] $n
	$t unset $n detail

	lappend defs $sym $n
	$t cut $first
    }

    # We remember a mapping from nonterminal names to their defining
    # nodes in the root as well, for quick reference later, when we
    # build nonterminal usage references

    $t set root definitions $defs
    return
}

proc ::page::util::norm::peg::Rightmost {t n} {
    # Determine the rightmost leaf under the specified node.

    if {[$t isleaf $n]} {return $n}
    return [Rightmost $t [lindex [$t children $n] end]]
}

proc ::page::util::norm::peg::Expressions {q t} {
    # We now transform the remaining nodes into proper expression
    # trees. The order matters, to shed as much nodes as possible
    # early, and to avoid unncessary work.

    ExprRanges       $q $t
    ExprUnaryOps     $q $t
    ExprChars        $q $t
    ExprNonterminals $q $t
    ExprOperators    $q $t
    ExprFlatten      $q $t
    return
}

proc ::page::util::norm::peg::ExprRanges {q t} {
    # Ranges = .. operator

    $q query tree withatt detail Range over n {
	# Two the children, both of text 'Char', their data is what we
	# take. The children become irrelevant and are removed.

	foreach {b e} [$t children $n] break
	set begin [unquote [$t get $b DATA]]
	set end   [unquote [$t get $e DATA]]

	$t set $n op ..
	$t set $n begin $begin
	$t set $n end   $end

	MergeLocations $t $b $e $n

	$t unset $n detail

	$t delete $b
	$t delete $e
    }
    return
}

proc ::page::util::norm::peg::ExprUnaryOps {q t} {
    # Unary operators ... Their transformation sheds more nodes.

    foreach {a op} {
	QUESTION ?
	STAR     *
	PLUS     +
	AND      &
	NOT      !
    } {
	$q query tree withatt detail $a over n {
	    set p [$t parent $n]

	    $t set $p op $op
	    $t cut $n

	    $t unset $p detail
	}
    }
    return
}

proc ::page::util::norm::peg::ExprChars {q t} {
    # Chars = t operator (The remaining Char'acters are plain terminal
    # symbols.

    $q query tree withatt detail Char over n {
	set ch [unquote [$t get $n DATA]]

	$t set $n op   t
	$t set $n char $ch

	$t unset $n detail
	$t unset $n DATA
    }
    return
}

proc ::page::util::norm::peg::ExprNonterminals {q t} {
    # Identifiers = n operator (nonterminal references) ...

    array set defs [$t get root definitions]
    array set undefined {}

    $q query tree withatt detail Identifier over n {
	set sym [$t get $n DATA]

	$t set $n op  n
	$t set $n sym $sym

	$t unset $n detail
	$t unset $n DATA

	# Create x-references between the users and the definition of
	# a nonterminal symbol.

	if {![info exists defs($sym)]} {
	    $t set $n def {}
	    lappend undefined($sym) $n
	    continue
	} else {
	    set def $defs($sym)
	    $t set $n def $def
	}

	set users [$t get $def users]
	lappend users $n
	$t set $def users $users
    }

    $t set root undefined [array get undefined]
    return
}

proc ::page::util::norm::peg::ExprOperators {q t} {
    # The remaining operator nodes can be changed directly from node
    # text to operator. Se we do.

    foreach {a op} {
	EPSILON    epsilon
	ALNUM      alnum
	ALPHA      alpha
	DOT        dot
	Literal    x
	Class      /
	Sequence   x
	Expression /
    } {
	$q query tree withatt detail $a over n {
	    $t set   $n op $op
	    $t unset $n detail
	}
    }
    return
}

proc ::page::util::norm::peg::ExprFlatten {q t} {
    # Last tweaks of the expressions. Classes inside of Expressions,
    # and Literals in Sequences create nested / or x expressions. We
    # locate such and flatten the nested expression, cutting out the
    # superfluous operator.

    foreach op {x /} {
	# Locate all x operators, whose parents are x operators as
	# well, then go back to the child operators and cut them out.

	$q query tree withatt op $op \
		parent unique withatt op $op \
		children withatt op $op \
		over n {
	    $t cut $n
	}

	# Locate all x operators without children and convert them
	# into epsilon operators. Because that is what they accept,
	# nothing.

	$q query tree withatt op $op over n {
	    if {[$t numchildren $n]} continue
	    $t set $n op epsilon
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Internal. Low-level helpers.

proc ::page::util::norm::peg::CopyLocation {t src dst} {
    $t set $dst range    [$t get $src range]
    $t set $dst range_lc [$t get $src range_lc]
    return
}

proc ::page::util::norm::peg::MergeLocations {t srca srcb dst} {
    set ar   [$t get $srca range]
    set arlc [$t get $srca range_lc]

    set br   [$t get $srcb range]
    set brlc [$t get $srcb range_lc]

    $t set $dst range    [list [lindex $ar   0] [lindex $br   1]]
    $t set $dst range_lc [list [lindex $arlc 0] [lindex $brlc 1]]
    return
}

proc ::page::util::norm::peg::TokReduce {t src attr} {
    set tokens [$t get $src $attr]
    set ch     {}
    foreach tok $tokens {
	lappend ch [lindex $tok 0]
    }
    $t set $src $attr [join $ch {}]
    return
}

proc ::page::util::norm::peg::AttrCopy {t src asrc dst adst} {
    $t set $dst $adst [$t get $src $asrc]
    return
}

proc ::page::util::norm::peg::Child {t n index} {
    return [lindex [$t children $n] $index]
}

# ### ### ### ######### ######### #########
## Ready

package provide page::util::norm::peg 0.1

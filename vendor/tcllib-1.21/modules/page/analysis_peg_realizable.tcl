# -*- tcl -*-
# ### ### ### ######### ######### #########

# Perform realizability analysis (x) on the PE grammar delivered by
# the frontend. The grammar is in normalized form (reduced to
# essentials, graph like node-x-references, expression trees).
#
# (x) = See "doc_realizable.txt".

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

package require page::plugin     ; # S.a. pseudo-package.
package require page::util::flow ; # Dataflow walking.
package require page::util::peg  ; # General utilities.
package require treeql

namespace eval ::page::analysis::peg::realizable {
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::analysis::peg::realizable::compute {t} {

    # Ignore call if already done before

    if {[$t keyexists root page::analysis::peg::realizable]} return

    # We compute the set of realizable nonterminal symbols by doing the
    # computation for all partial PE's in the grammar. We start at the
    # leaves and then iteratively propagate the property as far as
    # possible using the rules defining it, see the specification.

    # --- --- --- --------- --------- ---------

    # Initialize all nodes and the local arrays. Everything is not
    # realizable, except for the terminal leafs of the tree. Their parents
    # are scheduled to be visited as well.

    array set realizable   {} ; # Place where realizable nodes are held
    array set unrealizable {} ; # Place where unrealizable nodes are held
    array set nc           {} ; # Per node, number of children.
    array set uc           {} ; # Per node, number of realizable children.

    set nodeset [$t leaves]

    set q [treeql q -tree $t]
    $q query tree withatt op * over n {lappend nodeset $n}
    $q query tree withatt op ? over n {lappend nodeset $n}
    q destroy

    foreach n [$t nodes] {
	set unrealizable($n) .
	set nc($n)       [$t numchildren $n]
	set uc($n)       0
    }

    # A node is visited if it _may_ have changed its status (to
    # realizability).

    page::util::flow $nodeset flow n {
	# Realizable nodes cannot change, ignore them.

	if {[info exists realizable($n)]} continue

	# Determine new state of realizability, ignore a node if it is
	# unchanged.

	if {![Realizable $t $n nc uc realizable]} continue

	# Reclassify changed node, it is now realizable.
	unset unrealizable($n)
	set   realizable($n) .

	# Schedule visits to nodes which may have been affected by
	# this change. Update the relevant counters as well.

	# @ root       - none
	# @ definition - users of the definition
	# otherwise    - parent of operator.

	if {$n eq "root"} continue

	if {[$t keyexists $n symbol]} {
	    set users [$t get $n users]
	    $flow visitl $users
	    foreach u $users {
		incr uc($u)
	    }
	    continue
	}

	set p [$t parent $n]
	incr uc($p)
	$flow visit $p
    }

    # Set marker preventing future calls.
    $t set root page::analysis::peg::realizable   [array names realizable]
    $t set root page::analysis::peg::unrealizable [array names unrealizable]
    return
}

proc ::page::analysis::peg::realizable::remove! {t} {
    # Determine which parts of the grammar are realizable

    compute $t

    # Remove anything which is not realizable (and all their children),
    # except for the root itself, should it be unrealizablel.

    set unreal [$t get root page::analysis::peg::unrealizable]
    foreach n [lsort $unreal] {
	if {$n eq "root"} continue
	if {[$t exists $n]} {
	    $t delete $n
	}
    }

    # Notify the user of the definitions which were among the removed
    # nodes. Keep only the still-existing definitions.

    set res {}
    foreach {sym def} [$t get root definitions] {
	if {![$t exists $def]} {
	    page_warning "  $sym: Nonterminal symbol is not realizable, removed."
	} else {
	    lappend res $sym $def
	}
    }
    $t set root definitions $res

    if {![$t exists [$t get root start]]} {
	page_warning "  <Start expression>: Is not realizable, removed."
	$t set root start {}
    }

    # Find and cut operator chains, very restricted. Cut only chains
    # of x- and /-operators. The other operators have only one child
    # by definition and are thus not chains.

    set q [treeql q -tree $t]
    # q query tree over n
    foreach n [$t children -all root] {
	if {[$t keyexists $n symbol]}        continue
	if {[llength [$t children $n]] != 1} continue
	set op [$t get $n op]
	if {($op ne "/") && ($op ne "x")} continue
	$t cut $n
    }

    flatten $q $t
    q destroy

    # Clear computation results.

    $t unset root page::analysis::peg::realizable
    $t unset root page::analysis::peg::unrealizable

    updateUndefinedDueRemoval $t
    return
}

proc ::page::analysis::peg::realizable::reset {t} {
    # Remove marker, allow recalculation of realizability after changes.

    $t unset root page::analysis::peg::realizable
    return
}

# ### ### ### ######### ######### #########
## Internal

proc ::page::analysis::peg::realizable::First {v} {
    upvar 1 $v visit

    set id    [array startsearch visit]
    set first [array nextelement visit $id]
    array donesearch visit $id

    unset visit($first)
    return $first
}

proc ::page::analysis::peg::realizable::Realizable {t node ncv ucv uv} {
    upvar 1 $ncv nc $ucv uc $uv realizable

    if {$node eq "root"} {
	# Root inherits realizability of the start expression.

	return [info exists realizable([$t get root start])]
    }

    if {[$t keyexists $node symbol]} {
	# Symbol definitions inherit the realizability of their
	# expression.

	return [expr {$uc($node) >= $nc($node)}]
    }

    switch -exact -- [$t get $node op] {
	t - .. - epsilon - alpha - alnum - dot - * - ? {
	    # The terminal symbols are all realizable.
	    return 1
	}
	n {
	    # Symbol invokation inherits realizability of its definition.
	    # Calls to undefined symbols are not realizable.

	    set def [$t get $node def]
	    if {$def eq ""} {return 0}
	    return [info exists realizable($def)]
	}
	/ - | {
	    # Choice, ordered and unordered. Realizable if we have at
	    # least one realizable branch. A quick test based on the count
	    # of realizable children is used.

	    return [expr {$uc($node) > 0}]
	}
	default {
	    # Sequence, and all other operators, are realizable if and
	    # only if all its children are realizable. A quick test based
	    # on the count of realizable children is used.

	    return [expr {$uc($node) >= $nc($node)}]
	}
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide page::analysis::peg::realizable 0.1

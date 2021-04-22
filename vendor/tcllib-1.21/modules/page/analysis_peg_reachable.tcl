# -*- tcl -*-
# ### ### ### ######### ######### #########

# Perform reachability analysis on the PE grammar delivered by the
# frontend. The grammar is in normalized form (reduced to essentials,
# graph like node-x-references, expression trees).

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

namespace eval ::page::analysis::peg::reachable {
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::analysis::peg::reachable::compute {t} {

    # Ignore call if already done before
    if {[$t keyexists root page::analysis::peg::reachable]} return

    # We compute the set of all nodes which are reachable from the
    # root node of the start expression. This is a simple topdown walk
    # where the children of all reachable nodes are mode reachable as
    # well, and invokations of nonterminals symbols are treated as
    # children as well. At the end of the flow all reachable non-
    # terminal symbols and their expressions are marked, and none
    # other.

    # Initialize walking state: 2 arrays, all nodes (except root) are
    # in or the other array, and their location tells if they are
    # reachable or not. In the beginning no node is reachable. The
    # goal array (reach) also serves as minder of which nodes have
    # been seen, to cut multiple visits short.

    array set unreach {} ; foreach n [$t nodes] {set unreach($n) .}
    unset     unreach(root)
    array set reach   {}

    # A node is visited if it has been determined that it is indeed
    # reachable.

    page::util::flow [list [$t get root start]] flow n {
	# Ignore nodes already reached.
	if {[info exists reach($n)]} continue

	# Reclassify node, has been reached now.
	unset unreach($n)
	set   reach($n) .

	# Schedule children for visit --> topdown flow.
	$flow visitl [$t children $n]

	# Treat n-Nodes as special, their definition as indirect
	# child. But ignore invokations of undefined nonterminal
	# symbols, or those already marked as reachable.

	if {![$t keyexists $n op]} continue
	if {[$t get $n op] ne "n"} continue

	set def [$t get $n def]
	if {$def eq ""}                continue
	if {[info exists reach($def)]} continue
	$flow visit $def
    }

    # Store results. This also serves as marker.

    $t set root page::analysis::peg::reachable   [array names reach]
    $t set root page::analysis::peg::unreachable [array names unreach]
    return
}

proc ::page::analysis::peg::reachable::remove! {t} {

    # Determine which nonterminal symbols are reachable from the root
    # of the start expression.

    compute $t

    # Remove all nodes which are not reachable.

    set unreach [$t get root page::analysis::peg::unreachable]
    foreach n [lsort $unreach] {
	if {[$t exists $n]} {
	    $t delete $n
	}
    }

    # Notify the user of the definitions which were among the removed
    # nodes. Keep only the still-existing definitions.

    set res {}
    foreach {sym def} [$t get root definitions] {
	if {![$t exists $def]} {
	    page_warning "  $sym: Unreachable nonterminal symbol, deleting"
	} else {
	    lappend res $sym $def
	}
    }

    # Clear computation results.

    $t unset root page::analysis::peg::reachable
    $t unset root page::analysis::peg::unreachable

    $t set root definitions $res
    updateUndefinedDueRemoval $t
    return
}

proc ::page::analysis::peg::reachable::reset {t} {
    # Remove marker, allow recalculation of reachability after
    # changes.

    $t unset root page::analysis::peg::reachable
    $t unset root page::analysis::peg::unreachable
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide page::analysis::peg::reachable 0.1

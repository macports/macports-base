# -*- tcl -*-
# ### ### ### ######### ######### #########
## Package description

## Utility commands for the conversion between various representations
## of abstract syntax trees.

# ### ### ### ######### ######### #########
## Requisites

namespace eval ::grammar::me::util {
    namespace export ast2tree ast2etree tree2ast
}

# ### ### ### ######### ######### #########
## Implementation

# ### ### ### ######### ######### #########
## API Implementation.

proc ::grammar::me::util::ast2tree {ast tree {root {}}} {
    # See grammar::me_ast for the specification of both value and tree
    # representations.

    if {$root eq ""} {
	set root [$tree rootname]
    }

    # Decompose the AST value into its components.

    if {[llength $ast] < 3} {
	return -code error "Bad node \"$ast\", not enough elements"
    }

    set type     [lindex $ast 0]
    set range    [lrange $ast 1 2]
    set children [lrange $ast 3 end]

    if {($type eq "") && [llength $children]} {
	return -code error \
	    "Terminal node \"[lrange $ast 0 2]\" has children"
    }
    foreach {s e} $range break
    if {
	![string is integer -strict $s] || ($s < 0) ||
	![string is integer -strict $e] || ($e < 0)
    } {
	return -code error "Bad range information \"$range\""
    }

    # Create a node for the root of the AST and fill it with the data
    # from the value. Afterward recurse and build the tree for the
    # children of the root.

    set new [lindex [$tree insert $root end] 0]

    if {$type eq ""} {
	$tree set $new type terminal
    } else {
	$tree set $new type   nonterminal
	$tree set $new detail $type
    }

    $tree set $new range $range

    foreach child $children {
	ast2tree $child $tree $new
    }
    return
}

proc ::grammar::me::util::ast2etree {ast mcmd tree {root {}}} {
    # See grammar::me_ast for the specification of both value and tree
    # representations.

    if {$root eq ""} {
	set root [$tree rootname]
    }

    # Decompose the AST value into its components.

    if {[llength $ast] < 3} {
	return -code error "Bad node \"$ast\", not enough elements"
    }

    set type     [lindex $ast 0]
    set range    [lrange $ast 1 2]
    set children [lrange $ast 3 end]

    if {($type eq "") && [llength $children]} {
	return -code error \
	    "Terminal node \"[lrange $ast 0 2]\" has children"
    }
    foreach {s e} $range break
    if {
	![string is integer -strict $s] || ($s < 0) ||
	![string is integer -strict $e] || ($e < 0)
    } {
	return -code error "Bad range information \"$range\""
    }

    # Create a node for the root of the AST and fill it with the data
    # from the value. Afterward recurse and build the tree for the
    # children of the root.

    set new [lindex [$tree insert $root end] 0]

    if {$type eq ""} {
	set     cmd $mcmd
	lappend cmd tok
	foreach loc $range {lappend cmd $loc}

	$tree set $new type   terminal
	$tree set $new detail [uplevel \#0 $cmd]
    } else {
	$tree set $new type   nonterminal
	$tree set $new detail $type
    }

    set range_lc {}
    foreach loc $range {
	lappend range_lc [uplevel \#0 \
		[linsert $mcmd end lc $loc]]
    }

    $tree set $new range    $range
    $tree set $new range_lc $range_lc

    foreach child $children {
	ast2etree $child $mcmd $tree $new
    }
    return
}

proc ::grammar::me::util::tree2ast {tree {root {}}} {
    # See grammar::me_ast for the specification of both value and tree
    # representations.

    if {$root eq ""} {
	set root [$tree rootname]
    }

    set value {}

    if {![$tree keyexists $root type]} {
	return -code error "Bad node \"$root\", type information is missing"
    }
    if {![$tree keyexists $root range]} {
	return -code error "Bad node \"$root\", range information is missing"
    }

    set range [$tree get $root range]
    if {[llength $range] != 2} {
	return -code error "Bad node \"root\", bad range information \"$range\""
    }

    foreach {s e} $range break
    if {
	![string is integer -strict $s] || ($s < 0) ||
	![string is integer -strict $e] || ($e < 0)
    } {
	return -code error "Bad node \"root\", bad range information \"$range\""
    }

    if {[$tree get $root type] eq "terminal"} {
	lappend value {}
    } else {
	if {![$tree keyexists $root detail]} {
	    return -code error "Bad node \"$root\", nonterminal detail is missing"
	}

	lappend value [$tree get $root detail]
    }

    # Range data ...
    lappend value $s $e

    foreach child [$tree children $root] {
	lappend value [tree2ast $tree $child]
    }

    return $value
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::me::util 0.1

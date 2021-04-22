# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Frontend - Read serialized PEG container.

# ### ### ### ######### ######### #########
## Requisites

package require grammar::peg

namespace eval ::page::parse::pegser {}

# ### ### ### ######### ######### #########
## API

proc ::page::parse::pegser {serial t} {

    ::grammar::peg gr deserialize $serial

    $t set root start [pegser::treeOf $t root [gr start] fixup]

    array set definitions {}
    foreach sym [gr nonterminals] {
	set def [$t insert root end]

	$t set $def users  {}
	$t set $def symbol $sym
	$t set $def label  $sym
	$t set $def mode       [gr nonterminal mode $sym]
	pegser::treeOf $t $def [gr nonterminal rule $sym] fixup

	set definitions($sym) $def
    }

    array set undefined {}
    array set users     {}
    foreach {n sym} $fixup {
	if {[info exists definitions($sym)]} {
	    set def $definitions($sym)
	    $t set $n def $def
	    lappend users($def) $n
	} else {
	    lappend undefined($sym) $n
	}
    }

    foreach def [array names users] {
	$t set $def users $users($def)
    }

    $t set root definitions [array get definitions]
    $t set root undefined   [array get undefined]
    $t set root symbol <StartExpression>
    $t set root name   <Serialization>

    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::parse::pegser::treeOf {t root pe fv} {
    upvar 1 $fv fixup

    set n  [$t insert $root end]
    set op [lindex $pe 0]
    $t set $n op $op

    if {$op eq "t"} {
	$t set $n char [lindex $pe 1]

    } elseif {$op eq ".."} {
	$t set $n begin [lindex $pe 1]
	$t set $n end   [lindex $pe 2]

    } elseif {$op eq "n"} {

	set sym [lindex $pe 1]
	$t set $n sym $sym
	$t set $n def ""

	lappend fixup $n $sym
    } else {
	foreach sub [lrange $pe 1 end] {
	    treeOf $t $n $sub fixup
	}
    }
    return $n
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::parse::pegser {}

# ### ### ### ######### ######### #########
## Ready

package provide page::parse::pegser 0.1

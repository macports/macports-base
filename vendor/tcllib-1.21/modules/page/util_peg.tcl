# -*- tcl -*-
# ### ### ### ######### ######### #########

## This package provides a number of utility commands to
## transformations for common operations. It assumes a 'Normalized PE
## Grammar Tree' as input, possibly augmented with attributes coming
## from transformation not in conflict with the base definition.

# ### ### ### ######### ######### #########
## Requisites

package require page::util::quote

namespace eval ::page::util::peg {
    namespace export \
	    symbolOf symbolNodeOf \
	    updateUndefinedDueRemoval \
	    flatten peOf printTclExpr \
	    getWarnings printWarnings

    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl).

    namespace import ::page::util::quote::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::util::peg::symbolNodeOf {t n} {
    # Given an arbitrary root it determines the node (itself or an
    # ancestor) containing the name of the nonterminal symbol the node
    # belongs to, and returns its id. The result is either the root of
    # the tree (for the start expression), or a definition mode.

    while {![$t keyexists $n symbol]} {
	set n [$t parent $n]
    }
    return $n
}

proc ::page::util::peg::symbolOf {t n} {
    # As above, but returns the symbol name.

    return [$t get [symbolNodeOf $t $n] symbol]
}

proc ::page::util::peg::updateUndefinedDueRemoval {t} {
    # The removal of nodes may have caused symbols to lose one or more
    # users. Example: A used by B and C, B is reachable, C is not, so A
    # now loses a node in the expression for C calling it, or rather
    # not anymore.

    foreach {sym def} [$t get root definitions] {
	set res {}
	foreach u [$t get $def users] {
	    if {![$t exists $u]} continue
	    lappend res $u
	}
	$t set $def users $res
    }

    # Update the knowledge of undefined nonterminals. To be used when
    # a transformation can remove invokations of undefined symbols,
    # and is not able to generate such invokations.

    set res {}
    foreach {sym invokers} [$t get root undefined] {
	set sres {}
	foreach n $invokers {
	    if {![$t exists $n]} continue
	    lappend sres $n
	}
	if {[llength $sres]} {
	    lappend res $sym $sres
	}
    }
    $t set root undefined $res
    return
}

proc ::page::util::peg::flatten {q t} {
    # Flatten nested x-, or /-operators.
    # See peg_normalize.tcl, peg::normalize::ExprFlatten

    foreach op {x /} {
	# Locate all x operators, whose parents are x oerators as
	# well, then go back to the child operators and cut them out.

	$q query \
		tree          withatt op $op \
		parent unique withatt op $op \
		children      withatt op $op \
		over n {
	    $t cut $n
	}
    }
    return
}

proc ::page::util::peg::getWarnings {t} {
    # Look at the attributes for problems with the grammar and issue
    # warnings. They do not prevent us from writing the grammar, but
    # still represent problems with it the user should be made aware
    # of.

    array set msg {}
    array set undefined [$t get root undefined]
    foreach sym [array names undefined] {
	set msg($sym) {}
	foreach ref $undefined($sym) {
	    lappend msg($sym) "Undefined symbol used by the definition of '[symbolOf $t $ref]'."
	}
    }

    foreach {sym def} [$t get root definitions] {
	if {[llength [$t get $def users]] == 0} {
	    set msg($sym) [list "This symbol has been defined, but is not used."]
	}
    }

    return [array get msg]
}

proc ::page::util::peg::printWarnings {msg} {
    if {![llength $msg]} return

    set dict {}
    set max -1
    foreach {k v} $msg {
	set l [string length [list $k]]
	if {$l > $max} {set max $l}
	lappend dict [list $k $v $l]
    }

    foreach e [lsort -dict -index 0 $dict] {
	foreach {k msgs l} $e break

	set off [string repeat " " [expr {$max - $l}]]
	page_info "[list $k]$off : [lindex $msgs 0]"

	if {[llength $msgs] > 1} {
	    set indent [string repeat " " [string length [list $k]]]
	    foreach m [lrange $msgs 1 end] {
		puts stderr "  $indent$off : $m"
	    }
	}
    }
    return
}

proc ::page::util::peg::peOf {t eroot} {
    set op [$t get $eroot op]
    set pe [list $op]

    set ch [$t children $eroot]

    if {[llength $ch]} {
	foreach c $ch {
	    lappend pe [peOf $t $c]
	}
    } elseif {$op eq "n"} {
	lappend pe [$t get $eroot sym]
    } elseif {$op eq "t"} {
	lappend pe [unquote [$t get $eroot char]]
    } elseif {$op eq ".."} {
	lappend pe \
		[unquote [$t get $eroot begin]] \
		[unquote [$t get $eroot end]]

    }
    return $pe
}

proc ::page::util::peg::printTclExpr {pe} {
    list [PrintExprSub $pe]
}

# ### ### ### ######### ######### #########
## Internal

proc ::page::util::peg::PrintExprSub {pe} {
    set op   [lindex $pe 0]
    set args [lrange $pe 1 end]

    #puts stderr "PE [llength $args] $op | $args"

    if {$op eq "t"} {
	set a [lindex $args 0]
	return "$op [quote'tcl $a]"
    } elseif {$op eq ".."} {
	set a [lindex $args 0]
	set b [lindex $args 1]
	return "$op [quote'tcl $a] [quote'tcl $b]"
    } elseif {$op eq "n"} {
	return $pe
    } else {
	set res $op
	foreach a $args {
	    lappend res [PrintExprSub $a]
	}
	return $res
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide page::util::peg 0.1

# -*- tcl -*-
# ### ### ### ######### ######### #########

# Perform mode analysis (x) on the PE grammar delivered by the
# frontend. The grammar is in normalized form (*).
#
# (x) = See "doc_emodes.txt".
#       and "doc_emodes_alg.txt".
# (*) = See "doc_normalize.txt".

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

namespace eval ::page::analysis::peg::emodes {
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::analysis::peg::emodes::compute {t} {

    # Ignore call if already done before
    if {[$t keyexists root page::analysis::peg::emodes]} {return 1}

    # We do not actually compute per node a mode, but rather their
    # gen'erate and acc'eptance properties, as described in
    # "doc_emodes.txt".

    # Note: This implementation will not compute acc/gen information
    # for unreachable nodes.

    # --- --- --- --------- --------- ---------

    array set acc  {} ; # Per node X, acc(X), undefined if no element
    array set call {} ; # Per definition node, number of users
    array set cala {} ; # Per definition node, number of (non-)accepting users

    foreach {sym def} [$t get root definitions] {
	set call($def)   [llength [$t get $def users]]
	set cala(0,$def) 0
	set cala(1,$def) 0
    }

    set acc(root) 1 ; # Sentinel for root of start expression.

    # --- --- --- --------- --------- ---------

    #puts stderr ~~~~\t~~~\t~~~\t~~~\t~~~
    #puts stderr Node\tAcc\tNew\tWhat\tOp
    #puts stderr ~~~~\t~~~\t~~~\t~~~\t~~~

    # A node is visited if its value for acc() is either undefined or
    # may have changed. Basic flow is top down, from the start
    # expression and a definition a child of its invokers.

    set gstart [$t get root start]
    if {$gstart eq ""} {
	page_error "  No start expression, unable to compute accept/generate properties"
	return 0
    }

    page::util::flow [list $gstart] flow n {
	# Determine first or new value.

	#puts -nonewline stderr [string replace $n 1 3]

	if {![info exists acc($n)]} {
	    set a [Accepting $t $n acc call cala]
	    set acc($n) $a
	    set change 0

	    #puts -nonewline stderr \t-\t$a\t^
	} else {
	    set a   [Accepting $t $n acc call cala]
	    set old $acc($n)
	    if {$a == $old} {
		#puts stderr \t$old\t$a\t\ =
		continue
	    }
	    set change 1
	    set acc($n) $a

	    #puts -nonewline stderr \t$old\t$a\t\ \ *
	}

	# Update counters in definitions, if the node invokes them.
	# Also, schedule the children for their (re)definition.

	if {[$t keyexists $n symbol]} {
	    #puts -nonewline stderr \t\ DEF\t[$t get $n symbol]\t[$t get $n mode]
	} else {
	    #puts -nonewline stderr \t[$t get $n op]\t\t
	}

	if {[$t keyexists $n op] && ([$t get $n op] eq "n")} {
	    #puts -nonewline stderr ->\ [$t get $n sym]
	    set def [$t get $n def]
	    if {$def eq ""} continue

	    if {$change} {
		incr cala($old,$def) -1
	    }
	    incr cala($a,$def)
	    $flow visit $def

	    #puts -nonewline stderr @$def\t(0a$cala(0,$def),\ 1a$cala(1,$def),\ #$call($def))\tv($def)
	    #puts stderr ""
	    continue
	}

	#puts stderr \t\t\t\tv([$t children $n])
	$flow visitl [$t children $n]
    }

    # --- --- --- --------- --------- ---------

    array set gen {} ; # Per node X, gen(X), undefined if no element
    array set nc  {} ; # Per node, number of children
    array set ng  {} ; # Per node, number of (non-)generating children

    foreach n [$t nodes] {
	set nc($n)       [$t numchildren $n]
	set ng(0,$n)     0
	set ng(1,$n)     0
    }

    # --- --- --- --------- --------- ---------

    #puts stderr ~~~~\t~~~\t~~~\t~~~\t~~~
    #puts stderr Node\tGen\tNew\tWhat\tOp
    #puts stderr ~~~~\t~~~\t~~~\t~~~\t~~~

    # A node is visited if its value for gen() is either undefined or
    # may have changed. Basic flow is bottom up, from the all
    # leaves (and lookahead operators). Users of a definition are
    # considered as its parents.

    set start [$t leaves]
    set q [treeql q -tree $t]
    q query tree withatt op ! over n {lappend start $n}
    q query tree withatt op & over n {lappend start $n}
    q destroy

    page::util::flow $start flow n {
	# Ignore root.

	if {$n eq "root"} continue

	#puts -nonewline stderr [string replace $n 1 3]

	# Determine first or new value.

	if {![info exists gen($n)]} {
	    set g [Generating $t $n gen nc ng acc call cala]
	    set gen($n) $g

	    #puts -nonewline stderr \t-\t$g\t^

	} else {
	    set g   [Generating $t $n gen nc ng acc call cala]
	    set old $gen($n)
	    if {$g eq $old} {
		#puts stderr \t$old\t$g\t\ =
		continue
	    }
	    set gen($n) $g

	    #puts -nonewline stderr \t$old\t$g\t\ \ *
	}

	if {($g ne "maybe") && !$g && $acc($n)} {
	    # No generate here implies that none of our children will
	    # generate anything either. So the current acceptance of
	    # these non-existing values can be safely forced to
	    # non-acceptance.

	    set acc($n) 0
	    #puts -nonewline stderr "-a"
	}

	if {0} {
	    if {[$t keyexists $n symbol]} {
		#puts -nonewline stderr \t\ DEF\t[$t get $n symbol]\t[$t get $n mode]
	    } else {
		#puts -nonewline stderr \t[$t get $n op]\t\t
	    }
	}

	#puts -nonewline stderr \t(0g$ng(0,$n),1g$ng(1,$n),\ #$nc($n))

	# Update counters in the (virtual) parents, and schedule them
	# for a visit.

	if {[$t keyexists $n symbol]} {
	    # Users are virtual parents.

	    set users  [$t get $n users]
	    $flow visitl $users

	    if {$g ne "maybe"} {
		foreach u $users {incr ng($g,$u)}
	    }
	    #puts stderr \tv($users)
	    continue
	}

	set p [$t parent $n]
	$flow visit $p
	if {$g ne "maybe"} {
	    incr ng($g,$p)
	}

	#puts stderr \tv($p)
    }

    # --- --- --- --------- --------- ---------

    # Copy the calculated data over into the tree.
    # Note: There will be no data for unreachable nodes.

    foreach n [$t nodes] {
	if {$n eq "root"}           continue
	if {![info exists acc($n)]} continue
	$t set $n acc $acc($n)
	$t set $n gen $gen($n)
    }

    # Recompute the modes based on the current
    # acc/gen status of the definitions.

    #puts stderr ~~~~\t~~~\t~~~~\t~~~\t~~~\t~~~
    #puts stderr Node\tSym\tMode\tNew\tGen\tAcc
    #puts stderr ~~~~\t~~~\t~~~~\t~~~\t~~~\t~~~

    foreach {sym def} [$t get root definitions] {
	set m {}

	set old [$t get $def mode]

	if {[info exists acc($def)]} {
	    switch -exact -- $gen($def)/$acc($def) {
		0/0     {set m discard}
		0/1     {error "Bad gen/acc for $sym"}
		1/0     {# don't touch (match, leaf)}
		1/1     {set m value}
		maybe/0 {error "Bad gen/acc for $sym"}
		maybe/1 {set m value}
	    }
	    if {$m ne ""} {
		# Should check correctness of change, if any (We can drop
		# to discard, nothing else).
		$t set $def mode $m
	    }
	    #puts stderr [string replace $def 1 3]\t$sym\t$old\t[$t get $def mode]\t[$t get $def gen]\t[$t get $def acc]
	} else {
	    #puts stderr [string replace $def 1 3]\t$sym\t$old\t\t\t\tNOT_REACHED
	}
    }

    #puts stderr ~~~~\t~~~\t~~~~\t~~~\t~~~\t~~~

    # Wrap up the whole state and save it in the tree. No need to
    # throw this away, useful for other mode based transforms and
    # easier to get in this way than walking the tree again.

    $t set root page::analysis::peg::emodes [list \
	    [array get acc] \
	    [array get call] \
	    [array get cala] \
	    [array get gen] \
	    [array get nc] \
	    [array get ng]]
    return 1
}

proc ::page::analysis::peg::emodes::reset {t} {
    # Remove marker, allow recalculation of emodesness after changes.

    $t unset root page::analysis::peg::emodes
    return
}

# ### ### ### ######### ######### #########
## Internal

proc ::page::analysis::peg::emodes::Accepting {t n av cv cav} {
    upvar 1 $av acc $cv call $cav cala

    # Definitions accept based on how they are called first, and on
    # their mode if that is not possible.

    if {[$t keyexists $n symbol]} {
	# Call based acceptance.
	# !acc if all callers do not accept.

	if {$cala(0,$n) >= $call($n)} {
	    return 0
	}

	# Falling back to mode specific accptance
	return [expr {([$t get $n mode] eq "value") ? 1 : 0}]
    }

    set op [$t get $n op]

    # Lookahead operators will never accept.

    if {($op eq "!") || ($op eq "&")} {
	return 0
    }

    # All other operators inherit the acceptance
    # of their parent.

    return $acc([$t parent $n])
}

proc ::page::analysis::peg::emodes::Generating {t n gv ncv ngv av cv cav} {
    upvar 1 $gv gen $ncv nc $ngv ng $av acc $cv call $cav cala
    #           ~~~      ~~      ~~     ~~~     ~~~~      ~~~~

    # Definitions generate based on their mode, their defining
    # expression, and the acceptance of their callers.

    if {[$t keyexists $n symbol]} {

	# If no caller accepts a value, then this definition will not
	# generate one, even if its own mode asked it to do so.

	if {$cala(0,$n) >= $call($n)} {
	    return 0
	}

	# The definition has callers accepting values and callres not
	# doing so. It will generate as per its own mode and defining
	# expression.

	# The special modes know if they generate a value or not.
	# The pass through mode looks at the expression for the
	# information.

	switch -exact -- [$t get $n mode] {
	    value   {return $gen([lindex [$t children $n] 0])}
	    match   {return 1}
	    leaf    {return 1}
	    discard {return 0}
	}
	error PANIC
    }

    set op [$t get $n op]

    # Inner nodes generate based on operator and children.

    if {$nc($n)} {
	switch -exact -- $op {
	    ! - & {return 0}
	    ? - * {
		# No for all children --> no
		# Otherwise           --> maybe

		if {$ng(0,$n) >= $nc($n)} {
		    return 0
		} else {
		    return maybe
		}
	    }
	    + - / - | {
		# Yes for all children --> yes
		# No for all children  --> no
		# Otherwise            --> maybe

		if {$ng(1,$n) >= $nc($n)} {
		    return 1
		} elseif {$ng(0,$n) >= $nc($n)} {
		    return 0
		} else {
		    return maybe
		}
	    }
	    x {
		# Yes for some children --> yes
		# No for all children   --> no
		# Otherwise             --> maybe

		if {$ng(1,$n) > 0} {
		    return 1
		} elseif {$ng(0,$n) >= $nc($n)} {
		    return 0
		} else {
		    return maybe
		}
	    }
	}
	error PANIC
    }

    # Nonterminal leaves generate based on acceptance from their
    # parent and the referenced definition.

    # As acc(X) == acc(parent(X)) the test doesn't have to go to the
    # parent itself.

    if {$op eq "n"} {
	if {[info exists acc($n)] && !$acc($n)} {return 0}

	set def [$t get $n def]

	# Undefine symbols do not generate anything.
	if {$def eq ""} {return 0}

	# Inherit directly from the definition, if existing.
	if {![info exists gen($def)]} {
	    return maybe
	}

	return $gen($def)
    }

    # Terminal leaves generate values if and only if such values are
    # accepted by their parent. As acc(X) == acc(parent(X) the test
    # doesn't have to go to the parent itself.


    return $acc($n)
}

# ### ### ### ######### ######### #########
## Ready

package provide page::analysis::peg::emodes 0.1

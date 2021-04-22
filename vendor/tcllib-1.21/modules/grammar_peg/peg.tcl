# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Grammars / Parsing Expression Grammars / Container

# ### ### ### ######### ######### #########
## Package description

# A class whose instances hold all the information describing a single
# parsing expression grammar (terminal symbols, nonterminal symbols,
# nonterminal rules, start expression, hints), and operations to
# define, manipulate, and query this information.
#
# The container has only one functionality beyond the simple storage
# of the aforementioned information. It keeps track if the provided
# grammar is valid (*). The container provides no higher-level
# operations on the grammar, like removal of unreachable nonterminals,
# rule rewriting, etc.
#
# The set of terminal symbols is the set of characters (i.e.
# implicitly defined). For Tcl this means that all the unicode
# characters are supported.
#
# (*) A grammar is valid if and only if all its rules are valid.  A
# rule is valid if and only if all nonterminals referenced by the RHS
# of the rule are in the set of nonterminals, and if only the allowed
# operators are used in the expression.

# ### ### ### ######### ######### #########
## Requisites

package require snit         ; # Tcllib | OO system used

# ### ### ### ######### ######### #########
## Implementation

snit::type ::grammar::peg {
    # ### ### ### ######### ######### #########
    ## Type API. Helpful methods for PEs.

    proc ValidateSerial {e prefix} {}
    proc Validate   {e} {}
    proc References {e} {}
    proc Rename     {e old new} {}

    # ### ### ### ######### ######### #########
    ## Instance API

    constructor {args} {}

    method clear {} {}

    method =   {src} {}
    method --> {dst} {}
    method serialize {} {}
    method deserialize {value} {}

    method {is valid} {} {}
    method start {args} {}

    method nonterminals {} {}
    method {nonterminal add}    {nts pae} {}
    method {nonterminal delete} {nts pae} {}
    method {nonterminal exists} {nts} {}
    method {nonterminal rename} {ntsold ntsnew} {}
    method {nonterminal mode}   {nts args} {}

    method {unknown nonterminals} {} {}

    method {nonterminal rule}   {nts} {}

    # ### ### ### ######### ######### #########
    ## Internal data structures.

    ## - Set of nonterminal symbols, and
    ## - Mapping from nonterminals to their defining parsing
    ##   expressions, and
    ## - Start parsing expression.
    ## - And usage of nonterminals by others, required for tracking
    ##   of validity.

    ## se: expression               | Start expression
    ## nt: nonterm -> expression    | Known Nt's, their rules
    ## re: nonterm -> list(nonterm) | Known Nt's, what others they use.
    ## ir: nonterm -> list(nonterm) | Nt's, possibly unknown, their users.
    ## uk: nonterm -> use counter   | Nt's which are unknown.
    ##
    ## Both 're' and 'ir' can list a nonterminal A multiple times,
    ## if it uses or is used multiple times.
    ##
    ## Grammar is invalid <=> '[array size uk] > 0'

    variable se        epsilon
    variable nt -array {}
    variable re -array {}
    variable ir -array {}
    variable uk -array {}
    variable mo -array {}

    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {args} {
	if {
	    (([llength $args] != 0) && ([llength $args] != 2)) ||
	    (([llength $args] == 2) && ([lsearch {= := <-- as deserialize} [lindex $args 0]]) < 0)
	} {
	    return -code error "wrong#args: $self ?=|:=|<--|as|deserialize a'?"
	}

	# Serialization arguments.
	# [llength args] in {0 2}
	#
	# =           src-obj
	# :=          src-obj
	# <--         src-obj
	# as          src-obj
	# deserialize src-value

	if {[llength $args] == 2} {
	    foreach {op val} $args break
	    switch -exact -- $op {
		= - := - <-- - as {
		    $self deserialize [$val serialize]
		}
		deserialize {
		    $self deserialize $val
		}
	    }
	}
	return
    }

    #destructor {}

    method clear {} {
	array unset nt *
	array unset re *
	array unset ir *
	array unset uk *
	array unset mo *
	set se epsilon
	return
    }

    method = {src} {
	$self dserialize [$src serialize]
    }

    method --> {dst} {
	$dst deserialize [$self serialize]
    }

    method serialize {} {
	return [::list \
		grammar::pegc \
		[array get nt] \
		[array get mo] \
		$se]
    }

    method deserialize {value} {
	# Validate value, then clear and refill.

	$self CheckSerialization $value ntv mov sev
	$self clear

	foreach {s e} $ntv {
	    $self NtAdd $s $e
	}
	array set mo $mov
	$self start $sev
	return
    }

    method {is valid} {} {
	return [expr {[array size uk] == 0}]
    }

    method start {args} {
	if {[llength $args] == 0} {
	    return $se
	}
	if {[llength $args] > 1} {
	    return -code error "wrong#args: $self start ?pe?"
	}
	set newse [lindex $args 0]
	Validate $newse
	set se   $newse
	return
    }

    method nonterminals {} {
	return [array names nt]
    }

    method {nonterminal add} {nts pae} {
	$self CheckNtKnown $nts
	Validate $pae
	$self NtAdd $nts $pae
	return
    }

    method {nonterminal mode} {nts args} {
	$self CheckNt $nts
	if {![llength $args]} {
	    return $mo($nts)
	} elseif {[llength $args] == 1} {
	    set mo($nts) [lindex $args 0]
	    return
	} else {
	    return -code error "wrong#args"
	}
	return
    }

    method {nonterminal delete} {nts args} {
	set args [linsert $args 0 $nts]
	foreach nts $args {
	    $self CheckNt $nts
	}

	foreach nts $args {
	    $self NtDelete $nts
	}
	return
    }

    method {nonterminal exists} {nts} {
	return [info exists nt($nts)]
    }

    method {nonterminal rename} {ntsold ntsnew} {
	$self CheckNt      $ntsold
	$self CheckNtKnown $ntsnew

	# Difficult. We have to go through all rules and rewrite their
	# RHS to use the new name of the nonterminal. We can however
	# restrict ourselves to the rules which actually use the
	# changed nonterminal.

	# We also have to update the used/user information. We know
	# that the validity of the grammar is unchanged by this
	# operation. The unknown information is unchanged as well, as
	# we cannot rename an unknown nonterminal. IOW we know that
	# 'ntsold' is not in 'uk', and so 'ntsnew' will not be in that
	# array either after the rename.

	set myusers $ir($ntsold)
	set myused  $re($ntsold)

	set nt($ntsnew) $nt($ntsold)
	unset            nt($ntsold)

	set mo($ntsnew) $mo($ntsold)
	unset            mo($ntsold)

	foreach x $myusers {
	    set nt($x) [Rename $nt($x) $ntsold $ntsnew]
	}

	# It is possible to use myself, and be used by myself.

	while {[set pos [lsearch -exact $myusers $ntsold]] >= 0} {
	    set myusers [lreplace $myusers $pos $pos $ntsnew]
	}
	while {[set pos [lsearch -exact $myused $ntsold]] >= 0} {
	    set myused [lreplace $myused $pos $pos $ntsnew]
	}

	set re($ntsnew) $myusers
	set ir($ntsnew) $myused

	unset            re($ntsold)
	unset            ir($ntsold)
	return
    }

    method {unknown nonterminals} {} {
	return [array names uk]
    }

    method {nonterminal rule} {nts} {
	$self CheckNt $nts
	return $nt($nts)
    }

    # ### ### ### ######### ######### #########
    ## Internal helper methods

    method NtAdd {nts pae} {
	# None of the symbols is known. We can add them to the
	# grammar. If however any of their PEs is known to the PE
	# storage then we had expressions refering to unknown
	# symbols. The grammar is most certainly invalid and may have
	# become valid right now. We have to invalidate the validity
	# cache.

	set nt($nts) $pae
	set mo($nts) value

	# Track users, uses, and unknowns.

	set references [References $pae]

	# We use the refered symbols
	set re($nts) $references

	# We are a user for the refered symbols
	# Record unknown symbols immediately.
	foreach x $references {
	    lappend ir($x) $nts
	    if {[info exists nt($x)]} continue
	    if {[catch {incr uk($x)}]} {set uk($x) 1}
	}

	# We are definitely not unknown.
	unset -nocomplain uk($nts)
	return
    }

    method NtDelete {nts} {
	set references $re($nts)

	# We are gone. We are not using anything anymore.
	unset    nt($nts)
	unset    re($nts)
	unset    mo($nts)

	# Our references loose us as their user.
	foreach x $references {
	    set pos [lsearch -exact $ir($x) $x]
	    if {$pos < 0} {error PANIC}
	    set ir($x) [lreplace $ir($x) $pos $pos]
	    if {[llength $ir($x)] == 0} {
		unset ir($x)
		# x is not referenced anywhere, cannot be unknown.
		unset -nocomplain uk($x)
	    }
	    if {[info exists uk($x)]} {
		incr uk($x) -1
	    }
	}

	# We might be used by others still, and therefore become
	# unknown.

	if {[info exists ir($nts]} {
	    set uk($nts) [llength $ir($nts)]
	}
	return
    }

    method CheckNt {nts} {
	if {![info exists nt($nts)]} {
	    return -code error "Invalid nonterminal \"$nts\""
	}
	return
    }

    method CheckNtKnown {nts} {
	if {[info exists nt($nts)]} {
	    return -code error "Nonterminal \"$nts\" is already known"
	}
	return
    }

    method CheckSerialization {value ntv mov sev} {
	# value is list/3 ('grammar::pegc' nonterminals start)
	# terminals is list of string.
	# nonterminals is doct (key is string, value is expr)
	# start is expr
	# terminals * nonterminals == empty
	# expr is parsing expression (Validate PE).

	upvar 1 \
	    $ntv ntvs \
	    $mov movs \
	    $sev sevs

	set prefix "error in serialization:"
	if {[llength $value] != 4} {
	    return -code error "$prefix list length not 4"
	}

	struct::list assign $value type nonterminals hints start
	if {$type ne "grammar::pegc"} {
	    return -code error "$prefix unknown type \"$type\""
	}

	ValidateSerial $start "$prefix invalid start expression"

	if {[llength $nonterminals] % 2 == 1} {
	    return -code error "$prefix nonterminal data is not a dictionary"
	}
	array set _nt $nonterminals
	if {[llength $nonterminals] != (2*[array size _nt])} {
	    return -code error "$prefix nonterminal data contains duplicate names, or misses some"
	}

	foreach {s e} $nonterminals {
	    ValidateSerial $start "$prefix nonterminal \"$s\", invalid parsing expression"
	}


	if {[llength $hints] % 2 == 1} {
	    return -code error "$prefix nonterminal modes is not a dictionary"
	}
	array set _mo $hints
	if {[llength $hints] != (2*[array size _mo])} {
	    return -code error "$prefix nonterminal modes contains duplicate names, or misses some"
	}
	foreach {s _} $hints {
	    if {![info exists _nt($s)]} {
		return -code error "$prefix nonterminal mode for unknown nonterminal \"$s\""
	    }
	}

	set ntvs $nonterminals
	set sevs $start
	set movs $hints
	return
    }

    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########
    ## Type API implementation.

    proc ValidateSerial {e prefix} {
	if {![catch {Validate $e} msg]} return
	return -code error "$prefix, $msg"
    }

    proc Validate {e} {
	if {[llength $e] == 0} {
	    return -code error "invalid empty expression list"
	}

	set op [lindex $e 0]
	set ar [lrange $e 1 end]

	switch -exact -- $op {
	    epsilon - alpha - alnum - dot {
		if {[llength $ar] > 0} {
		    return -code error "wrong#args for \"$op\""
		}
	    }
	    .. {
		if {[llength $ar] != 2} {
		    return -code error "wrong#args for \"$op\""
		}
		# Leaf, arguments are not expressions to validate.
	    }
	    n - t {
		if {[llength $ar] != 1} {
		    return -code error "wrong#args for \"$op\""
		}
		# Leaf, argument is not expression to validate.
	    }
	    & - ! - * - + - ? {
		if {[llength $ar] != 1} {
		    return -code error "wrong#args for \"$op\""
		}
		Validate [lindex $ar 0]
	    }
	    x - / {
		if {![llength $ar]} {
		    return -code error "wrong#args for \"$op\""
		}
		foreach e $ar {
		    Validate $e
		}
	    }
	    default {
		return -code error "invalid operator \"$op\""
	    }
	}
    }

    proc References {e} {
	set references {}

	set op [lindex $e 0]
	set ar [lrange $e 1 end]

	switch -exact -- $op {
	    epsilon - t - alpha - alnum - dot - .. {}
	    n {
		# Remember referenced nonterminal
		lappend references [lindex $ar 0]
	    }
	    & - ! - * - + - ? {
		foreach r [References [lindex $ar 0]] {
		    lappend references $r
		}
	    }
	    x - / {
		foreach e $ar {
		    foreach r [References $e] {
			lappend references $r
		    }
		}
	    }
	}
	return $references
    }

    proc Rename {e old new} {
	set op [lindex $e 0]
	set ar [lrange $e 1 end]

	switch -exact -- $op {
	    epsilon - t - alpha - alnum - dot - .. {return $e}
	    n {
		if {[lindex $ar 0] ne $old} {return $e}
		return [list n $new]
	    }
	    & - ! - * - + - ? {
		return [list $op [Rename [lindex $ar 0] $old $new]]
	    }
	    x - / {
		set res $op
		foreach e $ar {
		    lappend res [Rename $e $old $new]
		}
		return $res
	    }
	}
    }

    # ### ### ### ######### ######### #########
    ## Type Internals.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::peg 0.2

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Package description

## Implementation of the ME virtual machine as a singleton, tied to
## Tcl for control flow and stack handling (except the AST stack).

# ### ### ### ######### ######### #########
## Requisites

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::grammar::me::tcl {
    namespace export \
	init lc tok sv tokens ast \
	astall ctok nc next ord \
	\
	isv_clear              ict_advance        inc_save    \
	isv_terminal           ict_match_token    inc_restore \
	isv_nonterminal_leaf   ict_match_tokrange icl_get     \
	isv_nonterminal_range  ict_match_tokclass icl_rewind  \
	isv_nonterminal_reduce iok_ok      \
	ier_clear              iok_fail    \
	ier_get                iok_negate  \
	ier_expected           ias_push    \
	ier_nonterminal        ias_mark    \
	ier_merge              ias_pop2mark

    variable ok
}

# ### ### ### ######### ######### #########
## Implementation, API. Ensemble command.

proc ::grammar::me::tcl {cmd args} {
    # Dispatcher for the ensemble command.
    variable tcl::cmds
    return [uplevel 1 [linsert $args 0 $cmds($cmd)]]
}

namespace eval grammar::me::tcl {
    variable cmds

    # Mapping from cmd names to procedures for quick dispatch. The
    # objects will shimmer into resolved command references.

    array set cmds {
	init   ::grammar::me::tcl::init
	lc     ::grammar::me::tcl::lc
	tok    ::grammar::me::tcl::tok
	sv     ::grammar::me::tcl::sv
	tokens ::grammar::me::tcl::tokens
	ast    ::grammar::me::tcl::ast
	astall ::grammar::me::tcl::astall
	ctok   ::grammar::me::tcl::ctok
	nc     ::grammar::me::tcl::nc
	next   ::grammar::me::tcl::next
	ord    ::grammar::me::tcl::ord
    }
}

# ### ### ### ######### ######### #########
## API Implementation.

proc ::grammar::me::tcl::init {nxcmd {tokmap {}}} {
    variable next  $nxcmd
    variable as    {}
    variable ok    0
    variable error {}
    variable sv    {}
    variable loc  -1
    variable ct    {}
    variable tc    {}
    variable nc
    variable tokOrd
    variable tokUseOrd 0

    array unset nc     *
    array unset tokOrd *

    if {[llength $tokmap]} {
	if {[llength $tokmap] % 2 == 1} {
	    return -code error \
		    "Bad token order map, not a dictionary"
	}
	array set tokOrd $tokmap
	set tokUseOrd 1
    }
    return
}

proc ::grammar::me::tcl::lc {pos} {
    variable tc
    return [lrange [lindex $tc $pos] 2 3]
}

proc ::grammar::me::tcl::tok {from {to {}}} {
    variable tc
    if {$to == {}} {set to $from}
    return [lrange $tc $from $to]
}

proc ::grammar::me::tcl::tokens {} {
    variable tc
    return [llength $tc]
}

proc ::grammar::me::tcl::sv {} {
    variable sv
    return  $sv
}

proc ::grammar::me::tcl::ast {} {
    variable as
    return [lindex $as end]
}

proc ::grammar::me::tcl::astall {} {
    variable as
    return $as
}

proc ::grammar::me::tcl::ctok {} {
    variable ct
    return  $ct
}

proc ::grammar::me::tcl::nc {} {
    variable nc
    return [array get nc]
}

proc ::grammar::me::tcl::next {} {
    variable next
    return  $next
}

proc ::grammar::me::tcl::ord {} {
    variable tokOrd
    return [array get tokOrd]
}

# ### ### ### ######### ######### #########
## Terminal matching

proc ::grammar::me::tcl::ict_advance {msg} {
    # Inlined: Getch, Expected, ClearErrors

    variable ok
    variable error
    # ------------------------
    variable tc
    variable loc
    variable ct
    # ------------------------
    variable next
    # ------------------------

    # Satisfy from input cache if possible.
    incr loc
    if {$loc < [llength $tc]} {
	set ct [lindex $tc $loc 0]
	set ok 1
	set error {}
	return
    }

    # Actually read from the input, and remember
    # the information.

    # Read from buffer, and remember.
    # Note: loc is the instance variable.
    # This implicitly increments the location!

    set tokdata [uplevel \#0 $next]
    if {![llength $tokdata]} {
	set ok 0
	set error [list $loc [list $msg]]
	return
    } elseif {[llength $tokdata] != 4} {
	return -code error "Bad callback result, expected 4 elements"
    }

    lappend tc $tokdata
    set ct [lindex $tokdata 0]
    set ok    1
    set error {}
    return
}

proc ::grammar::me::tcl::ict_match_token {tok msg} {
    variable ct
    variable ok

    set ok [expr {$tok eq $ct}]

    OkFail $msg
    return
}

proc ::grammar::me::tcl::ict_match_tokrange {toks toke msg} {
    variable ct
    variable ok
    variable tokUseOrd
    variable tokOrd

    if {$tokUseOrd} {
	set ord $tokOrd($ct)
	set ok [expr {
	    ($toks <= $ord) &&
	    ($ord <= $toke)
	}] ; # {}
    } else {
	set ok [expr {
	    ([string compare $toks   $ct] <= 0) &&
	    ([string compare $ct   $toke] <= 0)
	}] ; # {}
    }

    OkFail $msg
    return
}

proc ::grammar::me::tcl::ict_match_tokclass {code msg} {
    variable ct
    variable ok

    set ok [string is $code -strict $ct]

    OkFail $msg
    return
}

proc ::grammar::me::tcl::OkFail {msg} {
    variable ok
    variable error
    variable loc

    # Inlined: Expected, Unget, ClearErrors

    if {!$ok} {
	set error [list $loc [list $msg]]
	incr loc -1
    } else {
	set error {}
    }
    return
}

# ### ### ### ######### ######### #########
## Nonterminal cache

proc ::grammar::me::tcl::inc_restore {symbol} {
    variable loc
    variable nc
    variable ok
    variable error
    variable sv

    # Satisfy from cache if possible.
    if {[info exists nc($loc,$symbol)]} {
	foreach {go ok error sv} $nc($loc,$symbol) break

	# Go forward, as the nonterminal matches (or not).
	set loc $go
	return 1
    }
    return 0
}

proc ::grammar::me::tcl::inc_save {symbol at} {
    variable loc
    variable nc
    variable ok
    variable error
    variable sv

    if 0 {
	if {[info exists nc($at,$symbol)]} {
	    return -code error "Cannot overwrite\
		    existing data @ ($at, $symbol)"
	}
    }

    # FIXME - end location should be argument.

    # Store not only the value, but also how far
    # the match went (if it was a match).

    set nc($at,$symbol) [list $loc $ok $error $sv]
    return
}

# ### ### ### ######### ######### #########
## Unconditional matching.

proc ::grammar::me::tcl::iok_ok {} {
    variable ok 1
    return
}

proc ::grammar::me::tcl::iok_fail {} {
    variable ok 0
    return
}

proc ::grammar::me::tcl::iok_negate {} {
    variable ok
    set ok [expr {!$ok}]
    return
}

# ### ### ### ######### ######### #########
## Basic input handling and tracking

proc ::grammar::me::tcl::icl_get {} {
    variable loc
    return  $loc
}

proc ::grammar::me::tcl::icl_rewind {oldloc} {
    variable loc

    if 0 {
	if {($oldloc < -1) || ($oldloc > $loc)} {
	    return -code error "Bad location \"$oldloc\" (vs $loc)"
	}
    }
    set loc $oldloc
    return
}

# ### ### ### ######### ######### #########
## Error handling.

proc ::grammar::me::tcl::ier_get {} {
    variable error
    return  $error
}

proc ::grammar::me::tcl::ier_clear {} {
    variable error {}
    return
}

proc ::grammar::me::tcl::ier_nonterminal {msg pos} {
    # Inlined: Errors, Expected.

    variable error

    if {[llength $error]} {
	foreach {l m} $error break
	incr pos
	if {$l == $pos} {
	    set error [list $l [list $msg]]
	}
    }
}

proc ::grammar::me::tcl::ier_merge {new} {
    variable error

    # We have either old or new error data, keep it.

    if {![llength $error]} {set error $new ; return}
    if {![llength $new]}   {return}

    # If one of the errors is further on in the input choose that as
    # the information to propagate.

    foreach {loe msgse} $error break
    foreach {lon msgsn} $new   break

    if {$lon > $loe} {set error $new ; return}
    if {$loe > $lon} {return}

    # Equal locations, merge the message lists.

    foreach m $msgsn {lappend msgse $m}
    set error [list $loe [lsort -uniq $msgse]]
    return
}

# ### ### ### ######### ######### #########
## Operations for the construction of the
## abstract syntax tree (AST).

proc ::grammar::me::tcl::isv_clear {} {
    variable sv {}
    return
}

proc ::grammar::me::tcl::isv_terminal {} {
    variable loc
    variable sv
    variable as

    set sv [list {} $loc $loc]
    lappend as $sv
    return
}

proc ::grammar::me::tcl::isv_nonterminal_leaf {nt pos} {
    # Inlined clear, reduce, and optimized.
    variable ok
    variable loc
    variable sv {}

    # Clear ; if {$ok} {Reduce $nt}

    if {$ok} {
	incr pos
	set sv [list $nt $pos $loc]
    }
    return
}

proc ::grammar::me::tcl::isv_nonterminal_range {nt pos} {
    variable ok
    variable loc
    variable sv {}

    if {$ok} {
	# TerminalString $pos
	# Get all characters after 'pos' to current location as terminal data.

	incr pos
	set sv [list $nt $pos $loc [list {} $pos $loc]]

	#set sv [linsert $sv 0 $nt] ;#Reduce $nt
    }
    return
}

proc ::grammar::me::tcl::isv_nonterminal_reduce {nt pos {mrk 0}} {
    variable ok
    variable as
    variable loc
    variable sv {}

    if {$ok} {
	incr pos
	set sv [lrange $as $mrk end]         ;#SaveToMark $mrk
	set sv [linsert $sv 0 $nt $pos $loc] ;#Reduce $nt
    }
    return
}

# ### ### ### ######### ######### #########
## AST stack handling

proc ::grammar::me::tcl::ias_push {} {
    variable as
    variable sv
    lappend as $sv
    return
}

proc ::grammar::me::tcl::ias_mark {} {
    variable as
    return [llength $as]
}

proc ::grammar::me::tcl::ias_pop2mark {mark} {
    variable as
    if {[llength $as] <= $mark} return
    incr mark -1
    set as [lrange $as 0 $mark]
    return
}

# ### ### ### ######### ######### #########
## Data structures.

namespace eval ::grammar::me::tcl {
    # ### ### ### ######### ######### #########
    ## Public State of MVM (Matching Virtual Machine)

    variable ok   0  ; # Boolean: Ok/Fail of last match operation.

    # ### ### ### ######### ######### #########
    ## Internal state.

    variable ct   {}  ; # Current token.
    variable loc  0   ; # Location of 'ct' as offset in input.

    variable error {} ; # Error data for last match.
    #                 ; # == List (loc, list of strings)
    #                 ; # or empty list
    variable sv   {}  ; # Semantic value for last match.

    # ### ### ### ######### ######### #########
    ## Data structures for AST construction

    variable as {} ; # Stack of values for AST

    # ### ### ### ######### ######### #########
    ## Memo data structures for tokens and match results.

    variable tc {}
    variable nc ; array set nc {}

    # ### ### ### ######### ######### #########
    ## Input buffer, location of next character to read.
    ## ASSERT (loc <= cloc)

    variable next   ; # Callback to get next character.

    # Token ordering for range checks. Optional

    variable tokOrd ; array set tokOrd {}
    variable tokUseOrd 0

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::me::tcl 0.1

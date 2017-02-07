# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Grammar / Parsing Expression Grammar / Interpreter (Namespace based)

# ### ### ### ######### ######### #########
## Package description

## The instances of this class match an input provided by a buffer to
## a parsing expression grammar provided by a peg container. The
## matching process is interpretative, i.e. expressions are matched on
## the fly and multiple as they are encountered. The interpreter
## operates in pull-push mode, i.e. the interpreter object is in
## charge and reads the character stream from the buffer as it needs,
## and returns with the result of the match either when encountering
## an error, or when the match was successful.

# ### ### ### ######### ######### #########
## Requisites

package require grammar::me::tcl

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::grammar::peg::interp {
    # Import the virtual machine for matching.

    namespace import ::grammar::me::tcl::*
    upvar #0 ::grammar::me::tcl::ok ok
}

# ### ### ### ######### ######### #########
## Instance API Implementation.

proc ::grammar::peg::interp::setup {peg} {
    variable ru
    variable mo
    variable se

    if {![$peg is valid]} {
        return -code error "Cannot initialize interpreter for invalid grammar"
    }
    set se [$peg start]
    foreach s [$peg nonterminals] {
        set ru($s) [$peg nonterminal rule $s]
        set mo($s) [$peg nonterminal mode $s]
    }

    #parray mo
    return
}

proc ::grammar::peg::interp::parse {nxcmd emvar astvar} {
    variable ok
    variable se

    upvar 1 $emvar emsg $astvar ast

    init $nxcmd

    MatchExpr $se
    isv_nonterminal_reduce ALL -1
    set ast [sv]
    if {!$ok} {
        foreach {l m} [ier_get] break
        lappend l [lc $l]
        set emsg [list $l $m]
    }

    return $ok
}

# ### ### ### ######### ######### #########
## Internal helper methods

proc ::grammar::peg::interp::MatchExpr {e} {
    variable ok
    variable mode
    variable mo
    variable ru

    set op [lindex $e 0]
    set ar [lrange $e 1 end]

    switch -exact -- $op {
        epsilon {
            # No input to match, nor consume. Match always.
            iok_ok
        }
        dot {
            # Match and consume one character. No matter which
            # character. Fails only when reaching eof. Does not
            # consume input on failure.
            
            ict_advance "Expected any character (got EOF)"
            if {$ok && ($mode eq "value")} {isv_terminal}
        }
        alnum - alpha {
            ict_advance            "Expected <$op> (got EOF)"
            if {!$ok} return

            ict_match_tokclass $op "Expected <$op>"
            if {$ok && ($mode eq "value")} {isv_terminal}
        }
        t {
            # Match and consume one specific character. Fails if
            # the character at the location is not what was
            # expected. Does not consume input on failure.

            set ch [lindex $ar 0]

            ict_advance     "Expected $ch (got EOF)"
            if {!$ok} return

            ict_match_token $ch "Expected $ch"
            if {$ok && ($mode eq "value")} {isv_terminal}
        }
        .. {
            # Match and consume one character, if in the specified
            # range. Fails if the read character is outside of the
            # range. Does not consume input on failure.

            foreach {chbegin chend} $ar break

            ict_advance                        "Expected \[$chbegin .. $chend\] (got EOF)"
            if {!$ok} return

            ict_match_tokrange $chbegin $chend "Expected \[$chbegin .. $chend\]"
            if {$ok && ($mode eq "value")} {isv_terminal}
        }
        n {
            # To match a nonterminal in the input we match its
            # parsing expression. This can be cut short if the
            # necessary information can be obtained from the memo
            # cache. Does not consume input on failure.

            set nt [lindex $ar 0]
            set savemode $mode
            set mode $mo($nt)

            if {[inc_restore $nt]} {
                if {$ok && ($mode ne "discard")} ias_push
                set mode $savemode
                return
            }

            set pos [icl_get]
            set mrk [ias_mark]

            MatchExpr $ru($nt)

            # Generate semantic value, based on mode.
            if {$mode eq "value"} {
                isv_nonterminal_reduce $nt $pos $mrk
            } elseif {$mode eq "match"} {
                isv_nonterminal_range  $nt $pos
            } elseif {$mode eq "leaf"} {
                isv_nonterminal_leaf   $nt $pos
            } else {
                # mode eq "discard"
                isv_clear
            }
            inc_save $nt $pos

            # AST operations ...
            ias_pop2mark $mrk
            if {$ok && ($mode ne "discard")} ias_push

            set mode $savemode
            # Even if match is ok.
	    ier_nonterminal "Expected $nt" $pos
        }
        & {
            # Lookahead predicate. And. Matches the expression
            # against the input and returns match result. Never
            # consumes any input.

            set pos [icl_get]

            MatchExpr [lindex $ar 0]

            icl_rewind $pos
            return
        }
        ! {
            # Negated lookahead predicate. Matches the expression
            # against the input and returns the negated match
            # result. Never consumes any input.

            set pos [icl_get]
            set mrk [ias_mark]
            
            MatchExpr [lindex $ar 0]

            if {$ok} {ias_pop2mark $mrk}
            icl_rewind $pos

            iok_negate
            return
        }
        * {
            # Zero or more repetitions. This consumes as much
            # input as it was able to match the sub
            # expression. The expresion as a whole always matches,
            # even if the sub expression fails (zero repetition).

            set sub [lindex $ar 0]

            while {1} {
                set pos [icl_get]

                set old [ier_get]
                MatchExpr $sub
                ier_merge $old

                if {$ok} continue
		break
            }

	    icl_rewind $pos
	    iok_ok
	    return
        }
        + {
            # One or more repetition. Like *, except for one match
            # at the front which has to match for success. This
            # expression can fail. It will consume only as much
            # input as it was able to match.

            set sub [lindex $ar 0]

            set pos [icl_get]

            MatchExpr $sub
            if {!$ok} {
                icl_rewind $pos
                return
            }

            while {1} {
                set pos [icl_get]

                set old [ier_get]
                MatchExpr $sub
                ier_merge $old

                if {$ok} continue
		break
            }

	    icl_rewind $pos
	    iok_ok
	    return
        }
        ? {
            # Optional matching. Tries to match the sub
            # expression. Will never fail, even if the sub
            # expression is not matching. Consumes only input as
            # it could match in the sub expression. Like *, but
            # without the repetition.

            set pos [icl_get]

	    set old [ier_get]
            MatchExpr [lindex $ar 0]
	    ier_merge $old

            if {!$ok} {
                icl_rewind $pos
                iok_ok
            }
            return
        }
        x {
            # Sequence. Matches each sub expression in turn, each
            # consuming input. In case of failure by one of the
            # sequence elements nothing is consumed at all.

            set pos [icl_get]
            set mrk [ias_mark]
            ier_clear

            foreach e $ar {

                set old [ier_get]
                MatchExpr $e
                ier_merge $old

                if {!$ok} {
                    ias_pop2mark $mrk
                    icl_rewind $pos
                    return
                }
            }
            # OK
            return
        }
        / {
            # Choice. Matches each sub expression in turn, always
            # starting from the current location. Nothing is
            # consumed if all branches fail. Consumes as much as
            # was consumed by the matching branch.

            set pos [icl_get]
            set mrk [ias_mark]

            ier_clear
            foreach e $ar {

                set old [ier_get]
                MatchExpr $e
                ier_merge $old

                if {!$ok} {
                    ias_pop2mark $mrk
                    icl_rewind $pos
                    continue
                }
                return
            }
            # FAIL
            iok_fail
            return
        }
    }
}

# ### ### ### ######### ######### #########
## Interpreter data structures.

namespace eval ::grammar::peg::interp {
    ## Start expression.
    ## Map from nonterminals to their expressions.
    ## Reference to internal memo cache.

    variable se {} ; # Start expression.
    variable ru    ; # Nonterminals and rule map.
    variable mo    ; # Nonterminal modes.

    variable mode value ; # Matching mode.

    array set ru {}
    array set mo {}
}

# ### ### ### ######### ######### #########
## Package Management

package provide grammar::peg::interp 0.1.1

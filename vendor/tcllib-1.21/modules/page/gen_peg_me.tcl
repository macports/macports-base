# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - Generate a grammar::mengine based parser.

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
## Dumping the input grammar. But not as Tcl or other code. In PEG
## format again, pretty printing.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: page::plugin

package require page::plugin ; # S.a. pseudo-package.

package require textutil
package require page::analysis::peg::emodes
package require page::util::quote
package require page::util::peg

namespace eval ::page::gen::peg::me {
    # Get the peg char de/encoder commands.
    # (unquote, quote'tcl)

    namespace import ::page::util::quote::*
    namespace import ::page::util::peg::*
}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::me::package {text} {
    variable package $text
    return
}

proc ::page::gen::peg::me::copyright {text} {
    variable copyright $text
    return
}

proc ::page::gen::peg::me {t chan} {
    variable me::package
    variable me::copyright

    # Resolve the mode hints. Every gen(X) having a value of 'maybe'
    # (or missing) is for the purposes of this code a 'yes'.

    if {![page::analysis::peg::emodes::compute $t]} {
	page_error "  Unable to generate a ME parser without accept/generate properties"
	return
    }

    foreach n [$t nodes] {
	if {![$t keyexists $n gen] || ([$t get $n gen] eq "maybe")} {
	    $t set $n gen 1
	}
	if {![$t keyexists $n acc]} {$t set $n acc 1}
    }

    $t set root Pcount 0

    $t set root package   $package
    $t set root copyright $copyright

    # Synthesize all text fragments we need.
    me::Synth $t

    # And write the grammar text.
    puts $chan [$t get root TEXT]
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::peg::me::Synth {t} {
    # Phase 2: Bottom-up, synthesized attributes
    #
    # - Text blocks per node.

    $t walk root -order post -type dfs n {
	SynthNode $t $n
    }
    return
}

proc ::page::gen::peg::me::SynthNode {t n} {
    if {$n eq "root"} {
	set code Root
    } elseif {[$t keyexists $n symbol]} {
	set code Nonterminal
    } elseif {[$t keyexists $n op]} {
	set code [$t get $n op]
    } else {
	return -code error "PANIC. Bad node $n, cannot classify"
    }

    #puts stderr "SynthNode/$code $t $n"

    SynthNode/$code $t $n

    #SHOW [$t get $n TEXT] 1 0
    #catch {puts stderr "\t.[$t get $n W]x[$t get $n H]"}
    return
}

proc ::page::gen::peg::me::SynthNode/Root {t n} {
    variable template

    # Root is the grammar itself.

    # Text blocks we have to combine:
    # - Code for matching the start expression
    # - Supporting code for the above.
    # - Code per Nonterminal definition.

    set gname    [$t get root name]
    set gstart   [$t get root start]
    set gpackage [$t get root package]
    set gcopy    [$t get root copyright]

    if {$gcopy ne ""} {
	set gcopyright "## (C) $gcopy\n"
    } else {
	set gcopyright ""
    }
    if {$gpackage eq ""} {
	set gpackage $gname
    }

    page_info "  Grammar:   $gname"
    page_info "  Package:   $gpackage"
    if {$gcopy ne ""} {
	page_info "  Copyright: $gcopy"
    }

    if {$gstart ne ""} {
	set match   [textutil::indent \
		[$t get $gstart MATCH] \
		"    "]
    } else {
	page_error "  No start expression."
	set match ""
    }

    set crules {}
    set rules  {}
    set support [$t get [$t get root start] SUPPORT]
    if {[string length $support]} {
	lappend rules $support
	lappend rules {}
    }

    lappend crules "# Grammar '$gname'"
    lappend crules {#}

    array set def [$t get root definitions]
    foreach sym [lsort -dict [array names def]]  {
	lappend crules [Pfx "# " [$t get $def($sym) EXPR]]
	lappend crules {#}

	lappend rules  [$t get $def($sym) TEXT]
	lappend rules {}
    }
    set rules [join [lrange $rules 0 end-1] \n]

    lappend crules {}
    lappend crules $rules

    set crules [join $crules \n]

    # @PKG@ and @NAME@ are handled after the other expansions as their
    # contents may insert additional instances of these placeholders.

    $t set root TEXT \
	[string map \
	    [list \
	        @NAME@ $gname \
	        @PKG@  $gpackage \
	        @COPY@ $gcopyright] \
	    [string map \
	        [list \
		    @MATCH@ $match \
		    @RULES@ $crules \
		    ] $template]]
    return
}

proc ::page::gen::peg::me::SynthNode/Nonterminal {t n} {
    # This is the root of a definition.
    #
    # The text is a procedure wrapping the match code of its
    # expression into the required the nonterminal handling (caching
    # and such), plus the support code for the expression matcher.

    set sym      [$t get $n symbol]
    set label    [$t get $n label]
    set gen      [$t get $n gen]
    set mode     [$t get $n mode]

    set pe       [lindex [$t children $n] 0]
    set egen     [$t get $pe gen]
    set esupport [$t get $pe SUPPORT]
    set ematch   [$t get $pe MATCH]
    set eexpr    [$t get $pe EXPR]

    # Combine the information.

    set sexpr    [Cat "$sym = " $eexpr]

    set match {}
    #lappend match "puts stderr \"$label << \[icl_get\]\""
    #lappend match {}
    lappend match [Pfx "# " $sexpr]
    lappend match {}
    if {$gen} {
	lappend match {variable ok}
	lappend match "if \{\[inc_restore $label\]\} \{"
	lappend match "    if \{\$ok\} ias_push"
	#lappend match "    puts stderr \">> $label = \$ok (c) \[icl_get\]\""
	lappend match "    return"
	lappend match "\}"
    } else {
	set eop [$t get $pe op]
	if {
	    ($eop eq "t")     || ($eop eq "..") ||
	    ($eop eq "alpha") || ($eop eq "alnum")
	} {
	    # Required iff !dot
	    # Support for terminal expression 
	    lappend match {variable ok}
	}

	#lappend match "variable ok"
	lappend match "if \{\[inc_restore $label\]\} return"
	#lappend match "if \{\[inc_restore $label\]\} \{"
	#lappend match "    puts stderr \">> $label = \$ok (c) \[icl_get\]\""
	#lappend match "    return"
	#lappend match "\}"
    }
    lappend match {}
    lappend match {set pos [icl_get]}
    if {$egen} {
	# [*] Needed for removal of SV's from stack after handling by
	# this symbol, only if expression actually generates an SV.
	lappend match {set mrk [ias_mark]}
    }
    lappend match {}
    lappend match $ematch
    lappend match {}

    switch -exact -- $mode {
	value   {lappend match "isv_nonterminal_reduce $label \$pos \$mrk"}
	match   {lappend match "isv_nonterminal_range  $label \$pos"}
	leaf    {lappend match "isv_nonterminal_leaf   $label \$pos"}
	discard {lappend match "isv_clear"}
	default {return -code error "Bad nonterminal mode \"$mode\""}
    }

    lappend match "inc_save               $label \$pos"
    if {$egen} {
	# See [*], this is the removal spoken about before.
	lappend match {ias_pop2mark             $mrk}
    }
    if {$gen} {
	lappend match {if {$ok} ias_push}
    }
    lappend match "ier_nonterminal        \"Expected $label\" \$pos"
    #lappend match "puts stderr \">> $label = \$ok \[icl_get\]\""
    lappend match return

    # Final assembly

    set pname [Call $sym]
    set match [list [Proc $pname [join $match \n]]]

    if {[string length $esupport]} {
	lappend match {}
	lappend match $esupport
    }

    $t set $n TEXT [join $match \n]
    $t set $n EXPR $sexpr
    return
}

proc ::page::gen::peg::me::SynthNode/? {t n} {
    # The expression e? is equivalent to e/epsilon.
    # And like this it is compiled.

    set pe       [lindex [$t children $n] 0]
    set ematch   [$t get $pe MATCH]
    set esupport [$t get $pe SUPPORT]
    set eexpr    [$t get $pe EXPR]
    set egen     [$t get $pe gen]
    set sexpr    "[Cat "(? " $eexpr])"

    set     match {}
    lappend match {}
    lappend match [Pfx "# " $sexpr]
    lappend match {}
    lappend match {variable ok}
    lappend match {}
    lappend match {set pos [icl_get]}
    lappend match {}
    lappend match {set old [ier_get]}
    lappend match $ematch
    lappend match {ier_merge $old}
    lappend match {}
    lappend match {if {$ok} return}
    lappend match {icl_rewind $pos}
    lappend match {iok_ok}
    lappend match {return}

    # Final assembly

    set pname [NextProc $t opt]
    set match [list [Proc $pname [join $match \n]]]
    if {[string length $esupport]} {
	lappend match {}
	lappend match $esupport
    }

    $t set $n EXPR    $sexpr
    $t set $n MATCH   [Cat "$pname                ; " [Pfx "# " $sexpr]]
    $t set $n SUPPORT [join $match \n]
    return
}

proc ::page::gen::peg::me::SynthNode/* {t n} {
    # Kleene star is like a repeated ?

    # Note: Compilation as while loop, as done now
    # means that the parser has no information about
    # the intermediate structure of the input in his
    # cache.

    # Future: Create a helper symbol X and compile
    # the expression e = e'* as:
    #     e = X; X <- (e' X)?
    # with match data for X put into the cache. This
    # is not exactly equivalent, the structure of the
    # AST is different (right-nested tree instead of
    # a list). This however can be handled with a
    # special nonterminal mode to expand the current
    # SV on the stack.

    # Note 2: This is a transformation which can be
    # done on the grammar itself, before the actual
    # backend is let loose. This "strength reduction"
    # allows us to keep this code here.

    set pe       [lindex [$t children $n] 0]
    set ematch   [$t get $pe MATCH]
    set esupport [$t get $pe SUPPORT]
    set eexpr    [$t get $pe EXPR]
    set egen     [$t get $pe gen]
    set sexpr    "[Cat "(* " $eexpr])"

    set     match {}
    lappend match {}
    lappend match [Pfx "# " $sexpr]
    lappend match {}
    lappend match {variable ok}
    lappend match {}
    lappend match "while \{1\} \{"
    lappend match {    set pos [icl_get]}
    lappend match {}
    lappend match {    set old [ier_get]}
    lappend match [textutil::indent $ematch "    "]
    lappend match {    ier_merge $old}
    lappend match {}
    lappend match {    if {$ok} continue}
    lappend match {    break}
    lappend match "\}"
    lappend match {}
    lappend match {icl_rewind $pos}
    lappend match {iok_ok}
    lappend match {return}

    # Final assembly

    set pname [NextProc $t kleene]
    set match [list [Proc $pname [join $match \n]]]
    if {[string length $esupport]} {
	lappend match {}
	lappend match $esupport
    }

    $t set $n MATCH   [Cat "$pname                ; " [Pfx "# " $sexpr]]
    $t set $n SUPPORT [join $match \n]
    $t set $n EXPR    $sexpr
    return
}

proc ::page::gen::peg::me::SynthNode/+ {t n} {
    # Positive Kleene star x+ is equivalent to x x*
    # This is how it is compiled. See also the notes
    # at the * above, they apply in essence here as
    # well, except that the transformat scheme is
    # slighty different:
    #
    # e = e'*  ==> e = X; X <- e' X?

    set pe       [lindex [$t children $n] 0]
    set ematch   [$t get $pe MATCH]
    set esupport [$t get $pe SUPPORT]
    set eexpr    [$t get $pe EXPR]
    set egen     [$t get $pe gen]
    set sexpr    "[Cat "(+ " $eexpr])"

    set     match {}
    lappend match {}
    lappend match [Pfx "# " $sexpr]
    lappend match {}
    lappend match {variable ok}
    lappend match {}
    lappend match {set pos [icl_get]}
    lappend match {}
    lappend match {set old [ier_get]}
    lappend match $ematch
    lappend match {ier_merge $old}
    lappend match {}
    lappend match "if \{!\$ok\} \{"
    lappend match {    icl_rewind $pos}
    lappend match {    return}
    lappend match "\}"
    lappend match {}
    lappend match "while \{1\} \{"
    lappend match {    set pos [icl_get]}
    lappend match {}
    lappend match {    set old [ier_get]}
    lappend match [textutil::indent $ematch "    "]
    lappend match {    ier_merge $old}
    lappend match {}
    lappend match {    if {$ok} continue}
    lappend match {    break}
    lappend match "\}"
    lappend match {}
    lappend match {icl_rewind $pos}
    lappend match {iok_ok}
    lappend match {return}

    # Final assembly

    set pname [NextProc $t pkleene]
    set match [list [Proc $pname [join $match \n]]]
    if {[string length $esupport]} {
	lappend match {}
	lappend match $esupport
    }

    $t set $n MATCH   [Cat "$pname                ; " [Pfx "# " $sexpr]]
    $t set $n SUPPORT [join $match \n]
    $t set $n EXPR    $sexpr
    return
}

proc ::page::gen::peg::me::SynthNode// {t n} {
    set args [$t children $n]

    if {![llength $args]} {
	error "PANIC. Empty choice."

    } elseif {[llength $args] == 1} {
	# A choice over one branch is no real choice. The code
	# generated for the child applies here as well.

	set pe [lindex $args 0]
	$t set $n MATCH   [$t get $pe MATCH]
	$t set $n SUPPORT [$t get $pe SUPPORT]
	return
    }

    # Choice over at least two branches.

    set match   {}
    set support {}
    set sexpr   {}

    lappend match {}
    lappend match {}
    lappend match {variable ok}
    lappend match {}
    lappend match {set pos [icl_get]}
    foreach pe $args {
	lappend match {}

	set ematch   [$t get $pe MATCH]
	set esupport [$t get $pe SUPPORT]
	set eexpr    [$t get $pe EXPR]
	set egen     [$t get $pe gen]

	# Note: We do not check for static match results. Doing so is
	# an optimization we can do earlier, directly on the tree.

	lappend sexpr $eexpr

	if {[string length $esupport]} {
	    lappend support {}
	    lappend support $esupport
	}

	if {$egen} {
	    lappend match "set mrk \[ias_mark\]"
	}

	lappend match "set old \[ier_get\]"
	lappend match $ematch
	lappend match "ier_merge \$old"
	lappend match {}
	lappend match "if \{\$ok\} return"

	if {$egen} {
	    lappend match "ias_pop2mark \$mrk"
	}
	lappend match "icl_rewind   \$pos"
    }
    lappend match {}
    lappend match return

    # Final assembly

    set sexpr "[Cat "(/ " [join $sexpr \n]])"
    set match [linsert $match 1 [Pfx "# " $sexpr]]

    set pname [NextProc $t bra]
    set match [list [Proc $pname [join $match \n]]]
    if {[llength $support]} {
	lappend match {}
	lappend match [join [lrange $support 1 end] \n]
    }

    $t set $n MATCH   [Cat "$pname                ; " [Pfx "# " $sexpr]]
    $t set $n SUPPORT [join $match \n]
    $t set $n EXPR    $sexpr
    return
}

proc ::page::gen::peg::me::SynthNode/x {t n} {
    set args [$t children $n]

    if {![llength $args]} {
	error "PANIC. Empty sequence."

    } elseif {[llength $args] == 1} {
	# A sequence of one element is no real sequence. The code
	# generated for the child applies here as well.

	set pe [lindex $args 0]
	$t set $n MATCH   [$t get $pe MATCH]
	$t set $n SUPPORT [$t get $pe SUPPORT]
	$t set $n EXPR    [$t get $pe EXPRE]
	return
    }

    # Sequence of at least two elements.

    set match   {}
    set support {}
    set sexpr   {}
    set gen     0

    lappend match {}
    lappend match {}
    lappend match {variable ok}
    lappend match {}
    lappend match {set pos [icl_get]}

    foreach pe $args {
	lappend match {}

	set ematch   [$t get $pe MATCH]
	set esupport [$t get $pe SUPPORT]
	set eexpr    [$t get $pe EXPR]
	set egen     [$t get $pe gen]

	lappend sexpr $eexpr

	if {[string length $esupport]} {
	    lappend support {}
	    lappend support $esupport
	}

	if {$egen && !$gen} {
	    # From here on out is the sequence
	    # able to generate semantic values
	    # which have to be canceled when
	    # backtracking.

	    lappend match "set mrk \[ias_mark\]"
	    lappend match {}
	    set gen 1
	}

	lappend match "set old \[ier_get\]"
	lappend match $ematch
	lappend match "ier_merge \$old"
	lappend match {}

	if {$gen} {
	    lappend match "if \{!\$ok\} \{"
	    lappend match "    ias_pop2mark \$mrk"
	    lappend match "    icl_rewind   \$pos"
	    lappend match "    return"
	    lappend match "\}"
	} else {
	    lappend match "if \{!\$ok\} \{icl_rewind \$pos \; return\}"
	}
    }
    lappend match {}
    lappend match return

    # Final assembly

    set sexpr "[Cat "(x " [join $sexpr \n]])"
    set match [linsert $match 1 [Pfx "# " $sexpr]]

    set pname [NextProc $t seq]
    set match [list [Proc $pname [join $match \n]]]
    if {[llength $support]} {
	lappend match {}
	lappend match [join [lrange $support 1 end] \n]
    }

    $t set $n MATCH   [Cat "$pname                ; " [Pfx "# " $sexpr]]
    $t set $n SUPPORT [join $match \n]
    $t set $n EXPR    $sexpr
    return
}

proc ::page::gen::peg::me::SynthNode/& {t n} {
    SynthLookahead $t $n no
    return
}

proc ::page::gen::peg::me::SynthNode/! {t n} {
    SynthLookahead $t $n yes
    return
}

proc ::page::gen::peg::me::SynthNode/dot {t n} {
    SynthTerminal $t $n \
	    "any character" {}
    $t set $n EXPR "(dot)"
    return
}

proc ::page::gen::peg::me::SynthNode/epsilon {t n} {
    $t set $n MATCH   iok_ok
    $t set $n SUPPORT {}
    $t set $n EXPR "(epsilon)"
    return
}

proc ::page::gen::peg::me::SynthNode/alnum {t n} {
    SynthClass $t $n alnum
    return
}

proc ::page::gen::peg::me::SynthNode/alpha {t n} {
    SynthClass $t $n alpha
    return
}

proc ::page::gen::peg::me::SynthNode/.. {t n} {
    # Range is [x-y]

    set b [$t get $n begin]
    set e [$t get $n end]

    set tb [quote'tcl $b]
    set te [quote'tcl $e]

    set pb [quote'tclstr $b]
    set pe [quote'tclstr $e]

    set cb [quote'tclcom $b]
    set ce [quote'tclcom $e]

    SynthTerminal $t $n \
	    "\\\[${pb}..${pe}\\\]" \
	    "ict_match_tokrange $tb $te"
    $t set $n EXPR "(.. $cb $ce)"
    return
}

proc ::page::gen::peg::me::SynthNode/t {t n} {
    # Terminal node. Primitive matching.
    # Code is parameterized by gen(X) of this node X.

    set ch  [$t get $n char]
    set tch [quote'tcl    $ch]
    set pch [quote'tclstr $ch]
    set cch [quote'tclcom $ch]

    SynthTerminal $t $n \
	    $pch \
	    "ict_match_token $tch"
    $t set $n EXPR    "(t $cch)"
    return
}

proc ::page::gen::peg::me::SynthNode/n {t n} {
    # Nonterminal node. Primitive matching.
    # The code is parameterized by acc(X) of this node X, and gen(D)
    # of the invoked nonterminal D.

    set sym   [$t get $n sym]
    set def   [$t get $n def]

    if {$def eq ""} {
	# Invokation of an undefined nonterminal. This will always fail.
	set match "iok_fail ; # Match for undefined symbol '$sym'."
    } else {
	# Combinations
	# Acc Gen Action
	# --- --- ------
	#   0   0 Plain match
	#   0   1 Match with canceling of the semantic value.
	#   1   0 Plain match
	#   1   1 Plain match
	# --- --- ------

	if {[$t get $n acc] || ![$t get $def gen]} {
	    set match [Call $sym]
	} else {
	    set     match {}
	    lappend match "set p$sym \[ias_mark\]"
	    lappend match [Call $sym]
	    lappend match "ias_pop2mark \$p$sym"
	    set match [join $match \n]
	}
    }

    set sexpr "(n $sym)"
    $t set $n EXPR    $sexpr
    $t set $n MATCH   "$match    ; # $sexpr"
    $t set $n SUPPORT {}
    return
}

proc ::page::gen::peg::me::SynthLookahead {t n negated} {
    # Note: Per the rules about expression modes (! is a lookahead
    # ____| operator) this node has a mode of 'discard', and its child
    # ____| has so as well.

    # assert t get n  mode == discard
    # assert t get pe mode == discard

    set op       [$t get $n op]
    set pe       [lindex [$t children $n] 0]
    set eop      [$t get $pe op]
    set ematch   [$t get $pe MATCH]
    set esupport [$t get $pe SUPPORT]
    set eexpr    [$t get $pe EXPR]
    set pname    [NextProc $t bang]

    set     match {}

    if {
	($eop eq "t")     || ($eop eq "..") ||
	($eop eq "alpha") || ($eop eq "alnum")
    } {
	# Required iff !dot
	# Support for terminal expression 
	lappend match {variable ok}
	lappend match {}
    }

    lappend match {set pos [icl_get]}
    lappend match {}
    lappend match $ematch
    lappend match {}
    lappend match {icl_rewind $pos}

    if {$negated} {
	lappend match {iok_negate}
    }

    lappend match return

    set match [list [Proc $pname [join $match \n]]]
    if {[string length $esupport]} {
	lappend match {}
	lappend match $esupport
    }

    $t set $n MATCH   $pname
    $t set $n SUPPORT [join $match \n]
    $t set $n EXPR    "($op $eexpr)"
    return
}

proc ::page::gen::peg::me::SynthClass {t n op} {
    SynthTerminal $t $n \
	    <$op> \
	    "ict_match_tokclass $op"
    $t set $n EXPR ($op)
    return
}

proc ::page::gen::peg::me::SynthTerminal {t n msg cmd} {
    set     match {}
    lappend match "ict_advance \"Expected $msg (got EOF)\""

    if {$cmd ne ""} {
	lappend match "if \{\$ok\} \{$cmd \"Expected $msg\"\}"
    }
    if {[$t get $n gen]} {
	lappend match "if \{\$ok\} isv_terminal"
    }

    $t set $n MATCH   [join $match \n]
    $t set $n SUPPORT {}
    return
}

proc ::page::gen::peg::me::Call {sym} {
    # Generator for proc names (nonterminal symbols).
    return matchSymbol_$sym
}

proc ::page::gen::peg::me::NextProc {t {mark {}}} {
    set  count [$t get root Pcount]
    incr count
    $t set root Pcount $count
    return e$mark$count
}

proc ::page::gen::peg::me::Proc {name body} {
    set     script {}
    lappend script "proc ::@PKG@::$name \{\} \{"
    lappend script [::textutil::indent $body "    "]
    lappend script "\}"
    return [join $script \n]
}

proc ::page::gen::peg::me::Cat {prefix suffix} {
    return "$prefix[textutil::indent $suffix [textutil::blank [string length $prefix]] 1]"
}

proc ::page::gen::peg::me::Pfx {prefix suffix} {
    return [textutil::indent $suffix $prefix]
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::me {

    variable here          [file dirname [info script]]
    variable template_file [file join $here gen_peg_me.template]

    variable ch
    variable template \
	[string trimright [read [set ch [open $template_file r]]][close $ch]]
    unset ch

    variable package   ""
    variable copyright ""
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::me 0.1

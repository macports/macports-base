# peg_to_param.tcl --
#
#	Conversion of PEG to PARAM assembler.
#
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_param.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes the canonical serialization of a parsing
# expression grammar and produces text in PARAM assembler, i.e.
# readable machine code for the PARAM virtual machine.

## NOTE: Should have cheat sheet of PARAM instructions (which parts of
## the arch state they touch, and secondly, bigger effects).

# ### ### ### ######### ######### #########
## Requisites

package  require Tcl 8.5
package  require pt::peg             ; # Verification that the input
				       # is proper.
package  require pt::pe              ; # Walking an expression.
package  require text::write         ; # Text generation support
package  require char

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::to::param {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::param::reset {} {
    variable template @code@
    variable name     a_pe_grammar
    variable file     unknown
    variable user     unknown
    variable inline   1
    variable compact  1
    return
}

proc ::pt::peg::to::param::configure {args} {
    variable template
    variable name
    variable file
    variable user
    variable inline
    variable compact

    if {[llength $args] == 0} {
	return [list \
		    -inline   $inline \
		    -compact  $compact \
		    -file     $file \
		    -name     $name \
		    -template $template \
		    -user     $user]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists $variable]} {
	    return [set $variable]
	} else {
	    return -code error "Expected one of -compact, -file, -inline, -name, -template, or -user, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists $variable]} {
		return -code error "Expected one of -compact, -file, -inline, -name, -template, or -user, got \"$option\""
	    }
	}
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    switch -exact -- $variable {
		template {
		    if {$value eq {}} {
			return -code error "Expected template, got the empty string"
		    }
		}
		inline - compact {
		    if {![::string is boolean -strict $value]} {
			return -code error "Expected boolean, got \"$value\""
		    }
		}
		name -
		file -
		user { }
	    }
	    set $variable $value
	}
    } else {
	return -code error {wrong#args, expected option value ...}
    }
}

proc ::pt::peg::to::param::convert {serial} {
    variable template
    variable name
    variable file
    variable user

    Op::Asm::Setup

    ::pt::peg verify-as-canonical $serial

    # Unpack the serialization, known as canonical
    array set peg $serial
    array set peg $peg(pt::grammar::peg)
    unset     peg(pt::grammar::peg)

    set modes {}
    foreach {symbol def} $peg(rules) {
	lassign $def _ is _ mode
	lappend modes $symbol $mode
    }

    text::write reset
    set blocks {}

    # Translate all expressions/symbols, results are stored in
    # text::write blocks, command results are the block ids.
    lappend blocks [set start [Expression $peg(start) $modes]]

    foreach {symbol def} $peg(rules) {
	lassign $def _ is _ mode
	lappend blocks [Symbol $symbol $mode $is $modes]
    }

    # Assemble the output from the stored blocks.
    text::write clear
    Op::Asm::Header {Grammar Start Expression}
    Op::Asm::Label <<MAIN>>
    Op::Asm::Call $start 0
    Op::Asm::Ins  halt
    text::write /line

    Op::Asm::Use {*}$blocks

    # At last retrieve the fully assembled result and integrate with
    # the chosen template.

    return [string map \
		[list \
		     @user@   $user \
		     @format@ PEG   \
		     @file@   $file \
		     @name@   $name \
		     @code@   [text::write get]] $template]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals

proc ::pt::peg::to::param::Expression {expression modes} {
    return [pt::pe bottomup \
		[list [namespace current]::Op $modes] \
		$expression]
}

proc ::pt::peg::to::param::Symbol {symbol mode rhs modes} {

    set expression [Expression $rhs $modes]

    text::write clear
    Op::Asm::Header "$mode Symbol '$symbol'"
    text::write store FUN_HEADER

    Op::Asm::Start
    Op::Asm::ReExpression $symbol
    Op::Asm::GenAST $expression
    Op::Asm::PE $rhs

    set gen [dict get $result gen]

    Op::Asm::Function sym_$symbol {

	# We have six possibilites for the combination of AST node
	# generation by the rhs and AST generation by the symbol. Two
	# of these (leaf/0, value/0 coincide, leaving 5). This
	# controls the use of AS/ARS instructions.

	switch -exact -- $mode/$gen {
	    value/1 {
		# Generate value for symbol, rhs may have generated
		# AST nodes as well, keep rhs

		set found [Op::Asm::NewLabel found]

		Op::Asm::Ins symbol_restore $symbol
		Op::Asm::Ins found! jump $found

		Op::Asm::Ins loc_push
		Op::Asm::Ins ast_push

		Op::Asm::Call $expression

		Op::Asm::Ins fail! value_clear
		Op::Asm::Ins ok!   value_reduce $symbol

		Op::Asm::Ins symbol_save       $symbol
		Op::Asm::Ins error_nonterminal $symbol

		Op::Asm::Ins ast_pop_rewind
		Op::Asm::Ins loc_pop_discard

		Op::Asm::Label $found
		Op::Asm::Ins ok! ast_value_push
	    }
	    leaf/0 -
	    value/0 {
		# Generate value for symbol, rhs cannot generate its
		# own AST nodes => leaf/0.

		set found [Op::Asm::NewLabel found]

		Op::Asm::Ins symbol_restore $symbol
		Op::Asm::Ins found! jump $found

		Op::Asm::Ins loc_push

		Op::Asm::Call $expression

		Op::Asm::Ins fail! value_clear
		Op::Asm::Ins ok!   value_leaf $symbol

		Op::Asm::Ins symbol_save       $symbol
		Op::Asm::Ins error_nonterminal $symbol

		Op::Asm::Ins loc_pop_discard

		Op::Asm::Label $found
		Op::Asm::Ins ok! ast_value_push
	    }
	    leaf/1 {
		# Generate value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.

		set found [Op::Asm::NewLabel found]

		Op::Asm::Ins symbol_restore $symbol
		Op::Asm::Ins found! jump $found

		Op::Asm::Ins loc_push
		Op::Asm::Ins ast_push

		Op::Asm::Call $expression

		Op::Asm::Ins fail! value_clear
		Op::Asm::Ins ok!   value_leaf   $symbol

		Op::Asm::Ins symbol_save       $symbol
		Op::Asm::Ins error_nonterminal $symbol

		Op::Asm::Ins ast_pop_rewind
		Op::Asm::Ins loc_pop_discard

		Op::Asm::Label $found
		Op::Asm::Ins ok! ast_value_push
	    }
	    void/1 {
		# Generate no value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.

		Op::Asm::Ins symbol_restore $symbol ; # Implied
		Op::Asm::Ins found! return

		Op::Asm::Ins loc_push
		Op::Asm::Ins ast_push

		Op::Asm::Call $expression

		Op::Asm::Ins value_clear

		Op::Asm::Ins symbol_save       $symbol
		Op::Asm::Ins error_nonterminal $symbol

		Op::Asm::Ins ast_pop_rewind
		Op::Asm::Ins loc_pop_discard
	    }
	    void/0 {
		# Generate no value for symbol, rhs cannot generate
		# its own AST nodes. Nothing to save nor discard.

		Op::Asm::Ins symbol_restore $symbol ; # Implied
		Op::Asm::Ins found! return

		Op::Asm::Ins loc_push

		Op::Asm::Call $expression

		Op::Asm::Ins value_clear

		Op::Asm::Ins symbol_save       $symbol
		Op::Asm::Ins error_nonterminal $symbol

		Op::Asm::Ins loc_pop_discard
	    }
	}
    } $expression
    Op::Asm::Done
}

namespace eval ::pt::peg::to::param::Op {
    namespace export \
	alpha alnum ascii digit graph lower print \
	punct space upper wordchar xdigit ddigit \
	dot epsilon t .. n ? * + & ! x / 
}

proc ::pt::peg::to::param::Op {modes pe op arguments} {
    return [namespace eval Op [list $op $modes {*}$arguments]]
}

proc ::pt::peg::to::param::Op::epsilon {modes} {
    Asm::Start
    Asm::ReExpression epsilon
    Asm::Direct {
	Asm::Ins status_ok
    }
    Asm::Done
}

proc ::pt::peg::to::param::Op::dot {modes} {
    Asm::Start
    Asm::ReExpression dot
    Asm::Direct {
	Asm::Ins input_next \"dot\"
    }
    Asm::Done
}

foreach test {
    alpha alnum ascii digit graph lower print
    punct space upper wordchar xdigit ddigit
} {
    proc ::pt::peg::to::param::Op::$test {modes} \
	[string map [list @ $test] {
	    variable ::pt::peg::to::param::inline
	    Asm::Start
	    Asm::ReExpression @
	    if {$inline} {
		Asm::Direct {
		    Asm::Ins input_next \"@\"
		    Asm::Ins ok! test_@
		}
	    } else {
		Asm::Function [Asm::NewBlock @] {
		    Asm::Ins input_next \"@\"
		    Asm::Ins ok! test_@
		}
	    }
	    Asm::Done
	}]
}

proc ::pt::peg::to::param::Op::t {modes char} {
    variable ::pt::peg::to::param::inline
    Asm::Start
    Asm::ReTerminal t $char
    if {$inline} {
	Asm::Direct {
	    set c [char quote string $char]

	    Asm::Ins input_next "\"t $c\""
	    Asm::Ins ok! test_char \"$c\"
	}
    } else {
	Asm::Function [Asm::NewBlock char ] {
	    set c [char quote string $char]

	    Asm::Ins input_next "\"t $c\""
	    Asm::Ins ok! test_char \"$c\"
	}
    }
    Asm::Done
}

proc ::pt::peg::to::param::Op::.. {modes chstart chend} {
    variable ::pt::peg::to::param::inline
    Asm::Start
    Asm::ReTerminal .. $chstart $chend
    if {$inline} {
	Asm::Direct {
	    set s [char quote string $chstart]
	    set e [char quote string $chend]

	    Asm::Ins input_next "\".. $s $e\""
	    Asm::Ins ok! test_range \"$s\" \"$e\"
	}
    } else {
	Asm::Function [Asm::NewBlock range] {
	    set s [char quote string $chstart]
	    set e [char quote string $chend]

	    Asm::Ins input_next "\".. $s $e\""
	    Asm::Ins ok! test_range \"$s\" \"$e\"
	}
    }
    Asm::Done
}

proc ::pt::peg::to::param::Op::n {modes symbol} {
    # symbol mode determines AST generation
    # void       => non-generative,
    # leaf/value => generative.

    Asm::Start
    Asm::ReTerminal n $symbol

    if {![dict exists $modes $symbol]} {
	# Incomplete grammar. The symbol has no definition.
	Asm::Direct {
	    Asm::Ins status_fail {} "; # Undefined symbol '$symbol'"
	}
    } else {
	Asm::GenAST [list gen [expr { [dict get $modes $symbol] ne "void" }]]
	Asm::Direct {
	    Asm::Ins call sym_$symbol
	}
    }
    Asm::Done
}

proc ::pt::peg::to::param::Op::& {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use = consistent and simple.

    Asm::Start
    Asm::ReExpression & $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock ahead] {
	Asm::Ins loc_push
	Asm::Call $expression
	Asm::Ins loc_pop_rewind
    } $expression
    Asm::Done
}

proc ::pt::peg::to::param::Op::! {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use = consistent and simple.

    Asm::Start
    Asm::ReExpression ! $expression
    if {[dict get $expression gen]} {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression may generate AST elements. We must
	    # not pass them through.

	    Asm::Ins loc_push
	    Asm::Ins ast_push

	    Asm::Call $expression

	    Asm::Ins fail! ast_pop_discard
	    Asm::Ins ok!   ast_pop_rewind
	    Asm::Ins loc_pop_rewind
	    Asm::Ins status_negate
	} $expression
    } else {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression cannot generate AST elements. We can
	    # ignore AS/ARS, simplifying the code.

	    Asm::Ins loc_push

	    Asm::Call $expression

	    Asm::Ins loc_pop_rewind
	    Asm::Ins status_negate
	} $expression
    }
    Asm::Done
}

proc ::pt::peg::to::param::Op::? {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use => consistent and simple.

    Asm::Start
    Asm::ReExpression ? $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock optional] {
	Asm::Ins loc_push
	Asm::Ins error_push

	Asm::Call $expression

	Asm::Ins error_pop_merge
	Asm::Ins fail! loc_pop_rewind
	Asm::Ins ok!   loc_pop_discard
	Asm::Ins status_ok
    } $expression
    Asm::Done
}

proc ::pt::peg::to::param::Op::* {modes expression} {
    Asm::Start
    Asm::ReExpression * $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock kleene] {
	set failed [Asm::NewLabel failed]

	Asm::Ins loc_push
	Asm::Ins error_push

	Asm::Call $expression

	Asm::Ins error_pop_merge
	Asm::Ins fail! jump $failed
	Asm::Ins loc_pop_discard
	Asm::Ins jump [Asm::LastId] ; # Loop head = Function head.

	# FAILED, clean up and return OK.
	Asm::Label $failed
	Asm::Ins loc_pop_rewind
	Asm::Ins status_ok
    } $expression
    Asm::Done
}

proc ::pt::peg::to::param::Op::+ {modes expression} {
    Asm::Start
    Asm::ReExpression + $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock poskleene] {
	set failed   [Asm::NewLabel failed]
	set loophead [Asm::NewLabel loop]

	Asm::Ins loc_push

	Asm::Call $expression

	# FAILED truly.
	Asm::Ins fail! jump $failed

	Asm::Label $loophead
	Asm::Ins loc_pop_discard
	Asm::Ins loc_push
	Asm::Ins error_push

	Asm::Call $expression

	Asm::Ins error_pop_merge
	Asm::Ins ok! jump $loophead
	# FAILED, clean up and return OK.
	Asm::Ins status_ok

	Asm::Label $failed
	Asm::Ins loc_pop_rewind
    } $expression
    Asm::Done
}

proc ::pt::peg::to::param::Op::x {modes args} {
    if {[llength $args] == 1} {
	return [lindex $args 0]
    }

    Asm::Start
    Asm::ReExpression x {*}$args
    set gens [Asm::GenAST {*}$args]

    # We have three possibilities regarding AST node generation, each
    # requiring a slightly different instruction sequence.

    # i.  gen     == 0  <=> No node generation at all.
    # ii. gens[0] == 1  <=> We may have nodes from the beginning.
    # iii.              <=> Node generation starts in the middle.

    if {![dict get $result gen]} {
	set mode none
    } elseif {[lindex $gens 0]} {
	set mode all
    } else {
	set mode some
    }

    Asm::Function [Asm::NewBlock sequence] {

	set failed [Asm::NewLabel failed]
	if {$mode eq "some"} {
	    set failed_noast [Asm::NewLabel failednoast]
	}

	switch -exact -- $mode {
	    none {
		# (Ad i) No AST node generation at all.

		Asm::Ins loc_push
		Asm::Ins error_clear
		text::write /line

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		foreach expression $args {
		    Asm::Ins error_push

		    Asm::Call $expression

		    Asm::Ins error_pop_merge
		    # Stop the sequence on element failure
		    Asm::Ins fail! jump $failed
		}

		# All elements OK, squash backtracking state
		text::write /line
		Asm::Ins loc_pop_discard
		Asm::Ins return

		# An element failed, restore state to before we tried
		# the sequence.
		Asm::Label $failed
		Asm::Ins loc_pop_rewind
	    }
	    all {
		# (Ad ii) AST node generation from start to end.

		Asm::Ins ast_push
		Asm::Ins loc_push
		Asm::Ins error_clear
		text::write /line

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		foreach expression $args {
		    Asm::Ins error_push

		    Asm::Call $expression

		    Asm::Ins error_pop_merge
		    # Stop the sequence on element failure
		    Asm::Ins fail! jump $failed
		}

		# All elements OK, squash backtracking state
		text::write /line
		Asm::Ins ast_pop_discard
		Asm::Ins loc_pop_discard
		Asm::Ins return

		# An element failed, restore state to before we tried
		# the sequence.
		Asm::Label $failed
		Asm::Ins ast_pop_rewind
		Asm::Ins loc_pop_rewind
	    }
	    some {
		# (Ad iii). Start without AST nodes, later parts do
		# AST nodes.

		Asm::Ins loc_push
		Asm::Ins error_clear
		text::write /line

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		set pushed 0
		foreach expression $args xgen $gens {
		    if {!$pushed && $xgen} {
			Asm::Ins ast_push
			set pushed 1
		    }

		    Asm::Ins error_push

		    Asm::Call $expression

		    Asm::Ins error_pop_merge
		    # Stop the sequence on element failure
		    if {$pushed} {
			Asm::Ins fail! jump $failed
		    } else {
			Asm::Ins fail! jump $failed_noast
		    }
		}

		# All elements OK, squash backtracking state.
		text::write /line
		Asm::Ins ast_pop_discard
		Asm::Ins loc_pop_discard
		Asm::Ins return

		# An element failed, restore state to before we tried
		# the sequence.
		Asm::Label $failed
		Asm::Ins ast_pop_rewind
		Asm::Label $failed_noast
		Asm::Ins loc_pop_rewind
	    }
	}
    } {*}$args
    Asm::Done
}

proc ::pt::peg::to::param::Op::/ {modes args} {
    if {[llength $args] == 1} {
	return [lindex $args 0]
    }

    Asm::Start
    Asm::ReExpression / {*}$args
    set gens [Asm::GenAST {*}$args]

    if {![dict get $result genmin]} {
	# We have at least one branch without AST node generation.
	set ok_noast [Asm::NewLabel oknoast]
    } else {
	set ok_noast {}
    }
    if {[dict get $result gen]} {
	# We have at least one branch capable of generating AST nodes.
	set ok [Asm::NewLabel ok]
    } else {
	set ok {}
    }

    # Optimized AST handling: Handle each branch separately, based on
    # its ability to generate AST nodes.

    Asm::Function [Asm::NewBlock choice] {
	Asm::Ins error_clear
	text::write /line

	# Note: This loop runs at code generation time. At runtime the
	# entire construction is seentially a fully unrolled loop,
	# with each iteration having its own block of instructions.

	foreach expression $args xgen $gens {
	    if {$xgen} {
		Asm::Ins ast_push
	    }
	    Asm::Ins loc_push
	    Asm::Ins error_push

	    Asm::Call $expression

	    Asm::Ins error_pop_merge
	    if {$xgen} {
		Asm::Ins ok! jump $ok
	    } else {
		Asm::Ins ok! jump $ok_noast
	    }
	    text::write /line
	    if {$xgen} {
		Asm::Ins ast_pop_rewind
	    }
	    Asm::Ins loc_pop_rewind
	}

	# All branches FAILED
	Asm::Ins status_fail
	Asm::Ins return

	# A branch was successful, squash the backtracking state
	if {$ok ne {}} {
	    Asm::Label $ok
	    Asm::Ins ast_pop_discard
	}
	if {$ok_noast ne {}} {
	    Asm::Label $ok_noast
	}
	Asm::Ins loc_pop_discard
    } {*}$args
    Asm::Done
}

# ### ### ### ######### ######### #########
## Allocate a text block / internal symbol / function

namespace eval ::pt::peg::to::param::Op::Asm {}

proc ::pt::peg::to::param::Op::Asm::Start {} {
    upvar 1 result result
    set result {def {} use {} gen 0 pe {}}
    return
}

proc ::pt::peg::to::param::Op::Asm::Done {} {
    upvar 1 result result
    return -code return $result
    return
}

proc ::pt::peg::to::param::Op::Asm::ReExpression {op args} {
    upvar 1 result result

    set pe $op
    foreach a $args {
	lappend pe [dict get $a pe]
    }

    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::param::Op::Asm::ReTerminal {op args} {
    upvar 1 result result

    set pe [linsert $args 0 $op]
    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::param::Op::Asm::GenAST {args} {
    upvar 1 result result

    foreach a $args {
	lappend flags [dict get $a gen]
    }

    dict set result gen    [tcl::mathfunc::max {*}$flags]
    dict set result genmin [tcl::mathfunc::min {*}$flags]
    return $flags
}

proc ::pt::peg::to::param::Op::Asm::NewBlock {type} {
    variable counter
    variable lastid ${type}_[incr counter]
    return $lastid
}

proc ::pt::peg::to::param::Op::Asm::NewLabel {{prefix {label}}} {
    variable counter
    return ${prefix}_[incr counter]
}

proc ::pt::peg::to::param::Op::Asm::Function {name def args} {
    upvar 1 result result
    variable ::pt::peg::to::param::compact
    variable cache

    set k [list [dict get $result gen] [dict get $result pe]]

#puts $name///<<$k>>==[info exists cache($k)]\t\t($result)

    if {$compact && [info exists cache($k)]} {
	dict set result def {}
	dict set result use $cache($k)
	return
    }

    text::write clear
    if {[text::write exists FUN_HEADER]} {
	text::write recall FUN_HEADER
	text::write undef  FUN_HEADER
    }

    Label $name
    text::write recall PE ; # Generated in Asm::Zip, printed rep
    text::write undef  PE ; # of the expression, for code clarity

    uplevel 1 $def
    Ins return

    if {[llength $args]} {
	Use {*}$args
    }

    text::write store $name

    set useb [NewBlock anon]
    text::write clear
    Ins call $name
    text::write store $useb

    dict set result def $name
    dict set result use $useb

    set cache($k) $useb
    return
}

proc ::pt::peg::to::param::Op::Asm::Direct {use} {
    upvar 1 result result

    set useb [NewBlock anon]
    text::write clear
    uplevel 1 $use
    text::write store $useb

    dict set result def {}
    dict set result use $useb
    return
}

proc ::pt::peg::to::param::Op::Asm::Call {expr {distance 1}} {
    if {$distance} { text::write /line }
    text::write recall [dict get $expr use]
    if {$distance} { text::write /line }
    return
}

proc ::pt::peg::to::param::Op::Asm::Use {args} {
    foreach item $args {
	set def [dict get $item def]
	if {$def eq {}} continue
	text::write recall $def
	text::write undef  $def
    }
    return
}

proc ::pt::peg::to::param::Op::Asm::Ins {args} {
    variable fieldlen

    if {[string match *! [lindex $args 0]]} {
	set args [lassign $args guard]
	text::write fieldr 8 $guard
    } else {
	text::write fieldr 8 {}
    }
    foreach w $args len $fieldlen {
	text::write fieldl $len $w
    }
    text::write /line
    return
}

proc ::pt::peg::to::param::Op::Asm::Label {label} {
    text::write /line
    text::write field ${label}:
    text::write /line
    return
}

proc ::pt::peg::to::param::Op::Asm::LastId {} {
    variable lastid
    return $lastid
}

proc ::pt::peg::to::param::Op::Asm::Header {text} {
    text::write field "#"
    text::write /line
    text::write field "# $text"
    text::write /line
    text::write field "#"
    text::write /line
    #text::write /line
    return
}

proc ::pt::peg::to::param::Op::Asm::PE {pe} {
    text::write clear
    text::write field [pt::pe print $pe]
    text::write /line
    text::write prefix "# "
    text::write /line
    text::write store PE
    return
}

proc ::pt::peg::to::param::Op::Asm::Setup {} {
    variable counter 0
    variable fieldlen {17 5 5}
    variable cache
    array unset cache *
    return
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::param {
    namespace eval ::pt::peg::to::param::Op::Asm {
	variable counter 0
	variable fieldlen {17 5 5}
	variable  cache
	array set cache {}
    }

    variable inline   1            ; # A boolean flag. Specifies if we
				     # should inline terminal tests
				     # (default), or put them into
				     # their own functions.
    variable compact  1            ; # A boolean flag. Specifies if we
				     # should try to coalesce
				     # identical parsing expressions,
				     # i.e. compile them once
				     # (default), or not.
    variable template @code@       ; # A string. Specifies how to
				     # embed the generated code into a
				     # larger frame- work (the
				     # template).
    variable name     a_pe_grammar ; # String. Name of the grammar.
    variable file     unknown      ; # String. Name of the file or
				     # other entity the grammar came
				     # from.
    variable user     unknown      ; # String. Name of the user on
				     # which behalf the conversion has
				     # been invoked.
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::to::param 1.0.1
return

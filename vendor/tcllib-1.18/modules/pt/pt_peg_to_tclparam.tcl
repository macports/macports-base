# peg_to_param.tcl --
#
#	Conversion of PEG to Tcl/C PARAM, customizable text blocks.
#
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_tclparam.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

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
package  require pt::pe::op          ; # String/Class fusing
package  require text::write         ; # Text generation support
package  require char

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::to::tclparam {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::tclparam::reset {} {
    variable template @code@
    variable name     a_pe_grammar
    variable file     unknown
    variable user     unknown
    variable self     {}
    variable ns       ::
    variable runtime  {}
    variable def      proc
    variable main     __main
    variable indent   0
    variable prelude  {}
    return
}

proc ::pt::peg::to::tclparam::configure {args} {
    variable template
    variable name
    variable file
    variable user
    variable self
    variable ns
    variable runtime
    variable def
    variable main
    variable omap
    variable indent
    variable prelude

    if {[llength $args] == 0} {
	return [list \
		    -indent          $indent \
		    -runtime-command $runtime \
		    -self-command    $self \
		    -proc-command    $def \
		    -namespace       $ns \
		    -main            $main \
		    -file            $file \
		    -name            $name \
		    -template        $template \
		    -user            $user]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists omap($variable)]} {
	    return [set $omap($variable)]
	} else {
	    return -code error "Expected one of -indent, -runtime-command, -proc-command, -self-command, -namespace, -main, -file, -name, -template, or -user, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists omap($variable)]} {
		return -code error "Expected one of -indent, -runtime-command, -proc-command, -self-command, -namespace, -main, -file, -name, -template, or -user, got \"$option\""
	    }
	}
	foreach {option value} $args {
	    set variable $omap([string range $option 1 end])
	    switch -exact -- $variable {
		template {
		    if {$value eq {}} {
			return -code error "Expected template, got the empty string"
		    }
		}
		indent {
		    if {![string is integer -strict $value] || ($value < 0)} {
			return -code error "Expected int > 0, got \"$value\""
		    }
		}
		runtime -
		self -
		def -
		ns -
		main -
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

proc ::pt::peg::to::tclparam::convert {serial} {
    variable template
    variable name
    variable file
    variable user
    variable self
    variable ns
    variable runtime
    variable def
    variable main
    variable indent
    variable prelude

    Op::Asm::Setup

    ::pt::peg verify-as-canonical $serial

    # Unpack the serialization, known as canonical
    array set peg $serial
    array set peg $peg(pt::grammar::peg)
    unset     peg(pt::grammar::peg)

    set modes {}
    foreach {symbol symdef} $peg(rules) {
	lassign $symdef _ is _ mode
	lappend modes $symbol $mode
    }

    text::write reset
    set blocks {}

    # Translate all expressions/symbols, results are stored in
    # text::write blocks, command results are the block ids.

    set start [pt::pe::op flatten \
		   [pt::pe::op fusechars \
			[pt::pe::op flatten \
			     $peg(start)]]]

    lappend blocks [set start [Expression $start $modes]]

    foreach {symbol symdef} $peg(rules) {
	lassign $symdef _ is _ mode
	set is [pt::pe::op flatten \
		    [pt::pe::op fusechars \
			 [pt::pe::op flatten \
			      $is]]]
	lappend blocks [Symbol $symbol $mode $is $modes]
    }

    # Assemble the output from the stored blocks.
    text::write clear
    Op::Asm::Header {Grammar Start Expression}
    Op::Asm::FunStart @main@
    Op::Asm::Call $start 0
    Op::Asm::Tcl return
    Op::Asm::FunClose

    foreach b $blocks {
	Op::Asm::Use $b
	text::write /line
    }

    # At last retrieve the fully assembled result and integrate with
    # the chosen template.

    set code [text::write get]
    if {$indent} {
	set code [Indent $code $indent]
    }

    set pre $prelude ; if {$pre ne {}} { set pre " $pre" }
    set run $runtime ; if {$run ne {}} { append run { } }
    set slf $self    ; if {$slf ne {}} { append slf { } }

    set code [string map \
		  [list \
		       @user@   $user \
		       @format@ Tcl/PARAM   \
		       @file@   $file \
		       @name@   $name \
		       @code@   $code] $template]
    set code [string map \
		  [list \
		       {@runtime@ } $run \
		       { @prelude@} $pre \
		       {@self@ }    $slf \
		       @def@     $def \
		       @ns@      $ns   \
		       @main@    $main] $code]

    return $code
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals

proc ::pt::peg::to::tclparam::Indent {text n} {
    set b [string repeat { } $n]
    return $b[join [split $text \n] \n$b]
}

proc ::pt::peg::to::tclparam::Expression {expression modes} {
    # We first flatten for a maximum amount of adjacent terminals and
    # ranges, then fuse these into strings and classes, then flatten
    # again, eliminating all sequences and choices fully subsumed by
    # the new elements.

    return [pt::pe bottomup \
		[list [namespace current]::Op $modes] \
		$expression]
}

proc ::pt::peg::to::tclparam::Symbol {symbol mode rhs modes} {

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

		#Op::Asm::Tcl if \{!\[@runtime@ i_symbol_restore $symbol\]\} \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins i_loc_push
		#Op::Asm::Ins i_ast_push

		Op::Asm::Ins si:value_symbol_start $symbol
		Op::Asm::Call $expression
		Op::Asm::Ins si:reduce_symbol_end $symbol

		#Op::Asm::Ins i_value_clear/reduce $symbol
		#Op::Asm::Ins i_symbol_save       $symbol
		#Op::Asm::Ins i_error_nonterminal $symbol
		#Op::Asm::Ins i_ast_pop_rewind
		#Op::Asm::Ins i_loc_pop_discard
		#Op::Asm::<<< 4
		#Op::Asm::Tcl \}
		#Op::Asm::Ins i:ok_ast_value_push
	    }
	    leaf/0 -
	    value/0 {
		# Generate value for symbol, rhs cannot generate its
		# own AST nodes => leaf/0.

		#Op::Asm::Tcl if \{!\[@runtime@ i_symbol_restore $symbol\]\} \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins i_loc_push

		Op::Asm::Ins si:void_symbol_start $symbol
		Op::Asm::Call $expression
		Op::Asm::Ins si:void_leaf_symbol_end $symbol

		#Op::Asm::Ins i_value_clear/leaf $symbol
		#Op::Asm::Ins i_symbol_save       $symbol
		#Op::Asm::Ins i_error_nonterminal $symbol
		#Op::Asm::Ins i_loc_pop_discard
		#Op::Asm::<<< 4
		#Op::Asm::Tcl \}
		#Op::Asm::Ins i:ok_ast_value_push
	    }
	    leaf/1 {
		# Generate value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.

		#Op::Asm::Tcl if \{!\[@runtime@ i_symbol_restore $symbol\]\} \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins i_loc_push
		#Op::Asm::Ins i_ast_push

		Op::Asm::Ins si:value_symbol_start $symbol
		Op::Asm::Call $expression
		Op::Asm::Ins si:value_leaf_symbol_end $symbol

		#Op::Asm::Ins i_value_clear/leaf   $symbol
		#Op::Asm::Ins i_symbol_save       $symbol
		#Op::Asm::Ins i_error_nonterminal $symbol
		#Op::Asm::Ins i_ast_pop_rewind
		#Op::Asm::Ins i_loc_pop_discard
		#Op::Asm::<<< 4
		#Op::Asm::Tcl \}
		#Op::Asm::Ins i:ok_ast_value_push
	    }
	    void/1 {
		# Generate no value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.
		# // test case missing //

		#Op::Asm::Tcl if \{!\[@runtime@ i_symbol_restore $symbol\]\} \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins i_loc_push
		#Op::Asm::Ins i_ast_push

		Op::Asm::Ins si:value_void_symbol_start $symbol
		Op::Asm::Call $expression
		Op::Asm::Ins si:value_clear_symbol_end $symbol

		#Op::Asm::Ins i_value_clear
		#Op::Asm::Ins i_symbol_save       $symbol
		#Op::Asm::Ins i_error_nonterminal $symbol
		#Op::Asm::Ins i_ast_pop_rewind
		#Op::Asm::Ins i_loc_pop_discard
		#Op::Asm::<<< 4
		#Op::Asm::Tcl \}
	    }
	    void/0 {
		# Generate no value for symbol, rhs cannot generate
		# its own AST nodes. Nothing to save nor discard.

		#Op::Asm::Tcl if \{!\[@runtime@ i_symbol_restore $symbol\]\} \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins i_loc_push

		Op::Asm::Ins si:void_void_symbol_start $symbol
		Op::Asm::Call $expression
		Op::Asm::Ins si:void_clear_symbol_end $symbol

		#Op::Asm::Ins i_value_clear
		#Op::Asm::Ins i_symbol_save       $symbol
		#Op::Asm::Ins i_error_nonterminal $symbol
		#Op::Asm::Ins i_loc_pop_discard
		#Op::Asm::<<< 4
		#Op::Asm::Tcl \}
	    }
	}
    } $expression
    Op::Asm::Done
}

namespace eval ::pt::peg::to::tclparam::Op {
    namespace export \
	alpha alnum ascii control digit graph lower print \
	punct space upper wordchar xdigit ddigit \
	dot epsilon t .. n ? * + & ! x / str cl
}

proc ::pt::peg::to::tclparam::Op {modes pe op arguments} {
    return [namespace eval Op [list $op $modes {*}$arguments]]
}

proc ::pt::peg::to::tclparam::Op::epsilon {modes} {
    Asm::Start
    Asm::ReExpression epsilon
    Asm::Direct {
	Asm::Ins i_status_ok
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::dot {modes} {
    Asm::Start
    Asm::ReExpression dot
    Asm::Direct {
	Asm::Ins i_input_next dot
    }
    Asm::Done
}

foreach test {
    alpha alnum ascii control digit graph lower print
    punct space upper wordchar xdigit ddigit
} {
    proc ::pt::peg::to::tclparam::Op::$test {modes} \
	[string map [list @ $test] {
	    Asm::Start
	    Asm::ReExpression @
	    Asm::Direct {
		#Asm::Ins i_input_next @
		#Asm::Ins i:fail_return
		#Asm::Ins i_test_@

		Asm::Ins si:next_@
	    }
	    Asm::Done
	}]
}

proc ::pt::peg::to::tclparam::Op::t {modes char} {
    Asm::Start
    Asm::ReTerminal t $char
    Asm::Direct {
	set char [char quote tcl $char]

	#Asm::Ins i_input_next "\{t $char\}"
	#Asm::Ins i:fail_return
	#Asm::Ins i_test_char $char

	Asm::Ins si:next_char $char
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::.. {modes chs che} {
    Asm::Start
    Asm::ReTerminal .. $chs $che
    Asm::Direct {
	set chs [char quote tcl $chs]
	set che [char quote tcl $che]

	#Asm::Ins i_input_next "\{.. $chs $che\}"
	#Asm::Ins i:fail_return
	#Asm::Ins i_test_range $chs $che

	Asm::Ins si:next_range $chs $che
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::str {modes args} {
    Asm::Start
    Asm::ReTerminal str {*}$args
    Asm::Direct {
	# Without fusing this would be rendered as a sequence of
	# characters, with associated stack churn for each character/part
	# (See Op::x, void/all).

	set str [join $args {}]
	set str [char quote tcl $str]

	Asm::Ins si:next_str $str
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::cl {modes args} {
    # rorc = Range-OR-Char-List
    Asm::Start
    Asm::ReTerminal cl {*}$args
    Asm::Direct {
	# Without fusing this would be rendered as a choice of
	# characters, with associated stack churn for each
	# character/branch (See Op::/, void/all).

	set cl [join [Ranges {*}$args] {}]
	set cl [char quote tcl $cl]

	Asm::Ins si:next_class $cl
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::Ranges {args} {
    set res {}
    foreach rorc $args { lappend res [Range $rorc] }
    return $res
}

proc ::pt::peg::to::tclparam::Op::Range {rorc} {
    # See also pt::peg::to::peg

    # We use string ops here to distinguish terminals and ranges. The
    # input can be a single char, not a list, and further the char may
    # not be a proper list. Example: double-apostroph.
    if {[string length $rorc] > 1} {
	lassign $rorc s e

	# The whole range is expanded into its full set of characters.
	# Beware, this may blow the process if the range tries to
	# match a substantial part of the unicode character set. We
	# should see if there is a way to keep it encoded as range
	# without giving up on the fast matching.

	set s [scan $s %c]
	set e [scan $e %c]

	set res {}
	for {set i $s} {$i <= $e} {incr i} {
	    append res [format %c $i]
	}
	return $res
    } else {
	return $rorc ;#[char quote tcl $rorc]
    }
}

proc ::pt::peg::to::tclparam::Op::n {modes symbol} {
    # symbol mode determines AST generation
    # void       => non-generative,
    # leaf/value => generative.

    Asm::Start
    Asm::ReTerminal n $symbol

    if {![dict exists $modes $symbol]} {
	# Incomplete grammar. The symbol has no definition.
	Asm::Direct {
	    Asm::Ins i_status_fail "; # Undefined symbol '$symbol'"
	}
    } else {
	Asm::GenAST [list gen [expr { [dict get $modes $symbol] ne "void" }]]
	Asm::Direct {
	    Asm::Self sym_$symbol
	}
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::& {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use = consistent and simple.

    Asm::Start
    Asm::ReExpression & $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock ahead] {
	Asm::Ins i_loc_push
	Asm::Call $expression
	Asm::Ins i_loc_pop_rewind
    } $expression
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::! {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use = consistent and simple.

    Asm::Start
    Asm::ReExpression ! $expression
    if {[dict get $expression gen]} {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression may generate AST elements. We must
	    # not pass them through.

	    #Asm::Ins i_loc_push
	    #Asm::Ins i_ast_push

	    Asm::Ins si:value_notahead_start

	    Asm::Call $expression

	    #Asm::Ins i_ast_pop_discard/rewind
	    #Asm::Ins i_loc_pop_rewind
	    #Asm::Ins i_status_negate

	    Asm::Ins si:value_notahead_exit
	} $expression
    } else {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression cannot generate AST elements. We can
	    # ignore AS/ARS, simplifying the code.

	    Asm::Ins i_loc_push

	    Asm::Call $expression

	    #Asm::Ins i_loc_pop_rewind
	    #Asm::Ins i_status_negate

	    Asm::Ins si:void_notahead_exit
	} $expression
    }
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::? {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use => consistent and simple.

    Asm::Start
    Asm::ReExpression ? $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock optional] {
	#Asm::Ins i_loc_push
	#Asm::Ins i_error_push

	Asm::Ins si:void2_state_push

	Asm::Call $expression

	#Asm::Ins i_error_pop_merge
	#Asm::Ins i_loc_pop_rewind/discard
	#Asm::Ins i_status_ok

	Asm::Ins si:void_state_merge_ok
    } $expression
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::* {modes expression} {
    Asm::Start
    Asm::ReExpression * $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock kleene] {
	Asm::Tcl while \{1\} \{
	Asm::>>> 4
	#Asm::Ins i_loc_push
	#Asm::Ins i_error_push

	Asm::Ins si:void2_state_push

	Asm::Call $expression

	#Asm::Ins i_error_pop_merge
	#Asm::Ins i_loc_pop_rewind/discard
	#Asm::Ins i:fail_status_ok
	#Asm::Tcl i:fail_return

	Asm::Ins si:kleene_close
	Asm::<<< 4
	Asm::Tcl \}
	# FAILED, clean up and return OK.
    } $expression
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::+ {modes expression} {
    Asm::Start
    Asm::ReExpression + $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock poskleene] {
	Asm::Ins i_loc_push

	Asm::Call $expression

	#Asm::Ins i_loc_pop_rewind/discard
	#Asm::Ins i:fail_return

	Asm::Ins si:kleene_abort

	Asm::Tcl while \{1\} \{
	Asm::>>> 4
	#Asm::Ins i_loc_push
	#Asm::Ins i_error_push

	Asm::Ins si:void2_state_push

	Asm::Call $expression

	#Asm::Ins i_error_pop_merge
	#Asm::Ins i_loc_pop_rewind/discard
	#Asm::Ins i:ok_continue
	#Asm::Tcl break

	Asm::Ins si:kleene_close
	Asm::<<< 4
	Asm::Tcl \}
	# FAILED, clean up and return OK.
	#Asm::Ins i_status_ok

    } $expression
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::x {modes args} {
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
	switch -exact -- $mode {
	    none {
		# (Ad i) No AST node generation at all.

		Asm::xinit0

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		foreach expression [lrange $args 0 end-1] {
		    Asm::Call $expression
		    Asm::xinter00
		}
		Asm::Call [lindex $args end]
		Asm::xexit0
	    }
	    all {
		# (Ad ii) AST node generation from start to end.

		Asm::xinit1

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		foreach expression [lrange $args 0 end-1] {
		    Asm::Call $expression
		    Asm::xinter11
		}
		Asm::Call [lindex $args end]
		Asm::xexit1
	    }
	    some {
		# (Ad iii). Start without AST nodes, later parts do
		# AST nodes.

		Asm::xinit0

		# Note: This loop runs at code generation time. At
		# runtime the entire construction is essentially a
		# fully unrolled loop, with each iteration having its
		# own block of instructions.

		set pushed 0
		foreach expression [lrange $args 0 end-1] xgen [lrange $gens 1 end] {
		    Asm::Call $expression
		    if {!$pushed && $xgen} {
			Asm::xinter01
			set pushed 1
			continue
		    }
		    if {$pushed} {
			Asm::xinter11
		    } else {
			Asm::xinter00
		    }
		}
		Asm::Call [lindex $args end]
		Asm::xexit1
	    }
	}
    } {*}$args
    Asm::Done
}

proc ::pt::peg::to::tclparam::Op::/ {modes args} {
    if {[llength $args] == 1} {
	return [lindex $args 0]
    }

    Asm::Start
    Asm::ReExpression / {*}$args
    set gens [Asm::GenAST {*}$args]

    # Optimized AST handling: Handle each branch separately, based on
    # its ability to generate AST nodes.

    Asm::Function [Asm::NewBlock choice] {
	set xgen [lindex $gens 0]
	Asm::/init$xgen

	# Note: This loop runs at code generation time. At runtime the
	# entire construction is essentially a fully unrolled loop,
	# with each iteration having its own block of instructions.

	foreach expression [lrange $args 0 end-1] nxgen [lrange $gens 1 end] {
	    Asm::Call $expression
	    Asm::/inter$xgen$nxgen
	    set xgen $nxgen
	}

	Asm::Call [lindex $args end]
	Asm::/exit$nxgen

    } {*}$args
    Asm::Done
}

# ### ### ### ######### ######### #########
## Assembler commands

namespace eval ::pt::peg::to::tclparam::Op::Asm {}

# ### ### ### ######### ######### #########
## The various part of a sequence compilation.

proc ::pt::peg::to::tclparam::Op::Asm::xinit0 {} {
    #Ins i_loc_push
    #Ins i_error_clear_push

    Ins si:void_state_push
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xinit1 {} {
    #Ins i_ast_push
    #Ins i_loc_push
    #Ins i_error_clear_push

    Ins si:value_state_push
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xinter00 {} {
    #Ins i_error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #Ins i:fail_loc_pop_rewind
    #Ins i:fail_return
    #Ins i_error_push

    Ins si:voidvoid_part
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xinter01 {} {
    #Ins i_error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #Ins i:fail_loc_pop_rewind
    #Ins i:fail_return
    #Ins i_ast_push
    #Ins i_error_push

    Ins si:voidvalue_part
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xinter11 {} {
    #Ins i_error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #Ins i:fail_ast_pop_rewind
    #Ins i:fail_loc_pop_rewind
    #Ins i:fail_return
    #Ins i_error_push

    Ins si:valuevalue_part
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xexit0 {} {
    #Ins i_error_pop_merge
    #Ins i_loc_pop_rewind/discard
    #Ins i:fail_return

    Ins si:void_state_merge
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::xexit1 {} {
    #Ins i_error_pop_merge
    #Ins i_ast_pop_rewind/discard
    #Ins i_loc_pop_rewind/discard
    #Ins i:fail_return

    Ins si:value_state_merge
    return
}

# ### ### ### ######### ######### #########
## The various part of a choice compilation.

proc ::pt::peg::to::tclparam::Op::Asm::/init0 {} {
    #Ins i_loc_push
    #Ins i_error_clear_push

    Ins si:void_state_push
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/init1 {} {
    #Ins i_ast_push
    #Ins i_loc_push
    #Ins i_error_clear_push

    Ins si:value_state_push
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/inter00 {} {
    #Ins i_error_pop_merge
    # A branch was successful, squash the backtracking state
    #Ins i:ok_loc_pop_discard
    #Ins i:ok_return
    #Ins i_loc_rewind
    #Ins i_error_push

    Ins si:voidvoid_branch
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/inter01 {} {
    #Ins i_error_pop_merge
    # A branch was successful, squash the backtracking state
    #Ins i:ok_loc_pop_discard
    #Ins i:ok_return
    #Ins i_ast_push
    #Ins i_loc_rewind
    #Ins i_error_push

    Ins si:voidvalue_branch
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/inter10 {} {
    #Ins i_error_pop_merge
    #Ins i_ast_pop_rewind/discard
    # A branch was successful, squash the backtracking state
    #Ins i:ok_loc_pop_discard
    #Ins i:ok_return
    #Ins i_loc_rewind
    #Ins i_error_push

    Ins si:valuevoid_branch
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/inter11 {} {
    #Ins i_error_pop_merge
    # A branch was successful, squash the backtracking state
    #Ins i:ok_ast_pop_discard
    #Ins i:ok_loc_pop_discard
    #Ins i:ok_return
    #Ins i_ast_rewind
    #Ins i_loc_rewind
    #Ins i_error_push

    Ins si:valuevalue_branch
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/exit0 {} {
    #Ins i_error_pop_merge
    #Ins i_loc_pop_rewind/discard

    Ins si:void_state_merge

    # Note: on ok we return, on fail, we .. set to fail ... The last
    # is unnecessary. Which then makes the conditional return also
    # irrelevant.

    # A branch was successful, squash the backtracking state
    #Ins i:ok_return

    # All branches FAILED
    #text::write /line
    #Ins i_status_fail
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::/exit1 {} {
    #Ins i_error_pop_merge
    #Ins i_ast_pop_rewind/discard
    #Ins i_loc_pop_rewind/discard

    Ins si:value_state_merge

    # Note: on ok we return, on fail, we .. set to fail ... The last
    # is unnecessary. Which then makes the conditional return also
    # irrelevant.

    # A branch was successful, squash the backtracking state
    #Ins i:ok_return

    # All branches FAILED
    #text::write /line
    #Ins i_status_fail
    return
}

# ### ### ### ######### ######### #########
## Allocate a text block / internal symbol / function

proc ::pt::peg::to::tclparam::Op::Asm::Start {} {
    upvar 1 result result
    set result {def {} use {} gen 0 pe {}}
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Done {} {
    upvar 1 result result
    return -code return $result
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::ReExpression {op args} {
    upvar 1 result result

    set pe $op
    foreach a $args {
	lappend pe [dict get $a pe]
    }

    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::ReTerminal {op args} {
    upvar 1 result result

    set pe [linsert $args 0 $op]
    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::GenAST {args} {
    upvar 1 result result

    foreach a $args {
	lappend flags [dict get $a gen]
    }

    dict set result gen    [tcl::mathfunc::max {*}$flags]
    dict set result genmin [tcl::mathfunc::min {*}$flags]
    return $flags
}

proc ::pt::peg::to::tclparam::Op::Asm::NewBlock {type} {
    variable counter
    variable lastid ${type}_[incr counter]
    return $lastid
}

proc ::pt::peg::to::tclparam::Op::Asm::Function {name def args} {
    upvar 1 result result
    variable cache

    set k [list [dict get $result gen] [dict get $result pe]]

    # Hardcoded 'compact == 1', compare "pt_peg_to_param.tcl"
    if {[info exists cache($k)]} {
	dict set result def {}
	dict set result use $cache($k)
	return
    }

    text::write clear
    if {[text::write exists FUN_HEADER]} {
	text::write recall FUN_HEADER
	text::write undef  FUN_HEADER
    }

    FunStart $name

    text::write recall PE ; # Generated in Asm::ReExpression, printed
    text::write undef  PE ; # representation of the expression, to
			    # make the generated code more readable.
    uplevel 1 $def
    Tcl return

    FunClose

    if {[llength $args]} {
	Use {*}$args
    }

    text::write store $name

    set useb [NewBlock anon]
    text::write clear
    Self $name
    text::write store $useb

    dict set result def $name
    dict set result use $useb

    set cache($k) $useb
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Direct {use} {
    upvar 1 result result

    set useb [NewBlock anon]
    text::write clear
    uplevel 1 $use
    text::write store $useb

    dict set result def {}
    dict set result use $useb
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Call {expr {distance 1}} {
    #if {$distance} { text::write /line }

    text::write recall [dict get $expr use]

    #if {$distance} { text::write /line }
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Use {args} {
    foreach item $args {
	set def [dict get $item def]
	if {$def eq {}} continue
	text::write recall $def
	text::write undef  $def
    }
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::FunStart {name} {
    text::write /line
    text::write field @def@ @ns@$name \{\} \{ @prelude@
    text::write /line
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::FunClose {} {
    text::write field \}
    text::write /line
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Ins {args} {
    Tcl @runtime@ {*}$args
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Self {args} {
    Tcl @self@ {*}$args
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::>>> {n} {
    variable field
    incr field $n
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::<<< {n} {
    variable field
    incr field -$n
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Tcl {args} {
    variable field
    text::write fieldl $field {}
    text::write field {*}$args
    text::write /line
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Header {text} {
    text::write field "#"
    text::write /line
    text::write field "# $text"
    text::write /line
    text::write field "#"
    text::write /line
    #text::write /line
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::PE {pe} {
    text::write clear
    text::write field [pt::pe print $pe]
    text::write /line
    text::write prefix "    # "
    text::write /line
    text::write store PE
    return
}

proc ::pt::peg::to::tclparam::Op::Asm::Setup {} {
    variable counter 0
    variable field 3
    variable cache
    array unset cache *
    return
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::tclparam {
    namespace eval ::pt::peg::to::tclparam::Op::Asm {
	variable counter 0
	variable fieldlen {17 5 5}
	variable field 3
	variable  cache
	array set cache {}
    }

    variable omap ; array set omap {
	runtime-command runtime
	self-command    self
	proc-command    def
	namespace       ns
	main            main
	file            file
	name            name
	template        template
	user            user
	indent          indent
	prelude         prelude
    }

    variable self     {}
    variable ns       ::
    variable runtime  {}
    variable def      proc
    variable main     __main
    variable indent   0
    variable prelude  {}

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

package provide pt::peg::to::tclparam 1.0.3
return

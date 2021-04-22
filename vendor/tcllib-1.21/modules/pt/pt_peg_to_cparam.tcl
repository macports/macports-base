# peg_to_param.tcl --
#
#	Conversion of PEG to C PARAM, customizable text blocks.
#
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_cparam.tcl,v 1.2 2010/04/07 19:40:54 andreas_kupries Exp $

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

namespace eval ::pt::peg::to::cparam {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::cparam::reset {} {
    variable insertcmd {}             ; # -insert-command (hook)
    variable template  @code@         ; # -template
    variable name      a_pe_grammar   ; # -name
    variable file      unknown        ; # -file
    variable user      unknown        ; # -user
    variable self      {}             ; # -self-command
    variable ns        {}             ; # -namespace
    variable def       static         ; # -fun-qualifier
    variable main      __main         ; # -main
    variable indent    0              ; # -indent
    variable comments  1              ; # -comments
    variable prelude   {}             ; # -prelude
    variable statedecl {RDE_PARAM p}  ; # -state-decl
    variable stateref  {p}            ; # -state-ref
    variable strings   p_string       ; # -string-varname
    return
}

proc ::pt::peg::to::cparam::configure {args} {
    variable template
    variable name
    variable file
    variable user
    variable self
    variable ns
    variable def
    variable main
    variable omap
    variable indent
    variable insertcmd
    variable comments
    variable prelude
    variable statedecl
    variable stateref
    variable strings

    if {[llength $args] == 0} {
	return [list \
		    -comments        $comments \
		    -file            $file \
		    -fun-qualifier   $def \
		    -indent          $indent \
		    -insert-command  $insertcmd \
		    -main            $main \
		    -name            $name \
		    -namespace       $ns \
		    -self-command    $self \
		    -state-decl      $statedecl \
		    -state-ref       $stateref \
		    -string-varname  $strings \
		    -template        $template \
		    -user            $user \
		   ]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists omap($variable)]} {
	    return [set $omap($variable)]
	} else {
	    # TODO: compute this string dynamically.
	    return -code error "Expected one of -comments, -file, -fun-qualifier, -indent, -insert-cmd, -main, -name, -namespace, -self-command, -state-decl, -state-ref, -string-varname, -template, or -user, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists omap($variable)]} {
		# TODO: compute this string dynamically.
		return -code error "Expected one of -comments, -file, -fun-qualifier, -indent, -insert-cmd, -main, -name, -namespace, -self-command, -state-decl, -state-ref, -string-varname, -template, or -user, got \"$option\""
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
		comments {
		    if {![string is boolean -strict $value]} {
			return -code error "Expected boolean, got \"$value\""
		    }
		}
		insert-cmd -
		statedecl -
		stateref -
		strings -
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

proc ::pt::peg::to::cparam::convert {serial} {
    variable Op::Asm::cache
    variable template
    variable name
    variable file
    variable user
    variable self
    variable ns
    variable def
    variable main
    variable indent
    variable insertcmd
    variable prelude
    variable statedecl
    variable stateref
    variable strings

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

    # Fixed elements of the string table as needed by the lower level
    # PARAM functions (class tests, see param.c, enum test_class).
    # ** Keep in sync **
    #
    # Maybe move the interning into the lower level, i.e. PARAM ?

    Op::Asm::String alnum
    Op::Asm::String alpha
    Op::Asm::String ascii
    Op::Asm::String control
    Op::Asm::String ddigit
    Op::Asm::String digit
    Op::Asm::String graph
    Op::Asm::String lower
    Op::Asm::String print
    Op::Asm::String punct
    Op::Asm::String space
    Op::Asm::String upper
    Op::Asm::String wordchar
    Op::Asm::String xdigit

    Op::Asm::Header {Declaring the parse functions}
    text::write /line
    text::write store FORWARD

    text::write clear
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
    text::write recall FORWARD
    text::write /line

    Op::Asm::Header {Precomputed table of strings (symbols, error messages, etc.).}
    text::write /line
    set n [llength $cache(_strings)]
    text::write field static char const* @strings@ \[$n\] = \{
    text::write /line
    foreach s [lrange $cache(_strings) 0 end-1] {
	text::write field "   " ${s},
	text::write /line
    }
    text::write field "   " [lindex $cache(_strings) end]
    text::write /line
    text::write field \}\;
    text::write /line
    text::write /line

    Op::Asm::Header {Grammar Start Expression}
    Op::Asm::FunStart @main@
    Op::Asm::Call $start 0
    Op::Asm::CStmt return
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

    set xprelude $prelude ; if {$xprelude ne {}} { set xprelude " $xprelude" }
    set xself    $self    ; if {$xself    ne {}} { append xself { } }

    # I. run code through the insertcmd hook (if specified) to prepare it for embedding
    if {[llength $insertcmd]} {
	set code [{*}$insertcmd $code]
    }

    # II. Phase 1 merge of code into the template.
    #     (Placeholders only in the template)
    lappend map @user@   $user
    lappend map @format@ C/PARAM
    lappend map @file@   $file
    lappend map @name@   $name
    lappend map @code@   $code
    set code [string map $map $template]
    unset map

    # III. Phase 2 merge of code into the template.
    #      (Placeholders in generated code, and template).
    lappend map @statedecl@  $statedecl
    lappend map @stateref@   $stateref
    lappend map @strings@    $strings
    lappend map { @prelude@} $xprelude
    lappend map {@self@ }    $xself
    lappend map @def@        $def
    lappend map @ns@         $ns
    lappend map @main@       $main
    set code [string map $map $code]

    return $code
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals

proc ::pt::peg::to::cparam::Indent {text n} {
    set b [string repeat { } $n]
    return $b[join [split $text \n] \n$b]
}

proc ::pt::peg::to::cparam::Expression {expression modes} {
    return [pt::pe bottomup \
		[list [namespace current]::Op $modes] \
		$expression]
}

proc ::pt::peg::to::cparam::Symbol {symbol mode rhs modes} {
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
	# Message is Tcl list. Quote for C embedding.
	set msg    [Op::Asm::String [char quote cstring [list n $symbol]]]
	# Quote for C embedding.
	set symbol [Op::Asm::String [char quote cstring $symbol]]

	# We have six possibilites for the combination of AST node
	# generation by the rhs and AST generation by the symbol. Two
	# of these (leaf/0, value/0 coincide, leaving 5). This
	# controls the use of AS/ARS instructions.

	switch -exact -- $mode/$gen {
	    value/1 {
		# Generate value for symbol, rhs may have generated
		# AST nodes as well, keep rhs

		Op::Asm::CBlock if (rde_param_i_symbol_start_d (@stateref@, $symbol)) return \;
		Op::Asm::Call $expression
		Op::Asm::Ins symbol_done_d_reduce $symbol $msg

		#Op::Asm::CBlock if (!rde_param_i_symbol_restore (@stateref@, $symbol)) \{
		#Op::Asm::>>> 4

		#Op::Asm::Ins loc_push
		#Op::Asm::Ins ast_push

		#Op::Asm::Call $expression

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_reduce $symbol
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \} else \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_clear
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::Ins symbol_save        $symbol
		#Op::Asm::Ins error_nonterminal  $symbol

		#Op::Asm::Ins ast_pop_rewind
		#Op::Asm::Ins loc_pop_discard

		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins ast_value_push
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}
	    }
	    leaf/0 -
	    value/0 {
		# Generate value for symbol, rhs cannot generate its
		# own AST nodes => leaf/0.

		Op::Asm::CBlock if (rde_param_i_symbol_start (@stateref@, $symbol)) return \;
		Op::Asm::Call $expression
		Op::Asm::Ins symbol_done_leaf $symbol $msg

		#Op::Asm::CBlock if (!rde_param_i_symbol_restore (@stateref@, $symbol)) \{
		#Op::Asm::>>> 4

		#Op::Asm::Ins loc_push

		#Op::Asm::Call $expression

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_leaf $symbol
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \} else \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_clear
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::Ins symbol_save       $symbol
		#Op::Asm::Ins error_nonterminal $symbol

		#Op::Asm::Ins loc_pop_discard

		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins ast_value_push
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}
	    }
	    leaf/1 {
		# Generate value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.

		Op::Asm::CBlock if (rde_param_i_symbol_start_d (@stateref@, $symbol)) return \;
		Op::Asm::Call $expression
		Op::Asm::Ins symbol_done_d_leaf $symbol $msg

		#Op::Asm::CBlock if (!rde_param_i_symbol_restore (@stateref@, $symbol)) \{
		#Op::Asm::>>> 4

		#Op::Asm::Ins loc_push
		#Op::Asm::Ins ast_push

		#Op::Asm::Call $expression

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_leaf $symbol
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \} else \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins value_clear
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::Ins symbol_save       $symbol
		#Op::Asm::Ins error_nonterminal $symbol

		#Op::Asm::Ins ast_pop_rewind
		#Op::Asm::Ins loc_pop_discard

		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}

		#Op::Asm::CBlock if (rde_param_query_st(@stateref@)) \{
		#Op::Asm::>>> 4
		#Op::Asm::Ins ast_value_push
		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}
	    }
	    void/1 {
		# Generate no value for symbol, rhs may have generated
		# AST nodes as well, discard rhs.
		# // test case missing //

		Op::Asm::CBlock if (rde_param_i_symbol_void_start_d (@stateref@, $symbol)) return \;
		Op::Asm::Call $expression
		Op::Asm::Ins symbol_done_d_void $symbol $msg

		#Op::Asm::CBlock if (!rde_param_i_symbol_restore (@stateref@, $symbol)) \{
		#Op::Asm::>>> 4

		#Op::Asm::Ins loc_push
		#Op::Asm::Ins ast_push

		#Op::Asm::Call $expression

		#Op::Asm::Ins value_clear

		#Op::Asm::Ins symbol_save       $symbol
		#Op::Asm::Ins error_nonterminal $symbol

		#Op::Asm::Ins ast_pop_rewind
		#Op::Asm::Ins loc_pop_discard

		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}
	    }
	    void/0 {
		# Generate no value for symbol, rhs cannot generate
		# its own AST nodes. Nothing to save nor discard.

		Op::Asm::CBlock if (rde_param_i_symbol_void_start (@stateref@, $symbol)) return \;
		Op::Asm::Call $expression
		Op::Asm::Ins symbol_done_void $symbol $msg

		#Op::Asm::CBlock if (!rde_param_i_symbol_restore (@stateref@, $symbol)) \{
		#Op::Asm::>>> 4

		#Op::Asm::Ins loc_push

		#Op::Asm::Call $expression

		#Op::Asm::Ins value_clear

		#Op::Asm::Ins symbol_save       $symbol
		#Op::Asm::Ins error_nonterminal $symbol

		#Op::Asm::Ins loc_pop_discard

		#Op::Asm::<<< 4
		#Op::Asm::CBlock \}
	    }
	}
    } $expression
    Op::Asm::Done
}

namespace eval ::pt::peg::to::cparam::Op {
    namespace export \
	alpha alnum ascii control digit graph lower print \
	punct space upper wordchar xdigit ddigit \
	dot epsilon t .. n ? * + & ! x / 
}

proc ::pt::peg::to::cparam::Op {modes pe op arguments} {
    return [namespace eval Op [list $op $modes {*}$arguments]]
}

proc ::pt::peg::to::cparam::Op::epsilon {modes} {
    Asm::Start
    Asm::ReExpression epsilon
    Asm::Direct {
	Asm::Ins status_ok
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::dot {modes} {
    Asm::Start
    Asm::ReExpression dot
    Asm::Direct {
	Asm::Ins input_next [Asm::String dot]
    }
    Asm::Done
}

foreach test {
    alpha alnum ascii control digit graph lower print
    punct space upper wordchar xdigit ddigit
} {
    proc ::pt::peg::to::cparam::Op::$test {modes} \
	[string map [list @OP@ $test] {
	    Asm::Start
	    Asm::ReExpression @OP@
	    Asm::Direct {
		set m [Asm::String @OP@]
		#Asm::Ins input_next [Asm::String @OP@]
		#Asm::CStmt if (!rde_param_query_st(@stateref@)) return
		#Asm::Ins test_@OP@
		Asm::Ins next_@OP@ $m
	    }
	    Asm::Done
	}]
}

proc ::pt::peg::to::cparam::Op::t {modes char} {
    Asm::Start
    Asm::ReTerminal t $char
    Asm::Direct {
	# Message is Tcl list. Quote for C embedding.
	set msg  [Asm::String [char quote cstring [list t $char]]]
	# Quote for C embedding.
	set char [char quote cstring $char]

	#Asm::Ins input_next $msg
	#Asm::CStmt if (!rde_param_query_st(@stateref@)) return
	#Asm::Ins test_char \"$char\" $msg
	Asm::Ins next_char \"$char\" $msg
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::.. {modes chs che} {
    Asm::Start
    Asm::ReTerminal .. $chs $che
    Asm::Direct {
	# Message is Tcl list. Quote for C embedding.
	set msg [Asm::String [char quote cstring [list .. $chs $che]]]

	# Quote for C embedding
	set chs [char quote cstring $chs]
	set che [char quote cstring $che]

	#Asm::Ins input_next $msg
	#Asm::CStmt if (!rde_param_query_st(@stateref@)) return
	#Asm::Ins test_range \"$chs\" \"$che\" $msg
	Asm::Ins next_range \"$chs\" \"$che\" $msg
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::str {modes args} {
    Asm::Start
    Asm::ReTerminal str {*}$args
    Asm::Direct {
	set str [join $args {}]
	# Message is Tcl list. Quote for C embedding.
	set msg [Asm::String [char quote cstring [list str $str]]]
	# Quote for C embedding
	set str [char quote cstring $str]

	# Without fusing this would be rendered as a sequence of
	# characters, with associated stack churn for each
	# character/part (See Op::x, void/all).

	Asm::Ins next_str \"$str\" $msg
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::cl {modes args} {
    # rorc = Range-OR-Char-List
    Asm::Start
    Asm::ReTerminal cl {*}$args
    Asm::Direct {
	# Without fusing this would be rendered as a choice of
	# characters, with associated stack churn for each
	# character/branch (See Op::/, void/all).

	set cl  [join [Ranges {*}$args] {}]
	# Message is Tcl list. Quote for C embedding.
	set msg [Asm::String [char quote cstring [list cl $cl]]]
	# Quote for C embedding
	set cl  [char quote cstring $cl]

	Asm::Ins next_class \"$cl\" $msg
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::Ranges {args} {
    set res {}
    foreach rorc $args { lappend res [Range $rorc] }
    return $res
}

proc ::pt::peg::to::cparam::Op::Range {rorc} {
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

proc ::pt::peg::to::cparam::Op::n {modes symbol} {
    # symbol mode determines AST generation
    # void       => non-generative,
    # leaf/value => generative.

    Asm::Start
    Asm::ReTerminal n $symbol

    if {![dict exists $modes $symbol]} {
	# Incomplete grammar. The symbol has no definition.
	Asm::Direct {
	    Asm::CStmt "/* Undefined symbol '$symbol' */"
	    Asm::Ins status_fail
	}
    } else {
	Asm::GenAST [list gen [expr { [dict get $modes $symbol] ne "void" }]]
	Asm::Direct {
	    Asm::Self sym_$symbol
	}
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::& {modes expression} {
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

proc ::pt::peg::to::cparam::Op::! {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use = consistent and simple.

    Asm::Start
    Asm::ReExpression ! $expression
    if {[dict get $expression gen]} {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression may generate AST elements. We must
	    # not pass them through.

	    #Asm::Ins loc_push
	    #Asm::Ins ast_push

	    Asm::Ins notahead_start_d
	    Asm::Call $expression
	    Asm::Ins notahead_exit_d

	    #Asm::CBlock if (rde_param_query_st(@stateref@)) \{
	    #Asm::>>> 4
	    #Asm::Ins ast_pop_rewind
	    #Asm::<<< 4
	    #Asm::CBlock \} else \{
	    #Asm::>>> 4
	    #Asm::Ins ast_pop_discard
	    #Asm::<<< 4
	    #Asm::CBlock \}

	    #Asm::Ins loc_pop_rewind
	    #Asm::Ins status_negate
	} $expression
    } else {
	Asm::Function [Asm::NewBlock notahead] {
	    # The sub-expression cannot generate AST elements. We can
	    # ignore AS/ARS, simplifying the code.

	    Asm::Ins loc_push
	    Asm::Call $expression
	    Asm::Ins notahead_exit

	    #Asm::Ins loc_pop_rewind
	    #Asm::Ins status_negate
	} $expression
    }
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::? {modes expression} {
    # Note: This operation could be inlined, as it has no special
    #       control flow. Not done to make the higher-level ops are
    #       similar in construction and use => consistent and simple.

    Asm::Start
    Asm::ReExpression ? $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock optional] {
	#Asm::Ins loc_push
	#Asm::Ins error_push

	Asm::Ins state_push_2
	Asm::Call $expression
	Asm::Ins state_merge_ok

	#Asm::Ins error_pop_merge

	#Asm::CBlock if (rde_param_query_st(@stateref@)) \{
	#Asm::>>> 4
	#Asm::Ins loc_pop_discard
	#Asm::<<< 4
	#Asm::CBlock \} else \{
	#Asm::>>> 4
	#Asm::Ins loc_pop_rewind
	#Asm::<<< 4
	#Asm::CBlock \}

	#Asm::Ins status_ok
    } $expression
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::* {modes expression} {
    Asm::Start
    Asm::ReExpression * $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock kleene] {
	Asm::CBlock while (1) \{
	Asm::>>> 4
	#Asm::Ins loc_push
	#Asm::Ins error_push

	Asm::Ins state_push_2
	Asm::Call $expression
	Asm::CStmt if (rde_param_i_kleene_close(@stateref@)) return

	#Asm::Ins error_pop_merge

	#Asm::CStmt if (!rde_param_query_st(@stateref@)) break
	#Asm::Ins loc_pop_discard
	Asm::<<< 4
	Asm::CBlock \}
	# FAILED, clean up and return OK.
	#text::write /line
	#Asm::Ins loc_pop_rewind
	#Asm::Ins status_ok
    } $expression
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::+ {modes expression} {
    Asm::Start
    Asm::ReExpression + $expression
    Asm::GenAST $expression

    Asm::Function [Asm::NewBlock poskleene] {
	Asm::Ins loc_push
	Asm::Call $expression
	Asm::CStmt if (rde_param_i_kleene_abort(@stateref@)) return

	#Asm::CStmt if (!rde_param_query_st(@stateref@)) goto error
	#Asm::Ins loc_pop_discard
	#text::write /line

	Asm::CBlock while (1) \{
	Asm::>>> 4
	#Asm::Ins loc_push
	#Asm::Ins error_push

	Asm::Ins state_push_2
	Asm::Call $expression
	Asm::CStmt if (rde_param_i_kleene_close(@stateref@)) return

	#Asm::Ins error_pop_merge

	#Asm::CStmt if (!rde_param_query_st(@stateref@)) break
	#Asm::Ins loc_pop_discard
	Asm::<<< 4
	Asm::CBlock \}
	# FAILED, clean up and return OK.
	#text::write /line
	#Asm::Ins status_ok
	#Asm::CLabel error
	#Asm::Ins loc_pop_rewind
    } $expression
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::x {modes args} {
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
			#Asm::xinter11 error_pushed
			Asm::xinter11
		    } else {
			Asm::xinter00
		    }
		}
		Asm::Call [lindex $args end]
		#Asm::xexit1a
		Asm::xexit1
	    }
	}
    } {*}$args
    Asm::Done
}

proc ::pt::peg::to::cparam::Op::/ {modes args} {
    if {[llength $args] == 1} {
	return [lindex $args 0]
    }

    Asm::Start
    Asm::ReExpression / {*}$args
    set gens [Asm::GenAST {*}$args]

    # Optimized AST handling: Handle each branch separately, based on
    # its ability to generate AST nodes.

    Asm::Function [Asm::NewBlock choice] {
	set hasxgen   0
	set hasnoxgen 0
	if {[tcl::mathfunc::max {*}$gens]}  { set hasxgen   1 }
	if {![tcl::mathfunc::min {*}$gens]} { set hasnoxgen 1 }

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
	Asm::/exit$nxgen;#[expr {$nxgen ? $hasnoxgen : $hasxgen }]

    } {*}$args
    Asm::Done
}

# ### ### ### ######### ######### #########
## Assembler commands

namespace eval ::pt::peg::to::cparam::Op::Asm {}

# ### ### ### ######### ######### #########
## The various part of a sequence compilation.
proc ::pt::peg::to::cparam::Op::Asm::xinit0 {} {
    #Ins loc_push
    #Ins error_clear
    #text::write /line
    #Ins error_push

    Ins state_push_void
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xinit1 {} {
    #Ins ast_push
    #Ins loc_push
    #Ins error_clear
    #text::write /line
    #Ins error_push

    Ins state_push_value
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xinter00 {} {
    #Ins error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #CStmt if (!rde_param_query_st(@stateref@)) goto error
    #Ins error_push

    CStmt if (rde_param_i_seq_void2void(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xinter01 {} {
    #Ins error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #CStmt if (!rde_param_query_st(@stateref@)) goto error
    #Ins ast_push
    #Ins error_push

    CStmt if (rde_param_i_seq_void2value(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xinter11 {{label error}} {
    #Ins error_pop_merge
    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.
    #CStmt if (!rde_param_query_st(@stateref@)) goto $label
    #Ins error_push

    CStmt if (rde_param_i_seq_value2value(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xexit0 {} {
    #Ins error_pop_merge

    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.

    #CStmt if (!rde_param_query_st(@stateref@)) goto error

    # All elements OK, squash backtracking state
    #text::write /line
    #Ins loc_pop_discard
    #CStmt   return

    #CLabel error
    #Ins loc_pop_rewind

    Ins state_merge_void
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xexit1 {} {
    #Ins error_pop_merge

    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.

    #CStmt if (!rde_param_query_st(@stateref@)) goto error

    # All elements OK, squash backtracking state
    #text::write /line
    #Ins ast_pop_discard
    #Ins loc_pop_discard
    #CStmt   return

    #CLabel error
    #Ins ast_pop_rewind
    #Ins loc_pop_rewind

    Ins state_merge_value
    return
}

proc ::pt::peg::to::cparam::Op::Asm::xexit1a {} { error deprecated/illegal-to-call
    Ins error_pop_merge

    # Stop the sequence on element failure, and
    # restore state to before we tried the sequence.

    CStmt if (!rde_param_query_st(@stateref@)) goto error_pushed

    # All elements OK, squash backtracking state
    text::write /line
    Ins ast_pop_discard
    Ins loc_pop_discard
    CStmt   return

    CLabel error_pushed
    Ins ast_pop_rewind
    CLabel error
    Ins loc_pop_rewind
    return
}

# ### ### ### ######### ######### #########
## The various part of a choice compilation.

proc ::pt::peg::to::cparam::Op::Asm::/init0 {} {
    #Ins error_clear
    #text::write /line
    #Ins loc_push
    #Ins error_push

    Ins state_push_void
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/init1 {} {
    #Ins error_clear
    #text::write /line
    #Ins ast_push
    #Ins loc_push
    #Ins error_push

    Ins state_push_value
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/inter00 {} {
    #Ins error_pop_merge
    #CStmt if (rde_param_query_st(@stateref@)) goto ok
    #Ins loc_pop_rewind
    #Ins loc_push
    #Ins error_push

    CStmt if (rde_param_i_bra_void2void(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/inter01 {} {
    #Ins error_pop_merge
    #CStmt if (rde_param_query_st(@stateref@)) goto ok
    #Ins loc_pop_rewind
    #Ins ast_push
    #Ins loc_push
    #Ins error_push

    CStmt if (rde_param_i_bra_void2value(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/inter10 {} {
    #Ins error_pop_merge
    #CStmt if (rde_param_query_st(@stateref@)) goto ok_xgen
    #Ins ast_pop_rewind
    #Ins loc_pop_rewind
    #Ins ast_push ??-wrong
    #Ins loc_push
    #Ins error_push

    CStmt if (rde_param_i_bra_value2void(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/inter11 {} {
    #Ins error_pop_merge
    #CStmt if (rde_param_query_st(@stateref@)) goto ok_xgen
    #Ins ast_pop_rewind
    #Ins loc_pop_rewind
    #Ins ast_push
    #Ins loc_push
    #Ins error_push

    CStmt if (rde_param_i_bra_value2value(@stateref@)) return
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/exit0 {} {
    Ins state_merge_void
}

proc ::pt::peg::to::cparam::Op::Asm::/exit1 {} {
    Ins state_merge_value
}

proc ::pt::peg::to::cparam::Op::Asm::/exit00 {} { error deprecated
    Ins error_pop_merge

    CStmt if (rde_param_query_st(@stateref@)) goto ok

    Ins loc_pop_rewind

    # All branches FAILED
    text::write /line
    Ins status_fail
    CStmt   return

    CLabel ok
    Ins loc_pop_discard
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/exit01 {} { error deprecated
    Ins error_pop_merge

    CStmt if (rde_param_query_st(@stateref@)) goto ok

    Ins loc_pop_rewind

    # All branches FAILED
    text::write /line
    Ins status_fail
    CStmt   return

    CLabel ok_xgen
    Ins ast_pop_discard
    CLabel ok
    Ins loc_pop_discard
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/exit10 {} { error deprecated
    Ins error_pop_merge

    CStmt if (rde_param_query_st(@stateref@)) goto ok_xgen
    Ins ast_pop_rewind

    Ins loc_pop_rewind

    # All branches FAILED
    text::write /line
    Ins status_fail
    CStmt   return

    CLabel ok_xgen
    Ins ast_pop_discard

    Ins loc_pop_discard
    return
}

proc ::pt::peg::to::cparam::Op::Asm::/exit11 {} { error deprecated
    Ins error_pop_merge

    CStmt if (rde_param_query_st(@stateref@)) goto ok_xgen
    Ins ast_pop_rewind

    Ins loc_pop_rewind

    # All branches FAILED
    text::write /line
    Ins status_fail
    CStmt   return

    CLabel ok_xgen
    Ins ast_pop_discard

    CLabel ok
    Ins loc_pop_discard
    return
}

# ### ### ### ######### ######### #########
## Allocate a text block / internal symbol / function

proc ::pt::peg::to::cparam::Op::Asm::Start {} {
    upvar 1 result result
    set result {def {} use {} gen 0 pe {}}
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Done {} {
    upvar 1 result result
    return -code return $result
    return
}

proc ::pt::peg::to::cparam::Op::Asm::ReExpression {op args} {
    upvar 1 result result

    set pe $op
    foreach a $args {
	lappend pe [dict get $a pe]
    }

    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::cparam::Op::Asm::ReTerminal {op args} {
    upvar 1 result result

    set pe [linsert $args 0 $op]
    dict set result pe $pe
    PE $pe
    return
}

proc ::pt::peg::to::cparam::Op::Asm::GenAST {args} {
    upvar 1 result result

    foreach a $args {
	lappend flags [dict get $a gen]
    }

    dict set result gen    [tcl::mathfunc::max {*}$flags]
    dict set result genmin [tcl::mathfunc::min {*}$flags]
    return $flags
}

proc ::pt::peg::to::cparam::Op::Asm::NewBlock {type} {
    variable counter
    variable lastid ${type}_[incr counter]
    return $lastid
}

proc ::pt::peg::to::cparam::Op::Asm::Function {name def args} {
    upvar 1 result result
    variable cache
    variable field

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

    # Comment at function start.
    text::write recall PE ; # Generated in Asm::ReExpression, printed
    text::write undef  PE ; # representation of the expression, to
			    # make the generated code more readable.
    uplevel 1 $def
    CStmt return

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

proc ::pt::peg::to::cparam::Op::Asm::Direct {use} {
    variable field
    upvar 1 result result

    set useb [NewBlock anon]
    text::write clear

    set saved $field
    set field 0

    uplevel 1 $use

    text::write store $useb

    set field $saved

    dict set result def {}
    dict set result use $useb
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Call {expr {distance 1}} {
    variable field
    #if {$distance} { text::write /line }

    set id [dict get $expr use]

    text::write store CURRENT
    text::write clear
    text::write recall $id
    text::write indent $field
    text::write store CALL

    text::write clear
    text::write recall CURRENT
    text::write recall CALL

    text::write undef CURRENT
    text::write undef CALL

    #if {$distance} { text::write /line }
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Use {args} {
    foreach item $args {
	set def [dict get $item def]
	if {$def eq {}} continue
	text::write recall $def
	text::write undef  $def
    }
    return
}

proc ::pt::peg::to::cparam::Op::Asm::FunStart {name} {
    text::write /line
    text::write field @def@ void @ns@$name (@statedecl@) \{ @prelude@
    text::write /line
    text::write store CURRENT

    text::write clear
    text::write recall FORWARD
    text::write field @def@ void @ns@$name (@statedecl@)\;
    text::write /line
    text::write store FORWARD

    text::write clear
    text::write recall CURRENT
    return
}

proc ::pt::peg::to::cparam::Op::Asm::FunClose {} {
    text::write field \}
    text::write /line
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Ins {args} {
    set args [lassign $args name]
    CStmt rde_param_i_$name ([join [linsert $args 0 @stateref@] {, }])
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Self {args} {
    variable field
    set args [lassign $args name]
    set saved $field
    set field 0
    CStmt @self@ @ns@$name ([join [linsert $args 0 @stateref@] {, }])
    set field $saved
    return
}

proc ::pt::peg::to::cparam::Op::Asm::>>> {n} {
    variable field
    incr field $n
    return
}

proc ::pt::peg::to::cparam::Op::Asm::<<< {n} {
    variable field
    incr field -$n
    return
}

proc ::pt::peg::to::cparam::Op::Asm::CLabel {name} {
    text::write /line
    <<< 2
    CBlock ${name}:
    >>> 2
    return
}

proc ::pt::peg::to::cparam::Op::Asm::CStmt {args} {
    variable field

    # Note: The lreplace/lindex dance appends a ; to the last element
    #       in the list, closing the statement.

    text::write fieldl $field {}
    text::write field {*}[lreplace $args end end [lindex $args end]\;]
    text::write /line
    return
}

proc ::pt::peg::to::cparam::Op::Asm::CBlock {args} {
    variable field
    text::write fieldl $field {}
    text::write field {*}$args
    text::write /line
    return
}

proc ::pt::peg::to::cparam::Op::Asm::Header {text} {
    text::write field "/*"
    text::write /line
    text::write field " * $text"
    text::write /line
    text::write field " */"
    text::write /line
    #text::write /line
    return
}

proc ::pt::peg::to::cparam::Op::Asm::PE {pe} {
    variable ::pt::peg::to::cparam::comments

    text::write clear
    if {$comments} {
	text::write field "   /*"
	text::write /line

	# Ticket [da61329276]: Detect C comment opener and closer, and
	# disarm them. This can occur with char classes, and char
	# sequences, i.e. strings. We recode them into
	# backslash-escaped unicode code-points.

	# Note: Putting this into the 'pe print' method is not
	# possible, as the output can be used in other contexts (Tcl,
	# whatever), each with their own special strings to be aware
	# of. This is something each generator has to handle, knowing
	# their special sequences.

	lappend map "*/" "\\u002a\\u002f"
	lappend map "/*" "\\u002f\\u002a"

	foreach l [split [pt::pe print $pe] \n] {
	    text::write field  "    * [string map $map $l]"
	    text::write /line
	}
	text::write field "    */"
	text::write /line
	text::write /line
    }
    # Keeping the definition of PE, albeit empty avoids having to
    # special case the places using this block.
    text::write store PE
    return
}

proc ::pt::peg::to::cparam::Op::Asm::String {s} {
    variable cache

    set k str,$s

    if {![info exists cache($k)]} {
	set id [incr cache(_str,counter)]
	set cache($k) $id

	lappend cache(_strings) \
	    "/* [format %8d $id] = */   \"$s\""
    }

    return $cache($k)
}

proc ::pt::peg::to::cparam::Op::Asm::Setup {} {
    variable counter 0
    variable field 3
    variable cache
    array unset cache *
    set cache(_str,counter) -1
    set cache(_strings)     {}
    return
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::cparam {
    namespace eval ::pt::peg::to::cparam::Op::Asm {
	variable counter 0
	variable fieldlen {17 5 5}
	variable field 3
	variable  cache
	array set cache {}
	set cache(_str,counter) -1
	set cache(_strings)     {}
    }

    # Map from option name (without leading dash) to the name of the
    # variable used to store setting.
    variable omap ; array set omap {
	comments        comments
	file            file
	fun-qualifier   def
	indent          indent
	insert-cmd      insertcmd
	main            main
	name            name
	namespace       ns
	prelude         prelude
	self-command    self
	state-decl      statedecl
	state-ref       stateref
	string-varname  strings
	template        template
	user            user
    }

    variable insertcmd {}
    variable comments  1
    variable self      {}
    variable ns        {}
    variable def       static
    variable main      __main
    variable indent    0
    variable prelude   {}
    variable statedecl {RDE_PARAM p}
    variable stateref  p
    variable strings   p_string

    variable template @code@       ; # A string. Together with the
				     # insertcmd (if any) it specifies
				     # how to embed the generated code
				     # into a larger framework (the
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

package provide pt::peg::to::cparam 1.1.3
return

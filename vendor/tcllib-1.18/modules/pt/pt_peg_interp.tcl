# -*- tcl -*-
#
# Copyright (c) 2009-2014 by Andreas Kupries <andreas_kupries@users.sourceforge.net>

# Interpreter for parsing expression grammars. In essence a recursive
# descent parser configurable with a parsing expression grammar.

# ### ### ### ######### ######### #########
## Package description

## The instances of this class parse a text provided through a channel
## based on a parsing expression grammar provided by a peg container
## object. The parsing process is interpretative, i.e. the parsing
## expressions are decoded and checked on the fly and possibly
## multiple times, as they are encountered.

## The interpreter operates in pull-push mode, i.e. the interpreter
## object is in charge and reads the characters from the channel as
## needed, and returns with the result of the parse, either when
## encountering an error, or when the parse was successful.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require pt::rde ; # Virtual machine geared to the parsing of PEGs.
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type ::pt::peg::interp {

    # ### ### ### ######### ######### #########
    ## Instance API

    constructor {} {}

    method use {grammar} {}

    method parse {channel} {} ; # Parse the contents of the channel
				# against the configured grammar.

    method parset {text}   {} ; # Parse the text against the
                                # configured grammar.

    # ### ### ### ######### ######### #########
    ## Options

    ## None

    # ### ### ### ######### ######### #########
    ## Instance API Implementation.

    constructor {} {
	# Create the runtime supporting the parsing process.
	set myparser [pt::rde ${selfns}::ENGINE]
	return
    }

    method use {grammar} {
	# Release the information of any previously used grammar.

	array unset myrhs  *
	array unset mymode *
	set mystart epsilon

	# Copy the grammar into internal tables.

	# Note how the grammar is not used in any way, shape, or form
	# afterward.

	# Note also that it is not required to verify the
	# grammar. This was done while it was loaded into the grammar
	# object, be it incrementally or at once.

	array set myrhs  [$grammar rules]
	array set mymode [$grammar modes]
	set mystart      [$grammar start]
	return
    }

    method parse {channel} {
	$myparser reset $channel
	$self {*}$mystart
	return [$myparser complete]
    }

    method parset {text} {
	$myparser reset
	$myparser data $text
	$self {*}$mystart
	return [$myparser complete]
    }

    # ### ### ### ######### ######### #########
    ## Parse operator implementation

    # No input to parse, nor consume. Ok, always.

    method epsilon {} {
	$myparser i_status_ok
	return
    }

    # Parse and consume one character. No matter which character. This
    # fails only when reaching EOF. Does not consume input on failure.

    method dot {} {
	$self Next
	return
    }

    # Parse and consume one specific character. This fails if the
    # character at the location is not in the specified character
    # class. Does not consume input on failure.

    foreach operator {
	alnum alpha ascii control ddigit digit    graph
	lower print punct space   upper  wordchar xdigit
    } {
	method $operator {} [string map [list @ $operator] {
	    $self Next
	    $myparser i:fail_return
	    $myparser i_test_@
	    return
	}]
    }

    # Parse and consume one specific character. This fails if the
    # character at the location is not the expected character. Does
    # not consume input on failure.
    
    method t {char} {
	$self Next
	$myparser i:fail_return
	$myparser i_test_char $char
	return
    }

    # Parse and consume one character, if in the specified range. This
    # fails if the read character is outside of the range. Does not
    # consume input on failure.

    method .. {chstart chend} {
	$self Next
	$myparser i:fail_return
	$myparser i_test_range $chstart $chend
	return
    }

    # To parse a nonterminal symbol in the input we execute its
    # parsing expression, i.e its right-hand side. This can be cut
    # short if the necessary information can be obtained from the
    # nonterminal cache. Does not consume input on failure.

    method n {symbol} {
	set savemode      $mycurrentmode
	set mycurrentmode $mymode($symbol)

	# Query NC, and shortcut
	if {[$myparser i_symbol_restore $symbol]} {
	    $self ASTFinalize
	    return
	}

	# Save location and AST construction state
	$myparser i_loc_push ; # (i)
	$myparser i_ast_push ; # (1)

	# Run the right hand side.
	$self {*}$myrhs($symbol)

	# Generate a semantic value, based on the currently active
	# semantic mode.
	switch -exact -- $mycurrentmode {
	    value   { $myparser i_value_clear/reduce $symbol }
	    leaf    { $myparser i_value_clear/leaf   $symbol }
	    void    { $myparser i_value_clear }
	}

	$myparser i_symbol_save $symbol

	# Drop ARS. Unconditional as any necessary reduction was done
	# already (See (a)), and left the result in SV
	$myparser i_ast_pop_rewind ; # (Ad 1)
	$self ASTFinalize

	# Even if parse is ok.
	$myparser i_error_nonterminal $symbol
	$myparser i_loc_pop_discard ; # (Ad i)
	return
    }

    # And lookahead predicate. We parse the expression against the
    # input and return the parse result. No input is consumed.

    method & {expression} {
	$myparser i_loc_push

	    $self {*}$expression

	$myparser i_loc_pop_rewind
	return
    }

    # Negated lookahead predicate. We parse the expression against the
    # input and returns the negated parse result. No input is
    # consumed.

    method ! {expression} {
	$myparser i_loc_push
	$myparser i_ast_push

	$self {*}$expression

	$myparser i_ast_pop_discard/rewind ;# -- fail/ok
	$myparser i_loc_pop_rewind
	$myparser i_status_negate
	return
    }

    # Parsing an optional expression. This tries to parse the sub
    # expression. It will never fail, even if the sub expression
    # itself is not succesful. Consumes only input if it could parse
    # the sub expression. Like *, but without the repetition.

    method ? {expression} {
	$myparser i_loc_push
	$myparser i_error_push

	$self {*}$expression

	$myparser i_error_pop_merge
	$myparser i_loc_pop_rewind/discard ;# -- fail/ok
	$myparser i_status_ok
	return
    }

    # Parse zero or more repetitions of an expression (Kleene
    # closure).  This consumes as much input as we were able to parse
    # the sub expression. The expresion as a whole is always
    # succesful, even if the sub expression fails (zero repetitions).

    method * {expression} {
	# do { ... } while ok.
	while {1} {
	    $myparser i_loc_push
	    $myparser i_error_push

	    $self {*}$expression

	    $myparser i_error_pop_merge
	    $myparser i_loc_pop_rewind/discard ;# -- fail/ok
	    $myparser i:ok_continue
	    break
	}
	$myparser i_status_ok
	return
    }

    # Parse one or more repetitions of an expression (Positive kleene
    # closure). This is similar to *, except for one round at the
    # front which has to parse for success of the whole. This
    # expression can fail. It will consume only as much input as it
    # was able to parse.

    method + {expression} {
	$myparser i_loc_push

	$self {*}$expression

	$myparser i_loc_pop_rewind/discard ;# -- fail/ok
	$myparser i:fail_return

	$self * $expression
	return
    }

    # Parsing a sequence of expressions. This parses each sub
    # expression in turn, each consuming input. In the case of failure
    # by one of the sequence's elements nothing is consumed at all.

    method x {args} {
	$myparser i_loc_push
	$myparser i_ast_push
	$myparser i_error_clear

	foreach expression $args {
	    $myparser i_error_push

	    $self {*}$expression

	    $myparser i_error_pop_merge
	    # Branch failed, track back and report to caller.
	    $myparser i:fail_ast_pop_rewind
	    $myparser i:fail_loc_pop_rewind
	    $myparser i:fail_return         ; # Stop trying on element failure
	}

	# All elements OK, squash backtracking state
	$myparser i_loc_pop_discard
	$myparser i_ast_pop_discard
	return
    }

    # Parsing a series of alternatives (Choice). This parses each
    # alternative in turn, always starting from the current
    # location. Nothing is consumed if all alternatives fail. Consumes
    # as much as was consumed by the succesful branch.

    method / {args} {
	$myparser i_error_clear

	foreach expression $args {
	    $myparser i_loc_push
	    $myparser i_ast_push
	    $myparser i_error_push

	    $self {*}$expression

	    $myparser i_error_pop_merge
	    $myparser i_ast_pop_rewind/discard
	    $myparser i_loc_pop_rewind/discard
	    $myparser i:fail_continue
	    return ; # Stop trying on finding a successful branch.
	}

	# All branches FAIL
	$myparser i_status_fail
	return
    }

    # ### ### ### ######### ######### #########

    method Next {} {
	# We are processing the outer method call into an atomic
	# parsing expression for error messaging.
	$myparser i_input_next [regsub {^.*Snit_method} [lreplace [info level -1] 1 4] {}]
	return
    }

    method ASTFinalize {} {
	if {$mycurrentmode ne "void"} {
	    $myparser i:ok_ast_value_push
	}
	upvar 1 savemode savemode
	set mycurrentmode $savemode
	return
    }

    # ### ### ### ######### ######### #########
    ## State Interpreter data structures.

    variable myparser      {}    ; # Our PARAM instantiation.
    variable myrhs  -array {}    ; # Dictionary mapping nonterminal
				   # symbols to parsing expressions
				   # describing their sentence
				   # structure.
    variable mymode -array {}    ; # Dictionary mapping nonterminal
				   # symbols to semantic modes
				   # (controlling AST generation).
    variable mystart  epsilon    ; # The parsing expression to start
				   # the parse process with.
    variable mycurrentmode value ; # The currently active semantic mode.

    # ### ### ### ######### ######### #########
    ## Debugging helper. To activate
    ## string map {{self {*}} {self TRACE {*}}}

    method TRACE {args} {
	puts |$args|enter
	set res [$self {*}$args]
	puts |$args|return
	return $res
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Package Management

package provide pt::peg::interp 1.0.1

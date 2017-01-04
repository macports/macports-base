# pt_peg_from_peg.tcl --
#
#	Conversion from PEG (Human readable text) to PEG.
#
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_from_peg.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes text for a human-readable PEG and produces the
# canonical serialization of a parsing expression grammar.

# TODO :: APIs for reading from arbitrary channel.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require pt::peg  ; # Verification that the input is proper.
#package require pt::peg::interp
#package require pt::peg::container::peg
package require pt::parse::peg
package require pt::ast
package require pt::pe
package require pt::pe::op

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::from::peg {
    namespace export   convert convert-file
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::from::peg::convert {text} {
    # Initialize data for the pseudo-channel
    variable input $text
    variable loc   0
    variable max   [expr { [string length $text] - 1 }]

    return [Convert]
}

proc ::pt::peg::from::peg::convert-file {path} {
    # Initialize data for the pseudo-channel
    variable input [fileutil::cat $path]
    variable loc   0
    variable max   [expr { [string length $input] - 1 }]

    return [Convert]
}

# ### ### ### ######### ######### #########

proc ::pt::peg::from::peg::Convert {} {
    # Create the runtime ...
    set c [chan create read pt::peg::from::peg::CHAN] ; # pseudo-channel for input

    #set g [pt::peg::container::peg %AUTO]             ; # load peg grammar
    #set i [pt::peg::interp         %AUTO% $g]         ; # grammar interpreter / parser
    #$g destroy
    set i [pt::parse::peg]

    # Parse input.
    set fail [catch {
	set ast [$i parse $c]
    } msg]
    if {$fail} {
	set ei $::errorInfo
	set ec $::errorCode
    }

    $i destroy
    close $c

    if {$fail} {
	variable input {}
	return -code error -errorinfo $ei -errorcode $ec $msg
    }

    # Now convert the AST to the grammar serial.
    set serial [pt::ast bottomup \
		    pt::peg::from::peg::GEN \
		    $ast]

    variable input {}
    return $serial

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals - Pseudo channel to couple the in-memory text with the
## RDE.

namespace eval ::pt::peg::from::peg::CHAN {
    namespace export   initialize finalize read watch
    namespace ensemble create
}

proc pt::peg::from::peg::CHAN::initialize {c mode} {
    return {initialize finalize watch read}
}

proc pt::peg::from::peg::CHAN::finalize {c}        {}
proc pt::peg::from::peg::CHAN::watch    {c events} {}

proc pt::peg::from::peg::CHAN::read {c n} {
    # Note: Should have binary string of the input, to properly handle
    # encodings ...
    variable ::pt::peg::from::peg::input
    variable ::pt::peg::from::peg::loc
    variable ::pt::peg::from::peg::max

    if {$loc >= $max} { return {} }

    set end [expr {$loc + $n - 1}]
    set res [string range $input $loc $end]

    incr loc $n

    return $res
}

# ### ### ### ######### ######### #########
## Internals - Bottom up walk converting AST to PEG serialization.
## Pseudo-ensemble

namespace eval ::pt::peg::from::peg::GEN {}

proc pt::peg::from::peg::GEN {ast} {
    # The reason for not being an ensemble, an additional param
    # (8.6+ can code that as ensemble).
    return [namespace eval GEN $ast]
}

proc pt::peg::from::peg::GEN::ALNUM {s e} {
    return [pt::pe alnum]    
}

proc pt::peg::from::peg::GEN::ALPHA {s e} {
    return [pt::pe alpha]    
}

proc pt::peg::from::peg::GEN::AND {s e} {
    return [pt::pe ahead [pt::pe dot]] ; # -> Prefix
}

proc pt::peg::from::peg::GEN::ASCII {s e} {
    return [pt::pe ascii]    
}

proc pt::peg::from::peg::GEN::Attribute {s e args} {
    return [lindex $args 0] ; # -> Definition
}

proc pt::peg::from::peg::GEN::Char {s e args} {
    return [lindex $args 0]
}

proc pt::peg::from::peg::GEN::CharOctalFull {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe terminal [char unquote [string range $input $s $e]]]
}

proc pt::peg::from::peg::GEN::CharOctalPart {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe terminal [char unquote [string range $input $s $e]]]
}

proc pt::peg::from::peg::GEN::CharSpecial {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe terminal [char unquote [string range $input $s $e]]]
}

proc pt::peg::from::peg::GEN::CharUnescaped {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe terminal [string range $input $s $e]]
}

proc pt::peg::from::peg::GEN::CharUnicode {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe terminal [char unquote [string range $input $s $e]]]
}

proc pt::peg::from::peg::GEN::Class {s e args} {
    if {[llength $args] == 1} { ; # integrated pe::op flatten
	return [lindex $args 0]
    } else {
	return [pt::pe choice {*}$args] ; # <- Chars and Ranges
    }
}

proc pt::peg::from::peg::GEN::CONTROL {s e} {
    return [pt::pe control]
}

proc pt::peg::from::peg::GEN::DDIGIT {s e} {
    return [pt::pe ddigit]
}

proc pt::peg::from::peg::GEN::Definition {s e args} {
    # args = list/2 (symbol pe)      | <-           Ident(ifier) Expression
    # args = list/3 (mode symbol pe) | <- Attribute Ident(ifier) Expression
    if {[llength $args] == 3} {
	lassign $args mode sym pe
    } else {
	lassign $args sym pe
	set mode value
    }
    # sym = list/2 ('n' name)
    return [list [lindex $sym 1] $mode [pt::pe::op flatten $pe]]
}

proc pt::peg::from::peg::GEN::DIGIT {s e} {
    return [pt::pe digit]
}

proc pt::peg::from::peg::GEN::DOT {s e} {
    return [pt::pe dot]
}

proc pt::peg::from::peg::GEN::Expression {s e args} {
    if {[llength $args] == 1} { ; # integrated pe::op flatten
	return [lindex $args 0]
    } else {
	return [pt::pe choice {*}$args] ; # <- Primary
    }
}

proc pt::peg::from::peg::GEN::Grammar {s e args} {
    # args = list (start, list/3(symbol, mode, rule)...) <- Header Definition*
    array set symbols {}
    set rules {}
    foreach def [lsort -index 0 -dict [lassign $args startexpr]] {
	lassign $def sym mode rhs
	if {[info exists symbol($sym)]} {
	    return -code error "Double declaration of symolb '$sym'"
	}
	set symbols($sym) .
	lappend rules $sym [list is $rhs mode $mode]
    }
    # Full grammar
    return [list pt::grammar::peg [list rules $rules start $startexpr]]
}

proc pt::peg::from::peg::GEN::GRAPH {s e} {
    return [pt::pe graph]
}

proc pt::peg::from::peg::GEN::Header {s e args} {
    # args = list/2 (list/2 ('n', name), pe) <- Ident(ifier) StartExpr
    return [lindex $args 1] ; # StartExpr passes through
}

proc pt::peg::from::peg::GEN::Ident {s e} {
    variable ::pt::peg::from::peg::input
    return [pt::pe nonterminal [string range $input $s $e]]
}

proc pt::peg::from::peg::GEN::Identifier {s e args} {
    return [lindex $args 0] ; # <- Ident, passes through
}

proc pt::peg::from::peg::GEN::LEAF {s e} {
    return leaf
}

proc pt::peg::from::peg::GEN::LOWER {s e} {
    return [pt::pe lower]
}

proc pt::peg::from::peg::GEN::Literal {s e args} {
    set n [llength $args]
    if {$n == 1} {
	# integrated pe::op flatten, return just the char.
	return [lindex $args 0]
    } elseif {$n == 0} {
	# No chars, empty string, IOW epsilon.
	return [pt::pe epsilon]
    } else {
	# Series of chars -> Primary
	return [pt::pe sequence {*}$args]
    }
}

proc pt::peg::from::peg::GEN::NOT {s e} {
    return [pt::pe notahead [pt::pe dot]] ; # -> Prefix (dot is placeholder)
}

proc pt::peg::from::peg::GEN::PLUS {s e} {
    return [pt::pe repeat1 [pt::pe dot]] ; # -> Suffix (dot is placeholder)
}

proc pt::peg::from::peg::GEN::Primary {s e args} {
    return [lindex $args 0] ; # -> Expression, pass through
}

proc pt::peg::from::peg::GEN::Prefix {s e args} {
    # args = list/1 (pe)            | <- AND/NOT, Expression
    # args = list/2 (pe/prefix, pe) | <- Expression
    if {[llength $args] == 2} {
	# Prefix operator present ... Replace its child (dot,
	# placeholder) with our second, the actual expression.
	return [lreplace [lindex $args 0] 1 1 [lindex $args 1]]
    } else {
	# Pass the sub-expression
	return [lindex $args 0]
    }
}

proc pt::peg::from::peg::GEN::PRINTABLE {s e} {
    return [pt::pe printable]
}

proc pt::peg::from::peg::GEN::PUNCT {s e} {
    return [pt::pe punct]    
}

proc pt::peg::from::peg::GEN::QUESTION {s e} {
    return [pt::pe optional [pt::pe dot]] ; # -> Suffix (dot is placeholder)
}

proc pt::peg::from::peg::GEN::Range {s e args} {
    # args = list/1 (pe/t)       | <- Char (pass through)
    # args = list/2 (pe/t, pe/t) | <- Char, Char
    if {[llength $args] == 2} {
	# Convert two terminals to range
	return [pt::pe range [lindex $args 0 1] [lindex $args 1 1]]
    } else {
	# Pass the char ...
	return [lindex $args 0]
    }
}

proc pt::peg::from::peg::GEN::Sequence {s e args} {
    if {[llength $args] == 1} { ; # integrated pe::op flatten
	return [lindex $args 0]
    } else {
	return [pt::pe sequence {*}$args] ; # <- Prefix+
    }
}

proc pt::peg::from::peg::GEN::SPACE {s e} {
    return [pt::pe space]
}

proc pt::peg::from::peg::GEN::STAR {s e} {
    return [pt::pe repeat0 [pt::pe dot]] ; # -> Suffix (dot is placeholder)
}

proc pt::peg::from::peg::GEN::StartExpr {s e args} {
    # args = list/1 (pe) | <- Expression, -> Header
    return [pt::pe::op flatten [lindex $args 0]]
}
proc pt::peg::from::peg::GEN::Suffix {s e args} {
    # args = list/1 (pe)            | <- Expression 
    # args = list/2 (pe, pe/suffix) | <- Expression */+/?
    if {[llength $args] == 2} {
	# Suffix operator present ... Replace its child (dot,
	# placeholder) with our first, the actual expression.
	return [lreplace [lindex $args 1] 1 1 [lindex $args 0]]
    } else {
	# Pass the sub-expression
	return [lindex $args 0]
    }
}

proc pt::peg::from::peg::GEN::UPPER {s e} {
    return [pt::pe upper]   
}

proc pt::peg::from::peg::GEN::VOID {s e} {
    return void
}

proc pt::peg::from::peg::GEN::WORDCHAR {s e} {
    return [pt::pe wordchar]
}

proc pt::peg::from::peg::GEN::XDIGIT {s e} {
    return [pt::pe xdigit]  
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::from::peg 1.0.3
return

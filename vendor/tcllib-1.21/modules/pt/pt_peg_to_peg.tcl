# peg_to_peg.tcl --
#
#	Conversion from PEG to PEG (Human readable text).
#
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_peg.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes the canonical serialization of a parsing
# expression grammar and produces text in PEG format, a form of text
# which specifies a PEG in a human readable, yet formal manner,
# similar too, but not identical to EBNF.

# ### ### ### ######### ######### #########
## Requisites

package  require Tcl 8.5
package  require pt::peg  ; # Verification that the input
				       # is proper.
package  require pt::pe              ; # Walking an expression.
package  require pt::pe::op          ; # Flatten & fuse.
package  require text::write         ; # Text generation support
package  require textutil::adjust
package  require struct::list

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::to::peg {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::peg::reset {} {
    variable template @code@
    variable name     a_pe_grammar
    variable file     unknown
    variable user     unknown
    variable fused    1
    return
}

proc ::pt::peg::to::peg::configure {args} {
    variable template
    variable name
    variable file
    variable user
    variable fused

    if {[llength $args] == 0} {
	return [list \
		    -file     $file \
		    -fused    $fused \
		    -name     $name \
		    -template $template \
		    -user     $user]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists $variable]} {
	    return [set $variable]
	} else {
	    return -code error "Expected one of -file, -fused, -name, -template, or -user, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists $variable]} {
		return -code error "Expected one of -file, -fused, -name, -template, or -user, got \"$option\""
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
		fused {
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

proc ::pt::peg::to::peg::convert {serial} {
    variable template
    variable name
    variable file
    variable user

    ::pt::peg verify-as-canonical $serial

    # Unpack the serialization, known as canonical
    array set peg $serial
    array set peg $peg(pt::grammar::peg)
    unset     peg(pt::grammar::peg)

    # Determine the field sizes for nonterminal symbol names and
    # semantic modes.

    set smax [text::write maxlen [dict keys $peg(rules)]]
    set mmax [ModeSize                      $peg(rules)]

    # Assemble the output, various pieces
    text::write reset
    Header $peg(start)
    Rules  $peg(rules) $mmax $smax
    Trailer

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

proc ::pt::peg::to::peg::Header {startexpression} {
    variable name

    text::write field  PEG
    text::write field  $name
    text::write field  ([Expression $startexpression])
    text::write /line
    return
}

proc ::pt::peg::to::peg::Rules {rules mmax smax} {
    if {[llength $rules]} { text::write /line }

    foreach {symbol def} $rules {
	lassign $def _ is _ mode
	set mode  [expr {($mode eq "value")
			 ? ""
			 : "${mode}:"}]

	text::write fieldl $mmax $mode
	text::write fieldl $smax $symbol
	text::write field        "<-"
	text::write field        [Expression $is] 
	text::write field        ";"
	text::write /line
    }

    if {[llength $rules]} { text::write /line }
    return
}

proc ::pt::peg::to::peg::Trailer {} {
    text::write field  {END;}
    text::write /line
    return
}

# ### ### ### ######### ######### #########

proc ::pt::peg::to::peg::Expression {pe} {
    variable fused

    if {$fused} {
	# First flatten for a maximum amount of adjacent terminals and
	# ranges, then fuse these into strings and classes, then
	# flatten again, eliminating all sequences and choices fully
	# subsumed by the new elements.

	set pe [pt::pe::op flatten \
		    [pt::pe::op fusechars \
			 [pt::pe::op flatten \
			      $pe]]]
    }

    return [lindex [pt::pe bottomup \
			[namespace current]::Convert \
			$pe] 0]
}

proc ::pt::peg::to::peg::Convert {pe operator arguments} {
    # For the inner nodes the each of arguments are a pair of
    # generated text, and the sub-expression it came from, in this
    # order.

    switch -exact -- $operator {
	alpha - alnum - ascii - control - digit - graph - lower - print -
	punct - space - upper - wordchar - xdigit - ddigit {
	    # Special forms ...
	    return [list <$operator> $pe]
	}
	dot {
	    # Special form ...
	    return [list "." $pe]
	}
	epsilon {
	    # Special form, represented by the empty string ...
	    return [list "''" $pe]
	}
	t {
	    # Character ...
	    lassign $arguments char
	    return [list "'[Char ${char}]'" $pe]
	}
	.. {
	    # Range of characters ... Show as character class.
	    # Note: Canonical input means that an expression like
	    # {.. X X} cannot occur, and can be ignored.

	    lassign $arguments chstart chend
	    return [list "\[[Char ${chstart}]-[Char $chend]\]" $pe]
	}
	n {
	    # Nonterminal symbol
	    lassign $arguments symbol
	    return [list $symbol $pe]
	}
	? - * - + {
	    # Suffix operators (Option, Kleene Closure, Positive KC) ...
	    lassign $arguments child
	    lassign $child text def
	    lassign $def coperator
	    return [list [MayParens $operator $coperator $text]$operator $pe]
	}
	& -
	! {
	    # Prefix operators (And/Not Lookahead) ...
	    lassign $arguments child
	    lassign $child text def
	    lassign $def coperator
	    return [list $operator[MayParens $operator $coperator $text] $pe]
	}
	x {
	    # Sequences ...
	    # TODO :: merge adjacent chars into strings ...  also, cut
	    # x out if only one child

	    set t {}
	    set x {}
	    foreach a $arguments {
		lassign $a text def
		lassign $def coperator
		lappend t [MayParens $operator $coperator $text]
		lappend x $def
	    }
	    return [list [join $t { }] [list x {*}$x]]
	}
	/ {
	    # Choices ...
	    # TODO :: merge adjacent chars and ranges into classes ...
	    # also, cut / out if only one child

	    set t {}
	    set x {}
	    foreach a $arguments {
		lassign $a text def
		lassign $def coperator
		lappend t [MayParens $operator $coperator $text]
		lappend x $def
	    }
	    return [list [join $t { / }] [list / {*}$x]]
	}
	str {
	    return [list \
			'[join [struct::list map $arguments \
				    [namespace current]::Char] {}]' \
			$pe]
	}
	cl {
	    return [list \
			\[[join [struct::list map $arguments \
				     [namespace current]::Range] {}]\] \
			$pe]
	}
    }
}

proc ::pt::peg::to::peg::Range {range} {
    # See also pt::peg::to::tclparam

    # Use string ops here to distinguish terminals and ranges. The
    # input can be a single char, not a list, and further the char may
    # not be a proper list. Example: double-apostroph.
    if {[string length $range] > 1} {
	lassign $range s e
	return [Char $s]-[Char $e]
    } else {
	return [Char $range]
    }
}

proc ::pt::peg::to::peg::Char {ch} {
    # Encode a character, handle special cases.  We cannot use package
    # char, as that is geared towards character encoding for Tcl code.

    switch -exact -- $ch {
	"\n" { return "\\n"  }
	"\r" { return "\\r"  }
	"\t" { return "\\t"  }
	"\\" { return "\\\\" }
	"\"" { return "\\\"" }
	"'"  { return "\\'"  }
	"\]" { return "\\\]" }
	"\[" { return "\\\[" }
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode

    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.

    return $ch

}

proc ::pt::peg::to::peg::MayParens {op cop text} {
    if {![NeedParens $op $cop]} { return $text }
    return "([::textutil::adjust::indent $text " " 1])"
}

proc ::pt::peg::to::peg::NeedParens {op cop} {
    variable priority
    # c(hild)op is nested under op.
    # Parens are required if cop has a lower priority than op.

    return [expr {$priority($cop) < $priority($op)}]
}

# ### ### ### ######### ######### #########

proc ::pt::peg::to::peg::ModeSize {rules} {
    set modes {}
    foreach {symbol def} $rules {
	lassign $def _ is _ mode
	if {$mode eq "value"} continue ; # These are not shown in the
					 # text representation, as
					 # they are the implicit
					 # default for it.
	lappend modes ${mode}:
    }
    return [text::write maxlen [lsort -uniq $modes]]
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::peg {

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
    variable fused    1            ; # Boolean flag. If true character
				     # sequences and choices are fused
				     # into strings and classes.

    variable  priority
    array set priority {
	/ 0  t       4  ascii 4  upper    4
	x 1  n       4  digit 4  wordchar 4
	& 2  ..      4  graph 4  xdigit   4
	! 2  dot     4  lower 4  ddigit   4
	+ 3  epsilon 4  print 4  str      4
	* 3  alnum   4  punct 4  cl       4
	? 3  alpha   4  space 4  control  4
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::to::peg 1.0.2
return

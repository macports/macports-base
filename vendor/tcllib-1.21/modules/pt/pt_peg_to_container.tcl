# peg_to_container.tcl --
#
#	Conversion from PEG to CONTAINER (Tcl code).
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_to_container.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes the canonical serialization of a parsing
# expression grammar and produces text in CONTAINER format, a form
# of Tcl code which defines a snit::type whose instances store the
# converted grammar.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require pt::peg ; # Verification that the input is
				     # proper.
package require pt::pe             ; # Conversion of expressions.
package require text::write        ; # Text generation support
package require char               ; # Character quoting needed for
				     # the Tcl code to be correct.

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::to::container {
    namespace export \
	reset configure convert

    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::to::container::reset {} {
    variable template @code@
    variable mode     bulk
    variable name     a_pe_grammar
    variable file     unknown
    variable user     unknown
    return
}

proc ::pt::peg::to::container::configure {args} {
    variable template
    variable mode
    variable name
    variable file
    variable user

    if {[llength $args] == 0} {
	return [list \
		    -file     $file \
		    -mode     $mode \
		    -name     $name \
		    -template $template \
		    -user     $user]
    } elseif {[llength $args] == 1} {
	lassign $args option
	set variable [string range $option 1 end]
	if {[info exists $variable]} {
	    return [set $variable]
	} else {
	    return -code error "Expected one of -file, -mode, -name, -template, or -user, got \"$option\""
	}
    } elseif {[llength $args] % 2 == 0} {
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    if {![info exists $variable]} {
		return -code error "Expected one of -file, -mode, -name, -template, or -user, got \"$option\""
	    }
	}
	foreach {option value} $args {
	    set variable [string range $option 1 end]
	    switch -exact -- $variable {
		mode {
		    if {$value ni {bulk incremental}} {
			return -code error "Expected bulk, or incremental, got \"$value\""
		    }
		}
		template {
		    if {$value eq {}} {
			return -code error "Expected template, got the empty string"
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

proc ::pt::peg::to::container::convert {serial} {
    variable user
    variable file
    variable name
    variable mode
    variable template

    ::pt::peg verify-as-canonical $serial

    # TODO :: Reformat expressions for line-length (wrapping)
    # TODO :: Reformat 'add' bulk symbols for line-length (wrapping).
    # TODO :: Generate a read-only container.

    # Unpack the serialization, known as canonical.
    array set peg $serial
    array set peg $peg(pt::grammar::peg)
    unset     peg(pt::grammar::peg)

    # Determine the field size for nonterminal symbol names.
    set smax [text::write maxlen [dict keys $peg(rules)]]

    # Assemble the output, various pieces.
    text::write reset
    StartExpression $peg(start)
    Rules           $peg(rules) $smax
    Type

    # At last retrieve the fully assembled code and integrate with the
    # chosen template.
    return [string map \
		[list \
		     @user@   $user \
		     @format@ CONTAINER \
		     @file@   $file \
		     @name@   $name \
		     @mode@   $mode \
		     @code@   [text::write get]] $template]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Internals

proc ::pt::peg::to::container::StartExpression {startexpression} {
    text::write clear

    text::write field   install myg using pt::peg::container {${selfns}::G}
    text::write /line

    text::write field   {$myg} start [Expression $startexpression]
    text::write /line

    text::write indent 4
    text::write store START
    return
}

proc ::pt::peg::to::container::Rules {rules smax} {
    variable mode
    text::write clear
    if {[llength $rules]} {
	text::write /line
	switch -exact -- $mode {
	    bulk        { BulkLoading        $rules $smax }
	    incremental { IncrementalLoading $rules $smax }
	}

	text::write field  return
	text::write /line

	text::write indent 4
    }
    text::write store RULES
    return
}

proc ::pt::peg::to::container::BulkLoading {rules smax} {
    # 2 phases. First reshuffle the input into bulk
    # dictionaries, then write them.

    foreach {symbol def} $rules {
	lassign $def _ is _ mode
	lappend symbols $symbol
	lappend modes   $symbol $mode
	lappend rhs     $symbol $is
    }

    text::write clear
    foreach {symbol mode} $modes {
	text::write fieldl $smax $symbol
	text::write field        $mode
	text::write /line
    }
    text::write indent 4
    text::write store MODES

    text::write clear
    foreach {symbol is} $rhs {
	text::write fieldl $smax $symbol
	text::write field        [Expression $is]
	text::write /line
    }
    text::write indent 4
    text::write store RULES

    # note - allow line wrapping, max length of line?
    text::write clear
    text::write field {$myg} {add  } {*}$symbols
    text::write /line

    text::write field {$myg} modes \{
    text::write /line

    text::write recall MODES

    text::write field \}
    text::write /line

    text::write field {$myg} rules \{
    text::write /line

    text::write recall RULES

    text::write field \}
    text::write /line
    return
}

proc ::pt::peg::to::container::IncrementalLoading {rules smax} {
    foreach {symbol def} $rules {
	lassign $def _ is _ mode

	text::write field        {$myg}
	text::write fieldl 5     add
	text::write fieldl $smax $symbol
	text::write /line

	text::write field        {$myg}
	text::write fieldl 5     mode
	text::write fieldl $smax $symbol
	text::write field        $mode
	text::write /line

	text::write field        {$myg}
	text::write fieldl 5     rule
	text::write fieldl $smax $symbol
	text::write field        [Expression $is]
	text::write /line

	text::write /line
    }
    return
}

proc ::pt::peg::to::container::TypeBody {} {
    text::write clear

    text::write field constructor "{}" \{
    text::write /line

    text::write recall START
    text::write recall RULES

    text::write field \}
    text::write /line

    text::write /line

    text::write field component myg
    text::write /line

    text::write field delegate method * to myg
    text::write /line

    text::write indent 4
    text::write store BODY
    return
}

proc ::pt::peg::to::container::Type {} {
    variable name

    TypeBody

    text::write clear

    text::write field snit::type $name \{
    text::write /line

    text::write recall BODY

    text::write field \}
    text::write /line
    return
}

proc ::pt::peg::to::container::Expression {pe} {
    return [list [pt::pe bottomup \
		      [namespace current]::Convert \
		      $pe]]
}

proc ::pt::peg::to::container::Convert {pe operator arguments} {
    if {$operator eq "t"} {
	return "$operator [char quote tcl [lindex $arguments 0]]"
    } elseif {$operator eq ".."} {
	lassign $arguments ca ce
	return "$operator [char quote tcl $ca] [char quote tcl $ce]"
    } else {
	return $pe
    }
    return -code error {INTERNAL ERROR}
}

# ### ### ### ######### ######### #########
## Configuration

namespace eval ::pt::peg::to::container {

    variable template @code@       ; # A string. Specifies how to
				     # embed the generated code into a
				     # larger frame- work (the
				     # template).
    variable mode     bulk         ; # enum (bulk,
				     # incremental). Chooses between
				     # code for bulk or incrementally
				     # loading of the grammar into its
				     # container.
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

package provide pt::peg::to::container 1
return

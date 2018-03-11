# -*- tcl -*-
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>

# Verification of serialized PEGs, and conversion between
# serializations and other data structures.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5                 ; # Required runtime.
package require pt::pe

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::peg {
    namespace export \
	verify verify-as-canonical canonicalize print merge equal
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of a keyword index is
# indeed such.

proc ::pt::peg::verify {serial {canonvar {}}} {
    variable ourprefix
    variable ourshort
    variable ourtag
    variable ourcbadlen
    variable ourmiss
    variable ourbadpe
    variable ourcode

    # Basic syntax: Length and outer type code
    if {[llength $serial] != 2} {
	return -code error $ourprefix$ourshort
    }

    lassign $serial tag contents

    if {$tag ne $ourcode} {
	return -code error $ourprefix[format $ourtag $tag]
    }

    # contents = dict (rules, start -> ...)

    if {[llength $contents] != 4} {
	return -code error $ourprefix$ourcbadlen
    }

    # Unpack the contents, then check that all necessary keys are
    # present. Together with the length check we can then also be
    # sure that no other key is present either.
    array set peg $contents
    foreach k {rules start} {
	if {[info exists peg($k)]} continue
	return -code error $ourprefix[format $ourmiss $k]
    }

    if {[catch {
	pt::pe verify $peg(start) canon
    } msg]} {
	return -code error \
	    [string map \
		 [list \
		      {error in serialization:} \
		      $ourprefix[format $ourbadpe start]] \
		 $msg]
    }

    if {$canonvar eq {}} {
	VerifyRules $peg(rules)
    } else {
	upvar 1 $canonvar iscanonical
	set iscanonical $canon

	VerifyRules $peg(rules) iscanonical

	# Quick exit if the inner structure was already
	# non-canonical.
	if {!$iscanonical} return

	# Now various checks if the keys and identifiers are
	# properly sorted to make this a canonical serialization.

	lassign $contents a _ b _
	if {[list $a $b] ne {rules start}} {
	    set iscanonical 0
	}

	if {$serial ne [list {*}$serial]} {
	    set iscanonical 0
	}

	if {$contents ne [list {*}$contents]} {
	    set iscanonical 0
	}
    }

    # Everything checked out.
    return
}

proc ::pt::peg::verify-as-canonical {serial} {
    verify $serial iscanonical
    if {!$iscanonical} {
	variable ourprefix
	variable ourdupsort
	return -code error $ourprefix$ourdupsort
    }
    return
}

proc ::pt::peg::canonicalize {serial} {
    variable ourcode

    verify $serial iscanonical
    if {$iscanonical} { return $serial }

    # Unpack the serialization.
    array set peg $serial
    array set peg $peg($ourcode)
    unset     peg($ourcode)

    # Construct result, inside out
    set rules {}
    array set r $peg(rules)
    foreach symbol [lsort -dict [array names r]] {
	array set sd $r($symbol)
	lappend rules \
	    $symbol [list \
			 is   [pt::pe \
				   canonicalize $sd(is)] \
			 mode $sd(mode)]
	unset sd
    }

    set serial [list $ourcode \
		    [list \
			 rules  $rules \
			 start  [pt::pe \
				     canonicalize $peg(start)]]]
    return $serial
}

# Converts a PEG serialization into a human readable string for
# test results. It assumes that the serialization is at least
# structurally sound.

proc ::pt::peg::print {serial} {
    variable ourcode

    # Unpack the serialization.
    array set peg $serial
    array set peg $peg($ourcode)
    unset     peg($ourcode)
    # Print
    set lines {}
    lappend lines $ourcode
    lappend lines "    start := [join [split [pt::pe print $peg(start)] \n] "\n             "]"
    lappend lines {    rules}
    foreach {symbol value} $peg(rules) {
	array set sd $value
	# keys :: is, mode
	lappend lines "        $symbol :: <$sd(mode)> :="
	lappend lines "            [join [split [pt::pe print $sd(is)] \n] "\n            "]"
	unset sd
    }
    return [join $lines \n]
}

# # ## ### ##### ######## #############

proc ::pt::peg::merge {seriala serialb} {
    variable ourcode

    verify $seriala
    verify $serialb

    array set pega $seriala
    array set pega $pega($ourcode)
    unset     pega($ourcode)

    array set pegb $serialb
    array set pegb $pegb($ourcode)
    unset     pegb($ourcode)

    array set ra $pega(rules)
    array set rb $pegb(rules)

    foreach symbol [array names rb] {
	if {![info exists ra($symbol)]} {
	    # No conflict possible, copy over
	    set ra($symbol) $rb($symbol)
	} else {
	    # unpack definitions, check for conflicts
	    array set sda $ra($symbol)
	    array set sdb $rb($symbol)

	    if {$sda(mode) ne $sdb(mode)} {
		return -code "Merge error for nonterminal \"$symbol\", semantic mode mismatch"
	    }

	    # Merge parsing expressions, if not identical ...
	    if {![pt::pe equal \
		      $sda(is) \
		      $sdb(is)]} {
		set sda(is) [pt::pe choice \
				 $sda(is) \
				 $sdb(is)]
		set ra($symbol) [array get sda]
	    }

	    unset sda
	    unset sdb
	}
    }

    # Construct result, inside out

    set rules {}
    foreach symbol [lsort -dict [array names ra]] {
	array set sd $ra($symbol)
	lappend rules \
	    $symbol [list \
			 is   $sd(is) \
			 mode $sd(mode)]
	unset sd
    }

    if {![pt::pe equal \
	      $pega(start) \
	      $pegb(start)]} {
	set start [pt::pe choice \
		       $pega(start) \
		       $pegb(start)]
    } else {
	set start $pega(start)
    }

    set serial [list $ourcode \
		    [list \
			 rules  $rules \
			 start  $start]]
    return $serial

}

# # ## ### ##### ######## #############

proc ::pt::peg::equal {seriala serialb} {
    # syntactical (intensional) grammar equality.
    string equal \
	[canonicalize $seriala] \
	[canonicalize $serialb]
}

# # ## ### ##### ######## #############


proc ::pt::peg::VerifyRules {rules {canonvar {}}} {
    variable ourprefix
    variable ourrbadlen
    variable oursdup
    variable oursempty
    variable oursbadlen
    variable oursmiss
    variable ourbadpe
    variable ourbadmode
    variable ourmode

    if {$canonvar ne {}} {
	upvar 1 $canonvar iscanonical
    }

    if {[llength $rules] % 2 == 1} {
	return -code error $ourprefix$ourrbadlen
    }

    if {$rules ne [list {*}$rules]} {
	set iscanonical 0
    }

    array set r $rules

    if {([array size r]*2) < [llength $rules]} {
	return -code error $ourprefix$oursdup
    }

    foreach symbol [array names r] {
	if {$symbol eq {}} {
	    return -code error $ourprefix$oursempty
	}

	set def $r($symbol)

	if {[llength $def] != 4} {
	    return -code error $ourprefix[format $oursbadlen $symbol]
	}

	if {$def ne [list {*}$def]} {
	    set iscanonical 0
	}

	array set sd $def
	foreach k {is mode} {
	    if {[info exists sd($k)]} continue
	    return -code error $ourprefix[format $oursmiss $symbol $k]
	}

	if {[catch {
	    pt::pe verify $sd(is) canon
	} msg]} {
	    return -code error \
		[string map \
		     [list \
			  {error in serialization:} \
			  $ourprefix[format $ourbadpe ($symbol)]] \
		     $msg]
	}

	if {![info exists ourmode($sd(mode))]} {
	    return -code error $ourprefix[format $ourbadmode $symbol $sd(mode)]
	}

	# Now various checks if the keys and identifiers are
	# properly sorted to make this a canonical serialization.

	if {!$canon} {
	    set iscanonical 0
	    continue
	}

	lassign $def a _ b _
	if {[list $a $b] ne {is mode}} {
	    set iscanonical 0
	}
    }
    return
}

namespace eval ::pt::peg {
    # # ## ### ##### ######## #############

    variable ourcode      pt::grammar::peg
    variable ourprefix    {error in serialization:}
    #                                                                              # Test cases (grammar-peg-structure-)
    variable ourshort     { dictionary too short, expected exactly one key}      ; # 
    variable ourtag       { bad type tag "%s"}                                   ; # 
    variable ourcbadlen   { dictionary of bad length, expected exactly two keys} ; # 
    variable ourmiss      { missing expected key "%s"}                           ; # 
    variable oursmiss     { symbol "%s", missing expected key "%s"}                           ; # 
    variable ourbadpe     { bad %s parsing expression:}                      ; # 
    variable ourbadmode   { symbol "%s", bad nonterminal mode "%s"}                           ; # 
    variable ourrbadlen   { rule dictionary of bad length, not a dictionary}     ; # 
    variable oursempty    { expected symbol name, got empty string}
    variable oursbadlen   { symbol dictionary for "%s" of bad length, expected exactly two keys} ; # 
    variable oursdup      { duplicate nonterminal keywords}                                  ; # 
    # Message for non-canonical serialization when expecting canonical form
    variable ourdupsort   { duplicate and/or unsorted keywords and/or irrelevant whitespace}                ; #

    variable  ourmode
    array set ourmode {
	value .
	leaf  .
	void  .
    }

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::peg 1
return

# -*- tcl -*-
# Copyright (c) 2009-2014 Andreas Kupries <andreas_kupries@sourceforge.net>

# Verification of serialized parsing expressions, conversion
# between such and other data structures, and their construction.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.
package require char                 ; # Character quoting utilities.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::pe {
    namespace export \
	verify verify-as-canonical canonicalize \
	bottomup topdown print equal \
	\
	epsilon dot alnum alpha ascii digit graph lower printable \
	control punct space upper wordchar xdigit ddigit \
	nonterminal optional repeat0 repeat1 ahead notahead \
	choice sequence \
	terminal range class str

    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of a keyword index is
# indeed such.

proc ::pt::pe::verify {serial {canonvar {}}} {
    variable ourprefix
    variable ourempty
    #puts "V <$serial> /[llength [info level 0]] / [info level 0]"

    if {[llength $serial] == 0} {
	return -code error $ourprefix$ourempty
    }

    if {$canonvar ne {}} {
	upvar 1 $canonvar iscanonical
	set iscanonical [string equal $serial [list {*}$serial]]
    }

    topdown [list [namespace current]::Verify] $serial
    return
}

proc ::pt::pe::verify-as-canonical {serial} {
    verify $serial iscanonical
    if {!$iscanonical} {
	variable ourprefix
	variable ourimpure
	return -code error $ourprefix$ourimpure
    }
    return
}

proc ::pt::pe::Verify {pe op arguments} {
    variable ourprefix
    variable ourbadop
    variable ourarity
    variable ourwrongargs
    variable ourempty

    #puts "VE <$pe /$op /$arguments>"
    if {[llength $pe] == 0} {
	return -code error $ourprefix$ourempty
    }

    if {![info exists ourarity($op)]} {
	return -code error $ourprefix[format $ourbadop $op]
    }

    lassign $ourarity($op) min max

    set n [llength $arguments]
    if {($n < $min) || (($max >= 0) && ($n > $max))} {
	return -code error $ourprefix[format $ourwrongargs $op]
    }

    upvar 1 iscanonical iscanonical
    if {
	[info exists iscanonical] &&
	(($pe ne [list {*}$pe]) ||
	 ($op eq "..") && ([lindex $arguments 0] eq [lindex $arguments 1]))
    } {
	# Reject coding with superfluous whitespace, and the use of
	# {.. x x} as coding for {t x} as non-canonical.

	set iscanonical 0
    }
    return
}

# # ## ### ##### ######## #############

proc ::pt::pe::canonicalize {serial} {
    verify $serial iscanonical
    if {$iscanonical} { return $serial }
    return [bottomup [list [namespace current]::Canonicalize] $serial]
}

proc ::pt::pe::Canonicalize {pe op arguments} {
    # The input is mostly already pulled apart into its elements. Now
    # we construct a pure list out of them, and if necessary, convert
    # a {.. x x} expression into the canonical {t x} representation.

    if {($op eq ".." ) &&
	([lindex $arguments 0] eq [lindex $arguments 1])} {
	return [list t [lindex $arguments 0]]
    }
    return [list $op {*}$arguments]
}

# # ## ### ##### ######## #############

# Converts a parsing expression serialization into a human readable
# string for test results. It assumes that the serialization is at
# least structurally sound.

proc ::pt::pe::print {serial} {
    return [join [bottomup [list [namespace current]::Print] $serial] \n]
}

proc ::pt::pe::Print {pe op arguments} {
    switch -exact -- $op {
	epsilon - alpha - alnum - ascii - digit - graph - lower - print - \
	    control - punct - space - upper - wordchar - xdigit - ddigit - dot {
		return [list <$op>]
	    }
	str { return [list "\"[join [char quote comment {*}$arguments] {}]\""] }
	cl  { return [list "\[[join [char quote comment {*}$arguments] {}]\]"] }
	n   { return [list "([lindex $arguments 0])"] }
	t   { return [list "'[char quote comment [lindex $arguments 0]]'"] }
	..  {
	    lassign $arguments ca ce
	    return [list "range ([char quote comment $ca] .. [char quote comment $ce])"]
	}
    }
    # The arguments are already processed for printing

    set out {}
    lappend out $op
    foreach a $arguments {
	foreach line $a {
	    lappend out "    $line"
	}
    }
    return $out
}

# # ## ### ##### ######## #############

proc ::pt::pe::equal {seriala serialb} {
    return [string equal \
		[canonicalize $seriala] \
		[canonicalize $serialb]]
}

# # ## ### ##### ######## #############

proc ::pt::pe::bottomup {cmdprefix pe} {
    Bottomup 2 $cmdprefix $pe
}

proc ::pt::pe::Bottomup {level cmdprefix pe} {
    set op [lindex $pe 0]
    set ar [lrange $pe 1 end]

    switch -exact -- $op {
	& - ! - * - + - ? - x - / {
	    set clevel $level
	    incr clevel
	    set nar {}
	    foreach a $ar {
		lappend nar [Bottomup $clevel $cmdprefix $a]
	    }
	    set ar $nar
	    set pe [list $op {*}$nar]
	}
	default {}
    }

    return [uplevel $level [list {*}$cmdprefix $pe $op $ar]]
}

proc ::pt::pe::topdown {cmdprefix pe} {
    Topdown 2 $cmdprefix $pe
    return
}

proc ::pt::pe::Topdown {level cmdprefix pe} {
    set op [lindex $pe 0]
    set ar [lrange $pe 1 end]

    uplevel $level [list {*}$cmdprefix $pe $op $ar]

    switch -exact -- $op {
	& - ! - * - + - ? - x - / {
	    incr level
	    foreach a $ar {
		Topdown $level $cmdprefix $a
	    }
	}
	default {}
    }
    return
}

# # ## ### ##### ######## #############

proc ::pt::pe::epsilon   {} { return epsilon  }
proc ::pt::pe::dot       {} { return dot      }
proc ::pt::pe::alnum     {} { return alnum    }
proc ::pt::pe::alpha     {} { return alpha    }
proc ::pt::pe::ascii     {} { return ascii    }
proc ::pt::pe::control   {} { return control  }
proc ::pt::pe::digit     {} { return digit    }
proc ::pt::pe::graph     {} { return graph    }
proc ::pt::pe::lower     {} { return lower    }
proc ::pt::pe::printable {} { return print    }
proc ::pt::pe::punct     {} { return punct    }
proc ::pt::pe::space     {} { return space    }
proc ::pt::pe::upper     {} { return upper    }
proc ::pt::pe::wordchar  {} { return wordchar }
proc ::pt::pe::xdigit    {} { return xdigit   }
proc ::pt::pe::ddigit    {} { return ddigit   }

proc ::pt::pe::nonterminal {nt} { list n $nt }
proc ::pt::pe::optional    {pe} { list ? $pe }
proc ::pt::pe::repeat0     {pe} { list * $pe }
proc ::pt::pe::repeat1     {pe} { list + $pe }
proc ::pt::pe::ahead       {pe} { list & $pe }
proc ::pt::pe::notahead    {pe} { list ! $pe }

proc ::pt::pe::choice   {pe args} { linsert $args 0 / $pe }
proc ::pt::pe::sequence {pe args} { linsert $args 0 x $pe }

proc ::pt::pe::terminal {t} {
    list t $t
}
proc ::pt::pe::range {ta tb} {
    if {$ta eq $tb} {
	list t $ta
    } else {
	list .. $ta $tb
    }
}
proc ::pt::pe::class {set} {
    if {[string length $set] > 1} {
	list cl $set
    } else {
	list t $set
    }
}
proc ::pt::pe::str {str} {
    if {[string length $str] > 1} {
	list str $str
    } else {
	list t $str
    }
}

namespace eval ::pt::pe {
    # # ## ### ##### ######## #############
    ## Strings for error messages.

    variable ourprefix    "error in serialization:"
    variable ourempty     " got empty string"
    variable ourwrongargs " wrong#args for \"%s\""
    variable ourbadop     " invalid operator \"%s\""
    variable ourimpure    " has irrelevant whitespace or (.. X X)"

    # # ## ### ##### ######## #############
    ## operator arities

    variable  ourarity
    array set ourarity {
	epsilon  {0 0}
	alpha    {0 0}
	alnum    {0 0}
	ascii    {0 0}
	control  {0 0}
	digit    {0 0}
	graph    {0 0}
	lower    {0 0}
	print    {0 0}
	punct    {0 0}
	space    {0 0}
	upper    {0 0}
	wordchar {0 0}
	xdigit   {0 0}
	ddigit   {0 0}
	dot      {0 0}
	..       {2 2}
	n        {1 1}
	t        {1 1}
	&        {1 1}
	!        {1 1}
	*        {1 1}
	+        {1 1}
	?        {1 1}
	x        {1 -1}
	/        {1 -1}
    }

    ##
    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::pe 1.0.2
return

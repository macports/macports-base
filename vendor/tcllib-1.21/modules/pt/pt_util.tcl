# -*- tcl -*-
# Copyright (c) 2014 Andreas Kupries <andreas_kupries@sourceforge.net>

# Utility commands for parser syntax errors.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5 ; # Required runtime.
package require char

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::util {
    namespace export error2readable error2position error2text
    namespace ensemble create

    namespace import ::char::quote
}

# # ## ### ##### ######## #############
## Public API

proc ::pt::util::error2readable {error text} {
    lassign $error _ location msgs
    lassign [Position $location $text] l c

    lappend map \n \\n
    lappend map \r \\r
    lappend map \t \\t

    # Get 10 chars before and after the failure point.  Depending on
    # the relative position of input beginning and end we may get less
    # back of either.  Special characters in the input (line endings,
    # tabs) are quoted to keep this on a single line.
    set prefix [string map $map [string range $text ${location}-10 $location]]
    set suffix [string map $map [string range $text ${location}+1 ${location}+10]]

    # Construct a line pointing to the failure position. By using the
    # transformed prefix as our source (length) no complex
    # calculations are required. It is implicit in the prefix/suffix
    # separation above.
    set  n [string length $prefix]
    incr n -1
    set point [string repeat - $n]
    append point ^

    # Print our results.
    lappend lines "Parse error at position $location (Line $l, column $c)."
    lappend lines "... ${prefix}${suffix} ..."
    lappend lines "    $point"
    lappend lines "Expected one of"
    lappend lines "* [join [Readables $msgs] "\n* "]"
    lappend lines ""

    return [join $lines \n]
}

proc ::pt::util::error2position {error text} {
    lassign $error _ location msgs
    return [Position $location $text]
}

proc ::pt::util::error2text {error} {
    lassign $error _ location msgs
    return [Readables $msgs]
}

# # ## ### ##### ######## #############
## Internals

proc ::pt::util::Position {location text} {
    incr location -1

    # Computing the line/col of a position is quite easy. Split the
    # part before the location into lines (at eol), count them, and
    # look at the length of the last line in that.

    set prefix [string range $text 0 $location]
    set lines  [split $prefix \n]
    set line   [llength $lines]
    set col    [string length [lindex $lines end]]

    return [list $line $col]
}

proc ::pt::util::Readables {msgs} {
    set cl {}
    set r {}
    foreach pe $msgs {
	switch -exact -- [lindex $pe 0] {
	    t {
		# Fuse to multiple 't'-tags into a single 'cl'-tag.
		lappend cl [lindex $pe 1]
	    }
	    cl {
		# Fuse multiple 'cl'-tags into one.
		foreach c [split [lindex $pe 1]] { lappend cl $c }
	    }
	    default {
		lappend r [Readable $pe]
	    }
	}
    }
    if {[set n [llength $cl]]} {
	if {$n > 1} {
	    lappend r [Readable [list cl [join [lsort -dict $cl] {}]]]
	} else {
	    lappend r [Readable [list t [lindex $cl 0]]]
	}
    }
    return [lsort -dict $r]
}

proc ::pt::util::Readable {pe} {
    set details [lassign $pe tag]
    switch -exact -- $tag {
	t        {
	    set details [quote string {*}$details]
	    set m "The character '$details'"
	}
	n        { set m "The symbol $details" }
	..       {
	    set details [quote string {*}$details]
	    set m "A character in range '[join $details '-']'"
	}
	str      {
	    set details [join [quote string {*}[split $details {}]] {}]
	    set m "A string \"$details\""
	}
	cl       {
	    set details [join [quote string {*}[split $details {}]] {}]
	    set m "A character in set \{$details\}"
	}
	alpha    { set m "A unicode alphabetical character" }
	alnum    { set m "A unicode alphanumerical character" }
	ascii    { set m "An ascii character" }
	digit    { set m "A unicode digit character" }
	graph    { set m "A unicode printing character, but not space" }
	lower    { set m "A unicode lower-case alphabetical character" }
	print    { set m "A unicode printing character, including space" }
	control  { set m "A unicode control character" }
	punct    { set m "A unicode punctuation character" }
	space    { set m "A unicode space character" }
	upper    { set m "A unicode upper-case alphabetical character" }
	wordchar { set m "A unicode word character (alphanumerics + connectors)" }
	xdigit   { set m "A hexadecimal digit" }
	ddigit   { set m "A decimal digit" }
	dot      { set m "Any character" }
	default  { set m [string totitle $tag] }
    }
    return $m
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::util 1.1
return
